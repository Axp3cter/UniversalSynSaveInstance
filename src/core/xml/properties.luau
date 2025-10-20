--[[
	XML Properties - Property value serialization

	Converts Roblox property values to XML format following the .rbxlx specification.
	Each datatype has a specific XML encoding pattern with nested tags.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local StringUtil = require("@utilities/string")

export type SerializerContext = {
	sharedStrings: { [string]: string },
}

-- ============================================================================
-- XML Escaping
-- ============================================================================

-- Escapes special XML characters in strings
local function escapeXML(str: string): string
	return str
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end

-- Wraps content in CDATA section
local function cdata(content: string): string
	return `<![CDATA[{content}]]>`
end

-- ============================================================================
-- Basic Types
-- ============================================================================

local function serializeString(value: string): string
	return cdata(value)
end

local function serializeProtectedString(value: string): string
	-- Protected strings use CDATA with XML escaping
	return cdata(escapeXML(value))
end

local function serializeBool(value: boolean): string
	return if value then "true" else "false"
end

local function serializeInt(value: number): string
	return tostring(math.floor(value))
end

local function serializeFloat(value: number): string
	return tostring(value)
end

local function serializeDouble(value: number): string
	return tostring(value)
end

-- ============================================================================
-- Vector Types
-- ============================================================================

local function serializeVector2(value: Vector2): string
	return `<X>{value.X}</X><Y>{value.Y}</Y>`
end

local function serializeVector3(value: Vector3): string
	return `<X>{value.X}</X><Y>{value.Y}</Y><Z>{value.Z}</Z>`
end

local function serializeVector2int16(value: Vector2int16): string
	return `<X>{value.X}</X><Y>{value.Y}</Y>`
end

local function serializeVector3int16(value: Vector3int16): string
	return `<X>{value.X}</X><Y>{value.Y}</Y><Z>{value.Z}</Z>`
end

-- ============================================================================
-- Color Types
-- ============================================================================

local function serializeColor3(value: Color3): string
	local r = math.floor(value.R * 255)
	local g = math.floor(value.G * 255)
	local b = math.floor(value.B * 255)
	return tostring((r * 65536) + (g * 256) + b)
end

local function serializeColor3uint8(value: Color3): string
	return serializeColor3(value)
end

local function serializeBrickColor(value: BrickColor): string
	return tostring(value.Number)
end

-- ============================================================================
-- CFrame
-- ============================================================================

local function serializeCFrame(value: CFrame): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	return `<X>{x}</X><Y>{y}</Y><Z>{z}</Z><R00>{r00}</R00><R01>{r01}</R01><R02>{r02}</R02><R10>{r10}</R10><R11>{r11}</R11><R12>{r12}</R12><R20>{r20}</R20><R21>{r21}</R21><R22>{r22}</R22>`
end

-- ============================================================================
-- UDim Types
-- ============================================================================

local function serializeUDim(value: UDim): string
	return `<S>{value.Scale}</S><O>{value.Offset}</O>`
end

local function serializeUDim2(value: UDim2): string
	return `<XS>{value.X.Scale}</XS><XO>{value.X.Offset}</XO><YS>{value.Y.Scale}</YS><YO>{value.Y.Offset}</YO>`
end

-- ============================================================================
-- Rect
-- ============================================================================

local function serializeRect(value: Rect): string
	local min = value.Min
	local max = value.Max
	return `<min><X>{min.X}</X><Y>{min.Y}</Y></min><max><X>{max.X}</X><Y>{max.Y}</Y></max>`
end

-- ============================================================================
-- Ray
-- ============================================================================

local function serializeRay(value: Ray): string
	local origin = value.Origin
	local direction = value.Direction
	return `<origin><X>{origin.X}</X><Y>{origin.Y}</Y><Z>{origin.Z}</Z></origin><direction><X>{direction.X}</X><Y>{direction.Y}</Y><Z>{direction.Z}</Z></direction>`
end

-- ============================================================================
-- NumberSequence and ColorSequence
-- ============================================================================

local function serializeNumberSequence(value: NumberSequence): string
	local keypoints = value.Keypoints
	local parts = {}

	for _, keypoint in keypoints do
		table.insert(
			parts,
			`<Keypoint><Time>{keypoint.Time}</Time><Value>{keypoint.Value}</Value><Envelope>{keypoint.Envelope}</Envelope></Keypoint>`
		)
	end

	return table.concat(parts, "")
end

local function serializeColorSequence(value: ColorSequence): string
	local keypoints = value.Keypoints
	local parts = {}

	for _, keypoint in keypoints do
		local color = keypoint.Value
		table.insert(
			parts,
			`<Keypoint><Time>{keypoint.Time}</Time><Value>{serializeColor3(color)}</Value></Keypoint>`
		)
	end

	return table.concat(parts, "")
end

-- ============================================================================
-- NumberRange
-- ============================================================================

local function serializeNumberRange(value: NumberRange): string
	return `<min>{value.Min}</min><max>{value.Max}</max>`
end

-- ============================================================================
-- PhysicalProperties
-- ============================================================================

local function serializePhysicalProperties(value: PhysicalProperties?): string
	if not value then
		return `<CustomPhysics>false</CustomPhysics>`
	end

	return `<CustomPhysics>true</CustomPhysics><Density>{value.Density}</Density><Friction>{value.Friction}</Friction><Elasticity>{value.Elasticity}</Elasticity><FrictionWeight>{value.FrictionWeight}</FrictionWeight><ElasticityWeight>{value.ElasticityWeight}</ElasticityWeight>`
end

-- ============================================================================
-- Enum
-- ============================================================================

local function serializeEnum(value: EnumItem): string
	return tostring(value.Value)
end

-- ============================================================================
-- Instance Reference
-- ============================================================================

local function serializeRef(value: Instance?, referentMap: { [Instance]: string }): string
	if not value then
		return "null"
	end

	return referentMap[value] or "null"
end

-- ============================================================================
-- Binary String (Base64)
-- ============================================================================

local Executor = require("@utilities/executor")

local function serializeBinaryString(value: string): string
	local result = Executor.base64Encode(value):expect()

	if not result.success or not result.data then
		return ""
	end

	return result.data
end

-- ============================================================================
-- Faces and Axes
-- ============================================================================

local function serializeFaces(value: Faces): string
	local parts = {}

	if value.Top then
		table.insert(parts, "Top")
	end
	if value.Bottom then
		table.insert(parts, "Bottom")
	end
	if value.Left then
		table.insert(parts, "Left")
	end
	if value.Right then
		table.insert(parts, "Right")
	end
	if value.Front then
		table.insert(parts, "Front")
	end
	if value.Back then
		table.insert(parts, "Back")
	end

	return table.concat(parts, ",")
end

local function serializeAxes(value: Axes): string
	local parts = {}

	if value.X then
		table.insert(parts, "X")
	end
	if value.Y then
		table.insert(parts, "Y")
	end
	if value.Z then
		table.insert(parts, "Z")
	end

	return table.concat(parts, ",")
end

-- ============================================================================
-- Font
-- ============================================================================

local function serializeFont(value: Font): string
	local family = value.Family
	local weight = value.Weight
	local style = value.Style

	return `<Family>{cdata(family)}</Family><Weight>{weight.Value}</Weight><Style>{style.Value}</Style>`
end

-- ============================================================================
-- Main Serialization Router
-- ============================================================================

export type PropertySerializer = (value: any, context: SerializerContext?) -> string

local serializers: { [string]: PropertySerializer } = {
	-- Basic types
	string = serializeString,
	boolean = serializeBool,
	number = serializeDouble,
	int = serializeInt,
	int64 = serializeInt,
	float = serializeFloat,
	double = serializeDouble,

	-- Vector types
	Vector2 = serializeVector2,
	Vector3 = serializeVector3,
	Vector2int16 = serializeVector2int16,
	Vector3int16 = serializeVector3int16,

	-- Color types
	Color3 = serializeColor3,
	Color3uint8 = serializeColor3uint8,
	BrickColor = serializeBrickColor,

	-- Transform types
	CFrame = serializeCFrame,

	-- UDim types
	UDim = serializeUDim,
	UDim2 = serializeUDim2,

	-- Geometric types
	Rect = serializeRect,
	Ray = serializeRay,

	-- Sequence types
	NumberSequence = serializeNumberSequence,
	ColorSequence = serializeColorSequence,
	NumberRange = serializeNumberRange,

	-- Physical properties
	PhysicalProperties = serializePhysicalProperties,

	-- Enum
	EnumItem = serializeEnum,

	-- Binary data
	BinaryString = serializeBinaryString,
	ProtectedString = serializeProtectedString,

	-- Instance attributes
	Faces = serializeFaces,
	Axes = serializeAxes,

	-- Font
	Font = serializeFont,
}

--[=[
	Serializes property value to XML format

	Converts a Roblox property value to its XML representation following
	the .rbxlx specification format with type-specific encoding.

	@param valueType string -- Type name of the value
	@param value any -- Value to serialize
	@param context SerializerContext? -- Optional serialization context
	@return string -- XML-formatted value
]=]
local function serialize(valueType: string, value: any, context: SerializerContext?): string
	local serializer = serializers[valueType]

	if not serializer then
		-- Fallback to string representation
		return cdata(tostring(value))
	end

	return serializer(value, context)
end

--[=[
	Checks if value type is supported

	@param valueType string -- Type name to check
	@return boolean -- True if type can be serialized
]=]
local function isSupported(valueType: string): boolean
	return serializers[valueType] ~= nil
end

return {
	serialize = serialize,
	isSupported = isSupported,
	serializeRef = serializeRef,
	escapeXML = escapeXML,
	cdata = cdata,
}
