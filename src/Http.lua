-- Http.lua | HTTP adapter — executor, syn, and Studio bridge

local Http = {}

-- Detect environment
local _impl = (function()
	if typeof(syn) == "table" and syn.request then return "syn" end
	local r = rawget(_G, "request") or rawget(_G, "http_request")
		or (rawget(_G, "http") and rawget(_G, "http").request)
		or (rawget(_G, "fluxus") and rawget(_G, "fluxus").request)
	if r then return "executor", r end
	local RS = game:GetService("RunService")
	if RS:IsStudio() then return "studio" end
	return "unknown"
end)()

local _envName = type(_impl) == "string" and _impl or _impl
local _reqFn   = nil

if type(_impl) == "table" then
	-- executor path returns two values
	_envName, _reqFn = "executor", _impl
end

-- Re-detect cleanly
do
	local e = (function()
		if typeof(rawget(_G, "syn")) == "table" and rawget(_G, "syn").request then return "syn" end
		local fns = { "request", "http_request" }
		for _, fn in ipairs(fns) do
			if type(rawget(_G, fn)) == "function" then return "executor", rawget(_G, fn) end
		end
		if rawget(_G, "http") and type(rawget(_G, "http").request) == "function" then
			return "executor", rawget(_G, "http").request
		end
		if rawget(_G, "fluxus") and type(rawget(_G, "fluxus").request) == "function" then
			return "executor", rawget(_G, "fluxus").request
		end
		local ok, RS = pcall(game.GetService, game, "RunService")
		if ok and RS:IsStudio() then return "studio" end
		return "unknown"
	end)()
	if type(e) == "string" then
		_envName = e
	else
		_envName, _reqFn = e, select(2, e)
	end
end

Http.ENV = _envName

-- Pluggable override: set Http.adapter = function(options) → { StatusCode, Body }
Http.adapter = nil

function Http.send(url: string, headers: {[string]: string}, body: string): (number, string)
	local options = { Url = url, Method = "POST", Headers = headers, Body = body }

	if Http.adapter then
		local ok, res = pcall(Http.adapter, options)
		if not ok then return 0, tostring(res) end
		return res.StatusCode or 0, res.Body or ""
	end

	if _envName == "syn" then
		local ok, res = pcall(syn.request, options)
		if not ok then return 0, tostring(res) end
		return res.StatusCode or 0, res.Body or ""
	end

	if _envName == "executor" and _reqFn then
		local ok, res = pcall(_reqFn, options)
		if not ok then return 0, tostring(res) end
		return res.StatusCode or 0, res.Body or ""
	end

	if _envName == "studio" then
		local RS   = game:GetService("ReplicatedStorage")
		local bridge = RS:FindFirstChild("HttpBridge")
		if not bridge then
			return 0, "[PromptForge] HttpBridge not found in ReplicatedStorage"
		end
		local statusCode, responseBody
		local thread = coroutine.running()
		local conn
		conn = bridge.OnClientEvent:Connect(function(code, rbody)
			conn:Disconnect()
			statusCode   = code
			responseBody = rbody
			task.spawn(thread)
		end)
		bridge:FireServer(url, "POST", headers, body)
		coroutine.yield()
		return statusCode or 0, responseBody or ""
	end

	return 0, "[PromptForge] No HTTP implementation available (ENV=" .. _envName .. ")"
end

return Http
