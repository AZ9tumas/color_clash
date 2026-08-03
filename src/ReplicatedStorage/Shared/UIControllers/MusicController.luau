local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SettingsController = require(Shared.UIControllers.SettingsController)

local MusicController = {}

local player = Players.LocalPlayer
local FADE_TIME = 1.5

local currentName = nil

-- Master and Music sliders both apply. GetValue falls back to the config default when a
-- slider has never been touched, but guard the type anyway: unknown names return false.
local function settingScale()
	local master = SettingsController.GetValue("Master Volume")
	local music = SettingsController.GetValue("Music Volume")
	master = (type(master) == "number" and master or 100) / 100
	music = (type(music) == "number" and music or 100) / 100
	return master * music
end

-- The authored Studio volume is the mix ceiling; fades and sliders scale under it. It has
-- to be captured once, because the fades below mutate Sound.Volume directly.
local function baseVolume(sound)
	local base = sound:GetAttribute("BaseVolume")
	if base == nil then
		base = sound.Volume
		sound:SetAttribute("BaseVolume", base)
	end
	return base
end

-- Track choice is driven by replicated state only, so it needs no remotes:
--   main menu            -> Lobby
--   Shoot phase          -> Action (spectators hear the action too, by design)
--   anything else        -> Calm (tile-picking, lobby area between rounds)
local function desiredTrack()
	if player:GetAttribute("InMenu") ~= false then
		return "Lobby"
	end
	if Workspace:GetAttribute("ArenaPhase") == "Shoot" then
		return "Action"
	end
	return "Calm"
end

local function setTrack(name)
	local folder = SoundService:FindFirstChild("Music")
	if not folder then return end

	local target = folder:FindFirstChild(name)
	if not target then
		-- A missing track degrades to whichever exists rather than going silent.
		for _, alt in {"Calm", "Lobby", "Action"} do
			target = folder:FindFirstChild(alt)
			if target then
				name = alt
				break
			end
		end
	end
	if not target or name == currentName then return end
	currentName = name

	for _, sound in folder:GetChildren() do
		if sound:IsA("Sound") then
			if sound == target then
				-- Capture the authored volume BEFORE zeroing for the fade-in, or the
				-- base gets stamped as 0 and the track fades to silence forever.
				local fullVolume = baseVolume(sound) * settingScale()
				if not sound.IsPlaying then
					sound.Volume = 0
					sound:Play()
				end
				TweenService:Create(sound, TweenInfo.new(FADE_TIME), {
					Volume = fullVolume,
				}):Play()
			elseif sound.IsPlaying then
				local fade = TweenService:Create(sound, TweenInfo.new(FADE_TIME), {Volume = 0})
				fade:Play()
				fade.Completed:Connect(function()
					if currentName ~= sound.Name and sound.Volume < 0.01 then sound:Stop() end
				end)
			end
		end
	end
end

function MusicController.Init()
	Workspace:GetAttributeChangedSignal("ArenaPhase"):Connect(function()
		setTrack(desiredTrack())
	end)
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		setTrack(desiredTrack())
	end)

	setTrack(desiredTrack())

	-- Volume sliders have no change signal exposed, so follow them with the same 1s poll
	-- the rest of the UI layer uses. Retweening to an unchanged target is a no-op visually.
	task.spawn(function()
		while true do
			task.wait(1)
			local folder = SoundService:FindFirstChild("Music")
			local sound = folder and currentName and folder:FindFirstChild(currentName)
			if sound and sound.IsPlaying then
				local want = baseVolume(sound) * settingScale()
				if math.abs(sound.Volume - want) > 0.005 then
					TweenService:Create(sound, TweenInfo.new(0.3), {Volume = want}):Play()
				end
			end
		end
	end)
end

return MusicController
