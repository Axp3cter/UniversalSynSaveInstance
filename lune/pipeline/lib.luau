--!strict
--[=[
	@class Lib
	Pipeline library - consolidated utilities for build system.

	Provides filesystem operations, logging, configuration management,
	GitHub API integration, and template composition utilities.
]=]

-- Imports
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local DateTime = require("@lune/datetime")
local net = require("@lune/net")
local task = require("@lune/task")
local Process = require("@lune/process")
local Logging = require("../shared/logging")
local SharedFs = require("../shared/fs")

-- Module
local Lib = {}

--[=[
	@within Lib
	@class Logger
	Colored logging utilities for the build pipeline.

	Re-exports the shared Logging module with additional pipeline-specific functions.
]=]
local Logger = {}
Lib.Logger = Logger

-- Re-export shared logging functions
Logger.setVerbose = Logging.setVerbose
Logger.info = Logging.info
Logger.success = Logging.success
Logger.warn = Logging.warn
Logger.error = Logging.error
Logger.fatal = Logging.fatal
Logger.section = Logging.section
Logger.progress = Logging.progress
Logger.verbose = Logging.verbose
Logger.detail = Logging.detail
Logger.detailLast = Logging.detailLast
Logger.formatDuration = Logging.formatDuration
Logger.formatSize = Logging.formatSize

--[=[
	@within Lib
	@class Fs
	Filesystem operations for the build pipeline.

	Re-exports the shared Fs module for filesystem operations.
]=]
local Fs = SharedFs
Lib.Fs = Fs

--[=[
	@within Lib
	@class Config
	Configuration loader and validator for the build pipeline.
]=]
local Config = {}
Lib.Config = Config

export type DarkluaStage = {
	name: string,
	config: string,
	env: { [string]: string }?,
	optional: boolean?,
}

export type DarkluaConfig = {
	enabled: boolean?,
	stages: { DarkluaStage }?,
}

export type WaxConfig = {
	enabled: boolean?,
	input: string,
	output: string,
	minify: boolean?,
	envName: string?,
	darklua: { config: string? }?,
}

export type TemplateConfig = {
	enabled: boolean?,
	source: string,
	markers: { [string]: string }?,
}

export type PromptsConfig = {
	version: boolean?,
	deploy: boolean?,
}

export type GitHubConfig = {
	enabled: boolean?,
	owner: string,
	repo: string,
	apiKeyEnv: string?,
}

export type DeploymentConfig = {
	enabled: boolean?,
	prerelease: boolean?,
	github: GitHubConfig?,
}

export type StyluaConfig = {
	enabled: boolean?,
	configPath: string?,
}

export type BuildConfig = {
	name: string,
	description: string?,
	type: "standard" | "wax"?,
	extends: string?,
	input: string,
	output: string,
	darklua: DarkluaConfig?,
	wax: WaxConfig?,
	template: TemplateConfig?,
	prompts: PromptsConfig?,
	deployment: DeploymentConfig?,
	stylua: StyluaConfig?,
}

export type OutputConfig = {
	directory: string?,
	openInEditor: boolean?,
	editor: string?,
}

export type ConfigFile = {
	verbose: boolean?,
	ciMode: boolean?,
	output: OutputConfig?,
	builds: { [string]: BuildConfig },
}

local function mergeBuilds(base: BuildConfig, override: BuildConfig): BuildConfig
	local merged: BuildConfig = table.clone(base) :: any

	for key: string, value: any in override :: any do
		if key ~= "extends" then
			merged[key] = value
		end
	end

	return merged
end

function Config.load(path: string): (ConfigFile?, string?)
	if not fs.isFile(path) then
		return nil, `Config not found: {path}`
	end

	local success: boolean, contents: string = pcall(fs.readFile, path)
	if not success then
		return nil, `Read failed: {contents}`
	end

	local parseSuccess: boolean, parsed: any = pcall(serde.decode, "json", contents)
	if not parseSuccess then
		return nil, `Parse failed: {parsed}`
	end

	local config: ConfigFile = parsed :: ConfigFile

	local valid: boolean, err: string? = Config.validate(config)
	if not valid then
		return nil, err
	end

	return Config.resolveInheritance(config), nil
end

function Config.validate(config: any): (boolean, string?)
	if type(config) ~= "table" then
		return false, "Config must be a table"
	end

	if not config.builds or type(config.builds) ~= "table" then
		return false, "Config must have 'builds' table"
	end

	local buildCount: number = 0

	for name: string, buildCfg: any in config.builds do
		buildCount += 1

		if type(buildCfg) ~= "table" then
			return false, `Build '{name}' must be a table`
		end

		if not buildCfg.extends then
			if not buildCfg.input or type(buildCfg.input) ~= "string" then
				return false, `Build '{name}' missing 'input' string`
			end

			if not buildCfg.output or type(buildCfg.output) ~= "string" then
				return false, `Build '{name}' missing 'output' string`
			end
		end
	end

	if buildCount == 0 then
		return false, "Config must have at least one build"
	end

	return true, nil
end

function Config.resolveInheritance(config: ConfigFile): ConfigFile
	local resolved: ConfigFile = table.clone(config)
	resolved.builds = {}

	for name: string, buildCfg: BuildConfig in config.builds do
		local finalBuild: BuildConfig

		if buildCfg.extends then
			local baseName: string = buildCfg.extends
			local baseConfig: BuildConfig? = config.builds[baseName]

			if not baseConfig then
				error(`Build '{name}' extends unknown config '{baseName}'`)
			end

			finalBuild = mergeBuilds(baseConfig, buildCfg)
		else
			finalBuild = table.clone(buildCfg)
		end

		finalBuild.name = name
		resolved.builds[name] = finalBuild
	end

	return resolved
end

function Config.selectBuildConfig(config: ConfigFile, buildName: string?, ciMode: boolean?): BuildConfig?
	local isCiMode: boolean = ciMode or config.ciMode or false

	if buildName then
		return config.builds[buildName]
	end

	if isCiMode then
		return nil
	end

	local buildNames: { string } = {}
	local buildDescriptions: { string } = {}

	for name: string, buildCfg: BuildConfig in config.builds do
		table.insert(buildNames, name)
		table.insert(buildDescriptions, if buildCfg.description then `{name} - {buildCfg.description}` else name)
	end

	local selectedIndex: number = stdio.prompt("select", "Select build:", buildDescriptions)
	return config.builds[buildNames[selectedIndex]]
end

function Config.getBuildType(buildCfg: BuildConfig): "standard" | "wax"
	if buildCfg.type then
		return buildCfg.type
	end

	if buildCfg.wax and buildCfg.wax.enabled then
		return "wax"
	end

	return "standard"
end

function Config.isDarkluaEnabled(buildCfg: BuildConfig): boolean
	if not buildCfg.darklua then
		return false
	end

	if buildCfg.darklua.enabled == false then
		return false
	end

	return true
end

function Config.isWaxEnabled(buildCfg: BuildConfig): boolean
	if Config.getBuildType(buildCfg) ~= "wax" then
		return false
	end

	if not buildCfg.wax then
		return false
	end

	if buildCfg.wax.enabled == false then
		return false
	end

	return true
end

function Config.isTemplateEnabled(buildCfg: BuildConfig): boolean
	if not buildCfg.template then
		return false
	end

	if buildCfg.template.enabled == false then
		return false
	end

	return true
end

function Config.isDeploymentEnabled(buildCfg: BuildConfig): boolean
	if not buildCfg.deployment then
		return false
	end

	if buildCfg.deployment.enabled == false then
		return false
	end

	return true
end

function Config.isStyluaEnabled(buildCfg: BuildConfig): boolean
	if not buildCfg.stylua then
		return false
	end

	if buildCfg.stylua.enabled == false then
		return false
	end

	return true
end

--[=[
	@within Lib
	@class Git
	GitHub API operations for releases and deployments.
]=]
local Git = {}
Lib.Git = Git

local MAX_RETRIES = 3
local RETRY_DELAY = 2.0

export type GitHubRelease = {
	id: number,
	tag_name: string,
	name: string,
	body: string,
	html_url: string,
	upload_url: string,
}

function Git.getApiKey(name: string?): string?
	local key = name or "GITHUB_API_KEY"

	if Process.env[key] then
		return Process.env[key]
	end

	if not fs.isFile(".env") then
		return
	end

	for line in fs.readFile(".env"):gmatch("[^\r\n]+") do
		local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
		if k == key and v then
			return v:gsub('^["\'](.-)["\'"]$', "%1")
		end
	end
end

local function retry(config: any, maxRetries: number?): (any?, string?)
	local left = maxRetries or MAX_RETRIES
	local delay = RETRY_DELAY

	while left >= 0 do
		local ok, res = pcall(net.request, config)

		if ok then
			if res.statusCode and res.statusCode >= 500 and left > 0 then
				task.wait(delay)
				delay *= 2
				left -= 1
				continue
			end
			return res
		elseif left > 0 then
			task.wait(delay)
			delay *= 2
			left -= 1
			continue
		else
			return nil, `Network error: {res}`
		end
	end

	return nil, "Max retries exceeded"
end

function Git.createRelease(
	owner: string,
	repo: string,
	apiKey: string,
	tag: string,
	name: string,
	body: string,
	prerelease: boolean?,
	draft: boolean?
): (GitHubRelease?, string?)
	local res, err = retry({
		url = `https://api.github.com/repos/{owner}/{repo}/releases`,
		method = "POST",
		headers = {
			["Authorization"] = `Bearer {apiKey}`,
			["Content-Type"] = "application/json",
			["User-Agent"] = "Pipeline",
		},
		body = serde.encode("json", {
			tag_name = tag,
			name = name,
			body = body,
			draft = draft or false,
			prerelease = prerelease or false,
		}),
	})

	if not res then
		return nil, err
	end

	if not res.ok then
		local msg = `HTTP {res.statusCode}`
		if res.body then
			local ok, parsed = pcall(serde.decode, "json", res.body)
			if ok and parsed.message then
				msg ..= `: {parsed.message}`
			end
		end
		return nil, msg
	end

	return serde.decode("json", res.body)
end

function Git.uploadAsset(
	owner: string,
	repo: string,
	apiKey: string,
	releaseId: number,
	path: string,
	name: string?
): (boolean, string?)
	if not fs.isFile(path) then
		return false, `Not found: {path}`
	end

	local fileName = name or path:match("^.+[\\/](.+)$") or path

	local res, err = retry({
		url = `https://uploads.github.com/repos/{owner}/{repo}/releases/{releaseId}/assets?name={fileName}`,
		method = "POST",
		headers = {
			["Authorization"] = `Bearer {apiKey}`,
			["Content-Type"] = "application/octet-stream",
			["User-Agent"] = "Pipeline",
		},
		body = fs.readFile(path),
	})

	if not res then
		return false, err
	end

	if not res.ok then
		local msg = `HTTP {res.statusCode}`
		if res.body then
			local ok, parsed = pcall(serde.decode, "json", res.body)
			if ok and parsed.message then
				msg ..= `: {parsed.message}`
			end
		end
		return false, msg
	end

	return true
end

function Git.validateApiKey(apiKey: string): (boolean, string?)
	local res, err = retry({
		url = "https://api.github.com/user",
		method = "GET",
		headers = {
			["Authorization"] = `Bearer {apiKey}`,
			["User-Agent"] = "Pipeline",
		},
	})

	if not res then
		return false, err
	end

	if not res.ok then
		return false, if res.statusCode == 401 then "Invalid key" else `HTTP {res.statusCode}`
	end

	return true
end

function Git.releaseExists(owner: string, repo: string, apiKey: string, tag: string): (boolean?, string?)
	local res, err = retry({
		url = `https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}`,
		method = "GET",
		headers = {
			["Authorization"] = `Bearer {apiKey}`,
			["User-Agent"] = "Pipeline",
		},
	})

	if not res then
		return nil, err
	end

	if res.statusCode == 404 then
		return false
	end

	if not res.ok then
		return nil, `HTTP {res.statusCode}`
	end

	return true
end

--[=[
	@within Lib
	@class Composer
	Template composition engine for the build pipeline.
]=]
local Composer = {}
Lib.Composer = Composer

export type MarkerValue = string | () -> string

export type Markers = {
	[string]: MarkerValue,
}

export type ComposeResult = {
	success: boolean,
	output: string?,
	error: string?,
	replacements: number,
}

local function escapePattern(str: string): string
	return str:gsub("([%%%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
end

local function resolveMarkerValue(value: MarkerValue): string
	if type(value) == "function" then
		return (value :: () -> string)()
	end
	return value :: string
end

function Composer.compose(template: string, markers: Markers): ComposeResult
	local output: string = template
	local replacementCount: number = 0

	for key: string, value: MarkerValue in markers do
		local markerPattern: string = `__COMPOSER.Insert(__COMPOSER.{key})`
		local escapedPattern: string = escapePattern(markerPattern)
		local count: number = 0

		for _ in output:gmatch(escapedPattern) do
			count += 1
		end

		if count > 0 then
			local success: boolean, result: string = pcall(function()
				local resolvedValue: string = resolveMarkerValue(value)
				return output:gsub(escapedPattern, function()
					return resolvedValue
				end)
			end)

			if not success then
				return {
					success = false,
					output = nil,
					error = `Marker '{key}' resolution failed: {result}`,
					replacements = replacementCount,
				}
			end

			output = result
			replacementCount += count
		end
	end

	return {
		success = true,
		output = output,
		error = nil,
		replacements = replacementCount,
	}
end

function Composer.composeFromFile(templatePath: string, markers: Markers): ComposeResult
	local template: string?, err: string? = Fs.read(templatePath)
	if not template then
		return {
			success = false,
			output = nil,
			error = `Template load failed: {err}`,
			replacements = 0,
		}
	end

	return Composer.compose(template, markers)
end

function Composer.extractMarkers(template: string): { string }
	local found: { string } = {}
	local seen: { [string]: boolean } = {}

	for markerKey in template:gmatch("__COMPOSER%.Insert%(__COMPOSER%.([%w_]+)%)") do
		if not seen[markerKey] then
			table.insert(found, markerKey)
			seen[markerKey] = true
		end
	end

	return found
end

function Composer.createDefaultMarkers(buildCode: string, version: string, configName: string): Markers
	return {
		build = buildCode,
		genDate = function()
			return string.format("%q", DateTime.now():toIsoDate())
		end,
		cfg = function()
			return string.format("%q", configName)
		end,
		vers = function()
			return string.format("%q", version)
		end,
	}
end

return Lib
