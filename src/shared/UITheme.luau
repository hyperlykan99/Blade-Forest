-- UITheme: "Lumberjack Adventure" look shared by every menu.
-- Wood-plank panels, leafy green + gold accents, chunky Luckiest Guy titles.
local T = {}

T.Font = {
	Title = Font.fromEnum(Enum.Font.LuckiestGuy),
	Body = Font.fromEnum(Enum.Font.FredokaOne),
}

T.Color = {
	Ink = Color3.fromRGB(38, 22, 12),        -- outlines
	WoodDark = Color3.fromRGB(70, 42, 24),
	Wood = Color3.fromRGB(122, 78, 44),
	WoodLight = Color3.fromRGB(176, 120, 70),
	Plank = Color3.fromRGB(96, 60, 34),
	Cream = Color3.fromRGB(255, 244, 220),
	Gold = Color3.fromRGB(255, 203, 64),
	GoldDark = Color3.fromRGB(176, 118, 20),
	Leaf = Color3.fromRGB(96, 196, 72),
	LeafDark = Color3.fromRGB(40, 112, 36),
	Red = Color3.fromRGB(226, 72, 60),
	Blue = Color3.fromRGB(64, 150, 235),
	Purple = Color3.fromRGB(160, 90, 230),
	Teal = Color3.fromRGB(40, 190, 200),
	Orange = Color3.fromRGB(245, 150, 40),
	Grey = Color3.fromRGB(120, 112, 104),
}

-- Player scripts can start before StarterGui has been copied into PlayerGui.
-- Mount passive HUD items when their shared layout becomes available.
function T.AttachToHud(widget, containerName)
	task.spawn(function()
		local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		local gameUI = playerGui:WaitForChild("GameUI", math.huge)
		widget.Parent = gameUI:WaitForChild(containerName)
	end)
end

function T.Corner(p, r)
	local c = p:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
	return c
end

function T.Stroke(p, color, th, mode)
	local s = Instance.new("UIStroke")
	s.Color = color or T.Color.Ink
	s.Thickness = th or 3
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

-- top-light / bottom-dark sheen used on buttons + panels
function T.Sheen(p, dark)
	local g = p:FindFirstChild("ThemeSheen") or Instance.new("UIGradient")
	g.Name = "ThemeSheen"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(0.94, 0.94, 0.94)),
		ColorSequenceKeypoint.new(1, Color3.new(dark or 0.72, dark or 0.72, dark or 0.72)),
	})
	g.Parent = p
	return g
end

-- outlined cartoon text
function T.TextOutline(lbl, th)
	if lbl:FindFirstChild("ThemeTextStroke") then return end
	local s = Instance.new("UIStroke")
	s.Name = "ThemeTextStroke"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = T.Color.Ink
	s.Thickness = th or 2
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = lbl
end

function T.Label(parent, props, title)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = title and T.Font.Title or T.Font.Body
	l.TextColor3 = T.Color.Cream
	l.TextScaled = true
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	T.TextOutline(l, title and 2.5 or 1.5)
	return l
end

function T.Button(parent, props, color)
	local b = Instance.new("TextButton")
	b.FontFace = T.Font.Title
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color or T.Color.Leaf
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do b[k] = v end
	b.Parent = parent
	T.Corner(b, 12)
	T.Stroke(b, T.Color.Ink, 3)
	T.Sheen(b)
	T.TextOutline(b, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	return b
end

-- Wood panel with a title plate and close button. Returns panel, body, closeButton.
function T.Panel(parent, name, title, accent, w, hScale)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.new(0, w or 560, hScale or 0.8, 0)
	panel.BackgroundColor3 = T.Color.Wood
	panel.Visible = false
	panel.Parent = parent
	panel:SetAttribute("ThemePanel", true)
	T.Corner(panel, 18)
	T.Stroke(panel, T.Color.Ink, 5)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(w or 560, 580)
	lim.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Parent = panel
	local g = Instance.new("UIGradient")
	g.Name = "ThemeSheen"
	g.Rotation = 90
	g.Color = ColorSequence.new(T.Color.WoodLight, T.Color.WoodDark)
	g.Parent = panel
	-- title plate
	local plate = Instance.new("Frame")
	plate.Name = "TitlePlate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.new(0.5, 0, 0, 2)
	plate.Size = UDim2.fromOffset(300, 54)
	plate.BackgroundColor3 = accent or T.Color.Leaf
	plate.ZIndex = 5
	plate.Parent = panel
	T.Corner(plate, 14)
	T.Stroke(plate, T.Color.Ink, 4)
	T.Sheen(plate, 0.75)
	T.Label(plate, { Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Text = title, ZIndex = 6 }, true)
	-- body (inset darker plank)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(14, 38)
	body.Size = UDim2.new(1, -28, 1, -52)
	body.BackgroundColor3 = T.Color.WoodDark
	body.BackgroundTransparency = 0.25
	body.Parent = panel
	T.Corner(body, 12)
	local close = T.Button(panel, { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 10, 0, -14),
		Size = UDim2.fromOffset(48, 48), Text = "X", ZIndex = 6 }, T.Color.Red)
	return panel, body, close
end

function T.Pop(panel)
	local s = panel:FindFirstChild("PopScale")
	if not s then return end
	s.Scale = 0.88
	game:GetService("TweenService"):Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return T
