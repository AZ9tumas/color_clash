local _T = require(script.Parent.Parent.Types)
local Copy = require(script.Parent.copy)

local function freeze(dictionary: _T.AnyDictionary): _T.AnyDictionary
	local new = Copy(dictionary)

	table.freeze(new)

	return new
end

return freeze
