--!strict
-- Packages the viewmodel rigs in fsafs.rbxm into a single Rojo-mountable model at
-- src/ReplicatedStorage/Viewmodels.rbxm.
--
-- The runtime does NOT play the authored animation clips. It poses the rig from a single
-- captured rest pose and drives every bit of motion procedurally, because:
--   * coverage is incomplete - four of the six rigs have no reload clip and the SMG has no
--     idle, so half the guns would sit in a bind pose at some point, and
--   * procedural motion reacts to what the player is doing this frame (speed, strafe,
--     airtime, recoil, ADS) instead of replaying a fixed curve.
-- What the clips are still good for is hand placement, which is real authored art and not
-- something worth deriving. So this script takes the first keyframe of each rig's idle
-- (falling back to its reload, whose opening frame is also the ready pose) and bakes it
-- into a RestPose folder the runtime applies to the joints.
--
-- Three other things happen here:
--   1. The six rigs are grouped under one Folder - Rojo only mounts an .rbxm with exactly
--      one root instance.
--   2. Each rig is renamed to the weapon name the game uses, so the runtime lookup is
--      Viewmodels[tool.Name] with no mapping table in the middle.
--   3. The gun's own joints are tagged with a VMRole attribute, so the runtime can find the
--      magazine and trigger to animate without pattern-matching six spellings of "Magzaine"
--      at runtime.
--
-- Re-run after re-exporting fsafs.rbxm:  lune run build_viewmodels
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local INPUT = "fsafs.rbxm"
local OUTPUT = "src/ReplicatedStorage/Viewmodels.rbxm"

-- Keyed by the gun Model inside each rig, not by the rig's own name: three of the six rigs
-- are still called "TemplateR6".
local WEAPON_BY_GUN_MODEL = {
	["P90"] = "SMG",
	["AR"] = "AR",
	["Pistol"] = "Pistol",
	["Scar"] = "Scar",
	["Shotgun"] = "Shotgun",
	["Sniper"] = "Sniper",
}

-- The rigs were authored by hand, so the same part is "Mag", "Mag ", "Magzaine",
-- "Magzaine " and "magzaine" across six files. Normalise once here rather than guessing at
-- runtime; anything unmatched stays untagged and simply is not animated.
local ROLE_PATTERNS = {
	{ role = "Magazine", patterns = { "mag" } },
	{ role = "Shell", patterns = { "bullet" } },
	{ role = "Trigger", patterns = { "trigger" } },
	{ role = "Charge", patterns = { "reload", "bolt", "upperpart", "upper" } },
}

local function normalise(name: string): string
	return (string.gsub(string.lower(name), "[^%a]", ""))
end

local function roleFor(name: string): string?
	local key = normalise(name)
	for _, entry in ROLE_PATTERNS do
		for _, pattern in entry.patterns do
			if string.find(key, pattern, 1, true) then
				return entry.role
			end
		end
	end
	return nil
end

local model = roblox.deserializeModel(fs.readFile(INPUT))

local folder = roblox.Instance.new("Folder")
folder.Name = "Viewmodels"

local report = {}

for _, rig in model do
	local gunModel = nil
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == "Model" then
			assert(gunModel == nil, string.format("rig %q holds more than one Model - cannot tell which is the gun", rig.Name))
			gunModel = descendant
		end
	end
	assert(gunModel ~= nil, string.format("rig %q has no gun Model", rig.Name))

	local weapon = WEAPON_BY_GUN_MODEL[gunModel.Name]
	assert(weapon, string.format("gun model %q in rig %q is not mapped - add it to WEAPON_BY_GUN_MODEL", gunModel.Name, rig.Name))

	-- Pick the pose source: the idle's opening frame is the ready pose; a rig with only a
	-- reload opens on the same pose, so it works just as well.
	local idle, reload = nil, nil
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == "KeyframeSequence" then
			if descendant.Loop then
				assert(idle == nil, string.format("rig %q has two looping sequences - cannot tell which is the idle", weapon))
				idle = descendant
			else
				assert(reload == nil, string.format("rig %q has two one-shot sequences - cannot tell which is the reload", weapon))
				reload = descendant
			end
		end
	end

	local source = idle or reload
	assert(source, string.format("rig %q has no animation to take a rest pose from", weapon))

	local earliest = nil
	for _, keyframe in source:GetChildren() do
		if keyframe.ClassName == "Keyframe" then
			if earliest == nil or keyframe.Time < earliest.Time then
				earliest = keyframe
			end
		end
	end
	assert(earliest, string.format("rig %q sequence %q has no keyframes", weapon, source.Name))

	-- A Pose named X drives the Motor6D whose Part1 is the part named X - that is exactly
	-- how the animator applies it, so storing it per part name composes identically.
	local restPose = roblox.Instance.new("Folder")
	restPose.Name = "RestPose"
	local posed = 0
	for _, pose in earliest:GetDescendants() do
		if pose.ClassName == "Pose" then
			local value = roblox.Instance.new("CFrameValue")
			value.Name = pose.Name
			value.Value = pose.CFrame
			value.Parent = restPose
			posed += 1
		end
	end
	restPose.Parent = rig

	-- Tag the gun joints so the runtime can drive the magazine and trigger by role, and
	-- record which way is "down" and "back" for each one.
	--
	-- A Motor6D places its part at Part0.CFrame * C0 * Transform * C1:Inverse(), so a
	-- translation in Transform moves along the joint's own axes - and these joints were
	-- hand-built with C0 rotations that differ per gun and per part. Translating -Y in
	-- joint space drops the magazine straight down on one rig and slides it sideways
	-- through the receiver on the next. Resolving the axes here, against the pose the rig
	-- was authored in, is what makes "the magazine falls out" mean the same thing on all
	-- six.
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	assert(hrp, string.format("rig %q has no HumanoidRootPart", weapon))
	local worldDown = roblox.Vector3.new(0, -1, 0)
	local worldBack = -hrp.CFrame.LookVector

	local roles = {}
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == "Motor6D" and descendant.Part1 and descendant.Part0 then
			local role = roleFor(descendant.Part1.Name)
			if role then
				descendant:SetAttribute("VMRole", role)

				local jointFrame = descendant.Part0.CFrame * descendant.C0
				descendant:SetAttribute("VMDownAxis", jointFrame:VectorToObjectSpace(worldDown))
				descendant:SetAttribute("VMBackAxis", jointFrame:VectorToObjectSpace(worldBack))

				roles[role] = (roles[role] or 0) + 1
			end
		end
	end

	-- The clips have served their purpose. Dropping them keeps ~200KB of keyframe data out
	-- of every client's ReplicatedStorage; fsafs.rbxm still holds the originals.
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == "KeyframeSequence" then
			descendant:Destroy()
		end
	end
	local animSaves = rig:FindFirstChild("AnimSaves")
	if animSaves then
		animSaves:Destroy()
	end

	-- The Humanoid goes here as well as at runtime. A Model with one, parented under
	-- Workspace, is a character to the engine: it manages CanCollide on the limbs itself,
	-- and this rig's anchored root sits inside the player's torso, so one collidable limb
	-- launches them across the map. Nothing needs it now that no clips are played.
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == "Humanoid" or descendant.ClassName == "Animator"
			or descendant.ClassName == "HumanoidDescription" then
			descendant:Destroy()
		end
	end

	-- Ship the asset already inert, so a rig dragged in by hand behaves too.
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = false
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
		end
	end

	-- Every part has to hang off the anchored root through some joint. An unreachable one
	-- is unanchored, massless and non-collidable, so it does not throw anybody - it just
	-- silently falls out of the gun and through the floor the moment you equip.
	local reachable = { [hrp] = true }
	local changed = true
	while changed do
		changed = false
		for _, descendant in rig:GetDescendants() do
			local p0, p1 = nil, nil
			if descendant:IsA("JointInstance") then
				p0, p1 = descendant.Part0, descendant.Part1
			elseif descendant.ClassName == "WeldConstraint" then
				p0, p1 = descendant.Part0, descendant.Part1
			end
			if p0 and p1 then
				if reachable[p0] and not reachable[p1] then
					reachable[p1] = true
					changed = true
				elseif reachable[p1] and not reachable[p0] then
					reachable[p0] = true
					changed = true
				end
			end
		end
	end

	local orphans = {}
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") and not reachable[descendant] then
			table.insert(orphans, descendant.Name)
		end
	end
	assert(#orphans == 0, string.format(
		"rig %q has parts jointed to nothing - they will fall off on equip: %s",
		weapon, table.concat(orphans, ", ")))

	rig.Name = weapon
	rig.Parent = folder

	local roleList = {}
	for role, count in roles do
		table.insert(roleList, string.format("%s x%d", role, count))
	end
	table.sort(roleList)
	table.insert(report, string.format("  %-8s (%-8s) rest pose from %s, %d joints posed | tagged: %s",
		weapon, gunModel.Name, idle and "idle" or "reload", posed,
		#roleList > 0 and table.concat(roleList, ", ") or "none"))
end

fs.writeFile(OUTPUT, roblox.serializeModel({ folder }))

print("Packaged " .. #folder:GetChildren() .. " viewmodel rigs -> " .. OUTPUT)
table.sort(report)
print(table.concat(report, "\n"))
