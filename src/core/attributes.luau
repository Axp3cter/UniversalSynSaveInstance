--[[
	Attributes - Read instance attributes
	@author Aspecter | @version 2.0.0
]]

local Types = require("@types")

export type Options = {
	mode: Types.SaveMode,
}

export type Attribute = {
	name: string,
	value: any,
	valueType: string,
}

local function read(inst: Instance, opts: Options): { Attribute }
	local attributes: { Attribute } = {}

	local success, result = pcall(function()
		return inst:GetAttributes()
	end)

	if not success or not result then
		return attributes
	end

	for name, value in result do
		local attr: Attribute = {
			name = name,
			value = value,
			valueType = typeof(value),
		}
		table.insert(attributes, attr)
	end

	return attributes
end

return {
	read = read,
}
