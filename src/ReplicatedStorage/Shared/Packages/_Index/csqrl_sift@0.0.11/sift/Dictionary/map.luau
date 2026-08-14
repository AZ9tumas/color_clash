local function map<K, V, X, Y>(
	dictionary: { [K]: V },
	mapper: (value: V, key: K, dictionary: { [K]: V }) -> (Y?, X?)
): { [X]: Y }
	local mapped = {}

	for key, value in pairs(dictionary) do
		local mappedValue, mappedKey = mapper(value, key, dictionary)
		mapped[mappedKey or key] = mappedValue
	end

	return mapped
end

return map
