local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Poses OTHER players' necks from their replicated AimPitch attribute, so everyone can
-- read where a gunner is aiming. The local player's own pose is handled by their
-- ThirdPersonRig; this controller deliberately skips them.
local AimPoseController = {}

local player = Players.LocalPlayer

local NECK_PITCH_SCALE = 0.65
local SMOOTHING = 12

local currentPitch = {}

local function neckOf(character)
	local torso = character and character:FindFirstChild("Torso")
	return torso and torso:FindFirstChild("Neck")
end

function AimPoseController.Init()
	RunService.Heartbeat:Connect(function(dt)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local neck = neckOf(other.Character)
				if neck then
					local target = other:GetAttribute("AimPitch")
					if type(target) ~= "number" then target = 0 end

					local current = currentPitch[other] or 0
					local smoothed = current + (target - current) * math.min(1, dt * SMOOTHING)
					currentPitch[other] = smoothed

					if not neck:GetAttribute("PoseOriginalC0") then
						neck:SetAttribute("PoseOriginalC0", neck.C0)
					end

					-- Negated to match the measured R6 neck axis (positive X = head down).
					if math.abs(smoothed) > 0.005 then
						neck.C0 = neck:GetAttribute("PoseOriginalC0") * CFrame.Angles(-smoothed * NECK_PITCH_SCALE, 0, 0)
					else
						neck.C0 = neck:GetAttribute("PoseOriginalC0")
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
