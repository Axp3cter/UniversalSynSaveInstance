--!strict
--[=[
	@class Logging
	Shared logging utilities for lune scripts.

	Provides consistent colored output and formatting across
	dump scripts and pipeline stages.
]=]

-- Imports
local stdio = require("@lune/stdio")

-- Module
local Logging = {}

-- ANSI color codes and styles for formatted terminal output
local COLOR_RESET: string = stdio.color("reset")
local COLOR_CYAN: string = stdio.color("cyan")
local COLOR_GREEN: string = stdio.color("green")
local COLOR_YELLOW: string = stdio.color("yellow")
local COLOR_RED: string = stdio.color("red")
local COLOR_BLUE: string = stdio.color("blue")
local STYLE_BOLD: string = stdio.style("bold")
local STYLE_DIM: string = stdio.style("dim")

-- Unicode symbols used as visual prefixes for different log levels
local SYMBOL_INFO: string = "▶"
local SYMBOL_SUCCESS: string = "✓"
local SYMBOL_WARNING: string = "⚠"
local SYMBOL_ERROR: string = "✗"

-- Tracks whether verbose logging is enabled
local verboseEnabled: boolean = false

export type LogLevel = "info" | "success" | "warn" | "error" | "fatal"

--[=[
	Enables or disables verbose logging.

	@param enabled -- Whether to enable verbose output
]=]
function Logging.setVerbose(enabled: boolean)
	verboseEnabled = enabled
end

--[=[
	Logs an info message with cyan color and info symbol.

	@param message -- Info message to log
]=]
function Logging.info(message: string)
	print(`{COLOR_CYAN}{SYMBOL_INFO}{COLOR_RESET} {message}`)
end

--[=[
	Logs a success message with green color and checkmark symbol.

	@param message -- Success message to log
]=]
function Logging.success(message: string)
	print(`{COLOR_GREEN}{SYMBOL_SUCCESS}{COLOR_RESET} {message}`)
end

--[=[
	Logs a warning message with yellow color and warning symbol.

	@param message -- Warning message to log
]=]
function Logging.warn(message: string)
	print(`{COLOR_YELLOW}{SYMBOL_WARNING}{COLOR_RESET} {message}`)
end

--[=[
	Logs an error message with red color and error symbol.

	@param message -- Error message to log
]=]
function Logging.error(message: string)
	print(`{COLOR_RED}{SYMBOL_ERROR}{COLOR_RESET} {message}`)
end

--[=[
	Logs a fatal error message with bold red color.

	@param message -- Fatal error message to log
]=]
function Logging.fatal(message: string)
	print(`{COLOR_RED}{STYLE_BOLD}{SYMBOL_ERROR} {message}{COLOR_RESET}`)
end

--[=[
	Prints a section header with bold cyan color.

	@param title -- Section title
]=]
function Logging.section(title: string)
	print(`\n{COLOR_CYAN}{STYLE_BOLD}{title}{COLOR_RESET}`)
end

--[=[
	Prints a progress indicator with percentage and count.

	@param current -- Current progress count
	@param total -- Total count
	@param message -- Optional message to append
]=]
function Logging.progress(current: number, total: number, message: string?)
	local percent: number = math.floor((current / total) * 100)
	local progressText: string = `[{percent}%] ({current}/{total})`

	if not message then
		print(`{COLOR_CYAN}{SYMBOL_INFO}{COLOR_RESET} {progressText}`)
		return
	end

	print(`{COLOR_CYAN}{SYMBOL_INFO}{COLOR_RESET} {progressText} {message}`)
end

--[=[
	Logs a verbose/debug message (only shown if verbose mode is enabled).

	@param message -- Verbose message to log
]=]
function Logging.verbose(message: string)
	if verboseEnabled then
		print(`{STYLE_DIM}{message}{COLOR_RESET}`)
	end
end

--[=[
	Prints an indented detail line with tree branch symbol.

	@param message -- Detail message
	@param depth -- Optional indentation depth (default: 1)
]=]
function Logging.detail(message: string, depth: number?)
	local indent: string = string.rep("  ", depth or 1)
	print(`{indent}├─ {message}`)
end

--[=[
	Prints an indented detail line with tree end symbol.

	@param message -- Detail message
	@param depth -- Optional indentation depth (default: 1)
]=]
function Logging.detailLast(message: string, depth: number?)
	local indent: string = string.rep("  ", depth or 1)
	print(`{indent}└─ {message}`)
end

--[=[
	Prints dimmed text to stdout.

	@param text -- Text to print
]=]
function Logging.dim(text: string)
	stdio.write(STYLE_DIM)
	print(text)
	stdio.write(COLOR_RESET)
end

--[=[
	Formats duration in milliseconds to human-readable string.

	@param ms -- Duration in milliseconds
	@return Formatted duration string (e.g., "1.23s" or "456ms")
]=]
function Logging.formatDuration(ms: number): string
	if ms >= 1000 then
		return string.format("%.2fs", ms / 1000)
	end
	return string.format("%dms", math.floor(ms))
end

--[=[
	Formats byte size to human-readable string with units.

	@param bytes -- Size in bytes
	@return Formatted size string (e.g., "1.23 MB" or "456 KB")
]=]
function Logging.formatSize(bytes: number): string
	local units: { string } = { "B", "KB", "MB", "GB" }
	local size: number = bytes
	local unitIndex: number = 1

	while size >= 1024 and unitIndex < #units do
		size /= 1024
		unitIndex += 1
	end

	if unitIndex == 1 then
		return string.format("%d %s", size, units[unitIndex])
	end
	return string.format("%.2f %s", size, units[unitIndex])
end

return Logging
