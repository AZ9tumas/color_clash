local Sift = script.Parent.Parent

local None = require(Sift.None)

local function concat<T>(...: any): { T }
	local result = {}

	for arrayIndex = 1, select("#", ...) do
		local array = select(arrayIndex, ...)

		if type(array) ~= "table" then
			continue
		end

		for _, item in ipairs(array) do
			if item ~= None then
				table.insert(result, item)
			end
		end
	end

	return result
end

return concat
