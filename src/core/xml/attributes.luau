--[[
	XML Attributes - Attribute value serialization

	Converts Roblox Instance attributes to XML format following the .rbxlx specification.
	Attributes are stored as key-value pairs within an Attributes element.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local PropertyTypes = require ("@constants/propertyTypes")
local XMLProperties = require ("@core/xml/properties")
local XMLUtil = require ("@utilities/xml")

export type SerializedAttribute = {
	name: string,
	valueType: string,
	value: string,
}

--[=[
	Serializes attribute to XML structure

	Converts an attribute to a structured representation ready
	for XML generation with proper type mapping.

	@param name string -- Attribute name
	@param value any -- Attribute value
	@return SerializedAttribute -- Structured attribute data
]=]
local function serialize (name: string, value: any): SerializedAttribute
	local robloxType = typeof (value)
	local xmlType = PropertyTypes.getXMLType (robloxType)
	local serializedValue = XMLProperties.serialize (robloxType, value)

	return {
		name = name,
		valueType = xmlType,
		value = serializedValue,
	}
end

--[=[
	Converts serialized attributes to XML string

	Takes a list of serialized attributes and generates the XML
	markup for the Attributes section.

	@param attrs {SerializedAttribute} -- List of attributes
	@param indent number? -- Indentation level
	@return string -- XML markup for attributes
]=]
local function toXML (attrs: { SerializedAttribute }, indent: number?): string
	if #attrs == 0 then return "" end

	local level = indent or 0
	local tab = string.rep ("\t", level)
	local parts = { `{tab}<Attributes>` }

	for _, attr in attrs do
		table.insert (parts, `{tab}\t<{attr.valueType} name="{attr.name}">{attr.value}</{attr.valueType}>`)
	end

	table.insert (parts, `{tab}</Attributes>`)

	return table.concat (parts, "\n")
end

return {
	serialize = serialize,
	toXML = toXML,
}
