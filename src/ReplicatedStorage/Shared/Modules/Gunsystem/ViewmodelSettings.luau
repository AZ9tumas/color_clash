-- Central configuration for the first-person viewmodel.
-- Per-Tool reload Animation instances remain on their respective Tool assets.
return {
	PositionOffset = CFrame.new(0, -1.5, 0), --CFrame.new(-0.0213599205, -1.33662224, -1.63064575), -- CFrame.new(0, -1, -1),
	SpringsEnabled = false,
	AnimationsEnabled = true,

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
	ShowCharacterMeshes = false,

	AnimationIds = {
		ViewmodelLoad = "rbxassetid://79466363432702",
		WeaponAction = "rbxassetid://83198374002696",
	},
}
