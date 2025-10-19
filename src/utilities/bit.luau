--[[
	Bit Utilities - Bitwise Operations

	Provides bit manipulation utilities for binary operations.

	@author Aspecter
	@version 1.0.0
]]

--[=[
	Creates integer from boolean bit flags

	Converts boolean values into a single integer where each boolean
	represents a bit position. First argument is bit 0 (LSB).

	@param ... boolean -- Bit flags (true = 1, false = 0)
	@return number -- Combined bit value
]=]
local function fromFlags(...: boolean): number
	local value = 0
	local bits = { ... }

	for i, bit in bits do
		if bit then
			value += 2 ^ (i - 1)
		end
	end

	return value
end

return {
	fromFlags = fromFlags,
}
