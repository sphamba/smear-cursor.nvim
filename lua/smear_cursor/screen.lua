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

M.get_screen_cmd_cursor_position = function()
	if vim.g.ui_cmdline_pos ~= nil then -- noice.nvim
		local row = vim.g.ui_cmdline_pos[1]
		local col = vim.g.ui_cmdline_pos[2]

		if not row or not col then
			row = vim.g.ui_cmdline_pos.row
			col = vim.g.ui_cmdline_pos.col
		end

		col = col + vim.fn.getcmdpos() + 1
		return row, col
	end

	local row = vim.o.lines - vim.opt.cmdheight._value + 1
	local col = vim.fn.getcmdpos() + 1

	return row, col
end

M.get_screen_distance = function(row_start, row_end)
	local reversed = false

	if row_start > row_end then
		row_start, row_end = row_end, row_start
		reversed = true
	end

	local text_height
	local success = pcall(function()
		text_height = vim.api.nvim_win_text_height(0, {
			start_row = row_start - 1,
			end_row = row_end - 1,
		})
	end)

	if not success then -- line is not visible
		text_height = { all = 1 }
	end

	local distance = text_height.all - 1
	return reversed and -distance or distance
end

return M
