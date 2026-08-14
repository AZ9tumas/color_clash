local copy = require(script.Parent.copy)

local function removeKeys<K, V>(dictionary: { [K]: V }, ...: K): { [K]: V }
	local result = copy(dictionary)

	for _, key in ipairs({ ... }) do
		result[key] = nil
	end

	return result
end

return removeKeys
