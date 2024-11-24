local M = {}


M.logging_level = vim.log.levels.INFO
M.dont_erase = false -- Set to true for debugging

M.smear_between_buffers = true -- Smear cursor when switching buffers
M.smear_between_neighbor_lines = true -- Smear cursor when moving within line or to neighbor lines
M.use_floating_windows = true -- Fallback when extmarks cannot be drawn
M.legacy_computing_symbols_support = false -- Allow for blending of background colors
M.hide_target_hack = true -- Attempt to hide true cursor by drawing a character below it

M.time_interval = 17 -- milliseconds
M.max_slope_horizontal = 0.5
M.min_slope_vertical = 2
M.color_levels = 16 -- Minimum 1
M.gamma = 2.2
M.distance_stop_animating = 0.1 -- characters
M.stiffness = 0.6 -- 1: instantaneous, 0: no movement
M.trailing_stiffness = 0.3
M.trailing_exponent = 0.1 -- trailing stifness is multiplied by trailing_distance^TRAILING_EXPONENT
M.diagonal_pixel_value_threshold = 0.5 -- 0.1: more pixels, 0.9: less pixels
M.diagonal_thickness_factor = 0.7 -- put less than 1 to reduce diagonal smear fatness
M.thickness_reduction = 0.2 -- 0: no reduction, 1: full reduction


return M
