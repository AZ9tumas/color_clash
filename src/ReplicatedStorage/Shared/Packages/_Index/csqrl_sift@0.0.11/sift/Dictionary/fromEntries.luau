local function fromEntries<K, V>(entries: { [number]: { [number]: K | V } }): { [K]: V }
	local result = {}

	for _, entry in ipairs(entries) do
		result[entry[1]] = entry[2]
	end

	return result
end

return fromEntries
