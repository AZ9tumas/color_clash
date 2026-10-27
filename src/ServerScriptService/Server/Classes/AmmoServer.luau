-- The server's copy of every gun's magazine, so a client cannot fire rounds it
-- never loaded. Keyed by Tool instance: a freshly granted gun starts full, just
-- like the client's GunHandler. Reloads are timed here from the client's request.
-- Swapping away does not cancel one on the server, which can only leave the
-- server slightly more generous than the client, never stricter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Modules.Core.CombatConfig)

local AmmoServer = {}

-- The reload request and the first shot after it each cross the network, so
-- allow some jitter between them.
local RELOAD_GRACE = 0.2

-- A plain table, cleared when the tool is destroyed. Weak keys would not work:
-- Roblox can collect an Instance's Lua handle while the Instance still exists,
-- which would silently refill the magazine.
local magazines = {}

local function magazineFor(tool: Tool, data)
	local magazine = magazines[tool]
	if not magazine then
		magazine = { ammo = data.MaxAmmo, reloadStartedAt = nil, ammoAtReloadStart = 0 }
		magazines[tool] = magazine
		tool.Destroying:Once(function()
			magazines[tool] = nil
		end)
	end
	return magazine
end

-- Applies whatever the running reload has loaded by `now`.
local function settle(magazine, data, now: number)
	local startedAt = magazine.reloadStartedAt
	if not startedAt then return end

	local duration = math.max(magazine.reloadDuration or data.ReloadTime or 2, 0.05)
	local elapsed = now - startedAt + RELOAD_GRACE
	if data.ReloadPerShell then
		local loaded = math.floor(elapsed / duration)
		magazine.ammo = math.min(data.MaxAmmo, magazine.ammoAtReloadStart + loaded)
	elseif elapsed >= duration then
		magazine.ammo = data.MaxAmmo
	end

	if magazine.ammo >= data.MaxAmmo then
		magazine.reloadStartedAt = nil
	end
end

function AmmoServer.StartReload(tool: Tool, data)
	local now = os.clock()
	local magazine = magazineFor(tool, data)
	settle(magazine, data, now)
	if magazine.reloadStartedAt or magazine.ammo >= data.MaxAmmo then return end

	magazine.reloadStartedAt = now
	magazine.ammoAtReloadStart = magazine.ammo
	-- Same rule as the client's GunHandler: under GunHandling a magazine reload
	-- with rounds left in it uses the faster TacticalReloadTime.
	local handling = data.Handling
	if CombatConfig.IsEnabled("GunHandling") and handling and handling.TacticalReloadTime
		and not data.ReloadPerShell and magazine.ammo > 0 then
		magazine.reloadDuration = handling.TacticalReloadTime
	else
		magazine.reloadDuration = data.ReloadTime or 2
	end
end

-- Takes one round for a shot. Returns false and the rounds left when the
-- magazine is empty.
function AmmoServer.TryConsume(tool: Tool, data): (boolean, number)
	local magazine = magazineFor(tool, data)
	settle(magazine, data, os.clock())

	-- The client only fires mid-reload once it has cancelled it (swapping away
	-- and back), so a shot ends any reload with whatever it had loaded.
	magazine.reloadStartedAt = nil

	if magazine.ammo <= 0 then
		return false, 0
	end
	magazine.ammo -= 1
	return true, magazine.ammo
end

function AmmoServer.Get(tool: Tool, data): number
	local magazine = magazineFor(tool, data)
	settle(magazine, data, os.clock())
	return magazine.ammo
end

return AmmoServer
