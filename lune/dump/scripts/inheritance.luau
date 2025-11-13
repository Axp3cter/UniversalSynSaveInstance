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

type ClassInfo = {
	name: string,
	superclass: string?,
}

local Inheritance = {}

--[=[
	Finds classes not inheriting from Instance.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function Inheritance.run(hash: string?)
	local api = Lib.fetch(hash)
	local map = Lib.classes(api.Classes)
	local results = {}

	for _, class in api.Classes do
		if not Lib.inherits(class.Name, "Instance", map) then
			table.insert(results, {
				name = class.Name,
				superclass = class.Superclass,
			})
		end
	end

	table.sort(results, function(a, b)
		return a.name < b.name
	end)

	Lib.json("inheritance", Lib.output(hash, results))
	Lib.success(#results, "non-Instance classes")
end

Lib.runCli(Inheritance.run, Process.args)
