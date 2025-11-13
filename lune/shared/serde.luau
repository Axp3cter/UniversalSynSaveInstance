--!strict
--[=[
	@class Serde
	Shared serialization utilities for lune scripts.

	Provides standardized JSON encoding/decoding with metadata, versioning,
	and deterministic output formatting. Ensures consistent output schema
	across all project tools.

	@dep @lune/serde -- JSON encoding/decoding
]=]

-- ===== Imports =====

local serde = require("@lune/serde")

-- ===== Module =====

local Serde = {}

-- ===== Constants =====

-- Output format version for schema compatibility tracking
local OUTPUT_FORMAT_VERSION: string = "1.0"

-- ===== Type Definitions =====

--[=[
	@class Metadata
	Standard metadata included in all structured outputs.

	@field version string -- Output format version (for schema compatibility)
	@field timestamp string -- ISO 8601 timestamp of generation
	@field generator string? -- Optional name of generating tool
]=]
export type Metadata = {
	version: string,
	timestamp: string,
	generator: string?,
}

--[=[
	@class StandardOutput
	Standard output format for all JSON exports.

	Provides consistent schema with metadata, count, and optional breakdown.
	Data array is always sorted for deterministic diffs.

	@field count number -- Total number of items in data array
	@field metadata Metadata -- Generation metadata
	@field data {any} -- Array of result items (always sorted)
	@field breakdown {[string]: number}? -- Optional category counts
]=]
export type StandardOutput<T> = {
	count: number,
	metadata: Metadata,
	data: { T },
	breakdown: { [string]: number }?,
}

--[=[
	@class EncodeResult
	Result type for JSON encoding operations.
]=]
export type EncodeResult = {
	success: true,
	json: string,
} | {
	success: false,
	error: string,
}

--[=[
	@class DecodeResult
	Result type for JSON decoding operations.
]=]
export type DecodeResult<T> = {
	success: true,
	data: T,
} | {
	success: false,
	error: string,
}

-- ===== Private Helpers =====

--[=[
	@private
	Creates an ISO 8601 formatted timestamp for the current time.

	@return string -- Formatted timestamp (YYYY-MM-DDTHH:MM:SS)
]=]
local function createTimestamp(): string
	return os.date("%Y-%m-%dT%H:%M:%S") :: string
end

-- ===== Public API =====

--[=[
	Creates standardized metadata for output files.

	@param generator string? -- Optional name of generating tool
	@return Metadata -- Metadata object with version and timestamp
]=]
function Serde.createMetadata(generator: string?): Metadata
	return {
		version = OUTPUT_FORMAT_VERSION,
		timestamp = createTimestamp(),
		generator = generator,
	}
end

--[=[
	Creates a standardized output structure.

	Data array should be pre-sorted by the caller for deterministic output.

	@param data {any} -- Array of result items (must be pre-sorted)
	@param metadata Metadata -- Generation metadata
	@param breakdown {[string]: number}? -- Optional category breakdown
	@return StandardOutput -- Standardized output structure
]=]
function Serde.createOutput<T>(
	data: { T },
	metadata: Metadata,
	breakdown: { [string]: number }?
): StandardOutput<T>
	return {
		count = #data,
		metadata = metadata,
		data = data,
		breakdown = breakdown,
	}
end

--[=[
	Encodes data to JSON string with optional pretty-printing.

	Wraps serde.encode with error handling and returns a result type.

	@param data any -- Data to encode (must be JSON-serializable)
	@param pretty boolean? -- Enable pretty-printing (default: true)
	@return EncodeResult -- Result containing JSON string or error

	@error Never throws - all errors are captured in result type
]=]
function Serde.encodeJson(data: any, pretty: boolean?): EncodeResult
	local shouldPrettyPrint: boolean = if pretty == nil then true else pretty

	local success: boolean
	local result: string

	success, result = pcall(serde.encode, "json", data, shouldPrettyPrint)

	if success then
		return {
			success = true,
			json = result,
		}
	else
		return {
			success = false,
			error = `JSON encoding failed: {result}`,
		}
	end
end

--[=[
	Decodes JSON string to Luau data structure.

	Wraps serde.decode with error handling and returns a result type.

	@param json string -- JSON string to decode
	@return DecodeResult -- Result containing decoded data or error

	@error Never throws - all errors are captured in result type
]=]
function Serde.decodeJson<T>(json: string): DecodeResult<T>
	if type(json) ~= "string" or #json == 0 then
		return {
			success = false,
			error = "Input must be a non-empty string",
		}
	end

	local success: boolean
	local result: any

	success, result = pcall(serde.decode, "json", json)

	if success then
		return {
			success = true,
			data = result,
		}
	else
		return {
			success = false,
			error = `JSON decoding failed: {result}`,
		}
	end
end

--[=[
	Sorts a dictionary's keys alphabetically for deterministic iteration.

	Useful for consistent output when iterating over dictionaries.

	@param dictionary {[string]: any} -- Dictionary to sort
	@return {string} -- Sorted array of keys
]=]
function Serde.sortedKeys(dictionary: { [string]: any }): { string }
	local keys: { string } = {}

	for key in dictionary do
		table.insert(keys, key)
	end

	table.sort(keys)

	return keys
end

--[=[
	Sorts an array of items using a custom comparator.

	Performs an in-place sort for efficiency.

	@param items {T} -- Array to sort (modified in-place)
	@param comparator (T, T) -> boolean -- Comparison function (a < b)
	@return {T} -- The sorted array (same reference as input)
]=]
function Serde.sortArray<T>(items: { T }, comparator: (T, T) -> boolean): { T }
	table.sort(items, comparator)
	return items
end

return Serde
