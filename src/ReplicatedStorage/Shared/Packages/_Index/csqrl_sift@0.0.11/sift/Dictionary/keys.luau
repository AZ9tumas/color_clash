local function keys<K, V>(dictionary: { [K]: V }): { K }
	local result = {}

	for key in pairs(dictionary) do
		table.insert(result, key)
	end

	return result
end

return keys
