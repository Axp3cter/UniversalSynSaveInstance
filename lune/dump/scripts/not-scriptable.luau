--!strict

--[=[
	@class NotScriptableAnalyzer

	Analyzes NotScriptable properties with serialization support and proxy patterns.

	Detects three categories of interesting NotScriptable patterns:

	1. **NotScriptable + Serializable**:
	   - Properties hidden from scripts but present in save files
	   - Often internal engine state or editor-only properties
	   - May have PreferredDescriptorName for alternative script access

	2. **Serialization-Named Properties**:
	   - Properties with names suggesting serialization purposes
	   - Patterns: "xml", "internal", "serial", "replica"
	   - Tracked regardless of NotScriptable status

	3. **Proxy Properties**:
	   - Scriptable enum properties that proxy NotScriptable enum properties
	   - Enables script access to values stored in NotScriptable properties
	   - Detected by matching enum types between scriptable and NotScriptable properties

	These patterns reveal engine internals, legacy systems, and complex
	property access mechanisms that serialization frameworks must handle.

	Output: Array with type discriminator ("notScriptable", "serializationNamed",
	or "proxy"), sorted by class and property name.

	Usage:
	  lune run lune/dump/scripts/not-scriptable.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "not-scriptable"

-- Property name patterns suggesting serialization-related purposes
local SERIALIZATION_NAME_PATTERNS = {
	"xml",
	"internal",
	"serial",
	"replica",
}

-- Property member type identifier
local PROPERTY_MEMBER_TYPE = "Property"

-- Value type category for enum types
local ENUM_CATEGORY = "Enum"

-- ===== Type Definitions =====

--[=[
	@class NotScriptableProperty
	NotScriptable property that can be serialized.

	@field type "notScriptable" -- Discriminator for union type
	@field class string -- Class containing the property
	@field property string -- Property name
	@field valueType string -- Property value type name
	@field descriptor string? -- PreferredDescriptorName if available
]=]
type NotScriptableProperty = {
	type: "notScriptable",
	class: string,
	property: string,
	valueType: string,
	descriptor: string?,
}

--[=[
	@class SerializationNamedProperty
	Property with serialization-related naming pattern.

	@field type "serializationNamed" -- Discriminator for union type
	@field class string -- Class containing the property
	@field property string -- Property name
	@field scriptable boolean -- True if property is scriptable
	@field serializable boolean -- True if fully serializable (CanLoad and CanSave)
]=]
type SerializationNamedProperty = {
	type: "serializationNamed",
	class: string,
	property: string,
	scriptable: boolean,
	serializable: boolean,
}

--[=[
	@class ProxyProperty
	Detected proxy property pair for NotScriptable enum access.

	@field type "proxy" -- Discriminator for union type
	@field class string -- Class containing both properties
	@field real string -- NotScriptable enum property (real storage)
	@field proxy string -- Scriptable enum property (script access)
	@field enumType string -- Shared enum type name
]=]
type ProxyProperty = {
	type: "proxy",
	class: string,
	real: string,
	proxy: string,
	enumType: string,
}

--[=[
	@class Property
	Union type for all NotScriptable analysis categories.
]=]
type Property = NotScriptableProperty | SerializationNamedProperty | ProxyProperty

--[=[
	@class EnumTracker
	Tracks enum types from NotScriptable properties for proxy detection.

	Maps enum type name to the NotScriptable property name that uses it.
	Used in second pass to detect scriptable properties with matching enum types.

	@field [string] string -- Enum type name to property name
]=]
type EnumTracker = { [string]: string }

-- ===== Module Table =====

local NotScriptableAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if property name suggests serialization-related purpose.

	Lowercases the property name and checks for pattern matches to
	identify properties likely used for internal serialization.

	@param propertyName string -- Property name to check
	@return boolean -- True if name contains serialization pattern
]=]
local function hasSerializationNamePattern(propertyName: string): boolean
	local lowercaseName = string.lower(propertyName)

	for _, pattern in SERIALIZATION_NAME_PATTERNS do
		if string.find(lowercaseName, pattern) then
			return true
		end
	end

	return false
end

--[=[
	@private
	Checks if member should be processed for NotScriptable analysis.

	@param member Lib.Member -- Member to check
	@return boolean -- True if property with required metadata
]=]
local function shouldProcessMember(member: Lib.Member): boolean
	return member.MemberType == PROPERTY_MEMBER_TYPE
		and member.ValueType ~= nil
		and member.Serialization ~= nil
end

--[=[
	@private
	Processes NotScriptable serializable property.

	Extracts property information and tracks enum types for later
	proxy detection.

	@param className string -- Class containing the property
	@param member Lib.Member -- Member to process
	@param memberTags table -- Normalized member tags
	@param notScriptableProperties {NotScriptableProperty} -- Results list
	@param enumTracker EnumTracker -- Enum type tracker for proxy detection
	@side-effect Mutates notScriptableProperties and enumTracker
]=]
local function processNotScriptableProperty(
	className: string,
	member: Lib.Member,
	memberTags: { [string]: any },
	notScriptableProperties: { NotScriptableProperty },
	enumTracker: EnumTracker
)
	local valueType = member.ValueType :: Lib.ValueType

	-- Track enum types for proxy detection
	if valueType.Category == ENUM_CATEGORY then
		enumTracker[valueType.Name] = member.Name
	end

	local notScriptableProperty: NotScriptableProperty = {
		type = "notScriptable",
		class = className,
		property = member.Name,
		valueType = valueType.Name,
		descriptor = memberTags.PreferredDescriptorName,
	}

	table.insert(notScriptableProperties, notScriptableProperty)
end

--[=[
	@private
	Processes property with serialization-related name.

	Records properties with patterns suggesting internal serialization
	usage, regardless of NotScriptable status.

	@param className string -- Class containing the property
	@param member Lib.Member -- Member to process
	@param memberTags table -- Normalized member tags
	@param serialization Lib.Serialization -- Serialization flags
	@param serializationNamedProperties {SerializationNamedProperty} -- Results list
	@side-effect Mutates serializationNamedProperties
]=]
local function processSerializationNamedProperty(
	className: string,
	member: Lib.Member,
	memberTags: { [string]: any },
	serialization: Lib.Serialization,
	serializationNamedProperties: { SerializationNamedProperty }
)
	local serializationNamedProperty: SerializationNamedProperty = {
		type = "serializationNamed",
		class = className,
		property = member.Name,
		scriptable = not memberTags.NotScriptable,
		serializable = serialization.CanLoad and serialization.CanSave,
	}

	table.insert(serializationNamedProperties, serializationNamedProperty)
end

--[=[
	@private
	Detects proxy properties for NotScriptable enum access.

	Finds scriptable, serializable enum properties that share an enum type
	with a NotScriptable property. These act as script-accessible proxies
	for the hidden property's value.

	Only flags properties that are BOTH scriptable AND serializable to
	avoid false positives from other NotScriptable or non-serializable properties.

	@param class Lib.Class -- Class to check for proxies
	@param enumTracker EnumTracker -- Enum types from NotScriptable properties
	@param proxyProperties {ProxyProperty} -- Results list
	@side-effect Mutates proxyProperties
]=]
local function detectProxyProperties(
	class: Lib.Class,
	enumTracker: EnumTracker,
	proxyProperties: { ProxyProperty }
)
	-- Check each tracked enum type for proxy candidates
	for enumTypeName, realPropertyName in enumTracker do
		for _, member in class.Members do
			if not shouldProcessMember(member) then
				continue
			end

			-- Skip the real NotScriptable property itself
			if member.Name == realPropertyName then
				continue
			end

			local valueType = member.ValueType :: Lib.ValueType
			local serialization = member.Serialization :: Lib.Serialization

			-- Check if this property uses the same enum type
			if valueType.Category ~= ENUM_CATEGORY or valueType.Name ~= enumTypeName then
				continue
			end

			local memberTags = Lib.tags(member.Tags)

			-- Only flag scriptable, serializable properties as proxies
			-- This filters out other NotScriptable or non-serializable properties
			if not memberTags.NotScriptable and serialization.CanLoad and serialization.CanSave then
				local proxyProperty: ProxyProperty = {
					type = "proxy",
					class = class.Name,
					real = realPropertyName,
					proxy = member.Name,
					enumType = enumTypeName,
				}

				table.insert(proxyProperties, proxyProperty)
			end
		end
	end
end

--[=[
	@private
	Processes a single class for all NotScriptable analysis patterns.

	Three-stage analysis:
	1. Process all properties for NotScriptable + serializable
	2. Check all properties for serialization name patterns
	3. Detect proxy properties using enum tracker

	@param class Lib.Class -- Class to process
	@param notScriptableProperties {NotScriptableProperty} -- Results list
	@param serializationNamedProperties {SerializationNamedProperty} -- Results list
	@param proxyProperties {ProxyProperty} -- Results list
	@side-effect Mutates all three results lists
]=]
local function processClass(
	class: Lib.Class,
	notScriptableProperties: { NotScriptableProperty },
	serializationNamedProperties: { SerializationNamedProperty },
	proxyProperties: { ProxyProperty }
)
	-- Track enum types from NotScriptable properties for proxy detection
	local enumTracker: EnumTracker = {}

	for _, member in class.Members do
		if not shouldProcessMember(member) then
			continue
		end

		local tagsSuccess, memberTags = pcall(Lib.tags, member.Tags)
		if not tagsSuccess then
			Lib.warn(`Error processing tags for {class.Name}.{member.Name}: {memberTags}`)
			continue
		end

		local serialization = member.Serialization :: Lib.Serialization

		-- Check for NotScriptable + serializable
		if memberTags.NotScriptable and serialization.CanLoad and serialization.CanSave then
			processNotScriptableProperty(class.Name, member, memberTags, notScriptableProperties, enumTracker)
		end

		-- Check for serialization-related naming
		if hasSerializationNamePattern(member.Name) then
			processSerializationNamedProperty(
				class.Name,
				member,
				memberTags,
				serialization,
				serializationNamedProperties
			)
		end
	end

	-- Detect proxy properties after collecting enum types
	detectProxyProperties(class, enumTracker, proxyProperties)
end

--[=[
	@private
	Collects NotScriptable properties from API dump with error isolation.

	Traverses all classes, processing each for NotScriptable patterns.
	Individual errors are logged but don't abort analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return {NotScriptableProperty} -- NotScriptable serializable properties
	@return {SerializationNamedProperty} -- Serialization-named properties
	@return {ProxyProperty} -- Detected proxy properties
	@side-effect Logs warnings for processing errors
]=]
local function collectNotScriptableProperties(
	apiDump: Lib.ApiDump
): ({ NotScriptableProperty }, { SerializationNamedProperty }, { ProxyProperty })
	local notScriptableProperties: { NotScriptableProperty } = {}
	local serializationNamedProperties: { SerializationNamedProperty } = {}
	local proxyProperties: { ProxyProperty } = {}

	for _, class in apiDump.Classes do
		local processSuccess, errorMessage = pcall(
			processClass,
			class,
			notScriptableProperties,
			serializationNamedProperties,
			proxyProperties
		)

		if not processSuccess then
			Lib.warn(`Error processing class {class.Name}: {errorMessage}`)
		end
	end

	return notScriptableProperties, serializationNamedProperties, proxyProperties
end

--[=[
	@private
	Sorts properties by class name, then property name (or real property for proxies).

	@param a Property -- First property to compare
	@param b Property -- Second property to compare
	@return boolean -- True if a should sort before b
]=]
local function sortProperties(a: Property, b: Property): boolean
	if a.class == b.class then
		-- Use appropriate property name based on type
		local aPropertyName = if a.type == "proxy" then a.real else a.property
		local bPropertyName = if b.type == "proxy" then b.real else b.property

		return aPropertyName < bPropertyName
	end

	return a.class < b.class
end

--[=[
	@private
	Combines and sorts properties into unified output array.

	Merges all three property categories and sorts for deterministic output.

	@param notScriptableProperties {NotScriptableProperty} -- NotScriptable properties
	@param serializationNamedProperties {SerializationNamedProperty} -- Serialization-named properties
	@param proxyProperties {ProxyProperty} -- Proxy properties
	@return {Property} -- Combined sorted properties
]=]
local function buildUnifiedOutput(
	notScriptableProperties: { NotScriptableProperty },
	serializationNamedProperties: { SerializationNamedProperty },
	proxyProperties: { ProxyProperty }
): { Property }
	local combined: { Property } = {}

	-- Add all NotScriptable properties
	for _, property in notScriptableProperties do
		table.insert(combined, property)
	end

	-- Add all serialization-named properties
	for _, property in serializationNamedProperties do
		table.insert(combined, property)
	end

	-- Add all proxy properties
	for _, property in proxyProperties do
		table.insert(combined, property)
	end

	-- Sort for deterministic output
	table.sort(combined, sortProperties)

	return combined
end

--[=[
	@private
	Creates breakdown counts for output metadata.

	@param notScriptableCount number -- Count of NotScriptable properties
	@param serializationNamedCount number -- Count of serialization-named properties
	@param proxyCount number -- Count of proxy properties
	@return table -- Breakdown dictionary
]=]
local function createBreakdown(
	notScriptableCount: number,
	serializationNamedCount: number,
	proxyCount: number
): { [string]: number }
	return {
		notScriptable = notScriptableCount,
		serializationNamed = serializationNamedCount,
		proxy = proxyCount,
	}
end

-- ===== Public API =====

--[=[
	Runs NotScriptable analysis on Roblox API dump.

	Fetches API dump, identifies NotScriptable patterns and proxies,
	and generates JSON output with categorized property information.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function NotScriptableAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local notScriptableProperties, serializationNamedProperties, proxyProperties =
		collectNotScriptableProperties(apiDump)
	local combinedProperties = buildUnifiedOutput(notScriptableProperties, serializationNamedProperties, proxyProperties)

	local breakdown = createBreakdown(#notScriptableProperties, #serializationNamedProperties, #proxyProperties)
	local output = Lib.output(versionHash, combinedProperties, breakdown)

	Lib.json(OUTPUT_NAME, output)

	local secondaryInfo =
		`{#notScriptableProperties} NotScriptable, {#proxyProperties} proxies, {#serializationNamedProperties} serialization-named`
	Lib.success(#combinedProperties, "items", secondaryInfo)
end

-- ===== Entry Point =====

Lib.runCli(NotScriptableAnalyzer.run, Process.args)
