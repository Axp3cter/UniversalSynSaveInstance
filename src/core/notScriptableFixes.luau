--[[
	Not Scriptable Fixes - Property name mappings and special serializers

	Maps NotScriptable properties to their actual names or provides custom
	serialization functions for properties that need special handling.

	Based on comprehensive analysis of Roblox API and property access patterns.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local Bit = require ("@utilities/bit")

export type PropertyFix = string | (instance: Instance) -> any

export type ClassFixes = {
	[string]: PropertyFix,
}

export type NotScriptableFixes = {
	[string]: ClassFixes,
}

--[=[
	Serializes Instance attributes to binary format

	Format: u32 count, then for each attribute:
	- string name (u32 length + data)
	- u8 type ID
	- binary value (varies by type)

	@param instance Instance -- Instance with attributes
	@return string -- Binary data
]=]
local function serializeAttributes (instance: Instance): string
	local attrs = instance:GetAttributes ()
	if not next (attrs) then return "" end

	-- Sort attribute names for consistent output
	local attrNames = {}
	for name in attrs do
		table.insert (attrNames, name)
	end
	table.sort (attrNames)

	-- Calculate buffer size
	local bufferSize = 4 -- u32 count
	for _, name in attrNames do
		bufferSize += 4 + #name + 1 -- name length + name + type byte
		-- Add value size (simplified - would need actual Binary_Descriptors)
		bufferSize += 64 -- Conservative estimate per value
	end

	local b = buffer.create (bufferSize)
	local offset = 0

	-- Write count
	buffer.writeu32 (b, offset, #attrNames)
	offset += 4

	-- Write each attribute
	for _, name in attrNames do
		local value = attrs[name]

		-- Write name
		buffer.writeu32 (b, offset, #name)
		offset += 4
		buffer.writestring (b, offset, name)
		offset += #name

		-- Write type ID (simplified - would need actual attributeTypes)
		local valueType = typeof (value)
		local typeId = 0x02 -- String default
		if valueType == "boolean" then
			typeId = 0x03
		elseif valueType == "number" then
			typeId = 0x06
		end

		buffer.writeu8 (b, offset, typeId)
		offset += 1

		-- Write value (simplified)
		if valueType == "boolean" then
			buffer.writeu8 (b, offset, if value then 1 else 0)
			offset += 1
		elseif valueType == "number" then
			buffer.writef64 (b, offset, value)
			offset += 8
		end
	end

	return buffer.tostring (b):sub (1, offset)
end

--[=[
	Serializes terrain material colors to binary format

	Format: 6 reserved bytes + 63 bytes (21 materials × 3 RGB components)

	@param instance Terrain -- Terrain instance
	@return string -- Binary data
]=]
local function serializeMaterialColors (instance: Instance): string
	local terrain = instance :: Terrain

	local MATERIALS = {
		Enum.Material.Grass,
		Enum.Material.Slate,
		Enum.Material.Concrete,
		Enum.Material.Brick,
		Enum.Material.Sand,
		Enum.Material.WoodPlanks,
		Enum.Material.Rock,
		Enum.Material.Glacier,
		Enum.Material.Snow,
		Enum.Material.Sandstone,
		Enum.Material.Mud,
		Enum.Material.Basalt,
		Enum.Material.Ground,
		Enum.Material.CrackedLava,
		Enum.Material.Asphalt,
		Enum.Material.Cobblestone,
		Enum.Material.Ice,
		Enum.Material.LeafyGrass,
		Enum.Material.Salt,
		Enum.Material.Limestone,
		Enum.Material.Pavement,
	}

	local b = buffer.create (69) -- 6 reserved + 63 for colors
	local offset = 6 -- Skip reserved bytes

	for _, material in MATERIALS do
		local color = terrain:GetMaterialColor (material)
		buffer.writeu8 (b, offset, math.floor (color.R * 255))
		offset += 1
		buffer.writeu8 (b, offset, math.floor (color.G * 255))
		offset += 1
		buffer.writeu8 (b, offset, math.floor (color.B * 255))
		offset += 1
	end

	return buffer.tostring (b)
end

--[=[
	Serializes collision group data to binary format

	@return string -- Binary data
]=]
local function serializeCollisionGroupData (): string
	local PhysicsService = game:GetService ("PhysicsService")
	local groups = PhysicsService:GetRegisteredCollisionGroups ()

	if #groups == 0 then return "\1\0" end

	-- Calculate size
	local bufferSize = 2 -- version + count
	for _, group in groups do
		bufferSize += 7 + #group.name -- id + constant + mask + name_len + name
	end

	local b = buffer.create (bufferSize)
	local offset = 0

	buffer.writeu8 (b, offset, 1) -- Version
	offset += 1
	buffer.writeu8 (b, offset, #groups) -- Count
	offset += 1

	for i, group in groups do
		buffer.writeu8 (b, offset, i - 1) -- ID
		offset += 1
		buffer.writeu8 (b, offset, 4) -- Constant
		offset += 1
		buffer.writei32 (b, offset, group.mask) -- Mask
		offset += 4
		buffer.writeu8 (b, offset, #group.name) -- Name length
		offset += 1
		buffer.writestring (b, offset, group.name) -- Name
		offset += #group.name
	end

	return buffer.tostring (b)
end

--[=[
	Serializes HumanoidDescription emotes data

	Format: name^id1^id2^...^\

	@param instance HumanoidDescription
	@return string
]=]
local function serializeEmotesData (instance: Instance): string
	local desc = instance :: HumanoidDescription
	local result = ""
	for name, ids in desc:GetEmotes () do
		result ..= name .. "^" .. table.concat (ids, "^") .. "^\\"
	end
	return result
end

--[=[
	Serializes HumanoidDescription equipped emotes data

	Format: slot^name\slot^name\...

	@param instance HumanoidDescription
	@return string
]=]
local function serializeEquippedEmotesData (instance: Instance): string
	local desc = instance :: HumanoidDescription
	local result = ""
	for _, emote in desc:GetEquippedEmotes () do
		result ..= emote.Slot .. "^" .. emote.Name .. "\\"
	end
	return result
end

--[=[
	Serializes LocalizationTable contents

	@param instance LocalizationTable
	@return string
]=]
local function serializeLocalizationContents (instance: Instance): string
	local table = instance :: LocalizationTable
	return table:GetContents ()
end

--[=[
	Serializes Model scale factor

	@param instance Model
	@return number
]=]
local function serializeModelScale (instance: Instance): number
	local model = instance :: Model
	return model:GetScale ()
end

--[=[
	Serializes Instance tags

	Format: tag1\0tag2\0tag3

	@param instance Instance
	@return string
]=]
local function serializeTags (instance: Instance): string
	local tags = instance:GetTags ()
	if #tags == 0 then return "" end
	return table.concat (tags, "\0")
end

--[=[
	Serializes SecurityCapabilities to bitfield

	Converts SecurityCapabilities to 64-bit bitfield integer.
	Returns 0 for base capabilities.

	@param raw SecurityCapabilities
	@return number -- Bitfield value
]=]
local function serializeSecurityCapabilities (raw: any): number
	-- Try to create base capabilities for comparison
	local baseCapabilities = nil
	pcall (function () baseCapabilities = (SecurityCapabilities :: any).new () end)

	if baseCapabilities and raw == baseCapabilities then return 0 end

	-- Capability bit mappings (2^n)
	local CAPABILITY_BITS = {
		Plugin = 2 ^ 0, -- 0
		LocalUser = 2 ^ 1, -- 1
		WritePlayer = 2 ^ 2, -- 2
		RobloxScript = 2 ^ 3, -- 3
		RobloxEngine = 2 ^ 4, -- 4
		NotAccessible = 2 ^ 5, -- 5
		RunClientScript = 2 ^ 8, -- 8
		RunServerScript = 2 ^ 9, -- 9
		AccessOutsideWrite = 2 ^ 11, -- 11
		Unassigned = 2 ^ 15, -- 15
		AssetRequire = 2 ^ 16, -- 16
		LoadString = 2 ^ 17, -- 17
		ScriptGlobals = 2 ^ 18, -- 18
		CreateInstances = 2 ^ 19, -- 19
		Basic = 2 ^ 20, -- 20
		Audio = 2 ^ 21, -- 21
		DataStore = 2 ^ 22, -- 22
		Network = 2 ^ 23, -- 23
		Physics = 2 ^ 24, -- 24
		UI = 2 ^ 25, -- 25
		CSG = 2 ^ 26, -- 26
		Chat = 2 ^ 27, -- 27
		Animation = 2 ^ 28, -- 28
		Avatar = 2 ^ 29, -- 29
		Input = 2 ^ 30, -- 30
		Environment = 2 ^ 31, -- 31
		RemoteEvent = 2 ^ 32, -- 32
		LegacySound = 2 ^ 33, -- 33
		Players = 2 ^ 34, -- 34
		CapabilityControl = 2 ^ 35, -- 35
		InternalTest = 2 ^ 60, -- 60
		PluginOrOpenCloud = 2 ^ 61, -- 61
		Assistant = 2 ^ 62, -- 62
	}

	-- Parse capabilities from tostring() since API is experimental
	-- Format: "Capability1 | Capability2 | ..."
	local result = 0
	local capString = tostring (raw)

	for _, flag in string.split (capString, " | ") do
		local bit = CAPABILITY_BITS[flag]
		if bit then
			result += bit
		end
	end

	return result
end

-- Complete NotScriptableFixes mapping
local fixes: NotScriptableFixes = {
	-- Universal Instance properties
	Instance = {
		AttributesSerialize = serializeAttributes,
		DefinesCapabilities = "Sandboxed",
		SecurityCapabilities = serializeSecurityCapabilities,
		Tags = serializeTags,
	},

	-- Constraints
	BallSocketConstraint = {
		MaxFrictionTorqueXml = "MaxFrictionTorque",
	},

	-- Base parts
	BasePart = {
		Color3uint8 = "Color",
		MaterialVariantSerialized = "MaterialVariant",
		size = "Size",
	},

	-- Constrained values
	DoubleConstrainedValue = {
		value = "Value",
	},

	IntConstrainedValue = {
		value = "Value",
	},

	-- Terrain
	Terrain = {
		AcquisitionMethod = "LastUsedModificationMethod",
		MaterialColors = serializeMaterialColors,
	},

	-- Mesh parts
	TriangleMeshPart = {
		FluidFidelityInternal = "FluidFidelity",
	},

	MeshPart = {
		InitialSize = "MeshSize",
	},

	PartOperation = {
		InitialSize = "MeshSize",
	},

	-- Part types
	Part = {
		shape = "Shape",
	},

	TrussPart = {
		style = "Style",
	},

	FormFactorPart = {
		formFactorRaw = "FormFactor",
	},

	-- Effects
	Fire = {
		heat_xml = "Heat",
		size_xml = "Size",
	},

	Smoke = {
		size_xml = "Size",
		opacity_xml = "Opacity",
		riseVelocity_xml = "RiseVelocity",
	},

	-- Characters
	Humanoid = {
		Health_XML = "Health",
	},

	HumanoidDescription = {
		EmotesDataInternal = serializeEmotesData,
		EquippedEmotesDataInternal = serializeEquippedEmotesData,
	},

	-- Localization
	LocalizationTable = {
		Contents = serializeLocalizationContents,
	},

	-- Services and containers
	MaterialService = {
		Use2022MaterialsXml = "Use2022Materials",
	},

	Model = {
		ScaleFactor = serializeModelScale,
		WorldPivotData = "WorldPivot",
	},

	PackageLink = {
		PackageIdSerialize = "PackageId",
		VersionIdSerialize = "VersionNumber",
	},

	Players = {
		MaxPlayersInternal = "MaxPlayers",
		PreferredPlayersInternal = "PreferredPlayers",
	},

	StarterPlayer = {
		AvatarJointUpgrade_Serialized = "AvatarJointUpgrade",
	},

	-- Audio
	Sound = {
		xmlRead_MaxDistance_3 = "RollOffMaxDistance",
	},

	-- Welds
	WeldConstraint = {
		Part0Internal = "Part0",
		Part1Internal = "Part1",
	},

	-- Workspace
	Workspace = {
		CollisionGroupData = serializeCollisionGroupData,
	},
}

--[=[
	Gets the NotScriptable fix for a class and property

	@param className string -- Class name
	@param propertyName string -- Property name
	@return PropertyFix? -- Fix function or property name, or nil
]=]
local function getFix (className: string, propertyName: string): PropertyFix?
	local classFixes = fixes[className]
	if not classFixes then return nil end
	return classFixes[propertyName]
end

--[=[
	Checks if a property has a NotScriptable fix

	@param className string -- Class name
	@param propertyName string -- Property name
	@return boolean -- True if fix exists
]=]
local function hasFix (className: string, propertyName: string): boolean return getFix (className, propertyName) ~= nil end

return {
	fixes = fixes,
	getFix = getFix,
	hasFix = hasFix,
}
