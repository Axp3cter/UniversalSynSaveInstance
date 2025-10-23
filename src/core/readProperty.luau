--[[
	Read Property - Property reading with comprehensive fallback chain

	Provides multi-level fallback for reading properties:
	1. Direct property access
	2. gethiddenproperty (sUNC API)
	3. UGCValidationService fallback
	4. NotScriptable fixes
	5. PreferredDescriptorName
	6. Custom serialization functions

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local Executor = require ("@utilities/executor")
local NotScriptableFixes = require ("@core/notScriptableFixes")

export type PropertyDescriptor = {
	Name: string,
	ValueType: string,
	Category: string,
	Special: boolean?, -- NotScriptable
	Optional: string?, -- For OptionalCoordinateFrame -> "CoordinateFrame"
	CanRead: boolean?,
	Fallback: ((instance: Instance) -> any)?,
}

-- Sentinel value to indicate property read failed
local BREAK_SENTINEL = newproxy (true)
getmetatable (BREAK_SENTINEL).__tostring = function () return "__BREAK" end

--[=[
	Reads property value with full fallback chain

	Attempts multiple methods to read a property value:
	1. Standard property access (if not Special/NotScriptable)
	2. gethiddenproperty for Special properties
	3. UGCValidationService fallback
	4. NotScriptable fix function
	5. Property.Fallback function

	@param instance Instance -- Instance to read from
	@param property PropertyDescriptor -- Property metadata
	@return any -- Property value or BREAK_SENTINEL on failure
]=]
local function readProperty (instance: Instance, property: PropertyDescriptor): any
	local propertyName = property.Name
	local isSpecial = property.Special
	local optional = property.Optional

	-- Try direct property access first (if not NotScriptable)
	if not isSpecial then
		local ok, value = pcall (function () return (instance :: any)[propertyName] end)
		if ok then return value end
	end

	-- Try gethiddenproperty for Special properties
	if isSpecial and Executor.api.gethiddenproperty then
		local result = Executor.getHiddenProperty (instance, propertyName)
		if result.success then return result.data end
	end

	-- Try UGCValidationService fallback
	local ok, ugcService = pcall (function () return game:GetService ("UGCValidationService") end)
	if ok and ugcService then
		local success, value = pcall (
			function () return (ugcService :: any):GetPropertyValue (instance, propertyName) end
		)
		if success then return value end
	end

	-- Try NotScriptable fix
	local fix = NotScriptableFixes.getFix (instance.ClassName, propertyName)
	if fix then
		if type (fix) == "function" then
			-- Custom serialization function
			local success, value = pcall (fix, instance)
			if success then return value end
		elseif type (fix) == "string" then
			-- Property name mapping
			local success, value = pcall (function () return (instance :: any)[fix] end)
			if success then return value end
		end
	end

	-- Try property descriptor fallback
	if property.Fallback then
		local success, value = pcall (property.Fallback, instance)
		if success then return value end
	end

	-- If optional and nothing worked, return nil (valid for optional properties)
	if optional then return nil end

	-- All methods failed
	return BREAK_SENTINEL
end

--[=[
	Checks if value is the break sentinel

	@param value any
	@return boolean -- True if value is BREAK_SENTINEL
]=]
local function isBreak (value: any): boolean return value == BREAK_SENTINEL end

--[=[
	Reads property with type category handling

	Handles special cases for Enum and Class categories.

	@param instance Instance
	@param property PropertyDescriptor
	@return any -- Property value or BREAK_SENTINEL
]=]
local function readPropertyWithCategory (instance: Instance, property: PropertyDescriptor): any
	local value = readProperty (instance, property)

	-- Handle category-specific processing
	if not isBreak (value) and property.Category then
		if property.Category == "Enum" then
			-- Enum values are already EnumItem, no conversion needed
			return value
		elseif property.Category == "Class" then
			-- Instance references, no conversion needed
			return value
		end
	end

	return value
end

return {
	readProperty = readProperty,
	readPropertyWithCategory = readPropertyWithCategory,
	isBreak = isBreak,
	BREAK_SENTINEL = BREAK_SENTINEL,
}
