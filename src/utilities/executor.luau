--[[
	Executor Utilities - sUNC API Standard Wrapper

	Provides access to sUNC-compliant executor APIs with proper validation and fallbacks.
	All operations are synchronous as per sUNC specification - no Promise overhead.

	Reference: https://docs.sunc.su/

	@author Aspecter
	@version 3.0.0
	@since 2025-01-21
]]

local Types = require ("@types")

export type Result<T> = Types.Result<T>
export type ExecutorInfo = Types.ExecutorInfo

-- ============================================================================
-- UTILITIES
-- ============================================================================

--[=[
	Normalizes file path to forward slashes

	@param path string -- Path to normalize
	@return string -- Normalized path
]=]
local function normalizePath (path: string): string return path:gsub ("\\", "/") end

--[=[
	Safe call wrapper with error conversion

	@param fn function -- Function to call
	@param ... any -- Arguments
	@return Result<T> -- Result with data or error
]=]
local function trySafe <T>(fn: (...any) -> T, ...: any): Result<T>
	local ok, result = pcall (fn, ...)
	if ok then
		return { success = true, data = result }
	else
		return { success = false, error = tostring (result) }
	end
end

-- ============================================================================
-- sUNC API DETECTION & VALIDATION
-- ============================================================================

--[=[
	Checks if function exists in global environment

	Supports nested paths like "crypt.base64encode"

	@param name string -- Function name (supports dot notation)
	@return boolean -- True if function exists
]=]
local function hasFunction (name: string): boolean
	local parts = string.split (name, ".")
	local current: any = _G

	for _, part in parts do
		if type (current) ~= "table" then return false end
		current = current[part]
		if current == nil then return false end
	end

	return type (current) == "function"
end

--[=[
	Gets function from global environment

	@param name string -- Function name (supports dot notation)
	@return function? -- Function or nil
]=]
local function getFunction (name: string): ((...any) -> ...any)?
	local parts = string.split (name, ".")
	local current: any = _G

	for _, part in parts do
		if type (current) ~= "table" then return nil end
		current = current[part]
		if current == nil then return nil end
	end

	return if type (current) == "function" then current else nil
end

-- ============================================================================
-- EXECUTOR IDENTIFICATION
-- ============================================================================

local executorInfo: ExecutorInfo = { name = "Unknown", version = nil, detected = false }

-- Roblox client version (extracted from version() function)
local clientVersionNumber: number? = nil

-- Initialize executor info and client version on load
do
	-- sUNC standard: identifyexecutor only, no fallbacks
	local identifyFn = identifyexecutor

	if identifyFn then
		local ok, name, version = pcall (identifyFn)
		if ok and name then
			executorInfo.name = tostring (name)
			executorInfo.version = version and tostring (version) or nil
			executorInfo.detected = true
		end
	end

	-- Extract client version from version() function
	-- Format: "0.XXX.Y.ZZZZZ" -> extract XXX as number
	local ok, versionStr = pcall (version)
	if ok and versionStr then
		local parts = string.split (versionStr, ".")
		if #parts >= 2 then
			local versionNum = tonumber (parts[2])
			if versionNum then clientVersionNumber = versionNum end
		end
	end
end

-- ============================================================================
-- DIRECT sUNC API ACCESS
-- ============================================================================

--[=[
	Direct sUNC API table - exact function names per specification

	Access raw sUNC functions directly without wrappers.
	All functions return their native types.
	Check existence before use.

	@class api
]=]
local api = {
	-- Reflection (sUNC standard - exact names only)
	gethiddenproperty = gethiddenproperty,
	sethiddenproperty = sethiddenproperty,
	gethiddenproperties = gethiddenproperties,
	setthreadidentity = setthreadidentity,
	getthreadidentity = getthreadidentity,

	-- Scripts (sUNC standard - exact names only)
	getscriptbytecode = getscriptbytecode,
	getscripthash = getscripthash,
	decompile = decompile,
	getsenv = getsenv,
	getloadedmodules = getloadedmodules,
	getrunningscripts = getrunningscripts,
	getscriptclosure = getscriptclosure,

	-- Instances (sUNC standard - exact names only)
	cloneref = cloneref,
	compareinstances = compareinstances,
	getnilinstances = getnilinstances,
	getinstances = getinstances,
	gethui = gethui,

	-- Cryptography (sUNC standard - exact names in crypt table)
	crypt = {
		base64encode = crypt and crypt.base64encode,
		base64decode = crypt and crypt.base64decode,
		hash = crypt and crypt.hash,
		encrypt = crypt and crypt.encrypt,
		decrypt = crypt and crypt.decrypt,
		generatekey = crypt and crypt.generatekey,
		derivekeypbkdf2 = crypt and crypt.derivekeypbkdf2,
		generatebytes = crypt and crypt.generatebytes,
	},

	-- Debug (sUNC standard - exact names only)
	debug = {
		getconstants = debug.getconstants,
		getconstant = debug.getconstant,
		setconstant = debug.setconstant,
		getupvalues = debug.getupvalues,
		getupvalue = debug.getupvalue,
		setupvalue = debug.setupvalue,
		getstack = debug.getstack,
		setstack = debug.setstack,
		getinfo = debug.getinfo,
		getproto = debug.getproto,
		getprotos = debug.getprotos,
	},

	-- Closures (sUNC standard - exact names only)
	hookfunction = hookfunction,
	restorefunction = restorefunction,
	clonefunction = clonefunction,
	newcclosure = newcclosure,
	iscclosure = iscclosure,
	islclosure = islclosure,
	isexecutorclosure = isexecutorclosure,

	-- Environment (sUNC standard - exact names only)
	getgenv = getgenv,
	getrenv = getrenv,
	getmenv = getmenv,

	-- Filesystem (sUNC standard - exact names only)
	isfile = isfile,
	isfolder = isfolder,
	readfile = readfile,
	writefile = writefile,
	appendfile = appendfile,
	makefolder = makefolder,
	delfolder = delfolder,
	delfile = delfile,
	listfiles = listfiles,
}

-- ============================================================================
-- FALLBACK IMPLEMENTATIONS
-- ============================================================================

--[=[
	Fallback for gethiddenproperty using UGCValidationService

	@param instance Instance
	@param propertyName string
	@return any -- Property value or nil
]=]
local function gethiddenproperty_fallback (instance: Instance, propertyName: string): any
	local ok, UGCValidationService = pcall (function () return game:GetService ("UGCValidationService") end)

	if not ok then return nil end

	local success, result = pcall (function () return UGCValidationService:GetPropertyValue (instance, propertyName) end)

	return if success then result else nil
end

--[=[
	Fallback for base64 encoding using Reselim's implementation
	Only used if crypt.base64encode is not available

	@param data string
	@return string -- Encoded data
]=]
local base64encode_fallback: ((data: string) -> string)?

-- Reselim's Base64 fallback is allowed as it's a pure Lua implementation
-- This doesn't violate sUNC standard since we only use it when sUNC function is absent
do
	if not api.crypt.base64encode then
		local ok, result = pcall (function ()
			local code = game:HttpGet ("https://raw.githubusercontent.com/Reselim/Base64/master/Base64.lua", true)
			local Base64 = loadstring (code, "Base64") ()

			return function (raw: string): string return buffer.tostring (Base64.encode (buffer.fromstring (raw))) end
		end)

		if ok and result then base64encode_fallback = result end
	end
end

-- ============================================================================
-- SAFE WRAPPED FUNCTIONS
-- ============================================================================

--[=[
	Gets hidden property value with fallback

	@param instance Instance
	@param property string
	@return Result<any>
]=]
local function getHiddenProperty (instance: Instance, property: string): Result<any>
	if api.gethiddenproperty then
		local ok, value = pcall (api.gethiddenproperty, instance, property)
		if ok then return { success = true, data = value } end
	end

	-- Fallback to UGCValidationService
	local value = gethiddenproperty_fallback (instance, property)
	return { success = true, data = value }
end

--[=[
	Sets hidden property value

	@param instance Instance
	@param property string
	@param value any
	@return Result<nil>
]=]
local function setHiddenProperty (instance: Instance, property: string, value: any): Result<nil>
	if not api.sethiddenproperty then return { success = false, error = "sethiddenproperty not available" } end

	return trySafe (api.sethiddenproperty, instance, property, value)
end

--[=[
	Gets script bytecode

	@param script LuaSourceContainer
	@return Result<string>
]=]
local function getScriptBytecode (script: LuaSourceContainer): Result<string>
	if not api.getscriptbytecode then return { success = false, error = "getscriptbytecode not available" } end

	return trySafe (api.getscriptbytecode, script)
end

--[=[
	Gets script hash

	@param script LuaSourceContainer
	@return Result<string>
]=]
local function getScriptHash (script: LuaSourceContainer): Result<string>
	if not api.getscripthash then return { success = false, error = "getscripthash not available" } end

	return trySafe (api.getscripthash, script)
end

--[=[
	Clones instance reference

	@param instance Instance
	@return Result<Instance>
]=]
local function cloneRef <T>(instance: T & Instance): Result<T & Instance>
	if not api.cloneref then
		return { success = true, data = instance } -- Return original if not available
	end

	return trySafe (api.cloneref, instance)
end

--[=[
	Sets thread identity level

	@param identity number -- Identity level (0-8)
	@return Result<nil>
]=]
local function setThreadIdentity (identity: number): Result<nil>
	if not api.setthreadidentity then return { success = false, error = "setthreadidentity not available" } end

	return trySafe (api.setthreadidentity, identity)
end

--[=[
	Gets current thread identity level

	@return Result<number>
]=]
local function getThreadIdentity (): Result<number>
	if not api.getthreadidentity then return { success = false, error = "getthreadidentity not available" } end

	return trySafe (api.getthreadidentity)
end

--[=[
	Encodes string to base64 with fallback

	@param data string
	@return Result<string>
]=]
local function encodeBase64 (data: string): Result<string>
	if api.crypt.base64encode then
		local result = trySafe (api.crypt.base64encode, data)
		if result.success then return result end
	end

	-- Try fallback
	if base64encode_fallback then return trySafe (base64encode_fallback, data) end

	return { success = false, error = "base64encode not available" }
end

--[=[
	Decodes base64 string

	@param data string
	@return Result<string>
]=]
local function decodeBase64 (data: string): Result<string>
	if not api.crypt.base64decode then return { success = false, error = "base64decode not available" } end

	return trySafe (api.crypt.base64decode, data)
end

--[=[
	Computes hash using crypt.hash

	@param data string
	@param algorithm string -- Hash algorithm (e.g., "sha384", "md5")
	@return Result<string>
]=]
local function hash (data: string, algorithm: string): Result<string>
	if not api.crypt.hash then return { success = false, error = "crypt.hash not available" } end

	return trySafe (api.crypt.hash, data, algorithm)
end

--[=[
	Computes SHA384 hash

	@param data string
	@return Result<string>
]=]
local function hashSha384 (data: string): Result<string> return hash (data, "sha384") end

--[=[
	Gets nil instances (unparented instances)

	@return Result<{Instance}>
]=]
local function getNilInstances (): Result<{ Instance }>
	if not api.getnilinstances then return { success = false, error = "getnilinstances not available" } end

	return trySafe (api.getnilinstances)
end

--[=[
	Gets global environment table

	@return Result<{[any]: any}>
]=]
local function getgenv (): Result<{ [any]: any }>
	if not api.getgenv then return { success = false, error = "getgenv not available" } end

	return trySafe (api.getgenv)
end

-- ============================================================================
-- FILESYSTEM OPERATIONS
-- ============================================================================

--[=[
	Checks if path is a file

	@param path string
	@return Result<boolean>
]=]
local function isFile (path: string): Result<boolean>
	if not api.isfile then return { success = false, error = "isfile not available" } end

	return trySafe (api.isfile, normalizePath (path))
end

--[=[
	Checks if path is a folder

	@param path string
	@return Result<boolean>
]=]
local function isFolder (path: string): Result<boolean>
	if not api.isfolder then return { success = false, error = "isfolder not available" } end

	return trySafe (api.isfolder, normalizePath (path))
end

--[=[
	Creates folder (ensures directory exists)

	@param path string
	@return Result<nil>
]=]
local function createFolder (path: string): Result<nil>
	if not api.makefolder then return { success = false, error = "makefolder not available" } end

	local normalized = normalizePath (path)

	-- Check if already exists
	local folderCheck = isFolder (normalized)
	if folderCheck.success and folderCheck.data then return { success = true } end

	return trySafe (api.makefolder, normalized)
end

--[=[
	Reads file contents

	@param path string
	@return Result<string>
]=]
local function readFile (path: string): Result<string>
	if not api.readfile then return { success = false, error = "readfile not available" } end

	local normalized = normalizePath (path)

	-- Check if file exists
	local fileCheck = isFile (normalized)
	if fileCheck.success and not fileCheck.data then
		return { success = false, error = `File not found: {normalized}` }
	end

	return trySafe (api.readfile, normalized)
end

--[=[
	Writes content to file (creates parent directories if needed)

	@param path string
	@param content string
	@return Result<nil>
]=]
local function writeFile (path: string, content: string): Result<nil>
	if not api.writefile then return { success = false, error = "writefile not available" } end

	local normalized = normalizePath (path)

	-- Ensure parent directory exists
	local dir = normalized:match ("^(.+)/[^/]+$")
	if dir then
		local createResult = createFolder (dir)
		if not createResult.success then return createResult end
	end

	return trySafe (api.writefile, normalized, content)
end

--[=[
	Appends content to file

	@param path string
	@param content string
	@return Result<nil>
]=]
local function appendFile (path: string, content: string): Result<nil>
	if not api.appendfile then return { success = false, error = "appendfile not available" } end

	local normalized = normalizePath (path)

	-- Check if file exists
	local fileCheck = isFile (normalized)
	if fileCheck.success and not fileCheck.data then
		return { success = false, error = `File not found: {normalized}` }
	end

	return trySafe (api.appendfile, normalized, content)
end

--[=[
	Deletes file

	@param path string
	@return Result<nil>
]=]
local function deleteFile (path: string): Result<nil>
	if not api.delfile then return { success = false, error = "delfile not available" } end

	local normalized = normalizePath (path)

	-- Check if file exists
	local fileCheck = isFile (normalized)
	if fileCheck.success and not fileCheck.data then
		return { success = false, error = `File not found: {normalized}` }
	end

	return trySafe (api.delfile, normalized)
end

--[=[
	Lists files in directory

	@param path string
	@return Result<{string}>
]=]
local function listFiles (path: string): Result<{ string }>
	if not api.listfiles then return { success = false, error = "listfiles not available" } end

	local normalized = normalizePath (path)

	-- Check if folder exists
	local folderCheck = isFolder (normalized)
	if folderCheck.success and not folderCheck.data then
		return { success = false, error = `Folder not found: {normalized}` }
	end

	return trySafe (api.listfiles, normalized)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
	-- Info
	info = executorInfo,
	clientVersion = clientVersionNumber,

	-- API access
	api = api,
	hasFunction = hasFunction,

	-- Reflection
	getHiddenProperty = getHiddenProperty,
	setHiddenProperty = setHiddenProperty,
	setThreadIdentity = setThreadIdentity,
	getThreadIdentity = getThreadIdentity,

	-- Scripts
	getScriptBytecode = getScriptBytecode,
	getScriptHash = getScriptHash,

	-- Instances
	cloneRef = cloneRef,
	getNilInstances = getNilInstances,

	-- Cryptography
	encodeBase64 = encodeBase64,
	decodeBase64 = decodeBase64,
	hash = hash,
	hashSha384 = hashSha384,

	-- Environment
	getgenv = getgenv,

	-- Filesystem
	isFile = isFile,
	isFolder = isFolder,
	createFolder = createFolder,
	readFile = readFile,
	writeFile = writeFile,
	appendFile = appendFile,
	deleteFile = deleteFile,
	listFiles = listFiles,
}
