local function at<T>(array: { T }, index: number): T
	local length = #array

	if index < 1 then
		index += length
	end

	return array[index]
end

return at
