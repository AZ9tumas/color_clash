local ToSet = require(script.Parent.toSet)

local function removeValues<T>(array: { T }, ...: T): { T }
	local valueSet = ToSet({ ... })
	local result = {}

	for _, value in ipairs(array) do
		if not valueSet[value] then
			table.insert(result, value)
		end
	end

	return result
end

return removeValues
