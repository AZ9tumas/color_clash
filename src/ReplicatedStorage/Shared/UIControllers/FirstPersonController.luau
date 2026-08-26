local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)

local FirstPersonController = {}

local player = Players.LocalPlayer
local FIRST_PERSON_ATTRIBUTE = "ViewmodelLabFirstPersonEnabled"

local function firstPersonEnabled(): boolean
	return player:GetAttribute(FIRST_PERSON_ATTRIBUTE) ~= false
end

function FirstPersonController.Init()
	local rig = FirstPersonRig.GetShared()

	if player:GetAttribute(FIRST_PERSON_ATTRIBUTE) == nil then
		player:SetAttribute(FIRST_PERSON_ATTRIBUTE, true)
	end

	local function sync()
		local isPlaying = player:GetAttribute("IsPlaying") == true
		local enabled = isPlaying and firstPersonEnabled()

		if enabled then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			rig:Enable()

			local viewmodel = Viewmodel.GetShared()
			viewmodel:SyncCharacterMeshes(player.Character)
			viewmodel:Enable()
		else
			player.CameraMode = Enum.CameraMode.Classic
			rig:Disable()

			if isPlaying then
				local viewmodel = Viewmodel.GetShared()
				viewmodel:Disable()
			else
				Viewmodel.ClearShared()
			end
		end
	end

	player:GetAttributeChangedSignal("IsPlaying"):Connect(sync)
	player:GetAttributeChangedSignal(FIRST_PERSON_ATTRIBUTE):Connect(sync)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.M then return end
		player:SetAttribute(FIRST_PERSON_ATTRIBUTE, not firstPersonEnabled())
	end)

	player.CharacterAdded:Connect(function()
		Viewmodel.ClearShared()
		task.defer(sync)
	end)

	player.CharacterAppearanceLoaded:Connect(function(character)
		if character ~= player.Character then return end
		local viewmodel = Viewmodel.GetShared()
		viewmodel:SyncCharacterMeshes(character)
	end)

	sync()
end

return FirstPersonController
