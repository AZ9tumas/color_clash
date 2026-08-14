local function removeIndex<T>(array: { T }, index: number): { T }
	local length = #array
	local result = {}

	if index < 1 then
		index += length
	end

	for arrIndex, value in ipairs(array) do
		if arrIndex ~= index then
			table.insert(result, value)
		end
	end

	return result
end

return removeIndex
