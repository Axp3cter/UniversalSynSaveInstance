--[[
	XML Utilities - XML generation and escaping

	Provides utilities for XML spec-compliant serialization.
	Used by all XML serialization modules.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local function escapeXML (str: string): string
	return str:gsub ("&", "&amp;"):gsub ("<", "&lt;"):gsub (">", "&gt;"):gsub ('"', "&quot;"):gsub ("'", "&apos;")
end

local function cdata (content: string): string
	if string.find (content, "]]>", 1, true) then
		local parts = string.split (content, "]]>")
		return "<![CDATA[" .. table.concat (parts, "]]]]><![CDATA[>") .. "]]>"
	end
	return "<![CDATA[" .. content .. "]]>"
end

local function attribute (name: string, value: string): string return name .. '="' .. escapeXML (value) .. '"' end

local function openTag (tagName: string, attributes: { [string]: string }?): string
	if not attributes or next (attributes) == nil then return "<" .. tagName .. ">" end
	local parts = { "<" .. tagName }
	for name, value in attributes do
		table.insert (parts, " " .. attribute (name, value))
	end
	table.insert (parts, ">")
	return table.concat (parts)
end

local function closeTag (tagName: string): string return "</" .. tagName .. ">" end

local function element (tagName: string, content: string, attributes: { [string]: string }?): string
	return openTag (tagName, attributes) .. content .. closeTag (tagName)
end

return {
	escapeXML = escapeXML,
	cdata = cdata,
	attribute = attribute,
	openTag = openTag,
	closeTag = closeTag,
	element = element,
}
