local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local events = require("smear_cursor.events")
local M = {}


local enabled = false


local metatable = {
	__index = function(table, key)
		if key == "enabled" then
			return enabled
		end

		if key == "cursor_color" then
			return color.cursor_color
		end

		if config[key] ~= nil then
			return config[key]
		end

		return nil
	end,

	__newindex = function(table, key, value)
		if key == "enabled" then
			enabled = value
			if enabled then
				events.listen()
			else
				events.unlisten()
			end

		elseif key == "cursor_color" then
			color.cursor_color = value

		elseif config[key] ~= nil then
			config[key] = value

		else
			rawset(table, key, value)
		end
	end
}


M.setup = function(opts)
	opts = opts or {}
	if opts.enabled == nil then
		opts.enabled = true
	end

	for key, value in pairs(opts) do
		M[key] = value
	end
end


setmetatable(M, metatable)
return M
