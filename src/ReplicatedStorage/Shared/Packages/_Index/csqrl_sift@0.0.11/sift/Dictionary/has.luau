local _T = require(script.Parent.Parent.Types)

local function has(dictionary: _T.AnyDictionary, key: any): boolean
	return dictionary[key] ~= nil
end

return has
