-- ExtrasController: PETS (hatch / equip + pets that follow every player),
-- MARKET (sawmill: Logs -> Souls), TROPHY (achievements) and the
-- Ancient Treant status chip. World prompts (Pet Egg / Log Market) open the panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Extras = Remotes:WaitForChild("Extras")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")
local PetModels = ReplicatedStorage:WaitForChild("PetModels")

local player = Players.LocalPlayer
local myData

local gui = Instance.new("ScreenGui")
gui.Name = "ExtrasUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

local function call(...)
	local args = table.pack(...)
	local ok, a, b = pcall(function() return Extras:InvokeServer(table.unpack(args, 1, args.n)) end)
	if ok then return a, b end
	return false, "Error"
end

local function flash(btn, text)
	local old = btn.Text
	btn.Text = text
	task.delay(1.4, function() if btn.Text == text then btn.Text = old end end)
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
end

local function scroller(parent, pos, size, grid)
	local s = Instance.new("ScrollingFrame")
	s.Position = pos
	s.Size = size
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Parent = parent
	if grid then
		local g = Instance.new("UIGridLayout")
		g.CellSize = grid
		g.CellPadding = UDim2.fromOffset(8, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.HorizontalAlignment = Enum.HorizontalAlignment.Center
		g.Parent = s
	else
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 6)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = s
	end
	local p = Instance.new("UIPadding") p.PaddingTop = UDim.new(0, 4) p.PaddingBottom = UDim.new(0, 8) p.PaddingLeft = UDim.new(0, 4) p.PaddingRight = UDim.new(0, 8) p.Parent = s
	return s
end

local function tile(name)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(76, 76)
	b.Text = ""
	b.Parent = gui -- UIStyler moves it into the dock
	return b
end

--------------------------------------------------------------------
-- PETS panel
--------------------------------------------------------------------
local petsBtn = tile("PetsButton")
local pPanel, pBody, pClose = T.Panel(gui, "PetsPanel", "PETS", Color3.fromRGB(240, 140, 90), 560, 0.86)
local hatchInfo = T.Label(pBody, { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 22), Text = "" })
local hatch1 = T.Button(pBody, { Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(0.32, -8, 0, 44), Text = "HATCH x1" }, C.Leaf)
local hatch3 = T.Button(pBody, { Position = UDim2.new(0.32, 6, 0, 50), Size = UDim2.new(0.32, -8, 0, 44), Text = "HATCH x3" }, C.LeafDark)
local equipBest = T.Button(pBody, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 50), Size = UDim2.new(0.34, -8, 0, 44), Text = "EQUIP BEST" }, C.Blue)
local bonusLine = T.Label(pBody, { Position = UDim2.fromOffset(12, 100), Size = UDim2.new(1, -24, 0, 20), Text = "", TextColor3 = C.Gold })
local petGrid = scroller(pBody, UDim2.fromOffset(6, 126), UDim2.new(1, -12, 1, -132), UDim2.fromOffset(150, 170))

local function petViewport(parent, id)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -8, 0, 76)
	vp.Position = UDim2.fromOffset(4, 4)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local t = PetModels:FindFirstChild(id)
	if t then
		local m = t:Clone()
		m:PivotTo(CFrame.Angles(0, math.rad(200), 0))
		m.Parent = vp
		local cf, ext = m:GetBoundingBox()
		local r = math.max(ext.X, ext.Y, ext.Z) * 0.55
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, r * 0.3, r / math.tan(math.rad(15)) * 1.05), cf.Position)
	end
	return vp
end

local function refreshPets()
	if not myData or not pPanel.Visible then return end
	local cost = Config.GetEggCost(player) -- M1: progression tier (server sets PriceUnit)
	hatchInfo.Text = string.format("🥚 Pet Egg: %s Logs each  •  you have %s", Config.FormatNumber(cost), Config.FormatNumber(myData.Logs or 0))
	local eq = myData.EquippedPets or {}
	local maxP = Config.MaxPetsEquipped + (player:GetAttribute("Pass_VIP") and 1 or 0)
	local logs, luck = 0, 0
	for _, id in ipairs(eq) do local p = Config.PetById[id] if p then logs += p.Logs luck += p.Luck end end
	bonusLine.Text = string.format("Equipped %d/%d  •  +%d%% Logs  •  +%d%% Luck", #eq, maxP, logs * 100, luck * 100)
	clear(petGrid)
	for _, p in ipairs(Config.Pets) do
		local owned = (myData.Pets or {})[p.Id] or 0
		local using = 0
		for _, id in ipairs(eq) do if id == p.Id then using += 1 end end
		local r = Config.RarityById[p.Rarity]
		local f = Instance.new("Frame")
		f.LayoutOrder = p.Order
		f.BackgroundColor3 = owned > 0 and C.Plank or C.WoodDark
		f.Parent = petGrid
		T.Corner(f, 12)
		T.Stroke(f, r.Color, 3)
		local vp = petViewport(f, p.Id)
		if owned == 0 then vp.ImageColor3 = Color3.new(0, 0, 0) end
		T.Label(f, { Position = UDim2.fromOffset(6, 80), Size = UDim2.new(1, -12, 0, 20), Text = owned > 0 and p.Name or "???", TextColor3 = r.Color })
		T.Label(f, { Position = UDim2.fromOffset(6, 100), Size = UDim2.new(1, -12, 0, 15), Text = string.format("%s • %.1f%%", p.Rarity, p.Weight) })
		T.Label(f, { Position = UDim2.fromOffset(6, 116), Size = UDim2.new(1, -12, 0, 15), TextColor3 = C.Gold,
			Text = string.format("+%d%% Logs%s", p.Logs * 100, p.Luck > 0 and string.format(" +%d%% Luck", p.Luck * 100) or "") })
		if owned > 0 then
			local b = T.Button(f, { Position = UDim2.fromOffset(6, 134), Size = UDim2.new(1, -12, 0, 30),
				Text = using > 0 and string.format("UNEQUIP (%d/%d)", using, owned) or string.format("EQUIP (x%d)", owned) }, using > 0 and C.Grey or C.Blue)
			b.Activated:Connect(function()
				local ok, msg = call(using > 0 and "UnequipPet" or "EquipPet", p.Id)
				if not ok then flash(b, msg or "Can't") end
			end)
		end
	end
end

local function doHatch(n, btn)
	local ok, res = call("Hatch", n)
	if not ok then flash(btn, res or "Can't") return end
	local names = {}
	for _, id in ipairs(res) do table.insert(names, Config.PetById[id].Name) end
	flash(btn, "🐣 " .. table.concat(names, ", "))
end
hatch1.Activated:Connect(function() doHatch(1, hatch1) end)
hatch3.Activated:Connect(function() doHatch(3, hatch3) end)
equipBest.Activated:Connect(function() call("EquipBestPets") end)
petsBtn.Activated:Connect(function() pPanel.Visible = not pPanel.Visible refreshPets() end)
pClose.Activated:Connect(function() pPanel.Visible = false end)

--------------------------------------------------------------------
-- MARKET (sawmill) panel
--------------------------------------------------------------------
local marketBtn = tile("MarketButton")
local mPanel, mBody, mClose = T.Panel(gui, "MarketPanel", "LOG MARKET", C.WoodLight, 480, 0.7)
local mInfo = T.Label(mBody, { Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 90), Text = "", TextWrapped = true, TextScaled = true })
local sellBtns = {}
for i, frac in ipairs({ 0.1, 0.25, 0.5, 1 }) do
	local b = T.Button(mBody, { Position = UDim2.new((i - 1) * 0.25, 8, 0, 128), Size = UDim2.new(0.25, -12, 0, 50),
		Text = frac == 1 and "SELL ALL" or string.format("SELL %d%%", frac * 100) }, i == 4 and C.Orange or C.Leaf)
	sellBtns[i] = b
	b.Activated:Connect(function()
		local ok, res = call("SawmillSell", frac)
		flash(b, ok and ("+" .. tostring(res) .. " Souls") or (res or "Can't"))
	end)
end
local mNote = T.Label(mBody, { Position = UDim2.fromOffset(14, 186), Size = UDim2.new(1, -28, 0, 40), Text = "The price changes every hour - sell when the rate is high!", TextColor3 = C.WoodLight, TextWrapped = true })
local function refreshMarket()
	if not mPanel.Visible then return end
	local ok, info = call("SawmillInfo")
	if not ok or type(info) ~= "table" then return end
	local soulsFor = math.floor((myData and myData.Logs or 0) / (info.LogsPerSoul / info.Rate))
	mInfo.Text = string.format("🪚 Rate now: x%.2f  (next hour x%.2f in %d min)\n%s Logs = 1 Soul\nToday: %d / %d Souls  •  all your Logs = ~%d Souls",
		info.Rate, info.NextRate, math.ceil(info.SecondsLeft / 60), Config.FormatNumber(info.LogsPerSoul / info.Rate), info.Today, info.Cap,
		math.min(soulsFor, info.Cap - info.Today))
end
marketBtn.Activated:Connect(function() mPanel.Visible = not mPanel.Visible refreshMarket() end)
mClose.Activated:Connect(function() mPanel.Visible = false end)

--------------------------------------------------------------------
-- TROPHY (achievements) panel
--------------------------------------------------------------------
local achBtn = tile("AchievementsButton")
local aPanel, aBody, aClose = T.Panel(gui, "AchievementsPanel", "TROPHIES", Color3.fromRGB(200, 150, 40), 560, 0.86)
local aList = scroller(aBody, UDim2.fromOffset(6, 24), UDim2.new(1, -12, 1, -30))
local function refreshAch()
	if not myData or not aPanel.Visible then return end
	clear(aList)
	for i, a in ipairs(Config.Achievements) do
		local prog = Config.AchievementProgress(myData, a.Stat)
		local claimed = myData.Achievements and myData.Achievements[a.Id]
		local done = prog >= a.Goal
		local row = Instance.new("Frame")
		row.LayoutOrder = (claimed and 2000 or (done and 0 or 1000)) + i
		row.Size = UDim2.new(1, -6, 0, 62)
		row.BackgroundColor3 = claimed and C.WoodDark or C.Plank
		row.Parent = aList
		T.Corner(row, 10)
		T.Label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.62, 0, 0, 26), Text = (claimed and "✔ " or "🎖️ ") .. a.Name, TextXAlignment = Enum.TextXAlignment.Left }, true)
		local shown = a.Stat == "Rarest" and (prog >= a.Goal and "done" or Config.FormatOneIn(math.max(prog, 1))) or (Config.FormatNumber(math.min(prog, a.Goal)) .. " / " .. Config.FormatNumber(a.Goal))
		T.Label(row, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(0.62, 0, 0, 22), Text = a.Desc .. "  •  " .. shown, TextColor3 = C.WoodLight, TextXAlignment = Enum.TextXAlignment.Left })
		local b = T.Button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.36, 0, 0, 44),
			Text = claimed and "CLAIMED" or ("🎁 " .. Config.RewardText(a.Reward, player)) }, claimed and C.Grey or (done and C.Gold or C.WoodDark))
		if done and not claimed then
			b.Activated:Connect(function()
				local ok, msg = call("ClaimAchievement", a.Id)
				if not ok then flash(b, msg or "Can't") end
			end)
		end
	end
end
achBtn.Activated:Connect(function() aPanel.Visible = not aPanel.Visible refreshAch() end)
aClose.Activated:Connect(function() aPanel.Visible = false end)
local function achBadge()
	local n = player:GetAttribute("AchReady") or 0
	achBtn:SetAttribute("Badge", n > 0 and tostring(n) or false)
end
player:GetAttributeChangedSignal("AchReady"):Connect(achBadge)
achBadge()

--------------------------------------------------------------------
-- World prompts open the panels
--------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local which = prompt:GetAttribute("OpenPanel")
	if which == "Pets" then pPanel.Visible = true refreshPets()
	elseif which == "Sawmill" then mPanel.Visible = true refreshMarket() end
end)

--------------------------------------------------------------------
-- Data
--------------------------------------------------------------------
local function setData(d)
	myData = d
	refreshPets()
	refreshAch()
	refreshMarket()
end
DataSync.OnClientEvent:Connect(setData)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d and not myData then setData(d) end
end)

--------------------------------------------------------------------
-- Pets follow every player (drawn locally from the "Pets" attribute)
--------------------------------------------------------------------
local petFolder = Instance.new("Folder")
petFolder.Name = "LocalPets"
petFolder.Parent = workspace
local drawn = {} -- [player] = { Key, Models = {} }

local function clearPets(p)
	local v = drawn[p]
	if v then for _, m in ipairs(v.Models) do m:Destroy() end end
	drawn[p] = nil
end

local function buildPets(p, key)
	clearPets(p)
	local v = { Key = key, Models = {} }
	for id in string.gmatch(key, "[^,]+") do
		local t = PetModels:FindFirstChild(id)
		if t then
			local m = t:Clone()
			m.Parent = petFolder
			table.insert(v.Models, m)
		end
	end
	drawn[p] = v
end
Players.PlayerRemoving:Connect(clearPets)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = workspace.CurrentCamera.CFrame.Position
	local parts, cfs = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local key = p:GetAttribute("Pets") or ""
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if key == "" or not root or (root.Position - cam).Magnitude > 250 then
			if drawn[p] then clearPets(p) end
		else
			if not drawn[p] or drawn[p].Key ~= key then buildPets(p, key) end
			local v = drawn[p]
			local n = #v.Models
			for i, m in ipairs(v.Models) do
				-- trail behind the player in a small arc, bobbing gently
				local ang = (i - (n + 1) / 2) * 0.8 + (n == 1 and 0.6 or 0)
				local back = root.CFrame * CFrame.Angles(0, ang, 0) * CFrame.new(0, -0.6, 6)
				local pos = back.Position + Vector3.new(0, 0.6 + math.sin(t * 3 + i) * 0.35, 0)
				local goal = CFrame.lookAt(pos, pos + root.CFrame.LookVector)
				local cur = m:GetPivot()
				local nextCf = (cur.Position - goal.Position).Magnitude > 40 and goal or cur:Lerp(goal, 0.15)
				m:PivotTo(nextCf)
			end
		end
	end
end)

--------------------------------------------------------------------
-- Ancient Treant health and remaining time
--------------------------------------------------------------------
local chip = Instance.new("Frame")
chip.Name = "TreantChip"
chip.Size = UDim2.new(1, 0, 0, 24)
chip.LayoutOrder = 1
chip.BackgroundColor3 = C.WoodDark
chip.BorderSizePixel = 0
chip.Visible = false
T.AttachToHud(chip, "StatusRail")
T.Corner(chip, 6)
T.Stroke(chip, C.LeafDark, 1)
local track = Instance.new("Frame")
track.BorderSizePixel = 0
track.BackgroundColor3 = C.LeafDark
track.Position = UDim2.new(0, 5, 1, -5)
track.Size = UDim2.new(1, -10, 0, 3)
track.Parent = chip
local chipFill = Instance.new("Frame")
chipFill.BackgroundColor3 = C.Leaf
chipFill.BorderSizePixel = 0
chipFill.Size = UDim2.fromScale(1, 1)
chipFill.Parent = track
local chipText = T.Label(chip, {
	Position = UDim2.fromOffset(5, 1), Size = UDim2.new(1, -10, 0, 16), Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local textLimit = Instance.new("UITextSizeConstraint")
textLimit.MaxTextSize = 13
textLimit.Parent = chipText
task.spawn(function()
	while true do
		local tr = workspace:FindFirstChild("Breakables") and workspace.Breakables:FindFirstChild("AncientTreant")
		if tr and workspace:GetAttribute("TreantAlive") then
			local hp, max = tr:GetAttribute("Health") or 0, tr:GetAttribute("MaxHealth") or 1
			local left = math.max(0, (tr:GetAttribute("ExpiresAt") or 0) - workspace:GetServerTimeNow())
			chip.Visible = true
			chipFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			chipText.Text = string.format("Ancient Treant (N)  %d%%  ·  %d:%02d", math.ceil(hp / max * 100), left // 60, left % 60)
		else
			chip.Visible = false
		end
		task.wait(0.5)
	end
end)
