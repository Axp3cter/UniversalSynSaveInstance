--!strict

--[=[
	@class Lib

	Shared utilities for API dump analysis scripts.

	Provides comprehensive tooling for:
	- Fetching and caching API dumps from Roblox CDN with retry logic
	- Normalizing tag structures for consistent dictionary-based access
	- Standardized JSON serialization with deterministic output
	- File I/O with defensive error handling
	- Class inheritance relationship traversal
	- CLI entrypoint scaffolding with consistent error formatting

	All fetched dumps are memoized within a single process run to minimize
	network requests and improve performance across multiple dumper scripts.
]=]

-- ===== Imports =====

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local Logging = require("../shared/logging")
local Http = require("../shared/http")
local Serde = require("../shared/serde")

-- ===== Constants =====

-- Roblox CDN base URL for API dump downloads
local CDN_BASE_URL = "https://setup.rbxcdn.com"

-- Deployment history endpoint for finding latest accessible dump
local DEPLOY_HISTORY_URL = `{CDN_BASE_URL}/DeployHistory.txt`

-- API dump filename pattern: {hash}-Full-API-Dump.json
local API_DUMP_TEMPLATE = "{hash}-Full-API-Dump.json"

-- Output directory for generated JSON files
local OUTPUT_DIRECTORY = "lune/dump/gen"

-- Progress reporting interval in version checks
local PROGRESS_INTERVAL = 10

-- Version hash pattern for deployment history parsing
local VERSION_PATTERN = "(version%-[^%s]+)"

-- Timestamp format for output metadata
local TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%S"

-- ===== Type Definitions =====

--[=[
	@class Class
	Represents a class from the Roblox API dump.

	@field Name string -- Class name
	@field Superclass string? -- Parent class name (nil for root classes)
	@field Tags table? -- Class tags (array or object format)
	@field Members {Member} -- Array of class members
]=]
export type Class = {
	Name: string,
	Superclass: string?,
	Tags: { [any]: any }?,
	Members: { Member },
}

--[=[
	@class ClassMap
	Dictionary mapping class names to Class objects for O(1) lookup.

	Used for efficient inheritance checking and class relationship queries.
]=]
export type ClassMap = { [string]: Class }

--[=[
	@class Member
	Represents a class member (property, method, event, callback).

	@field Name string -- Member name
	@field MemberType string -- "Property" | "Function" | "Event" | "Callback"
	@field ValueType ValueType? -- Type information (properties only)
	@field Serialization Serialization? -- Serialization flags (properties only)
	@field Tags table? -- Member tags (array or object format)
	@field Default string? -- Default value (properties only)
]=]
export type Member = {
	Name: string,
	MemberType: string,
	ValueType: ValueType?,
	Serialization: Serialization?,
	Tags: { [any]: any }?,
	Default: string?,
}

--[=[
	@class ValueType
	Describes the data type of a property value.

	@field Name string -- Type name (e.g., "string", "Vector3", "Material")
	@field Category string -- "Primitive" | "DataType" | "Enum" | "Class"
]=]
export type ValueType = {
	Name: string,
	Category: "Primitive" | "DataType" | "Enum" | "Class",
}

--[=[
	@class Serialization
	Describes property serialization capabilities for save/load operations.

	Asymmetric serialization (differing CanLoad/CanSave values) indicates
	properties requiring custom descriptors or special handling.

	@field CanLoad boolean -- Property can be deserialized from file
	@field CanSave boolean -- Property can be serialized to file
]=]
export type Serialization = {
	CanLoad: boolean,
	CanSave: boolean,
}

--[=[
	@class ApiDump
	Root structure of Roblox API dump JSON.

	@field Classes {Class} -- Array of all classes in the API
]=]
export type ApiDump = {
	Classes: { Class },
}

--[=[
	@class StandardOutput
	Standardized output format for all dumper scripts.

	Provides consistent schema across all analysis tools:
	- **count**: Total number of items in data array
	- **metadata**: Version hash and generation timestamp
	- **data**: Always an array (never nested objects) for uniform iteration
	- **breakdown**: Optional categorization counts when data has type discriminator

	Design principles:
	- Uniform iteration: consumers loop over data[] without type switching
	- Type discrimination: use 'type' field when mixing categories in one output
	- Deterministic: data is always sorted for stable git diffs
	- Flat structure: no nested groupings or multiple top-level data keys

	@field count number -- Total items in data array
	@field metadata table -- { version: string, timestamp: string }
	@field data {any} -- Sorted array of result items
	@field breakdown table? -- Optional category counts { [string]: number }
]=]
export type StandardOutput = {
	count: number,
	metadata: {
		version: string,
		timestamp: string,
	},
	data: { any },
	breakdown: { [string]: number }?,
}

--[=[
	@class FetchResult
	Result of attempting to fetch a specific API dump version.

	@field success boolean -- True if fetch and parse succeeded
	@field data ApiDump? -- Parsed API dump (nil on failure)
	@field error string? -- Error message (nil on success)
]=]
type FetchResult = {
	success: boolean,
	data: ApiDump?,
	error: string?,
}

-- ===== Module State =====

-- Cache for fetched API dumps by hash to avoid redundant network requests
-- Key format: version hash or "latest" for most recent accessible dump
local apiDumpCache: { [string]: ApiDump } = {}

-- ===== Module Table =====

local Lib = {}

-- ===== Private Helpers =====

--[=[
	@private
	Constructs CDN URL for specific API dump version.

	@param versionHash string -- Version hash (e.g., "version-abc123def456")
	@return string -- Full CDN URL for API dump JSON
]=]
local function buildApiDumpUrl(versionHash: string): string
	return `{CDN_BASE_URL}/{versionHash}-Full-API-Dump.json`
end

--[=[
	@private
	Attempts to fetch and parse a specific API dump version.

	Handles network failures, HTTP errors, and JSON parse errors gracefully.
	Logs verbose diagnostics for 403/404 responses to aid debugging.

	@param versionHash string -- Version hash to fetch
	@return FetchResult -- Fetch result with success status
	@side-effect Logs verbose messages to stdout
]=]
local function tryFetchVersion(versionHash: string): FetchResult
	local apiUrl = buildApiDumpUrl(versionHash)

	Logging.verbose(`Attempting to fetch {versionHash}...`)

	local httpResult = Http.get(apiUrl)
	if not httpResult.success then
		local errorMessage = `Failed to fetch {versionHash}: {httpResult.error}`

		-- Log specific diagnostics for common HTTP errors
		if httpResult.statusCode == 403 then
			Logging.verbose(`Access denied (403) for {versionHash}`)
		elseif httpResult.statusCode == 404 then
			Logging.verbose(`Version {versionHash} not found (404)`)
		else
			Logging.verbose(errorMessage)
		end

		return {
			success = false,
			data = nil,
			error = errorMessage,
		}
	end

	local responseBody = httpResult.response.body
	local decodeResult = Serde.decodeJson(responseBody)

	if not decodeResult.success then
		local errorMessage = `Failed to parse JSON for {versionHash}: {decodeResult.error}`
		Logging.verbose(errorMessage)

		return {
			success = false,
			data = nil,
			error = errorMessage,
		}
	end

	Logging.dim(`Fetched {versionHash} ({Logging.formatSize(#responseBody)})`)

	return {
		success = true,
		data = decodeResult.data,
		error = nil,
	}
end

--[=[
	@private
	Counts total version entries in deployment history.

	@param historyText string -- Raw deployment history text
	@return number -- Total version count
]=]
local function countVersionsInHistory(historyText: string): number
	local versionCount = 0

	for _ in string.gmatch(historyText, VERSION_PATTERN) do
		versionCount += 1
	end

	return versionCount
end

--[=[
	@private
	Extracts version hash from deployment history line.

	@param line string -- Single line from deployment history
	@return string? -- Version hash if found, nil otherwise
]=]
local function extractVersionHash(line: string): string?
	return string.match(line, VERSION_PATTERN)
end

--[=[
	@private
	Finds latest accessible API dump by scanning deployment history.

	Iterates through deployment history from newest to oldest, attempting
	to fetch each version until one succeeds. Reports progress every 10
	attempts to provide feedback during long searches.

	@return ApiDump -- Latest accessible API dump
	@error Throws if no accessible dump found or history fetch fails
	@side-effect Logs progress and status messages to stdout
]=]
local function findLatestApiDump(): ApiDump
	Logging.info("Fetching Roblox deployment history...")

	local historyResult = Http.get(DEPLOY_HISTORY_URL)
	if not historyResult.success then
		error(`Failed to fetch deployment history: {historyResult.error}`)
	end

	local historyText = historyResult.response.body
	Logging.dim(`Retrieved deployment history ({Logging.formatSize(#historyText)})`)

	local totalVersions = countVersionsInHistory(historyText)
	Logging.info(`Searching through {totalVersions} deployment versions for accessible API dump...`)

	local attemptCount = 0
	local lastError = "Unknown error"

	-- Scan history line by line, trying each version
	for line in string.gmatch(historyText, "[^\r\n]+") do
		local versionHash = extractVersionHash(line)

		if versionHash then
			attemptCount += 1

			local fetchResult = tryFetchVersion(versionHash)
			if fetchResult.success and fetchResult.data then
				Logging.success(`Found accessible API dump: {versionHash}`)
				return fetchResult.data
			end

			if fetchResult.error then
				lastError = fetchResult.error
			end

			-- Report progress every N attempts to show activity
			if attemptCount % PROGRESS_INTERVAL == 0 then
				Logging.progress(attemptCount, totalVersions, "Checking versions...")
			end
		end
	end

	error(
		`Failed to fetch any accessible API dump after checking {attemptCount} versions. Last error: {lastError}`
	)
end

--[=[
	@private
	Ensures output directory exists, creating it if necessary.

	@error Throws if directory creation fails
	@side-effect Creates directory on filesystem
]=]
local function ensureOutputDirectory()
	local success, errorMessage = pcall(function()
		if not fs.isDir(OUTPUT_DIRECTORY) then
			fs.writeDir(OUTPUT_DIRECTORY)
		end
	end)

	if not success then
		error(`Failed to create output directory {OUTPUT_DIRECTORY}: {errorMessage}`)
	end
end

-- ===== Public API =====

--[=[
	Fetches API dump from Roblox CDN with caching.

	Results are memoized by version hash to avoid redundant downloads within
	a single process run. Multiple dumper scripts can call this without
	incurring additional network overhead.

	When no hash is provided, searches deployment history for the latest
	accessible dump. This may take several attempts due to CDN propagation.

	@param versionHash string? -- Optional version hash (defaults to latest)
	@return ApiDump -- Parsed API dump
	@error Throws if fetch fails or no accessible dump found
	@side-effect Caches result in module state, logs to stdout
]=]
function Lib.fetch(versionHash: string?): ApiDump
	local cacheKey = versionHash or "latest"

	-- Return cached result if available
	if apiDumpCache[cacheKey] then
		return apiDumpCache[cacheKey]
	end

	local apiDump: ApiDump

	if versionHash then
		-- Fetch specific version
		local fetchResult = tryFetchVersion(versionHash)

		if not fetchResult.success or not fetchResult.data then
			error(`Failed to fetch version {versionHash}`)
		end

		apiDump = fetchResult.data
	else
		-- Find latest accessible version
		apiDump = findLatestApiDump()
	end

	-- Cache result for subsequent calls
	apiDumpCache[cacheKey] = apiDump

	return apiDump
end

--[=[
	Normalizes tags into consistent dictionary format for easy lookup.

	API dump tags come in two formats:
	- Array style: { "Deprecated", "NotScriptable" }
	- Object style: { Deprecated = true, NotScriptable = true }

	This function normalizes both formats into dictionaries with boolean
	values, enabling consistent `if tags.Deprecated then` checks.

	@param rawTags table? -- Raw tags from API dump (nil-safe)
	@return table -- Normalized tag dictionary { [string]: boolean }
]=]
function Lib.tags(rawTags: { any }?): { [string]: any }
	if not rawTags then
		return {}
	end

	local normalizedTags: { [string]: any } = {}

	for key, value in rawTags do
		if type(key) == "number" then
			-- Array-style tag: { "Deprecated" }
			if type(value) == "string" then
				normalizedTags[value] = true
			elseif type(value) == "table" then
				-- Nested table of tags: { { Key = Value } }
				for nestedKey, nestedValue in value do
					normalizedTags[nestedKey] = nestedValue
				end
			end
		else
			-- Object-style tag: { Deprecated = true }
			normalizedTags[key] = value
		end
	end

	return normalizedTags
end

--[=[
	Writes content to file in output directory.

	Creates the output directory if it doesn't exist. File path is relative
	to OUTPUT_DIRECTORY constant.

	@param filename string -- Filename with extension
	@param content string -- File content to write
	@error Throws if directory creation or file write fails
	@side-effect Creates directory and writes file to filesystem, logs to stdout
]=]
function Lib.write(filename: string, content: string)
	ensureOutputDirectory()

	local filePath = `{OUTPUT_DIRECTORY}/{filename}`
	local writeSuccess, writeError = pcall(fs.writeFile, filePath, content)

	if not writeSuccess then
		error(`Failed to write file {filePath}: {writeError}`)
	end

	Logging.file(filePath)
end

--[=[
	Creates standardized metadata object for output files.

	Metadata includes:
	- version: API dump version hash or "latest"
	- timestamp: ISO 8601 formatted generation time

	@param versionHash string? -- Optional version hash (defaults to "latest")
	@return table -- Metadata object { version: string, timestamp: string }
]=]
function Lib.metadata(versionHash: string?): { version: string, timestamp: string }
	return {
		version = versionHash or "latest",
		timestamp = os.date(TIMESTAMP_FORMAT),
	}
end

--[=[
	Creates StandardOutput structure with metadata.

	Data array must be pre-sorted by caller for deterministic output.
	Breakdown is optional and should map type discriminator values to counts.

	@param versionHash string? -- Optional version hash
	@param data {any} -- Pre-sorted data array
	@param breakdown table? -- Optional category counts { [string]: number }
	@return StandardOutput -- Standardized output object
]=]
function Lib.output(versionHash: string?, data: { any }, breakdown: { [string]: number }?): StandardOutput
	return {
		count = #data,
		metadata = Lib.metadata(versionHash),
		data = data,
		breakdown = breakdown,
	}
end

--[=[
	Prints success message with count statistics.

	@param itemCount number -- Primary item count
	@param itemLabel string -- Label for items (e.g., "properties")
	@param secondaryInfo string? -- Optional additional info to display
	@side-effect Prints colored message to stdout
]=]
function Lib.success(itemCount: number, itemLabel: string, secondaryInfo: string?)
	Logging.successCount(itemCount, itemLabel, secondaryInfo)
end

--[=[
	Serializes data to JSON and writes to output directory.

	Automatically includes version hash in filename when available and not
	"latest" to prevent overwriting versioned dumps.

	Filename format:
	- With hash: {name}-{hash}.json
	- Without hash: {name}.json

	@param baseName string -- Base filename without extension
	@param data any -- Data to serialize (should be StandardOutput)
	@error Throws if JSON encoding or file write fails
	@side-effect Writes JSON file to OUTPUT_DIRECTORY, logs to stdout
]=]
function Lib.json(baseName: string, data: any)
	local encodeResult = Serde.encodeJson(data, true)

	if not encodeResult.success then
		error(`Failed to encode JSON: {encodeResult.error}`)
	end

	-- Include version hash in filename when available
	local filename: string
	local hasVersionHash = data.metadata and data.metadata.version and data.metadata.version ~= "latest"

	if hasVersionHash then
		filename = `{baseName}-{data.metadata.version}.json`
	else
		filename = `{baseName}.json`
	end

	Lib.write(filename, encodeResult.json)
end

--[=[
	Logs error message with consistent formatting.

	@param message string -- Error message to display
	@side-effect Prints colored error to stderr
]=]
function Lib.error(message: string)
	Logging.error(message)
end

--[=[
	Logs warning message with consistent formatting.

	@param message string -- Warning message to display
	@side-effect Prints colored warning to stdout
]=]
function Lib.warn(message: string)
	Logging.warn(message)
end

--[=[
	Logs info message with consistent formatting.

	@param message string -- Info message to display
	@side-effect Prints colored info to stdout
]=]
function Lib.info(message: string)
	Logging.info(message)
end

--[=[
	Checks if class inherits from specified base class.

	Walks the inheritance chain through Superclass references until finding
	a match or reaching a root class (no superclass).

	@param className string -- Class name to check
	@param baseClassName string -- Target base class name
	@param classMap ClassMap -- Class lookup dictionary
	@return boolean -- True if className inherits from baseClassName
]=]
function Lib.inherits(className: string, baseClassName: string, classMap: ClassMap): boolean
	local currentClass: Class? = classMap[className]

	while currentClass do
		if currentClass.Name == baseClassName then
			return true
		end

		-- Reached root class without finding base
		if not currentClass.Superclass then
			return false
		end

		currentClass = classMap[currentClass.Superclass]
	end

	return false
end

--[=[
	Builds class lookup map from array for O(1) access.

	Converts linear array of classes into dictionary indexed by class name.
	Enables efficient inheritance checking and class relationship queries.

	@param classList {Class} -- Array of classes from API dump
	@return ClassMap -- Class lookup dictionary { [string]: Class }
]=]
function Lib.classes(classList: { Class }): ClassMap
	local classMap: ClassMap = {}

	for _, class in classList do
		classMap[class.Name] = class
	end

	return classMap
end

--[=[
	Runs dumper script with standardized CLI error handling.

	Provides consistent entrypoint behavior for all dumper scripts:
	- Parses optional version hash from first argument
	- Wraps dumper function in pcall for error catching
	- Formats errors with red "Fatal:" prefix
	- Exits with code 1 on failure

	Usage in dumper scripts:
	```lua
	function MyDumper.run(hash: string?)
		-- Implementation
	end

	Lib.runCli(MyDumper.run, process.args)
	```

	@param dumperFunction function -- Dumper function to run (receives hash param)
	@param processArgs {string} -- Process arguments array
	@error Exits process with code 1 on failure
	@side-effect May exit process, prints to stderr on failure
]=]
function Lib.runCli(dumperFunction: (string?) -> (), processArgs: { string })
	local versionHash: string? = processArgs[1]

	local success, errorMessage = pcall(dumperFunction, versionHash)

	if not success then
		Lib.error(`Fatal: {errorMessage}`)

		local Process = require("@lune/process")
		Process.exit(1)
	end
end

return Lib
