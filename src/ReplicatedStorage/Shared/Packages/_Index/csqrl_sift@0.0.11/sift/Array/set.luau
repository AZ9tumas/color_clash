local function set<T>(array: { T }, index: number, value: T?): { T }
	local length = #array
	local result = {}

	if index < 1 then
		index += length
	end

	for arrIndex, arrValue in ipairs(array) do
		if arrIndex == index then
			table.insert(result, value)
		else
			table.insert(result, arrValue)
		end
	end

	return result
end

return set
