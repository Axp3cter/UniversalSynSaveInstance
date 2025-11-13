--!strict

--[=[
	@class Runner

	Orchestrates execution of all API dump analysis scripts.

	Provides automated batch processing of dumper scripts with:
	- Automatic script discovery in scripts/ directory
	- Sequential execution with progress tracking
	- Individual script error isolation (failures don't abort batch)
	- Comprehensive execution summary with timing statistics
	- Consistent CLI entrypoint with version hash support

	Usage:
	  lune run lune/dump/main.luau [version-hash]

	Exit codes:
	  0 - All dumpers succeeded
	  1 - One or more dumpers failed or no scripts found

	The runner discovers all .luau files in lune/dump/scripts/ and executes
	them in sorted order, passing the optional version hash to each script.
]=]

-- ===== Imports =====

local fs = require("@lune/fs")
local Process = require("@lune/process")
local stdio = require("@lune/stdio")
local Lib = require("./lib")

-- ===== Constants =====

-- Directory containing dumper scripts to execute
local SCRIPTS_DIRECTORY = "lune/dump/scripts"

-- File extension filter for script discovery
local SCRIPT_EXTENSION = ".luau"

-- Visual separator width for headers and summaries
local SEPARATOR_WIDTH = 70

-- Timestamp format for execution header
local TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S"

-- ===== Type Definitions =====

--[=[
	@class ExecutionResult
	Tracks success and failure counts across all dumper executions.

	@field succeeded number -- Count of scripts that completed successfully
	@field failed number -- Count of scripts that failed or exited non-zero
]=]
type ExecutionResult = {
	succeeded: number,
	failed: number,
}

--[=[
	@class ScriptExecution
	Configuration for executing a single dumper script.

	@field scriptPath string -- Absolute path to script file
	@field versionHash string? -- Optional API dump version hash to pass
]=]
type ScriptExecution = {
	scriptPath: string,
	versionHash: string?,
}

-- ===== Module Table =====

local Runner = {}

-- ===== Private Helpers =====

--[=[
	@private
	Checks if filename has the script extension.

	@param filename string -- Filename to check
	@return boolean -- True if filename ends with SCRIPT_EXTENSION
]=]
local function isScriptFile(filename: string): boolean
	return string.match(filename, `{SCRIPT_EXTENSION}$`) ~= nil
end

--[=[
	@private
	Removes file extension from filename.

	@param filename string -- Filename with extension
	@return string -- Filename without extension
]=]
local function removeExtension(filename: string): string
	return string.gsub(filename, `{SCRIPT_EXTENSION}$`, "")
end

--[=[
	@private
	Discovers dumper scripts in the scripts directory.

	Filters for .luau files and returns them in sorted order for
	deterministic execution sequence.

	@return {string} -- Sorted array of script filenames
	@error Throws if directory read fails
]=]
local function discoverScripts(): { string }
	local readSuccess, directoryEntries = pcall(fs.readDir, SCRIPTS_DIRECTORY)

	if not readSuccess then
		error(`Failed to read scripts directory {SCRIPTS_DIRECTORY}: {directoryEntries}`)
	end

	local scriptFiles: { string } = {}

	for _, entry in directoryEntries do
		if isScriptFile(entry) then
			table.insert(scriptFiles, entry)
		end
	end

	-- Sort for deterministic execution order
	table.sort(scriptFiles)

	return scriptFiles
end

--[=[
	@private
	Creates visual separator line for headers.

	@return string -- Separator line of SEPARATOR_WIDTH characters
]=]
local function createSeparator(): string
	return string.rep("=", SEPARATOR_WIDTH)
end

--[=[
	@private
	Prints formatted section header with styling.

	@param headerText string -- Text to display in header
	@side-effect Prints styled header to stdout
]=]
local function printHeader(headerText: string)
	local separator = createSeparator()

	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("cyan"))
	print("")
	print(separator)
	print(headerText)
	print(separator)
	stdio.write(stdio.style("reset"))
	stdio.write(stdio.color("reset"))
	print("")
end

--[=[
	@private
	Determines summary color based on execution results.

	@param result ExecutionResult -- Execution statistics
	@return string -- Color name for stdio.color()
]=]
local function getSummaryColor(result: ExecutionResult): string
	return if result.failed == 0 then "green" else "yellow"
end

--[=[
	@private
	Prints execution summary with statistics.

	Displays success/failure counts, total scripts, and elapsed time.
	Uses color coding to indicate overall status (green = all passed,
	yellow/red = some failed).

	@param result ExecutionResult -- Execution statistics
	@param totalScripts number -- Total number of scripts executed
	@param elapsedSeconds number -- Total execution time in seconds
	@side-effect Prints styled summary to stdout
]=]
local function printSummary(result: ExecutionResult, totalScripts: number, elapsedSeconds: number)
	local separator = createSeparator()

	-- Print header
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("cyan"))
	print("")
	print(separator)
	print("Summary")
	print(separator)
	stdio.write(stdio.style("reset"))

	-- Print success count with appropriate color
	local successColor = getSummaryColor(result)
	stdio.write(stdio.color(successColor))
	print(`  Succeeded: {result.succeeded}/{totalScripts}`)
	stdio.write(stdio.color("reset"))

	-- Print failure count if any failures occurred
	if result.failed > 0 then
		stdio.write(stdio.color("red"))
		print(`  Failed: {result.failed}/{totalScripts}`)
		stdio.write(stdio.color("reset"))
	end

	-- Print execution time
	stdio.write(stdio.color("blue"))
	print(`  Time: {string.format("%.2f", elapsedSeconds)}s`)
	stdio.write(stdio.color("reset"))
end

--[=[
	@private
	Executes a single dumper script as a subprocess.

	Spawns lune process with inherited stdio for real-time output.
	Returns success status based on exit code.

	@param execution ScriptExecution -- Script execution configuration
	@return boolean -- True if script exited with code 0
	@side-effect Executes subprocess, prints to stdout/stderr
]=]
local function executeScript(execution: ScriptExecution): boolean
	local arguments: { string } = { "run", execution.scriptPath }

	-- Append version hash if provided
	if execution.versionHash then
		table.insert(arguments, execution.versionHash)
	end

	local spawnSuccess, processResult = pcall(Process.exec, "lune", arguments, {
		stdio = "inherit",
	})

	-- Handle process spawn failure
	if not spawnSuccess then
		stdio.write(stdio.color("red"))
		stdio.write("x ")
		stdio.write(stdio.color("reset"))
		stdio.ewrite(`Failed to execute script: {processResult}\n`)
		return false
	end

	-- Handle non-zero exit code
	if not processResult.ok then
		stdio.write(stdio.color("red"))
		stdio.write("x ")
		stdio.write(stdio.color("reset"))
		stdio.ewrite(`Script exited with code {processResult.code}\n`)
		return false
	end

	return true
end

--[=[
	@private
	Prints script name with progress indicator.

	Formats output as "[index/total] scriptName" in bold.

	@param scriptIndex number -- Current script index (1-based)
	@param totalScripts number -- Total number of scripts
	@param scriptFilename string -- Script filename with extension
	@side-effect Prints styled script name to stdout
]=]
local function printScriptProgress(scriptIndex: number, totalScripts: number, scriptFilename: string)
	local scriptName = removeExtension(scriptFilename)

	stdio.write(stdio.style("bold"))
	print(`[{scriptIndex}/{totalScripts}] {scriptName}`)
	stdio.write(stdio.style("reset"))
end

--[=[
	@private
	Prints version hash information if provided.

	@param versionHash string? -- Optional version hash
	@side-effect Prints version info to stdout if hash provided
]=]
local function printVersionInfo(versionHash: string?)
	if not versionHash then
		return
	end

	stdio.write(stdio.color("blue"))
	stdio.write("i ")
	stdio.write(stdio.color("reset"))
	print(`Version: {versionHash}`)
	print("")
end

--[=[
	@private
	Initializes execution result tracker.

	@return ExecutionResult -- New result tracker with zero counts
]=]
local function createExecutionResult(): ExecutionResult
	return {
		succeeded = 0,
		failed = 0,
	}
end

-- ===== Public API =====

--[=[
	Runs all dumper scripts sequentially with progress tracking.

	Discovers scripts in SCRIPTS_DIRECTORY, executes each in sorted order,
	and reports comprehensive statistics. Individual script failures are
	isolated and don't abort the batch.

	@param versionHash string? -- Optional API dump version hash to pass to scripts
	@error Exits process with code 1 if any script fails or no scripts found
	@side-effect Executes subprocesses, prints to stdout/stderr, may exit process
]=]
function Runner.run(versionHash: string?)
	local scriptFiles = discoverScripts()

	-- Guard against empty scripts directory
	if #scriptFiles == 0 then
		stdio.write(stdio.color("yellow"))
		stdio.write("! ")
		stdio.write(stdio.color("reset"))
		print("No dumper scripts found in scripts directory")
		Process.exit(1)
	end

	local currentTime = os.date(TIMESTAMP_FORMAT)
	printHeader(`API Dump Analysis  •  {currentTime}`)
	printVersionInfo(versionHash)

	local executionResult = createExecutionResult()
	local startTime = os.time()

	-- Execute each script and track results
	for scriptIndex, scriptFilename in scriptFiles do
		printScriptProgress(scriptIndex, #scriptFiles, scriptFilename)

		local execution: ScriptExecution = {
			scriptPath = `{SCRIPTS_DIRECTORY}/{scriptFilename}`,
			versionHash = versionHash,
		}

		local scriptSucceeded = executeScript(execution)

		if scriptSucceeded then
			executionResult.succeeded += 1
		else
			executionResult.failed += 1
		end

		print("")
	end

	local elapsedSeconds = os.time() - startTime
	printSummary(executionResult, #scriptFiles, elapsedSeconds)

	-- Exit with error code if any failures occurred
	if executionResult.failed > 0 then
		Process.exit(1)
	end
end

-- ===== Entry Point =====

Lib.runCli(Runner.run, Process.args)
