local function pop<T>(array: { T }, count: number?): { T }
	local length = #array
	local result = {}

	count = if type(count) == "number" then count else 1

	for i = 1, length - count do
		table.insert(result, array[i])
	end

	return result
end

return pop
