# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UniversalSynSaveInstance is a Roblox serialization library written in Luau. The project analyzes the Roblox API to understand instance serialization capabilities and provides utilities for saving/loading Roblox instances.

## Development Commands

### Building
The project uses a custom build pipeline with darklua for bundling and minification:
```bash
lune run lune/pipeline/init.luau <config.json>
```

The build system (`lune/pipeline/init.luau`) handles:
- Interactive build configuration selection
- Version prompting
- Source processing with darklua (bundling, minification, variable renaming)
- Template composition using `lune/pipeline/frame.luau` with composer markers
- Optional GitHub release deployment

Composer markers in `lune/pipeline/frame.luau`:
- `__COMPOSER.Insert(__COMPOSER.build)` - Injects compiled source
- `__COMPOSER.Insert(__COMPOSER.genDate)` - Injects build date
- `__COMPOSER.Insert(__COMPOSER.cfg)` - Injects build config name
- `__COMPOSER.Insert(__COMPOSER.vers)` - Injects version string

### Running API Dumpers
The `lune/dump/scripts/` directory contains analysis scripts that fetch and process Roblox API dumps:
```bash
lune run lune/dump/init.luau [version-hash]
```

This executes all dumper scripts sequentially and generates JSON output in `lune/dump/gen/`. Each dumper analyzes specific aspects:
- `datatypes.luau` - Data type serialization capabilities (asymmetric save/load)
- `expected-classes.luau` - Classes expected in serialization
- `interesting-properties.luau` - Properties with special serialization behavior
- `not-creatable.luau` - Non-instantiable classes
- `not-scriptable.luau` - Classes hidden from scripting API
- `inheritance.luau` - Class hierarchy relationships

### Linting
```bash
selene src/ lune/
```

### Formatting
```bash
stylua src/ lune/
```

## Architecture

### Core Structure
- `src/` - Main library source (entry point: `src/init.luau`)
- `src/types.luau` - Type definitions for the library
- `packages/` - Third-party dependencies (fusion.luau, promise.luau, rbxmSuite.luau)
- `lune/` - Lune scripts directory (build and analysis tooling)
  - `lune/pipeline/` - Build system and template files
  - `lune/dump/` - API analysis tooling
    - `lune/dump/scripts/` - Individual dumper scripts
    - `lune/dump/gen/` - Generated JSON output files
  - `lune/shared/` - Shared utilities (logging, filesystem, CLI helpers)

### Build Pipeline Architecture
The build system uses a two-stage process:
1. **Darklua Processing**: Bundles and minifies source code using configurations in `lune/pipeline/.darklua/` directory (production, debug, minify variants). Applies aggressive optimizations including variable renaming, dead code elimination, and comment removal.
2. **Template Composition**: Injects processed code into `lune/pipeline/frame.luau` by replacing composer markers with actual values (build code, date, config, version).

### API Dumper Architecture
- `lune/dump/lib.luau` - Dumper-specific utilities:
  - `Lib.fetch(hash?)` - Fetches API dump from Roblox CDN (latest or specific version)
  - `Lib.tags()` - Normalizes tag arrays/objects to dictionaries
  - `Lib.json()` - Serializes data and writes to `lune/dump/gen/`
  - `Lib.inherits()` - Checks class inheritance relationships
  - `Lib.classes()` - Builds class lookup maps
- `lune/shared/` - Shared utilities across all lune scripts:
  - `logging.luau` - Colored logging, progress indicators, formatting
  - `fs.luau` - Filesystem operations with error handling
  - `cli.luau` - CLI argument parsing and error handling
- Each dumper is autonomous and follows the pattern:
  1. Fetch API dump via `lib.fetch()`
  2. Process/analyze specific aspect
  3. Output JSON via `lib.json()`

### Global Type Definitions
- `.globals/environment.d.luau` - Standard Luau/Roblox types
- `.globals/pcmp.d.luau` - Build system globals (`__COMPOSER`, `_P`)

## Toolchain
Managed by Rokit (see `rokit.toml`):
- **lune** (0.10.4) - Luau script runtime for build/analysis scripts
- **selene** (0.29.0) - Luau linter
- **StyLua** (2.3.1) - Code formatter
- **darklua** (0.17.2) - Bundler and minifier

Install tools: `rokit install`

## Key Conventions
- File extension: `.luau` (not `.lua`)
- Type annotations: Use `--!strict` for full type checking
- All lune scripts are organized under `lune/` directory to prevent redundant code
- Dumper scripts are discovered automatically by filename pattern `lune/dump/scripts/*.luau`
- API dumps are fetched from `https://setup.rbxcdn.com/` and output to `lune/dump/gen/`
- Build configurations are stored in JSON files and passed to the build script
- GitHub deployment requires `GITHUB_API_KEY` in `.env` file
