local animation = require("smear_cursor.animation")
local logging = require("smear_cursor.logging")
local screen = require("smear_cursor.screen")
local M = {}


M.move_cursor = function()
	local row, col = screen.get_screen_cursor_position()
	animation.change_target_position(row, col)
end


M.jump_cursor = function()
	local row, col = screen.get_screen_cursor_position()
	animation.change_target_position(row, col, true)
end


M.listen = function()
	vim.api.nvim_exec([[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved * lua require("smear_cursor.events").move_cursor()
		augroup END

		augroup SmearCursorJump
			autocmd!
			autocmd CursorMovedI * lua require("smear_cursor.events").jump_cursor()
		augroup END
	]], false)
end


return M
