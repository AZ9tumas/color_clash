local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local FXConfig = require(Shared.Modules.Core.FXConfig)
local GunHandler = require(Shared.Classes.GunHandler)
local MeleeHandler = require(Shared.Classes.MeleeHandler)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Gun] " .. string.format(message, ...))
	end
end

local GunClient = {}

local player = Players.LocalPlayer

local gunControllers = {}
local currentlyEquippedGun = nil

local function weaponDataFor(tool)
	if not tool:IsA("Tool") then return nil end
	return Items[tool.Name]
end

local function teardown(tool)
	local controller = gunControllers[tool]
	if not controller then return end

	gunControllers[tool] = nil
	if currentlyEquippedGun == controller then
		currentlyEquippedGun = nil
	end

	local ok, err = pcall(function() controller:Destroy() end)
	if not ok then
		warn(string.format("[Gun] teardown failed for %q: %s", tool.Name, tostring(err)))
	end
	log("teardown %s (tool destroyed or removed)", tool.Name)
end

local function setup(tool)
	local data = weaponDataFor(tool)
	if not data then return end
	if gunControllers[tool] then return end

	local factory = data.MaxAmmo and GunHandler.New or MeleeHandler.New
	local ok, controller = pcall(factory, tool)
	if not ok or not controller then
		if not ok then
			warn(string.format("[Gun] setup failed for %q: %s", tool.Name, tostring(controller)))
		end
		return
	end

	gunControllers[tool] = controller
	log("controller built for %s", tool.Name)

	local function refreshEquipState()
		if not gunControllers[tool] then return end
		local shouldEquip = tool.Parent == player.Character

		if shouldEquip and not controller.isEquipped then
			local ok, err = pcall(function() controller:Equip() end)
			if ok then
				currentlyEquippedGun = controller
				log("equipped %s: shoulder cam + arm tracking on", tool.Name)
			else
				warn(string.format("[Gun] equip FAILED for %q: %s", tool.Name, tostring(err)))
			end
		elseif not shouldEquip and controller.isEquipped then
			pcall(function() controller:Unequip() end)
			if currentlyEquippedGun == controller then
				currentlyEquippedGun = nil
			end
			log("unequipped %s (parent now %s)", tool.Name, tostring(tool.Parent))
		end
	end

	tool.AncestryChanged:Connect(function()
		if tool.Parent == nil then
			teardown(tool)
		else
			task.defer(refreshEquipState)
		end
	end)

	tool.Destroying:Connect(function()
		teardown(tool)
	end)

	refreshEquipState()
end

local function watchContainer(container)
	for _, tool in container:GetChildren() do
		setup(tool)
	end
	container.ChildAdded:Connect(setup)
end

function GunClient.Init()
	log("GunClient initialized - controllers will report as tools arrive")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not currentlyEquippedGun then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if currentlyEquippedGun.shoot then
				currentlyEquippedGun:shoot()
			elseif currentlyEquippedGun.Swing then
				currentlyEquippedGun:Swing()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if currentlyEquippedGun.ADS then currentlyEquippedGun:ADS() end
		elseif input.KeyCode == Enum.KeyCode.R then
			if currentlyEquippedGun.Reload then currentlyEquippedGun:Reload() end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not currentlyEquippedGun then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if currentlyEquippedGun.stopShoot then currentlyEquippedGun:stopShoot() end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if currentlyEquippedGun.stopADS then currentlyEquippedGun:stopADS() end
		end
	end)

	local function onCharacterAdded(character)
		watchContainer(character)
		local backpack = player:WaitForChild("Backpack", 5)
		if backpack then watchContainer(backpack) end
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return GunClient
