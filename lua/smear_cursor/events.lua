local config = require("smear_cursor.config")
local draw = require("smear_cursor.draw")
local logging = require("smear_cursor.logging")
local M = {}


-- Get cursor position (1-indexed)
M.get_cursor_position = function()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local col = vim.fn.virtcol(".", 1)[1] -- Take into account wide characters
	logging.debug("Cursor position (" .. row .. ", " .. col .. ")")
	return row, col
end


local previous_cursor_position = {1, 1}


M.on_cursor_moved = function()
	local row, col = M.get_cursor_position()

	if config.DONT_ERASE then draw.clear() end
	draw.draw_line(previous_cursor_position[1], previous_cursor_position[2], row, col)
	previous_cursor_position = {row, col}

	if config.DONT_ERASE then return end
	vim.defer_fn(draw.clear, config.PERSISTENCE)
end


M.listen = function()
	vim.api.nvim_exec([[
		augroup GetCursorPosition
			autocmd!
			autocmd CursorMoved * lua require("smear_cursor.events").on_cursor_moved()
		augroup END
	]], false)
end


return M
