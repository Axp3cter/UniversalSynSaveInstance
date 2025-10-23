--[[
	XML Properties - Property value serialization

	Converts Roblox property values to XML format following the .rbxlx specification.
	Each datatype has a specific XML encoding pattern with nested tags.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local Bit = require ("@utilities/bit")
local Executor = require ("@utilities/executor")
local PropertyTypes = require ("@constants/propertyTypes")
local XMLUtil = require ("@utilities/xml")

export type SerializerContext = {
	sharedStrings: { [string]: string },
}

-- ============================================================================
-- Basic Types
-- ============================================================================

local function serializeString (value: string): string return XMLUtil.cdata (value) end

local function serializeProtectedString (value: string): string
	-- Protected strings use sophisticated escape detection
	return XMLUtil.protectedString (value)
end

local function serializeBool (value: boolean): string return if value then "true" else "false" end

local function serializeInt (value: number): string return tostring (math.floor (value)) end

local function normalizeNumber (value: number): string
	-- Handle special float values (NaN, Infinity, -Infinity)
	if value ~= value then
		return "NAN"
	elseif value == math.huge then
		return "INF"
	elseif value == -math.huge then
		return "-INF"
	end
	return tostring (value)
end

local function normalizeRange (value: number): string
	-- For ranges, convert NaN to 0 for compatibility
	return if value ~= value then "0" else tostring (value)
end

local function serializeFloat (value: number): string return normalizeNumber (value) end

local function serializeDouble (value: number): string return normalizeNumber (value) end

-- ============================================================================
-- Vector Types
-- ============================================================================

local function serializeVector2 (value: Vector2): string return `<X>{value.X}</X><Y>{value.Y}</Y>` end

local function serializeVector3 (value: Vector3): string return `<X>{value.X}</X><Y>{value.Y}</Y><Z>{value.Z}</Z>` end

local function serializeVector2int16 (value: Vector2int16): string return `<X>{value.X}</X><Y>{value.Y}</Y>` end

local function serializeVector3int16 (value: Vector3int16): string
	return `<X>{value.X}</X><Y>{value.Y}</Y><Z>{value.Z}</Z>`
end

-- ============================================================================
-- Color Types
-- ============================================================================

local function serializeColor3 (value: Color3): string
	-- Use element format for better compatibility
	return `<R>{value.R}</R><G>{value.G}</G><B>{value.B}</B>`
end

local function serializeColor3uint8 (value: Color3): string
	-- Color3uint8 uses packed integer format
	local r = math.floor (value.R * 255)
	local g = math.floor (value.G * 255)
	local b = math.floor (value.B * 255)
	return tostring (0xFF000000 + (r * 0x10000) + (g * 0x100) + b)
end

local function serializeBrickColor (value: BrickColor): string return tostring (value.Number) end

-- ============================================================================
-- CFrame
-- ============================================================================

local function serializeCFrame (value: CFrame): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents ()

	-- Optimization: Check for identity rotation (no rotation applied)
	-- Identity matrix: [[1,0,0],[0,1,0],[0,0,1]]
	local epsilon = 1e-6
	local isIdentity = math.abs (r00 - 1) < epsilon
		and math.abs (r01) < epsilon
		and math.abs (r02) < epsilon
		and math.abs (r10) < epsilon
		and math.abs (r11 - 1) < epsilon
		and math.abs (r12) < epsilon
		and math.abs (r20) < epsilon
		and math.abs (r21) < epsilon
		and math.abs (r22 - 1) < epsilon

	if isIdentity then
		-- Shortened format for identity rotation
		return `<X>{x}</X><Y>{y}</Y><Z>{z}</Z>`
	else
		-- Full matrix format
		return `<X>{x}</X><Y>{y}</Y><Z>{z}</Z><R00>{r00}</R00><R01>{r01}</R01><R02>{r02}</R02><R10>{r10}</R10><R11>{r11}</R11><R12>{r12}</R12><R20>{r20}</R20><R21>{r21}</R21><R22>{r22}</R22>`
	end
end

-- ============================================================================
-- UDim Types
-- ============================================================================

local function serializeUDim (value: UDim): string return `<S>{value.Scale}</S><O>{value.Offset}</O>` end

local function serializeUDim2 (value: UDim2): string
	return `<XS>{value.X.Scale}</XS><XO>{value.X.Offset}</XO><YS>{value.Y.Scale}</YS><YO>{value.Y.Offset}</YO>`
end

-- ============================================================================
-- Rect
-- ============================================================================

local function serializeRect (value: Rect): string
	local min = value.Min
	local max = value.Max
	return `<min><X>{min.X}</X><Y>{min.Y}</Y></min><max><X>{max.X}</X><Y>{max.Y}</Y></max>`
end

-- ============================================================================
-- Ray
-- ============================================================================

local function serializeRay (value: Ray): string
	local origin = value.Origin
	local direction = value.Direction
	return `<origin><X>{origin.X}</X><Y>{origin.Y}</Y><Z>{origin.Z}</Z></origin><direction><X>{direction.X}</X><Y>{direction.Y}</Y><Z>{direction.Z}</Z></direction>`
end

-- ============================================================================
-- NumberSequence and ColorSequence
-- ============================================================================

local function serializeNumberSequence (value: NumberSequence): string
	-- Space-separated format: time value envelope time value envelope ...
	local keypoints = value.Keypoints
	local parts = {}

	for _, keypoint in keypoints do
		-- Use normalizeRange for NaN handling
		table.insert (parts, tostring (keypoint.Time))
		table.insert (parts, normalizeRange (keypoint.Value))
		table.insert (parts, normalizeRange (keypoint.Envelope))
	end

	return table.concat (parts, " ")
end

local function serializeColorSequence (value: ColorSequence): string
	-- Space-separated format: time r g b 0 time r g b 0 ...
	local keypoints = value.Keypoints
	local parts = {}

	for _, keypoint in keypoints do
		local color = keypoint.Value
		table.insert (parts, tostring (keypoint.Time))
		table.insert (parts, normalizeRange (color.R))
		table.insert (parts, normalizeRange (color.G))
		table.insert (parts, normalizeRange (color.B))
		table.insert (parts, "0") -- Envelope value always 0 for ColorSequence
	end

	return table.concat (parts, " ")
end

-- ============================================================================
-- NumberRange
-- ============================================================================

local function serializeNumberRange (value: NumberRange): string
	-- Space-separated format with NaN handling
	return normalizeRange (value.Min) .. " " .. normalizeRange (value.Max)
end

-- ============================================================================
-- PhysicalProperties
-- ============================================================================

local function serializePhysicalProperties (value: PhysicalProperties?): string
	if not value then return `<CustomPhysics>false</CustomPhysics>` end

	return `<CustomPhysics>true</CustomPhysics><Density>{value.Density}</Density><Friction>{value.Friction}</Friction><Elasticity>{value.Elasticity}</Elasticity><FrictionWeight>{value.FrictionWeight}</FrictionWeight><ElasticityWeight>{value.ElasticityWeight}</ElasticityWeight>`
end

-- ============================================================================
-- Enum
-- ============================================================================

local function serializeEnum (value: EnumItem): string return tostring (value.Value) end

-- ============================================================================
-- Instance Reference
-- ============================================================================

local function serializeRef (value: Instance?, referentMap: { [Instance]: string }): string
	if not value then return "null" end

	return referentMap[value] or "null"
end

-- ============================================================================
-- Binary String (Base64)
-- ============================================================================

local function serializeBinaryString (value: string): string
	local result = Executor.encodeBase64 (value)

	if not result.success or not result.data then return "" end

	return result.data
end

-- ============================================================================
-- Faces and Axes
-- ============================================================================

local function serializeFaces (value: Faces): string
	-- Bitfield encoding: integer 0-63
	-- Order: Right, Top, Back, Left, Bottom, Front
	return `<faces>{Bit.combineFlags (value.Right, value.Top, value.Back, value.Left, value.Bottom, value.Front)}</faces>`
end

local function serializeAxes (value: Axes): string
	-- Bitfield encoding: integer 0-7
	-- Order: X, Y, Z
	return `<axes>{Bit.combineFlags (value.X, value.Y, value.Z)}</axes>`
end

-- ============================================================================
-- Font
-- ============================================================================

local function serializeFont (value: Font): string
	local family = value.Family
	local weight = value.Weight
	local style = value.Style

	return `<Family>{XMLUtil.cdata (family)}</Family><Weight>{weight.Value}</Weight><Style>{style.Value}</Style>`
end

-- ============================================================================
-- DateTime
-- ============================================================================

local function serializeDateTime (value: DateTime): string
	-- Unix timestamp in milliseconds
	return tostring (value.UnixTimestampMillis)
end

-- ============================================================================
-- Region3 and Region3int16
-- ============================================================================

local function serializeRegion3 (value: Region3): string
	local min = value.CFrame.Position - value.Size / 2
	local max = value.CFrame.Position + value.Size / 2
	return `<min><X>{min.X}</X><Y>{min.Y}</Y><Z>{min.Z}</Z></min><max><X>{max.X}</X><Y>{max.Y}</Y><Z>{max.Z}</Z></max>`
end

local function serializeRegion3int16 (value: Region3int16): string
	local min = value.Min
	local max = value.Max
	return `<min><X>{min.X}</X><Y>{min.Y}</Y><Z>{min.Z}</Z></min><max><X>{max.X}</X><Y>{max.Y}</Y><Z>{max.Z}</Z></max>`
end

-- ============================================================================
-- SharedString
-- ============================================================================

local function serializeSharedString (value: string, context: SerializerContext?): string
	-- SharedStrings are hashed and referenced by ID
	if context and context.sharedStrings then
		local hash = context.sharedStrings[value]
		if hash then return hash end
	end

	-- Fallback to base64
	local result = Executor.encodeBase64 (value)
	return if result.success and result.data then result.data else ""
end

-- ============================================================================
-- FloatCurve (NumberSequence-like for terrain)
-- ============================================================================

local function serializeFloatCurve (value: FloatCurve): string
	local keypoints = value:GetKeypoints ()
	local parts = {}

	for _, keypoint in keypoints do
		table.insert (parts, `<Keypoint><Time>{keypoint.Time}</Time><Value>{keypoint.Value}</Value></Keypoint>`)
	end

	return table.concat (parts, "")
end

-- ============================================================================
-- OptionalCoordinateFrame
-- ============================================================================

local function serializeOptionalCoordinateFrame (value: CFrame?): string
	if not value then return "" end
	return serializeCFrame (value)
end

-- ============================================================================
-- Content and ContentId
-- ============================================================================

local function serializeContent (value: Content, referentMap: { [Instance]: string }): string
	-- Content type with multiple source types
	local sourceType = (value :: any).SourceType
	if not sourceType then return "<null></null>" end

	if sourceType == Enum.ContentSourceType.None then
		return "<null></null>"
	elseif sourceType == Enum.ContentSourceType.Uri then
		return "<uri>" .. XMLUtil.cdata ((value :: any).Uri) .. "</uri>"
	elseif sourceType == Enum.ContentSourceType.Object then
		local ref = serializeRef ((value :: any).Object, referentMap)
		return "<Ref>" .. ref .. "</Ref>"
	end

	return "<null></null>"
end

local function serializeContentId (value: string): string
	-- ContentId is a URL string (can be empty for null)
	if value == "" then return "<null></null>" end
	return "<url>" .. XMLUtil.cdata (value) .. "</url>"
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

	-- DateTime
	DateTime = serializeDateTime,

	-- Region types
	Region3 = serializeRegion3,
	Region3int16 = serializeRegion3int16,

	-- SharedString
	SharedString = serializeSharedString,

	-- FloatCurve
	FloatCurve = serializeFloatCurve,

	-- Optional types
	OptionalCoordinateFrame = serializeOptionalCoordinateFrame,

	-- Content types
	Content = serializeContent,
	ContentId = serializeContentId,
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
local function serialize (valueType: string, value: any, context: SerializerContext?): string
	local serializer = serializers[valueType]

	if not serializer then
		-- Fallback to string representation
		return XMLUtil.cdata (tostring (value))
	end

	return serializer (value, context)
end

--[=[
	Checks if value type is supported

	@param valueType string -- Type name to check
	@return boolean -- True if type can be serialized
]=]
local function isSupported (valueType: string): boolean return serializers[valueType] ~= nil end

return {
	serialize = serialize,
	isSupported = isSupported,
	serializeRef = serializeRef,
}
