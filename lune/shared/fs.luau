--!strict
--[=[
	@class Fs
	Shared filesystem utilities for lune scripts.

	Provides defensive file and directory operations with comprehensive error handling.
	All I/O operations return result types rather than throwing errors, making
	failures explicit and recoverable.

	@dep @lune/fs -- Filesystem operations
]=]

-- ===== Imports =====

local fs = require("@lune/fs")

-- ===== Module =====

local Fs = {}

-- ===== Type Definitions =====

--[=[
	@class ReadResult
	Result type for file read operations.
]=]
export type ReadResult = {
	success: true,
	content: string,
} | {
	success: false,
	error: string,
}

--[=[
	@class WriteResult
	Result type for file write operations.
]=]
export type WriteResult = {
	success: true,
} | {
	success: false,
	error: string,
}

-- ===== Path Manipulation =====

--[=[
	Extracts the basename (filename) from a file path.

	Handles both forward slash and backslash path separators for cross-platform
	compatibility. Returns the full path if no directory separator is found.

	@param path string -- File path to extract basename from
	@return string -- Basename component (e.g., "file.txt" from "/dir/file.txt")
]=]
function Fs.basename(path: string): string
	local basename: string? = path:match("^.+[\\/](.+)$")
	return basename or path
end

--[=[
	Extracts the directory name from a file path.

	Handles both forward slash and backslash path separators. Returns "." if
	the path contains no directory component.

	@param path string -- File path to extract directory from
	@return string -- Directory component (e.g., "/dir" from "/dir/file.txt")
]=]
function Fs.dirname(path: string): string
	local dirname: string? = path:match("^(.+)[\\/][^\\/]+$")
	return dirname or "."
end

-- ===== Directory Operations =====

--[=[
	Ensures a directory exists, creating it if necessary.

	Creates the directory only if it doesn't already exist. Does not create
	parent directories - use ensureParent() for that.

	@param path string -- Directory path to ensure exists

	@error Throws if directory creation fails
]=]
function Fs.ensureDir(path: string)
	if fs.isDir(path) then
		return
	end

	fs.writeDir(path)
end

--[=[
	Ensures the parent directory of a path exists.

	Useful before writing a file to ensure its containing directory exists.

	@param path string -- File or directory path whose parent should exist

	@error Throws if parent directory creation fails
]=]
function Fs.ensureParent(path: string)
	local parentDir: string = Fs.dirname(path)
	Fs.ensureDir(parentDir)
end

-- ===== File Status Checks =====

--[=[
	Checks if a file exists and is readable.

	Tests both file existence and read permission in a single operation.

	@param path string -- File path to check
	@return boolean -- True if file exists and can be read
]=]
function Fs.exists(path: string): boolean
	if not fs.isFile(path) then
		return false
	end

	local canRead: boolean = pcall(fs.readFile, path)
	return canRead
end

--[=[
	Gets the size of a file in bytes.

	@param path string -- File path to check
	@return number? -- File size in bytes, or nil if file doesn't exist
]=]
function Fs.size(path: string): number?
	local metadata = fs.metadata(path)

	if not metadata.exists then
		return nil
	end

	if metadata.kind ~= "file" then
		return nil
	end

	return metadata.size
end

-- ===== File I/O Operations =====

--[=[
	Reads a file with comprehensive error handling.

	Wraps fs.readFile with defensive checks and returns a result type instead
	of throwing errors.

	@param path string -- File path to read
	@return ReadResult -- Result containing file contents or error message

	@error Never throws - all errors are captured in result type
]=]
function Fs.read(path: string): ReadResult
	if not fs.isFile(path) then
		return {
			success = false,
			error = `Not found: {path}`,
		}
	end

	local readSuccess: boolean
	local content: string

	readSuccess, content = pcall(fs.readFile, path)

	if readSuccess then
		return {
			success = true,
			content = content,
		}
	else
		return {
			success = false,
			error = `Read failed: {content}`,
		}
	end
end

--[=[
	Writes content to a file, creating parent directories if needed.

	Automatically creates any missing parent directories before writing. The
	entire operation is atomic - if any step fails, no partial changes occur.

	@param path string -- File path to write
	@param content string -- Content to write to file
	@return WriteResult -- Result indicating success or error

	@error Never throws - all errors are captured in result type
]=]
function Fs.write(path: string, content: string): WriteResult
	local writeSuccess: boolean
	local writeError: any

	writeSuccess, writeError = pcall(function()
		Fs.ensureParent(path)
		fs.writeFile(path, content)
	end)

	if writeSuccess then
		return {
			success = true,
		}
	else
		return {
			success = false,
			error = `Write failed: {writeError}`,
		}
	end
end

--[=[
	Removes a file if it exists.

	Succeeds silently if the file doesn't exist (idempotent operation).

	@param path string -- File path to remove
	@return WriteResult -- Result indicating success or error

	@error Never throws - all errors are captured in result type
]=]
function Fs.remove(path: string): WriteResult
	if not fs.isFile(path) then
		return {
			success = true,
		}
	end

	local removeSuccess: boolean
	local removeError: any

	removeSuccess, removeError = pcall(fs.removeFile, path)

	if removeSuccess then
		return {
			success = true,
		}
	else
		return {
			success = false,
			error = `Remove failed: {removeError}`,
		}
	end
end

return Fs
