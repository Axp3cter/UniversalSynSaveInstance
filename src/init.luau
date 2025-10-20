--[[
	UniversalSynSaveInstance (USSI) - Main Entry Point

	Comprehensive save instance system for Roblox with XML format support.
	Provides both headless and UI-based operation modes.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

-- Type definitions
local Types = require("@types")

-- Asynchronous operations
local Promise = require("@packages/promise")

-- Core modules
local XML = require("@core/xml")
local Scripts = require("@core/scripts")
local Statistics = require("@utilities/statistics")
local Executor = require("@utilities/executor")

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
local function mergeOptions(userOpts: Types.Options?): Types.Options
	if not userOpts then
		return DEFAULT_OPTIONS
	end

	local merged = table.clone(DEFAULT_OPTIONS) :: any

	for key, value in userOpts :: any do
		merged[key] = value
	end

	return merged :: Types.Options
end

-- Validates options
local function validateOptions(opts: Types.Options): (boolean, string?)
	-- Validate mode
	if opts.mode and opts.mode ~= "full" and opts.mode ~= "optimized" and opts.mode ~= "scripts" then
		return false, `Invalid mode: {opts.mode}`
	end

	-- Validate timeout
	if opts.timeout and type(opts.timeout) ~= "number" then
		return false, "Timeout must be a number"
	end

	-- Validate object if provided
	if opts.object and typeof(opts.object) ~= "Instance" then
		return false, "Object must be an Instance"
	end

	return true, nil
end

-- Determines file extension based on options
local function getFileExtension(opts: Types.Options): string
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
local function saveInstance(userOptions: Types.Options?): Promise.TypedPromise<Types.Result>
	return Promise.defer(function(resolve)
		local startTime = os.clock()

		-- Merge and validate options
		local opts = mergeOptions(userOptions)
		local valid, error = validateOptions(opts)

		if not valid then
			return resolve({
				success = false,
				error = error,
			} :: Types.Result)
		end

		-- Show status if enabled
		if opts.showStatus then
			print(`[USSI] Starting save operation (mode: {opts.mode})...`)
		end

		-- Check for binary format
		if opts.binary then
			return resolve({
				success = false,
				error = "Binary format not yet implemented. Use XML format (binary = false)",
			} :: Types.Result)
		end

		-- Determine if saving model or place
		local isModel = opts.isModel or opts.object ~= nil

		-- Generate XML document
		XML.Document
			.generate({
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
			})
			:andThen(function(result)
				if not result.success then
					return resolve(result)
				end

				local xml = result.data
				local elapsed = os.clock() - startTime

				-- Update statistics
				if result.stats then
					result.stats.timeElapsed = elapsed
				end

				-- Handle callback mode
				if opts.callback then
					opts.callback(xml)

					if opts.showStatus then
						print(
							`[USSI] Save completed in {string.format("%.2f", elapsed)}s ({result.stats and result.stats.instancesProcessed or 0} instances)`
						)
					end

					return resolve(result)
				end

				-- Write to file
				local extension = getFileExtension(opts)
				local filePath = opts.filePath .. extension

				Executor
					.writeFile(filePath, xml)
					:andThen(function(writeResult)
						if writeResult.success then
							if opts.showStatus then
								print(
									`[USSI] Saved to {filePath} ({string.format("%.2f", elapsed)}s, {result.stats and result.stats.instancesProcessed or 0} instances)`
								)
							end

							result.filePath = filePath
							resolve(result)
						else
							resolve({
								success = false,
								error = `Failed to write file: {writeResult.error}`,
							} :: Types.Result)
						end
					end)
					:catch(function(err)
						resolve({
							success = false,
							error = `File write error: {tostring(err)}`,
						} :: Types.Result)
					end)
			end)
			:catch(function(err)
				resolve({
					success = false,
					error = `Generation error: {tostring(err)}`,
				} :: Types.Result)
			end)
	end)
end

--[=[
	Gets executor information

	Returns information about the detected executor environment.

	@return Types.ExecutorInfo -- Executor name, version, and detection status
]=]
local function getExecutorInfo(): Types.ExecutorInfo
	return {
		name = Executor.info.name,
		version = Executor.info.version,
		detected = Executor.info.detected,
	}
end

--[=[
	Clears internal caches

	Resets script cache and shared string deduplication tables.
	Useful between multiple save operations to free memory.
]=]
local function clearCache(): ()
	Scripts.clearCache()
	-- SharedStrings and Referent are cleared automatically during generation
end

--[=[
	Gets cache statistics

	Returns information about current cache state.

	@return {scriptCacheSize: number} -- Cache statistics
]=]
local function getCacheStats(): { scriptCacheSize: number }
	local size, _ = Scripts.getCacheStats()
	return {
		scriptCacheSize = size,
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
