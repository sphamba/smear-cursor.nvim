local M = {}

M.get_screen_cursor_position = function()
	-- Must be called in a vim.defer_fn, otherwise it will return previous cursor position
	local window_id = vim.api.nvim_get_current_win()
	local window_info = vim.fn.getwininfo(window_id)[1]
	local window_config = vim.api.nvim_win_get_config(window_id)
	local row = vim.fn.screenrow()
	local col = vim.fn.screencol()

	if #window_config.relative > 0 then
		row = row + window_info.winrow - 1
		col = col + window_info.wincol - 1
	end

	return row, col
end

return M
