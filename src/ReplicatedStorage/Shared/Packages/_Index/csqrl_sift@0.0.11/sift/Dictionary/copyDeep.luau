local function copyDeep<T>(dictionary: T): T
	local new = table.clone(dictionary)

	for key, value in pairs(dictionary) do
		if type(value) == "table" then
			new[key] = copyDeep(value)
		end
	end

	return new
end

return copyDeep
