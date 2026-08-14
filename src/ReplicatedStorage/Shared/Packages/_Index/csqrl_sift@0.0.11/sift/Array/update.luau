local Sift = script.Parent.Parent

local Util = require(Sift.Util)
local Copy = require(script.Parent.copy)

type Callback<T> = (index: number) -> T
type Updater<T> = (currentValue: T, index: number) -> T

local function call<T>(callback: Callback<T>, index: number)
	if type(callback) == "function" then
		return callback(index)
	end
end

local function update<T>(
	array: { T },
	index: number,
	updater: Updater<T>?,
	callback: Callback<T>?
): { T }
	local length = #array
	local result = Copy(array)

	if index < 1 then
		index += length
	end

	updater = if type(updater) == "function" then updater else Util.func.returned

	if result[index] ~= nil then
		result[index] = updater(result[index], index)
	else
		result[index] = call(callback, index)
	end

	return result
end

return update
