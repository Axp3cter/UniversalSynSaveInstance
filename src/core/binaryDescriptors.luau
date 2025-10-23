--[[
	Binary Descriptors - Binary serialization for all Roblox datatypes

	Provides buffer-based serialization for attributes and binary file formats.
	Each descriptor returns a buffer and its length.

	Based on Roblox binary format specification and attribute serialization.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local AttributeTypes = require ("@constants/attributeTypes")
local Bit = require ("@utilities/bit")
local CFrameRotations = require ("@constants/cframeRotations")
local Executor = require ("@utilities/executor")

export type BinaryDescriptor = (value: any) -> (buffer, number)

--[=[
	Helper for sequence types (NumberSequence, ColorSequence)

	@param raw NumberSequence | ColorSequence
	@param valueFormatter function? -- Optional value formatter
	@param keypointSize number? -- Size per keypoint (default 12)
	@param envelope number? -- Override envelope value
	@return (buffer, number)
]=]
local function serializeSequence (
	raw: NumberSequence | ColorSequence,
	valueFormatter: ((any, buffer, number) -> number)?,
	keypointSize: number?,
	envelope: number?
): (buffer, number)
	local keypoints = raw.Keypoints
	local keypointCount = #keypoints

	local size = keypointSize or 12
	local len = 4 + size * keypointCount

	local b = buffer.create (len)
	local offset = 0

	buffer.writeu32 (b, offset, keypointCount)
	offset += 4

	for _, keypoint in keypoints do
		buffer.writef32 (b, offset, envelope or keypoint.Envelope)
		offset += 4
		buffer.writef32 (b, offset, keypoint.Time)
		offset += 4

		if valueFormatter then
			offset += valueFormatter (keypoint.Value, b, offset)
		else
			buffer.writef32 (b, offset, keypoint.Value)
			offset += 4
		end
	end

	return b, len
end

-- Binary descriptor table
local descriptors: { [string]: BinaryDescriptor } = {}

-- String
descriptors.string = function (raw: string): (buffer, number)
	local len = 4 + #raw
	local b = buffer.create (len)
	buffer.writeu32 (b, 0, #raw)
	buffer.writestring (b, 4, raw)
	return b, len
end

-- Boolean
descriptors.boolean = function (raw: boolean): (buffer, number)
	local b = buffer.create (1)
	buffer.writeu8 (b, 0, if raw then 1 else 0)
	return b, 1
end

-- Number (double)
descriptors.number = function (raw: number): (buffer, number)
	local b = buffer.create (8)
	buffer.writef64 (b, 0, raw)
	return b, 8
end

-- UDim
descriptors.UDim = function (raw: UDim): (buffer, number)
	local b = buffer.create (8)
	buffer.writef32 (b, 0, raw.Scale)
	buffer.writei32 (b, 4, raw.Offset)
	return b, 8
end

-- UDim2
descriptors.UDim2 = function (raw: UDim2): (buffer, number)
	local b = buffer.create (16)
	local xBuf, xLen = descriptors.UDim (raw.X)
	buffer.copy (b, 0, xBuf)
	local yBuf, yLen = descriptors.UDim (raw.Y)
	buffer.copy (b, 8, yBuf)
	return b, 16
end

-- Ray
descriptors.Ray = function (raw: Ray): (buffer, number)
	local b = buffer.create (24)
	local originBuf, originLen = descriptors.Vector3 (raw.Origin)
	buffer.copy (b, 0, originBuf)
	local dirBuf, dirLen = descriptors.Vector3 (raw.Direction)
	buffer.copy (b, 12, dirBuf)
	return b, 24
end

-- Faces
descriptors.Faces = function (raw: Faces): (buffer, number)
	local b = buffer.create (4)
	buffer.writeu32 (b, 0, Bit.combineFlags (raw.Right, raw.Top, raw.Back, raw.Left, raw.Bottom, raw.Front))
	return b, 4
end

-- Axes
descriptors.Axes = function (raw: Axes): (buffer, number)
	local b = buffer.create (4)
	buffer.writeu32 (b, 0, Bit.combineFlags (raw.X, raw.Y, raw.Z))
	return b, 4
end

-- BrickColor
descriptors.BrickColor = function (raw: BrickColor): (buffer, number)
	local b = buffer.create (4)
	buffer.writeu32 (b, 0, raw.Number)
	return b, 4
end

-- Color3
descriptors.Color3 = function (raw: Color3): (buffer, number)
	local b = buffer.create (12)
	buffer.writef32 (b, 0, raw.R)
	buffer.writef32 (b, 4, raw.G)
	buffer.writef32 (b, 8, raw.B)
	return b, 12
end

-- Vector2
descriptors.Vector2 = function (raw: Vector2): (buffer, number)
	local b = buffer.create (8)
	buffer.writef32 (b, 0, raw.X)
	buffer.writef32 (b, 4, raw.Y)
	return b, 8
end

-- Vector3
descriptors.Vector3 = function (raw: Vector3): (buffer, number)
	local b = buffer.create (12)
	buffer.writef32 (b, 0, raw.X)
	buffer.writef32 (b, 4, raw.Y)
	buffer.writef32 (b, 8, raw.Z)
	return b, 12
end

-- Vector2int16
descriptors.Vector2int16 = function (raw: Vector2int16): (buffer, number)
	local b = buffer.create (4)
	buffer.writei16 (b, 0, raw.X)
	buffer.writei16 (b, 2, raw.Y)
	return b, 4
end

-- Vector3int16
descriptors.Vector3int16 = function (raw: Vector3int16): (buffer, number)
	local b = buffer.create (6)
	buffer.writei16 (b, 0, raw.X)
	buffer.writei16 (b, 2, raw.Y)
	buffer.writei16 (b, 4, raw.Z)
	return b, 6
end

-- CFrame
descriptors.CFrame = function (raw: CFrame): (buffer, number)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = raw:GetComponents ()

	-- Check for known rotation matrix
	local rotationKey = string.pack ("<fffffffff", r00, r01, r02, r10, r11, r12, r20, r21, r22)
	local rotationId = CFrameRotations[rotationKey]

	local len = if rotationId then 13 else 49
	local b = buffer.create (len)

	-- Write position
	buffer.writef32 (b, 0, x)
	buffer.writef32 (b, 4, y)
	buffer.writef32 (b, 8, z)

	if rotationId then
		-- Optimized: just rotation ID
		buffer.writeu8 (b, 12, rotationId)
	else
		-- Full rotation matrix
		buffer.writeu8 (b, 12, 0x0)
		buffer.writef32 (b, 13, r00)
		buffer.writef32 (b, 17, r01)
		buffer.writef32 (b, 21, r02)
		buffer.writef32 (b, 25, r10)
		buffer.writef32 (b, 29, r11)
		buffer.writef32 (b, 33, r12)
		buffer.writef32 (b, 37, r20)
		buffer.writef32 (b, 41, r21)
		buffer.writef32 (b, 45, r22)
	end

	return b, len
end

-- EnumItem
descriptors.EnumItem = function (raw: EnumItem): (buffer, number)
	local nameBuf, nameLen = descriptors.string (tostring (raw.EnumType))
	local len = nameLen + 4
	local b = buffer.create (len)
	buffer.copy (b, 0, nameBuf)
	buffer.writeu32 (b, nameLen, raw.Value)
	return b, len
end

-- NumberSequence
descriptors.NumberSequence = function (raw: NumberSequence): (buffer, number)
	return serializeSequence (raw, nil, 12, nil)
end

-- ColorSequence
descriptors.ColorSequence = function (raw: ColorSequence): (buffer, number)
	return serializeSequence (raw, function (color3: Color3, b: buffer, offset: number): number
		local colorBuf, colorLen = descriptors.Color3 (color3)
		buffer.copy (b, offset, colorBuf)
		return 12
	end, 20, 0)
end

-- NumberRange
descriptors.NumberRange = function (raw: NumberRange): (buffer, number)
	local b = buffer.create (8)
	buffer.writef32 (b, 0, raw.Min)
	buffer.writef32 (b, 4, raw.Max)
	return b, 8
end

-- Rect
descriptors.Rect = function (raw: Rect): (buffer, number)
	local b = buffer.create (16)
	local minBuf, minLen = descriptors.Vector2 (raw.Min)
	buffer.copy (b, 0, minBuf)
	local maxBuf, maxLen = descriptors.Vector2 (raw.Max)
	buffer.copy (b, 8, maxBuf)
	return b, 16
end

-- PhysicalProperties
descriptors.PhysicalProperties = function (raw: PhysicalProperties?): (buffer, number)
	local len = if raw then 21 else 1
	local b = buffer.create (len)
	buffer.writeu8 (b, 0, if raw then 1 else 0)

	if raw then
		buffer.writef32 (b, 1, raw.Density)
		buffer.writef32 (b, 5, raw.Friction)
		buffer.writef32 (b, 9, raw.Elasticity)
		buffer.writef32 (b, 13, raw.FrictionWeight)
		buffer.writef32 (b, 17, raw.ElasticityWeight)
	end

	return b, len
end

-- Region3
descriptors.Region3 = function (raw: Region3): (buffer, number)
	local b = buffer.create (24)
	local minBuf, minLen = descriptors.Vector3 (raw.CFrame.Position - raw.Size / 2)
	buffer.copy (b, 0, minBuf)
	local maxBuf, maxLen = descriptors.Vector3 (raw.CFrame.Position + raw.Size / 2)
	buffer.copy (b, 12, maxBuf)
	return b, 24
end

-- Region3int16
descriptors.Region3int16 = function (raw: Region3int16): (buffer, number)
	local b = buffer.create (12)
	local minBuf, minLen = descriptors.Vector3int16 (raw.Min)
	buffer.copy (b, 0, minBuf)
	local maxBuf, maxLen = descriptors.Vector3int16 (raw.Max)
	buffer.copy (b, 6, maxBuf)
	return b, 12
end

-- Font (version-dependent)
descriptors.Font = function (raw: Font): (buffer, number)
	local familyBuf, familyLen = descriptors.string (raw.Family)
	local cachedFaceBuf, cachedFaceLen = descriptors.string ("")

	local len = 3 + familyLen + cachedFaceLen
	local b = buffer.create (len)

	-- Try to read Weight and Style (may not exist in older versions)
	local weightValue = 0
	local styleValue = 0

	local ok, weight = pcall (function () return (raw :: any).Weight end)
	if ok and weight then weightValue = weight.Value end

	local ok2, style = pcall (function () return (raw :: any).Style end)
	if ok2 and style then styleValue = style.Value end

	buffer.writeu16 (b, 0, weightValue)
	buffer.writeu8 (b, 2, styleValue)
	buffer.copy (b, 3, familyBuf)
	buffer.copy (b, 3 + familyLen, cachedFaceBuf)

	return b, len
end

--[=[
	Serializes value to binary format

	@param valueType string -- Type name
	@param value any -- Value to serialize
	@return (buffer?, number?) -- Buffer and length, or nil if unsupported
]=]
local function serialize (valueType: string, value: any): (buffer?, number?)
	local descriptor = descriptors[valueType]
	if not descriptor then return nil, nil end
	return descriptor (value)
end

--[=[
	Checks if type is supported

	@param valueType string -- Type name
	@return boolean
]=]
local function isSupported (valueType: string): boolean return descriptors[valueType] ~= nil end

return {
	descriptors = descriptors,
	serialize = serialize,
	isSupported = isSupported,
	serializeSequence = serializeSequence,
}
