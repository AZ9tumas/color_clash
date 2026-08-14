local function find<T>(array: { T }, value: any?, from: number?): number?
	local length = #array

	from = if type(from) == "number" then if from < 1 then length + from else from else 1

	return table.find(array, value, from)
end

return find
