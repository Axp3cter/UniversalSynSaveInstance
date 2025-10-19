--[[
	String Utilities - Essential String Operations

	Provides focused string manipulation beyond standard library.
	Only includes functions that add real value.

	@author Aspecter
	@version 2.0.0
]]

--[=[
	Checks if string contains substring

	@param str string -- String to search
	@param substr string -- Substring to find
	@return boolean -- True if found
]=]
local function contains(str: string, substr: string): boolean
	return string.find(str, substr, 1, true) ~= nil
end

--[=[
	Checks if string starts with prefix

	@param str string -- String to check
	@param prefix string -- Prefix to match
	@return boolean -- True if starts with prefix
]=]
local function startsWith(str: string, prefix: string): boolean
	return string.sub(str, 1, #prefix) == prefix
end

--[=[
	Checks if string ends with suffix

	@param str string -- String to check
	@param suffix string -- Suffix to match
	@return boolean -- True if ends with suffix
]=]
local function endsWith(str: string, suffix: string): boolean
	return string.sub(str, -#suffix) == suffix
end

--[=[
	Trims whitespace from string

	@param str string -- String to trim
	@param mode ("both" | "start" | "end")? -- Which sides to trim (default: "both")
	@return string -- Trimmed string
]=]
local function trim(str: string, mode: ("both" | "start" | "end")?): string
	local trimMode = mode or "both"

	if trimMode == "both" then
		return string.match(str, "^%s*(.-)%s*$") or str
	elseif trimMode == "start" then
		return string.match(str, "^%s*(.-)$") or str
	elseif trimMode == "end" then
		return string.match(str, "^(.-)%s*$") or str
	end

	error(`Invalid trim mode: {trimMode}`)
end

--[=[
	Pads string to target length

	@param str string -- String to pad
	@param length number -- Target length
	@param char string? -- Pad character (default: " ")
	@param side ("left" | "right")? -- Pad side (default: "left")
	@return string -- Padded string
]=]
local function pad(str: string, length: number, char: string?, side: ("left" | "right")?): string
	if #str >= length then
		return str
	end

	local padding = string.rep(char or " ", length - #str)
	return if (side or "left") == "left" then padding .. str else str .. padding
end

--[=[
	Splits string by separator

	@param str string -- String to split
	@param separator string? -- Separator (default: ",")
	@return {string} -- Split parts
]=]
local function split(str: string, separator: string?): { string }
	return string.split(str, separator or ",")
end

return {
	contains = contains,
	startsWith = startsWith,
	endsWith = endsWith,
	trim = trim,
	pad = pad,
	split = split,
}
