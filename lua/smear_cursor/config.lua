local M = {}


M.LOGGING_LEVEL = vim.log.levels.INFO

M.TIME_INTERVAL = 17 -- milliseconds
M.DONT_ERASE = false -- Set to true for debugging
M.MAX_SLOPE_HORIZONTAL = 0.5
M.MIN_SLOPE_VERTICAL = 2

M.DISTANCE_STOP_ANIMATING = 0.2 -- characters
M.STIFFNESS = 0.7 -- 1: instantaneous, 0: no movement
M.STIFFNESS_VARIATION = 0.2 -- range of randomness in stiffness
M.TRAILING = 0.5 -- 1: full trailing, 0: no trailing


if M.DONT_ERASE then
	M.TRAILING = 1
end


return M