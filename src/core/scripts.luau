--[[
	Scripts - Decompile and cache scripts
	@author Aspecter | @version 2.0.0
]]

local Promise = require("@packages/promise")
local Types = require("@types")
local Executor = require("@utilities/executor")

export type Options = {
	mode: Types.SaveMode,
	noScripts: boolean,
	scriptCache: boolean,
	timeout: number?,
	saveBytecode: boolean,
	decompileIgnore: { [string]: any }?,
}

export type ScriptData = {
	source: string?,
	bytecode: string?,
	hash: string?,
	cached: boolean,
}

local cache: { [string]: string } = {}

local function shouldDecompile(scr: LuaSourceContainer, opts: Options): boolean
	if opts.noScripts then
		return false
	end

	if opts.mode == "optimized" then
		local source = (scr :: any).Source
		if source and #source > 0 then
			return false
		end
	end

	local ignoreList = opts.decompileIgnore
	if ignoreList then
		local fullName = scr:GetFullName()
		if ignoreList[fullName] then
			return false
		end
	end

	return true
end

local function decompile(scr: LuaSourceContainer): Promise.TypedPromise<string?>
	return Promise.new(function(resolve)
		local source = (scr :: any).Source
		if source and #source > 0 then
			resolve(source)
		else
			resolve("-- Decompilation not implemented")
		end
	end)
end

local function process(scr: LuaSourceContainer, opts: Options): Promise.TypedPromise<ScriptData>
	return Promise.new(function(resolve)
		local data: ScriptData = {
			source = nil,
			bytecode = nil,
			hash = nil,
			cached = false,
		}

		if opts.scriptCache or opts.saveBytecode then
			local result = Executor.getScriptHash(scr :: any):expect()
			if result.success and result.data then
				data.hash = result.data
			end
		end

		if opts.scriptCache and data.hash then
			local cached = cache[data.hash]
			if cached then
				data.source = cached
				data.cached = true
				return resolve(data)
			end
		end

		if opts.saveBytecode then
			local result = Executor.getScriptBytecode(scr :: any):expect()
			if result.success and result.data then
				data.bytecode = result.data
			end
		end

		if shouldDecompile(scr, opts) then
			decompile(scr)
				:andThen(function(source)
					data.source = source

					if opts.scriptCache and data.hash and source then
						cache[data.hash] = source
					end

					resolve(data)
				end)
				:catch(function(error)
					local errorMsg = tostring(error)
					data.source = `-- Decompilation failed: {errorMsg}`
					resolve(data)
				end)
		else
			local source = (scr :: any).Source
			data.source = source
			resolve(data)
		end
	end)
end

local function clearCache(): ()
	table.clear(cache)
end

local function getCacheStats(): (number, number)
	local size = 0
	for _ in cache do
		size += 1
	end
	return size, size
end

return {
	process = process,
	clearCache = clearCache,
	getCacheStats = getCacheStats,
}
