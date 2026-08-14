local Sift = script.Parent.Parent

local Util = require(Sift.Util)
local _T = require(Sift.Types)

local function compareDeep(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in pairs(a) do
		if not compareDeep(value, b[key]) then
			return false
		end
	end

	for key, value in pairs(b) do
		if not compareDeep(value, a[key]) then
			return false
		end
	end

	return true
end

local function equalsDeep(...: _T.AnyDictionary): boolean
	if Util.equalObjects(...) then
		return true
	end

	local totalArgs = select("#", ...)
	local firstItem = select(1, ...)

	for i = 2, totalArgs do
		local item = select(i, ...)

		if not compareDeep(firstItem, item) then
			return false
		end
	end

	return true
end

return equalsDeep
