local M = {}

-- General configuration -------------------------------------------------------

-- Smear cursor when switching buffers or windows
M.smear_between_buffers = true

-- Smear cursor when moving within line or to neighbor lines
M.smear_between_neighbor_lines = true

-- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
-- Smears will blend better on all backgrounds.
M.legacy_computing_symbols_support = false

-- Attempt to hide the real cursor by drawing a character below it.
M.hide_target_hack = true

M.time_interval = 17 -- milliseconds

-- Smear configuration ---------------------------------------------------------

-- How fast the smear's head moves towards the target.
-- 0: no movement, 1: instantaneous
M.stiffness = 0.6

-- How fast the smear's tail moves towards the target.
-- 0: no movement, 1: instantaneous
M.trailing_stiffness = 0.3

-- How much the tail slows down when getting close to the head.
-- 0: no slowdown, more: more slowdown
M.slowdown_exponent = 0

-- Stop animating when the smear's tail is within this distance (in characters) from the target.
M.distance_stop_animating = 0.1

-- When to switch between rasterization methods
M.max_slope_horizontal = 0.5
M.min_slope_vertical = 2

M.color_levels = 16 -- Minimum 1
M.gamma = 2.2 -- For color blending
M.diagonal_pixel_value_threshold = 0.25 -- 0.1: more pixels, 0.9: less pixels
M.volume_reduction_exponent = 0.2 -- 0: no reduction, 1: full reduction
M.minimum_volume_factor = 0.7 -- 0: no limit, 1: no reduction

-- For debugging ---------------------------------------------------------------

M.logging_level = vim.log.levels.INFO
-- Set trailing_stiffness to 0 for debugging

return M
