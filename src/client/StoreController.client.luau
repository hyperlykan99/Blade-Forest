-- StoreController: Robux store (game passes + developer products).
-- Items whose ID is 0 in BladeConfig show as "SOON".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetData = Remotes:WaitForChild("GetData")
local DataSync = Remotes:WaitForChild("DataSync")

local player = Players.LocalPlayer
local F = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 200, 60)
local ROBUX = utf8.char(0xE002)

local myData
local randomRestricted = false
task.spawn(function()
	local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
	if ok and info then randomRestricted = info.ArePaidRandomItemsRestricted == true end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "StoreUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
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
local function button(parent, props)
	local b = Instance.new("TextButton")
	b.Font = F
	b.TextScaled = true
	b.TextColor3 = WHITE
	for k, v in pairs(props) do b[k] = v end
	b.Parent = parent
	corner(b, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	return b
end

--------------------------------------------------------------------
-- STORE button (right side, under TRAITS)
--------------------------------------------------------------------
local openBtn = button(gui, { Name = "StoreButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 32),
	Size = UDim2.fromOffset(140, 54), BackgroundColor3 = Color3.fromRGB(245, 185, 40), Text = "💰 STORE", TextScaled = false, TextSize = 21 })
corner(openBtn, 14)
stroke(openBtn, Color3.fromRGB(140, 90, 0), 3)

--------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "Store"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.53)
panel.Size = UDim2.new(0, 580, 0.82, 0)
panel.BackgroundColor3 = Color3.fromRGB(30, 26, 20)
panel.Visible = false
panel.Parent = gui
corner(panel, 18)
stroke(panel, GOLD, 4)
local lim = Instance.new("UISizeConstraint") lim.MaxSize = Vector2.new(580, 580) lim.Parent = panel
local popScale = Instance.new("UIScale") popScale.Parent = panel

label(panel, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -90, 0, 38), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "💰 STORE", TextColor3 = GOLD })
local closeBtn = button(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Color3.fromRGB(200, 50, 60), Text = "X" })

-- Starter Pack banner
local starter = Instance.new("Frame")
starter.Position = UDim2.fromOffset(16, 58)
starter.Size = UDim2.new(1, -32, 0, 86)
starter.BackgroundColor3 = Color3.fromRGB(70, 30, 110)
starter.Parent = panel
corner(starter, 14)
stroke(starter, Color3.fromRGB(200, 90, 255), 3)
local sg = Instance.new("UIGradient")
sg.Color = ColorSequence.new(Color3.fromRGB(150, 70, 230), Color3.fromRGB(60, 25, 100))
sg.Rotation = 90
sg.Parent = starter
label(starter, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 32), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "✨ STARTER PACK", TextColor3 = Color3.fromRGB(255, 225, 120) })
label(starter, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -170, 0, 36), TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, Text = Config.ProductById.StarterPack.Desc, TextColor3 = Color3.fromRGB(235, 220, 255) })
local starterBuy = button(starter, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 56),
	BackgroundColor3 = Color3.fromRGB(70, 175, 80), Text = ROBUX .. " 99" })

-- tabs
local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Parent = panel
local tabPasses = button(tabs, { Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = GOLD, Text = "PASSES", TextColor3 = Color3.fromRGB(40, 30, 10) })
local tabBoosts = button(tabs, { Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(70, 62, 45), Text = "BOOSTS & PACKS" })

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = GOLD
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 8) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = list

local function layoutPanel()
	local showStarter = not (myData and myData.StarterPack)
	starter.Visible = showStarter
	local top = showStarter and 154 or 60
	tabs.Position = UDim2.fromOffset(16, top)
	tabs.Size = UDim2.new(1, -32, 0, 40)
	list.Position = UDim2.fromOffset(16, top + 50)
	list.Size = UDim2.new(1, -32, 1, -(top + 64))
end

local note = label(panel, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -40, 0, 14),
	Text = "Trait Crate odds are shown in the TRAITS menu", TextColor3 = Color3.fromRGB(170, 160, 140) })

--------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------
local rows = {} -- { Frame, Buy, Item, Kind, Desc }
local priceCache = {}

local function fetchPrice(kind, item)
	local id = kind == "Pass" and item.PassId or item.ProductId
	if id == 0 or priceCache[id] then return end
	priceCache[id] = item.Price
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then priceCache[id] = info.PriceInRobux end
	end)
end

local refresh -- forward

local function makeRow(kind, item)
	local row = Instance.new("Frame")
	row.Name = item.Id
	row.LayoutOrder = item.Order
	row.Size = UDim2.new(1, -10, 0, 72)
	row.BackgroundColor3 = Color3.fromRGB(48, 42, 32)
	row.Parent = list
	corner(row, 12)
	stroke(row, Color3.fromRGB(110, 90, 50), 2)
	label(row, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 30), TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Name, TextColor3 = kind == "Pass" and GOLD or WHITE })
	local desc = label(row, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -170, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Desc, TextColor3 = Color3.fromRGB(215, 205, 185) })
	local buy = button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 50) })
	buy.Activated:Connect(function()
		if kind == "Pass" then
			if item.PassId == 0 or player:GetAttribute("Pass_" .. item.Id) then return end
			MarketplaceService:PromptGamePassPurchase(player, item.PassId)
		else
			if item.ProductId == 0 then return end
			MarketplaceService:PromptProductPurchase(player, item.ProductId)
		end
	end)
	fetchPrice(kind, item)
	table.insert(rows, { Frame = row, Buy = buy, Item = item, Kind = kind, Desc = desc })
end

for _, p in ipairs(Config.GamePasses) do makeRow("Pass", p) end
for _, p in ipairs(Config.DevProducts) do if p.Id ~= "StarterPack" then makeRow("Product", p) end end

local currentTab = "Pass"
refresh = function()
	layoutPanel()
	tabPasses.BackgroundColor3 = currentTab == "Pass" and GOLD or Color3.fromRGB(70, 62, 45)
	tabPasses.TextColor3 = currentTab == "Pass" and Color3.fromRGB(40, 30, 10) or WHITE
	tabBoosts.BackgroundColor3 = currentTab == "Product" and GOLD or Color3.fromRGB(70, 62, 45)
	tabBoosts.TextColor3 = currentTab == "Product" and Color3.fromRGB(40, 30, 10) or WHITE
	for _, r in ipairs(rows) do
		local item = r.Item
		local visible = r.Kind == currentTab and not (item.RandomItem and randomRestricted)
		r.Frame.Visible = visible
		local id = r.Kind == "Pass" and item.PassId or item.ProductId
		if item.PackMult then
			r.Desc.Text = "+" .. Config.FormatNumber(Config.GetLogPackAmount(item.Id, myData and myData.BestArea)) .. " Logs (grows with your area)"
		end
		if r.Kind == "Pass" and player:GetAttribute("Pass_" .. item.Id) then
			r.Buy.Text = "OWNED"
			r.Buy.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
		elseif id == 0 then
			r.Buy.Text = "SOON"
			r.Buy.BackgroundColor3 = Color3.fromRGB(90, 85, 75)
		else
			r.Buy.Text = ROBUX .. " " .. tostring(priceCache[id] or item.Price)
			r.Buy.BackgroundColor3 = Color3.fromRGB(70, 175, 80)
		end
	end
	local sp = Config.ProductById.StarterPack
	local spId = (sp.PassId and sp.PassId ~= 0) and sp.PassId or sp.ProductId
	if spId == 0 then
		starterBuy.Text = "SOON"
		starterBuy.BackgroundColor3 = Color3.fromRGB(90, 85, 75)
	else
		starterBuy.Text = ROBUX .. " " .. tostring(priceCache[spId] or sp.Price)
		starterBuy.BackgroundColor3 = Color3.fromRGB(70, 175, 80)
	end
end
do
	local sp = Config.ProductById.StarterPack
	if sp.PassId and sp.PassId ~= 0 then
		fetchPrice("Pass", { PassId = sp.PassId, Price = sp.Price })
	else
		fetchPrice("Product", sp)
	end
end

starterBuy.Activated:Connect(function()
	local sp = Config.ProductById.StarterPack
	if sp.PassId and sp.PassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, sp.PassId)
	elseif sp.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, sp.ProductId)
	end
end)
tabPasses.Activated:Connect(function() currentTab = "Pass" refresh() end)
tabBoosts.Activated:Connect(function() currentTab = "Product" refresh() end)

DataSync.OnClientEvent:Connect(function(d) myData = d if panel.Visible then refresh() end end)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then myData = d end
	refresh()
end)
player.AttributeChanged:Connect(function(a)
	if a:sub(1, 5) == "Pass_" and panel.Visible then refresh() end
end)

local function open(on)
	panel.Visible = on
	if on then
		refresh()
		popScale.Scale = 0.9
		TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end
openBtn.Activated:Connect(function() open(not panel.Visible) end)
closeBtn.Activated:Connect(function() open(false) end)

local api = Instance.new("BindableFunction")
api.Name = "StoreAPI"
api.OnInvoke = function(cmd, arg)
	if cmd == "Open" then open(arg ~= false) end
	if cmd == "Tab" then currentTab = arg refresh() end
	return true
end
api.Parent = script
