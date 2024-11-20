local M = {}


M.LOGGING_LEVEL = vim.log.levels.DEBUG
M.USE_FLOATING_WINDOWS = false -- Better capabilities but can have bad berformance with some plugins
M.LEGACY_COMPUTING_SYMBOLS_SUPPORT = false

M.TIME_INTERVAL = 17 -- milliseconds
M.DONT_ERASE = false -- Set to true for debugging
M.MAX_SLOPE_HORIZONTAL = 0.5
M.MIN_SLOPE_VERTICAL = 2

M.DISTANCE_STOP_ANIMATING = 0.125 -- characters
M.STIFFNESS = 0.6 -- 1: instantaneous, 0: no movement
M.TRAILING_STIFFNESS = 0.2
M.TRAILING_EXPONENT = 0.15 -- trailing stifness is multiplied by trailing_distance^TRAILING_POWER


if M.DONT_ERASE then
	M.TRAILING = 1
end


return M
