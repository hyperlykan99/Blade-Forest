-- Economy (M1): the ONE place every economy formula lives. Pure functions on plain
-- tables, shared by the server (authoritative) and clients (display only).
-- Numbers come from EconomyConfig (generated from tools/econsim/economy_params.json);
-- tools/econsim/m1sim.py implements the same formulas for balance simulation.
--
-- Stacking model (audit §8, owner-directed M1):
--   * bonuses of one CATEGORY add up inside a pool; each pool is soft-capped:
--       soft(S, C) = C * (1 - exp(-S / C))      (always grows, never passes C)
--   * pools multiply ACROSS categories (few, fixed categories)
--   * paid passes keep their exact advertised effect (x2 Logs, x1.1 VIP, x2 Luck)
--   * temporary sources (potions, events, PvP) never stack: the STRONGEST applies
--   * luck has a hard cap; rarer tiers feel luck less (gamma per rarity)
-- Future systems (Tech Tree, Mastery, runes, guilds...) add to an existing pool via
-- ctx.Extra[Channel], never as a new multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local EC = require(ReplicatedStorage:WaitForChild("EconomyConfig"))

local Layout = require(ReplicatedStorage:WaitForChild("M4Layout"))

local E = {}
E.Config = EC
local P = EC.Pools

function E.soft(S, cap)
	S = tonumber(S) or 0
	if S ~= S or S <= 0 or cap <= 0 then return 0 end
	return cap * (1 - math.exp(-S / cap))
end

local UPG = {}
for _, u in ipairs(EC.Upgrades) do UPG[u.Id] = u end
E.UpgradeById = UPG
local SOUL = {}
for _, u in ipairs(EC.SoulUpgrades) do SOUL[u.Id] = u end
E.SoulUpgradeById = SOUL

local function num(v) v = tonumber(v) return (v and v == v and v ~= math.huge and v ~= -math.huge) and v or 0 end
local function lvl(levels, id)
	local u = UPG[id]
	return math.clamp(math.floor(num(levels and levels[id])), 0, u and u.MaxLevel or 0)
end
local function soulLvl(su, id)
	local u = SOUL[id]
	return math.clamp(math.floor(num(su and su[id])), 0, u and u.MaxLevel or 0)
end

--------------------------------------------------------------------
-- Upgrades (Logs, reset on rebirth) and Soul upgrades (Souls, permanent)
--------------------------------------------------------------------
function E.UpgradeValue(id, level)
	local u = UPG[id]
	return u.Base + u.PerLevel * level
end

function E.UpgradeCost(id, level)
	local u = UPG[id]
	return math.floor(u.BaseCost * u.CostMult ^ level)
end

function E.SoulUpgradeCost(id, level)
	local u = SOUL[id]
	return math.floor(u.BaseCost * u.CostMult ^ level)
end

--------------------------------------------------------------------
-- Context: everything the formulas need, built from a profile (server) or a
-- DataSync snapshot (client). Extra = future channels { [channel] = {Logs=, Luck=, ...} }
--------------------------------------------------------------------
-- ctx = {
--   Levels, SoulUpgrades, Rebirths, TraitMult, Pets = {petDef...}, Passes = {[id]=true},
--   InGroup, Boosts = {[id]=expires}, Now, EventLogs, EventLuck, PvP,
--   IndexBonus = {Logs=, Luck=}, Extra = {}
-- }

--------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------
local function passMult(passes, key)
	local m = 1
	for id, eff in pairs(EC.PassEffects) do
		if passes and passes[id] and eff[key] then m *= eff[key] end
	end
	return m
end

local function extraSum(ctx, key)
	local s = 0
	for _, ch in pairs(ctx.Extra or {}) do s += num(ch[key]) end
	return s
end

function E.TempLogs(ctx)
	local best = 1
	local now = ctx.Now or os.time()
	for id, expires in pairs(ctx.Boosts or {}) do
		local b = EC.TempSources.Boosts[id]
		if b and b.Logs and num(expires) > now then best = math.max(best, b.Logs) end
	end
	best = math.max(best, num(ctx.EventLogs) > 0 and num(ctx.EventLogs) or 1)
	if ctx.PvP then best = math.max(best, EC.TempSources.PvPLogs) end
	return math.min(best, P.TempLogsMax)
end

-- Returns a breakdown; .Base excludes temporary boosts, .Total includes them
function E.LogsBreakdown(ctx)
	local b = {}
	b.PermS = math.max(num(ctx.TraitMult) - 1, 0) + num(ctx.IndexBonus and ctx.IndexBonus.Logs)
		+ soulLvl(ctx.SoulUpgrades, "SoulBlessing") * SOUL.SoulBlessing.PerLevel + extraSum(ctx, "Logs")
	b.Perm = 1 + E.soft(b.PermS, P.PermLogsCap)
	b.PetS = extraSum(ctx, "PetLogs")
	for _, pet in ipairs(ctx.Pets or {}) do b.PetS += num(pet.Logs) end
	b.Pet = 1 + E.soft(b.PetS, P.PetLogsCap)
	b.Rebirth = 1 + E.soft(P.RebirthLogsPer * num(ctx.Rebirths), P.RebirthLogsCap)
	b.Pass = passMult(ctx.Passes, "Logs")
	b.Temp = E.TempLogs(ctx)
	b.Base = b.Perm * b.Pet * b.Rebirth * b.Pass
	b.Total = b.Base * b.Temp
	return b
end

--------------------------------------------------------------------
-- Luck
--------------------------------------------------------------------
function E.TempLuck(ctx)
	local best = 1
	local now = ctx.Now or os.time()
	for id, expires in pairs(ctx.Boosts or {}) do
		local b = EC.TempSources.Boosts[id]
		if b and b.Luck and num(expires) > now then best = math.max(best, b.Luck) end
	end
	best = math.max(best, num(ctx.EventLuck) > 0 and num(ctx.EventLuck) or 1)
	return math.min(best, P.TempLuckMax)
end

function E.LuckBreakdown(ctx)
	local b = {}
	b.S = UPG.Luck.PerLevel * lvl(ctx.Levels, "Luck")
		+ P.RebirthLuckPer * num(ctx.Rebirths)
		+ num(ctx.IndexBonus and ctx.IndexBonus.Luck)
		+ (ctx.InGroup and (Config.GroupLuck - 1) or 0)
		+ soulLvl(ctx.SoulUpgrades, "SoulFortune") * SOUL.SoulFortune.PerLevel
		+ extraSum(ctx, "Luck")
	for _, pet in ipairs(ctx.Pets or {}) do b.S += num(pet.Luck) end
	b.Perm = 1 + E.soft(b.S, P.PermLuckCap)
	b.Pass = passMult(ctx.Passes, "Luck")
	b.Temp = E.TempLuck(ctx)
	b.Total = math.min(b.Perm * b.Pass * b.Temp, P.LuckHardCap)
	return b
end

-- luck of one roll (every LuckyRollEvery-th roll doubles it), still capped
function E.RollLuck(luck, lucky)
	return math.min(math.max(num(luck), 1) * (lucky and P.LuckyRollMult or 1), P.LuckHardCap)
end

--------------------------------------------------------------------
-- Damage / movement / renewal
--------------------------------------------------------------------
-- multiplier on top of the Damage upgrade for future sources (traits, Tech Tree, runes)
function E.DamageExtraMult(ctx)
	return 1 + E.soft(extraSum(ctx, "Damage"), P.DamageExtraCap)
end

-- server-authoritative walk speed: base + regular upgrade (<= RegularMax) + capped future mobility
function E.WalkSpeed(levels, extraMobility)
	local M = EC.Movement
	local regular = math.min(M.BaseWalkSpeed + UPG.WalkSpeed.PerLevel * lvl(levels, "WalkSpeed"), M.RegularMaxWalkSpeed)
	return regular + math.clamp(num(extraMobility), 0, M.MobilityExtraMax)
end
-- the highest walk speed any legitimate player can have (for audits / tests)
function E.MaxLegitWalkSpeed()
	return EC.Movement.RegularMaxWalkSpeed + EC.Movement.MobilityExtraMax
end

function E.RenewalReduction(level, extra)
	local R = EC.Renewal
	return math.min(UPG.Renewal.PerLevel * math.clamp(math.floor(num(level)), 0, UPG.Renewal.MaxLevel) + math.max(0, num(extra)), R.MaxReduction)
end

local RENEW_RARITY = {}
for _, r in ipairs(EC.Renewal.Rarities) do RENEW_RARITY[r] = true end
-- respawn delay of a tree felled by a player with this Renewal level
-- (Legendary and rarer trees are never accelerated)
function E.RenewedRespawn(respawn, rarity, level, extra)
	respawn = num(respawn)
	if not RENEW_RARITY[rarity] then return respawn, false end
	local red = E.RenewalReduction(level, extra)
	if red <= 0 then return respawn, false end
	return math.max(EC.Renewal.MinRespawn, respawn * (1 - red)), true
end

--------------------------------------------------------------------
-- Weapons: island altars with exact odds
--------------------------------------------------------------------
local GAMMA = EC.LuckGamma
function E.EffectiveOneIn(w, luck)
	local oneIn = num(w.OneIn)
	if oneIn <= EC.LuckMinOneIn then return oneIn end
	return math.max(oneIn / math.max(num(luck), 1) ^ (GAMMA[w.Rarity] or 1), 1)
end

local poolCache = {}
-- weapons rollable at an island's altar, rarest first (own areas + inherited islands)
function E.AltarPool(islandId)
	if poolCache[islandId] then return poolCache[islandId] end
	local a = EC.Altars[islandId]
	if not a then return nil end
	local set, list = {}, {}
	local function add(isl)
		local def = EC.Altars[isl]
		for _, w in ipairs(Config.RollPool) do
			if table.find(def.Areas, w.Area) and not set[w.Id] then set[w.Id] = true table.insert(list, w) end
		end
		for _, parent in ipairs(def.Inherit) do add(parent) end
	end
	add(islandId)
	table.sort(list, function(x, y) return x.OneIn > y.OneIn end)
	poolCache[islandId] = list
	return list
end

-- the exact algorithm the server uses: rarest first, each weapon hits with
-- probability 1 / EffectiveOneIn; nothing hit -> the starter weapon
function E.RollAltar(rng, islandId, luck)
	for _, w in ipairs(E.AltarPool(islandId)) do
		if rng:NextNumber() * E.EffectiveOneIn(w, luck) < 1 then return w end
	end
	return Config.WeaponById[Config.StarterWeapon]
end

-- EXACT per-weapon probabilities of one roll at this luck (sums to 1 incl. the starter)
-- returns { {Weapon = def, P = prob}, ... } rarest first, plus byRarity totals
function E.AltarOdds(islandId, luck)
	local survive, list, byRarity = 1, {}, {}
	for _, w in ipairs(E.AltarPool(islandId)) do
		local p = survive / E.EffectiveOneIn(w, luck)
		table.insert(list, { Weapon = w, P = p })
		byRarity[w.Rarity] = (byRarity[w.Rarity] or 0) + p
		survive -= p
	end
	local starter = Config.WeaponById[Config.StarterWeapon]
	table.insert(list, { Weapon = starter, P = survive })
	byRarity[starter.Rarity] = (byRarity[starter.Rarity] or 0) + survive
	return list, byRarity
end

-- M2: the island (altar) a weapon belongs to, and its exact odds there for one roll
function E.WeaponIsland(w)
	return w and Config.AreaIsland and Config.AreaIsland[w.Area] or nil
end
function E.WeaponOdds(weaponId, luck)
	local w = Config.WeaponById[weaponId]
	local isl = E.WeaponIsland(w)
	if not (w and isl and EC.Altars[isl]) or w.Exclusive or not w.OneIn then return nil, isl end
	for _, o in ipairs((E.AltarOdds(isl, luck or 1))) do
		if o.Weapon.Id == weaponId then return o.P, isl end
	end
	return nil, isl
end

-- M2: Altar Essence day key (UTC) for the daily cap
function E.EssenceDay(t)
	return math.floor((t or os.time()) / 86400)
end

--------------------------------------------------------------------
-- Progression tier pricing (replaces BestArea pricing, audit M4)
--------------------------------------------------------------------
local ISL_INDEX = {}
for i, id in ipairs(EC.IslandOrder) do ISL_INDEX[id] = i end
E.IslandIndex = ISL_INDEX

function E.HighestIsland(unlocked)
	local best = 1
	for id, on in pairs(unlocked or {}) do
		if on and ISL_INDEX[id] and ISL_INDEX[id] > best then best = ISL_INDEX[id] end
	end
	return EC.IslandOrder[best], best
end

-- tier = highest tier whose Power band the player's BEST weapon reaches AND whose island they can enter
function E.PriceTier(bestPower, unlocked)
	local _, access = E.HighestIsland(unlocked)
	local tier = EC.PriceTiers[1]
	for _, t in ipairs(EC.PriceTiers) do
		if num(bestPower) >= t.MinPower and ISL_INDEX[t.MaxIsland] <= access then tier = t end
	end
	return tier
end

function E.Price(item, unit)
	return math.floor(num(EC.Prices[item]) * num(unit))
end

function E.RebirthCost(n, unit)
	local R = EC.Rebirth
	return math.max(R.MinCost, math.floor(R.Units * R.Growth ^ num(n) * num(unit)))
end

-- Logs reward expressed in units ("Mult") -> Logs at this unit
function E.UnitReward(mult, unit)
	return math.floor(num(mult) * num(unit))
end

--------------------------------------------------------------------
-- Island gates (staged): Power + active requirements. "planned" requirements are
-- shown but never block (their content is not built yet).
-- gctx = { BestPower, BossKills = {[boss]=n}, TreesByArea = {[area]=n} }
--------------------------------------------------------------------
function E.GateStatus(islandId, gctx)
	local g = EC.Gates[islandId]
	if not g then return true, {} end
	local list = {}
	local ok = num(gctx.BestPower) >= g.Power
	table.insert(list, { Id = "power", Text = string.format("Reach %s Power", Config.FormatNumber(g.Power)),
		Have = math.floor(num(gctx.BestPower)), Need = g.Power, Met = num(gctx.BestPower) >= g.Power, Stage = "active" })
	for _, r in ipairs(g.Requirements) do
		local have = 0
		if r.Kind == "BossKills" then
			have = num(gctx.BossKills and gctx.BossKills[r.Boss])
		elseif r.Kind == "TreesInAreas" then
			for _, a in ipairs(r.Areas) do have += num(gctx.TreesByArea and gctx.TreesByArea[a]) end
		end
		local met = have >= r.Count
		local stage = r.Id == "colossus" and workspace:GetAttribute("M4ColossusReady") == true and "active" or r.Stage
		table.insert(list, { Id = r.Id, Text = string.format(r.Text, r.Count), Have = have, Need = r.Count, Met = met, Stage = stage })
		if stage == "active" and not met then ok = false end
	end
	return ok, list
end

-- trees chopped per legacy area from the tree index counts
function E.TreesByArea(trees)
	local out = {}
	for id, n in pairs(trees or {}) do
		local tt = Config.TreeTypes[id]
		if tt then out[tt.Area] = (out[tt.Area] or 0) + num(n) end
	end
	return out
end

--------------------------------------------------------------------
-- Bosses: tier-scaled rewards for every eligible participant (co-op friendly)
--------------------------------------------------------------------
-- Logs = LogsUnits x Unit(tier) x LogMultBase ^ LogMultExponent: grows with the player's
-- permanent progress like chopping does (dampened), so active play stays worth ~1/3 more
function E.BossReward(bossId, unit, share, isTop, logMultBase)
	local b = EC.Bosses[bossId] or Layout.Bosses[bossId]
	share = math.clamp(num(share), 0, 1)
	local scale = math.max(num(logMultBase), 1) ^ (EC.Bosses.LogMultExponent or 0)
	return {
		Logs = math.floor(b.LogsUnits * num(unit) * scale),
		Souls = math.floor(b.Souls + (b.SoulsTop - b.Souls) * share),
		Crates = (b.Crates or 0) + ((isTop and b.Crates) and 1 or 0),
	}
end

--------------------------------------------------------------------
-- M5 reward values are tier Units and bounded raw currency. The callers own
-- their daily/weekly budgets and record claims before entering this calculation.
function E.M5Reward(unit,plan)
	return {
		Logs=math.floor(math.max(0,num(unit))*math.clamp(num(plan.Logs),0,3)),
		Souls=math.floor(math.clamp(num(plan.Souls),0,75)),
		XP=math.floor(math.clamp(num(plan.XP),0,750)),
		Materials=math.floor(math.clamp(num(plan.Materials),0,4)),
	}
end

-- Index editions (H5): completion is recorded per edition and never revoked.
-- editions = { ["Weapon/<area>/Standard/1"] = true, ... }
--------------------------------------------------------------------
function E.IndexBonus(editions)
	local I = EC.Index
	local logs, luck = 0, 0
	for key, on in pairs(editions or {}) do
		if on then
			local kind, area, part, ed = string.match(key, "^(%a+)/([%w_]+)/(%a+)/(%d+)$")
			local def = kind == "Weapon" and Config.IndexEditions.Weapon[area] and Config.IndexEditions.Weapon[area][tonumber(ed)]
			-- M2: later editions (the expansion weapons) pay a reduced share (EditionScale)
			local es = (I.EditionScale and I.EditionScale[tonumber(ed) or 1]) or (I.EditionScale and I.EditionScale[#I.EditionScale]) or 1
			if kind == "Weapon" and part == "Standard" then
				logs += I.WeaponStandard.Logs * es luck += I.WeaponStandard.Luck * es
				if def and def.StandardBonusFull then -- an area with no separate Mastery set
					logs += I.WeaponMastery.Logs * es luck += I.WeaponMastery.Luck * es
				end
			elseif kind == "Weapon" and part == "Mastery" then
				logs += I.WeaponMastery.Logs * es luck += I.WeaponMastery.Luck * es
			elseif kind == "Tree" then
				logs += I.Tree.Logs
			end
		end
	end
	return { Logs = logs, Luck = luck }
end

return E
