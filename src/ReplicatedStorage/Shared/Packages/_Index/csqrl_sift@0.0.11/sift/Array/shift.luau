local function shift<T>(array: { T }, count: number?): { T }
	local length = #array
	local result = {}

	count = if type(count) == "number" then count + 1 else 2

	for i = count, length do
		table.insert(result, array[i])
	end

	return result
end

return shift
