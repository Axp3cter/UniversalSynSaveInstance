# lib.luau - 20 Specific Style Guide Violations

## Issue 1: Line 79-91 - Missing LDoc on private helper
**Violation**: `normalizeTag` helper function lacks documentation
**Rule**: All functions should have LDoc, even private helpers
**Location**: `local function normalizeTag(key: any, value: any, tags: { [string]: any })`

## Issue 2: Line 143-151 - Missing LDoc on private helper
**Violation**: `ensureDir` helper function lacks documentation
**Rule**: Private helpers should document their purpose
**Location**: `local function ensureDir()`

## Issue 3: Line 210-231 - Missing LDoc on private helper
**Violation**: `tryFetch` helper function lacks documentation
**Rule**: Complex helpers need documentation
**Location**: `local function tryFetch(hash: string): FetchResult`

## Issue 4: Line 233-276 - Missing LDoc on private helper
**Violation**: `findLatest` helper function lacks documentation
**Rule**: Complex logic needs explanation
**Location**: `local function findLatest(): ApiDump`

## Issue 5: Line 192-206 - Missing LDoc on public logging wrappers
**Violation**: Public functions `success`, `error`, `warn`, `info` lack LDoc
**Rule**: All public API must be documented
**Location**: Functions at lines 192, 196, 200, 204

## Issue 6: Line 192 - Missing return type annotation
**Violation**: `function Lib.success(count: number, label: string, extra: string?)`
**Rule**: All functions must declare explicit return type
**Location**: Should be `function Lib.success(...): ()`

## Issue 7: Line 196 - Missing return type annotation
**Violation**: `function Lib.error(msg: string)`
**Rule**: All functions must declare explicit return type
**Location**: Should be `function Lib.error(msg: string): ()`

## Issue 8: Line 200 - Missing return type annotation
**Violation**: `function Lib.warn(msg: string)`
**Rule**: All functions must declare explicit return type
**Location**: Should be `function Lib.warn(msg: string): ()`

## Issue 9: Line 204 - Missing return type annotation
**Violation**: `function Lib.info(msg: string)`
**Rule**: All functions must declare explicit return type
**Location**: Should be `function Lib.info(msg: string): ()`

## Issue 10: Line 27 - Using `any` type
**Violation**: `Tags: { [any]: any }?` in Class type
**Rule**: Avoid `any`, use specific types
**Location**: `export type Class` definition

## Issue 11: Line 38 - Using `any` type
**Violation**: `Tags: { [any]: any }?` in Member type
**Rule**: Avoid `any`, use specific types
**Location**: `export type Member` definition

## Issue 12: Line 59 - Using `any` array type
**Violation**: `data: { any }` in StandardOutput type
**Rule**: Arrays should have specific element types
**Location**: `export type StandardOutput` definition

## Issue 13: Line 104 - Untyped table initialization
**Violation**: `local tags = {}` lacks type annotation
**Rule**: All variables should have explicit or inferred types
**Location**: Inside `Lib.tags` function

## Issue 14: Line 79 - Mutating parameter without const indicator
**Violation**: `tags` parameter is mutated in place
**Rule**: Functions should not mutate parameters, or should document it
**Location**: `normalizeTag` function modifies `tags` table

## Issue 15: Line 144-150 - Nested anonymous function in pcall
**Violation**: `if not pcall(function() ... end) then`
**Rule**: Prefer named functions or direct pcall
**Location**: `ensureDir` function

## Issue 16: Line 245-247 - Inline counting without extraction
**Violation**: Counting loop for `totalVersions` inline
**Rule**: Complex calculations should be extracted to named functions
**Location**: `for _ in string.gmatch(history, "version%-[^%s]+") do totalVersions += 1 end`

## Issue 17: Line 338 - Missing type annotation on table.create
**Violation**: `local map = table.create(#list)` lacks explicit type
**Rule**: Type annotations improve clarity
**Location**: Inside `Lib.classes` function

## Issue 18: Line 162-165 - Implicit error message
**Violation**: Generic error message `Failed to write {path}`
**Rule**: Error messages should indicate root cause
**Location**: Inside `Lib.write` function

## Issue 19: Line 177-180 - Implicit error handling
**Violation**: `if not result.success then error(...)`
**Rule**: Should use guard clause pattern consistently
**Location**: Inside `Lib.json` function

## Issue 20: Line 85 - Unclear iteration pattern
**Violation**: `for k, v in value do` iterates over unknown structure
**Rule**: Should validate or type narrow before iteration
**Location**: Inside `normalizeTag` function
