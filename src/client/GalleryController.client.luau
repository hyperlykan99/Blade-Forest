-- GalleryController (M2): the weapon collection gallery.
--  * all weapons in Config.Weapons (120 today; new entries appear automatically)
--  * filters: island, rarity, type, owned/missing, favourites; sorting
--  * 3D inspection (drag to rotate), exact odds at the weapon's altar, how to get it
--  * favourite (copies never sold), equip, Auto Equip, copies / stars / Shiny
--  * Altar Essence + Divine Attunement (one Divine per island, claimable once)
-- Display only: every action is a server request (ShopAction / Roll remotes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local M6Inventory = require(ReplicatedStorage:WaitForChild("M6Inventory"))
local Economy = require(ReplicatedStorage:WaitForChild("Economy"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")
local ShopAction = Remotes:WaitForChild("ShopAction")
local RollRemote = Remotes:WaitForChild("Roll")
local BladeModels = ReplicatedStorage:WaitForChild("BladeModels")

local player = Players.LocalPlayer

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local ISLANDS = Config.Economy.IslandOrder -- TimberHaven, CrystalWilds, FrostboundReach
local RARITIES = {}
for _, r in ipairs(Config.Rarities) do table.insert(RARITIES, r.Id) end
local TYPES = { "Sword", "Axe", "Scythe" }
local SORTS = { "Rarity ▼", "Rarity ▲", "Power ▼", "Name", "Island" }

local gui = new("ScreenGui", { Name = "GalleryUI", ResetOnSpawn = false, DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
-- dock tile (UIStyler: GalleryButton)
local openBtn = new("TextButton", { Name = "GalleryButton", Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.Purple, Text = "🗡️ GALLERY" }, gui)
local panel, body, closeBtn = T.Panel(gui, "GalleryPanel", "GALLERY", C.Purple, 860, 0.9)
panel:FindFirstChildOfClass("UISizeConstraint").MaxSize = Vector2.new(860, 620)

-- filter row
local filters = new("Frame", { Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 34), BackgroundTransparency = 1 }, body)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, filters)
local state = { island = nil, rarity = nil, type = nil, owned = nil, fav = false, sort = 1, selected = nil }
local function fbtn(order, w, color) return T.Button(filters, { LayoutOrder = order, Size = UDim2.new(w, -5, 1, 0), Text = "" }, color) end
local islandBtn = fbtn(1, 0.2, C.Teal)
local rarityBtn = fbtn(2, 0.15, C.Plank)
local typeBtn = fbtn(3, 0.13, C.Plank)
local ownedBtn = fbtn(4, 0.15, C.Plank)
local favBtn = fbtn(5, 0.12, C.Plank)
local sortBtn = fbtn(6, 0.25, C.WoodDark)

-- status row: count + essence + attune
local status = T.Label(body, { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(0.45, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local essenceLbl = T.Label(body, { Position = UDim2.new(0.45, 0, 0, 56), Size = UDim2.new(0.3, 0, 0, 22), Text = "", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
local attuneBtn = T.Button(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52), Size = UDim2.new(0.24, 0, 0, 30), Text = "" }, C.Gold)

-- grid (left) + detail (right)
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(8, 86), Size = UDim2.new(0.58, -12, 1, -94), BackgroundTransparency = 1,
	ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, body)
new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 112), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
local detail = new("Frame", { Position = UDim2.new(0.58, 0, 0, 86), Size = UDim2.new(0.42, -8, 1, -94), BackgroundColor3 = C.WoodDark, BackgroundTransparency = 0.2 }, body)
T.Corner(detail, 12)
local bigVp = new("ViewportFrame", { Size = UDim2.new(1, -12, 0.36, 0), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(60, 52, 44),
	BackgroundTransparency = 0.1, Ambient = Color3.fromRGB(220, 220, 220), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1) }, detail)
T.Corner(bigVp, 10)
local bigCam = new("Camera", { FieldOfView = 40 }, bigVp)
bigVp.CurrentCamera = bigCam
local dName = T.Label(detail, { Position = UDim2.new(0, 10, 0.37, 4), Size = UDim2.new(1, -20, 0, 30), Text = "Select a weapon" }, true)
local dRarity = T.Label(detail, { Position = UDim2.new(0, 10, 0.37, 34), Size = UDim2.new(1, -20, 0, 20), Text = "" })
local dInfo = T.Label(detail, { Position = UDim2.new(0, 10, 0.37, 56), Size = UDim2.new(1, -20, 0.63, -110), Text = "", TextScaled = true, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left }, false)
local actions = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 40), BackgroundTransparency = 1 }, detail)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, actions)
local favToggle = T.Button(actions, { Size = UDim2.new(0.3, -4, 1, 0), Text = "☆" }, C.Plank)
local equipBtn = T.Button(actions, { Size = UDim2.new(0.38, -4, 1, 0), Text = "EQUIP" }, C.Leaf)
local autoBtn = T.Button(actions, { Size = UDim2.new(0.32, -4, 1, 0), Text = "AUTO" }, C.Grey)

local myData
local cards = {} -- [id] = { Frame, Vp, Model?, Label, Badge }

local function owned(id) return myData and myData.Weapons and myData.Weapons[id] end
local function isFav(id) return myData and myData.Favorites and myData.Favorites[id] == true end
local function rarityOf(w) return Config.RarityById[w.Rarity] end
local function islandName(id) local i = Config.IslandById[id] return i and i.Name or tostring(id) end

-- model in a viewport, framed by its bounding box; tip up
local function placeModel(vp, cam, id, dist)
	local tpl = BladeModels:FindFirstChild(id) or BladeModels:FindFirstChild(Config.StarterWeapon)
	local m = tpl:Clone()
	m:PivotTo(CFrame.Angles(math.rad(90), 0, 0))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then d:Destroy() end
	end
	m.Parent = vp
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist or 6.2), Vector3.zero)
	return m
end

-- lazy thumbnails: a few per frame so opening the gallery never hitches
local thumbQueue = {}
RunService.Heartbeat:Connect(function()
	if not panel.Visible then return end
	for _ = 1, 4 do
		local c = table.remove(thumbQueue, 1)
		if not c then break end
		if not c.Model then c.Model = placeModel(c.Vp, c.Cam, c.Id, 5.4) end
	end
end)

local function makeCard(w)
	local r = rarityOf(w)
	local f = new("TextButton", { Name = w.Id, Text = "", BackgroundColor3 = r.Color:Lerp(Color3.new(0, 0, 0), 0.55), AutoButtonColor = true }, grid)
	T.Corner(f, 10)
	local st = T.Stroke(f, r.Color, 2)
	if r.Rainbow then new("UIGradient", { Color = Config.RainbowSequence }, st) end
	local vp = new("ViewportFrame", { Size = UDim2.new(1, -8, 0, 72), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 180, 180), LightDirection = Vector3.new(-1, -1, -1) }, f)
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	vp.CurrentCamera = cam
	local lbl = T.Label(f, { Position = UDim2.new(0, 3, 0, 78), Size = UDim2.new(1, -6, 0, 30), Text = w.Name, TextWrapped = true })
	local badge = T.Label(f, { Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 16), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Gold })
	local c = { Frame = f, Vp = vp, Cam = cam, Label = lbl, Badge = badge, Id = w.Id }
	cards[w.Id] = c
	f.Activated:Connect(function() state.selected = w.Id refreshDetail() end)
	return c
end
for _, w in ipairs(Config.Weapons) do
	table.insert(thumbQueue, makeCard(w))
end

local function sortKey(w)
	local e = owned(w.Id)
	local pw = Config.GetWeaponPower(w.Id, e and e.Star or 0, e and e.Shiny, myData and M6Inventory.Stage(myData, w.Id))
	return pw
end

function refreshGrid()
	islandBtn.Text = state.island and ("🏝 " .. islandName(state.island)) or "🏝 All islands"
	rarityBtn.Text = state.rarity or "All rarities"
	rarityBtn.BackgroundColor3 = state.rarity and Config.RarityById[state.rarity].Color:Lerp(Color3.new(0, 0, 0), 0.3) or C.Plank
	typeBtn.Text = state.type or "All types"
	ownedBtn.Text = state.owned == true and "Owned" or (state.owned == false and "Missing" or "Owned+Missing")
	favBtn.Text = state.fav and "★ Favs" or "☆ Favs"
	favBtn.BackgroundColor3 = state.fav and C.Gold or C.Plank
	sortBtn.Text = "Sort: " .. SORTS[state.sort]
	local list = {}
	local have, total = 0, 0
	for _, w in ipairs(Config.Weapons) do
		total += 1
		if owned(w.Id) then have += 1 end
		local ok = (not state.island or w.Island == state.island)
			and (not state.rarity or w.Rarity == state.rarity)
			and (not state.type or w.Type == state.type)
			and (state.owned == nil or (owned(w.Id) ~= nil) == state.owned)
			and (not state.fav or isFav(w.Id))
		cards[w.Id].Frame.Visible = ok
		if ok then table.insert(list, w) end
	end
	local s = state.sort
	table.sort(list, function(a, b)
		local ra, rb = rarityOf(a).Order, rarityOf(b).Order
		if s == 1 and ra ~= rb then return ra > rb end
		if s == 2 and ra ~= rb then return ra < rb end
		if s == 3 then local pa, pb = sortKey(a), sortKey(b) if pa ~= pb then return pa > pb end end
		if s == 5 then
			local ia, ib = Economy.IslandIndex[a.Island] or 9, Economy.IslandIndex[b.Island] or 9
			if ia ~= ib then return ia < ib end
		end
		if s == 4 then return a.Name < b.Name end
		return (a.OneIn or 0) > (b.OneIn or 0)
	end)
	for i, w in ipairs(list) do
		local c = cards[w.Id]
		local e = owned(w.Id)
		c.Frame.LayoutOrder = i
		c.Vp.ImageColor3 = e and Color3.new(1, 1, 1) or Color3.new(0, 0, 0) -- undiscovered = silhouette
		c.Vp.ImageTransparency = e and 0 or 0.25
		c.Label.Text = e and w.Name or "???"
		local b = ""
		if e then
			b = (e.Shiny and "✨" or "") .. (e.Star and e.Star > 0 and string.rep("★", e.Star) or "") .. (isFav(w.Id) and " ♥" or "")
		end
		c.Badge.Text = b
	end
	status.Text = string.format("Collected %d / %d", have, total)
	local E = myData and myData.Essence or {}
	essenceLbl.Text = string.format("✦ Essence %s  (today %s/%s)", Config.FormatNumber(E.Total or 0), Config.FormatNumber(E.Today or 0),
		Config.FormatNumber(Config.Attunement.DailyCap))
	-- attune: first unlocked, unclaimed island
	local target
	for _, isl in ipairs(ISLANDS) do
		local unlocked = isl == Config.HomeIsland or (myData and myData.UnlockedIslands and myData.UnlockedIslands[isl])
		if unlocked and not (myData and myData.Attuned and myData.Attuned[isl]) then target = isl break end
	end
	attuneBtn:SetAttribute("Island", target)
	if target then
		local wid = Config.Attunement.Attunement[target]
		local can = (E.Total or 0) >= Config.Attunement.AttuneCost
		attuneBtn.Text = (can and "👑 ATTUNE " or "🔒 ") .. Config.WeaponById[wid].Name
		attuneBtn.BackgroundColor3 = can and C.Gold or C.Grey
	else
		attuneBtn.Text = "👑 All attuned"
		attuneBtn.BackgroundColor3 = C.Grey
	end
end

local bigModel
function refreshDetail()
	local id = state.selected
	local w = id and Config.WeaponById[id]
	if bigModel then bigModel:Destroy() bigModel = nil end
	if not w then return end
	local r = rarityOf(w)
	local e = owned(id)
	bigModel = placeModel(bigVp, bigCam, id, 4.6)
	bigVp.ImageColor3 = e and Color3.new(1, 1, 1) or Color3.new(0.08, 0.08, 0.08)
	dName.Text = e and w.Name or ("??? (" .. w.Name .. ")")
	dRarity.Text = string.format("%s  •  %s  •  %s", w.Rarity:upper(), w.Type, islandName(w.Island))
	dRarity.TextColor3 = r.Rainbow and Color3.new(1, 1, 1) or r.Color
	local luck = player:GetAttribute("LuckMult") or 1
	local p = Economy.WeaponOdds(id, luck)
	local lines = {}
	local stage = myData and M6Inventory.Stage(myData, id) or 0
	table.insert(lines, string.format("⚡ Power %s", Config.FormatNumber(Config.GetWeaponPower(id, e and e.Star or 0, e and e.Shiny, stage))))
	if stage > 0 then table.insert(lines, string.format("Awakening %s  •  %d rune sockets", ({"I", "II", "III"})[stage], stage)) end
	if p and p > 0 then
		table.insert(lines, string.format("🎲 %s base  •  you: 1 in %s per roll at its altar", Config.FormatOneIn(w.OneIn), Config.FormatNumber(math.floor(1 / p + 0.5))))
	end
	table.insert(lines, "📍 " .. Config.AcquireText(w))
	if e then
		table.insert(lines, string.format("📦 %d spare copies  •  ★%d%s  •  pulled %d×", e.Copies or 0, e.Star or 0, e.Shiny and "  •  ✨ SHINY" or "", e.Pulled or 0))
	end
	dInfo.Text = table.concat(lines, "\n")
	favToggle.Text = isFav(id) and "♥ FAV" or "♡ FAV"
	favToggle.BackgroundColor3 = isFav(id) and C.Red or C.Plank
	local equipped = player:GetAttribute("EquippedBlade") == id
	equipBtn.Text = equipped and "EQUIPPED" or (e and "EQUIP" or "LOCKED")
	equipBtn.BackgroundColor3 = equipped and C.Gold or (e and C.Leaf or C.Grey)
	autoBtn.Text = (myData and myData.AutoEquip) and "AUTO ✓" or "AUTO ✗"
	autoBtn.BackgroundColor3 = (myData and myData.AutoEquip) and C.Teal or C.Grey
end

-- spin + drag to rotate the inspected weapon
local yaw, dragging, lastX = 0, false, 0
bigVp.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, lastX = true, i.Position.X end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		yaw += (i.Position.X - lastX) * 0.012
		lastX = i.Position.X
	end
end)
RunService.RenderStepped:Connect(function(dt)
	if not panel.Visible or not bigModel then return end
	if not dragging and not player:GetAttribute("Pref_ReducedMotion") then yaw += dt * 0.6 end
	bigModel:PivotTo(CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(90), 0, 0))
end)

local function cycle(list, cur)
	if cur == nil then return list[1] end
	local i = table.find(list, cur)
	return (i and i < #list) and list[i + 1] or nil
end
islandBtn.Activated:Connect(function() state.island = cycle(ISLANDS, state.island) refreshGrid() end)
rarityBtn.Activated:Connect(function() state.rarity = cycle(RARITIES, state.rarity) refreshGrid() end)
typeBtn.Activated:Connect(function() state.type = cycle(TYPES, state.type) refreshGrid() end)
ownedBtn.Activated:Connect(function()
	if state.owned == nil then state.owned = true elseif state.owned == true then state.owned = false else state.owned = nil end
	refreshGrid()
end)
favBtn.Activated:Connect(function() state.fav = not state.fav refreshGrid() end)
sortBtn.Activated:Connect(function() state.sort = state.sort % #SORTS + 1 refreshGrid() end)

favToggle.Activated:Connect(function()
	local id = state.selected
	if not (id and owned(id)) then return end
	local ok, res = pcall(function() return RollRemote:InvokeServer("Favorite", id, not isFav(id)) end)
	if ok and res and myData then
		myData.Favorites = myData.Favorites or {}
		myData.Favorites[id] = (not myData.Favorites[id]) or nil
		refreshGrid() refreshDetail()
	end
end)
equipBtn.Activated:Connect(function()
	local id = state.selected
	if id and owned(id) then pcall(function() ShopAction:InvokeServer("Equip", id) end) task.wait(0.2) refreshDetail() end
end)
autoBtn.Activated:Connect(function()
	if myData then pcall(function() ShopAction:InvokeServer("AutoEquip", nil, not myData.AutoEquip) end) end
end)
attuneBtn.Activated:Connect(function()
	local isl = attuneBtn:GetAttribute("Island")
	if not isl then return end
	pcall(function() RollRemote:InvokeServer("Attune", isl) end)
end)

local function setData(d)
	myData = d
	if panel.Visible then refreshGrid() refreshDetail() end
end
DataSync.OnClientEvent:Connect(setData)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then setData(d) end
end)

local function setOpen(visible)
	panel.Visible = visible
	if panel.Visible then
		T.Pop(panel)
		refreshGrid()
		if not state.selected then
			state.selected = player:GetAttribute("EquippedBlade") or Config.StarterWeapon
		end
		refreshDetail()
	end
end
openBtn.Activated:Connect(function() setOpen(not panel.Visible) end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("OpenPanel")=="Gallery" then setOpen(true) end
end)
closeBtn.Activated:Connect(function() panel.Visible = false end)
player:GetAttributeChangedSignal("EquippedBlade"):Connect(function() if panel.Visible then refreshDetail() end end)
