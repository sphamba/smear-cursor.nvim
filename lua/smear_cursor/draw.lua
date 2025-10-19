local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local atan_cached = require("smear_cursor.math").atan_cached
local round = require("smear_cursor.math").round
local M = {}

-- stylua: ignore start
local BOTTOM_BLOCKS        = { "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " " }
local LEFT_BLOCKS          = { " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" }
local TOP_BLOCKS           = { " ", "▔", "🮂", "🮃", "▀", "🮄", "🮅", "🮆", "█" }
local RIGHT_BLOCKS         = { "█", "🮋", "🮊", "🮉", "▐", "🮈", "🮇", "▕", " " }
local MATRIX_CHARACTERS    = { "▘", "▝", "▀", "▖", "▌", "▞", "▛", "▗", "▚", "▐", "▜", "▄", "▙", "▟", "█" }
local VERTICAL_BARS        = { "▏", "🭰", "🭱", "🭲", "🭳", "🭳", "🭵", "▕" }
local LEFT_DIAGONAL_BLOCKS = {
	[-2] = {            -- slope Y/X
		[-1 / 4] = "🭛", -- X intersection -> symbol
		[ 1 / 4] = "🭟",
	},
	[-4 / 3] = {
		[-3 / 8] = "🭙",
		[ 3 / 8] = "🭟",
	},
	[-1] = {
		[     0] = "◤",
	},
	[-2 / 3] = {
		[-3 / 4] = "🭗",
		[-1 / 4] = "🭚",
		[ 1 / 4] = "🭠",
		[ 3 / 4] = "🭝",
	},
	[-1 / 3] = {
		[    -1] = "🭘",
		[     0] = "🭜",
		[     1] = "🭞",
	},
	[1 / 3] = {
		[    -1] = "🬽",
		[     0] = "🭑",
		[     1] = "🭍",
	},
	[2 / 3] = {
		[-3 / 4] = "🬼",
		[-1 / 4] = "🬿",
		[ 1 / 4] = "🭏",
		[ 3 / 4] = "🭌",
	},
	[1] = {
		[     0] = "◣",
	},
	[4 / 3] = {
		[-3 / 8] = "🬾",
		[ 3 / 8] = "🭎",
	},
	[2] = {
		[-1 / 4] = "🭀",
		[ 1 / 4] = "🭐",
	},
}
local RIGHT_DIAGONAL_BLOCKS = {
	[-2] = {
		[-1 / 4] = "🭅",
		[ 1 / 4] = "🭋",
	},
	[-4 / 3] = {
		[-3 / 8] = "🭃",
		[ 3 / 8] = "🭉",
	},
	[-1] = {
		[     0] = "◢",
	},
	[-2 / 3] = {
		[-3 / 4] = "🭁",
		[-1 / 4] = "🭄",
		[ 1 / 4] = "🭊",
		[ 3 / 4] = "🭇",
	},
	[-1 / 3] = {
		[    -1] = "🭂",
		[     0] = "🭆",
		[     1] = "🭈",
	},
	[1 / 3] = {
		[    -1] = "🭓",
		[     0] = "🭧",
		[     1] = "🭣",
	},
	[2 / 3] = {
		[-3 / 4] = "🭒",
		[-1 / 4] = "🭕",
		[ 1 / 4] = "🭥",
		[ 3 / 4] = "🭢",
	},
	[1] = {
		[     0] = "◥",
	},
	[4 / 3] = {
		[-3 / 8] = "🭔",
		[ 3 / 8] = "🭤",
	},
	[2] = {
		[-1 / 4] = "🭖",
		[ 1 / 4] = "🭦",
	},
}
local BLOCK_ASPECT_RATIO = 2.0 -- height / width
-- stylua: ignore end

-- Enums for drawing quad
local TOP = 1
local BOTTOM = 2
local LEFT = 3
local RIGHT = 4
local LEFT_DIAGONAL = 5
local RIGHT_DIAGONAL = 6
local DIAGONAL = 7
local NONE = 8

-- Create a namespace for the extmarks
local cursor_namespace = vim.api.nvim_create_namespace("smear_cursor")
local can_hide = vim.fn.has("nvim-0.10") == 1
local extmark_id = 999

-- Switch between bulging above and below the line
local bulge_above = false

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
			local window_config = { relative = "editor", border = "none", row = row - 1, col = col - 1 }
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
		border = "none",
		focusable = false,
		noautocmd = true,
		zindex = config.windows_zindex,
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
	if row < 1 or row > vim.o.lines - vim.opt.cmdheight._value or col < 1 or col > vim.o.columns then return end

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

local function draw_matrix_character(row, col, matrix, vertical_bar)
	local max = math.max(matrix[1][1], matrix[1][2], matrix[2][1], matrix[2][2])
	local matrix_pixel_threshold = vertical_bar and config.matrix_pixel_threshold_vertical_bar
		or config.matrix_pixel_threshold
	if max < matrix_pixel_threshold then return end
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

local function get_top_block_properties(micro_shift, thickness, shade)
	local character_index = math.ceil(micro_shift)
	if character_index == 0 then return end

	local character_thickness = character_index / 8
	shade = shade * thickness / character_thickness
	local hl_group_index = round(shade * config.color_levels)
	if hl_group_index == 0 then return end

	local character_list, hl_group

	if config.legacy_computing_symbols_support then
		character_list = TOP_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	else
		character_list = BOTTOM_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index, inverted = true })
	end

	return character_index, character_list, hl_group
end

local function get_bottom_block_properties(micro_shift, thickness, shade)
	local character_index = math.floor(micro_shift)
	if character_index == 8 then return end

	local character_thickness = 1 - character_index / 8
	shade = shade * thickness / character_thickness
	local hl_group_index = round(shade * config.color_levels)
	if hl_group_index == 0 then return end

	local character_list = BOTTOM_BLOCKS
	local hl_group = color.get_hl_group({ level = hl_group_index })

	return character_index, character_list, hl_group
end

local function draw_vertically_shifted_sub_block(row_top, row_bottom, col, shade)
	if row_top >= row_bottom then return end
	-- logging.debug("top: " .. row_top .. ", bottom: " .. row_bottom .. ", col: " .. col)

	local row = math.floor(row_top)
	local center = (row_top + row_bottom) / 2 % 1
	local thickness = row_bottom - row_top
	local character_index, character_list, hl_group
	local gap_top = row_top % 1
	local gap_bottom = (1 - row_bottom) % 1

	if math.max(gap_top, gap_bottom) / 2 < math.min(gap_top, gap_bottom) then
		-- Draw alternating block
		if bulge_above then
			local micro_shift = (row_bottom % 1) * 8
			character_index, character_list, hl_group = get_top_block_properties(micro_shift, thickness, shade)
		else
			local micro_shift = (row_top % 1) * 8
			character_index, character_list, hl_group = get_bottom_block_properties(micro_shift, thickness, shade)
		end
	elseif center < 0.5 then
		-- Draw top block
		local micro_shift = center * 16
		character_index, character_list, hl_group = get_top_block_properties(micro_shift, thickness, shade)
	else
		-- Draw bottom block
		local micro_shift = center * 16 - 8
		character_index, character_list, hl_group = get_bottom_block_properties(micro_shift, thickness, shade)
	end

	if character_index == nil then return end
	draw_partial_block(row, col, character_list, character_index, hl_group)
end

local function get_vertical_bar_properties(micro_shift, thickness, shade)
	local character_index = math.floor(micro_shift)
	if character_index < 0 or character_index >= 8 then return end

	local character_thickness = 1 / 8
	shade = math.min(1, shade * thickness / character_thickness)
	local hl_group_index = round(shade * config.color_levels)
	if hl_group_index == 0 then return end

	local character_list = VERTICAL_BARS
	local hl_group = color.get_hl_group({ level = hl_group_index })

	return character_index, character_list, hl_group
end

local function get_left_block_properties(micro_shift, thickness, shade)
	local character_index = math.ceil(micro_shift)
	if character_index == 0 then return end

	local character_thickness = character_index / 8
	shade = shade * thickness / character_thickness
	local hl_group_index = round(shade * config.color_levels)
	if hl_group_index == 0 then return end

	local character_list = LEFT_BLOCKS
	local hl_group = color.get_hl_group({ level = hl_group_index })

	return character_index, character_list, hl_group
end

local function get_right_block_properties(micro_shift, thickness, shade)
	local character_index = math.floor(micro_shift)
	if character_index == 8 then return end

	local character_thickness = 1 - character_index / 8
	shade = shade * thickness / character_thickness
	local hl_group_index = round(shade * config.color_levels)
	if hl_group_index == 0 then return end

	local character_list, hl_group

	if config.legacy_computing_symbols_support then
		character_list = RIGHT_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index })
	else
		character_list = LEFT_BLOCKS
		hl_group = color.get_hl_group({ level = hl_group_index, inverted = true })
	end

	return character_index, character_list, hl_group
end

local function draw_horizontally_shifted_sub_block(row, col_left, col_right, shade)
	if col_left >= col_right then return end
	-- logging.debug("row: " .. row .. ", left: " .. col_left .. ", right: " .. col_right)

	local col = math.floor(col_left)
	local center = (col_left + col_right) / 2 % 1
	local thickness = col_right - col_left
	local character_list, character_index, hl_group

	local gap_left = col_left % 1
	local gap_right = (1 - col_right) % 1

	if
		(config.legacy_computing_symbols_support or config.legacy_computing_symbols_support_vertical_bars)
		and thickness <= 1.5 / 8
	then
		-- Draw vertical bar
		local micro_shift = center * 8
		character_index, character_list, hl_group = get_vertical_bar_properties(micro_shift, thickness, shade)
	elseif math.max(gap_left, gap_right) / 2 < math.min(gap_left, gap_right) then
		-- Draw alternating block
		if bulge_above then
			local micro_shift = (col_right % 1) * 8
			character_index, character_list, hl_group = get_left_block_properties(micro_shift, thickness, shade)
		else
			local micro_shift = (col_left % 1) * 8
			character_index, character_list, hl_group = get_right_block_properties(micro_shift, thickness, shade)
		end
	elseif center < 0.5 then
		-- Draw left block
		local micro_shift = center * 16
		character_index, character_list, hl_group = get_left_block_properties(micro_shift, thickness, shade)
	else
		-- Draw right block
		local micro_shift = center * 16 - 8
		character_index, character_list, hl_group = get_right_block_properties(micro_shift, thickness, shade)
	end

	if character_index == nil then return end
	draw_partial_block(row, col, character_list, character_index, hl_group)
end

local function ensure_clockwise(corners)
	if
		(corners[2][1] - corners[1][1]) * (corners[4][2] - corners[1][2])
			- (corners[2][2] - corners[1][2]) * (corners[4][1] - corners[1][1])
		> 0
	then
		corners = { corners[3], corners[2], corners[1], corners[4] }
	end

	return corners
end

local function precompute_intersections_horizontal(corners, G, index)
	local centerlines = {}
	local fractions = {}

	for col = G.left, G.right do
		centerlines[col] = corners[index][1] + (col + 0.5 - corners[index][2]) * G.slopes[index]
		fractions[col] = {}

		for j = 1, 2 do
			local shift = (j == 1) and -0.25 or 0.25
			fractions[col][j] = centerlines[col] + shift * G.slopes[index]
		end
	end

	G.I.centerlines[index] = centerlines
	G.I.fractions[index] = fractions
end

local function precompute_intersections_vertical(corners, G, index)
	local centerlines = {}
	local fractions = {}

	for row = G.top, G.bottom do
		centerlines[row] = corners[index][2] + (row + 0.5 - corners[index][1]) / G.slopes[index]
		fractions[row] = {}

		for j = 1, 2 do
			local shift = (j == 1) and -0.25 or 0.25
			fractions[row][j] = centerlines[row] + shift / G.slopes[index]
		end
	end

	G.I.centerlines[index] = centerlines
	G.I.fractions[index] = fractions
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

	-- Compute closest matching slope for diagonal blocks
	local min_angle_difference = math.huge
	local closest_slope = nil
	for block_slope, _ in pairs(LEFT_DIAGONAL_BLOCKS) do
		local angle_difference = math.abs(atan_cached(BLOCK_ASPECT_RATIO * block_slope) - G.angles[index])
		if angle_difference < min_angle_difference then
			min_angle_difference = angle_difference
			closest_slope = block_slope
		end
	end
	if closest_slope ~= nil and min_angle_difference <= config.max_angle_difference_diagonal then
		G.slopes[index] = closest_slope
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
	[NONE] = function() end,
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
	G.angles = {}

	for i = 1, 4 do
		edges[i] = {
			corners[i % 4 + 1][1] - corners[i][1],
			corners[i % 4 + 1][2] - corners[i][2],
		}
		G.slopes[i] = edges[i][1] / edges[i][2]
		G.angles[i] = math.atan(BLOCK_ASPECT_RATIO * G.slopes[i])
	end

	-- Edge types
	G.edge_types = {}

	for i = 1, 4 do
		local abs_slope = math.abs(G.slopes[i])

		if abs_slope ~= abs_slope then
			G.edge_types[i] = NONE
		elseif abs_slope <= config.max_slope_horizontal then
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
	[NONE] = function()
		return 0
	end,
}

local function get_edge_cell_intersection(edge_index, row, col, G)
	local edge_type = G.edge_types[edge_index]
	return get_edge_cell_intersection_functions[edge_type](edge_index, row, col, G)
end

local function update_matrix_with_top_edge(edge_index, fraction_index, row, col, G, matrix)
	local row_float = 2 * (G.I.fractions[edge_index][col][fraction_index] - row)
	local matrix_index = math.floor(row_float) + 1
	for index = 1, math.min(2, matrix_index - 1) do
		matrix[index][fraction_index] = 0
	end
	if matrix_index == 1 or matrix_index == 2 then
		local shade = 1 - (row_float % 1)
		matrix[matrix_index][fraction_index] = matrix[matrix_index][fraction_index] * shade
	end
end

local function update_matrix_with_bottom_edge(edge_index, fraction_index, row, col, G, matrix)
	local row_float = 2 * (G.I.fractions[edge_index][col][fraction_index] - row)
	local matrix_index = math.floor(row_float) + 1
	for index = math.max(1, matrix_index + 1), 2 do
		matrix[index][fraction_index] = 0
	end
	if matrix_index == 1 or matrix_index == 2 then
		local shade = row_float % 1
		matrix[matrix_index][fraction_index] = matrix[matrix_index][fraction_index] * shade
	end
end

local function update_matrix_with_left_edge(edge_index, fraction_index, row, col, G, matrix)
	local col_float = 2 * (G.I.fractions[edge_index][row][fraction_index] - col)
	local matrix_index = math.floor(col_float) + 1
	for index = 1, math.min(2, matrix_index - 1) do
		matrix[fraction_index][index] = 0
	end
	if matrix_index == 1 or matrix_index == 2 then
		local shade = 1 - (col_float % 1)
		matrix[fraction_index][matrix_index] = matrix[fraction_index][matrix_index] * shade
	end
end

local function update_matrix_with_right_edge(edge_index, fraction_index, row, col, G, matrix)
	local col_float = 2 * (G.I.fractions[edge_index][row][fraction_index] - col)
	local matrix_index = math.floor(col_float) + 1
	for index = math.max(1, matrix_index + 1), 2 do
		matrix[fraction_index][index] = 0
	end
	if matrix_index == 1 or matrix_index == 2 then
		local shade = col_float % 1
		matrix[fraction_index][matrix_index] = matrix[fraction_index][matrix_index] * shade
	end
end

local update_matrix_with_edge_functions = {
	[TOP] = update_matrix_with_top_edge,
	[BOTTOM] = update_matrix_with_bottom_edge,
	[LEFT] = update_matrix_with_left_edge,
	[RIGHT] = update_matrix_with_right_edge,
	[LEFT_DIAGONAL] = update_matrix_with_left_edge,
	[RIGHT_DIAGONAL] = update_matrix_with_right_edge,
	[NONE] = function() end,
}

local function update_matrix_with_edge(edge_index, matrix_index, row, col, G, matrix)
	local edge_type = G.edge_types[edge_index]
	update_matrix_with_edge_functions[edge_type](edge_index, matrix_index, row, col, G, matrix)
end

local function draw_diagonal_block(row, col, edge_index, G, vertical_bar)
	local edge_type = G.edge_types[edge_index]
	local slope = G.slopes[edge_index]
	local blocks = (edge_type == LEFT_DIAGONAL and RIGHT_DIAGONAL_BLOCKS or LEFT_DIAGONAL_BLOCKS)[slope]
	if blocks ~= nil then
		local min_offset = math.huge
		local matching_char = nil
		for shift, char in pairs(blocks) do
			local offset = math.abs(G.I.centerlines[edge_index][row] - col - 0.5 - shift)
			if offset < min_offset then
				min_offset = offset
				matching_char = char
			end
		end
		if matching_char ~= nil and min_offset <= config.max_offset_diagonal then
			local shade = vertical_bar and math.ceil(config.color_levels / 8) or config.color_levels
			M.draw_character(row, col, matching_char, color.get_hl_group({ level = shade }))
			return true
		end
	end

	return false
end

M.draw_quad = function(corners, target_position, vertical_bar)
	if target_position == nil then target_position = { 0, 0 } end

	bulge_above = not bulge_above
	corners = ensure_clockwise(corners)
	local G = precompute_quad_geometry(corners)

	for row = G.top, G.bottom do
		for col = G.left, G.right do
			-- Check if on target
			if
				config.never_draw_over_target
				and not vertical_bar
				and row == target_position[1]
				and col == target_position[2]
			then
				goto continue
			end

			local intersections = {}
			local only_diagonal = true
			local diagonal_edge_index = nil
			for i = 1, 4 do
				local intersection = get_edge_cell_intersection(i, row, col, G)
				local edge_type = G.edge_types[i]
				if edge_type == LEFT_DIAGONAL or edge_type == RIGHT_DIAGONAL then edge_type = DIAGONAL end
				if edge_type ~= DIAGONAL and intersection >= 1 then goto continue end

				if edge_type ~= DIAGONAL and intersection > 0 and intersection < 1 then only_diagonal = false end

				if intersections[edge_type] == nil or intersections[edge_type] < intersection then
					intersections[edge_type] = intersection
					if edge_type == DIAGONAL then diagonal_edge_index = i end
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
					if
						1 - intersections[RIGHT] <= 1 / 8
						and row == target_position[1]
						and (col == target_position[2] or col == target_position[2] + 1)
					then
						goto continue
					end
					draw_horizontally_shifted_sub_block(
						row,
						col + intersections[LEFT],
						col + 1 - intersections[RIGHT],
						vertical_shade
					)
					goto continue
				end
			end

			-- Try to render as diagonal block
			if only_diagonal and config.use_diagonal_blocks and config.legacy_computing_symbols_support then
				local has_drawn_diagonal_block = draw_diagonal_block(row, col, diagonal_edge_index, G, vertical_bar)
				if has_drawn_diagonal_block then goto continue end
			end

			-- Draw matrix
			local matrix = {
				{ 1, 1 },
				{ 1, 1 },
			}

			for edge_index = 1, 4 do
				for fraction_index = 1, 2 do
					update_matrix_with_edge(edge_index, fraction_index, row, col, G, matrix)
				end
			end

			draw_matrix_character(row, col, matrix, vertical_bar)

			::continue::
		end
	end
end

return M
