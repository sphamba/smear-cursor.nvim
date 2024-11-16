local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local logging = require("smear_cursor.logging")
local M = {}


local target_position = {1, 1}
local current_position = {1, 1}
local animating = false


local function update()
	current_position[1] = current_position[1] + (target_position[1] - current_position[1]) * config.STIFFNESS
	current_position[2] = current_position[2] + (target_position[2] - current_position[2]) * config.STIFFNESS
end


local function animate()
	local previous_position = {current_position[1], current_position[2]}
	update()

	local distance = math.sqrt((target_position[1] - current_position[1])^2 + (target_position[2] - current_position[2])^2)
	if not config.DONT_ERASE then draw.clear() end
	if distance > 1.5 then
		local trailing_position = {
			current_position[1] - (current_position[1] - previous_position[1]) * config.TRAILING,
			current_position[2] - (current_position[2] - previous_position[2]) * config.TRAILING
		}
		draw.draw_line(trailing_position[1], trailing_position[2], current_position[1], current_position[2])
	else
		draw.draw_line(previous_position[1], previous_position[2], target_position[1], target_position[2], true)
	end

	if distance > config.DISTANCE_STOP_ANIMATING then
		animating = true
		vim.defer_fn(animate, config.TIME_INTERVAL)
	else
		animating = false
		if not config.DONT_ERASE then draw.clear() end
		current_position = {target_position[1], target_position[2]}
	end
end


M.change_target_position = function(row, col)
	if config.DONT_ERASE then draw.clear() end

	if animating then
		draw.draw_line(current_position[1], current_position[2], target_position[1], target_position[2])
		current_position = {target_position[1], target_position[2]}
	end

	target_position = {row, col}

	if not animating then
		animate()
	end
end


return M
