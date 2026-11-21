-- PvPSoulController: PvP toggle button, Souls counter, "+N Souls" pop-ups
-- and the Soul Shop panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PvPToggle = Remotes:WaitForChild("PvPToggle")
local SoulShop = Remotes:WaitForChild("SoulShop")
local SoulReward = Remotes:WaitForChild("SoulReward")
local GetData = Remotes:WaitForChild("GetData")
local DataSync = Remotes:WaitForChild("DataSync")
local BladeModels = ReplicatedStorage:WaitForChild("BladeModels")

local player = Players.LocalPlayer
local F = Enum.Font.FredokaOne
local SOUL = Config.SoulColor
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "PvPSoulUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10 -- shop panel draws over the HUD
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 12) c.Parent = p return c end
local function stroke(p, color, th) local s = Instance.new("UIStroke") s.Color = color s.Thickness = th or 3 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p return s end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = F
	l.TextColor3 = WHITE
	l.TextScaled = true
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

-- hide the old "SAFE ZONE / PVP ZONE" label (safe zones are gone)
task.spawn(function()
	local gameUI = player.PlayerGui:WaitForChild("GameUI", 20)
	local z = gameUI and gameUI:FindFirstChild("ZoneLabel")
	if z then z.Visible = false end
end)

--------------------------------------------------------------------
-- PvP button
--------------------------------------------------------------------
local OFF_BG, OFF_ST = Color3.fromRGB(70, 75, 90), Color3.fromRGB(35, 38, 48)
local ON_BG, ON_ST = Color3.fromRGB(200, 40, 45), Color3.fromRGB(110, 15, 20)

local pvpButton = Instance.new("TextButton")
pvpButton.Name = "PvPButton"
pvpButton.Font = F
pvpButton.TextColor3 = WHITE
pvpButton.AutoButtonColor = true
local pvpStroke = stroke(pvpButton, OFF_ST, 2)
pvpButton.Parent = gui.Parent:WaitForChild("RollUI"):WaitForChild("RollBar")

local function refreshPvP()
	local on = player:GetAttribute("PvP") == true
	local now = workspace:GetServerTimeNow()
	local lock = (player:GetAttribute("CombatUntil") or 0) - now
	local cd = Config.PvP.ToggleCooldown - (now - (player:GetAttribute("PvPToggleAt") or 0))
	if on then
		if lock > 0 then
			pvpButton.Text = string.format("COMBAT\n%ds", math.ceil(lock))
		else
			pvpButton.Text = string.format("PVP ON\n×%.1f", Config.PvP.LogMult)
		end
		pvpButton.BackgroundColor3 = ON_BG
		pvpStroke.Color = ON_ST
	else
		pvpButton.Text = cd > 0 and string.format("PVP OFF\n%ds", math.ceil(cd)) or "PVP\nOFF"
		pvpButton.BackgroundColor3 = OFF_BG
		pvpStroke.Color = OFF_ST
	end
end

local busy = false
pvpButton.Activated:Connect(function()
	if busy then return end
	busy = true
	local ok, msg = PvPToggle:InvokeServer(not (player:GetAttribute("PvP") == true))
	busy = false
	if not ok and msg then
		player.PlayerGui:WaitForChild("GameUI"):WaitForChild("HudNotice"):Fire(msg, Color3.fromRGB(255, 153, 137))
	end
	refreshPvP()
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	refreshPvP()
end)
player:GetAttributeChangedSignal("PvP"):Connect(refreshPvP)
refreshPvP()

--------------------------------------------------------------------
-- Souls counter (click = Soul Shop)
--------------------------------------------------------------------
local soulsButton = Instance.new("TextButton")
soulsButton.Name = "SoulsButton"
soulsButton.AnchorPoint = Vector2.new(0, 0)
soulsButton.Position = UDim2.new(0.5, -5, 0, 2)
soulsButton.Size = UDim2.fromOffset(114, 44)
soulsButton.BackgroundTransparency = 1
soulsButton.Text = ""
soulsButton.Parent = gui

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(0, 0.5)
pill.Position = UDim2.fromScale(0, 0.5)
pill.Size = UDim2.new(1, 0, 0, 30)
pill.BorderSizePixel = 0
local soulBackground = Color3.fromRGB(40, 25, 60)
pill.BackgroundColor3 = soulBackground
pill.Parent = soulsButton
corner(pill, 10)
stroke(pill, SOUL, 2)
local soulsText = label(pill, {
	Name = "Amount", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -53, 1, -10),
	TextColor3 = SOUL, Text = "✨ 0",
})
local amountSize = Instance.new("UITextSizeConstraint")
amountSize.MinTextSize = 9
amountSize.MaxTextSize = 16
amountSize.Parent = soulsText
local shopBadge = label(pill, {
	Name = "Shop", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(38, 18),
	BackgroundTransparency = 0, BackgroundColor3 = SOUL, Text = "SHOP", TextColor3 = Color3.fromRGB(35, 15, 55),
})
corner(shopBadge, 5)

local function getSouls()
	local ls = player:FindFirstChild("leaderstats")
	local s = ls and ls:FindFirstChild("Souls")
	return s and s.Value or 0
end

local refreshShop -- forward
local function refreshSouls()
	soulsText.Text = "✨ " .. Config.FormatNumber(getSouls())
	if refreshShop then refreshShop() end
end
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local s = ls:WaitForChild("Souls")
	local last = s.Value
	s.Changed:Connect(function(v)
		if v > last then
			pill.BackgroundColor3 = Color3.fromRGB(94, 58, 126)
			TweenService:Create(pill, TweenInfo.new(0.25), { BackgroundColor3 = soulBackground }):Play()
		end
		last = v
		refreshSouls()
	end)
	refreshSouls()
end)

--------------------------------------------------------------------
-- "+N Souls" pop-ups
--------------------------------------------------------------------
local fx = workspace:FindFirstChild("SoulFX") or Instance.new("Folder")
fx.Name = "SoulFX"
fx.Parent = workspace
SoulReward.OnClientEvent:Connect(function(amount, pos)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = pos + Vector3.new(math.random(-10, 10) / 10, 1, 0)
	anchor.Parent = fx
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(170, 34)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local l = label(bb, { Size = UDim2.fromScale(1, 1), TextColor3 = SOUL, TextStrokeTransparency = 0, Text = "+" .. amount .. " Souls" })
	TweenService:Create(anchor, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = anchor.Position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.3)
end)

--------------------------------------------------------------------
-- Soul Shop panel
--------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "SoulShop"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.53)
panel.Size = UDim2.new(0, 520, 0.8, 0) -- fits small screens too
local popScale = Instance.new("UIScale")
popScale.Parent = panel
panel.BackgroundColor3 = Color3.fromRGB(24, 18, 36)
panel.Visible = false
panel.Parent = gui
corner(panel, 18)
stroke(panel, SOUL, 4)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(520, 520)
sizeLimit.Parent = panel

label(panel, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -150, 0, 40), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "✨ SOUL SHOP", TextColor3 = SOUL })
label(panel, { Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 20), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Earn Souls by defeating slimes, bandits, the Blade King and PvP players", TextColor3 = Color3.fromRGB(200, 185, 225) })
local panelSouls = label(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 16), Size = UDim2.fromOffset(130, 32),
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = SOUL, Text = "✨ 0" })

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(42, 42)
close.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
close.Font = F
close.Text = "X"
close.TextSize = 24
close.TextColor3 = WHITE
close.Parent = panel
corner(close, 10)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(16, 80)
list.Size = UDim2.new(1, -32, 1, -96)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = SOUL
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local myData
local rows = {}

local BOOST_ICON = { LuckPotion = "🍀", LogBoost = "💰", MegaLuck = "🍀", SoulCrate = "✨", SoulBlessing = "🪵", SoulFortune = "🌟" }

local function weaponViewport(parent, weaponId)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = WHITE
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local tpl = BladeModels:FindFirstChild(weaponId)
	if tpl then
		local m = tpl:Clone()
		m:PivotTo(CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(-90), 0, 0))
		m.Parent = vp
		local _, size = m:GetBoundingBox()
		local r = math.max(size.X, size.Y, size.Z)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, r * 1.15), Vector3.zero)
		-- meshes sometimes need a re-parent once loaded
		task.delay(0.3, function() if vp.Parent then m.Parent = nil m.Parent = vp end end)
	end
	return vp
end

local function buildRow(item)
	local row = Instance.new("Frame")
	row.Name = item.Id
	row.LayoutOrder = item.Order
	row.Size = UDim2.new(1, -10, 0, 74)
	row.BackgroundColor3 = Color3.fromRGB(40, 30, 58)
	row.Parent = list
	corner(row, 12)
	local accent = SOUL
	local w = item.Kind == "Weapon" and Config.WeaponById[item.Weapon]
	if w then accent = Config.RarityById[w.Rarity].Color end
	stroke(row, accent, 2)

	local icon = Instance.new("Frame")
	icon.Position = UDim2.fromOffset(8, 7)
	icon.Size = UDim2.fromOffset(60, 60)
	icon.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
	icon.Parent = row
	corner(icon, 10)
	if w then
		weaponViewport(icon, w.Id)
	else
		label(icon, { Size = UDim2.fromScale(1, 1), Text = BOOST_ICON[item.Id] or "✨" })
	end

	label(row, { Position = UDim2.fromOffset(78, 8), Size = UDim2.new(1, -220, 0, 30), TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Name, TextColor3 = w and accent or WHITE })
	label(row, { Position = UDim2.fromOffset(78, 40), Size = UDim2.new(1, -220, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Desc or "", TextColor3 = Color3.fromRGB(205, 195, 225) })

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)
	buy.Size = UDim2.fromOffset(124, 46)
	buy.Font = F
	buy.TextScaled = true
	buy.TextColor3 = WHITE
	buy.Parent = row
	corner(buy, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = buy
	buy.Activated:Connect(function()
		if item.Kind == "OpenTraits" then
			player:SetAttribute("OpenTraitsUI", os.clock()) -- TraitsController listens
			panel.Visible = false
			return
		end
		local ok, msg = SoulShop:InvokeServer(item.Id)
		if not ok then
			local old = buy.Text
			buy.Text = msg or "?"
			task.delay(1.4, function() if refreshShop then refreshShop() end end)
		end
	end)
	rows[item.Id] = { Row = row, Buy = buy, Item = item }
end

for _, item in ipairs(Config.SoulShop) do buildRow(item) end

refreshShop = function()
	local souls = getSouls()
	panelSouls.Text = "✨ " .. Config.FormatNumber(souls)
	for id, r in pairs(rows) do
		local item = r.Item
		if item.Kind == "OpenTraits" then
			r.Buy.Text = "OPEN"
			r.Buy.BackgroundColor3 = Color3.fromRGB(150, 80, 230)
		elseif item.Kind == "Soon" then
			r.Buy.Text = "SOON"
			r.Buy.BackgroundColor3 = Color3.fromRGB(80, 75, 95)
		elseif item.Kind == "Weapon" and myData and myData.Weapons and myData.Weapons[item.Weapon] then
			r.Buy.Text = "OWNED"
			r.Buy.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
		elseif item.Kind == "SoulUpgrade" then
			-- M1: level-based cost, level shown on the button
			local lv = (myData and myData.SoulUpgrades and myData.SoulUpgrades[item.Upgrade]) or 0
			if lv >= item.MaxLevel then
				r.Buy.Text = "MAX " .. lv .. "/" .. item.MaxLevel
				r.Buy.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
			else
				local cost = Config.GetSoulUpgradeCost(item.Upgrade, lv)
				r.Buy.Text = string.format("Lv %d/%d  ✨ %s", lv, item.MaxLevel, Config.FormatNumber(cost))
				r.Buy.BackgroundColor3 = souls >= cost and Color3.fromRGB(150, 80, 230) or Color3.fromRGB(85, 75, 100)
			end
		else
			r.Buy.Text = "✨ " .. Config.FormatNumber(item.Cost)
			r.Buy.BackgroundColor3 = souls >= item.Cost and Color3.fromRGB(150, 80, 230) or Color3.fromRGB(85, 75, 100)
		end
	end
end

DataSync.OnClientEvent:Connect(function(data)
	myData = data
	refreshShop()
end)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then myData = d end
	refreshShop()
end)

local function openShop(on)
	panel.Visible = on
	if on then
		refreshShop()
		popScale.Scale = 0.9
		TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end
soulsButton.Activated:Connect(function() openShop(not panel.Visible) end)
close.Activated:Connect(function() openShop(false) end)
