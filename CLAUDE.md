# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**UniversalSynSaveInstance (USSI)** is a Roblox saveinstance tool rewritten with modern architecture. The goal is to rewrite the old saveinstance code (`.cursor/data/old/saveinstance.luau`) using a Cascade UI-inspired structure with support for both UI and headless operation modes.

### Core Purpose
- Save Roblox game instances to XML (with binary support architecture)
- Support both model (`.rbxmx`) and game (`.rbxlx`) file formats
- Provide UI interface via Cascade and headless operation with logging
- Maintain full property coverage with authoritative documentation

## Build System

### Running Builds

```bash
lune run pipeline/build.luau pipeline/.pcmp.json
```

This prompts you to select from 4 build configurations:

1. **Test** - `tests/test.luau` → `generated/test.client.luau` (debug, no versioning)
2. **Debug** - `src/init.luau` → `generated/debug.luau` (development build)
3. **Beta** - `src/init.luau` → `generated/dist.luau` (prompts version, enables deployment, marked as prerelease)
4. **Release** - `src/init.luau` → `generated/dist.luau` (prompts version, full production release)

### Build Process

The build system uses:
- **darklua** for code processing (debug config retains lines, production config optimizes aggressively)
- **Template injection** via `pipeline/frame.luau` with markers:
  - `__COMPOSER.Insert(__COMPOSER.build)` - Injects processed code
  - `__COMPOSER.Insert(__COMPOSER.genDate)` - Injects ISO date
  - `__COMPOSER.Insert(__COMPOSER.cfg)` - Injects config name
  - `__COMPOSER.Insert(__COMPOSER.vers)` - Injects version string

### Deployment

Beta/Release builds can auto-deploy to GitHub:
- Requires `.env` file with `GITHUB_API_KEY=your_token_here`
- Configured in `pipeline/.pcmp.json` under `deployment.github`
- Creates GitHub release with tag and uploads asset

## Project Structure & Architecture

### Directory Organization

```
src/
├── init.luau              # Main entry point, orchestrates saveinstance operation
├── types.luau             # Comprehensive type definitions for all modules
├── utilities/             # Pure utility functions (string, table, io, services, executor)
│   ├── string.luau        # String manipulation utilities
│   ├── table.luau         # Table operations (wraps TableUtil package)
│   ├── io.luau            # Promise-based file I/O operations
│   ├── services.luau      # Cached Roblox service access with fallbacks
│   └── executor.luau      # Executor detection, function validation, safe API wrappers
└── modules/               # Feature modules (to be implemented)
```

### Module Import Pattern

```lua
-- External packages use @packages prefix
local Fusion = require("@packages/fusion")
local Promise = require("@packages/promise")
local TableUtil = require("@packages/tableUtil")

-- Utilities use @utilities prefix
local StringUtil = require("@utilities/string")
local TableUtil = require("@utilities/table")
local IO = require("@utilities/io")
local Services = require("@utilities/services")
local Executor = require("@utilities/executor")

-- Types use @types prefix
local Types = require("@types")
```

### Key Architecture Patterns

#### 1. Executor Environment System - sUNC API Compliance (`src/utilities/executor.luau`)

**CRITICAL**: This project uses **sUNC API standard exclusively** (https://docs.sunc.su/).

The executor module provides safe access to sUNC-compliant executor APIs:

```lua
local Executor = require("@utilities/executor")

-- Executor info (uses identifyexecutor per sUNC spec)
print(Executor.info.name)      -- Executor name
print(Executor.info.version)   -- Version string
print(Executor.info.detected)  -- Detection success

-- Direct sUNC API access (exact function names from sUNC spec)
local api = Executor.api
api.gethiddenproperty(instance, "PropertyName")  -- Not gethiddenprop or GetHiddenProperty
api.getscriptbytecode(script)                    -- Not dumpstring or getscriptcode
api.crypt.base64encode(data)                      -- In crypt table
api.debug.getconstants(fn)                        -- In debug table

-- Safe wrapped functions with fallbacks
local value = Executor.getHiddenProperty(instance, "PropertyName")
local bytecode = Executor.getScriptBytecode(script)
local hash = Executor.getScriptHash(script)
local encoded = Executor.encodeBase64(data)  -- Uses crypt.base64encode

-- Thread identity management
Executor.setThreadIdentity(8)
local identity = Executor.getThreadIdentity()

-- Check function availability (supports nested paths)
if Executor.hasFunction("crypt.base64encode") then
    -- Use base64 encoding
end
```

**sUNC Compliance Features:**
- **No aliases**: Only exact sUNC function names (no `gethiddenprop`, `dumpstring`, etc.)
- **Strict naming**: Matches sUNC specification exactly
- **Organized API**: Functions grouped by category (Reflection, Scripts, Instances, Cryptography, Debug, Closures, Signals)
- **Validation**: Tests functions with known inputs per sUNC spec
- **Fallbacks**: UGCValidationService for `gethiddenproperty`, Reselim's Base64 for `crypt.base64encode`
- **Documentation**: All function references point to https://docs.sunc.su/

#### 2. Service Access Pattern (`src/utilities/services.luau`)

```lua
local getService = require("@utilities/services")

-- Attempts multiple access methods with caching
local RunService = getService("RunService")
local HttpService = getService("HttpService")
```

Services are retrieved via:
1. `Instance.new(serviceName)`
2. `game:GetService(serviceName)`
3. `settings():GetService(serviceName)`
4. `UserSettings():GetService(serviceName)`

Successfully retrieved services are cached and cloneref'd if available.

#### 3. Promise-Based I/O (`src/utilities/io.luau`)

```lua
local IO = require("@utilities/io")

-- All operations return promises
IO.read("path/to/file"):andThen(function(result)
    if result.success then
        print(result.data)
    else
        warn(result.error)
    end
end)

IO.write("path/to/file", content):await()
```

#### 4. Type System (`src/types.luau`)

Comprehensive exported types for save operations:
- `SaveMode` - "full" | "optimized" | "scripts"
- `FileFormat` - "rbxl" | "rbxlx" | "rbxm" | "rbxmx"
- `Options` - Complete configuration with 30+ options
- `Result` - Save operation result with stats
- `Stats` - Operation statistics (instances processed, time, file size, etc.)

## Development Standards (From `.cursor/rules/goal.mdc`)

### Code Quality Requirements

1. **Build from scratch** - Use `.cursor/data` only as reference, don't copy-paste
2. **Multi-source verification** - Read at least 3 different versions before implementing
3. **File modification** - Read minimum 3 reference files before changes
4. **New file creation** - Read minimum 5 reference files before implementation
5. **Robust error handling** - Include edge case testing
6. **Modular and clean** - Apply aggressive design principles

### Reference Materials

- **Old saveinstance code**: `.cursor/data/old/saveinstance.luau`
- **Cascade UI structure**: `.cursor/data/Cascade-main/` (learn folder/file organization)
- **Binary/XML parsing**: Reference projects in `.cursor/data/`
- **sUNC API docs**: `.cursor/data/docs.sunc.su-main/` (executor API reference)

### Technology Requirements

- **UI**: Cascade package for interface
- **Internal logic**: Fusion (reactive), Promise (async), TableUtil (data manipulation)
- **Format support**: XML (primary), Binary (architecture ready)
- **Documentation**: Authoritative info with comparisons for verification

## Code Style

### Formatting (StyLua)

```toml
line_endings = "Windows"      # CRLF
indent_type = "Tabs"          # Tab characters
indent_width = 4              # 4 spaces wide
column_width = 120            # Max line length
quote_style = "AutoPreferDouble"
```

Run formatter: `stylua .`

### Documentation Pattern

```lua
--[[
    Module Name - Brief Description

    Detailed description of module purpose and usage patterns.

    Usage:
        local Module = require("path.to.module")
        local result = Module.function(args)

    @author Aspecter
    @version 1.0.0
    @since 1.0.0
]]

--[=[
    Function description

    @param name type -- Description
    @param optional type? -- Optional parameter description
    @return type -- Return value description
]=]
local function functionName(name: string, optional: number?): ReturnType
    -- Implementation
end
```

### Error Handling Pattern

```lua
-- Validate inputs
if type(param) ~= "expectedType" then
    error(`Expected expectedType, got {type(param)}`)
end

-- Safe external calls
local success, result = pcall(function()
    return externalFunction(args)
end)

if not success then
    -- Handle error
    return nil
end
```

## Important Implementation Notes

### sUNC API Standard - No Aliases

**CRITICAL DIFFERENCE FROM OLD CODE**: The old saveinstance used a "UniversalMethodFinder" to detect executor functions with multiple naming conventions. **The new implementation uses sUNC API exclusively with NO aliases**.

```lua
-- OLD WAY (multiple aliases):
container.gethiddenproperty = (gethiddenproperty :: any)
    or (gethiddenprop :: any)
    or (GetHiddenProperty :: any)

-- NEW WAY (sUNC standard only):
api.gethiddenproperty = (gethiddenproperty :: any)  -- Exact sUNC name only
```

**Why sUNC Only?**
- All modern executors implement sUNC standard
- Single source of truth: https://docs.sunc.su/
- No detection overhead, simpler codebase
- Clear specification for all function signatures

**sUNC Function Categories:**
- **Reflection**: `gethiddenproperty`, `sethiddenproperty`, `setthreadidentity`, etc.
- **Scripts**: `getscriptbytecode`, `getscripthash`, `getsenv`, etc.
- **Instances**: `cloneref`, `getnilinstances`, `gethui`, etc.
- **Cryptography**: `crypt.base64encode`, `crypt.base64decode`
- **Debug**: `debug.getconstants`, `debug.getupvalues`, etc.
- **Closures**: `hookfunction`, `clonefunction`, `iscclosure`, etc.

### Service Metatable Pattern

The old code used a metatable for lazy service loading. The new implementation uses a function-based approach in `src/utilities/services.luau` with caching and cloneref support.

### Property Reading with Thread Identity

When reading hidden properties, thread identity may need elevation:

```lua
Executor.setThreadIdentity(8)  -- Elevate to max identity
local value = Executor.getHiddenProperty(instance, "PropertyName")
```

### Base64 Encoding

The sUNC API provides `crypt.base64encode` and `crypt.base64decode` in the `crypt` table:

```lua
-- sUNC standard way
local encoded = crypt.base64encode(data)
local decoded = crypt.base64decode(encoded)

-- Via executor wrapper
local encoded = Executor.encodeBase64(data)
local decoded = Executor.decodeBase64(data)
```

The executor module provides fallback to Reselim's Base64 library when `crypt.base64encode` is unavailable.

## Testing

Place test files in:
- `tests/pre/` - Pre-build validation
- `tests/mid/` - Mid-build checks
- `tests/post/` - Post-build verification

Test build command: `lune run pipeline/build.luau pipeline/.pcmp.json` → Select "Test"

## Common Patterns

### Getting Started with a New Module

1. Read 5+ reference files from `.cursor/data/`
2. Define types in `src/types.luau`
3. Create module in `src/modules/` or utility in `src/utilities/`
4. Use existing utilities (string, table, io, services, executor)
5. Document with `--[[]]` and `--[=[]=]` blocks
6. Test with Test build configuration

### Working with Instances

```lua
local Services = require("@utilities/services")
local Executor = require("@utilities/executor")

-- Get service safely
local Workspace = Services("Workspace")

-- Read hidden property with fallback (uses sUNC gethiddenproperty)
local value = Executor.getHiddenProperty(instance, "PropertyName")

-- Set hidden property (uses sUNC sethiddenproperty)
local success = Executor.setHiddenProperty(instance, "PropertyName", newValue)

-- Clone reference to avoid detection (uses sUNC cloneref)
local safeRef = Executor.cloneReference(service)

-- Direct sUNC API access
Executor.api.gethiddenproperty(instance, "PropertyName")
Executor.api.cloneref(service)
```

### Async Operations

```lua
local Promise = require("@packages/promise")
local IO = require("@utilities/io")

Promise.new(function(resolve, reject)
    -- Async work
    resolve(result)
end):andThen(function(result)
    return IO.write("output.txt", result)
end):andThen(function()
    print("Done!")
end):catch(function(err)
    warn("Error:", err)
end)
```

## Workflow Execution Framework

The project uses a structured 4-prompt workflow (see `.cursor/rules/prompt.mdc`):

1. **PROMPT 0**: Acknowledge requirements
2. **PROMPT 1**: Project analysis → Create/update `.cursor/rules/context.mdc`
3. **PROMPT 2**: 25 strategic questions with answers
4. **PROMPT 3**: 50+ actionable todos with full metadata
5. **PROMPT 4**: Execute todos → Generate status reports in `.cursor/reports/`

**Important**: When following this workflow:
- Read minimum 25 files before creating todos (PROMPT 3)
- Each todo requires: ID, title, description, category, phase, priority, dependencies, success criteria, related questions
- Reports saved to `.cursor/reports/report_YYYYMMDD_HHMMSS.md`
- Ruthlessly prevent scope creep - log improvements but don't implement unless planned

## Key Constraints

1. **XML Primary, Binary Ready** - Focus on XML implementation but architecture must support binary
2. **No Scope Creep** - Don't introduce new features unless absolutely necessary for cleaner code
3. **Keep It Simple** - Use existing packages (Cascade, Fusion, Promise, TableUtil)
4. **Reference Multiple Sources** - Minimum 3 implementations before coding
5. **Authoritative Documentation** - Include source citations for verification
6. **Cascade UI Structure** - Follow the organizational patterns from `.cursor/data/Cascade-main/`
