local Sift = script.Parent.Parent

local Util = require(Sift.Util)

local function filter<T>(
	array: { T },
	predicate: ((value: T, index: number, array: { T }) -> boolean?)?
): { T }
	local result = {}

	predicate = if type(predicate) == "function" then predicate else Util.func.truthy

	for index, value in ipairs(array) do
		if predicate(value, index, array) then
			table.insert(result, value)
		end
	end

	return result
end

return filter
