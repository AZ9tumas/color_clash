local function findWhere<T>(
	array: { T },
	predicate: (value: T, index: number, array: { T }) -> any,
	from: number?
): number?
	local length = #array

	from = if type(from) == "number" then if from < 1 then length + from else from else 1

	for index = from, #array do
		if predicate(array[index], index, array) then
			return index
		end
	end

	return
end

return findWhere
