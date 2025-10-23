--[[
	XML Utilities - XML generation and escaping

	Provides utilities for XML spec-compliant serialization.
	Used by all XML serialization modules.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

-- Pattern for characters that need escaping in XML
local ESCAPE_PATTERN = "[&<>\"'\0\1-\9\11-\12\14-\31\127-\255]"

-- XML escape codes (optimized for common characters first)
local ESCAPE_MAP = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&#34;",
	["'"] = "&#39;",
	["\0"] = "",
}

-- Generate numeric escapes for control characters
for rangeStart, rangeEnd in string.gmatch (ESCAPE_PATTERN, "(.)%-(.)") do
	for charCode = string.byte (rangeStart), string.byte (rangeEnd) do
		local char = string.char (charCode)
		if not ESCAPE_MAP[char] then ESCAPE_MAP[char] = "&#" .. charCode .. ";" end
	end
end

local function escapeXml (str: string): string return str:gsub (ESCAPE_PATTERN, ESCAPE_MAP) end

local function cdata (content: string): string
	if string.find (content, "]]>", 1, true) then
		local parts = string.split (content, "]]>")
		return "<![CDATA[" .. table.concat (parts, "]]]]><![CDATA[>") .. "]]>"
	end
	return "<![CDATA[" .. content .. "]]>"
end

local function protectedString (raw: string): string
	-- ProtectedString uses CDATA if no "]]>", otherwise uses XML escaping
	if string.find (raw, "]]>", 1, true) then return escapeXml (raw) end
	return cdata (raw)
end

local function attribute (name: string, value: string): string return name .. '="' .. escapeXml (value) .. '"' end

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
	escapeXml = escapeXml,
	cdata = cdata,
	protectedString = protectedString,
	attribute = attribute,
	openTag = openTag,
	closeTag = closeTag,
	element = element,
}
