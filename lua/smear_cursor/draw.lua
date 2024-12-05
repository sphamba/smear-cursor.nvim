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

---@param window_id number
---@param options vim.wo
local function set_window_options(window_id, options)
	if options == nil then return end

	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, { scope = "local", win = window_id })
	end
end

---@param buffer_id number
---@param options vim.bo
local function set_buffer_options(buffer_id, options)
	if options == nil then return end

	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, { buf = buffer_id })
	end
end

local function get_window(tab, row, col)
	all_tab_windows[tab] = all_tab_windows[tab] or { active = 0, windows = {} }
	local tab_windows = all_tab_windows[tab]

	-- Find existing window
	tab_windows.active = tab_windows.active + 1
	while tab_windows.active <= #tab_windows.windows do
		local wb = tab_windows.windows[tab_windows.active]

		if vim.api.nvim_win_is_valid(wb.window_id) and vim.api.nvim_buf_is_valid(wb.buffer_id) then
			---@type vim.api.keyset.win_config
			local window_config = { relative = "editor", row = row - 1, col = col - 1 }
			if can_hide then window_config.hide = false end
			vim.api.nvim_win_set_config(wb.window_id, window_config)
			return wb.window_id, wb.buffer_id
		end

		-- Remove invalid window
		table.remove(tab_windows.windows, tab_windows.active)
	end

	-- Create a new window
	local ei = vim.o.ei -- eventignore
	vim.o.ei = "all" -- ignore all events

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

	set_buffer_options(
		buffer_id,
		{ buftype = "nofile", filetype = "smear-cursor", bufhidden = "wipe", swapfile = false }
	)
	set_window_options(window_id, { winhighlight = "NormalFloat:Normal", winblend = 100 })
	vim.o.ei = ei
	tab_windows.windows[tab_windows.active] = { window_id = window_id, buffer_id = buffer_id }

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
	for tab, tab_windows in pairs(all_tab_windows) do
		-- Hide windows without deleting them
		for i = 1, math.min(tab_windows.active, config.max_kept_windows) do
			local wb = tab_windows.windows[i]

			if wb and vim.api.nvim_win_is_valid(wb.window_id) then
				vim.api.nvim_buf_del_extmark(wb.buffer_id, cursor_namespace, extmark_id)
				if can_hide then
					vim.api.nvim_win_set_config(wb.window_id, { hide = true })
				else
					vim.api.nvim_win_set_config(wb.window_id, { relative = "editor", row = 0, col = 0 })
				end
			end
		end

		all_tab_windows[tab].active = 0

		-- Delete supplementary windows
		local ei = vim.o.ei -- eventignore
		vim.o.ei = "all" -- ignore all events
		for i = config.max_kept_windows + 1, #tab_windows.windows do
			local wb = tab_windows.windows[i]

			if wb and vim.api.nvim_win_is_valid(wb.window_id) then vim.api.nvim_win_close(wb.window_id, true) end

			tab_windows.windows[i] = nil
		end
		vim.o.ei = ei
	end
end

local function draw_partial_block(row, col, character_list, character_index, hl_group)
	local character = character_list[character_index + 1]
	M.draw_character(row, col, character, hl_group)
end

local function draw_matrix_character(row, col, matrix)
	local max = math.max(matrix[1][1], matrix[1][2], matrix[2][1], matrix[2][2])
	if max < config.matrix_pixel_threshold then return end
	local threshold = max * config.matrix_pixel_min_factor
	local bit_1 = (matrix[1][1] > threshold) and 1 or 0
	local bit_2 = (matrix[1][2] > threshold) and 1 or 0
	local bit_3 = (matrix[2][1] > threshold) and 1 or 0
	local bit_4 = (matrix[2][2] > threshold) and 1 or 0
	local index = bit_1 * 1 + bit_2 * 2 + bit_3 * 4 + bit_4 * 8
	if index == 0 then return end

	local character = MATRIX_CHARACTERS[index]
	local shade = matrix[1][1] + matrix[1][2] + matrix[2][1] + matrix[2][2]
	local max_shade = bit_1 + bit_2 + bit_3 + bit_4
	local hl_group_index = round(shade / max_shade * config.color_levels)
	hl_group_index = math.min(hl_group_index, config.color_levels)
	if hl_group_index == 0 then return end

	M.draw_character(row, col, character, color.get_hl_group({ level = hl_group_index }))
end

local function draw_vertically_shifted_sub_block(row_top, row_bottom, col, shade)
	if row_top >= row_bottom then return end
	-- logging.debug("top: " .. row_top .. ", bottom: " .. row_bottom .. ", col: " .. col)

	local row = math.floor(row_top)
	local center = (row_top + row_bottom) / 2 % 1
	local thickness = row_bottom - row_top
	local character_list, character_index, hl_group

	if center < 0.5 then
		local micro_shift = center * 16
		character_index = math.ceil(micro_shift)
		if character_index == 0 then return end

		local character_thickness = character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then return end

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
		if character_index == 8 then return end

		local character_thickness = 1 - character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then return end

		character_list = BOTTOM_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	end

	draw_partial_block(row, col, character_list, character_index, hl_group)
end

local function draw_horizontally_shifted_sub_block(row, col_left, col_right, shade)
	if col_left >= col_right then return end
	-- logging.debug("row: " .. row .. ", left: " .. col_left .. ", right: " .. col_right)

	local col = math.floor(col_left)
	local center = (col_left + col_right) / 2 % 1
	local thickness = col_right - col_left
	local character_list, character_index, hl_group

	if center < 0.5 then
		local micro_shift = center * 16
		character_index = math.ceil(micro_shift)
		if character_index == 0 then return end

		local character_thickness = character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then return end

		character_list = LEFT_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	else
		local micro_shift = center * 16 - 8
		character_index = math.floor(micro_shift)
		if character_index == 8 then return end

		local character_thickness = 1 - character_index / 8
		shade = shade * thickness / character_thickness
		local hl_group_index = round(shade * config.color_levels)
		if hl_group_index == 0 then return end

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

local function precompute_quad_geometry(corners)
	local G = {}

	-- Bounding box
	G.top = math.floor(math.min(corners[1][1], corners[2][1], corners[3][1], corners[4][1]))
	G.bottom = math.ceil(math.max(corners[1][1], corners[2][1], corners[3][1], corners[4][1])) - 1
	G.left = math.floor(math.min(corners[1][2], corners[2][2], corners[3][2], corners[4][2]))
	G.right = math.ceil(math.max(corners[1][2], corners[2][2], corners[3][2], corners[4][2])) - 1

	-- Slopes
	G.slopes = {}

	for i = 1, 4 do
		local edge = {
			corners[i % 4 + 1][1] - corners[i][1],
			corners[i % 4 + 1][2] - corners[i][2],
		}
		G.slopes[i] = edge[1] / edge[2]
	end

	G.top_horizontal = math.abs(G.slopes[1]) <= config.max_slope_horizontal
	G.bottom_horizontal = math.abs(G.slopes[3]) <= config.max_slope_horizontal
	G.left_vertical = math.abs(G.slopes[4]) >= config.min_slope_vertical
	G.right_vertical = math.abs(G.slopes[2]) >= config.min_slope_vertical

	-- Intersections
	-- Intersection of quad edge with centerline of cells
	G.top_centerlines = {}
	-- Lowest intersection of quad edge with lateral edges of cells
	G.top_edges = {}
	-- Intersection of quad edge with lines at 0.25 and 0.75
	G.top_fractions = {}
	G.bottom_centerlines = {}
	G.bottom_edges = {}
	G.bottom_fractions = {}
	G.left_centerlines = {}
	G.left_edges = {}
	G.left_fractions = {}
	G.right_centerlines = {}
	G.right_edges = {}
	G.right_fractions = {}

	for col = G.left, G.right do
		G.top_centerlines[col] = corners[1][1] + (col + 0.5 - corners[1][2]) * G.slopes[1]
		G.top_edges[col] = G.top_centerlines[col] + 0.5 * math.abs(G.slopes[1])
		G.top_fractions[col] = {}
		G.bottom_centerlines[col] = corners[3][1] + (col + 0.5 - corners[3][2]) * G.slopes[3]
		G.bottom_edges[col] = G.bottom_centerlines[col] - 0.5 * math.abs(G.slopes[3])
		G.bottom_fractions[col] = {}

		for i = 1, 2 do
			local shift = (i == 1) and -0.25 or 0.25
			G.top_fractions[col][i] = G.top_centerlines[col] + shift * G.slopes[1]
			G.bottom_fractions[col][i] = G.bottom_centerlines[col] + shift * G.slopes[3]
		end
	end

	for row = G.top, G.bottom do
		G.right_centerlines[row] = corners[2][2] + (row + 0.5 - corners[2][1]) / G.slopes[2]
		G.right_edges[row] = G.right_centerlines[row] - 0.5 / math.abs(G.slopes[2])
		G.right_fractions[row] = {}
		G.left_centerlines[row] = corners[4][2] + (row + 0.5 - corners[4][1]) / G.slopes[4]
		G.left_edges[row] = G.left_centerlines[row] + 0.5 / math.abs(G.slopes[4])
		G.left_fractions[row] = {}

		for i = 1, 2 do
			local shift = (i == 1) and -0.25 or 0.25
			G.right_fractions[row][i] = G.right_centerlines[row] + shift / G.slopes[2]
			G.left_fractions[row][i] = G.left_centerlines[row] + shift / G.slopes[4]
		end
	end

	return G
end

M.draw_quad = function(corners, target_position)
	if target_position == nil then target_position = { 0, 0 } end

	local G = precompute_quad_geometry(corners)

	for row = G.top, G.bottom do
		local left = corners[4][2] + (row + 0.5 - corners[4][1]) / G.slopes[4]
		left = left - 0.5 / math.abs(G.slopes[4])
		local right = corners[2][2] + (row + 0.5 - corners[2][1]) / G.slopes[2]
		right = right + 0.5 / math.abs(G.slopes[2])

		for col = math.max(G.left, math.floor(left)), math.min(G.right, math.ceil(right)) do
			-- Check if on target
			if row == target_position[1] and col == target_position[2] then goto continue end

			local is_vertically_shifted = false
			local vertical_shade = 1
			local is_horizontally_shifted = false
			local horizontal_shade = 1

			-- Check if vertically shifted block
			local left_in = G.left_edges[row] > col
			local right_in = G.right_edges[row] < col + 1
			if not (left_in and not G.left_vertical) and not (right_in and not G.right_vertical) then
				local top_near = G.top_centerlines[col] > row
				local bottom_near = G.bottom_centerlines[col] < row + 1
				if
					(top_near and G.top_horizontal and (not bottom_near or G.bottom_horizontal))
					or (bottom_near and G.bottom_horizontal and (not top_near or G.top_horizontal))
				then
					is_vertically_shifted = true
					vertical_shade = math.min(row + 1, G.bottom_centerlines[col])
						- math.max(row, G.top_centerlines[col])
				end
			end

			-- Check if horizontally shifted block
			local top_in = G.top_edges[col] > row
			local bottom_in = G.bottom_edges[col] < row + 1
			if not (top_in and not G.top_horizontal) and not (bottom_in and not G.bottom_horizontal) then
				local left_near = G.left_centerlines[row] > col
				local right_near = G.right_centerlines[row] < col + 1
				if
					(left_near and G.left_vertical and (not right_near or G.right_vertical))
					or (right_near and G.right_vertical and (not left_near or G.left_vertical))
				then
					is_horizontally_shifted = true
					horizontal_shade = math.min(col + 1, G.right_centerlines[row])
						- math.max(col, G.left_centerlines[row])
				end
			end

			-- Draw shifted block
			if is_vertically_shifted and is_horizontally_shifted then
				if vertical_shade < config.max_shade_no_matrix and horizontal_shade < config.max_shade_no_matrix then
					is_horizontally_shifted = false
					is_vertically_shifted = false
				elseif vertical_shade < horizontal_shade then
					is_horizontally_shifted = false
				else
					is_vertically_shifted = false
				end
			end

			if is_vertically_shifted and horizontal_shade > 0 then
				draw_vertically_shifted_sub_block(
					math.max(row, G.top_centerlines[col]),
					math.min(row + 1, G.bottom_centerlines[col]),
					col,
					horizontal_shade
				)
				goto continue
			end

			if is_horizontally_shifted and vertical_shade > 0 then
				draw_horizontally_shifted_sub_block(
					row,
					math.max(col, G.left_centerlines[row]),
					math.min(col + 1, G.right_centerlines[row]),
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
				-- Intersection with top quad edge
				row_float = 2 * (G.top_fractions[col][i] - row)
				matrix_index = math.floor(row_float) + 1
				for index = 1, math.min(2, matrix_index - 1) do
					matrix[index][i] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = 1 - (row_float % 1)
					matrix[matrix_index][i] = matrix[matrix_index][i] * shade
				end

				-- Intersection with right quad edge
				col_float = 2 * (G.right_fractions[row][i] - col)
				matrix_index = math.floor(col_float) + 1
				for index = math.max(1, matrix_index + 1), 2 do
					matrix[i][index] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = col_float % 1
					matrix[i][matrix_index] = matrix[i][matrix_index] * shade
				end

				-- Intersection with bottom quad edge
				row_float = 2 * (G.bottom_fractions[col][i] - row)
				matrix_index = math.floor(row_float) + 1
				for index = math.max(1, matrix_index + 1), 2 do
					matrix[index][i] = 0
				end
				if matrix_index == 1 or matrix_index == 2 then
					shade = row_float % 1
					matrix[matrix_index][i] = matrix[matrix_index][i] * shade
				end

				-- Intersection with left quad edge
				col_float = 2 * (G.left_fractions[row][i] - col)
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
