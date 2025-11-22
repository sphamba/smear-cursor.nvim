-- The following options can be set using the `setup` function.
-- Refer to the README for more information.

local config = require("smear_cursor.config")
local round = require("smear_cursor.math").round
local C = {}
local M = {}

-- Color configuration ---------------------------------------------------------

-- Smear cursor color. Defaults to Cursor GUI color if not set.
-- Set to "none" to match the text color at the target cursor position.
-- Can be a hex color code, or a highlight group name.
C.cursor_color = nil
C.cursor_color_insert_mode = nil

-- Background color. Defaults to Normal GUI background color if not set.
C.normal_bg = nil

-- Set when the background is transparent and when not using legacy computing symbols.
C.transparent_bg_fallback_color = "#303030"

-- Cterm color gradient, from bg color (excluded) to cursor color (included)
C.cterm_cursor_colors = {
	240,
	241,
	242,
	243,
	244,
	245,
	246,
	247,
	248,
	249,
	250,
	251,
	252,
	253,
	254,
	255,
}

-- Cterm background color. Must set when not using legacy computing symbols.
C.cterm_bg = 235

--------------------------------------------------------------------------------

M.config_variables = {
	"cursor_color",
	"cursor_color_insert_mode",
	"normal_bg",
	"transparent_bg_fallback_color",
	"cterm_cursor_colors",
	"cterm_bg",
}

-- Get a color from a highlight group
local function get_hl_color(group, attr)
	local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
	if hl[attr] then return string.format("#%06x", hl[attr]) end
	return nil
end

local color_at_cursor = nil
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

function M.clear_cache()
	cache = {}
end

local function resolve_color(str)
	if not str then return nil end
	if str:match("^#") then return str end
	return get_hl_color(str, "bg")
end

function M.get_color_at_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	cursor[1] = cursor[1] - 1
	if vim.b.ts_highlight then
		-- get the treesitter highlight group at the cursor
		local ts_hl_group ---@type string?
		for _, capture in pairs(vim.treesitter.get_captures_at_pos(0, cursor[1], cursor[2])) do
			ts_hl_group = "@" .. capture.capture .. "." .. capture.lang
		end
		if ts_hl_group then return get_hl_color(ts_hl_group, "fg") end
	end
	-- get any extmark with hl_group at the cursor
	local extmarks = vim.api.nvim_buf_get_extmarks(0, -1, cursor, cursor, { details = true, overlap = true })
	for _, extmark in ipairs(extmarks) do
		local ret = extmark[4].hl_group and get_hl_color(extmark[4].hl_group, "fg")
		if ret then return ret end
	end
end

function M.update_color_at_cursor()
	if C.cursor_color ~= "none" and C.cursor_color_insert_mode ~= "none" then return end
	color_at_cursor = M.get_color_at_cursor()
end

---@param opts? {level?: number, inverted?: boolean}
function M.get_hl_group(opts)
	opts = opts or {}
	local _cursor_color = (vim.api.nvim_get_mode().mode == "i") and resolve_color(C.cursor_color_insert_mode)
		or resolve_color(C.cursor_color)

	local hl_group = ("SmearCursor%s%s"):format(opts.inverted and "Inverted" or "", tostring(opts.level or ""))

	-- Get the cursor color from the treesitter highlight group at the cursor.
	if _cursor_color == "none" then
		_cursor_color = color_at_cursor
		if _cursor_color then hl_group = hl_group .. "_" .. _cursor_color:sub(2) end
	end

	if cache[hl_group] then return hl_group end

	-- Retrieve the cursor color and the normal background color if not set by the user
	_cursor_color = _cursor_color or get_hl_color("Cursor", "bg") or get_hl_color("Normal", "fg") or "#d0d0d0"
	local _normal_bg = C.normal_bg or get_hl_color("Normal", "bg") or "none"
	---@type integer?
	local _cterm_cursor_color = C.cterm_cursor_colors and C.cterm_cursor_colors[#C.cterm_cursor_colors] or nil

	-- Blending breaks with transparent backgrounds
	local blending = config.legacy_computing_symbols_support and _normal_bg ~= "none"

	if opts.level then
		local opacity = (opts.level / config.color_levels) ^ (1 / config.gamma)
		_cursor_color = interpolate_colors(
			_normal_bg == "none" and C.transparent_bg_fallback_color or _normal_bg,
			_cursor_color,
			opacity
		)
		_cterm_cursor_color = C.cterm_cursor_colors and C.cterm_cursor_colors[opts.level] or nil
	end

	---@type vim.api.keyset.highlight
	-- stylua: ignore
	local hl = opts.inverted and {
		fg = _normal_bg == "none" and C.transparent_bg_fallback_color or _normal_bg,
		bg = _cursor_color,
		ctermfg = C.cterm_bg or (C.cterm_cursor_colors and C.cterm_cursor_colors[1]),
		ctermbg = _cterm_cursor_color,
		blend = 0,
	} or {
		fg = _cursor_color,
		bg = "none",
		ctermfg = _cterm_cursor_color,
		blend = blending and 100 or 0,
	}

	vim.api.nvim_set_hl(0, hl_group, hl)
	cache[hl_group] = true
	return hl_group
end

setmetatable(M, {
	__index = function(_, key)
		if vim.tbl_contains(M.config_variables, key) then
			return C[key]
		else
			return nil
		end
	end,

	__newindex = function(table, key, value)
		if vim.tbl_contains(M.config_variables, key) then
			C[key] = value
			M.clear_cache()
		else
			rawset(table, key, value)
		end

		if key == "cterm_cursor_colors" then config.color_levels = #value end
	end,
})

-- Make the real cursor hideable
if type(vim.o.guicursor) == "string" then
	if vim.o.guicursor ~= "" then vim.o.guicursor = vim.o.guicursor .. "," end
	vim.o.guicursor = vim.o.guicursor .. "a:SmearCursorHideable"
end

M.hide_real_cursor = function()
	vim.api.nvim_set_hl(0, "SmearCursorHideable", {
		fg = "white",
		blend = 100,
	})
end

M.unhide_real_cursor = function()
	vim.api.nvim_set_hl(0, "SmearCursorHideable", {
		fg = "none",
		blend = 0,
	})
end

return M
