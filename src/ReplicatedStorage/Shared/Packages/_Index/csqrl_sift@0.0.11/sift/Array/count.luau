local Sift = script.Parent.Parent

local Util = require(Sift.Util)

local function count<T>(
	array: { T },
	predicate: ((value: T, index: number, array: { T }) -> any)?
): number
	local counter = 0

	predicate = if type(predicate) == "function" then predicate else Util.func.truthy

	for index, value in ipairs(array) do
		if predicate(value, index, array) then
			counter += 1
		end
	end

	return counter
end

return count
