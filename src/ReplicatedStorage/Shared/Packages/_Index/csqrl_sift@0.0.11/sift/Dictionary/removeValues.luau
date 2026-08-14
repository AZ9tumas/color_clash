local Sift = script.Parent.Parent

local ToSet = require(Sift.Array.toSet)

local function removeValues<K, V>(dictionary: { [K]: V }, ...: V): { [K]: V }
	local values = ToSet({ ... })
	local result = {}

	for key, value in pairs(dictionary) do
		if not values[value] then
			result[key] = value
		end
	end

	return result
end

return removeValues
