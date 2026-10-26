-- Run in Studio's Edit command bar or execute_luau after syncing with Rojo.
-- Creates no instances and changes no game state.
local Shared = game:GetService("ReplicatedStorage").Shared
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local Items = require(Shared.Modules.Core.Items)
local random = Random.new(6072026)
local checked = 0

for _, data in pairs(Items) do
	if not data.MaxAmmo then continue end
	for _, aiming in { false, true } do
		local spread = HitscanUtil.EffectiveSpread(data, aiming)
		for i = 1, 10000 do
			local aim = random:NextUnitVector()
			if i == 1 then aim = Vector3.yAxis end
			if i == 2 then aim = -Vector3.yAxis end
			local direction = HitscanUtil.ConeDirection(aim, spread)
			assert(HitscanUtil.ValidateDirections({ direction }, aim, spread, 1), "Legitimate spread rejected")
			checked += 1
		end
	end
end

local aim = Vector3.new(0, 0, -1)
local function rejects(directions, spread, pellets)
	assert(HitscanUtil.ValidateDirections(directions, aim, spread or 30, pellets or 1) == nil, "Invalid directions accepted")
end

rejects(nil)
rejects("invalid")
rejects({})
rejects({ aim }, 30, 8)
rejects({ aim, aim })
rejects({ "invalid" })
rejects({ Vector3.zero })
rejects({ aim * 2 })
rejects({ Vector3.new(0/0, 0, -1) })
rejects({ Vector3.new(math.huge, 0, -1) })
rejects({ -aim })
-- This nearly unit vector passed the old unnormalised dot/acos cone check.
rejects({ CFrame.Angles(0, math.rad(8), 0).LookVector * 1.009 })
rejects({ CFrame.Angles(0, math.rad(0.1), 0).LookVector }, 0)
rejects({ CFrame.Angles(0, 0.0301, 0).LookVector }, 30)
assert(HitscanUtil.ValidateDirections(table.create(8, aim), aim, 30, 8), "Valid shotgun rejected")
assert(not HitscanUtil.IsFiniteVector(Vector3.new(0, -math.huge, 0)), "Infinite Y accepted")
assert(not HitscanUtil.IsFiniteVector(Vector3.new(0, 0, 0/0)), "NaN Z accepted")
assert(HitscanUtil.IsFiniteVector(Vector3.zero), "Finite origin rejected")

return { legitimateDirections = checked, malformedAndOutOfConeRejected = true }
