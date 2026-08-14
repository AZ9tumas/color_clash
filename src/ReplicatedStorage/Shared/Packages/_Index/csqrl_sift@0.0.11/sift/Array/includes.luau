local Find = require(script.Parent.find)

local function includes<T>(array: { T }, value: any, from: number?): boolean
	return Find(array, value, from) ~= nil
end

return includes
