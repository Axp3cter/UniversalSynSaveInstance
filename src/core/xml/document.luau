--[[
	XML Document - Complete document generation

	Creates complete .rbxlx (place) and .rbxmx (model) files with proper structure,
	including roblox root element, shared strings, metadata, and instance hierarchy.

	@author Aspecter
	@version 2.0.0
	@since 2025-01-20
]]

local Hierarchy = require ("@core/hierarchy")
local Promise = require ("@packages/promise")
local Referent = require ("@core/referent")
local Scripts = require ("@core/scripts")
local SharedStrings = require ("@core/sharedStrings")
local Statistics = require ("@utilities/statistics")
local Traversal = require ("@core/traversal")
local Types = require ("@types")
local XMLInstance = require ("@core/xml/instance")

export type Options = {
	mode: Types.SaveMode,
	object: Instance?,
	isModel: boolean,
	nilInstances: boolean,
	extraInstances: { Instance }?,
	ignoreNotArchivable: boolean,
	removePlayerCharacters: boolean,
	ignoreProperties: { string }?,
	ignoreDefaultProperties: boolean,
	ignoreSpecialProperties: boolean,
	ignoreNonScriptProperties: boolean?,
	saveNotCreatable: boolean?,
	ignoreDefaultPlayerScripts: boolean?,
	isolateLocalPlayer: boolean?,
	isolateStarterPlayer: boolean?,
	isolateLocalPlayerCharacter: boolean?,
}

export type DocumentStructure = {
	header: string,
	sharedStrings: string,
	metadata: string?,
	instances: string,
	footer: string,
}

-- XML declaration and root element version
local XML_HEADER =
	`<?xml version="1.0" encoding="utf-8"?>\n<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">`
local XML_FOOTER = "</roblox>"

--[=[
	Generates shared strings section

	Creates the SharedStrings section containing all deduplicated binary strings
	used in the document. Returns empty string if no shared strings exist.

	@return string -- SharedStrings XML section
]=]
local function generateSharedStrings (): string
	local strings = SharedStrings.getAll ()
	local count = SharedStrings.count ()

	if count == 0 then return "" end

	local parts = { "\t<SharedStrings>" }

	for content, id in strings do
		table.insert (parts, `\t\t<SharedString md5="{id}">{content}</SharedString>`)
	end

	table.insert (parts, "\t</SharedStrings>")
	return table.concat (parts, "\n")
end

--[=[
	Generates metadata section for models

	Creates the Meta section with ExternalSourceURL and ExternalSourceName
	fields. Only used in .rbxmx (model) files.

	@param name string? -- Model name (optional)
	@return string -- Meta XML section
]=]
local function generateMetadata (name: string?): string
	local parts = { '\t<Meta name="ExternalSourceUrl">[ExternalSourceUrl]</Meta>' }

	if name then table.insert (parts, `\t<Meta name="ExternalSourceName">{name}</Meta>`) end

	return table.concat (parts, "\n")
end

-- Instance hierarchy tracking for proper nesting
type InstanceNode = {
	serialized: XMLInstance.SerializedInstance,
	children: { InstanceNode },
	indent: number,
}

-- Builds instance tree structure
local function buildTree (instances: { Instance }, opts: Options): { InstanceNode }
	local serializeOpts = {
		mode = opts.mode,
		ignoreProperties = opts.ignoreProperties,
		ignoreDefaultProperties = opts.ignoreDefaultProperties,
		ignoreSpecialProperties = opts.ignoreSpecialProperties,
		ignoreNonScriptProperties = opts.ignoreNonScriptProperties,
		saveNotCreatable = opts.saveNotCreatable,
	}

	local hierarchyRoots = Hierarchy.build (instances)
	local roots: { InstanceNode } = {}

	local function convert (node): InstanceNode
		local serialized = XMLInstance.serialize (node.instance, serializeOpts)
		local convertedChildren: { InstanceNode } = {}

		for _, child in node.children do
			table.insert (convertedChildren, convert (child))
		end

		return {
			serialized = serialized,
			children = convertedChildren,
			indent = 1,
		}
	end

	for _, node in hierarchyRoots do
		table.insert (roots, convert (node))
	end

	return roots
end

-- Updates indent levels recursively
local function updateIndents (node: InstanceNode, level: number): ()
	node.indent = level

	for _, child in node.children do
		updateIndents (child, level + 1)
	end
end

-- Serializes instance tree to XML
local function serializeTree (node: InstanceNode): string
	local parts = {}
	local indent = node.indent

	-- Opening tag and properties
	table.insert (parts, XMLInstance.toXML (node.serialized, indent))

	-- Serialize children recursively
	for _, child in node.children do
		table.insert (parts, serializeTree (child))
	end

	-- Closing tag
	table.insert (parts, XMLInstance.closeTag (indent))

	return table.concat (parts, "\n")
end

--[=[
	Generates instances section

	Creates the complete instance hierarchy with proper nesting and indentation.
	Instances are organized based on Parent-child relationships.

	@param instances {Instance} -- All instances to serialize
	@param opts Options -- Serialization options
	@return string -- Instances XML section
]=]
local function generateInstances (instances: { Instance }, opts: Options): string
	if #instances == 0 then return "" end

	-- Build tree structure
	local roots = buildTree (instances, opts)

	-- Update indent levels starting from 1
	for _, root in roots do
		updateIndents (root, 1)
	end

	-- Serialize each root tree
	local parts = {}
	for _, root in roots do
		table.insert (parts, serializeTree (root))
	end

	return table.concat (parts, "\n")
end

--[=[
	Generates complete XML document

	Creates a complete .rbxlx or .rbxmx file with all sections:
	- XML header with roblox root element
	- SharedStrings (if any)
	- Meta (for models only)
	- Instance hierarchy
	- Closing tags

	@param opts Options -- Document generation options
	@return Promise<Types.Result> -- Generated XML content or error
]=]
local function generate (opts: Options): Promise.TypedPromise<Types.Result>
	return Promise.defer (function (resolve)
		local generationStart = os.clock ()

		-- Clear shared state
		SharedStrings.clear ()
		Referent.clear ()
		Statistics.reset ()

		-- Traverse and collect instances
		local traversalOpts = {
			mode = opts.mode,
			object = opts.object,
			nilInstances = opts.nilInstances,
			extraInstances = opts.extraInstances,
			ignoreNotArchivable = opts.ignoreNotArchivable,
			removePlayerCharacters = opts.removePlayerCharacters,
			ignoreDefaultPlayerScripts = opts.ignoreDefaultPlayerScripts,
			isolateLocalPlayer = opts.isolateLocalPlayer,
			isolateStarterPlayer = opts.isolateStarterPlayer,
			isolateLocalPlayerCharacter = opts.isolateLocalPlayerCharacter,
		}

		local instances = Traversal.traverse (traversalOpts)

		if #instances == 0 then
			return resolve ({
				success = false,
				error = "No instances to serialize",
			} :: Types.Result)
		end

		-- Build document sections
		local structure: DocumentStructure = {
			header = XML_HEADER,
			sharedStrings = generateSharedStrings (),
			metadata = if opts.isModel then generateMetadata (opts.object and opts.object.Name or nil) else nil,
			instances = generateInstances (instances, opts),
			footer = XML_FOOTER,
		}

		-- Combine sections
		local parts = { structure.header }

		if #structure.sharedStrings > 0 then table.insert (parts, structure.sharedStrings) end

		if structure.metadata then table.insert (parts, structure.metadata) end

		table.insert (parts, structure.instances)
		table.insert (parts, structure.footer)

		local xml = table.concat (parts, "\n")

		-- Get final statistics
		local stats = Statistics.get ()
		stats.instancesProcessed = #instances
		stats.sharedStringsCount = SharedStrings.count ()
		stats.fileSize = #xml
		stats.timeElapsed = os.clock () - generationStart

		-- Track memory if gcinfo is available
		local ok, memKB = pcall (function () return gcinfo () end)
		if ok and memKB then stats.memoryUsed = math.floor (memKB * 1024) end

		resolve ({
			success = true,
			data = xml,
			stats = stats,
		} :: Types.SaveResult)
	end)
end

return {
	generate = generate,
}
