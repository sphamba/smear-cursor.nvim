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

-- Enums for drawing quad
local TOP = 1
local BOTTOM = 2
local LEFT = 3
local RIGHT = 4
local LEFT_DIAGONAL = 5
local RIGHT_DIAGONAL = 6
local DIAGONAL = 7

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

local function precompute_intersections_horizontal(corners, G, index)
	local centerlines = {}

	for col = G.left, G.right do
		centerlines[col] = corners[index][1] + (col + 0.5 - corners[index][2]) * G.slopes[index]
	end

	G.I.centerlines[index] = centerlines
end

local function precompute_intersections_vertical(corners, G, index)
	local centerlines = {}

	for row = G.top, G.bottom do
		centerlines[row] = corners[index][2] + (row + 0.5 - corners[index][1]) / G.slopes[index]
	end

	G.I.centerlines[index] = centerlines
end

local function precompute_intersections_diagonal(corners, G, index)
	local edge_type = G.edge_types[index]
	local centerlines = {}
	local edges = {}
	local fractions = {}

	for row = G.top, G.bottom do
		centerlines[row] = corners[index][2] + (row + 0.5 - corners[index][1]) / G.slopes[index]
		edges[row] = centerlines[row] + (edge_type == LEFT_DIAGONAL and 0.5 or -0.5) / math.abs(G.slopes[index])
		fractions[row] = {}
		for j = 1, 2 do
			local shift = (j == 1) and -0.25 or 0.25
			fractions[row][j] = centerlines[row] + shift / G.slopes[index]
		end
	end

	G.I.centerlines[index] = centerlines
	G.I.edges[index] = edges
	G.I.fractions[index] = fractions
end

local precompute_intersections_functions = {
	[TOP] = precompute_intersections_horizontal,
	[BOTTOM] = precompute_intersections_horizontal,
	[LEFT] = precompute_intersections_vertical,
	[RIGHT] = precompute_intersections_vertical,
	[LEFT_DIAGONAL] = precompute_intersections_diagonal,
	[RIGHT_DIAGONAL] = precompute_intersections_diagonal,
}

local function precompute_quad_geometry(corners)
	local G = {}

	-- Bounding box
	G.top = math.floor(math.min(corners[1][1], corners[2][1], corners[3][1], corners[4][1]))
	G.bottom = math.ceil(math.max(corners[1][1], corners[2][1], corners[3][1], corners[4][1])) - 1
	G.left = math.floor(math.min(corners[1][2], corners[2][2], corners[3][2], corners[4][2]))
	G.right = math.ceil(math.max(corners[1][2], corners[2][2], corners[3][2], corners[4][2])) - 1

	-- Slopes
	local edges = {}
	G.slopes = {}

	for i = 1, 4 do
		edges[i] = {
			corners[i % 4 + 1][1] - corners[i][1],
			corners[i % 4 + 1][2] - corners[i][2],
		}
		G.slopes[i] = edges[i][1] / edges[i][2]
	end

	-- Edge types
	G.edge_types = {}

	for i = 1, 4 do
		local abs_slope = math.abs(G.slopes[i])

		if abs_slope <= config.max_slope_horizontal then
			G.edge_types[i] = (edges[i][2] > 0) and TOP or BOTTOM
		elseif abs_slope >= config.min_slope_vertical then
			G.edge_types[i] = (edges[i][1] > 0) and RIGHT or LEFT
		else
			G.edge_types[i] = (edges[i][1] > 0) and RIGHT_DIAGONAL or LEFT_DIAGONAL
		end
	end

	-- Intersections
	G.I = {}
	-- Intersection of quad edge with centerline of cells
	G.I.centerlines = {}
	-- Closest intersection of quad edge with lateral edges of cells
	G.I.edges = {}
	-- Intersection of quad edge with lines at 0.25 and 0.75
	G.I.fractions = {}

	for i = 1, 4 do
		local edge_type = G.edge_types[i]
		precompute_intersections_functions[edge_type](corners, G, i)
	end

	return G
end

local get_edge_cell_intersection_functions = {
	[TOP] = function(edge_index, row, col, G)
		return G.I.centerlines[edge_index][col] - row
	end,
	[BOTTOM] = function(edge_index, row, col, G)
		return row + 1 - G.I.centerlines[edge_index][col]
	end,
	[LEFT] = function(edge_index, row, col, G)
		return G.I.centerlines[edge_index][row] - col
	end,
	[RIGHT] = function(edge_index, row, col, G)
		return col + 1 - G.I.centerlines[edge_index][row]
	end,
	[LEFT_DIAGONAL] = function(edge_index, row, col, G)
		return G.I.edges[edge_index][row] - col
	end,
	[RIGHT_DIAGONAL] = function(edge_index, row, col, G)
		return col + 1 - G.I.edges[edge_index][row]
	end,
}

local function get_edge_cell_intersection(edge_index, row, col, G)
	local edge_type = G.edge_types[edge_index]
	return get_edge_cell_intersection_functions[edge_type](edge_index, row, col, G)
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

			local intersections = {}
			for i = 1, 4 do
				local intersection = get_edge_cell_intersection(i, row, col, G)
				if intersection >= 1 then goto continue end

				local edge_type = G.edge_types[i]
				if edge_type == LEFT_DIAGONAL or edge_type == RIGHT_DIAGONAL then edge_type = DIAGONAL end

				if intersections[edge_type] == nil or intersections[edge_type] < intersection then
					intersections[edge_type] = intersection
				end
			end

			-- Try to render as shifted block
			if intersections[DIAGONAL] == nil or intersections[DIAGONAL] < 1 - config.max_shade_no_matrix then
				local is_vertically_shifted = false
				local vertical_shade = 1
				local is_horizontally_shifted = false
				local horizontal_shade = 1

				if intersections[TOP] ~= nil or intersections[BOTTOM] ~= nil then
					is_vertically_shifted = true
					intersections[TOP] = math.max(0, intersections[TOP] or 0)
					intersections[BOTTOM] = math.max(0, intersections[BOTTOM] or 0)
					vertical_shade = 1 - intersections[TOP] - intersections[BOTTOM]
				end

				if intersections[LEFT] ~= nil or intersections[RIGHT] ~= nil then
					is_horizontally_shifted = true
					intersections[LEFT] = math.max(0, intersections[LEFT] or 0)
					intersections[RIGHT] = math.max(0, intersections[RIGHT] or 0)
					horizontal_shade = 1 - intersections[LEFT] - intersections[RIGHT]
				end

				if is_vertically_shifted and is_horizontally_shifted then
					if
						vertical_shade < config.max_shade_no_matrix
						and horizontal_shade < config.max_shade_no_matrix
					then
						is_horizontally_shifted = false
						is_vertically_shifted = false
					elseif 2 * (1 - vertical_shade) > (1 - horizontal_shade) then
						is_horizontally_shifted = false
					else
						is_vertically_shifted = false
					end
				end

				-- Draw shifted block
				if is_vertically_shifted then
					draw_vertically_shifted_sub_block(
						row + intersections[TOP],
						row + 1 - intersections[BOTTOM],
						col,
						horizontal_shade
					)
					goto continue
				end

				if is_horizontally_shifted then
					draw_horizontally_shifted_sub_block(
						row,
						col + intersections[LEFT],
						col + 1 - intersections[RIGHT],
						vertical_shade
					)
					goto continue
				end
			end

			-- Draw matrix
			local row_float, col_float, matrix_index, shade
			local matrix = {
				{ 1, 1 },
				{ 1, 1 },
			}

			for i = 1, 0 do
				-- for i = 1, 2 do
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
