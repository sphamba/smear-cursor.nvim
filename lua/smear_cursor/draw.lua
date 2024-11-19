local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local screen = require("smear_cursor.screen")
local M = {}


BOTTOM_BLOCKS = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " "}
LEFT_BLOCKS   = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
MATRIX_CHARACTERS = {"▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█"}


-- Create buffer and floating window
local buffer_id = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(buffer_id, "buftype", "nofile")
vim.api.nvim_buf_set_option(buffer_id, "bufhidden", "wipe")
vim.api.nvim_buf_set_option(buffer_id, "swapfile", false)

local window_id = vim.api.nvim_open_win(buffer_id, false, {
	relative = "editor",
	row = 0,
	col = 0,
	width = 1,
	height = 1,
	style = "minimal",
	focusable = false,
})
vim.api.nvim_win_set_option(window_id, "winblend", 30)
vim.api.nvim_win_set_option(window_id, "winhl", "Normal:" .. color.hl_group)


-- Create a namespace for the extmarks
M.cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")


local function draw_character_extmark(screen_row, screen_col, character, hl_group, L)
	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")

	local buffer_id, row, col = screen.screen_to_buffer(screen_row, screen_col)
	if buffer_id == nil then
		return
	end

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
end


local function clear_extmarks()
	local buffer_ids = vim.api.nvim_list_bufs()

	for _, buffer_id in ipairs(buffer_ids) do
		vim.api.nvim_buf_clear_namespace(buffer_id, M.cursor_namespace, 0, -1)
	end
end


local function draw_character_floating_window(row, col, character, hl_group, L)
	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")
	
	-- TODO: Find a better way to handle inverted colors, which don't work with winblend
	-- if hl_group == color.hl_group_inverted then
	-- 	draw_character_extmark(row, col, character, hl_group, L)
	-- 	return
	-- end

	pcall(function ()
		vim.api.nvim_buf_set_extmark(
			buffer_id,
			M.cursor_namespace,
			row - L.top + 1,
			0,
			{
				virt_text = {{character, hl_group}},
				virt_text_win_col = col - L.left + 1,
			}
		)
	end)
end


local function clear_floating_window(new_height)
	if new_height == nil then
		new_height = 1
	end 

	local empty_lines = {}
	for i = 1, new_height do
		table.insert(empty_lines, "")
	end
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, empty_lines)
end


if config.USE_FLOATING_WINDOWS then
	M.draw_character = draw_character_floating_window
	M.clear = function()
		clear_extmarks()
		clear_floating_window()
	end
else
	M.draw_character = draw_character_extmark
	M.clear = clear_extmarks
end


local function draw_partial_block(row, col, character_list, character_index, hl_group, L)
	local character = character_list[character_index + 1]
	M.draw_character(row, col, character, hl_group, L)
end


local function draw_matrix_character(row, col, matrix, L)
	local index = matrix[1][1] * 1 + matrix[1][2] * 2 + matrix[2][1] * 4 + matrix[2][2] * 8
	if index == 0 then return end
	local character = MATRIX_CHARACTERS[index]
	M.draw_character(row, col, character, color.hl_group, L)
end


local function draw_vertically_shifted_block(row_float, col, L)
	local row = math.floor(row_float)
	local shift = row_float - row
	local character_index = round(shift * 8)

	if character_index < 8 and (not L.skip_end or row ~= L.row_end_rounded or col ~= L.col_end_rounded) then
		draw_partial_block(row, col, BOTTOM_BLOCKS, character_index, color.hl_group, L)
	end

	if character_index > 0 and (not L.skip_end or row + 1 ~= L.row_end_rounded or col ~= L.col_end_rounded) then
		draw_partial_block(row + 1, col, BOTTOM_BLOCKS, character_index, color.hl_group_inverted, L)
	end
end


local function draw_horizontally_shifted_block(row, col_float, L)
	local col = math.floor(col_float)
	local shift = col_float - col
	local character_index = round(shift * 8)

	if character_index < 7 and (not L.skip_end or row ~= L.row_end_rounded or col ~= L.col_end_rounded) then
		draw_partial_block(row, col, LEFT_BLOCKS, character_index, color.hl_group_inverted, L)
	end

	if character_index > 0 and (not L.skip_end or row ~= L.row_end_rounded or col + 1 ~= L.col_end_rounded) then
		draw_partial_block(row, col + 1, LEFT_BLOCKS, character_index, color.hl_group, L)
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
	if col > L.left then
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
	if col < L.right then
		local shift_right = shift + 0.5 * L.slope
		local half_row_right = round(shift_right * 2)
		m[3 + half_row_right][2] = 1
		m[4 + half_row_right][2] = 1
	end

	for i = -1, 1 do
		local row_i = row + i
		if not L.skip_end or row_i ~= L.row_end_rounded or col ~= L.col_end_rounded then
		-- Equivalent to `not (skip_end and row_i == row_end_rounded and col == col_end_rounded)`
			draw_matrix_character(row_i, col, {m[2 * i + 3], m[2 * i + 4]}, L)
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
	if row > L.top then
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
	if row < L.bottom then
		local shift_bottom = shift + 0.5 / L.slope
		local half_row_bottom = round(shift_bottom * 2)
		m[2][3 + half_row_bottom] = 1
		m[2][4 + half_row_bottom] = 1
	end

	for i = -1, 1 do
		local col_i = col + i
		if (not L.skip_end or row ~= L.row_end_rounded or col_i ~= L.col_end_rounded) then
		-- Equivalent to `if not (skip_end and row == row_end_rounded and col_i == col_end_rounded)`
			draw_matrix_character(row, col_i, {
				{m[1][2 * i + 3], m[1][2 * i + 4]},
				{m[2][2 * i + 3], m[2][2 * i + 4]}
			}, L)
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


local function draw_ending(L)
	-- Apply factors to reduce size of diagonal partial blocks
	local row_shift = L.row_shift * (1 - math.abs(L.col_shift))
	local col_shift = L.col_shift * (1 - math.abs(L.row_shift))
	draw_vertically_shifted_block(L.row_end_rounded - row_shift, L.col_end_rounded, L)
	draw_horizontally_shifted_block(L.row_end_rounded, L.col_end_rounded - col_shift, L)
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

	L.top = math.min(L.row_start_rounded, L.row_end_rounded)
	L.bottom = math.max(L.row_start_rounded, L.row_end_rounded)
	L.left = math.min(L.col_start_rounded, L.col_end_rounded)
	L.right = math.max(L.col_start_rounded, L.col_end_rounded)
	L.row_direction = L.row_shift >= 0 and 1 or -1
	L.col_direction = L.col_shift >= 0 and 1 or -1
	L.slope = L.row_shift / L.col_shift
	L.slope_abs = math.abs(L.slope)

	if config.USE_FLOATING_WINDOWS then
		-- Set a window with 1-padding around the line
		local width = L.right - L.left + 1
		local height = L.bottom - L.top + 1

		vim.api.nvim_win_set_config(window_id, {
			relative = "editor",
			row = L.top - 2,
			col = L.left - 2,
			width = width + 2,
			height = height + 2,
		})

		clear_floating_window(height + 2)
	end

	if L.slope ~= L.slope then
		if not L.skip_end then
			M.draw_character(L.row_end_rounded, L.col_end_rounded, "█", color.hl_group, L)
		end
		return
	end

	if L.skip_end and L.row_shift^2 + L.col_shift^2 < 1 then
		draw_ending(L)
		return
	end

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


return M
