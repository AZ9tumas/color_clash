local function intersection<T>(...: { [any]: boolean }): { [T]: boolean }
	local setCount = select("#", ...)
	local firstSet = select(1, ...)

	local result = {}

	for key, _ in pairs(firstSet) do
		local intersects = true

		for index = 2, setCount do
			local set = select(index, ...)

			if set[key] ~= true then
				intersects = false
				break
			end
		end

		if intersects then
			result[key] = true
		end
	end

	return result
end

return intersection
