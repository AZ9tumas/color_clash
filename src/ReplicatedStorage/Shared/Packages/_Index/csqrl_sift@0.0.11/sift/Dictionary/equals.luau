local Sift = script.Parent.Parent

local Util = require(Sift.Util)
local _T = require(Sift.Types)

local function compare(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end

	for key, value in pairs(b) do
		if a[key] ~= value then
			return false
		end
	end

	return true
end

local function equals(...: _T.AnyDictionary): boolean
	if Util.equalObjects(...) then
		return true
	end

	local totalArgs = select("#", ...)
	local firstItem = select(1, ...)

	for i = 2, totalArgs do
		local item = select(i, ...)

		if not compare(firstItem, item) then
			return false
		end
	end

	return true
end

return equals
