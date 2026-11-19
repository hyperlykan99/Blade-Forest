-- TraitsController: TRAITS button + Trait Crate panel, rolling reveal and the
-- keep / replace choice. Opens from the button, the crate in the plaza, or
-- the Soul Shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TraitAction = Remotes:WaitForChild("TraitAction")
local GetData = Remotes:WaitForChild("GetData")
local DataSync = Remotes:WaitForChild("DataSync")

local player = Players.LocalPlayer
local F = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PURPLE = Color3.fromRGB(200, 120, 255)
local SOUL = Config.SoulColor

local myData

local gui = Instance.new("ScreenGui")
gui.Name = "TraitsUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
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
	b.AutoButtonColor = true
	for k, v in pairs(props) do b[k] = v end
	b.Parent = parent
	corner(b, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	return b
end
local function rainbowize(lbl, on)
	local g = lbl:FindFirstChild("Rainbow")
	if on and not g then
		g = Instance.new("UIGradient")
		g.Name = "Rainbow"
		g.Color = Config.RainbowSequence
		g.Parent = lbl
	elseif not on and g then
		g:Destroy()
	end
end
local function traitText(lbl, t)
	if not t then
		lbl.Text = "No trait yet"
		lbl.TextColor3 = Color3.fromRGB(170, 170, 185)
		rainbowize(lbl, false)
		return
	end
	lbl.Text = t.Name
	lbl.TextColor3 = t.Rainbow and WHITE or t.Color
	rainbowize(lbl, t.Rainbow)
end

--------------------------------------------------------------------
-- TRAITS button (right side)
--------------------------------------------------------------------
local openBtn = button(gui, {
	Name = "TraitsButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -34),
	Size = UDim2.fromOffset(140, 54), BackgroundColor3 = Color3.fromRGB(175, 90, 235), Text = "✨ TRAITS", TextScaled = false, TextSize = 21,
})
corner(openBtn, 14)
stroke(openBtn, Color3.fromRGB(95, 35, 140), 3)

--------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "TraitPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.53)
panel.Size = UDim2.new(0, 560, 0.82, 0)
panel.BackgroundColor3 = Color3.fromRGB(26, 20, 38)
panel.Visible = false
panel.Parent = gui
corner(panel, 18)
stroke(panel, PURPLE, 4)
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(560, 560)
maxSize.Parent = panel
local popScale = Instance.new("UIScale")
popScale.Parent = panel

label(panel, { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -90, 0, 38), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "✨ TRAIT CRATE", TextColor3 = PURPLE })
local closeBtn = button(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Color3.fromRGB(200, 50, 60), Text = "X" })

-- current trait card
local card = Instance.new("Frame")
card.Position = UDim2.fromOffset(16, 60)
card.Size = UDim2.new(1, -32, 0, 70)
card.BackgroundColor3 = Color3.fromRGB(40, 30, 58)
card.Parent = panel
corner(card, 12)
local cardStroke = stroke(card, PURPLE, 2)
label(card, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.5, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "YOUR TRAIT", TextColor3 = Color3.fromRGB(180, 165, 205) })
local curName = label(card, { Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -200, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
local curMult = label(card, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -112, 0, 22), Size = UDim2.fromOffset(110, 30),
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 220, 120) })
local lockBtn = button(card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(92, 44),
	BackgroundColor3 = Color3.fromRGB(80, 75, 95), Text = "Lock" })

-- odds table
local oddsFrame = Instance.new("Frame")
oddsFrame.Position = UDim2.fromOffset(16, 142)
oddsFrame.Size = UDim2.new(1, -32, 1, -142 - 86)
oddsFrame.BackgroundTransparency = 1
oddsFrame.Parent = panel
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 22)
header.BackgroundTransparency = 1
header.Parent = oddsFrame
label(header, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.42, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = "TRAIT", TextColor3 = Color3.fromRGB(180, 165, 205) })
label(header, { Position = UDim2.fromScale(0.42, 0), Size = UDim2.fromScale(0.18, 1), Text = "BONUS", TextColor3 = Color3.fromRGB(180, 165, 205) })
label(header, { Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.2, 1), Text = "CRATE", TextColor3 = Color3.fromRGB(255, 220, 120) })
label(header, { Position = UDim2.fromScale(0.8, 0), Size = UDim2.fromScale(0.2, 1), Text = "SOUL", TextColor3 = SOUL })
local rowsHolder = Instance.new("Frame")
rowsHolder.Position = UDim2.fromOffset(0, 26)
rowsHolder.Size = UDim2.new(1, 0, 1, -26)
rowsHolder.BackgroundTransparency = 1
rowsHolder.Parent = oddsFrame
local rl = Instance.new("UIListLayout")
rl.Padding = UDim.new(0, 4)
rl.SortOrder = Enum.SortOrder.LayoutOrder
rl.Parent = rowsHolder

local lucky = player:GetAttribute("Pass_LuckyCrates") == true
local logOdds, soulOdds = Config.GetTraitOdds("Logs", lucky), Config.GetTraitOdds("Souls", lucky)
local oddsLabels = {}
local function pct(c)
	if c <= 0 then return "-" end
	return c >= 1 and string.format("%g%%", math.floor(c * 10 + 0.5) / 10) or string.format("%.1f%%", c)
end
local traitRows = {}
for i, t in ipairs(Config.Traits) do
	local row = Instance.new("Frame")
	row.LayoutOrder = i
	row.Size = UDim2.new(1, 0, 1 / #Config.Traits, -4)
	row.BackgroundColor3 = Color3.fromRGB(38, 30, 54)
	row.Parent = rowsHolder
	corner(row, 8)
	local rs = stroke(row, t.Color, 0)
	local n = label(row, { Position = UDim2.new(0, 10, 0.15, 0), Size = UDim2.new(0.42, -10, 0.7, 0), TextXAlignment = Enum.TextXAlignment.Left })
	traitText(n, t)
	label(row, { Position = UDim2.fromScale(0.42, 0.15), Size = UDim2.fromScale(0.18, 0.7), Text = "x" .. tostring(t.Mult), TextColor3 = Color3.fromRGB(255, 220, 120) })
	local lo = label(row, { Position = UDim2.fromScale(0.6, 0.15), Size = UDim2.fromScale(0.2, 0.7), Text = pct(logOdds[i].Chance) })
	local so = label(row, { Position = UDim2.fromScale(0.8, 0.15), Size = UDim2.fromScale(0.2, 0.7), Text = pct(soulOdds[i].Chance), TextColor3 = SOUL })
	oddsLabels[i] = { lo, so }
	traitRows[t.Id] = rs
end

player:GetAttributeChangedSignal("Pass_LuckyCrates"):Connect(function()
	local l = player:GetAttribute("Pass_LuckyCrates") == true
	local a, b = Config.GetTraitOdds("Logs", l), Config.GetTraitOdds("Souls", l)
	for i, pair in pairs(oddsLabels) do
		pair[1].Text = pct(a[i].Chance)
		pair[2].Text = pct(b[i].Chance)
	end
end)

-- roll buttons
local logBtn = button(panel, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(0.5, -24, 0, 58),
	BackgroundColor3 = Color3.fromRGB(70, 175, 80), Text = "Open Crate" })
stroke(logBtn, Color3.fromRGB(30, 95, 40), 3)
local soulBtn = button(panel, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0.5, -24, 0, 58),
	BackgroundColor3 = Color3.fromRGB(140, 80, 220), Text = "Soul Crate" })
stroke(soulBtn, Color3.fromRGB(70, 30, 120), 3)

local msgLabel = label(panel, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -78), Size = UDim2.new(1, -40, 0, 20),
	Text = "", TextColor3 = Color3.fromRGB(255, 130, 130) })
local msgToken = 0
local function flash(text, color)
	msgToken += 1
	local my = msgToken
	msgLabel.Text = text
	msgLabel.TextColor3 = color or Color3.fromRGB(255, 130, 130)
	task.delay(2.5, function() if msgToken == my then msgLabel.Text = "" end end)
end

local function refresh()
	local t = myData and myData.Trait and Config.TraitById[myData.Trait]
	traitText(curName, t)
	curMult.Text = t and ("x" .. tostring(t.Mult) .. " Logs") or "x1 Logs"
	cardStroke.Color = t and t.Color or PURPLE
	local locked = myData and myData.TraitLocked
	lockBtn.Text = locked and "🔒 Locked" or "Lock"
	lockBtn.BackgroundColor3 = locked and Color3.fromRGB(200, 150, 40) or Color3.fromRGB(80, 75, 95)
	for id, rs in pairs(traitRows) do rs.Thickness = (t and t.Id == id) and 3 or 0 end
	local cost = Config.GetTraitCrateCost(myData and myData.BestArea)
	local free = myData and myData.FreeCrates or 0
	if free > 0 then
		logBtn.Text = string.format("FREE Crate  (%d left)", free)
		logBtn.BackgroundColor3 = Color3.fromRGB(230, 165, 30)
	else
		logBtn.Text = "Open Crate  " .. Config.FormatNumber(cost) .. " Logs"
		logBtn.BackgroundColor3 = Color3.fromRGB(70, 175, 80)
	end
	soulBtn.Text = "Soul Crate  ✨" .. Config.SoulCrateCost
end

DataSync.OnClientEvent:Connect(function(data) myData = data refresh() end)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then myData = d end
	refresh()
end)

--------------------------------------------------------------------
-- Reveal overlay
--------------------------------------------------------------------
local overlay = Instance.new("Frame")
overlay.Name = "Reveal"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.Visible = false
overlay.ZIndex = 20
overlay.Parent = gui
local revealTop = label(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(500, 34),
	Text = "ROLLING...", TextColor3 = Color3.fromRGB(220, 210, 240), ZIndex = 21 })
local revealName = label(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 80),
	TextStrokeTransparency = 0, ZIndex = 21 })
local revealMult = label(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(400, 40),
	TextColor3 = Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 0.2, ZIndex = 21 })
local keepNew = button(overlay, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -10, 0.66, 0), Size = UDim2.fromOffset(230, 60),
	BackgroundColor3 = Color3.fromRGB(70, 175, 80), Text = "Take NEW", ZIndex = 22, Visible = false })
local keepOld = button(overlay, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 10, 0.66, 0), Size = UDim2.fromOffset(230, 60),
	BackgroundColor3 = Color3.fromRGB(90, 85, 110), Text = "Keep CURRENT", ZIndex = 22, Visible = false })
local okBtn = button(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(200, 56),
	BackgroundColor3 = Color3.fromRGB(140, 80, 220), Text = "Nice!", ZIndex = 22, Visible = false })

local rolling = false

local function showTrait(t)
	traitText(revealName, t)
	revealMult.Text = "x" .. tostring(t.Mult) .. " Logs forever"
end

local function spin(finalId)
	-- cycle through traits, slowing down, then land on the result
	local delay = 0.04
	local i = math.random(1, #Config.Traits)
	while delay < 0.22 do
		i = i % #Config.Traits + 1
		showTrait(Config.Traits[i])
		task.wait(delay)
		delay *= 1.16
	end
	local t = Config.TraitById[finalId]
	showTrait(t)
	revealName.Size = UDim2.fromOffset(640, 100)
	TweenService:Create(revealName, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 80) }):Play()
	return t
end

local function finish()
	overlay.Visible = false
	panel.Visible = true
	keepNew.Visible, keepOld.Visible, okBtn.Visible = false, false, false
	rolling = false
	refresh()
end

local function doRoll(crate)
	if rolling then return end
	rolling = true
	local ok, res = TraitAction:InvokeServer("Roll", crate)
	if not ok then
		rolling = false
		flash(res or "?")
		return
	end
	overlay.Visible = true
	panel.Visible = false
	revealTop.Text = crate == "Souls" and "SOUL CRATE" or (crate == "Free" and "FREE TRAIT CRATE" or "TRAIT CRATE")
	local t = spin(res.Result)
	if res.Applied then
		revealTop.Text = "NEW TRAIT!"
		okBtn.Visible = true
	elseif res.Same then
		revealTop.Text = "Same as your current trait"
		okBtn.Text = "OK"
		okBtn.Visible = true
	elseif res.Pending then
		local cur = Config.TraitById[res.Current]
		revealTop.Text = string.format("You have %s (x%s)", cur.Name, tostring(cur.Mult))
		keepNew.Text = "Take " .. t.Name
		keepOld.Text = "Keep " .. cur.Name
		keepNew.BackgroundColor3 = t.Mult > cur.Mult and Color3.fromRGB(70, 175, 80) or Color3.fromRGB(90, 85, 110)
		keepOld.BackgroundColor3 = t.Mult > cur.Mult and Color3.fromRGB(90, 85, 110) or Color3.fromRGB(70, 175, 80)
		keepNew.Visible, keepOld.Visible = true, true
	end
end

keepNew.Activated:Connect(function()
	TraitAction:InvokeServer("Choose", true)
	finish()
end)
keepOld.Activated:Connect(function()
	TraitAction:InvokeServer("Choose", false)
	finish()
end)
okBtn.Activated:Connect(function()
	okBtn.Text = "Nice!"
	finish()
end)

logBtn.Activated:Connect(function()
	doRoll((myData and (myData.FreeCrates or 0) > 0) and "Free" or "Logs")
end)
soulBtn.Activated:Connect(function() doRoll("Souls") end)
lockBtn.Activated:Connect(function()
	local ok, res = TraitAction:InvokeServer("Lock", not (myData and myData.TraitLocked))
	if ok and myData then myData.TraitLocked = res.Locked refresh() end
end)

--------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------
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
player:GetAttributeChangedSignal("OpenTraitsUI"):Connect(function() open(true) end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "TraitPrompt" then open(true) end
end)

-- expose for testing
local api = Instance.new("BindableFunction")
api.Name = "TraitsAPI"
api.OnInvoke = function(cmd, arg)
	if cmd == "Open" then open(arg ~= false) end
	if cmd == "Roll" then task.spawn(doRoll, arg) end
	return true
end
api.Parent = script
