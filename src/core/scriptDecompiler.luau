--[[
	Script Decompiler - Decompilation with LinkedSource and caching

	Provides comprehensive script source extraction:
	1. LinkedSource asset downloading from roproxy
	2. Script bytecode caching with hashing
	3. Decompiler integration with timeout handling
	4. Bytecode saving for later decompilation

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local Executor = require ("@utilities/executor")

export type DecompileOptions = {
	timeout: number, -- Timeout in seconds (default 10, -1 to disable)
	saveBytes: boolean, -- Save bytecode in output (default false)
	useCache: boolean, -- Use bytecode cache (default true)
	ignoreList: { [Instance]: boolean }?, -- Instances to ignore
	jobless: boolean, -- Only use cached, don't decompile new (default false)
}

export type DecompileResult = {
	success: boolean,
	source: string?,
	bytecode: string?,
	cached: boolean,
	linkedSource: string?,
	error: string?,
}

-- Global script cache (persists across saves)
local scriptCache: { [string]: string } = {}

-- Try to restore from getgenv
do
	local genvResult = Executor.getgenv ()
	if genvResult.success and genvResult.data then
		local genv = genvResult.data
		if genv.scriptcache and type (genv.scriptcache) == "table" then scriptCache = genv.scriptcache end
	end
end

--[=[
	Constructs timeout handler for decompilation

	@param timeout number -- Timeout in seconds
	@param fn function -- Function to call
	@param timeoutRet string -- Return value on timeout
	@return function -- Wrapped function
]=]
local function constructTimeoutHandler (timeout: number, fn: (any) -> any, timeoutRet: string): (any) -> (boolean, any)
	if timeout < 0 then
		-- No timeout
		return function (script: any): (boolean, any) return pcall (fn, script) end
	end

	return function (script: any): (boolean, any)
		local thread = coroutine.running ()
		local timeoutThread, isCancelled

		timeoutThread = task.delay (timeout, function ()
			isCancelled = true
			coroutine.resume (thread, nil, timeoutRet)
		end)

		task.spawn (function ()
			local ok, result = pcall (fn, script)

			if isCancelled then return end

			task.cancel (timeoutThread)

			while coroutine.status (thread) ~= "suspended" do
				task.wait ()
			end

			coroutine.resume (thread, ok, result)
		end)

		return coroutine.yield ()
	end
end

--[=[
	Filters LinkedSource content to verify it's valid Lua

	@param source string -- Source code
	@return boolean -- True if valid
]=]
local function filterLinkedSource (source: string): boolean
	-- Basic validation: check if it looks like Lua code
	if #source == 0 then return false end

	-- Check for common Lua patterns
	local hasLuaKeywords = string.find (source, "local%s")
		or string.find (source, "function%s")
		or string.find (source, "return%s")
		or string.find (source, "if%s")
		or string.find (source, "end%s")

	return hasLuaKeywords ~= nil
end

--[=[
	Downloads LinkedSource from asset delivery

	@param linkedSourceUrl string -- Full LinkedSource URL
	@param cache table -- Script cache for storing
	@return (boolean, string?) -- Success and source code
]=]
local function downloadLinkedSource (linkedSourceUrl: string, cache: { [string]: string }): (boolean, string?)
	-- Extract asset ID or hash from URL
	-- Format: "rbxassetid://123456" or "rbxassetid://0&hash=abc123"
	local assetId = string.match (linkedSourceUrl, "%w+$")
	if not assetId then return false, nil end

	-- Check cache first
	if cache[assetId] then return true, cache[assetId] end

	-- Determine asset type (hash vs id)
	local assetType = string.find (assetId, "%a") and "hash" or "id"
	local assetParam = assetType .. "=" .. assetId

	-- Download from roproxy
	local ok, source = pcall (
		function () return game:HttpGet ("https://assetdelivery.roproxy.com/v1/asset/?" .. assetParam) end
	)

	if ok and source and filterLinkedSource (source) then
		-- Cache it
		cache[assetId] = source
		return true, source
	end

	return false, nil
end

--[=[
	Gets script bytecode with timeout

	@param script LuaSourceContainer
	@param timeout number -- Timeout in seconds
	@return (boolean, string?) -- Success and bytecode
]=]
local function getBytecodeWithTimeout (script: LuaSourceContainer, timeout: number): (boolean, string?)
	if not Executor.api.getscriptbytecode then return false, nil end

	local handler = constructTimeoutHandler (timeout, Executor.api.getscriptbytecode, "Bytecode timeout")
	return handler (script)
end

--[=[
	Decompiles script with full feature support

	@param script LuaSourceContainer -- Script to decompile
	@param options DecompileOptions -- Decompile options
	@return DecompileResult -- Decompilation result
]=]
local function decompileScript (script: LuaSourceContainer, options: DecompileOptions): DecompileResult
	local result: DecompileResult = {
		success = false,
		source = nil,
		bytecode = nil,
		cached = false,
		linkedSource = nil,
		error = nil,
	}

	-- Check ignore list
	if options.ignoreList and options.ignoreList[script] then
		result.source = "-- Ignored"
		result.success = true
		return result
	end

	-- Try LinkedSource first
	local linkedSourceUrl = script.LinkedSource
	local hasLinkedSource = linkedSourceUrl ~= ""

	if hasLinkedSource then
		local ok, source = downloadLinkedSource (linkedSourceUrl, scriptCache)
		if ok and source then
			result.success = true
			result.source = source
			result.linkedSource = linkedSourceUrl
			result.cached = scriptCache[string.match (linkedSourceUrl, "%w+$") or ""] ~= nil
			return result
		end

		-- LinkedSource download failed
		result.error = "Failed to download LinkedSource: " .. linkedSourceUrl
	end

	-- Check if we should skip decompilation (jobless mode)
	if options.jobless then
		result.source = "-- Not found in cache (jobless mode)"
		result.success = true
		return result
	end

	-- Check for server-side scripts (can't decompile)
	local isLocalScript = script:IsA ("LocalScript")
	local isScript = script:IsA ("Script")

	if isLocalScript and script.RunContext == Enum.RunContext.Server then
		result.source = "-- [FilteringEnabled] Server Scripts are IMPOSSIBLE to save"
		result.success = true
		return result
	elseif isScript and script.RunContext ~= Enum.RunContext.Client then
		result.source = "-- [FilteringEnabled] Server Scripts are IMPOSSIBLE to save"
		result.success = true
		return result
	end

	-- Try getting bytecode (for caching and optional saving)
	if options.useCache or options.saveBytes then
		local ok, bytecode = getBytecodeWithTimeout (script, 3) -- 3 second timeout for bytecode

		if ok and bytecode and bytecode ~= "" then
			result.bytecode = bytecode

			-- Check cache by bytecode hash
			local hashResult = Executor.getScriptHash (script)
			if hashResult.success and hashResult.data then
				local hash = hashResult.data
				if scriptCache[hash] then
					result.source = scriptCache[hash]
					result.success = true
					result.cached = true
					return result
				end
			end
		end
	end

	-- Try decompilation
	if not Executor.api.decompile then
		result.source = "-- Decompiler not available"
		result.success = true
		return result
	end

	local decompileHandler =
		constructTimeoutHandler (options.timeout, Executor.api.decompile, "-- Decompiler timed out")
	local ok, source = decompileHandler (script)

	if ok and source and source ~= "" and not string.find (source, "timeout", 1, true) then
		result.source = source
		result.success = true

		-- Cache by hash if we have bytecode
		local hashResult = Executor.getScriptHash (script)
		if hashResult.success and hashResult.data then scriptCache[hashResult.data] = source end

		return result
	end

	-- Decompilation failed
	result.source = "-- Decompilation failed: " .. tostring (source or "unknown error")
	result.error = "Decompilation failed"
	result.success = false

	return result
end

--[=[
	Formats decompilation result for saving

	Adds header comments and optional bytecode.

	@param result DecompileResult
	@param scriptPath string -- Full path to script
	@return string -- Formatted source
]=]
local function formatDecompileResult (result: DecompileResult, scriptPath: string): string
	local lines = {}

	-- Header
	table.insert (lines, "-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw")
	table.insert (lines, "")

	-- LinkedSource info
	if result.linkedSource then
		local assetId = string.match (result.linkedSource, "%w+$")
		local assetType = string.find (assetId or "", "%a") and "hash" or "id"
		table.insert (
			lines,
			`-- Original Source: https://assetdelivery.roblox.com/v1/asset/?{assetType}={assetId or result.linkedSource}`
		)
		table.insert (lines, "")
	end

	-- Bytecode
	if result.bytecode then
		local encodeResult = Executor.encodeBase64 (result.bytecode)
		if encodeResult.success and encodeResult.data then
			table.insert (lines, "-- Bytecode (Base64):")
			table.insert (lines, "-- " .. encodeResult.data)
			table.insert (lines, "")
		end
	end

	-- Source
	table.insert (lines, result.source or "-- No source available")

	return table.concat (lines, "\n")
end

--[=[
	Clears script cache

	Useful for testing or memory management
]=]
local function clearCache (): ()
	table.clear (scriptCache)

	-- Clear from getgenv too
	local genvResult = Executor.getgenv ()
	if genvResult.success and genvResult.data then genvResult.data.scriptcache = nil end
end

--[=[
	Persists cache to getgenv for future sessions
]=]
local function persistCache (): ()
	local genvResult = Executor.getgenv ()
	if genvResult.success and genvResult.data then genvResult.data.scriptcache = scriptCache end
end

return {
	decompileScript = decompileScript,
	formatDecompileResult = formatDecompileResult,
	downloadLinkedSource = downloadLinkedSource,
	clearCache = clearCache,
	persistCache = persistCache,
	scriptCache = scriptCache,
}
