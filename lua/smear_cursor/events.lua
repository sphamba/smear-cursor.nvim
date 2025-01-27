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

local function move_cursor(trigger, jump)
	-- Calls to this function must deferred for screen.get_screen_cursor_position() and vim.api.nvim.get_mode() to work
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
		if jump then
			animation.jump(row, col)
		else
			animation.change_target_position(row, col)
		end
	else -- try until the cursor stops moving
		latest_mode = mode
		latest_row = row
		latest_col = col

		timer = vim.uv.new_timer()
		timer:start(
			config.delay_event_to_smear,
			0,
			vim.schedule_wrap(function()
				move_cursor(AFTER_DELAY, jump)
			end)
		)
	end
end

M.move_cursor = function()
	vim.defer_fn(function()
		move_cursor(EVENT_TRIGGER, false)
	end, 0)
end

M.move_cursor_insert_mode = function()
	vim.defer_fn(function()
		move_cursor(EVENT_TRIGGER, not config.smear_insert_mode)
	end, 0)
end

M.jump_cursor = function()
	vim.defer_fn(function()
		move_cursor(EVENT_TRIGGER, true)
	end, 0)
end

M.listen = function()
	vim.api.nvim_exec2(
		[[
		augroup SmearCursor
			autocmd!
			autocmd CursorMoved,CursorMovedI * lua require("smear_cursor.color").update_color_at_cursor()
			autocmd CursorMoved,ModeChanged,WinScrolled * lua require("smear_cursor.events").move_cursor()
			autocmd CursorMovedI * lua require("smear_cursor.events").move_cursor_insert_mode()
			autocmd CmdlineChanged * lua require("smear_cursor.events").jump_cursor()
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
