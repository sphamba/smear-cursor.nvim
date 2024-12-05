local M = {}

-- stylua: ignore start
local level_names = {}
level_names[vim.log.levels.TRACE] = "TRACE"
level_names[vim.log.levels.DEBUG] = "DEBUG"
level_names[vim.log.levels.INFO]  = "INFO"
level_names[vim.log.levels.WARN]  = "WARNING"
level_names[vim.log.levels.ERROR] = "ERROR"
-- stylua: ignore end

local function log(message, level)
	local logging_level = require("smear_cursor.config").logging_level
	local level_name = vim.log.levels[level + 1]

	if logging_level <= level then vim.notify("[smear_cursor][" .. level_names[level] .. "] " .. message, level) end
end

M.trace = function(message)
	log(message, vim.log.levels.TRACE)
end

M.debug = function(message)
	log(message, vim.log.levels.DEBUG)
end

M.info = function(message)
	log(message, vim.log.levels.INFO)
end

M.warning = function(message)
	log(message, vim.log.levels.WARN)
end

M.error = function(message)
	log(message, vim.log.levels.ERROR)
end

return M
