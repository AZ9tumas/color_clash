local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local UtilityConfig = require(Shared.Modules.Core.UtilityConfig)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local WeaponServer = require(ServerScriptService.Server.Classes.WeaponServer)
local LagCompensation = require(ServerScriptService.Server.Classes.LagCompensation)

-- Throwables (CombatConfig.Utilities). The server owns all of it: charges and
-- their recharge (published as the GrenadeCharges player attribute), the
-- grenade's flight, and the blast, which damages every character in range that
-- the explosion can see. The thrower is never hurt by their own grenade.
local UtilityServer = {}

-- How far the client-reported eye may sit from the head (as WeaponServer).
local MAX_EYE_OFFSET = 14
-- Spawn this far ahead of the eye so the grenade clears the thrower's body.
local SPAWN_AHEAD = 2.5

local DamageVFX = CombatRemotes.GetDamageVFX()

-- [Player] = { charges, nextChargeAt, lastThrowAt }
local throwers = {}

local function stateFor(player: Player)
	local state = throwers[player]
	if not state then
		state = { charges = UtilityConfig.Grenade.Charges, nextChargeAt = nil, lastThrowAt = 0 }
		throwers[player] = state
		player:SetAttribute("GrenadeCharges", state.charges)
	end
	return state
end

local function refill(player: Player)
	local state = stateFor(player)
	state.charges = UtilityConfig.Grenade.Charges
	state.nextChargeAt = nil
	player:SetAttribute("GrenadeCharges", state.charges)
end

local function explode(thrower: Player, grenade: BasePart)
	if not grenade.Parent then return end
	local config = UtilityConfig.Grenade
	local center = grenade.Position
	grenade:Destroy()

	-- Visual only: no pressure and no joint breaking; damage is applied below.
	local blast = Instance.new("Explosion")
	blast.Position = center
	blast.BlastRadius = config.Radius
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.ExplosionType = Enum.ExplosionType.NoCraters
	blast.Parent = Workspace

	local throwerCharacter = thrower.Character
	local seen = {}
	for _, part in Workspace:GetPartBoundsInRadius(center, config.Radius) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and not seen[model] and model ~= throwerCharacter and model:FindFirstChildOfClass("Humanoid") then
			seen[model] = true
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			local head = model:FindFirstChild("Head")
			local target = root or head
			if target and target:IsA("BasePart") then
				local visible = LagCompensation.IsClear(center, target.Position, model)
					or (head and LagCompensation.IsClear(center, head.Position, model))
				if visible then
					local t = math.clamp((target.Position - center).Magnitude / config.Radius, 0, 1)
					local damage = math.floor(config.MaxDamage + (config.MinDamage - config.MaxDamage) * t + 0.5)
					local killed = WeaponServer.ProcessDamage(model, damage, thrower.Name, thrower, config.DisplayName, false, center)
					if thrower.Parent then
						DamageVFX:FireClient(thrower, target.Position, tostring(damage), target, nil, killed == true)
					end
				end
			end
		end
	end
end

local function spawnGrenade(player: Player, origin: Vector3, direction: Vector3)
	local config = UtilityConfig.Grenade
	local character = player.Character

	-- Do not start the grenade on the far side of a wall the thrower is hugging.
	local start = origin + direction * SPAWN_AHEAD
	local blocked = HitscanUtil.Cast(origin, direction, SPAWN_AHEAD, character)
	if blocked then
		start = blocked.Position - direction * 0.6
	end

	local grenade = Instance.new("Part")
	grenade.Name = "FragGrenade"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(0.9, 0.9, 0.9)
	grenade.Color = Color3.fromRGB(62, 82, 46)
	grenade.Material = Enum.Material.SmoothPlastic
	grenade.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.35, 1, 1)
	grenade.CanTouch = false
	grenade.CanQuery = false
	-- It remains collidable, so HitscanUtil explicitly excludes its folder.
	grenade.CFrame = CFrame.new(start)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 6
	light.Brightness = 3
	light.Parent = grenade

	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inherited = root and root.AssemblyLinearVelocity * 0.5 or Vector3.zero
	grenade.AssemblyLinearVelocity = direction * config.ThrowSpeed + Vector3.new(0, config.ThrowLift, 0) + inherited
	grenade.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
	local folder = Workspace:FindFirstChild("GrenadeProjectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GrenadeProjectiles"
		folder.Parent = Workspace
	end
	grenade.Parent = folder
	grenade:SetNetworkOwner(nil)

	task.delay(config.Fuse, explode, player, grenade)
end

local function onThrow(player: Player, kind, origin, direction)
	if kind ~= "Grenade" or not CombatConfig.IsEnabled("Utilities") then return end
	if not player:GetAttribute("IsPlaying") or Workspace:GetAttribute("ArenaPhase") ~= "Shoot" then return end
	if not HitscanUtil.IsFiniteVector(direction) or direction.Magnitude < 0.5 then return end

	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	if not HitscanUtil.IsFiniteVector(origin) or (origin - head.Position).Magnitude > MAX_EYE_OFFSET then
		origin = head.Position
	end

	local config = UtilityConfig.Grenade
	local state = stateFor(player)
	local now = os.clock()
	if state.charges <= 0 or now - state.lastThrowAt < config.ThrowCooldown then return end

	state.charges -= 1
	state.lastThrowAt = now
	state.nextChargeAt = state.nextChargeAt or now + config.Recharge
	player:SetAttribute("GrenadeCharges", state.charges)
	spawnGrenade(player, origin, direction.Unit)
end

function UtilityServer.Init()
	CombatRemotes.GetThrowUtility().OnServerEvent:Connect(onThrow)

	local function watch(player: Player)
		stateFor(player)
		-- every round starts with full charges
		player:GetAttributeChangedSignal("IsPlaying"):Connect(function()
			if player:GetAttribute("IsPlaying") then refill(player) end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		throwers[player] = nil
	end)

	-- Recharge one charge at a time.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then return end
		accumulator = 0
		local now = os.clock()
		local config = UtilityConfig.Grenade
		for player, state in throwers do
			if state.nextChargeAt and now >= state.nextChargeAt then
				state.charges = math.min(state.charges + 1, config.Charges)
				state.nextChargeAt = state.charges < config.Charges and now + config.Recharge or nil
				player:SetAttribute("GrenadeCharges", state.charges)
			end
		end
	end)
end

return UtilityServer
