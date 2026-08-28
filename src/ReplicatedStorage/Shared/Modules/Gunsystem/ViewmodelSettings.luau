-- Central configuration for the first-person viewmodel.
-- Per-Tool reload Animation instances remain on their respective Tool assets.
return {
	PositionOffset = CFrame.new(-0.0213599205, -1.33662224, -1.63064575), -- CFrame.new(0, -1, -1),
	SpringsEnabled = false,
	AnimationsEnabled = true,

	-- Set false to use the rig's built-in arm meshes without cloning the
	-- player's R6 CharacterMesh objects into the viewmodel.
	ShowCharacterMeshes = false,

	AnimationIds = {
		ViewmodelLoad = "rbxassetid://79466363432702",
		WeaponAction = "rbxassetid://83198374002696",
	},
}
