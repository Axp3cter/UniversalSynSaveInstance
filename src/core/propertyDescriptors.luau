--[[
	Property Descriptors - Property metadata and default values

	Tracks inherited properties, default values, and property metadata
	for accurate serialization and default value filtering.

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

-- Cache for inherited properties by class
local inheritedProperties: { [string]: { [string]: boolean } } = {}

-- Cache for default instance values by class
local defaultInstances: { [string]: Instance } = {}

--[=[
	Gets or creates a default instance for a class

	@param className string -- Class name
	@return Instance? -- Default instance or nil if not creatable
]=]
local function getDefaultInstance (className: string): Instance?
	if defaultInstances[className] then return defaultInstances[className] end

	local ok, instance = pcall (Instance.new, className)
	if ok and instance then
		defaultInstances[className] = instance
		return instance
	end

	return nil
end

--[=[
	Gets default property value for a class

	@param className string -- Class name
	@param propertyName string -- Property name
	@return (boolean, any) -- Success and default value
]=]
local function getDefaultValue (className: string, propertyName: string): (boolean, any)
	local defaultInstance = getDefaultInstance (className)
	if not defaultInstance then return false, nil end

	local ok, value = pcall (function () return (defaultInstance :: any)[propertyName] end)

	return ok, value
end

--[=[
	Checks if property value matches default

	@param instance Instance -- Instance to check
	@param propertyName string -- Property name
	@param currentValue any -- Current property value
	@return boolean -- True if matches default
]=]
local function isDefaultValue (instance: Instance, propertyName: string, currentValue: any): boolean
	local ok, defaultValue = getDefaultValue (instance.ClassName, propertyName)

	if not ok then return false end

	-- Handle different value types
	if typeof (currentValue) ~= typeof (defaultValue) then return false end

	-- Direct equality check (works for primitives and some types)
	if currentValue == defaultValue then return true end

	-- Special handling for types that need deep comparison
	local valueType = typeof (currentValue)

	if valueType == "Vector3" or valueType == "Vector2" or valueType == "CFrame" then
		-- These types have proper equality operators
		return currentValue == defaultValue
	elseif valueType == "Color3" then
		return currentValue.R == defaultValue.R
			and currentValue.G == defaultValue.G
			and currentValue.B == defaultValue.B
	elseif valueType == "UDim2" then
		return currentValue.X == defaultValue.X and currentValue.Y == defaultValue.Y
	end

	return false
end

--[=[
	Marks property as inherited for a class

	@param className string -- Class name
	@param propertyName string -- Property name
]=]
local function markInherited (className: string, propertyName: string): ()
	if not inheritedProperties[className] then inheritedProperties[className] = {} end

	inheritedProperties[className][propertyName] = true
end

--[=[
	Checks if property is inherited

	@param className string -- Class name
	@param propertyName string -- Property name
	@return boolean -- True if inherited
]=]
local function isInherited (className: string, propertyName: string): boolean
	if not inheritedProperties[className] then return false end

	return inheritedProperties[className][propertyName] == true
end

--[=[
	Clears all caches

	Useful for testing or memory management
]=]
local function clearCaches (): ()
	table.clear (inheritedProperties)

	for _, instance in defaultInstances do
		pcall (function () instance:Destroy () end)
	end

	table.clear (defaultInstances)
end

return {
	getDefaultInstance = getDefaultInstance,
	getDefaultValue = getDefaultValue,
	isDefaultValue = isDefaultValue,
	markInherited = markInherited,
	isInherited = isInherited,
	clearCaches = clearCaches,
}
