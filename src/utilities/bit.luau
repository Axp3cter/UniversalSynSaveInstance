--[[
	Bit Utilities - Bit manipulation and binary operations

	Provides bit32 fallbacks and binary data utilities for executors
	that don't support all bit operations.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

-- Check if bit32.byteswap exists and works
local hasByteswap = bit32.byteswap and pcall (bit32.byteswap, 1)

--[=[
	Fallback implementation of bit32.byteswap for Fluxus and other executors

	@param num number -- 32-bit integer
	@return number -- Byte-swapped value
]=]
local function byteswap_fallback (num: number): number
	local BYTE_SIZE = 8
	local MAX_BYTE_VALUE = 255

	-- Ensure 32-bit range
	num %= bit32.bxor (2, 32)

	-- Extract bytes
	local a = bit32.band (num, MAX_BYTE_VALUE)
	num = bit32.rshift (num, BYTE_SIZE)

	local b = bit32.band (num, MAX_BYTE_VALUE)
	num = bit32.rshift (num, BYTE_SIZE)

	local c = bit32.band (num, MAX_BYTE_VALUE)
	num = bit32.rshift (num, BYTE_SIZE)

	local d = bit32.band (num, MAX_BYTE_VALUE)

	-- Reconstruct in swapped order
	local result = bit32.lshift (bit32.lshift (bit32.lshift (a, BYTE_SIZE) + b, BYTE_SIZE) + c, BYTE_SIZE) + d

	-- Convert to signed 32-bit if needed
	if result > 0x7FFFFFFF then
		result -= 0x100000000
	end

	return result
end

--[=[
	Byte swap operation (with fallback support)

	@param num number -- 32-bit integer
	@return number -- Byte-swapped value
]=]
local function byteswap (num: number): number
	if hasByteswap then return bit32.byteswap (num) end

	return byteswap_fallback (num)
end

--[=[
	Converts bit flags to single value

	Used for Faces, Axes, and other bitfield types

	@param ... boolean -- Bit flags in order
	@return number -- Combined bit value
]=]
local function combineFlags (...: boolean): number
	local value = 0

	for i, flag in { ... } do
		if flag then
			value += 2 ^ (i - 1)
		end
	end

	return value
end

return {
	byteswap = byteswap,
	combineFlags = combineFlags,
	hasByteswap = hasByteswap,
}
