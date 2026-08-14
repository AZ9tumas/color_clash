local Sift = script.Parent.Parent

local Util = require(Sift.Util)

local function filter<K, V>(
	dictionary: { [K]: V },
	predicate: ((value: V, key: K, dictionary: { [K]: V }) -> any)?
): { [K]: V }
	local result = {}

	predicate = if type(predicate) == "function" then predicate else Util.func.truthy

	for key, value in pairs(dictionary) do
		if predicate(value, key, dictionary) then
			result[key] = value
		end
	end

	return result
end

return filter
