local animation = require("smear_cursor.animation")
local config = require("smear_cursor.config")
local screen = require("smear_cursor.screen")
local M = {}

local latest_mode = nil
local latest_row = nil
local latest_col = nil
local timer = nil

local EVENT_TRIGGER = nil
local AFTER_DELAY = 1

local function move_cursor(trigger)
	trigger = trigger or EVENT_TRIGGER
	local row, col
	local mode = vim.api.nvim_get_mode().mode

	if mode ~= "c" then
		row, col = screen.get_screen_cursor_position()
	elseif config.smear_to_cmd then
		row, col = screen.get_screen_cmd_cursor_position()
	else
		return
	end

	if timer ~= nil and timer:is_active() then
		timer:stop()
		timer:close()
	end

	if trigger == AFTER_DELAY and mode == latest_mode and row == latest_row and col == latest_col then
		animation.change_target_position(row, col)
	else -- try until the cursor stops moving
		latest_mode = mode
		latest_row = row
		latest_col = col

		timer = vim.uv.new_timer()
		timer:start(
			config.delay_event_to_smear,
			0,
			vim.schedule_wrap(function()
				move_cursor(AFTER_DELAY)
			end)
		)
	end
end

M.move_cursor = function(trigger)
	-- Must defer for screen.get_screen_cursor_position() and vim.api.nvim.get_mode()
	vim.defer_fn(function()
		move_cursor(trigger)
	end, 0)
end

local function jump_cursor()
	local row, col = screen.get_screen_cursor_position()
	animation.jump(row, col)
end

M.jump_cursor = function()
	vim.defer_fn(jump_cursor, 0) -- for screen.get_screen_cursor_position()
end

M.move_cursor_insert_mode = function(trigger)
	if config.smear_insert_mode then
		M.move_cursor(trigger)
	else
		M.jump_cursor()
	end
end

M.listen = function()
	vim.api.nvim_exec2(
		[[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved,CursorMovedI * lua require("smear_cursor.color").update_color_at_cursor()
			autocmd CursorMoved,ModeChanged,WinScrolled * lua require("smear_cursor.events").move_cursor(nil)
			autocmd CursorMovedI * lua require("smear_cursor.events").move_cursor_insert_mode(nil)
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
