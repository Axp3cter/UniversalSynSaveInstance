--[[
	Services Utility - Cached Service Access

	Safe, cached access to Roblox services with multiple fallback strategies.
	Automatically uses cloneRef when available for security.

	@author Aspecter
	@version 2.0.0
]]

local cloneRef = require("@utilities/executor").cloneRef

export type Service = Instance | SomeOtherService | UserGameSettings

local cache: { [string]: Service } = {}

-- Safe call wrapper
local function tryGet(fn: () -> Service): Service?
	local ok, result = pcall(fn)
	return if ok then result else nil
end

--[=[
	Retrieves service with caching and fallback strategies

	Attempts retrieval in order:
	1. Instance.new (for service classes)
	2. game:GetService (standard access)
	3. settings():GetService (settings services)
	4. UserSettings():GetService (user services)

	Successfully retrieved services are cached and cloneref'd.

	@param name string -- Service name
	@return Service? -- Service instance or nil
]=]
return function(name: string): Service?
	-- Return cached service
	if cache[name] then
		return cache[name]
	end

	-- Try multiple access methods
	local service = tryGet(function()
		return Instance.new(name) :: Service
	end)
		or tryGet(function()
			return game:GetService(name) :: Service
		end)
		or tryGet(function()
			return settings():GetService(name) :: Service
		end)
		or tryGet(function()
			return UserSettings():GetService(name :: any) :: Service
		end)

	if service then
		-- Clone reference using executor wrapper
		local result = cloneRef(service :: Instance):expect()
		service = if result.success and result.data then result.data else service

		-- Cache the service
		cache[name] = service
	end

	return service
end
