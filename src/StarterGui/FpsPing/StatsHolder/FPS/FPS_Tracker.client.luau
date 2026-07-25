local RunService = game:GetService("RunService")
local fpsValue = script.Parent.Container.StatRow.Value
local frameCount, lastTime = 0, tick()
local screenGui = script:FindFirstAncestorWhichIsA("ScreenGui")

RunService.RenderStepped:Connect(function()
	if not screenGui.Enabled or not script.Parent.Visible then return end

	frameCount += 1
	local currentTime = tick()
	if currentTime - lastTime >= 1 then
		fpsValue.Text = tostring(frameCount) .. " FPS"
		if frameCount >= 55 then
			fpsValue.TextColor3 = Color3.fromRGB(74, 222, 128)
		elseif frameCount >= 30 then
			fpsValue.TextColor3 = Color3.fromRGB(250, 204, 21)
		else
			fpsValue.TextColor3 = Color3.fromRGB(248, 113, 113)
		end
		frameCount, lastTime = 0, currentTime
	end
end)
