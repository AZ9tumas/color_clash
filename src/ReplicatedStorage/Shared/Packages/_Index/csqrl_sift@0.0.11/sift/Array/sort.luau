local Copy = require(script.Parent.copy)

local function sort<T>(array: { T }, comparator: ((firstValue: T, secondValue: T) -> boolean)?): { T }
	local result = Copy(array)

	table.sort(result, comparator)

	return result
end

return sort
