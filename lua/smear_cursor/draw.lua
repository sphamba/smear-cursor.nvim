local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local round = require("smear_cursor.math").round
local M = {}

-- stylua: ignore start
local BOTTOM_BLOCKS     = { "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " " }
local LEFT_BLOCKS       = { " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" }
local TOP_BLOCKS        = { " ", "▔", "🮂", "🮃", "▀", "🮄", "🮅", "🮆", "█" }
local RIGHT_BLOCKS      = { "█", "🮋", "🮊", "🮉", "▐", "🮈", "🮇", "▕", " " }
local MATRIX_CHARACTERS = { "▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█" }
-- stylua: ignore end

-- Create a namespace for the extmarks
local cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")
local can_hide = vim.fn.has("nvim-0.10") == 1
local extmark_id = 999

---@type table<number, {active:number, windows:{window_id:number, buffer_id:number}[]}>
local all_tab_windows = {}

-- Remove any invalid windows
function M.check_windows()
	for _, tab_windows in pairs(all_tab_windows) do
		tab_windows.windows = vim.tbl_filter(function(wb)
			return wb.window_id
				and vim.api.nvim_win_is_valid(wb.window_id)
				and wb.buffer_id
				and vim.api.nvim_buf_is_valid(wb.buffer_id)
		end, tab_windows.windows)
	end
end

---@param window_id number
---@param options vim.wo
local function set_window_options(window_id, options)
	if options == nil then
		return
	end

	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, { scope = "local", win = window_id })
	end
end

---@param buffer_id number
---@param options vim.bo
local function set_buffer_options(buffer_id, options)
	if options == nil then
		return
	end

	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, { buf = buffer_id })
	end
end

local function get_window(tab, row, col)
	all_tab_windows[tab] = all_tab_windows[tab] or { active = 0, windows = {} }
	local tab_windows = all_tab_windows[tab]

	tab_windows.active = tab_windows.active + 1
	local wb = tab_windows.windows[tab_windows.active]

	if wb then -- Window already exists
		---@type vim.api.keyset.win_config
		local window_config = { relative = "editor", row = row - 1, col = col - 1 }
		if can_hide then
			window_config.hide = false
		end
		vim.api.nvim_win_set_config(wb.window_id, window_config)
		return wb.window_id, wb.buffer_id
	end

	-- Create a new window
	local buffer_id = vim.api.nvim_create_buf(false, true)

	local window_id = vim.api.nvim_open_win(buffer_id, false, {
		relative = "editor",
		row = row - 1,
		col = col - 1,
		width = 1,
		height = 1,
		style = "minimal",
		focusable = false,
		noautocmd = true,
		zindex = 300,
	})

	local ei = vim.o.ei -- eventignore
	vim.o.ei = "all" -- ignore all events
	set_buffer_options(buffer_id, { buftype = "nofile", bufhidden = "wipe", swapfile = false })
	set_window_options(window_id, { winhighlight = "NormalFloat:Normal", winblend = 100 })
	vim.o.ei = ei
	tab_windows.windows[tab_windows.active] = { window_id = window_id, buffer_id = buffer_id }
	vim.api.nvim_create_autocmd("BufWipeout", { buffer = buffer_id, callback = vim.schedule_wrap(M.check_windows) })
	return window_id, buffer_id
end

M.draw_character = function(row, col, character, hl_group, L)
	if L ~= nil and L.end_reached and row == L.row_end_rounded and col == L.col_end_rounded then
		return
	end
	-- logging.debug("Drawing character " .. character .. " at (" .. row .. ", " .. col .. ")")
	local current_tab = vim.api.nvim_get_current_tabpage()
	local _, buffer_id = get_window(current_tab, row, col)

	vim.api.nvim_buf_set_extmark(buffer_id, cursor_namespace, 0, 0, {
		id = extmark_id, -- use a fixed extmark id
		virt_text = { { character, hl_group } },
		virt_text_win_col = 0,
	})
end

M.clear = function()
	-- Hide the windows without deleting them
	for tab, tab_windows in pairs(all_tab_windows) do
		for i = 1, tab_windows.active do
			local wb = tab_windows.windows[i]

			if wb and vim.api.nvim_win_is_valid(wb.window_id) then
				if can_hide then
					vim.api.nvim_win_set_config(wb.window_id, { hide = true })
				else
					vim.api.nvim_buf_del_extmark(wb.buffer_id, cursor_namespace, extmark_id)
					vim.api.nvim_win_set_config(wb.window_id, { relative = "editor", row = 0, col = 0 })
				end
			end
		end

		all_tab_windows[tab].active = 0
	end
end

local function draw_partial_block(row, col, character_list, character_index, hl_group, L)
	local character = character_list[character_index + 1]
	M.draw_character(row, col, character, hl_group, L)
end

local function draw_matrix_character(row, col, matrix, L)
	local threshold = config.diagonal_pixel_value_threshold
		* math.max(matrix[1][1], matrix[1][2], matrix[2][1], matrix[2][2])
	local bit_1 = (matrix[1][1] > threshold) and 1 or 0
	local bit_2 = (matrix[1][2] > threshold) and 1 or 0
	local bit_3 = (matrix[2][1] > threshold) and 1 or 0
	local bit_4 = (matrix[2][2] > threshold) and 1 or 0
	local index = bit_1 * 1 + bit_2 * 2 + bit_3 * 4 + bit_4 * 8
	if index == 0 then
		return
	end

	local character = MATRIX_CHARACTERS[index]
	local shade = matrix[1][1] + matrix[1][2] + matrix[2][1] + matrix[2][2]
	local max_shade = bit_1 + bit_2 + bit_3 + bit_4
	local hl_group_index = round(shade / max_shade * config.color_levels)
	hl_group_index = math.min(hl_group_index, config.color_levels)
	if hl_group_index == 0 then
		return
	end

	M.draw_character(row, col, character, color.hl_groups[hl_group_index], L)
end

local function draw_vertically_shifted_sub_block(row_top, row_bottom, col, L)
	if row_top >= row_bottom then
		return
	end
	-- logging.debug("top: " .. row_top .. ", bottom: " .. row_bottom .. ", col: " .. col)

	local row = math.floor(row_top)
	local center = (row_top + row_bottom) / 2 % 1
	local thickness = row_bottom - row_top
	local character_list, character_index, hl_group

	if center < 0.5 then
		local micro_shift = center * 16
		character_index = math.ceil(micro_shift)
		if character_index == 0 then
			return
		end

		local character_thickness = character_index / 8
		local shade = thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		if config.legacy_computing_symbols_support then
			character_list = TOP_BLOCKS
			hl_group = color.hl_groups[hl_group_index]
		else
			character_list = BOTTOM_BLOCKS
			hl_group = color.hl_groups_inverted[hl_group_index]
		end
	else
		local micro_shift = center * 16 - 8
		character_index = math.floor(micro_shift)
		if character_index == 8 then
			return
		end

		local character_thickness = 1 - character_index / 8
		local shade = thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		character_list = BOTTOM_BLOCKS
		hl_group = color.hl_groups[hl_group_index]
	end

	draw_partial_block(row, col, character_list, character_index, hl_group, L)
end

local function draw_vertically_shifted_block(row_float, col, L)
	local top = row_float + 0.5 - L.thickness / 2
	local bottom = top + L.thickness
	local row = math.floor(top)

	draw_vertically_shifted_sub_block(top, math.min(bottom, row + 1), col, L)
	draw_vertically_shifted_sub_block(row + 1, bottom, col, L)
end

local function draw_horizontally_shifted_sub_block(row, col_left, col_right, L)
	if col_left >= col_right then
		return
	end
	-- logging.debug("row: " .. row .. ", left: " .. col_left .. ", right: " .. col_right)

	local col = math.floor(col_left)
	local center = (col_left + col_right) / 2 % 1
	local thickness = col_right - col_left
	local character_list, character_index, hl_group

	if center < 0.5 then
		local micro_shift = center * 16
		character_index = math.ceil(micro_shift)
		if character_index == 0 then
			return
		end

		local character_thickness = character_index / 8
		local shade = thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		character_list = LEFT_BLOCKS
		hl_group = color.hl_groups[hl_group_index]
	else
		local micro_shift = center * 16 - 8
		character_index = math.floor(micro_shift)
		if character_index == 8 then
			return
		end

		local character_thickness = 1 - character_index / 8
		local shade = thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		if config.legacy_computing_symbols_support then
			character_list = RIGHT_BLOCKS
			hl_group = color.hl_groups[hl_group_index]
		else
			character_list = LEFT_BLOCKS
			hl_group = color.hl_groups_inverted[hl_group_index]
		end
	end

	draw_partial_block(row, col, character_list, character_index, hl_group, L)
end

local function draw_horizontally_shifted_block(row, col_float, L)
	local left = col_float + 0.5 - L.thickness / 2
	local right = left + L.thickness
	local col = math.floor(left)

	draw_horizontally_shifted_sub_block(row, left, math.min(right, col + 1), L)
	draw_horizontally_shifted_sub_block(row, col + 1, right, L)
end

local function fill_matrix_vertical_sub_block(matrix, row_top, row_bottom, col)
	if row_top >= row_bottom then
		return
	end
	local row = math.floor(row_top)
	if row < 1 or row > #matrix then
		return
	end
	local shade = row_bottom - row_top
	matrix[row][col] = math.max(matrix[row][col], shade)
end

local function fill_matrix_vertically(matrix, row_float, col, thickness)
	local top = row_float + 1 - thickness * config.diagonal_thickness_factor
	local bottom = top + 2 * thickness * config.diagonal_thickness_factor
	local row = math.floor(top)
	-- logging.debug("top: " .. top .. ", bottom: " .. bottom)

	fill_matrix_vertical_sub_block(matrix, top, math.min(bottom, row + 1), col)
	fill_matrix_vertical_sub_block(matrix, row + 1, math.min(bottom, row + 2), col)
	fill_matrix_vertical_sub_block(matrix, row + 2, bottom, col)
end

local function draw_diagonal_horizontal_block(row_float, col, L)
	local row = math.floor(row_float)
	local shift = row_float - row
	-- Matrix of lit quarters
	local m = {
		{ 0, 0 }, -- Top of row above
		{ 0, 0 }, -- Bottom of row above
		{ 0, 0 }, -- Top of current row
		{ 0, 0 }, -- Bottom of current row
		{ 0, 0 }, -- Top of row below
		{ 0, 0 }, -- Bottom of row below
	}

	-- Lit from the left
	if col > L.left then
		local shift_left = shift - 0.5 * L.slope
		fill_matrix_vertically(m, 3 + 2 * shift_left, 1, L.thickness)
	end

	-- Lit from center
	fill_matrix_vertically(m, 3 + 2 * shift, 1, L.thickness)
	fill_matrix_vertically(m, 3 + 2 * shift, 2, L.thickness)

	-- Lit from the right
	if col < L.right then
		local shift_right = shift + 0.5 * L.slope
		fill_matrix_vertically(m, 3 + 2 * shift_right, 2, L.thickness)
	end

	for i = -1, 1 do
		local row_i = row + i
		draw_matrix_character(row_i, col, { m[2 * i + 3], m[2 * i + 4] }, L)
	end
end

local function fill_matrix_horizontal_sub_block(matrix, row, col_left, col_right)
	if col_left >= col_right then
		return
	end
	local col = math.floor(col_left)
	if col < 1 or col > #matrix[1] then
		return
	end
	local shade = col_right - col_left
	matrix[row][col] = math.max(matrix[row][col], shade)
end

local function fill_matrix_horizontally(matrix, row, col_float, thickness)
	local left = col_float + 1 - thickness * config.diagonal_thickness_factor
	local right = left + 2 * thickness * config.diagonal_thickness_factor
	local col = math.floor(left)
	-- logging.debug("left: " .. left .. ", right: " .. right)

	fill_matrix_horizontal_sub_block(matrix, row, left, math.min(right, col + 1))
	fill_matrix_horizontal_sub_block(matrix, row, col + 1, math.min(right, col + 2))
	fill_matrix_horizontal_sub_block(matrix, row, col + 2, right)
end

local function draw_diagonal_vertical_block(row, col_float, L)
	local col = math.floor(col_float)
	local shift = col_float - col
	-- Matrix of lit quarters
	local m = {
		{ 0, 0, 0, 0, 0, 0 }, -- Top
		{ 0, 0, 0, 0, 0, 0 }, -- Bottom
	} -- c-1    c    c+1

	-- Lit from the top
	if row > L.top then
		local shift_top = shift - 0.5 / L.slope
		fill_matrix_horizontally(m, 1, 3 + 2 * shift_top, L.thickness)
	end

	-- Lit from center
	local half_row = round(shift * 2)
	fill_matrix_horizontally(m, 1, 3 + half_row, L.thickness)
	fill_matrix_horizontally(m, 2, 3 + half_row, L.thickness)

	-- Lit from the bottom
	if row < L.bottom then
		local shift_bottom = shift + 0.5 / L.slope
		fill_matrix_horizontally(m, 2, 3 + 2 * shift_bottom, L.thickness)
	end

	for i = -1, 1 do
		local col_i = col + i
		draw_matrix_character(row, col_i, {
			{ m[1][2 * i + 3], m[1][2 * i + 4] },
			{ m[2][2 * i + 3], m[2][2 * i + 4] },
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
	local correction = config.distance_stop_animating + (1 - config.distance_stop_animating) * L.shift
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
		end_reached = end_reached,
	}

	L.top = math.min(L.row_start_rounded, L.row_end_rounded)
	L.bottom = math.max(L.row_start_rounded, L.row_end_rounded)
	L.left = math.min(L.col_start_rounded, L.col_end_rounded)
	L.right = math.max(L.col_start_rounded, L.col_end_rounded)
	L.row_direction = L.row_shift >= 0 and 1 or -1
	L.col_direction = L.col_shift >= 0 and 1 or -1
	L.slope = L.row_shift / L.col_shift
	L.slope_abs = math.abs(L.slope)
	L.shift = math.sqrt(L.row_shift ^ 2 + L.col_shift ^ 2)
	L.thickness = math.min(1 / L.shift, 1) ^ config.thickness_reduction_exponent
	L.thickness = math.max(L.thickness, config.minimum_thickness)

	if L.slope ~= L.slope then
		M.draw_character(L.row_end_rounded, L.col_end_rounded, "█", color.hl_group, L)
		return
	end

	if L.end_reached and L.shift < 1 then
		draw_ending(L)
		return
	end

	if L.slope_abs <= config.max_slope_horizontal then
		-- logging.debug("Drawing horizontal-ish line")
		-- if math.abs(L.row_shift) > 1 then
		-- 	-- Avoid bulging on thin lines
		-- 	L.thickness = math.max(L.thickness, 1)
		-- end
		draw_horizontal_ish_line(L, draw_vertically_shifted_block)
		return
	end

	if L.slope_abs >= config.min_slope_vertical then
		-- logging.debug("Drawing vertical-ish line")
		-- if math.abs(L.col_shift) > 1 then
		-- 	-- Avoid bulging on thin lines
		-- 	L.thickness = math.max(L.thickness, 1)
		-- end
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
