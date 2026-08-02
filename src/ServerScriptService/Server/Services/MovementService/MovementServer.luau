local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local MovementRemotes = require(Shared.Remotes.MovementRemotes)
local MovementConfig = require(Shared.Modules.Core.MovementConfig)

local MovementServer = {}

local function maxAllowedSpeed()
	local air = MovementConfig.Air
	local ceiling = air and tonumber(air.MaxAirSpeed) or nil
	-- Never below the fastest ground speed, or legitimate wall running would be clamped.
	return math.max(ceiling or 0, MovementConfig.Speeds.WallRun, MovementConfig.Speeds.Sprint)
end

function MovementServer.Init()
	MovementRemotes.GetUpdateStateEvent().OnServerEvent:Connect(function(player, state, speed)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		-- The client carries momentum by raising its own WalkSpeed, so it now sends the
		-- value it wants. Clamped here so this stays the single authority on how fast a
		-- player can be told to move.
		if type(speed) == "number" and speed == speed then
			hum.WalkSpeed = math.clamp(speed, 0, maxAllowedSpeed())
			return
		end

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
