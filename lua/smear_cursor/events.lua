local animation = require("smear_cursor.animation")
local logging = require("smear_cursor.logging")
local screen = require("smear_cursor.screen")
local M = {}


M.on_cursor_moved = function()
	local row, col = screen.get_screen_cursor_position()
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
