local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local round = require("smear_cursor.math").round
local screen = require("smear_cursor.screen")
local M = {}

local animating = false
local target_position = { 0, 0 }
local current_corners = {}
local target_corners = {}
local stiffnesses = { 0, 0, 0, 0 }

local function set_corners(corners, row, col)
	corners[1] = { row, col }
	corners[2] = { row, col + 1 }
	corners[3] = { row + 1, col + 1 }
	corners[4] = { row + 1, col }
end

vim.defer_fn(function()
	local cursor_row, cursor_col = screen.get_screen_cursor_position()
	target_position = { cursor_row, cursor_col }
	set_corners(current_corners, cursor_row, cursor_col)
	set_corners(target_corners, cursor_row, cursor_col)
end, 0)

local function update()
	for i = 1, 4 do
		local distance_squared = (current_corners[i][1] - target_corners[i][1]) ^ 2
			+ (current_corners[i][2] - target_corners[i][2]) ^ 2
		local stiffness = math.min(1, stiffnesses[i] * distance_squared ^ config.slowdown_exponent)
		for j = 1, 2 do
			current_corners[i][j] = current_corners[i][j] + (target_corners[i][j] - current_corners[i][j]) * stiffness
		end
	end
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

	local center = {
		(corners[1][1] + corners[2][1] + corners[3][1] + corners[4][1]) / 4,
		(corners[1][2] + corners[2][2] + corners[3][2] + corners[4][2]) / 4,
	}

	local factor = (1 / volume) ^ (config.volume_reduction_exponent / 2)
	factor = math.max(config.minimum_volume_factor, factor)
	local shrunk_corners = {}
	for i = 1, 4 do
		shrunk_corners[i] = {
			center[1] + (corners[i][1] - center[1]) * factor,
			center[2] + (corners[i][2] - center[2]) * factor,
		}
	end

	return shrunk_corners
end

local function animate()
	animating = true
	update()
	draw.clear()

	local max_distance = 0
	for i = 1, 4 do
		local distance = math.sqrt(
			(current_corners[i][1] - target_corners[i][1]) ^ 2 + (current_corners[i][2] - target_corners[i][2]) ^ 2
		)
		max_distance = math.max(max_distance, distance)
	end
	if max_distance > config.distance_stop_animating then
		local shrunk_corners = shrink_volume(current_corners)
		draw.draw_quad(shrunk_corners, target_position)
		local target_reached = (
			math.floor(current_corners[1][1]) == target_position[1]
			and math.floor(current_corners[1][2]) == target_position[2]
		)
			or (math.floor(current_corners[2][1]) == target_position[1] and math.ceil(current_corners[2][2]) - 1 == target_position[2])
			or (math.ceil(current_corners[3][1]) - 1 == target_position[1] and math.ceil(current_corners[3][2]) - 1 == target_position[2])
			or (
				math.ceil(current_corners[4][1]) - 1 == target_position[1]
				and math.floor(current_corners[4][2]) == target_position[2]
			)
		if not target_reached and config.hide_target_hack then
			draw.draw_character(target_position[1], target_position[2], " ", color.get_hl_group({ inverted = true }))
		end
		vim.defer_fn(animate, config.time_interval)
	else
		animating = false
		set_corners(current_corners, target_position[1], target_position[2])
	end
end

local function set_stiffnesses(head_stiffness, trailing_stiffness)
	local target_center = { target_position[1] + 0.5, target_position[2] + 0.5 }
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

	for i = 1, 4 do
		local stiffness = head_stiffness
			+ (trailing_stiffness - head_stiffness) * (distances[i] - min_distance) / (max_distance - min_distance)
		stiffnesses[i] = math.min(1, stiffness)
	end
end

M.change_target_position = function(row, col, jump)
	if target_position[1] == row and target_position[2] == col then
		return
	end
	draw.clear()

	-- Draw end of previous smear
	if animating then
		set_stiffnesses(1, 0)
		update()
		draw.draw_quad(shrink_volume(current_corners), target_position)
		set_corners(current_corners, target_position[1], target_position[2])
	end

	target_position = { row, col }
	set_corners(target_corners, row, col)
	set_stiffnesses(config.stiffness, config.trailing_stiffness)

	if jump then
		set_corners(current_corners, row, col)
		return
	end

	if not animating then
		animate()
	end
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
