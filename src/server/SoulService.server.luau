-- SoulService: Soul Shop purchases (Souls come from NPC + PvP kills).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoulShop = Remotes:WaitForChild("SoulShop")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))

local lastBuy = {}

SoulShop.OnServerInvoke = function(player, itemId)
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	if os.clock() - (lastBuy[player] or 0) < 0.3 then return false, "Slow down" end
	lastBuy[player] = os.clock()

	local item = Config.SoulShopById[itemId]
	if not item then return false, "?" end
	if item.Kind == "Soon" then return false, "Coming soon!" end
	if item.Kind == "OpenTraits" then return false, "Open it at the Trait Crate" end
	if item.Kind == "Weapon" and d.Weapons[item.Weapon] then return false, "Already owned" end
	if item.Kind == "SoulUpgrade" then
		-- M1: permanent Soul upgrade, next level
		d.SoulUpgrades = d.SoulUpgrades or {}
		local lv = d.SoulUpgrades[item.Upgrade] or 0
		if lv >= item.MaxLevel then return false, "MAXED" end
		local cost = Config.GetSoulUpgradeCost(item.Upgrade, lv)
		if (d.Souls or 0) < cost then return false, string.format("Need %d more Souls", cost - (d.Souls or 0)) end
		if not DataService.SpendSouls(player, cost) then return false, "Not enough Souls" end
		d.SoulUpgrades[item.Upgrade] = lv + 1
		DataService.RecalcMultipliers(player)
		NotifyRemote:FireClient(player, string.format("%s level %d/%d!", item.Name, lv + 1, item.MaxLevel), "rare_Epic")
		DataService.Sync(player)
		return true
	end
	if (d.Souls or 0) < item.Cost then
		return false, string.format("Need %d more Souls", item.Cost - (d.Souls or 0))
	end
	if not DataService.SpendSouls(player, item.Cost) then return false, "Not enough Souls" end

	if item.Kind == "Boost" then
		DataService.AddBoost(player, item.Boost, item.Seconds)
		NotifyRemote:FireClient(player, string.format("%s active for %d min!", item.Name, item.Seconds // 60), "rare_Epic")
	elseif item.Kind == "Weapon" then
		DataService.AddWeapon(player, item.Weapon)
		local w = Config.WeaponById[item.Weapon]
		NotifyRemote:FireClient(player, string.format("You got the %s! Equip it in WEAPONS", w.Name), "rare_" .. w.Rarity)
		NotifyRemote:FireAllClients(string.format("%s bought the %s from the Soul Shop!", player.DisplayName, w.Name), "rare_" .. w.Rarity)
	end
	DataService.Sync(player)
	return true
end
