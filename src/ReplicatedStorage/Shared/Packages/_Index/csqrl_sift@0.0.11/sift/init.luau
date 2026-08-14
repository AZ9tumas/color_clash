local Types = require(script.Types)

local Sift = {
	Array = require(script.Array),
	Dictionary = require(script.Dictionary),
	Set = require(script.Set),

	None = require(script.None),
	Types = require(script.Types),

	equalObjects = require(script.Util.equalObjects),
	isEmpty = require(script.Util.isEmpty),
}

Sift.List = Sift.Array

export type Dictionary<K, V> = Types.Dictionary<K, V>

export type Array<T> = Types.Array<T>
export type List<T> = Array<T>
export type Set<T> = Types.Set<T>

return Sift
