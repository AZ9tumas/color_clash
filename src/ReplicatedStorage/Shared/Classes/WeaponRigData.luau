local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[RigData] " .. string.format(message, ...))
	end
end

-- Reads what the viewmodel needs straight out of the authored fsafs rigs sitting in
-- ReplicatedStorage. There is no build step and no packaged copy: the rigs in the place are
-- the source of truth, so re-exporting them is the whole update process.
--
-- Each rig is an R6 body with a weapon jointed onto it and the reload saved underneath as a
-- KeyframeSequence. Three things are pulled out of that:
--
--   Reload    the clip itself
--   RestPose  the opening frame, which is the ready pose - arms up, weapon held. Without it
--             an unanimated R6 rig hangs its arms at its sides.
--   Joints    the C0 of every weapon joint, so the viewmodel can rebuild the exact
--             arrangement the animation was posed against. This is what lets the clip drive
--             the magazine and trigger and not just the arms.
--
-- Everything is resolved once per weapon and cached; the rigs never change at runtime.
local WeaponRigData = {}

-- Keyed by the weapon Model inside each rig rather than the rig's own name: three of the
-- six rigs are all called "TemplateR6".
local WEAPON_BY_GUN_MODEL = {
	["P90"] = "SMG",
	["AR"] = "AR",
	["Pistol"] = "Pistol",
	["Scar"] = "Scar",
	["Shotgun"] = "Shotgun",
	["Sniper"] = "Sniper",
}

-- Joints that every R6 character already has. The viewmodel inherits these from the cloned
-- character and must not have them rebuilt underneath it.
local function isBodyPart(name)
	return name == "Torso" or name == "Head"
		or string.find(name, "Arm") ~= nil
		or string.find(name, "Leg") ~= nil
end

local cache = {}
local scanned = false

local function gunModelOf(rig)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Model") then
			return descendant
		end
	end
	return nil
end

-- The rigs may sit in a container named after the file or be dropped straight into
-- ReplicatedStorage, so both are searched rather than assuming one.
local function candidateRoots()
	local roots = {}

	for _, name in { "fsafs", "Viewmodels", "WeaponRigs" } do
		local container = ReplicatedStorage:FindFirstChild(name)
		if container then
			table.insert(roots, container)
		end
	end
	table.insert(roots, ReplicatedStorage)

	return roots
end

local function scan()
	if scanned then return end
	scanned = true

	local found = {}
	for _, root in candidateRoots() do
		for _, child in root:GetChildren() do
			if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
				local gun = gunModelOf(child)
				local weapon = gun and WEAPON_BY_GUN_MODEL[gun.Name]
				if weapon and not found[weapon] then
					found[weapon] = child
				end
			end
		end
	end

	for weapon, rig in found do
		cache[weapon] = { rig = rig }
	end

	local names = {}
	for weapon in found do
		table.insert(names, weapon)
	end
	table.sort(names)

	if #names == 0 then
		warn("[RigData] no authored weapon rigs found in ReplicatedStorage - the viewmodel will have nothing to hold. Expected the fsafs rigs, each an R6 model containing its weapon.")
	else
		log("rigs found: %s", table.concat(names, ", "))
	end
end

local function resolve(weaponName)
	scan()

	local entry = cache[weaponName]
	if not entry then return nil end
	if entry.resolved then return entry end
	entry.resolved = true

	local rig = entry.rig
	-- The weapon model the animation was actually authored against. The Tool in
	-- Assets.Weapons is a DIFFERENT model with different part names - the SMG tool has no
	-- "Mag" at all - so jointing that one leaves the magazine unanimated.
	entry.gunModel = gunModelOf(rig)

	-- The longest clip is the finished reload; a shorter save is a partial pass.
	local best, bestLength = nil, -1
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("KeyframeSequence") then
			local length = 0
			for _, keyframe in descendant:GetChildren() do
				if keyframe:IsA("Keyframe") then
					length = math.max(length, keyframe.Time)
				end
			end
			if length > bestLength then
				best, bestLength = descendant, length
			end
		end
	end
	entry.reload = best
	entry.reloadLength = bestLength

	-- Opening frame as the static ready pose.
	entry.restPose = {}
	if best then
		local earliest = nil
		for _, keyframe in best:GetChildren() do
			if keyframe:IsA("Keyframe") then
				if earliest == nil or keyframe.Time < earliest.Time then
					earliest = keyframe
				end
			end
		end
		if earliest then
			for _, pose in earliest:GetDescendants() do
				if pose:IsA("Pose") then
					entry.restPose[pose.Name] = pose.CFrame
				end
			end
		end
	end

	-- Weapon joints only, with the C0 the animation was authored against.
	entry.joints = {}
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
			if not isBodyPart(descendant.Part1.Name) then
				table.insert(entry.joints, {
					JointName = descendant.Name,
					Part0 = descendant.Part0.Name,
					Part1 = descendant.Part1.Name,
					C0 = descendant.C0,
					C1 = descendant.C1,
				})
			end
		end
	end

	log("%s: %.2fs reload, %d weapon joint(s)", weaponName, bestLength, #entry.joints)
	return entry
end

-- Returns the rig entry for a weapon, or nil if this weapon has no authored rig.
function WeaponRigData.Get(weaponName)
	return resolve(weaponName)
end

return WeaponRigData
