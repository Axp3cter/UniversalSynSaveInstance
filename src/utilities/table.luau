--[[
	Table Utilities - Extended Table Operations

	Wraps TableUtil package with focused utilities that add value.
	Avoids redundant wrappers of native table library.

	@author Aspecter
	@version 2.0.0
]]

local TableUtil = require("@packages/tableUtil")

-- Deep copy table
local function copy<T>(tbl: { T }): { T }
	return TableUtil.Copy(tbl, true)
end

-- Synchronize source with template (deep sync)
local function sync<T>(src: { T }, template: { T }): { T }
	return TableUtil.Sync(src, template)
end

-- Reconcile source with template (one-way sync)
local function reconcile<T>(src: { T }, template: { T }): { T }
	return TableUtil.Reconcile(src, template)
end

-- Map table values
local function map<T, U, K>(tbl: { [K]: T }, callback: (T, K, { [K]: T }) -> U): { [K]: U }
	return TableUtil.Map(tbl, callback)
end

-- Filter table values
local function filter<T, K>(tbl: { [K]: T }, predicate: (T, K, { [K]: T }) -> boolean): { [K]: T }
	return TableUtil.Filter(tbl, predicate)
end

-- Reduce table to single value
local function reduce<T, U, K>(tbl: { [K]: T }, callback: (U, T, K, { [K]: T }) -> U, initial: U?): U
	return TableUtil.Reduce(tbl, callback, initial)
end

-- Extend array with another
local function extend<T>(target: { T }, extension: { T }): { T }
	return TableUtil.Extend(target, extension)
end

-- Reverse array
local function reverse<T>(tbl: { T }): { T }
	return TableUtil.Reverse(tbl)
end

-- Get table keys as array
local function keys<K, V>(tbl: { [K]: V }): { K }
	return TableUtil.Keys(tbl)
end

-- Get table values as array
local function values<K, V>(tbl: { [K]: V }): { V }
	return TableUtil.Values(tbl)
end

-- Find first matching element
local function find<T, K>(tbl: { [K]: T }, predicate: (T, K, { [K]: T }) -> boolean): (T?, K?)
	return TableUtil.Find(tbl, predicate)
end

-- Check if all elements match
local function every<T, K>(tbl: { [K]: T }, predicate: (T, K, { [K]: T }) -> boolean): boolean
	return TableUtil.Every(tbl, predicate)
end

-- Check if any element matches
local function some<T, K>(tbl: { [K]: T }, predicate: (T, K, { [K]: T }) -> boolean): boolean
	return TableUtil.Some(tbl, predicate)
end

-- Check if table is empty
local function isEmpty<K, V>(tbl: { [K]: V }): boolean
	return TableUtil.IsEmpty(tbl)
end

-- Merge tables (shallow)
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

-- Remove duplicates from array
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

-- Flatten nested arrays
local function flatten<T>(tbl: { T }, depth: number?): { T }
	return TableUtil.Flat(tbl, depth or 1)
end

-- Shuffle array elements
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
