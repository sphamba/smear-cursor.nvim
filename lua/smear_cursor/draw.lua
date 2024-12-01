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

M.draw_character = function(row, col, character, hl_group)
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

local function draw_partial_block(row, col, character_list, character_index, hl_group)
	local character = character_list[character_index + 1]
	M.draw_character(row, col, character, hl_group)
end

local function draw_matrix_character(row, col, matrix)
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

	M.draw_character(row, col, character, color.get_hl_group({ level = hl_group_index }))
end

local function draw_vertically_shifted_sub_block(row_top, row_bottom, col, shade)
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
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		if config.legacy_computing_symbols_support then
			character_list = TOP_BLOCKS
			hl_group = color.get_hl_group({ level = hl_group_index })
		else
			character_list = BOTTOM_BLOCKS
			hl_group = color.get_hl_group({ level = hl_group_index, inverted = true })
		end
	else
		local micro_shift = center * 16 - 8
		character_index = math.floor(micro_shift)
		if character_index == 8 then
			return
		end

		local character_thickness = 1 - character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		character_list = BOTTOM_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	end

	draw_partial_block(row, col, character_list, character_index, hl_group)
end

local function draw_horizontally_shifted_sub_block(row, col_left, col_right, shade)
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
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		character_list = LEFT_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	else
		local micro_shift = center * 16 - 8
		character_index = math.floor(micro_shift)
		if character_index == 8 then
			return
		end

		local character_thickness = 1 - character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then
			return
		end

		if config.legacy_computing_symbols_support then
			character_list = RIGHT_BLOCKS
			hl_group = color.get_hl_group({ level = hl_group_index })
		else
			character_list = LEFT_BLOCKS
			hl_group = color.get_hl_group({ level = hl_group_index, inverted = true })
		end
	end

	draw_partial_block(row, col, character_list, character_index, hl_group)
end

M.draw_quad = function(corners, target_position)
	if target_position == nil then
		target_position = { 0, 0 }
	end

	local slopes = {}

	for i = 1, 4 do
		local edge = {
			corners[i % 4 + 1][1] - corners[i][1],
			corners[i % 4 + 1][2] - corners[i][2],
		}
		slopes[i] = edge[1] / edge[2]
	end

	local top = math.floor(math.min(corners[1][1], corners[2][1], corners[3][1], corners[4][1]))
	local bottom = math.ceil(math.max(corners[1][1], corners[2][1], corners[3][1], corners[4][1])) - 1

	for row = top, bottom do
		local left = corners[4][2] + (row + 0.5 - corners[4][1]) / slopes[4]
		left = left - 0.5 / math.abs(slopes[4])
		local right = corners[2][2] + (row + 0.5 - corners[2][1]) / slopes[2]
		right = right + 0.5 / math.abs(slopes[2])

		for col = math.floor(left), math.ceil(right) do
			-- Check if on target
			if row == target_position[1] and col == target_position[2] then
				goto continue
			end

			-- Intersection of quad edge with centerline of cell
			local top_centerline = corners[1][1] + (col + 0.5 - corners[1][2]) * slopes[1]
			-- Lowest intersection of quad edge with lateral edges of cell
			local top_intersection = top_centerline + 0.5 * math.abs(slopes[1])
			local right_centerline = corners[2][2] + (row + 0.5 - corners[2][1]) / slopes[2]
			local right_intersection = right_centerline - 0.5 / math.abs(slopes[2])
			local bottom_centerline = corners[3][1] + (col + 0.5 - corners[3][2]) * slopes[3]
			local bottom_intersection = bottom_centerline - 0.5 * math.abs(slopes[3])
			local left_centerline = corners[4][2] + (row + 0.5 - corners[4][1]) / slopes[4]
			local left_intersection = left_centerline + 0.5 / math.abs(slopes[4])

			local is_vertically_shifted = false
			local vertical_shade = 1
			local is_horizontally_shifted = false
			local horizontal_shade = 1

			-- Check if vertically shifted block
			local top_horizontal = math.abs(slopes[1]) <= config.max_slope_horizontal
			local bottom_horizontal = math.abs(slopes[3]) <= config.max_slope_horizontal
			local left_in = left_intersection > col
			local left_vertical = math.abs(slopes[4]) >= config.min_slope_vertical
			local right_in = right_intersection < col + 1
			local right_vertical = math.abs(slopes[2]) >= config.min_slope_vertical
			if not (left_in and not left_vertical) and not (right_in and not right_vertical) then
				local top_near = top_centerline > row
				local bottom_near = bottom_centerline < row + 1
				if
					(top_near and top_horizontal and (not bottom_near or bottom_horizontal))
					or (bottom_near and bottom_horizontal and (not top_near or top_horizontal))
				then
					is_vertically_shifted = true
					vertical_shade = math.min(row + 1, bottom_centerline) - math.max(row, top_centerline)
				end
			end

			-- Check if horizontally shifted block
			local top_in = top_intersection > row
			local bottom_in = bottom_intersection < row + 1
			if not (top_in and not top_horizontal) and not (bottom_in and not bottom_horizontal) then
				local left_near = left_centerline > col
				local right_near = right_centerline < col + 1
				if
					(left_near and left_vertical and (not right_near or right_vertical))
					or (right_near and right_vertical and (not left_near or left_vertical))
				then
					is_horizontally_shifted = true
					horizontal_shade = math.min(col + 1, right_centerline) - math.max(col, left_centerline)
				end
			end

			-- Draw shifted block
			if is_vertically_shifted and is_horizontally_shifted then
				if vertical_shade < 0.75 and horizontal_shade < 0.75 then
					goto continue
				elseif vertical_shade < horizontal_shade then
					is_horizontally_shifted = false
				else
					is_vertically_shifted = false
				end
			end

			if is_vertically_shifted and horizontal_shade > 0 then
				draw_vertically_shifted_sub_block(
					math.max(row, top_centerline),
					math.min(row + 1, bottom_centerline),
					col,
					horizontal_shade
				)
				goto continue
			end

			if is_horizontally_shifted and vertical_shade > 0 then
				draw_horizontally_shifted_sub_block(
					row,
					math.max(col, left_centerline),
					math.min(col + 1, right_centerline),
					vertical_shade
				)
				goto continue
			end

			-- Draw matrix
			local row_float, col_float, matrix_index, shade
			local matrix = {
				{ 1, 1 },
				{ 1, 1 },
			}

			for i = 1, 2 do
				local shift = (i == 1) and -0.25 or 0.25

				-- Intersection with top quad edge
				row_float = top_centerline + shift * slopes[1]
				row_float = 2 * (row_float - row)
				matrix_index = math.floor(row_float) + 1
				for index = 1, math.min(2, matrix_index - 1) do
					matrix[index][i] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = 1 - (row_float % 1)
					matrix[matrix_index][i] = matrix[matrix_index][i] * shade
				end

				-- Intersection with right quad edge
				col_float = right_centerline + shift / slopes[2]
				col_float = 2 * (col_float - col)
				matrix_index = math.floor(col_float) + 1
				for index = math.max(1, matrix_index + 1), 2 do
					matrix[i][index] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = col_float % 1
					matrix[i][matrix_index] = matrix[i][matrix_index] * shade
				end

				-- Intersection with bottom quad edge
				row_float = bottom_centerline + shift * slopes[3]
				row_float = 2 * (row_float - row)
				matrix_index = math.floor(row_float) + 1
				for index = math.max(1, matrix_index + 1), 2 do
					matrix[index][i] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = row_float % 1
					matrix[matrix_index][i] = matrix[matrix_index][i] * shade
				end

				-- Intersection with left quad edge
				col_float = left_centerline + shift / slopes[4]
				col_float = 2 * (col_float - col)
				matrix_index = math.floor(col_float) + 1
				for index = 1, math.min(2, matrix_index - 1) do
					matrix[i][index] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = 1 - (col_float % 1)
					matrix[i][matrix_index] = matrix[i][matrix_index] * shade
				end
			end

			draw_matrix_character(row, col, matrix)

			::continue::
		end
	end
end

return M
