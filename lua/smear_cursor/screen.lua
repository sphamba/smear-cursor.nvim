local logging = require("smear_cursor.logging")
local M = {}


M.get_window_cursor_position = function(window_id)
	if window_id == nil then
		window_id = vim.api.nvim_get_current_win()
	end

	local window_position = vim.api.nvim_win_get_position(window_id)
	local window_row = window_position[1]
	local window_col = window_position[2]

	return window_row, window_col
end


M.get_screen_cursor_position = function(window_id)
	if window_id == nil then
		window_id = vim.api.nvim_get_current_win()
	end

	local window_origin = vim.fn.win_screenpos(window_id) -- 1-indexed
	local window_row = window_origin[1]
	local window_col = window_origin[2]
	local screen_row = window_row + vim.fn.winline() - 1
	local screen_col = window_col + vim.fn.wincol() - 1

	return screen_row, screen_col
end


M.screen_to_buffer = function(screen_row, screen_col)
	-- TODO: Find window that contains the screen coordinates
	local window_id = vim.api.nvim_get_current_win()
	local buffer_id = vim.api.nvim_win_get_buf(window_id)

	local start_row = vim.fn.line("w0", window_id)
	local buffer_origin = vim.fn.screenpos(window_id, start_row, 0)
	-- local row = screen_row - buffer_origin.row + start_row
	local col = screen_col - buffer_origin.col + 1

	local row = start_row
	for current_screen_row = buffer_origin.row, screen_row - 1 do
		if vim.fn.foldclosed(row) == -1 then
			row = row + 1
		else
			row = vim.fn.foldclosedend(row) + 1
		end
	end

	return buffer_id, row, col
end


return M
