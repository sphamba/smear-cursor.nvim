local animation = require("smear_cursor.animation")
local logging = require("smear_cursor.logging")
local screen = require("smear_cursor.screen")
local M = {}


local switching_buffer = false


M.move_cursor = function()
	local row, col = screen.get_screen_cursor_position()
	animation.change_target_position(row, col)
end


M.jump_cursor = function()
	local row, col = screen.get_screen_cursor_position()

	if not switching_buffer then
		animation.change_target_position(row, col, true)
	end

	switching_buffer = false
end


M.flag_switching_buffer = function()
	switching_buffer = true
end


M.listen = function()
	vim.api.nvim_exec([[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved * lua require("smear_cursor.events").move_cursor()
			autocmd CursorMovedI,WinScrolled * lua require("smear_cursor.events").jump_cursor()
			autocmd BufLeave * lua require("smear_cursor.events").flag_switching_buffer()
		augroup END
	]], false)
end


M.unlisten = function()
	vim.api.nvim_exec([[
		augroup SmearCursor
			autocmd!
		augroup END
	]], false)
end


return M
