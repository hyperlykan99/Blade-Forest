-- RollService: FREE weapon rolls from the HUD (Sol's RNG style).
-- Every weapon has its own "1 in X". Luck divides X. Every 10th roll = 2x luck.
-- Huge pulls are announced to the server (1 in 100K+) and to every server (1 in 1M+).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollRemote = Remotes:WaitForChild("Roll")
local NotifyRemote = Remotes:WaitForChild("Notify")

local rng = Random.new()
local lastRoll = {}
local GLOBAL_TOPIC = "BladeForest_BigPull"

local function getLuck(player)
	return (player:GetAttribute("LuckMult") or 1) * (workspace:GetAttribute("EventLuck") or 1)
end

local function rollOnce(player)
	local d = DataService.Get(player)
	d.Rolls.Total += 1
	local lucky = d.Rolls.Total % Config.LuckyRollEvery == 0
	local luck = getLuck(player) * (lucky and 2 or 1)
	local weapon = Config.RollWeapon(rng, luck)

	local result = DataService.AddWeapon(player, weapon.Id, d.Settings.AutoSellBelow)
	result.Rarity = weapon.Rarity
	result.OneIn = weapon.OneIn
	result.Lucky = lucky
	result.RollNumber = d.Rolls.Total
	result.Luck = luck

	-- stats
	if weapon.OneIn > (d.Stats.RarestOneIn or 0) then
		d.Stats.RarestOneIn = weapon.OneIn
		d.Stats.RarestId = weapon.Id
		result.NewBest = true
	end
	Progress.Add(player, "Rolls", 1)
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
RollRemote.OnServerInvoke = function(player)
	if not DataService.Get(player) then return false, "Loading..." end
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
