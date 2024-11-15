local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local M = {}


BOTTOM_BLOCKS = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " "}
LEFT_BLOCKS   = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
MATRIX_CHARACTERS = {" ", "▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█"}


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


local function draw_partial_block(row, col, character_list, character_index, hl_group)
	local character = character_list[character_index + 1]
	draw_character(row, col, character, hl_group)
end


local function draw_vertically_shifted_block(row_float, col)
	local row = math.floor(row_float)
	local shift = row_float - row
	local character_index = math.floor(shift * 8 + 0.5)

	if character_index < 8 then
		draw_partial_block(
			row,
			col,
			BOTTOM_BLOCKS,
			character_index,
			color.hl_group
		)
	end

	if character_index > 0 then
		draw_partial_block(
			row + 1,
			col,
			BOTTOM_BLOCKS,
			character_index,
			color.hl_group_inverted
		)
	end
end


local function draw_horizontally_shifted_block(row, col_float)
	local col = math.floor(col_float)
	local shift = col_float - col
	local character_index = math.floor(shift * 8 + 0.5)

	if character_index < 7 then
		draw_partial_block(
			row,
			col,
			LEFT_BLOCKS,
			character_index,
			color.hl_group_inverted
		)
	end

	if character_index > 0 then
		draw_partial_block(
			row,
			col + 1,
			LEFT_BLOCKS,
			character_index,
			color.hl_group
		)
	end
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
		local row_float = row_start + (row_end - row_start) * i / distance
		local col = col_start + direction * i
		draw_vertically_shifted_block(row_float, col)
	end
end


local function draw_vertical_ish_line(row_start, col_start, row_end, col_end)
	local distance = math.abs(row_end - row_start)
	local direction = row_end > row_start and 1 or -1

	for i = 0, distance - 1 do
		local row = row_start + direction * i
		local col_float = col_start + (col_end - col_start) * i / distance
		draw_horizontally_shifted_block(row, col_float)
	end
end


local function draw_matrix_character(row, col, matrix)
	local index = matrix[1][1] * 1 + matrix[1][2] * 2 + matrix[2][1] * 4 + matrix[2][2] * 8
	if index == 0 then return end
	local character = MATRIX_CHARACTERS[index + 1]
	draw_character(row, col, character)
end


local function draw_diagonal_horizontal_block(row_float, col, row_start, col_start, row_end, col_end, slope)
	local row = math.floor(row_float + 0.5)
	local shift = row_float - row
	-- Matrix of lit quarters
	local m = {
		{0, 0}, -- Top of row above
		{0, 0}, -- Bottom of row above
		{0, 0}, -- Top of current row
		{0, 0}, -- Bottom of current row
		{0, 0}, -- Top of row below
		{0, 0}  -- Bottom of row below
	}

	-- Lit from the left
	local shift_left = shift - 0.5 * slope
	local half_row_left = math.floor(shift_left * 2 + 0.5)
	m[3 + half_row_left][1] = 1
	m[4 + half_row_left][1] = 1

	-- Lit from center
	local half_row = math.floor(shift * 2 + 0.5)
	m[3 + half_row][1] = 1
	m[4 + half_row][1] = 1
	m[3 + half_row][2] = 1
	m[4 + half_row][2] = 1

	-- Lit from the right
	local shift_right = shift + 0.5 * slope
	local half_row_right = math.floor(shift_right * 2 + 0.5)
	m[3 + half_row_right][2] = 1
	m[4 + half_row_right][2] = 1

	for i = -1, 1 do
		local row_i = row + i
		if not (row_i == row_end and col == col_end)
			and not (row_i < math.min(row_start, row_end))
			and not (row_i > math.max(row_start, row_end)) then
			draw_matrix_character(row_i, col, {m[2 * i + 3], m[2 * i + 4]})
		end
	end
end


local function draw_diagonal_vertical_block(row, col_float, row_start, col_start, row_end, col_end, slope)
	draw_vertical_ish_line(row_start, col_start, row_end, col_end)
end


local function draw_diagonal_horizontal_line(row_start, col_start, row_end, col_end)
	local distance = math.abs(col_end - col_start)
	local direction = col_end > col_start and 1 or -1
	local slope = (row_end - row_start) / (col_end - col_start)

	for i = 0, distance do
		local row_float = row_start + (row_end - row_start) * i / distance
		local col = col_start + direction * i
		draw_diagonal_horizontal_block(row_float, col, row_start, col_start, row_end, col_end, slope)
	end
end


local function draw_diagonal_vertical_line(row_start, col_start, row_end, col_end, slope)
	local distance = math.abs(row_end - row_start)
	local direction = row_end > row_start and 1 or -1
	local slope = (row_end - row_start) / (col_end - col_start)

	for i = 0, distance do
		local row = row_start + direction * i
		local col_float = col_start + (col_end - col_start) * i / distance
		draw_diagonal_vertical_block(row, col_float, row_start, col_start, row_end, col_end, slope)
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

	if vertical_shift <= horizontal_shift then
		logging.debug("Drawing diagonal-horizontal line")
		draw_diagonal_horizontal_line(row_start, col_start, row_end, col_end)
		return
	end

	logging.debug("Drawing diagonal-vertical line")
	draw_diagonal_vertical_line(row_start, col_start, row_end, col_end)
end


M.clear = function()
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buffer_id, M.cursor_namespace, 0, -1)
end


return M
