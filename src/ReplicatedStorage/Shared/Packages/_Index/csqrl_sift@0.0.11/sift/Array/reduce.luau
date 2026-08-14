local function reduce<T, U>(
	array: { T },
	reducer: (accumulator: U, value: T, index: number, array: { T }) -> U,
	initReduction: U?
): U
	local result = initReduction
	local start = 1

	if result == nil then
		result = array[1]
		start = 2
	end

	for index = start, #array do
		result = reducer(result, array[index], index, array)
	end

	return result
end

return reduce
