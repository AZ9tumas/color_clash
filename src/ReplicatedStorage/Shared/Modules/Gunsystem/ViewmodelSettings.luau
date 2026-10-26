-- Central configuration for the first-person viewmodel.
-- Per-Tool reload Animation instances remain on their respective Tool assets.
return {
	--[[
	-- As of now, CFrame.new(0, -1.5, 0) as shown to be the
	-- perfect offset for the viewmodel (no character meshes).
	--
	-- For melee, viewmodel offset is CFrame.identity
	--]]
	PositionOffset = CFrame.new(0, -1.5, 0), --CFrame.new(-0.0213599205, -1.33662224, -1.63064575), -- CFrame.new(0, -1, -1),
	SpringsEnabled = false, -- recommended to remain false.
	AnimationsEnabled = true,

	-- Clone WeaponViewmodelData.<Weapon>.WeaponModel for the viewmodel instead of
	-- the Tool. The Tool is authored for the character's hand: its parts sit on a
	-- different axis from the joints, it can be missing parts the sequences drive
	-- (the SMG has no Mag at all), and its internal welds bind every part rigidly
	-- to the Handle, which silently overrides the authored motors. Set false to go
	-- back to cloning the Tool.
	-- OFF: the authored WeaponModels are joint-authoring proxies, not the shipping
	-- visuals - they lack the Tool's meshes/textures, so the viewmodel renders as
	-- untextured blocks. Do not turn this on without fixing the visuals first.
	UseAuthoredWeaponModel = false,

	-- Build weapon joints from ReplicatedStorage.WeaponViewmodelData.<Weapon>.Joints
	-- so the authored reload sequences can drive the magazine, trigger and shells.
	-- Set false to fall back to the single GunGrip motor on RightGripAttachment.
	UseAuthoredJoints = true,

	-- The looped ViewmodelLoad pose below. It was authored against the old
	-- three-part rig, so it only shows through on joints no weapon track poses.
	-- Set false if it fights the authored Hold pose on the current rig.
	BaseAnimationEnabled = true,

	-- Set false to use the rig's built-in arm meshes without cloning the
	-- player's R6 CharacterMesh objects into the viewmodel.
	ShowCharacterMeshes = false, -- "true" will definitely break on some characters

	-- Print every track that starts or stops on the VIEWMODEL's own Animator.
	-- Scoped to the viewmodel rig by construction, so the real character's
	-- animations never appear in these logs.
	LogAnimations = true,

	-- Every other gun-system diagnostic - joint building, grip placement, reload
	-- sources, missing metadata - is gated on this. Off so the animation logs
	-- above are the only thing that reaches the console.
	Verbose = true,

	-- Procedural motion on top of the animations: recoil kick, look sway, movement
	-- bob, landing dip. Kick values scale with each weapon's Items.Recoil numbers.
	-- Set MotionEnabled false to glue the gun rigidly to the camera again.
	MotionEnabled = true,
	Motion = {
		Pivot = Vector3.new(0.5, -0.6, -1.2), -- camera-space point the gun rotates about

		-- recoil kick (per unit of Items.Recoil.Pitch / Yaw)
		KickFrequency = 9, KickDamping = 0.6,
		KickBack = 4.4, KickUp = 1.2, KickSide = 0.6,
		KickPitch = 1.7, KickYaw = 0.9, KickRoll = 0.7,
		KickMaxMove = Vector3.new(0.15, 0.15, 0.6),
		KickMaxTurn = Vector3.new(0.35, 0.15, 0.2),
		AimKickScale = 0.55,

		-- look sway
		SwayFrequency = 6, SwayDamping = 0.85,
		SwayTurn = 0.02, SwayMaxTurn = Vector3.new(0.12, 0.12, 0.08),
		SwayShift = 0.03, SwayMaxShift = Vector3.new(0.12, 0.08, 0),
		AimSwayScale = 0.35,

		-- movement bob
		BobFrequency = 1.8, BobReferenceSpeed = 16, BobBlend = 10,
		BobSide = 0.035, BobVertical = 0.03, BobRoll = 0.012,
		SprintBobScale = 1.4, SprintBobRate = 1.3, AimBobScale = 0.25,

		-- landing dip
		LandFrequency = 6, LandDamping = 0.55, LandKick = 0.25, LandMaxFallSpeed = 60,

		-- idle breath
		BreathRate = 0.25, BreathAmount = 0.008,
	},

	AnimationIds = {
		ViewmodelLoad = "rbxassetid://79466363432702",
		WeaponAction = "rbxassetid://83198374002696",

		-- The main melee hold. This is the pose that drives the melee viewmodel:
		-- the per-weapon Idle/Walk/Sprint set is deliberately NOT loaded onto the
		-- viewmodel so nothing can mask it. The weapon must have a Handle.
		MeleeHold = "rbxassetid://85046073154659",
	},
}
