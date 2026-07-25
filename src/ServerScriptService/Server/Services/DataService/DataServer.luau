local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DataTemplate = require(Shared.Modules.Core.DataTemplate)

local ServerPackages = ServerScriptService.Server.ServerPackages
local ProfileStore = require(ServerPackages.profilestore)
local signal = require(Shared.Packages.signal)

local DataServer = {}
DataServer.ProfileLoaded = signal.new()

local profileStore = ProfileStore.New("PlayerData_v2", DataTemplate)
local profiles = {}

local function PlayerAdded(player)
    local profileKey = "Player_" .. tostring(player.UserId)
    local profile = profileStore:StartSessionAsync(profileKey, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })

    if profile ~= nil then
        profile:AddUserId(player.UserId)
        profile.OnSessionEnd:Connect(function()
            profiles[player] = nil
            player:Kick("Your data profile session has ended. Please rejoin.")
        end)

        if player.Parent == Players then
            profiles[player] = profile
            DataServer.ProfileLoaded:Fire(player, profile)
        else
            profile:EndSession()
        end
    else
        player:Kick("Unable to load data profile. Please try rejoining.")
    end
end

function DataServer.Init()
    for _, player in Players:GetPlayers() do
        task.spawn(PlayerAdded, player)
    end
    Players.PlayerAdded:Connect(PlayerAdded)

    Players.PlayerRemoving:Connect(function(player)
        local profile = profiles[player]
        if profile then
            profile:EndSession()
        end
    end)
    
    game:BindToClose(function()
        for _, player in Players:GetPlayers() do
            local profile = profiles[player]
            if profile then
                profile:EndSession()
            end
        end
    end)
end

function DataServer.GetProfile(player)
    return profiles[player]
end

function DataServer.WaitForProfile(player)
    local profile = profiles[player]
    while not profile and player.Parent == Players do
        task.wait(0.1)
        profile = profiles[player]
    end
    return profile
end

function DataServer.GetData(player)
    local profile = profiles[player]
    if profile then
        return profile.Data
    end
    return nil
end

return DataServer