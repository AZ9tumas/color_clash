local Sift = script.Parent.Parent

local Util = require(Sift.Util)

local function count<K, V>(
	dictionary: { [K]: V },
	predicate: ((value: V, key: K, dictionary: { [K]: V }) -> any)?
): number
	local counter = 0

	predicate = if type(predicate) == "function" then predicate else Util.func.truthy

	for key, value in pairs(dictionary) do
		if predicate(value, key, dictionary) then
			counter += 1
		end
	end

	return counter
end

return count
