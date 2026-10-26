local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local Shared = game:GetService("ReplicatedStorage").Shared
local FXConfig = require(Shared.Modules.Core.FXConfig)
local SettingsController = require(Shared.UIControllers.SettingsController)

local Audio = {}
Audio.__index = Audio

local function sourceFor(tool)
	local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true))
	local sound = handle and handle:FindFirstChild("FireSFX")
	return sound and sound:IsA("Sound") and sound.SoundId ~= "" and sound or nil
end

local function playShot(template, parent, spatial)
	local config = FXConfig.LocalGunAudio
	local master = SettingsController.GetValue("Master Volume")
	local sfx = SettingsController.GetValue("SFX Volume")
	local volume = (type(master) == "number" and master / 100 or 1)
		* (type(sfx) == "number" and sfx / 100 or 1) * config.Volume
	-- Exactly one voice per cartridge. Let its natural decay overlap the next shot.
	local sound = template:Clone()
	sound.Name = spatial and "RemoteFireSFX" or "LocalFireSFX"
	sound:Stop()
	sound.Looped = false
	sound.PlayOnRemove = false
	sound.TimePosition = template:GetAttribute("ShotStartTime") or 0
	local variation = config.Enabled and config.PitchVariation or 0
	sound.PlaybackSpeed = template.PlaybackSpeed * (1 + (math.random() * 2 - 1) * variation)
	sound.Volume = template.Volume * volume
	if config.Enabled and not spatial and not sound:FindFirstChildOfClass("EqualizerSoundEffect") then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain, eq.MidGain, eq.HighGain = config.LowGain, config.MidGain, config.HighGain
		eq.Parent = sound
	end
	sound.Parent = parent
	local cleanup = spatial and parent or sound
	sound.Ended:Once(function() cleanup:Destroy() end)
	Debris:AddItem(cleanup, math.clamp(template.TimeLength / math.max(sound.PlaybackSpeed, 0.1) + 2, 5, 15))
	sound:Play()
	return sound
end

function Audio.Preload()
	task.spawn(function()
		local sounds = {}
		for _, tool in Shared.Assets.Weapons:GetChildren() do
			local source = sourceFor(tool)
			if source then table.insert(sounds, source) end
		end
		pcall(function() ContentProvider:PreloadAsync(sounds) end)
	end)
end

function Audio.new(tool, _properties)
	local source = sourceFor(tool)
	local template = source and source:Clone()
	if template then template:Stop() end
	return setmetatable({template = template, destroyed = false}, Audio)
end

function Audio:Play()
	if self.destroyed or not self.template then return end
	return playShot(self.template, SoundService, false)
end

function Audio.PlayRemote(weaponName, position)
	if type(weaponName) ~= "string" or typeof(position) ~= "Vector3" then return end
	local source = sourceFor(Shared.Assets.Weapons:FindFirstChild(weaponName))
	if not source then return end
	local camera = workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > source.RollOffMaxDistance then return end
	local emitter = Instance.new("Part")
	emitter.Name = "GunShotEmitter"
	emitter.Size = Vector3.new(0.01, 0.01, 0.01)
	emitter.Transparency = 1
	emitter.Anchored = true
	emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = false, false, false
	emitter.Position = position
	emitter.Parent = workspace
	return playShot(source, emitter, true)
end

function Audio:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	if self.template then self.template:Destroy(); self.template = nil end
end

return Audio
