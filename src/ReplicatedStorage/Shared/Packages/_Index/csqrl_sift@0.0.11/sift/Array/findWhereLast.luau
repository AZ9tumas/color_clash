local function findWhereLast<T>(
	array: { T },
	predicate: (value: T, index: number, array: { T }) -> any,
	from: number?
): number?
	local length = #array

	from = if type(from) == "number" then if from < 1 then length + from else from else length

	for index = from, 1, -1 do
		if predicate(array[index], index, array) then
			return index
		end
	end

	return
end

return findWhereLast
