--[[
	Instance Serializer - Format agnostic instance preparation

	Provides common logic for collecting and filtering Instance properties
	before handing them off to format specific serializers (XML, binary, etc).
	This keeps shared functionality outside of format folders.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local Types = require("@types")
local Properties = require("@core/properties")

export type Options = {
	mode: Types.SaveMode,
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean,
	ignoreSpecialProperties: boolean,
}

export type SerializedProperty = Properties.PropertyValue

export type SerializedInstance = {
	className: string,
	properties: { SerializedProperty },
}

-- Determines if a property should be included in the serialized output.
local function shouldSerialize(prop: SerializedProperty, opts: Options): boolean
	if prop.value == nil then
		return false
	end

	if opts.mode == "optimized" and opts.ignoreDefaultProperties then
		-- TODO: Hook default value comparison once available.
		return true
	end

	return true
end

-- Collects and filters properties for the given Instance.
local function serialize(instance: Instance, opts: Options): SerializedInstance
	local propOpts = {
		ignoreProperties = opts.ignoreProperties,
		ignoreDefaultProperties = opts.ignoreDefaultProperties,
		ignoreSpecialProperties = opts.ignoreSpecialProperties,
		mode = opts.mode,
	}

	local properties = Properties.read(instance, propOpts)
	local filtered: { SerializedProperty } = {}

	for _, prop in properties do
		if shouldSerialize(prop, opts) then
			table.insert(filtered, prop)
		end
	end

	table.sort(filtered, function(a, b)
		return a.name < b.name
	end)

	return {
		className = instance.ClassName,
		properties = filtered,
	}
end

return {
	serialize = serialize,
	shouldSerialize = shouldSerialize,
}

