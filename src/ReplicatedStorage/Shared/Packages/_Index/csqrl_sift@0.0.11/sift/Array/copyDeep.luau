local function copyDeep<T>(array: { T }): { T }
	local result = table.clone(array)

	for index, value in array do
		if type(value) == "table" then
			result[index] = copyDeep(value) :: any
		end
	end

	return result
end

return copyDeep
