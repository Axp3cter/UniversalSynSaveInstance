--[[
	XML Instance - Instance serialization

	Converts Roblox Instance objects to XML <Item> elements with properties.
	Handles property sorting, type mapping, and special property cases.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local Attributes = require ("@core/attributes")
local CoreInstance = require ("@core/instance")
local PropertyTypes = require ("@constants/propertyTypes")
local Referent = require ("@core/referent")
local Tags = require ("@core/tags")
local XMLAttributes = require ("@core/xml/attributes")
local XMLProperties = require ("@core/xml/properties")
local XMLUtil = require ("@utilities/xml")

export type Options = CoreInstance.Options

export type SerializedAttribute = XMLAttributes.SerializedAttribute

export type SerializedProperty = {
	name: string,
	valueType: string,
	value: string,
}

export type SerializedInstance = {
	className: string,
	referent: string,
	properties: { SerializedProperty },
	attributes: { SerializedAttribute },
	tags: string?,
}

--[=[
	Serializes instance to XML structure

	Converts a Roblox Instance to a structured representation ready
	for XML generation, including all properties and proper type mapping.

	@param instance Instance -- Instance to serialize
	@param opts Options -- Serialization options
	@return SerializedInstance -- Structured instance data
]=]
local function serialize (instance: Instance, opts: Options): SerializedInstance
	local base = CoreInstance.serialize (instance, opts)
	local referent = Referent.rbx (instance)
	local serializedProps: { SerializedProperty } = {}
	local serializedAttrs: { SerializedAttribute } = {}

	-- Serialize each property
	for _, prop in base.properties do
		local xmlType = PropertyTypes.getXMLType (prop.valueType)
		local serializedValue = XMLProperties.serialize (prop.valueType, prop.value)

		table.insert (serializedProps, {
			name = prop.name,
			valueType = xmlType,
			value = serializedValue,
		})
	end

	-- Sort properties alphabetically by name (per .rbxlx spec)
	table.sort (serializedProps, function (a, b) return a.name < b.name end)

	-- Serialize attributes
	local attrs = Attributes.read (instance, { mode = opts.mode })
	for _, attr in attrs do
		table.insert (serializedAttrs, XMLAttributes.serialize (attr.name, attr.value))
	end

	-- Sort attributes alphabetically by name
	table.sort (serializedAttrs, function (a, b) return a.name < b.name end)

	-- Serialize tags
	local tags = Tags.read (instance, { mode = opts.mode })
	local tagsStr = Tags.serialize (tags)

	return {
		className = base.className,
		referent = referent,
		properties = serializedProps,
		attributes = serializedAttrs,
		tags = if tagsStr and #tagsStr > 0 then tagsStr else nil,
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
local function toXML (data: SerializedInstance, indent: number?): string
	local level = indent or 0
	local tab = string.rep ("\t", level)
	local parts = {}

	-- Opening Item tag
	table.insert (parts, `{tab}<Item class="{data.className}" referent="{data.referent}">`)

	-- Properties section
	if #data.properties > 0 then
		table.insert (parts, `{tab}\t<Properties>`)

		for _, prop in data.properties do
			table.insert (parts, `{tab}\t\t<{prop.valueType} name="{prop.name}">{prop.value}</{prop.valueType}>`)
		end

		table.insert (parts, `{tab}\t</Properties>`)
	end

	-- Attributes section
	if #data.attributes > 0 then table.insert (parts, XMLAttributes.toXML (data.attributes, level + 1)) end

	-- Tags section
	if data.tags then
		local tagIndent = string.rep ("\t", level + 1)
		table.insert (parts, `{tagIndent}<Tags>{XMLUtil.cdata (data.tags)}</Tags>`)
	end

	return table.concat (parts, "\n")
end

--[=[
	Closes XML Item tag

	Generates the closing tag for an instance element with proper indentation.

	@param indent number? -- Indentation level (default: 0)
	@return string -- Closing tag markup
]=]
local function closeTag (indent: number?): string
	local level = indent or 0
	local tab = string.rep ("\t", level)
	return `{tab}</Item>`
end

return {
	serialize = serialize,
	toXML = toXML,
	closeTag = closeTag,
}
