local M = {}

M.round = function(x)
	return math.floor(x + 0.5)
end

local atan_cache = {}

M.atan_cached = function(x)
	if atan_cache[x] == nil then atan_cache[x] = math.atan(x) end
	return atan_cache[x]
end

return M
