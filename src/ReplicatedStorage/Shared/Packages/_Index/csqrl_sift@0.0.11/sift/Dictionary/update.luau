local copy = require(script.Parent.copy)

local function update<K, V, U, C>(
	dictionary: { [K]: V? },
	key: K,
	updater: ((value: V, key: K) -> U)?,
	callback: ((key: K) -> C)?
): { [K]: V | U | C }
	local result: { [K]: any } = copy(dictionary)

	if result[key] then
		if updater then
			result[key] = updater(result[key], key)
		end
	else
		if typeof(callback) == "function" then
			result[key] = callback(key)
		end
	end

	return result
end

return update
