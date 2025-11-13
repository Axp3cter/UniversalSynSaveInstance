--!strict

local Process = require("@lune/process")
local Lib = require("../lib")

type ClassInfo = {
	name: string,
	superclass: string?,
}

local InheritanceAnalyzer = {}

function InheritanceAnalyzer.run(hash: string?)
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

Lib.runCli(InheritanceAnalyzer.run, Process.args)
