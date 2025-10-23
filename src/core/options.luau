--[[
	Options - Configuration system with defaults and validation

	Provides comprehensive saveinstance configuration with:
	- Executor-specific defaults
	- Alias resolution
	- Type validation
	- Option merging

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local Executor = require ("@utilities/executor")
local TableUtil = require ("@utilities/table")

export type SaveMode = "full" | "optimized" | "scripts"

export type Options = {
	-- Core options
	mode: SaveMode,
	noscripts: boolean,
	scriptcache: boolean,
	timeout: number,

	-- Debug and output
	__DEBUG_MODE: boolean | ((message: string, ...any) -> ()),
	Callback: ((data: string) -> ())?,
	ShowStatus: boolean,
	ReadMe: boolean,

	-- Decompilation
	DecompileJobless: boolean,
	DecompileIgnore: { Instance | string | { [string]: { string } } },
	SaveBytecode: boolean,
	IgnoreDefaultPlayerScripts: boolean,

	-- Filtering
	IgnoreProperties: { [string]: boolean },
	IgnoreList: { Instance | string | { [string]: { string } } },
	ExtraInstances: { Instance },
	NilInstances: boolean,
	NilInstancesFixes: { [string]: any },

	-- Performance
	SaveCacheInterval: number,

	-- Safety and anti-detection
	SafeMode: boolean,
	ShutdownWhenDone: boolean,
	AntiIdle: boolean,
	Anonymous: boolean | { UserId: string, Name: string },

	-- File output
	FilePath: string?,
	Object: Instance?,
	IsModel: boolean,

	-- Property handling
	IgnoreDefaultProperties: boolean,
	IgnoreNotArchivable: boolean,
	IgnorePropertiesOfNotScriptsOnScriptsMode: boolean,
	IgnoreSpecialProperties: boolean,

	-- Player isolation
	IsolateLocalPlayer: boolean,
	IsolateLocalPlayerCharacter: boolean,
	IsolatePlayers: boolean,
	IsolateStarterPlayer: boolean,
	RemovePlayerCharacters: boolean,

	-- Instance handling
	SaveNotCreatable: boolean,
	NotCreatableFixes: { [string]: string | boolean },

	-- Risky options
	IgnoreSharedStrings: boolean,
	SharedStringOverwrite: boolean,
	TreatUnionsAsParts: boolean,
	AlternativeWritefile: boolean,
}

-- Executor-specific overrides
local executorName = Executor.info.name

-- Default options
local defaults: Options = {
	mode = "optimized",
	noscripts = false,
	scriptcache = true,
	timeout = 10,

	__DEBUG_MODE = false,
	Callback = nil,
	ShowStatus = true,
	ReadMe = true,

	DecompileJobless = false,
	DecompileIgnore = {
		"TextChatService",
	},
	SaveBytecode = false,
	IgnoreDefaultPlayerScripts = executorName ~= "Wave",

	IgnoreProperties = {},
	IgnoreList = { "CoreGui", "CorePackages" },
	ExtraInstances = {},
	NilInstances = false,
	NilInstancesFixes = {},

	SaveCacheInterval = 0x1600 * 10,

	SafeMode = false,
	ShutdownWhenDone = false,
	AntiIdle = true,
	Anonymous = false,

	FilePath = nil,
	Object = nil,
	IsModel = false,

	IgnoreDefaultProperties = true,
	IgnoreNotArchivable = true,
	IgnorePropertiesOfNotScriptsOnScriptsMode = false,
	IgnoreSpecialProperties = TableUtil.arrayToDict ({ "Fluxus", "Delta", "Solara" })[executorName] or false,

	IsolateLocalPlayer = false,
	IsolateLocalPlayerCharacter = false,
	IsolatePlayers = false,
	IsolateStarterPlayer = false,
	RemovePlayerCharacters = true,

	SaveNotCreatable = false,
	NotCreatableFixes = {
		"", -- FilteredSelection
		AnimationTrack = true,
		Player = true,
		PlayerGui = true,
		PlayerScripts = true,
		PlayerMouse = true,
		ScreenshotHud = true,
		StudioData = true,
		TextSource = true,
		TouchTransmitter = true,
	},

	IgnoreSharedStrings = executorName ~= "Wave",
	SharedStringOverwrite = false,
	TreatUnionsAsParts = executorName == "Solara",
	AlternativeWritefile = not TableUtil.arrayToDict ({ "WRD", "Xeno", "Zorara" })[executorName],
}

-- Option aliases for backwards compatibility
local aliases = {
	DecompileTimeout = "timeout",
	FileName = "FilePath",
	IgnoreArchivable = "IgnoreNotArchivable",
	IgnoreDefaultProps = "IgnoreDefaultProperties",
	SaveNonCreatable = "SaveNotCreatable",
	SavePlayers = "IsolatePlayers",
}

--[=[
	Resolves option name through aliases

	@param name string -- Option name (case-insensitive)
	@return string? -- Resolved option name or nil
]=]
local function resolveOptionName (name: string): string?
	local lowerName = string.lower (name)

	-- Build lookup map
	local lookup = {}
	for optionName in defaults do
		lookup[string.lower (optionName)] = optionName
	end
	for alias, optionName in aliases do
		lookup[string.lower (alias)] = optionName
	end

	return lookup[lowerName]
end

--[=[
	Validates and merges user options with defaults

	@param userOptions table? -- User-provided options
	@return Options -- Merged options
]=]
local function mergeOptions (userOptions: any?): Options
	local options: any = table.clone (defaults)

	if not userOptions then return options :: Options end

	-- Handle special case: array of instances as ExtraInstances
	if typeof (userOptions) == "table" and typeof (userOptions[1]) == "Instance" then
		options.mode = "invalidmode"
		options.ExtraInstances = userOptions
		options.IsModel = true
		return options :: Options
	end

	-- Handle special case: single instance as Object
	if typeof (userOptions) == "Instance" then
		options.mode = "invalidmode"
		options.Object = userOptions
		return options :: Options
	end

	if typeof (userOptions) ~= "table" then return options :: Options end

	-- Merge user options
	for key, value in userOptions do
		local resolvedKey = resolveOptionName (key)
		if resolvedKey then options[resolvedKey] = value end
	end

	-- Handle inverse aliases
	if userOptions.Decompile ~= nil then options.noscripts = not userOptions.Decompile end

	if userOptions.SavePlayerCharacters ~= nil then
		options.RemovePlayerCharacters = not userOptions.SavePlayerCharacters
	end

	if userOptions.RemovePlayers ~= nil then options.IsolatePlayers = not userOptions.RemovePlayers end

	-- Validate and adjust options
	if options.DecompileJobless then options.scriptcache = true end

	if options.Object == game then
		options.mode = "full"
		options.Object = nil
		options.IsModel = nil
	end

	if options.Object and userOptions.IsModel == nil then options.IsModel = true end

	if options.Object and options.mode == "optimized" then
		-- Optimized mode not compatible with Object
		options.mode = "full"
	end

	return options :: Options
end

--[=[
	Converts options to array-based lists for performance

	@param options Options
	@return table -- Processed options with arrays
]=]
local function processOptions (options: Options): any
	local processed = table.clone (options :: any)

	-- Convert ignore lists to dictionaries
	processed.DecompileIgnore = TableUtil.arrayToDict (options.DecompileIgnore, true)
	processed.IgnoreList = TableUtil.arrayToDict (options.IgnoreList, true)
	processed.IgnoreProperties = TableUtil.arrayToDict (options.IgnoreProperties)
	processed.NotCreatableFixes = TableUtil.arrayToDict (options.NotCreatableFixes, true, "Folder")

	return processed
end

return {
	defaults = defaults,
	aliases = aliases,
	resolveOptionName = resolveOptionName,
	mergeOptions = mergeOptions,
	processOptions = processOptions,
}
