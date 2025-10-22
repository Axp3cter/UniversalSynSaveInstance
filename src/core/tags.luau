--[[
	Tags - CollectionService tag serialization
	@author Aspecter | @version 1.0.0
]]

local Services = require ("@utilities/services")
local Types = require ("@types")

export type Options = Types.TagOptions

local function read (inst: Instance, opts: Options?): { string }
	local CollectionService = Services.getService ("CollectionService")
	if not CollectionService then return {} end

	local ok, tags = pcall (function () return (CollectionService :: any):GetTags (inst) end)

	return if ok and tags then tags else {}
end

local function serialize (tags: { string }): string return table.concat (tags, ",") end

return {
	read = read,
	serialize = serialize,
}
