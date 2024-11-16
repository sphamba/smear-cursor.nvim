local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local M = {}


BOTTOM_BLOCKS = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " "}
LEFT_BLOCKS   = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
MATRIX_CHARACTERS = {"▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█"}


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
		logging.debug("Failed to draw character at (" .. row .. ", " .. col .. ")")
	end

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


local function draw_partial_block(row, col, character_list, character_index, hl_group)
	local character = character_list[character_index + 1]
	draw_character(row, col, character, hl_group)
end


local function draw_matrix_character(row, col, matrix)
	local index = matrix[1][1] * 1 + matrix[1][2] * 2 + matrix[2][1] * 4 + matrix[2][2] * 8
	if index == 0 then return end
	local character = MATRIX_CHARACTERS[index]
	draw_character(row, col, character)
end


local function draw_vertically_shifted_block(row_float, col, L)
	if L.skip_end and col == L.col_end_rounded then return end

	local row = math.floor(row_float)
	local shift = row_float - row
	local character_index = round(shift * 8)

	if character_index < 8 then
		draw_partial_block(row, col, BOTTOM_BLOCKS, character_index, color.hl_group)
	end

	if character_index > 0 then
		draw_partial_block(row + 1, col, BOTTOM_BLOCKS, character_index, color.hl_group_inverted)
	end
end


local function draw_horizontally_shifted_block(row, col_float, L)
	if L.skip_end and row == L.row_end_rounded then return end

	local col = math.floor(col_float)
	local shift = col_float - col
	local character_index = round(shift * 8)

	if character_index < 7 then
		draw_partial_block(row, col, LEFT_BLOCKS, character_index, color.hl_group_inverted)
	end

	if character_index > 0 then
		draw_partial_block(row, col + 1, LEFT_BLOCKS, character_index, color.hl_group)
	end
end


local function draw_diagonal_horizontal_block(row_float, col, L)
	local row = round(row_float)
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
	if col ~= L.left then
		local shift_left = shift - 0.5 * L.slope
		local half_row_left = round(shift_left * 2)
		m[3 + half_row_left][1] = 1
		m[4 + half_row_left][1] = 1
	end

	-- Lit from center
	local half_row = round(shift * 2)
	m[3 + half_row][1] = 1
	m[4 + half_row][1] = 1
	m[3 + half_row][2] = 1
	m[4 + half_row][2] = 1

	-- Lit from the right
	if col ~= L.right then
		local shift_right = shift + 0.5 * L.slope
		local half_row_right = round(shift_right * 2)
		m[3 + half_row_right][2] = 1
		m[4 + half_row_right][2] = 1
	end

	for i = -1, 1 do
		local row_i = row + i
		if not L.skip_end or row_i ~= L.row_end or col ~= L.col_end then
		-- Equivalent to `not (skip_end and row_i == row_end and col == col_end)`
			draw_matrix_character(row_i, col, {m[2 * i + 3], m[2 * i + 4]})
		end
	end
end


local function draw_diagonal_vertical_block(row, col_float, L)
	local col = round(col_float)
	local shift = col_float - col
	-- Matrix of lit quarters
	local m = {
		{0, 0, 0, 0, 0, 0}, -- Top
		{0, 0, 0, 0, 0, 0}  -- Bottom
	} -- c-1    c    c+1

	-- Lit from the top
	if row ~= L.top then
		local shift_top = shift - 0.5 / L.slope
		local half_row_top = round(shift_top * 2)
		m[1][3 + half_row_top] = 1
		m[1][4 + half_row_top] = 1
	end

	-- Lit from center
	local half_row = round(shift * 2)
	m[1][3 + half_row] = 1
	m[1][4 + half_row] = 1
	m[2][3 + half_row] = 1
	m[2][4 + half_row] = 1

	-- Lit from the bottom
	if row ~= L.bottom then
		local shift_bottom = shift + 0.5 / L.slope
		local half_row_bottom = round(shift_bottom * 2)
		m[2][3 + half_row_bottom] = 1
		m[2][4 + half_row_bottom] = 1
	end

	for i = -1, 1 do
		local col_i = col + i
		if not L.skip_end or row ~= L.row_end or col_i ~= L.col_end then
		-- Equivalent to `if not (skip_end and row == row_end and col_i == col_end)`
			draw_matrix_character(row, col_i, {
				{m[1][2 * i + 3], m[1][2 * i + 4]},
				{m[2][2 * i + 3], m[2][2 * i + 4]}
			})
		end
	end
end


local function draw_horizontal_ish_line(L, draw_block_function)
	for col = L.col_start_rounded, L.col_end_rounded, L.col_direction do
		local row_float = L.row_start + L.row_shift * (col - L.col_start) / L.col_shift
		draw_block_function(row_float, col, L)
	end
end


local function draw_vertical_ish_line(L, draw_block_function)
	for row = L.row_start_rounded, L.row_end_rounded, L.row_direction do
		local col_float = L.col_start + L.col_shift * (row - L.row_start) / L.row_shift
		draw_block_function(row, col_float, L)
	end
end


M.draw_line = function(row_start, col_start, row_end, col_end, skip_end)
	-- logging.debug("Drawing line from (" .. row_start .. ", " .. col_start .. ") to (" .. row_end .. ", " .. col_end .. ")")

	local L = {
		row_start = row_start,
		col_start = col_start,
		row_end = row_end,
		col_end = col_end,
		row_start_rounded = round(row_start),
		col_start_rounded = round(col_start),
		row_end_rounded = round(row_end),
		col_end_rounded = round(col_end),
		row_shift = row_end - row_start,
		col_shift = col_end - col_start,
		skip_end = skip_end
	}

	L.left = math.min(L.col_start, L.col_end)
	L.right = math.max(L.col_start, L.col_end)
	L.top = math.min(L.row_start, L.row_end)
	L.bottom = math.max(L.row_start, L.row_end)
	L.row_direction = L.row_shift >= 0 and 1 or -1
	L.col_direction = L.col_shift >= 0 and 1 or -1
	L.slope = L.row_shift / L.col_shift
	L.slope_abs = math.abs(L.slope)

	if L.slope_abs <= config.MAX_SLOPE_HORIZONTAL then
		-- logging.debug("Drawing horizontal-ish line")
		draw_horizontal_ish_line(L, draw_vertically_shifted_block)
		return
	end

	if L.slope_abs >= config.MIN_SLOPE_VERTICAL then
		-- logging.debug("Drawing vertical-ish line")
		draw_vertical_ish_line(L, draw_horizontally_shifted_block)
		return
	end

	if L.slope_abs <= 1 then
		-- logging.debug("Drawing diagonal-horizontal line")
		draw_horizontal_ish_line(L, draw_diagonal_horizontal_block)
		return
	end

	-- logging.debug("Drawing diagonal-vertical line")
	draw_vertical_ish_line(L, draw_diagonal_vertical_block)
end


M.clear = function()
	local buffer_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buffer_id, M.cursor_namespace, 0, -1)
end


return M
