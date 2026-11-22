-- M1Tests: quick unit checks for the M1 economy (Studio only, never runs by itself).
--   require(game.ServerStorage.M1Tests).RunAll()
-- E1 compares ReplicatedStorage.Economy with GOLDEN values produced by the balance
-- simulator's own formulas (tools/econsim/golden.py), so game and model cannot drift.
-- The save checks build profiles in memory only (no DataStore writes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local T = {}

local G = {
	soft_2_6 = 1.7008121365572644,
	soft_10_3 = 2.892978019958243,
	logs_dev_base = 3.37321408118159,
	logs_dev_event2 = 6.74642816236318,
	logs_max_base = 42.94305446654813,
	luck_dev = 2.578052109371577,
	luck_max_mega = 50,
	eff_divine_50 = 1414213.562373095,
	eff_myth_10 = 177827.94100389228,
	pool_TimberHaven = 39, -- M2: +15
	pool_CrystalWilds = 77, -- M2: +28 (+15 inherited)
	pool_FrostboundReach = 115, -- M2: every rollable weapon
	p_th_luck1_rarest = 8.333333333333334e-08, -- M2: Hearthforge Sovereign (1 in 12M)
	th_rarest_id = "HearthforgeSovereign",
	p_cw_luck10_sum = 0.9937674786267635,
	rebirth_2_12M = 238050000,
	cost_walk_24 = 1807091,
	cost_luck_0 = 1500,
	cost_renewal_19 = 2910261,
	king_12M_half_lm4 = 8400000,
}

local function suite(name)
	local s = { name = name, pass = 0, fail = 0, lines = {} }
	function s.check(id, cond, detail)
		if cond then s.pass += 1 else s.fail += 1 end
		table.insert(s.lines, (cond and "PASS " or "FAIL ") .. id .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
	return s
end
local function near(a, b, rel) rel = rel or 1e-9 return math.abs(a - b) <= math.max(math.abs(b) * rel, 1e-12) end

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

--------------------------------------------------------------------
function T.E1()
	local E = require(ReplicatedStorage.Economy)
	local Config = require(ReplicatedStorage.BladeConfig)
	local s = suite("E1 Economy formulas vs simulator (golden values)")
	s.check("E1.1 soft caps", near(E.soft(2, 6), G.soft_2_6) and near(E.soft(10, 3), G.soft_10_3) and E.soft(0, 6) == 0 and E.soft(0 / 0, 6) == 0)
	local passes = { ["2xLogs"] = true, VIP = true }
	local dev = { Levels = {}, Rebirths = 2, TraitMult = 1, Pets = {}, Passes = passes, Boosts = {}, Now = 100, EventLogs = 1,
		IndexBonus = { Logs = 0.05, Luck = 0 } }
	local b = E.LogsBreakdown(dev)
	s.check("E1.2 dev-like Logs multiplier", near(b.Base, G.logs_dev_base) and near(b.Total, G.logs_dev_base), b.Base)
	dev.EventLogs = 2
	dev.Boosts = { LogBoost = 1000 }
	dev.PvP = true
	local b2 = E.LogsBreakdown(dev)
	s.check("E1.3 temporary sources never stack (event x2 + Log Boost x2 + PvP x1.5 = x2)", near(b2.Total, G.logs_dev_event2) and b2.Temp == 2, b2.Temp)
	local dragon, root = Config.PetById.Dragon, nil
	for _, t in ipairs(Config.Traits) do if t.Id == "AncientRoot" then root = t end end
	local I = Config.Economy.Index
	local max = { Levels = {}, Rebirths = 20, TraitMult = root.Mult, Pets = { dragon, dragon, dragon }, Passes = {}, Boosts = {}, Now = 0,
		SoulUpgrades = { SoulBlessing = 20 }, IndexBonus = { Logs = 4 * (I.WeaponStandard.Logs + I.WeaponMastery.Logs) + 4 * I.Tree.Logs, Luck = 0 } }
	s.check("E1.4 max free build Logs (pools soft-capped)", near(E.LogsBreakdown(max).Base, G.logs_max_base, 1e-9), E.LogsBreakdown(max).Base)
	local ldev = E.LuckBreakdown({ Levels = {}, Rebirths = 2, InGroup = true, Passes = { ["2xLuck"] = true }, Pets = {}, Boosts = {}, Now = 0, EventLuck = 1 })
	s.check("E1.5 dev-like Luck", near(ldev.Total, G.luck_dev), ldev.Total)
	local lmax = E.LuckBreakdown({ Levels = { Luck = 100 }, Rebirths = 20, InGroup = true, Passes = { ["2xLuck"] = true }, Pets = { dragon, dragon, dragon },
		Boosts = { MegaLuckPotion = 1000 }, Now = 0, EventLuck = 5, SoulUpgrades = { SoulFortune = 20 },
		IndexBonus = { Luck = 4 * (I.WeaponStandard.Luck + I.WeaponMastery.Luck) } })
	s.check("E1.6 luck hard cap x50 (Mega Luck + Blood Moon do not stack)", lmax.Total == G.luck_max_mega and lmax.Temp == 10, lmax.Total)
	s.check("E1.7 lucky roll still capped", E.RollLuck(40, true) == 50 and E.RollLuck(3, true) == 6)
	local divine = { OneIn = 10000000, Rarity = "Divine" }
	local myth = { OneIn = 1000000, Rarity = "Mythic" }
	s.check("E1.8 rarer tiers feel luck less (gamma)", near(E.EffectiveOneIn(divine, 50), G.eff_divine_50) and near(E.EffectiveOneIn(myth, 10), G.eff_myth_10)
		and E.EffectiveOneIn({ OneIn = 5, Rarity = "Common" }, 50) == 5)
	s.check("E1.9 Config.EffectiveOneIn matches Economy", near(Config.EffectiveOneIn(divine, 50), G.eff_divine_50))
	s.check("E1.10 rebirth cost tier-scaled", math.abs(E.RebirthCost(2, 12e6) - G.rebirth_2_12M) <= 1 and E.RebirthCost(0, 750) == Config.Economy.Rebirth.MinCost, E.RebirthCost(2, 12e6))
	s.check("E1.11 upgrade costs", E.UpgradeCost("WalkSpeed", 24) == G.cost_walk_24 and E.UpgradeCost("Luck", 0) == G.cost_luck_0
		and E.UpgradeCost("Renewal", 19) == G.cost_renewal_19 and Config.GetCost("WalkSpeed", 24) == G.cost_walk_24)
	local kr = E.BossReward("BladeKing", 12e6, 0.5, false, 4)
	s.check("E1.12 Blade King reward (tier unit, grows with sqrt(base LogMult))", kr.Logs == G.king_12M_half_lm4 and kr.Souls == 32, kr.Logs .. "/" .. kr.Souls)
	return s
end

--------------------------------------------------------------------
function T.E2()
	local E = require(ReplicatedStorage.Economy)
	local Config = require(ReplicatedStorage.BladeConfig)
	local s = suite("E2 altars and exact odds")
	for _, isl in ipairs(Config.Economy.IslandOrder) do
		s.check("E2.1 pool size " .. isl, #E.AltarPool(isl) == G["pool_" .. isl], #E.AltarPool(isl))
	end
	local th = E.AltarPool("TimberHaven")
	local frostAtTH = false
	for _, w in ipairs(th) do if w.Area == "CrystalCanyon" or w.Area == "FrostPeaks" then frostAtTH = true end end
	s.check("E2.2 Timber Haven altar: only Starter Grove + Pine Forest weapons", not frostAtTH and th[1].Id == G.th_rarest_id)
	local all = {}
	for _, w in ipairs(E.AltarPool("FrostboundReach")) do all[w.Id] = true end
	local missing = 0
	for _, w in ipairs(Config.RollPool) do if not all[w.Id] then missing += 1 end end
	s.check("E2.3 every rollable weapon is still obtainable (Frostbound altar = all rollable)", missing == 0, missing)
	local odds, byR = E.AltarOdds("TimberHaven", 1)
	local sum = 0
	for _, o in ipairs(odds) do sum += o.P end
	s.check("E2.4 odds sum to exactly 1", near(sum, 1, 1e-12), sum)
	s.check("E2.5 rarest Timber Haven weapon at luck 1", near(odds[1].P, G.p_th_luck1_rarest, 1e-9), odds[1].P)
	local o10 = E.AltarOdds("CrystalWilds", 10)
	local nonStarter = 0
	for _, o in ipairs(o10) do if o.Weapon.Id ~= Config.StarterWeapon then nonStarter += o.P end end
	s.check("E2.6 Crystal Wilds odds at luck 10 match the simulator", near(nonStarter, G.p_cw_luck10_sum, 1e-9), nonStarter)
	-- empirical: the roll function draws exactly the displayed odds
	local rng = Random.new(42)
	local N, counts = 200000, {}
	for _ = 1, N do
		local w = E.RollAltar(rng, "TimberHaven", 1)
		counts[w.Id] = (counts[w.Id] or 0) + 1
	end
	local worst, worstId = 0, nil
	for _, o in ipairs(odds) do
		if o.P > 0.02 then
			local z = math.abs((counts[o.Weapon.Id] or 0) / N - o.P) / math.sqrt(o.P * (1 - o.P) / N)
			if z > worst then worst, worstId = z, o.Weapon.Id end
		end
	end
	s.check("E2.7 200k rolls follow the displayed odds (max |z| < 4.5)", worst < 4.5, string.format("%.2f %s", worst, tostring(worstId)))
	s.check("E2.8 rarity totals add up", near((byR.Common or 0) + (byR.Uncommon or 0) + (byR.Rare or 0) + (byR.Epic or 0) + (byR.Legendary or 0)
		+ (byR.Mythic or 0) + (byR.Secret or 0) + (byR.Divine or 0), 1, 1e-12))
	return s
end

--------------------------------------------------------------------
function T.E3()
	local E = require(ReplicatedStorage.Economy)
	local Config = require(ReplicatedStorage.BladeConfig)
	local s = suite("E3 progression tiers, gates, movement, renewal, index editions")
	local all = { TimberHaven = true, CrystalWilds = true, FrostboundReach = true }
	s.check("E3.1 price tier: dev profile (Power 1,834, all islands) = Crystal II", E.PriceTier(1834, all).Tier == 4)
	s.check("E3.2 tier capped by island access (Power 2,500, no Frostbound)", E.PriceTier(2500, { TimberHaven = true, CrystalWilds = true }).Tier == 4)
	s.check("E3.3 tier follows Power, not BestArea (Power 2,500 + Frostbound = Frost I)", E.PriceTier(2500, all).Tier == 5)
	s.check("E3.4 Config.GetTraitCrateCost(number unit)", Config.GetTraitCrateCost(12e6) == 12e6 and Config.GetEggCost(12e6) == 18e6)
	s.check("E3.5 legacy area pricing still answers", Config.GetTraitCrateCost("PineForest") == 25000)
	local ok1, l1 = E.GateStatus("CrystalWilds", { BestPower = 300, BossKills = {}, TreesByArea = { StarterGrove = 400, PineForest = 300 } })
	local ok2 = E.GateStatus("CrystalWilds", { BestPower = 300, BossKills = { BladeKing = 1 }, TreesByArea = { StarterGrove = 400, PineForest = 300 } })
	local ok3 = E.GateStatus("CrystalWilds", { BestPower = 200, BossKills = { BladeKing = 1 }, TreesByArea = { PineForest = 900 } })
	s.check("E3.6 Crystal Wilds gate: Power 250 + Blade King + 600 Timber Haven trees", not ok1 and ok2 and not ok3 and #l1 == 3)
	local okF, lF = E.GateStatus("FrostboundReach", { BestPower = 2100, BossKills = {}, TreesByArea = { CrystalCanyon = 6000 } })
	local planned
	for _, r in ipairs(lF) do if r.Id == "colossus" then planned = r end end
	local active = workspace:GetAttribute("M4ColossusReady") == true
	local credited = E.GateStatus("FrostboundReach", { BestPower = 2100, BossKills = { CrystalColossus = 1 }, TreesByArea = { CrystalCanyon = 6000 } })
	s.check("E3.7 Frostbound gate: require Colossus credit when the encounter is ready",
		planned and not planned.Met and planned.Stage == (active and "active" or "planned") and okF == not active and credited)
	s.check("E3.8 walk speed 16 -> 24 over 25 levels, future mobility capped +4",
		E.WalkSpeed({}, 0) == 16 and near(E.WalkSpeed({ WalkSpeed = 10 }, 0), 19.2) and E.WalkSpeed({ WalkSpeed = 25 }, 0) == 24
		and E.WalkSpeed({ WalkSpeed = 99 }, 0) == 24 and E.WalkSpeed({ WalkSpeed = 25 }, 10) == 28 and E.MaxLegitWalkSpeed() == 28)
	local r1, a1 = E.RenewedRespawn(8, "Common", 20)
	local r2, a2 = E.RenewedRespawn(90, "Legendary", 20)
	local r3 = E.RenewedRespawn(4, "Common", 20)
	s.check("E3.9 Forest Renewal: -40% at max for Common..Epic, never Legendary+, min 3 s",
		near(r1, 4.8) and a1 and r2 == 90 and not a2 and r3 == 3 and E.RenewalReduction(10) == 0.2)
	local ib = E.IndexBonus({ ["Weapon/StarterGrove/Standard/1"] = true, ["Weapon/StarterGrove/Mastery/1"] = true,
		["Weapon/FrostPeaks/Standard/1"] = true, ["Tree/CrystalCanyon/All/1"] = true })
	s.check("E3.10 index editions: full area = +10%/+10% (Frost's Divines are its standard set), tree +5%",
		near(ib.Luck, 0.20) and near(ib.Logs, 0.25), ib.Luck .. "/" .. ib.Logs)
	-- MovementGuard accepts upgraded walking, still catches speed hacks above the upgrade
	local MG = require(SSS.MovementGuard)
	local g = MG.new()
	local flags, flags2 = 0, 0
	for i = 1, 400 do
		if not g:Check("w24", { X = i * 0.05 * 24, Z = 0 }, 24, i * 0.05) then flags += 1 end
		if not g:Check("h48", { X = i * 0.05 * 48, Z = 0 }, 24, i * 0.05) then flags2 += 1 end
	end
	s.check("E3.11 MovementGuard: 24 studs/s with WalkSpeed 24 never flagged; 2x (48) flagged", flags == 0 and flags2 > 0, flags .. "/" .. flags2)
	return s
end

--------------------------------------------------------------------
-- save compatibility: the real dev profile snapshot (taken at the M1 checkpoint) built
-- through the M1 DataService in memory. Nothing is written anywhere.
function T.E4()
	local DataService = require(SSS.DataService)
	local s = suite("E4 save compatibility (dev profile snapshot, in memory)")
	local snap = game.ServerStorage:FindFirstChild("M1Backups") and game.ServerStorage.M1Backups:FindFirstChild("DevProfileSnapshot_p_394034825")
	if not snap then s.check("E4.0 snapshot present", false) return s end
	local raw = HttpService:JSONDecode(snap.Value)
	local before = deepCopy(raw)
	local ok, d, how = DataService.BuildProfile(raw, nil, nil)
	s.check("E4.1 builds without migration (still v4)", ok and d.Version == 4 and how == "current", tostring(how))
	s.check("E4.2 currencies unchanged", d.Logs == before.Logs and d.Souls == before.Souls and (d.FreeCrates or 0) == (before.FreeCrates or 0)
		and d.Rebirths == before.Rebirths, d.Logs)
	local lost = 0
	for id in pairs(before.Weapons or {}) do if not d.Weapons[id] then lost += 1 end end
	s.check("E4.3 no weapon lost (" .. (function() local n = 0 for _ in pairs(before.Weapons) do n += 1 end return n end)() .. " owned)", lost == 0, lost)
	local same = true
	for k, v in pairs(before) do
		if k ~= "_Session" and k ~= "_WriteSeq" and HttpService:JSONEncode(v) ~= HttpService:JSONEncode(d[k]) then
			-- reconcile may only ADD keys inside tables; check old leaves are still equal
			if type(v) == "table" and type(d[k]) == "table" then
				for kk, vv in pairs(v) do
					if HttpService:JSONEncode(vv) ~= HttpService:JSONEncode(d[k][kk]) then same = false end
				end
			else
				same = false
			end
		end
	end
	s.check("E4.4 every existing value preserved (purchases, codes, upgrades, islands...)", same)
	s.check("E4.5 new M1 fields default (additive)", type(d.IndexEditions) == "table" and type(d.SoulUpgrades) == "table" and type(d.BossKills) == "table"
		and type(d.AltarRolls) == "table" and type(d.AltarGuarantee) == "table")
	local legacyIdx = 0
	for area, on in pairs(before.IndexDone or {}) do if on then legacyIdx += 1 end end
	local edCount = 0
	for _ in pairs(d.IndexEditions) do edCount += 1 end
	s.check("E4.6 legacy index completions became permanent edition records", legacyIdx == 0 or edCount >= legacyIdx, legacyIdx .. " -> " .. edCount)
	local ok2, round = pcall(function() return HttpService:JSONDecode(HttpService:JSONEncode(d)) end)
	s.check("E4.7 profile still JSON-encodable", ok2 and round.Logs == d.Logs)
	-- legacy-index fixture
	local fx = deepCopy(before)
	fx.IndexDone = { FrostPeaks = true, StarterGrove = true }
	fx.TreeIndexDone = { PineForest = true }
	fx.IndexEditions = nil
	local okF, dF = DataService.BuildProfile(fx, nil, nil)
	local Economy = require(ReplicatedStorage.Economy)
	local bonus = Economy.IndexBonus(dF.IndexEditions)
	s.check("E4.8 old completions keep their old +10%/+10% each (no revocation)", okF and near(bonus.Luck, 0.20) and near(bonus.Logs, 0.25),
		bonus.Luck .. "/" .. bonus.Logs)
	return s
end

function T.RunAll()
	local out, P, F = {}, 0, 0
	for _, name in ipairs({ "E1", "E2", "E3", "E4" }) do
		local ok, res = pcall(T[name])
		if ok then
			P += res.pass F += res.fail
			table.insert(out, "== " .. res.name .. ": " .. res.pass .. " pass, " .. res.fail .. " fail")
			for _, l in ipairs(res.lines) do table.insert(out, "  " .. l) end
		else
			F += 1
			table.insert(out, "== ERROR in " .. name .. ": " .. tostring(res))
		end
	end
	table.insert(out, 1, ("M1 tests: %d pass, %d fail"):format(P, F))
	return table.concat(out, "\n"), P, F
end

return T
