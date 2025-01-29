local animation = require("smear_cursor.animation")
local config = require("smear_cursor.config")
local screen = require("smear_cursor.screen")
local M = {}

local latest_mode = nil
local latest_row = nil
local latest_col = nil
local timer = nil
local cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")

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
	timer = nil

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

local function on_key(key, typed)
	vim.defer_fn(function()
		if timer == nil then M.move_cursor() end
	end, config.delay_after_key)
end

M.listen = function()
	local group = vim.api.nvim_create_augroup("SmearCursor", { clear = true })

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			require("smear_cursor.color").update_color_at_cursor()
		end,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "WinScrolled" }, {
		group = group,
		callback = function()
			require("smear_cursor.events").move_cursor()
		end,
	})

	vim.api.nvim_create_autocmd("CursorMovedI", {
		group = group,
		callback = function()
			require("smear_cursor.events").move_cursor_insert_mode()
		end,
	})

	vim.api.nvim_create_autocmd("CmdlineChanged", {
		group = group,
		callback = function()
			require("smear_cursor.events").jump_cursor()
		end,
	})

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			require("smear_cursor.color").clear_cache()
		end,
	})

	-- To catch changes that do not trigger events (e.g. opening/closing folds)
	vim.on_key(on_key, cursor_namespace)

	if #config.filetypes_disabled > 0 then
		local ignore_group = vim.api.nvim_create_augroup("SmearCursorIgnore", { clear = true })
		vim.api.nvim_create_autocmd("BufEnter", {
			pattern = "*",
			group = ignore_group,
			callback = function()
				require("smear_cursor").enabled =
					not vim.tbl_contains(require("smear_cursor").filetypes_disabled, vim.bo.filetype)
			end,
		})
	end
end

M.unlisten = function()
	vim.api.nvim_create_augroup("SmearCursor", { clear = true })
	vim.on_key(nil, cursor_namespace)
end

return M
