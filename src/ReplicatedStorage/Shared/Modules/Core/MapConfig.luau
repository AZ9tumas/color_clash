local MapConfig = {}

MapConfig.Rows = 8
MapConfig.Cols = 8

MapConfig.CellPitchX = 42.7147
MapConfig.CellPitchZ = 45.8270

MapConfig.Center = Vector3.new(429.385, 0, 224.570)

MapConfig.Colors = {
	Green = Color3.fromRGB(58, 125, 21),
	Blue = Color3.fromRGB(13, 105, 172),
	Yellow = Color3.fromRGB(255, 176, 0),
	Red = Color3.fromRGB(196, 40, 28),
}

MapConfig.ColorOrder = { "Green", "Blue", "Yellow", "Red" }

MapConfig.LayoutAttempts = 8

return MapConfig
