--!strict

--[=[
	@class ExpectedClassesAnalyzer

	Identifies properties that expect specific class types during serialization.

	Finds serializable properties with:
	- ValueType.Category == "Class"
	- ValueType.Name != "Instance" (more specific than base Instance)
	- CanLoad = true AND CanSave = true (fully serializable)

	These properties enforce type constraints during deserialization. For example,
	a property expecting "Model" will validate that the deserialized instance
	inherits from Model, not just any Instance.

	Output: Array of properties sorted by class name, then property name, with
	the expected class type for each property.

	Usage:
	  lune run lune/dump/scripts/expected-classes.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "expected-classes"

-- Value type category for class references
local CLASS_CATEGORY = "Class"

-- Base instance type name (not considered "specific")
local BASE_INSTANCE_TYPE = "Instance"

-- ===== Type Definitions =====

--[=[
	@class PropertyInfo
	Property that expects a specific class type.

	@field class string -- Class containing the property
	@field property string -- Property name
	@field expected string -- Expected class type (e.g., "Model", "Part")
]=]
type PropertyInfo = {
	class: string,
	property: string,
	expected: string,
}

-- ===== Module Table =====

local ExpectedClassesAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if property expects a specific class type.

	Properties expecting "Instance" are excluded because they accept any
	instance without type validation. Only properties requiring more
	specific types are included.

	@param valueType Lib.ValueType -- Property value type
	@param serialization Lib.Serialization -- Property serialization flags
	@return boolean -- True if expects specific class
]=]
local function expectsSpecificClassType(valueType: Lib.ValueType, serialization: Lib.Serialization): boolean
	return serialization.CanLoad
		and serialization.CanSave
		and valueType.Category == CLASS_CATEGORY
		and valueType.Name ~= BASE_INSTANCE_TYPE
end

--[=[
	@private
	Checks if member should be processed for class type analysis.

	Only processes properties that have both ValueType and Serialization
	metadata. Skips methods, events, and properties without type information.

	@param member Lib.Member -- Class member to check
	@return boolean -- True if member should be processed
]=]
local function shouldProcessMember(member: Lib.Member): boolean
	return member.MemberType == "Property"
		and member.ValueType ~= nil
		and member.Serialization ~= nil
end

--[=[
	@private
	Processes member for class type expectations.

	Extracts property information if the member expects a specific class
	type during serialization.

	@param className string -- Class containing the member
	@param member Lib.Member -- Member to process
	@param properties {PropertyInfo} -- Properties list to append to
	@side-effect Mutates properties list by appending new entries
]=]
local function processMember(className: string, member: Lib.Member, properties: { PropertyInfo })
	if not shouldProcessMember(member) then
		return
	end

	local valueType = member.ValueType :: Lib.ValueType
	local serialization = member.Serialization :: Lib.Serialization

	if not expectsSpecificClassType(valueType, serialization) then
		return
	end

	local propertyInfo: PropertyInfo = {
		class = className,
		property = member.Name,
		expected = valueType.Name,
	}

	table.insert(properties, propertyInfo)
end

--[=[
	@private
	Sorts properties by class name, then property name.

	Provides deterministic ordering for stable output and easy diffing.

	@param a PropertyInfo -- First property to compare
	@param b PropertyInfo -- Second property to compare
	@return boolean -- True if a should sort before b
]=]
local function sortProperties(a: PropertyInfo, b: PropertyInfo): boolean
	if a.class == b.class then
		return a.property < b.property
	end
	return a.class < b.class
end

--[=[
	@private
	Collects class-typed properties from API dump with error isolation.

	Traverses all classes and members, processing each property to find
	those expecting specific class types. Individual member errors are
	logged but don't abort the analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return {PropertyInfo} -- Properties sorted by class and property name
	@side-effect Logs warnings for processing errors
]=]
local function collectClassTypedProperties(apiDump: Lib.ApiDump): { PropertyInfo }
	local properties: { PropertyInfo } = {}

	for _, class in apiDump.Classes do
		for _, member in class.Members do
			local processSuccess, errorMessage = pcall(processMember, class.Name, member, properties)

			if not processSuccess then
				Lib.warn(`Error processing {class.Name}.{member.Name}: {errorMessage}`)
			end
		end
	end

	-- Sort for deterministic output
	table.sort(properties, sortProperties)

	return properties
end

-- ===== Public API =====

--[=[
	Runs expected classes analysis on Roblox API dump.

	Fetches API dump, identifies properties expecting specific class types,
	and generates JSON output with class-typed property information.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function ExpectedClassesAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local properties = collectClassTypedProperties(apiDump)

	local output = Lib.output(versionHash, properties)
	Lib.json(OUTPUT_NAME, output)

	Lib.success(#properties, "class-typed properties")
end

-- ===== Entry Point =====

Lib.runCli(ExpectedClassesAnalyzer.run, Process.args)
