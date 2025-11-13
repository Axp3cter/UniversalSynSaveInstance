--!strict

local Process = require("@lune/process")
local Lib = require("../lib")

type ClassInfo = {
	name: string,
	isService: boolean,
	tags: { string },
}

local NotCreatableAnalyzer = {}

local EXCLUDE_PATTERNS = { "Base", "Page", "Plugin", "Setting" }

local function matchesPattern(name: string): boolean
	for _, pattern in EXCLUDE_PATTERNS do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

function NotCreatableAnalyzer.run(hash: string?)
	local api = Lib.fetch(hash)
	local results = {}

	for _, class in api.Classes do
		local tags = Lib.tags(class.Tags)

		if tags.NotCreatable and not tags.Service and not matchesPattern(class.Name) then
			local tagList = {}
			for tag, val in tags do
				if val == true then
					table.insert(tagList, tag)
				end
			end
			table.sort(tagList)

			table.insert(results, {
				name = class.Name,
				isService = tags.Service == true,
				tags = tagList,
			})
		end
	end

	table.sort(results, function(a, b)
		return a.name < b.name
	end)

	Lib.json("not-creatable", Lib.output(hash, results))
	Lib.success(#results, "NotCreatable classes")
end

Lib.runCli(NotCreatableAnalyzer.run, Process.args)
