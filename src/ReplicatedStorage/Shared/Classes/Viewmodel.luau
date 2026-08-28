local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gunsystem = Shared.Modules.Gunsystem
local GunsystemGunHandler = require(Gunsystem.GunHandler)
local ViewModelHandler = require(Gunsystem.ViewModelHandler)

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local player = Players.LocalPlayer
local shared = nil

local function equippedTool(weaponName: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(weaponName)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

function Viewmodel.new()
	local renderer = ViewModelHandler.new(Vector3.zero)
	renderer:SyncCharacterMeshes(player.Character)

	return setmetatable({
		renderer = renderer,
		model = renderer.model,
		weaponController = nil,
		weaponName = nil,
		enabled = false,
		destroyed = false,
	}, Viewmodel)
end

function Viewmodel.GetShared()
	if shared and not shared.destroyed then
		return shared
	end
	shared = Viewmodel.new()
	return shared
end

-- Non-creating accessor. Callers that only want to decorate an existing
-- viewmodel must not spawn one for a player who is not in first person.
function Viewmodel.GetExisting()
	if shared and not shared.destroyed then
		return shared
	end
	return nil
end

function Viewmodel.ClearShared()
	if shared then
		shared:Destroy()
		shared = nil
	end
end

function Viewmodel:SyncCharacterMeshes(character: Model?)
	if self.destroyed then return end
	self.renderer:SyncCharacterMeshes(character)
end

function Viewmodel:SetWeapon(weaponName: string, _config, tool: Tool?): boolean
	if self.destroyed then return false end
	self:ClearWeapon()

	local sourceTool = tool or equippedTool(weaponName)
	if not sourceTool then
		warn(string.format("[Viewmodel] %s has no equipped Tool", weaponName))
		return false
	end

	local controller = GunsystemGunHandler.New(sourceTool, self.renderer)
	if not controller then return false end

	local ok, err = pcall(function()
		controller:Equip()
	end)
	if not ok then
		warn(string.format("[Viewmodel] failed to equip %s: %s", weaponName, tostring(err)))
		return false
	end

	self.weaponController = controller
	self.weaponName = weaponName

	-- GunHandler:Equip enables the shared renderer. Preserve the production
	-- first-person toggle when a Tool is equipped while the camera is classic.
	if not self.enabled then
		self.renderer:Disable()
	end
	return true
end

function Viewmodel:ClearWeapon()
	if self.weaponController then
		self.weaponController:Unequip()
		self.weaponController = nil
	end
	self.weaponName = nil
end

function Viewmodel:GetAnimator(): Animator?
	if self.destroyed then return nil end
	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

function Viewmodel:GetMuzzlePosition(): Vector3?
	local controller = self.weaponController
	return controller and controller:GetMuzzlePosition() or nil
end

function Viewmodel:GetEjectPosition(): Vector3?
	local controller = self.weaponController
	return controller and controller:GetEjectPosition() or nil
end

-- Emitted on the viewmodel gun itself, so the flash tracks the weapon instead of
-- being stamped into the world at the position it happened to occupy this frame.
function Viewmodel:MuzzleFlash(scale: number?)
	local controller = self.weaponController
	if controller then
		controller:MuzzleFlash(scale)
	end
end

function Viewmodel:applyRecoilImpulse(impulse: Vector3)
	if self.destroyed then return end
	self.renderer:applyRecoilImpulse(impulse)
end

function Viewmodel:StartADS()
	if self.destroyed then return end
	self.renderer:StartADS(Vector3.zero)
end

function Viewmodel:StopADS()
	if self.destroyed then return end
	self.renderer:StopADS()
end

function Viewmodel:PlayReload(duration: number?): boolean
	local controller = self.weaponController
	if not controller then return false end
	return controller:PlayReloadAnimation(duration)
end

function Viewmodel:StopReload()
	local controller = self.weaponController
	if controller then
		controller:StopReloadAnimation()
	end
end

function Viewmodel:PlayShoot(): boolean
	local controller = self.weaponController
	if not controller then return false end
	return controller:PlayShootAnimation()
end

function Viewmodel:Enable()
	if self.destroyed then return end
	self.enabled = true
	self.renderer:SyncCharacterMeshes(player.Character)
	self.renderer:Enable()
end

function Viewmodel:Disable()
	if self.destroyed then return end
	self.enabled = false
	self.renderer:Disable()
end

function Viewmodel:Destroy()
	if self.destroyed then return end
	self:ClearWeapon()
	self.renderer:Disable()
	self.renderer.offsetSpring:Destroy()
	self.model:Destroy()
	self.destroyed = true
end

return Viewmodel
