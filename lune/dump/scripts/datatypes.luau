--!strict

--[=[
	@class DatatypesAnalyzer

	Analyzes data type serialization capabilities from Roblox API dumps.

	Identifies types with custom serialization descriptors by detecting
	asymmetric save/load capabilities. Types requiring descriptors have:
	- CanSave = true, CanLoad = false (save-only serialization)
	- CanSave = false, CanLoad = true (load-only serialization)

	Excludes Enum and Class categories as they don't represent serializable
	data types in the traditional sense (enums are primitives, classes are
	references).

	Output: Array of data types sorted alphabetically with serialization
	flags and descriptor requirement indicator.

	Usage:
	  lune run lune/dump/scripts/datatypes.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "datatypes"

-- Categories to exclude from data type analysis
local EXCLUDED_CATEGORIES = {
	Enum = true,
	Class = true,
}

-- ===== Type Definitions =====

--[=[
	@class SerializationCapabilities
	Tracks which types can be saved and/or loaded.

	Dictionary mapping type names to boolean flags. A type's entry is set
	to true if ANY property of that type has the capability enabled.

	@field [string] boolean -- Type name to capability flag
]=]
type SerializationCapabilities = { [string]: boolean }

--[=[
	@class TypeInfo
	Complete serialization information for a single data type.

	@field name string -- Data type name (e.g., "Vector3", "CFrame")
	@field canSave boolean -- At least one property of this type can save
	@field canLoad boolean -- At least one property of this type can load
	@field hasDescriptor boolean -- Asymmetric serialization (needs custom descriptor)
]=]
type TypeInfo = {
	name: string,
	canSave: boolean,
	canLoad: boolean,
	hasDescriptor: boolean,
}

--[=[
	@class TypeCollection
	Accumulated type analysis data during API dump traversal.

	@field typeNames {string} -- Ordered list of discovered type names
	@field seenTypes table -- Set of already-discovered types for deduplication
	@field saveCapabilities SerializationCapabilities -- Types that can be saved
	@field loadCapabilities SerializationCapabilities -- Types that can be loaded
]=]
type TypeCollection = {
	typeNames: { string },
	seenTypes: { [string]: true },
	saveCapabilities: SerializationCapabilities,
	loadCapabilities: SerializationCapabilities,
}

-- ===== Module Table =====

local DatatypesAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if value type category should be excluded from analysis.

	Enums are excluded because they serialize as integers, not descriptors.
	Classes are excluded because they serialize as references, not values.

	@param category string -- ValueType category
	@return boolean -- True if category should be excluded
]=]
local function shouldExcludeCategory(category: string): boolean
	return EXCLUDED_CATEGORIES[category] == true
end

--[=[
	@private
	Initializes empty type collection for accumulating analysis results.

	@return TypeCollection -- New type collection with empty state
]=]
local function createTypeCollection(): TypeCollection
	return {
		typeNames = {},
		seenTypes = {},
		saveCapabilities = {},
		loadCapabilities = {},
	}
end

--[=[
	@private
	Records serialization capability for a type.

	Updates capability maps to track whether the type can be saved/loaded.
	If a type has ANY property that can save, the type is marked saveable.
	Same logic applies to loading.

	@param typeName string -- Data type name
	@param serialization Lib.Serialization -- Property serialization flags
	@param collection TypeCollection -- Type collection to update
	@side-effect Mutates collection's capability maps
]=]
local function recordSerializationCapability(
	typeName: string,
	serialization: Lib.Serialization,
	collection: TypeCollection
)
	-- Mark type as saveable if this property can save
	if serialization.CanSave then
		collection.saveCapabilities[typeName] = true
	elseif collection.saveCapabilities[typeName] == nil then
		-- Initialize to false if not yet seen
		collection.saveCapabilities[typeName] = false
	end

	-- Mark type as loadable if this property can load
	if serialization.CanLoad then
		collection.loadCapabilities[typeName] = true
	elseif collection.loadCapabilities[typeName] == nil then
		-- Initialize to false if not yet seen
		collection.loadCapabilities[typeName] = false
	end
end

--[=[
	@private
	Records type name for ordered output.

	Deduplicates type names using seenTypes set. Only adds types that
	haven't been encountered before.

	@param typeName string -- Data type name
	@param collection TypeCollection -- Type collection to update
	@side-effect Mutates collection's typeNames and seenTypes
]=]
local function recordTypeName(typeName: string, collection: TypeCollection)
	if collection.seenTypes[typeName] then
		return
	end

	collection.seenTypes[typeName] = true
	table.insert(collection.typeNames, typeName)
end

--[=[
	@private
	Checks if member should be processed for type analysis.

	Only processes properties that have both ValueType and Serialization
	metadata. Skips methods, events, and properties without serialization info.

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
	Processes a single member to extract type serialization information.

	Filters out excluded categories, records serialization capabilities,
	and tracks unique type names for final output.

	@param member Lib.Member -- Member to process
	@param collection TypeCollection -- Type collection to update
	@side-effect Mutates collection with discovered type data
]=]
local function processMember(member: Lib.Member, collection: TypeCollection)
	if not shouldProcessMember(member) then
		return
	end

	local valueType = member.ValueType :: Lib.ValueType
	local serialization = member.Serialization :: Lib.Serialization

	-- Skip excluded categories
	if shouldExcludeCategory(valueType.Category) then
		return
	end

	local typeName = valueType.Name

	recordSerializationCapability(typeName, serialization, collection)
	recordTypeName(typeName, collection)
end

--[=[
	@private
	Collects all data types from API dump with error isolation.

	Traverses all classes and members, processing each property to extract
	type serialization information. Individual member errors are logged but
	don't abort the analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return TypeCollection -- Collected type data
	@side-effect Logs warnings for processing errors
]=]
local function collectDataTypes(apiDump: Lib.ApiDump): TypeCollection
	local collection = createTypeCollection()

	for _, class in apiDump.Classes do
		for _, member in class.Members do
			local processSuccess, errorMessage = pcall(processMember, member, collection)

			if not processSuccess then
				Lib.warn(`Error processing {class.Name}.{member.Name}: {errorMessage}`)
			end
		end
	end

	return collection
end

--[=[
	@private
	Checks if type has asymmetric serialization requiring a descriptor.

	Asymmetric serialization occurs when save and load capabilities differ.
	This indicates the type needs custom logic to convert between memory
	representation and serialized format.

	@param canSave boolean -- Type can be saved
	@param canLoad boolean -- Type can be loaded
	@return boolean -- True if capabilities are asymmetric
]=]
local function hasAsymmetricSerialization(canSave: boolean, canLoad: boolean): boolean
	return canSave ~= canLoad
end

--[=[
	@private
	Builds structured type info from collected capabilities.

	Sorts types alphabetically for deterministic output and creates
	TypeInfo objects with all serialization metadata.

	@param collection TypeCollection -- Collected type data
	@return {TypeInfo} -- Array of type info objects sorted by name
]=]
local function buildTypeInfoList(collection: TypeCollection): { TypeInfo }
	-- Sort type names for deterministic output
	table.sort(collection.typeNames)

	local typeInfoList: { TypeInfo } = {}

	for _, typeName in collection.typeNames do
		local canSave = collection.saveCapabilities[typeName] == true
		local canLoad = collection.loadCapabilities[typeName] == true

		local typeInfo: TypeInfo = {
			name = typeName,
			canSave = canSave,
			canLoad = canLoad,
			hasDescriptor = hasAsymmetricSerialization(canSave, canLoad),
		}

		table.insert(typeInfoList, typeInfo)
	end

	return typeInfoList
end

-- ===== Public API =====

--[=[
	Runs datatype analysis on Roblox API dump.

	Fetches API dump, analyzes all property types, and generates JSON output
	with serialization capabilities for each data type.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function DatatypesAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local collection = collectDataTypes(apiDump)
	local typeInfoList = buildTypeInfoList(collection)

	local output = Lib.output(versionHash, typeInfoList)
	Lib.json(OUTPUT_NAME, output)

	Lib.success(#typeInfoList, "data types")
end

-- ===== Entry Point =====

Lib.runCli(DatatypesAnalyzer.run, Process.args)
