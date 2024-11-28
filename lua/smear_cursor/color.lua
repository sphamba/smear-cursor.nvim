local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local M = {}

-- TODO: does not work
M.get_hl_group = function(row, col)
	-- Retrieve the current buffer
	local buffer_id = vim.api.nvim_get_current_buf()

	local extmarks = vim.api.nvim_buf_get_extmarks(buffer_id, -1, { row, col }, { row, col + 1 }, {
		details = true,
		overlap = true,
	})
	logging.debug(vim.inspect(extmarks))

	if #extmarks > 0 then
		local extmark = extmarks[1]
		if extmark[4] and extmark[4].hl_group then
			return extmark[4].hl_group
		end
	end

	return "Normal"
end

-- Get a color from a highlight group
local function get_hl_color(group, attr)
	local hl = vim.api.nvim_get_hl_by_name(group, true)
	if hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end

local cursor_color = nil
local normal_bg = nil
local transparent_bg_fallback_color = "#303030"

local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	local r, g, b = hex:match("(..)(..)(..)")
	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function rgb_to_hex(r, g, b)
	return string.format("#%02X%02X%02X", r, g, b)
end

local function interpolate_colors(hex1, hex2, t)
	local r1, g1, b1 = hex_to_rgb(hex1)
	local r2, g2, b2 = hex_to_rgb(hex2)

	local r = round(r1 + t * (r2 - r1))
	local g = round(g1 + t * (g2 - g1))
	local b = round(b1 + t * (b2 - b1))

	return rgb_to_hex(r, g, b)
end

M.set_hl_groups = function()
	-- Retrieve the cursor color and the normal background color if not set by the user
	local _cursor_color = cursor_color
		or get_hl_color("Cursor", "background")
		or get_hl_color("Normal", "foreground")
		or "#d0d0d0"
	local _normal_bg = normal_bg or get_hl_color("Normal", "background") or "none"

	-- Blending breaks with transparent backgrounds
	local blending = config.legacy_computing_symbols_support and _normal_bg ~= "none"

	vim.api.nvim_set_hl(0, M.hl_group, {
		fg = _cursor_color,
		bg = "none",
		blend = blending and 100 or 0,
	})
	vim.api.nvim_set_hl(
		0,
		M.hl_group_inverted,
		-- Blending does not work as we'd like with reversed colors
		{ fg = _normal_bg == "none" and transparent_bg_fallback_color or _normal_bg, bg = _cursor_color, blend = 0 }
	)

	M.hl_groups = {}
	M.hl_groups_inverted = {}

	for i = 1, config.color_levels do
		local opacity = (i / config.color_levels) ^ (1 / config.gamma)
		local blended_cursor_color = interpolate_colors(
			_normal_bg == "none" and transparent_bg_fallback_color or _normal_bg,
			_cursor_color,
			opacity
		)
		local blended_hl_group = M.hl_group .. i
		local blended_hl_group_inverted = M.hl_group_inverted .. i
		M.hl_groups[i] = blended_hl_group
		M.hl_groups_inverted[i] = blended_hl_group_inverted

		vim.api.nvim_set_hl(0, blended_hl_group, {
			fg = blended_cursor_color,
			bg = _normal_bg,
			blend = blending and 100 or 0,
		})
		vim.api.nvim_set_hl(0, blended_hl_group_inverted, {
			fg = _normal_bg == "none" and transparent_bg_fallback_color or _normal_bg,
			bg = blended_cursor_color,
			blend = 0,
		})
	end
end

-- Define new highlight groups using the retrieved colors
M.hl_group = "SmearCursorNormal"
M.hl_group_inverted = "SmearCursorNormalInverted"
M.hl_groups = {}
M.hl_groups_inverted = {}
M.set_hl_groups()

local metatable = {
	__index = function(table, key)
		if key == "cursor_color" then
			return cursor_color
		elseif key == "normal_bg" then
			return normal_bg
		elseif key == "transparent_bg_fallback_color" then
			return transparent_bg_fallback_color
		else
			return nil
		end
	end,

	__newindex = function(table, key, value)
		if key == "cursor_color" then
			cursor_color = value
			M.set_hl_groups()
		elseif key == "normal_bg" then
			normal_bg = value
			M.set_hl_groups()
		elseif key == "transparent_bg_fallback_color" then
			transparent_bg_fallback_color = value
			M.set_hl_groups()
		else
			rawset(table, key, value)
		end
	end,
}

setmetatable(M, metatable)

return M
