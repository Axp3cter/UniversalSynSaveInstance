--!strict

--[=[
	@class InheritanceAnalyzer

	Identifies classes that exist outside the Instance inheritance hierarchy.

	Finds special engine types that do not inherit from Instance, including:
	- Abstract base types (e.g., <<<object>>>, ServiceProvider)
	- Low-level engine classes (e.g., DataModel, PackageLink)
	- Standalone utility classes (e.g., RBXScriptSignal, ContentProvider handles)

	These classes typically:
	- Cannot appear in serialized instance trees
	- Represent engine internals or abstract concepts
	- May be created automatically by the engine
	- Are not constructible via Instance.new()

	Output: Array of classes sorted by name with their optional superclass.

	Usage:
	  lune run lune/dump/scripts/inheritance.luau [version-hash]
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Lib = require("../lib")

-- ===== Constants =====

-- Output filename base (without extension)
local OUTPUT_NAME = "inheritance"

-- Base class for instance hierarchy
local INSTANCE_BASE_CLASS = "Instance"

-- ===== Type Definitions =====

--[=[
	@class ClassInfo
	Information about a non-Instance class.

	@field name string -- Class name
	@field superclass string? -- Parent class name (nil for root classes)
]=]
type ClassInfo = {
	name: string,
	superclass: string?,
}

-- ===== Module Table =====

local InheritanceAnalyzer = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if class inherits from Instance base class.

	Walks the inheritance chain to determine if the class eventually
	derives from Instance. Classes without inheritance from Instance
	are outside the standard object hierarchy.

	@param className string -- Class name to check
	@param classMap Lib.ClassMap -- Class lookup dictionary
	@return boolean -- True if inherits from Instance
]=]
local function inheritsFromInstance(className: string, classMap: Lib.ClassMap): boolean
	return Lib.inherits(className, INSTANCE_BASE_CLASS, classMap)
end

--[=[
	@private
	Sorts classes by name for deterministic output.

	@param a ClassInfo -- First class to compare
	@param b ClassInfo -- Second class to compare
	@return boolean -- True if a should sort before b
]=]
local function sortClasses(a: ClassInfo, b: ClassInfo): boolean
	return a.name < b.name
end

--[=[
	@private
	Collects non-Instance classes from API dump with error isolation.

	Traverses all classes, checking inheritance for each. Classes that
	don't inherit from Instance are included in the result. Individual
	errors are logged but don't abort the analysis.

	@param apiDump Lib.ApiDump -- API dump to analyze
	@return {ClassInfo} -- Non-Instance classes sorted by name
	@side-effect Logs warnings for processing errors
]=]
local function collectNonInstanceClasses(apiDump: Lib.ApiDump): { ClassInfo }
	local classMap = Lib.classes(apiDump.Classes)
	local nonInstanceClasses: { ClassInfo } = {}

	for _, class in apiDump.Classes do
		local checkSuccess, doesInheritFromInstance = pcall(inheritsFromInstance, class.Name, classMap)

		if not checkSuccess then
			Lib.warn(`Error checking inheritance for {class.Name}: {doesInheritFromInstance}`)
			continue
		end

		-- Include classes that don't inherit from Instance
		if not doesInheritFromInstance then
			local classInfo: ClassInfo = {
				name = class.Name,
				superclass = class.Superclass,
			}

			table.insert(nonInstanceClasses, classInfo)
		end
	end

	-- Sort for deterministic output
	table.sort(nonInstanceClasses, sortClasses)

	return nonInstanceClasses
end

-- ===== Public API =====

--[=[
	Runs inheritance analysis on Roblox API dump.

	Fetches API dump, identifies classes outside Instance hierarchy,
	and generates JSON output with non-Instance class information.

	@param versionHash string? -- Optional specific API dump version
	@error Throws if API fetch fails or analysis encounters fatal error
	@side-effect Writes JSON file to output directory, logs to stdout
]=]
function InheritanceAnalyzer.run(versionHash: string?)
	local apiDump = Lib.fetch(versionHash)
	local nonInstanceClasses = collectNonInstanceClasses(apiDump)

	local output = Lib.output(versionHash, nonInstanceClasses)
	Lib.json(OUTPUT_NAME, output)

	Lib.success(#nonInstanceClasses, "non-Instance classes")
end

-- ===== Entry Point =====

Lib.runCli(InheritanceAnalyzer.run, Process.args)
