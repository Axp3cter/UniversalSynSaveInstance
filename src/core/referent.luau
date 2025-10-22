--[[
	Referent - Sequential IDs for instances
	@author Aspecter | @version 2.0.0
]]

local Executor = require ("@utilities/executor")
local Types = require ("@types")

export type ReferentMap = Types.ReferentMap

local refs: ReferentMap = {}
local nextId: number = 0

local function get (inst: Instance): number
	local existing = refs[inst]
	if existing ~= nil then return existing end

	local id = nextId
	refs[inst] = id
	nextId += 1
	return id
end

local function rbx (inst: Instance): string
	local id = get (inst)
	local result = Executor.base64Encode (tostring (id))

	if not result.success or not result.data then error (result.error or "Base64 encoding failed") end

	return `RBX{result.data}`
end

local function clear (): ()
	table.clear (refs)
	nextId = 0
end

local function count (): number return nextId end

return {
	get = get,
	rbx = rbx,
	clear = clear,
	count = count,
}
