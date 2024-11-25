local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local events = require("smear_cursor.events")
local M = {}


local enabled = false


local function initialize()
	if _G.smear_cursor == nil then
		_G.smear_cursor = {}
	end
	draw.initialize_lists()
	events.listen()
end


local metatable = {
	__index = function(table, key)
		if key == "enabled" then
			return enabled
		end

		if key == "cursor_color" or key == "normal_bg" then
			return color[key]
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
				initialize()
			else
				events.unlisten()
			end

		elseif key == "cursor_color" or key == "normal_bg" then
			color[key] = value

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
