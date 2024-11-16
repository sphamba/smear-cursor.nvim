local M = {}


M.LOGGING_LEVEL = vim.log.levels.DEBUG

M.TIME_INTERVAL = 17 -- milliseconds
M.DONT_ERASE = false -- Set to true for debugging
M.MAX_SLOPE_HORIZONTAL = 0.5
M.MIN_SLOPE_VERTICAL = 2

M.DISTANCE_STOP_ANIMATING = 0.2 -- characters
M.STIFFNESS = 0.7 -- 1: instantaneous, 0: no movement
M.TRAILING = 0.5 -- 1: full trailing, 0: no trailing


return M
