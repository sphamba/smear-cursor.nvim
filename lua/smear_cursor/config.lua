local M = {}


M.LOGGING_LEVEL = vim.log.levels.INFO
M.USE_FLOATING_WINDOWS = true -- Fallback when extmarks cannot be drawn
M.LEGACY_COMPUTING_SYMBOLS_SUPPORT = false -- Allow for blending of background colors
M.HIDE_TARGET_HACK = true -- Attempt to hide true cursor by drawing a character below it

M.TIME_INTERVAL = 17 -- milliseconds
M.DONT_ERASE = false -- Set to true for debugging
M.MAX_SLOPE_HORIZONTAL = 0.5
M.MIN_SLOPE_VERTICAL = 2
M.COLOR_LEVELS = 16 -- Minimum 1
M.GAMMA = 2.2

M.DISTANCE_STOP_ANIMATING = 0.1 -- characters
M.STIFFNESS = 0.6 -- 1: instantaneous, 0: no movement
M.TRAILING_STIFFNESS = 0.3
M.TRAILING_EXPONENT = 0.1 -- trailing stifness is multiplied by trailing_distance^TRAILING_EXPONENT
M.DIAGONAL_PIXEL_VALUE_THRESHOLD = 0.5 -- 0.1: more pixels, 0.9: less pixels
M.DIAGONAL_THICKNESS_FACTOR = 0.7 -- put less than 1 to reduce diagonal smear fatness
M.THICKNESS_REDUCTION = 0.3 -- 0: no reduction, 1: full reduction


if M.DONT_ERASE then
	M.TRAILING = 1
end


return M
