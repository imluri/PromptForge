-- PromptForge | Fluent LLM request builder for Luau
-- https://github.com/imluri/PromptForge

local PromptForge = {}

local Providers = require(script.Providers)
local Tool      = require(script.Tool)
local Http      = require(script.Http)

local HS = game:GetService("HttpService")

-- Expose sub-builders
PromptForge.tool = Tool.new
PromptForge.ENV  = Http.ENV

-- Allow plugging in a custom HTTP adapter:
--   PromptForge.setAdapter(fn)  where fn(options) → { StatusCode, Body }
function PromptForge.setAdapter(fn)
	assert(type(fn) == "function", "[PromptForge] adapter must be a function")
	Http.adapter = fn
end

function PromptForge.new()
	local Request = {
		_provider    = "OpenRouter",
		_apiKey      = "",
		_customUrl   = nil,
		_model       = "",
		_messages    = {},
		_tools       = {},
		_temperature = nil,
		_maxTokens   = nil,
		_topP        = nil,
		_stream      = false,
		_extra       = {},
	}

	-- ── Provider / auth ──────────────────────────────────────────────

	function Request:provider(name: string, apiKey: string?, customUrl: string?)
		assert(type(name) == "string" and name ~= "", "[PromptForge] provider name required")
		self._provider  = name
		self._apiKey    = apiKey or ""
		self._customUrl = customUrl
		return self
	end

	function Request:apiKey(key: string)
		self._apiKey = key
		return self
	end

	function Request:url(customUrl: string)
		self._customUrl = customUrl
		return self
	end

	-- ── Model ────────────────────────────────────────────────────────

	function Request:model(name: string)
		assert(type(name) == "string" and name ~= "", "[PromptForge] model name required")
		self._model = name
		return self
	end

	-- ── Messages ─────────────────────────────────────────────────────

	function Request:system(content: string)
		table.insert(self._messages, { role = "system", content = content })
		return self
	end

	function Request:user(content: string)
		table.insert(self._messages, { role = "user", content = content })
		return self
	end

	function Request:assistant(content: string)
		table.insert(self._messages, { role = "assistant", content = content })
		return self
	end

	-- Insert a pre-built message table directly
	function Request:message(msg: {})
		assert(type(msg) == "table" and msg.role, "[PromptForge] message must have a role field")
		table.insert(self._messages, msg)
		return self
	end

	-- Replace all messages at once
	function Request:messages(list: {})
		assert(type(list) == "table", "[PromptForge] messages must be a table")
		self._messages = list
		return self
	end

	-- ── Tools ────────────────────────────────────────────────────────

	-- Accept a built tool table or a Tool builder (calls :build() automatically)
	function Request:tool(toolDef: {})
		if type(toolDef.build) == "function" then
			toolDef = toolDef:build()
		end
		table.insert(self._tools, toolDef)
		return self
	end

	function Request:tools(list: {})
		for _, t in ipairs(list) do
			self:tool(t)
		end
		return self
	end

	-- ── Sampling params ──────────────────────────────────────────────

	function Request:temperature(t: number)
		assert(type(t) == "number", "[PromptForge] temperature must be a number")
		self._temperature = t
		return self
	end

	function Request:maxTokens(n: number)
		assert(type(n) == "number" and n > 0, "[PromptForge] maxTokens must be a positive number")
		self._maxTokens = n
		return self
	end

	function Request:topP(p: number)
		assert(type(p) == "number", "[PromptForge] topP must be a number")
		self._topP = p
		return self
	end

	-- Merge any extra top-level fields into the request body
	function Request:extra(fields: {})
		for k, v in pairs(fields) do
			self._extra[k] = v
		end
		return self
	end

	-- ── Build payload ────────────────────────────────────────────────

	function Request:_buildBody(): string
		assert(self._model ~= "", "[PromptForge] model is required — call :model()")
		assert(#self._messages > 0, "[PromptForge] at least one message is required")

		local body = {
			model    = self._model,
			messages = self._messages,
		}

		if self._temperature ~= nil then body.temperature  = self._temperature  end
		if self._maxTokens   ~= nil then body.max_tokens   = self._maxTokens    end
		if self._topP        ~= nil then body.top_p        = self._topP         end
		if #self._tools > 0         then body.tools        = self._tools        end
		if self._stream             then body.stream       = true               end

		for k, v in pairs(self._extra) do
			body[k] = v
		end

		local ok, json = pcall(HS.JSONEncode, HS, body)
		assert(ok, "[PromptForge] Failed to encode request body: " .. tostring(json))
		return json
	end

	-- ── Send ─────────────────────────────────────────────────────────

	function Request:send(): {}
		local url     = Providers.endpoint(self._provider, self._customUrl)
		local headers = Providers.headers(self._provider, self._apiKey)
		local body    = self:_buildBody()

		local status, responseBody = Http.send(url, headers, body)

		local result = {
			ok         = status == 200,
			status     = status,
			raw        = responseBody,
			message    = nil,
			content    = nil,
			toolCalls  = nil,
			usage      = nil,
			error      = nil,
		}

		if responseBody == "" then
			result.error = "Empty response (HTTP " .. status .. ")"
			return result
		end

		local decodeOk, data = pcall(HS.JSONDecode, HS, responseBody)
		if not decodeOk then
			result.error = "JSON decode failed: " .. tostring(data)
			return result
		end

		-- OpenAI-compatible shape
		local choice = data.choices and data.choices[1]
		if choice then
			local msg = choice.message
			result.message   = msg
			result.content   = msg and msg.content
			result.toolCalls = msg and msg.tool_calls
		end

		-- Ollama shape
		if data.message then
			result.message   = data.message
			result.content   = data.message.content
			result.toolCalls = data.message.tool_calls
		end

		result.usage = data.usage
		result.data  = data

		if not result.ok then
			local errMsg = data.error and (data.error.message or HS:JSONEncode(data.error)) or responseBody
			result.error = "HTTP " .. status .. ": " .. errMsg
		end

		return result
	end

	-- Convenience: clone this request so you can branch from a base config
	function Request:clone()
		local copy = PromptForge.new()
		copy._provider    = self._provider
		copy._apiKey      = self._apiKey
		copy._customUrl   = self._customUrl
		copy._model       = self._model
		copy._temperature = self._temperature
		copy._maxTokens   = self._maxTokens
		copy._topP        = self._topP
		copy._stream      = self._stream

		-- Deep-copy tables
		for _, m in ipairs(self._messages) do copy._messages[#copy._messages + 1] = m end
		for _, t in ipairs(self._tools)    do copy._tools[#copy._tools + 1] = t       end
		for k, v in pairs(self._extra)     do copy._extra[k] = v                      end

		return copy
	end

	return Request
end

return PromptForge
