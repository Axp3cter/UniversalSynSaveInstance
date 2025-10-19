--[[
	Roblox Utilities - Roblox Environment Helpers

	Provides utilities for interacting with the Roblox environment.

	@author Aspecter
	@version 1.0.0
]]

--[=[
	Gets Roblox client version number

	Extracts the minor version number from the version() string.
	Format: "major.minor.patch.build" → returns minor.

	@return number -- Client version number (minor component)
]=]
local function getClientVersion(): number
	local parts = string.split(version(), ".")
	return tonumber(parts[2]) or 0
end

return {
	getClientVersion = getClientVersion,
}
