local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)

local RoundUIController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local Message = MainHUD:WaitForChild("Message")
local ButtonsHolder = MainHUD:WaitForChild("ButtonsHolder")
local MainFrames = ButtonsHolder:WaitForChild("Main")

local TopFrame = MainHUD:WaitForChild("Top")
local TimerTitle = TopFrame:WaitForChild("Timer"):WaitForChild("Title")
local TopLeft = TopFrame:WaitForChild("Left")
local TopRight = TopFrame:WaitForChild("Right")

local currentState = nil
local currentColorThread = nil
local activeFrames = {}
local originalButtonPositions = {}
local hasPlayedVotingAnim = false

local function UpdateTopBar()
	local entities = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InMenu") == false and p:GetAttribute("IsPlaying") == true then
			table.insert(entities, {Name = p.Name, Kills = p:GetAttribute("Kills") or 0, UserId = p.UserId})
		end
	end
	
	local workspaceObjs = Workspace:GetChildren()
	for _, bot in ipairs(workspaceObjs) do
		if string.match(bot.Name, "^Bot_") and bot:FindFirstChild("Humanoid") and bot.Humanoid.Health > 0 then
			table.insert(entities, {Name = "Robot_" .. bot.Name:sub(5), Kills = bot:GetAttribute("Kills") or 0, UserId = 1})
		end
	end
	
	table.sort(entities, function(a, b) return a.Kills > b.Kills end)

	local slots = {
		TopLeft:FindFirstChild("1"), TopLeft:FindFirstChild("2"), TopLeft:FindFirstChild("3"), TopLeft:FindFirstChild("4"),
		TopRight:FindFirstChild("5"), TopRight:FindFirstChild("6"), TopRight:FindFirstChild("7"), TopRight:FindFirstChild("8")
	}

	for i, slotFrame in ipairs(slots) do
		if slotFrame and slotFrame:IsA("Frame") then
			local btn = slotFrame:FindFirstChild("btn")
			if btn then
				local p = entities[i]
				if p then
					btn.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(p.UserId) .. "&w=150&h=150"
					btn.Kills.Text = tostring(p.Kills)
					btn.Rank.Text = "#" .. tostring(i)
					btn.Avatar.Visible = true; btn.Kills.Visible = true; btn.Rank.Visible = true
				else
					btn.Avatar.Visible = false; btn.Kills.Visible = false; btn.Rank.Visible = false
				end
			end
		end
	end
end

local function playVotingAnimation()
	if hasPlayedVotingAnim then return end
	hasPlayedVotingAnim = true

	for _, frame in ipairs(activeFrames) do
		if originalButtonPositions[frame] then
			frame.Position = UDim2.new(originalButtonPositions[frame].X.Scale, originalButtonPositions[frame].X.Offset, 1.5, 0)
		end
		
		local btn = frame:FindFirstChild("Button")
		local title = btn and btn:FindFirstChild("Title")
		local titleFrame = title and title:FindFirstChild("Frame")
		
		if title and titleFrame then
			titleFrame.Size = UDim2.new(0.094, 0, 0.055, 0)
			titleFrame.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			title.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end
	
	UIAnimations.PopIn(ButtonsHolder)
	
	task.spawn(function()
		task.wait(0.2) 
		
		for _, frame in ipairs(activeFrames) do
			if not originalButtonPositions[frame] then continue end
			
			local btn = frame:FindFirstChild("Button")
			local title = btn and btn:FindFirstChild("Title")
			local titleFrame = title and title:FindFirstChild("Frame")
			
			TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = originalButtonPositions[frame]
			}):Play()
			
			if title and titleFrame then
				task.delay(0.15, function()
					TweenService:Create(titleFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(1, 0, 0.055, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					}):Play()
					
					TweenService:Create(title, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextColor3 = Color3.fromRGB(255, 255, 255)
					}):Play()
				end)
			end
			
			task.wait(0.3) 
		end
	end)
	
	task.delay(0.4, function() if currentState == RoundConfig.States.Voting then UIAnimations.PopInFromTop(Message) end end)
end

local function syncUIVisibility()
	local inMenu = player:GetAttribute("InMenu") ~= false
	if inMenu then
		UIAnimations.PopOutToTop(Message)
		UIAnimations.PopOut(ButtonsHolder)
		TopFrame.Visible = false
		hasPlayedVotingAnim = false
	else
		if currentState == RoundConfig.States.Voting then
			playVotingAnimation()
		elseif currentState == RoundConfig.States.Intermission or currentState == RoundConfig.States.PostRound then
			UIAnimations.PopInFromTop(Message)
		end
		
		if currentState == RoundConfig.States.InGame and player:GetAttribute("IsPlaying") == true then
			TopFrame.Visible = true
		end
	end
end

function RoundUIController.Init()
	UIAnimations.InitializePopFromTop(Message)
	UIAnimations.InitializePopObject(ButtonsHolder)
	TopFrame.Visible = false

	local modeNames = {"FFA", "Teams"}
	local framesToMap = {MainFrames:FindFirstChild("1"), MainFrames:FindFirstChild("2"), MainFrames:FindFirstChild("3")}

	for i, frame in ipairs(framesToMap) do
		if frame and frame:IsA("Frame") then
			local modeName = modeNames[i]
			if modeName then
				frame.Name = modeName
				
				local wrapper = Instance.new("Frame")
				wrapper.Name = modeName .. "_Wrapper"
				wrapper.Size = frame.Size
				wrapper.BackgroundTransparency = 1
				wrapper.ClipsDescendants = true
				wrapper.LayoutOrder = frame.LayoutOrder
				wrapper.Parent = MainFrames
				
				frame.Parent = wrapper
				frame.Size = UDim2.fromScale(1, 1)
				
				originalButtonPositions[frame] = UDim2.fromScale(0, 0)
				frame.Position = UDim2.new(0, 0, 1.5, 0) 
				
				table.insert(activeFrames, frame)
				
				local btn = frame:WaitForChild("Button")
				btn.ZIndex = 1
				
				local title = btn:WaitForChild("Title")
				title.Text = modeName
				
				local titleFrame = title:WaitForChild("Frame")
				titleFrame.AnchorPoint = Vector2.new(0.5, 1)
				titleFrame.Size = UDim2.new(0.094, 0, 0.055, 0)
				titleFrame.Position = UDim2.new(0.5, 0, 1, 0)
				titleFrame.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
				title.TextColor3 = Color3.fromRGB(200, 200, 200)
				
				local holder = btn:FindFirstChild("Holder")
				if holder then
					holder.ZIndex = 10
					holder.Visible = true
					local template = holder:FindFirstChild("Template")
					if template then template.Visible = false end
				end
				
				UIAnimations.BindButtonAnimations(btn)

				btn.MouseButton1Click:Connect(function()
					if currentState == RoundConfig.States.Voting then
						RoundRemotes.GetClientVoteEvent():FireServer(modeName)
					end
				end)
			else
				frame.Visible = false
			end
		end
	end

	RoundRemotes.GetUpdateEvent().OnClientEvent:Connect(function(newState, timeLeft)
		local oldState = currentState
		currentState = newState
		local inMenu = player:GetAttribute("InMenu") ~= false

		if newState ~= RoundConfig.States.Voting then
			hasPlayedVotingAnim = false
		end

		if newState == RoundConfig.States.Voting then
			if not inMenu then
				playVotingAnimation()
				Message.Text = "Vote for next match!(" .. tostring(timeLeft) .. "s)"
				Message.TextColor3 = Color3.new(1, 1, 1)
			end
			
		elseif newState == RoundConfig.States.PostRound then
			if not inMenu then
				if oldState == RoundConfig.States.Voting then UIAnimations.PopOut(ButtonsHolder)
				elseif oldState ~= RoundConfig.States.PostRound then UIAnimations.PopInFromTop(Message) end
				Message.Text = "Intermission: " .. tostring(timeLeft) .. "s"
				Message.TextColor3 = Color3.new(1, 1, 1)
			end

		elseif newState == RoundConfig.States.TeamSelect then
			if not inMenu then
				if oldState == RoundConfig.States.Voting then UIAnimations.PopOut(ButtonsHolder)
				elseif oldState ~= RoundConfig.States.TeamSelect then UIAnimations.PopInFromTop(Message) end
				Message.Text = "Pick a team to play: " .. tostring(timeLeft) .. "s"
				Message.TextColor3 = Color3.new(1, 1, 1)
			end

		elseif newState == RoundConfig.States.Intermission then
			if not inMenu then
				if oldState == RoundConfig.States.Voting then UIAnimations.PopOut(ButtonsHolder)
				elseif oldState ~= RoundConfig.States.Intermission then UIAnimations.PopInFromTop(Message) end
				Message.Text = "Starting in: " .. tostring(timeLeft) .. "s"
				Message.TextColor3 = Color3.new(1, 1, 1)
			end

		elseif newState == RoundConfig.States.InGame then
			if oldState == RoundConfig.States.Intermission or oldState == RoundConfig.States.Voting or oldState == RoundConfig.States.PostRound then 
				UIAnimations.PopOutToTop(Message) 
			end
			TimerTitle.Text = string.format("%d:%02d", math.floor(timeLeft / 60), timeLeft % 60)

		else
			if oldState == RoundConfig.States.Voting or oldState == RoundConfig.States.Intermission or oldState == RoundConfig.States.PostRound then
				UIAnimations.PopOutToTop(Message)
				if oldState == RoundConfig.States.Voting then UIAnimations.PopOut(ButtonsHolder) end
			end
		end
		
		TopFrame.Visible = (newState == RoundConfig.States.InGame and player:GetAttribute("IsPlaying") == true)
	end)

	RoundRemotes.GetUpdateVotesEvent().OnClientEvent:Connect(function(votes)
		for _, frame in ipairs(activeFrames) do
			if frame.Visible then
				local btn = frame:FindFirstChild("Button")
				local holder = btn and btn:FindFirstChild("Holder")
				if holder then
					for _, child in holder:GetChildren() do
						if child:IsA("ImageLabel") and child.Name ~= "Template" then child:Destroy() end
					end
				end
			end
		end
		
		for userIdStr, modeName in pairs(votes) do
			local targetFrame = nil
			for _, frame in ipairs(activeFrames) do
				if frame.Name == modeName then
					targetFrame = frame
					break
				end
			end
			
			if targetFrame then
				local btn = targetFrame:FindFirstChild("Button")
				local holder = btn and btn:FindFirstChild("Holder")
				local template = holder and holder:FindFirstChild("Template")
				
				if holder and template then
					local clone = template:Clone()
					clone.Name = tostring(userIdStr)
					clone.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userIdStr .. "&w=150&h=150"
					clone.ZIndex = 20
					clone.Visible = true
					clone.Parent = holder
				end
			end
		end
	end)

	RoundRemotes.GetColorEvent().OnClientEvent:Connect(function(color, duration)
		if player:GetAttribute("InMenu") ~= false then return end
		
		if currentColorThread then
			task.cancel(currentColorThread)
			currentColorThread = nil
		end

		if color == "Next" then
			Message.TextColor3 = Color3.new(1, 1, 1)
			UIAnimations.PopInFromTop(Message)
			UIAnimations.PopText(Message)
			
			currentColorThread = task.spawn(function()
				for i = duration, 1, -1 do
					Message.Text = "Next color in: " .. i .. "s"
					task.wait(1)
				end
				Message.Text = "Next color in: 0s"
				task.wait(0.5) 
				if string.match(Message.Text, "Next color in") then
					UIAnimations.PopOutToTop(Message)
				end
			end)
			return
		end

		local colorCode = Color3.new(1, 1, 1)
		if color == "Red" then colorCode = Color3.new(1, 0.2, 0.2)
		elseif color == "Blue" then colorCode = Color3.new(0.2, 0.5, 1)
		elseif color == "Green" then colorCode = Color3.new(0.2, 1, 0.2)
		elseif color == "Yellow" then colorCode = Color3.new(1, 0.9, 0.2) end

		Message.TextColor3 = colorCode
		UIAnimations.PopInFromTop(Message)
		UIAnimations.PopText(Message)
		
		currentColorThread = task.spawn(function()
			for i = duration, 1, -1 do
				Message.Text = "STAND ON " .. string.upper(color) .. "! (" .. i .. "s)"
				task.wait(1)
			end
			Message.Text = "STAND ON " .. string.upper(color) .. "! (0s)"
			task.wait(2.2) 
			if string.match(Message.Text, "STAND ON") then
				UIAnimations.PopOutToTop(Message)
			end
		end)
	end)

	player:GetAttributeChangedSignal("InMenu"):Connect(syncUIVisibility)
	
	player:GetAttributeChangedSignal("IsPlaying"):Connect(function()
		TopFrame.Visible = (currentState == RoundConfig.States.InGame and player:GetAttribute("IsPlaying") == true)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if currentState == RoundConfig.States.InGame then UpdateTopBar() end
		end
	end)
end

return RoundUIController