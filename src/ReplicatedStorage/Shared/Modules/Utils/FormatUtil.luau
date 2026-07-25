local FormatUtil = {}

function FormatUtil.Comma(num)
	local formatted = tostring(math.floor(num))
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

local suffixes = {"", "k", "m", "b", "t", "q", "Q"}

function FormatUtil.Suffix(num)
	if num < 1000 then return tostring(math.floor(num)) end
	local exp = math.floor(math.log10(num) / 3)
	local suffix = suffixes[exp + 1] or ""
	local val = num / (10 ^ (exp * 3))
	
	local formatted = string.format("%.1f", val)
	return formatted .. suffix
end

return FormatUtil