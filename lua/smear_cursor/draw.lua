local logging = require("smear_cursor.logging")
local M = {}

-- Create a namespace for the extmarks
M.cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")


M.draw_character = function(row, col, character)
	if character == nil then
		character = "█"
	end

	logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")

	-- Retrieve the current buffer
	local buffer_id = vim.api.nvim_get_current_buf()

	-- Add extra lines to the buffer if necessary
	-- local line_count = vim.api.nvim_buf_line_count(buffer_id)
	-- if row > line_count then
	-- 	local new_lines = {}
	-- 	for _ = 1, row - line_count do
	-- 		table.insert(new_lines, "")
	-- 	end
	-- 	logging.debug("Adding lines to the buffer from " .. line_count .. " to " .. row)
	-- 	vim.api.nvim_buf_set_lines(buffer_id, line_count, line_count, false, new_lines)
	-- end

	-- Place new extmark with the determined position
	local extmark_id = vim.api.nvim_buf_set_extmark(buffer_id, M.cursor_namespace, row - 1, 0, {
		virt_text = {{character, "SmearCursor"}},
		virt_text_win_col = col - 1,
	})

	-- Clean extra lines
	-- if row > line_count then
	-- 	logging.debug("Removing extra lines from " .. line_count .. " to " .. row)
	-- 	vim.api.nvim_buf_set_lines(buffer_id, line_count, row, false, {})
	-- end

	return extmark_id
end


M.remove_character = function(extmark_id)
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_del_extmark(buffer_id, M.cursor_namespace, extmark_id)
	logging.debug("Removed character")
end


M.draw_line = function(row_start, col_start, row_end, col_end)
	logging.debug("Drawing line from (" .. row_start .. ", " .. col_start .. ") to (" .. row_end .. ", " .. col_end .. ")")

	local distance = math.sqrt((row_end - row_start)^2 + (col_end - col_start)^2)
	if distance < 1 then
		return
	end

	for i = 0, distance - 1 do
		local row = row_start + (row_end - row_start) * i / distance
		local col = col_start + (col_end - col_start) * i / distance
		row = math.floor(row + 0.5)
		col = math.floor(col + 0.5)
		if not pcall(function () M.draw_character(row, col) end) then
			logging.debug("Failed to draw character at (" .. row .. ", " .. col .. ")")
		end
	end
end


M.clear = function()
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buffer_id, M.cursor_namespace, 0, -1)
end


return M
