local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local logging = require("smear_cursor.logging")
local round = require("smear_cursor.math").round
local screen = require("smear_cursor.screen")
local M = {}


local BOTTOM_BLOCKS = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " "}
local LEFT_BLOCKS   = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
local TOP_BLOCKS    = {" ", "▔", "🮂", "🮃", "▀", "🮄", "🮅", "🮆", "█"}
local RIGHT_BLOCKS  = {"█", "🮋", "🮊", "🮉", "▐", "🮈", "🮇", "▕", " "}
local MATRIX_CHARACTERS = {"▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█"}


-- Create a namespace for the extmarks
local cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")

local window_ids = {}
local n_active_windows = 0


local function draw_character_floating_window(row, col, character, hl_group, L)
	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")

	n_active_windows = n_active_windows + 1
	local window_id
	local buffer_id

	if #window_ids >= n_active_windows then
		-- Get existing window
		window_id = window_ids[n_active_windows]
		buffer_id = vim.api.nvim_win_get_buf(window_id)
		vim.api.nvim_win_set_config(window_id, {
			relative = "editor",
			row = row - 1,
			col = col - 1,
		})
	
	else
		-- Create new window
		buffer_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buffer_id, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buffer_id, "bufhidden", "wipe")
		vim.api.nvim_buf_set_option(buffer_id, "swapfile", false)

		window_id = vim.api.nvim_open_win(buffer_id, false, {
			relative = "editor",
			row = row - 1,
			col = col - 1,
			width = 1,
			height = 1,
			style = "minimal",
			focusable = false,
		})
		vim.api.nvim_win_set_option(window_id, "winhl", "Normal:Normal")

		table.insert(window_ids, window_id)
	end

	vim.api.nvim_win_set_option(window_id, "winblend", config.LEGACY_COMPUTING_SYMBOLS_SUPPORT and 100 or 0)
	vim.api.nvim_buf_set_extmark(buffer_id, cursor_namespace, 0, 0, {
		virt_text = {{character, hl_group}},
		virt_text_win_col = 0,
	})
end


local function clear_floating_windows(clear_extmarks)
	if clear_extmarks == nil then clear_extmarks = true end

	-- Hide the windows without deleting them
	for i = 1, n_active_windows do
		local window_id = window_ids[i]
		vim.api.nvim_win_set_option(window_id, "winblend", 100)

		if clear_extmarks then
			local buffer_id = vim.api.nvim_win_get_buf(window_id)
			vim.api.nvim_buf_clear_namespace(buffer_id, cursor_namespace, 0, -1)
		end

		vim.api.nvim_win_set_config(window_id, {
			relative = "editor",
			row = 0,
			col = 0,
		})
	end

	n_active_windows = 0
end


local function draw_character_extmark(screen_row, screen_col, character, hl_group, L)
	if L ~= nil and L.end_reached and screen_row == L.row_end_rounded and screen_col == L.col_end_rounded then
		return
	end
	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")

	local buffer_id, row, col = screen.screen_to_buffer(screen_row, screen_col)
	if buffer_id == nil then
		if config.USE_FLOATING_WINDOWS then
			draw_character_floating_window(screen_row, screen_col, character, hl_group, L)
		end
		return
	end

	-- Place new extmark with the determined position
	local success, extmark_id = pcall(function ()
		vim.api.nvim_buf_set_extmark(buffer_id, cursor_namespace, row - 1, 0, {
			virt_text = {{character, hl_group}},
			virt_text_win_col = col - 1,
		})
	end)

	if not success and config.USE_FLOATING_WINDOWS then
		draw_character_floating_window(screen_row, screen_col, character, hl_group, L)
	end
end


local function clear_extmarks()
	local buffer_ids = vim.api.nvim_list_bufs()

	for _, buffer_id in ipairs(buffer_ids) do
		vim.api.nvim_buf_clear_namespace(buffer_id, cursor_namespace, 0, -1)
	end
end


M.draw_character = draw_character_extmark


M.clear = function()
	clear_extmarks()
	clear_floating_windows(false)
end


local function draw_partial_block(row, col, character_list, character_index, hl_group, L)
	local character = character_list[character_index + 1]
	M.draw_character(row, col, character, hl_group, L)
end


local function draw_matrix_character(row, col, matrix, L)
	local bit_1 = math.ceil(matrix[1][1])
	local bit_2 = math.ceil(matrix[1][2])
	local bit_3 = math.ceil(matrix[2][1])
	local bit_4 = math.ceil(matrix[2][2])

	local index = bit_1 * 1 + bit_2 * 2 + bit_3 * 4 + bit_4 * 8
	if index == 0 then return end

	local character = MATRIX_CHARACTERS[index]
	local shade = matrix[1][1] + matrix[1][2] + matrix[2][1] + matrix[2][2]
	local max_shade = bit_1 + bit_2 + bit_3 + bit_4
	local hl_group_index = round(shade / max_shade * config.COLOR_LEVELS)
	if hl_group_index == 0 then return end

	M.draw_character(row, col, character, color.hl_groups[hl_group_index], L)
end


local function draw_vertically_shifted_block(row_float, col, L)
	local row = math.floor(row_float)
	local shift = row_float - row
	local micro_shift = shift * 8
	local character_index = round(micro_shift)

	if micro_shift > 7 then
		local shade = 1 - (micro_shift - 7)
		local hl_group_index = round(shade * config.COLOR_LEVELS)
		if hl_group_index > 0 then
			draw_partial_block(row, col, BOTTOM_BLOCKS, 7, color.hl_groups[hl_group_index], L)
		end

	elseif character_index < 8 then
		draw_partial_block(row, col, BOTTOM_BLOCKS, character_index, color.hl_group, L)
	end

	if micro_shift < 1 then
		local shade = micro_shift
		local hl_group_index = round(shade * config.COLOR_LEVELS)
		if hl_group_index > 0 then
			draw_partial_block(row + 1, col, BOTTOM_BLOCKS, 1, color.hl_groups_inverted[hl_group_index], L)
		end

	elseif character_index > 0 then
		if config.LEGACY_COMPUTING_SYMBOLS_SUPPORT then
			draw_partial_block(row + 1, col, TOP_BLOCKS, character_index, color.hl_group, L)
		else
			draw_partial_block(row + 1, col, BOTTOM_BLOCKS, character_index, color.hl_group_inverted, L)
		end
	end
end


local function draw_horizontally_shifted_block(row, col_float, L)
	local col = math.floor(col_float)
	local shift = col_float - col
	local micro_shift = shift * 8
	local character_index = round(micro_shift)


	if micro_shift > 7 then
		local shade = 1 - (micro_shift - 7)
		local hl_group_index = round(shade * config.COLOR_LEVELS)
		if hl_group_index > 0 then
			draw_partial_block(row, col, LEFT_BLOCKS, 7, color.hl_groups_inverted[hl_group_index], L)
		end

	elseif character_index < 8 then
		if config.LEGACY_COMPUTING_SYMBOLS_SUPPORT then
			draw_partial_block(row, col, RIGHT_BLOCKS, character_index, color.hl_group, L)
		else
			draw_partial_block(row, col, LEFT_BLOCKS, character_index, color.hl_group_inverted, L)
		end
	end

	if micro_shift < 1 then
		local shade = micro_shift
		local hl_group_index = round(shade * config.COLOR_LEVELS)
		if hl_group_index > 0 then
			draw_partial_block(row, col + 1, LEFT_BLOCKS, 1, color.hl_groups[hl_group_index], L)
		end

	elseif character_index > 0 then
		draw_partial_block(row, col + 1, LEFT_BLOCKS, character_index, color.hl_group, L)
	end
end


local function fill_matrix_vertically(matrix, col, row_float)
	local row = math.floor(row_float)
	local shift = row_float - row
	matrix[row][col] = math.max(matrix[row][col], 1 - shift)
	matrix[row + 1][col] = 1
	matrix[row + 2][col] = math.max(matrix[row + 2][col], shift)
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
		fill_matrix_vertically(m, 1, 3 + 2 * shift_left)
	end

	-- Lit from center
	fill_matrix_vertically(m, 1, 3 + 2 * shift)
	fill_matrix_vertically(m, 2, 3 + 2 * shift)

	-- Lit from the right
	if col < L.right then
		local shift_right = shift + 0.5 * L.slope
		fill_matrix_vertically(m, 2, 3 + 2 * shift_right)
	end

	for i = -1, 1 do
		local row_i = row + i
		draw_matrix_character(row_i, col, {m[2 * i + 3], m[2 * i + 4]}, L)
	end
end


local function fill_matrix_horizontally(matrix, row, col_float)
	local col = math.floor(col_float)
	local shift = col_float - col
	matrix[row][col] = math.min(matrix[row][col] + 1 - shift, 1)
	matrix[row][col + 1] = 1
	matrix[row][col + 2] = math.min(matrix[row][col + 2] + shift, 1)
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
		fill_matrix_horizontally(m, 1, 3 + 2 * shift_top)
	end

	-- Lit from center
	local half_row = round(shift * 2)
	fill_matrix_horizontally(m, 1, 3 + half_row)
	fill_matrix_horizontally(m, 2, 3 + half_row)

	-- Lit from the bottom
	if row < L.bottom then
		local shift_bottom = shift + 0.5 / L.slope
		fill_matrix_horizontally(m, 2, 3 + 2 * shift_bottom)
	end

	for i = -1, 1 do
		local col_i = col + i
		draw_matrix_character(row, col_i, {
			{m[1][2 * i + 3], m[1][2 * i + 4]},
			{m[2][2 * i + 3], m[2][2 * i + 4]}
		}, L)
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
	-- Apply correction to avoid jump before stop animating
	local correction = config.DISTANCE_STOP_ANIMATING + (1 - config.DISTANCE_STOP_ANIMATING) * L.shift
	local row_shift = L.row_shift * correction
	local col_shift = L.col_shift * correction

	-- Apply factors to reduce size of diagonal partial blocks
	row_shift = row_shift * (1 - math.abs(col_shift))
	col_shift = col_shift * (1 - math.abs(row_shift))

	draw_vertically_shifted_block(L.row_end_rounded - row_shift, L.col_end_rounded, L)
	draw_horizontally_shifted_block(L.row_end_rounded, L.col_end_rounded - col_shift, L)
end


M.draw_line = function(row_start, col_start, row_end, col_end, end_reached)
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
		end_reached = end_reached
	}

	L.top = math.min(L.row_start_rounded, L.row_end_rounded)
	L.bottom = math.max(L.row_start_rounded, L.row_end_rounded)
	L.left = math.min(L.col_start_rounded, L.col_end_rounded)
	L.right = math.max(L.col_start_rounded, L.col_end_rounded)
	L.row_direction = L.row_shift >= 0 and 1 or -1
	L.col_direction = L.col_shift >= 0 and 1 or -1
	L.slope = L.row_shift / L.col_shift
	L.slope_abs = math.abs(L.slope)
	L.shift = math.sqrt(L.row_shift^2 + L.col_shift^2)
	L.thickness = math.min(1 / L.shift, 1)

	if L.slope ~= L.slope then
		M.draw_character(L.row_end_rounded, L.col_end_rounded, "█", color.hl_group, L)
		return
	end

	if L.end_reached and L.shift < 1 then
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
