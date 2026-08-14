local Reduce = require(script.Parent.reduce)

local function zip<T>(...: { any }): T
	local argCount = select("#", ...)
	local arguments = { ... }

	local result = {}

	if argCount == 0 then
		return result
	end

	local minLength: number = Reduce(arguments, function(acc, val)
		return math.min(acc, #val)
	end, #arguments[1])

	for index = 1, minLength do
		local values = {}

		for _, argArray in ipairs(arguments) do
			table.insert(values, argArray[index])
		end

		table.insert(result, values)
	end

	return result
end

return zip
