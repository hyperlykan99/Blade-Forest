-- Analytics (M0-F): lightweight, server-authoritative analytics baseline.
--
-- Uses AnalyticsService (LogOnboardingFunnelStepEvent, LogProgressionCompleteEvent,
-- LogEconomyEvent, LogCustomEvent). Design rules:
--   * Never blocks or breaks gameplay: every call is pcall'd and queued.
--   * No personal information: no names, user ids or free text in fields.
--   * No duplicates: one-time steps are remembered in the profile
--     (d.Analytics.Onboard / d.Analytics.Prog), so a rejoin never re-logs them.
--   * Bounded frequency: currency flows are aggregated per player and flushed
--     at most once per FLUSH seconds; the send queue is rate-limited.
--   * Milestones are detected by polling saved profile fields every POLL
--     seconds, so no combat/reward code had to change. The only hook is a
--     pcall-wrapped observer around Progress.Add for "Boss" (boss defeats).
--   * Studio: events are recorded in Analytics.Recent for verification; the
--     real API is still called but dashboard ingestion is NOT verified there.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))

local A = {}
A.POLL = 5            -- seconds between milestone checks
A.FLUSH = 60          -- seconds between economy flushes per player
A.MAX_PER_SECOND = 20 -- global send budget
A.Recent = {}         -- last 300 events (for tests / dev inspection)
A.Counts = { sent = 0, failed = 0, dropped = 0 }
A.Disabled = false    -- test hook: simulate the service being unavailable

local DataService -- set in Start

local ONBOARD = {
	{ 1, "SessionStarted" },
	{ 2, "FirstTreeChopped" },
	{ 3, "FirstBladeUpgrade" },
	{ 4, "FirstWeaponDiscovered" },
	{ 5, "FirstEggHatched" },
	{ 6, "FirstTraitObtained" },
	{ 7, "FirstBossEncounter" },
	{ 8, "FirstIslandUnlocked" },
}

--------------------------------------------------------------------
-- queue + send
--------------------------------------------------------------------
local queue = {}
local function record(kind, name, value)
	table.insert(A.Recent, { t = os.clock(), kind = kind, name = name, value = value })
	if #A.Recent > 300 then table.remove(A.Recent, 1) end
end

local function enqueue(kind, fn, name, value)
	if A._immediate then -- leaving player: send now, before the Player object goes away
		record(kind, name, value)
		if A.Disabled then A.Counts.failed += 1 return end
		if pcall(fn) then A.Counts.sent += 1 else A.Counts.failed += 1 end
		return
	end
	if #queue > 500 then A.Counts.dropped += 1 return end
	table.insert(queue, { kind = kind, fn = fn, name = name, value = value })
end

task.spawn(function()
	while true do
		task.wait(1)
		local n = 0
		while #queue > 0 and n < A.MAX_PER_SECOND do
			local e = table.remove(queue, 1)
			n += 1
			record(e.kind, e.name, e.value)
			if A.Disabled then
				A.Counts.failed += 1
			else
				local ok = pcall(e.fn)
				if ok then A.Counts.sent += 1 else A.Counts.failed += 1 end
			end
		end
	end
end)

local function alive(player) return player and player.Parent == Players end

--------------------------------------------------------------------
-- public helpers
--------------------------------------------------------------------
function A.Custom(player, name, value, fields)
	if not alive(player) then return end
	enqueue("custom", function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end, name, value or 1)
end

-- outcome: "Granted" | "Deferred" | "Duplicate" | "Failed"; productKey = config id (not a user id)
function A.Receipt(player, outcome, productKey)
	A.Custom(player, "Receipt" .. outcome, 1, { CustomField01 = tostring(productKey or "unknown") })
end

local function onboard(player, d, step, name)
	d.Analytics = d.Analytics or { Onboard = {}, Prog = {} }
	d.Analytics.Onboard = d.Analytics.Onboard or {}
	if d.Analytics.Legacy or d.Analytics.Onboard[name] then return end
	d.Analytics.Onboard[name] = true
	enqueue("onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end, name, step)
end

local function progression(player, d, path, level, levelName)
	d.Analytics = d.Analytics or { Onboard = {}, Prog = {} }
	d.Analytics.Prog = d.Analytics.Prog or {}
	local key = path .. ":" .. levelName
	if d.Analytics.Prog[key] then return end
	d.Analytics.Prog[key] = true
	if A._silent then return end -- seeding: remember without sending
	enqueue("progression", function()
		AnalyticsService:LogProgressionCompleteEvent(player, path, level, levelName)
	end, key, level)
end

--------------------------------------------------------------------
-- per-player state for economy aggregation and session length
--------------------------------------------------------------------
local state = {} -- [player] = { logsEarned, logs, soulsEarned, souls, lastFlush, joined }

local function economyFlush(player, d, st)
	local le, se = d.Stats.LogsEarned or 0, d.Stats.SoulsEarned or 0
	local logsIn = math.max(0, le - st.logsEarned)
	local logsOut = math.max(0, st.logs + logsIn - (d.Logs or 0))
	local soulsIn = math.max(0, se - st.soulsEarned)
	local soulsOut = math.max(0, st.souls + soulsIn - (d.Souls or 0))
	local logsNow, soulsNow = d.Logs or 0, d.Souls or 0
	st.logsEarned, st.logs, st.soulsEarned, st.souls = le, logsNow, se, soulsNow
	st.lastFlush = os.clock()
	local function econ(flow, currency, amount, balance, sku)
		if amount <= 0 then return end
		enqueue("economy", function()
			AnalyticsService:LogEconomyEvent(player, flow, currency, amount, balance,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name, sku)
		end, currency .. "_" .. flow.Name, amount)
	end
	econ(Enum.AnalyticsEconomyFlowType.Source, "Logs", logsIn, logsNow, "Aggregate")
	econ(Enum.AnalyticsEconomyFlowType.Sink, "Logs", logsOut, logsNow, "Aggregate")
	econ(Enum.AnalyticsEconomyFlowType.Source, "Souls", soulsIn, soulsNow, "Aggregate")
	econ(Enum.AnalyticsEconomyFlowType.Sink, "Souls", soulsOut, soulsNow, "Aggregate")
end

local function countKeys(t) local n = 0 for _ in pairs(t or {}) do n += 1 end return n end

local function checkMilestones(player, d)
	local st = state[player]
	if not st then return end
	-- onboarding (new players only)
	onboard(player, d, 1, "SessionStarted")
	if (d.Stats.TreesChopped or 0) > 0 then onboard(player, d, 2, "FirstTreeChopped") end
	for _, lvl in pairs(d.Levels or {}) do if (tonumber(lvl) or 0) > 0 then onboard(player, d, 3, "FirstBladeUpgrade") break end end
	if countKeys(d.Weapons) > 1 then onboard(player, d, 4, "FirstWeaponDiscovered") end
	if (d.Stats.PetsHatched or 0) > 0 then onboard(player, d, 5, "FirstEggHatched") end
	if d.Trait then onboard(player, d, 6, "FirstTraitObtained") end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and workspace:GetAttribute("BossAlive") and ((root.Position - Config.GetArenaCenter()) * Vector3.new(1, 0, 1)).Magnitude <= Config.ArenaRadius + 22 then
		onboard(player, d, 7, "FirstBossEncounter")
	end
	if countKeys(d.UnlockedIslands) > 1 then onboard(player, d, 8, "FirstIslandUnlocked") end
	-- progression (all players, once each)
	for _, isl in ipairs(Config.Islands or {}) do
		if d.UnlockedIslands and d.UnlockedIslands[isl.Id] then progression(player, d, "Islands", isl.Order, isl.Id) end
	end
	local best = Config.AreaById[d.BestArea]
	if best then
		for _, a in ipairs(Config.Areas) do
			if a.Order <= best.Order then progression(player, d, "Areas", a.Order, a.Id) end
		end
	end
	local rarest = d.Stats.RarestOneIn or 0
	if rarest > 0 then
		-- tier of the rarest weapon ever pulled, by rarity of the weapon id
		local w = d.Stats.RarestId and Config.WeaponById[d.Stats.RarestId]
		if w then
			local r = Config.RarityById[w.Rarity]
			for _, rr in ipairs(Config.Rarities) do
				if rr.Order <= r.Order then progression(player, d, "WeaponTier", rr.Order, rr.Id) end
			end
		end
	end
	if not A._silent and os.clock() - st.lastFlush >= A.FLUSH then economyFlush(player, d, st) end
end

--------------------------------------------------------------------
-- lifecycle
--------------------------------------------------------------------
local function begin(player)
	local d = DataService and DataService.Get(player)
	if not d or state[player] then return end
	state[player] = {
		logsEarned = d.Stats.LogsEarned or 0, logs = d.Logs or 0,
		soulsEarned = d.Stats.SoulsEarned or 0, souls = d.Souls or 0,
		lastFlush = os.clock(), joined = os.clock(),
	}
	if d.Analytics and not d.Analytics.Legacy and not d.Analytics.FirstSeen then
		d.Analytics.FirstSeen = true
	end
	-- players who existed before v4: mark progress already reached as logged,
	-- so historical milestones are not reported as if they happened now
	if d.Analytics and d.Analytics.Legacy and not d.Analytics.Seeded then
		A._silent = true
		pcall(checkMilestones, player, d)
		A._silent = false
		d.Analytics.Seeded = true
	end
end

-- called by DataService before the final save of a leaving player
function A.OnLeaving(player)
	local st = state[player]
	local d = DataService and DataService.Get(player)
	if st and d then
		A._immediate = true
		pcall(economyFlush, player, d, st)
		local minutes = math.floor((os.clock() - st.joined) / 60 * 10 + 0.5) / 10
		pcall(A.Custom, player, "SessionMinutes", minutes)
		A._immediate = false
	end
	state[player] = nil
end

function A.SaveFailed(player, why)
	A.Custom(player, "SaveFailure", 1, { CustomField01 = tostring(why or "unknown"):sub(1, 30) })
end

local started = false
function A.Start(dataService)
	if started then return end
	started = true
	DataService = dataService
	if RunService:IsStudio() then
		-- Studio-only inspection hook for M0 tests (command-bar code runs in a
		-- separate module cache, so it cannot read A.Recent directly)
		local bf = Instance.new("BindableFunction")
		bf.Name = "DevAnalytics"
		bf.OnInvoke = function(cmd, v)
			if cmd == "SetDisabled" then A.Disabled = v == true end
			return { Recent = A.Recent, Counts = A.Counts, Disabled = A.Disabled, Queue = #queue }
		end
		bf.Parent = game:GetService("ServerStorage")
	end
	-- observe boss defeats without changing combat code
	local okP, Progress = pcall(require, ServerScriptService:WaitForChild("Progress"))
	if okP and type(Progress) == "table" and type(Progress.Add) == "function" then
		local original = Progress.Add
		Progress.Add = function(player, stat, n, ...)
			local r = table.pack(original(player, stat, n, ...))
			if stat == "Boss" then
				pcall(function()
					local d = DataService.Get(player)
					if d then
						d.Analytics = d.Analytics or { Onboard = {}, Prog = {} }
						d.Analytics.BossKills = (d.Analytics.BossKills or 0) + (n or 1)
						progression(player, d, "Bosses", 1, "BladeKing")
						A.Custom(player, "BossDefeated", 1, { CustomField01 = "BladeKing" })
					end
				end)
			end
			return table.unpack(r, 1, r.n)
		end
	end
	task.spawn(function()
		while true do
			task.wait(A.POLL)
			for _, p in ipairs(Players:GetPlayers()) do
				local d = DataService.Get(p)
				if d and p:GetAttribute("Loaded") then
					if not state[p] then begin(p) end
					pcall(checkMilestones, p, d)
				end
			end
		end
	end)
end

A.IsStudio = RunService:IsStudio()
return A
