--[[
	Class Property Exceptions - Whitelist and blacklist for specific properties

	Defines exceptions to normal property serialization rules:
	- Whitelist: Properties that should be saved even if marked as CanSave=false
	- Blacklist: Properties that should never be saved

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

export type PropertySet = { [string]: boolean }

export type ClassExceptions = {
	Whitelist: { [string]: PropertySet },
	Blacklist: { [string]: PropertySet },
}

-- Properties that should be saved even if CanSave=false
local whitelist: { [string]: PropertySet } = {
	-- Mesh parts need CollisionFidelity for proper physics
	MeshPart = {
		CollisionFidelity = true,
	},

	PartOperation = {
		CollisionFidelity = true,
	},

	TriangleMeshPart = {
		CollisionFidelity = true,
	},
}

-- Properties that should never be saved
local blacklist: { [string]: PropertySet } = {
	-- Script GUIDs change on every save and cause diff noise
	LuaSourceContainer = {
		ScriptGuid = true,
	},

	-- UniqueId and HistoryId are unstable and cause diff noise
	Instance = {
		UniqueId = true,
		HistoryId = true,
	},
}

--[=[
	Checks if property is whitelisted for a class

	@param className string -- Class name
	@param propertyName string -- Property name
	@return boolean -- True if whitelisted
]=]
local function isWhitelisted (className: string, propertyName: string): boolean
	local classWhitelist = whitelist[className]
	if not classWhitelist then return false end
	return classWhitelist[propertyName] == true
end

--[=[
	Checks if property is blacklisted for a class

	@param className string -- Class name
	@param propertyName string -- Property name
	@return boolean -- True if blacklisted
]=]
local function isBlacklisted (className: string, propertyName: string): boolean
	local classBlacklist = blacklist[className]
	if not classBlacklist then return false end
	return classBlacklist[propertyName] == true
end

--[=[
	Checks if property should be saved

	Considers both whitelist and blacklist.
	Returns true if explicitly whitelisted, false if blacklisted, nil if neither.

	@param className string -- Class name
	@param propertyName string -- Property name
	@param canSave boolean -- CanSave flag from API dump
	@return boolean? -- True to save, false to skip, nil for default behavior
]=]
local function shouldSave (className: string, propertyName: string, canSave: boolean): boolean?
	-- Blacklist overrides everything
	if isBlacklisted (className, propertyName) then return false end

	-- Whitelist allows saving even if CanSave=false
	if isWhitelisted (className, propertyName) then return true end

	-- Use CanSave flag for decision
	return if canSave then true else nil
end

return {
	whitelist = whitelist,
	blacklist = blacklist,
	isWhitelisted = isWhitelisted,
	isBlacklisted = isBlacklisted,
	shouldSave = shouldSave,
}
