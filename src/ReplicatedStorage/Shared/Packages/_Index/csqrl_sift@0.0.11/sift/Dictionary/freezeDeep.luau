local _T = require(script.Parent.Parent.Types)

local function freezeDeep(dictionary: _T.AnyDictionary): _T.AnyDictionary
	local result = {}

	for key, value in pairs(dictionary) do
		if type(value) == "table" then
			result[key] = freezeDeep(value)
		else
			result[key] = value
		end
	end

	table.freeze(result)

	return result
end

return freezeDeep
