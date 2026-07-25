local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local container = script.Parent.Container
local fpsValue = container.FPS.Value
local cpuValue = container.CPU.Value
local gpuValue = container.GPU.Value
local memValue = container.MEM.Value

local frameCount = 0
local lastTime = tick()
local screenGui = script:FindFirstAncestorWhichIsA("ScreenGui")

RunService.RenderStepped:Connect(function(deltaTime)
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

		frameCount = 0
		lastTime = currentTime
	end

	local gpuTime = deltaTime * 1000
	gpuValue.Text = string.format("%.2f ms", gpuTime)

	local memory = Stats:GetTotalMemoryUsageMb()
	memValue.Text = math.floor(memory) .. " MB"
end)

RunService.Heartbeat:Connect(function(deltaTime)
	if not screenGui.Enabled or not script.Parent.Visible then return end

	local cpuTime = deltaTime * 1000
	cpuValue.Text = string.format("%.2f ms", cpuTime)
end)
