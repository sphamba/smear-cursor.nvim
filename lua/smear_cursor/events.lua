local animation = require("smear_cursor.animation")
local config = require("smear_cursor.config")
local screen = require("smear_cursor.screen")
local M = {}

local switching_buffer = false

local function move_cursor()
	local row, col = screen.get_screen_cursor_position()
	local jump = not config.smear_between_buffers and switching_buffer
	animation.change_target_position(row, col, jump)

	switching_buffer = false
end

M.move_cursor = function()
	vim.defer_fn(move_cursor, 0) -- for screen.get_screen_cursor_position()
end

local function jump_cursor()
	local row, col = screen.get_screen_cursor_position()
	animation.change_target_position(row, col, true)
end

M.jump_cursor = function()
	vim.defer_fn(jump_cursor, 0) -- for screen.get_screen_cursor_position()
end

M.flag_switching_buffer = function()
	switching_buffer = true
end

M.listen = function()
	vim.api.nvim_exec(
		[[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved * lua require("smear_cursor.events").move_cursor()
			autocmd CursorMovedI,WinScrolled * lua require("smear_cursor.events").jump_cursor()
			autocmd BufLeave * lua require("smear_cursor.events").flag_switching_buffer()
			autocmd ColorScheme * lua require("smear_cursor.color").clear()
		augroup END
	]],
		false
	)
end

M.unlisten = function()
	vim.api.nvim_exec(
		[[
		augroup SmearCursor
			autocmd!
		augroup END
	]],
		false
	)
end

return M
