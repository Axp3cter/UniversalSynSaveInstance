--[[
	Statistics Utilities - Benchmarking and Performance Tracking

	Provides benchmarking utilities and performance measurement tools.
	Used to select fastest implementation between multiple options.

	@author Aspecter
	@version 2.0.0
]]

-- Types
export type BenchmarkResult = {
	time: number,
	fn: (...any) -> ...any,
}

export type Stats = {
	min: number,
	max: number,
	avg: number,
	total: number,
	median: number,
}

-- Private: Measures execution time of a function with arguments
local function _measureTime(fn: (...any) -> ...any, args: { any }): number
	local start = os.clock()
	fn(table.unpack(args))
	return os.clock() - start
end

--[=[
	Benchmarks multiple functions and returns the fastest

	Runs each function multiple times and measures execution time.
	Returns the function with the lowest average time.

	@param iterations number -- Number of times to run each function
	@param ... (...any) -> ...any -- Functions to benchmark
	@return (...any) -> ...any -- Fastest function
]=]
local function benchmark(iterations: number, ...: (...any) -> ...any): (...any) -> ...any
	local functions = { ... }
	local results: { BenchmarkResult } = {}

	-- Benchmark each function
	for i, fn in functions do
		local start = os.clock()
		for _ = 1, iterations do
			fn()
		end
		local elapsed = os.clock() - start

		results[i] = {
			time = elapsed,
			fn = fn,
		}
	end

	-- Sort by execution time (fastest first)
	table.sort(results, function(a, b)
		return a.time < b.time
	end)

	return results[1].fn
end

--[=[
	Benchmarks functions with arguments and returns the fastest

	Similar to benchmark() but passes arguments to each function call.

	@param iterations number -- Number of iterations per function
	@param args {any} -- Arguments to pass to each function
	@param ... (...any) -> ...any -- Functions to benchmark
	@return (...any) -> ...any -- Fastest function
]=]
local function benchmarkWithArgs(
	iterations: number,
	args: { any },
	...: (...any) -> ...any
): (...any) -> ...any
	local functions = { ... }
	local results: { BenchmarkResult } = {}

	-- Benchmark each function with arguments
	for i, fn in functions do
		local start = os.clock()
		for _ = 1, iterations do
			fn(table.unpack(args))
		end
		local elapsed = os.clock() - start

		results[i] = {
			time = elapsed,
			fn = fn,
		}
	end

	-- Sort by execution time (fastest first)
	table.sort(results, function(a, b)
		return a.time < b.time
	end)

	return results[1].fn
end

--[=[
	Measures execution time of a single function

	@param fn (...any) -> ...any -- Function to measure
	@param ... any -- Arguments to pass to function
	@return number -- Execution time in seconds
]=]
local function measure(fn: (...any) -> ...any, ...: any): number
	local start = os.clock()
	fn(...)
	return os.clock() - start
end

--[=[
	Runs function multiple times and returns average execution time

	@param iterations number -- Number of times to run function
	@param fn (...any) -> ...any -- Function to measure
	@param ... any -- Arguments to pass to function
	@return number -- Average execution time in seconds
]=]
local function average(iterations: number, fn: (...any) -> ...any, ...: any): number
	local args = { ... }
	local total = 0

	for _ = 1, iterations do
		total += _measureTime(fn, args)
	end

	return total / iterations
end

--[=[
	Gets detailed benchmark statistics

	Runs function multiple times and collects comprehensive statistics
	including min, max, average, total, and median execution times.

	@param iterations number -- Number of times to run function
	@param fn (...any) -> ...any -- Function to benchmark
	@param ... any -- Arguments to pass to function
	@return Stats -- Detailed statistics
]=]
local function getStats(iterations: number, fn: (...any) -> ...any, ...: any): Stats
	local args = { ... }
	local times: { number } = {}
	local total = 0

	-- Collect all execution times
	for i = 1, iterations do
		local elapsed = _measureTime(fn, args)
		times[i] = elapsed
		total += elapsed
	end

	-- Sort times for median calculation
	table.sort(times)

	return {
		min = times[1],
		max = times[#times],
		avg = total / iterations,
		total = total,
		median = times[math.ceil(#times / 2)],
	}
end

return {
	benchmark = benchmark,
	benchmarkWithArgs = benchmarkWithArgs,
	measure = measure,
	average = average,
	getStats = getStats,
}
