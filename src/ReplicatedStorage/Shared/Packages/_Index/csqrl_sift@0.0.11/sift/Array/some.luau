local function some<T>(
	array: { T },
	predicate: (value: T, index: number, array: { T }) -> any
): boolean
	for index, value in ipairs(array) do
		if predicate(value, index, array) then
			return true
		end
	end

	return false
end

return some
