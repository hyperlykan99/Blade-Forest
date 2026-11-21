-- MetaService: everything around the core loop.
--   Settings (prefs) | Rebirth | Luck events | Daily login | Playtime gifts
--   Quests | Codes | Group reward | play-time stats
-- Client talks to it through Remotes.Meta:InvokeServer(action, ...)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Gifts = require(script.Parent:WaitForChild("PlaytimeGifts")) -- M0.1 (H6): visit kept in the profile
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")
local Meta = Remotes:FindFirstChild("Meta") or Instance.new("RemoteFunction")
Meta.Name = "Meta"
Meta.Parent = Remotes

local function today() return math.floor(os.time() / 86400) end

--------------------------------------------------------------------
-- Prefs
--------------------------------------------------------------------
local PREF_TYPES = { Music = "number", SFX = "number", Graphics = "string", DamageNumbers = "boolean", SkipReveals = "boolean", ShowTags = "boolean", ScreenShake = "boolean", ReducedMotion = "boolean" }
local function applyPrefs(player, d)
	for k, v in pairs(d.Prefs) do player:SetAttribute("Pref_" .. k, v) end
end

--------------------------------------------------------------------
-- Playtime gifts (M0.1, H6): progress lives in the profile (d.Playtime), so
-- it survives AFK server hops and quick rejoins (see PlaytimeGifts).
-- The client still reads SessionStart / GiftsClaimed attributes as before.
--------------------------------------------------------------------
local function giftState(player)
	local d = DataService.Get(player)
	if not d then return end
	local pt = d.Playtime
	local ready = false
	for i in ipairs(Config.PlaytimeGifts) do
		if Gifts.CanClaim(pt, i, Config.PlaytimeGifts) then ready = true end
	end
	player:SetAttribute("GiftsClaimed", Gifts.ClaimedList(pt, Config.PlaytimeGifts))
	player:SetAttribute("SessionStart", workspace:GetServerTimeNow() - pt.Seconds)
	local dailyReady = d.Daily.LastDay < today()
	player:SetAttribute("DailyReady", dailyReady == true)
	player:SetAttribute("GiftReady", ready or dailyReady == true)
end

local function questReady(player)
	local d = DataService.Get(player)
	if not d then return end
	Progress.Refresh(player)
	local ready = false
	for _, set in ipairs({ d.Quests.Daily, d.Quests.Weekly }) do
		for id, st in pairs(set) do
			local q = Progress.QuestById[id]
			if q and not st.Claimed and st.Progress >= q.Goal then ready = true end
		end
	end
	player:SetAttribute("QuestReady", ready)
end

--------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------
local lastAction = {}
Meta.OnServerInvoke = function(player, action, a, b)
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	if os.clock() - (lastAction[player] or 0) < 0.15 then return false, "Slow down" end
	lastAction[player] = os.clock()

	if action == "SetPref" then
		local want = PREF_TYPES[a]
		if not want or type(b) ~= want then return false, "?" end
		if want == "number" then b = math.clamp(b, 0, 1) end
		if a == "Graphics" and not table.find({ "Low", "Medium", "High" }, b) then return false, "?" end
		d.Prefs[a] = b
		player:SetAttribute("Pref_" .. a, b)
		return true

	elseif action == "ClaimDaily" then
		if d.Daily.LastDay >= today() then return false, "Come back tomorrow!" end
		if d.Daily.LastDay == today() - 1 then d.Daily.Streak += 1 else d.Daily.Streak = 1 end
		d.Daily.LastDay = today()
		local rw = Config.DailyRewards[(d.Daily.Streak - 1) % #Config.DailyRewards + 1]
		Progress.Grant(player, rw, "Day " .. d.Daily.Streak)
		giftState(player)
		return true, d.Daily.Streak

	elseif action == "ClaimGift" then
		local g = type(a) == "number" and Config.PlaytimeGifts[a] or nil
		if not g then return false, "?" end
		local ok, why = Gifts.Claim(d.Playtime, a, Config.PlaytimeGifts)
		if not ok then return false, why end
		Progress.Grant(player, g, "Gift")
		giftState(player)
		return true

	elseif action == "ClaimQuest" then
		Progress.Refresh(player)
		local set = a == "Weekly" and d.Quests.Weekly or d.Quests.Daily
		local st = set[b]
		local q = Progress.QuestById[b]
		if not st or not q then return false, "?" end
		if st.Claimed then return false, "Already claimed" end
		if st.Progress < q.Goal then return false, "Not finished" end
		st.Claimed = true
		Progress.Grant(player, q.Reward, "Quest")
		questReady(player)
		return true

	elseif action == "Redeem" then
		local code = type(a) == "string" and a:upper():gsub("%s", "") or ""
		local c = Config.Codes[code]
		if not c then return false, "Invalid code" end
		if d.Codes[code] then return false, "Already redeemed" end
		d.Codes[code] = true
		if c.Souls then DataService.AddSouls(player, c.Souls) end
		if c.Crates then d.FreeCrates = (d.FreeCrates or 0) + c.Crates end
		if c.Boost then DataService.AddBoost(player, c.Boost, c.Seconds or 600) end
		if c.Logs then DataService.AddCoins(player, c.Logs, nil, true) end -- M1: fixed amounts (L10)
		if c.LogsMult then DataService.AddCoins(player, Config.GetPriceUnit(player) * c.LogsMult, nil, true) end
		DataService.Sync(player)
		NotifyRemote:FireClient(player, "Code " .. code .. " redeemed!", "rare_Legendary")
		return true

	elseif action == "ClaimIndex" or action == "ClaimIndexAll" then
		-- one-time discovery rewards for weapons (kind "Weapon") and trees (kind "Tree")
		local function rewardFor(kind, id)
			if kind == "Weapon" then
				local w = Config.WeaponById[id]
				if not w or not d.Weapons[id] or d.IndexClaimed[id] then return nil end
				return Config.IndexRewards[w.Rarity], w.Name
			elseif kind == "Tree" then
				local tt = Config.TreeTypes[id]
				if not tt or not d.Trees[id] or d.TreeClaimed[id] then return nil end
				return Config.TreeIndexRewards[tt.Rarity], tt.Name
			end
		end
		local function mark(kind, id)
			if kind == "Weapon" then d.IndexClaimed[id] = true else d.TreeClaimed[id] = true end
		end
		if action == "ClaimIndex" then
			local rw, name = rewardFor(a, b)
			if not rw then return false, "Nothing to claim" end
			mark(a, b)
			Progress.Grant(player, rw, "📖 " .. name)
			return true
		end
		-- claim everything ready in one tab (a = "Weapon" | "Tree"), rewards merged
		local logs, souls, crates, boosts, n = 0, 0, 0, {}, 0
		local ids = {}
		if a == "Weapon" then for id in pairs(d.Weapons) do table.insert(ids, id) end
		else for id in pairs(d.Trees) do table.insert(ids, id) end end
		for _, id in ipairs(ids) do
			local rw = rewardFor(a, id)
			if rw then
				mark(a, id)
				n += 1
				if rw.Kind == "Logs" then logs += rw.Mult
				elseif rw.Kind == "Souls" then souls += rw.Amount
				elseif rw.Kind == "Crate" then crates += rw.Amount
				elseif rw.Kind == "Boost" then table.insert(boosts, rw) end
			end
		end
		if n == 0 then return false, "Nothing to claim" end
		local why = string.format("📖 %d discover%s", n, n == 1 and "y" or "ies")
		if logs > 0 then Progress.Grant(player, { Kind = "Logs", Mult = logs }, why) end
		if souls > 0 then Progress.Grant(player, { Kind = "Souls", Amount = souls }, why) end
		if crates > 0 then Progress.Grant(player, { Kind = "Crate", Amount = crates }, why) end
		for _, rw in ipairs(boosts) do Progress.Grant(player, rw, why) end
		return true, n

	elseif action == "SetBlades" then
		-- a = true -> blades spinning, false -> stopped (no blades, no hits)
		player:SetAttribute("BladesOff", a == false or nil)
		return true

	elseif action == "TutorialDone" then
		d.TutorialDone = true
		return true

	elseif action == "Rebirth" then
		local cost = Config.GetRebirthCost(d.Rebirths, player) -- M1: tier-scaled
		if d.Logs < cost then return false, "Need " .. Config.FormatNumber(cost) .. " Logs" end
		DataService.SpendCoins(player, d.Logs) -- all logs reset
		for _, u in ipairs(Config.Upgrades) do DataService.SetLevel(player, u.Id, 0) end
		d.Rebirths += 1
		player:SetAttribute("Rebirths", d.Rebirths)
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		NotifyRemote:FireAllClients(string.format("%s rebirthed! (Rebirth %d)", player.DisplayName, d.Rebirths), "rare_Mythic")
		return true, d.Rebirths
	end
	return false, "?"
end

--------------------------------------------------------------------
-- Join
--------------------------------------------------------------------
local function onPlayer(player)
	player:SetAttribute("SessionStart", workspace:GetServerTimeNow())
	task.spawn(function()
		while player.Parent and not player:GetAttribute("Loaded") do task.wait(0.25) end
		local d = DataService.Get(player)
		if not d then return end
		Gifts.Begin(d.Playtime, os.time(), today()) -- resume the visit or start a new one
		applyPrefs(player, d)
		player:SetAttribute("Rebirths", d.Rebirths or 0)
		questReady(player)
		giftState(player)
		if Config.GroupId and Config.GroupId > 0 then
			local ok, inGroup = pcall(function() return player:IsInGroupAsync(Config.GroupId) end)
			if ok and inGroup then
				player:SetAttribute("InGroup", true)
				DataService.RecalcMultipliers(player)
			end
		end
		DataService.Sync(player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p)
	lastAction[p] = nil
	local d = DataService.Get(p)
	if d and d.Playtime then d.Playtime.LastSeen = os.time() end
end)

-- play time + gift/quest badges, once a minute
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			local d = DataService.Get(p)
			if d then
				d.Stats.PlaySeconds += 60
				Gifts.Tick(d.Playtime, 60, os.time())
				Progress.Add(p, "Minutes", 1)
				giftState(p)
				questReady(p)
			end
		end
	end
end)

--------------------------------------------------------------------
-- Luck events
--------------------------------------------------------------------
local function startEvent(ev)
	workspace:SetAttribute("EventId", ev.Id)
	workspace:SetAttribute("EventEnd", workspace:GetServerTimeNow() + ev.Seconds)
	workspace:SetAttribute("EventLuck", ev.Luck)
	workspace:SetAttribute("EventLogs", ev.Logs)
	NotifyRemote:FireAllClients(ev.Name .. "!  " .. ev.Desc, ev.Id == "BloodMoon" and "rare_Mythic" or "rare_Legendary")
	task.wait(ev.Seconds)
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventEnd", nil)
	workspace:SetAttribute("EventLuck", 1)
	workspace:SetAttribute("EventLogs", 1)
end

workspace:SetAttribute("EventLuck", 1)
workspace:SetAttribute("EventLogs", 1)
local evRng = Random.new()
task.spawn(function()
	task.wait(evRng:NextNumber(360, 600)) -- first event 6-10 min after the server starts
	while true do
		local total = 0
		for _, e in ipairs(Config.Events) do total += e.Weight end
		local r = evRng:NextNumber() * total
		local pick = Config.Events[1]
		for _, e in ipairs(Config.Events) do
			r -= e.Weight
			if r <= 0 then pick = e break end
		end
		startEvent(pick)
		task.wait(evRng:NextNumber(Config.EventGap[1], Config.EventGap[2]))
	end
end)

-- Studio test hook: ServerStorage.DevMeta:Invoke("Event", id)
if game:GetService("RunService"):IsStudio() then
	local bf = game:GetService("ServerStorage"):FindFirstChild("DevMeta") or Instance.new("BindableFunction")
	bf.Name = "DevMeta"
	bf.OnInvoke = function(cmd, arg)
		if cmd == "Event" then
			for _, e in ipairs(Config.Events) do if e.Id == arg then task.spawn(startEvent, e) return true end end
		end
		if cmd == "SessionBack" then -- pretend everyone has played arg minutes
			for _, p in ipairs(Players:GetPlayers()) do
				local d = DataService.Get(p)
				if d then Gifts.Tick(d.Playtime, arg * 60, os.time()) giftState(p) end
			end
			return true
		end
		return false
	end
	bf.Parent = game:GetService("ServerStorage")
end
