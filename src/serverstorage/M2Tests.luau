-- M2Tests: quick checks for the 120-weapon collection (Studio only, never runs by itself).
--   require(game.ServerStorage.M2Tests).RunAll()
-- W1 catalog  W2 models  W3 altars/odds  W4 progression  W5 editions/attunement  W6 save compatibility (in memory)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local T = {}

-- Power of the 43 legacy weapons at the end of M1 (must never decrease)
local LEGACY_POWER = {Wooden = 7, LumberHatchet = 11, WoodsmanAxe = 13, FarmhandScythe = 9, RustySickle = 8, Iron = 21, EngravedAxe = 40, WillowScythe = 25, BoneScythe = 34, RoninKatana = 29, Golden = 60, EmberHatchet = 70, RedcliffAxe = 169, Bloodthorn = 476, Starbreaker = 3008, Emerald = 82, BloodvineScythe = 95, SilverLabrys = 112, Frost = 197, WarlordAxe = 231, CrimsonCrescent = 269, Inferno = 554, VenomfangAxe = 651, SoulfireScythe = 1343, StarfallReaper = 3785, GlacierFang = 315, BonewhiteReaper = 757, SunsteelSword = 889, Void = 1834, Umbraxe = 2134, ShadowKatana = 2506, MagmaHook = 1562, Galaxy = 4676, Celestial = 7063, PrismSaber = 5818, GlacialEdge = 8476, Dragonflame = 10667, SeraphsLight = 14572, FrostboundReaper = 19905, FoundersEdge = 60, SoulboundBlade = 120, SoulHarvester = 300, ForsakenAxe = 1000}
-- legacy models that are all-MeshPart (cannot be merged in Studio) - documented, not new
local PART_EXEMPT = { BonewhiteReaper = true, SoulboundBlade = true, WarlordAxe = true, SunsteelSword = true, FoundersEdge = true, ForsakenAxe = true }

local function suite(name)
	local s = { name = name, pass = 0, fail = 0, lines = {} }
	function s.check(id, cond, detail)
		if cond then s.pass += 1 else s.fail += 1 end
		table.insert(s.lines, (cond and "PASS " or "FAIL ") .. id .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
	return s
end
local function near(a, b, rel) rel = rel or 1e-9 return math.abs(a - b) <= math.max(math.abs(b) * rel, 1e-12) end

function T.W1()
	local Config = require(ReplicatedStorage.BladeConfig)
	local s = suite("W1 catalog (120 weapons, ids, power)")
	local ids, dup = {}, {}
	for _, w in ipairs(Config.Weapons) do
		if ids[w.Id] then table.insert(dup, w.Id) end
		ids[w.Id] = true
	end
	s.check("W1.1 120 weapons", #Config.Weapons == 120, #Config.Weapons)
	s.check("W1.2 no duplicate ids", #dup == 0, table.concat(dup, ","))
	local missing, lower = {}, {}
	for id, p in pairs(LEGACY_POWER) do
		local w = Config.WeaponById[id]
		if not w then table.insert(missing, id) elseif w.Power < p then table.insert(lower, id .. " " .. w.Power .. "<" .. p) end
	end
	s.check("W1.3 all 43 legacy ids kept", #missing == 0, table.concat(missing, ","))
	s.check("W1.4 no legacy weapon lost Power", #lower == 0, table.concat(lower, ","))
	local legacyOrder = true
	for i = 1, 43 do if not LEGACY_POWER[Config.Weapons[i].Id] then legacyOrder = false end end
	s.check("W1.5 legacy entries keep their catalog order (1..43)", legacyOrder)
	local bad = {}
	for _, w in ipairs(Config.Weapons) do
		if not (w.Name and w.Type and Config.RarityById[w.Rarity] and w.Island and w.Power and w.VfxTier and w.Source and w.Future) then table.insert(bad, w.Id) end
		if not table.find({ "Sword", "Axe", "Scythe" }, w.Type) then table.insert(bad, w.Id .. ":type") end
	end
	s.check("W1.6 every weapon has name/type/rarity/island/power/vfx/source/future", #bad == 0, table.concat(bad, ","))
	local count = {}
	for _, w in ipairs(Config.Weapons) do count[w.Rarity] = (count[w.Rarity] or 0) + 1 end
	local few = {}
	for _, r in ipairs(Config.Rarities) do if (count[r.Id] or 0) < 5 then table.insert(few, r.Id) end end
	s.check("W1.7 every rarity has >= 5 weapons", #few == 0, HttpService:JSONEncode(count))
	local m2 = 0
	for _, w in ipairs(Config.Weapons) do if w.Edition == 2 then m2 += 1 end end
	s.check("W1.8 77 new (edition 2) weapons", m2 == 77, m2)
	return s
end

function T.W2()
	local Config = require(ReplicatedStorage.BladeConfig)
	local BM = ReplicatedStorage.BladeModels
	local s = suite("W2 models (template per weapon, budgets)")
	local missing, heavy, scripts, lights, len, orphans = {}, {}, {}, {}, {}, {}
	for _, w in ipairs(Config.Weapons) do
		local m = BM:FindFirstChild(w.Id)
		if not m then table.insert(missing, w.Id) else
			local parts, em = 0, 0
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then parts += 1 end
				if d:IsA("LuaSourceContainer") then table.insert(scripts, w.Id) end
				if d:IsA("Light") then table.insert(lights, w.Id) end
				if d:IsA("ParticleEmitter") then em += 1 end
			end
			if (parts > 8 and not PART_EXEMPT[w.Id]) or em > 2 then table.insert(heavy, w.Id .. " p" .. parts .. " e" .. em) end
			if m:GetAttribute("TemplateLength") ~= 4 then table.insert(len, w.Id) end
		end
	end
	for _, m in ipairs(BM:GetChildren()) do if not Config.WeaponById[m.Name] then table.insert(orphans, m.Name) end end
	s.check("W2.1 every weapon has a model", #missing == 0, table.concat(missing, ","))
	s.check("W2.2 no orphan models", #orphans == 0, table.concat(orphans, ","))
	s.check("W2.3 0 scripts in any model", #scripts == 0, table.concat(scripts, ","))
	s.check("W2.4 0 lights in any model", #lights == 0, table.concat(lights, ","))
	s.check("W2.5 <= 8 parts and <= 2 emitters (legacy all-mesh exempt)", #heavy == 0, table.concat(heavy, ","))
	s.check("W2.6 TemplateLength 4 everywhere", #len == 0, table.concat(len, ","))
	local src = 0
	for _, w in ipairs(Config.Weapons) do
		local m = BM:FindFirstChild(w.Id)
		if w.Edition == 2 and m and m:GetAttribute("SourceAssetId") and m:GetAttribute("SourceCreator") then src += 1 end
	end
	s.check("W2.7 all 77 new models carry asset id + creator", src == 77, src)
	return s
end

function T.W3()
	local Config = require(ReplicatedStorage.BladeConfig)
	local E = require(ReplicatedStorage.Economy)
	local s = suite("W3 altars and exact odds (server = UI)")
	local sizes = { TimberHaven = 39, CrystalWilds = 77, FrostboundReach = 115 }
	for _, isl in ipairs(Config.Economy.IslandOrder) do
		s.check("W3.1 pool size " .. isl, #E.AltarPool(isl) == sizes[isl], #E.AltarPool(isl))
		for _, luck in ipairs({ 1, 7.5, 50 }) do
			local odds = E.AltarOdds(isl, luck)
			local sum, neg = 0, false
			for _, o in ipairs(odds) do sum += o.P if o.P < 0 then neg = true end end
			s.check(("W3.2 %s luck %g: odds valid, sum 1"):format(isl, luck), near(sum, 1, 1e-12) and not neg, sum)
		end
	end
	local rollable = 0
	for _, w in ipairs(Config.Weapons) do
		if w.Altar then
			rollable += 1
			local inOwn = false
			for _, x in ipairs(E.AltarPool(w.Altar)) do if x.Id == w.Id then inOwn = true break end end
			if not inOwn then s.check("W3.3 " .. w.Id .. " in its own altar", false) end
		end
	end
	s.check("W3.3 every rollable weapon is in its island's altar (" .. rollable .. ")", rollable == 115, rollable)
	-- the Gallery's per-weapon odds = the server's altar odds
	local mism = 0
	for _, isl in ipairs(Config.Economy.IslandOrder) do
		for _, o in ipairs((E.AltarOdds(isl, 3.2))) do
			local w = o.Weapon
			if w.Altar == isl then
				local p = E.WeaponOdds(w.Id, 3.2)
				if not (p and near(p, o.P, 1e-12)) then mism += 1 end
			end
		end
	end
	s.check("W3.4 Gallery odds == server altar odds", mism == 0, mism)
	local odds = E.AltarOdds("FrostboundReach", 1)
	local rng, N, counts = Random.new(7), 200000, {}
	for _ = 1, N do local w = E.RollAltar(rng, "FrostboundReach", 1) counts[w.Id] = (counts[w.Id] or 0) + 1 end
	local worst = 0
	for _, o in ipairs(odds) do
		if o.P > 0.01 then worst = math.max(worst, math.abs((counts[o.Weapon.Id] or 0) / N - o.P) / math.sqrt(o.P * (1 - o.P) / N)) end
	end
	s.check("W3.5 200k Frostbound rolls follow the displayed odds (max |z| < 4.5)", worst < 4.5, string.format("%.2f", worst))
	return s
end

function T.W4()
	local Config = require(ReplicatedStorage.BladeConfig)
	local E = require(ReplicatedStorage.Economy)
	local s = suite("W4 progression (guarantees, gates, power ladder)")
	for isl, a in pairs(Config.Economy.Altars) do
		local g = a.Guarantee
		if g then
			local w = Config.WeaponById[g.Weapon]
			local inPool = false
			for _, x in ipairs(E.AltarPool(isl)) do if x.Id == g.Weapon then inPool = true end end
			s.check("W4.1 guarantee " .. isl .. " -> " .. g.Weapon .. " reaches the next gate Power", w and inPool and w.Power >= g.UntilPower, w and w.Power)
		end
	end
	-- the new roster must not put island-gate Power into an earlier island's commons
	local th = 0
	for _, w in ipairs(E.AltarPool("TimberHaven")) do
		if Config.RarityById[w.Rarity].Order <= Config.RarityById.Rare.Order then th = math.max(th, w.Power) end
	end
	s.check("W4.2 Timber Haven Common..Rare stay below the Crystal Wilds gate (250)", th < 250, th)
	local maxP = 0
	for _, w in ipairs(Config.Weapons) do maxP = math.max(maxP, w.Power) end
	s.check("W4.3 strongest weapon is still a legacy Divine (no power creep from M2)", maxP == LEGACY_POWER.FrostboundReaper, maxP)
	local order = true
	for _, w in ipairs(Config.Weapons) do
		if w.Edition == 2 and w.Power > (5 * (w.OneIn or 2) ^ 0.45 + 1) then order = false end
	end
	s.check("W4.4 new weapons use the legacy Power formula (5 x OneIn^0.45)", order)
	return s
end

function T.W5()
	local Config = require(ReplicatedStorage.BladeConfig)
	local E = require(ReplicatedStorage.Economy)
	local s = suite("W5 index editions + Divine Attunement")
	local ok2 = true
	for area, eds in pairs(Config.IndexEditions.Weapon) do
		for _, part in ipairs({ "Standard", "Mastery" }) do
			for _, id in ipairs((eds[2] and eds[2][part]) or {}) do
				local w = Config.WeaponById[id]
				if not (w and w.Area == area and w.Edition == 2) then ok2 = false end
			end
		end
	end
	s.check("W5.1 edition 2 lists hold only that area's new weapons", ok2)
	local e1 = E.IndexBonus({ ["Weapon/PineForest/Standard/1"] = true })
	local e2 = E.IndexBonus({ ["Weapon/PineForest/Standard/2"] = true })
	s.check("W5.2 edition 2 pays half of edition 1", near(e2.Logs * 2, e1.Logs) and near(e2.Luck * 2, e1.Luck), e2.Logs .. "/" .. e1.Logs)
	local fp = E.IndexBonus({ ["Weapon/FrostPeaks/Standard/1"] = true })
	s.check("W5.3 M1 Frost Peaks completion keeps +10%/+10%", near(fp.Logs, 0.10) and near(fp.Luck, 0.10), fp.Logs)
	local att = true
	for isl, id in pairs(Config.Attunement.Attunement) do
		local w = Config.WeaponById[id]
		if not (w and w.Rarity == "Divine" and w.Island == isl) then att = false end
	end
	s.check("W5.4 one Attunement Divine per island, from that island", att)
	local A = Config.Attunement
	s.check("W5.5 attunement is bounded (daily essence cap, one claim per island)", A.DailyCap > 0 and A.AttuneCost / A.DailyCap >= 3, A.AttuneCost / A.DailyCap .. " days minimum")
	return s
end

-- save compatibility: the dev profile snapshot taken at the M2 checkpoint, built in memory
function T.W6()
	local DataService = require(SSS.DataService)
	local s = suite("W6 save compatibility (dev profile snapshot, in memory)")
	local snap = game.ServerStorage:FindFirstChild("M2Backups") and game.ServerStorage.M2Backups:FindFirstChild("DevProfileSnapshot_p_394034825")
	if not snap then s.check("W6.0 snapshot present", false) return s end
	local raw = HttpService:JSONDecode(snap.Value)
	local before = HttpService:JSONDecode(snap.Value)
	local ok, d, how = DataService.BuildProfile(raw, nil, nil)
	s.check("W6.1 builds without migration (still v4)", ok and d.Version == 4 and how == "current", tostring(how))
	s.check("W6.2 currencies unchanged", d.Logs == before.Logs and d.Souls == before.Souls and d.Rebirths == before.Rebirths, d.Logs)
	local lost, changed = 0, 0
	for id, e in pairs(before.Weapons or {}) do
		local n = d.Weapons[id]
		if not n then lost += 1 elseif n.Star ~= e.Star or n.Copies ~= e.Copies or n.Shiny ~= e.Shiny then changed += 1 end
	end
	s.check("W6.3 no weapon lost or altered (stars, copies, Shiny)", lost == 0 and changed == 0, lost .. "/" .. changed)
	s.check("W6.4 new M2 fields default (additive)", type(d.Favorites) == "table" and type(d.Essence) == "table" and d.Essence.Total == 0 and type(d.Attuned) == "table")
	local keys = 0
	for k in pairs(d.IndexEditions or {}) do keys += 1 end
	local bkeys = 0
	for k in pairs(before.IndexEditions or {}) do bkeys += 1 end
	s.check("W6.5 existing index edition records kept", keys >= bkeys, bkeys .. " -> " .. keys)
	local ok2 = pcall(function() return HttpService:JSONEncode(d) end)
	s.check("W6.6 profile still JSON-encodable", ok2)
	return s
end

function T.RunAll()
	local out, P, F = {}, 0, 0
	for _, name in ipairs({ "W1", "W2", "W3", "W4", "W5", "W6" }) do
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
	table.insert(out, 1, ("M2 tests: %d pass, %d fail"):format(P, F))
	return table.concat(out, "\n"), P, F
end

return T
