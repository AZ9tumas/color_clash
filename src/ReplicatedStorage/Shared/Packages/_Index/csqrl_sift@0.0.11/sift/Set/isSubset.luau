local function isSubset(subset: { [any]: boolean }, superset: { [any]: boolean }): boolean
	for key, value in pairs(subset) do
		if superset[key] ~= value then
			return false
		end
	end

	return true
end

return isSubset
