--[[
	UniversalSynSaveInstance (USSI) - Type Definitions
	
	Comprehensive type system for Roblox save instance operations.
	Provides type safety and clear interfaces for save functionality.
	
	@author Aspecter
	@version 1.0.0
	@since 2025-10-19
]]

-- ============================================================================
-- FOUNDATION TYPES
-- ============================================================================

--- Save operation modes
--- @alias SaveMode "full" | "optimized" | "scripts"
export type SaveMode = "full" | "optimized" | "scripts"

--- Supported file formats for save operations
--- @alias FileFormat "rbxl" | "rbxlx" | "rbxm" | "rbxmx"
export type FileFormat = "rbxl" | "rbxlx" | "rbxm" | "rbxmx"

--- Error information structure for save operation failures
--- @class Error
export type Error = {
	--- Error code identifier
	code: string,
	--- Human-readable error message
	message: string,
	--- Additional error details
	details: any?,
}

--- Result of a save instance operation
--- @class Result
export type Result = {
	--- Whether the operation succeeded
	success: boolean,
	--- Path to the saved file (if applicable)
	filePath: string?,
	--- Serialized data (if using callback)
	data: string?,
	--- Error message (if failed)
	error: string?,
	--- Operation statistics
	stats: Stats?,
}

--- Statistics collected during save instance operation
--- @class Stats
export type Stats = {
	--- Number of instances processed
	instancesProcessed: number,
	--- Number of scripts decompiled
	scriptsDecompiled: number,
	--- Time elapsed in seconds
	timeElapsed: number,
	--- Output file size in bytes
	fileSize: number,
	--- Save mode used
	mode: SaveMode,
}

--- Executor environment information
--- @class ExecutorInfo
export type ExecutorInfo = {
	--- Executor name
	name: string,
	--- Executor version
	version: string?,
	--- Whether executor was successfully detected
	detected: boolean,
}


-- ============================================================================
-- CONFIGURATION OPTIONS
-- ============================================================================

--- Complete configuration options for save instance operations
--- @class Options
export type Options = {
	-- Debug and Status
	--- Enable debug logging to console
	debugMode: boolean?,
	--- Show progress messages during save
	showStatus: boolean?,
	
	-- Safety and Execution
	--- Kick player before saving to prevent detection
	safeMode: boolean?,
	--- Close game when save operation completes
	shutdownWhenDone: boolean?,
	--- Prevent 20-minute idle kick during save
	antiIdle: boolean?,
	
	-- Save Modes
	--- Save mode: full, optimized, or scripts only
	mode: SaveMode?,
	--- Skip script decompilation entirely
	noScripts: boolean?,
	--- Cache and reuse previously decompiled scripts
	scriptCache: boolean?,
	--- Maximum decompilation timeout in seconds
	timeout: number?,
	--- Use cached decompiled code without recompiling
	decompileJobless: boolean?,
	--- Include script bytecode in output
	saveBytecode: boolean?,
	
	-- File Output
	--- Output filename without extension
	filePath: string?,
	--- Callback function to receive data instead of saving to file
	callback: ((data: string) -> ())?,
	--- Use binary format (rbxl/rbxm) instead of XML
	binary: boolean?,
	
	-- Instance Handling
	--- Save specific instance only (creates model file)
	object: Instance?,
	--- Force model format (.rbxm/.rbxmx) when object is specified
	isModel: boolean?,
	--- Include unparented instances in save
	nilInstances: boolean?,
	--- Additional instances to include in save
	extraInstances: {Instance}?,
	
	-- Property Filtering
	--- List of property names to ignore during save
	ignoreProperties: {string}?,
	--- Skip properties with default values
	ignoreDefaultProperties: boolean?,
	--- Include instances marked as non-archivable
	ignoreNotArchivable: boolean?,
	--- Skip non-script properties when in scripts mode
	ignoreNonScriptProperties: boolean?,
	--- Skip gethiddenproperty calls (fallback to defaults)
	ignoreSpecialProperties: boolean?,
	
	-- Player Isolation
	--- Save LocalPlayer children in separate folder
	isolateLocalPlayer: boolean?,
	--- Save StarterPlayer in separate folder
	isolateStarterPlayer: boolean?,
	--- Save LocalPlayer.Character in separate folder
	isolateLocalPlayerCharacter: boolean?,
	--- Skip all player characters during save
	removePlayerCharacters: boolean?,
	--- Save non-serializable instances as Folder objects
	saveNotCreatable: boolean?,
	
	-- Advanced Options
	--- RISKY: Overwrite shared strings for smaller file size
	sharedStringOverwrite: boolean?,
	--- Cache save frequency (lower = more frequent saves)
	saveCacheInterval: number?,
	--- Scripts to skip during decompilation
	decompileIgnore: {[string]: any}?,
	--- Skip default player scripts (StarterPlayer, StarterGui, etc.)
	ignoreDefaultPlayerScripts: boolean?,
}

return {}
