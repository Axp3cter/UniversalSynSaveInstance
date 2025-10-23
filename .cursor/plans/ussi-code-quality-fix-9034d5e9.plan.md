<!-- 9034d5e9-6338-4f0a-a0d4-c22d18489628 4aeb93e6-f91e-404b-a4db-2853bd633dac -->
# USSI Complete Code Quality and Consistency Fixes

## Overview

This plan systematically addresses all 31 files requiring fixes, creation, or deletion identified in the comprehensive analysis. The work is organized into 5 phases with clear dependencies, following strict criteria: sUNC API compliance, type system consistency, one comment per line, 3+ source verification, and zero information loss.

## Strict Criteria (Applied to All Tasks)

1. sUNC API Compliance: ONLY exact sUNC function names (no fallbacks, alternatives, or legacy functions)
2. Type System Consistency: All types must match between types.luau and implementation files exactly
3. Documentation Standard: One comment per line of code explaining authoritative information
4. Code Quality: Follow established patterns, 3+ reference verification for new patterns
5. Error Handling: Explicit error returns (Go-style), comprehensive validation
6. Zero Information Loss: No data loss in serialization/deserialization
7. Reference Verification: Every implementation verified against 3+ sources

## Phase 1: Critical Foundation (Blocks Everything)

### 1.1 Type System Overhaul (src/types.luau)

BLOCKS: All other files

Current Issues:

- Result<T> generic doesn't match Types.Result usage in init.luau
- SaveResult type doesn't match actual return structure
- Missing types: PropertySerializer, DocumentStructure, SerializerContext
- Type inconsistency between logger types and implementation

Changes Required:

- Change Result<T> to non-generic Result type matching usage patterns
- Update SaveResult to match actual structure in init.luau (line 227-278)
- Add PropertySerializer type for xml/properties.luau (line 309)
- Add DocumentStructure type for xml/document.luau (lines 41-47)
- Add SerializerContext type for xml/properties.luau (lines 16-18)
- Fix Stats type to match statistics.luau implementation (lines 10-17)
- Add proper type exports for all public interfaces

Dependent Files to Update:

- src/init.luau (lines 223-397 Promise return type)
- src/utilities/executor.luau (all Result<T> usage)
- src/core/xml/document.luau (line 277 type)
- src/core/xml/properties.luau (SerializerContext usage)
- src/utilities/statistics.luau (Stats type alignment)

### 1.2 sUNC API Compliance Overhaul (src/utilities/executor.luau)

BLOCKS: All sUNC API usage

CRITICAL Issues:

- Line 99: Uses `identifyexecutor or getexecutorname or whatexecutor` (NON-SUNC)
- Lines 129-130: Uses `setthreadidentity or setthreadcontext or setidentity` (NON-SUNC)
- Line 182: Uses `isexecutorclosure or checkcaller or is_syn_closure` (NON-SUNC)
- Lines 149-158: Incorrect crypt API access (should be direct crypt.base64encode)
- Lines 233-242: External HTTP dependency for base64 fallback (VIOLATES SUNC)
- Lines 424-561: File existence check logic returns wrong success values

Changes Required:

- Remove ALL non-sUNC function references (lines 99, 129-130, 182)
- Fix crypt API to use ONLY crypt.base64encode/decode (lines 149-158)
- DELETE external HTTP fallback code entirely (lines 228-242)
- Fix isFile() and isFolder() success return values (lines 424-440)
- Standardize error handling to consistent Result pattern
- Remove redundant wrapper functions (base64Encode, base64Decode can be direct)
- Keep ONLY exact sUNC names: identifyexecutor, setthreadidentity, isexecutorclosure

Dependent Files to Update:

- src/init.luau (writeFile usage line 355)
- src/core/referent.luau (base64Encode usage line 26)
- src/core/sharedStrings.luau (base64Encode usage line 18)
- src/core/properties.luau (getHiddenProperty usage lines 62-64)
- src/core/xml/properties.luau (base64Encode usage lines 194, 277)

### 1.3 Create Missing Core Module: attributes.luau

BLOCKS: XML serialization pipeline

File: src/core/attributes.luau (MISSING - CREATE NEW)

Implementation Required:

- Read instance attributes using Instance:GetAttributes()
- Type validation for all attribute types (string, boolean, number, etc.)
- Attribute value serialization preparation
- Integration with Types.AttributeValue structure
- Error handling for attribute access failures
- One comment per line documentation

Reference: Study Roblox attribute system documentation and 3+ saveinstance implementations

Dependent Files to Update:

- src/core/xml/instance.luau (attribute reading line 71)
- src/core/xml/attributes.luau (attribute serialization)

### 1.4 Create Missing Core Module: tags.luau

BLOCKS: XML serialization pipeline

File: src/core/tags.luau (MISSING - CREATE NEW)

Implementation Required:

- Read instance tags using CollectionService:GetTags()
- Tag serialization to comma-separated string format
- Integration with XML generation pipeline
- Error handling for tag access failures
- One comment per line documentation

Reference: Study CollectionService API and XML tag format in 3+ references

Dependent Files to Update:

- src/core/xml/instance.luau (tags integration line 80)

### 1.5 Create Missing XML Module: xml/attributes.luau

BLOCKS: XML generation

File: src/core/xml/attributes.luau (MISSING - CREATE NEW)

Implementation Required:

- Serialize attributes to XML format per .rbxlx specification
- Handle all attribute type conversions (string, number, boolean, UDim2, etc.)
- XML structure: <BinaryString name="AttributesSerialize">base64data</BinaryString>
- Integration with xml/instance.luau (line 122)
- toXML() function matching xml/properties.luau pattern
- One comment per line documentation

Reference: Study .rbxlx attribute format in Roblox Studio saved files (3+ examples)

Dependent Files to Update:

- src/core/xml/init.luau (module exports line 14)
- src/core/xml/instance.luau (attribute integration lines 71-77, 122)

## Phase 2: Core Logic Fixes (Depends on Phase 1)

### 2.1 Main Entry Point Refactor (src/init.luau)

DEPENDS ON: Phase 1 (types.luau, executor.luau)

Issues:

- Line 205-211: getFileExtension() logic error - returns wrong extensions
- Lines 223-397: Inconsistent type usage Types.Result vs Result<T>
- Lines 188-194: Missing validation for logical conflicts
- Lines 246-258: Redundant anti-idle logic
- Missing comprehensive documentation (one comment per line)

Changes Required:

- Fix getFileExtension() to return correct .rbxl/.rbxlx/.rbxm/.rbxmx
- Standardize all Result type usage to match types.luau
- Add validation for noScripts=true with mode="scripts" conflict
- Simplify anti-idle implementation (lines 246-258)
- Add authoritative documentation for every line (currently ~40% commented)
- Fix Promise return type to match types.luau

### 2.2 XML Document Generation Fixes (src/core/xml/document.luau)

DEPENDS ON: Phase 1 (types.luau, attributes.luau, tags.luau, xml/attributes.luau)

Issues:

- Line 277: Uses Types.SaveResult instead of Types.Result
- Lines 234-239: Missing validation for empty instance collections
- Lines 263-267: Redundant statistics calculation
- Missing error handling for malformed XML generation

Changes Required:

- Fix return type at line 277 to use Types.Result
- Add validation for empty instances before line 234
- Simplify statistics calculation (lines 263-267)
- Add comprehensive error handling for XML generation failures
- Add missing documentation for all functions

### 2.3 Property Serialization Fixes (src/core/xml/properties.luau)

DEPENDS ON: Phase 1 (executor.luau)

CRITICAL Issues:

- Lines 194, 277: Use Executor.base64Encode() (sUNC violation)
- Missing validation for property type support
- Lines 12-14: Inconsistent XML escaping and CDATA usage
- Missing error handling for serialization failures

Changes Required:

- Replace Executor.base64Encode with direct crypt.base64encode (lines 194, 277)
- Add validation for all supported property types
- Fix XML escaping and CDATA usage to match specification
- Implement proper error handling for serialization failures
- Simplify serializer function structure

### 2.4 Instance Serialization Refactor (src/core/instance.luau)

DEPENDS ON: Phase 1 (types.luau)

Issues:

- Lines 74-76: Property filtering doesn't handle nil values correctly
- Missing validation for property reading operations
- Line 78: Inconsistent sorting logic for properties
- Missing error handling for property access failures

Changes Required:

- Fix nil value filtering in property serialization (lines 74-76)
- Add comprehensive validation for all property operations
- Standardize property sorting to follow XML specification (line 78)
- Implement proper error handling for property access
- Remove redundant property processing logic

### 2.5 Property Reading Overhaul (src/core/properties.luau)

DEPENDS ON: Phase 1 (executor.luau)

CRITICAL Issues:

- Lines 62-64: Uses Executor.getHiddenProperty() instead of direct sUNC API
- Missing validation for property type checking
- Lines 35-59: Inconsistent property filtering logic
- Missing error handling for property access failures

Changes Required:

- Replace Executor wrapper with direct gethiddenproperty sUNC API (lines 62-64)
- Add comprehensive property type validation
- Fix property filtering to handle all edge cases (lines 35-59)
- Implement proper error handling for property access
- Optimize property iteration logic (lines 77-82)

### 2.6 Traversal Logic Fixes (src/core/traversal.luau)

Issues:

- Line 141: Double-requires executor module (also required at top)
- Lines 86-114: Inconsistent instance filtering logic
- Missing validation for traversal options
- Lines 11-38: Redundant service checking logic

Changes Required:

- Remove duplicate executor require (line 141)
- Fix instance filtering to handle all edge cases (lines 86-114)
- Add comprehensive validation for traversal options
- Simplify service checking logic (lines 11-38)
- Implement proper error handling for service access

### 2.7 Hierarchy Building Simplification (src/core/hierarchy.luau)

Issues:

- Missing validation for instance references
- No error handling for malformed hierarchies
- Lines 20-25: Redundant node creation logic
- Missing documentation for hierarchy building algorithm

Changes Required:

- Add validation for instance references and parent-child relationships
- Implement error handling for malformed hierarchies
- Simplify node creation logic (lines 20-25)
- Add comprehensive documentation explaining hierarchy algorithm (currently no comments)

### 2.8 Referent System Overhaul (src/core/referent.luau)

DEPENDS ON: Phase 1 (executor.luau)

CRITICAL Issues:

- Line 26: Uses Executor.base64Encode() (sUNC violation)
- Line 12: ID generation starts from 0 (should start from 1)
- Missing validation for referent ID collisions
- No error handling for encoding failures

Changes Required:

- Replace base64Encode with direct crypt.base64encode (line 26)
- Fix ID generation to start from 1 instead of 0 (line 12)
- Add validation to prevent ID collisions
- Implement proper error handling for encoding failures

### 2.9 Shared Strings Fixes (src/core/sharedStrings.luau)

DEPENDS ON: Phase 1 (executor.luau)

CRITICAL Issues:

- Line 18: Uses Executor.base64Encode() (sUNC violation)
- Line 12: Inconsistent ID generation (should match referent system)
- Missing validation for string collisions
- No error handling for encoding failures

Changes Required:

- Replace base64Encode with direct crypt.base64encode (line 18)
- Align ID generation with referent system
- Add validation to prevent string collisions
- Implement proper error handling for encoding failures

### 2.10 Script Processing Overhaul (src/core/scripts.luau)

DEPENDS ON: Phase 1 (executor.luau)

CRITICAL Issues:

- Line 73: Uses `syn_decompile` fallback (violates sUNC - should only use `decompile`)
- Missing validation for script processing options
- Lines 78-88: Inconsistent error handling for decompilation failures
- Lines 109-116: Redundant caching logic
- Lines 78-88: Missing proper timeout implementation

Changes Required:

- Remove all non-sUNC decompiler references (line 73 - ONLY use `decompile`)
- Add comprehensive validation for script options
- Implement consistent error handling for decompilation (lines 78-88)
- Simplify caching logic (lines 109-116)
- Add proper timeout implementation for decompilation (lines 78-88)

### 2.11 Instance XML Generation Fixes (src/core/xml/instance.luau)

DEPENDS ON: Phase 1 (xml/attributes.luau)

Issues:

- Missing validation for serialized data structure
- Lines 68, 77: Inconsistent property/attribute sorting logic
- Missing error handling for XML generation
- Lines 71-77: Redundant attribute processing logic
- Missing documentation for XML format compliance

Changes Required:

- Add validation for all serialized data structures
- Fix property and attribute sorting to match XML specification (lines 68, 77)
- Implement proper error handling for XML generation
- Simplify attribute processing logic (lines 71-77)
- Add comprehensive documentation for XML format

## Phase 3: Supporting Systems (Independent)

### 3.1 Service Access Overhaul (src/utilities/services.luau)

CRITICAL Issues:

- Line 43: Uses Instance.new() for service creation (INCORRECT - services can't be created this way)
- Lines 38-58: Inconsistent service caching logic
- Missing validation for service availability
- Lines 42-46: Redundant service access methods
- Missing error handling for service failures

Changes Required:

- Remove Instance.new() attempt at line 43 (services CANNOT be instantiated)
- Use ONLY game:GetService() method (line 44)
- Simplify service caching logic (lines 38-58)
- Add comprehensive validation for service availability
- Remove redundant service access methods (lines 42-46, keep only game:GetService)
- Implement proper error handling for service failures

### 3.2 Statistics Tracking Fixes (src/utilities/statistics.luau)

Issues:

- Lines 10-17: Inconsistent statistics field naming
- Missing validation for statistics updates
- Lines 28-39: Redundant statistics calculation logic
- Lines 19-26: Missing memory tracking implementation
- Line 19: Inconsistent statistics reset logic

Changes Required:

- Standardize statistics field naming to match types.luau (lines 10-17)
- Add validation for all statistics updates
- Simplify statistics calculation logic (lines 28-39)
- Implement proper memory tracking (lines 19-26)
- Fix statistics reset logic (line 19)

### 3.3 Logger Standardization (src/utilities/logger.luau)

Issues:

- Lines 47-80: Inconsistent log level filtering
- Missing structured logging format
- Lines 20-26: Redundant logging configuration logic
- Missing log rotation and management
- Lines 63-67: Inconsistent error vs warning output handling

Changes Required:

- Standardize log level filtering and priority (lines 47-80)
- Implement structured logging format
- Simplify logging configuration logic (lines 20-26)
- Add log rotation and management
- Fix error vs warning output handling (lines 63-67)

### 3.4 XML Utilities Completion (src/utilities/xml.luau)

Issues:

- Missing comprehensive XML validation
- Lines 16-22: Inconsistent CDATA escaping (doesn't handle nested ]]>)
- Missing XML namespace handling
- Lines 24-40: Redundant XML utility functions
- Missing XML format compliance validation

Changes Required:

- Add comprehensive XML validation functions
- Fix CDATA escaping to handle all edge cases (lines 16-22)
- Add XML namespace handling
- Remove redundant utility functions (lines 24-40)
- Add XML format compliance validation

### 3.5 Table Utilities Cleanup (src/utilities/table.luau)

Issues:

- Lines 152-162: Redundant assign() implementation (TableUtil.Assign exists)
- Lines 202-220: Inconsistent function naming patterns
- Missing documentation for some utilities
- Lines 170-182: Redundant unique() implementation (should use TableUtil)
- Missing error handling for table operations

Changes Required:

- Remove redundant assign() function (lines 152-162, use TableUtil.Assign)
- Standardize function naming to match TableUtil patterns
- Add missing documentation for all functions
- Remove redundant unique() implementation (lines 170-182)
- Add error handling for all table operations

## Phase 4: Constants and Utilities

### 4.1 Create Missing: cframeRotations.luau

File: src/constants/cframeRotations.luau (MISSING - CREATE NEW)

Implementation Required:

- CFrame rotation matrix constants for common rotations (90°, 180°, 270°)
- CFrame identity matrix definitions
- Rotation utility functions for optimization
- Authoritative documentation from Roblox CFrame specification
- One comment per line

Reference: Roblox CFrame documentation and 3+ CFrame optimization examples

Dependent Files to Update:

- src/core/xml/properties.luau (CFrame serialization optimization line 72-94)
- src/constants/init.luau (module export line 10)

### 4.2 Attribute Type Constants Fixes (src/constants/attributeTypes.luau)

Issues:

- Missing documentation for type ID mappings
- Lines 36-62: Type ID values may be incorrect (need verification)
- Missing validation for type ID ranges
- Redundant type definitions with propertyTypes.luau

Changes Required:

- Add comprehensive documentation for all type IDs (authoritative source)
- Verify type ID values against Roblox specification (lines 36-62)
- Add validation for type ID ranges
- Remove redundant type definitions
- Add authoritative source references in comments

### 4.3 Property Type Constants Overhaul (src/constants/propertyTypes.luau)

Issues:

- Lines 21-72: Missing type mappings for some Roblox types
- Lines 21-72: Inconsistent XML type name mappings
- Lines 75-85: Missing default value validation
- Lines 147-177: Redundant type checking functions

Changes Required:

- Add missing type mappings for all Roblox property types (lines 21-72)
- Fix XML type name mappings to match specification (lines 21-72)
- Add validation for all default values (lines 75-85)
- Simplify type checking functions (lines 147-177)
- Add comprehensive documentation with authoritative sources

### 4.4 Constants Aggregation Fixes (src/constants/init.luau)

Issues:

- Line 10: References missing cframeRotations.luau file
- Lines 8-11: Inconsistent constant organization
- Missing validation for constant loading
- No error handling for missing constants

Changes Required:

- Remove reference to cframeRotations until Phase 4.1 completes (line 10)
- Reorganize constants by category (lines 8-11)
- Add validation for constant loading
- Implement error handling for missing constants
- Add comprehensive documentation

### 4.5 Create Missing: bit.luau

File: src/utilities/bit.luau (MISSING - CREATE NEW)

Implementation Required:

- Bit manipulation utilities for binary data processing
- Bit buffer integration with packages/bitBuffer.luau
- Bit-level data processing functions
- Binary format utilities for future binary implementation
- One comment per line documentation

Reference: Study bitBuffer.luau package and 3+ binary format implementations

Dependent Files to Update:

- src/core/binary/ (future binary format implementation)

### 4.6 Create Missing: string.luau

File: src/utilities/string.luau (MISSING - CREATE NEW)

Implementation Required:

- String validation functions (non-empty, valid characters, etc.)
- String format utilities (padding, truncation, etc.)
- String escaping utilities (XML, JSON, etc.)
- String encoding utilities
- One comment per line documentation

Reference: Study common string utility patterns in 3+ Luau projects

Dependent Files to Update:

- src/core/xml/properties.luau (string serialization)
- src/utilities/xml.luau (XML string handling)

### 4.7 Delete Backup File (src/utilities/executor.luau.backup)

File: src/utilities/executor.luau.backup (DELETE)

Action: Remove backup file entirely - causes confusion and has no documentation explaining purpose. Proper version control should be used instead.

## Phase 5: Testing and Build System

### 5.1 Create Test Implementation (tests/mid/xml_generation.luau)

File: tests/mid/xml_generation.luau (MISSING - CREATE NEW)

Implementation Required:

- Comprehensive XML generation tests
- Tests for all XML serialization functions
- Validation for serialization accuracy (zero information loss)
- Performance and memory usage tests
- Compare output against Roblox Studio .rbxlx files
- One comment per line documentation

Reference: Study test patterns in 3+ Luau test frameworks

### 5.2 Create Build Configuration (pipeline/.pcmp.json)

File: pipeline/.pcmp.json (MISSING - CREATE NEW)

Implementation Required:

- Complete build configuration for 4 build types (Test, Debug, Beta, Release)
- Build profile definitions with optimization levels
- Deployment settings for GitHub
- Test execution configuration
- JSON schema documentation

Reference: Study context.md build system description (lines 225-268)

### 5.3 Build Template Fixes (pipeline/frame.luau)

Issues:

- Missing comprehensive build metadata injection
- Inconsistent template variable replacement
- Missing validation for template injection
- No error handling for template processing

Changes Required:

- Add comprehensive build metadata injection
- Fix template variable replacement logic
- Add validation for all template variables
- Implement proper error handling for template processing
- Add documentation for template system

## Success Criteria for Completion

Each file/task is ONLY complete when:

- All code changes implemented with one comment per line
- All dependent files updated
- All documentation added with authoritative sources
- No new issues introduced
- Follows all 7 strict criteria
- Verified against 3+ reference sources

## Implementation Order Summary

1. Phase 1 (Foundation): types.luau → executor.luau → attributes.luau → tags.luau → xml/attributes.luau
2. Phase 2 (Core Logic): init.luau → xml/document.luau → xml/properties.luau → instance.luau → properties.luau → traversal.luau → hierarchy.luau → referent.luau → sharedStrings.luau → scripts.luau → xml/instance.luau
3. Phase 3 (Supporting): services.luau → statistics.luau → logger.luau → xml.luau → table.luau
4. Phase 4 (Constants/Utilities): cframeRotations.luau → attributeTypes.luau → propertyTypes.luau → constants/init.luau → bit.luau → string.luau → DELETE executor.luau.backup
5. Phase 5 (Testing/Build): xml_generation.luau → .pcmp.json → frame.luau

Total Files: 31 (5 new, 25 fixes, 1 deletion)
Critical Path: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

### To-dos

- [ ] Fix type system in src/types.luau - Result<T>, SaveResult, add missing types (PropertySerializer, DocumentStructure, SerializerContext), fix Stats type
- [ ] Fix sUNC compliance in src/utilities/executor.luau - remove non-sUNC functions (lines 99, 129-130, 182), fix crypt API, delete HTTP fallback, fix file check logic
- [ ] Create src/core/attributes.luau - read instance attributes, type validation, serialization prep, error handling
- [ ] Create src/core/tags.luau - read tags via CollectionService, serialize to comma-separated format, error handling
- [ ] Create src/core/xml/attributes.luau - XML attribute serialization per .rbxlx spec, toXML() function, all attribute types
- [ ] Fix src/init.luau - getFileExtension() logic, Result type usage, validation, anti-idle simplification, add documentation
- [ ] Fix src/core/xml/document.luau - Result type at line 277, empty instance validation, simplify statistics, error handling
- [ ] Fix src/core/xml/properties.luau - replace Executor.base64Encode with crypt.base64encode (lines 194, 277), type validation, XML escaping
- [ ] Fix src/core/instance.luau - nil value filtering (lines 74-76), property validation, sorting logic (line 78), error handling
- [ ] Fix src/core/properties.luau - replace Executor wrapper with direct gethiddenproperty (lines 62-64), type validation, filtering logic
- [ ] Fix src/core/traversal.luau - remove duplicate executor require (line 141), instance filtering (lines 86-114), service checking simplification
- [ ] Fix src/core/hierarchy.luau - add validation, error handling, simplify node creation (lines 20-25), add documentation
- [ ] Fix src/core/referent.luau - replace base64Encode with crypt.base64encode (line 26), start ID from 1 not 0 (line 12), collision validation
- [ ] Fix src/core/sharedStrings.luau - replace base64Encode with crypt.base64encode (line 18), align ID generation, collision validation
- [ ] Fix src/core/scripts.luau - remove syn_decompile fallback (line 73, use ONLY decompile), validation, error handling, simplify caching
- [ ] Fix src/core/xml/instance.luau - validation, sorting (lines 68, 77), error handling, simplify attribute processing (lines 71-77)
- [ ] Fix src/utilities/services.luau - remove Instance.new() (line 43), use ONLY game:GetService(), simplify caching, validation, error handling
- [ ] Fix src/utilities/statistics.luau - standardize field naming (lines 10-17), validation, simplify calculation (lines 28-39), memory tracking
- [ ] Fix src/utilities/logger.luau - log level filtering (lines 47-80), structured format, simplify config (lines 20-26), rotation, error/warning output
- [ ] Fix src/utilities/xml.luau - validation, CDATA escaping (lines 16-22), namespace handling, remove redundant functions (lines 24-40)
- [ ] Fix src/utilities/table.luau - remove redundant assign() (lines 152-162), unique() (lines 170-182), standardize naming, error handling
- [ ] Create src/constants/cframeRotations.luau - rotation matrix constants, identity matrix, utility functions, documentation
- [ ] Fix src/constants/attributeTypes.luau - add documentation, verify type IDs (lines 36-62), validation, remove redundancy, authoritative sources
- [ ] Fix src/constants/propertyTypes.luau - add missing type mappings (lines 21-72), fix XML names, default value validation (lines 75-85), simplify checking
- [ ] Fix src/constants/init.luau - remove cframeRotations reference until created, reorganize (lines 8-11), validation, error handling
- [ ] Create src/utilities/bit.luau - bit manipulation, bitBuffer integration, binary data processing, documentation
- [ ] Create src/utilities/string.luau - validation functions, format utilities, escaping, encoding, documentation
- [ ] Delete src/utilities/executor.luau.backup - remove unnecessary backup file
- [ ] Create tests/mid/xml_generation.luau - comprehensive XML tests, serialization accuracy, performance tests, compare against Studio files
- [ ] Create pipeline/.pcmp.json - 4 build types, optimization levels, deployment settings, test execution config
- [ ] Fix pipeline/frame.luau - metadata injection, variable replacement, validation, error handling, documentation