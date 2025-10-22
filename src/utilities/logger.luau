--[[
	Logger - Simple logging utility

	Provides structured logging with levels and prefixes.
	Used for debug output and status reporting.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-20
]]

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

export type LogEntry = {
	level: LogLevel,
	message: string,
	timestamp: number,
}

-- Configuration
local config = {
	enabled = true,
	minLevel = "INFO",
	prefix = "[USSI]",
	useTimestamp = false,
}

-- Level priority mapping
local LEVELS: { [LogLevel]: number } = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

-- Log history
local history: { LogEntry } = {}
local maxHistorySize = 1000

--[=[
	Logs a message with specified level

	@param level LogLevel -- Log level
	@param message string -- Message to log
	@param ... any -- Additional format arguments
]=]
local function log (level: LogLevel, message: string, ...: any)
	if not config.enabled then return end

	-- Check if message should be logged based on level
	if LEVELS[level] < LEVELS[config.minLevel] then return end

	-- Format message with arguments
	local formatted = message
	if select ("#", ...) > 0 then formatted = string.format (message, ...) end

	-- Build output
	local output = config.prefix .. " [" .. level .. "] " .. formatted

	if config.useTimestamp then output = string.format ("[%.3f] %s", os.clock (), output) end

	-- Print to console
	if level == "ERROR" then
		warn (output)
	else
		print (output)
	end

	-- Store in history
	local entry: LogEntry = {
		level = level,
		message = formatted,
		timestamp = os.clock (),
	}

	table.insert (history, entry)

	-- Trim history if it gets too large
	if #history > maxHistorySize then table.remove (history, 1) end
end

--[=[
	Logs debug message

	@param message string -- Message to log
	@param ... any -- Additional format arguments
]=]
local function debug (message: string, ...: any) log ("DEBUG", message, ...) end

--[=[
	Logs info message

	@param message string -- Message to log
	@param ... any -- Additional format arguments
]=]
local function info (message: string, ...: any) log ("INFO", message, ...) end

--[=[
	Logs warning message

	@param message string -- Message to log
	@param ... any -- Additional format arguments
]=]
local function warn (message: string, ...: any) log ("WARN", message, ...) end

--[=[
	Logs error message

	@param message string -- Message to log
	@param ... any -- Additional format arguments
]=]
local function error (message: string, ...: any) log ("ERROR", message, ...) end

--[=[
	Sets logger configuration

	@param newConfig {enabled: boolean?, minLevel: LogLevel?, prefix: string?, useTimestamp: boolean?}
]=]
local function setConfig (newConfig: { enabled: boolean?, minLevel: LogLevel?, prefix: string?, useTimestamp: boolean? })
	for key, value in newConfig do
		if config[key] ~= nil then config[key] = value end
	end
end

--[=[
	Gets logger configuration

	@return {enabled: boolean, minLevel: LogLevel, prefix: string, useTimestamp: boolean}
]=]
local function getConfig (): { enabled: boolean, minLevel: LogLevel, prefix: string, useTimestamp: boolean }
	return table.clone (config) :: any
end

--[=[
	Gets log history

	@return {LogEntry}
]=]
local function getHistory (): { LogEntry } return table.clone (history) end

--[=[
	Clears log history
]=]
local function clearHistory () table.clear (history) end

return {
	debug = debug,
	info = info,
	warn = warn,
	error = error,
	setConfig = setConfig,
	getConfig = getConfig,
	getHistory = getHistory,
	clearHistory = clearHistory,
}
