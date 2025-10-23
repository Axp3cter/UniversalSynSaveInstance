--[[
	Traversal - Walk instance tree

	Provides comprehensive instance tree traversal with:
	- Mode-based ToSaveList building (full/optimized/scripts)
	- IgnoreList and DecompileIgnore filtering
	- Player isolation and character removal
	- Default script filtering
	- NilInstances and ExtraInstances support

	@author Aspecter
	@version 2.0.0
]]

local Services = require ("@utilities/services")
local Types = require ("@types")

export type Options = Types.TraversalOptions

-- Services for optimized mode
local OPTIMIZED_SERVICES = {
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService", -- LoadStringEnabled property
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"Chat",
	"TextChatService",
	"LocalizationService", -- For LocalizationTables
	"JointsService",
}

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

--[=[
	Checks if instance should be ignored based on IgnoreList

	@param instance Instance
	@param ignoreList {[any]: boolean | {[string]: boolean}}?
	@return boolean | "descendants" -- true = skip entirely, "descendants" = skip descendants only
]=]
local function checkIgnoreList (
	instance: Instance,
	ignoreList: { [any]: boolean | { [string]: boolean } }?
): boolean | "descendants"
	if not ignoreList then return false end

	local className = instance.ClassName
	local name = instance.Name

	-- Check direct instance reference
	local directCheck = ignoreList[instance]
	if directCheck == true then
		return true
	elseif directCheck == false then
		return "descendants"
	end

	-- Check by ClassName
	local classCheck = ignoreList[className]
	if classCheck == true then
		return true
	elseif classCheck == false then
		return "descendants"
	elseif type (classCheck) == "table" then
		-- Check by ClassName + Name
		if (classCheck :: any)[name] then return true end
	end

	return false
end

local function include (inst: Instance, opts: Options): boolean
	-- Check IgnoreList
	local ignoreCheck = checkIgnoreList (inst, opts.ignoreList)
	if ignoreCheck == true then return false end
	-- Note: "descendants" case is handled in walk() function

	if opts.ignoreNotArchivable then
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

	-- Check if we should skip descendants
	local ignoreCheck = checkIgnoreList (inst, opts.ignoreList)
	if ignoreCheck == "descendants" then return end

	local children = inst:GetChildren ()
	for _, child in children do
		walk (child, opts, output)
	end
end

--[=[
	Checks if instance is a LuaSourceContainer

	@param instance Instance
	@return boolean
]=]
local function isLuaSourceContainer (instance: Instance): boolean return instance:IsA ("LuaSourceContainer") end

--[=[
	Builds ToSaveList for full mode

	Includes all game children.

	@param object Instance? -- Optional object to save
	@return {Instance}
]=]
local function buildFullList (object: Instance?): { Instance }
	local root = object or game
	local list: { Instance } = {}

	if object and object ~= game then
		-- If specific object (not game), just return it
		return { object }
	end

	-- Get all game children
	local children = root:GetChildren ()
	for _, child in children do
		table.insert (list, child)
	end

	return list
end

--[=[
	Builds ToSaveList for optimized mode

	Includes only essential services.

	@return {Instance}
]=]
local function buildOptimizedList (): { Instance }
	local list: { Instance } = {}
	local listDict = {}

	for _, serviceName in OPTIMIZED_SERVICES do
		-- Use FindService to check existence without creating
		local service = game:FindService (serviceName)
		if service and not listDict[service] then
			table.insert (list, service)
			listDict[service] = true
		end
	end

	return list
end

--[=[
	Builds ToSaveList for scripts mode

	Finds all scripts and includes their parent trees.

	@param object Instance? -- Root to search from
	@return {Instance}
]=]
local function buildScriptsList (object: Instance?): { Instance }
	local root = object or game
	local unique: { [Instance]: boolean } = {}

	-- Find all scripts
	for _, instance in root:GetDescendants () do
		if isLuaSourceContainer (instance) then
			-- Walk up to root and mark top-level parent
			local current = instance
			local parent = current.Parent

			while parent and parent ~= root do
				current = parent
				parent = current.Parent
			end

			if parent then unique[current] = true end
		end
	end

	-- Convert to array
	local list: { Instance } = {}
	for instance in unique do
		table.insert (list, instance)
	end

	return list
end

--[=[
	Builds initial ToSaveList based on mode

	@param mode SaveMode -- Save mode
	@param object Instance? -- Optional object to save
	@return {Instance}
]=]
local function buildToSaveList (mode: string, object: Instance?): { Instance }
	if mode == "full" then
		return buildFullList (object)
	elseif mode == "optimized" then
		if object then
			-- Optimized mode is incompatible with Object saves
			return { object }
		end
		return buildOptimizedList ()
	elseif mode == "scripts" then
		return buildScriptsList (object)
	else
		-- Invalid mode or mode with only ExtraInstances/Object
		return if object then { object } else {}
	end
end

--[=[
	Traverses instance tree based on options

	Builds initial list based on mode, then walks all instances with filtering.

	@param opts Options -- Traversal options
	@return {Instance} -- Filtered list of instances
]=]
local function traverse (opts: Options): { Instance }
	-- Build initial list based on mode
	local toSaveList = buildToSaveList (opts.mode, opts.object)

	-- Walk all instances in the list
	local output: { Instance } = {}
	for _, instance in toSaveList do
		walk (instance, opts, output)
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
