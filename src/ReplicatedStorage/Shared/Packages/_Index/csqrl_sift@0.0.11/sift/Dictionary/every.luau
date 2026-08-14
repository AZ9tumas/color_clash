local function every<K, V>(
	dictionary: { [K]: V },
	predicate: (value: V, key: K, dictionary: { [K]: V }) -> any
): boolean
	for key, value in pairs(dictionary) do
		if not predicate(value, key, dictionary) then
			return false
		end
	end

	return true
end

return every
