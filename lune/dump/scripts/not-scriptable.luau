--!strict

--[=[
	@class NotScriptable

	Analyzes NotScriptable properties and proxy patterns.

	Identifies properties hidden from scripts but serializable, properties
	with serialization-related names (xml, internal, serial, replica),
	and proxy properties where scriptable enum properties mirror
	NotScriptable ones for backward compatibility.
]=]

local Process = require("@lune/process")
local Lib = require("../lib")

type NotScriptableProperty = {
	type: "notScriptable",
	class: string,
	property: string,
	valueType: string,
	descriptor: string?,
}

type SerializationProperty = {
	type: "serializationNamed",
	class: string,
	property: string,
	scriptable: boolean,
	serializable: boolean,
}

type ProxyProperty = {
	type: "proxy",
	class: string,
	real: string,
	proxy: string,
	enumType: string,
}

type Property = NotScriptableProperty | SerializationProperty | ProxyProperty

local NotScriptable = {}

local PATTERNS = { "xml", "internal", "serial", "replica" }

local function hasPattern(name: string): boolean
	local lower = string.lower(name)
	for _, pattern in PATTERNS do
		if string.find(lower, pattern) then
			return true
		end
	end
	return false
end

--[=[
	Analyzes NotScriptable and serialization-named properties.

	@param hash string? -- Optional version hash (latest if nil)
]=]
function NotScriptable.run(hash: string?)
	local api = Lib.fetch(hash)
	local results = {}
	local notScriptableCount = 0
	local serializationNamedCount = 0

	for _, class in api.Classes do
		local enumTracker = {}

		for _, member in class.Members do
			if member.MemberType == "Property" and member.ValueType and member.Serialization then
				local tags = Lib.tags(member.Tags)
				local vt = member.ValueType
				local ser = member.Serialization

				if tags.NotScriptable and ser.CanLoad and ser.CanSave then
					notScriptableCount += 1

					if vt.Category == "Enum" then
						enumTracker[vt.Name] = member.Name
					end

					table.insert(results, {
						type = "notScriptable",
						class = class.Name,
						property = member.Name,
						valueType = vt.Name,
						descriptor = tags.PreferredDescriptorName,
					})
				end

				if hasPattern(member.Name) then
					serializationNamedCount += 1
					table.insert(results, {
						type = "serializationNamed",
						class = class.Name,
						property = member.Name,
						scriptable = not tags.NotScriptable,
						serializable = ser.CanLoad and ser.CanSave,
					})
				end
			end
		end

		for enumType, realName in enumTracker do
			for _, member in class.Members do
				if member.MemberType == "Property" and member.ValueType and member.Serialization and member.Name ~= realName then
					local vt = member.ValueType

					if vt.Category == "Enum" and vt.Name == enumType then
						local tags = Lib.tags(member.Tags)
						local ser = member.Serialization

						if not tags.NotScriptable and ser.CanLoad and ser.CanSave then
							table.insert(results, {
								type = "proxy",
								class = class.Name,
								real = realName,
								proxy = member.Name,
								enumType = enumType,
							})
						end
					end
				end
			end
		end
	end

	local proxyCount = #results - notScriptableCount - serializationNamedCount

	table.sort(results, function(a, b)
		if a.class == b.class then
			local aProp = if a.type == "proxy" then a.real else a.property
			local bProp = if b.type == "proxy" then b.real else b.property
			return aProp < bProp
		end
		return a.class < b.class
	end)

	local breakdown = {
		notScriptable = notScriptableCount,
		serializationNamed = serializationNamedCount,
		proxy = proxyCount,
	}

	Lib.json("not-scriptable", Lib.output(hash, results, breakdown))
	Lib.success(#results, "items", `{notScriptableCount} NotScriptable, {proxyCount} proxies, {serializationNamedCount} serialization-named`)
end

Lib.runCli(NotScriptable.run, Process.args)
