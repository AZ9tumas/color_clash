local function removeIndices<T>(array: { T }, ...: number): { T }
	local length = #array
	local indices = {}
	local result = {}

	for _, index in ipairs({ ... }) do
		if index < 1 then
			index += length
		end

		indices[index] = true
	end

	for index, value in ipairs(array) do
		if not indices[index] then
			table.insert(result, value)
		end
	end

	return result
end

return removeIndices
