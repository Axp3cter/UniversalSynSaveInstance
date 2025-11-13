--!strict

--[=[
	@class Inheritance

	Identifies classes outside the Instance hierarchy.

	Finds classes not inheriting from Instance, representing standalone
	types like Enums, RaycastParams, or other non-Instance objects that
	require different serialization strategies.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local BASE_INSTANCE_CLASS = "Instance"

-- Types

type ClassInfo = {
	name: string,
	superclass: string?,
}

-- Helpers

--[=[
	Compares two ClassInfo records for sorting.

	@param a ClassInfo -- First class
	@param b ClassInfo -- Second class
	@return boolean -- True if a should come before b
]=]
local function compareClasses(a: ClassInfo, b: ClassInfo): boolean
	return a.name < b.name
end

local Inheritance = {}

--[=[
	Finds classes not inheriting from Instance.

	Identifies standalone types like Enums, RaycastParams that
	require different serialization strategies.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function Inheritance.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing

	local classMap = Lib.classes(api.Classes)
	local nonInstanceClasses: { ClassInfo } = {}

	for _, class in api.Classes do
		local inheritsFromInstance = Lib.inherits(class.Name, BASE_INSTANCE_CLASS, classMap)

		if not inheritsFromInstance then
			local classInfo: ClassInfo = {
				name = class.Name,
				superclass = class.Superclass,
			}
			table.insert(nonInstanceClasses, classInfo)
		end
	end

	-- Sorting

	table.sort(nonInstanceClasses, compareClasses)

	-- Output

	Lib.json("inheritance", Lib.output(hash, nonInstanceClasses))
	Lib.success(#nonInstanceClasses, "non-Instance classes")
end

Lib.runCli(Inheritance.run, Process.args)
