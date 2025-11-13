--!strict

local Process = require("@lune/process")
local Lib = require("../lib")

type AsymmetricProperty = {
	type: "asymmetric",
	class: string,
	property: string,
	reason: string,
	canSave: boolean?,
	canLoad: boolean?,
	deprecated: boolean?,
}

type NotCreatableDefault = {
	type: "notCreatableDefault",
	class: string,
	property: string,
	default: string,
}

type Property = AsymmetricProperty | NotCreatableDefault

local InterestingPropertiesAnalyzer = {}

local function isPlaceholder(value: string?): boolean
	if not value then
		return true
	end
	return string.find(value, "__api_dump_", 1, true) ~= nil
end

function InterestingPropertiesAnalyzer.run(hash: string?)
	local api = Lib.fetch(hash)
	local classProps = {}
	local results = {}

	for _, class in api.Classes do
		local classTags = Lib.tags(class.Tags)
		classProps[class.Name] = { tags = classTags, props = {} }

		for _, member in class.Members do
			if member.MemberType == "Property" and member.Serialization then
				local tags = Lib.tags(member.Tags)
				local ser = member.Serialization

				classProps[class.Name].props[member.Name] = {
					default = member.Default,
					tags = tags,
				}

				if ser.CanLoad or ser.CanSave then
					local reason = nil
					if ser.CanLoad and not ser.CanSave then
						reason = "CanLoad only"
					elseif ser.CanSave and not ser.CanLoad then
						reason = "CanSave only"
					elseif tags.Deprecated and ser.CanSave then
						reason = "Deprecated but saveable"
					end

					if reason then
						table.insert(results, {
							type = "asymmetric",
							class = class.Name,
							property = member.Name,
							reason = reason,
							canSave = ser.CanSave,
							canLoad = ser.CanLoad,
							deprecated = if tags.Deprecated then true else nil,
						})
					end
				end
			end
		end
	end

	local asymmetricCount = #results

	for className, data in classProps do
		if data.tags.NotCreatable then
			for propName, propData in data.props do
				if not isPlaceholder(propData.default) then
					table.insert(results, {
						type = "notCreatableDefault",
						class = className,
						property = propName,
						default = propData.default,
					})
				end
			end
		end
	end

	table.sort(results, function(a, b)
		if a.class == b.class then
			return a.property < b.property
		end
		return a.class < b.class
	end)

	local breakdown = {
		asymmetric = asymmetricCount,
		notCreatableDefault = #results - asymmetricCount,
	}

	Lib.json("interesting-properties", Lib.output(hash, results, breakdown))
	Lib.success(#results, "interesting properties", `{breakdown.asymmetric} asymmetric, {breakdown.notCreatableDefault} NotCreatable defaults`)
end

Lib.runCli(InterestingPropertiesAnalyzer.run, Process.args)
