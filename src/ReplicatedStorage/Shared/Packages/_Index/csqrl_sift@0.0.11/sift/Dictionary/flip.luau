local function flip<K, V>(dictionary: { [K]: V }): { [V]: K }
	local result = {}

	for key, value in pairs(dictionary) do
		result[value] = key
	end

	return result
end

return flip
