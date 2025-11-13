--!strict
--[=[
	@class Fs
	Shared filesystem utilities for lune scripts.

	Provides file and directory operations with error handling.
]=]

-- Imports
local fs = require("@lune/fs")

-- Module
local Fs = {}

--[=[
	Extracts the basename (filename) from a path.

	@param path -- File path
	@return Basename of the path
]=]
function Fs.basename(path: string): string
	return path:match("^.+[\\/](.+)$") or path
end

--[=[
	Extracts the directory name from a path.

	@param path -- File path
	@return Directory name (or "." if no directory)
]=]
function Fs.dirname(path: string): string
	return path:match("^(.+)[\\/][^\\/]+$") or "."
end

--[=[
	Ensures a directory exists, creating it if necessary.

	@param path -- Directory path
]=]
function Fs.ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

--[=[
	Ensures the parent directory of a path exists.

	@param path -- File path
]=]
function Fs.ensureParent(path: string)
	Fs.ensureDir(Fs.dirname(path))
end

--[=[
	Checks if a file exists and is readable.

	@param path -- File path
	@return True if file exists
]=]
function Fs.exists(path: string): boolean
	return fs.isFile(path) and pcall(fs.readFile, path)
end

--[=[
	Gets the size of a file in bytes.

	@param path -- File path
	@return File size in bytes, or nil if file doesn't exist
]=]
function Fs.size(path: string): number?
	local meta = fs.metadata(path)
	return if meta.exists and meta.kind == "file" then meta.size else nil
end

--[=[
	Reads a file with error handling.

	@param path -- File path
	@return File contents if successful, nil on error
	@return Error message if failed
]=]
function Fs.read(path: string): (string?, string?)
	if not fs.isFile(path) then
		return nil, `Not found: {path}`
	end

	local ok: boolean, result: string = pcall(fs.readFile, path)
	return if ok then result else nil, result
end

--[=[
	Writes content to a file, creating parent directories if needed.

	@param path -- File path
	@param content -- Content to write
	@return Success boolean
	@return Error message if failed
]=]
function Fs.write(path: string, content: string): (boolean, string?)
	local ok, err = pcall(function()
		Fs.ensureParent(path)
		fs.writeFile(path, content)
	end)
	return if ok then true else false, err
end

--[=[
	Removes a file if it exists.

	@param path -- File path
	@return Success boolean
	@return Error message if failed
]=]
function Fs.remove(path: string): (boolean, string?)
	if not fs.isFile(path) then
		return true
	end

	local ok, err = pcall(fs.removeFile, path)
	return if ok then true else false, err
end

return Fs
