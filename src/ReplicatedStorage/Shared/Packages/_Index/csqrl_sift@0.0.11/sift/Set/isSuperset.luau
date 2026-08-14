local isSubset = require(script.Parent.isSubset)

local function isSuperset<any>(superset: { [any]: boolean }, subset: { [any]: boolean }): boolean
	return isSubset(subset, superset)
end

return isSuperset
