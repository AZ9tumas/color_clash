local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local FXConfig = require(Shared.Modules.Core.FXConfig)
local GunHandler = require(Shared.Classes.GunHandler)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Gun] " .. string.format(message, ...))
	end
end

-- Entry point in the reference gunsystem's architecture: one controller per gun tool,
-- input routed to whichever controller is currently equipped. The reference built its
-- controllers once on a ClientGunInit signal; here tools are granted and stripped every
-- round phase, so controllers are built and torn down on backpack traffic instead.
local GunClient = {}

local player = Players.LocalPlayer

local gunControllers = {}
local currentlyEquippedGun = nil

local function isGunTool(tool)
	if not tool:IsA("Tool") then return false end
	local data = Items[tool.Name]
	return data ~= nil and data.MaxAmmo ~= nil
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
	if not isGunTool(tool) then return end
	if gunControllers[tool] then return end

	-- Isolated per gun: a bad gun logs and is skipped, everything else keeps working.
	local ok, controller = pcall(GunHandler.New, tool)
	if not ok or not controller then
		if not ok then
			warn(string.format("[Gun] setup failed for %q: %s", tool.Name, tostring(controller)))
		end
		return
	end

	gunControllers[tool] = controller
	log("controller built for %s", tool.Name)

	-- Equip state is DERIVED from where the tool actually is, never from event order:
	-- with deferred signals a backpack-to-character hop can deliver a stale Unequipped
	-- after the final Equipped, and trusting the sequence shuts the rig straight back
	-- off. Parent checks cannot be reordered.
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
			currentlyEquippedGun:shoot()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			currentlyEquippedGun:ADS()
		elseif input.KeyCode == Enum.KeyCode.R then
			currentlyEquippedGun:Reload()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not currentlyEquippedGun then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			currentlyEquippedGun:stopShoot()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			currentlyEquippedGun:stopADS()
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
