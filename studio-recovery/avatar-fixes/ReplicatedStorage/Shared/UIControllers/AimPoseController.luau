local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local JointUtil = require(game:GetService("ReplicatedStorage").Shared.Modules.Utils.JointUtil)

local AimPoseController = {}

local player = Players.LocalPlayer

local NECK_PITCH_SCALE = 0.65
local SMOOTHING = 12

local currentPitch = {}

local function neckOf(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isR15 = humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
	local parent = character and character:FindFirstChild(isR15 and "Head" or "Torso")
	return parent and parent:FindFirstChild("Neck"), isR15 and 1 or -1
end

function AimPoseController.Init()
	RunService.Heartbeat:Connect(function(dt)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local neck, pitchSign = neckOf(other.Character)
				if neck and JointUtil.GetC0(neck) then
					local target = other:GetAttribute("AimPitch")
					if type(target) ~= "number" then target = 0 end

					local current = currentPitch[other] or 0
					local smoothed = current + (target - current) * math.min(1, dt * SMOOTHING)
					currentPitch[other] = smoothed

					if not neck:GetAttribute("PoseOriginalC0") then
						neck:SetAttribute("PoseOriginalC0", JointUtil.GetC0(neck))
					end

					if math.abs(smoothed) > 0.005 then
						JointUtil.SetC0(neck, neck:GetAttribute("PoseOriginalC0") * CFrame.Angles(pitchSign * smoothed * NECK_PITCH_SCALE, 0, 0))
					else
						JointUtil.SetC0(neck, neck:GetAttribute("PoseOriginalC0"))
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		currentPitch[leaving] = nil
	end)
end

return AimPoseController
