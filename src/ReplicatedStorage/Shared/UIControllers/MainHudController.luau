local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)

local MainHudController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local WeaponsFrame = MainHUD:WaitForChild("Weapons")
local AmmoText = WeaponsFrame:WaitForChild("Info"):WaitForChild("Ammo")
local NameText = WeaponsFrame:WaitForChild("Info"):WaitForChild("Name")

local MainSlotBtn = WeaponsFrame:WaitForChild("Main"):WaitForChild("btn")
local MeleeSlotBtn = WeaponsFrame:WaitForChild("Melee"):WaitForChild("btn")

local HealthBarFrame = MainHUD:WaitForChild("HealthBar")
local HealthAmount = HealthBarFrame:WaitForChild("Holder"):WaitForChild("Amount")
local HealthBarFill = HealthBarFrame:WaitForChild("Bar")

local currentWeaponsVisible = false

function MainHudController.SetWeaponInfo(weaponName, ammoStr)
	NameText.Text = weaponName or "N/A"
	AmmoText.Text = ammoStr or "N/A"
end

local weaponsFolder = nil

local function weaponTemplate(name)
	if not weaponsFolder then
		local assets = Shared:FindFirstChild("Assets")
		weaponsFolder = assets and assets:FindFirstChild("Weapons")
	end
	if not weaponsFolder or not name then return nil end
	return weaponsFolder:FindFirstChild(name)
end

local function boundsOf(instance)
	local min, max
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") then
			local lo, hi = d.Position - d.Size / 2, d.Position + d.Size / 2
			min = min and Vector3.new(math.min(min.X, lo.X), math.min(min.Y, lo.Y), math.min(min.Z, lo.Z)) or lo
			max = max and Vector3.new(math.max(max.X, hi.X), math.max(max.Y, hi.Y), math.max(max.Z, hi.Z)) or hi
		end
	end
	return min, max
end

local function renderWeaponIcon(btn, weaponName)
	local viewport = btn:FindFirstChild("WeaponIcon")
	local template = weaponTemplate(weaponName)

	if not template then
		if viewport then viewport.Visible = false end
		return
	end

	if viewport and viewport:GetAttribute("Weapon") == weaponName then
		viewport.Visible = true
		return
	end

	if not viewport then
		viewport = Instance.new("ViewportFrame")
		viewport.Name = "WeaponIcon"
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = btn.ZIndex + 1
		viewport.Parent = btn
	end

	for _, child in viewport:GetChildren() do child:Destroy() end

	local model = template:Clone()

	for _, d in model:GetDescendants() do
		if d:IsA("Sound") or d:IsA("RemoteEvent") or d:IsA("BaseScript") or d:IsA("Animation") then
			d:Destroy()
		end
	end
	model.Parent = viewport

	local min, max = boundsOf(model)
	if not min then
		viewport.Visible = false
		return
	end

	local center = (min + max) / 2
	local radius = math.max((max - min).Magnitude / 2, 0.1)

	local cam = Instance.new("Camera")
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	cam.CFrame = CFrame.lookAt(center + Vector3.new(1, 0.45, 1).Unit * (radius * 2.6), center)

	viewport:SetAttribute("Weapon", weaponName)
	viewport.Visible = true

	btn.Image = ""
end

local function refreshWeaponIcons()
	local mainName, meleeName

	local containers = {}
	if player.Character then table.insert(containers, player.Character) end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then table.insert(containers, backpack) end

	for _, container in containers do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") then
					local data = Items[tool.Name]
					local isMain = data and data.MaxAmmo ~= nil
					if isMain and not mainName then
						mainName = tool.Name
					elseif not isMain and not meleeName then
						meleeName = tool.Name
					end
				end
			end
		end
	end

	renderWeaponIcon(MainSlotBtn, mainName)
	renderWeaponIcon(MeleeSlotBtn, meleeName)
end

local function updateVisibility()
	local hasTools = false
	if player.Character then
		for _, child in player.Character:GetChildren() do
			if child:IsA("Tool") then hasTools = true; break end
		end
	end
	if not hasTools then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, child in backpack:GetChildren() do
				if child:IsA("Tool") then hasTools = true; break end
			end
		end
	end

	local isPlaying = player:GetAttribute("IsPlaying") == true
	local shouldShowWeapons = isPlaying and hasTools

	if shouldShowWeapons ~= currentWeaponsVisible then
		currentWeaponsVisible = shouldShowWeapons
		if shouldShowWeapons then
			UIAnimations.PopIn(WeaponsFrame)
		else
			UIAnimations.PopOut(WeaponsFrame)
		end
	end

	HealthBarFrame.Visible = isPlaying
	refreshWeaponIcons()
end

local function updateHealth(health, maxHealth)
	health = math.max(0, health)
	maxHealth = math.max(1, maxHealth)
	HealthAmount.Text = math.floor(health) .. "/" .. math.floor(maxHealth)
	TweenService:Create(HealthBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(math.clamp(health / maxHealth, 0, 1), 0, 1, 0)}):Play()
end

local function equipWeapon(slot)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local targetTool = nil
	local backpack = player:FindFirstChild("Backpack")

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local isMain = Items[tool.Name] and Items[tool.Name].MaxAmmo ~= nil
				if (slot == "Main" and isMain) or (slot == "Melee" and not isMain) then
					targetTool = tool; break
				end
			end
		end
	end

	if not targetTool then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				local isMain = Items[tool.Name] and Items[tool.Name].MaxAmmo ~= nil
				if (slot == "Main" and isMain) or (slot == "Melee" and not isMain) then
					targetTool = tool; break
				end
			end
		end
	end

	if targetTool then
		if targetTool.Parent == char then humanoid:UnequipTools() else humanoid:EquipTool(targetTool) end
	end
end

function MainHudController.Init()
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	task.spawn(function()
		local StarterGui = game:GetService("StarterGui")
		local resetBindable = Instance.new("BindableEvent")
		resetBindable.Event:Connect(function()
			RoundRemotes.GetResetEvent():FireServer()
		end)

		local success = false
		while not success do
			success = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", resetBindable)
			end)
			task.wait(0.5)
		end
	end)

	UIAnimations.InitializePopObject(WeaponsFrame)
	HealthBarFrame.Visible = false
	MainHudController.SetWeaponInfo("N/A", "N/A")

	UIAnimations.BindButtonAnimations(MainSlotBtn)
	UIAnimations.BindButtonAnimations(MeleeSlotBtn)
	MainSlotBtn.MouseButton1Click:Connect(function() equipWeapon("Main") end)
	MeleeSlotBtn.MouseButton1Click:Connect(function() equipWeapon("Melee") end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("InMenu") ~= false then return end
		if input.KeyCode == Enum.KeyCode.One then equipWeapon("Main")
		elseif input.KeyCode == Enum.KeyCode.Two then equipWeapon("Melee") end
	end)

	player:GetAttributeChangedSignal("IsPlaying"):Connect(updateVisibility)

	local function onCharacterAdded(char)
		char.ChildAdded:Connect(updateVisibility)
		char.ChildRemoved:Connect(updateVisibility)

		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			humanoid.BreakJointsOnDeath = false

			humanoid.HealthChanged:Connect(function(h)
				updateHealth(h, humanoid.MaxHealth)
				if h <= 0 then
					task.delay(0.1, function()
						local PlayerScripts = player:FindFirstChild("PlayerScripts")
						if PlayerScripts then
							local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
							if PlayerModule and type(PlayerModule) == "table" and PlayerModule.GetControls then
								PlayerModule:GetControls():Enable(true)
							end
						end
						if humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid:GetState() == Enum.HumanoidStateType.Physics then
							humanoid:ChangeState(Enum.HumanoidStateType.Running)
						end
					end)
				end
			end)
			updateHealth(humanoid.Health, humanoid.MaxHealth)
		end

		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			backpack.ChildAdded:Connect(updateVisibility)
			backpack.ChildRemoved:Connect(updateVisibility)
		end

		updateVisibility()
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return MainHudController