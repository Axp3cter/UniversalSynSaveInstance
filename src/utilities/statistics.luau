--[[
	Statistics Utilities - Benchmarking and Performance Tracking

	Provides benchmarking utilities and performance measurement tools.
	Used to select fastest implementation between multiple options.

	@author Aspecter
	@version 2.0.0
]]

export type BenchmarkResult = {
	time: number,
	function: (...any) -> ...any,
}

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

	for i, fn in functions do
		local start = os.clock()
		for _ = 1, iterations do
			fn()
		end
		local elapsed = os.clock() - start

		results[i] = {
			time = elapsed,
			["function"] = fn,
		}
	end

	table.sort(results, function(a, b)
		return a.time < b.time
	end)

	return results[1]["function"]
end

--[=[
	Benchmarks functions with arguments and returns the fastest

	@param iterations number -- Number of iterations
	@param args {any} -- Arguments to pass to functions
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

	for i, fn in functions do
		local start = os.clock()
		for _ = 1, iterations do
			fn(table.unpack(args))
		end
		local elapsed = os.clock() - start

		results[i] = {
			time = elapsed,
			["function"] = fn,
		}
	end

	table.sort(results, function(a, b)
		return a.time < b.time
	end)

	return results[1]["function"]
end

--[=[
	Measures execution time of a single function

	@param fn (...any) -> ...any -- Function to measure
	@param ... any -- Arguments to pass
	@return number -- Execution time in seconds
]=]
local function measure(fn: (...any) -> ...any, ...: any): number
	local start = os.clock()
	fn(...)
	return os.clock() - start
end

--[=[
	Runs function multiple times and returns average time

	@param iterations number -- Number of iterations
	@param fn (...any) -> ...any -- Function to measure
	@param ... any -- Arguments to pass
	@return number -- Average execution time
]=]
local function average(iterations: number, fn: (...any) -> ...any, ...: any): number
	local args = { ... }
	local total = 0

	for _ = 1, iterations do
		local start = os.clock()
		fn(table.unpack(args))
		total += os.clock() - start
	end

	return total / iterations
end

--[=[
	Gets detailed benchmark statistics

	@param iterations number -- Number of iterations
	@param fn (...any) -> ...any -- Function to benchmark
	@param ... any -- Arguments to pass
	@return table -- Statistics (min, max, avg, total)
]=]
local function stats(iterations: number, fn: (...any) -> ...any, ...: any)
	local args = { ... }
	local times = {}
	local total = 0

	for i = 1, iterations do
		local start = os.clock()
		fn(table.unpack(args))
		local elapsed = os.clock() - start
		times[i] = elapsed
		total += elapsed
	end

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
	stats = stats,
}
