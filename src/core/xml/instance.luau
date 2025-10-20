--[[
	XML Instance - Instance serialization

	Converts Roblox Instance objects to XML <Item> elements with properties.
	Handles property sorting, type mapping, and special property cases.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local CoreInstance = require("@core/instance")
local XMLProperties = require("@core/xml/properties")
local Referent = require("@core/referent")

export type Options = CoreInstance.Options

export type SerializedInstance = {
	className: string,
	referent: string,
	properties: { SerializedProperty },
}

export type SerializedProperty = {
	name: string,
	valueType: string,
	value: string,
}

-- Property type mapping for XML
local TYPE_MAP: { [string]: string } = {
	string = "string",
	boolean = "bool",
	number = "float",
	Vector2 = "Vector2",
	Vector3 = "Vector3",
	Vector2int16 = "Vector2int16",
	Vector3int16 = "Vector3int16",
	Color3 = "Color3uint8",
	CFrame = "CoordinateFrame",
	UDim = "UDim",
	UDim2 = "UDim2",
	BrickColor = "int",
	Rect = "Rect2D",
	Ray = "Ray",
	NumberSequence = "NumberSequence",
	ColorSequence = "ColorSequence",
	NumberRange = "NumberRange",
	PhysicalProperties = "PhysicalProperties",
	EnumItem = "token",
	Faces = "Faces",
	Axes = "Axes",
	Font = "Font",
	Instance = "Ref",
}

-- Gets XML type name for Roblox type
local function getXMLType(robloxType: string): string
	return TYPE_MAP[robloxType] or "string"
end

--[=[
	Serializes instance to XML structure

	Converts a Roblox Instance to a structured representation ready
	for XML generation, including all properties and proper type mapping.

	@param instance Instance -- Instance to serialize
	@param opts Options -- Serialization options
	@return SerializedInstance -- Structured instance data
]=]
local function serialize(instance: Instance, opts: Options): SerializedInstance
	local base = CoreInstance.serialize(instance, opts)
	local referent = Referent.rbx(instance)
	local serializedProps: { SerializedProperty } = {}

	-- Serialize each property
	for _, prop in base.properties do
		local xmlType = getXMLType(prop.valueType)
		local serializedValue = XMLProperties.serialize(prop.valueType, prop.value)

		table.insert(serializedProps, {
			name = prop.name,
			valueType = xmlType,
			value = serializedValue,
		})
	end

	-- Sort properties alphabetically by name (per .rbxlx spec)
	table.sort(serializedProps, function(a, b)
		return a.name < b.name
	end)

	return {
		className = base.className,
		referent = referent,
		properties = serializedProps,
	}
end

--[=[
	Converts serialized instance to XML string

	Takes a structured instance representation and generates the XML
	markup following the .rbxlx specification format.

	@param data SerializedInstance -- Structured instance data
	@param indent number? -- Indentation level (default: 0)
	@return string -- XML markup for instance
]=]
local function toXML(data: SerializedInstance, indent: number?): string
	local level = indent or 0
	local tab = string.rep("\t", level)
	local parts = {}

	-- Opening Item tag
	table.insert(parts, `{tab}<Item class="{data.className}" referent="{data.referent}">`)

	-- Properties section
	if #data.properties > 0 then
		table.insert(parts, `{tab}\t<Properties>`)

		for _, prop in data.properties do
			table.insert(parts, `{tab}\t\t<{prop.valueType} name="{prop.name}">{prop.value}</{prop.valueType}>`)
		end

		table.insert(parts, `{tab}\t</Properties>`)
	end

	return table.concat(parts, "\n")
end

--[=[
	Closes XML Item tag

	Generates the closing tag for an instance element with proper indentation.

	@param indent number? -- Indentation level (default: 0)
	@return string -- Closing tag markup
]=]
local function closeTag(indent: number?): string
	local level = indent or 0
	local tab = string.rep("\t", level)
	return `{tab}</Item>`
end

return {
	serialize = serialize,
	toXML = toXML,
	closeTag = closeTag,
}
