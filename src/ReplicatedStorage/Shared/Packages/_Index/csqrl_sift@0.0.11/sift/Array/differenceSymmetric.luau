local T = require(script.Parent.Parent.Types)

local toSet = require(script.Parent.toSet)
local toArray = require(script.Parent.Parent.Set.toArray)
local setDifferenceSymmetric = require(script.Parent.Parent.Set.differenceSymmetric)

local function differenceSymmetric<V>(array: T.Array<V>, ...: T.Array<V>): T.Array<V>
	local arraySet = toSet(array)
	local otherSets = {}

	for _, nextArray in { ... } do
		if typeof(nextArray) ~= "table" then
			continue
		end

		table.insert(otherSets, toSet(nextArray))
	end

	local differenceSet = setDifferenceSymmetric(arraySet, unpack(otherSets))

	return toArray(differenceSet)
end

return differenceSymmetric
