local function has<T>(set: { [T]: boolean }, value: any): boolean
	return set[value] == true
end

return has
