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

-- local loop_metatable = {
-- 	__index = function(table, key)
-- 		if key == 5 then
-- 			return table[1]
-- 		else
-- 			return nil
-- 		end
-- 	end,
-- }

-- setmetatable(current_corners, loop_metatable)
-- setmetatable(target_corners, loop_metatable)

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
		draw.draw_quad(current_corners, target_position)
		-- TODO: draw character at cursor if hack is enabled
		-- local end_reached = ...
		-- if not end_reached and config.hide_target_hack then
		-- 	draw.draw_character(target_position[1], target_position[2], " ", color.get_hl_group({ inverted = true }))
		-- end
		vim.defer_fn(animate, config.time_interval)
	else
		animating = false
		set_corners(current_corners, target_position[1], target_position[2])
	end
end

local function set_stiffnesses()
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
		local stiffness = config.stiffness
			+ (config.trailing_stiffness - config.stiffness)
				* (distances[i] - min_distance)
				/ (max_distance - min_distance)
		stiffnesses[i] = math.min(1, stiffness)
	end
end

M.change_target_position = function(row, col, jump)
	if target_position[1] == row and target_position[2] == col then
		return
	end
	draw.clear()

	if animating then
		draw.draw_quad(current_corners, target_position)
		set_corners(current_corners, target_position[1], target_position[2])
	end

	target_position = { row, col }
	set_corners(target_corners, row, col)
	if jump then
		set_corners(current_corners, row, col)
		return
	end

	if not animating then
		set_stiffnesses()
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
