--[[
        Bit - Bitwise flag operations

        Provides bit manipulation for converting boolean flags to integers,
        leveraging the utilities module context for bit operations.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local BitBuffer = require("@packages/bitBuffer")

type BitBufferModule = typeof(BitBuffer)
export type BitBuffer = BitBufferModule.BitBuffer

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

--[=[
        Creates a new BitBuffer instance

        Provides direct access to the BitBuffer package constructor, ensuring
        consumers can create buffers without requiring the package manually.

        @param sizeInBits number? -- Optional initial size for the buffer (in bits)
        @return BitBuffer -- Newly created BitBuffer instance
]=]
local function newBuffer(sizeInBits: number?): BitBuffer
        return BitBuffer.new(sizeInBits)
end

--[=[
        Creates BitBuffer from raw string data

        @param input string -- Binary string source
        @return BitBuffer -- BitBuffer populated from string contents
]=]
local function bufferFromString(input: string): BitBuffer
        return BitBuffer.FromString(input)
end

--[=[
        Creates BitBuffer from Base64 string

        @param input string -- Base64 encoded payload
        @return BitBuffer -- BitBuffer populated from Base64 contents
]=]
local function bufferFromBase64(input: string): BitBuffer
        return BitBuffer.FromBase64(input)
end

--[=[
        Creates BitBuffer from Base91 string

        @param input string -- Base91 encoded payload
        @return BitBuffer -- BitBuffer populated from Base91 contents
]=]
local function bufferFromBase91(input: string): BitBuffer
        return BitBuffer.FromBase91(input)
end

--[=[
        Creates BitBuffer from Base128 string

        @param input string -- Base128 encoded payload
        @return BitBuffer -- BitBuffer populated from Base128 contents
]=]
local function bufferFromBase128(input: string): BitBuffer
        return BitBuffer.FromBase128(input)
end

--[=[
        Checks if value is a BitBuffer instance

        @param value any -- Value to inspect
        @return boolean -- True if value is BitBuffer instance
]=]
local function isBuffer(value: any): boolean
        return BitBuffer.is(value)
end

return {
        fromFlags = fromFlags,
        toFlags = toFlags,
        isSet = isSet,
        setBit = setBit,
        newBuffer = newBuffer,
        bufferFromString = bufferFromString,
        bufferFromBase64 = bufferFromBase64,
        bufferFromBase91 = bufferFromBase91,
        bufferFromBase128 = bufferFromBase128,
        isBuffer = isBuffer,
}
