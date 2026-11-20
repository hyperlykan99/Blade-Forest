-- M01Tests: tests for the M0.1 corrections (Studio only, never runs by itself).
--   require(game.ServerStorage.M01Tests).RunAll()
-- Mock DataStores with injectable DELAYS and FAILURES drive the real
-- SessionStore / ProfileWriter / ReceiptProcessor / DataService.Load code.
-- Mock results prove the LOGIC in one process; they are NOT cross-server or
-- real-purchase evidence.

local HttpService = game:GetService("HttpService")
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = {}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end
local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function roundtrip(t) if t == nil then return nil end return HttpService:JSONDecode(HttpService:JSONEncode(t)) end

-- Mock DataStore: JSON round trip, failNext, per-call hook (may yield), write log
function T.MockStore()
	local m = { data = {}, failNext = 0, writes = {}, hook = nil }
	function m:UpdateAsync(key, fn)
		if self.hook then self.hook(key, "update") end
		if self.failNext > 0 then
			self.failNext -= 1
			error("mock DataStore error (injected)")
		end
		local old = self.data[key]
		local new = fn(type(old) == "table" and roundtrip(old) or old)
		if new ~= nil then
			self.data[key] = roundtrip(new)
			table.insert(self.writes, { key = key, seq = type(new) == "table" and new._WriteSeq or nil, logs = type(new) == "table" and new.Logs or nil })
		end
		return new
	end
	function m:GetAsync(key)
		if self.hook then self.hook(key, "get") end
		if self.failNext > 0 then
			self.failNext -= 1
			error("mock DataStore error (injected)")
		end
		local v = self.data[key]
		return type(v) == "table" and roundtrip(v) or v
	end
	return m
end

local function suite(name)
	local s = { name = name, pass = 0, fail = 0, lines = {} }
	function s.check(id, cond, detail)
		if cond then s.pass += 1 else s.fail += 1 end
		table.insert(s.lines, (cond and "PASS " or "FAIL ") .. id .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
	return s
end

local function newSS(store, id, extra)
	local SessionStore = require(SSS.SessionStore)
	local o = { store = store, sessionId = id or "S", jobId = "job-" .. (id or "S"), placeId = 1, wait = function(sec) task.wait(math.min(sec, 0.05)) end, lockRetries = 2, lockRetryWait = 0, log = function() end }
	for k, v in pairs(extra or {}) do o[k] = v end
	return SessionStore.new(o)
end

local function waitUntil(fn, timeout)
	local t = os.clock()
	while not fn() and os.clock() - t < (timeout or 5) do task.wait(0.02) end
	return fn()
end

--------------------------------------------------------------------
-- H2: serialized writes + persistent sequence fence
--------------------------------------------------------------------
function T.H2()
	local ProfileWriter = require(SSS.ProfileWriter)
	local ReceiptProcessor = require(SSS.ReceiptProcessor)
	local s = suite("H2 serialized writes + write-sequence fence")

	-- 1. fence at the SessionStore level
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("k")
		local st5 = ss:Write("k", { Logs = 5 }, false, 5)
		local st4 = ss:Write("k", { Logs = 4 }, false, 4)
		local rec = store:GetAsync("k")
		s.check("H2.1 older seq refused as stale, newer data kept", st5 == "ok" and st4 == "stale" and rec.Logs == 5 and rec._WriteSeq == 5, st4)
		local st5b = ss:Write("k", { Logs = 55 }, false, 5)
		s.check("H2.2 equal seq accepted (idempotent retry)", st5b == "ok" and store:GetAsync("k").Logs == 55)
		local stN = ss:Write("k", { Logs = 6 }, false)
		s.check("H2.3 write without seq keeps the stored sequence", stN == "ok" and store:GetAsync("k")._WriteSeq == 5)
		local _, _, info = (function() ss:Write("k", { Logs = 6 }, true, 6) return newSS(store, "B"):Acquire("k") end)()
		s.check("H2.4 Acquire reports the stored sequence", info and info.Seq == 6, info and info.Seq)
		store.data["e"] = { _WriteSeq = 9 }
		local stE, dE, iE = newSS(store, "C"):Acquire("e")
		s.check("H2.5 record holding only _WriteSeq is a new profile with Seq kept", stE == "ok" and dE == nil and iE.Seq == 9)
	end

	-- 2. overlapping saves: a slow first save must finish before the second starts,
	--    and the second carries the NEWER data (the M0 30 s fall-through is gone)
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("p")
		local data = { Logs = 1, Purchases = {} }
		local w = ProfileWriter.new({ sessions = ss, key = "p", data = data, seq = 0 })
		local firstDelay = true
		local order = {}
		store.hook = function(key, kind)
			if kind == "update" and key == "p" and firstDelay then
				firstDelay = false
				table.insert(order, "A-start")
				task.wait(1.0) -- slow DataStore call
			end
		end
		local resA
		task.spawn(function() resA = { w:Save(false) } table.insert(order, "A-done") end)
		task.wait(0.1)
		data.Logs = 2
		data.Purchases["RCPT-1"] = true
		table.insert(order, "B-queued")
		local okB, stB = w:Save(false)
		table.insert(order, "B-done")
		waitUntil(function() return resA ~= nil end)
		local rec = store:GetAsync("p")
		s.check("H2.6 second save waited for the first (no overlap)", table.concat(order, ",") == "A-start,B-queued,A-done,B-done", table.concat(order, ","))
		s.check("H2.7 final record is the newest data incl. purchase", okB and rec.Logs == 2 and rec.Purchases["RCPT-1"] == true and rec._WriteSeq == 2, HttpService:JSONEncode(rec))
		s.check("H2.8 sequence strictly increasing in write log", #store.writes >= 2 and store.writes[#store.writes - 1].seq == 1 and store.writes[#store.writes].seq == 2)
	end

	-- 3. interrupted receipt: autosave with an OLD copy in flight + DataStore
	--    failures, receipt granted meanwhile -> purchase must never be lost or doubled
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("r")
		local data = { Logs = 0, Purchases = {} }
		local w = ProfileWriter.new({ sessions = ss, key = "r", data = data, seq = 0 })
		local slow = true
		store.hook = function(key, kind)
			if kind == "update" and key == "r" and slow then slow = false task.wait(0.8) end
		end
		local player = { UserId = 1 }
		local rp = ReceiptProcessor.new({
			getPlayer = function() return player end,
			product = function(id) return id == 111 and { Id = "LogPackS" } or nil end,
			isActive = function() return not w.lost and not w.released end,
			canPersist = function() return true end,
			getData = function() return data end,
			grant = function() data.Logs += 100 end,
			saveNow = function() return (w:Save(false)) end,
			afterRestore = function() end,
			report = function() end,
		})
		local autosaveDone = false
		task.spawn(function() w:Save(false) autosaveDone = true end) -- old snapshot (Logs 0) in flight
		task.wait(0.1)
		local d1 = rp.process({ PlayerId = 1, ProductId = 111, PurchaseId = "R1" })
		waitUntil(function() return autosaveDone end)
		local rec = store:GetAsync("r")
		s.check("H2.9 receipt during slow autosave: granted only after its own confirmed write", d1 == Enum.ProductPurchaseDecision.PurchaseGranted and rec.Purchases.R1 == true and rec.Logs == 100, rec.Logs)
		-- failure injection: every attempt fails -> NotProcessedYet, nothing doubled
		store.failNext = 100
		local d2 = rp.process({ PlayerId = 1, ProductId = 111, PurchaseId = "R2" })
		store.failNext = 0
		s.check("H2.10 DataStore down: NotProcessedYet, grant kept in memory once", d2 == Enum.ProductPurchaseDecision.NotProcessedYet and data.Logs == 200 and store:GetAsync("r").Purchases.R2 == nil)
		local d3 = rp.process({ PlayerId = 1, ProductId = 111, PurchaseId = "R2" })
		local rec3 = store:GetAsync("r")
		s.check("H2.11 Roblox retry after recovery: Granted, single grant persisted", d3 == Enum.ProductPurchaseDecision.PurchaseGranted and rec3.Logs == 200 and rec3.Purchases.R2 == true)
		-- an OLDER snapshot written later by any path is refused by the fence
		local stOld = ss:Write("r", { Logs = 0, Purchases = {} }, false, 1)
		s.check("H2.12 late stale snapshot cannot erase confirmed purchases", stOld == "stale" and store:GetAsync("r").Purchases.R1 == true and store:GetAsync("r").Logs == 200, stOld)
	end

	-- 4. a newer write by the same key (e.g. rolled-back server) -> writer stops
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("z")
		store.data["z"]._WriteSeq = 10
		local w = ProfileWriter.new({ sessions = ss, key = "z", data = { Logs = 1 }, seq = 3 })
		local ok, st = w:Save(false)
		s.check("H2.13 writer behind the stored sequence is fenced and stops writing", not ok and st == "stale" and w.lost == true, st)
	end

	-- 5. queue timeout never writes out of order
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("q")
		local data = { Logs = 1 }
		local w = ProfileWriter.new({ sessions = ss, key = "q", data = data, seq = 0, maxQueueWait = 0.3 })
		local hang = true
		store.hook = function(key, kind) if kind == "update" and key == "q" and hang then hang = false task.wait(1.0) end end
		local doneA = false
		task.spawn(function() w:Save(false) doneA = true end)
		task.wait(0.05)
		local okB, stB = w:Save(false)
		waitUntil(function() return doneA end)
		data.Logs = 3
		local okC = w:Save(false)
		local rec = store:GetAsync("q")
		s.check("H2.14 queued save times out WITHOUT writing; later saves still ordered", not okB and stB == "queue_timeout" and okC and rec.Logs == 3 and rec._WriteSeq == 2 and w:Pending() == 0, stB)
	end
	return s
end

--------------------------------------------------------------------
-- H3: leaving during first-time migration releases the lock untouched
--------------------------------------------------------------------
local function v3Record()
	return { Version = 3, Logs = 1234, Souls = 7, Kills = 0, Levels = {}, Weapons = { Wooden = { Copies = 0, Star = 0, Pulled = 1 }, Iron = { Copies = 2, Star = 1, Pulled = 5 } },
		Equipped = "Iron", AutoEquip = true, Rolls = { Total = 10, SinceEpic = 1, SinceLegendary = 10 }, Purchases = {}, FreeCrates = 2, BestArea = "PineForest",
		Stats = { LogsEarned = 5000, TreesChopped = 40 }, Settings = { AutoFuse = true } }
end

function T.H3()
	local DataService = require(SSS.DataService)
	local s = suite("H3 leaving during load / migration")
	-- a. leave while the backup is being written
	do
		local store = T.MockStore()
		local original = v3Record()
		store.data["p_5001"] = deepCopy(original)
		local fake = { UserId = 5001, Parent = true }
		store.hook = function(key, kind)
			if key == "bk3_p_5001" and kind == "update" then
				task.wait(0.2)
				fake.Parent = nil -- player leaves mid-backup
			end
		end
		local res = DataService.Load(fake, newSS(store, "L1"))
		local released = waitUntil(function() return store.data["p_5001"]._Session == nil end, 3)
		local rec = deepCopy(store.data["p_5001"])
		s.check("H3.1 Load reports the departure", res == "left_during_build", res)
		s.check("H3.2 lock released (no 300 s leak)", released)
		rec._Session = nil
		s.check("H3.3 original v3 record untouched (not migrated, not emptied)", deepEqual(rec, original), HttpService:JSONEncode(rec))
		s.check("H3.4 verified backup still written", store.data["bk3_p_5001"] ~= nil and deepEqual(store.data["bk3_p_5001"].Profile, original))
		local st2 = newSS(store, "L2"):Acquire("p_5001")
		s.check("H3.5 immediate rejoin acquires the profile", st2 == "ok", st2)
	end
	-- b. leave during Acquire (existing M0 path, now via the shared helper)
	do
		local store = T.MockStore()
		store.data["p_5002"] = v3Record()
		local fake = { UserId = 5002, Parent = true }
		store.hook = function(key, kind) if key == "p_5002" and kind == "update" and fake.Parent then fake.Parent = nil end end
		local res = DataService.Load(fake, newSS(store, "L3"))
		local released = waitUntil(function() return store.data["p_5002"]._Session == nil end, 3)
		s.check("H3.6 leave during Acquire: released, data unchanged", res == "left" and released and store.data["p_5002"].Logs == 1234, res)
	end
	-- c. brand-new player leaving: no content written
	do
		local store = T.MockStore()
		local fake = { UserId = 5003, Parent = true }
		store.hook = function(key, kind) if key == "p_5003" and kind == "update" and fake.Parent then fake.Parent = nil end end
		DataService.Load(fake, newSS(store, "L4"))
		waitUntil(function() return store.data["p_5003"] and store.data["p_5003"]._Session == nil end, 3)
		local st, data = newSS(store, "L5"):Acquire("p_5003")
		s.check("H3.7 new player leaving: next join is still a NEW profile", st == "ok" and data == nil, st)
	end
	-- d. normal load still works and keeps the lock
	do
		local store = T.MockStore()
		store.data["p_5004"] = v3Record()
		local fake = { UserId = 5004, Parent = true }
		local res, data = DataService.Load(fake, newSS(store, "L6"))
		s.check("H3.8 player who stays: profile built (v4), lock held", res == "ok" and data and data.Version == 4 and store.data["p_5004"]._Session ~= nil and data._WriteSeq == 0, res)
	end
	return s
end

--------------------------------------------------------------------
-- H1: movement sanity
--------------------------------------------------------------------
function T.H1()
	local MG = require(SSS.MovementGuard)
	local s = suite("H1 movement sanity (synthetic paths, 20 Hz)")
	local function run(g, key, t0, secs, speed, ws, opts)
		opts = opts or {}
		local flags, t, x = 0, t0, opts.x0 or 0
		local dt = 0.05
		local lastSent = { x = x }
		for i = 1, math.floor(secs / dt) do
			t += dt
			x += speed * dt
			local send = x
			if opts.burst then -- replication arrives every `burst` seconds
				if (i * dt) % opts.burst < dt then lastSent.x = x end
				send = lastSent.x
			end
			local ok = g:Check(key, { X = send, Z = 0 }, ws, t)
			if not ok then flags += 1 end
		end
		return flags, t, x
	end
	local g = MG.new()
	s.check("H1.1 walking at 16 for 20 s: never flagged", (run(g, "walk", 0, 20, 16, 16)) == 0)
	s.check("H1.2 Walk Speed upgrade 24 (server WalkSpeed 24): never flagged", (run(g, "fast", 0, 20, 24, 24)) == 0)
	s.check("H1.3 bursty replication (0.6 s bursts) at 16: never flagged", (run(g, "burst", 0, 20, 16, 16, { burst = 0.6 })) == 0)
	s.check("H1.4 1.3x speed hack tolerated (documented tolerance)", (run(g, "tol", 0, 10, 20.8, 16)) == 0)
	local flags2 = run(g, "hack2", 0, 6, 32, 16)
	s.check("H1.5 2x speed hack flagged", flags2 > 0, flags2)
	local flags3 = run(g, "hack3", 0, 6, 48, 16)
	s.check("H1.6 3x speed hack flagged", flags3 > 0, flags3)
	-- teleport
	local g2 = MG.new()
	run(g2, "tp", 0, 2, 0, 16)
	local ok1 = g2:Check("tp", { X = 500, Z = 0 }, 16, 2.05)
	local ok2 = g2:Check("tp", { X = 500, Z = 0 }, 16, 3.0)
	local ok3 = g2:Check("tp", { X = 500, Z = 0 }, 16, 5.2)
	s.check("H1.7 500-stud teleport: credit paused ~3 s, then resumes", ok1 == false and ok2 == false and ok3 == true)
	-- sanctioned teleport
	local g3 = MG.new()
	run(g3, "travel", 0, 2, 0, 16)
	g3:Allow("travel", 3, 2.0, { X = 3000, Z = 0 })
	local okT = g3:Check("travel", { X = 3000, Z = 0 }, 16, 2.1)
	local flagsAfter = run(g3, "travel", 2.1, 5, 16, 16, { x0 = 3000 })
	s.check("H1.8 island travel (Allow): no pause, walking after it fine", okT and flagsAfter == 0)
	-- respawn
	local g4 = MG.new()
	run(g4, "spawn", 0, 2, 0, 16)
	g4:Reset("spawn")
	local okR = g4:Check("spawn", { X = -800, Z = 0 }, 16, 2.1)
	s.check("H1.9 respawn far away (Reset): not flagged", okR)
	-- vertical ignored
	local g5 = MG.new()
	local okF = true
	for i = 1, 60 do
		if not g5:Check("fall", { X = 0, Y = -i * 20, Z = 0 }, 16, i * 0.05) then okF = false end
	end
	s.check("H1.10 falling 1,200 studs vertically: not flagged", okF)
	-- repeated teleports -> long suspension
	local g6 = MG.new()
	local t = 0
	g6:Check("rep", { X = 0, Z = 0 }, 16, 0)
	for k = 1, 5 do
		t += 4
		g6:Check("rep", { X = k * 1000, Z = 0 }, 16, t)
	end
	local okLong = g6:Check("rep", { X = 5000, Z = 0 }, 16, t + 10)
	s.check("H1.11 5 teleports within 60 s: 30 s suspension", okLong == false and g6:Violations("rep") == 5)
	-- join/rejoin as observed in Studio: the server teleport reaches the server's
	-- view of the client-owned character 4 s late (old spot first, then the target)
	local g7 = MG.new()
	run(g7, "lag", 0, 2, 0, 16, { x0 = 20 })
	g7:Allow("lag", 3, 2.0, { X = 2790, Z = 0 })
	local transit, viol = 0, 0
	for i = 1, 80 do -- 4 s still at the old spot, at 20 Hz
		local ok, why = g7:Check("lag", { X = 20, Z = 0 }, 16, 2.0 + i * 0.05)
		if why == "transit" then transit += 1 end
	end
	local okArr = g7:Check("lag", { X = 2790, Z = 0 }, 16, 6.05)
	local flagsAfterArr = run(g7, "lag", 6.05, 5, 16, 16, { x0 = 2790 })
	s.check("H1.12 late-applied teleport (4 s lag): no violation, credit waits, resumes on arrival", g7:Violations("lag") == 0 and transit == 80 and okArr and flagsAfterArr == 0, transit)
	local g8 = MG.new()
	run(g8, "never", 0, 2, 0, 16)
	g8:Allow("never", 3, 2.0, { X = 5000, Z = 0 })
	local okWait = g8:Check("never", { X = 0, Z = 0 }, 16, 11.9)
	local okAfter = g8:Check("never", { X = 0, Z = 0 }, 16, 12.1)
	local flagsLater = run(g8, "never", 12.1, 5, 16, 16)
	s.check("H1.13 teleport never applied: credit waits at most 10 s, then normal (no strike)", okWait == false and okAfter == true and flagsLater == 0 and g8:Violations("never") == 0)
	-- the pattern seen live on join: server view at the destination (server's own
	-- write), then stale client positions back at the spawn, interpolated points,
	-- then the destination again
	local g9 = MG.new()
	run(g9, "rev", 0, 2, 0, 16, { x0 = 20 })
	g9:Allow("rev", 3, 2.0, { X = 2790, Z = 0 }, { X = 20, Z = 0 })
	local seq = { 2790, 2790, 20, 20, 20, 25, 383, 832, 2790, 2790 }
	local credited = {}
	for i, x in ipairs(seq) do
		local ok = g9:Check("rev", { X = x, Z = 0 }, 16, 2.0 + i * 0.3)
		if ok then table.insert(credited, x) end
	end
	local onlyDest = true
	for _, x in ipairs(credited) do if x ~= 2790 then onlyDest = false end end
	local tEnd = 2.0 + #seq * 0.3
	local flagsWalk = run(g9, "rev", tEnd, 3, 16, 16, { x0 = 2790 }) -- walks off the path
	local walkedTo = 2790 + 16 * 3
	local okJump = g9:Check("rev", { X = walkedTo + 500, Z = 0 }, 16, tEnd + 3.05)
	s.check("H1.14 join revert sequence (dest -> spawn -> 383 -> 832 -> dest): no strike, credit only at dest, later teleports still caught",
		g9:Violations("rev") == 1 and onlyDest and #credited == 4 and flagsWalk == 0 and okJump == false, #credited .. "/" .. g9:Violations("rev"))
	return s
end

--------------------------------------------------------------------
-- M1: AFK handoff
--------------------------------------------------------------------
function T.M1()
	local ProfileWriter = require(SSS.ProfileWriter)
	local AFK = require(SSS.AFKHandoff)
	local Config = require(ReplicatedStorage.BladeConfig)
	local s = suite("M1 AFK server-hop handoff")
	-- writer handoff / resume
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("h")
		local data = { Logs = 10 }
		local w = ProfileWriter.new({ sessions = ss, key = "h", data = data, seq = 0 })
		local ok = w:Handoff()
		local rec = store:GetAsync("h")
		s.check("M1.1 handoff = confirmed save + lock released", ok and rec._Session == nil and rec.Logs == 10 and w.released)
		data.Logs = 11
		local okS, stS = w:Save(false)
		s.check("M1.2 no writes after handoff", not okS and stS == "released" and store:GetAsync("h").Logs == 10)
		local ssB = newSS(store, "B")
		local stB = ssB:Acquire("h")
		s.check("M1.3 new server acquires immediately (no 45 s wait)", stB == "ok", stB)
		-- B saves then releases: A's resume must not overwrite
		ssB:Write("h", { Logs = 50 }, true, 2)
		local r = w:Resume()
		s.check("M1.4 resume after someone else wrote = conflict, their data kept", r == "conflict" and w.lost and store:GetAsync("h").Logs == 50 and store:GetAsync("h")._Session == nil, r)
	end
	do
		local store = T.MockStore()
		local ss = newSS(store, "A")
		ss:Acquire("h2")
		local data = { Logs = 1 }
		local w = ProfileWriter.new({ sessions = ss, key = "h2", data = data, seq = 0 })
		w:Handoff()
		local r = w:Resume()
		data.Logs = 2
		local okS = w:Save(false)
		local rec = store:GetAsync("h2")
		s.check("M1.5 failed teleport: resume re-acquires and saving continues in sequence", r == "ok" and okS and rec.Logs == 2 and rec._WriteSeq == 2 and rec._Session ~= nil, r)
		store.failNext = 100
		local w2 = ProfileWriter.new({ sessions = ss, key = "h2", data = { Logs = 9 }, seq = 2 })
		local okH = w2:Handoff()
		store.failNext = 0
		s.check("M1.6 handoff not confirmed (DataStore down): not released, keeps the lock", not okH and not w2.released and store:GetAsync("h2")._Session ~= nil)
	end
	-- orchestration
	do
		local calls = {}
		local deps = {
			now = function() return 1000 end,
			joinedAt = function() return 0 end,
			lastHop = function() return nil end,
			setLastHop = function() end,
			release = function() table.insert(calls, "release") return true end,
			teleport = function() table.insert(calls, "teleport") return true end,
			resume = function() table.insert(calls, "resume") return true end,
			log = function() end,
		}
		s.check("M1.7 happy path: release then teleport", AFK.Run({}, {}, deps) == "teleported" and table.concat(calls, ",") == "release,teleport")
		calls = {}
		deps.release = function() table.insert(calls, "release") return false, "error" end
		s.check("M1.8 release not confirmed: no teleport", AFK.Run({}, {}, deps) == "release_failed" and table.concat(calls, ",") == "release")
		calls = {}
		deps.release = function() table.insert(calls, "release") return true end
		deps.teleport = function() table.insert(calls, "teleport") return false, "TeleportFailed" end
		s.check("M1.9 teleport fails: profile re-acquired", AFK.Run({}, {}, deps) == "resumed" and table.concat(calls, ",") == "release,teleport,resume")
		deps.joinedAt = function() return 900 end
		s.check("M1.10 hop within 5 min of joining refused", AFK.Run({}, {}, deps) == "too_soon")
		deps.joinedAt = function() return 0 end
		deps.lastHop = function() return 950 end
		s.check("M1.11 second hop within 5 min refused", AFK.Run({}, {}, deps) == "too_soon")
	end
	-- sanitising client-supplied stats
	do
		local clean = AFK.Sanitize({ Start = 0 / 0, Rolls = 1e300, Logs = -5, Souls = "x", BestId = string.rep("a", 500), BestOneIn = math.huge,
			New = { "Void", "NotAWeapon", 42, string.rep("b", 100) }, Evil = { Admin = true } }, Config.WeaponById, 100000)
		s.check("M1.12 session stats sanitised (NaN/inf -> floor, huge -> cap, bad ids, extra keys)", clean.Start == 100000 and clean.Rolls == 1e7 and clean.Logs == 0 and clean.Souls == 0
			and clean.BestId == nil and clean.BestOneIn == 0 and AFK.Sanitize({ BestOneIn = 1e300 }, Config.WeaponById, 1).BestOneIn == 1e10 and #clean.New == 1 and clean.New[1] == "Void" and clean.Evil == nil, HttpService:JSONEncode(clean))
		local c2 = AFK.Sanitize("not a table", Config.WeaponById, 5)
		s.check("M1.13 non-table session -> empty stats", c2.Start == 5 and c2.Rolls == 0)
	end
	return s
end

--------------------------------------------------------------------
-- H6: playtime gifts in the profile
--------------------------------------------------------------------
function T.H6()
	local G = require(SSS.PlaytimeGifts)
	local Config = require(ReplicatedStorage.BladeConfig)
	local gifts = Config.PlaytimeGifts
	local s = suite("H6 playtime gifts across server hops")
	local day = 20000
	local st = G.Default()
	s.check("H6.1 first join starts a visit", G.Begin(st, 1000, day) == "new" and st.Visits == 1)
	G.Tick(st, 300, 1300)
	local ok1 = G.Claim(st, 1, gifts)
	local ok1b, why1b = G.Claim(st, 1, gifts)
	s.check("H6.2 5-min gift claimable once", ok1 and not ok1b and why1b == "Already claimed", why1b)
	local okEarly = G.Claim(st, 2, gifts)
	s.check("H6.3 10-min gift not before 10 min", not okEarly)
	-- AFK hop / rejoin 60 s later: same visit
	local r = G.Begin(st, 1360, day)
	s.check("H6.4 rejoin within 30 min resumes the visit (progress + claims kept)", r == "resumed" and st.Seconds == 300 and st.Claimed["1"] == true)
	local okAgain = G.Claim(st, 1, gifts)
	s.check("H6.5 rejoin cannot re-claim the 5-min gift (old exploit)", not okAgain)
	G.Tick(st, 300, 1660)
	s.check("H6.6 progress continues across the hop (10-min gift now ready)", (G.Claim(st, 2, gifts)))
	-- long break: new visit
	local r2 = G.Begin(st, 1660 + 3600, day)
	s.check("H6.7 break > 30 min starts a new visit (fresh ladder, as before)", r2 == "new" and st.Seconds == 0 and next(st.Claimed) == nil and st.Visits == 2)
	G.Begin(st, 1660 + 7200, day)
	local r4 = G.Begin(st, 1660 + 10800, day)
	G.Tick(st, 300, 1660 + 11100)
	local okCap, whyCap = G.Claim(st, 1, gifts)
	s.check("H6.8 4th visit in one UTC day pays no gifts", r4 == "capped" and not okCap and whyCap ~= nil and G.ClaimedList(st, gifts) == "1,2,3,4,5,6,7,8", whyCap)
	local r5 = G.Begin(st, 1660 + 90000, day + 1)
	G.Tick(st, 300, 1660 + 90300)
	s.check("H6.9 next UTC day: visits reset, gifts claimable again", r5 == "new" and st.Visits == 1 and (G.Claim(st, 1, gifts)))
	-- farming simulation: rejoin every 10 min for 3 hours
	local farm, paid = G.Default(), 0
	local t = 0
	for k = 1, 18 do
		G.Begin(farm, t, day)
		G.Tick(farm, 300, t + 300)
		if G.Claim(farm, 1, gifts) then paid += 1 end
		G.Tick(farm, 300, t + 600)
		if G.Claim(farm, 2, gifts) then paid += 1 end
		t += 610
	end
	s.check("H6.10 rejoin every 10 min for 3 h: 5/10-min gifts paid once (was 18x each)", paid == 2, paid)
	local garbage = { Seconds = "x", Claimed = 5, LastSeen = 0 / 0 }
	s.check("H6.11 malformed state is repaired, not crashed", G.Begin(garbage, 50, day) == "new" and type(garbage.Claimed) == "table")
	return s
end

--------------------------------------------------------------------
-- M5: boss scaling and minimum contribution
--------------------------------------------------------------------
function T.M5()
	local B = require(SSS.BossRules)
	local s = suite("M5 boss health scaling + minimum contribution")
	local center = Vector3.new(0, 0, 205)
	local entries = {
		{ pos = Vector3.new(10, 0, 200), power = 1000 },
		{ pos = Vector3.new(3000, 0, 0), power = 50000 }, -- AFK on another island
		{ pos = nil, power = 9999 },                       -- no character
	}
	local n, power = B.InRange(entries, center, B.TREANT_RANGE)
	s.check("M5.1 only players near the Treant scale its HP", n == 1 and power == 1000, n .. "/" .. power)
	local shares = { [1] = 9000, [2] = 80, [3] = 150 }
	local hits = { [1] = 40, [2] = 3, [3] = 15 }
	local ranked, inel = B.Rank(shares, hits)
	s.check("M5.2 one-touch share (0.8%, 3 hits) not rewarded", #inel == 1 and inel[1][1] == 2)
	s.check("M5.3 small share with enough hits (15) still rewarded; best first", #ranked == 2 and ranked[1][1] == 1 and ranked[2][1] == 3)
	local r2 = B.Rank({ [7] = 100 }, { [7] = 1 })
	s.check("M5.4 a solo player always qualifies (100% share)", #r2 == 1)
	return s
end

function T.RunAll()
	local out, P, F = {}, 0, 0
	for _, name in ipairs({ "H2", "H3", "H1", "M1", "H6", "M5" }) do
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
	table.insert(out, 1, ("M0.1 tests: %d pass, %d fail"):format(P, F))
	return table.concat(out, "\n"), P, F
end

return T
