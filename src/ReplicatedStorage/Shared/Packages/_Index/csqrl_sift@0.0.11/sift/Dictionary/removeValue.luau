local function removeValue<K, V>(dictionary: { [K]: V }, value: V): { [K]: V }
	local result = {}

	for key, v in pairs(dictionary) do
		if v ~= value then
			result[key] = v
		end
	end

	return result
end

return removeValue
