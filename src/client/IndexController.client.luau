-- IndexController: the collection book.
--  * WEAPONS: every weapon per area (model, odds, best star, pulls)
--  * TREES:   every tree type per area (model, strength, logs, times chopped)
-- Each new discovery has a one-time reward you CLAIM here (badge on the tile).
-- Finishing an area: weapons = +10% Luck & Logs, trees = +5% Logs (forever).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Economy = require(ReplicatedStorage:WaitForChild("Economy")) -- M1: exact altar odds
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")
local Meta = Remotes:WaitForChild("Meta")
local BladeModels = ReplicatedStorage:WaitForChild("BladeModels")
local TreeModels = ReplicatedStorage:WaitForChild("TreeModels")

local player = Players.LocalPlayer

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local AREA_COLORS = {
	StarterGrove = Color3.fromRGB(90, 200, 90),
	PineForest = Color3.fromRGB(40, 150, 110),
	CrystalCanyon = Color3.fromRGB(200, 80, 220),
	FrostPeaks = Color3.fromRGB(80, 170, 240),
}

local gui = new("ScreenGui", { Name = "IndexUI", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- tile button (UIStyler turns it into the INDEX dock tile)
local openBtn = new("TextButton", { Name = "IndexButton", Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.Teal, Text = "📖 INDEX" }, gui)

local panel, body, closeBtn = T.Panel(gui, "IndexPanel", "INDEX", C.Teal, 720, 0.88)

-- row 1: mode toggle + claim all
local modeRow = new("Frame", { Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1 }, body)
local weaponsTab = T.Button(modeRow, { Size = UDim2.new(0.3, -6, 1, 0), Text = "⚔️ WEAPONS" }, C.Purple)
local treesTab = T.Button(modeRow, { Position = UDim2.new(0.3, 0, 0, 0), Size = UDim2.new(0.3, -6, 1, 0), Text = "🌳 TREES" }, C.Leaf)
local claimAll = T.Button(modeRow, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.36, 0, 1, 0), Text = "🎁 CLAIM ALL" }, C.Gold)

-- row 2: area tabs
local areaRow = new("Frame", { Position = UDim2.fromOffset(10, 68), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1 }, body)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, areaRow)
local areaButtons = {}
for i, a in ipairs(Config.Areas) do
	local b = T.Button(areaRow, { Name = a.Id, LayoutOrder = i, Size = UDim2.new(1 / #Config.Areas, -5, 1, 0), Text = a.Name }, C.Plank)
	areaButtons[a.Id] = b
end

-- row 3: progress + completion reward
local header = T.Label(body, { Position = UDim2.fromOffset(12, 108), Size = UDim2.new(1, -270, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
-- M1.5: which island altar your rolls use (click to switch between unlocked islands)
local altarButton = T.Button(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 106), Size = UDim2.fromOffset(250, 26), Text = "" }, C.Teal)
local RollRemote = Remotes:WaitForChild("Roll")
local bonusLabel = T.Label(body, { Position = UDim2.fromOffset(12, 131), Size = UDim2.new(1, -24, 0, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.WoodLight })

local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 154), Size = UDim2.new(1, -16, 1, -162), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, body)
new("UIGridLayout", { CellSize = UDim2.fromOffset(152, 188), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, grid)

--------------------------------------------------------------------
-- cards
--------------------------------------------------------------------
local cards = { Weapon = {}, Tree = {} }
local myData
local function unlockedIslands()
	local list = {}
	for _, id in ipairs(Config.Economy.IslandOrder) do
		if id == Config.HomeIsland or (myData and myData.UnlockedIslands and myData.UnlockedIslands[id]) then table.insert(list, id) end
	end
	return list
end
local function currentAltar()
	local list = unlockedIslands()
	local chosen = myData and myData.Settings and myData.Settings.Altar
	if chosen and table.find(list, chosen) then return chosen end
	return list[#list] or Config.HomeIsland
end
local mode = "Weapon"
local currentArea = Config.Areas[1].Id
local refresh

local function call(...)
	local args = table.pack(...)
	local ok, a, b = pcall(function() return Meta:InvokeServer(table.unpack(args, 1, args.n)) end)
	if ok then return a, b end
	return false, "Error"
end

local function fitModel(model, cam, vp)
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	local r = math.max(ext.X, ext.Y, ext.Z) * 0.5
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2)) * 1.1
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.35, ext.Y * 0.08, dist), cf.Position)
end

local function rewardText(kind, rarity)
	local rw = (kind == "Weapon" and Config.IndexRewards or Config.TreeIndexRewards)[rarity]
	return rw and Config.RewardText(rw, player) or ""
end

local function makeCard(kind, def)
	local r = Config.RarityById[def.Rarity]
	local f = new("Frame", { Name = def.Id, Size = UDim2.fromOffset(152, 188), BackgroundColor3 = C.Plank, Visible = false }, grid)
	T.Corner(f, 12)
	local st = T.Stroke(f, r.Color, 3)
	local vp = new("ViewportFrame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 78), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 200), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1) }, f)
	local cam = new("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = cam
	local model
	if kind == "Weapon" then
		local t = BladeModels:FindFirstChild(def.Id)
		if t then
			model = t:Clone()
			model:PivotTo(CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.rad(-20), 0))
			fitModel(model, cam, vp)
		end
	else
		local tpl
		for _, m in ipairs(TreeModels:GetChildren()) do
			if m:GetAttribute("TreeType") == def.Id and (not tpl or m.Name < tpl.Name) then tpl = m end
		end
		if tpl then
			model = tpl:Clone()
			local hb = model:FindFirstChild("Hitbox")
			if hb then hb:Destroy() end
			model:PivotTo(CFrame.Angles(0, math.rad(25), 0))
			fitModel(model, cam, vp)
		end
	end
	local name = T.Label(f, { Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 22), Text = def.Name, TextColor3 = r.Color })
	local rarity = T.Label(f, { Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 16), Text = def.Rarity, TextColor3 = r.Color })
	if r.Rainbow then
		rarity.TextColor3 = Color3.new(1, 1, 1)
		new("UIGradient", { Color = Config.RainbowSequence }, rarity)
	end
	local line1 = T.Label(f, { Position = UDim2.fromOffset(6, 121), Size = UDim2.new(1, -12, 0, 15), Text = "", TextColor3 = C.Cream })
	local line2 = T.Label(f, { Position = UDim2.fromOffset(6, 137), Size = UDim2.new(1, -12, 0, 15), Text = "", TextColor3 = C.Gold })
	local claim = T.Button(f, { Name = "Claim", Position = UDim2.fromOffset(6, 154), Size = UDim2.new(1, -12, 0, 28), Text = "CLAIM", Visible = false }, C.Gold)
	local done = T.Label(f, { Position = UDim2.fromOffset(6, 157), Size = UDim2.new(1, -12, 0, 22), Text = "", TextColor3 = C.Leaf })
	claim.Activated:Connect(function()
		claim.Visible = false
		local ok = call("ClaimIndex", kind, def.Id)
		if ok then
			if kind == "Weapon" then myData.IndexClaimed[def.Id] = true else myData.TreeClaimed[def.Id] = true end
		end
		refresh()
	end)
	cards[kind][def.Id] = { Frame = f, Viewport = vp, Model = model, Name = name, Line1 = line1, Line2 = line2, Claim = claim, Done = done, Stroke = st, Def = def, Rarity = r }
end

for _, w in ipairs(Config.Weapons) do makeCard("Weapon", w) end
local treeList = {}
for _, tt in pairs(Config.TreeTypes) do table.insert(treeList, tt) end
table.sort(treeList, function(a, b) return a.Id < b.Id end)
for _, tt in ipairs(treeList) do makeCard("Tree", tt) end

--------------------------------------------------------------------
-- state helpers
--------------------------------------------------------------------
local function owned(kind, id)
	if not myData then return nil end
	if kind == "Weapon" then return myData.Weapons and myData.Weapons[id] end
	return myData.Trees and myData.Trees[id]
end
local function claimed(kind, id)
	if not myData then return false end
	if kind == "Weapon" then return myData.IndexClaimed and myData.IndexClaimed[id] end
	return myData.TreeClaimed and myData.TreeClaimed[id]
end
local function claimable(kind, def)
	if not owned(kind, def.Id) or claimed(kind, def.Id) then return false end
	local rewards = kind == "Weapon" and Config.IndexRewards or Config.TreeIndexRewards
	return rewards[def.Rarity] ~= nil
end
local function countReady(kind)
	local n = 0
	for _, c in pairs(cards[kind]) do
		if claimable(kind, c.Def) then n += 1 end
	end
	return n
end

local function updateBadge()
	local w, t = countReady("Weapon"), countReady("Tree")
	local n = w + t
	openBtn:SetAttribute("Badge", n > 0 and (n > 99 and "99+" or tostring(n)) or false)
	weaponsTab.Text = "⚔️ WEAPONS" .. (w > 0 and (" (" .. w .. ")") or "")
	treesTab.Text = "🌳 TREES" .. (t > 0 and (" (" .. t .. ")") or "")
end

local function redrawModels()
	for _, c in pairs(cards[mode]) do
		if c.Model and c.Frame.Visible then
			c.Model.Parent = nil
			c.Model.Parent = c.Viewport
		end
	end
end

--------------------------------------------------------------------
-- refresh
--------------------------------------------------------------------
refresh = function()
	updateBadge()
	if not panel.Visible then return end
	local luck = player:GetAttribute("LuckMult") or 1 -- M1: already includes events (strongest temp only)
	-- M1.5: exact odds of ONE roll at your altar (same pool + luck the server uses)
	local altar = currentAltar()
	local oddsById = {}
	for _, o in ipairs((Economy.AltarOdds(altar, luck))) do oddsById[o.Weapon.Id] = o.P end
	local isl = Config.IslandById[altar]
	altarButton.Text = string.format("🛕 Altar: %s  (luck x%s) ▸", isl and isl.Name or altar, tostring(luck))
	local found, count, ready = 0, 0, 0
	for _, c in pairs(cards[mode == "Weapon" and "Tree" or "Weapon"]) do c.Frame.Visible = false end

	for id, c in pairs(cards[mode]) do
		local def = c.Def
		local isMine = owned(mode, id)
		local inTab = def.Area == currentArea and (mode == "Tree" or not def.Exclusive or isMine)
		c.Frame.Visible = inTab and true or false
		if inTab then
			local r = c.Rarity
			local canClaim = claimable(mode, def)
			c.Frame.LayoutOrder = (canClaim and 0 or 1000) + r.Order * 100 + (def.Order or 0)
			if mode == "Tree" or not def.Exclusive then
				count += 1
				if isMine then found += 1 end
			end
			if canClaim then ready += 1 end

			if mode == "Weapon" then
				if def.Exclusive then
					c.Line1.Text = def.SoulCost and "Soul Shop exclusive" or "Starter Pack exclusive"
				else
					local pr = oddsById[def.Id]
					if pr and pr > 0 then
						local you = 1 / pr
						c.Line1.Text = Config.FormatOneIn(def.OneIn or 2) .. ((you < (def.OneIn or 2) * 0.99) and ("  (you: " .. Config.FormatOneIn(you):gsub("1 in ", "") .. ")") or "")
					else
						local from = Config.AreaIsland[def.Area]
						local fi = from and Config.IslandById[from]
						c.Line1.Text = "🛕 " .. (fi and fi.Name or "?") .. " altar"
					end
				end
			else
				c.Line1.Text = "⚡ " .. Config.FormatNumber(def.Strength) .. "  •  +" .. Config.FormatNumber(def.Logs) .. " logs"
			end

			if isMine then
				c.Viewport.ImageColor3 = Color3.new(1, 1, 1)
				c.Name.Text = def.Name
				c.Stroke.Transparency = 0
				c.Frame.BackgroundColor3 = C.Plank
				if mode == "Weapon" then
					c.Line2.Text = string.format("%s  •  x%d", string.rep("★", isMine.Star or 0) .. string.rep("☆", Config.MaxStar - (isMine.Star or 0)), isMine.Pulled or 1)
				else
					c.Line2.Text = "chopped " .. Config.FormatNumber(isMine)
				end
			else
				c.Viewport.ImageColor3 = Color3.new(0, 0, 0)
				c.Name.Text = "???"
				c.Stroke.Transparency = 0.6
				c.Frame.BackgroundColor3 = C.WoodDark
				c.Line2.Text = mode == "Weapon" and "roll to find" or "chop to find"
			end

			c.Claim.Visible = canClaim
			if canClaim then
				c.Claim.Text = "🎁 " .. rewardText(mode, def.Rarity)
				c.Done.Text = ""
			elseif isMine and claimed(mode, id) then
				c.Done.Text = "✔ claimed"
				c.Done.TextColor3 = C.Leaf
			else
				c.Done.Text = "🎁 " .. rewardText(mode, def.Rarity)
				c.Done.TextColor3 = C.WoodLight
			end
		end
	end

	local area = Config.AreaById[currentArea]
	local complete = found == count and count > 0
	header.Text = string.format("%s  —  %d / %d %s found%s", area.Name, found, count, mode == "Weapon" and "weapons" or "trees",
		ready > 0 and ("  •  " .. ready .. " to claim!") or "")
	if mode == "Weapon" then
		-- M1 (H5): editions - each part is recorded once and kept forever
		local ed = (myData and myData.IndexEditions) or {}
		local def1 = Config.IndexEditions.Weapon[currentArea] and Config.IndexEditions.Weapon[currentArea][1]
		local I = Config.Economy.Index
		local parts = {}
		if def1 and def1.Standard then
			local full = def1.StandardBonusFull
			table.insert(parts, string.format("Set: +%d%% Luck, +%d%% Logs %s",
				(I.WeaponStandard.Luck + (full and I.WeaponMastery.Luck or 0)) * 100, (I.WeaponStandard.Logs + (full and I.WeaponMastery.Logs or 0)) * 100,
				ed["Weapon/" .. currentArea .. "/Standard/1"] and "✔" or "🔒"))
		end
		if def1 and def1.Mastery then
			table.insert(parts, string.format("Mastery (Secret): +%d%% / +%d%% %s", I.WeaponMastery.Luck * 100, I.WeaponMastery.Logs * 100,
				ed["Weapon/" .. currentArea .. "/Mastery/1"] and "✔" or "🔒"))
		end
		bonusLabel.Text = "Forever: " .. table.concat(parts, "   •   ")
		complete = def1 ~= nil and (not def1.Standard or ed["Weapon/" .. currentArea .. "/Standard/1"]) and (not def1.Mastery or ed["Weapon/" .. currentArea .. "/Mastery/1"]) and true or false
	else
		local muts = {}
		for _, m in ipairs(Config.Mutations) do
			table.insert(muts, m.Icon .. Config.FormatNumber((myData and myData.MutationsFound and myData.MutationsFound[m.Id]) or 0))
		end
		bonusLabel.Text = string.format("Complete it: +%d%% Logs %s   •   Mutations chopped: %s", Config.TreeIndexBonus.Logs * 100,
			complete and "✔" or "🔒", table.concat(muts, "  "))
	end
	bonusLabel.TextColor3 = complete and C.Leaf or C.WoodLight

	weaponsTab.BackgroundColor3 = mode == "Weapon" and C.Purple or C.Grey
	treesTab.BackgroundColor3 = mode == "Tree" and C.Leaf or C.Grey
	claimAll.Visible = countReady(mode) > 0
	for id, b in pairs(areaButtons) do
		b.BackgroundColor3 = id == currentArea and (AREA_COLORS[id] or C.Teal) or C.Plank
	end
end

local function redrawSoon()
	redrawModels()
	task.delay(0.4, redrawModels)
	task.delay(1.5, redrawModels)
end

altarButton.Activated:Connect(function()
	local list = unlockedIslands()
	local cur = currentAltar()
	local i = table.find(list, cur) or #list
	local nextId = list[i % #list + 1]
	local ok, res = pcall(function() return RollRemote:InvokeServer("SetAltar", nextId) end)
	if ok and res and myData then
		myData.Settings = myData.Settings or {}
		myData.Settings.Altar = nextId
	end
	refresh()
end)

for id, b in pairs(areaButtons) do
	b.Activated:Connect(function()
		currentArea = id
		refresh()
		redrawSoon()
	end)
end
weaponsTab.Activated:Connect(function() mode = "Weapon" refresh() redrawSoon() end)
treesTab.Activated:Connect(function() mode = "Tree" refresh() redrawSoon() end)
claimAll.Activated:Connect(function()
	claimAll.Visible = false
	local ok = call("ClaimIndexAll", mode)
	if ok then
		for id, c in pairs(cards[mode]) do
			if claimable(mode, c.Def) then
				if mode == "Weapon" then myData.IndexClaimed[id] = true else myData.TreeClaimed[id] = true end
			end
		end
	end
	refresh()
end)

local openedOnce = false
openBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		if not openedOnce and myData and myData.BestArea and Config.AreaById[myData.BestArea] then
			currentArea = myData.BestArea -- open on your best area
		end
		openedOnce = true
		refresh()
		redrawSoon()
	end
end)
closeBtn.Activated:Connect(function() panel.Visible = false end)

local function setData(d)
	myData = d
	myData.IndexClaimed = myData.IndexClaimed or {}
	myData.TreeClaimed = myData.TreeClaimed or {}
	myData.Trees = myData.Trees or {}
	refresh()
end
DataSync.OnClientEvent:Connect(setData)
player:GetAttributeChangedSignal("LuckMult"):Connect(function() if panel.Visible then refresh() end end)
task.spawn(function()
	local d = GetData:InvokeServer()
	if d and not myData then setData(d) end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(BladeModels:GetDescendants())
	end)
end)
