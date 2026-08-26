local Types = {}

export type RigAnimationIds = {
	R6: string,
	R15: string,
}

export type WeaponAnimations = {
	Swing: RigAnimationIds?,
	Shoot: string?,
	Reload: string?,
	Idle: string?,
	Walk: string?,
	Sprint: string?,
	Hold: string?,
	Equip: string?,
}

export type ShakeConfig = {
	Intensity: number,
	Decay: number,
}

export type RecoilConfig = {
	Pitch: number,
	Yaw: number,
}

export type AimConfig = {
	FOV: number,
	SpreadMultiplier: number,
}

export type ViewmodelConfig = {
	Offset: Vector3?,
}

export type WeaponDefinition = {
	Damage: number,
	Cooldown: number,
	Grip: CFrame,
	Shake: ShakeConfig,
	Animations: WeaponAnimations,
	Range: number?,
	MaxAmmo: number?,
	ReloadTime: number?,
	ReloadPerShell: boolean?,
	Spread: number?,
	Pellets: number?,
	AutoFire: boolean?,
	Recoil: RecoilConfig?,
	Aim: AimConfig?,
	Viewmodel: ViewmodelConfig?,
}

export type GunDefinition = WeaponDefinition & {
	Range: number,
	MaxAmmo: number,
	ReloadTime: number,
	Spread: number,
	Recoil: RecoilConfig,
	Aim: AimConfig,
}

export type WeaponCatalog = {
	[string]: WeaponDefinition,
}

export type AnimationTrackSet = {
	[string]: AnimationTrack,
}

export type WeaponController = {
	isEquipped: boolean,
	Equip: (self: WeaponController) -> (),
	Unequip: (self: WeaponController) -> (),
	Destroy: (self: WeaponController) -> (),
	shoot: ((self: WeaponController) -> ())?,
	stopShoot: ((self: WeaponController) -> ())?,
	Swing: ((self: WeaponController) -> ())?,
	ADS: ((self: WeaponController) -> ())?,
	stopADS: ((self: WeaponController) -> ())?,
	Reload: ((self: WeaponController) -> ())?,
}

export type PendingRootFollower = {
	config: Instance,
	part: BasePart,
	relative: CFrame,
}

export type RootFollower = {
	motor: Motor6D,
	relative: CFrame,
}

return Types
