local logging = require("smear_cursor.logging")
local M = {}


M.get_screen_cursor_position = function(window_id)
	window_id = window_id or vim.api.nvim_get_current_win()

	local window_origin = vim.api.nvim_win_get_position(window_id)
	local window_row = window_origin[1]
	local window_col = window_origin[2]
	local screen_row = window_row + vim.fn.winline()
	local screen_col = window_col + vim.fn.wincol()

	-- Count concealed characters
	local n_concealed = 0
	local n_replacements = 0
	local cursor_row = vim.fn.line(".")
	local cursor_col = vim.fn.col(".")
	local last_region = 0
	for col = 1, cursor_col - 1 do
		local concealed_info = vim.fn.synconcealed(cursor_row, col)
		local concealed, replacement, region = concealed_info[1], concealed_info[2], concealed_info[3]
		if concealed == 1 then
			n_concealed = n_concealed + 1
			if region ~= last_region then
				n_replacements = n_replacements + #replacement
				last_region = region
			end
		end
	end

	-- logging.debug("screen_col: " .. screen_col .. ", n_concealed: " .. n_concealed .. ", n_replacements: " .. n_replacements)

	return screen_row, screen_col - n_concealed + n_replacements
end


local function get_window_containing_position(screen_row, screen_col)
	local current_tab = vim.api.nvim_get_current_tabpage()
	local window_ids = vim.api.nvim_tabpage_list_wins(current_tab)

	for _, window_id in pairs(window_ids) do
		local window_origin = vim.api.nvim_win_get_position(window_id)
		local window_row = window_origin[1] + 1
		local window_col = window_origin[2] + 1
		local window_height = vim.api.nvim_win_get_height(window_id)
		local window_width = vim.api.nvim_win_get_width(window_id)

		if screen_row >= window_row and screen_row < window_row + window_height and
			screen_col >= window_col and screen_col < window_col + window_width then
			return window_id
		end
	end

	return nil
end


M.screen_to_buffer = function(screen_row, screen_col)
	local window_id = get_window_containing_position(screen_row, screen_col)
	if window_id == nil then
		return nil
	end

	local buffer_id = vim.api.nvim_win_get_buf(window_id)

	-- If buffer appears in another visible window, return nil
	local buffer_window_ids = vim.fn.getbufinfo(buffer_id)[1].windows
	local current_tab = vim.api.nvim_get_current_tabpage()
	local tab_window_ids = vim.api.nvim_tabpage_list_wins(current_tab)
	for _, other_window_id in pairs(tab_window_ids) do
		if other_window_id ~= window_id and vim.tbl_contains(buffer_window_ids, other_window_id) then
			return nil
		end
	end

	local start_row = vim.fn.line("w0", window_id)
	local buffer_origin = vim.fn.screenpos(window_id, start_row, 1)
	local col = screen_col - buffer_origin.col + 1
	local col_shift = 0 -- To draw to the left of wrapped lines, positive

	-- Find the buffer row corresponding to the screen row
	-- Take into account folds and wrapped lines
	local buffer_row = start_row
	local current_screen_row = buffer_origin.row

	while (current_screen_row < screen_row) do
		if vim.fn.foldclosed(buffer_row) ~= -1 then
			buffer_row = vim.fn.foldclosedend(buffer_row) + 1
			current_screen_row = current_screen_row + 1

		else

			local text_height
			local success = pcall(function()
				text_height = vim.api.nvim_win_text_height(window_id, {
					start_row = buffer_row - 1,
					end_row = buffer_row - 1,
				})
			end)

			if not success then -- line is not visible
				return nil
			end

			buffer_row = buffer_row + 1
			current_screen_row = current_screen_row + text_height.all
		end
	end

	if current_screen_row > screen_row then
		return nil -- in wrapped line
	end

	return buffer_id, buffer_row, col, col_shift
end


return M
