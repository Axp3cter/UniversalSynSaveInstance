--!strict

--[=[
	@class NotCreatableAnalyzer

	Identifies classes marked NotCreatable that aren't services or common abstractions.

	NotCreatable classes cannot be instantiated via Instance.new() but may:
	- Be created automatically by the engine
	- Appear in serialized data from Studio or engine operations
	- Exist as singletons or system-managed instances

	Filters out common patterns to focus on interesting NotCreatable classes:
	- Services (marked with Service tag)
	- Base classes (names containing "Base")
	- Page classes (names containing "Page")
	- Plugin classes (names containing "Plugin")
	- Setting classes (names containing "Setting")

	Output: Array of classes sorted by name with service flag and tag list.

	Usage:
	  lune run lune/dump/scripts/not-creatable.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "not-creatable"

-- Class name patterns to exclude (common abstract/base patterns)
local EXCLUSION_PATTERNS = { "Base", "Page", "Plugin", "Setting" }

-- ===== Type Definitions =====

--[=[
	@class ClassInfo
	NotCreatable class information.

	@field name string -- Class name
	@field isService boolean -- True if class has Service tag
	@field tags {string} -- Sorted array of tag names
]=]
type ClassInfo = {
	name: string,
	isService: boolean,
	tags: { string },
}

-- ===== Module Table =====

local NotCreatableAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if class name matches any exclusion pattern.

	Filters out common abstract/base class naming conventions to focus
	on interesting NotCreatable classes.

	@param className string -- Class name to check
	@return boolean -- True if name contains exclusion pattern
]=]
local function matchesExclusionPattern(className: string): boolean
	for _, pattern in EXCLUSION_PATTERNS do
		if string.find(className, pattern) then
			return true
		end
	end

	return false
end

--[=[
	@private
	Checks if class should be included in output.

	Includes classes that are:
	- Marked NotCreatable
	- NOT marked Service
	- NOT matching exclusion patterns

	@param normalizedTags table -- Normalized tag dictionary
	@param className string -- Class name
	@return boolean -- True if should be included
]=]
local function shouldIncludeClass(normalizedTags: { [string]: any }, className: string): boolean
	return normalizedTags.NotCreatable
		and not normalizedTags.Service
		and not matchesExclusionPattern(className)
end

--[=[
	@private
	Extracts sorted array of tag names from normalized tag dictionary.

	Filters to boolean tags (value = true) and returns alphabetically
	sorted list for consistent output.

	@param normalizedTags table -- Normalized tag dictionary
	@return {string} -- Sorted array of tag names
]=]
local function extractTagNames(normalizedTags: { [string]: any }): { string }
	local tagNames: { string } = {}

	for tagName, tagValue in normalizedTags do
		if tagValue == true then
			table.insert(tagNames, tagName)
		end
	end

	table.sort(tagNames)

	return tagNames
end

--[=[
	@private
	Sorts classes alphabetically by name.

	@param a ClassInfo -- First class to compare
	@param b ClassInfo -- Second class to compare
	@return boolean -- True if a should sort before b
]=]
local function sortClasses(a: ClassInfo, b: ClassInfo): boolean
	return a.name < b.name
end

--[=[
	@private
	Collects NotCreatable classes from API dump with error isolation.

	Traverses all classes, filters based on tags and naming patterns,
	and builds structured output. Individual errors are logged but
	don't abort analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return {ClassInfo} -- NotCreatable classes sorted by name
	@side-effect Logs warnings for processing errors
]=]
local function collectNotCreatableClasses(apiDump: Lib.ApiDump): { ClassInfo }
	local notCreatableClasses: { ClassInfo } = {}

	for _, class in apiDump.Classes do
		local tagsSuccess, normalizedTags = pcall(Lib.tags, class.Tags)

		if not tagsSuccess then
			Lib.warn(`Error processing tags for {class.Name}: {normalizedTags}`)
			continue
		end

		if shouldIncludeClass(normalizedTags, class.Name) then
			local classInfo: ClassInfo = {
				name = class.Name,
				isService = normalizedTags.Service == true,
				tags = extractTagNames(normalizedTags),
			}

			table.insert(notCreatableClasses, classInfo)
		end
	end

	-- Sort for deterministic output
	table.sort(notCreatableClasses, sortClasses)

	return notCreatableClasses
end

-- ===== Public API =====

--[=[
	Runs NotCreatable analysis on Roblox API dump.

	Fetches API dump, identifies interesting NotCreatable classes,
	and generates JSON output with class information and tags.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function NotCreatableAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local notCreatableClasses = collectNotCreatableClasses(apiDump)

	local output = Lib.output(versionHash, notCreatableClasses)
	Lib.json(OUTPUT_NAME, output)

	Lib.success(#notCreatableClasses, "NotCreatable classes")
end

-- ===== Entry Point =====

Lib.runCli(NotCreatableAnalyzer.run, Process.args)
