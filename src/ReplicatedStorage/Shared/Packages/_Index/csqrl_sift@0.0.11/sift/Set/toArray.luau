local function toArray<T>(set: { [T]: boolean }): { T }
	local result = {}

	for key, _ in pairs(set) do
		table.insert(result, key)
	end

	return result
end

return toArray
