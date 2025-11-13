--!strict

--[=[
	@class Lib

	Shared utilities for API dump analysis.

	Provides core functionality for fetching Roblox API dumps from CDN,
	normalizing tag structures, writing JSON output files, and managing
	class inheritance relationships.
]=]

local fs = require("@lune/fs")
local Logging = require("../shared/logging")
local Http = require("../shared/http")
local Serde = require("../shared/serde")

local CDN_BASE = "https://setup.rbxcdn.com"
local OUTPUT_DIR = "lune/dump/gen"
local PROGRESS_INTERVAL = 10

-- Export Types

export type Class = {
	Name: string,
	Superclass: string?,
	Tags: { [any]: any }?,
	Members: { Member },
}

export type ClassMap = { [string]: Class }

export type Member = {
	Name: string,
	MemberType: string,
	ValueType: ValueType?,
	Serialization: Serialization?,
	Tags: { [any]: any }?,
	Default: string?,
}

export type ValueType = {
	Name: string,
	Category: "Primitive" | "DataType" | "Enum" | "Class",
}

export type Serialization = {
	CanLoad: boolean,
	CanSave: boolean,
}

export type ApiDump = {
	Classes: { Class },
}

export type StandardOutput = {
	count: number,
	metadata: { version: string, timestamp: string },
	data: { any },
	breakdown: { [string]: number }?,
}

-- Internal Types

type FetchResult = {
	ok: boolean,
	data: ApiDump?,
	error: string?,
}

-- Module State

local cache: { [string]: ApiDump } = {}

local Lib = {}

-- Utilities

local function normalizeTag(key: any, value: any, tags: { [string]: any })
	if type(key) == "number" then
		if type(value) == "string" then
			tags[value] = true
		elseif type(value) == "table" then
			for k, v in value do
				tags[k] = v
			end
		end
	else
		tags[key] = value
	end
end

--[=[
	Normalizes API dump tags into dictionary format.

	@param raw table? -- Raw tags from API dump
	@return table -- Normalized tag dictionary
]=]
function Lib.tags(raw: { any }?): { [string]: any }
	if not raw then
		return {}
	end

	local tags = {}
	for key, value in raw do
		normalizeTag(key, value, tags)
	end
	return tags
end

--[=[
	Creates metadata object for output files.

	@param hash string? -- Optional version hash
	@return table -- Metadata with version and timestamp
]=]
function Lib.metadata(hash: string?): { version: string, timestamp: string }
	return {
		version = hash or "latest",
		timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
	}
end

--[=[
	Creates standardized output structure.

	@param hash string? -- Optional version hash
	@param data table -- Result data array
	@param breakdown table? -- Optional category counts
	@return StandardOutput -- Complete output structure
]=]
function Lib.output(hash: string?, data: { any }, breakdown: { [string]: number }?): StandardOutput
	return {
		count = #data,
		metadata = Lib.metadata(hash),
		data = data,
		breakdown = breakdown,
	}
end

-- File I/O

local function ensureDir()
	if not pcall(function()
		if not fs.isDir(OUTPUT_DIR) then
			fs.writeDir(OUTPUT_DIR)
		end
	end) then
		error(`Failed to create {OUTPUT_DIR}`)
	end
end

--[=[
	Writes content to file in output directory.

	@param name string -- Filename with extension
	@param content string -- File content
	@error Throws if write fails
]=]
function Lib.write(name: string, content: string)
	ensureDir()
	local path = `{OUTPUT_DIR}/{name}`
	if not pcall(fs.writeFile, path, content) then
		error(`Failed to write {path}`)
	end
	Logging.file(path)
end

--[=[
	Serializes data to JSON and writes to file.

	@param name string -- Base filename without extension
	@param data any -- Data to serialize
	@error Throws if encode or write fails
]=]
function Lib.json(name: string, data: any)
	local result = Serde.encodeJson(data, true)
	if not result.success then
		error(`JSON encode failed: {result.error}`)
	end

	local filename = name
	if data.metadata and data.metadata.version ~= "latest" then
		filename = `{name}-{data.metadata.version}`
	end

	Lib.write(`{filename}.json`, result.json)
end

-- Logging

function Lib.success(count: number, label: string, extra: string?)
	Logging.successCount(count, label, extra)
end

function Lib.error(msg: string)
	Logging.error(msg)
end

function Lib.warn(msg: string)
	Logging.warn(msg)
end

function Lib.info(msg: string)
	Logging.info(msg)
end

-- API Fetching

local function tryFetch(hash: string): FetchResult
	Logging.verbose(`Fetching {hash}...`)

	local httpResult = Http.get(`{CDN_BASE}/{hash}-Full-API-Dump.json`)
	if not httpResult.success then
		if httpResult.statusCode == 403 then
			Logging.verbose(`Access denied: {hash}`)
		elseif httpResult.statusCode == 404 then
			Logging.verbose(`Not found: {hash}`)
		end
		return { ok = false, data = nil, error = httpResult.error }
	end

	local body = httpResult.response.body
	local parseResult = Serde.decodeJson(body)
	if not parseResult.success then
		return { ok = false, data = nil, error = parseResult.error }
	end

	Logging.dim(`Fetched {hash} ({Logging.formatSize(#body)})`)
	return { ok = true, data = parseResult.data, error = nil }
end

local function findLatest(): ApiDump
	Logging.info("Fetching deployment history...")

	local historyResult = Http.get(`{CDN_BASE}/DeployHistory.txt`)
	if not historyResult.success then
		error(`History fetch failed: {historyResult.error}`)
	end

	local history = historyResult.response.body
	Logging.dim(`History size: {Logging.formatSize(#history)}`)

	local totalVersions = 0
	for _ in string.gmatch(history, "version%-[^%s]+") do
		totalVersions += 1
	end

	Logging.info(`Checking {totalVersions} versions...`)

	local attempts = 0
	local lastError = "No versions found"

	for line in string.gmatch(history, "[^\r\n]+") do
		local hash = string.match(line, "(version%-[^%s]+)")
		if hash then
			attempts += 1
			local result = tryFetch(hash)

			if result.ok and result.data then
				Logging.success(`Found: {hash}`)
				return result.data
			end

			if result.error then
				lastError = result.error
			end

			if attempts % PROGRESS_INTERVAL == 0 then
				Logging.progress(attempts, totalVersions, "Searching...")
			end
		end
	end

	error(`No accessible dump after {attempts} attempts. Last: {lastError}`)
end

--[=[
	Fetches API dump from Roblox CDN with caching.

	@param hash string? -- Optional version hash (latest if nil)
	@return ApiDump -- Parsed API dump
	@error Throws if fetch fails
]=]
function Lib.fetch(hash: string?): ApiDump
	local key = hash or "latest"

	if cache[key] then
		return cache[key]
	end

	local dump: ApiDump
	if hash then
		local result = tryFetch(hash)
		if not result.ok or not result.data then
			error(`Failed to fetch {hash}`)
		end
		dump = result.data
	else
		dump = findLatest()
	end

	cache[key] = dump
	return dump
end

-- Class Utilities

--[=[
	Checks if class inherits from base class.

	@param name string -- Class name to check
	@param base string -- Target base class
	@param map ClassMap -- Class lookup map
	@return boolean -- True if inherits from base
]=]
function Lib.inherits(name: string, base: string, map: ClassMap): boolean
	local current = map[name]
	while current do
		if current.Name == base then
			return true
		end
		if not current.Superclass then
			return false
		end
		current = map[current.Superclass]
	end
	return false
end

--[=[
	Builds class lookup map from array.

	@param list table -- Array of classes
	@return ClassMap -- Name-to-class dictionary
]=]
function Lib.classes(list: { Class }): ClassMap
	local map = table.create(#list)
	for _, class in list do
		map[class.Name] = class
	end
	return map
end

-- CLI

--[=[
	Runs dumper script with error handling.

	@param fn function -- Dumper function to run
	@param args table -- Process arguments
	@error Exits with code 1 on failure
]=]
function Lib.runCli(fn: (string?) -> (), args: { string })
	local hash = args[1]
	local ok, err = pcall(fn, hash)
	if not ok then
		Lib.error(`Fatal: {err}`)
		require("@lune/process").exit(1)
	end
end

return Lib
