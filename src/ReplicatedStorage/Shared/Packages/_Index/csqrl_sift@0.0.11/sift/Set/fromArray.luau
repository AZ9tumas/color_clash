local function fromArray<T>(array: { T }): { [T]: boolean }
	local result = table.create(#array)

	for _, value in ipairs(array) do
		result[value] = true
	end

	return result
end

return fromArray
