local function push<T>(array: { T }, ...: T): { T }
	local result = {}

	for _, value in ipairs(array) do
		table.insert(result, value)
	end

	for _, value in ipairs({ ... }) do
		table.insert(result, value)
	end

	return result
end

return push
