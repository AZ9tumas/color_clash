local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	BuyItem = "RemoteFunction",
	GetInventory = "RemoteFunction",
	EquipItem = "RemoteFunction"
}

if isServer then
	for name, className in pairs(remoteNames) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
	end
end

local function getRemote(name)
	if isServer then
		return folder:FindFirstChild(name)
	else
		return folder:WaitForChild(name)
	end
end

function ShopRemotes.GetBuyItemFunction() return getRemote("BuyItem") end
function ShopRemotes.GetInventoryFunction() return getRemote("GetInventory") end
function ShopRemotes.GetEquipItemFunction() return getRemote("EquipItem") end

return ShopRemotes