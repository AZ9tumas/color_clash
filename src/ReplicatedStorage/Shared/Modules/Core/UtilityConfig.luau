-- Throwables, only active while CombatConfig.Utilities is on. Distances are in
-- studs, times in seconds, speeds in studs per second.
local UtilityConfig = {
	Grenade = {
		DisplayName = "Frag Grenade", -- shown in the kill feed
		Charges = 2, -- held at once; a round starts full
		Recharge = 12, -- per charge
		ThrowCooldown = 0.6,
		ThrowSpeed = 75,
		ThrowLift = 18, -- extra upward speed so the throw arcs
		Fuse = 1.8,
		Radius = 16,
		MaxDamage = 95, -- at the centre, easing to MinDamage at the edge
		MinDamage = 15,
	},
}

return UtilityConfig
