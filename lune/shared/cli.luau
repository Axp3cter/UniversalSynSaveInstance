--!strict
--[=[
	@class Cli
	Shared CLI utilities for lune scripts.

	Provides command-line interface helpers including argument parsing and
	standardized error handling for script entry points.

	@dep @lune/process -- Process control and argument access
]=]

-- ===== Imports =====

local Process = require("@lune/process")
local Logging = require("./logging")

-- ===== Module =====

local Cli = {}

-- ===== Type Definitions =====

--[=[
	@class ParsedArguments
	Structure containing parsed command-line arguments.

	Arguments are categorized into positional arguments, boolean flags, and
	key-value options for easy consumption.

	@field positional {string} -- Ordered non-flag arguments
	@field flags {[string]: boolean} -- Boolean flags (--flag or -f)
	@field options {[string]: string} -- Key-value pairs (--key=value)
]=]
export type ParsedArguments = {
	positional: { string },
	flags: { [string]: boolean },
	options: { [string]: string },
}

-- ===== CLI Error Handling =====

--[=[
	Runs a script function with standardized error handling.

	Provides consistent CLI entry point behavior:
	- Extracts optional hash parameter from arguments
	- Wraps execution in pcall for safe error capture
	- Logs fatal errors with consistent formatting
	- Exits with code 1 on any failure

	This pattern ensures all CLI tools have uniform error reporting.

	@param scriptFunction (string?) -> () -- Function to execute (receives hash parameter)
	@param arguments {string} -- Command-line arguments array

	@error Exits process with code 1 on any error (never throws)
]=]
function Cli.run(scriptFunction: (string?) -> (), arguments: { string })
	local hashParameter: string? = arguments[1]

	local executeSuccess: boolean
	local executeError: any

	executeSuccess, executeError = pcall(scriptFunction, hashParameter)

	if not executeSuccess then
		Logging.error(`Fatal: {executeError}`)
		Process.exit(1)
	end
end

-- ===== Argument Parsing =====

--[=[
	Parses command-line arguments into structured format.

	Recognizes three argument types:
	- Flags: --verbose, --ci, -v, -f (boolean)
	- Options: --config=path, --name=value (key-value)
	- Positional: Any arguments without -- prefix

	@param arguments {string} -- Raw command-line arguments array
	@return ParsedArguments -- Structured arguments with positional, flags, and options

	@example
	```lua
	local args = Cli.parseArgs({"input.txt", "--verbose", "--output=result.json"})
	-- args.positional = {"input.txt"}
	-- args.flags = {verbose = true}
	-- args.options = {output = "result.json"}
	```
]=]
function Cli.parseArgs(arguments: { string }): ParsedArguments
	local positional: { string } = {}
	local flags: { [string]: boolean } = {}
	local options: { [string]: string } = {}

	for _, argument in arguments do
		-- Check for option with value (--key=value)
		local optionKey: string?
		local optionValue: string?
		optionKey, optionValue = argument:match("^%-%-(.+)=(.+)$")

		if optionKey and optionValue then
			options[optionKey] = optionValue
			continue
		end

		-- Check for long flag (--flag)
		local longFlag: string? = argument:match("^%-%-(.+)$")
		if longFlag then
			flags[longFlag] = true
			continue
		end

		-- Check for short flag (-f)
		local shortFlag: string? = argument:match("^%-(.+)$")
		if shortFlag then
			flags[shortFlag] = true
			continue
		end

		-- Positional argument (no prefix)
		table.insert(positional, argument)
	end

	return {
		positional = positional,
		flags = flags,
		options = options,
	}
end

return Cli
