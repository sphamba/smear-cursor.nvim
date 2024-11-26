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


return M
