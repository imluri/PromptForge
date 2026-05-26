# PromptForge

Fluent LLM request builder for Luau — messages, tools, and completions across providers.

## Install

**Wally**
```toml
[dependencies]
PromptForge = "imluri/promptforge@0.1.0"
```

**Manual** — drop the `src/` folder into your project and require `init.lua`.

## Quick Start

```lua
local PromptForge = require(script.PromptForge)

local result = PromptForge.new()
    :provider("OpenRouter", "sk-...")
    :model("deepseek/deepseek-chat-v3-5")
    :system("You are a helpful assistant.")
    :user("What is 2 + 2?")
    :temperature(0.7)
    :maxTokens(512)
    :send()

if result.ok then
    print(result.content)
else
    warn(result.error)
end
```

## API

### `PromptForge.new()` → Request

Returns a new fluent request builder.

---

#### Provider & Auth

| Method | Description |
|--------|-------------|
| `:provider(name, apiKey?, customUrl?)` | Set provider. Known: `OpenRouter`, `OpenAI`, `Mistral`, `Groq`, `Pollinations`, `HuggingFace`, `Google`, `Ollama` |
| `:apiKey(key)` | Set API key separately |
| `:url(customUrl)` | Override the endpoint URL |

#### Messages

| Method | Description |
|--------|-------------|
| `:system(content)` | Add a system message |
| `:user(content)` | Add a user message |
| `:assistant(content)` | Add an assistant message |
| `:message(msg)` | Insert a raw message table |
| `:messages(list)` | Replace all messages at once |

#### Model & Sampling

| Method | Description |
|--------|-------------|
| `:model(name)` | Set the model ID |
| `:temperature(n)` | Sampling temperature |
| `:maxTokens(n)` | Max output tokens |
| `:topP(n)` | Top-p sampling |
| `:extra(fields)` | Merge extra fields into the request body |

#### Tools

| Method | Description |
|--------|-------------|
| `:tool(def)` | Add a tool (built table or Tool builder) |
| `:tools(list)` | Add multiple tools at once |

#### Send

| Method | Description |
|--------|-------------|
| `:send()` | Build and send the request. Returns a result table. |
| `:clone()` | Clone this request to branch from a shared base config |

---

### Result table

```lua
{
    ok        = true,           -- HTTP 200
    status    = 200,            -- raw HTTP status
    content   = "...",          -- assistant text content
    message   = { role, content, tool_calls? },
    toolCalls = { ... },        -- tool_calls array if present
    usage     = { prompt_tokens, completion_tokens, total_tokens },
    error     = nil,            -- error string if not ok
    raw       = "...",          -- raw response body
    data      = { ... },        -- full decoded JSON
}
```

---

### `PromptForge.tool(name)` → Tool builder

```lua
local weatherTool = PromptForge.tool("get_weather")
    :description("Get current weather for a location")
    :param("city",    "string",  "The city name",         true)
    :param("units",   "string",  "celsius or fahrenheit", false)
    :enumParam("mode", {"current", "forecast"}, "Forecast type", true)
    :build()

local result = PromptForge.new()
    :provider("OpenRouter", "sk-...")
    :model("deepseek/deepseek-chat-v3-5")
    :tool(weatherTool)
    :user("What's the weather in Singapore?")
    :send()

if result.toolCalls then
    for _, call in ipairs(result.toolCalls) do
        print(call.function.name, call.function.arguments)
    end
end
```

---

### Reusable base config

```lua
local base = PromptForge.new()
    :provider("OpenRouter", "sk-...")
    :model("deepseek/deepseek-chat-v3-5")
    :temperature(0.7)

-- Branch without mutating base
local result = base:clone()
    :system("You are a Roblox scripting expert.")
    :user("How do I tween a part?")
    :send()
```

---

### Custom HTTP adapter

By default PromptForge uses `syn.request`, executor `request`, or the Studio HttpBridge. You can override this:

```lua
PromptForge.setAdapter(function(options)
    -- options = { Url, Method, Headers, Body }
    local res = myHttpLib.request(options)
    return { StatusCode = res.code, Body = res.body }
end)
```

## Providers

| Name | Notes |
|------|-------|
| `OpenRouter` | Adds `HTTP-Referer` and `X-Title` headers automatically |
| `OpenAI` | Standard OpenAI API |
| `Mistral` | Mistral API |
| `Groq` | Groq API |
| `Pollinations` | No key required |
| `HuggingFace` | HuggingFace Inference Router |
| `Google` | Google AI Studio (Gemini via OpenAI-compat) |
| `Ollama` | Local Ollama instance (`http://localhost:11434`) |

## License

MIT
