local function some<K, V>(
	dictionary: { [K]: V },
	predicate: (value: V, key: V, dictionary: { [K]: V }) -> any
): boolean
	for key, value in pairs(dictionary) do
		if predicate(value, key, dictionary) then
			return true
		end
	end

	return false
end

return some
