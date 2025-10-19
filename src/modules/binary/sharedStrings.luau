--[[
	Shared Strings

	@author Aspecter
	@version 1.0.0
]]

local Executor = require("@utilities/executor")

export type SharedStringMap = { [string]: string }

-- State
local strings: SharedStringMap = {}
local nextId = 1e15

-- Gets or creates shared string identifier
local function getId(str: string): string
	local existing = strings[str]
	if existing then
		return existing
	end

	-- Generate base64 identifier
	local result = Executor.base64Encode(tostring(nextId)):expect()

	if not result.success then
		error(`Failed to encode shared string ID: {result.error}`)
	end

	local id = result.data :: string
	strings[str] = id
	nextId += 1

	return id
end

-- Gets all shared strings
local function getAll(): SharedStringMap
	return strings
end

-- Clears all shared strings
local function clear(): ()
	table.clear(strings)
	nextId = 1e15
end

-- Gets count
local function getCount(): number
	local count = 0
	for _ in strings do
		count += 1
	end
	return count
end

-- Checks if string exists
local function has(str: string): boolean
	return strings[str] ~= nil
end

return {
	getId = getId,
	getAll = getAll,
	clear = clear,
	getCount = getCount,
	has = has,
}
