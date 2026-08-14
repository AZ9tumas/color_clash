local function is(object: any): boolean
	return typeof(object) == "table" and #object > 0 and next(object, #object) == nil
end

return is
