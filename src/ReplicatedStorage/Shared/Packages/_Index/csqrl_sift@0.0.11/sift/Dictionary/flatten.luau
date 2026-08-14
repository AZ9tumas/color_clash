local _T = require(script.Parent.Parent.Types)

local function flatten(dictionary: _T.AnyDictionary, depth: number?): _T.AnyDictionary
	depth = if type(depth) == "number" then depth else math.huge

	local result = {}

	for key, value in pairs(dictionary :: _T.AnyDictionary) do
		if type(value) == "table" and depth > 0 then
			local nested = flatten(value, depth - 1)

			for resultKey, resultValue in pairs(result) do
				nested[resultKey] = resultValue
			end

			result = nested
		else
			result[key] = value
		end
	end

	return result
end

return flatten
