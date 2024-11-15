local M = {}


-- Get a color from a highlight group
M.get_hl_color = function(group, attr)
	local hl = vim.api.nvim_get_hl_by_name(group, true)
	if hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end

-- Get cursor foreground color and normal background color
-- local cursor_fg = get_hl_color("Normal", "foreground") -- Cursor color
local cursor_fg = "#d3cdc3" -- Cursor color set by terminal
local normal_bg = M.get_hl_color("Normal", "background") -- Normal background

-- Define new highlight groups using the retrieved colors
M.hl_group = "SmearCursor"
M.hl_group_inverted = "SmearCursorInverted"
vim.api.nvim_set_hl(0, M.hl_group, { fg = cursor_fg, bg = normal_bg })
vim.api.nvim_set_hl(0, M.hl_group_inverted, { fg = normal_bg, bg = cursor_fg })


return M
