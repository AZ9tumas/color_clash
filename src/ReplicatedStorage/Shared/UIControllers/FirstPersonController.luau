local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)

local FirstPersonController = {}

local player = Players.LocalPlayer

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

	player.CharacterAdded:Connect(function()
		Viewmodel.ClearShared()
		task.defer(sync)
	end)

	sync()
end

return FirstPersonController
