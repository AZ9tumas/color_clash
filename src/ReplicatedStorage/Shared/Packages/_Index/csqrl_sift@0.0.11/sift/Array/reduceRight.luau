local function reduceRight<T, U>(
	array: { T },
	reducer: (accumulator: U, value: T, index: number, array: { T }) -> U,
	initReduction: U?
): U
	local result = initReduction
	local start = #array

	if result == nil then
		result = array[start]
		start -= 1
	end

	for index = start, 1, -1 do
		result = reducer(result, array[index], index, array)
	end

	return result
end

return reduceRight
