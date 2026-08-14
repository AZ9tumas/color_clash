local Copy = require(script.Parent.copy)

local function freeze<T>(array: { T }): { T }
	local new = Copy(array)

	table.freeze(new)

	return new
end

return freeze
