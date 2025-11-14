--!strict

--[=[
	@class ExpectedClasses

	Identifies properties with specific class type expectations.

	Finds serializable properties typed to specific Instance subclasses
	(not generic Instance), indicating typed references that may require
	validation or special handling during serialization.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local MEMBER_TYPE_PROPERTY = "Property"
local CATEGORY_CLASS = "Class"
local BASE_INSTANCE_CLASS = "Instance"

-- Types

type PropertyInfo = {
	class: string,
	property: string,
	expected: string,
}

-- Helpers

--[=[
	Compares two PropertyInfo records for sorting.

	@param a PropertyInfo -- First property
	@param b PropertyInfo -- Second property
	@return boolean -- True if a should come before b
]=]
local function compareProperties(a: PropertyInfo, b: PropertyInfo): boolean
	if a.class == b.class then
		return a.property < b.property
	end
	return a.class < b.class
end

local ExpectedClasses = {}

--[=[
	Finds properties expecting specific class types.

	Identifies properties with specific Instance subclass requirements
	(not generic Instance), indicating typed references.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function ExpectedClasses.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing

	local properties: { PropertyInfo } = {}

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
			local isSerializable = serialization.CanLoad and serialization.CanSave
			local isClassType = valueType.Category == CATEGORY_CLASS
			local isSpecificClass = valueType.Name ~= BASE_INSTANCE_CLASS

			if isSerializable and isClassType and isSpecificClass then
				local propInfo: PropertyInfo = {
					class = class.Name,
					property = member.Name,
					expected = valueType.Name,
				}
				table.insert(properties, propInfo)
			end
		end
	end

	-- Sorting

	table.sort(properties, compareProperties)

	-- Output

	Lib.json("expected-classes", Lib.output(hash, properties))
	Lib.success(#properties, "class-typed properties")
end

Lib.runCli(ExpectedClasses.run, Process.args)
