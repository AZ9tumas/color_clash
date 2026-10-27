local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)

-- Keeps the last second of every character's body-part positions, so a shot can
-- be checked against the scene the shooter saw when they fired, not where the
-- target has moved since. Players are recorded automatically; tag any other
-- model TRACK_TAG (a bot, a test dummy) to record it too. Other humanoids are
-- checked where they stand now. Only records while ClientHitReg is on.
local LagCompensation = {}

local TRACK_TAG = "LagCompensated"
local HISTORY_SECONDS = 1

-- How far back a shot may be checked: the shooter's round trip plus the delay
-- Roblox adds when interpolating other characters, capped so a high ping or a
-- lying client cannot land shots on positions from long ago.
local INTERPOLATION_ALLOWANCE = 0.15
local MIN_REWIND = 0.2
local MAX_REWIND = 0.6

-- Padding around each part for float error, plus how far it moved between two
-- samples (capped, so a teleport does not inflate the box).
local BASE_TOLERANCE = 0.35
local MAX_MOTION_SLACK = 4

-- How much earlier along the ray another body part must start before the
-- claimed part counts as hidden behind it.
local OCCLUSION_MARGIN = 0.5

-- [Model] = { parts = { BasePart }?, frames = { { time, cframes } }, connections }
local tracked = {}

local function collectParts(model: Model): { BasePart }
	local parts = {}
	for _, descendant in model:GetDescendants() do
		-- Held tools are not hittable (PlayerUtil.MakeToolPhysicsSafe).
		if descendant:IsA("BasePart") and not descendant:FindFirstAncestorWhichIsA("Tool") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function untrack(model: Model)
	local entry = tracked[model]
	if not entry then return end
	tracked[model] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then return end

	local entry = { parts = nil, frames = {}, connections = {} }
	tracked[model] = entry

	local function markDirty()
		entry.parts = nil
	end
	table.insert(entry.connections, model.DescendantAdded:Connect(markDirty))
	table.insert(entry.connections, model.DescendantRemoving:Connect(markDirty))
	table.insert(entry.connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then untrack(model) end
	end))
	table.insert(entry.connections, model.Destroying:Connect(function()
		untrack(model)
	end))
end

local function record(now: number)
	for model, entry in tracked do
		if not entry.parts then
			entry.parts = collectParts(model)
		end

		local cframes = {}
		for _, part in entry.parts do
			cframes[part] = part.CFrame
		end

		local frames = entry.frames
		table.insert(frames, { time = now, cframes = cframes })
		while frames[1] and frames[1].time < now - HISTORY_SECONDS do
			table.remove(frames, 1)
		end
	end
end

local function slab(origin: number, direction: number, half: number, tMin: number, tMax: number): (number?, number?)
	if math.abs(direction) < 1e-8 then
		if origin < -half or origin > half then return nil, nil end
		return tMin, tMax
	end
	local t1 = (-half - origin) / direction
	local t2 = (half - origin) / direction
	if t1 > t2 then t1, t2 = t2, t1 end
	return math.max(tMin, t1), math.min(tMax, t2)
end

-- Distance along the ray to where it enters the box, or nil if it misses.
local function rayBoxEntry(origin: Vector3, direction: Vector3, cframe: CFrame, halfSize: Vector3): number?
	local o = cframe:PointToObjectSpace(origin)
	local d = cframe:VectorToObjectSpace(direction)

	local tMin, tMax = slab(o.X, d.X, halfSize.X, -math.huge, math.huge)
	if not tMin or tMin > tMax then return nil end
	tMin, tMax = slab(o.Y, d.Y, halfSize.Y, tMin, tMax)
	if not tMin or tMin > tMax then return nil end
	tMin, tMax = slab(o.Z, d.Z, halfSize.Z, tMin, tMax)
	if not tMin or tMin > tMax or tMax < 0 then return nil end

	return math.max(tMin, 0)
end

local function rewindWindow(shooter: Player): number
	local ok, ping = pcall(shooter.GetNetworkPing, shooter)
	if not ok or type(ping) ~= "number" or ping ~= ping then
		ping = 0
	end
	return math.clamp(ping * 2 + INTERPOLATION_ALLOWANCE, MIN_REWIND, MAX_REWIND)
end

-- The character a hit part belongs to, matching how the client picks targets.
function LagCompensation.ModelOf(part: Instance): Model?
	-- Claims arrive from clients, so stored templates and non-queryable parts
	-- must never become damage targets. Collidable parts remain ray-queryable
	-- in Roblox even when their CanQuery property is false.
	if not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or part:FindFirstAncestorWhichIsA("Tool")
		or (not part.CanQuery and not part.CanCollide) then
		return nil
	end
	local model = part:FindFirstAncestorWhichIsA("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return model
	end
	return nil
end

local function currentCFrame(part: BasePart): CFrame
	return part.CFrame
end

-- Checks one moment: the claimed part, padded, must sit on the ray. The client
-- names the first part its ray met, so if another part of the same character
-- starts clearly earlier along the ray (a head claimed through the torso), the
-- pellet lands on that nearer part instead.
local function testMoment(origin, direction, range, part, padding, parts, cframeOf): (Vector3?, BasePart?)
	local cframe = cframeOf(part)
	if not cframe then return nil, nil end
	local distance = rayBoxEntry(origin, direction, cframe, part.Size * 0.5 + Vector3.one * padding)
	if not distance or distance > range then return nil, nil end

	local struck, struckAt = part, distance
	for _, other in parts do
		if other ~= part and other.CanQuery then
			local otherCFrame = cframeOf(other)
			local otherAt = otherCFrame and rayBoxEntry(origin, direction, otherCFrame, other.Size * 0.5)
			if otherAt and otherAt < struckAt - OCCLUSION_MARGIN then
				struck, struckAt = other, otherAt
			end
		end
	end
	return origin + direction * struckAt, struck
end

-- Where the ray struck the character that owns `part`, at some moment the
-- shooter could have seen it, and which part it struck first. Nil if the part
-- never sat on that ray inside the shooter's rewind window.
function LagCompensation.FindHit(shooter: Player, part: BasePart, origin: Vector3, direction: Vector3, range: number): (Vector3?, BasePart?)
	local model = LagCompensation.ModelOf(part)
	if not model then return nil, nil end
	local entry = tracked[model]
	local parts = entry and entry.parts or collectParts(model)

	local position, struck = testMoment(origin, direction, range, part, BASE_TOLERANCE, parts, currentCFrame)
	if position then return position, struck end
	if not entry then return nil, nil end

	local oldest = os.clock() - rewindWindow(shooter)
	local frames = entry.frames
	local newer = part.CFrame
	for i = #frames, 1, -1 do
		local frame = frames[i]
		if frame.time < oldest then break end

		local cframes = frame.cframes
		local cframe = cframes[part]
		if cframe then
			local motion = math.min((newer.Position - cframe.Position).Magnitude, MAX_MOTION_SLACK)
			position, struck = testMoment(origin, direction, range, part, BASE_TOLERANCE + motion, parts, function(p)
				return cframes[p]
			end)
			if position then return position, struck end
			newer = cframe
		end
	end

	return nil, nil
end

-- True when no wall stands between the two points. Characters are skipped:
-- they are at their present positions, not where the shooter saw them.
function LagCompensation.IsClear(from: Vector3, to: Vector3, target: Model?): boolean
	local offset = to - from
	local length = offset.Magnitude
	if length < 0.05 then return true end

	local ignore = {}
	if target then table.insert(ignore, target) end
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	for model in tracked do
		table.insert(ignore, model)
	end

	local result = HitscanUtil.CastIgnoring(from, offset / length, length, ignore)
	return result == nil or (result.Position - from).Magnitude >= length - 0.05
end

function LagCompensation.Start()
	local function watchPlayer(player: Player)
		if player.Character then track(player.Character) end
		player.CharacterAdded:Connect(track)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	for _, model in CollectionService:GetTagged(TRACK_TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(TRACK_TAG):Connect(track)

	local recording = false
	RunService.Heartbeat:Connect(function()
		if not CombatConfig.IsEnabled("ClientHitReg") then
			-- Drop stale history so turning the flag back on starts clean.
			if recording then
				recording = false
				for _, entry in tracked do
					table.clear(entry.frames)
				end
			end
			return
		end
		recording = true
		record(os.clock())
	end)
end

return LagCompensation
