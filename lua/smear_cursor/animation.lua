local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local round = require("smear_cursor.math").round
local screen = require("smear_cursor.screen")
local M = {}


local cursor_row, cursor_col = screen.get_screen_cursor_position()
local target_position = {cursor_row, cursor_col}
local current_position = {cursor_row, cursor_col}
local trailing_position = {cursor_row, cursor_col}
local animating = false


local function update()
	current_position[1] = current_position[1] + (target_position[1] - current_position[1]) * config.STIFFNESS
	current_position[2] = current_position[2] + (target_position[2] - current_position[2]) * config.STIFFNESS

	local trailing_distance_squared = (current_position[1] - trailing_position[1])^2 + (current_position[2] - trailing_position[2])^2
	local trailing_stiffness = math.min(1, config.TRAILING_STIFFNESS * trailing_distance_squared^config.TRAILING_EXPONENT)
	trailing_position[1] = trailing_position[1] + (current_position[1] - trailing_position[1]) * trailing_stiffness
	trailing_position[2] = trailing_position[2] + (current_position[2] - trailing_position[2]) * trailing_stiffness
end


local function animate()
	update()

	if not config.DONT_ERASE then draw.clear() end
	local skip_end = round(current_position[1]) == target_position[1] and round(current_position[2]) == target_position[2]
	draw.draw_line(trailing_position[1], trailing_position[2], current_position[1], current_position[2], skip_end)

	local trailing_distance = math.sqrt((target_position[1] - trailing_position[1])^2 + (target_position[2] - trailing_position[2])^2)
	if trailing_distance > config.DISTANCE_STOP_ANIMATING then
		animating = true
		vim.defer_fn(animate, config.TIME_INTERVAL)
	else
		animating = false
		if not config.DONT_ERASE then draw.clear() end
		current_position = {target_position[1], target_position[2]}
	end
end


M.change_target_position = function(row, col, jump)
	if jump == nil then jump = false end
	if config.DONT_ERASE then draw.clear() end

	if animating then
		draw.draw_line(trailing_position[1], current_position[2], trailing_position[1], target_position[2])
		current_position = {target_position[1], target_position[2]}
		trailing_position = {target_position[1], target_position[2]}
	end

	target_position = {row, col}
	if jump then
		current_position = {row, col}
		trailing_position = {row, col}
	end

	if not animating then
		animate()
	end
end


return M
