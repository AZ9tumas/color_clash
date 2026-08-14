local None = newproxy(true)

getmetatable(None :: any).__tostring = function()
	return "Sift.None"
end

return None
