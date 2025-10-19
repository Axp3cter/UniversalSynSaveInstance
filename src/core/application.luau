-- USSI Rewrite - Core Application Controller
-- Main application controller managing initialization, mode detection, and lifecycle

local Types = require("@types")

-- Application state management
local ApplicationState = {
	Mode = "Headless" :: Types.ApplicationMode,  -- Default to headless mode
	IsInitialized = false,
	Configuration = {} :: Types.AppConfig,
	Parsers = {} :: {Types.Parser},
	CurrentFile = nil :: string?,
	LoadedInstance = nil :: Types.Instance?
}

-- Mode detection based on environment
local function detectApplicationMode(): Types.ApplicationMode
	-- Check if we're in a Roblox Studio environment (UI mode available)
	if game:GetService("RunService"):IsStudio() then
		return "UI"
	end

	-- Check for command line arguments or headless indicators
	-- For now, default to headless mode for safety
	return "Headless"
end

-- Initialize application configuration
local function initializeConfiguration(): Types.AppConfig
	return {
		Mode = ApplicationState.Mode,
		LogLevel = "INFO",
		MaxFileSize = 50 * 1024 * 1024, -- 50MB
		EnableValidation = true,
		Theme = "Dark",
		AutoSave = false,
		BackupEnabled = true
	}
end

-- Register available parsers
local function registerParsers()
	-- Import and register XML parser
	local XmlParser = require("@modules/xml/main")

	-- Validate parser interface
	assert(XmlParser.detectFormat, "Parser missing detectFormat function")
	assert(XmlParser.parse, "Parser missing parse function")
	assert(XmlParser.serialize, "Parser missing serialize function")

	-- Create parser wrapper
	local xmlParser: Types.Parser = {
		canParse = function(format: Types.FileFormat): boolean
			return format == "RBXLX" or format == "RBXMX"
		end,

		parse = function(content: string): (Types.Instance?, string?)
			local instance, error = XmlParser.parse(content)
			if error then
				return nil, error.Message
			end
			return instance, nil
		end,

		serialize = function(root: Types.Instance?): (string, string?)
			local xml, error = XmlParser.serialize(root)
			if error then
				return "", error.Message
			end
			return xml or "", nil
		end,

		getFormat = function(): Types.FileFormat
			return "RBXLX"
		end,

		validate = function(content: string): (boolean, string?)
			local format = XmlParser.detectFormat(content)
			if not format then
				return false, "Invalid XML format"
			end
			return true, nil
		end
	}

	table.insert(ApplicationState.Parsers, xmlParser)
end

-- Initialize application components
local function initializeComponents()
	-- Register parsers
	registerParsers()

	-- TODO: Initialize state management (Fusion-based)
	-- TODO: Initialize UI components (Cascade-based, UI mode only)
	-- TODO: Initialize file I/O system
	-- TODO: Initialize logging system

	ApplicationState.IsInitialized = true
end

-- Main application initialization
local function initialize(): (boolean, any?)
	-- Detect application mode
	ApplicationState.Mode = detectApplicationMode()

	-- Initialize configuration
	ApplicationState.Configuration = initializeConfiguration()

	-- Initialize core components
	local success = pcall(initializeComponents)

	if not success then
		return false, "Failed to initialize components"
	end

	return true, nil
end

-- Get current application state
local function getState(): {Mode: Types.ApplicationMode, IsInitialized: boolean, Configuration: Types.AppConfig}
	return {
		Mode = ApplicationState.Mode,
		IsInitialized = ApplicationState.IsInitialized,
		Configuration = ApplicationState.Configuration
	}
end

-- Get available parsers
local function getParsers(): {Types.Parser}
	return ApplicationState.Parsers
end

-- Set current file being worked on
local function setCurrentFile(filePath: string?): ()
	ApplicationState.CurrentFile = filePath
end

-- Get current file path
local function getCurrentFile(): string?
	return ApplicationState.CurrentFile
end

-- Set loaded instance tree
local function setLoadedInstance(instance: Types.Instance?): ()
	ApplicationState.LoadedInstance = instance
end

-- Get loaded instance tree
local function getLoadedInstance(): Types.Instance?
	return ApplicationState.LoadedInstance
end

-- Shutdown application
local function shutdown(): ()
	-- TODO: Cleanup resources
	-- TODO: Save configuration
	-- TODO: Close open files
	-- TODO: Cleanup UI components

	ApplicationState.IsInitialized = false
end

-- Module exports for core application functionality
return {
	-- Initialization
	initialize = initialize,

	-- State management
	getState = getState,
	setCurrentFile = setCurrentFile,
	getCurrentFile = getCurrentFile,
	setLoadedInstance = setLoadedInstance,
	getLoadedInstance = getLoadedInstance,

	-- Parsers
	getParsers = getParsers,

	-- Lifecycle
	shutdown = shutdown
}
