--[[
	File Writer - Chunked file writing with memory management

	Provides efficient file writing with:
	- Chunked buffering to prevent memory overflow
	- SaveCacheInterval for periodic flushing
	- String length overflow prevention (200MB chunks)
	- Alternative writefile using appendfile for executor compatibility
	- Size tracking and formatting
	- Support for callbacks and status updates

	@author Aspecter
	@version 1.0.0
	@since 2025-01-21
]]

local Executor = require ("@utilities/executor")
local Types = require ("@types")

export type WriteOptions = {
	filePath: string,
	saveCacheInterval: number, -- Items per buffer flush
	alternativeWritefile: boolean, -- Use appendfile for compatibility
	callback: ((content: string, chunks: { Chunk }, totalSize: number) -> ())?,
	statusCallback: ((message: string) -> ())?,
}

export type Chunk = {
	size: number,
	str: string,
}

export type FileWriter = {
	write: (content: string) -> (),
	flush: (final: boolean?) -> (),
	finalize: () -> { success: boolean, error: string?, totalSize: number },
	getFormattedSize: () -> string,
	getTotalSize: () -> number,
	getItemCount: () -> number,
	incrementItemCount: () -> (),
}

-- Constants
local CHUNK_LIMIT = 200 * 1024 * 1024 -- 200MB string length overflow prevention
local SEGMENT_SIZE = 4145728 -- ~4MB for appendfile compatibility (Celery executor limit)

--[=[
	Formats byte size to human-readable format

	@param size number -- Size in bytes
	@return string -- Formatted size (e.g., "1.5 MB")
]=]
local function formatSize (size: number): string
	local units = { "B", "KB", "MB", "GB", "TB" }

	for i = 1, #units do
		local threshold = 0x400 ^ i -- 1024^i
		if size < threshold then
			local value = size / (0x400 ^ (i - 1))
			return string.format ("%.1f %s", math.floor (value * 10) / 10, units[i])
		end
	end

	-- Fallback for extremely large sizes
	local value = size / (0x400 ^ (#units - 1))
	return string.format ("%.1f %s", math.floor (value * 10) / 10, units[#units])
end

--[=[
	Creates a new FileWriter instance

	@param options WriteOptions -- Writer configuration
	@return FileWriter -- Writer instance
]=]
local function createWriter (options: WriteOptions): FileWriter
	-- State
	local savebuffer: { string } = {}
	local savebufferSize = 0
	local chunks: { Chunk } = {}
	local currentStr = ""
	local currentSize = 0
	local totalSize = 0
	local itemCount = 0

	--[=[
		Writes content to buffer

		@param content string -- Content to write
	]=]
	local function write (content: string): ()
		savebufferSize += 1
		savebuffer[savebufferSize] = content
	end

	--[=[
		Flushes buffer to chunks

		@param final boolean? -- Whether this is the final flush
	]=]
	local function flush (final: boolean?): ()
		if savebufferSize == 0 then return end

		-- Concatenate buffer
		local saveStr = table.concat (savebuffer)
		currentStr ..= saveStr

		local saveStrLen = #saveStr
		totalSize += saveStrLen
		currentSize += saveStrLen

		-- Clear buffer
		table.clear (savebuffer)
		savebufferSize = 0

		-- Save chunk if over limit or final
		if CHUNK_LIMIT < currentSize or final then
			table.insert (chunks, { size = currentSize, str = currentStr })
			currentStr = ""
			currentSize = 0
		end

		-- Status update
		if options.statusCallback then options.statusCallback (`Saving.. Size: {formatSize (totalSize)}`) end
	end

	--[=[
		Writes chunks to file

		@return table -- Result with success, error, totalSize
	]=]
	local function finalize (): { success: boolean, error: string?, totalSize: number }
		-- Final flush
		flush (true)

		-- Add header if provided (handled externally, chunks only contain body)
		local filePath = options.filePath

		-- Callback mode
		if options.callback then
			local totalStr = ""
			for _, chunk in chunks do
				totalStr ..= chunk.str
			end
			options.callback (totalStr, chunks, totalSize)
			return { success = true, totalSize = totalSize }
		end

		-- Alternative writefile mode (appendfile)
		if options.alternativeWritefile and Executor.api.appendfile then
			local totalLen = math.ceil (totalSize / SEGMENT_SIZE)
			local currentLen = 1

			for _, chunk in chunks do
				local length = math.ceil (chunk.size / SEGMENT_SIZE)
				for i = 1, length do
					local segmentStart = (i - 1) * SEGMENT_SIZE + 1
					local segmentEnd = i * SEGMENT_SIZE
					local saveStr = string.sub (chunk.str, segmentStart, segmentEnd)

					-- Append segment
					local appendResult = Executor.appendFile (filePath, saveStr)
					if not appendResult.success then
						return {
							success = false,
							error = `Failed to append file: {appendResult.error}`,
							totalSize = totalSize,
						}
					end

					currentLen += 1

					-- Status update
					if options.statusCallback then
						local progress = math.round (currentLen / totalLen * 100)
						options.statusCallback (`Writing to File {progress}% (Depends on Exec)`)
					end

					-- Yield between segments
					if i ~= length then task.wait () end
				end
			end

			return { success = true, totalSize = totalSize }
		end

		-- Standard writefile mode
		local totalStr = ""
		for _, chunk in chunks do
			totalStr ..= chunk.str
		end

		-- Status update
		if options.statusCallback then
			options.statusCallback (`Writing {formatSize (totalSize)} to File (Depends on Exec)`)
		end

		local writeResult = Executor.writeFile (filePath, totalStr)
		if not writeResult.success then
			return { success = false, error = `Failed to write file: {writeResult.error}`, totalSize = totalSize }
		end

		return { success = true, totalSize = totalSize }
	end

	--[=[
		Gets formatted size string

		@return string -- Formatted size
	]=]
	local function getFormattedSize (): string return formatSize (totalSize) end

	--[=[
		Gets total size in bytes

		@return number -- Total size
	]=]
	local function getTotalSize (): number return totalSize end

	--[=[
		Gets item count

		@return number -- Item count
	]=]
	local function getItemCount (): number return itemCount end

	--[=[
		Increments item count and checks if flush is needed

		Automatically flushes if itemCount >= saveCacheInterval.
	]=]
	local function incrementItemCount (): ()
		itemCount += 1
		if itemCount >= options.saveCacheInterval then flush () end
	end

	return {
		write = write,
		flush = flush,
		finalize = finalize,
		getFormattedSize = getFormattedSize,
		getTotalSize = getTotalSize,
		getItemCount = getItemCount,
		incrementItemCount = incrementItemCount,
	}
end

return {
	createWriter = createWriter,
	formatSize = formatSize,
	CHUNK_LIMIT = CHUNK_LIMIT,
	SEGMENT_SIZE = SEGMENT_SIZE,
}
