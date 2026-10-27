-- Daily chests in Workspace.Chests. Each chest model carries a ChestId attribute;
-- every player can open each chest once per Cooldown seconds for a random
-- number of coins between Min and Max.
local ChestConfig = {
	Cooldown = 24 * 60 * 60,

	Chests = {
		GreenChest = { DisplayName = "Green Chest", Min = 100, Max = 200 },
		OrangeChest = { DisplayName = "Orange Chest", Min = 100, Max = 200 },
		RedChest = { DisplayName = "Big Red Chest", Min = 250, Max = 500 },
	},

	-- Used for any chest without an entry above.
	Default = { DisplayName = "Chest", Min = 100, Max = 200 },
}

function ChestConfig.For(chestId: string)
	return ChestConfig.Chests[chestId] or ChestConfig.Default
end

return ChestConfig
