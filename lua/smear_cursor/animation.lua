local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local screen = require("smear_cursor.screen")
local M = {}

local animating = false
local timer = nil
local target_position = { 0, 0 }
local current_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
local target_corners = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
local stiffnesses = { 0, 0, 0, 0 }

local previous_window_id = -1
local current_window_id = -1
local previous_buffer_id = -1
local current_buffer_id = -1
local previous_top_row = -1
local current_top_row = -1
local previous_line = -1
local current_line = -1

local function cursor_is_vertical_bar()
	if vim.api.nvim_get_mode().mode == "i" then
		return config.vertical_bar_cursor_insert_mode
	else
		return config.vertical_bar_cursor
	end
end

local function cursor_is_horizontal_bar()
	return vim.api.nvim_get_mode().mode == "R" and config.horizontal_bar_cursor_replace_mode
end

local function set_corners(corners, row, col)
	if cursor_is_vertical_bar() then
		corners[1] = { row, col }
		corners[2] = { row, col + 1 / 8 }
		corners[3] = { row + 1, col + 1 / 8 }
	elseif cursor_is_horizontal_bar() then
		corners[1] = { row + 7 / 8, col }
		corners[2] = { row + 7 / 8, col + 1 }
		corners[3] = { row + 1, col + 1 }
	else
		corners[1] = { row, col }
		corners[2] = { row, col + 1 }
		corners[3] = { row + 1, col + 1 }
	end
	corners[4] = { row + 1, col }
end

local function update_current_ids_and_row()
	previous_window_id = current_window_id
	previous_buffer_id = current_buffer_id
	previous_top_row = current_top_row
	previous_line = current_line
	current_window_id = vim.api.nvim_get_current_win()
	current_buffer_id = vim.api.nvim_get_current_buf()
	current_top_row = vim.fn.line("w0")
	current_line = vim.fn.line(".")
end

vim.defer_fn(function()
	local cursor_row, cursor_col = screen.get_screen_cursor_position()
	target_position = { cursor_row, cursor_col }
	set_corners(current_corners, cursor_row, cursor_col)
	set_corners(target_corners, cursor_row, cursor_col)
	update_current_ids_and_row()
end, 0)

local function update()
	local distance_head_to_target = math.huge
	local index_head = 0
	local max_length = vim.api.nvim_get_mode().mode == "i" and config.max_length_insert_mode or config.max_length

	-- Move toward targets
	for i = 1, 4 do
		local distance_squared = (current_corners[i][1] - target_corners[i][1]) ^ 2
			+ (current_corners[i][2] - target_corners[i][2]) ^ 2
		local stiffness = math.min(1, stiffnesses[i] * distance_squared ^ config.slowdown_exponent)

		if distance_squared < distance_head_to_target then
			distance_head_to_target = distance_squared
			index_head = i
		end

		for j = 1, 2 do
			current_corners[i][j] = current_corners[i][j] + (target_corners[i][j] - current_corners[i][j]) * stiffness
		end
	end

	-- Shorten smear if too long
	local smear_length = 0

	for i = 1, 4 do
		if i ~= index_head then
			-- stylua: ignore
			local distance = math.sqrt(
				(current_corners[i][1] - current_corners[index_head][1]) ^ 2 +
				(current_corners[i][2] - current_corners[index_head][2]) ^ 2
			)
			smear_length = math.max(smear_length, distance)
		end
	end

	if smear_length <= max_length then return end
	local factor = max_length / smear_length

	for i = 1, 4 do
		if i ~= index_head then
			for j = 1, 2 do
				current_corners[i][j] = current_corners[index_head][j]
					+ (current_corners[i][j] - current_corners[index_head][j]) * factor
			end
		end
	end
end

local function get_center(corners)
	return {
		(corners[1][1] + corners[2][1] + corners[3][1] + corners[4][1]) / 4,
		(corners[1][2] + corners[2][2] + corners[3][2] + corners[4][2]) / 4,
	}
end

local function normalize(v)
	local length = math.sqrt(v[1] ^ 2 + v[2] ^ 2)
	if length == 0 then return { 0, 0 } end
	return { v[1] / length, v[2] / length }
end

local function shrink_volume(corners)
	local edges = {}
	for i = 1, 3 do
		edges[i] = {
			corners[i + 1][1] - corners[1][1],
			corners[i + 1][2] - corners[1][2],
		}
	end

	local double_volumes = {}
	for i = 1, 2 do
		double_volumes[i] = edges[1][2] * edges[2][1] - edges[1][1] * edges[2][2]
	end
	local volume = (double_volumes[1] + double_volumes[2]) / 2
	if volume <= 0 then return corners end

	local center = get_center(corners)
	local factor = (1 / volume) ^ (config.volume_reduction_exponent / 2)
	factor = math.max(config.minimum_volume_factor, factor)

	local shrunk_corners = {}
	for i = 1, 4 do
		-- Only shrink perpendicular to the motion
		local corner_to_target = { target_corners[i][1] - corners[i][1], target_corners[i][2] - corners[i][2] }
		local center_to_corner = { corners[i][1] - center[1], corners[i][2] - center[2] }
		local normal = normalize({ -corner_to_target[2], corner_to_target[1] })
		local projection = center_to_corner[1] * normal[1] + center_to_corner[2] * normal[2]
		local shift = projection * (1 - factor)

		shrunk_corners[i] = {
			corners[i][1] - normal[1] * shift,
			corners[i][2] - normal[2] * shift,
		}
	end

	return shrunk_corners
end

local function stop_animation()
	if timer == nil then return end
	timer:stop()
	timer:close()
	timer = nil
	animating = false
end

local function hide_real_cursor()
	if vim.api.nvim_get_mode().mode == "c" then return end
	if not config.hide_target_hack then
		color.hide_real_cursor()
	elseif not cursor_is_vertical_bar() then
		local character = "█"
		draw.draw_character(target_position[1], target_position[2], character, color.get_hl_group())
	end
end

local function unhide_real_cursor()
	if not config.hide_target_hack then color.unhide_real_cursor() end
end

M.replace_real_cursor = function()
	local mode = vim.api.nvim_get_mode().mode
	if
		config.hide_target_hack
		or animating
		or (mode == "c" and not config.smear_to_cmd)
		or (mode == "i" and not config.smear_insert_mode)
		or (mode == "R" and not config.smear_replace_mode)
		or (mode == "t" and not config.smear_terminal_mode)
	then
		return
	end
	color.hide_real_cursor()
	draw.draw_quad(current_corners, { -1, -1 }, cursor_is_vertical_bar())
end

local function animate()
	animating = true
	update()

	local max_distance = 0
	local left_bound = vim.o.columns
	local right_bound = 0
	for i = 1, 4 do
		local distance = math.sqrt(
			(current_corners[i][1] - target_corners[i][1]) ^ 2 + (current_corners[i][2] - target_corners[i][2]) ^ 2
		)
		max_distance = math.max(max_distance, distance)
		left_bound = math.min(left_bound, current_corners[i][2])
		right_bound = math.max(right_bound, current_corners[i][2])
	end
	local thickness = right_bound - left_bound

	draw.clear()

	if
		max_distance <= config.distance_stop_animating
		or (thickness <= 1.5 / 8 and max_distance <= config.distance_stop_animating_vertical_bar)
	then
		set_corners(current_corners, target_position[1], target_position[2])
		if vim.api.nvim_get_mode().mode == "c" then vim.cmd.redraw() end
		unhide_real_cursor()
		stop_animation()
		return
	end

	-- Only shrink the volume if not moving on a straight line
	local current_center = get_center(current_corners)
	local target_center = get_center(target_corners)
	local straight_line = math.abs(target_center[1] - current_center[1]) < 1 / 8
		or math.abs(target_center[2] - current_center[2]) < 1 / 8
	local drawn_corners = straight_line and current_corners or shrink_volume(current_corners)

	local target_reached = false
	for i = 1, 4 do
		-- stylua: ignore
		if (
			drawn_corners[i][1] >= target_corners[1][1] and
			drawn_corners[i][1] <= target_corners[3][1] and
			drawn_corners[i][2] >= target_corners[1][2] and
			drawn_corners[i][2] <= target_corners[3][2]
		) then
			target_reached = true
			break
		end
	end

	if target_reached and (config.never_draw_over_target or vim.api.nvim_get_mode().mode == "c") then
		unhide_real_cursor()
	else
		hide_real_cursor()
	end

	draw.draw_quad(drawn_corners, target_position, cursor_is_vertical_bar())
	if vim.api.nvim_get_mode().mode == "c" then vim.cmd.redraw() end
end

local function start_anination()
	if timer ~= nil then return end
	timer = vim.uv.new_timer()
	timer:start(0, config.time_interval, vim.schedule_wrap(animate))
end

local function set_stiffnesses()
	local target_center = get_center(target_corners)
	local distances = {}
	local min_distance = math.huge
	local max_distance = 0
	local head_stiffness, trailing_stiffness, trailing_exponent

	if vim.api.nvim_get_mode().mode == "i" then
		head_stiffness = config.stiffness_insert_mode
		trailing_stiffness = config.trailing_stiffness_insert_mode
		trailing_exponent = config.trailing_exponent_insert_mode
	else
		head_stiffness = config.stiffness
		trailing_stiffness = config.trailing_stiffness
		trailing_exponent = config.trailing_exponent
	end

	for i = 1, 4 do
		local distance =
			math.sqrt((current_corners[i][1] - target_center[1]) ^ 2 + (current_corners[i][2] - target_center[2]) ^ 2)
		min_distance = math.min(min_distance, distance)
		max_distance = math.max(max_distance, distance)
		distances[i] = distance
	end

	if max_distance == min_distance then
		for i = 1, 4 do
			stiffnesses[i] = head_stiffness
		end
		return
	end

	for i = 1, 4 do
		local x = (distances[i] - min_distance) / (max_distance - min_distance)
		local stiffness = head_stiffness + (trailing_stiffness - head_stiffness) * x ^ trailing_exponent
		stiffnesses[i] = math.min(1, stiffness)
	end
end

local function clamp_to_buffer(position)
	local window_origin = vim.api.nvim_win_get_position(current_window_id)
	local window_row = window_origin[1] + 1
	-- local window_col = window_origin[2] + 1
	local window_height = vim.api.nvim_win_get_height(current_window_id)
	-- local window_width = vim.api.nvim_win_get_width(current_window_id)

	position[1] = math.max(window_row, math.min(window_row + window_height - 1, position[1]))
end

local function scroll_buffer_space()
	if current_top_row ~= previous_top_row and current_line ~= previous_line then
		-- Shift to show smear in buffer space instead of screen space
		local shift = screen.get_screen_distance(previous_top_row, current_top_row)
		local shifted_position = { current_corners[1][1] - shift, current_corners[1][2] }
		clamp_to_buffer(shifted_position)
		set_corners(current_corners, shifted_position[1], shifted_position[2])

		target_position[1] = target_position[1] - shift
		clamp_to_buffer(target_position)
	end
end

M.jump = function(row, col)
	target_position = { row, col }
	set_corners(target_corners, row, col)
	set_corners(current_corners, row, col)
	unhide_real_cursor()
	draw.clear()
end

M.change_target_position = function(row, col)
	update_current_ids_and_row()

	if current_window_id == previous_window_id and current_buffer_id == previous_buffer_id then
		if config.scroll_buffer_space then scroll_buffer_space() end
		-- stylua: ignore
		if
			(not config.smear_between_neighbor_lines and math.abs(row - current_corners[1][1]) <= 1.5)
			or (
				math.abs(row - current_corners[1][1]) < config.min_vertical_distance_smear
				and math.abs(col - current_corners[1][2]) < config.min_horizontal_distance_smear
			)
			or (not config.smear_horizontally and math.abs(row - current_corners[1][1]) <= 0.5)
			or (not config.smear_vertically and math.abs(col - current_corners[1][2]) <= 0.5)
			or (
				not config.smear_diagonally
				and math.abs(row - current_corners[1][1]) > 0.5
				and math.abs(col - current_corners[1][2]) > 0.5
			)
		then
			if animating then
				stop_animation()
			end
			M.jump(row, col)
			if vim.api.nvim_get_mode().mode == "c" then vim.cmd.redraw() end
			return
		end
	else
		if not config.smear_between_buffers then
			M.jump(row, col)
			return
		end
	end

	if target_position[1] == row and vim.api.nvim_get_mode().mode == "c" then return end

	target_position = { row, col }
	set_corners(target_corners, row, col)
	set_stiffnesses()

	hide_real_cursor()
	start_anination()
end

setmetatable(M, {
	__index = function(_, key)
		if key == "target_position" then
			return target_position
		else
			return nil
		end
	end,
})

return M
