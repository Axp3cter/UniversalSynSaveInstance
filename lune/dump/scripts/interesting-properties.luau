--!strict

--[=[
	@class InterestingPropertiesAnalyzer

	Identifies properties with unusual serialization behaviors requiring special handling.

	Detects three categories of interesting properties:

	1. **Asymmetric Serialization**:
	   - CanLoad only (no save): Properties restored from files but not persisted
	   - CanSave only (no load): Properties persisted but not restored
	   - Deprecated but saveable: Legacy properties still in serialization format

	2. **NotCreatable Defaults**:
	   - Properties on NotCreatable classes with non-placeholder default values
	   - Indicates values that appear in serialized data despite class restrictions

	These patterns reveal engine quirks, legacy behaviors, and special
	serialization logic that standard serialization frameworks must handle.

	Output: Array of properties with type discriminator ("asymmetric" or
	"notCreatableDefault"), sorted by class and property name.

	Usage:
	  lune run lune/dump/scripts/interesting-properties.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "interesting-properties"

-- Sentinel patterns indicating placeholder/unavailable default values
local PLACEHOLDER_PATTERNS = {
	"__api_dump_class_not_creatable__",
	"__api_dump_",
}

-- Property member type identifier
local PROPERTY_MEMBER_TYPE = "Property"

-- ===== Type Definitions =====

--[=[
	@class PropertyData
	Internal property serialization data during analysis.

	@field serialization Lib.Serialization -- Save/load capabilities
	@field tags table -- Normalized property tags
	@field default string? -- Default value (may be placeholder)
]=]
type PropertyData = {
	serialization: Lib.Serialization,
	tags: { [string]: any },
	default: string?,
}

--[=[
	@class ClassData
	Accumulated class-level data during analysis.

	@field tags table -- Normalized class tags
	@field properties table -- Dictionary of property name to PropertyData
]=]
type ClassData = {
	tags: { [string]: any },
	properties: { [string]: PropertyData },
}

--[=[
	@class AsymmetricProperty
	Property with asymmetric or unusual serialization.

	@field type "asymmetric" -- Discriminator for union type
	@field class string -- Class containing the property
	@field property string -- Property name
	@field reason string -- Human-readable explanation
	@field canSave boolean? -- Optional save capability flag
	@field canLoad boolean? -- Optional load capability flag
	@field deprecated boolean? -- Optional deprecation flag
]=]
type AsymmetricProperty = {
	type: "asymmetric",
	class: string,
	property: string,
	reason: string,
	canSave: boolean?,
	canLoad: boolean?,
	deprecated: boolean?,
}

--[=[
	@class NotCreatableDefault
	NotCreatable class property with non-placeholder default.

	@field type "notCreatableDefault" -- Discriminator for union type
	@field class string -- NotCreatable class containing the property
	@field property string -- Property name
	@field default string -- Non-placeholder default value
]=]
type NotCreatableDefault = {
	type: "notCreatableDefault",
	class: string,
	property: string,
	default: string,
}

--[=[
	@class Property
	Union type for all interesting property categories.
]=]
type Property = AsymmetricProperty | NotCreatableDefault

-- ===== Module Table =====

local InterestingPropertiesAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if default value is a placeholder sentinel.

	Placeholder patterns indicate the API dump couldn't determine a real
	default value (often for NotCreatable classes or engine-internal types).

	@param defaultValue string? -- Default value to check
	@return boolean -- True if value is nil or matches placeholder pattern
]=]
local function isPlaceholderDefault(defaultValue: string?): boolean
	if not defaultValue then
		return true
	end

	for _, pattern in PLACEHOLDER_PATTERNS do
		if string.find(defaultValue, pattern, 1, true) then
			return true
		end
	end

	return false
end

--[=[
	@private
	Initializes class data map with tags and empty property storage.

	Pre-processes all classes to build a lookup structure for later
	property analysis and default value checking.

	@param apiDump Lib.ApiDump -- API dump to process
	@return table -- Map of class name to ClassData
]=]
local function initializeClassDataMap(apiDump: Lib.ApiDump): { [string]: ClassData }
	local classDataMap: { [string]: ClassData } = {}

	for _, class in apiDump.Classes do
		local classData: ClassData = {
			tags = Lib.tags(class.Tags),
			properties = {},
		}

		classDataMap[class.Name] = classData
	end

	return classDataMap
end

--[=[
	@private
	Builds reason string for asymmetric serialization patterns.

	Returns a human-readable explanation of why the property is interesting,
	or nil if the property follows standard symmetric serialization.

	@param serialization Lib.Serialization -- Property serialization flags
	@param tags table -- Normalized property tags
	@return string? -- Reason if interesting, nil if standard
]=]
local function buildAsymmetricReason(serialization: Lib.Serialization, tags: { [string]: any }): string?
	if serialization.CanLoad and not serialization.CanSave then
		return "CanLoad only"
	elseif serialization.CanSave and not serialization.CanLoad then
		return "CanSave only"
	elseif tags.Deprecated and serialization.CanSave then
		return "Deprecated but saveable"
	end

	return nil
end

--[=[
	@private
	Checks if member should be processed for property analysis.

	@param member Lib.Member -- Member to check
	@return boolean -- True if member is a property with serialization info
]=]
local function shouldProcessMember(member: Lib.Member): boolean
	return member.MemberType == PROPERTY_MEMBER_TYPE and member.Serialization ~= nil
end

--[=[
	@private
	Processes member for asymmetric serialization detection.

	Stores property data for later default value checking and adds
	asymmetric properties to the results list.

	@param className string -- Class containing the member
	@param member Lib.Member -- Member to process
	@param classData ClassData -- Class data storage
	@param asymmetricProperties {AsymmetricProperty} -- Results list to append to
	@side-effect Mutates classData and asymmetricProperties
]=]
local function processMemberForAsymmetry(
	className: string,
	member: Lib.Member,
	classData: ClassData,
	asymmetricProperties: { AsymmetricProperty }
)
	if not shouldProcessMember(member) then
		return
	end

	local memberTags = Lib.tags(member.Tags)
	local serialization = member.Serialization :: Lib.Serialization

	-- Store property data for default value checking
	classData.properties[member.Name] = {
		serialization = serialization,
		tags = memberTags,
		default = member.Default,
	}

	-- Check for interesting serialization patterns
	if not serialization.CanLoad and not serialization.CanSave then
		-- Neither can load nor save - not interesting for serialization
		return
	end

	local reason = buildAsymmetricReason(serialization, memberTags)
	if not reason then
		return
	end

	local asymmetricProperty: AsymmetricProperty = {
		type = "asymmetric",
		class = className,
		property = member.Name,
		reason = reason,
		canSave = serialization.CanSave,
		canLoad = serialization.CanLoad,
		deprecated = if memberTags.Deprecated then true else nil,
	}

	table.insert(asymmetricProperties, asymmetricProperty)
end

--[=[
	@private
	Checks NotCreatable class for properties with non-placeholder defaults.

	NotCreatable classes shouldn't have instantiable defaults, but some
	properties have real default values that appear in serialized data.

	@param className string -- Class name to check
	@param classData ClassData -- Class data with property information
	@param notCreatableDefaults {NotCreatableDefault} -- Results list to append to
	@side-effect Mutates notCreatableDefaults
]=]
local function checkNotCreatableDefaults(
	className: string,
	classData: ClassData,
	notCreatableDefaults: { NotCreatableDefault }
)
	if not classData.tags.NotCreatable then
		return
	end

	for propertyName, propertyData in classData.properties do
		if not isPlaceholderDefault(propertyData.default) then
			local notCreatableDefault: NotCreatableDefault = {
				type = "notCreatableDefault",
				class = className,
				property = propertyName,
				default = propertyData.default :: string,
			}

			table.insert(notCreatableDefaults, notCreatableDefault)
		end
	end
end

--[=[
	@private
	Collects interesting properties from API dump with error isolation.

	Two-pass analysis:
	1. Process all members for asymmetric serialization
	2. Check NotCreatable classes for non-placeholder defaults

	Individual errors are logged but don't abort analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return {AsymmetricProperty} -- Asymmetric properties
	@return {NotCreatableDefault} -- NotCreatable defaults
	@side-effect Logs warnings for processing errors
]=]
local function collectInterestingProperties(
	apiDump: Lib.ApiDump
): ({ AsymmetricProperty }, { NotCreatableDefault })
	local classDataMap = initializeClassDataMap(apiDump)
	local asymmetricProperties: { AsymmetricProperty } = {}
	local notCreatableDefaults: { NotCreatableDefault } = {}

	-- First pass: process all members for asymmetric serialization
	for _, class in apiDump.Classes do
		local classData = classDataMap[class.Name]

		for _, member in class.Members do
			local processSuccess, errorMessage = pcall(
				processMemberForAsymmetry,
				class.Name,
				member,
				classData,
				asymmetricProperties
			)

			if not processSuccess then
				Lib.warn(`Error processing {class.Name}.{member.Name}: {errorMessage}`)
			end
		end
	end

	-- Second pass: check NotCreatable defaults
	for className, classData in classDataMap do
		checkNotCreatableDefaults(className, classData, notCreatableDefaults)
	end

	return asymmetricProperties, notCreatableDefaults
end

--[=[
	@private
	Sorts properties by class name, then property name.

	@param a Property -- First property to compare
	@param b Property -- Second property to compare
	@return boolean -- True if a should sort before b
]=]
local function sortProperties(a: Property, b: Property): boolean
	if a.class == b.class then
		return a.property < b.property
	end
	return a.class < b.class
end

--[=[
	@private
	Combines and sorts properties into unified output array.

	Merges asymmetric properties and NotCreatable defaults, then sorts
	for deterministic output.

	@param asymmetricProperties {AsymmetricProperty} -- Asymmetric properties
	@param notCreatableDefaults {NotCreatableDefault} -- NotCreatable defaults
	@return {Property} -- Combined sorted properties
]=]
local function buildUnifiedOutput(
	asymmetricProperties: { AsymmetricProperty },
	notCreatableDefaults: { NotCreatableDefault }
): { Property }
	local combined: { Property } = {}

	-- Add all asymmetric properties
	for _, property in asymmetricProperties do
		table.insert(combined, property)
	end

	-- Add all NotCreatable defaults
	for _, property in notCreatableDefaults do
		table.insert(combined, property)
	end

	-- Sort for deterministic output
	table.sort(combined, sortProperties)

	return combined
end

--[=[
	@private
	Creates breakdown counts for output metadata.

	@param asymmetricCount number -- Count of asymmetric properties
	@param notCreatableDefaultCount number -- Count of NotCreatable defaults
	@return table -- Breakdown dictionary
]=]
local function createBreakdown(asymmetricCount: number, notCreatableDefaultCount: number): { [string]: number }
	return {
		asymmetric = asymmetricCount,
		notCreatableDefault = notCreatableDefaultCount,
	}
end

-- ===== Public API =====

--[=[
	Runs interesting properties analysis on Roblox API dump.

	Fetches API dump, identifies properties with unusual serialization,
	and generates JSON output with categorized property information.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function InterestingPropertiesAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local asymmetricProperties, notCreatableDefaults = collectInterestingProperties(apiDump)
	local combinedProperties = buildUnifiedOutput(asymmetricProperties, notCreatableDefaults)

	local breakdown = createBreakdown(#asymmetricProperties, #notCreatableDefaults)
	local output = Lib.output(versionHash, combinedProperties, breakdown)

	Lib.json(OUTPUT_NAME, output)

	local secondaryInfo = `{#asymmetricProperties} asymmetric, {#notCreatableDefaults} NotCreatable defaults`
	Lib.success(#combinedProperties, "interesting properties", secondaryInfo)
end

-- ===== Entry Point =====

Lib.runCli(InterestingPropertiesAnalyzer.run, Process.args)
