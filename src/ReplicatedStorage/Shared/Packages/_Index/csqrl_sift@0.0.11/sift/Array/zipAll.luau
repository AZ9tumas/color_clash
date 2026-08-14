local Sift = script.Parent.Parent

local Reduce = require(script.Parent.reduce)
local None = require(Sift.None)

local function zipAll<T>(...: { any }): T
	local argCount = select("#", ...)
	local arguments = { ... }
	local result = {}

	if argCount == 0 then
		return result
	end

	local maxLength = Reduce(arguments, function(acc, val)
		return math.max(acc, #val)
	end, #arguments[1])

	for index = 1, maxLength do
		local values = {}

		for _, argArray in ipairs(arguments) do
			local value = argArray[index]
			table.insert(values, if value == nil then None else value)
		end

		table.insert(result, values)
	end

	return result
end

return zipAll
