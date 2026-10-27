local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local ChestConfig = require(Shared.Modules.Core.ChestConfig)
local ChestRemotes = require(Shared.Remotes.ChestRemotes)
local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)
local CurrencyServer = require(ServerScriptService.Server.Services.CurrencyService.CurrencyServer)

-- Daily chests: each player can open each chest in Workspace.Chests once every
-- ChestConfig.Cooldown seconds (24 hours) for some coins. When they last opened
-- each chest is saved in their profile (Data.Chests), so the timer carries over
-- between servers and rejoins. ChestClient shows each player their own state.
local ChestServer = {}

local chestsFolder = nil
local busy = {} -- [Player] = true while an open is being processed

local function chestId(chest: Model): string
	return chest:GetAttribute("ChestId") or chest.Name
end

local function openedTimes(player: Player)
	local profile = DataServer.GetProfile(player)
	if not profile then return nil end
	if type(profile.Data.Chests) ~= "table" then
		profile.Data.Chests = {}
	end
	return profile.Data.Chests
end

local function secondsLeft(times, id: string): number
	local last = times[id]
	if type(last) ~= "number" then return 0 end
	return math.max(0, last + ChestConfig.Cooldown - os.time())
end

function ChestServer.GetState(player: Player)
	local times = openedTimes(player)
	if not times or not chestsFolder then return nil end

	local state = {}
	for _, chest in chestsFolder:GetChildren() do
		if chest:IsA("Model") then
			local id = chestId(chest)
			state[id] = secondsLeft(times, id)
		end
	end
	return state
end

local function open(player: Player, chest: Model)
	if busy[player] then return end
	busy[player] = true

	local id = chestId(chest)
	local times = openedTimes(player)
	if times then
		local left = secondsLeft(times, id)
		if left > 0 then
			ChestRemotes.GetOpenedEvent():FireClient(player, { ChestId = id, SecondsLeft = left })
		else
			local settings = ChestConfig.For(id)
			local coins = math.random(settings.Min, settings.Max)
			times[id] = os.time()
			CurrencyServer.AddCash(player, coins)
			ChestRemotes.GetOpenedEvent():FireClient(player, {
				ChestId = id,
				Coins = coins,
				SecondsLeft = ChestConfig.Cooldown,
			})
		end
	end

	busy[player] = nil
end

function ChestServer.Init()
	ChestRemotes.GetStateFunction().OnServerInvoke = function(player)
		DataServer.WaitForProfile(player)
		return ChestServer.GetState(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	chestsFolder = Workspace:WaitForChild("Chests", 10)
	if not chestsFolder then return end

	for _, chest in ipairs(chestsFolder:GetChildren()) do
		if chest:IsA("Model") and chest.PrimaryPart then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ChestPrompt"
			prompt.ActionText = "Open Chest"
			prompt.ObjectText = ChestConfig.For(chestId(chest)).DisplayName
			prompt.HoldDuration = 1.25
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 12
			prompt.Parent = chest.PrimaryPart

			-- Per player: one player opening a chest must not lock it for anyone else.
			prompt.Triggered:Connect(function(player)
				open(player, chest)
			end)
		end
	end
end

return ChestServer
