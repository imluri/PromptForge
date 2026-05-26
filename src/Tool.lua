-- Tool.lua | Fluent builder for a single function/tool definition

local module = {}

local TYPES = { string = true, number = true, boolean = true, array = true, object = true }

function module.new(name: string)
	assert(type(name) == "string" and name ~= "", "[PromptForge] Tool name must be a non-empty string")

	local Tool = {
		_name        = name,
		_description = "",
		_params      = {},
		_required    = {},
	}

	function Tool:description(desc: string)
		assert(type(desc) == "string", "[PromptForge] description must be a string")
		self._description = desc
		return self
	end

	-- :param(name, type, description, required?)
	function Tool:param(paramName: string, paramType: string, desc: string, required: boolean?)
		assert(type(paramName) == "string" and paramName ~= "", "[PromptForge] param name must be a non-empty string")
		assert(TYPES[paramType], "[PromptForge] param type must be one of: string, number, boolean, array, object")
		self._params[paramName] = { type = paramType, description = desc or "" }
		if required then
			self._required[#self._required + 1] = paramName
		end
		return self
	end

	-- :enumParam(name, values, description, required?)
	function Tool:enumParam(paramName: string, values: {string}, desc: string, required: boolean?)
		assert(type(paramName) == "string" and paramName ~= "", "[PromptForge] param name must be a non-empty string")
		assert(type(values) == "table" and #values > 0, "[PromptForge] enum values must be a non-empty array")
		self._params[paramName] = { type = "string", enum = values, description = desc or "" }
		if required then
			self._required[#self._required + 1] = paramName
		end
		return self
	end

	function Tool:build(): {}
		local properties = {}
		for k, v in pairs(self._params) do
			properties[k] = v
		end
		return {
			type     = "function",
			function = {
				name        = self._name,
				description = self._description,
				parameters  = {
					type       = "object",
					properties = properties,
					required   = self._required,
				},
			},
		}
	end

	return Tool
end

return module
