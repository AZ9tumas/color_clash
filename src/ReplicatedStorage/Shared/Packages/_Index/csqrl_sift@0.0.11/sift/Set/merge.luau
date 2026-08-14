local function merge<T>(...: any): { [T]: boolean }
	local result = {}

	for setIndex = 1, select("#", ...) do
		local set = select(setIndex, ...)

		if type(set) ~= "table" then
			continue
		end

		for key, _ in pairs(set) do
			result[key] = true
		end
	end

	return result
end

return merge
