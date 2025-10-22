--[[
	Properties - Read instance properties
	@author Aspecter | @version 2.0.0
]]

local Executor = require ("@utilities/executor")
local Types = require ("@types")

export type Options = Types.PropertyOptions
export type PropertyValue = Types.PropertyValue

local IGNORED_PROPERTIES: { string } = {
	"Parent",
	"DataCost",
	"RobloxLocked",
}

-- Script-related properties that should be kept in scripts mode
local SCRIPT_PROPERTIES: { string } = {
	"Source",
	"Name",
	"ClassName",
	"Disabled",
	"RunContext",
	"LinkedSource",
}

local function isScriptProperty (propName: string): boolean
	for _, scriptProp in SCRIPT_PROPERTIES do
		if propName == scriptProp then return true end
	end
	return false
end

local function skip (propName: string, opts: Options, inst: Instance): boolean
	-- Always skip core ignored properties
	for _, ignored in IGNORED_PROPERTIES do
		if propName == ignored then return true end
	end

	-- User-specified ignore list
	local userIgnored = opts.ignoreProperties
	if userIgnored then
		for _, ignored in userIgnored do
			if propName == ignored then return true end
		end
	end

	-- In scripts mode with ignoreNonScriptProperties, skip non-script properties
	if opts.ignoreNonScriptProperties and opts.mode == "scripts" then
		-- Check if instance is a script
		local className = inst.ClassName
		local isScript = className == "LocalScript" or className == "Script" or className == "ModuleScript"

		if isScript and not isScriptProperty (propName) then return true end
	end

	return false
end

local function get (inst: Instance, propName: string, useHidden: boolean): (boolean, any)
	if useHidden and Executor.hasFunction ("gethiddenproperty") then
		local result = Executor.getHiddenProperty (inst, propName)
		if result.success and result.data ~= nil then return true, result.data end
	end

	local success, value = pcall (function () return (inst :: any)[propName] end)

	return success, value
end

local function read (inst: Instance, opts: Options): { PropertyValue }
	local properties: { PropertyValue } = {}
	local useHidden = not opts.ignoreSpecialProperties
	local propNames: { string } = {}

	local success = pcall (function ()
		for key in inst :: any do
			if type (key) == "string" then table.insert (propNames, key) end
		end
	end)

	if not success then return properties end

	for _, propName in propNames do
		if not skip (propName, opts, inst) then
			local ok, value = get (inst, propName, useHidden)

			if ok and value ~= nil then
				local prop: PropertyValue = {
					name = propName,
					value = value,
					valueType = typeof (value),
				}
				table.insert (properties, prop)
			end
		end
	end

	return properties
end

local function getProperty (inst: Instance, propName: string, useHidden: boolean?): (boolean, any)
	local shouldUseHidden = if useHidden ~= nil then useHidden else true
	return get (inst, propName, shouldUseHidden)
end

return {
	read = read,
	getProperty = getProperty,
}
