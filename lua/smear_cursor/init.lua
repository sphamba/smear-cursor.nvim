local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local events = require("smear_cursor.events")
local M = {}

local enabled = false

local metatable = {
	__index = function(table, key)
		if key == "enabled" then return enabled end

		if vim.tbl_contains(color.config_variables, key) then return color[key] end

		if config[key] ~= nil then return config[key] end

		return nil
	end,

	__newindex = function(table, key, value)
		if key == "enabled" then
			enabled = value
			if enabled then
				events.listen()
				events.jump_cursor()
			else
				events.unlisten()
				events.jump_cursor()
			end
		elseif vim.tbl_contains(color.config_variables, key) then
			color[key] = value
		elseif key == "legacy_computing_symbols_support" then
			config.legacy_computing_symbols_support = value
			color.clear_cache()
		elseif config[key] ~= nil then
			config[key] = value
		else
			rawset(table, key, value)
		end
	end,
}

M.setup = function(opts)
	opts = opts or {}
	if opts.enabled == nil then opts.enabled = true end

	for key, value in pairs(opts) do
		M[key] = value
	end

	vim.api.nvim_create_user_command("SmearCursorToggle", M.toggle, {})
end

M.toggle = function(opts)
	M.enabled = not M.enabled
end

setmetatable(M, metatable)
return M
