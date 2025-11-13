--!strict
--[=[
	@class Logging
	Shared logging utilities for lune scripts.

	Provides consistent colored output and formatting across dump scripts and
	pipeline stages. Uses simple ASCII symbols for maximum terminal compatibility.

	All logging functions write to stdout except error/fatal which use stderr.
	Verbose logging can be enabled/disabled globally via setVerbose().

	@dep @lune/stdio -- Terminal I/O and ANSI formatting
]=]

-- ===== Imports =====

local stdio = require("@lune/stdio")

-- ===== Module =====

local Logging = {}

-- ===== Constants =====

-- ANSI color codes for formatted terminal output
local COLOR_RESET: string = stdio.color("reset")
local COLOR_CYAN: string = stdio.color("cyan")
local COLOR_GREEN: string = stdio.color("green")
local COLOR_YELLOW: string = stdio.color("yellow")
local COLOR_RED: string = stdio.color("red")
local COLOR_BLUE: string = stdio.color("blue")

-- ANSI text styles
local STYLE_BOLD: string = stdio.style("bold")
local STYLE_DIM: string = stdio.style("dim")

-- Simple ASCII symbols for different log levels (maximum compatibility)
local SYMBOL_INFO: string = "i"
local SYMBOL_SUCCESS: string = ">"
local SYMBOL_WARNING: string = "!"
local SYMBOL_ERROR: string = "x"
local SYMBOL_FILE: string = "+"

-- File size units for human-readable formatting
local SIZE_UNITS: { string } = { "B", "KB", "MB", "GB" }
local BYTES_PER_UNIT: number = 1024

-- Time unit thresholds
local MILLISECONDS_PER_SECOND: number = 1000

-- ===== Type Definitions =====

--[=[
	@type LogLevel
	Standard log levels supported by the logging system.
]=]
export type LogLevel = "info" | "success" | "warn" | "error" | "fatal"

-- ===== Module State =====

-- Tracks whether verbose logging is enabled globally
local verboseEnabled: boolean = false

-- ===== Configuration =====

--[=[
	Enables or disables verbose logging globally.

	When enabled, verbose() calls will output dimmed text. When disabled,
	verbose() calls are completely suppressed.

	@param enabled boolean -- True to enable verbose output
]=]
function Logging.setVerbose(enabled: boolean)
	verboseEnabled = enabled
end

-- ===== Core Logging Functions =====

--[=[
	Logs an informational message with blue color.

	Used for general information, status updates, and progress indicators.

	@param message string -- Info message to log
]=]
function Logging.info(message: string)
	stdio.write(COLOR_BLUE)
	stdio.write(SYMBOL_INFO)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	print(message)
end

--[=[
	Logs a success message with green color.

	Used for successful operations, completions, and positive outcomes.

	@param message string -- Success message to log
]=]
function Logging.success(message: string)
	stdio.write(COLOR_GREEN)
	stdio.write(SYMBOL_SUCCESS)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	print(message)
end

--[=[
	Logs a warning message with yellow color.

	Used for non-fatal issues, deprecation notices, and cautions.

	@param message string -- Warning message to log
]=]
function Logging.warn(message: string)
	stdio.write(COLOR_YELLOW)
	stdio.write(SYMBOL_WARNING)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	print(message)
end

--[=[
	Logs an error message with red color to stderr.

	Used for recoverable errors and operation failures.

	@param message string -- Error message to log
]=]
function Logging.error(message: string)
	stdio.write(COLOR_RED)
	stdio.write(SYMBOL_ERROR)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	stdio.ewrite(`{message}\n`)
end

--[=[
	Logs a fatal error message with bold red color to stderr.

	Used for unrecoverable errors that will cause program termination.

	@param message string -- Fatal error message to log
]=]
function Logging.fatal(message: string)
	stdio.write(COLOR_RED)
	stdio.write(STYLE_BOLD)
	stdio.write(SYMBOL_ERROR)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	stdio.ewrite(`{message}\n`)
end

-- ===== Specialized Logging Functions =====

--[=[
	Prints a section header with bold cyan color.

	Used to visually separate major sections in output. Includes leading newline
	for spacing.

	@param title string -- Section title to display
]=]
function Logging.section(title: string)
	print(`\n{COLOR_CYAN}{STYLE_BOLD}{title}{COLOR_RESET}`)
end

--[=[
	Logs a successful file operation with green color.

	Used to report file writes, copies, or other filesystem operations.

	@param path string -- File path that was operated on
]=]
function Logging.file(path: string)
	stdio.write(COLOR_GREEN)
	stdio.write(SYMBOL_FILE)
	stdio.write(" ")
	stdio.write(COLOR_RESET)
	print(path)
end

--[=[
	Prints a success message with count and optional secondary information.

	Used for summarizing batch operations or reporting statistics.

	@param count number -- Primary count to display
	@param label string -- Description of what is being counted
	@param secondary string? -- Optional secondary information in parentheses
]=]
function Logging.successCount(count: number, label: string, secondary: string?)
	stdio.write(COLOR_GREEN)
	stdio.write(SYMBOL_SUCCESS)
	stdio.write(" ")
	stdio.write(COLOR_RESET)

	if secondary then
		print(`{count} {label} ({secondary})`)
	else
		print(`{count} {label}`)
	end
end

--[=[
	Prints a progress indicator with percentage and count.

	Displays completion progress in the format: [percentage%] (current/total) [message]

	@param current number -- Current progress count (0-based or 1-based)
	@param total number -- Total count to complete
	@param message string? -- Optional status message to append
]=]
function Logging.progress(current: number, total: number, message: string?)
	local percent: number = math.floor((current / total) * 100)
	local progressText: string = `[{percent}%] ({current}/{total})`

	stdio.write(COLOR_BLUE)
	stdio.write(SYMBOL_INFO)
	stdio.write(" ")
	stdio.write(COLOR_RESET)

	if message then
		print(`{progressText} {message}`)
	else
		print(progressText)
	end
end

--[=[
	Logs a verbose/debug message with dimmed styling.

	Only outputs if verbose mode is enabled via setVerbose(). Used for detailed
	diagnostic information that would clutter normal output.

	@param message string -- Verbose message to log
]=]
function Logging.verbose(message: string)
	if not verboseEnabled then
		return
	end

	stdio.write(STYLE_DIM)
	print(message)
	stdio.write(COLOR_RESET)
end

--[=[
	Prints a dimmed text message.

	Used for secondary information or less important status updates.

	@param text string -- Text to print with dim styling
]=]
function Logging.dim(text: string)
	stdio.write(STYLE_DIM)
	print(text)
	stdio.write(COLOR_RESET)
end

-- ===== Tree Structure Formatting =====

--[=[
	Prints an indented detail line with tree branch symbol (├─).

	Used for hierarchical output structures. Should be followed by detailLast()
	for the final item in a group.

	@param message string -- Detail message to display
	@param depth number? -- Indentation depth in levels (default: 1)
]=]
function Logging.detail(message: string, depth: number?)
	local indentLevel: number = depth or 1
	local indent: string = string.rep("  ", indentLevel)
	print(`{indent}├─ {message}`)
end

--[=[
	Prints an indented detail line with tree end symbol (└─).

	Used as the final item in a hierarchical group to close the tree structure.

	@param message string -- Detail message to display
	@param depth number? -- Indentation depth in levels (default: 1)
]=]
function Logging.detailLast(message: string, depth: number?)
	local indentLevel: number = depth or 1
	local indent: string = string.rep("  ", indentLevel)
	print(`{indent}└─ {message}`)
end

-- ===== Formatting Utilities =====

--[=[
	Formats duration in milliseconds to human-readable string.

	Automatically selects appropriate unit (seconds or milliseconds) based on magnitude.

	@param durationMs number -- Duration in milliseconds
	@return string -- Formatted duration (e.g., "1.23s" or "456ms")
]=]
function Logging.formatDuration(durationMs: number): string
	if durationMs >= MILLISECONDS_PER_SECOND then
		local seconds: number = durationMs / MILLISECONDS_PER_SECOND
		return string.format("%.2fs", seconds)
	end

	local milliseconds: number = math.floor(durationMs)
	return string.format("%dms", milliseconds)
end

--[=[
	Formats byte size to human-readable string with appropriate units.

	Automatically selects unit (B, KB, MB, GB) based on magnitude. Uses 1024-based
	conversion (binary) rather than 1000-based (decimal).

	@param bytes number -- Size in bytes
	@return string -- Formatted size (e.g., "1.23 MB" or "456 KB")
]=]
function Logging.formatSize(bytes: number): string
	local size: number = bytes
	local unitIndex: number = 1

	-- Convert to larger units while size exceeds threshold
	while size >= BYTES_PER_UNIT and unitIndex < #SIZE_UNITS do
		size /= BYTES_PER_UNIT
		unitIndex += 1
	end

	-- Format with appropriate precision
	if unitIndex == 1 then
		-- Bytes - no decimal places
		return string.format("%d %s", size, SIZE_UNITS[unitIndex])
	else
		-- Larger units - 2 decimal places
		return string.format("%.2f %s", size, SIZE_UNITS[unitIndex])
	end
end

return Logging
