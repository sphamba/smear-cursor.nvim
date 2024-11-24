local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local M = {}


-- TODO: does not work
M.get_hl_group = function(row, col)
	-- Retrieve the current buffer
	local buffer_id = vim.api.nvim_get_current_buf()

    local extmarks = vim.api.nvim_buf_get_extmarks(
		buffer_id,
		-1,
		{row, col},
		{row, col + 1},
		{
			details = true,
			overlap = true,
		}
	)
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


-- Get cursor foreground color and normal background color
local cursor_color = get_hl_color("Normal", "foreground") -- Cursor color
local normal_bg = get_hl_color("Normal", "background") -- Normal background
normal_bg = normal_bg or "#282828"


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


local function set_hl_groups()
	vim.api.nvim_set_hl(0, M.hl_group, { fg = cursor_color, bg = normal_bg })
	vim.api.nvim_set_hl(0, M.hl_group_inverted, { fg = cursor_color, bg = normal_bg, reverse = true })

	M.hl_groups = {}
	M.hl_groups_inverted = {}

	for i = 1, config.color_levels do
		local blended_cursor_color = interpolate_colors(normal_bg, cursor_color, (i / config.color_levels)^(1 / config.gamma))
		local blended_hl_group = M.hl_group .. i
		local blended_hl_group_inverted = M.hl_group_inverted .. i
		M.hl_groups[i] = blended_hl_group
		M.hl_groups_inverted[i] = blended_hl_group_inverted
		vim.api.nvim_set_hl(0, blended_hl_group, { fg = blended_cursor_color, bg = normal_bg })
		vim.api.nvim_set_hl(0, blended_hl_group_inverted, { fg = blended_cursor_color, bg = normal_bg, reverse = true })
	end
end


-- Define new highlight groups using the retrieved colors
M.hl_group = "SmearCursorNormal"
M.hl_group_inverted = "SmearCursorNormalInverted"
M.hl_groups = {}
M.hl_groups_inverted = {}
set_hl_groups()


local metatable = {
	__index = function(table, key)
		if key == "cursor_color" then
			return cursor_color
		end

		if key == "normal_bg" then
			return normal_bg
		end

		return nil
	end,

	__newindex = function(table, key, value)
		if key == "cursor_color" then
			cursor_color = value
			set_hl_groups()

		elseif key == "normal_bg" then
			normal_bg = value
			set_hl_groups()

		else
			rawset(table, key, value)
		end
	end
}

setmetatable(M, metatable)


return M
