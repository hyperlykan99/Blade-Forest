-- AFKController: AFK Mode button -> full-screen session tracker.
-- Turns on auto roll + Auto Chop, shows what you got this session,
-- and avoids the 20-minute idle kick by hopping to a fresh server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AFKRejoin = Remotes:WaitForChild("AFKRejoin")

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")

--------------------------------------------------------------------
-- Session tracking (always on, since join)
--------------------------------------------------------------------
local session = { Start = os.time(), Rolls = 0, BestId = nil, BestOneIn = 0, New = {}, Logs = 0, Souls = 0, Trees = 0 }
local tdata = TeleportService:GetLocalPlayerTeleportData()
local resume = false
if type(tdata) == "table" and tdata.ResumeAFK then
	resume = true
	local s = tdata.Session
	if type(s) == "table" then
		for k, v in pairs(s) do session[k] = v end
	end
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local function track(name, key)
		local v = ls:WaitForChild(name)
		local last = v.Value
		v.Changed:Connect(function(n)
			if n > last then session[key] += n - last end
			last = n
		end)
	end
	track("Logs", "Logs")
	track("Souls", "Souls")
end)

local function onResult(result)
	session.Rolls += 1
	if (result.OneIn or 0) > session.BestOneIn then
		session.BestOneIn = result.OneIn
		session.BestId = result.Id
	end
	if result.IsNew then
		table.insert(session.New, result.Id)
		if #session.New > 40 then table.remove(session.New, 1) end
	end
end
task.spawn(function()
	local rc = scripts:WaitForChild("RollController")
	rc:WaitForChild("RollResult").Event:Connect(onResult)
end)

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AFKUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local afkBtn = Instance.new("TextButton")
afkBtn.Name = "AFKButton"
afkBtn.Size = UDim2.fromOffset(76, 76)
afkBtn.Text = "AFK"
afkBtn.Parent = gui

local screen = Instance.new("Frame")
screen.Name = "AFKScreen"
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundColor3 = Color3.fromRGB(14, 10, 8)
screen.BackgroundTransparency = 0.25
screen.Visible = false
screen.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(520, 600)
local cardScale = Instance.new("UIScale") cardScale.Parent = card
local function fitCard()
	local vp = workspace.CurrentCamera.ViewportSize
	cardScale.Scale = math.min(1, (vp.Y - 70) / 600, (vp.X - 20) / 520)
end
fitCard()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCard)
card.BackgroundColor3 = C.Wood
card.Parent = screen
T.Corner(card, 20)
T.Stroke(card, C.Ink, 5)
local cg = Instance.new("UIGradient") cg.Rotation = 90 cg.Color = ColorSequence.new(C.WoodLight, C.WoodDark) cg.Parent = card
local lim = Instance.new("UISizeConstraint") lim.MaxSize = Vector2.new(520, 620) lim.Parent = card

T.Label(card, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 46), Text = "AFK MODE", TextColor3 = C.Gold }, true)
local timeLbl = T.Label(card, { Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 26), Text = "" })
local statusLbl = T.Label(card, { Position = UDim2.fromOffset(20, 88), Size = UDim2.new(1, -40, 0, 20), Text = "Auto Roll + Auto Chop are running", TextColor3 = C.Leaf })

-- stat tiles
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(20, 118)
grid.Size = UDim2.new(1, -40, 0, 150)
grid.Parent = card
local gl = Instance.new("UIGridLayout") gl.CellSize = UDim2.new(0.5, -6, 0, 70) gl.CellPadding = UDim2.fromOffset(12, 10) gl.Parent = grid
local tiles = {}
for i, spec in ipairs({ { "Rolls", "ROLLS" }, { "Logs", "LOGS EARNED" }, { "Souls", "SOULS EARNED" }, { "New", "NEW WEAPONS" } }) do
	local f = Instance.new("Frame")
	f.LayoutOrder = i
	f.BackgroundColor3 = C.WoodDark
	f.Parent = grid
	T.Corner(f, 12)
	T.Stroke(f, C.Ink, 3)
	T.Label(f, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 18), Text = spec[2], TextColor3 = C.WoodLight })
	tiles[spec[1]] = T.Label(f, { Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 0, 40), Text = "0", TextColor3 = C.Cream }, true)
end

-- best pull
local best = Instance.new("Frame")
best.Position = UDim2.fromOffset(20, 280)
best.Size = UDim2.new(1, -40, 0, 64)
best.BackgroundColor3 = C.WoodDark
best.Parent = card
T.Corner(best, 12)
local bestStroke = T.Stroke(best, C.Gold, 3)
T.Label(best, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, 0, 0, 18), Text = "BEST PULL", TextColor3 = C.WoodLight, TextXAlignment = Enum.TextXAlignment.Left })
local bestName = T.Label(best, { Position = UDim2.fromOffset(12, 22), Size = UDim2.new(0.62, 0, 0, 36), Text = "-", TextXAlignment = Enum.TextXAlignment.Left }, true)
local bestOdds = T.Label(best, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 20), Size = UDim2.new(0.36, 0, 0, 34), Text = "", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right }, true)

-- new weapons list
T.Label(card, { Position = UDim2.fromOffset(20, 352), Size = UDim2.new(1, -40, 0, 20), Text = "FOUND THIS SESSION", TextColor3 = C.WoodLight, TextXAlignment = Enum.TextXAlignment.Left })
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(20, 376)
list.Size = UDim2.new(1, -40, 1, -376 - 84)
list.BackgroundColor3 = C.WoodDark
list.BackgroundTransparency = 0.3
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = card
T.Corner(list, 10)
local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 4) ll.SortOrder = Enum.SortOrder.LayoutOrder ll.Parent = list
local lp = Instance.new("UIPadding") lp.PaddingTop = UDim.new(0, 6) lp.PaddingLeft = UDim.new(0, 8) lp.PaddingRight = UDim.new(0, 8) lp.Parent = list

local batteryBtn = T.Button(card, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -16), Size = UDim2.new(0.5, -26, 0, 54), Text = "SAVE BATTERY: OFF" }, C.Grey)
local exitBtn = T.Button(card, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -16), Size = UDim2.new(0.5, -26, 0, 54), Text = "EXIT AFK" }, C.Red)

local shownNew = 0
local function fmtTime(sec)
	return string.format("%d:%02d:%02d", sec // 3600, (sec // 60) % 60, sec % 60)
end
local function rarityColor(w)
	local r = Config.RarityById[w.Rarity]
	return r.Rainbow and Color3.new(1, 1, 1) or r.Color
end
local function refresh()
	timeLbl.Text = "Session " .. fmtTime(os.time() - session.Start)
	tiles.Rolls.Text = Config.FormatNumber(session.Rolls)
	tiles.Logs.Text = Config.FormatNumber(session.Logs)
	tiles.Souls.Text = Config.FormatNumber(session.Souls)
	tiles.New.Text = tostring(#session.New)
	local w = session.BestId and Config.WeaponById[session.BestId]
	if w then
		bestName.Text = w.Name
		bestName.TextColor3 = rarityColor(w)
		bestOdds.Text = Config.FormatOneIn(w.OneIn or 2)
		bestStroke.Color = Config.RarityById[w.Rarity].Color
	end
	while shownNew < #session.New do
		shownNew += 1
		local nw = Config.WeaponById[session.New[shownNew]]
		if nw then
			local row = T.Label(list, { LayoutOrder = -shownNew, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left,
				Text = nw.Name .. "   " .. Config.FormatOneIn(nw.OneIn or 2), TextColor3 = rarityColor(nw) })
			row:SetAttribute("NoTheme", true)
		end
	end
end

--------------------------------------------------------------------
-- AFK on/off
--------------------------------------------------------------------
local afk = false
local saveBattery = false
local function api(name, ...)
	local s = scripts:FindFirstChild(name)
	if not s then return end
	for _, c in ipairs(s:GetChildren()) do
		if c:IsA("BindableFunction") then return c:Invoke(...) end
	end
end

local function setBattery(on)
	saveBattery = on
	pcall(function() RunService:Set3dRenderingEnabled(not on) end)
	screen.BackgroundTransparency = on and 0 or 0.25
	batteryBtn.Text = on and "SAVE BATTERY: ON" or "SAVE BATTERY: OFF"
	batteryBtn.BackgroundColor3 = on and C.Leaf or C.Grey
end

local function setAFK(on)
	afk = on
	screen.Visible = on
	player:SetAttribute("AFKMode", on)
	if on then
		api("RollController", "SetAuto", true)
		api("AutoChop", true)
		refresh()
	else
		api("RollController", "SetAuto", false)
		api("AutoChop", false)
		setBattery(false)
	end
end

afkBtn.Activated:Connect(function() setAFK(not afk) end)
exitBtn.Activated:Connect(function() setAFK(false) end)
batteryBtn.Activated:Connect(function() setBattery(not saveBattery) end)

task.spawn(function()
	while true do
		if afk then refresh() end
		task.wait(1)
	end
end)

-- anti idle-kick: rejoin a fresh server at 17+ idle minutes while AFK/auto
player.Idled:Connect(function(idleSeconds)
	local auto = afk or player:GetAttribute("AutoChop") or api("RollController", "IsAuto")
	if auto and idleSeconds >= 17 * 60 then
		statusLbl.Text = "Moving you to a fresh server so you don't get kicked..."
		AFKRejoin:FireServer({ Start = session.Start, Rolls = session.Rolls, BestId = session.BestId, BestOneIn = session.BestOneIn,
			New = session.New, Logs = session.Logs, Souls = session.Souls })
	end
end)

if resume then
	task.spawn(function()
		while not player:GetAttribute("Loaded") do task.wait(0.3) end
		task.wait(2)
		setAFK(true)
	end)
end
