local Workspace = game:GetService("Workspace")

local RaycastUtil = {}

function RaycastUtil.CastWithIgnore(origin, direction, range, initialIgnoreList, ignoreNames)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local currentIgnore = {}
	for _, v in ipairs(initialIgnoreList) do table.insert(currentIgnore, v) end
	
	while true do
		params.FilterDescendantsInstances = currentIgnore
		local result = Workspace:Raycast(origin, direction * range, params)
		
		if result and result.Instance then
			local shouldIgnore = false
			for _, name in ipairs(ignoreNames) do
				if result.Instance.Name == name or string.find(result.Instance.Name, name) then
					shouldIgnore = true
					break
				end
			end
			
			if shouldIgnore then
				table.insert(currentIgnore, result.Instance)
			else
				return result
			end
		else
			return result
		end
	end
end

return RaycastUtil