local logging = require("smear_cursor.logging")
local M = {}


-- TODO: does not work
M.get_hl_group = function(row, col)
	-- Retrieve the current buffer
	local buffer_id = vim.api.nvim_get_current_buf()

    local extmarks = vim.api.nvim_buf_get_extmarks(
		buffer_id,
		-1,
		{row, col},
		{row, col + 1},
		{
			details = true,
			overlap = true,
		}
	)
	logging.debug(vim.inspect(extmarks))

    if #extmarks > 0 then
        local extmark = extmarks[1]
        if extmark[4] and extmark[4].hl_group then
            return extmark[4].hl_group
        end
    end

    return "Normal"
end


-- Get a color from a highlight group
local function get_hl_color(group, attr)
	local hl = vim.api.nvim_get_hl_by_name(group, true)
	if hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end


-- Get cursor foreground color and normal background color
local cursor_fg = get_hl_color("Normal", "foreground") -- Cursor color
local normal_bg = get_hl_color("Normal", "background") -- Normal background


local function set_hl_groups()
	vim.api.nvim_set_hl(0, M.hl_group, { fg = cursor_fg, bg = normal_bg })
	vim.api.nvim_set_hl(0, M.hl_group_inverted, { fg = normal_bg, bg = cursor_fg })
end


-- Define new highlight groups using the retrieved colors
M.hl_group = "SmearCursor"
M.hl_group_inverted = "SmearCursorInverted"
set_hl_groups()


local metatable = {
	__index = function(table, key)
		if key == "cursor_fg" then
			return cursor_fg
		end

		if key == "normal_bg" then
			return normal_bg
		end

		return nil
	end,

	__newindex = function(table, key, value)
		if key == "cursor_fg" then
			cursor_fg = value
			set_hl_groups()

		elseif key == "normal_bg" then
			normal_bg = value
			set_hl_groups()

		else
			rawset(table, key, value)
		end
	end
}

setmetatable(M, metatable)


return M
