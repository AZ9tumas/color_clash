local _T = require(script.Parent.Parent.Types)

local function isEmpty(table: _T.Table): boolean
	return next(table) == nil
end

return isEmpty
