-- EconomyTelemetry (M1.7): measures the economy instead of guessing. In-memory only
-- (never saved, never affects rewards). Read it from Studio with
--   game.ServerStorage.DevEconomy:Invoke("Report")
-- and it posts a compact hourly summary per player through Analytics when available.
--
-- Tracked:
--   per player : Logs/h by source (chop / boss / other), trees felled, rolls, rare pulls
--                (Legendary+), time in "AFK mode" vs active (client-reported state, used ONLY
--                for these statistics), Souls/h
--   per server : trees felled/s, accelerated (Forest Renewal) regrowths and budget
--                refusals, trees alive per area (forest congestion), combat heartbeat cost

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = {}
local per = {} -- [player] = stats
local server = { Start = os.clock(), Felled = 0, Renewed = 0, RenewRefused = 0, HeartbeatMs = 0, HeartbeatN = 0, HeartbeatMax = 0 }
T.Server = server

local function st(player)
	local s = per[player]
	if not s then
		s = { Start = os.clock(), Logs = { chop = 0, boss = 0, other = 0 }, Souls = 0, Trees = 0, Rolls = 0, Rares = 0,
			AfkSeconds = 0, ActiveSeconds = 0, Afk = false, LastState = os.clock() }
		per[player] = s
	end
	return s
end

function T.Logs(player, amount, source)
	if not player or not amount or amount <= 0 then return end
	local s = st(player)
	s.Logs[source or "other"] = (s.Logs[source or "other"] or 0) + amount
end
function T.Souls(player, amount) if player and amount then st(player).Souls += amount end end
function T.Tree(player) if player then st(player).Trees += 1 end server.Felled += 1 end
function T.Roll(player, rarity)
	local s = st(player)
	s.Rolls += 1
	if rarity == "Legendary" or rarity == "Mythic" or rarity == "Secret" or rarity == "Divine" then s.Rares += 1 end
end
function T.Renewal(accepted) if accepted then server.Renewed += 1 else server.RenewRefused += 1 end end
function T.Heartbeat(ms)
	server.HeartbeatMs += ms
	server.HeartbeatN += 1
	if ms > server.HeartbeatMax then server.HeartbeatMax = ms end
end

local function settleState(s)
	local now = os.clock()
	if s.Afk then s.AfkSeconds += now - s.LastState else s.ActiveSeconds += now - s.LastState end
	s.LastState = now
end

-- client-reported AFK / Auto Chop state: statistics only
function T.SetClientState(player, afk)
	local s = st(player)
	settleState(s)
	s.Afk = afk == true
end

local function perHour(v, secs) return secs > 0 and v * 3600 / secs or 0 end

function T.PlayerReport(player)
	local s = per[player]
	if not s then return nil end
	settleState(s)
	local secs = math.max(os.clock() - s.Start, 1)
	local total = s.Logs.chop + s.Logs.boss + s.Logs.other
	return {
		Seconds = math.floor(secs), LogsPerHour = perHour(total, secs), ChopPerHour = perHour(s.Logs.chop, secs),
		BossPerHour = perHour(s.Logs.boss, secs), OtherPerHour = perHour(s.Logs.other, secs), SoulsPerHour = perHour(s.Souls, secs),
		TreesPerHour = perHour(s.Trees, secs), RollsPerHour = perHour(s.Rolls, secs), RaresPerHour = perHour(s.Rares, secs),
		AfkShare = (s.AfkSeconds + s.ActiveSeconds) > 0 and s.AfkSeconds / (s.AfkSeconds + s.ActiveSeconds) or 0,
	}
end

function T.ServerReport()
	local secs = math.max(os.clock() - server.Start, 1)
	local alive = {}
	local bk = workspace:FindFirstChild("Breakables")
	if bk then
		for _, m in ipairs(bk:GetChildren()) do
			if m:GetAttribute("IsTree") then
				local a = m:GetAttribute("Area") or "?"
				alive[a] = (alive[a] or 0) + 1
			end
		end
	end
	return {
		Seconds = math.floor(secs), Players = #Players:GetPlayers(), FelledPerSecond = server.Felled / secs,
		Renewed = server.Renewed, RenewRefused = server.RenewRefused, TreesAlive = alive,
		HeartbeatAvgMs = server.HeartbeatN > 0 and server.HeartbeatMs / server.HeartbeatN or 0, HeartbeatMaxMs = server.HeartbeatMax,
	}
end

function T.Report()
	local players = {}
	for p in pairs(per) do
		if p.Parent then players[p.Name] = T.PlayerReport(p) end
	end
	return { Server = T.ServerReport(), Players = players }
end

-- client state remote (statistics only; rate-limited)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = Remotes:FindFirstChild("ClientState")
if not stateRemote then
	stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "ClientState"
	stateRemote.Parent = Remotes
end
local lastState = {}
stateRemote.OnServerEvent:Connect(function(player, afk)
	if os.clock() - (lastState[player] or 0) < 2 then return end
	lastState[player] = os.clock()
	T.SetClientState(player, afk == true)
end)

Players.PlayerRemoving:Connect(function(p)
	per[p] = nil
	lastState[p] = nil
end)

-- Studio-only read hook: game.ServerStorage.DevEconomy:Invoke("Report")
if game:GetService("RunService"):IsStudio() then
	local ServerStorage = game:GetService("ServerStorage")
	local bf = ServerStorage:FindFirstChild("DevEconomy") or Instance.new("BindableFunction")
	bf.Name = "DevEconomy"
	bf.Parent = ServerStorage
	bf.OnInvoke = function(cmd)
		if cmd == "Report" then return T.Report() end
		return nil
	end
end

-- hourly per-player summary to Analytics (best effort)
task.spawn(function()
	while true do
		task.wait(3600)
		local ok, Analytics = pcall(require, script.Parent:WaitForChild("Analytics"))
		if ok and type(Analytics) == "table" and Analytics.Custom then
			for p in pairs(per) do
				local r = p.Parent and T.PlayerReport(p)
				if r then
					pcall(Analytics.Custom, p, "EconomyLogsPerHour", math.floor(r.LogsPerHour))
				end
			end
		end
	end
end)

return T
