local T = require(script.Parent.Parent.Types)

local function differenceSymmetric<V>(set: T.Set<V>, ...: T.Set<V>): T.Set<V>
	local diff = table.clone(set)

	for _, nextSet in { ... } do
		if typeof(nextSet) ~= "table" then
			continue
		end

		for value in nextSet do
			diff[value] = if diff[value] == nil then true else false
		end
	end

	for value, keep in diff do
		diff[value] = if keep then true else nil
	end

	return diff
end

return differenceSymmetric
