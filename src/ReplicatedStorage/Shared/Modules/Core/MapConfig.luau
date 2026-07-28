local MapConfig = {}

-- Grid size. Rows run along Z, Cols run along X. Change these to resize the arena;
-- cells keep their authored size and the map grows or shrinks around Center.
MapConfig.Rows = 8
MapConfig.Cols = 8

-- Grid pitch, measured from the hand-built 8x8 map (footprint / 8 on each axis).
-- Cells are authored geometry and are never scaled, so this should only change if
-- the cell models themselves are rebuilt at a different size.
MapConfig.CellPitchX = 42.7147
MapConfig.CellPitchZ = 45.8270

-- The arena stays centred here at any grid size, so Workspace.Game stays roughly
-- central and the lobby does not need moving.
MapConfig.Center = Vector3.new(429.385, 0, 224.570)

-- One flat colour per folder, sampled from the original build.
MapConfig.Colors = {
	Green = Color3.fromRGB(58, 125, 21),
	Blue = Color3.fromRGB(13, 105, 172),
	Yellow = Color3.fromRGB(255, 176, 0),
	Red = Color3.fromRGB(196, 40, 28),
}

-- Folder order under Workspace.Map. RoundMechanic picks the round colour from this
-- list, so adding or removing a colour here flows through to the round automatically.
MapConfig.ColorOrder = { "Green", "Blue", "Yellow", "Red" }

-- How many random permutations to try per block when minimising same-colour
-- adjacency across block seams. Higher is tidier, with diminishing returns.
MapConfig.LayoutAttempts = 8

return MapConfig
