--!strict

local fs = require("@lune/fs")
local Process = require("@lune/process")
local stdio = require("@lune/stdio")
local Lib = require("./lib")

local SCRIPTS_DIR = "lune/dump/scripts"
local SEPARATOR = string.rep("=", 70)

local Runner = {}

-- Script discovery and validation

local function discoverScripts(): { string }
	local ok, entries = pcall(fs.readDir, SCRIPTS_DIR)
	if not ok then
		error(`Failed to read {SCRIPTS_DIR}`)
	end

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

local function printHeader(text: string)
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("cyan"))
	print(`\n{SEPARATOR}\n{text}\n{SEPARATOR}\n`)
	stdio.write(stdio.style("reset"))
	stdio.write(stdio.color("reset"))
end

local function printProgress(index: number, total: number, name: string)
	stdio.write(stdio.style("bold"))
	print(`[{index}/{total}] {string.gsub(name, "%.luau$", "")}`)
	stdio.write(stdio.style("reset"))
end

local function printSummary(succeeded: number, failed: number, total: number, elapsed: number)
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

local function executeScript(path: string, hash: string?): boolean
	local args = { "run", path }
	if hash then
		table.insert(args, hash)
	end

	local ok, result = pcall(Process.exec, "lune", args, { stdio = "inherit" })

	if not ok then
		stdio.write(stdio.color("red"))
		stdio.ewrite(`x {result}\n`)
		stdio.write(stdio.color("reset"))
		return false
	end

	if not result.ok then
		stdio.write(stdio.color("red"))
		stdio.ewrite(`x Exit code {result.code}\n`)
		stdio.write(stdio.color("reset"))
		return false
	end

	return true
end

-- Main runner

function Runner.run(hash: string?)
	local scripts = discoverScripts()

	if #scripts == 0 then
		stdio.write(stdio.color("yellow"))
		print("! No scripts found")
		stdio.write(stdio.color("reset"))
		Process.exit(1)
	end

	printHeader(`API Dump Analysis  •  {os.date("%Y-%m-%d %H:%M:%S")}`)

	if hash then
		stdio.write(stdio.color("blue"))
		print(`i Version: {hash}\n`)
		stdio.write(stdio.color("reset"))
	end

	local succeeded = 0
	local failed = 0
	local startTime = os.time()

	for i, script in scripts do
		printProgress(i, #scripts, script)

		if executeScript(`{SCRIPTS_DIR}/{script}`, hash) then
			succeeded += 1
		else
			failed += 1
		end

		print("")
	end

	printSummary(succeeded, failed, #scripts, os.time() - startTime)

	if failed > 0 then
		Process.exit(1)
	end
end

Lib.runCli(Runner.run, Process.args)
