local animation = require("smear_cursor.animation")
local config = require("smear_cursor.config")
local screen = require("smear_cursor.screen")
local M = {}

local function get_cmd_row()
	return vim.o.lines - vim.opt.cmdheight._value + 1
end

local function move_cursor_cmd()
	if not config.smear_to_cmd then return end
	local row = get_cmd_row()
	local col = vim.fn.getcmdpos() + 1
	animation.change_target_position(row, col)
end

local function move_cursor()
	if vim.api.nvim_get_mode().mode == "c" then
		move_cursor_cmd()
	else
		local row, col = screen.get_screen_cursor_position()
		animation.change_target_position(row, col)
	end
end

M.move_cursor = function()
	-- Must defer for screen.get_screen_cursor_position() and vim.api.nvim.get_mode()
	vim.defer_fn(move_cursor, 0)
end

local function jump_cursor()
	local row, col = screen.get_screen_cursor_position()
	animation.jump(row, col)
end

M.jump_cursor = function()
	vim.defer_fn(jump_cursor, 0) -- for screen.get_screen_cursor_position()
end

M.listen = function()
	vim.api.nvim_exec2(
		[[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved,CursorMovedI * lua require("smear_cursor.color").update_color_at_cursor()
			autocmd CursorMoved,ModeChanged,WinScrolled * lua require("smear_cursor.events").move_cursor()
			autocmd CursorMovedI * lua require("smear_cursor.events").jump_cursor()
			autocmd ColorScheme * lua require("smear_cursor.color").clear_cache()
		augroup END
	]],
		{}
	)

	if #config.filetypes_disabled > 0 then
		vim.api.nvim_exec2(
			[[
		augroup SmearCursorIgnore
			autocmd!
			autocmd BufEnter * lua require("smear_cursor").enabled = not vim.tbl_contains(require("smear_cursor").filetypes_disabled, vim.bo.filetype)
		augroup END
	]],
			{}
		)
	end
end

M.unlisten = function()
	vim.api.nvim_exec2(
		[[
		augroup SmearCursor
			autocmd!
		augroup END
	]],
		{}
	)
end

return M
