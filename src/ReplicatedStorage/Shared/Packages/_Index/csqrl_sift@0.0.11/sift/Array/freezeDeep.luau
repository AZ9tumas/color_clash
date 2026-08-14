local function freezeDeep<T>(array: { T }): { T }
	local result = {}

	for i = 1, #array do
		local value = array[i]

		if type(value) == "table" then
			table.insert(result, freezeDeep(value))
		else
			table.insert(result, value)
		end
	end

	table.freeze(result)

	return result
end

return freezeDeep
