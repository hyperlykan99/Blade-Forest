-- DataService: the one place player data lives on the server.
-- Save format v3:
--   Logs (main currency, was Coins), Kills, Levels{upgradeId=level}
--   Weapons{ [weaponId] = { Copies = spare dupes, Star = 0..5, Pulled = total pulled } }
--   Equipped, AutoEquip
--   Rolls{ Total, SinceEpic, SinceLegendary }  (pity counters)
--   LuckLevel, Trait, TraitLocked
--   Boosts{ [boostId] = expiresAt (os.time) }
--   Purchases{ [receiptId] = true }, StarterPack
--   Settings{ AutoFuse, AutoSellBelow }
--   BestArea

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")
local RewardRemote = Remotes:WaitForChild("Reward")

local STORE_NAME = "BladeForest_v3"
local store
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local DataService = {}
local profiles = {} -- [player] = data

local DEFAULT = {
	Version = 3,
	Logs = 0,
	Kills = 0,
	Levels = {},
	Weapons = { [Config.StarterWeapon] = { Copies = 0, Star = 0, Pulled = 1 } },
	Equipped = Config.StarterWeapon,
	AutoEquip = true,
	Rolls = { Total = 0, SinceEpic = 0, SinceLegendary = 0 },
	LuckLevel = 0,
	Trait = nil,
	TraitLocked = false,
	Boosts = {},
	Purchases = {},
	StarterPack = false,
	Settings = { AutoFuse = true, AutoSellBelow = nil },
	BestArea = "StarterGrove",
	IndexDone = {}, -- [areaId] = true once every weapon of that area is found
	IndexClaimed = {}, -- [weaponId] = true once its discovery reward was claimed
	Trees = {}, -- [treeTypeId] = times chopped (tree index)
	TreeClaimed = {}, -- [treeTypeId] = true once its discovery reward was claimed
	TreeIndexDone = {}, -- [areaId] = true once every tree of that area is found
	MutationsFound = {}, -- [mutationId] = mutated trees chopped
	Souls = 0, -- second currency (NPC + PvP kills), spent in the Soul Shop
	FreeCrates = 0, -- free Trait Crate rolls (Robux crates, Starter Pack, VIP daily)
	LastVipCrate = 0, -- os.time of the last VIP daily crate
	Stats = { LogsEarned = 0, TreesChopped = 0, PlaySeconds = 0, RarestOneIn = 0, RarestId = false, SoulsEarned = 0, PetsHatched = 0, Treants = 0 },
	Pets = {}, -- [petId] = how many you own
	EquippedPets = {}, -- list of petIds following you
	Achievements = {}, -- [achievementId] = true once claimed
	Sawmill = { Day = 0, Souls = 0 }, -- souls traded today
	Rebirths = 0,
	Prefs = { Music = 0.5, SFX = 0.8, Graphics = "High", DamageNumbers = true, SkipReveals = false, ShowTags = true, ScreenShake = true, ReducedMotion = false },
	Daily = { Streak = 0, LastDay = 0 },
	Quests = { DayKey = 0, WeekKey = 0, Daily = {}, Weekly = {} },
	Codes = {},
	GroupClaimed = false,
	TutorialDone = false,
	-- P1a islands (added via reconcile; old keys untouched)
	UnlockedIslands = { TimberHaven = true }, -- [islandId] = true
	LastIsland = "TimberHaven",
	IslandProgress = {}, -- [islandId] = { ... } reserved for P1c objectives
}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

-- fill in any keys missing from older saves
local function reconcile(data, default)
	for k, v in pairs(default) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Weapons" then
			reconcile(data[k], v)
		end
	end
end

--------------------------------------------------------------------
-- Access + client sync
--------------------------------------------------------------------
function DataService.Get(player)
	return profiles[player]
end

function DataService.Snapshot(data)
	local snap = {}
	for k, v in pairs(data) do
		if k ~= "Purchases" then snap[k] = deepCopy(v) end
	end
	return snap
end

local syncQueued = {}
function DataService.Sync(player)
	if syncQueued[player] then return end
	syncQueued[player] = true
	task.delay(0.1, function()
		syncQueued[player] = nil
		local d = profiles[player]
		if d and player.Parent then
			DataSync:FireClient(player, DataService.Snapshot(d))
		end
	end)
end

GetData.OnServerInvoke = function(player)
	local t = os.clock()
	while not profiles[player] and os.clock() - t < 15 do task.wait(0.1) end
	local d = profiles[player]
	return d and DataService.Snapshot(d) or nil
end

--------------------------------------------------------------------
-- Multipliers (luck + coins). Recalculated whenever a source changes.
--   Luck  = Lucky Charm upgrade x potions x 2x Luck pass x (1 + index bonus)
--   Coins = trait x 2x Coins pass x VIP x coin boost x (1 + index bonus)
-- Pass/trait parts read attributes that later steps set.
--------------------------------------------------------------------
local NotifyRemote = Remotes:WaitForChild("Notify")

local function areaComplete(d, areaId)
	for _, w in ipairs(Config.Weapons) do
		if w.Area == areaId and not w.Exclusive and not d.Weapons[w.Id] then return false end
	end
	return true
end

function DataService.RecalcMultipliers(player)
	local d = profiles[player]
	if not d then return end
	local now = os.time()

	-- index completion
	local done = 0
	for _, a in ipairs(Config.Areas) do
		if areaComplete(d, a.Id) then
			done += 1
			if not d.IndexDone[a.Id] then
				d.IndexDone[a.Id] = true
				NotifyRemote:FireClient(player, string.format("📖 %s Index complete! +%d%% Luck, +%d%% Logs forever", a.Name,
					Config.IndexBonus.Luck * 100, (Config.IndexBonus.Logs or 0) * 100), "boss")
			end
		end
	end

	-- tree index completion (+Logs per area)
	local treeDone = 0
	for _, a in ipairs(Config.Areas) do
		local all = true
		for id, tt in pairs(Config.TreeTypes) do
			if tt.Area == a.Id and not (d.Trees and d.Trees[id]) then all = false break end
		end
		if all then
			treeDone += 1
			if not d.TreeIndexDone[a.Id] then
				d.TreeIndexDone[a.Id] = true
				NotifyRemote:FireClient(player, string.format("🌳 %s Tree Index complete! +%d%% Logs forever", a.Name,
					Config.TreeIndexBonus.Logs * 100), "boss")
			end
		end
	end

	local luck = Config.GetValue("Luck", d.Levels.Luck or 0)
	local coins = 1
	for id, expires in pairs(d.Boosts) do
		local b = Config.Boosts[id]
		if b and expires > now then
			luck *= b.Luck or 1
			coins *= b.Logs or 1
		end
	end
	if player:GetAttribute("Pass_2xLuck") then luck *= 2 end
	if player:GetAttribute("Pass_2xLogs") then coins *= 2 end
	if player:GetAttribute("Pass_VIP") then coins *= 1.1 end
	coins *= player:GetAttribute("TraitMult") or 1
	-- rebirths: +25% Logs and +10% Luck each
	coins *= 1 + Config.Rebirth.LogsPer * (d.Rebirths or 0)
	luck *= 1 + Config.Rebirth.LuckPer * (d.Rebirths or 0)
	if player:GetAttribute("InGroup") then luck *= Config.GroupLuck end
	if player:GetAttribute("PvP") then coins *= Config.PvP.LogMult end
	-- pets: bonuses add up, then multiply
	local petLogs, petLuck, names = 0, 0, {}
	for _, id in ipairs(d.EquippedPets or {}) do
		local p = Config.PetById[id]
		if p then
			petLogs += p.Logs
			petLuck += p.Luck
			table.insert(names, id)
		end
	end
	coins *= 1 + petLogs
	luck *= 1 + petLuck
	player:SetAttribute("Pets", table.concat(names, ",")) -- clients draw the pets from this
	luck *= 1 + done * Config.IndexBonus.Luck
	coins *= 1 + done * (Config.IndexBonus.Logs or 0)
	coins *= 1 + treeDone * Config.TreeIndexBonus.Logs

	player:SetAttribute("LuckMult", math.floor(luck * 100 + 0.5) / 100)
	player:SetAttribute("LogMult", math.floor(coins * 100 + 0.5) / 100)
end

-- Add (or extend) a timed boost
function DataService.AddBoost(player, boostId, seconds)
	local d = profiles[player]
	if not d or not Config.Boosts[boostId] then return false end
	local now = os.time()
	d.Boosts[boostId] = math.max(d.Boosts[boostId] or 0, now) + seconds
	DataService.RecalcMultipliers(player)
	DataService.Sync(player)
	return true
end

-- expire boosts
task.spawn(function()
	while true do
		task.wait(2)
		local now = os.time()
		for player, d in pairs(profiles) do
			local changed = false
			for id, expires in pairs(d.Boosts) do
				if expires <= now then
					d.Boosts[id] = nil
					changed = true
				end
			end
			if changed then
				DataService.RecalcMultipliers(player)
				DataService.Sync(player)
			end
		end
	end
end)

--------------------------------------------------------------------
-- Coins
--------------------------------------------------------------------
function DataService.GetCoinMultiplier(player)
	return player:GetAttribute("LogMult") or 1
end

function DataService.AddCoins(player, amount, pos, raw)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls or amount <= 0 then return 0 end
	if not raw then amount *= DataService.GetCoinMultiplier(player) * (workspace:GetAttribute("EventLogs") or 1) end
	amount = math.floor(amount)
	d.Logs += amount
	d.Stats.LogsEarned += amount
	ls.Logs.Value = d.Logs
	if pos then RewardRemote:FireClient(player, amount, pos) end
	return amount
end

-- Souls (raw, no multipliers). pos -> floating "+N Souls" for that player
function DataService.AddSouls(player, amount, pos)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	amount = math.floor(amount or 0)
	if not d or not ls or amount <= 0 then return 0 end
	d.Souls = (d.Souls or 0) + amount
	d.Stats.SoulsEarned += amount
	if ls:FindFirstChild("Souls") then ls.Souls.Value = d.Souls end
	local r = Remotes:FindFirstChild("SoulReward")
	if r and pos then r:FireClient(player, amount, pos) end
	return amount
end

function DataService.SpendSouls(player, amount)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls or (d.Souls or 0) < amount then return false end
	d.Souls -= amount
	if ls:FindFirstChild("Souls") then ls.Souls.Value = d.Souls end
	return true
end

function DataService.SpendCoins(player, amount)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls or d.Logs < amount then return false end
	d.Logs -= amount
	ls.Logs.Value = d.Logs
	return true
end

function DataService.AddKill(player)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls then return end
	d.Kills += 1
	ls.Kills.Value = d.Kills
end

--------------------------------------------------------------------
-- Weapons, stars, equip
--------------------------------------------------------------------
local function weaponPower(id, entry)
	return Config.GetWeaponPower(id, entry and entry.Star or 0, entry and entry.Shiny)
end

function DataService.BestWeapon(data)
	local bestId, bestPower = Config.StarterWeapon, -1
	for id, entry in pairs(data.Weapons) do
		if Config.WeaponById[id] then
			local p = weaponPower(id, entry)
			if p > bestPower then bestId, bestPower = id, p end
		end
	end
	return bestId
end

function DataService.ApplyEquip(player)
	local d = profiles[player]
	if not d then return end
	if d.AutoEquip or not d.Weapons[d.Equipped] then
		d.Equipped = DataService.BestWeapon(d)
	end
	local entry = d.Weapons[d.Equipped]
	player:SetAttribute("EquippedBlade", d.Equipped)
	player:SetAttribute("EquippedStar", entry and entry.Star or 0)
	player:SetAttribute("EquippedShiny", (entry and entry.Shiny) or nil)
	player:SetAttribute("Power", math.floor(weaponPower(d.Equipped, entry)))
end

function DataService.Equip(player, id)
	local d = profiles[player]
	if not d or not d.Weapons[id] then return false, "Not owned" end
	d.Equipped = id
	d.AutoEquip = false
	DataService.ApplyEquip(player)
	DataService.Sync(player)
	return true
end

function DataService.SetAutoEquip(player, on)
	local d = profiles[player]
	if not d then return end
	d.AutoEquip = on and true or false
	DataService.ApplyEquip(player)
	DataService.Sync(player)
end

-- Fuse spare copies upward as far as they go. Returns stars gained.
local function fuseEntry(entry)
	local gained = 0
	while entry.Star < Config.MaxStar and entry.Copies >= Config.FuseCost[entry.Star + 1] do
		entry.Copies -= Config.FuseCost[entry.Star + 1]
		entry.Star += 1
		gained += 1
	end
	return gained
end

local function sellValue(id)
	local w = Config.WeaponById[id]
	local r = Config.RarityById[w.Rarity]
	return r.SellValue * Config.AreaById[w.Area].PowerMult
end

-- Manual fuse (one press = as many stars as copies allow)
function DataService.Fuse(player, id)
	local d = profiles[player]
	local entry = d and d.Weapons[id]
	if not entry then return false, "Not owned" end
	if entry.Star >= Config.MaxStar then
		-- crafting: max-star + spare copies -> SHINY
		if entry.Shiny then return false, "MAX" end
		if entry.Copies < Config.ShinyCopies then return false, string.format("Need %d copies", Config.ShinyCopies) end
		entry.Copies -= Config.ShinyCopies
		entry.Shiny = true
		DataService.ApplyEquip(player)
		DataService.Sync(player)
		NotifyRemote:FireAllClients(string.format("✨ %s crafted a SHINY %s!", player.DisplayName, Config.WeaponById[id].Name), "rare_Legendary")
		return true, "Shiny"
	end
	local gained = fuseEntry(entry)
	if gained == 0 then
		return false, string.format("Need %d copies", Config.FuseCost[entry.Star + 1])
	end
	DataService.ApplyEquip(player)
	DataService.Sync(player)
	return true, gained
end

-- Give a weapon (from a roll, pack, etc). Handles dupes, auto-fuse and selling extras past max star.
-- autoSellBelow (rarity id, optional): a DUPLICATE below this rarity is sold instead of kept.
function DataService.AddWeapon(player, id, autoSellBelow)
	local d = profiles[player]
	if not d or not Config.WeaponById[id] then return nil end
	local result = { Id = id, IsNew = false, StarsGained = 0, Sold = 0 }
	local entry = d.Weapons[id]
	local w = Config.WeaponById[id]
	local sellBelow = autoSellBelow and Config.RarityById[autoSellBelow]
	if entry and sellBelow and Config.RarityById[w.Rarity].Order < sellBelow.Order then
		entry.Pulled += 1
		result.Sold = DataService.AddCoins(player, sellValue(id), nil, true)
		result.AutoSold = true
		result.Star = entry.Star
		result.Copies = entry.Copies
		DataService.Sync(player)
		return result
	end
	if not entry then
		entry = { Copies = 0, Star = 0, Pulled = 1 }
		d.Weapons[id] = entry
		result.IsNew = true
	else
		entry.Pulled += 1
		entry.Copies += 1
		if d.Settings.AutoFuse then
			result.StarsGained = fuseEntry(entry)
		end
		-- max star: keep up to ShinyCopies spares for Shiny crafting, sell the rest
		local keep = entry.Shiny and 0 or Config.ShinyCopies
		if entry.Star >= Config.MaxStar and entry.Copies > keep then
			result.Sold = DataService.AddCoins(player, sellValue(id) * (entry.Copies - keep), nil, true)
			entry.Copies = keep
		end
	end
	result.Star = entry.Star
	result.Copies = entry.Copies
	DataService.ApplyEquip(player)
	if result.IsNew then DataService.RecalcMultipliers(player) end
	DataService.Sync(player)
	return result
end

function DataService.SetSetting(player, key, value)
	local d = profiles[player]
	if not d then return false end
	if key == "AutoSellBelow" then
		if value ~= nil and not Config.RarityById[value] then return false end
	elseif d.Settings[key] == nil then
		return false
	end
	d.Settings[key] = value
	DataService.Sync(player)
	return true
end

--------------------------------------------------------------------
-- Upgrades
--------------------------------------------------------------------
function DataService.SetLevel(player, upgradeId, level)
	local d = profiles[player]
	if not d then return end
	d.Levels[upgradeId] = level
	player:SetAttribute("Lvl_" .. upgradeId, level)
	DataService.RecalcMultipliers(player)
end

--------------------------------------------------------------------
-- Load / save
--------------------------------------------------------------------
function DataService.Load(player)
	local data, loadFailed
	if store then
		for attempt = 1, 3 do
			local ok, res = pcall(function()
				return store:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				data = res
				loadFailed = false
				break
			end
			loadFailed = true
			if RunService:IsStudio() then break end -- Studio API access off: don't stall
			task.wait(1)
		end
	end
	if type(data) ~= "table" then data = deepCopy(DEFAULT) end
	-- migrate old saves: Coins -> Logs
	if data.Coins ~= nil then
		data.Logs = (data.Logs or 0) + data.Coins
		data.Coins = nil
	end
	reconcile(data, DEFAULT)
	-- P1a islands: grandfather legacy progress (BestArea) into island unlocks. Only ever adds.
	do
		local best = Config.AreaById[data.BestArea] or Config.AreaById.StarterGrove
		for _, isl in ipairs(Config.Islands or {}) do
			local la = isl.LegacyArea and Config.AreaById[isl.LegacyArea]
			if la and best.Order >= la.Order then data.UnlockedIslands[isl.Id] = true end
		end
		if type(data.LastIsland) ~= "string" or not (Config.IslandById and Config.IslandById[data.LastIsland]) then
			data.LastIsland = Config.HomeIsland or "TimberHaven"
		end
	end
	-- never let a failed load overwrite the real save
	data._NoSave = loadFailed or nil

	-- drop weapons that no longer exist in the catalog
	for id in pairs(data.Weapons) do
		if not Config.WeaponById[id] then data.Weapons[id] = nil end
	end
	if not data.Weapons[Config.StarterWeapon] then
		data.Weapons[Config.StarterWeapon] = { Copies = 0, Star = 0, Pulled = 1 }
	end

	if not player.Parent then return end
	profiles[player] = data

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Logs"
	coins.Value = data.Logs
	coins.Parent = ls
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = data.Kills
	kills.Parent = ls
	local souls = Instance.new("IntValue")
	souls.Name = "Souls"
	souls.Value = data.Souls or 0
	souls.Parent = ls
	ls.Parent = player

	for _, u in ipairs(Config.Upgrades) do
		player:SetAttribute("Lvl_" .. u.Id, math.clamp(data.Levels[u.Id] or 0, 0, u.MaxLevel))
	end
	player:SetAttribute("Streak", 0)
	DataService.ApplyEquip(player)
	DataService.RecalcMultipliers(player)
	player:SetAttribute("Loaded", true)
	DataService.Sync(player)
end

function DataService.Save(player)
	local d = profiles[player]
	if not d or not store or d._NoSave then return end
	local copy = deepCopy(d)
	copy._NoSave = nil
	pcall(function()
		store:SetAsync("p_" .. player.UserId, copy)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Save(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	local threads = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(threads, task.spawn(DataService.Save, p))
	end
	task.wait(2)
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do task.spawn(DataService.Save, p) end
	end
end)

-- Studio-only test hook: ServerStorage.DevGrant:Invoke(player, "AddWeapon", id) etc.
if RunService:IsStudio() then
	local dev = Instance.new("BindableFunction")
	dev.Name = "DevGrant"
	dev.OnInvoke = function(player, fn, ...)
		if fn == "SetPity" then
			local d = profiles[player]
			local sinceEpic, sinceLegendary = ...
			d.Rolls.SinceEpic = sinceEpic
			d.Rolls.SinceLegendary = sinceLegendary
			DataService.Sync(player)
			return true
		end
		return DataService[fn](player, ...)
	end
	dev.Parent = game:GetService("ServerStorage")
end

-- Logs is the main currency (functions kept their old names too)
DataService.AddLogs = DataService.AddCoins
DataService.SpendLogs = DataService.SpendCoins

return DataService
