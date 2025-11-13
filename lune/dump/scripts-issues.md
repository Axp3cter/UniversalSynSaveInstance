# All Script Files - Common Style Guide Violations

## Common Issues Across All 6 Scripts

All scripts share these violations (20 issues × 6 files = 120 total):

### datatypes.luau, expected-classes.luau, inheritance.luau, interesting-properties.luau, not-creatable.luau, not-scriptable.luau

**Issue 1**: Missing return type on `.run()` function
- Should be `function [Module].run(hash: string?): ()`

**Issue 2**: Missing section comments for organization
- No `-- Processing`, `-- Sorting`, `-- Output` sections

**Issue 3**: Untyped table initialization for results
- `local results = {}` should have type annotation

**Issue 4**: Missing intermediate variable names
- Inline table constructions reduce clarity

**Issue 5**: Missing LDoc on private helper functions (where applicable)
- Functions like `isPlaceholder`, `hasPattern`, `matchesPattern` lack docs

**Issue 6**: Missing return type on private helper functions
- All helpers need explicit return types

**Issue 7**: Generic loop variable names in nested loops
- Using `_` for both outer and inner loops is confusing

**Issue 8**: Untyped local variables in main loop
- Variables like `tags`, `vt`, `ser` lack explicit types

**Issue 9**: Table field access without nil checks
- Direct access like `member.ValueType` without validation

**Issue 10**: Magic string literals inline
- Strings like "Property", "Enum", "Class" should be constants

**Issue 11**: Inline boolean expressions
- Conditions like `ser.CanLoad and ser.CanSave` repeated multiple times

**Issue 12**: Missing early return optimization
- Deep nesting instead of guard clauses

**Issue 13**: Anonymous sort functions
- Sort comparators should be extracted and named

**Issue 14**: Implicit table insertions
- `table.insert(results, {...})` doesn't show result type

**Issue 15**: Missing validation before operations
- No checks that api.Classes exists and is iterable

**Issue 16**: Hardcoded string patterns
- Patterns like `"%.luau$"` should be constants

**Issue 17**: Inconsistent spacing around operators
- Some places have `==` others have `==` with varied spacing

**Issue 18**: Missing error context in success messages
- Generic labels like "items" vs specific descriptions

**Issue 19**: Duplicated tag normalization pattern
- `local tags = Lib.tags(...)` pattern repeated without helper

**Issue 20**: Missing module-level type definitions for results
- Each script's result format should be exported type

## Specific Issues Per File

### datatypes.luau Additional Concerns
- Line 33: Uses 3 parallel tracking tables (types, seen, saveFlags, loadFlags)
- Line 65: Boolean calculation `hasDescriptor = canSave ~= canLoad` lacks explanation

### expected-classes.luau Additional Concerns
- Line 24: Condition `vt.Name ~= "Instance"` hardcodes special case
- Line 36: Sort function directly inline

### inheritance.luau Additional Concerns
- Line 19: Direct call to `Lib.inherits` without caching result
- Line 15: Map creation could fail if list is empty

### interesting-properties.luau Additional Concerns
- Line 41: Complex nested table `classProps[class.Name] = { tags =..., props = {} }`
- Line 84: `isPlaceholder` function uses magic string `"__api_dump_"`
- Line 50-52: Triple assignment for prop metadata

### not-creatable.luau Additional Concerns
- Line 26: `matchesPattern` iterates full pattern list every time
- Line 33: Building tagList from tags dict could use table.create

### not-scriptable.luau Additional Concerns
- Line 90-110: Three-pass processing (NotScriptable, serialization-named, proxies)
- Line 53: `enumTracker` table purpose unclear without docs
- Line 114: Complex proxy count calculation `#results - notScriptableCount - serializationNamedCount`
