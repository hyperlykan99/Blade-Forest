-- RollService: FREE weapon rolls from the HUD (Sol's RNG style).
-- Every weapon has its own "1 in X". Luck divides X (rarer tiers feel it less: luck^gamma).
-- Every 10th roll = 2x luck (capped).
-- M1.5: rolls happen at an ISLAND ALTAR. The pool is that island's weapons plus the
-- islands before it (Economy.AltarPool). The altar is the player's choice among unlocked
-- islands (default: the highest). Odds shown to players are Economy.AltarOdds, computed
-- from the same pool and luck the server uses. Rolls cost nothing (no paid random items).
-- Progression guarantee: after N rolls at an altar without reaching the next island's
-- gate Power, the roll becomes the configured gate weapon once (RNG can't block an island).
-- Huge pulls are announced to the server (1 in 100K+) and to every server (1 in 1M+).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Economy = require(ReplicatedStorage:WaitForChild("Economy"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Telemetry = require(script.Parent:WaitForChild("EconomyTelemetry"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollRemote = Remotes:WaitForChild("Roll")
local NotifyRemote = Remotes:WaitForChild("Notify")

local rng = Random.new()
local lastRoll = {}
local GLOBAL_TOPIC = "BladeForest_BigPull"

-- M1: LuckMult already includes events / potions (strongest only) and the cap
local function getLuck(player)
	return player:GetAttribute("LuckMult") or 1
end

-- the altar a player rolls at: chosen unlocked island, else the highest unlocked one
local function altarOf(d)
	local chosen = d.Settings and d.Settings.Altar
	if type(chosen) == "string" and d.UnlockedIslands[chosen] and Config.Economy.Altars[chosen] then return chosen end
	return (Economy.HighestIsland(d.UnlockedIslands))
end

local function rollOnce(player)
	local d = DataService.Get(player)
	d.Rolls.Total += 1
	local lucky = d.Rolls.Total % Config.LuckyRollEvery == 0
	local luck = Economy.RollLuck(getLuck(player), lucky)
	local altar = altarOf(d)
	local weapon = Economy.RollAltar(rng, altar, luck)
	-- progression guarantee (once per altar)
	d.AltarRolls[altar] = (d.AltarRolls[altar] or 0) + 1
	local g = Config.Economy.Altars[altar].Guarantee
	local guaranteed = false
	if g and not d.AltarGuarantee[altar] and d.AltarRolls[altar] >= g.Rolls and DataService.BestPower(d) < g.UntilPower then
		local gw = Config.WeaponById[g.Weapon]
		if gw and Config.GetWeaponPower(gw.Id, 0) > Config.GetWeaponPower(weapon.Id, 0) then
			weapon = gw
			guaranteed = true
		end
		d.AltarGuarantee[altar] = true
	end

	local result = DataService.AddWeapon(player, weapon.Id, d.Settings.AutoSellBelow)
	result.Rarity = weapon.Rarity
	result.OneIn = weapon.OneIn
	result.Lucky = lucky
	result.RollNumber = d.Rolls.Total
	result.Luck = luck
	result.Altar = altar
	result.Guaranteed = guaranteed
	if guaranteed then
		NotifyRemote:FireClient(player, string.format("🛡 Progression guarantee: %s! (%s altar, %d rolls)", weapon.Name,
			Config.IslandById[altar] and Config.IslandById[altar].Name or altar, d.AltarRolls[altar]), "rare_" .. weapon.Rarity)
	end

	-- stats
	if weapon.OneIn > (d.Stats.RarestOneIn or 0) then
		d.Stats.RarestOneIn = weapon.OneIn
		d.Stats.RarestId = weapon.Id
		result.NewBest = true
	end
	Progress.Add(player, "Rolls", 1)
	Telemetry.Roll(player, weapon.Rarity)
	if Config.RarityById[weapon.Rarity].Order >= Config.RarityById.Epic.Order then
		Progress.Add(player, "RarePull", 1)
	end

	-- announcements
	if weapon.OneIn >= Config.AnnounceGlobal then
		pcall(function()
			MessagingService:PublishAsync(GLOBAL_TOPIC, { Name = player.DisplayName, Weapon = weapon.Id, JobId = game.JobId })
		end)
	end
	if weapon.OneIn >= Config.AnnounceServer then
		NotifyRemote:FireAllClients(string.format("%s rolled %s [%s] (%s)!", player.DisplayName, weapon.Name, weapon.Rarity,
			Config.FormatOneIn(weapon.OneIn)), "rare_" .. weapon.Rarity)
	end
	return result
end

-- Roll() -> ok, result | ok=false, reason
-- Roll("SetAltar", islandId) -> ok, altar   (only unlocked islands)
RollRemote.OnServerInvoke = function(player, action, arg)
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	if action == "SetAltar" then
		if type(arg) ~= "string" or not d.UnlockedIslands[arg] or not Config.Economy.Altars[arg] then return false, "Locked" end
		d.Settings.Altar = arg
		player:SetAttribute("Altar", arg)
		DataService.Sync(player)
		return true, arg
	elseif action ~= nil then
		return false, "?"
	end
	local interval = player:GetAttribute("Pass_FastRoll") and Config.FastRollInterval or Config.RollInterval
	if os.clock() - (lastRoll[player] or 0) < interval * 0.85 then return false, "cooldown" end
	lastRoll[player] = os.clock()
	return true, rollOnce(player)
end

Players.PlayerRemoving:Connect(function(p) lastRoll[p] = nil end)

-- big pulls from other servers
pcall(function()
	MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(msg)
		local data = msg.Data
		if type(data) ~= "table" or data.JobId == game.JobId then return end
		local w = Config.WeaponById[data.Weapon]
		if not w then return end
		NotifyRemote:FireAllClients(string.format("[GLOBAL] %s rolled %s (%s)!", tostring(data.Name), w.Name, Config.FormatOneIn(w.OneIn)),
			"rare_" .. w.Rarity)
	end)
end)
