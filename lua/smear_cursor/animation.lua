local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local screen = require("smear_cursor.screen")
local M = {}

local animating = false
local target_position = { 0, 0 }
local current_corners = {}
local target_corners = {}
local stiffnesses = { 0, 0, 0, 0 }
local previous_ending_drawn = false -- only draw previous smear once

local previous_window_id = -1
local current_window_id = -1
local previous_buffer_id = -1
local current_buffer_id = -1
local previous_top_row = -1
local current_top_row = -1

local function set_corners(corners, row, col)
	corners[1] = { row, col }
	if config.vertical_bar_cursor then
		corners[2] = { row, col + 1 / 8 }
		corners[3] = { row + 1, col + 1 / 8 }
	else
		corners[2] = { row, col + 1 }
		corners[3] = { row + 1, col + 1 }
	end
	corners[4] = { row + 1, col }
end

local function update_current_ids_and_row()
	previous_window_id = current_window_id
	previous_buffer_id = current_buffer_id
	previous_top_row = current_top_row
	current_window_id = vim.api.nvim_get_current_win()
	current_buffer_id = vim.api.nvim_get_current_buf()
	current_top_row = vim.fn.line("w0")
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

	if smear_length <= config.max_length then return end
	local factor = config.max_length / smear_length

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

local function animate()
	animating = true
	update()

	local max_distance = 0
	for i = 1, 4 do
		local distance = math.sqrt(
			(current_corners[i][1] - target_corners[i][1]) ^ 2 + (current_corners[i][2] - target_corners[i][2]) ^ 2
		)
		max_distance = math.max(max_distance, distance)
	end

	draw.clear()
	previous_ending_drawn = false

	if max_distance <= config.distance_stop_animating then
		animating = false
		set_corners(current_corners, target_position[1], target_position[2])
		return
	end

	local shrunk_corners = shrink_volume(current_corners)
	if config.hide_target_hack then
		-- stylua: ignore
		local target_reached = (
			math.floor(shrunk_corners[1][1]) == target_position[1] and
			math.floor(shrunk_corners[1][2]) == target_position[2]
		) or (
			math.floor(shrunk_corners[2][1]) == target_position[1] and
			math.ceil(shrunk_corners[2][2]) - 1 == target_position[2]
		) or (
			math.ceil(shrunk_corners[3][1]) - 1 == target_position[1] and
			math.ceil(shrunk_corners[3][2]) - 1 == target_position[2]
		) or (
			math.ceil(shrunk_corners[4][1]) - 1 == target_position[1] and
			math.floor(shrunk_corners[4][2]) == target_position[2]
		)

		if not target_reached then
			local character = config.vertical_bar_cursor and "▏" or "█"
			draw.draw_character(target_position[1], target_position[2], character, color.get_hl_group())
		end
	end

	draw.draw_quad(shrunk_corners, target_position)
	vim.defer_fn(animate, config.time_interval)
end

local function set_stiffnesses(head_stiffness, trailing_stiffness)
	local target_center = get_center(target_corners)
	local distances = {}
	local min_distance = math.huge
	local max_distance = 0

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
		local stiffness = head_stiffness + (trailing_stiffness - head_stiffness) * x ^ config.trailing_exponent
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
	if current_top_row ~= previous_top_row then
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
	draw.clear()
end

M.change_target_position = function(row, col)
	update_current_ids_and_row()

	if current_window_id == previous_window_id and current_buffer_id == previous_buffer_id then
		if config.scroll_buffer_space then scroll_buffer_space() end
		if not config.smear_between_neighbor_lines and not animating and math.abs(row - target_position[1]) <= 1 then
			M.jump(row, col)
			return
		end
	else
		if not config.smear_between_buffers then
			M.jump(row, col)
			return
		end
	end

	if target_position[1] == row and target_position[2] == col then return end
	draw.clear()

	-- Draw end of previous smear
	if animating then
		if not previous_ending_drawn then
			set_stiffnesses(1, 0)
			update()
			draw.draw_quad(shrink_volume(current_corners), target_position)
			previous_ending_drawn = true
		end
		set_corners(current_corners, target_position[1], target_position[2])
	end

	target_position = { row, col }
	set_corners(target_corners, row, col)
	set_stiffnesses(config.stiffness, config.trailing_stiffness)

	if not animating then animate() end
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
