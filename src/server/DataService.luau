-- DataService: the one place player data lives on the server.
-- M0 (save format v4): session-locked persistence (SessionStore), numbered
-- migrations (SaveMigrations), confirmed saves for receipts (SaveNow),
-- fail-closed loading and crate-origin bookkeeping. Same DataStore and key
-- ("BladeForest_v3" / "p_<UserId>") as v3; v4 only ADDS fields.
-- Save format v3 (all fields kept in v4):
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
local Economy = require(ReplicatedStorage:WaitForChild("Economy")) -- M1: every economy formula
local SessionStore = require(script.Parent:WaitForChild("SessionStore"))
local SaveMigrations = require(script.Parent:WaitForChild("SaveMigrations"))
local ProfileWriter = require(script.Parent:WaitForChild("ProfileWriter")) -- M0.1 serialized, sequence-fenced saves
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
local sessions -- SessionStore bound to `store` (nil when DataStores are unavailable)
if store then
	sessions = SessionStore.new({ store = store })
end
DataService.AUTOSAVE = 60 -- seconds; also refreshes the session lease (SessionStore.LEASE = 300)
local writers = {}   -- [player] = ProfileWriter (M0.1: one serialized writer per profile)
local lost = {}      -- [player] = true once another session took the profile
local Analytics      -- optional, set via DataService.SetAnalytics

local Progression = require(ReplicatedStorage:WaitForChild("CharacterProgression"))

local DEFAULT = {
	Version = 4,
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
	-- v4 (M0) additions; see SaveMigrations
	WeaponItems = {}, -- future per-item weapon identity (empty until M6)
	RetiredWeapons = {}, -- catalog-missing weapons parked instead of deleted
	CrateOrigins = { Earned = 0, Paid = 0, Legacy = 0 }, -- origin of FreeCrates
	Analytics = { Onboard = {}, Prog = {} }, -- analytics bookkeeping, no personal data
	Collections = {}, -- reserved for later collectible systems
	-- M0.1 (H6): playtime-gift visit kept across server hops (see PlaytimeGifts)
	Playtime = { Seconds = 0, Claimed = {}, LastSeen = 0, Day = 0, Visits = 0 },
	-- M1 (additive; absent = default, so v4 saves load unchanged)
	IndexEditions = {}, -- ["Weapon/<area>/Standard|Mastery/<ed>"] / ["Tree/<area>/All/<ed>"] = true, never removed
	SoulUpgrades = {}, -- [soulUpgradeId] = level (permanent, Souls)
	BossKills = {}, -- [bossId] = kills (gate requirements)
	BossFirstClears = {},
	BossSigils = {},
	AltarRolls = {}, -- [islandId] = rolls at that altar since its progression guarantee was last used
	AltarGuarantee = {}, -- [islandId] = true once the island's progression guarantee was granted
	EconomyVersion = 0, -- 1 once the M1 economy notice was shown
	-- M2 (additive)
	Favorites = {}, -- [weaponId] = true: copies are never sold (auto-sell / max-star overflow); future salvage/trade blocked
	Essence = { Total = 0, Day = 0, Today = 0 }, -- Altar Essence (1 per altar roll, daily cap) for Divine Attunement
	Attuned = {}, -- [islandId] = true once that island's Attunement Divine was claimed (one per island, forever)
	Mastery = { Level = 1, XP = 0 },
	TechTree = { TP = 0, Spent = 0, Nodes = {}, Revision = 0 },
	Trait2Locked = false,
	TraitOffer = {},
	PetGolden = {},
	PetRainbow = {},
	_Meta = { Applied = { ["4"] = true } },
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
		if k ~= "Purchases" and k ~= "_Meta" and k ~= "_Session" and k ~= "_NoSave" and k ~= "Analytics" and k ~= "_WriteSeq" then
			snap[k] = deepCopy(v)
		end
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
-- Multipliers (M1): ONE central formula in ReplicatedStorage.Economy.
--   Logs  = (1+soft(perm,6)) x (1+soft(pets,3)) x (1+soft(0.25 n,3)) x passes x strongest temp
--   Luck  = min(50, (1+soft(S_luck,4)) x 2x Luck pass x strongest temp)
-- Attributes: LogMult (incl. temp, what a chop pays now), LogMultBase (no temp),
-- LuckMult (incl. temp/events, what the next normal roll uses), PriceTier/PriceUnit,
-- BestPower, WalkSpeedStat. Recalculated whenever a source changes (and on events).
--------------------------------------------------------------------
local NotifyRemote = Remotes:WaitForChild("Notify")

local function owned(d, id)
	return d.Weapons[id] ~= nil
end

-- record newly completed index editions (sticky: a record is never removed, so adding
-- content later can never take a bonus away - audit H5)
local function updateIndexEditions(player, d)
	d.IndexEditions = d.IndexEditions or {}
	local ed = d.IndexEditions
	local changed = false
	for area, eds in pairs(Config.IndexEditions.Weapon) do
		for n, def in pairs(eds) do
			for _, part in ipairs({ "Standard", "Mastery" }) do
				local list = def[part]
				local key = "Weapon/" .. area .. "/" .. part .. "/" .. n
				if list and #list > 0 and not ed[key] then
					local all = true
					for _, id in ipairs(list) do if not owned(d, id) then all = false break end end
					if all then
						ed[key] = true
						changed = true
						local a = Config.AreaById[area]
						if player then
							NotifyRemote:FireClient(player, string.format("📖 %s %s Index complete! Permanent bonus unlocked", a and a.Name or area,
								part == "Mastery" and "Mastery" or "Weapon"), "boss")
						end
					end
				end
			end
		end
		-- legacy flag for old UI
		local std = ed["Weapon/" .. area .. "/Standard/1"]
		local mas = ed["Weapon/" .. area .. "/Mastery/1"] or not (Config.IndexEditions.Weapon[area][1].Mastery)
		if std and mas and not d.IndexDone[area] then d.IndexDone[area] = true end
	end
	for area, eds in pairs(Config.IndexEditions.Tree) do
		for n in pairs(eds) do
			local key = "Tree/" .. area .. "/All/" .. n
			if not ed[key] then
				local all = true
				for id, tt in pairs(Config.TreeTypes) do
					if tt.Area == area and not (d.Trees and d.Trees[id]) then all = false break end
				end
				if all then
					ed[key] = true
					changed = true
					d.TreeIndexDone[area] = true
					local a = Config.AreaById[area]
					if player then
						NotifyRemote:FireClient(player, string.format("🌳 %s Tree Index complete! +%d%% Logs forever", a and a.Name or area,
							Config.Economy.Index.Tree.Logs * 100), "boss")
					end
				end
			end
		end
	end
	return changed
end
DataService.UpdateIndexEditions = updateIndexEditions

-- best Power of any owned weapon (the progression measure; equip choice does not matter)
function DataService.BestPower(d)
	local best = 0
	for id, entry in pairs(d.Weapons) do
		if Config.WeaponById[id] then
			best = math.max(best, Config.GetWeaponPower(id, entry.Star or 0, entry.Shiny))
		end
	end
	return best
end

-- economy context for Economy.* from a profile + live player state
function DataService.EconomyContext(player, d)
	local passes = {}
	for _, gp in ipairs(Config.GamePasses) do
		if player and player:GetAttribute("Pass_" .. gp.Id) then passes[gp.Id] = true end
	end
	local pets = {}
	for _, id in ipairs(d.EquippedPets or {}) do
		local pd = Config.PetById[id]
		if pd then table.insert(pets, pd) end
	end
	local secondary = d.UnlockedIslands.FrostboundReach == true and Config.TraitById[d.Trait2]
	if secondary and d.Trait2 == d.Trait then secondary = nil end
	local primary = Config.TraitById[d.Trait]
	local function traitBonus(trait, key)
		return trait and trait.Bonuses and trait.Bonuses[key] or 0
	end
	local extra = Progression.Bonuses(d)
	for _, channel in ipairs({ "Luck", "Damage", "Mobility", "PetLogs", "Renewal" }) do
		extra[channel] += traitBonus(primary, channel) + traitBonus(secondary, channel)
	end
	local traitLogs = 1 + (primary and primary.Mult - 1 or 0) + (secondary and secondary.Mult - 1 or 0)
	return {
		Levels = d.Levels, SoulUpgrades = d.SoulUpgrades, Rebirths = d.Rebirths or 0,
		TraitMult = traitLogs, Pets = pets, Passes = passes,
		InGroup = player and player:GetAttribute("InGroup") == true, Boosts = d.Boosts, Now = os.time(),
		EventLogs = workspace:GetAttribute("EventLogs") or 1, EventLuck = workspace:GetAttribute("EventLuck") or 1,
		PvP = player and player:GetAttribute("PvP") == true,
		IndexBonus = Economy.IndexBonus(d.IndexEditions), Extra = { Character = extra },
	}
end

local function round2(x) return math.floor(x * 100 + 0.5) / 100 end

function DataService.RecalcMultipliers(player)
	local d = profiles[player]
	if not d then return end
	updateIndexEditions(player, d)
	local ctx = DataService.EconomyContext(player, d)
	local logs = Economy.LogsBreakdown(ctx)
	local luck = Economy.LuckBreakdown(ctx)
	local names = {}
	for _, id in ipairs(d.EquippedPets or {}) do if Config.PetById[id] then table.insert(names, id) end end
	player:SetAttribute("Pets", table.concat(names, ",")) -- clients draw the pets from this
	player:SetAttribute("LogMult", round2(logs.Total))
	player:SetAttribute("LogMultBase", round2(logs.Base))
	player:SetAttribute("LogTemp", round2(logs.Temp))
	player:SetAttribute("LuckMult", round2(luck.Total))
	player:SetAttribute("LuckTemp", round2(luck.Temp))
	-- progression price tier (audit M4: not BestArea)
	local best = DataService.BestPower(d)
	local tier = Economy.PriceTier(best, d.UnlockedIslands)
	player:SetAttribute("BestPower", math.floor(best))
	local isl = {}
	for id, on in pairs(d.UnlockedIslands or {}) do if on then table.insert(isl, id) end end
	table.sort(isl)
	player:SetAttribute("UnlockedIslands", table.concat(isl, ","))
	player:SetAttribute("PriceTier", tier.Tier)
	player:SetAttribute("PriceUnit", tier.Unit)
	player:SetAttribute("TreeDamageMult", Economy.DamageExtraMult(ctx))
	player:SetAttribute("RenewalBonus", ctx.Extra.Character.Renewal)
	player:SetAttribute("MasteryLevel", d.Mastery.Level)
	player:SetAttribute("MasteryXP", d.Mastery.XP)
	DataService.ApplyMovement(player, ctx.Extra.Character.Mobility)
end

-- recompute every loaded player (luck events, server-wide changes)
function DataService.RecalcAll()
	for player in pairs(profiles) do
		if player.Parent then pcall(DataService.RecalcMultipliers, player) end
	end
end
workspace:GetAttributeChangedSignal("EventLogs"):Connect(DataService.RecalcAll)
workspace:GetAttributeChangedSignal("EventLuck"):Connect(DataService.RecalcAll)

-- M1.3: server-authoritative walk speed (Walk Speed upgrade + future capped mobility).
-- Set on the server Humanoid, so MovementGuard and replication both use it.
function DataService.ApplyMovement(player, mobility)
	local d = profiles[player]
	if not d then return end
	local speed = Economy.WalkSpeed(d.Levels, mobility or DataService.EconomyContext(player, d).Extra.Character.Mobility)
	player:SetAttribute("WalkSpeedStat", speed)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed ~= speed then hum.WalkSpeed = speed end
end

-- price unit of this player's progression tier (prices and Logs rewards)
function DataService.PriceUnit(player)
	return player:GetAttribute("PriceUnit") or Config.Economy.PriceTiers[1].Unit
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
-- M1: LogMult already includes the strongest temporary source (event / Log Boost / PvP)
function DataService.GetCoinMultiplier(player)
	return player:GetAttribute("LogMult") or 1
end

function DataService.AddCoins(player, amount, pos, raw)
	local d = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls or amount <= 0 then return 0 end
	if not raw then amount *= DataService.GetCoinMultiplier(player) end
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
-- Free Trait Crates with origin tracking (M0-D)
--   FreeCrates stays the total the UI shows. CrateOrigins splits it into
--   Earned (gameplay), Paid (bought with Robux / paid entitlements) and Legacy
--   (owned before v4, origin unknown). Code that adds crates directly to
--   FreeCrates (quests, achievements, codes, Treant) is a free source, so any
--   unclassified surplus is counted as Earned.
--------------------------------------------------------------------
local function normalizeCrates(d)
	d.FreeCrates = math.max(0, math.floor(tonumber(d.FreeCrates) or 0))
	local o = d.CrateOrigins
	if type(o) ~= "table" then o = { Earned = 0, Paid = 0, Legacy = d.FreeCrates } d.CrateOrigins = o end
	o.Earned = math.max(0, math.floor(tonumber(o.Earned) or 0))
	o.Paid = math.max(0, math.floor(tonumber(o.Paid) or 0))
	o.Legacy = math.max(0, math.floor(tonumber(o.Legacy) or 0))
	local classified = o.Earned + o.Paid + o.Legacy
	if d.FreeCrates > classified then
		o.Earned += d.FreeCrates - classified
	elseif d.FreeCrates < classified then
		local over = classified - d.FreeCrates
		for _, k in ipairs({ "Legacy", "Paid", "Earned" }) do
			local take = math.min(over, o[k])
			o[k] -= take
			over -= take
		end
	end
	return o
end
DataService.NormalizeCrates = normalizeCrates

-- origin: "Earned" | "Paid"
function DataService.AddCrates(player, n, origin)
	local d = profiles[player]
	n = math.floor(tonumber(n) or 0)
	if not d or n <= 0 then return false end
	local o = normalizeCrates(d)
	o[origin == "Paid" and "Paid" or "Earned"] += n
	d.FreeCrates += n
	return true
end

-- Spend one free crate. allowPaid=false limits it to Earned crates.
-- Returns ok, originUsed | false, reason
local function spendCrateOn(d, allowPaid)
	local o = normalizeCrates(d)
	if d.FreeCrates < 1 then return false, "none" end
	local order = allowPaid and { "Earned", "Legacy", "Paid" } or { "Earned" }
	for _, k in ipairs(order) do
		if o[k] > 0 then
			o[k] -= 1
			d.FreeCrates -= 1
			return true, k
		end
	end
	return false, "restricted"
end
DataService.SpendCrateOn = spendCrateOn -- pure version used by tests

function DataService.SpendCrate(player, allowPaid)
	local d = profiles[player]
	if not d then return false, "Loading..." end
	return spendCrateOn(d, allowPaid)
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
	local fav = d.Favorites and d.Favorites[id] == true -- M2: favorites are never sold
	if entry and sellBelow and not fav and Config.RarityById[w.Rarity].Order < sellBelow.Order then
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
		if fav then keep = Config.WeaponFuture.MaxFavoriteCopies end -- M2: keep favorite copies (bounded)
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
	DataService.RecalcMultipliers(player) -- also re-applies the server WalkSpeed
end

-- M1.6: inputs for Economy.GateStatus
function DataService.GateContext(d)
	return { BestPower = DataService.BestPower(d), BossKills = d.BossKills or {}, TreesByArea = Economy.TreesByArea(d.Trees) }
end

-- M1.6: the island gate (staged requirements). Already-unlocked islands stay unlocked.
function DataService.IslandGate(player, islandId)
	local d = profiles[player]
	if not d then return false, {} end
	if d.UnlockedIslands[islandId] then return true, {}, true end
	local ok, list = Economy.GateStatus(islandId, DataService.GateContext(d))
	return ok, list, false
end

-- M1.6: unlock an island if its active gate requirements are met (Power is checked by
-- the caller against the equipped Power, like AreaService). Returns ok, message.
-- Already-unlocked islands (incl. grandfathered legacy progress) are never re-gated.
function DataService.TryUnlockIsland(player, islandId)
	local d = profiles[player]
	if not d then return false, "Loading..." end
	if islandId == Config.HomeIsland or d.UnlockedIslands[islandId] then return true end
	local ok, list = DataService.IslandGate(player, islandId)
	if not ok then
		local missing = {}
		for _, r in ipairs(list) do
			if r.Stage == "active" and not r.Met then
				table.insert(missing, string.format("%s (%s/%s)", r.Text, Config.FormatNumber(r.Have), Config.FormatNumber(r.Need)))
			end
		end
		local isl = Config.IslandById[islandId]
		return false, "🔒 " .. (isl and isl.Name or islandId) .. ": " .. (#missing > 0 and table.concat(missing, " • ") or "Locked")
	end
	d.UnlockedIslands[islandId] = true
	DataService.RecalcMultipliers(player) -- price tier can rise
	DataService.Sync(player)
	local isl = Config.IslandById[islandId]
	NotifyRemote:FireClient(player, "🏝 " .. (isl and isl.Name or islandId) .. " unlocked!", "boss")
	return true
end

function DataService.AddMasteryXP(player, xp)
	local data = profiles[player]
	if not data or data.Mastery.Level >= Progression.MaxLevel or player:GetAttribute("Handoff") then return end
	local before, reward = Progression.AddXP(data.Mastery, xp)
	player:SetAttribute("MasteryXP", data.Mastery.XP)
	if data.Mastery.Level ~= before then
		data.TechTree.TP += reward
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		local bonus = reward > 0 and string.format("  •  +%d Tech Points", reward) or ""
		NotifyRemote:FireClient(player, string.format("Mastery level %d%s", data.Mastery.Level, bonus), "rare_Legendary")
	end
end

local M4Layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
function DataService.GrantM4FirstClear(player,bossId)
	local d=profiles[player]
	if not d or player:GetAttribute("Handoff") or d.BossFirstClears[bossId] then return false end
	local spec=M4Layout.Bosses[bossId]
	if not spec and bossId~="BladeKing" then return false end
	if bossId=="BladeKing" and not M4Layout.Enabled() then return false end
	local weapon=spec and spec.Weapon or Config.Economy.Altars.TimberHaven.Guarantee.Weapon
	local sigil=spec and spec.Sigil or "Bark"
	assert(Config.WeaponById[weapon],weapon)
	d.BossFirstClears[bossId]=true
	d.BossSigils[sigil]=(d.BossSigils[sigil] or 0)+1
	if not d.Weapons[weapon] then DataService.AddWeapon(player,weapon,nil) end
	DataService.Sync(player)
	return true,weapon
end

function DataService.AddBossKill(player, bossId)
	local d = profiles[player]
	if not d then return end
	d.BossKills = d.BossKills or {}
	d.BossKills[bossId] = (d.BossKills[bossId] or 0) + 1
	if bossId == "Treant" or bossId == "BladeKing" then
		DataService.AddMasteryXP(player, bossId == "Treant" and 650 or 240)
	elseif M4Layout.Bosses[bossId] then
		DataService.AddMasteryXP(player,M4Layout.Bosses[bossId].XP)
	end
end

--------------------------------------------------------------------
-- M2: favorites, Altar Essence and Divine Attunement (server-authoritative)
--------------------------------------------------------------------
function DataService.SetFavorite(player, id, on)
	local d = profiles[player]
	if not d or type(id) ~= "string" or not Config.WeaponById[id] or not d.Weapons[id] then return false, "Not owned" end
	d.Favorites = d.Favorites or {}
	d.Favorites[id] = (on == true) or nil
	DataService.Sync(player)
	return true, d.Favorites[id] == true
end

-- +n essence, capped per UTC day; returns the amount actually added
function DataService.AddEssence(player, n)
	local d = profiles[player]
	if not d then return 0 end
	local E, A = d.Essence, Config.Attunement
	if type(E) ~= "table" then E = { Total = 0, Day = 0, Today = 0 } d.Essence = E end
	local day = Economy.EssenceDay()
	if E.Day ~= day then E.Day = day E.Today = 0 end
	local add = math.clamp(math.floor(n or 0), 0, math.max(A.DailyCap - E.Today, 0))
	E.Today += add
	E.Total += add
	return add
end

-- claim the island's Attunement Divine once (needs the island unlocked + AttuneCost essence)
function DataService.Attune(player, islandId)
	local d = profiles[player]
	if not d then return false, "Loading..." end
	local A = Config.Attunement
	local wid = type(islandId) == "string" and A.Attunement[islandId]
	if not wid then return false, "Unknown altar" end
	if not d.UnlockedIslands[islandId] and islandId ~= Config.HomeIsland then return false, "Unlock the island first" end
	d.Attuned = d.Attuned or {}
	if d.Attuned[islandId] then return false, "Already attuned" end
	if (d.Essence and d.Essence.Total or 0) < A.AttuneCost then
		return false, string.format("Need %s Altar Essence", Config.FormatNumber(A.AttuneCost))
	end
	d.Essence.Total -= A.AttuneCost
	d.Attuned[islandId] = true
	local result = DataService.AddWeapon(player, wid, nil)
	return true, result
end

--------------------------------------------------------------------
-- Load / save (M0-A, M0-B)
--   * Load acquires the session lock (SessionStore.Acquire). If the profile
--     is locked by a live server, unreadable, or the DataStore is down, the
--     player is KICKED with a clear message (fail closed). No default profile
--     is ever created for an existing player whose data could not be read.
--   * v3 -> v4: a one-time backup of the untouched v3 record is written to
--     "bk3_p_<UserId>" and read back before the migrated profile can be saved.
--   * Save writes only while this server owns the session; if another session
--     took it over, this server stops saving and kicks the player.
--------------------------------------------------------------------
local function profileKey(player) return "p_" .. player.UserId end
local function backupKey(player) return "bk3_p_" .. player.UserId end

local function kick(player, msg)
	if player.Parent then player:Kick(msg) end
end

local MSG_LOCKED = "Your Blade Forest data is still open in another server. Please rejoin in a minute."
local MSG_DOWN = "Roblox data services are not responding, so your progress could not be loaded safely. Please rejoin shortly."
local MSG_CORRUPT = "Your save could not be read. It has not been changed. Please contact the developer."
local MSG_MIGRATE = "Your save could not be upgraded safely. It has not been changed. Please rejoin shortly."
local MSG_LOST = "Your Blade Forest data was opened in another server. Please rejoin."

local function encodeEqual(a, b)
	local HttpService = game:GetService("HttpService")
	local ok1, ea = pcall(HttpService.JSONEncode, HttpService, a)
	local ok2, eb = pcall(HttpService.JSONEncode, HttpService, b)
	if not (ok1 and ok2 and #ea == #eb) then return false end
	-- spot-check the fields that matter most
	return a.Logs == b.Logs and a.Souls == b.Souls and a.Version == b.Version and a.Rebirths == b.Rebirths
end

-- finishes building a profile table into the in-memory format
local function prepare(data)
	-- migrate old saves: Coins -> Logs (v1/v2)
	if data.Coins ~= nil then
		data.Logs = (data.Logs or 0) + data.Coins
		data.Coins = nil
	end
	-- Derived M3 structures never reinterpret existing trait or pet ownership.
	for _, key in ipairs({ "Mastery", "TechTree", "PetGolden", "PetRainbow", "TraitOffer" }) do
		if type(data[key]) ~= "table" then data[key] = nil end
	end
	reconcile(data, DEFAULT)
	if type(data.TechTree.Nodes) ~= "table" then data.TechTree.Nodes = {} end
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
	-- weapons that no longer exist in the catalog are parked, not deleted
	for id, entry in pairs(data.Weapons) do
		if not Config.WeaponById[id] then
			data.RetiredWeapons[id] = entry
			data.Weapons[id] = nil
		end
	end
	-- a parked weapon that is back in the catalog returns to the inventory
	for id, entry in pairs(data.RetiredWeapons) do
		if Config.WeaponById[id] and not data.Weapons[id] then
			data.Weapons[id] = entry
			data.RetiredWeapons[id] = nil
		end
	end
	if not data.Weapons[Config.StarterWeapon] then
		data.Weapons[Config.StarterWeapon] = { Copies = 0, Star = 0, Pulled = 1 }
	end
	normalizeCrates(data)
	-- M1 (H5): existing index completions become permanent edition-1 records (only ever adds)
	for area, done in pairs(data.IndexDone or {}) do
		local def = done and Config.IndexEditions.Weapon[area] and Config.IndexEditions.Weapon[area][1]
		if def then
			for _, part in ipairs({ "Standard", "Mastery" }) do
				if def[part] then data.IndexEditions["Weapon/" .. area .. "/" .. part .. "/1"] = true end
			end
		end
	end
	for area, done in pairs(data.TreeIndexDone or {}) do
		if done and Config.IndexEditions.Tree[area] then data.IndexEditions["Tree/" .. area .. "/All/1"] = true end
	end
	return data
end

-- Loads and migrates a raw record. Returns ok, data | false, kickMessage
-- ss: optional SessionStore override (tests); defaults to the live one
function DataService.BuildProfile(raw, player, ss)
	local sessions = ss or sessions
	if raw == nil then
		local ok, fresh = SaveMigrations.Migrate(deepCopy(DEFAULT))
		if not ok then return false, MSG_MIGRATE end
		fresh.Analytics = { Onboard = {}, Prog = {} } -- new player: onboarding funnel applies
		return true, prepare(fresh), "new"
	end
	local needs = (tonumber(raw.Version) or 0) < SaveMigrations.CURRENT
		or not (type(raw._Meta) == "table" and type(raw._Meta.Applied) == "table" and raw._Meta.Applied[tostring(SaveMigrations.CURRENT)])
	if needs and sessions and player then
		-- one-time, read-back-verified backup of the untouched pre-v4 record
		local original = deepCopy(raw)
		original._Session = nil
		local st, stored = sessions:WriteOnce(backupKey(player), { SavedAt = os.time(), FromVersion = raw.Version, Profile = original })
		if st == "error" then return false, MSG_DOWN end
		local rs, readBack = sessions:Read(backupKey(player))
		if rs ~= "ok" or type(readBack) ~= "table" or type(readBack.Profile) ~= "table" then return false, MSG_DOWN end
		if st == "written" and not encodeEqual(readBack.Profile, original) then return false, MSG_MIGRATE end
	end
	local ok, migrated = SaveMigrations.Migrate(raw)
	if not ok then
		warn("[DataService] migration failed:", migrated)
		return false, MSG_MIGRATE
	end
	return true, prepare(migrated), needs and "migrated" or "current"
end

local function finishLoad(player, data)
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

-- Releases a lock this server just acquired WITHOUT changing the record:
-- `raw` is the untouched record returned by Acquire (nil/empty for a new key).
local function releaseUntouched(ss, player, raw)
	task.spawn(function()
		local st = ss:Write(profileKey(player), raw or {}, true)
		if st ~= "ok" then
			warn("[DataService] could not release untouched lock for", player.UserId, st, "- it expires after SessionStore.LEASE")
		end
	end)
end

-- ss: optional SessionStore override (M0.1 tests drive this with a mock store
-- and a stand-in player table; in game it is always called with one argument)
function DataService.Load(player, ss)
	local sessions = ss or sessions
	if not sessions then
		if RunService:IsStudio() then
			-- Studio with API access off: play on a throwaway profile that is never saved
			warn("[DataService] DataStores unavailable in Studio: using an unsaved test profile")
			local ok, data = DataService.BuildProfile(nil, nil)
			if ok then
				data._NoSave = true
				finishLoad(player, data)
			end
			return
		end
		return kick(player, MSG_DOWN)
	end
	local status, raw, info = sessions:Acquire(profileKey(player))
	if not player.Parent then
		-- left while loading: release the lock we may have just taken
		if status == "ok" then releaseUntouched(sessions, player, raw) end
		return "left"
	end
	if status == "locked" then kick(player, MSG_LOCKED) return "locked" end
	if status == "corrupt" then kick(player, MSG_CORRUPT) return "corrupt" end
	if status ~= "ok" then kick(player, MSG_DOWN) return "error" end

	local ok, data, how = DataService.BuildProfile(raw, player, sessions)
	if not ok then
		-- release the lock without writing anything new
		releaseUntouched(sessions, player, raw)
		kick(player, data)
		return "build_failed"
	end
	-- M0.1 (H3): BuildProfile yields while it writes the first-time migration
	-- backup. If the player left meanwhile, PlayerRemoving has already run with
	-- no profile to release, so release the lock here, writing back the
	-- untouched original record (the migrated copy is discarded).
	if not player.Parent then
		releaseUntouched(sessions, player, raw)
		return "left_during_build"
	end
	data._WriteSeq = info and info.Seq or tonumber(data._WriteSeq) or 0
	if ss then return "ok", data end -- test drive: never register stand-in players
	writers[player] = ProfileWriter.new({ sessions = sessions, key = profileKey(player), data = data, seq = data._WriteSeq })
	player:SetAttribute("SaveFormat", how) -- "new" | "migrated" | "current" (diagnostics)
	finishLoad(player, data)
	return "ok"
end

-- Saves now. release=true also releases the session lock.
-- Returns true only when the write was confirmed by the DataStore.
-- M0.1 (H2): writes are serialized per profile by ProfileWriter (no overlap,
-- each write copies the newest data when it starts) and fenced by a
-- persistent write sequence in SessionStore.
function DataService.SaveNow(player, release)
	local d = profiles[player]
	local w = writers[player]
	if not d or not w or d._NoSave or lost[player] then return false end
	local ok, status, err = w:Save(release)
	if ok then return true end
	if status == "lost" or status == "stale" then
		if not lost[player] then
			lost[player] = true
			warn("[DataService] session lost for", player.UserId, "(" .. status .. ") - this server will not save again")
			if Analytics then pcall(Analytics.SaveFailed, player, status == "stale" and "Stale" or "SessionLost") end
			kick(player, MSG_LOST)
		end
	elseif status ~= "released" then
		warn("[DataService] save failed for", player.UserId, status, err)
		if Analytics then pcall(Analytics.SaveFailed, player, status == "queue_timeout" and "QueueTimeout" or "Error") end
	end
	return false
end

function DataService.Save(player)
	return DataService.SaveNow(player, false)
end

-- true while this server is the authoritative owner of the player's profile
function DataService.IsActive(player)
	local w = writers[player]
	return profiles[player] ~= nil and w ~= nil and not w.lost and not w.released and not lost[player]
		and player:GetAttribute("Loaded") == true
end

function DataService.CanPersist(player)
	local d = profiles[player]
	local w = writers[player]
	return d ~= nil and w ~= nil and not d._NoSave and not lost[player] and not w.lost and not w.released
end

-- number of saves queued or in flight (autosave skips busy profiles)
function DataService.PendingSaves(player)
	local w = writers[player]
	return w and w:Pending() or 0
end

--------------------------------------------------------------------
-- M0.1 (M1) AFK server-hop handoff
--   HandoffRelease: blocks rewards (attribute "Handoff"), makes a confirmed
--   final save that releases the lock. Only then may the player teleport.
--   ResumeAfterHandoff: teleport failed -> take the lock back if nobody wrote
--   since; otherwise the player is kicked (their saved data is intact).
--------------------------------------------------------------------
function DataService.HandoffRelease(player)
	local w = writers[player]
	if not w or not DataService.CanPersist(player) then return false, "not_active" end
	player:SetAttribute("Handoff", true)
	local ok, status = DataService.SaveNow(player, true)
	if not ok then
		player:SetAttribute("Handoff", nil)
		return false, status or "save_failed"
	end
	return true
end

function DataService.ResumeAfterHandoff(player)
	local w = writers[player]
	if not w or not w.released then return false, "not_released" end
	local res = w:Resume()
	if res == "ok" then
		player:SetAttribute("Handoff", nil)
		return true
	end
	warn("[DataService] could not resume after handoff for", player.UserId, res)
	lost[player] = true
	kick(player, res == "locked" and MSG_LOCKED or MSG_LOST)
	return false, res
end

function DataService.SetAnalytics(a) Analytics = a end

local releasing = {}
local function releasePlayer(player)
	if releasing[player] then return end
	releasing[player] = true
	if Analytics then pcall(Analytics.OnLeaving, player) end
	local w = writers[player]
	if profiles[player] and w and not w.released then
		local ok = DataService.SaveNow(player, true)
		if not ok and not lost[player] and DataService.CanPersist(player) then
			-- one more attempt; if it still fails the lease expires after SessionStore.LEASE
			task.wait(2)
			DataService.SaveNow(player, true)
		end
	end
	profiles[player] = nil
	writers[player] = nil
	lost[player] = nil
	releasing[player] = nil
end

Players.PlayerRemoving:Connect(releasePlayer)

-- Shutdown: release every profile in parallel, bounded to 25 s
game:BindToClose(function()
	local pending = 0
	for _, p in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			pcall(releasePlayer, p)
			pending -= 1
		end)
	end
	local t = os.clock()
	-- wait for our own threads AND any release already started by PlayerRemoving
	while (pending > 0 or next(profiles) ~= nil) and os.clock() - t < 25 do task.wait(0.1) end
	if pending > 0 or next(profiles) ~= nil then warn("[DataService] shutdown: some saves did not finish in 25 s (locks expire after SessionStore.LEASE)") end
end)

-- Autosave every AUTOSAVE seconds (also refreshes the session lease)
task.spawn(function()
	while true do
		task.wait(DataService.AUTOSAVE)
		for _, p in ipairs(Players:GetPlayers()) do
			local w = writers[p]
			if profiles[p] and w and w:Pending() == 0 and not w.released then task.spawn(DataService.Save, p) end
		end
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
