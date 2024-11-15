local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local M = {}


BOTTOM_BLOCKS = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " "}
LEFT_BLOCKS   = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}


-- Create a namespace for the extmarks
M.cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")


local function draw_character(row, col, character, hl_group)
	if character == nil then
		character = "█"
	end

	if hl_group == nil then
		hl_group = color.hl_group
	end

	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")

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
	local success, extmark_id = pcall(function ()
		vim.api.nvim_buf_set_extmark(buffer_id, M.cursor_namespace, row - 1, 0, {
			virt_text = {{character, hl_group}},
			virt_text_win_col = col - 1,
		})
	end)

	if not success then
		logging.warning("Failed to draw character at (" .. row .. ", " .. col .. ")")
	end

	-- Clean extra lines
	-- if row > line_count then
	-- 	logging.debug("Removing extra lines from " .. line_count .. " to " .. row)
	-- 	vim.api.nvim_buf_set_lines(buffer_id, line_count, row, false, {})
	-- end

	return extmark_id
end


local function draw_bottom_block(row, col, character_index)
	if character_index > 7 then
		return
	end
	local character = BOTTOM_BLOCKS[character_index + 1]
	draw_character(row, col, character)
end


local function draw_top_block(row, col, character_index)
	if character_index < 1 then
		return
	end
	local character = BOTTOM_BLOCKS[character_index + 1]
	draw_character(row, col, character, color.hl_group_inverted)
end


local function draw_vertically_shifted_block(row_float, col)
	local row = math.floor(row_float)
	local character_index = math.floor((row_float - row) * 8 + 0.5)
	draw_bottom_block(row, col, character_index)
	draw_top_block(row + 1, col, character_index)
end


local function draw_right_block(row, col, character_index)
	if character_index > 7 then
		return
	end
	local character = LEFT_BLOCKS[character_index + 1]
	draw_character(row, col, character, color.hl_group_inverted)
end


local function draw_left_block(row, col, character_index)
	if character_index < 1 then
		return
	end
	local character = LEFT_BLOCKS[character_index + 1]
	draw_character(row, col, character)
end


local function draw_horizontally_shifted_block(row, col_float)
	local col = math.floor(col_float)
	local character_index = math.floor((col_float - col) * 8 + 0.5)
	draw_right_block(row, col, character_index)
	draw_left_block(row, col + 1, character_index)
end


M.remove_character = function(extmark_id)
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_del_extmark(buffer_id, M.cursor_namespace, extmark_id)
	logging.debug("Removed character")
end


local function draw_horizontal_ish_line(row_start, col_start, row_end, col_end)
	local distance = math.abs(col_end - col_start)
	local direction = col_end > col_start and 1 or -1

	for i = 0, distance - 1 do
		local row = row_start + (row_end - row_start) * i / distance
		local col = col_start + direction * i
		draw_vertically_shifted_block(row, col)
	end
end


local function draw_vertical_ish_line(row_start, col_start, row_end, col_end)
	local distance = math.abs(row_end - row_start)
	local direction = row_end > row_start and 1 or -1

	for i = 0, distance - 1 do
		local row = row_start + direction * i
		local col = col_start + (col_end - col_start) * i / distance
		draw_horizontally_shifted_block(row, col)
	end
end


local function draw_diagonal_line(row_start, col_start, row_end, col_end)
	local distance = math.sqrt((row_end - row_start)^2 + (col_end - col_start)^2)
	if distance < 1 then
		return
	end

	for i = 0, distance - 1 do
		local row = row_start + (row_end - row_start) * i / distance
		local col = col_start + (col_end - col_start) * i / distance
		row = math.floor(row + 0.5)
		col = math.floor(col + 0.5)
		draw_character(row, col)
	end
end


M.draw_line = function(row_start, col_start, row_end, col_end)
	logging.debug("Drawing line from (" .. row_start .. ", " .. col_start .. ") to (" .. row_end .. ", " .. col_end .. ")")
	local horizontal_shift = math.abs(col_end - col_start)
	local vertical_shift = math.abs(row_end - row_start)

	if vertical_shift <= config.MAX_SLOPE_HORIZONTAL * horizontal_shift then
		logging.debug("Drawing horizontal-ish line")
		draw_horizontal_ish_line(row_start, col_start, row_end, col_end)
		return
	end

	if vertical_shift >= config.MIN_SLOPE_VERTICAL * horizontal_shift then
		logging.debug("Drawing vertical-ish line")
		draw_vertical_ish_line(row_start, col_start, row_end, col_end)
		return
	end
	
	logging.debug("Drawing diagonal line")
	draw_diagonal_line(row_start, col_start, row_end, col_end)
end


M.clear = function()
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buffer_id, M.cursor_namespace, 0, -1)
end


return M
