-- All the following options can be set using the `setup` function.
-- Refer to the README for more information.

local M = {}

-- General configuration -------------------------------------------------------

-- Smear cursor when switching buffers or windows
M.smear_between_buffers = true

-- Smear cursor when moving within line or to neighbor lines
-- Use `min_horizontal_distance_smear` and `min_vertical_distance_smear` for finer control
M.smear_between_neighbor_lines = true

-- Only smear cursor when moving at least these distances
M.min_horizontal_distance_smear = 0
M.min_vertical_distance_smear = 0

-- Toggles for directions
M.smear_horizontally = true
M.smear_vertically = true
M.smear_diagonally = true -- Neither horizontal nor vertical

-- Smear cursor when entering or leaving command line mode
M.smear_to_cmd = true

-- Draw the smear in buffer space instead of screen space when scrolling
M.scroll_buffer_space = true

-- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
-- Smears will blend better on all backgrounds.
M.legacy_computing_symbols_support = false
M.legacy_computing_symbols_support_vertical_bars = false
M.use_diagonal_blocks = true -- Only effective if `legacy_computing_symbols_support` is `true`

-- Set to `true` if your cursor is a vertical bar in normal mode.
M.vertical_bar_cursor = false

-- Smear cursor in insert mode.
-- See also `vertical_bar_cursor_insert_mode` and `distance_stop_animating_vertical_bar`.
M.smear_insert_mode = true

-- Set to `true` if your cursor is a vertical bar in insert mode.
M.vertical_bar_cursor_insert_mode = true

-- Smear cursor in replace mode.
M.smear_replace_mode = false

-- Smear cursor in terminal mode.
-- If the smear goes to the wrong location when enabled, try increasing `delay_after_key`.
M.smear_terminal_mode = false

-- Set to `true` if your cursor is a horizontal bar in replace mode.
M.horizontal_bar_cursor_replace_mode = true

-- Set to `true` to prevent the smear from overlapping the target character, hiding it until the animation is over.
M.never_draw_over_target = false

-- Attempt to hide the real cursor by drawing a character below it.
-- Can be useful when not using `termguicolors`
-- Do not set to `true` if `never_draw_over_target` is `false`.
M.hide_target_hack = false

-- Number of windows that stay open for rendering.
M.max_kept_windows = 50

-- Adjust to have the smear appear above or below other floating windows
M.windows_zindex = 300

-- List of filetypes where the plugin is disabled.
M.filetypes_disabled = {}

-- Sets animation framerate
M.time_interval = 17 -- milliseconds

-- Disable smear in the current buffer if the animation is stuck for at least this amount of time.
-- Set to nil to disable this feature.
M.delay_disable = nil -- milliseconds

-- Amount of time the cursor has to stay still before triggering animation.
-- Useful if the target changes and rapidly comes back to its original position.
-- E.g. when hitting a keybinding that triggers CmdlineEnter.
-- Increase if the cursor makes weird jumps when hitting keys.
M.delay_event_to_smear = 1 -- milliseconds

-- Delay for `vim.on_key` to avoid redundancy with vim events triggers.
M.delay_after_key = 5 -- milliseconds

-- Smear configuration ---------------------------------------------------------

-- How fast the smear's head moves towards the target.
-- 0: no movement, 1: instantaneous
M.stiffness = 0.6

-- How fast the smear's tail moves towards the target.
-- 0: no movement, 1: instantaneous
M.trailing_stiffness = 0.45

-- Initial velocity factor in the direction opposite to the target
M.anticipation = 0.2

-- Velocity reduction over time. O: no reduction, 1: full reduction
M.damping = 0.85

-- Controls if middle points are closer to the head or the tail.
-- < 1: closer to the tail, > 1: closer to the head
M.trailing_exponent = 3

-- Stop animating when the smear's tail is within this distance (in characters) from the target.
M.distance_stop_animating = 0.1

-- Set of parameters for insert mode
M.stiffness_insert_mode = 0.5
M.trailing_stiffness_insert_mode = 0.5
M.damping_insert_mode = 0.9
M.trailing_exponent_insert_mode = 1
M.distance_stop_animating_vertical_bar = 0.875 -- Can be decreased (e.g. to 0.1) if using legacy computing symbols

-- When to switch between rasterization methods
M.max_slope_horizontal = (1 / 3) / 1.5
M.min_slope_vertical = 2 * 1.5
M.max_angle_difference_diagonal = math.pi / 16 -- radians
M.max_offset_diagonal = 0.2 -- cell widths
M.min_shade_no_diagonal = 0.2 -- 0: less diagonal blocks, 1: more diagonal blocks
M.min_shade_no_diagonal_vertical_bar = 0.5

M.color_levels = 16 -- Minimum 1, don't set manually if using cterm_cursor_colors
M.gamma = 2.2 -- For color blending
M.gradient_exponent = 1.0 -- For longitudinal gradient. 0: no gradient, 1: linear, ...
M.max_shade_no_matrix = 0.75 -- 0: more overhangs, 1: more matrices
M.matrix_pixel_threshold = 0.7 -- 0: all pixels, 1: no pixel
M.matrix_pixel_threshold_vertical_bar = 0.25 -- 0: all pixels, 1: no pixel
M.matrix_pixel_min_factor = 0.5 -- 0: all pixels, 1: no pixel
M.volume_reduction_exponent = 0.3 -- 0: no reduction, 1: full reduction
M.minimum_volume_factor = 0.7 -- 0: no limit, 1: no reduction
M.max_length = 25 -- Maximum smear length
M.max_length_insert_mode = 1

-- Particles configuration -----------------------------------------------------

M.particles_enabled = false -- When true, better to also set `never_draw_over_target` to true
M.particle_max_num = 100
M.particle_spread = 0.5 -- 0: no spread, 1: spread over entire cursor
M.particles_per_second = 200
M.particles_per_length = 1.0 -- per character width
M.particle_max_lifetime = 300 -- milliseconds
M.particle_lifetime_distribution_exponent = 5
M.particle_max_initial_velocity = 10 -- characters width per second
M.particle_velocity_from_cursor = 0.2 -- 0: none, 1: full
M.particle_random_velocity = 100 -- characters width per second
M.particle_damping = 0.2
M.particle_gravity = 20 -- characters width per second squared
M.min_distance_emit_particles = 1.5 -- character widths
M.particle_switch_octant_braille = 0.3 -- fraction of lifetime, used if `legacy_computing_symbols_support` is true
M.particles_over_text = false

-- For debugging ---------------------------------------------------------------

M.logging_level = vim.log.levels.INFO
-- Set trailing_stiffness to 0 for debugging

return M
