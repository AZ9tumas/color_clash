local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)

local PushServer = {}

local lastPush = {}

local function log(message, ...)
	if RoundConfig.Push.Debug then
		print("[Push/server] " .. string.format(message, ...))
	end
end

-- Applies the shove with a LinearVelocity rather than writing AssemblyLinearVelocity.
-- The target's own client owns their character's physics, so a server-side velocity write
-- gets fought or discarded; a constraint replicates and the owning client simulates it.
-- Same mover and attachment pattern MovementClient uses for slide and wall-climb.
local function applyPush(targetRoot, velocity)
	local config = RoundConfig.Push

	-- Repeated shoves must not stack movers on one character.
	local existing = targetRoot:FindFirstChild("PushVelocity")
	if existing then existing:Destroy() end

	local attachment = targetRoot:FindFirstChild("RootRigAttachment")
		or targetRoot:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "PushAttachment"
		attachment.Parent = targetRoot
	end

	local mover = Instance.new("LinearVelocity")
	mover.Name = "PushVelocity"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(config.MaxForce, config.MaxForce, config.MaxForce)
	mover.VectorVelocity = velocity
	mover.Parent = targetRoot

	-- Impulse, not a sustained force: let it go after Duration.
	Debris:AddItem(mover, config.Duration)
end

-- Fully server-authoritative: the client only says "I pushed", the server decides who is
-- close enough to be hit and how hard, so a client cannot pick its own targets or force.
local function tryPush(pusher)
	local config = RoundConfig.Push

	-- Legal for the whole round regardless of phase. IsPlaying is only true between the
	-- round-start teleport and round end, so it covers both "round is on" and "is a player".
	if not pusher:GetAttribute("IsPlaying") then
		log("%s rejected: not IsPlaying, so not in the round", pusher.Name)
		return
	end

	local now = tick()
	local since = now - (lastPush[pusher.UserId] or 0)
	if since < config.Cooldown then
		log("%s rejected: cooldown, %.2fs remaining", pusher.Name, config.Cooldown - since)
		return
	end

	local character = pusher.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		log("%s rejected: no HumanoidRootPart", pusher.Name)
		return
	end

	lastPush[pusher.UserId] = now

	local origin = root.Position
	local facing = root.CFrame.LookVector
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	flatFacing = flatFacing.Magnitude > 0 and flatFacing.Unit or Vector3.new(0, 0, -1)

	local considered, hits = 0, 0

	for _, target in Players:GetPlayers() do
		if target ~= pusher and target:GetAttribute("IsPlaying") then
			local targetChar = target.Character
			local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
			local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

			local mode = RoundConfig.CurrentMode
			local sameTeam = mode.TeamBased
				and pusher:GetAttribute("Team") ~= nil
				and pusher:GetAttribute("Team") == target:GetAttribute("Team")

			if sameTeam then
				log("  %s skipped: on your team", target.Name)
			elseif not targetRoot or not targetHum then
				log("  %s skipped: no character parts", target.Name)
			elseif targetHum.Health <= 0 then
				log("  %s skipped: dead", target.Name)
			elseif targetChar:GetAttribute("Ragdolled") then
				log("  %s skipped: already ragdolled", target.Name)
			else
				considered += 1

				local offset = targetRoot.Position - origin
				local distance = offset.Magnitude
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local direction = flat.Magnitude > 0 and flat.Unit or flatFacing
				local dot = direction:Dot(flatFacing)

				if distance > config.Radius then
					log("  %s missed: %.1f studs away, radius is %.1f", target.Name, distance, config.Radius)
				elseif dot <= config.MinDot then
					log("  %s missed: dot %.2f, need above %.2f (not in front of you)", target.Name, dot, config.MinDot)
				else
					local velocity = (direction * config.Force) + Vector3.new(0, config.Lift, 0)
					applyPush(targetRoot, velocity)
					hits += 1
					log("  %s HIT: %.1f studs, dot %.2f, LinearVelocity (%.0f, %.0f, %.0f) for %.2fs",
						target.Name, distance, dot, velocity.X, velocity.Y, velocity.Z, config.Duration)
				end
			end
		end
	end

	log("%s pushed: %d candidate(s) in the round, %d hit", pusher.Name, considered, hits)
	if considered == 0 then
		log("  (nobody else has IsPlaying set, so there is nothing to push)")
	end
end

function PushServer.Init()
	CombatRemotes.GetPushRequest().OnServerEvent:Connect(tryPush)

	Players.PlayerRemoving:Connect(function(player)
		lastPush[player.UserId] = nil
	end)

	log("ready - radius %.1f, force %.0f, lift %.0f, cooldown %.2fs, minDot %.2f",
		RoundConfig.Push.Radius, RoundConfig.Push.Force, RoundConfig.Push.Lift,
		RoundConfig.Push.Cooldown, RoundConfig.Push.MinDot)
end

return PushServer
