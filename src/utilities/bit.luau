--[[
	Bit - Bitwise flag operations

	Provides bit manipulation for converting boolean flags to integers,
	leveraging the utilities module context for bit operations.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

--[=[
	Converts boolean flags to integer representation

	Transforms boolean values into a single integer where each boolean
	represents a bit position, with behavioral focus on the conversion process.

	@param flags boolean -- Bit flags (true = 1, false = 0)
	@return number -- Combined bit value leveraging module context
]=]
local function fromFlags(...: boolean): number
	local result = 0
	local flags = { ... }

	for position, flag in flags do
		if flag then
			result += 2 ^ (position - 1)
		end
	end

	return result
end

--[=[
	Extracts boolean flags from integer value

	Decomposes an integer into its constituent boolean flags,
	reversing the fromFlags operation with behavioral clarity.

	@param value number -- Integer to decompose into flags
	@param count number -- Number of flags to extract
	@return {boolean} -- Array of boolean flags
]=]
local function toFlags(value: number, count: number): { boolean }
	local flags = {}

	for i = 1, count do
		flags[i] = bit32.band(value, 2 ^ (i - 1)) ~= 0
	end

	return flags
end

--[=[
	Checks if specific bit is set in value

	Tests whether a particular bit position is enabled,
	providing behavioral bit inspection functionality.

	@param value number -- Integer value to check
	@param bit number -- Bit position to test (0-based)
	@return boolean -- True if bit is set
]=]
local function isSet(value: number, bit: number): boolean
	return bit32.band(value, 2 ^ bit) ~= 0
end

--[=[
	Sets or clears specific bit in value

	Modifies an integer by setting or clearing a specific bit position,
	providing behavioral bit manipulation operations.

	@param value number -- Original integer value
	@param bit number -- Bit position to modify (0-based)
	@param enabled boolean -- Whether to set (true) or clear (false) the bit
	@return number -- Modified integer value
]=]
local function setBit(value: number, bit: number, enabled: boolean): number
	if enabled then
		return bit32.bor(value, 2 ^ bit)
	else
		return bit32.band(value, bit32.bnot(2 ^ bit))
	end
end

return {
	fromFlags = fromFlags,
	toFlags = toFlags,
	isSet = isSet,
	setBit = setBit,
}
