--!strict
--[=[
	@class Http
	Shared HTTP utilities for lune scripts.

	Provides defensive HTTP operations with automatic retries, exponential backoff,
	and comprehensive error handling. All network operations are wrapped in pcall
	for safety.

	@dep @lune/net -- Network operations
	@dep @lune/task -- Delay operations for retry backoff
]=]

-- ===== Imports =====

local net = require("@lune/net")
local task = require("@lune/task")

-- ===== Module =====

local Http = {}

-- ===== Constants =====

-- Retry configuration with exponential backoff
local MAX_RETRY_ATTEMPTS: number = 3
local INITIAL_RETRY_DELAY_MS: number = 1000 -- 1 second
local RETRY_BACKOFF_MULTIPLIER: number = 2

-- HTTP status codes
local STATUS_OK: number = 200
local STATUS_CREATED: number = 201
local STATUS_NO_CONTENT: number = 204
local STATUS_BAD_REQUEST: number = 400
local STATUS_NOT_FOUND: number = 404
local STATUS_SERVER_ERROR: number = 500

-- ===== Type Definitions =====

--[=[
	@class HttpResponse
	Represents a successful HTTP response.

	@field ok boolean -- True if status code indicates success (2xx)
	@field statusCode number -- HTTP status code
	@field statusMessage string -- HTTP status message
	@field headers {[string]: string} -- Response headers
	@field body string -- Response body
]=]
export type HttpResponse = {
	ok: boolean,
	statusCode: number,
	statusMessage: string,
	headers: { [string]: string },
	body: string,
}

--[=[
	@class HttpRequest
	Configuration for an HTTP request.

	@field url string -- Target URL (must be valid HTTP/HTTPS)
	@field method string? -- HTTP method (default: "GET")
	@field headers {[string]: string}? -- Request headers
	@field body string? -- Request body
]=]
export type HttpRequest = {
	url: string,
	method: string?,
	headers: { [string]: string }?,
	body: string?,
}

--[=[
	@class HttpResult
	Result type for HTTP operations.

	Union type that represents either successful response or error.
]=]
export type HttpResult = {
	success: true,
	response: HttpResponse,
} | {
	success: false,
	error: string,
	statusCode: number?,
}

-- ===== Private Helpers =====

--[=[
	@private
	Validates that a URL is well-formed and uses HTTP(S) protocol.

	@param url string -- URL to validate
	@return boolean -- True if URL is valid
	@return string? -- Error message if invalid
]=]
local function validateUrl(url: string): (boolean, string?)
	if type(url) ~= "string" or #url == 0 then
		return false, "URL must be a non-empty string"
	end

	if not (url:match("^https?://") ~= nil) then
		return false, "URL must use http:// or https:// protocol"
	end

	return true, nil
end

--[=[
	@private
	Calculates delay for retry attempt using exponential backoff.

	@param attempt number -- Current attempt number (0-indexed)
	@return number -- Delay in milliseconds
]=]
local function calculateRetryDelay(attempt: number): number
	return INITIAL_RETRY_DELAY_MS * (RETRY_BACKOFF_MULTIPLIER ^ attempt)
end

--[=[
	@private
	Determines if an HTTP status code indicates a retryable error.

	Server errors (5xx) are retryable, client errors (4xx) are not.

	@param statusCode number -- HTTP status code
	@return boolean -- True if error is retryable
]=]
local function isRetryableError(statusCode: number): boolean
	return statusCode >= STATUS_SERVER_ERROR
end

-- ===== Public API =====

--[=[
	Performs an HTTP request with automatic retries and exponential backoff.

	Retries only on server errors (5xx) or network failures. Client errors (4xx)
	are returned immediately. Uses exponential backoff between retry attempts.

	@param request HttpRequest -- Request configuration
	@return HttpResult -- Result containing response or error

	@error Never throws - all errors are captured in result type
]=]
function Http.request(request: HttpRequest): HttpResult
	local isValid: boolean
	local validationError: string?

	-- Validate URL before attempting request
	isValid, validationError = validateUrl(request.url)
	if not isValid then
		return {
			success = false,
			error = validationError or "Invalid URL",
			statusCode = nil,
		}
	end

	local lastError: string = "Unknown error"
	local lastStatusCode: number? = nil

	-- Attempt request with retries
	for attempt = 0, MAX_RETRY_ATTEMPTS - 1 do
		local requestSuccess: boolean
		local response: any

		requestSuccess, response = pcall(net.request, {
			url = request.url,
			method = request.method or "GET",
			headers = request.headers,
			body = request.body,
		})

		if requestSuccess then
			-- Request succeeded - check status code
			if response.ok then
				return {
					success = true,
					response = response,
				}
			end

			-- Non-2xx status code
			lastStatusCode = response.statusCode
			lastError = `HTTP {response.statusCode}: {response.statusMessage}`

			-- Don't retry client errors (4xx)
			if not isRetryableError(response.statusCode) then
				return {
					success = false,
					error = lastError,
					statusCode = lastStatusCode,
				}
			end
		else
			-- Network error occurred
			lastError = `Network error: {response}`
		end

		-- Retry with exponential backoff (except on last attempt)
		if attempt < MAX_RETRY_ATTEMPTS - 1 then
			local delayMs: number = calculateRetryDelay(attempt)
			task.wait(delayMs / 1000)
		end
	end

	-- All retries exhausted
	return {
		success = false,
		error = `Failed after {MAX_RETRY_ATTEMPTS} attempts: {lastError}`,
		statusCode = lastStatusCode,
	}
end

--[=[
	Performs a GET request.

	Convenience wrapper around Http.request for GET operations.

	@param url string -- Target URL
	@param headers {[string]: string}? -- Optional request headers
	@return HttpResult -- Result containing response or error
]=]
function Http.get(url: string, headers: { [string]: string }?): HttpResult
	return Http.request({
		url = url,
		method = "GET",
		headers = headers,
	})
end

--[=[
	Performs a POST request.

	Convenience wrapper around Http.request for POST operations.

	@param url string -- Target URL
	@param body string -- Request body
	@param headers {[string]: string}? -- Optional request headers
	@return HttpResult -- Result containing response or error
]=]
function Http.post(url: string, body: string, headers: { [string]: string }?): HttpResult
	return Http.request({
		url = url,
		method = "POST",
		body = body,
		headers = headers,
	})
end

return Http
