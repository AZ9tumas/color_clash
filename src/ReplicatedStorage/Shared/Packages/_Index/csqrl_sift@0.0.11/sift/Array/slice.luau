local function slice<T>(array: { T }, from: number?, to: number?): { T }
	local length = #array
	local result = {}

	from = if type(from) == "number" then from else 1
	to = if type(to) == "number" then to else length

	if from < 1 then
		from += length
	end

	if to < 1 then
		to += length
	end

	for i = from, to do
		table.insert(result, array[i])
	end

	return result
end

return slice
