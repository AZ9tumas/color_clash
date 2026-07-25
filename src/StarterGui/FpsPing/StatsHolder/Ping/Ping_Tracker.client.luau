local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local pingValue = script.Parent.Container.StatRow.Value
local player = Players.LocalPlayer
local updateTimer = 0
local screenGui = script:FindFirstAncestorWhichIsA("ScreenGui")

RunService.RenderStepped:Connect(function(deltaTime)
	if not screenGui.Enabled or not script.Parent.Visible then return end

	updateTimer += deltaTime
	if updateTimer >= 0.5 then
		updateTimer = 0
		local pingMs = 0
		if player then
			pingMs = math.floor(player:GetNetworkPing() * 1000)
		end
		pingValue.Text = tostring(pingMs) .. " ms"

		if pingMs < 80 then
			pingValue.TextColor3 = Color3.fromRGB(74, 222, 128)
		elseif pingMs < 150 then
			pingValue.TextColor3 = Color3.fromRGB(250, 204, 21)
		else
			pingValue.TextColor3 = Color3.fromRGB(248, 113, 113)
		end
	end
end)