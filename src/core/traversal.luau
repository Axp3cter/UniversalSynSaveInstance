--[[
	Traversal - Walk instance tree
	@author Aspecter | @version 2.0.0
]]

local Services = require ("@utilities/services")
local Types = require ("@types")

export type Options = Types.TraversalOptions

local function shouldIsolate (inst: Instance, opts: Options): (boolean, string?)
	-- Check if this instance should be isolated into a separate folder
	local Players = Services.getService ("Players")

	if opts.isolateLocalPlayer and Players then
		local LocalPlayer = (Players :: Players).LocalPlayer
		if LocalPlayer and (inst == LocalPlayer or inst:IsDescendantOf (LocalPlayer)) then
			return true, "LocalPlayer"
		end
	end

	if opts.isolateLocalPlayerCharacter and Players then
		local LocalPlayer = (Players :: Players).LocalPlayer
		if LocalPlayer and LocalPlayer.Character then
			local character = LocalPlayer.Character
			if inst == character or inst:IsDescendantOf (character) then return true, "LocalPlayerCharacter" end
		end
	end

	if opts.isolateStarterPlayer then
		local StarterPlayer = Services.getService ("StarterPlayer")
		if StarterPlayer and (inst == StarterPlayer or inst:IsDescendantOf (StarterPlayer)) then
			return true, "StarterPlayer"
		end
	end

	return false, nil
end

local function isDefaultPlayerScript (inst: Instance): boolean
	-- Check if this is a default script in player-related containers
	local StarterGui = Services.getService ("StarterGui")
	local StarterPlayer = Services.getService ("StarterPlayer")
	local Players = Services.getService ("Players")

	-- Check StarterGui default scripts
	if StarterGui and inst:IsDescendantOf (StarterGui) then
		-- Common default script names
		local name = inst.Name
		if name == "RbxCharacterSounds" or name == "RbxCameraScript" or name == "ControlScript" then return true end
	end

	-- Check StarterPlayer default scripts
	if StarterPlayer then
		local StarterPlayerScripts = StarterPlayer:FindFirstChild ("StarterPlayerScripts")
		local StarterCharacterScripts = StarterPlayer:FindFirstChild ("StarterCharacterScripts")

		if StarterPlayerScripts and inst:IsDescendantOf (StarterPlayerScripts) then
			local name = inst.Name
			if name == "CameraScript" or name == "ControlScript" then return true end
		end

		if StarterCharacterScripts and inst:IsDescendantOf (StarterCharacterScripts) then
			local name = inst.Name
			if name == "Animate" or name == "Health" or name == "Sound" or name == "RbxCharacterSounds" then
				return true
			end
		end
	end

	-- Check LocalPlayer.PlayerGui default scripts
	if Players then
		local LocalPlayer = (Players :: Players).LocalPlayer
		if LocalPlayer then
			local PlayerGui = LocalPlayer:FindFirstChild ("PlayerGui")
			if PlayerGui and inst:IsDescendantOf (PlayerGui) then
				local name = inst.Name
				if name == "RbxChatScript" or name == "BubbleChat" then return true end
			end
		end
	end

	return false
end

local function include (inst: Instance, opts: Options): boolean
	if not opts.ignoreNotArchivable then
		if not inst.Archivable then return false end
	end

	if opts.removePlayerCharacters then
		local Players = Services.getService ("Players")
		if Players then
			local list = (Players :: Players):GetPlayers ()

			for _, player in list do
				local character = player.Character
				if character then
					if inst == character or inst:IsDescendantOf (character) then return false end
				end
			end
		end
	end

	-- Filter default player scripts if option enabled
	if opts.ignoreDefaultPlayerScripts then
		local className = inst.ClassName
		if className == "LocalScript" or className == "Script" or className == "ModuleScript" then
			if isDefaultPlayerScript (inst) then return false end
		end
	end

	return true
end

local function walk (inst: Instance, opts: Options, output: { Instance }): ()
	if not include (inst, opts) then return end

	table.insert (output, inst)

	local children = inst:GetChildren ()
	for _, child in children do
		walk (child, opts, output)
	end
end

local function traverse (opts: Options): { Instance }
	local output: { Instance } = {}

	if opts.object then
		walk (opts.object, opts, output)
	else
		local children = game:GetChildren ()
		for _, child in children do
			walk (child, opts, output)
		end
	end

	-- Get nil instances using executor wrapper
	if opts.nilInstances then
		local Executor = require ("@utilities/executor")
		local nilResult = Executor.getNilInstances ()

		if nilResult.success and nilResult.data then
			for _, inst in nilResult.data do
				if typeof (inst) == "Instance" and include (inst, opts) and not table.find (output, inst) then
					table.insert (output, inst)
				end
			end
		end
	end

	-- Add extra instances with deduplication
	if opts.extraInstances then
		for _, inst in opts.extraInstances do
			if include (inst, opts) and not table.find (output, inst) then table.insert (output, inst) end
		end
	end

	return output
end

return {
	traverse = traverse,
	shouldIsolate = shouldIsolate,
}
