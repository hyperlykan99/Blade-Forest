-- UIController: logs counter, boss bar, safe-zone indicator, toasts, upgrade + weapon menus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopAction = Remotes:WaitForChild("ShopAction")
local NotifyRemote = Remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui.Panel
local upgradesPage = panel.UpgradesPage
local bladesPage = panel.BladesPage
local coinsLabel = gui.CoinsLabel -- shows Logs
local amountText = Instance.new("TextLabel")
amountText.Name = "Amount"
amountText.BackgroundTransparency = 1
amountText.Position = UDim2.fromOffset(29, 3)
amountText.Size = UDim2.new(1, -35, 1, -6)
amountText.Font = Enum.Font.FredokaOne
amountText.Text = "0"
amountText.TextScaled = true
amountText.TextColor3 = Color3.fromRGB(255, 203, 64)
amountText:SetAttribute("NoTheme", true)
amountText.Parent = coinsLabel
local amountSize = Instance.new("UITextSizeConstraint")
amountSize.MaxTextSize = 17
amountSize.MinTextSize = 9
amountSize.Parent = amountText
require(ReplicatedStorage:WaitForChild("UIIcons")).Log(coinsLabel, 21, UDim2.new(0, 6, 0.5, 0))
local statusRail = gui:WaitForChild("StatusRail")
local function placeStatusRail()
	local width = gui.AbsoluteSize.X
	local narrow = width < 640
	local railWidth = math.min(208, math.floor(width * (narrow and 0.47 or 0.30)) - 8)
	statusRail.Position = UDim2.new(1, -8, 0, narrow and 54 or 4)
	statusRail.Size = UDim2.fromOffset(math.max(1, railWidth), 0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeStatusRail)
placeStatusRail()
local bossFrame = statusRail:WaitForChild("BossFrame")
local zoneLabel = gui.ZoneLabel

local GREEN = Color3.fromRGB(60, 200, 90)
local GREY = Color3.fromRGB(100, 100, 115)
local GOLD = Color3.fromRGB(255, 170, 40)
local BLUE = Color3.fromRGB(70, 130, 255)

local function getCoins()
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Logs") and ls.Logs.Value or 0
end

--------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------
local TOAST_COLORS = {
	kill = Color3.fromRGB(255, 220, 80),
	death = Color3.fromRGB(255, 110, 110),
	streak = Color3.fromRGB(255, 150, 60),
	boss = Color3.fromRGB(210, 140, 255),
}
local feed = gui.Toasts
local template = gui.ToastTemplate
local announcements = {}
local quickRoll
local sequence = 0
local visibleLimit = 1

local function fitNotices()
	while #announcements > visibleLimit do
		table.remove(announcements, 1):Destroy()
	end
	if quickRoll then
		quickRoll.Visible = #announcements < visibleLimit
	end
end

local function fitFeed()
	local size = gui.AbsoluteSize
	local touch = game:GetService("UserInputService")
	local compact = size.Y < 560 or size.X < 780 or (touch.TouchEnabled and not touch.KeyboardEnabled)
	visibleLimit = compact and 1 or 2
	local narrow = size.X < 640
	local width = math.floor(size.X * (narrow and 0.5 or 0.28)) - 12
	feed.Size = UDim2.fromOffset(math.clamp(width, 1, compact and 216 or 268), 0)
	feed.Position = UDim2.fromOffset(6, narrow and 54 or 4)
	fitNotices()
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitFeed)
fitFeed()

local function showNotice(message, color, channel)
	local isRoll = channel == "quickRoll"
	local notice = template:Clone()
	notice.Name = isRoll and "QuickRoll" or "Toast"
	notice.Text = message
	notice.TextColor3 = (color or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.22)
	if isRoll then
		if quickRoll then quickRoll:Destroy() end
		quickRoll = notice
	else
		sequence += 1
		notice.LayoutOrder = -sequence -- latest announcement first, quick results last
		table.insert(announcements, notice)
	end
	notice.Visible = true
	fitNotices()
	notice.Parent = feed

	task.delay(isRoll and 3 or 4, function()
		if not notice.Parent then return end
		TweenService:Create(notice, TweenInfo.new(0.25), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		if not notice.Parent then return end
		if isRoll then
			quickRoll = nil
		else
			table.remove(announcements, table.find(announcements, notice))
		end
		notice:Destroy()
		fitNotices()
	end)
end

gui.HudNotice.Event:Connect(showNotice)
NotifyRemote.OnClientEvent:Connect(function(message, kind)
	local rarityId = type(kind) == "string" and kind:match("^rare_(.+)")
	local rarity = rarityId and Config.RarityById[rarityId]
	showNotice(message, (rarity and rarity.Color) or TOAST_COLORS[kind])
end)

--------------------------------------------------------------------
-- Shop panel
--------------------------------------------------------------------
local upgradeCards, bladeCards = {}, {}

local function flash(button, text)
	button.Text = text
	task.delay(0.9, function()
		if button.Text == text then
			button:SetAttribute("Refresh", os.clock())
		end
	end)
end

local refresh

local function fmt(u, level)
	local v = Config.GetValue(u.Id, level)
	if u.Id == "Speed" and Config.MaxSpinSpeed and v > Config.MaxSpinSpeed then
		-- spin is capped for comfort; extra levels become damage
		return string.format("max spin +%d%% dmg", math.floor((v / Config.MaxSpinSpeed - 1) * 100 + 0.5))
	end
	-- M1: Lucky Charm adds to the permanent luck pool; Forest Renewal shows its regrow cut
	if u.Id == "Luck" then return string.format(u.Format, v - 1) end
	if u.Id == "Renewal" then return string.format(u.Format, math.floor(v * 100 + 0.5)) end
	return string.format(u.Format, v)
end

for i, u in ipairs(Config.Upgrades) do
	local card = panel.UpgradeCard:Clone()
	card.Name = u.Id
	card.LayoutOrder = i
	card.Visible = true
	card.UpgradeName.Text = u.Name
	card.Parent = upgradesPage
	upgradeCards[u.Id] = card
	card.BuyButton.MouseButton1Click:Connect(function()
		local ok, msg = ShopAction:InvokeServer("Upgrade", u.Id)
		if ok then refresh() else flash(card.BuyButton, msg or "Can't") end
	end)
	card.BuyButton:GetAttributeChangedSignal("Refresh"):Connect(function() refresh() end)
end

--------------------------------------------------------------------
-- Weapons inventory (owned weapons, rarity, stars, fuse, equip)
--------------------------------------------------------------------
local myData = nil
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")

-- toolbar above the grid
bladesPage.Position = UDim2.fromOffset(18, 104)
bladesPage.Size = UDim2.new(1, -36, 1, -122)
local bar = Instance.new("Frame")
bar.Name = "WeaponBar"
bar.Position = UDim2.fromOffset(18, 58)
bar.Size = UDim2.new(1, -36, 0, 38)
bar.BackgroundTransparency = 1
bar.Visible = false
bar.Parent = panel
local barInfo = Instance.new("TextLabel")
barInfo.Size = UDim2.new(1, -300, 1, 0)
barInfo.BackgroundTransparency = 1
barInfo.Font = Enum.Font.FredokaOne
barInfo.TextSize = 18
barInfo.TextXAlignment = Enum.TextXAlignment.Left
barInfo.TextColor3 = Color3.fromRGB(220, 220, 235)
barInfo.Parent = bar
local function toggleButton(text, x)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, x, 0, 0)
	b.Size = UDim2.fromOffset(140, 36)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.Parent = bar
	return b
end
local autoEquipBtn = toggleButton("Auto Equip", 0)
local autoFuseBtn = toggleButton("Auto Fuse", -150)
autoEquipBtn.MouseButton1Click:Connect(function()
	if myData then ShopAction:InvokeServer("AutoEquip", nil, not myData.AutoEquip) end
end)
autoFuseBtn.MouseButton1Click:Connect(function()
	if myData then ShopAction:InvokeServer("Setting", "AutoFuse", not myData.Settings.AutoFuse) end
end)

local function starText(star)
	return string.rep("★", star) .. string.rep("☆", Config.MaxStar - star)
end

local function makeWeaponCard(b)
	local rarity = Config.RarityById[b.Rarity]
	local card = panel.BladeCard:Clone()
	card.Name = b.Id
	card.Visible = true
	card.BladeName.Text = b.Name
	card.BladeName.TextColor3 = rarity.Color
	card.BladeName.TextScaled = true
	local st = Instance.new("UIStroke")
	st.Color = rarity.Color
	st.Thickness = b.Rarity == "Common" and 1 or 2
	st.Parent = card
	-- fuse button (top-right)
	local fuse = Instance.new("TextButton")
	fuse.Name = "FuseButton"
	fuse.AnchorPoint = Vector2.new(1, 0)
	fuse.Position = UDim2.new(1, -6, 0, 6)
	fuse.Size = UDim2.fromOffset(56, 22)
	fuse.ZIndex = 3
	fuse.BackgroundColor3 = Color3.fromRGB(255, 150, 40)
	fuse.Font = Enum.Font.FredokaOne
	fuse.TextSize = 14
	fuse.TextColor3 = Color3.new(1, 1, 1)
	fuse.Text = "FUSE"
	fuse.Visible = false
	Instance.new("UICorner", fuse).CornerRadius = UDim.new(0, 6)
	fuse.Parent = card
	-- 3D preview of the actual weapon
	card.Swatch.Visible = false
	local template = ReplicatedStorage:WaitForChild("BladeModels"):FindFirstChild(b.Id)
	if template then
		local vp = Instance.new("ViewportFrame")
		vp.Name = "Preview"
		vp.AnchorPoint = Vector2.new(0.5, 0)
		vp.Position = UDim2.new(0.5, 0, 0, 4)
		vp.Size = UDim2.new(1, -8, 0, 52)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(190, 190, 200)
		vp.LightColor = Color3.new(1, 1, 1)
		vp.LightDirection = Vector3.new(-1, -1, -1)
		vp.Parent = card
		local sword = template:Clone()
		-- lay the sword across the card, tip to the right, flat face to the camera
		sword:PivotTo(CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.rad(-12), 0))
		sword.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 20
		cam.CFrame = CFrame.new(0, 0, 6.2)
		cam.Parent = vp
		vp.CurrentCamera = cam
		-- glow ring behind it in the blade's colour
		local glow = Instance.new("Frame")
		glow.ZIndex = 0
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.new(0.5, 0, 0, 30)
		glow.Size = UDim2.fromOffset(130, 34)
		glow.BackgroundColor3 = rarity.Color
		glow.BackgroundTransparency = 0.7
		Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
		glow.Parent = card
		if rarity.Rainbow then
			local g = Instance.new("UIGradient")
			g.Color = Config.RainbowSequence
			g.Parent = glow
		end
	end
	card.Parent = bladesPage
	bladeCards[b.Id] = card
	card.ActionButton.MouseButton1Click:Connect(function()
		local ok, msg = ShopAction:InvokeServer("Equip", b.Id)
		if not ok then flash(card.ActionButton, msg or "Can't") end
	end)
	fuse.MouseButton1Click:Connect(function()
		local ok, msg = ShopAction:InvokeServer("Fuse", b.Id)
		if not ok then flash(fuse, msg or "Can't") end
	end)
	card.ActionButton:GetAttributeChangedSignal("Refresh"):Connect(function() refresh() end)
	return card
end

local function refreshWeapons()
	if not myData then return end
	local owned, found = 0, 0
	for _, b in ipairs(Config.Weapons) do
		local entry = myData.Weapons[b.Id]
		if entry then
			owned += 1
			if not b.Exclusive then found += 1 end
			local card = bladeCards[b.Id] or makeWeaponCard(b)
			local power = Config.GetWeaponPower(b.Id, entry.Star, entry.Shiny)
			-- strongest first
			card.LayoutOrder = -math.floor(power * 10)
			local nextCost = Config.FuseCost[entry.Star + 1]
			local fuseLine
			if nextCost then
				fuseLine = string.format("%d/%d copies", entry.Copies, nextCost)
			elseif entry.Shiny then
				fuseLine = "✨ SHINY"
			else
				fuseLine = string.format("Shiny %d/%d", entry.Copies, Config.ShinyCopies)
			end
			card.Stats.Text = string.format("%s %s\n⚡ %s Power • %s", b.Rarity, starText(entry.Star), Config.FormatNumber(power), fuseLine)
			local canShiny = not nextCost and not entry.Shiny and entry.Copies >= Config.ShinyCopies
			card.FuseButton.Visible = (nextCost ~= nil and entry.Copies >= nextCost) or canShiny
			card.FuseButton.Text = canShiny and "SHINY" or "FUSE"
			card.FuseButton.BackgroundColor3 = canShiny and Color3.fromRGB(240, 190, 40) or Color3.fromRGB(255, 150, 40)
			local btn = card.ActionButton
			if myData.Equipped == b.Id then
				btn.Text = "EQUIPPED"
				btn.BackgroundColor3 = GOLD
			else
				btn.Text = "EQUIP"
				btn.BackgroundColor3 = BLUE
			end
		end
	end
	local total = 0
	for _, b in ipairs(Config.Weapons) do if not b.Exclusive then total += 1 end end
	barInfo.Text = string.format("⚡ Power %s   •   %d/%d found", Config.FormatNumber(player:GetAttribute("Power") or 0), found, total)
	autoEquipBtn.Text = "Auto Equip: " .. (myData.AutoEquip and "ON" or "OFF")
	autoEquipBtn.BackgroundColor3 = myData.AutoEquip and GREEN or GREY
	autoFuseBtn.Text = "Auto Fuse: " .. (myData.Settings.AutoFuse and "ON" or "OFF")
	autoFuseBtn.BackgroundColor3 = myData.Settings.AutoFuse and GREEN or GREY
end

DataSync.OnClientEvent:Connect(function(data)
	myData = data
	refreshWeapons()
end)
task.spawn(function()
	local data = GetData:InvokeServer()
	if data and not myData then
		myData = data
		refreshWeapons()
	end
end)

-- sword meshes may still be downloading; once they are, re-add them so the previews draw
local function redrawPreviews()
	for _, card in pairs(bladeCards) do
		local vp = card:FindFirstChild("Preview")
		local sword = vp and vp:FindFirstChildOfClass("Model")
		if sword then
			sword.Parent = nil
			sword.Parent = vp
		end
	end
end
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("BladeModels")
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(models:GetDescendants())
	end)
	for _ = 1, 5 do
		redrawPreviews()
		task.wait(2)
	end
end)

refresh = function()
	local coins = getCoins()
	amountText.Text = Config.FormatNumber(coins)

	for id, card in pairs(upgradeCards) do
		local u = Config.ById[id]
		local level = Config.GetLevel(player, id)
		if level >= u.MaxLevel then
			card.Info.Text = string.format("MAX %d/%d • %s", level, u.MaxLevel, fmt(u, level))
			card.BuyButton.Text = "MAXED"
			card.BuyButton.BackgroundColor3 = GOLD
		else
			local cost = Config.GetCost(id, level)
			card.Info.Text = string.format("Lv %d/%d • %s → %s", level, u.MaxLevel, fmt(u, level), fmt(u, level + 1))
			card.BuyButton.Text = Config.FormatNumber(cost) .. " Logs"
			card.BuyButton.BackgroundColor3 = coins >= cost and GREEN or GREY
		end
	end

	refreshWeapons()
end

local function openPage(name)
	if panel.Visible and panel.Title.Text == name then
		panel.Visible = false
		return
	end
	panel.Title.Text = name
	upgradesPage.Visible = name == "Upgrades"
	bladesPage.Visible = name == "Weapons"
	bar.Visible = name == "Weapons"
	panel.UIStroke.Color = name == "Upgrades" and GOLD or Color3.fromRGB(150, 80, 255)
	panel.Visible = true
	refresh()
	if name == "Weapons" then
		redrawPreviews()
		task.delay(0.5, redrawPreviews)
	end
end
-- UIStyler may already have moved these two template buttons into its drawer.
local function menuButton(name)
	return gui:FindFirstChild(name) or player.PlayerGui.HUDDock.LeftDock[name]
end
local upgradesButton = menuButton("UpgradesButton")
local bladesButton = menuButton("BladesButton")
upgradesButton.Activated:Connect(function() openPage("Upgrades") end)
bladesButton.Text = "⚔ WEAPONS"
bladesButton.Activated:Connect(function() openPage("Weapons") end)
panel.Close.MouseButton1Click:Connect(function() panel.Visible = false end)

for _, attr in ipairs({ "EquippedBlade", "EquippedStar", "Power", "Lvl_Blades", "Lvl_Speed", "Lvl_Damage", "Lvl_Reach" }) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end

local lastCoins = 0
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local c = ls:WaitForChild("Logs")
	lastCoins = c.Value
	c.Changed:Connect(function(v)
		if v > lastCoins then
			amountText.TextColor3 = Color3.fromRGB(255, 250, 225)
			TweenService:Create(amountText, TweenInfo.new(0.25), { TextColor3 = Color3.fromRGB(255, 203, 64) }):Play()
		end
		lastCoins = v
		refresh()
	end)
	refresh()
end)

--------------------------------------------------------------------
-- Boss bar + zone indicator
--------------------------------------------------------------------
local frenzyFlash = 0
RunService.Heartbeat:Connect(function(dt)
	-- boss: the bar / timer only shows while you are in (or right next to) the arena
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inArena = me and ((me.Position - Config.ArenaCenter) * Vector3.new(1, 0, 1)).Magnitude <= Config.ArenaRadius + 22
	bossFrame.Visible = inArena and true or false
	local bossModel = CollectionService:GetTagged("Boss")[1]
	local hum = bossModel and bossModel:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		bossFrame.Bar.Visible = true
		local frenzy = bossModel:GetAttribute("Frenzy")
		bossFrame.BossLabel.Text = string.format("☠ BLADE KING %s — %s / %s", frenzy and "(FRENZY!)" or "",
			Config.FormatNumber(hum.Health), Config.FormatNumber(hum.MaxHealth))
		bossFrame.Bar.Fill.Size = UDim2.fromScale(hum.Health / hum.MaxHealth, 1)
		frenzyFlash += dt * 10
		bossFrame.Bar.Fill.BackgroundColor3 = frenzy and Color3.fromRGB(255, 60 + 60 * math.sin(frenzyFlash), 120) or Color3.fromRGB(170, 60, 255)
	else
		bossFrame.Bar.Visible = false
		local at = workspace:GetAttribute("BossSpawnAt")
		if at then
			local left = math.max(0, at - workspace:GetServerTimeNow())
			bossFrame.BossLabel.Text = string.format("Blade King spawns in %d:%02d", left // 60, left % 60)
		else
			bossFrame.BossLabel.Text = ""
		end
	end

	-- zone
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		if Config.InSafeZone(root.Position) then
			zoneLabel.Text = "🛡 SAFE ZONE"
			zoneLabel.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
		else
			local streak = player:GetAttribute("Streak") or 0
			zoneLabel.Text = streak > 0 and string.format("⚔ PVP ZONE • %d streak", streak) or "⚔ PVP ZONE"
			zoneLabel.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
		end
	end
end)
