--!strict

local Process = require("@lune/process")
local Lib = require("../lib")

type PropertyInfo = {
	class: string,
	property: string,
	expected: string,
}

local ExpectedClassesAnalyzer = {}

function ExpectedClassesAnalyzer.run(hash: string?)
	local api = Lib.fetch(hash)
	local props = {}

	for _, class in api.Classes do
		for _, member in class.Members do
			if member.MemberType == "Property" and member.ValueType and member.Serialization then
				local vt = member.ValueType
				local ser = member.Serialization

				if ser.CanLoad and ser.CanSave and vt.Category == "Class" and vt.Name ~= "Instance" then
					table.insert(props, {
						class = class.Name,
						property = member.Name,
						expected = vt.Name,
					})
				end
			end
		end
	end

	table.sort(props, function(a, b)
		if a.class == b.class then
			return a.property < b.property
		end
		return a.class < b.class
	end)

	Lib.json("expected-classes", Lib.output(hash, props))
	Lib.success(#props, "class-typed properties")
end

Lib.runCli(ExpectedClassesAnalyzer.run, Process.args)
