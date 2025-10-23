--[[
	Services Utility - Cached Service Access

	Safe, cached access to Roblox services with multiple fallback strategies.
	Automatically uses cloneref when available for security.

	@author Aspecter
	@version 3.0.0
	@since 2025-01-21
]]

local Executor = require ("@utilities/executor")

export type Service = Instance | SomeOtherService | UserGameSettings

local cache: { [string]: Service } = {}

-- Safe call wrapper
local function tryGet (fn: () -> Service): Service?
	local ok, result = pcall (fn)
	return if ok then result else nil
end

--[=[
	Retrieves service with caching and fallback strategies

	Attempts retrieval in order:
	1. Instance.new (for service classes)
	2. game:GetService (standard access)
	3. settings():GetService (settings services)
	4. UserSettings():GetService (user services)

	Successfully retrieved services are cached and cloneref'd if available.

	@param name string -- Service name
	@return Service? -- Service instance or nil
]=]
local function getService (name: string): Service?
	-- Return cached service
	if cache[name] then return cache[name] end

	-- FIXED: Only use proper service access methods (no Instance.new)
	-- Try in order: game:GetService -> settings:GetService -> UserSettings:GetService
	local service = tryGet (function () return game:GetService (name) :: Service end)
		or tryGet (function () return settings ():GetService (name) :: Service end)
		or tryGet (function () return UserSettings ():GetService (name :: any) :: Service end)

	if service then
		-- Clone reference if available (synchronous operation)
		local cloneResult = Executor.cloneRef (service :: Instance)
		service = if cloneResult.success and cloneResult.data then cloneResult.data else service

		-- Cache the service
		cache[name] = service
	end

	return service
end

--[=[
	Clears service cache

	Useful for testing or when services need to be re-acquired
]=]
local function clearCache (): () table.clear (cache) end

--[=[
	Gets cache statistics

	@return number -- Number of cached services
]=]
local function getCacheSize (): number
	local count = 0
	for _ in cache do
		count += 1
	end
	return count
end

return {
	getService = getService,
	clearCache = clearCache,
	getCacheSize = getCacheSize,
}
