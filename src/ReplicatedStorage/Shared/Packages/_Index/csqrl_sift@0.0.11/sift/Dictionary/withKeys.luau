local function withKeys<K, V>(dictionary: { [K]: V }, ...: K): { [K]: V }
	local result = {}

	for _, key in ipairs({ ... }) do
		result[key] = dictionary[key]
	end

	return result
end

return withKeys
