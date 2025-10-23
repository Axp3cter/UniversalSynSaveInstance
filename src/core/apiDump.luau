--[[
	API Dump - Fetch and parse Roblox API dump

	Downloads version-matched API dump from rbxcdn or falls back to latest.
	Parses class hierarchy, properties, and member information.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local ClassPropertyExceptions = require ("@core/classPropertyExceptions")
local Executor = require ("@utilities/executor")
local NotScriptableFixes = require ("@core/notScriptableFixes")
local Services = require ("@utilities/services")
local TableUtil = require ("@utilities/table")

export type PropertyDescriptor = {
	Name: string,
	ValueType: string,
	Category: string,
	Special: boolean?, -- NotScriptable
	Optional: string?, -- For OptionalCoordinateFrame -> "CoordinateFrame"
	CanRead: boolean?,
	Fallback: ((instance: Instance) -> any)?,
}

export type ClassDescriptor = {
	Properties: { PropertyDescriptor },
	Superclass: string?,
	Tags: { [string]: boolean }?,
}

export type ClassList = {
	[string]: ClassDescriptor,
}

local HttpService = Services.getService ("HttpService")

--[=[
	Fetches API dump for current client version or latest

	Downloads from rbxcdn using DeployHistory to match version,
	or falls back to MaximumADHD's tracker.

	@param clientVersion number? -- Client version number (from version())
	@return string? -- JSON string or nil
]=]
local function fetchApiDump (clientVersion: number?): string?
	if not HttpService then
		warn ("[API Dump] HttpService not available")
		return nil
	end

	local cachedFileName = if clientVersion then tostring (clientVersion) else "latest"

	-- Try reading cached version
	local cacheResult = Executor.readFile (cachedFileName)
	if cacheResult.success and cacheResult.data and #cacheResult.data > 0 then
		-- Validate it's JSON
		local ok = pcall (function () return (HttpService :: HttpService):JSONDecode (cacheResult.data) end)
		if ok then return cacheResult.data end
	end

	-- Try fetching from rbxcdn
	if clientVersion then
		local ok, deployHistory = pcall (
			function () return game:HttpGet ("https://setup.rbxcdn.com/DeployHistory.txt", true) end
		)

		if ok and deployHistory then
			local matchingVersions = {}
			local isMatched = false
			local clientVersionStr = tostring (clientVersion)

			-- Parse DeployHistory.txt
			for line in string.gmatch (deployHistory, "[^\n]+") do
				local fileVersion = string.match (line, "file version: ([%d, ]+)")

				if fileVersion then
					local parts = string.split (fileVersion, ", ")
					if parts[2] == clientVersionStr then
						isMatched = true
						local versionHash = string.match (line, "(version%-[^%s]+)")
						if versionHash then matchingVersions[versionHash] = true end
					elseif isMatched then
						break
					end
				end
			end

			-- Try downloading API dump for matched versions
			for versionHash in matchingVersions do
				local url = `https://setup.rbxcdn.com/{versionHash}-Full-API-Dump.json`
				local ok2, result = pcall (function () return game:HttpGet (url, true) end)

				if ok2 and result then
					-- Validate and minify
					local parseOk, parsed = pcall (
						function () return (HttpService :: HttpService):JSONDecode (result) end
					)

					if parseOk and parsed and parsed.Classes then
						-- Minify by encoding just Classes
						local minified = (HttpService :: HttpService):JSONEncode (parsed.Classes)

						-- Cache it
						Executor.writeFile (cachedFileName, minified)

						return minified
					end
				end
			end
		end
	end

	-- Fallback to latest from MaximumADHD's tracker
	warn ("[API Dump] Failed to get version-matched dump, using latest...")
	local ok, result = pcall (
		function ()
			return game:HttpGet (
				"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json",
				true
			)
		end
	)

	if ok and result then
		local parseOk, parsed = pcall (function () return (HttpService :: HttpService):JSONDecode (result) end)

		if parseOk and parsed and parsed.Classes then
			local minified = (HttpService :: HttpService):JSONEncode (parsed.Classes)
			Executor.writeFile (cachedFileName, minified)
			return minified
		end
	end

	return nil
end

--[=[
	Builds inherited properties list for a class

	Recursively walks superclass chain and collects all properties.

	@param className string -- Class name
	@param classList ClassList -- Full class list
	@return {PropertyDescriptor} -- All inherited properties
]=]
local function getInheritedProperties (className: string, classList: ClassList): { PropertyDescriptor }
	local result = {}
	local current = className

	while current do
		local class = classList[current]
		if not class then break end

		-- Add this class's properties
		for _, prop in class.Properties do
			table.insert (result, prop)
		end

		current = class.Superclass
	end

	return result
end

--[=[
	Builds ClassList from API dump JSON

	Parses API dump and applies property filtering, NotScriptable fixes,
	and exception handling.

	@param apiDumpJson string -- JSON string from API dump
	@return ClassList? -- Parsed class list or nil on error
]=]
local function buildClassList (apiDumpJson: string): ClassList?
	if not HttpService then return nil end

	local ok, classes = pcall (function () return (HttpService :: HttpService):JSONDecode (apiDumpJson) end)

	if not ok or not classes then
		warn ("[API Dump] Failed to parse API dump JSON")
		return nil
	end

	local classList: ClassList = {}

	-- First pass: Create all class descriptors
	for _, apiClass in classes do
		local className = apiClass.Name
		local properties = {}

		local class: ClassDescriptor = {
			Properties = properties,
			Superclass = apiClass.Superclass,
		}

		-- Parse tags
		if apiClass.Tags then class.Tags = TableUtil.arrayToDict (apiClass.Tags) end

		-- Get NotScriptable fixes for this class
		local notScriptableFix = NotScriptableFixes.fixes[className]

		-- Parse properties
		for _, member in apiClass.Members or {} do
			if member.MemberType == "Property" then
				local serialization = member.Serialization

				-- Check if property should be saved
				if serialization.CanLoad then
					local propertyName = member.Name
					local valueType = member.ValueType
					local valueTypeName = valueType.Name

					-- Skip Content type for client version >= 645 (Roblox hasn't added descriptor yet)
					local clientVersion = Executor.clientVersion
					if clientVersion and clientVersion >= 645 and valueTypeName == "Content" then continue end

					-- Check exceptions
					local shouldSave =
						ClassPropertyExceptions.shouldSave (className, propertyName, serialization.CanSave)

					if shouldSave == false then
						continue -- Blacklisted
					elseif shouldSave == nil and not serialization.CanSave then
						continue -- Not whitelisted and CanSave=false
					end

					-- Parse tags
					local isSpecial = false
					local preferredDescriptorName = nil

					if member.Tags then
						for _, tag in member.Tags do
							if type (tag) == "table" and tag.PreferredDescriptorName then
								preferredDescriptorName = tag.PreferredDescriptorName
							elseif tag == "NotScriptable" then
								isSpecial = true
							end
						end
					end

					-- Build property descriptor
					local prop: PropertyDescriptor = {
						Name = propertyName,
						ValueType = valueTypeName,
						Category = valueType.Category,
						Special = isSpecial,
						CanRead = nil,
					}

					-- Handle Optional types (e.g., OptionalCoordinateFrame)
					if string.sub (valueTypeName, 1, 8) == "Optional" then
						prop.Optional = string.sub (valueTypeName, 9)
					end

					-- Apply NotScriptable fix
					if notScriptableFix then
						local fix = notScriptableFix[propertyName]

						if fix then
							if type (fix) == "function" then
								-- Custom serialization function
								prop.Fallback = fix
							elseif preferredDescriptorName then
								-- Try PreferredDescriptorName first, then fallback to mapped name
								prop.Fallback = function (instance: Instance): any
									local ok, result = pcall (
										function () return (instance :: any)[preferredDescriptorName] end
									)
									if ok then return result end
									return (instance :: any)[fix]
								end
							else
								-- Simple property name mapping
								prop.Fallback = function (instance: Instance): any return (instance :: any)[fix] end
							end
						end
					elseif preferredDescriptorName then
						-- Only PreferredDescriptorName
						prop.Fallback = function (instance: Instance): any
							return (instance :: any)[preferredDescriptorName]
						end
					end

					table.insert (properties, prop)
				end
			end
		end

		classList[className] = class
	end

	return classList
end

--[=[
	Fetches and builds complete ClassList

	Downloads API dump, parses it, and applies all filtering.

	@param clientVersion number? -- Client version (optional)
	@return ClassList? -- Class list or nil on error
]=]
local function fetchAndBuild (clientVersion: number?): ClassList?
	local apiDumpJson = fetchApiDump (clientVersion)
	if not apiDumpJson then
		warn ("[API Dump] Failed to fetch API dump")
		return nil
	end

	return buildClassList (apiDumpJson)
end

return {
	fetchApiDump = fetchApiDump,
	buildClassList = buildClassList,
	fetchAndBuild = fetchAndBuild,
	getInheritedProperties = getInheritedProperties,
}
