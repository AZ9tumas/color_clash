local Sift = script.Parent.Parent

local Util = require(Sift.Util)

local function filter<T>(
	set: { [T]: boolean },
	predicate: ((T, { [T]: boolean }) -> any)?
): { [T]: boolean }
	local result = {}

	predicate = if type(predicate) == "function" then predicate else Util.func.truthy

	for key, _ in pairs(set) do
		if predicate(key, set) then
			result[key] = true
		end
	end

	return result
end

return filter
