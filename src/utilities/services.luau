--[[
	Services Utility - Cached Service Access

	Safe, cached access to Roblox services with multiple fallback strategies.
	Automatically uses cloneref when available for security.

	@author Aspecter
	@version 2.0.0
]]

export type Service = Instance | SomeOtherService | UserGameSettings

local cache: { [string]: Service } = {}

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
	if cache[name] then
		return cache[name]
	end

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
		if cloneref then
			service = tryGet(function()
				return cloneref(service :: Instance)
			end) or service
		end
		cache[name] = service
	end

	return service
end
