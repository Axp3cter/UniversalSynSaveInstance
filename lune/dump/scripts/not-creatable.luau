--!strict

--[=[
	@class NotCreatable

	Identifies NotCreatable classes excluding common patterns.

	Finds classes marked NotCreatable that aren't Services or common
	base types (Base, Page, Plugin, Setting), representing classes
	only obtainable through engine APIs or special constructors.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

-- Constants

local EXCLUDE_PATTERNS = { "Base", "Page", "Plugin", "Setting" }

-- Types

type ClassInfo = {
	name: string,
	isService: boolean,
	tags: { string },
}

-- Helpers

--[=[
	Checks if class name matches any exclusion pattern.

	@param name string -- Class name to check
	@return boolean -- True if matches any pattern
]=]
local function matchesPattern(name: string): boolean
	for _, pattern in EXCLUDE_PATTERNS do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

--[=[
	Extracts boolean tag names from tag dictionary.

	Filters tags to only include those with value `true`,
	returning sorted array of tag names.

	@param tags table -- Tag dictionary
	@return table -- Sorted array of tag names
]=]
local function extractTagNames(tags: { [string]: any }): { string }
	local tagNames: { string } = {}

	for tagName, tagValue in tags do
		if tagValue == true then
			table.insert(tagNames, tagName)
		end
	end

	table.sort(tagNames)
	return tagNames
end

--[=[
	Compares two ClassInfo records for sorting.

	@param a ClassInfo -- First class
	@param b ClassInfo -- Second class
	@return boolean -- True if a should come before b
]=]
local function compareClasses(a: ClassInfo, b: ClassInfo): boolean
	return a.name < b.name
end

local NotCreatable = {}

--[=[
	Finds NotCreatable classes excluding common patterns.

	Filters to non-Service classes that don't match base type patterns,
	representing classes only obtainable through engine APIs.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function NotCreatable.run(hash: string?): ()
	local api = Lib.fetch(hash)

	-- Processing

	local classes: { ClassInfo } = {}

	for _, class in api.Classes do
		local tags = Lib.tags(class.Tags)
		local isNotCreatable = tags.NotCreatable == true
		local isService = tags.Service == true
		local matchesExclusion = matchesPattern(class.Name)

		if not (isNotCreatable and not isService and not matchesExclusion) then
			continue
		end

		local tagNames = extractTagNames(tags)
		local classInfo: ClassInfo = {
			name = class.Name,
			isService = isService,
			tags = tagNames,
		}
		table.insert(classes, classInfo)
	end

	-- Sorting

	table.sort(classes, compareClasses)

	-- Output

	Lib.json("not-creatable", Lib.output(hash, classes))
	Lib.success(#classes, "NotCreatable classes")
end

Lib.runCli(NotCreatable.run, Process.args)
