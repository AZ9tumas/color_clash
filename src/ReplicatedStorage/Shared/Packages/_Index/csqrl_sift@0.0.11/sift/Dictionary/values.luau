local function values<K, V>(dictionary: { [K]: V }): { V }
	local result = {}

	for _, value in pairs(dictionary) do
		table.insert(result, value)
	end

	return result
end

return values
