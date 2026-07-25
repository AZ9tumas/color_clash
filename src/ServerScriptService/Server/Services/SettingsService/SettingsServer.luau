local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)
local SettingsRemotes = require(Shared.Remotes.SettingsRemotes)
local SettingsConfig = require(Shared.Modules.Core.SettingsConfig)

local SettingsServer = {}

function SettingsServer.Init()
	SettingsRemotes.GetSettingsFunction().OnServerInvoke = function(player)
		local profile = DataServer.WaitForProfile(player)
		if profile then
			if type(profile.Data.Settings) ~= "table" then
				profile.Data.Settings = {}
			end
			return profile.Data.Settings
		end
		return {}
	end

	SettingsRemotes.GetUpdateSettingEvent().OnServerEvent:Connect(function(player, settingName, value)
		local profile = DataServer.GetProfile(player)
		if not profile then return end

		if type(profile.Data.Settings) ~= "table" then
			profile.Data.Settings = {}
		end

		local isValid = false
		for _, categoryData in pairs(SettingsConfig.Categories) do
			for _, section in ipairs(categoryData) do
				for _, setting in ipairs(section.Settings) do
					if setting.Name == settingName then
						isValid = true
						break
					end
				end
				if isValid then break end
			end
			if isValid then break end
		end

		if isValid then
			profile.Data.Settings[settingName] = value
		end
	end)
end

return SettingsServer