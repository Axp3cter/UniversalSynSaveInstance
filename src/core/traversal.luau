--[[
	Traversal - Walk instance tree
	@author Aspecter | @version 2.0.0
]]

local Types = require("@types")
local Services = require("@utilities/services")

export type Options = {
	mode: Types.SaveMode,
	object: Instance?,
	nilInstances: boolean,
	extraInstances: { Instance }?,
	ignoreNotArchivable: boolean,
	removePlayerCharacters: boolean,
}

local function include(inst: Instance, opts: Options): boolean
	if not opts.ignoreNotArchivable then
		if not inst.Archivable then
			return false
		end
	end

	if opts.removePlayerCharacters then
		local Players = Services("Players")
		if Players then
			local list = (Players :: Players):GetPlayers()

			for _, player in list do
				local character = player.Character
				if character then
					if inst == character or inst:IsDescendantOf(character) then
						return false
					end
				end
			end
		end
	end

	return true
end

local function walk(inst: Instance, opts: Options, output: { Instance }): ()
	if not include(inst, opts) then
		return
	end

	table.insert(output, inst)

	local children = inst:GetChildren()
	for _, child in children do
		walk(child, opts, output)
	end
end

local function traverse(opts: Options): { Instance }
	local output: { Instance } = {}

	if opts.object then
		walk(opts.object, opts, output)
	else
		local children = game:GetChildren()
		for _, child in children do
			walk(child, opts, output)
		end
	end

	if opts.nilInstances then
		local env = getgenv and getgenv()
		if env and env.getnilinstances then
			local success, nils = pcall(env.getnilinstances)
			if success and nils then
				for _, inst in nils do
					if include(inst, opts) then
						table.insert(output, inst)
					end
				end
			end
		end
	end

	if opts.extraInstances then
		for _, inst in opts.extraInstances do
			if include(inst, opts) then
				table.insert(output, inst)
			end
		end
	end

	return output
end

return {
	traverse = traverse,
}
