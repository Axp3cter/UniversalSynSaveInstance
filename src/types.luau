--[[
	UniversalSynSaveInstance (USSI) - Type Definitions

	Centralized type system for all modules.
	All types are namespaced to prevent conflicts.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-21
]]

-- ============================================================================
-- CORE TYPES
-- ============================================================================

--- Save operation modes
export type SaveMode = "full" | "optimized" | "scripts"

--- Supported file formats for save operations
export type FileFormat = "rbxl" | "rbxlx" | "rbxm" | "rbxmx"

--- Generic result type for operations (replaces Promise pattern)
export type Result<T> = {
	success: boolean,
	data: T?,
	error: string?,
}

-- ============================================================================
-- EXECUTOR TYPES
-- ============================================================================

--- Executor environment information
export type ExecutorInfo = {
	name: string,
	version: string?,
	detected: boolean,
}

-- ============================================================================
-- LOGGER TYPES
-- ============================================================================

--- Log severity levels
export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

--- Log entry structure
export type LogEntry = {
	level: LogLevel,
	message: string,
	timestamp: number,
}

-- ============================================================================
-- STATISTICS TYPES
-- ============================================================================

--- Performance and operation metrics
export type Stats = {
	instancesProcessed: number,
	scriptsDecompiled: number,
	propertiesRead: number,
	sharedStringsCount: number,
	timeElapsed: number,
	memoryUsed: number?,
	fileSize: number?,
}

-- ============================================================================
-- PROPERTY TYPES
-- ============================================================================

--- Property value with metadata
export type PropertyValue = {
	name: string,
	value: any,
	valueType: string,
}

--- Options for property reading
export type PropertyOptions = {
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean,
	ignoreSpecialProperties: boolean,
	ignoreNonScriptProperties: boolean?,
	mode: SaveMode,
}

-- ============================================================================
-- SCRIPT TYPES
-- ============================================================================

--- Script decompilation data
export type ScriptData = {
	source: string?,
	bytecode: string?,
	hash: string?,
	cached: boolean,
	decompiled: boolean,
}

--- Options for script processing
export type ScriptOptions = {
	mode: SaveMode,
	noScripts: boolean,
	scriptCache: boolean,
	timeout: number?,
	saveBytecode: boolean,
	decompileIgnore: { [string]: any }?,
	decompileJobless: boolean?,
}

-- ============================================================================
-- INSTANCE TYPES
-- ============================================================================

--- Serialized instance data
export type SerializedInstance = {
	className: string,
	properties: { PropertyValue },
}

--- Options for instance serialization
export type InstanceOptions = {
	mode: SaveMode,
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean,
	ignoreSpecialProperties: boolean,
	ignoreNonScriptProperties: boolean?,
	saveNotCreatable: boolean?,
}

-- ============================================================================
-- TRAVERSAL TYPES
-- ============================================================================

--- Options for instance tree traversal
export type TraversalOptions = {
	mode: SaveMode,
	object: Instance?,
	nilInstances: boolean,
	extraInstances: { Instance }?,
	ignoreNotArchivable: boolean,
	removePlayerCharacters: boolean,
	ignoreDefaultPlayerScripts: boolean?,
	isolateLocalPlayer: boolean?,
	isolateStarterPlayer: boolean?,
	isolateLocalPlayerCharacter: boolean?,
}

-- ============================================================================
-- TAG TYPES
-- ============================================================================

--- Options for tag serialization
export type TagOptions = {
	mode: SaveMode,
}

-- ============================================================================
-- REFERENCE TYPES
-- ============================================================================

--- Referent ID mapping
export type ReferentMap = { [Instance]: number }

--- Shared string mapping
export type SharedStringMap = { [string]: string }

-- ============================================================================
-- MAIN OPTIONS TYPE
-- ============================================================================

--- Complete configuration for save instance operations
export type Options = {
	-- Debug and Status
	debugMode: boolean?,
	showStatus: boolean?,

	-- Safety and Execution
	safeMode: boolean?,
	shutdownWhenDone: boolean?,
	antiIdle: boolean?,

	-- Save Modes
	mode: SaveMode?,
	noScripts: boolean?,
	scriptCache: boolean?,
	timeout: number?,
	decompileJobless: boolean?,
	saveBytecode: boolean?,

	-- File Output
	filePath: string?,
	callback: ((data: string) -> ())?,
	binary: boolean?,

	-- Instance Handling
	object: Instance?,
	isModel: boolean?,
	nilInstances: boolean?,
	extraInstances: { Instance }?,

	-- Property Filtering
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean?,
	ignoreNotArchivable: boolean?,
	ignoreNonScriptProperties: boolean?,
	ignoreSpecialProperties: boolean?,

	-- Player Isolation
	isolateLocalPlayer: boolean?,
	isolateStarterPlayer: boolean?,
	isolateLocalPlayerCharacter: boolean?,
	removePlayerCharacters: boolean?,
	saveNotCreatable: boolean?,

	-- Advanced Options
	sharedStringOverwrite: boolean?,
	saveCacheInterval: number?,
	decompileIgnore: { [string]: any }?,
	ignoreDefaultPlayerScripts: boolean?,
}

--- Result of a save instance operation
export type SaveResult = {
	success: boolean,
	filePath: string?,
	data: string?,
	error: string?,
	stats: Stats?,
}

return {}
