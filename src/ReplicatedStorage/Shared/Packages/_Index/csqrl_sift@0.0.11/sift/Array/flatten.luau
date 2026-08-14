local function flatten<T>(array: { T }, depth: number?): { T }
	depth = if type(depth) == "number" then depth else math.huge

	local result = {}

	for _, value in ipairs(array) do
		if type(value) == "table" and depth > 0 then
			local nested = flatten(value, depth - 1)

			for _, nestedValue in ipairs(nested) do
				table.insert(result, nestedValue)
			end
		else
			table.insert(result, value)
		end
	end

	return result
end

return flatten
