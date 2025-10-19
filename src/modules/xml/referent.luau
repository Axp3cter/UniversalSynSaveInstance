--[[
	XML Referent Tracker

	@author Aspecter
	@version 1.0.0
]]

local Executor = require("@utilities/executor")

export type ReferentMap = { [Instance]: number }

-- State
local referents: ReferentMap = {}
local size = 0

-- Gets or creates referent ID
local function getRef(instance: Instance): number
	local ref = referents[instance]
	if ref then
		return ref
	end

	ref = size
	referents[instance] = ref
	size += 1

	return ref
end

-- Generates RBX-format referent string
local function generateReferent(instance: Instance): string
	local id = getRef(instance)
	local encoded = Executor.base64Encode(tostring(id)):expect()

	if not encoded.success then
		error(`Failed to encode referent: {encoded.error}`)
	end

	return `RBX{encoded.data}`
end

-- Clears all referents
local function clear(): ()
	table.clear(referents)
	size = 0
end

-- Gets referent count
local function getCount(): number
	return size
end

return {
	getRef = getRef,
	generateReferent = generateReferent,
	clear = clear,
	getCount = getCount,
}
