--[[
	Properties - Read instance properties
	@author Aspecter | @version 2.0.0
]]

local Types = require("@types")
local Executor = require("@utilities/executor")

export type Options = {
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean,
	ignoreSpecialProperties: boolean,
	mode: Types.SaveMode,
}

export type PropertyValue = {
	name: string,
	value: any,
	valueType: string,
}

local IGNORED_PROPERTIES: { string } = {
	"Parent",
	"DataCost",
	"RobloxLocked",
}

local function skip(propName: string, opts: Options): boolean
	for _, ignored in IGNORED_PROPERTIES do
		if propName == ignored then
			return true
		end
	end

	local userIgnored = opts.ignoreProperties
	if userIgnored then
		for _, ignored in userIgnored do
			if propName == ignored then
				return true
			end
		end
	end

	return false
end

local function get(inst: Instance, propName: string, useHidden: boolean): (boolean, any)
	if useHidden and Executor.hasFunction("gethiddenproperty") then
		local result = Executor.getHiddenProperty(inst, propName):expect()
		if result.success then
			return true, result.data
		end
	end

	local success, value = pcall(function()
		return (inst :: any)[propName]
	end)

	return success, value
end

local function read(inst: Instance, opts: Options): { PropertyValue }
	local properties: { PropertyValue } = {}
	local useHidden = not opts.ignoreSpecialProperties
	local propNames: { string } = {}

	local success = pcall(function()
		for key in (inst :: any) do
			if type(key) == "string" then
				table.insert(propNames, key)
			end
		end
	end)

	if not success then
		return properties
	end

	for _, propName in propNames do
		if not skip(propName, opts) then
			local ok, value = get(inst, propName, useHidden)

			if ok and value ~= nil then
				local prop: PropertyValue = {
					name = propName,
					value = value,
					valueType = typeof(value),
				}
				table.insert(properties, prop)
			end
		end
	end

	return properties
end

local function getProperty(inst: Instance, propName: string, useHidden: boolean?): (boolean, any)
	local shouldUseHidden = if useHidden ~= nil then useHidden else true
	return get(inst, propName, shouldUseHidden)
end

return {
	read = read,
	getProperty = getProperty,
}
