local T = require(script.Parent.Parent.Types)

local function difference<V>(set: T.Set<V>, ...: T.Set<V>): T.Set<V>
	local diff = table.clone(set)

	for _, nextSet in { ... } do
		if typeof(nextSet) ~= "table" then
			continue
		end

		for value in nextSet do
			diff[value] = nil
		end
	end

	return diff
end

return difference
