--[[
	UniversalSynSaveInstance (USSI) - Main Entry Point

	Comprehensive save instance system for Roblox with XML format support.
	Provides both headless and UI-based operation modes.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

-- Type definitions
local Types = require ("@types")

-- Asynchronous operations
local Promise = require ("@packages/promise")

-- Utilities
local Executor = require ("@utilities/executor")
local Logger = require ("@utilities/logger")
local Statistics = require ("@utilities/statistics")

-- Core modules
local Referent = require ("@core/referent")
local Scripts = require ("@core/scripts")
local SharedStrings = require ("@core/sharedStrings")
local XML = require ("@core/xml")

-- Services
local Services = require ("@utilities/services")

-- Default options
local DEFAULT_OPTIONS: Types.Options = {
	-- Debug and Status
	debugMode = false,
	showStatus = true,

	-- Safety and Execution
	safeMode = false,
	shutdownWhenDone = false,
	antiIdle = false,

	-- Save Modes
	mode = "full",
	noScripts = false,
	scriptCache = true,
	timeout = 30,
	decompileJobless = false,
	saveBytecode = false,

	-- File Output
	filePath = "output",
	callback = nil,
	binary = false,

	-- Instance Handling
	object = nil,
	isModel = false,
	nilInstances = false,
	extraInstances = nil,

	-- Property Filtering
	ignoreProperties = nil,
	ignoreDefaultProperties = false,
	ignoreNotArchivable = false,
	ignoreNonScriptProperties = false,
	ignoreSpecialProperties = false,

	-- Player Isolation
	isolateLocalPlayer = false,
	isolateStarterPlayer = false,
	isolateLocalPlayerCharacter = false,
	removePlayerCharacters = false,
	saveNotCreatable = false,

	-- Advanced Options
	sharedStringOverwrite = false,
	saveCacheInterval = 0,
	decompileIgnore = nil,
	ignoreDefaultPlayerScripts = false,
}

-- Merges user options with defaults
local function mergeOptions (userOpts: Types.Options?): Types.Options
	if not userOpts then return DEFAULT_OPTIONS end

	local merged = table.clone (DEFAULT_OPTIONS) :: any

	for key, value in userOpts :: any do
		merged[key] = value
	end

	return merged :: Types.Options
end

-- Validates options
local function validateOptions (opts: Types.Options): (boolean, string?)
	-- Validate mode
	if opts.mode then
		local validModes = { full = true, optimized = true, scripts = true }
		if not validModes[opts.mode] then
			return false, `Invalid mode: {opts.mode}. Must be "full", "optimized", or "scripts"`
		end
	end

	-- Validate boolean fields
	local booleanFields = {
		"debugMode",
		"showStatus",
		"safeMode",
		"shutdownWhenDone",
		"antiIdle",
		"noScripts",
		"scriptCache",
		"decompileJobless",
		"saveBytecode",
		"binary",
		"isModel",
		"nilInstances",
		"ignoreDefaultProperties",
		"ignoreNotArchivable",
		"ignoreNonScriptProperties",
		"ignoreSpecialProperties",
		"isolateLocalPlayer",
		"isolateStarterPlayer",
		"isolateLocalPlayerCharacter",
		"removePlayerCharacters",
		"saveNotCreatable",
		"sharedStringOverwrite",
		"ignoreDefaultPlayerScripts",
	}

	for _, field in booleanFields do
		local value = (opts :: any)[field]
		if value ~= nil and type (value) ~= "boolean" then
			return false, `Field "{field}" must be a boolean, got {type (value)}`
		end
	end

	-- Validate numeric fields with ranges
	if opts.timeout then
		if type (opts.timeout) ~= "number" then return false, "timeout must be a number" end
		if opts.timeout <= 0 then return false, "timeout must be greater than 0" end
		if opts.timeout > 600 then return false, "timeout cannot exceed 600 seconds" end
	end

	if opts.saveCacheInterval then
		if type (opts.saveCacheInterval) ~= "number" then return false, "saveCacheInterval must be a number" end
		if opts.saveCacheInterval < 0 then return false, "saveCacheInterval must be non-negative" end
	end

	-- Validate string fields
	if opts.filePath then
		if type (opts.filePath) ~= "string" then return false, "filePath must be a string" end
		if #opts.filePath == 0 then return false, "filePath cannot be empty" end
	end

	-- Validate instance reference
	if opts.object and typeof (opts.object) ~= "Instance" then return false, "object must be an Instance" end

	-- Validate callback function
	if opts.callback and type (opts.callback) ~= "function" then return false, "callback must be a function" end

	-- Validate arrays
	if opts.ignoreProperties then
		if type (opts.ignoreProperties) ~= "table" then return false, "ignoreProperties must be a table" end
		for i, prop in opts.ignoreProperties do
			if type (prop) ~= "string" then
				return false, `ignoreProperties[{i}] must be a string, got {type (prop)}`
			end
		end
	end

	if opts.extraInstances then
		if type (opts.extraInstances) ~= "table" then return false, "extraInstances must be a table" end
		for i, inst in opts.extraInstances do
			if typeof (inst) ~= "Instance" then
				return false, `extraInstances[{i}] must be an Instance, got {typeof (inst)}`
			end
		end
	end

	if opts.decompileIgnore then
		if type (opts.decompileIgnore) ~= "table" then return false, "decompileIgnore must be a table" end
	end

	-- Validate logical conflicts
	if opts.noScripts and opts.mode == "scripts" then return false, 'Cannot use noScripts=true with mode="scripts"' end

	if opts.callback and opts.filePath and opts.filePath ~= "output" then
		return false, "Cannot specify both callback and filePath"
	end

	if opts.binary then return false, "Binary format not yet implemented. Use XML format (binary = false)" end

	-- Warn about risky options
	if opts.sharedStringOverwrite then
		warn ("[USSI] WARNING: sharedStringOverwrite is enabled. This may corrupt the file if SharedStrings are reused!")
	end

	return true, nil
end

-- Determines file extension based on options
local function getFileExtension (opts: Types.Options): string
	if opts.binary then
		return if opts.isModel or opts.object then ".rbxm" else ".rbxl"
	else
		return if opts.isModel or opts.object then ".rbxmx" else ".rbxlx"
	end
end

--[=[
	Saves Roblox game or model to file

	Main entry point for save instance operations. Supports both XML (.rbxlx/.rbxmx)
	and binary (.rbxl/.rbxm) formats with comprehensive options for customization.

	@param userOptions Types.Options? -- Configuration options
	@return Promise<Types.Result> -- Operation result with statistics
]=]
local function saveInstance (userOptions: Types.Options?): Promise.TypedPromise<Types.Result>
	return Promise.defer (function (resolve)
		local startTime = os.clock ()

		-- Merge and validate options
		local opts = mergeOptions (userOptions)
		local valid, error = validateOptions (opts)

		-- Configure logger based on debug mode
		if opts.debugMode then Logger.setConfig ({ minLevel = "DEBUG" }) end

		if not valid then
			Logger.error ("Validation failed: %s", error)
			return resolve ({
				success = false,
				error = error,
			} :: Types.Result)
		end

		-- Show status if enabled
		if opts.showStatus then
			Logger.info ("Starting save operation (mode: %s, executor: %s)", opts.mode, Executor.info.name)
		end

		-- Anti-idle system: prevent player from being kicked during long saves
		local antiIdleConnection
		if opts.antiIdle then
			local VirtualUser = Services.getService ("VirtualUser")
			if VirtualUser then
				antiIdleConnection = game:GetService ("Players").LocalPlayer.Idled:Connect (
					function ()
						(VirtualUser :: any):CaptureController () (VirtualUser :: any):ClickButton2 (Vector2.new ())
					end
				)
				if opts.showStatus then Logger.info ("Anti-idle enabled") end
			end
		end

		-- Safe mode: kick player before saving to prevent detection
		local shouldKick = opts.safeMode
		if shouldKick and opts.showStatus then Logger.info ("Safe mode enabled - player will be kicked before save") end

		-- Check for binary format
		if opts.binary then
			Logger.error ("Binary format not yet implemented")
			if antiIdleConnection then antiIdleConnection:Disconnect () end
			return resolve ({
				success = false,
				error = "Binary format not yet implemented. Use XML format (binary = false)",
			} :: Types.Result)
		end

		-- Determine if saving model or place
		local isModel = opts.isModel or opts.object ~= nil

		-- Generate XML document
		XML.Document
			.generate ({
				mode = opts.mode,
				object = opts.object,
				isModel = isModel,
				nilInstances = opts.nilInstances,
				extraInstances = opts.extraInstances,
				ignoreNotArchivable = opts.ignoreNotArchivable,
				removePlayerCharacters = opts.removePlayerCharacters,
				ignoreProperties = opts.ignoreProperties,
				ignoreDefaultProperties = opts.ignoreDefaultProperties,
				ignoreSpecialProperties = opts.ignoreSpecialProperties,
				ignoreNonScriptProperties = opts.ignoreNonScriptProperties,
				saveNotCreatable = opts.saveNotCreatable,
				ignoreDefaultPlayerScripts = opts.ignoreDefaultPlayerScripts,
				isolateLocalPlayer = opts.isolateLocalPlayer,
				isolateStarterPlayer = opts.isolateStarterPlayer,
				isolateLocalPlayerCharacter = opts.isolateLocalPlayerCharacter,
			})
			:andThen (function (result)
				if not result.success then
					Logger.error ("XML generation failed: %s", result.error)
					if antiIdleConnection then antiIdleConnection:Disconnect () end
					return resolve (result)
				end

				local xml = result.data
				local elapsed = os.clock () - startTime

				-- Update statistics
				if result.stats then result.stats.timeElapsed = elapsed end

				-- Cleanup function for all exit paths
				local function cleanup ()
					-- Disconnect anti-idle
					if antiIdleConnection then antiIdleConnection:Disconnect () end

					-- Safe mode: kick player
					if shouldKick then
						local Players = Services.getService ("Players")
						if Players then
							local LocalPlayer = (Players :: Players).LocalPlayer
							if LocalPlayer then
								task.defer (function () LocalPlayer:Kick ("Save completed - kicked for safety") end)
							end
						end
					end

					-- Shutdown game if requested
					if opts.shutdownWhenDone then
						task.defer (function ()
							task.wait (0.5) -- Brief delay to ensure file is written
							game:Shutdown ()
						end)
					end
				end

				-- Handle callback mode
				if opts.callback then
					opts.callback (xml)

					if opts.showStatus then
						Logger.info (
							"Save completed in %.2fs (%d instances)",
							elapsed,
							result.stats and result.stats.instancesProcessed or 0
						)
					end

					cleanup ()
					return resolve (result)
				end

				-- Write to file
				local extension = getFileExtension (opts)
				local filePath = opts.filePath .. extension

				Executor.writeFile (filePath, xml)
					:andThen (function (writeResult)
						if writeResult.success then
							if opts.showStatus then
								Logger.info (
									"Saved to %s (%.2fs, %d instances)",
									filePath,
									elapsed,
									result.stats and result.stats.instancesProcessed or 0
								)
							end

							result.filePath = filePath
							cleanup ()
							resolve (result)
						else
							Logger.error ("Failed to write file: %s", writeResult.error)
							cleanup ()
							resolve ({
								success = false,
								error = `Failed to write file: {writeResult.error}`,
							} :: Types.Result)
						end
					end)
					:catch (function (err)
						Logger.error ("File write error: %s", tostring (err))
						cleanup ()
						resolve ({
							success = false,
							error = `File write error: {tostring (err)}`,
						} :: Types.Result)
					end)
			end)
			:catch (function (err)
				Logger.error ("Generation error: %s", tostring (err))
				if antiIdleConnection then antiIdleConnection:Disconnect () end
				resolve ({
					success = false,
					error = `Generation error: {tostring (err)}`,
				} :: Types.Result)
			end)
	end)
end

--[=[
	Gets executor information

	Returns information about the detected executor environment.

	@return Types.ExecutorInfo -- Executor name, version, and detection status
]=]
local function getExecutorInfo (): Types.ExecutorInfo
	return {
		name = Executor.info.name,
		version = Executor.info.version,
		detected = Executor.info.detected,
	}
end

--[=[
	Clears internal caches

	Resets ALL caches: scripts, shared strings, referents, and services.
	Useful between multiple save operations to free memory.
]=]
local function clearCache (): ()
	Scripts.clearCache ()
	SharedStrings.clear ()
	Referent.clear ()
	Services.clearCache ()
end

--[=[
	Gets cache statistics

	Returns comprehensive information about all cache states.

	@return table -- All cache statistics
]=]
local function getCacheStats (): {
	scriptCacheSize: number,
	sharedStringsCount: number,
	referentCount: number,
	serviceCacheSize: number,
}
	return {
		scriptCacheSize = Scripts.getCacheStats (),
		sharedStringsCount = SharedStrings.count (),
		referentCount = Referent.count (),
		serviceCacheSize = Services.getCacheSize (),
	}
end

return {
	saveInstance = saveInstance,
	getExecutorInfo = getExecutorInfo,
	clearCache = clearCache,
	getCacheStats = getCacheStats,

	-- Version information
	VERSION = "2.0.0",
	BUILD_DATE = "2025-01-20",
}
