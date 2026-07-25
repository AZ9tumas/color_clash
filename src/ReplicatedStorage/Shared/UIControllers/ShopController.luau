local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ShopConfig = require(Shared.Modules.Core.ShopConfig)
local ShopRemotes = require(Shared.Remotes.ShopRemotes)
local FormatUtil = require(Shared.Modules.Utils.FormatUtil)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)

local ShopController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ShopGui = PlayerGui:WaitForChild("Shop")
local ShopFrame = ShopGui:WaitForChild("Frame")

local CategoryFrame = ShopFrame:WaitForChild("Category")
local CatScroll = CategoryFrame:WaitForChild("ScrollingFrame")
local MainFrame = ShopFrame:WaitForChild("MainFrame")
local Container = MainFrame:WaitForChild("Container")

local SectionTemplate = Container:WaitForChild("Section")
local Template = Container:WaitForChild("Template")

local currentCategory = nil
local isSwitching = false
local isFirstLoad = true
local inventoryData = { Inventory = {}, Equipped = {} }

local activeUpdaters = {}
local origSectionPos = nil
local origTemplatePos = nil
local lastOverlapZone = "None"

local tabsData = {
	Weapons = { UI = CatScroll:WaitForChild("Weapons"), UnselSize = UDim2.new(0.134, 0, 0.116, 0), UnselPos = UDim2.new(0.5, 0, 1, 0), SelSize = UDim2.new(1, 0, 0.116, 0), SelPos = UDim2.new(0.5, 0, 1, 0) },
	Skins = { UI = CatScroll:WaitForChild("Skins"), UnselSize = UDim2.new(0.228, 0, 0.116, 0), UnselPos = UDim2.new(0.5, 0, 1, 0), SelSize = UDim2.new(1.574, 0, 0.116, 0), SelPos = UDim2.new(0.85, 0, 1, 0) },
	Effects = { UI = CatScroll:WaitForChild("Effects"), UnselSize = UDim2.new(0.15, 0, 0.116, 0), UnselPos = UDim2.new(0.5, 0, 1, 0), SelSize = UDim2.new(1.176, 0, 0.116, 0), SelPos = UDim2.new(0.65, 0, 1, 0) }
}

local function checkPadOverlap(part)
	if not part or not player.Character then return false end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local pDir = hrp.Position - part.Position
		local ext = part.Size / 2
		return math.abs(pDir.X) < ext.X + 2.5 and math.abs(pDir.Y) < ext.Y + 2.5 and math.abs(pDir.Z) < ext.Z + 2.5
	end
	return false
end

local function updateTabVisuals(activeTabName)
	local colorNormal = Color3.fromRGB(200, 200, 200)
	local colorSelected = Color3.fromRGB(255, 255, 255)
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	for tabName, data in pairs(tabsData) do
		local titleFrame = data.UI.btn.Title.Frame
		local titleText = data.UI.btn.Title
		local targetSize = (tabName == activeTabName) and data.SelSize or data.UnselSize
		local targetPos = (tabName == activeTabName) and data.SelPos or data.UnselPos
		local targetColor = (tabName == activeTabName) and colorSelected or colorNormal

		TweenService:Create(titleFrame, tweenInfo, {Size = targetSize, Position = targetPos, BackgroundColor3 = targetColor}):Play()
		TweenService:Create(titleText, tweenInfo, {TextColor3 = targetColor}):Play()
	end
end

local function getGroupedSubcategories(categoryName)
	local items = ShopConfig.Categories[categoryName] or {}
	local order = {}
	local dict = {}
	
	if categoryName == "Weapons" then
		order = {"Ranged", "Melee"}
	else
		order = {categoryName}
	end

	for _, sub in ipairs(order) do dict[sub] = {} end

	for _, item in ipairs(items) do
		local sub = item.Subcategory or categoryName
		if not dict[sub] then
			dict[sub] = {}
			table.insert(order, sub)
		end
		table.insert(dict[sub], item)
	end

	return order, dict
end

local function setButtonGradient(btn, gradName, animate)
	local targetGrad = btn:FindFirstChild(gradName)
	if not targetGrad then return end
	
	if targetGrad.Enabled and targetGrad.Offset.X == 0 then return end

	for _, child in btn:GetChildren() do
		if child:IsA("UIGradient") and child.Name ~= gradName then
			child.Enabled = false
		end
	end

	targetGrad.Enabled = true
	if animate then
		targetGrad.Offset = Vector2.new(-1, 0)
		TweenService:Create(targetGrad, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Offset = Vector2.new(0, 0)}):Play()
	else
		targetGrad.Offset = Vector2.new(0, 0)
	end
end

local function bumpButton(btn)
	local scaleObj = btn:FindFirstChildOfClass("UIScale")
	if not scaleObj then
		scaleObj = Instance.new("UIScale", btn)
	end
	scaleObj.Scale = 0.85
	TweenService:Create(scaleObj, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function switchCategory(categoryName)
	if currentCategory == categoryName or isSwitching then return end
	isSwitching = true
	currentCategory = categoryName
	updateTabVisuals(categoryName)

	local outInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local inInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local popInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if not isFirstLoad then
		for _, child in Container:GetChildren() do
			if child:IsA("Frame") and child.Name == "ItemTemplate" then
				local uiScale = child.Frame:FindFirstChildOfClass("UIScale")
				if uiScale then
					TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
				end
			elseif child:IsA("Frame") and child.Name == "SectionInstance" then
				TweenService:Create(child.Frame, outInfo, {Position = UDim2.new(1.5, 0, origSectionPos.Y.Scale, origSectionPos.Y.Offset)}):Play()
			end
		end
		
		task.wait(0.25)
		for _, child in Container:GetChildren() do
			if child.Name == "ItemTemplate" or child.Name == "SectionInstance" then child:Destroy() end
		end
	end
	
	isFirstLoad = false
	activeUpdaters = {}

	local subOrder, subDict = getGroupedSubcategories(categoryName)
	local layoutCounter = 1

	for _, subName in ipairs(subOrder) do
		local items = subDict[subName]
		if #items > 0 or subName == categoryName then
			
			local secClone = SectionTemplate:Clone()
			secClone.Name = "SectionInstance"
			secClone.LayoutOrder = layoutCounter
			secClone.ZIndex = layoutCounter
			layoutCounter += 1
			
			local secFrame = secClone.Frame
			local secTitle = secFrame.Title
			local secUnderline = secTitle.Frame
			
			secTitle.Text = subName
			secFrame.Position = UDim2.new(-1.5, 0, origSectionPos.Y.Scale, origSectionPos.Y.Offset)
			
			local colorDim = Color3.fromRGB(200, 200, 200)
			local colorWhite = Color3.fromRGB(255, 255, 255)
			
			secTitle.TextColor3 = colorDim
			secUnderline.BackgroundColor3 = colorDim
			secUnderline.Size = UDim2.new(0.05, 0, 0.116, 0)
			secUnderline.Position = UDim2.new(0.469, 0, 1, 0)
			
			secClone.Visible = true
			secClone.Parent = Container
			
			TweenService:Create(secFrame, inInfo, {Position = origSectionPos}):Play()
			
			task.delay(0.25, function()
				if secTitle and secUnderline then
					TweenService:Create(secTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextColor3 = colorWhite}):Play()
					TweenService:Create(secUnderline, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = colorWhite,
						Size = UDim2.new(1, 0, 0.116, 0),
						Position = UDim2.new(0.5, 0, 1, 0)
					}):Play()
				end
			end)
			
			task.wait(0.1)

			for _, item in ipairs(items) do
				local clone = Template:Clone()
				clone.Name = "ItemTemplate"
				clone.LayoutOrder = layoutCounter
				clone.ZIndex = layoutCounter
				layoutCounter += 1
				
				clone.Frame.Title.Text = item.Name
				clone.Frame.Description.Text = item.Description
				clone.Frame.Position = origTemplatePos
				
				local uiScale = clone.Frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", clone.Frame)
				uiScale.Scale = 0 
				
				local buyBtn = clone.Frame.BuyButtons.btn
				UIAnimations.BindButtonAnimations(buyBtn)
				
				local isProcessing = false
				
				local function updateButtonVisuals(animate)
					local isOwned = inventoryData.Inventory[categoryName] and inventoryData.Inventory[categoryName][item.Name]
					local isEquipped = false
					
					if categoryName == "Weapons" then
						local slot = item.Subcategory == "Melee" and "Melee" or "Main"
						isEquipped = inventoryData.Equipped[slot] == item.Name
					end

					if isEquipped then
						buyBtn.Price.Text = "Equipped"
						setButtonGradient(buyBtn, "Equipped", animate)
					elseif isOwned then
						buyBtn.Price.Text = "Equip"
						setButtonGradient(buyBtn, "Equip", animate)
					else
						buyBtn.Price.Text = "$" .. FormatUtil.Suffix(item.Price)
						setButtonGradient(buyBtn, "Purchase", animate)
					end
				end

				updateButtonVisuals(false)
				table.insert(activeUpdaters, updateButtonVisuals)

				buyBtn.MouseButton1Click:Connect(function()
					if isProcessing then return end
					isProcessing = true
					
					bumpButton(buyBtn)
					
					local isOwned = inventoryData.Inventory[categoryName] and inventoryData.Inventory[categoryName][item.Name]
					local slot = item.Subcategory == "Melee" and "Melee" or "Main"
					local isEquipped = categoryName == "Weapons" and inventoryData.Equipped[slot] == item.Name

					if not isOwned then
						local success = ShopRemotes.GetBuyItemFunction():InvokeServer(categoryName, item.Name)
						if success then
							inventoryData.Inventory[categoryName] = inventoryData.Inventory[categoryName] or {}
							inventoryData.Inventory[categoryName][item.Name] = true
							
							for _, updateFn in ipairs(activeUpdaters) do updateFn(true) end
						else
							buyBtn.Price.Text = "Failed"
							setButtonGradient(buyBtn, "Failed", true)
							
							task.delay(1, function()
								for _, updateFn in ipairs(activeUpdaters) do updateFn(true) end
							end)
						end
					elseif not isEquipped then
						local success, assignedSlot = ShopRemotes.GetEquipItemFunction():InvokeServer(categoryName, item.Name)
						if success then
							inventoryData.Equipped[assignedSlot] = item.Name
							for _, updateFn in ipairs(activeUpdaters) do updateFn(true) end
						end
					end
					
					isProcessing = false
				end)

				clone.Visible = true
				clone.Parent = Container

				TweenService:Create(uiScale, popInfo, {Scale = 1}):Play()
				task.wait(0.04)
			end
		end
	end
	
	isSwitching = false
end

function ShopController.Init()
	SectionTemplate.Visible = false
	Template.Visible = false
	
	origSectionPos = SectionTemplate.Frame.Position
	origTemplatePos = Template.Frame.Position
	
	task.spawn(function()
		inventoryData = ShopRemotes.GetInventoryFunction():InvokeServer()
		
		for tabName, data in pairs(tabsData) do
			data.UI.btn.MouseButton1Click:Connect(function()
				switchCategory(tabName)
			end)
		end
		
		switchCategory("Weapons")
	end)
	
	RunService.Heartbeat:Connect(function()
		local shopPart = Workspace:FindFirstChild("Shop")
		local skinsPart = Workspace:FindFirstChild("Skins")
		
		local currentZone = "None"
		
		if checkPadOverlap(shopPart) then
			currentZone = "Weapons"
		elseif checkPadOverlap(skinsPart) then
			currentZone = "Skins"
		end
		
		if currentZone ~= lastOverlapZone then
			lastOverlapZone = currentZone
			
			if currentZone == "Weapons" then
				if currentCategory ~= "Weapons" then switchCategory("Weapons") end
				UIAnimations.PopIn(ShopFrame)
			elseif currentZone == "Skins" then
				if currentCategory ~= "Skins" then switchCategory("Skins") end
				UIAnimations.PopIn(ShopFrame)
			else
				if player:GetAttribute("InMenu") == false then
					UIAnimations.PopOut(ShopFrame)
				end
			end
		end
	end)
end

return ShopController