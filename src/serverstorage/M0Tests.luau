-- M0Tests: deterministic test harness for M0 (Studio only, never runs by itself).
-- Usage from the command bar / MCP (Server or Edit context):
--   require(game.ServerStorage.M0Tests).RunAll()            -- mock-store unit tests
--   require(game.ServerStorage.M0Tests).RunDataStore(store)  -- same lock tests on a real
--                                                              throwaway DataStore
-- Uses synthetic fixtures plus (read-only) copies of authorized dev profiles passed in.
-- Mock results prove the LOGIC only; they are not cross-server evidence.

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = {}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end
local function json(t) return HttpService:JSONEncode(t) end
local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function roundtrip(t) if t == nil then return nil end return HttpService:JSONDecode(json(t)) end

--------------------------------------------------------------------
-- Mock DataStore (UpdateAsync/GetAsync semantics, JSON round trip, fault injection)
--------------------------------------------------------------------
function T.MockStore()
	local m = { data = {}, failNext = 0, calls = 0, writes = 0 }
	function m:UpdateAsync(key, fn)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("mock DataStore error (injected)")
		end
		local old = self.data[key]
		local new = fn(type(old) == "table" and roundtrip(old) or old)
		if new ~= nil then
			self.data[key] = roundtrip(new)
			self.writes += 1
		end
		return new
	end
	function m:GetAsync(key)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("mock DataStore error (injected)")
		end
		local v = self.data[key]
		return type(v) == "table" and roundtrip(v) or v
	end
	return m
end

local function newClock(start)
	local c = { now = start or 1000000 }
	function c.fn() return c.now end
	return c
end

--------------------------------------------------------------------
-- tiny assertion collector
--------------------------------------------------------------------
local function suite(name)
	local s = { name = name, pass = 0, fail = 0, lines = {} }
	function s.check(id, cond, detail)
		if cond then s.pass += 1 else s.fail += 1 end
		table.insert(s.lines, (cond and "PASS " or "FAIL ") .. id .. (detail and (" - " .. tostring(detail)) or ""))
	end
	return s
end

--------------------------------------------------------------------
-- T3 session locking (logic, mock store)
--------------------------------------------------------------------
function T.Locking(store, label, cycles)
	cycles = cycles or 50
	local SessionStore = require(ServerScriptService.SessionStore)
	local s = suite("T3 session locking (" .. (label or "mock store") .. ")")
	store = store or T.MockStore()
	local clock = newClock()
	local noWait = function() end
	local function mk(id) return SessionStore.new({ store = store, clock = clock.fn, wait = noWait, sessionId = id, jobId = "job-" .. id, placeId = 1, lockRetries = 3, log = function() end }) end
	local A, B = mk("A"), mk("B")
	local key = "m0t_" .. HttpService:GenerateGUID(false):sub(1, 8)

	local st, data, info = A:Acquire(key)
	s.check("T3.1 new profile acquire", st == "ok" and data == nil and info.New, st)
	local stB = B:Acquire(key)
	s.check("T3.2 duplicate session refused while lease fresh", stB == "locked", stB)
	s.check("T3.3 owner write while locked", A:Write(key, { Logs = 10 }) == "ok")
	clock.now += SessionStore.LEASE - 1
	s.check("T3.4 lease not yet expired -> still locked", B:Acquire(key) == "locked")
	-- A refreshes lease by writing; B still locked
	s.check("T3.5 lease refresh by autosave", A:Write(key, { Logs = 11 }) == "ok" and B:Acquire(key) == "locked")
	-- A crashes (no more writes); lease expires; B takes over
	clock.now += SessionStore.LEASE + 1
	local stT, dT, iT = B:Acquire(key)
	s.check("T3.6 stale lock recovery", stT == "ok" and iT.TookOverStale and dT and dT.Logs == 11, stT)
	-- stale A tries to save old snapshot -> must be rejected, B's data intact
	local stW = A:Write(key, { Logs = 999 })
	local rec = store:GetAsync(key)
	s.check("T3.7 stale session write rejected", stW == "lost" and rec.Logs == 11 and rec._Session.Id == "B", stW)
	-- B releases; A can acquire immediately
	s.check("T3.8 release clears lock", B:Write(key, { Logs = 12 }, true) == "ok" and store:GetAsync(key)._Session == nil)
	local stA2, dA2 = A:Acquire(key)
	s.check("T3.9 acquire after release", stA2 == "ok" and dA2.Logs == 12)
	-- write after release by B -> lost
	s.check("T3.10 released session cannot write", B:Write(key, { Logs = 0 }) == "lost" and store:GetAsync(key).Logs == 12)

	if type(store) == "table" and store.failNext ~= nil then -- fault injection: mock store only
		-- transient errors
		store.failNext = 2
		s.check("T3.11 save retry after transient errors", A:Write(key, { Logs = 13 }) == "ok" and store:GetAsync(key).Logs == 13)
		store.failNext = 50
		local stE = A:Write(key, { Logs = 14 })
		store.failNext = 0
		s.check("T3.12 outage -> error, record unchanged", stE == "error" and store:GetAsync(key).Logs == 13, stE)
		store.failNext = 50
		local stL = B:Acquire("m0t_outage")
		store.failNext = 0
		s.check("T3.13 load during outage -> error (caller fails closed)", stL == "error", stL)
		-- corrupt record
		store.data["m0t_corrupt"] = "not a table"
		s.check("T3.14 corrupt record refused and untouched", A:Acquire("m0t_corrupt") == "corrupt" and store.data["m0t_corrupt"] == "not a table")
	end

	-- 50 alternating sessions (logic simulation, NOT cross-server evidence)
	local ckey = key .. "_cycle"
	local servers = { mk("S1"), mk("S2"), mk("S3") }
	local okCycles, expected = 0, 0
	for i = 1, cycles do
		local srv = servers[(i % 3) + 1]
		local stc, dc = srv:Acquire(ckey)
		if stc == "ok" then
			dc = dc or { Counter = 0 }
			dc.Counter = (dc.Counter or 0) + 1
			expected += 1
			if srv:Write(ckey, dc, true) == "ok" then okCycles += 1 end
		end
	end
	local final = store:GetAsync(ckey)
	s.check("T3.15 " .. cycles .. " sequential handoffs, no lost/duplicated write (simulated)", okCycles == cycles and final.Counter == cycles, okCycles .. "/" .. tostring(final and final.Counter))
	return s
end

--------------------------------------------------------------------
-- T2 migration (fixtures) + T9 before/after comparison
--------------------------------------------------------------------
local function v3Base()
	return {
		Version = 3, Logs = 1200, Kills = 3, Levels = { Blades = 2, Speed = 4 },
		Weapons = { Wooden = { Copies = 0, Star = 0, Pulled = 1 }, Iron = { Copies = 1, Star = 1, Pulled = 4 } },
		Equipped = "Iron", AutoEquip = true, Rolls = { Total = 520, SinceEpic = 3, SinceLegendary = 520 },
		LuckLevel = 0, TraitLocked = false, Boosts = {}, Purchases = {}, StarterPack = false,
		Settings = { AutoFuse = true }, BestArea = "PineForest", IndexDone = {}, IndexClaimed = { Iron = true },
		Trees = { Grove_Common = 40 }, TreeClaimed = {}, TreeIndexDone = {}, MutationsFound = { Golden = 1 },
		Souls = 55, FreeCrates = 2, LastVipCrate = 0,
		Stats = { LogsEarned = 9000, TreesChopped = 420, PlaySeconds = 3600, RarestOneIn = 100, RarestId = "EngravedAxe", SoulsEarned = 70, PetsHatched = 1, Treants = 0 },
		Pets = { Bunny = 1 }, EquippedPets = { "Bunny" }, Achievements = { chop100 = true }, Sawmill = { Day = 0, Souls = 0 },
		Rebirths = 0, Prefs = { Music = 0.5, SFX = 0.8, Graphics = "High", DamageNumbers = true, SkipReveals = false, ShowTags = true, ScreenShake = true, ReducedMotion = false },
		Daily = { Streak = 2, LastDay = 20000 }, Quests = { DayKey = 1, WeekKey = 1, Daily = {}, Weekly = {} }, Codes = { RELEASE = true },
		GroupClaimed = true, TutorialDone = true, UnlockedIslands = { TimberHaven = true }, LastIsland = "TimberHaven", IslandProgress = {},
	}
end

function T.Fixtures(devProfiles)
	local f = {}
	f.new = { label = "brand-new player", raw = nil }
	f.v3 = { label = "existing v3 player", raw = v3Base() }
	local rare = v3Base()
	rare.Weapons.GlacialEdge = { Copies = 3, Star = 5, Pulled = 9, Shiny = true }
	rare.Weapons.FrostboundReaper = { Copies = 0, Star = 2, Pulled = 3 }
	rare.Weapons.FoundersEdge = { Copies = 0, Star = 0, Pulled = 1 }
	rare.Equipped = "GlacialEdge"
	f.rare = { label = "rare weapons (Divine, Shiny, exclusive)", raw = rare }
	local high = v3Base()
	high.Rebirths = 10 high.Logs = 4.2e9 high.Souls = 99999 high.BestArea = "FrostPeaks"
	high.UnlockedIslands = { TimberHaven = true, CrystalWilds = true, FrostboundReach = true }
	high.Trait = "AncientRoot" high.TraitLocked = true
	for _, a in ipairs({ "StarterGrove", "PineForest", "CrystalCanyon", "FrostPeaks" }) do high.IndexDone[a] = true high.TreeIndexDone[a] = true end
	high.Pets = { Dragon = 2, Owl = 3 } high.EquippedPets = { "Dragon", "Dragon", "Owl" }
	f.high = { label = "high progression", raw = high }
	local paid = v3Base()
	paid.Purchases = { ["P-1001"] = true, ["P-1002"] = true, ["P-1003"] = true }
	paid.StarterPack = true paid.FreeCrates = 13
	paid.Weapons.FoundersEdge = { Copies = 0, Star = 0, Pulled = 1 }
	paid.Boosts = { LuckPotion = 2000000000 }
	f.paid = { label = "player with purchases", raw = paid }
	local old = v3Base()
	old.Version = 2 old.Coins = 500 old.Pets = nil old.Prefs = nil old.UnlockedIslands = nil old.LastIsland = nil
	old.Stats = { LogsEarned = 10 } old.Weapons.OldRetiredBlade = { Copies = 2, Star = 1, Pulled = 3 }
	f.old = { label = "older save, missing optional fields, retired weapon id", raw = old }
	local bad = v3Base()
	bad.Version = "three" bad.FreeCrates = -7 bad.CrateOrigins = nil
	f.invalid = { label = "invalid values (non-numeric Version, negative crates)", raw = bad }
	for i, p in ipairs(devProfiles or {}) do
		f["dev" .. i] = { label = "authorized dev profile snapshot #" .. i .. " (read-only copy)", raw = deepCopy(p) }
	end
	return f
end

local PRESERVE_SKIP = { Version = true, Coins = true, _Meta = true, _Session = true }

function T.Migration(devProfiles)
	local DataService = require(ServerScriptService.DataService)
	local SaveMigrations = require(ServerScriptService.SaveMigrations)
	local SessionStore = require(ServerScriptService.SessionStore)
	local s = suite("T2/T9 migration and before/after comparison")
	local fixtures = T.Fixtures(devProfiles)
	local names = {}
	for k in pairs(fixtures) do table.insert(names, k) end
	table.sort(names)
	local compared = 0
	for _, name in ipairs(names) do
		local fx = fixtures[name]
		local before = deepCopy(fx.raw)
		local rawCopy = deepCopy(fx.raw)
		local store = T.MockStore()
		local ss = SessionStore.new({ store = store, wait = function() end, sessionId = "T", log = function() end })
		local fakePlayer = { UserId = 9000 + #name }
		local ok, data, how = DataService.BuildProfile(rawCopy, fx.raw and fakePlayer or nil, ss)
		s.check("T2 " .. name .. " builds", ok, ok and how or data)
		if ok then
			s.check("T2 " .. name .. " version 4", data.Version == 4 and data._Meta.Applied["4"] == true)
			s.check("T2 " .. name .. " input not mutated", rawCopy == nil or deepEqual(rawCopy, before))
			s.check("T2 " .. name .. " JSON-encodable", (pcall(json, data)))
			if before then
				-- every original top-level key survives with the same value (except intended upgrades)
				local diffs = {}
				for k, v in pairs(before) do
					if not PRESERVE_SKIP[k] and not (k == "Logs" and before.Coins ~= nil) then -- Logs+Coins checked below
						local nv = data[k]
						if k == "Weapons" then
							for wid, e in pairs(v) do
								local got = data.Weapons[wid] or data.RetiredWeapons[wid]
								if not got or not deepEqual(got, e) then table.insert(diffs, "Weapons." .. wid) end
							end
						elseif k == "FreeCrates" and (tonumber(v) or 0) < 0 then
							if nv ~= 0 then table.insert(diffs, k) end -- negative clamps to 0
						elseif type(v) == "table" then
							for kk, vv in pairs(v) do
								if not deepEqual((nv or {})[kk], vv) then table.insert(diffs, k .. "." .. tostring(kk)) end
							end
						elseif nv ~= v then
							table.insert(diffs, k)
						end
					end
				end
				s.check("T9 " .. name .. " all legacy values preserved", #diffs == 0, table.concat(diffs, ","))
				if before.Coins then s.check("T2 " .. name .. " Coins folded into Logs", data.Logs == (before.Logs or 0) + before.Coins and data.Coins == nil) end
				if before.Weapons.OldRetiredBlade then s.check("T2 " .. name .. " retired weapon parked, not deleted", data.RetiredWeapons.OldRetiredBlade ~= nil) end
				local o = data.CrateOrigins
				s.check("T2 " .. name .. " crate origins sum to FreeCrates", o.Earned + o.Paid + o.Legacy == data.FreeCrates, json(o))
				-- backup written once and readable
				local bk = store:GetAsync("bk3_p_" .. fakePlayer.UserId)
				s.check("T2 " .. name .. " pre-migration backup stored", bk ~= nil and type(bk.Profile) == "table" and deepEqual(bk.Profile, before), bk and "present" or "missing")
				-- repeated migration: idempotent
				local ok2, again = SaveMigrations.Migrate(data)
				s.check("T2 " .. name .. " repeated migration is a no-op", ok2 and deepEqual(again, data))
				-- second load must not overwrite the backup
				local ok3 = DataService.BuildProfile(roundtrip(data), fakePlayer, ss)
				local bk2 = store:GetAsync("bk3_p_" .. fakePlayer.UserId)
				s.check("T2 " .. name .. " backup not overwritten on rejoin", ok3 and deepEqual(bk2, bk))
				compared += 1
			else
				s.check("T2 new player onboarding funnel enabled", data.Analytics and not data.Analytics.Legacy)
			end
		end
	end
	-- interrupted migration: a failing step leaves the original untouched
	local orig = v3Base()
	local snapshotT = deepCopy(orig)
	local savedCurrent, savedStep = SaveMigrations.CURRENT, SaveMigrations.steps[5]
	SaveMigrations.CURRENT = 5
	SaveMigrations.steps[5] = function(d) d.Logs = -1 error("simulated crash in step 5") end
	local okI, errI = SaveMigrations.Migrate(orig)
	SaveMigrations.CURRENT, SaveMigrations.steps[5] = savedCurrent, savedStep
	s.check("T2 interrupted migration fails closed, original untouched", okI == false and deepEqual(orig, snapshotT), errI)
	-- backup failure -> refuse to migrate
	local store = T.MockStore()
	local ss = SessionStore.new({ store = store, wait = function() end, sessionId = "T", log = function() end, ioRetries = 2 })
	store.failNext = 100
	local okB = DataService.BuildProfile(v3Base(), { UserId = 8001 }, ss)
	store.failNext = 0
	s.check("T2 backup unavailable -> load refused (fail closed)", okB == false)
	s.check("T9 profiles compared before/after", compared >= 5, compared .. " (" .. #(devProfiles or {}) .. " real dev snapshot(s), rest synthetic)")
	return s
end

--------------------------------------------------------------------
-- T4 receipts (ReceiptProcessor with fake dependencies)
--------------------------------------------------------------------
function T.Receipts()
	local ReceiptProcessor = require(ServerScriptService.ReceiptProcessor)
	local s = suite("T4 receipts (synthetic receipts, injected dependencies)")
	local Granted, NotYet = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
	local player = { UserId = 7001 }
	local data = { Logs = 0, Purchases = {} }
	local env = { present = true, active = true, persist = true, saveOk = true, grantFail = false, saved = nil, reports = {} }
	local products = { [111] = { Id = "LogPackS" } }
	local rp = ReceiptProcessor.new({
		getPlayer = function(id) return (env.present and id == player.UserId) and player or nil end,
		product = function(id) return products[id] end,
		isActive = function() return env.active end,
		canPersist = function() return env.persist end,
		getData = function() return data end,
		grant = function(_, p)
			data.Logs += 100
			if env.grantFail then error("simulated grant crash") end
		end,
		saveNow = function()
			if env.saveOk then env.saved = HttpService:JSONEncode(data) return true end
			return false
		end,
		afterRestore = function() end,
		report = function(_, outcome) table.insert(env.reports, outcome) end,
	})
	local function r(pid, prod) return { PlayerId = player.UserId, ProductId = prod or 111, PurchaseId = pid } end

	local d1 = rp.process(r("R1"))
	s.check("T4.1 first receipt granted after confirmed save", d1 == Granted and data.Logs == 100 and data.Purchases.R1 and env.saved:find("R1"))
	local d2 = rp.process(r("R1"))
	s.check("T4.2 duplicate receipt not granted twice", d2 == Granted and data.Logs == 100)
	env.saveOk = false
	local d3 = rp.process(r("R2"))
	s.check("T4.3 save failure -> NotProcessedYet", d3 == NotYet and data.Purchases.R2 == true and data.Logs == 200)
	local d4 = rp.process(r("R2"))
	s.check("T4.4 retry while save still failing -> NotProcessedYet, no second grant", d4 == NotYet and data.Logs == 200)
	env.saveOk = true
	local d5 = rp.process(r("R2"))
	s.check("T4.5 retry after save recovers -> Granted, still one grant", d5 == Granted and data.Logs == 200 and #rp.pending() == 0)
	env.grantFail = true
	local d6 = rp.process(r("R3"))
	env.grantFail = false
	s.check("T4.6 interrupted grant rolled back (no record, no partial reward)", d6 == NotYet and data.Purchases.R3 == nil and data.Logs == 200)
	local d7 = rp.process(r("R3"))
	s.check("T4.7 retry after interrupted grant grants once", d7 == Granted and data.Logs == 300)
	env.present = false
	s.check("T4.8 player not in server -> NotProcessedYet", rp.process(r("R4")) == NotYet and data.Logs == 300)
	env.present = true env.active = false
	s.check("T4.9 data not loaded / profile owned elsewhere -> NotProcessedYet", rp.process(r("R4")) == NotYet and data.Logs == 300)
	env.active = true env.persist = false
	s.check("T4.10 unsaved test profile -> NotProcessedYet", rp.process(r("R4")) == NotYet)
	env.persist = true
	s.check("T4.11 unknown product id -> NotProcessedYet", rp.process(r("R5", 999)) == NotYet and data.Purchases.R5 == nil)
	s.check("T4.12 empty purchase id refused", rp.process(r("")) == NotYet)
	s.check("T4.13 purchase ids kept (never pruned)", data.Purchases.R1 and data.Purchases.R2 and data.Purchases.R3)
	return s
end

--------------------------------------------------------------------
-- T5 crate origins + policy classification (pure)
--------------------------------------------------------------------
function T.PaidRandom()
	local DataService = require(ServerScriptService.DataService)
	local Config = require(ReplicatedStorage.BladeConfig)
	local Policy = require(ServerScriptService.PaidRandomPolicy)
	local s = suite("T5 paid-random restrictions (pure logic)")
	local d = { FreeCrates = 5, CrateOrigins = { Earned = 1, Paid = 2, Legacy = 2 } }
	local ok1, o1 = DataService.SpendCrateOn(d, false)
	s.check("T5.1 restricted player can open an Earned crate", ok1 and o1 == "Earned" and d.FreeCrates == 4)
	local ok2, o2 = DataService.SpendCrateOn(d, false)
	s.check("T5.2 restricted player cannot open Paid/Legacy crates (kept, not removed)", not ok2 and o2 == "restricted" and d.FreeCrates == 4)
	local ok3, o3 = DataService.SpendCrateOn(d, true)
	s.check("T5.3 allowed player opens Legacy before Paid", ok3 and o3 == "Legacy" and d.FreeCrates == 3)
	d.FreeCrates += 2 -- free source added directly (quest/achievement code path)
	DataService.NormalizeCrates(d)
	s.check("T5.4 unclassified additions count as Earned", d.CrateOrigins.Earned == 2 and d.CrateOrigins.Earned + d.CrateOrigins.Paid + d.CrateOrigins.Legacy == d.FreeCrates)
	s.check("T5.5 Logs are not Robux-purchasable today (all log packs ProductId = 0)", Policy.LogsArePaidCurrency() == false)
	local pack = Config.ProductById.LogPackS
	local saved = pack.ProductId
	pack.ProductId = 123 -- in-memory only
	s.check("T5.6 once a log pack is live, Logs-paid crates/eggs are classified paid", Policy.LogsArePaidCurrency() == true)
	pack.ProductId = saved
	return s
end

function T.RunAll(devProfiles)
	local out, totalP, totalF = {}, 0, 0
	for _, fn in ipairs({ function() return T.Locking() end, function() return T.Migration(devProfiles) end, T.Receipts, T.PaidRandom }) do
		local ok, res = pcall(fn)
		if ok then
			totalP += res.pass totalF += res.fail
			table.insert(out, "== " .. res.name .. ": " .. res.pass .. " pass, " .. res.fail .. " fail")
			for _, l in ipairs(res.lines) do table.insert(out, "  " .. l) end
		else
			totalF += 1
			table.insert(out, "== ERROR: " .. tostring(res))
		end
	end
	table.insert(out, 1, ("M0 unit tests: %d pass, %d fail"):format(totalP, totalF))
	return table.concat(out, "\n"), totalP, totalF
end

-- Same lock tests against a REAL DataStore (single Studio process: proves the
-- API behaves as the mock does; still not cross-server evidence).
function T.RunDataStore(store)
	local res = T.Locking(store, "real DataStore, single process", 5)
	local out = { "== " .. res.name .. ": " .. res.pass .. " pass, " .. res.fail .. " fail" }
	for _, l in ipairs(res.lines) do table.insert(out, "  " .. l) end
	return table.concat(out, "\n"), res.pass, res.fail
end

return T
