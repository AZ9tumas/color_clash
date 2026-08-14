local Copy = require(script.Parent.copy)

local function shuffle<T>(array: { T }): { T }
	local random = Random.new(os.time() * #array)
	local result = Copy(array)

	for index = #result, 1, -1 do
		local randomIndex = random:NextInteger(1, index)
		local temp = result[index]

		result[index] = result[randomIndex]
		result[randomIndex] = temp
	end

	return result
end

return shuffle
