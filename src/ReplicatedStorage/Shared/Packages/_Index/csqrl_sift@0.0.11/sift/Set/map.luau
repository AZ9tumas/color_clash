local function map<T, U>(set: { [T]: boolean }, mapper: (T, { [T]: boolean }) -> U): { [U]: boolean }
	local result = {}

	for key, _ in pairs(set) do
		local mappedKey = mapper(key, set)

		if mappedKey ~= nil then
			result[mappedKey] = true
		end
	end

	return result
end

return map
