local function entries<K, V>(dictionary: { [K]: V }): { [number]: { [number]: K | V } }
	local result = {}

	for key, value in pairs(dictionary) do
		table.insert(result, { key, value })
	end

	return result
end

return entries
