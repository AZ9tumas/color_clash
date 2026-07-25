local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)
local CurrencyServer = require(ServerScriptService.Server.Services.CurrencyService.CurrencyServer)
local ShopRemotes = require(Shared.Remotes.ShopRemotes)
local ShopConfig = require(Shared.Modules.Core.ShopConfig)

local ShopServer = {}

function ShopServer.Init()
	local function ensureDataSafety(profile)
		if type(profile.Data.Inventory) ~= "table" then
			profile.Data.Inventory = { Weapons = {}, Skins = {}, Effects = {} }
		end
		if type(profile.Data.Inventory.Weapons) ~= "table" then profile.Data.Inventory.Weapons = {} end
		
		profile.Data.Inventory.Weapons["Pistol"] = true
		profile.Data.Inventory.Weapons["Wooden Knife"] = true

		if type(profile.Data.Equipped) ~= "table" then
			profile.Data.Equipped = { Main = "Pistol", Melee = "Wooden Knife" }
		end
		
		if profile.Data.Equipped.Melee == "Knife" and not profile.Data.Inventory.Weapons["Knife"] then
			profile.Data.Equipped.Melee = "Wooden Knife"
		end
	end

	ShopRemotes.GetInventoryFunction().OnServerInvoke = function(player)
		local profile = DataServer.WaitForProfile(player)
		if profile then
			ensureDataSafety(profile)
			return { Inventory = profile.Data.Inventory, Equipped = profile.Data.Equipped }
		end
		return { 
			Inventory = {Weapons = {["Pistol"]=true, ["Wooden Knife"]=true}}, 
			Equipped = {Main = "Pistol", Melee = "Wooden Knife"} 
		}
	end

	ShopRemotes.GetBuyItemFunction().OnServerInvoke = function(player, category, itemName)
		local profile = DataServer.WaitForProfile(player)
		if not profile then return false end
		ensureDataSafety(profile)

		local categoryData = ShopConfig.Categories[category]
		if not categoryData then return false end

		local itemData = nil
		for _, item in ipairs(categoryData) do
			if item.Name == itemName then
				itemData = item; break
			end
		end

		if not itemData then return false end
		if not profile.Data.Inventory[category] then profile.Data.Inventory[category] = {} end
		if profile.Data.Inventory[category][itemName] then return false end

		if CurrencyServer.RemoveCash(player, itemData.Price) then
			profile.Data.Inventory[category][itemName] = true
			return true
		end
		return false
	end

	ShopRemotes.GetEquipItemFunction().OnServerInvoke = function(player, category, itemName)
		local profile = DataServer.WaitForProfile(player)
		if not profile then return false end
		ensureDataSafety(profile)

		if category == "Weapons" then
			if profile.Data.Inventory.Weapons[itemName] then
				local slot = "Main"
				for _, item in ipairs(ShopConfig.Categories.Weapons) do
					if item.Name == itemName then
						if item.Subcategory == "Melee" then slot = "Melee" end
						break
					end
				end
				profile.Data.Equipped[slot] = itemName
				return true, slot
			end
		end
		return false
	end
end

return ShopServer