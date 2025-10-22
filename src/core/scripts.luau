--[[
	Scripts - Decompile and cache scripts
	@author Aspecter | @version 3.0.0
]]

local Executor = require ("@utilities/executor")
local Types = require ("@types")

export type Options = {
	mode: Types.SaveMode,
	noScripts: boolean,
	scriptCache: boolean,
	timeout: number?,
	saveBytecode: boolean,
	decompileIgnore: { [string]: any }?,
	decompileJobless: boolean?,
}

export type ScriptData = {
	source: string?,
	bytecode: string?,
	hash: string?,
	cached: boolean,
	decompiled: boolean,
}

local cache: { [string]: string } = {}

local function shouldDecompile (scr: LuaSourceContainer, opts: Options): boolean
	if opts.noScripts then return false end

	-- In decompileJobless mode, skip decompilation if Source exists
	if opts.decompileJobless then
		local source = (scr :: any).Source
		if source and #source > 0 then return false end
	end

	if opts.mode == "optimized" then
		local source = (scr :: any).Source
		if source and #source > 0 then return false end
	end

	local ignoreList = opts.decompileIgnore
	if ignoreList then
		local fullName = scr:GetFullName ()
		if ignoreList[fullName] then return false end
	end

	return true
end

--[=[
	Attempts to decompile script using available decompilers

	Tries decompilers in order:
	1. decompile() - Standard sUNC function
	2. syn_decompile() - Synapse X compatibility

	@param scr LuaSourceContainer -- Script to decompile
	@param timeout number? -- Optional timeout in seconds
	@return string? -- Decompiled source or nil
]=]
local function decompile (scr: LuaSourceContainer, timeout: number?): string?
	-- Check for existing source first
	local source = (scr :: any).Source
	if source and #source > 0 then return source end

	-- Try to get bytecode first
	local bytecodeResult = Executor.getScriptBytecode (scr :: any)
	if not bytecodeResult.success or not bytecodeResult.data then return nil end

	-- Check for decompile function
	local decompileFn = Executor.api.decompile or syn_decompile

	if not decompileFn then return nil end

	-- Attempt decompilation with timeout
	local startTime = os.clock ()
	local timeoutDuration = timeout or 10

	local success, result = pcall (function ()
		-- Check timeout
		if os.clock () - startTime > timeoutDuration then error ("Decompilation timeout") end

		return decompileFn (scr)
	end)

	if success and result and type (result) == "string" and #result > 0 then return result end

	return nil
end

local function process (scr: LuaSourceContainer, opts: Options): ScriptData
	local data: ScriptData = {
		source = nil,
		bytecode = nil,
		hash = nil,
		cached = false,
		decompiled = false,
	}

	-- Get script hash for caching
	if opts.scriptCache or opts.saveBytecode then
		local result = Executor.getScriptHash (scr :: any)
		if result.success and result.data then data.hash = result.data end
	end

	-- Check cache
	if opts.scriptCache and data.hash then
		local cached = cache[data.hash]
		if cached then
			data.source = cached
			data.cached = true
			return data
		end
	end

	-- Get bytecode if requested
	if opts.saveBytecode then
		local result = Executor.getScriptBytecode (scr :: any)
		if result.success and result.data then data.bytecode = result.data end
	end

	-- Decompile if needed
	if shouldDecompile (scr, opts) then
		local source = decompile (scr, opts.timeout)

		if source then
			data.source = source
			data.decompiled = true

			-- Cache the result
			if opts.scriptCache and data.hash then cache[data.hash] = source end
		else
			-- Fallback messages based on availability
			if not Executor.hasFunction ("getscriptbytecode") then
				data.source = "-- [No decompiler available]"
			else
				local bytecodeResult = Executor.getScriptBytecode (scr :: any)
				if bytecodeResult.success and bytecodeResult.data then
					data.source = string.format (
						"-- [Decompilation failed]\n-- Bytecode size: %d bytes\n-- Hash: %s",
						#bytecodeResult.data,
						data.hash or "unknown"
					)
				else
					data.source = "-- [Source and bytecode unavailable]"
				end
			end
		end
	else
		-- Just use the .Source property
		local source = (scr :: any).Source
		data.source = source or ""
	end

	return data
end

local function clearCache (): () table.clear (cache) end

local function getCacheStats (): number
	local size = 0
	for _ in cache do
		size += 1
	end
	return size
end

return {
	process = process,
	clearCache = clearCache,
	getCacheStats = getCacheStats,
}
