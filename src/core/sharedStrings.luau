--[[
	SharedStrings - String deduplication
	@author Aspecter | @version 2.0.0
]]

local Executor = require ("@utilities/executor")
local Types = require ("@types")

export type SharedStringMap = Types.SharedStringMap

local strs: SharedStringMap = {}
local nextId: number = 1e15

local function get (str: string): string
	local existing = strs[str]
	if existing ~= nil then return existing end

	local result = Executor.base64Encode (tostring (nextId))

	if not result.success or not result.data then error (result.error or "Base64 encoding failed") end

	local encoded = result.data
	strs[str] = encoded
	nextId += 1

	return encoded
end

local function getAll (): SharedStringMap return table.clone (strs) end

local function has (str: string): boolean return strs[str] ~= nil end

local function count (): number
	local total = 0
	for _ in strs do
		total += 1
	end
	return total
end

local function clear (): ()
	table.clear (strs)
	nextId = 1e15
end

return {
	get = get,
	getAll = getAll,
	has = has,
	count = count,
	clear = clear,
}
