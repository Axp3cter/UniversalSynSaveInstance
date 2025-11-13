--!strict

local Process = require("@lune/process")
local Lib = require("../lib")

type TypeInfo = {
	name: string,
	canSave: boolean,
	canLoad: boolean,
	hasDescriptor: boolean,
}

local DatatypesAnalyzer = {}

function DatatypesAnalyzer.run(hash: string?)
	local api = Lib.fetch(hash)

	local types = {}
	local seen = {}
	local saveFlags = {}
	local loadFlags = {}

	for _, class in api.Classes do
		for _, member in class.Members do
			if member.MemberType == "Property" and member.ValueType and member.Serialization then
				local vt = member.ValueType

				if vt.Category ~= "Enum" and vt.Category ~= "Class" then
					local name = vt.Name

					if not seen[name] then
						seen[name] = true
						table.insert(types, name)
					end

					local ser = member.Serialization
					if ser.CanSave then
						saveFlags[name] = true
					elseif saveFlags[name] == nil then
						saveFlags[name] = false
					end

					if ser.CanLoad then
						loadFlags[name] = true
					elseif loadFlags[name] == nil then
						loadFlags[name] = false
					end
				end
			end
		end
	end

	table.sort(types)

	local results = table.create(#types)
	for _, name in types do
		local canSave = saveFlags[name] == true
		local canLoad = loadFlags[name] == true

		table.insert(results, {
			name = name,
			canSave = canSave,
			canLoad = canLoad,
			hasDescriptor = canSave ~= canLoad,
		})
	end

	Lib.json("datatypes", Lib.output(hash, results))
	Lib.success(#results, "data types")
end

Lib.runCli(DatatypesAnalyzer.run, Process.args)
