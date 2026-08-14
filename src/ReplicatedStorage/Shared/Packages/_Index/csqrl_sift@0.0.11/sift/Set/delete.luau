local function delete<T>(set: { [T]: boolean }, ...: T): { [T]: boolean }
	local result = {}

	for key, _ in pairs(set) do
		result[key] = true
	end

	for _, value in ipairs({ ... }) do
		result[value] = nil
	end

	return result
end

return delete
