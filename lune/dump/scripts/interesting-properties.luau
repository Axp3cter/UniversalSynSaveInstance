--!strict

--[=[
	@class InterestingProperties

	Detects properties with unusual serialization characteristics.

	Identifies asymmetric serialization (CanLoad≠CanSave), deprecated
	but saveable properties, and NotCreatable classes with non-placeholder
	defaults that reveal instance state otherwise inaccessible.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local MEMBER_TYPE_PROPERTY = "Property"
local PLACEHOLDER_PREFIX = "__api_dump_"

-- Types

type AsymmetricProperty = {
	type: "asymmetric",
	class: string,
	property: string,
	reason: string,
	canSave: boolean?,
	canLoad: boolean?,
	deprecated: boolean?,
}

type NotCreatableDefault = {
	type: "notCreatableDefault",
	class: string,
	property: string,
	default: string,
}

type Property = AsymmetricProperty | NotCreatableDefault

type PropertyData = {
	default: string?,
	tags: { [string]: any },
}

type ClassData = {
	tags: { [string]: any },
	props: { [string]: PropertyData },
}

-- Helpers

--[=[
	Checks if a default value is a placeholder.

	Placeholder values contain the prefix "__api_dump_" and don't
	represent actual runtime defaults.

	@param value string? -- Default value to check
	@return boolean -- True if placeholder or nil
]=]
local function isPlaceholder(value: string?): boolean
	if not value then
		return true
	end
	return string.find(value, PLACEHOLDER_PREFIX, 1, true) ~= nil
end

--[=[
	Compares two Property records for sorting.

	@param a Property -- First property
	@param b Property -- Second property
	@return boolean -- True if a should come before b
]=]
local function compareProperties(a: Property, b: Property): boolean
	if a.class == b.class then
		return a.property < b.property
	end
	return a.class < b.class
end

local InterestingProperties = {}

--[=[
	Analyzes properties for asymmetric serialization and defaults.

	Two-pass processing: first identifies asymmetric serialization patterns,
	then finds NotCreatable classes with meaningful defaults.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function InterestingProperties.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing: Pass 1 - Build class metadata and find asymmetric properties

	local classMetadata: { [string]: ClassData } = {}
	local properties: { Property } = {}

	for _, class in api.Classes do
		local classTags = Lib.tags(class.Tags)
		classMetadata[class.Name] = {
			tags = classTags,
			props = {},
		}

		for _, member in class.Members do
			local isProperty = member.MemberType == MEMBER_TYPE_PROPERTY
			local hasSerializationInfo = member.Serialization ~= nil

			if not (isProperty and hasSerializationInfo) then
				continue
			end

			local memberTags = Lib.tags(member.Tags)
			local serialization = member.Serialization

			-- Store property metadata for pass 2
			classMetadata[class.Name].props[member.Name] = {
				default = member.Default,
				tags = memberTags,
			}

			-- Check for asymmetric serialization or deprecated saveable
			local canLoad = serialization.CanLoad
			local canSave = serialization.CanSave
			local isDeprecated = memberTags.Deprecated == true

			if not (canLoad or canSave) then
				continue
			end

			local reason: string? = nil
			if canLoad and not canSave then
				reason = "CanLoad only"
			elseif canSave and not canLoad then
				reason = "CanSave only"
			elseif isDeprecated and canSave then
				reason = "Deprecated but saveable"
			end

			if reason then
				local asymmetricProp: AsymmetricProperty = {
					type = "asymmetric",
					class = class.Name,
					property = member.Name,
					reason = reason,
					canSave = canSave,
					canLoad = canLoad,
					deprecated = if isDeprecated then true else nil,
				}
				table.insert(properties, asymmetricProp)
			end
		end
	end

	local asymmetricCount = #properties

	-- Processing: Pass 2 - Find NotCreatable defaults

	for className, classData in classMetadata do
		local isNotCreatable = classData.tags.NotCreatable == true

		if not isNotCreatable then
			continue
		end

		for propertyName, propertyData in classData.props do
			if not isPlaceholder(propertyData.default) then
				local defaultProp: NotCreatableDefault = {
					type = "notCreatableDefault",
					class = className,
					property = propertyName,
					default = propertyData.default :: string,
				}
				table.insert(properties, defaultProp)
			end
		end
	end

	-- Sorting

	table.sort(properties, compareProperties)

	-- Output

	local breakdown = {
		asymmetric = asymmetricCount,
		notCreatableDefault = #properties - asymmetricCount,
	}

	Lib.json("interesting-properties", Lib.output(hash, properties, breakdown))
	Lib.success(
		#properties,
		"interesting properties",
		`{breakdown.asymmetric} asymmetric, {breakdown.notCreatableDefault} NotCreatable defaults`
	)
end

Lib.runCli(InterestingProperties.run, Process.args)
