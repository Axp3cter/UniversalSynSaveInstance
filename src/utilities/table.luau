--[[
	Table Utilities - Extended Table Operations

	Wraps TableUtil package with focused utilities that add value.
	Avoids redundant wrappers of native table library.

	@author Aspecter
	@version 2.0.0
]]

local TableUtil = require("@packages/tableUtil")

--[=[
	Creates deep copy of table

	@param tbl {T} -- Table to copy
	@return {T} -- Deep copied table
]=]
local function copy<T>(tbl: { T }): { T }
	return TableUtil.Copy(tbl, true)
end

--[=[
	Synchronizes source table with template (deep sync)

	@param src {T} -- Source table to synchronize
	@param template {T} -- Template table
	@return {T} -- Synchronized table
]=]
local function sync<T>(src: { T }, template: { T }): { T }
	return TableUtil.Sync(src, template)
end

--[=[
	Reconciles source with template (one-way sync)

	@param src {T} -- Source table
	@param template {T} -- Template table
	@return {T} -- Reconciled table
]=]
local function reconcile<T>(src: { T }, template: { T }): { T }
	return TableUtil.Reconcile(src, template)
end

--[=[
	Maps array values through callback function

	@param tbl {T} -- Array to map
	@param callback (T, number, {T}) -> U -- Transformation function
	@return {U} -- Mapped array
]=]
local function map<T, U>(tbl: { T }, callback: (T, number, { T }) -> U): { U }
	return TableUtil.Map(tbl, callback)
end

--[=[
	Filters array values by predicate

	@param tbl {T} -- Array to filter
	@param predicate (T, number, {T}) -> boolean -- Filter function
	@return {T} -- Filtered array
]=]
local function filter<T>(tbl: { T }, predicate: (T, number, { T }) -> boolean): { T }
	return TableUtil.Filter(tbl, predicate)
end

--[=[
	Reduces array to single value

	@param tbl {T} -- Array to reduce
	@param callback (U, T, number, {T}) -> U -- Reducer function
	@param initial U -- Initial accumulator value
	@return U -- Reduced value
]=]
local function reduce<T, U>(tbl: { T }, callback: (U, T, number, { T }) -> U, initial: U): U
	return TableUtil.Reduce(tbl, callback, initial)
end

--[=[
	Extends target array with extension array

	@param target {T} -- Target array
	@param extension {T} -- Extension array
	@return {T} -- Extended array
]=]
local function extend<T>(target: { T }, extension: { T }): { T }
	return TableUtil.Extend(target, extension)
end

--[=[
	Reverses array elements

	@param tbl {T} -- Array to reverse
	@return {T} -- Reversed array
]=]
local function reverse<T>(tbl: { T }): { T }
	return TableUtil.Reverse(tbl)
end

--[=[
	Gets table keys as array

	@param tbl {[K]: V} -- Table to extract keys from
	@return {K} -- Array of keys
]=]
local function keys<K, V>(tbl: { [K]: V }): { K }
	return TableUtil.Keys(tbl)
end

--[=[
	Gets table values as array

	@param tbl {[K]: V} -- Table to extract values from
	@return {V} -- Array of values
]=]
local function values<K, V>(tbl: { [K]: V }): { V }
	return TableUtil.Values(tbl)
end

--[=[
	Finds first element matching predicate

	@param tbl {T} -- Array to search
	@param predicate (T, number, {T}) -> boolean -- Match function
	@return (T?, number?) -- Found value and index, or nil
]=]
local function find<T>(tbl: { T }, predicate: (T, number, { T }) -> boolean): (T?, number?)
	return TableUtil.Find(tbl, predicate)
end

--[=[
	Checks if all elements match predicate

	@param tbl {T} -- Array to check
	@param predicate (T, number, {T}) -> boolean -- Test function
	@return boolean -- True if all match
]=]
local function every<T>(tbl: { T }, predicate: (T, number, { T }) -> boolean): boolean
	return TableUtil.Every(tbl, predicate)
end

--[=[
	Checks if any element matches predicate

	@param tbl {T} -- Array to check
	@param predicate (T, number, {T}) -> boolean -- Test function
	@return boolean -- True if any match
]=]
local function some<T>(tbl: { T }, predicate: (T, number, { T }) -> boolean): boolean
	return TableUtil.Some(tbl, predicate)
end

--[=[
	Checks if table is empty

	@param tbl {any} -- Table to check
	@return boolean -- True if empty
]=]
local function isEmpty(tbl: { any }): boolean
	return TableUtil.IsEmpty(tbl)
end

--[=[
	Merges tables (shallow merge)

	@param target {[K]: V} -- Target table
	@param ... {[K]: V} -- Source tables to merge
	@return {[K]: V} -- Merged table
]=]
local function assign<K, V>(target: { [K]: V }, ...: { [K]: V }): { [K]: V }
	local result = table.clone(target)
	for _, source in { ... } do
		if type(source) == "table" then
			for k, v in source do
				result[k] = v
			end
		end
	end
	return result
end

--[=[
	Removes duplicate values from array

	@param tbl {T} -- Array to process
	@return {T} -- Array with duplicates removed
]=]
local function unique<T>(tbl: { T }): { T }
	local seen = {}
	local result = {}

	for _, v in tbl do
		if not seen[v] then
			seen[v] = true
			table.insert(result, v)
		end
	end

	return result
end

--[=[
	Flattens nested arrays

	@param tbl {T} -- Nested array to flatten
	@param depth number? -- Depth to flatten (default: 1)
	@return {T} -- Flattened array
]=]
local function flatten<T>(tbl: { T }, depth: number?): { T }
	return TableUtil.Flat(tbl, depth or 1)
end

--[=[
	Shuffles array elements randomly

	@param tbl {T} -- Array to shuffle
	@return {T} -- Shuffled array
]=]
local function shuffle<T>(tbl: { T }): { T }
	return TableUtil.Shuffle(tbl)
end

return {
	copy = copy,
	sync = sync,
	reconcile = reconcile,
	map = map,
	filter = filter,
	reduce = reduce,
	extend = extend,
	reverse = reverse,
	keys = keys,
	values = values,
	find = find,
	every = every,
	some = some,
	isEmpty = isEmpty,
	assign = assign,
	unique = unique,
	flatten = flatten,
	shuffle = shuffle,
}
