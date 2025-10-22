--[[
	Statistics - Performance and operation metrics tracking
	@author Aspecter | @version 1.0.0
]]

local Types = require ("@types")

export type Stats = Types.Stats

local stats: Stats = {
	instancesProcessed = 0,
	scriptsDecompiled = 0,
	propertiesRead = 0,
	sharedStringsCount = 0,
	timeElapsed = 0,
	memoryUsed = nil,
}

local function reset (): ()
	stats.instancesProcessed = 0
	stats.scriptsDecompiled = 0
	stats.propertiesRead = 0
	stats.sharedStringsCount = 0
	stats.timeElapsed = 0
	stats.memoryUsed = nil
end

local function increment (key: string, amount: number?): ()
	local value = amount or 1
	if key == "instances" then
		stats.instancesProcessed += value
	elseif key == "scripts" then
		stats.scriptsDecompiled += value
	elseif key == "properties" then
		stats.propertiesRead += value
	elseif key == "sharedStrings" then
		stats.sharedStringsCount += value
	end
end

local function setElapsed (time: number): () stats.timeElapsed = time end

local function setMemory (bytes: number): () stats.memoryUsed = bytes end

local function get (): Stats return table.clone (stats) end

return {
	reset = reset,
	increment = increment,
	setElapsed = setElapsed,
	setMemory = setMemory,
	get = get,
}
