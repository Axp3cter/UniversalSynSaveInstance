--!strict

--[=[
	@class Datatypes

	Analyzes data type serialization capabilities from API dump.

	Identifies primitive and data types with their save/load capabilities,
	flagging asymmetric serialization where descriptors may be needed.
	Excludes Enum and Class categories to focus on value types.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local MEMBER_TYPE_PROPERTY = "Property"
local CATEGORY_ENUM = "Enum"
local CATEGORY_CLASS = "Class"

-- Types

type TypeInfo = {
	name: string,
	canSave: boolean,
	canLoad: boolean,
	hasDescriptor: boolean,
}

local Datatypes = {}

--[=[
	Analyzes all data types and their serialization flags.

	Processes all properties to identify non-Enum, non-Class types and tracks
	their serialization capabilities. Uses separate tracking for save/load flags
	since properties may have partial serialization support.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function Datatypes.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing

	local types: { string } = {}
	local seen: { [string]: boolean } = {}
	local saveFlags: { [string]: boolean } = {}
	local loadFlags: { [string]: boolean } = {}

	for _, class in api.Classes do
		for _, member in class.Members do
			local isProperty = member.MemberType == MEMBER_TYPE_PROPERTY
			local hasValueType = member.ValueType ~= nil
			local hasSerializationInfo = member.Serialization ~= nil

			if not (isProperty and hasValueType and hasSerializationInfo) then
				continue
			end

			local valueType = member.ValueType
			local serialization = member.Serialization
			local isEnumOrClass = valueType.Category == CATEGORY_ENUM or valueType.Category == CATEGORY_CLASS

			if isEnumOrClass then
				continue
			end

			local typeName = valueType.Name

			if not seen[typeName] then
				seen[typeName] = true
				table.insert(types, typeName)
			end

			if serialization.CanSave then
				saveFlags[typeName] = true
			elseif saveFlags[typeName] == nil then
				saveFlags[typeName] = false
			end

			if serialization.CanLoad then
				loadFlags[typeName] = true
			elseif loadFlags[typeName] == nil then
				loadFlags[typeName] = false
			end
		end
	end

	-- Sorting

	table.sort(types)

	-- Output

	local results: { TypeInfo } = table.create(#types)
	for _, typeName in types do
		local canSave = saveFlags[typeName] == true
		local canLoad = loadFlags[typeName] == true
		-- Asymmetric serialization requires descriptors for proper round-tripping
		local requiresDescriptor = canSave ~= canLoad

		local typeInfo: TypeInfo = {
			name = typeName,
			canSave = canSave,
			canLoad = canLoad,
			hasDescriptor = requiresDescriptor,
		}
		table.insert(results, typeInfo)
	end

	Lib.json("datatypes", Lib.output(hash, results))
	Lib.success(#results, "data types")
end

Lib.runCli(Datatypes.run, Process.args)
