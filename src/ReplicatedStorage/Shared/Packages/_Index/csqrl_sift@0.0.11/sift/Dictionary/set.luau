local copy = require(script.Parent.copy)

local function set<K, V>(dictionary: { [K]: V }, key: K, value: V): { [K]: V }
	local result = copy(dictionary)

	result[key] = value

	return result
end

return set
