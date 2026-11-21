-- UIStyler: applies the "Lumberjack Adventure" theme to ALL game UI.
--  * fonts: Luckiest Guy for buttons/titles, Fredoka One for small text, cartoon outlines
--  * menu buttons become icon tiles in two docks (left + right) that fit phones
--  * big menus get wood-panel skin, pop animation, and only one is open at a time
-- New UI made later is picked up automatically (DescendantAdded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- Docks
--------------------------------------------------------------------
local dockGui = Instance.new("ScreenGui")
dockGui.Name = "HUDDock"
dockGui.ResetOnSpawn = false
dockGui.DisplayOrder = 5
dockGui.Parent = pg

-- Give the tabs a larger touch target than the visible arrow.
local UIS = game:GetService("UserInputService")
local function isCompact()
	local size = dockGui.AbsoluteSize
	return (UIS.TouchEnabled and not UIS.KeyboardEnabled) or size.Y < 510 or size.X < 680
end

local compact = isCompact()
local function makeDock(name, left)
	local side = left and 0 or 1
	local inward = left and 1 or -1
	local dock = Instance.new("Frame")
	dock.Name = name
	dock.BackgroundTransparency = 1
	dock.AnchorPoint = Vector2.new(side, 0)
	dock.Visible = not compact
	dock.Parent = dockGui
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
	grid.Parent = dock

	local tab = Instance.new("TextButton")
	tab.Name = left and "HideLeft" or "HideRight"
	tab.AnchorPoint = Vector2.new(side, 0)
	tab.Size = UDim2.fromOffset(44, 44)
	tab.Text = ""
	tab.BackgroundTransparency = 1
	tab:SetAttribute("NoTheme", true)
	tab.Parent = dockGui
	local face = Instance.new("TextLabel")
	face.Name = "Arrow"
	face.AnchorPoint = Vector2.new(side, 0.5)
	face.Position = UDim2.new(side, inward * 3, 0.5, 0)
	face.Size = UDim2.fromOffset(28, 30)
	face.BackgroundColor3 = C.WoodDark
	face.FontFace = T.Font.Body
	face.TextSize = 16
	face.TextColor3 = C.Cream
	face:SetAttribute("NoTheme", true)
	face.Parent = tab
	T.Corner(face, 9)
	T.Stroke(face, C.Ink, 2)

	local function updateArrow()
		face.Text = dock.Visible == left and "◀" or "▶"
	end
	dock:GetPropertyChangedSignal("Visible"):Connect(updateArrow)
	updateArrow()

	local function place()
		local size = dockGui.AbsoluteSize
		local tile = compact and 44 or 52
		local gap = compact and 4 or 5
		local columns = compact and size.Y < 300 and size.X > size.Y and 4 or 3
		local rows = math.ceil((left and 9 or 11) / columns)
		local width = columns * tile + (columns - 1) * gap
		local height = rows * tile + (rows - 1) * gap
		local y
		if compact then
			y = size.X < 640 and 166 or 114
			y = math.min(y, math.max(54, size.Y - height - 8))
		else
			y = math.max(98, math.floor((size.Y - height) * 0.5))
		end
		grid.CellSize = UDim2.fromOffset(tile, tile)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.FillDirectionMaxCells = columns
		dock.Size = UDim2.fromOffset(width, height)
		dock.Position = UDim2.new(side, inward * 49, 0, y)
		tab.Position = UDim2.new(side, inward * 2, 0, y)
	end
	return dock, tab, place
end

local leftDock, leftTab, placeLeft = makeDock("LeftDock", true)
local rightDock, rightTab, placeRight = makeDock("RightDock", false)
local function toggle(dock, other)
	local opening = not dock.Visible
	if compact and opening then other.Visible = false end
	dock.Visible = opening
end
leftTab.Activated:Connect(function() toggle(leftDock, rightDock) end)
rightTab.Activated:Connect(function() toggle(rightDock, leftDock) end)

local function layoutDocks()
	local nextCompact = isCompact()
	if nextCompact ~= compact then
		compact = nextCompact
		leftDock.Visible = not compact
		rightDock.Visible = not compact
	end
	placeLeft()
	placeRight()
end
dockGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutDocks)
layoutDocks()

-- button name -> tile look
local TILES = {
	M6ForgeButton = { Side = "R", Order = 10, Icon = "⚒", Label = "FORGE", Color = C.GoldDark },
	M7SocialButton = { Side = "R", Order = 11, Icon = "♜", Label = "SOCIAL", Color = C.Teal },
	M5AdventuresButton = { Side = "R", Order = 9, Icon = "⟡", Label = "ADVENTURES", Color = C.Teal },
	CharacterProgressionButton = { Side = "R", Order = 7, Icon = "✦", Label = "MASTERY", Color = Color3.fromRGB(157, 109, 220) },
	UpgradesButton    = { Side = "L", Order = 1, Icon = "📈", Label = "UPGRADE", Color = C.Orange },
	BladesButton      = { Side = "L", Order = 2, Icon = "⚔️", Label = "WEAPONS", Color = C.Purple },
	IndexButton       = { Side = "L", Order = 3, Icon = "📖", Label = "INDEX", Color = C.Teal },
	RebirthButton     = { Side = "L", Order = 4, Icon = "🔄", Label = "REBIRTH", Color = C.Red },
	TraitsButton      = { Side = "L", Order = 5, Icon = "✨", Label = "TRAITS", Color = Color3.fromRGB(190, 100, 240) },
	StoreButton       = { Side = "L", Order = 6, Icon = "💰", Label = "STORE", Color = C.Gold },
	AutoButton        = { Side = "R", Order = 1, Icon = "🎯", Label = "AUTO", Dynamic = true },
	AFKButton         = { Side = "R", Order = 2, Icon = "💤", Label = "AFK", Color = Color3.fromRGB(90, 110, 200) },
	DailyButton       = { Side = "R", Order = 3, Icon = "🎁", Label = "GIFTS", Color = Color3.fromRGB(240, 90, 130) },
	QuestsButton      = { Side = "R", Order = 4, Icon = "📜", Label = "QUESTS", Color = C.Leaf },
	LeaderboardButton = { Side = "R", Order = 5, Icon = "🏆", Label = "TOP", Color = C.GoldDark },
	SettingsButton    = { Side = "R", Order = 8, Icon = "⚙️", Label = "SETTINGS", Color = C.Grey },
	PetsButton        = { Side = "L", Order = 7, Icon = "🐾", Label = "PETS", Color = Color3.fromRGB(240, 140, 90) },
	MarketButton      = { Side = "L", Order = 8, Icon = "🏪", Label = "MARKET", Color = C.WoodLight },
	GalleryButton     = { Side = "L", Order = 9, Icon = "🗡️", Label = "GALLERY", Color = Color3.fromRGB(120, 90, 210) }, -- M2
	AchievementsButton = { Side = "R", Order = 6, Icon = "🎖️", Label = "TROPHY", Color = Color3.fromRGB(200, 150, 40) },
}

local function setBadge(btn)
	local b = btn:FindFirstChild("TileBadge")
	local v = btn:GetAttribute("Badge")
	if v and v ~= "" and v ~= false then
		if not b then
			b = Instance.new("TextLabel")
			b.Name = "TileBadge"
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.new(1, -5, 0, 5)
			b.Size = UDim2.fromOffset(17, 17)
			b.BackgroundColor3 = C.Red
			b.FontFace = T.Font.Title
			b.TextScaled = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.ZIndex = 10
			b.Parent = btn
			T.Corner(b, 9)
			T.Stroke(b, C.Ink, 2)
		end
		b.Text = v == true and "!" or tostring(v)
		b.Visible = true
	elseif b then
		b.Visible = false
	end
end

local function makeTile(btn, spec)
	if btn:GetAttribute("Tiled") then return end
	btn:SetAttribute("Tiled", true)
	btn.Parent = spec.Side == "L" and leftDock or rightDock
	btn.LayoutOrder = spec.Order
	if spec.Color then btn.BackgroundColor3 = spec.Color end
	btn.AutoButtonColor = true
	for _, c in ipairs(btn:GetChildren()) do
		if c:IsA("UIPadding") or c:IsA("UIGradient") then c:Destroy() end
		if c:IsA("UIStroke") then c.Color = C.Ink c.Thickness = 2 c.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	end
	if not btn:FindFirstChildOfClass("UIStroke") then T.Stroke(btn, C.Ink, 2) end
	T.Corner(btn, 10)
	T.Sheen(btn, 0.7)
	local icon = Instance.new("TextLabel")
	icon.Name = "TileIcon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0.12, 0.04)
	icon.Size = UDim2.fromScale(0.76, 0.58)
	icon.TextScaled = true
	icon.Text = spec.Icon
	icon.Parent = btn
	local lbl = Instance.new("TextLabel")
	lbl.Name = "TileLabel"
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromScale(0.04, 0.64)
	lbl.Size = UDim2.fromScale(0.92, 0.3)
	lbl.FontFace = T.Font.Title
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = spec.Label
	lbl:SetAttribute("NoTheme", true)
	lbl.Parent = btn
	T.TextOutline(lbl, 1)
	local function syncText()
		local t = btn.Text
		if t == "" then return end
		if spec.Dynamic then
			lbl.Text = t:find("ON") and "AUTO ON" or "AUTO"
		end
		btn.Text = ""
	end
	btn:GetPropertyChangedSignal("Text"):Connect(syncText)
	syncText()
	btn:GetAttributeChangedSignal("Badge"):Connect(function() setBadge(btn) end)
	setBadge(btn)
end

--------------------------------------------------------------------
-- Text + panels
--------------------------------------------------------------------
local function luminance(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end

local function styleText(obj)
	if obj:GetAttribute("NoTheme") or obj:GetAttribute("Themed") then return end
	obj:SetAttribute("Themed", true)
	if obj:IsA("TextBox") then
		obj.FontFace = T.Font.Body
		return
	end
	local function decide()
		local big = obj:IsA("TextButton") or obj.TextSize >= 24 or (obj.TextScaled and obj.AbsoluteSize.Y >= 26)
		obj.FontFace = big and T.Font.Title or T.Font.Body
	end
	decide()
	task.delay(0.1, decide) -- once layout is known
	if luminance(obj.TextColor3) > 0.55 and obj.TextStrokeTransparency >= 0.95 then
		local has = false
		for _, c in ipairs(obj:GetChildren()) do
			if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then has = true end
		end
		if not has then T.TextOutline(obj, obj:IsA("TextButton") and 2 or 1.5) end
	end
end

local panels = {}
local function isPanel(f)
	if not f:IsA("Frame") or not f.Parent or not f.Parent:IsA("ScreenGui") then return false end
	if f.Parent == dockGui then return false end
	if f.Size.X.Scale >= 0.99 and f.Size.Y.Scale >= 0.99 then return false end -- overlays
	local w = f.Size.X.Offset + f.Size.X.Scale * 1000
	local h = f.Size.Y.Offset + f.Size.Y.Scale * 700
	return w >= 380 and h >= 300
end

local function skinPanel(f)
	if f:GetAttribute("ThemeSkinned") then return end
	f:SetAttribute("ThemeSkinned", true)
	if not f:GetAttribute("ThemePanel") then
		f.BackgroundColor3 = C.Wood
		for _, c in ipairs(f:GetChildren()) do
			if c:IsA("UIStroke") then c.Color = C.Ink c.Thickness = 5 end
			if c:IsA("UIGradient") then c:Destroy() end
		end
		local g = Instance.new("UIGradient")
		g.Name = "ThemeSheen"
		g.Rotation = 90
		g.Color = ColorSequence.new(C.WoodLight, C.WoodDark)
		g.Parent = f
		if not f:FindFirstChildOfClass("UIScale") then
			local s = Instance.new("UIScale")
			s.Name = "PopScale"
			s.Parent = f
		end
	end
end

local function trackPanel(f)
	if panels[f] then return end
	panels[f] = true
	skinPanel(f)
	f:GetPropertyChangedSignal("Visible"):Connect(function()
		if not f.Visible then return end
		-- one menu at a time
		for other in pairs(panels) do
			if other ~= f and other.Parent and other.Visible then other.Visible = false end
		end
		T.Pop(f)
	end)
end

local function onAdded(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		task.defer(styleText, obj)
	end
	if obj:IsA("TextButton") and TILES[obj.Name] and obj.Parent and obj.Parent:IsA("ScreenGui") then
		task.defer(makeTile, obj, TILES[obj.Name])
	end
	if obj:IsA("Frame") then
		task.defer(function()
			if isPanel(obj) then trackPanel(obj) end
		end)
	end
end

for _, d in ipairs(pg:GetDescendants()) do onAdded(d) end
pg.DescendantAdded:Connect(onAdded)

-- world text (tree tags, overhead titles, floating numbers) gets the font too
local function onWorld(obj)
	if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj:FindFirstAncestorWhichIsA("BillboardGui") then
		obj.FontFace = T.Font.Title
	end
end
workspace.DescendantAdded:Connect(onWorld)
task.spawn(function()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") then
			for _, t in ipairs(d:GetDescendants()) do onWorld(t) end
		end
	end
end)

--------------------------------------------------------------------
-- Top bar pills
--------------------------------------------------------------------
task.spawn(function()
	local gameUI = pg:WaitForChild("GameUI", 20)
	local coins = gameUI and gameUI:FindFirstChild("CoinsLabel")
	if coins then
		coins.BackgroundColor3 = C.WoodDark
		for _, c in ipairs(coins:GetChildren()) do
			if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then c.Color = C.Gold c.Thickness = 2 end
		end
		coins.TextColor3 = C.Gold
		T.Sheen(coins, 0.8)
	end
end)
