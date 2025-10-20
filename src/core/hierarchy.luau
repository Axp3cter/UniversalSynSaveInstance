--[[
	Hierarchy Builder - Shared instance tree construction

	Produces parent/child relationships for a collection of Instances so
	format-specific serializers (XML, binary, etc.) can render output using
	the same structural information.

	This logic is shared between XML and binary serialization.
]]

export type Node = {
	instance: Instance,
	children: { Node },
}

local function build(instances: { Instance }): { Node }
	local nodes: { [Instance]: Node } = {}
	local roots: { Node } = {}

	for _, inst in instances do
		nodes[inst] = {
			instance = inst,
			children = {},
		}
	end

	for inst, node in nodes do
		local parent = inst.Parent
		local parentNode = if parent then nodes[parent] else nil

		if parentNode then
			table.insert(parentNode.children, node)
		else
			table.insert(roots, node)
		end
	end

	return roots
end

return {
	build = build,
}

