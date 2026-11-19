-- RollController: altar odds panel, roll animation + reveal, spinning altar showcases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollRemote = Remotes:WaitForChild("Roll")
local ShopAction = Remotes:WaitForChild("ShopAction")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")
local BladeModels = ReplicatedStorage:WaitForChild("BladeModels")

local player = Players.LocalPlayer
local F = Enum.Font.FredokaOne

local myData

--------------------------------------------------------------------
-- small UI helpers
--------------------------------------------------------------------
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(p, r) new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, p) end
local function stroke(p, c, t) return new("UIStroke", { Color = c, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p) end

local function sound(id, vol, pitch)
	local s = new("Sound", { SoundId = id, Volume = vol or 0.5, PlaybackSpeed = pitch or 1 }, SoundService)
	s:Play()
	task.delay(3, function() s:Destroy() end)
end
local TICK_SOUND = "rbxasset://sounds/clickfast.wav"
local REVEAL_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local gui = new("ScreenGui", { Name = "RollUI", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
--------------------------------------------------------------------
-- HUD roll bar (free rolls, Sol's RNG style)
--------------------------------------------------------------------
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local resultEvent = Instance.new("BindableEvent")
resultEvent.Name = "RollResult" -- AFK tracker listens to this
resultEvent.Parent = script

local bar = new("Frame", {
	Name = "RollBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	BackgroundTransparency = 1, Active = false,
}, gui)
local rollBtn = T.Button(bar, { Name = "RollButton", Text = "ROLL" }, T.Color.Leaf)
local autoBtn = T.Button(bar, { Name = "AutoRollButton", Text = "AUTO" }, T.Color.Grey)
local filterBtn = T.Button(bar, { Name = "FilterButton", Text = "SELL\nOFF" }, T.Color.Grey)
local infoLabel2 = T.Label(bar, {
	Name = "RollInfo", Size = UDim2.new(1, 0, 0, 16), Text = "",
})
new("UITextSizeConstraint", { MaxTextSize = 13 }, infoLabel2)

-- The action buttons share the same safe-area origin, even though their
-- gameplay handlers live in different controllers.
local widths = { PvPButton = 66, FilterButton = 62, RollButton = 86, AutoRollButton = 54, BladeToggle = 68 }
local fullRow = { "PvPButton", "FilterButton", "RollButton", "AutoRollButton", "BladeToggle" }
local rollRow = { "FilterButton", "RollButton", "AutoRollButton" }
local toggleRow = { "PvPButton", "BladeToggle" }
local gap, buttonHeight = 6, 44

local function placeRow(names, bottom)
	local width = (#names - 1) * gap
	for _, name in ipairs(names) do width += widths[name] end
	local x = -width / 2
	for _, name in ipairs(names) do
		local button = bar:FindFirstChild(name)
		if button then
			button.AnchorPoint = Vector2.new(0, 1)
			button.Position = UDim2.new(0.5, x, 1, -bottom)
			button.Size = UDim2.fromOffset(widths[name], buttonHeight)
		end
		x += widths[name] + gap
	end
	return width
end

local function fitBar()
	local size = gui.AbsoluteSize
	local wide = size.X >= (size.Y < 500 and 560 or 680)
	if wide then
		bar.Size = UDim2.fromOffset(placeRow(fullRow, 0), 64)
	else
		local width = placeRow(rollRow, buttonHeight + gap)
		placeRow(toggleRow, 0)
		bar.Size = UDim2.fromOffset(width, 64 + buttonHeight + gap)
	end
	-- Portrait phones need clearance above Roblox's thumbstick and jump button.
	local bottom = not wide and size.Y > size.X and 112 or 8
	bar.Position = UDim2.new(0.5, 0, 1, -bottom)
end

local function styleAction(button)
	if not widths[button.Name] or not button:IsA("TextButton") then return end
	button.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = button == rollBtn and 25 or 15 }, button)
	local pad = button:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
	end
	T.Corner(button, 9)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Thickness = child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and 2 or 1
		end
	end
end
for _, child in ipairs(bar:GetChildren()) do styleAction(child) end
bar.ChildAdded:Connect(function(child)
	if widths[child.Name] then
		task.defer(styleAction, child)
		fitBar()
	end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBar)
fitBar()
local FILTERS = { false, "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local autoOn = false
local LEGENDARY = Config.RarityById.Legendary.Order
local closeReveal, doRoll -- defined below

local function getLuck()
	return (player:GetAttribute("LuckMult") or 1) * (workspace:GetAttribute("EventLuck") or 1)
end

local function refreshBar()
	local total = myData and myData.Rolls and myData.Rolls.Total or 0
	local toLucky = Config.LuckyRollEvery - (total % Config.LuckyRollEvery)
	local luckTxt = string.format("Luck x%s", (math.floor(getLuck() * 100 + 0.5) / 100))
	infoLabel2.Text = string.format("Roll #%s  •  %s  •  %s", Config.FormatNumber(total), luckTxt,
		toLucky == 1 and "Next roll 2×" or ("2× in " .. (toLucky - 1)))
	infoLabel2.TextColor3 = toLucky == 1 and T.Color.Gold or T.Color.Cream
	autoBtn.Text = autoOn and "AUTO\nON" or "AUTO"
	autoBtn.BackgroundColor3 = autoOn and T.Color.Leaf or T.Color.Grey
	local f = myData and myData.Settings and myData.Settings.AutoSellBelow
	filterBtn.Text = f and ("SELL <\n" .. f:upper()) or "SELL\nOFF"
	filterBtn.BackgroundColor3 = f and Config.RarityById[f].Color:Lerp(Color3.new(0, 0, 0), 0.25) or T.Color.Grey
end
local function applyData(data)
	myData = data
	refreshBar()
end
DataSync.OnClientEvent:Connect(applyData)
task.spawn(function()
	local data = GetData:InvokeServer()
	if data and not myData then applyData(data) end
end)
player:GetAttributeChangedSignal("LuckMult"):Connect(refreshBar)
workspace:GetAttributeChangedSignal("EventLuck"):Connect(refreshBar)
task.defer(refreshBar)

filterBtn.Activated:Connect(function()
	if not myData then return end
	local cur = myData.Settings.AutoSellBelow or false
	local idx = table.find(FILTERS, cur) or 1
	local nextValue = FILTERS[idx % #FILTERS + 1]
	ShopAction:InvokeServer("Setting", "AutoSellBelow", nextValue or nil)
end)

local playRoll -- defined below
--------------------------------------------------------------------
-- Reveal overlay
--------------------------------------------------------------------
local overlay = new("TextButton", { Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
	Text = "", AutoButtonColor = false, Visible = false, ZIndex = 10 }, gui)
local center = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 10 }, overlay)
-- light rays behind the weapon
local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 10 }, center)
local rayParts = {}
for i = 1, 12 do
	local ray = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 760), Rotation = i * 15,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 10 }, rays)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }, ray)
	table.insert(rayParts, ray)
end
local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 420), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.6, ZIndex = 10 }, center)
corner(glow, 400)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, glow)
local vp = new("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 300), BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(200, 200, 210), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 11 }, center)
local vpCam = new("Camera", { FieldOfView = 22, CFrame = CFrame.new(0, 0, 13) }, vp)
vp.CurrentCamera = vpCam
local rarityLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(600, 40), BackgroundTransparency = 1,
	Font = F, TextSize = 34, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = "", ZIndex = 12 }, overlay)
local rarityGradient = new("UIGradient", { Color = Config.RainbowSequence, Enabled = false }, rarityLabel)
local nameLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 40), Size = UDim2.fromOffset(700, 60), BackgroundTransparency = 1,
	Font = F, TextSize = 52, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, Text = "", ZIndex = 12 }, overlay)
local infoLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 104), Size = UDim2.fromOffset(700, 34), BackgroundTransparency = 1,
	Font = F, TextSize = 26, TextColor3 = Color3.fromRGB(255, 230, 120), TextStrokeTransparency = 0.2, Text = "", ZIndex = 12 }, overlay)
local hintLabel = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(500, 26), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = Color3.fromRGB(200, 200, 210), Text = "", ZIndex = 12 }, overlay)
local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 20 }, gui)

-- Every weapon is cloned into the viewport ONCE and parked off-camera.
-- Showing one = moving it to the centre. (Viewports don't draw meshes that
-- were created mid-animation, so we never create them on the fly.)
local SHOW_CF = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.rad(-28), 0)
local HIDE_CF = CFrame.new(0, 500, 0)
local vpModels = {}
for _, t in ipairs(BladeModels:GetChildren()) do
	local m = t:Clone()
	m:PivotTo(HIDE_CF)
	m.Parent = vp
	vpModels[t.Name] = m
end
local shownModel
local function showWeapon(id)
	if shownModel then shownModel:PivotTo(HIDE_CF) end
	shownModel = vpModels[id]
	if shownModel then shownModel:PivotTo(SHOW_CF) end
end
local function hideWeapon()
	if shownModel then shownModel:PivotTo(HIDE_CF) end
	shownModel = nil
end
-- once meshes have downloaded, re-add the models so the viewport picks them up
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(BladeModels:GetDescendants())
	end)
	for _, m in pairs(vpModels) do
		m.Parent = nil
		m.Parent = vp
	end
end)


local spinT = 0
local currentGlowColor = Color3.new(1, 1, 1)
local rainbowOn = false
RunService.RenderStepped:Connect(function(dt)
	if not overlay.Visible then return end
	spinT += dt
	rays.Rotation = player:GetAttribute("Pref_ReducedMotion") and 0 or spinT * 25
	if shownModel then
		shownModel:PivotTo(SHOW_CF * CFrame.Angles(0, 0, math.sin(spinT * 2) * 0.35))
	end
	if rainbowOn then
		local c = Color3.fromHSV((spinT * 0.4) % 1, 0.7, 1)
		glow.BackgroundColor3 = c
		for _, r in ipairs(rayParts) do r.BackgroundColor3 = c end
	end
end)

local function setGlow(color, strength)
	currentGlowColor = color
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.75 - 0.35 * strength
	for _, r in ipairs(rayParts) do
		r.BackgroundColor3 = color
		r.BackgroundTransparency = 1 - 0.85 * strength
	end
end

local skipRequested = false
local revealDone = false
local animating = false

function closeReveal()
	overlay.Visible = false
	hideWeapon()
end

overlay.MouseButton1Click:Connect(function()
	if animating then
		skipRequested = true
	elseif revealDone then
		closeReveal()
	end
end)

function playRoll(result)
	animating, revealDone, skipRequested = true, false, false
	rainbowOn = false
	rarityGradient.Enabled = false
	overlay.Visible = true
	for _, m in pairs(vpModels) do
		m.Parent = nil
		m.Parent = vp
	end
	for _, m in pairs(vpModels) do
		m.Parent = nil
		m.Parent = vp
	end
	for _, m in pairs(vpModels) do
		m.Parent = nil
		m.Parent = vp
	end
	rarityLabel.Text = ""
	nameLabel.Text = ""
	infoLabel.Text = ""
	hintLabel.Text = "click to skip"

	local finalWeapon = Config.WeaponById[result.Id]
	local finalRarity = Config.RarityById[finalWeapon.Rarity]

	-- the cycle shows weapons of similar rarity (and a few rarer teasers)
	local pool = {}
	for _, w in ipairs(Config.RollPool) do
		if w.OneIn <= math.max(finalWeapon.OneIn or 2, 50) * 20 then table.insert(pool, w) end
	end
	if #pool == 0 then pool = { finalWeapon } end

	-- rarer pulls spin longer
	local duration = 1.1 + finalRarity.Order * 0.3
	local t, interval = 0, 0.045
	local last
	while t < duration and not skipRequested do
		local w
		repeat w = pool[math.random(1, #pool)] until w ~= last or #pool == 1
		last = w
		showWeapon(w.Id)
		setGlow(Config.RarityById[w.Rarity].Color, 0.35)
		sound(TICK_SOUND, 0.25, 1 + t / duration * 0.6)
		task.wait(interval)
		t += interval
		interval = math.min(interval * 1.09, 0.32)
	end

	-- land on the result
	animating = false
	showWeapon(result.Id)
	local strength = math.clamp(finalRarity.Order / 5, 0.35, 1)
	setGlow(finalRarity.Color, strength)
	rainbowOn = finalRarity.Rainbow == true
	vp.Size = UDim2.fromOffset(380, 200)
	TweenService:Create(vp, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 300) }):Play()
	sound(REVEAL_SOUND, 0.6, 1.2 - finalRarity.Order * 0.06)

	if finalRarity.Order >= Config.RarityById.Legendary.Order then
		-- Reduced Motion: a soft tint instead of a full white flash
		flash.BackgroundTransparency = player:GetAttribute("Pref_ReducedMotion") and 0.75 or 0
		flash.BackgroundColor3 = finalRarity.Rainbow and Color3.new(1, 1, 1) or finalRarity.Color
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end

	rarityLabel.Text = finalRarity.Id:upper() .. "  •  " .. Config.FormatOneIn(finalWeapon.OneIn or 2)
	rarityLabel.TextColor3 = finalRarity.Rainbow and Color3.new(1, 1, 1) or finalRarity.Color
	rarityGradient.Enabled = finalRarity.Rainbow == true
	nameLabel.Text = finalWeapon.Name
	nameLabel.TextColor3 = finalRarity.Rainbow and Color3.new(1, 1, 1) or finalRarity.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	nameLabel.TextSize = 30
	TweenService:Create(nameLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { TextSize = 52 }):Play()

	local power = Config.FormatNumber(Config.GetWeaponPower(result.Id, result.Star))
	if result.IsNew then
		infoLabel.Text = "✨ NEW! ✨   ⚡ " .. power .. " Power"
	elseif result.Sold and result.Sold > 0 then
		infoLabel.Text = string.format("Max stars — sold for %s Logs", Config.FormatNumber(result.Sold))
	elseif result.StarsGained and result.StarsGained > 0 then
		infoLabel.Text = string.format("FUSED!  → %s   ⚡ %s Power", string.rep("★", result.Star), power)
	else
		local need = Config.FuseCost[(result.Star or 0) + 1]
		infoLabel.Text = need and string.format("+1 copy  (%d/%d to ★%d)", result.Copies, need, result.Star + 1) or "+1 copy"
	end
	if result.AutoSold then
		infoLabel.Text = string.format("auto-sold for %s Logs", Config.FormatNumber(result.Sold))
	end
	if result.Lucky then
		infoLabel.Text = "2x LUCK ROLL!  •  " .. infoLabel.Text
	end
	hintLabel.Text = "click to continue"
	if player:GetAttribute("EquippedBlade") == result.Id then
		hintLabel.Text = "Equipped!  •  click to continue"
	end
	task.wait(0.4)
	revealDone = true
end
--------------------------------------------------------------------
-- Auto roll: small result cards, full reveal only for big pulls
--------------------------------------------------------------------
local function quickCard(result)
	local w = Config.WeaponById[result.Id]
	local r = Config.RarityById[w.Rarity]
	local info
	if result.IsNew then
		info = "NEW  " .. Config.FormatOneIn(w.OneIn or 2)
	elseif (result.Sold or 0) > 0 then
		info = "sold +" .. Config.FormatNumber(result.Sold) .. " Logs"
	elseif (result.StarsGained or 0) > 0 then
		info = "FUSED " .. string.rep("★", result.Star)
	else
		local need = Config.FuseCost[(result.Star or 0) + 1]
		info = need and string.format("%d/%d copies", result.Copies, need) or "+1"
	end
	local hud = player.PlayerGui:WaitForChild("GameUI")
	hud:WaitForChild("HudNotice"):Fire(w.Name .. "  •  " .. info, r.Rainbow and Color3.new(1, 1, 1) or r.Color, "quickRoll")
end
--------------------------------------------------------------------
-- Rolling
--------------------------------------------------------------------
local busy = false
local function rollRequest()
	local ok, result = RollRemote:InvokeServer()
	if ok and myData then
		myData.Rolls.Total = result.RollNumber or myData.Rolls.Total + 1
		refreshBar()
	end
	return ok, result
end

local function bigEnough(result)
	if player:GetAttribute("Pref_SkipReveals") then return false end
	return result.OneIn >= 1000 or (result.IsNew and Config.RarityById[result.Rarity].Order >= Config.RarityById.Rare.Order)
end

function doRoll()
	if busy or overlay.Visible then return end
	busy = true
	local ok, result = rollRequest()
	if ok then
		resultEvent:Fire(result)
		if bigEnough(result) or not player:GetAttribute("Pref_SkipReveals") then
			playRoll(result)
		else
			quickCard(result)
		end
	elseif result ~= "cooldown" then
		player.PlayerGui:WaitForChild("GameUI"):WaitForChild("HudNotice"):Fire(tostring(result), Color3.fromRGB(255, 153, 137))
	end
	busy = false
end
rollBtn.Activated:Connect(function()
	if not autoOn then doRoll() end
end)

local function autoLoop()
	while autoOn do
		if not overlay.Visible and not busy then
			busy = true
			local ok, result = rollRequest()
			busy = false
			if ok then
				resultEvent:Fire(result)
				if bigEnough(result) then
					playRoll(result)
					task.wait(1.6)
					if overlay.Visible and revealDone then closeReveal() end
				else
					quickCard(result)
				end
			end
		end
		task.wait(player:GetAttribute("Pass_FastRoll") and Config.FastRollInterval or Config.RollInterval)
	end
end

local function setAuto(on)
	if on == autoOn then return end
	autoOn = on
	refreshBar()
	if autoOn then task.spawn(autoLoop) end
end
autoBtn.Activated:Connect(function() setAuto(not autoOn) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		if overlay.Visible and revealDone then
			closeReveal()
		elseif overlay.Visible and animating then
			skipRequested = true
		elseif not autoOn then
			doRoll()
		end
	end
end)

local api = Instance.new("BindableFunction")
api.Name = "RollAPI"
api.OnInvoke = function(cmd, arg)
	if cmd == "SetAuto" then setAuto(arg == true) end
	if cmd == "IsAuto" then return autoOn end
	return autoOn
end
api.Parent = script
