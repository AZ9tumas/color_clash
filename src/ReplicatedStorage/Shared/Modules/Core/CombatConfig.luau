local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Combat feature flags. The server publishes each one as a Workspace attribute
-- when it starts, so a flag can be flipped live in a playtest (or set on
-- Workspace in Studio before pressing Play) and both sides see the same value.
-- The values below are what live servers use; STUDIO_DEFAULTS turns flags on for
-- Studio playtests only, so new gunplay can be tried without shipping it.
local CombatConfig = {
	-- On: the shooter's client decides what each pellet hit, and the server checks
	-- that claim against where the target was when the shooter saw it (lag
	-- compensation) before applying damage. The server also keeps its own copy of
	-- every gun's magazine and reloads. Off: the server raycasts against current
	-- positions and trusts the client's ammo count, as before.
	ClientHitReg = false,

	-- On: each gun's Items.Handling drives its feel. Spread grows with movement,
	-- jumping, sliding and sustained fire and the crosshair draws the real cone;
	-- recoil follows a learnable per-gun pattern and the aim recovers after a
	-- burst; damage falls off with range and headshots use a per-gun multiplier;
	-- tactical reloads are faster than empty ones, shotguns can fire mid-reload
	-- and scoped guns show a scope overlay. Off: fixed spread, random recoil kick,
	-- flat damage with a 2x headshot, as before.
	GunHandling = false,

	-- On: Q and the mouse wheel swap weapons, pressing the held slot's key no
	-- longer holsters it, and every gun has a short draw time (Items.Handling
	-- .EquipTime, checked by the server too) with a procedural draw motion.
	QuickSwap = false,

	-- On: bullet impacts on walls, a hit-direction indicator when you take damage,
	-- a low-ammo tint on the ammo counter, and hit-marker sounds that load.
	CombatFeedback = false,

	-- On: F throws a frag grenade (server-simulated, splash damage with line of
	-- sight), with charges that recharge over time.
	Utilities = false,
}

local FLAGS = { "ClientHitReg", "GunHandling", "QuickSwap", "CombatFeedback", "Utilities" }

local STUDIO_DEFAULTS = {
	ClientHitReg = true,
	GunHandling = true,
	QuickSwap = true,
	CombatFeedback = true,
	Utilities = true,
}

function CombatConfig.IsEnabled(flag: string): boolean
	local value = Workspace:GetAttribute(flag)
	if value == nil then
		value = CombatConfig[flag]
	end
	return value == true
end

-- Server only. A value already set on Workspace wins over the defaults here.
function CombatConfig.Publish()
	local studio = RunService:IsStudio()
	for _, flag in FLAGS do
		if Workspace:GetAttribute(flag) == nil then
			local value = CombatConfig[flag] == true
			if studio and STUDIO_DEFAULTS[flag] ~= nil then
				value = STUDIO_DEFAULTS[flag]
			end
			Workspace:SetAttribute(flag, value)
		end
	end
end

return CombatConfig
