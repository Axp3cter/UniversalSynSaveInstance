--[[
	Executor Utilities - sUNC API Wrapper

	Promise-based executor function wrappers following sUNC specification.
	Functions are prefixed with underscore to avoid conflicts with globals.

	@author Aspecter
	@version 2.0.0
]]

local Promise = require("@packages/promise")

export type ExecutorResult<T> = {
	success: boolean,
	data: T?,
	error: string?,
}

export type ExecutorInfo = {
	name: string,
	version: string?,
	detected: boolean,
}

-- Executor detection
local info: ExecutorInfo = { name = "Unknown", version = nil, detected = false }

if identifyexecutor then
	local ok, name, version = pcall(identifyexecutor)
	if ok then
		info.name = tostring(name or "Unknown")
		info.version = version and tostring(version) or nil
		info.detected = true
	end
end

-- Normalize file paths (convert backslashes to forward slashes)
local function normalizePath(path: string): string
	return path:gsub("\\", "/")
end

-- Ensure parent directory exists for file path
local function ensureDirectory(path: string): boolean
	local dir = path:match("^(.+)/")
	if not dir or isfolder(dir) then
		return true
	end
	return pcall(makefolder, dir)
end

--[=[
	Gets hidden property value

	@param instance Instance -- Instance to read from
	@param property string -- Property name
	@return Promise<ExecutorResult<any>> -- Property value or error
]=]
local function _getHiddenProperty(instance: Instance, property: string)
	return Promise.defer(function(resolve)
		-- Check if function exists
		if not gethiddenproperty then
			return resolve({ success = false, error = "gethiddenproperty not found" } :: ExecutorResult<any>)
		end

		-- Call function safely
		local ok, result = pcall(gethiddenproperty, instance, property)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<any>
		)
	end)
end

--[=[
	Sets hidden property value

	@param instance Instance -- Instance to modify
	@param property string -- Property name
	@param value any -- New value
	@return Promise<ExecutorResult<boolean>> -- Success or error
]=]
local function _setHiddenProperty(instance: Instance, property: string, value: any)
	return Promise.defer(function(resolve)
		-- Check if function exists
		if not sethiddenproperty then
			return resolve({ success = false, error = "sethiddenproperty not found" } :: ExecutorResult<boolean>)
		end

		-- Call function safely
		local ok, result = pcall(sethiddenproperty, instance, property, value)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<boolean>
		)
	end)
end

--[=[
	Gets script bytecode

	@param script BaseScript | ModuleScript -- Script instance
	@return Promise<ExecutorResult<string>> -- Bytecode or error
]=]
local function _getScriptBytecode(script: BaseScript | ModuleScript)
	return Promise.defer(function(resolve)
		-- Check if function exists
		if not getscriptbytecode then
			return resolve({ success = false, error = "getscriptbytecode not found" } :: ExecutorResult<string>)
		end

		-- Call function safely
		local ok, result = pcall(getscriptbytecode, script)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Gets script hash

	@param script BaseScript | ModuleScript -- Script instance
	@return Promise<ExecutorResult<string>> -- Hash or error
]=]
local function _getScriptHash(script: BaseScript | ModuleScript)
	return Promise.defer(function(resolve)
		-- Check if function exists
		if not getscripthash then
			return resolve({ success = false, error = "getscripthash not found" } :: ExecutorResult<string>)
		end

		-- Call function safely
		local ok, result = pcall(getscripthash, script)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Clones instance reference

	@param object Instance -- Instance to clone
	@return T -- Cloned reference or original
]=]
local function _cloneRef<T>(object: T & Instance): T
	-- Return original if function doesn't exist
	if not cloneref then
		return object
	end

	-- Try to clone, fallback to original
	local ok, result = pcall(cloneref, object)
	return if ok then result else object
end

--[=[
	Sets thread identity level

	@param identity number -- Identity level (0-8)
	@return Promise<ExecutorResult<nil>> -- Success or error
]=]
local function _setThreadIdentity(identity: number)
	return Promise.defer(function(resolve)
		-- Check if function exists
		if not setthreadidentity then
			return resolve({ success = false, error = "setthreadidentity not found" } :: ExecutorResult<nil>)
		end

		-- Call function safely
		local ok = pcall(setthreadidentity, identity)
		resolve(
			if ok
				then { success = true }
				else { success = false, error = `Failed to set identity to {identity}` } :: ExecutorResult<nil>
		)
	end)
end

--[=[
	Gets current thread identity level

	@return Promise<ExecutorResult<number>> -- Identity level
]=]
local function _getThreadIdentity()
	return Promise.defer(function(resolve)
		-- Return 0 if function doesn't exist
		if not getthreadidentity then
			return resolve({ success = true, data = 0 } :: ExecutorResult<number>)
		end

		-- Get identity, default to 0 on failure
		local ok, result = pcall(getthreadidentity)
		resolve({
			success = true,
			data = if ok and type(result) == "number" then result else 0,
		} :: ExecutorResult<number>)
	end)
end

--[=[
	Encodes string to base64

	@param data string -- Data to encode
	@return Promise<ExecutorResult<string>> -- Encoded data or error
]=]
local function _base64Encode(data: string)
	return Promise.defer(function(resolve)
		-- Check if crypt table and function exist
		if not crypt or not crypt.base64encode then
			return resolve({ success = false, error = "crypt.base64encode not found" } :: ExecutorResult<string>)
		end

		-- Encode data safely
		local ok, result = pcall(crypt.base64encode, data)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Decodes base64 string

	@param data string -- Data to decode
	@return Promise<ExecutorResult<string>> -- Decoded data or error
]=]
local function _base64Decode(data: string)
	return Promise.defer(function(resolve)
		-- Check if crypt table and function exist
		if not crypt or not crypt.base64decode then
			return resolve({ success = false, error = "crypt.base64decode not found" } :: ExecutorResult<string>)
		end

		-- Decode data safely
		local ok, result = pcall(crypt.base64decode, data)
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Computes SHA384 hash

	@param data string -- Data to hash
	@return Promise<ExecutorResult<string>> -- Hash or error
]=]
local function _sha384Hash(data: string)
	return Promise.defer(function(resolve)
		-- Check if crypt table and hash function exist
		if not crypt or not crypt.hash then
			return resolve({ success = false, error = "crypt.hash not found" } :: ExecutorResult<string>)
		end

		-- Compute hash safely
		local ok, result = pcall(crypt.hash, data, "sha384")
		resolve(
			if ok
				then { success = true, data = result }
				else { success = false, error = tostring(result) } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Reads file contents

	@param path string -- File path
	@return Promise<ExecutorResult<string>> -- File contents or error
]=]
local function _readFile(path: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Check if file exists
		if not isfile(path) then
			return resolve({ success = false, error = `File not found: {path}` } :: ExecutorResult<string>)
		end

		-- Read file safely
		local ok, data = pcall(readfile, path)
		resolve(
			if ok
				then { success = true, data = data }
				else { success = false, error = `Failed to read: {data}` } :: ExecutorResult<string>
		)
	end)
end

--[=[
	Writes content to file

	@param path string -- File path
	@param content string -- Content to write
	@return Promise<ExecutorResult<nil>> -- Success or error
]=]
local function _writeFile(path: string, content: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Ensure parent directory exists
		if not ensureDirectory(path) then
			return resolve({ success = false, error = `Failed to create directory` } :: ExecutorResult<nil>)
		end

		-- Write file safely
		local ok = pcall(writefile, path, content)
		resolve(if ok then { success = true } else { success = false, error = `Failed to write` } :: ExecutorResult<nil>)
	end)
end

--[=[
	Appends content to file

	@param path string -- File path
	@param content string -- Content to append
	@return Promise<ExecutorResult<nil>> -- Success or error
]=]
local function _appendFile(path: string, content: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Check if file exists
		if not isfile(path) then
			return resolve({ success = false, error = `File not found: {path}` } :: ExecutorResult<nil>)
		end

		-- Append to file safely
		local ok = pcall(appendfile, path, content)
		resolve(if ok then { success = true } else { success = false, error = `Failed to append` } :: ExecutorResult<nil>)
	end)
end

--[=[
	Deletes file

	@param path string -- File path
	@return Promise<ExecutorResult<nil>> -- Success or error
]=]
local function _deleteFile(path: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Check if file exists
		if not isfile(path) then
			return resolve({ success = false, error = `File not found: {path}` } :: ExecutorResult<nil>)
		end

		-- Delete file safely
		local ok = pcall(delfile, path)
		resolve(if ok then { success = true } else { success = false, error = `Failed to delete` } :: ExecutorResult<nil>)
	end)
end

--[=[
	Lists directory contents

	@param path string -- Directory path
	@return Promise<ExecutorResult<{string}>> -- File list or error
]=]
local function _listFiles(path: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Check if directory exists
		if not isfolder(path) then
			return resolve({ success = false, error = `Directory not found: {path}` } :: ExecutorResult<{ string }>)
		end

		-- List files safely
		local ok, files = pcall(listfiles, path)
		resolve(
			if ok
				then { success = true, data = files }
				else { success = false, error = `Failed to list: {files}` } :: ExecutorResult<{ string }>
		)
	end)
end

--[=[
	Creates directory

	@param path string -- Directory path
	@return Promise<ExecutorResult<nil>> -- Success or error
]=]
local function _createFolder(path: string)
	return Promise.defer(function(resolve)
		-- Normalize path separators
		path = normalizePath(path)

		-- Skip if already exists
		if isfolder(path) then
			return resolve({ success = true } :: ExecutorResult<nil>)
		end

		-- Create folder safely
		local ok = pcall(makefolder, path)
		resolve(if ok then { success = true } else { success = false, error = `Failed to create folder` } :: ExecutorResult<nil>)
	end)
end

--[=[
	Checks if path is a file

	@param path string -- Path to check
	@return boolean -- True if file exists
]=]
local function _isFile(path: string): boolean
	return isfile(normalizePath(path))
end

--[=[
	Checks if path is a directory

	@param path string -- Path to check
	@return boolean -- True if directory exists
]=]
local function _isFolder(path: string): boolean
	return isfolder(normalizePath(path))
end

--[=[
	Checks if function exists in executor environment

	@param name string -- Function name (supports nested: "crypt.base64encode")
	@return boolean -- True if function exists
]=]
local function hasFunction(name: string): boolean
	local parts = string.split(name, ".")
	local current = getgenv()

	-- Traverse nested path
	for _, part in parts do
		if type(current) ~= "table" then
			return false
		end
		current = current[part]
		if not current then
			return false
		end
	end

	return true
end

--[=[
	Refreshes executor detection info

	@return nil
]=]
local function refresh()
	if identifyexecutor then
		local ok, name, version = pcall(identifyexecutor)
		if ok then
			info.name = tostring(name or "Unknown")
			info.version = version and tostring(version) or nil
			info.detected = true
		end
	end
end

return {
	info = info,
	getHiddenProperty = _getHiddenProperty,
	setHiddenProperty = _setHiddenProperty,
	getScriptBytecode = _getScriptBytecode,
	getScriptHash = _getScriptHash,
	cloneRef = _cloneRef,
	setThreadIdentity = _setThreadIdentity,
	getThreadIdentity = _getThreadIdentity,
	base64Encode = _base64Encode,
	base64Decode = _base64Decode,
	sha384Hash = _sha384Hash,
	readFile = _readFile,
	writeFile = _writeFile,
	appendFile = _appendFile,
	deleteFile = _deleteFile,
	listFiles = _listFiles,
	createFolder = _createFolder,
	isFile = _isFile,
	isFolder = _isFolder,
	hasFunction = hasFunction,
	refresh = refresh,
}
