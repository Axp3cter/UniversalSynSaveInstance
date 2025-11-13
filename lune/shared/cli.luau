--!strict
--[=[
	@class Cli
	Shared CLI utilities for lune scripts.

	Provides command-line interface helpers and error handling.
]=]

-- Imports
local Process = require("@lune/process")
local Logging = require("./logging")

-- Module
local Cli = {}

--[=[
	Runs a script function with standardized error handling.

	Provides consistent CLI entrypoint behavior:
	- Parses Process.args for optional hash parameter
	- Catches errors and formats as fatal error messages
	- Exits with code 1 on failure

	@param fn -- Function to run (receives hash parameter)
	@param args -- Process arguments array
	@error Exits with code 1 on failure
]=]
function Cli.run(fn: (string?) -> (), args: { string })
	local hash: string? = args[1]
	local ok: boolean, err: any = pcall(fn, hash)

	if not ok then
		Logging.error(`Fatal: {err}`)
		Process.exit(1)
	end
end

--[=[
	Parses command-line arguments.

	Recognizes flags like --ci, --verbose/-v, --config=path, and positional arguments.

	@param args -- Command-line arguments array
	@return Parsed arguments table
]=]
function Cli.parseArgs(args: { string }): {
	positional: { string },
	flags: { [string]: boolean },
	options: { [string]: string },
}
	local positional: { string } = {}
	local flags: { [string]: boolean } = {}
	local options: { [string]: string } = {}

	for _, arg: string in args do
		if arg:match("^%-%-(.+)=(.+)$") then
			-- Option with value: --key=value
			local key, value = arg:match("^%-%-(.+)=(.+)$")
			if key and value then
				options[key] = value
			end
		elseif arg:match("^%-%-(.+)$") then
			-- Flag: --flag
			local key = arg:match("^%-%-(.+)$")
			if key then
				flags[key] = true
			end
		elseif arg:match("^%-(.+)$") then
			-- Short flag: -f
			local key = arg:match("^%-(.+)$")
			if key then
				flags[key] = true
			end
		else
			-- Positional argument
			table.insert(positional, arg)
		end
	end

	return {
		positional = positional,
		flags = flags,
		options = options,
	}
end

return Cli
