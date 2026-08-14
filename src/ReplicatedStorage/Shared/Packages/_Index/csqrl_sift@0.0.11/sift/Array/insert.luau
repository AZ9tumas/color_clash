local function insert<T>(array: { T }, index: number, ...: T): { T }
	local length = #array

	if index < 1 then
		index += length + 1
	end

	if index > length then
		if index > length + 1 then
			return array
		end

		index = length + 1
		length += 1
	end

	local result = {}

	for i = 1, length do
		if i == index then
			for _, value in ipairs({ ... }) do
				table.insert(result, value)
			end
		end

		table.insert(result, array[i])
	end

	return result
end

return insert
