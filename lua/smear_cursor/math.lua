local M = {}


M.round = function(x)
	return math.floor(x + 0.5)
end


M.sign = function(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end


return M
