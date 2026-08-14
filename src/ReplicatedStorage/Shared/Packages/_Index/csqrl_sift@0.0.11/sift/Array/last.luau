local At = require(script.Parent.at)

local function last<T>(array: { T }): T
	return At(array, 0)
end

return last
