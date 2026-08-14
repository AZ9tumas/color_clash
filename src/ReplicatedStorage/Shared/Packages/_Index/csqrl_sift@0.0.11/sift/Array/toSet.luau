local Sift = script.Parent.Parent
local _T = require(Sift.Types)

local function toSet<T>(array: { T }): _T.Set<T>
	local set = {}

	for _, value in ipairs(array) do
		set[value] = true
	end

	return set
end

return toSet
