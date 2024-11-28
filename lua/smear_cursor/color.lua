local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local M = {}

-- Get a color from a highlight group
local function get_hl_color(group, attr)
	local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
	if hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end

local cursor_color = nil
local normal_bg = nil
local transparent_bg_fallback_color = "#303030"
local cache = {} ---@type table<string, boolean>

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

function M.clear()
	cache = {}
end

---@param opts? {level?: number, inverted?: boolean}
function M.get_hl_group(opts)
	opts = opts or {}
	local _cursor_color = cursor_color

	local hl_group = ("SmearCursorNormal%s%s"):format(opts.inverted and "Inverted" or "", tostring(opts.level) or "")

	-- Get the cursor color from the treesitter highlight group
	-- at the cursor.
	if cursor_color == "treesitter" then
		_cursor_color = nil
		if vim.b.ts_highlight then
			local cursor = vim.api.nvim_win_get_cursor(0)
			local ts_hl_group ---@type string?
			for _, capture in pairs(vim.treesitter.get_captures_at_pos(0, cursor[1] - 1, cursor[2])) do
				ts_hl_group = "@" .. capture.capture .. "." .. capture.lang
			end
			local ts_color = ts_hl_group and get_hl_color(ts_hl_group, "fg")
			if ts_color then
				_cursor_color = ts_color
				hl_group = hl_group .. "_" .. ts_color:sub(2)
			end
		end
	end

	if cache[hl_group] then
		return hl_group
	end

	local _normal_bg = normal_bg or get_hl_color("Normal", "bg") or "none"

	-- Retrieve the cursor color and the normal background color if not set by the user
	_cursor_color = _cursor_color or get_hl_color("Cursor", "bg") or get_hl_color("Normal", "fg") or "#d0d0d0"

	-- Blending breaks with transparent backgrounds
	local blending = config.legacy_computing_symbols_support and _normal_bg ~= "none"

	if opts.level then
		local opacity = (opts.level / config.color_levels) ^ (1 / config.gamma)
		_cursor_color = interpolate_colors(
			_normal_bg == "none" and transparent_bg_fallback_color or _normal_bg,
			_cursor_color,
			opacity
		)
	end

	---@type vim.api.keyset.highlight
	local hl = opts.inverted
			and {
				fg = _normal_bg == "none" and transparent_bg_fallback_color or _normal_bg,
				bg = _cursor_color,
				blend = 0,
			}
		or {
			fg = _cursor_color,
			bg = "none", -- _normal_bg,
			blend = blending and 100 or 0,
		}

	vim.api.nvim_set_hl(0, hl_group, hl)
	cache[hl_group] = true
	return hl_group
end

-- Define new highlight groups using the retrieved colors
M.hl_groups = setmetatable({}, {
	__index = function(_, key)
		return M.get_hl_group({ level = key })
	end,
})
M.hl_groups_inverted = setmetatable({}, {
	__index = function(_, key)
		return M.get_hl_group({ level = key, inverted = true })
	end,
})

local metatable = {
	__index = function(_, key)
		if key == "cursor_color" then
			return cursor_color
		elseif key == "normal_bg" then
			return normal_bg
		elseif key == "transparent_bg_fallback_color" then
			return transparent_bg_fallback_color
		elseif key == "hl_group" then
			return M.get_hl_group()
		elseif key == "hl_group_inverted" then
			return M.get_hl_group({ inverted = true })
		else
			return nil
		end
	end,

	__newindex = function(table, key, value)
		if key == "cursor_color" then
			cursor_color = value
			M.clear()
		elseif key == "normal_bg" then
			normal_bg = value
			M.clear()
		elseif key == "transparent_bg_fallback_color" then
			transparent_bg_fallback_color = value
			M.clear()
		else
			rawset(table, key, value)
		end
	end,
}

setmetatable(M, metatable)

return M
