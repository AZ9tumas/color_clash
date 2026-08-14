local At = require(script.Parent.at)

local function first<T>(array: { T }): T
	return At(array, 1)
end

return first
