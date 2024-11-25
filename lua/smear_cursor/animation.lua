local color = require("smear_cursor.color")
local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local round = require("smear_cursor.math").round
local screen = require("smear_cursor.screen")
local M = {}


local cursor_row, cursor_col = screen.get_screen_cursor_position()
local target_position = {cursor_row + 1, cursor_col + 1} -- Not sure why +1 is needed
local current_position = {target_position[1], target_position[2]}
local trailing_position = {target_position[1], target_position[2]}
local animating = false


local function update()
	current_position[1] = current_position[1] + (target_position[1] - current_position[1]) * config.stiffness
	current_position[2] = current_position[2] + (target_position[2] - current_position[2]) * config.stiffness

	local trailing_distance_squared = (current_position[1] - trailing_position[1])^2 + (current_position[2] - trailing_position[2])^2
	local trailing_stiffness = math.min(1, config.trailing_stiffness * trailing_distance_squared^config.trailing_exponent)
	trailing_position[1] = trailing_position[1] + (current_position[1] - trailing_position[1]) * trailing_stiffness
	trailing_position[2] = trailing_position[2] + (current_position[2] - trailing_position[2]) * trailing_stiffness
end


local function animate()
	if not animating then return end
	update()

	if not config.dont_erase then draw.clear() end
	local end_reached = round(current_position[1]) == target_position[1] and round(current_position[2]) == target_position[2]
	draw.draw_line(trailing_position[1], trailing_position[2], current_position[1], current_position[2], end_reached)
	if not end_reached and config.hide_target_hack then
		draw.draw_character(target_position[1], target_position[2], " ", color.hl_group_inverted)
	end

	local trailing_distance = math.sqrt((target_position[1] - trailing_position[1])^2 + (target_position[2] - trailing_position[2])^2)
	if trailing_distance > config.distance_stop_animating then
		animating = true
		vim.defer_fn(animate, config.time_interval)
	else
		animating = false
		if not config.dont_erase then draw.clear() end
		current_position = {target_position[1], target_position[2]}
		trailing_position = {target_position[1], target_position[2]}
	end
end


M.change_target_position = function(row, col, jump)
	jump = jump or (not config.smear_between_neighbor_lines and math.abs(row - current_position[1]) <= 1)
	if (target_position[1] == row and target_position[2] == col) then return end
	draw.clear()

	if animating then
		draw.draw_line(trailing_position[1], trailing_position[2], target_position[1], target_position[2])
		current_position = {target_position[1], target_position[2]}
		trailing_position = {target_position[1], target_position[2]}
	end

	target_position = {row, col}
	if jump then
		current_position = {row, col}
		trailing_position = {row, col}
		return
	end

	if not animating then
		animating = true
		animate()
	end
end


return M
