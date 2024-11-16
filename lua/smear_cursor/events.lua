local animation = require("smear_cursor.animation")
local logging = require("smear_cursor.logging")
local M = {}


-- Get cursor position (1-indexed)
M.get_cursor_position = function()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local col = vim.fn.virtcol(".", 1)[1] -- Take into account wide characters
	return row, col
end


M.on_cursor_moved = function()
	local row, col = M.get_cursor_position()
	animation.change_target_position(row, col)
end


M.listen = function()
	vim.api.nvim_exec([[
		augroup GetCursorPosition
			autocmd!
			autocmd CursorMoved * lua require("smear_cursor.events").on_cursor_moved()
		augroup END
	]], false)
end


return M
