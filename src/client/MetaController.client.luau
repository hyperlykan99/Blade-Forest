-- MetaController: Settings (+Stats, Codes), Gifts (daily + playtime), Quests,
-- Rebirth, TOP leaderboards, luck-event banner, music + graphics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Meta = Remotes:WaitForChild("Meta")
local GetData = Remotes:WaitForChild("GetData")
local DataSync = Remotes:WaitForChild("DataSync")
local LB = Remotes:WaitForChild("Leaderboards")

local player = Players.LocalPlayer
local myData

local gui = Instance.new("ScreenGui")
gui.Name = "MetaUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 13
gui.Parent = player:WaitForChild("PlayerGui")

local function tileButton(name)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(76, 76)
	b.Text = name
	b.Parent = gui
	return b
end
local function fmtTime(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%dh %02dm", s // 3600, (s // 60) % 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end
local function call(...)
	local ok, a, b = pcall(function(...) return Meta:InvokeServer(...) end, ...)
	if not ok then return false, "Error" end
	return a, b
end
local function row(parent, order, h)
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.new(1, -8, 0, h or 56)
	f.BackgroundColor3 = C.Plank
	f.Parent = parent
	T.Corner(f, 10)
	T.Stroke(f, C.Ink, 2)
	return f
end
local function scroller(parent, pos, size)
	local s = Instance.new("ScrollingFrame")
	s.Position = pos or UDim2.fromOffset(8, 8)
	s.Size = size or UDim2.new(1, -16, 1, -16)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = C.Gold
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Parent = parent
	local l = Instance.new("UIListLayout") l.Padding = UDim.new(0, 6) l.SortOrder = Enum.SortOrder.LayoutOrder l.HorizontalAlignment = Enum.HorizontalAlignment.Center l.Parent = s
	local p = Instance.new("UIPadding") p.PaddingTop = UDim.new(0, 4) p.PaddingBottom = UDim.new(0, 4) p.Parent = s
	return s
end
local function clear(f)
	for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
end
local function tabs(parent, names, onPick)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(8, 8)
	bar.Size = UDim2.new(1, -16, 0, 40)
	bar.Parent = parent
	local l = Instance.new("UIListLayout") l.FillDirection = Enum.FillDirection.Horizontal l.Padding = UDim.new(0, 6) l.Parent = bar
	local btns = {}
	local function pick(i)
		for j, b in ipairs(btns) do b.BackgroundColor3 = j == i and C.Gold or C.WoodLight end
		onPick(i)
	end
	for i, n in ipairs(names) do
		local b = T.Button(bar, { Size = UDim2.new(1 / #names, -6, 1, 0), Text = n, LayoutOrder = i }, C.WoodLight)
		b.Activated:Connect(function() pick(i) end)
		btns[i] = b
	end
	return pick
end

--------------------------------------------------------------------
-- Audio: music playlist (APM tracks from the Creator Store) + SFX group
--------------------------------------------------------------------
local musicGroup = Instance.new("SoundGroup") musicGroup.Name = "Music" musicGroup.Parent = SoundService
local sfxGroup = Instance.new("SoundGroup") sfxGroup.Name = "SFX" sfxGroup.Parent = SoundService
local PLAYLIST = { "rbxassetid://1842185080", "rbxassetid://1846800656", "rbxassetid://1842185105" }
local music = Instance.new("Sound")
music.Name = "BGMusic"
music.SoundGroup = musicGroup
music.Volume = 0.35
music.Parent = SoundService
local track = 0
local function nextTrack()
	track = track % #PLAYLIST + 1
	music.SoundId = PLAYLIST[track]
	music:Play()
end
music.Ended:Connect(nextTrack)
task.delay(2, nextTrack)
local function tagSfx(s)
	if s:IsA("Sound") and s ~= music and not s.SoundGroup then s.SoundGroup = sfxGroup end
end
workspace.DescendantAdded:Connect(tagSfx)
SoundService.DescendantAdded:Connect(tagSfx)

--------------------------------------------------------------------
-- Graphics
--------------------------------------------------------------------
local disabledEmitters = {}
local function applyGraphics(q)
	Lighting.GlobalShadows = q == "High"
	if q == "Low" then
		for _, e in ipairs(workspace:GetDescendants()) do
			if (e:IsA("ParticleEmitter") or e:IsA("Trail")) and e.Enabled and not e:IsDescendantOf(player.Character or workspace.Terrain) then
				e.Enabled = false
				disabledEmitters[e] = true
			end
		end
	else
		for e in pairs(disabledEmitters) do if e.Parent then e.Enabled = true end end
		table.clear(disabledEmitters)
	end
end

local function applyPrefs()
	musicGroup.Volume = player:GetAttribute("Pref_Music") or 0.5
	sfxGroup.Volume = player:GetAttribute("Pref_SFX") or 0.8
	applyGraphics(player:GetAttribute("Pref_Graphics") or "High")
end
player.AttributeChanged:Connect(function(a) if a:sub(1, 5) == "Pref_" then applyPrefs() end end)
task.delay(3, applyPrefs)

--------------------------------------------------------------------
-- SETTINGS panel (Settings / Stats / Codes)
--------------------------------------------------------------------
local settingsBtn = tileButton("SettingsButton")
local sPanel, sBody, sClose = T.Panel(gui, "SettingsPanel", "SETTINGS", C.Grey, 520)
local sContent = Instance.new("Frame") sContent.BackgroundTransparency = 1 sContent.Position = UDim2.fromOffset(0, 52) sContent.Size = UDim2.new(1, 0, 1, -52) sContent.Parent = sBody

local PREFS = {
	{ Key = "Music", Label = "Music", Kind = "Volume" },
	{ Key = "SFX", Label = "Sound Effects", Kind = "Volume" },
	{ Key = "Graphics", Label = "Graphics", Kind = "Choice", Options = { "Low", "Medium", "High" } },
	{ Key = "ScreenShake", Label = "Screen Shake", Kind = "Bool" },
	{ Key = "ReducedMotion", Label = "Reduced Motion", Kind = "Bool" },
	{ Key = "DamageNumbers", Label = "Damage Numbers", Kind = "Bool" },
	{ Key = "ShowTags", Label = "Tree Strength Tags", Kind = "Bool" },
	{ Key = "SkipReveals", Label = "Skip Roll Animations", Kind = "Bool" },
}
local function prefText(p, v)
	if p.Kind == "Volume" then return math.floor((v or 0) * 100 + 0.5) .. "%" end
	if p.Kind == "Bool" then return v and "ON" or "OFF" end
	return tostring(v)
end
local function showSettings()
	clear(sContent)
	local list = scroller(sContent)
	for i, p in ipairs(PREFS) do
		local r = row(list, i)
		T.Label(r, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.6, 0, 1, -16), Text = p.Label, TextXAlignment = Enum.TextXAlignment.Left })
		local v = player:GetAttribute("Pref_" .. p.Key)
		local b = T.Button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 42), Text = prefText(p, v) },
			(p.Kind == "Bool" and not v) and C.Grey or C.Leaf)
		b.Activated:Connect(function()
			local cur = player:GetAttribute("Pref_" .. p.Key)
			local nv
			if p.Kind == "Volume" then nv = ((math.floor((cur or 0) * 4 + 0.5) + 1) % 5) / 4
			elseif p.Kind == "Bool" then nv = not cur
			else nv = p.Options[(table.find(p.Options, cur) or 0) % #p.Options + 1] end
			if call("SetPref", p.Key, nv) then
				b.Text = prefText(p, nv)
				b.BackgroundColor3 = (p.Kind == "Bool" and not nv) and C.Grey or C.Leaf
			end
		end)
	end
end
local function statRows()
	local d = myData or {}
	local s = d.Stats or {}
	local rare = s.RarestId and Config.WeaponById[s.RarestId]
	return {
		{ "Logs Earned (all time)", Config.FormatNumber(s.LogsEarned or 0) },
		{ "Time Played", fmtTime(s.PlaySeconds or 0) },
		{ "Trees Chopped", Config.FormatNumber(s.TreesChopped or 0) },
		{ "Weapon Rolls", Config.FormatNumber(d.Rolls and d.Rolls.Total or 0) },
		{ "Rarest Pull", rare and (rare.Name .. " (" .. Config.FormatOneIn(rare.OneIn or 2) .. ")") or "-" },
		{ "Player Kills", Config.FormatNumber(d.Kills or 0) },
		{ "Souls Earned", Config.FormatNumber(s.SoulsEarned or 0) },
		{ "Rebirths", tostring(d.Rebirths or 0) },
		{ "Luck", "x" .. tostring(player:GetAttribute("LuckMult") or 1) },
		{ "Logs Multiplier", "x" .. tostring(player:GetAttribute("LogMult") or 1) },
	}
end
local function showStats()
	clear(sContent)
	local list = scroller(sContent)
	for i, sr in ipairs(statRows()) do
		local r = row(list, i, 44)
		T.Label(r, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.55, 0, 1, -16), Text = sr[1], TextXAlignment = Enum.TextXAlignment.Left })
		T.Label(r, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.new(0.43, 0, 1, -16), Text = sr[2], TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right }, true)
	end
end
local function showCodes()
	clear(sContent)
	T.Label(sContent, { Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 30), Text = "Enter a code for free rewards!" }, true)
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(16, 64)
	box.Size = UDim2.new(1, -32, 0, 56)
	box.BackgroundColor3 = C.Cream
	box.TextColor3 = C.Ink
	box.PlaceholderText = "Type code here"
	box.PlaceholderColor3 = Color3.fromRGB(150, 130, 110)
	box.Text = ""
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Parent = sContent
	T.Corner(box, 12)
	T.Stroke(box, C.Ink, 3)
	local msg = T.Label(sContent, { Position = UDim2.fromOffset(16, 200), Size = UDim2.new(1, -32, 0, 26), Text = "" })
	local b = T.Button(sContent, { Position = UDim2.fromOffset(16, 132), Size = UDim2.new(1, -32, 0, 56), Text = "REDEEM" }, C.Leaf)
	b.Activated:Connect(function()
		local ok, err = call("Redeem", box.Text)
		msg.Text = ok and "Redeemed!" or tostring(err)
		msg.TextColor3 = ok and C.Leaf or C.Red
	end)
	T.Label(sContent, { Position = UDim2.fromOffset(16, 240), Size = UDim2.new(1, -32, 0, 22), Text = "Follow the game for new codes!", TextColor3 = C.WoodLight })
end
local SETTINGS_TABS = { showSettings, showStats, showCodes }
local pickSettingsTab = tabs(sBody, { "SETTINGS", "STATS", "CODES" }, function(i)
	SETTINGS_TABS[i]()
end)
settingsBtn.Activated:Connect(function() sPanel.Visible = not sPanel.Visible if sPanel.Visible then pickSettingsTab(1) end end)
sClose.Activated:Connect(function() sPanel.Visible = false end)

--------------------------------------------------------------------
-- GIFTS panel (daily streak + playtime)
--------------------------------------------------------------------
local giftsBtn = tileButton("DailyButton")
local gPanel, gBody, gClose = T.Panel(gui, "GiftsPanel", "GIFTS", Color3.fromRGB(240, 90, 130), 560)
local gList = scroller(gBody)

local function refreshGifts()
	if not gPanel.Visible then return end
	clear(gList)
	local d = myData or {}
	local daily = d.Daily or { Streak = 0, LastDay = 0 }
	local today = math.floor(os.time() / 86400)
	local canClaim = daily.LastDay < today
	local nextStreak = canClaim and ((daily.LastDay == today - 1) and daily.Streak + 1 or 1) or daily.Streak
	-- daily header
	local h = row(gList, 1, 150)
	T.Label(h, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Text = "DAILY LOGIN  -  streak " .. (daily.Streak or 0) .. " day" .. ((daily.Streak or 0) == 1 and "" or "s"), TextColor3 = C.Gold }, true)
	local days = Instance.new("Frame") days.BackgroundTransparency = 1 days.Position = UDim2.fromOffset(8, 38) days.Size = UDim2.new(1, -16, 0, 56) days.Parent = h
	local dl = Instance.new("UIListLayout") dl.FillDirection = Enum.FillDirection.Horizontal dl.Padding = UDim.new(0, 4) dl.Parent = days
	for i, rw in ipairs(Config.DailyRewards) do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1 / 7, -4, 1, 0)
		local cur = ((nextStreak - 1) % 7) + 1
		f.BackgroundColor3 = (i == cur and canClaim) and C.Gold or (i < cur or (i == cur and not canClaim)) and C.LeafDark or C.WoodDark
		f.Parent = days
		T.Corner(f, 8)
		T.Label(f, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 0.4, 0), Text = "DAY " .. i }, true)
		T.Label(f, { Position = UDim2.new(0, 2, 0.42, 0), Size = UDim2.new(1, -4, 0.55, 0), Text = Config.RewardText(rw, d.BestArea), TextWrapped = true })
	end
	local b = T.Button(h, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.6, 0, 0, 40),
		Text = canClaim and "CLAIM DAY " .. nextStreak or "COME BACK TOMORROW" }, canClaim and C.Leaf or C.Grey)
	b.Activated:Connect(function()
		if call("ClaimDaily") then task.delay(0.3, refreshGifts) end
	end)
	-- playtime gifts
	local claimed = {}
	for s in string.gmatch(player:GetAttribute("GiftsClaimed") or "", "%d+") do claimed[tonumber(s)] = true end
	local elapsed = workspace:GetServerTimeNow() - (player:GetAttribute("SessionStart") or workspace:GetServerTimeNow())
	local ph = row(gList, 2, 40)
	ph.BackgroundTransparency = 1
	T.Label(ph, { Size = UDim2.fromScale(1, 1), Text = "PLAYTIME GIFTS  (this visit)", TextColor3 = C.Gold }, true)
	for i, g in ipairs(Config.PlaytimeGifts) do
		local r = row(gList, 2 + i, 52)
		T.Label(r, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.55, 0, 1, -16), Text = Config.RewardText(g, d.BestArea), TextXAlignment = Enum.TextXAlignment.Left })
		local left = g.Minutes * 60 - elapsed
		local txt, col = "CLAIM", C.Leaf
		if claimed[i] then txt, col = "CLAIMED", C.Grey
		elseif left > 0 then txt, col = fmtTime(left), C.WoodLight end
		local b2 = T.Button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 40), Text = txt }, col)
		b2.Activated:Connect(function()
			if call("ClaimGift", i) then task.delay(0.3, refreshGifts) end
		end)
	end
end
giftsBtn.Activated:Connect(function() gPanel.Visible = not gPanel.Visible refreshGifts() end)
gClose.Activated:Connect(function() gPanel.Visible = false end)

--------------------------------------------------------------------
-- QUESTS panel
--------------------------------------------------------------------
local questsBtn = tileButton("QuestsButton")
local qPanel, qBody, qClose = T.Panel(gui, "QuestsPanel", "QUESTS", C.Leaf, 560)
local qList = scroller(qBody)
local QBY = {}
for _, q in ipairs(Config.DailyQuests) do QBY[q.Id] = q end
for _, q in ipairs(Config.WeeklyQuests) do QBY[q.Id] = q end

local function refreshQuests()
	if not qPanel.Visible then return end
	clear(qList)
	local d = myData or {}
	local qs = d.Quests or { Daily = {}, Weekly = {} }
	local now = os.time()
	local order = 0
	for _, kind in ipairs({ "Daily", "Weekly" }) do
		order += 1
		local reset = kind == "Daily" and (86400 - now % 86400) or ((7 - ((math.floor(now / 86400) + 3) % 7)) * 86400 - now % 86400)
		local hdr = row(qList, order, 34)
		hdr.BackgroundTransparency = 1
		T.Label(hdr, { Size = UDim2.fromScale(1, 1), Text = kind:upper() .. " QUESTS  -  new in " .. fmtTime(reset), TextColor3 = C.Gold }, true)
		local ids = {}
		for id in pairs(qs[kind] or {}) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local q, st = QBY[id], qs[kind][id]
			if q then
				order += 1
				local r = row(qList, order, 70)
				T.Label(r, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 24), Text = string.format(q.Text, Config.FormatNumber(q.Goal)), TextXAlignment = Enum.TextXAlignment.Left })
				local barBg = Instance.new("Frame") barBg.Position = UDim2.fromOffset(12, 36) barBg.Size = UDim2.new(1, -170, 0, 22) barBg.BackgroundColor3 = C.WoodDark barBg.Parent = r
				T.Corner(barBg, 11)
				local fill = Instance.new("Frame") fill.Size = UDim2.new(math.clamp(st.Progress / q.Goal, 0, 1), 0, 1, 0) fill.BackgroundColor3 = C.Leaf fill.Parent = barBg
				T.Corner(fill, 11)
				T.Label(barBg, { Size = UDim2.fromScale(1, 1), Text = Config.FormatNumber(st.Progress) .. " / " .. Config.FormatNumber(q.Goal) .. "   •   " .. Config.RewardText(q.Reward, d.BestArea), ZIndex = 3 })
				local done = st.Progress >= q.Goal
				local b = T.Button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 46),
					Text = st.Claimed and "DONE" or (done and "CLAIM" or "...") }, (done and not st.Claimed) and C.Leaf or C.Grey)
				b.Activated:Connect(function()
					if call("ClaimQuest", kind, id) then task.delay(0.3, refreshQuests) end
				end)
			end
		end
	end
end
questsBtn.Activated:Connect(function() qPanel.Visible = not qPanel.Visible refreshQuests() end)
qClose.Activated:Connect(function() qPanel.Visible = false end)

--------------------------------------------------------------------
-- REBIRTH panel
--------------------------------------------------------------------
local rebirthBtn = tileButton("RebirthButton")
local rPanel, rBody, rClose = T.Panel(gui, "RebirthPanel", "REBIRTH", C.Red, 500)
local confirmUntil = 0
local function refreshRebirth()
	if not rPanel.Visible then return end
	clear(rBody)
	local n = (myData and myData.Rebirths) or 0
	local cost = Config.GetRebirthCost(n)
	local logs = (myData and myData.Logs) or 0
	local R = Config.Rebirth
	T.Label(rBody, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 40), Text = "REBIRTHS: " .. n, TextColor3 = C.Gold }, true)
	T.Label(rBody, { Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 28),
		Text = string.format("Now: x%.2f Logs  •  x%.2f Luck", 1 + R.LogsPer * n, 1 + R.LuckPer * n) })
	T.Label(rBody, { Position = UDim2.fromOffset(16, 92), Size = UDim2.new(1, -32, 0, 28), TextColor3 = C.Leaf,
		Text = string.format("Next: x%.2f Logs  •  x%.2f Luck", 1 + R.LogsPer * (n + 1), 1 + R.LuckPer * (n + 1)) })
	local barBg = Instance.new("Frame") barBg.Position = UDim2.fromOffset(16, 136) barBg.Size = UDim2.new(1, -32, 0, 34) barBg.BackgroundColor3 = C.WoodDark barBg.Parent = rBody
	T.Corner(barBg, 17)
	local fill = Instance.new("Frame") fill.Size = UDim2.new(math.clamp(logs / cost, 0, 1), 0, 1, 0) fill.BackgroundColor3 = C.Gold fill.Parent = barBg
	T.Corner(fill, 17)
	T.Label(barBg, { Size = UDim2.fromScale(1, 1), Text = Config.FormatNumber(logs) .. " / " .. Config.FormatNumber(cost) .. " Logs", ZIndex = 3 }, true)
	T.Label(rBody, { Position = UDim2.fromOffset(16, 184), Size = UDim2.new(1, -32, 0, 44), TextWrapped = true, TextColor3 = C.WoodLight,
		Text = "Resets your Logs and upgrades. You KEEP weapons, traits, Souls and passes." })
	local ready = logs >= cost
	local b = T.Button(rBody, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.7, 0, 0, 60),
		Text = ready and (os.clock() < confirmUntil and "TAP AGAIN TO CONFIRM" or "REBIRTH!") or "NEED MORE LOGS" }, ready and C.Red or C.Grey)
	b.Activated:Connect(function()
		if not ready then return end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			call("Rebirth")
		else
			confirmUntil = os.clock() + 3
		end
		task.delay(0.2, refreshRebirth)
	end)
end
rebirthBtn.Activated:Connect(function() rPanel.Visible = not rPanel.Visible refreshRebirth() end)
rClose.Activated:Connect(function() rPanel.Visible = false end)

--------------------------------------------------------------------
-- TOP (leaderboards) panel
--------------------------------------------------------------------
local topBtn = tileButton("LeaderboardButton")
local tPanel, tBody, tClose = T.Panel(gui, "TopPanel", "LEADERBOARDS", C.GoldDark, 560)
local tContent = Instance.new("Frame") tContent.BackgroundTransparency = 1 tContent.Position = UDim2.fromOffset(0, 100) tContent.Size = UDim2.new(1, 0, 1, -100) tContent.Parent = tBody
local boards = {}
local function showBoard(i)
	clear(tContent)
	local b = boards[i]
	if not b then return end
	local list = scroller(tContent)
	if #b.List == 0 then
		T.Label(list, { Size = UDim2.new(1, 0, 0, 40), Text = "No entries yet" })
	end
	for rank, e in ipairs(b.List) do
		local r = row(list, rank, 40)
		if e.UserId == player.UserId then r.BackgroundColor3 = C.LeafDark end
		local medal = ({ C.Gold, Color3.fromRGB(220, 225, 235), Color3.fromRGB(230, 150, 80) })[rank] or C.Cream
		T.Label(r, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0, 50, 1, -12), Text = "#" .. rank, TextColor3 = medal }, true)
		T.Label(r, { Position = UDim2.fromOffset(66, 6), Size = UDim2.new(0.55, -66, 1, -12), Text = e.Name, TextXAlignment = Enum.TextXAlignment.Left })
		T.Label(r, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.new(0.4, 0, 1, -12), Text = e.Text, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right }, true)
	end
end
local tabRow = Instance.new("Frame") tabRow.BackgroundTransparency = 1 tabRow.Position = UDim2.fromOffset(8, 8) tabRow.Size = UDim2.new(1, -16, 0, 86) tabRow.Parent = tBody
local tg = Instance.new("UIGridLayout") tg.CellSize = UDim2.new(1 / 3, -6, 0, 38) tg.CellPadding = UDim2.fromOffset(6, 6) tg.Parent = tabRow
local tabBtns = {}
local currentBoard = 1
local function pickBoard(i)
	currentBoard = i
	for j, b in ipairs(tabBtns) do b.BackgroundColor3 = j == i and C.Gold or C.WoodLight end
	showBoard(i)
end
for i, name in ipairs({ "LOGS", "RAREST", "HOURS", "ROLLS", "KILLS", "SOULS" }) do
	local b = T.Button(tabRow, { Text = name, LayoutOrder = i }, C.WoodLight)
	b.Activated:Connect(function() pickBoard(i) end)
	tabBtns[i] = b
end
topBtn.Activated:Connect(function()
	tPanel.Visible = not tPanel.Visible
	if tPanel.Visible then
		local ok, data = pcall(function() return LB:InvokeServer() end)
		boards = ok and data or {}
		pickBoard(currentBoard)
	end
end)
tClose.Activated:Connect(function() tPanel.Visible = false end)

--------------------------------------------------------------------
-- Luck event banner
--------------------------------------------------------------------
local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.Size = UDim2.new(1, 0, 0, 31)
banner.BackgroundColor3 = C.WoodDark
banner.BorderSizePixel = 0
banner.LayoutOrder = 2
banner.Visible = false
T.AttachToHud(banner, "StatusRail")
T.Corner(banner, 6)
local bannerEdge = T.Stroke(banner, C.Gold, 1)
local bannerText = T.Label(banner, {
	Position = UDim2.fromOffset(7, 1), Size = UDim2.new(1, -51, 0, 15),
	Text = "", TextSize = 13, TextScaled = false, TextXAlignment = Enum.TextXAlignment.Left,
})
local eventEffect = T.Label(banner, {
	Position = UDim2.fromOffset(7, 16), Size = UDim2.new(1, -14, 0, 13),
	Text = "", TextSize = 12, TextScaled = false, TextXAlignment = Enum.TextXAlignment.Left,
})
local eventTime = T.Label(banner, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 1),
	Size = UDim2.fromOffset(43, 15), Text = "", TextSize = 13, TextScaled = false,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local EV = {}
for _, e in ipairs(Config.Events) do EV[e.Id] = e end

--------------------------------------------------------------------
-- Data + badges + timers
--------------------------------------------------------------------
local function onData(d)
	myData = d
	refreshGifts()
	refreshQuests()
	refreshRebirth()
end
DataSync.OnClientEvent:Connect(onData)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then onData(d) end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then return end
	acc = 0
	giftsBtn:SetAttribute("Badge", player:GetAttribute("GiftReady") == true)
	questsBtn:SetAttribute("Badge", player:GetAttribute("QuestReady") == true)
	local canRebirth = myData and myData.Logs and myData.Logs >= Config.GetRebirthCost(myData.Rebirths or 0)
	rebirthBtn:SetAttribute("Badge", canRebirth == true)
	-- event banner
	local id = workspace:GetAttribute("EventId")
	local e = id and EV[id]
	if e then
		banner.Visible = true
		bannerEdge.Color = e.Color
		bannerText.TextColor3 = e.Color:Lerp(C.Cream, 0.55)
		bannerText.Text = e.Name
		eventEffect.Text = e.Desc:gsub(" for everyone!", ""):gsub("!", "")
		eventTime.Text = fmtTime((workspace:GetAttribute("EventEnd") or 0) - workspace:GetServerTimeNow())
	else
		banner.Visible = false
	end
	if gPanel.Visible then refreshGifts() end
end)

-- blood moon tint
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "EventTint"
cc.Enabled = false
cc.Parent = Lighting
workspace:GetAttributeChangedSignal("EventId"):Connect(function()
	local id = workspace:GetAttribute("EventId")
	cc.Enabled = id == "BloodMoon" or id == "GoldenHour"
	cc.TintColor = id == "BloodMoon" and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(255, 235, 190)
	cc.Saturation = id == "BloodMoon" and 0.15 or 0.1
end)
