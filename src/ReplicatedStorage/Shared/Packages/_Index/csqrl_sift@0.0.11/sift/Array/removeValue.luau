local function removeValue<T>(array: { T }, value: T): { T }
	local result = {}

	for _, arrValue in ipairs(array) do
		if arrValue ~= value then
			table.insert(result, arrValue)
		end
	end

	return result
end

return removeValue
