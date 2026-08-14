local copy = require(script.Parent.copy)

local function removeKey<K, V>(dictionary: { [K]: V }, key: K): { [K]: V }
	local result = copy(dictionary)

	result[key] = nil

	return result
end

return removeKey
