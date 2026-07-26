local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpectateRemotes = require(Shared.Remotes.SpectateRemotes)

local SpectateMechanic = {}
SpectateMechanic.Spectators = {}

function SpectateMechanic.GetActive()
	local active = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("IsPlaying") then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then table.insert(active, p) end
		end
	end
	table.sort(active, function(a, b) return a.UserId < b.UserId end)
	return active
end

local function broadcast()
	local active = SpectateMechanic.GetActive()
	local update = SpectateRemotes.GetUpdateEvent()
	local watching, dropped = {}, {}

	for player, index in pairs(SpectateMechanic.Spectators) do
		local target = nil
		if player.Parent == Players and not player:GetAttribute("IsPlaying") then
			target = active[index]
		end

		if target then
			watching[player] = target
		else
			table.insert(dropped, player)
		end
	end

	for _, player in dropped do
		SpectateMechanic.Spectators[player] = nil
		if player.Parent == Players then update:FireClient(player, nil, 0) end
	end

	local count = 0
	for _ in pairs(watching) do count += 1 end

	for player, target in pairs(watching) do
		update:FireClient(player, target, count)
	end
end

function SpectateMechanic.Start(player)
	if player.Parent ~= Players then return end
	if player:GetAttribute("IsPlaying") then return end

	if #SpectateMechanic.GetActive() == 0 then
		SpectateRemotes.GetUpdateEvent():FireClient(player, nil, 0)
		return
	end

	SpectateMechanic.Spectators[player] = 1
	broadcast()
end

function SpectateMechanic.Stop(player)
	SpectateMechanic.Spectators[player] = nil
	if player.Parent == Players then
		SpectateRemotes.GetUpdateEvent():FireClient(player, nil, 0)
	end
	broadcast()
end

function SpectateMechanic.Cycle(player, delta)
	local index = SpectateMechanic.Spectators[player]
	if not index then return end

	local active = SpectateMechanic.GetActive()
	if #active > 0 then
		SpectateMechanic.Spectators[player] = ((index - 1 + delta) % #active) + 1
	end

	broadcast()
end

function SpectateMechanic.Refresh()
	local count = #SpectateMechanic.GetActive()
	for player, index in pairs(SpectateMechanic.Spectators) do
		if index > count then SpectateMechanic.Spectators[player] = 1 end
	end

	broadcast()
end

return SpectateMechanic
