-- Providers.lua | Known provider endpoints and header builders

local Providers = {}

local ENDPOINTS = {
	OpenRouter    = "https://openrouter.ai/api/v1/chat/completions",
	OpenAI        = "https://api.openai.com/v1/chat/completions",
	Mistral       = "https://api.mistral.ai/v1/chat/completions",
	Groq          = "https://api.groq.com/openai/v1/chat/completions",
	Pollinations  = "https://text.pollinations.ai/openai",
	HuggingFace   = "https://router.huggingface.co/v1/chat/completions",
	Google        = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
	Ollama        = "http://localhost:11434/api/chat",
}

function Providers.endpoint(provider: string, customUrl: string?): string
	if customUrl and customUrl ~= "" then
		return customUrl
	end
	return ENDPOINTS[provider] or error("[PromptForge] Unknown provider: " .. tostring(provider))
end

function Providers.headers(provider: string, apiKey: string): {[string]: string}
	local headers = { ["Content-Type"] = "application/json" }
	if apiKey and apiKey ~= "" then
		headers["Authorization"] = "Bearer " .. apiKey
	end
	if provider == "OpenRouter" then
		headers["HTTP-Referer"] = "https://github.com/imluri/PromptForge"
		headers["X-Title"]      = "PromptForge"
	end
	return headers
end

function Providers.isOllama(provider: string): boolean
	return provider == "Ollama"
end

function Providers.known(): {string}
	local list = {}
	for name in pairs(ENDPOINTS) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

return Providers
