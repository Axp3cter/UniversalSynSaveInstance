# main.luau - 20 Specific Style Guide Violations

## Issue 1: Line 25-30 - Missing LDoc on private helper
**Violation**: `discoverScripts` function lacks documentation
**Rule**: All functions should have LDoc
**Location**: `local function discoverScripts(): { string }`

## Issue 2: Line 34-40 - Missing LDoc on private helper
**Violation**: `printHeader` function lacks documentation
**Rule**: All functions should have LDoc
**Location**: `local function printHeader(text: string)`

## Issue 3: Line 42-46 - Missing LDoc on private helper
**Violation**: `printProgress` function lacks documentation
**Rule**: All functions should have LDoc
**Location**: `local function printProgress(index: number, total: number, name: string)`

## Issue 4: Line 48-69 - Missing LDoc on private helper
**Violation**: `printSummary` function lacks documentation
**Rule**: All functions should have LDoc
**Location**: `local function printSummary(succeeded: number, failed: number, total: number, elapsed: number)`

## Issue 5: Line 73-96 - Missing LDoc on private helper
**Violation**: `executeScript` function lacks documentation
**Rule**: All functions should have LDoc
**Location**: `local function executeScript(path: string, hash: string?): boolean`

## Issue 6: Line 34 - Missing return type annotation
**Violation**: `printHeader` lacks explicit return type
**Rule**: All functions must declare return type
**Location**: Should be `function printHeader(text: string): ()`

## Issue 7: Line 42 - Missing return type annotation
**Violation**: `printProgress` lacks explicit return type
**Rule**: All functions must declare return type
**Location**: Should be `function printProgress(...): ()`

## Issue 8: Line 48 - Missing return type annotation
**Violation**: `printSummary` lacks explicit return type
**Rule**: All functions must declare return type
**Location**: Should be `function printSummary(...): ()`

## Issue 9: Line 21 - Untyped module table
**Violation**: `local Main = {}` lacks type annotation
**Rule**: Tables should have explicit types where possible
**Location**: Should declare module type

## Issue 10: Line 79 - Implicit error handling
**Violation**: `pcall(Process.exec, ...)` doesn't use result properly
**Rule**: Should capture and use both ok and result explicitly
**Location**: Inside `executeScript` function

## Issue 11: Line 82-85 - Generic error message
**Violation**: Error output `x {result}` is unclear
**Rule**: Error messages should be specific
**Location**: Should explain what result represents

## Issue 12: Line 89-92 - Generic error message
**Violation**: Error output `x Exit code {result.code}` lacks context
**Rule**: Should include which script failed
**Location**: Should include script path in error

## Issue 13: Line 17 - Duplicate stdio import usage
**Violation**: Multiple `stdio.write` calls for same style
**Rule**: Could extract style management to helper
**Location**: Throughout file - repeated style/color patterns

## Issue 14: Line 110-111 - Magic string formatting
**Violation**: `API Dump Analysis  •  {os.date(...)}`  uses hardcoded format
**Rule**: Should extract format string to constant
**Location**: Inside `Main.run` function

## Issue 15: Line 44 - String gsub inline
**Violation**: `string.gsub(name, "%.luau$", "")` inline in print
**Rule**: Should extract to variable for clarity
**Location**: Inside `printProgress` function

## Issue 16: Line 18 - Magic number 70
**Violation**: `string.rep("=", 70)` hardcodes separator length
**Rule**: Should be named constant with comment
**Location**: `SEPARATOR` definition could use better constant name like `SEPARATOR_WIDTH`

## Issue 17: Line 105-107 - Repeated stdio pattern
**Violation**: `stdio.write(stdio.color("yellow"))` then print then reset
**Rule**: Should extract to helper function
**Location**: Repeated pattern throughout file

## Issue 18: Line 122-132 - Large function body
**Violation**: Main loop mixes iteration, execution, and counting
**Rule**: Should extract loop body to helper
**Location**: Inside `Main.run` for loop

## Issue 19: Line 120 - Using os.time() for elapsed calculation
**Violation**: `os.time()` returns seconds since epoch (large number)
**Rule**: Should use os.clock() for elapsed time measurement
**Location**: `local startTime = os.time()`

## Issue 20: Line 28 - Generic error message
**Violation**: `error(\`Failed to read {SCRIPTS_DIR}\`)` doesn't include actual error
**Rule**: Should include the actual error from pcall
**Location**: Inside `discoverScripts` function
