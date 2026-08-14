local function splice<T>(array: { T }, from: number?, to: number?, ...: T?): { T }
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

	for index = 1, from - 1 do
		table.insert(result, array[index])
	end

	for _, value in ipairs({ ... }) do
		table.insert(result, value)
	end

	for index = to + 1, length do
		table.insert(result, array[index])
	end

	return result
end

return splice
