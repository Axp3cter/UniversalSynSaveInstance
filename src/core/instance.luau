--[[
	Instance Serializer - Format agnostic instance preparation

	Provides common logic for collecting and filtering Instance properties
	before handing them off to format specific serializers (XML, binary, etc).
	This keeps shared functionality outside of format folders.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local Properties = require ("@core/properties")
local Types = require ("@types")

export type Options = Types.InstanceOptions
export type SerializedProperty = Types.PropertyValue
export type SerializedInstance = Types.SerializedInstance

-- Non-creatable service classes that should be converted to Folder when saveNotCreatable is true
local NON_CREATABLE_SERVICES: { string } = {
	"Workspace",
	"Players",
	"Lighting",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"Chat",
	"LocalizationService",
	"TestService",
}

local function isNotCreatable (className: string): boolean
	for _, service in NON_CREATABLE_SERVICES do
		if className == service then return true end
	end
	return false
end

--[=[
	Collects and filters properties for the given Instance

	Reads all properties from instance and filters based on options.
	Default value filtering should be handled by property descriptor system.

	@param instance Instance -- Instance to serialize
	@param opts Options -- Serialization options
	@return SerializedInstance -- Serialized instance with filtered properties
]=]
local function serialize (instance: Instance, opts: Options): SerializedInstance
	local className = instance.ClassName

	-- Convert non-creatable services to Folder if option is enabled
	if opts.saveNotCreatable and isNotCreatable (className) then className = "Folder" end

	local propOpts = {
		ignoreProperties = opts.ignoreProperties,
		ignoreDefaultProperties = opts.ignoreDefaultProperties,
		ignoreSpecialProperties = opts.ignoreSpecialProperties,
		ignoreNonScriptProperties = opts.ignoreNonScriptProperties,
		mode = opts.mode,
	}

	local properties = Properties.read (instance, propOpts)
	local filtered: { SerializedProperty } = {}

	-- Filter nil values and sort
	for _, prop in properties do
		if prop.value ~= nil then table.insert (filtered, prop) end
	end

	table.sort (filtered, function (a, b) return a.name < b.name end)

	return {
		className = className,
		properties = filtered,
	}
end

return {
	serialize = serialize,
}
