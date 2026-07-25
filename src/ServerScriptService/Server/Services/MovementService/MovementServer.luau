local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local MovementRemotes = require(Shared.Remotes.MovementRemotes)
local MovementConfig = require(Shared.Modules.Core.MovementConfig)

local MovementServer = {}

function MovementServer.Init()
	MovementRemotes.GetUpdateStateEvent().OnServerEvent:Connect(function(player, state)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		
		if state == "Sprint" then
			hum.WalkSpeed = MovementConfig.Speeds.Sprint
		elseif state == "Walk" then
			hum.WalkSpeed = MovementConfig.Speeds.Walk
		elseif state == "Slide" then
			hum.WalkSpeed = MovementConfig.Speeds.Walk 
		elseif string.find(state, "WallRun") then
			hum.WalkSpeed = MovementConfig.Speeds.WallRun
		end
	end)
end

return MovementServer