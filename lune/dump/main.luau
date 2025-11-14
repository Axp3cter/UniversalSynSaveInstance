--!strict

--[=[
	@class Main

	Orchestrates execution of all API dump analysis scripts.

	Discovery scans `lune/dump/scripts/` for .luau files and executes
	each dumper script sequentially with progress reporting and error
	handling. Generates formatted output with execution summary.
]=]

local fs = require("@lune/fs")
local Process = require("@lune/process")
local stdio = require("@lune/stdio")
local Lib = require("./lib")

local SCRIPTS_DIR = "lune/dump/scripts"
local SEPARATOR_WIDTH = 70
local SEPARATOR = string.rep("=", SEPARATOR_WIDTH)
local HEADER_FORMAT = "API Dump Analysis  •  %Y-%m-%d %H:%M:%S"

local Main = {}

-- Script discovery and validation

--[=[
	Discovers all .luau dumper scripts in scripts directory.

	@return table -- Array of script filenames
	@error Throws if directory read fails
]=]
local function discoverScripts(): { string }
	local ok, err = pcall(fs.readDir, SCRIPTS_DIR)
	if not ok then
		error(`Failed to read {SCRIPTS_DIR}: {err}`)
	end
	local entries = err

	local scripts = {}
	for _, entry in entries do
		if string.match(entry, "%.luau$") then
			table.insert(scripts, entry)
		end
	end

	table.sort(scripts)
	return scripts
end

-- Output formatting

--[=[
	Prints formatted header with separator lines.

	@param text string -- Header text to display
]=]
local function printHeader(text: string): ()
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("cyan"))
	print(`\n{SEPARATOR}\n{text}\n{SEPARATOR}\n`)
	stdio.write(stdio.style("reset"))
	stdio.write(stdio.color("reset"))
end

--[=[
	Prints progress indicator for current script.

	@param index number -- Current script index
	@param total number -- Total scripts count
	@param name string -- Script filename
]=]
local function printProgress(index: number, total: number, name: string): ()
	local scriptName = string.gsub(name, "%.luau$", "")
	stdio.write(stdio.style("bold"))
	print(`[{index}/{total}] {scriptName}`)
	stdio.write(stdio.style("reset"))
end

--[=[
	Prints execution summary with statistics.

	@param succeeded number -- Successful scripts count
	@param failed number -- Failed scripts count
	@param total number -- Total scripts count
	@param elapsed number -- Elapsed time in seconds
]=]
local function printSummary(succeeded: number, failed: number, total: number, elapsed: number): ()
	local color = if failed == 0 then "green" else "yellow"

	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("cyan"))
	print(`\n{SEPARATOR}\nSummary\n{SEPARATOR}`)
	stdio.write(stdio.style("reset"))

	stdio.write(stdio.color(color))
	print(`  Succeeded: {succeeded}/{total}`)
	stdio.write(stdio.color("reset"))

	if failed > 0 then
		stdio.write(stdio.color("red"))
		print(`  Failed: {failed}/{total}`)
		stdio.write(stdio.color("reset"))
	end

	stdio.write(stdio.color("blue"))
	print(`  Time: {string.format("%.2f", elapsed)}s`)
	stdio.write(stdio.color("reset"))
end

-- Script execution

--[=[
	Executes a dumper script with optional version hash.

	@param path string -- Full path to script file
	@param hash string? -- Optional version hash to pass
	@return boolean -- True if execution succeeded
]=]
local function executeScript(path: string, hash: string?): boolean
	local args = { "run", path }
	if hash then
		table.insert(args, hash)
	end

	local ok, result = pcall(Process.exec, "lune", args, { stdio = "inherit" })

	if not ok then
		stdio.write(stdio.color("red"))
		stdio.ewrite(`x Script execution failed: {result}\n`)
		stdio.write(stdio.color("reset"))
		return false
	end

	if not result.ok then
		stdio.write(stdio.color("red"))
		stdio.ewrite(`x Script {path} exited with code {result.code}\n`)
		stdio.write(stdio.color("reset"))
		return false
	end

	return true
end

-- Main runner

--[=[
	Runs all dumper scripts with formatted output.

	@param hash string? -- Optional version hash (latest if nil)
	@error Exits with code 1 if any script fails
]=]
function Main.run(hash: string?)
	local scripts = discoverScripts()

	if #scripts == 0 then
		stdio.write(stdio.color("yellow"))
		print("! No scripts found")
		stdio.write(stdio.color("reset"))
		Process.exit(1)
	end

	printHeader(os.date(HEADER_FORMAT))

	if hash then
		stdio.write(stdio.color("blue"))
		print(`i Version: {hash}\n`)
		stdio.write(stdio.color("reset"))
	end

	local succeeded = 0
	local failed = 0
	local startTime = os.clock()

	for i, script in scripts do
		printProgress(i, #scripts, script)

		if executeScript(`{SCRIPTS_DIR}/{script}`, hash) then
			succeeded += 1
		else
			failed += 1
		end

		print("")
	end

	local elapsed = os.clock() - startTime
	printSummary(succeeded, failed, #scripts, elapsed)

	if failed > 0 then
		Process.exit(1)
	end
end

Lib.runCli(Main.run, Process.args)
