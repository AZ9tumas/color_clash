local function findLast<T>(array: { T }, value: any?, from: number?): number?
	local length = #array

	from = if type(from) == "number" then if from < 1 then length + from else from else length

	for index = from, 1, -1 do
		if array[index] == value then
			return index
		end
	end

	return
end

return findLast
