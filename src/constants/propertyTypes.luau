--[[
	Property Types - Centralized type mappings and constants

	Defines all type mappings for XML/Binary serialization.
	Single source of truth for property type handling.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

--[=[
	Maps Roblox types to XML type names
	Used by all serializers to maintain consistency
]=]
export type PropertyTypeMap = {
	[string]: string,
}

-- Roblox type to XML type mapping
local ROBLOX_TO_XML: PropertyTypeMap = {
	-- Primitives
	string = "string",
	boolean = "bool",
	number = "float",

	-- Vectors
	Vector2 = "Vector2",
	Vector3 = "Vector3",
	Vector2int16 = "Vector2int16",
	Vector3int16 = "Vector3int16",

	-- Colors
	Color3 = "Color3uint8",
	BrickColor = "int",

	-- Transforms
	CFrame = "CoordinateFrame",

	-- Dimensions
	UDim = "UDim",
	UDim2 = "UDim2",

	-- Geometry
	Rect = "Rect2D",
	Ray = "Ray",

	-- Sequences
	NumberSequence = "NumberSequence",
	ColorSequence = "ColorSequence",
	NumberRange = "NumberRange",

	-- Physics
	PhysicalProperties = "PhysicalProperties",

	-- Enums
	EnumItem = "token",

	-- Bitsets
	Faces = "Faces",
	Axes = "Axes",

	-- Text
	Font = "Font",

	-- References
	Instance = "Ref",

	-- Binary
	BinaryString = "BinaryString",
	ProtectedString = "ProtectedString",
}

-- Default values for properties by type
local DEFAULT_VALUES: { [string]: any } = {
	boolean = false,
	number = 0,
	string = "",
	Vector3 = Vector3.new (0, 0, 0),
	Vector2 = Vector2.new (0, 0),
	Color3 = Color3.new (1, 1, 1),
	CFrame = CFrame.new (),
	UDim2 = UDim2.new (0, 0, 0, 0),
	BrickColor = BrickColor.new ("White"),
}

-- Numeric type IDs for attributes (binary format)
local ATTRIBUTE_TYPE_IDS: { [string]: number } = {
	string = 0x02,
	boolean = 0x03,
	number = 0x06,
	UDim = 0x09,
	UDim2 = 0x0A,
	Ray = 0x0B,
	Faces = 0x0C,
	Axes = 0x0D,
	BrickColor = 0x0E,
	Color3 = 0x0F,
	Vector2 = 0x10,
	Vector3 = 0x11,
	Vector2int16 = 0x12,
	Vector3int16 = 0x13,
	CFrame = 0x14,
	EnumItem = 0x15,
	NumberSequence = 0x17,
	NumberSequenceKeypoint = 0x18,
	ColorSequence = 0x19,
	ColorSequenceKeypoint = 0x1A,
	NumberRange = 0x1B,
	Rect = 0x1C,
	PhysicalProperties = 0x1D,
	Region3 = 0x1F,
	Region3int16 = 0x20,
	Font = 0x21,
}

--[=[
	Gets XML type name for Roblox type

	@param robloxType string -- Roblox type name
	@return string -- XML type name (defaults to "string" if unknown)
]=]
local function getXMLType (robloxType: string): string return ROBLOX_TO_XML[robloxType] or "string" end

--[=[
	Gets default value for type

	@param valueType string -- Type name
	@return any -- Default value or nil
]=]
local function getDefaultValue (valueType: string): any return DEFAULT_VALUES[valueType] end

--[=[
	Gets attribute type ID for binary format

	@param valueType string -- Type name
	@return number? -- Type ID or nil
]=]
local function getAttributeTypeId (valueType: string): number? return ATTRIBUTE_TYPE_IDS[valueType] end

--[=[
	Checks if type is numeric

	@param valueType string -- Type name
	@return boolean
]=]
local function isNumericType (valueType: string): boolean
	return valueType == "number"
		or valueType == "int"
		or valueType == "int64"
		or valueType == "float"
		or valueType == "double"
end

--[=[
	Checks if type needs binary encoding

	@param valueType string -- Type name
	@return boolean
]=]
local function isBinaryType (valueType: string): boolean
	return valueType == "BinaryString" or valueType == "ProtectedString"
end

--[=[
	Checks if type is a vector/geometric type

	@param valueType string -- Type name
	@return boolean
]=]
local function isGeometricType (valueType: string): boolean
	return string.find (valueType, "Vector") ~= nil
		or string.find (valueType, "CFrame") ~= nil
		or string.find (valueType, "Ray") ~= nil
		or string.find (valueType, "Rect") ~= nil
end

return {
	ROBLOX_TO_XML = ROBLOX_TO_XML,
	DEFAULT_VALUES = DEFAULT_VALUES,
	ATTRIBUTE_TYPE_IDS = ATTRIBUTE_TYPE_IDS,
	getXMLType = getXMLType,
	getDefaultValue = getDefaultValue,
	getAttributeTypeId = getAttributeTypeId,
	isNumericType = isNumericType,
	isBinaryType = isBinaryType,
	isGeometricType = isGeometricType,
}
