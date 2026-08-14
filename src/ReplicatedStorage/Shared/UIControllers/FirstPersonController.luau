local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)

-- Owns the first-person camera for the whole round rather than for the length of a weapon.
--
-- The rig used to be created and enabled by GunHandler on equip, which meant the game was
-- only first person while a gun was out - swapping to a melee, running dry between rounds
-- or simply holding nothing dropped the player back into the default third-person camera
-- mid-match. First person is the game's camera now, so its lifetime is the round's.
--
-- Gated on IsPlaying, which is the round actually starting, NOT on InMenu. InMenu goes
-- false the moment the player hits Play, and they then stand around the lobby through
-- voting and team select - taking the camera there put them in first person inside lobby
-- geometry with nothing to look at. IsPlaying is set as each player is placed on the arena
-- and cleared when they are eliminated or the round ends, which is exactly the window first
-- person should cover.
--
-- The rig still stands itself down inside _update for death, ragdoll and the menu, so this
-- controller only has to answer the coarse in-round / not-in-round question.
local FirstPersonController = {}

local player = Players.LocalPlayer

-- The viewmodel comes up with the camera and stays up. Its arms are the player's hands
-- whether or not a weapon is in them; GunHandler only swaps what they are holding. Built
-- per round rather than once, because it is a clone of the character and the character is
-- replaced on death.
function FirstPersonController.Init()
	local rig = FirstPersonRig.GetShared()

	local function sync()
		if player:GetAttribute("IsPlaying") == true then
			rig:Enable()

			local viewmodel = Viewmodel.GetShared()
			if viewmodel then
				viewmodel:Enable()
			end
		else
			rig:Disable()
			Viewmodel.ClearShared()
		end
	end

	player:GetAttributeChangedSignal("IsPlaying"):Connect(sync)

	-- A fresh character means a fresh clone; the old one is wearing a body that no longer
	-- exists.
	player.CharacterAdded:Connect(function()
		Viewmodel.ClearShared()
		task.defer(sync)
	end)

	sync()
end

return FirstPersonController
