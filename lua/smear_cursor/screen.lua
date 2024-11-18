local logging = require("smear_cursor.logging")
local M = {}


M.get_screen_cursor_position = function(window_id)
	if window_id == nil then
		window_id = vim.api.nvim_get_current_win()
	end

	local window_origin = vim.api.nvim_win_get_position(window_id)
	local window_row = window_origin[1]
	local window_col = window_origin[2]
	local screen_row = window_row + vim.fn.winline()
	local screen_col = window_col + vim.fn.wincol()

	return screen_row, screen_col
end


local function get_window_containing_position(screen_row, screen_col)
	local window_ids = vim.api.nvim_list_wins()

	for _, window_id in ipairs(window_ids) do
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


M.screen_to_buffer = function(screen_row, screen_col)
	local window_id = get_window_containing_position(screen_row, screen_col)
	if window_id == nil then
		return nil
	end

	local buffer_id = vim.api.nvim_win_get_buf(window_id)

	local start_row = vim.fn.line("w0", window_id)
	local buffer_origin = vim.fn.screenpos(window_id, start_row, 1)
	local col = screen_col - buffer_origin.col + 1
	local col_shift = 0 -- To draw to the left of wrapped lines, positive

	-- Find the buffer row corresponding to the screen row
	-- Take into account folds
	local row = start_row
	for current_screen_row = buffer_origin.row, screen_row - 1 do
		if vim.fn.foldclosed(row) ~= -1 then
			row = vim.fn.foldclosedend(row) + 1

		else

			row = row + 1
		end
	end

	return buffer_id, row, col, col_shift
end


return M
