local config = require("smear_cursor.config")
local events = require("smear_cursor.events")


-- Remove Airline autocmd to prevent bad performance
if config.USE_FLOATING_WINDOWS then
	vim.cmd([[
		augroup airline
			autocmd! BufWinEnter,BufUnload
		augroup END
	]])
end


events.listen()
