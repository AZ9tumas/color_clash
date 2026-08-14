local function includes<K, V>(dictionary: { [K]: V }, value: V): boolean
	for _, v in pairs(dictionary) do
		if v == value then
			return true
		end
	end

	return false
end

return includes
