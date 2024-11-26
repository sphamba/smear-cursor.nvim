local logging = require("smear_cursor.logging")
local M = {}


M.get_screen_cursor_position = function(window_id)
	window_id = window_id or vim.api.nvim_get_current_win()

	local window_origin = vim.api.nvim_win_get_position(window_id)
	local window_row = window_origin[1]
	local window_col = window_origin[2]
	local screen_row = window_row + vim.fn.winline()
	local screen_col = window_col + vim.fn.wincol()

	return screen_row, screen_col
end


local function get_window_containing_position(screen_row, screen_col)
	local current_tab = vim.api.nvim_get_current_tabpage()
	local window_ids = vim.api.nvim_tabpage_list_wins(current_tab)

	for _, window_id in pairs(window_ids) do
		local window_origin = vim.api.nvim_win_get_position(window_id)
		local window_row = window_origin[1] + 1
		local window_col = window_origin[2] + 1
		local window_height = vim.api.nvim_win_get_height(window_id)
		local window_width = vim.api.nvim_win_get_width(window_id)

		if screen_row >= window_row and screen_row < window_row + window_height and
			screen_col >= window_col and screen_col < window_col + window_width then
			return window_id
		end
	end

	return nil
end


return M
