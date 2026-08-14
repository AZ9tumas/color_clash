local function fromArrays<K, V>(keys: { K }, values: { V }): { [K]: V }
	local keysLength = #keys
	local result = {}

	for i = 1, keysLength do
		result[keys[i]] = values[i]
	end

	return result
end

return fromArrays
