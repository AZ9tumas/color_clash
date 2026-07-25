local Workspace = game:GetService("Workspace")

local ChestServer = {}

function ChestServer.Init()
	local chestsFolder = Workspace:WaitForChild("Chests", 10)
	
	if chestsFolder then
		for _, chest in ipairs(chestsFolder:GetChildren()) do
			if chest:IsA("Model") and chest.PrimaryPart then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Open Chest"
				prompt.ObjectText = chest.Name
				prompt.HoldDuration = 1.25
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.Style = Enum.ProximityPromptStyle.Custom
				prompt.RequiresLineOfSight = false
				prompt.MaxActivationDistance = 12
				prompt.Parent = chest.PrimaryPart
				
				prompt.Triggered:Connect(function(player)
					print(player.Name .. " opened " .. chest.Name)
					prompt.Enabled = false
					task.wait(5) 
					prompt.Enabled = true
				end)
			end
		end
	end
end

return ChestServer