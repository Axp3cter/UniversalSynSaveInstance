--!strict

--[=[
	@class NotScriptable

	Analyzes NotScriptable properties and proxy patterns.

	Identifies properties hidden from scripts but serializable, properties
	with serialization-related names (xml, internal, serial, replica),
	and proxy properties where scriptable enum properties mirror
	NotScriptable ones for backward compatibility.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local MEMBER_TYPE_PROPERTY = "Property"
local CATEGORY_ENUM = "Enum"
local SERIALIZATION_NAME_PATTERNS = { "xml", "internal", "serial", "replica" }

-- Types

type NotScriptableProperty = {
	type: "notScriptable",
	class: string,
	property: string,
	valueType: string,
	descriptor: string?,
}

type SerializationProperty = {
	type: "serializationNamed",
	class: string,
	property: string,
	scriptable: boolean,
	serializable: boolean,
}

type ProxyProperty = {
	type: "proxy",
	class: string,
	real: string,
	proxy: string,
	enumType: string,
}

type Property = NotScriptableProperty | SerializationProperty | ProxyProperty

type EnumTracker = { [string]: string }

-- Helpers

--[=[
	Checks if property name matches serialization patterns.

	@param name string -- Property name to check
	@return boolean -- True if matches any pattern
]=]
local function hasSerializationPattern(name: string): boolean
	local lowerName = string.lower(name)
	for _, pattern in SERIALIZATION_NAME_PATTERNS do
		if string.find(lowerName, pattern) then
			return true
		end
	end
	return false
end

--[=[
	Compares two Property records for sorting.

	Handles different property types, using appropriate field
	for comparison (property name or real name for proxies).

	@param a Property -- First property
	@param b Property -- Second property
	@return boolean -- True if a should come before b
]=]
local function compareProperties(a: Property, b: Property): boolean
	if a.class == b.class then
		local aName = if a.type == "proxy" then a.real else a.property
		local bName = if b.type == "proxy" then b.real else b.property
		return aName < bName
	end
	return a.class < b.class
end

local NotScriptable = {}

--[=[
	Analyzes NotScriptable and serialization-named properties.

	Three-pass processing per class:
	1. Find NotScriptable serializable properties and build enum tracker
	2. Find properties with serialization-related names
	3. Find scriptable enum proxies for NotScriptable enum properties

	@param hash string? -- Optional version hash (latest if nil)
]=]
function NotScriptable.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing

	local properties: { Property } = {}
	local notScriptableCount = 0
	local serializationNamedCount = 0

	for _, class in api.Classes do
		-- Per-class enum tracking for proxy detection
		local enumTracker: EnumTracker = {}

		-- Pass 1: NotScriptable properties
		for _, member in class.Members do
			local isProperty = member.MemberType == MEMBER_TYPE_PROPERTY
			local hasValueType = member.ValueType ~= nil
			local hasSerializationInfo = member.Serialization ~= nil

			if not (isProperty and hasValueType and hasSerializationInfo) then
				continue
			end

			local tags = Lib.tags(member.Tags)
			local valueType = member.ValueType
			local serialization = member.Serialization
			local isNotScriptable = tags.NotScriptable == true
			local isSerializable = serialization.CanLoad and serialization.CanSave

			if isNotScriptable and isSerializable then
				notScriptableCount += 1

				-- Track enum properties for proxy detection
				if valueType.Category == CATEGORY_ENUM then
					enumTracker[valueType.Name] = member.Name
				end

				local notScriptableProp: NotScriptableProperty = {
					type = "notScriptable",
					class = class.Name,
					property = member.Name,
					valueType = valueType.Name,
					descriptor = tags.PreferredDescriptorName,
				}
				table.insert(properties, notScriptableProp)
			end
		end

		-- Pass 2: Serialization-named properties
		for _, member in class.Members do
			local isProperty = member.MemberType == MEMBER_TYPE_PROPERTY
			local hasValueType = member.ValueType ~= nil
			local hasSerializationInfo = member.Serialization ~= nil

			if not (isProperty and hasValueType and hasSerializationInfo) then
				continue
			end

			if hasSerializationPattern(member.Name) then
				serializationNamedCount += 1

				local tags = Lib.tags(member.Tags)
				local serialization = member.Serialization

				local serializationProp: SerializationProperty = {
					type = "serializationNamed",
					class = class.Name,
					property = member.Name,
					scriptable = not tags.NotScriptable,
					serializable = serialization.CanLoad and serialization.CanSave,
				}
				table.insert(properties, serializationProp)
			end
		end

		-- Pass 3: Proxy properties
		for enumType, realPropertyName in enumTracker do
			for _, member in class.Members do
				local isProperty = member.MemberType == MEMBER_TYPE_PROPERTY
				local hasValueType = member.ValueType ~= nil
				local hasSerializationInfo = member.Serialization ~= nil
				local isDifferentProperty = member.Name ~= realPropertyName

				if not (isProperty and hasValueType and hasSerializationInfo and isDifferentProperty) then
					continue
				end

				local valueType = member.ValueType
				local matchesEnumType = valueType.Category == CATEGORY_ENUM and valueType.Name == enumType

				if not matchesEnumType then
					continue
				end

				local tags = Lib.tags(member.Tags)
				local serialization = member.Serialization
				local isScriptable = not tags.NotScriptable
				local isSerializable = serialization.CanLoad and serialization.CanSave

				if isScriptable and isSerializable then
					local proxyProp: ProxyProperty = {
						type = "proxy",
						class = class.Name,
						real = realPropertyName,
						proxy = member.Name,
						enumType = enumType,
					}
					table.insert(properties, proxyProp)
				end
			end
		end
	end

	-- Calculate proxy count from remaining properties
	local proxyCount = #properties - notScriptableCount - serializationNamedCount

	-- Sorting

	table.sort(properties, compareProperties)

	-- Output

	local breakdown = {
		notScriptable = notScriptableCount,
		serializationNamed = serializationNamedCount,
		proxy = proxyCount,
	}

	Lib.json("not-scriptable", Lib.output(hash, properties, breakdown))
	Lib.success(
		#properties,
		"items",
		`{notScriptableCount} NotScriptable, {proxyCount} proxies, {serializationNamedCount} serialization-named`
	)
end

Lib.runCli(NotScriptable.run, Process.args)
