local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)

local PushClient = {}

local player = Players.LocalPlayer
local lastPush = 0

local function log(message, ...)
	if RoundConfig.Push.Debug then
		print("[Push/client] " .. string.format(message, ...))
	end
end

function PushClient.Init()
	local pushRequest = CombatRemotes.GetPushRequest()

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if processed then
			log("click ignored: consumed by the UI (clicked a button or GUI element)")
			return
		end

		-- Pushing is legal for the whole round, in every phase. IsPlaying is only true
		-- between the round-start teleport and round end, so it is the only gate needed.
		if player:GetAttribute("IsPlaying") ~= true then
			log("click ignored: IsPlaying=%s, you are not in the round", tostring(player:GetAttribute("IsPlaying")))
			return
		end

		if player:GetAttribute("InMenu") ~= false then
			log("click ignored: still InMenu")
			return
		end

		local character = player.Character
		if not character then
			log("click ignored: no character")
			return
		end
		if character:GetAttribute("Ragdolled") then
			log("click ignored: you are ragdolled")
			return
		end

		-- Local throttle only, to keep the remote quiet. The server enforces the real one.
		local now = tick()
		local since = now - lastPush
		if since < RoundConfig.Push.Cooldown then
			log("click ignored: cooldown, %.2fs of %.2fs remaining", RoundConfig.Push.Cooldown - since, RoundConfig.Push.Cooldown)
			return
		end
		lastPush = now

		log("push sent to server")
		pushRequest:FireServer()
	end)

	log("ready - left click any time you are in the round to shove")
end

return PushClient
