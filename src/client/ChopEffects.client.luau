-- ChopEffects: everything that makes chopping feel good.
--   * strength tags on trees (green = full damage, red = too weak)
--   * gates open (walk-through) once your Power is high enough
--   * trees shake on every hit, chop sounds rise in pitch with your combo
--   * felled trees topple, crash, split into logs that fly into you

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Breakables = workspace:WaitForChild("Breakables")
local TreeModels = ReplicatedStorage:WaitForChild("TreeModels")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local F = Enum.Font.FredokaOne

local CHOP_SOUND = "rbxassetid://9120811299"
local FALL_SOUND = "rbxassetid://9120796401"
local POP_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local fx = Instance.new("Folder")
fx.Name = "ChopFX"
fx.Parent = workspace

local function myPower()
	return player:GetAttribute("Power") or 0
end

local function sound3D(id, pos, vol, pitch)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = pitch
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 140
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 3)
end

local function floatText(pos, text, color, size, rise, life)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = pos
	anchor.Parent = fx
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size * 6, size)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = F
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Text = text
	l.Parent = bb
	TweenService:Create(anchor, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(life * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, life * 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, life)
end

--------------------------------------------------------------------
-- 1) Strength tags
--------------------------------------------------------------------
local GREEN = Color3.fromRGB(110, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)
local tags = {}

local function updateTag(tree)
	local t = tags[tree]
	if not t then return end
	local s = tree:GetAttribute("Strength") or 0
	local ok = myPower() >= s
	t.Label.Text = (ok and "⚡ " or "🔒 ") .. Config.FormatNumber(s)
	t.Label.TextColor3 = ok and GREEN or RED
	t.Stroke.Color = ok and GREEN or RED
end

local function makeTag(tree)
	if tags[tree] or not tree:IsA("Model") or not tree:GetAttribute("IsTree") then return end
	local pp = tree.PrimaryPart
	if not pp then return end -- not streamed in yet; the sweep below retries
	local rarity = tree:GetAttribute("Rarity") or "Common"
	local rdef = Config.RarityById[rarity]
	local mut = Config.MutationById[tree:GetAttribute("Mutation") or ""]
	local fancy = rarity ~= "Common" or mut ~= nil
	local bb = Instance.new("BillboardGui")
	bb.Name = "StrengthTag"
	bb.Size = UDim2.fromOffset(fancy and (mut and 150 or 100) or 78, fancy and 44 or 24)
	bb.MaxDistance = (rdef and rdef.Order >= 4) and 90 or 48
	bb.LightInfluence = 0
	bb.Adornee = pp
	bb.StudsOffsetWorldSpace = Vector3.new(0, -pp.Size.Y / 2 + 4.6, 0)
	if fancy then
		local r = Instance.new("TextLabel")
		r.Name = "Rarity"
		r.Size = UDim2.new(1, 0, 0, 18)
		r.BackgroundTransparency = 1
		r.Font = F
		r.TextScaled = true
		r.Text = mut and string.upper(mut.Icon .. " " .. mut.Name .. " • " .. rarity) or string.upper(rarity)
		r.TextColor3 = rdef and rdef.Color or Color3.new(1, 1, 1)
		r.TextStrokeTransparency = 0.2
		r.Parent = bb
		if mut and not mut.Rainbow then r.TextColor3 = mut.Id == "Shadow" and Color3.fromRGB(190, 120, 255) or mut.Color end
		if (rdef and rdef.Rainbow) or (mut and mut.Rainbow) then
			r.TextColor3 = Color3.new(1, 1, 1)
			local g = Instance.new("UIGradient") g.Color = Config.RainbowSequence g.Parent = r
		end
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromOffset(78, 24)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	frame.BackgroundTransparency = 0.25
	frame.Parent = bb
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, -4)
	label.Position = UDim2.fromOffset(4, 2)
	label.BackgroundTransparency = 1
	label.Font = F
	label.TextScaled = true
	label.Parent = frame
	bb.Parent = fx
	tags[tree] = { Gui = bb, Label = label, Stroke = st }
	updateTag(tree)
	tree.AncestryChanged:Connect(function()
		if not tree:IsDescendantOf(workspace) and tags[tree] then
			tags[tree].Gui:Destroy()
			tags[tree] = nil
		end
	end)
end

-- Tags only exist near you (thousands of trees!). Same loop fades canopies
-- that sit between the camera and your character so chopping stays visible.
local TAG_IN, TAG_OUT = 90, 110
local function removeTag(tree)
	local t = tags[tree]
	if not t then return end
	for _, p in ipairs(t.Leaves) do p.LocalTransparencyModifier = 0 end
	t.Gui:Destroy()
	tags[tree] = nil
end

local function leavesOf(tree)
	local list = {}
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(list, d) end
	end
	return list
end

task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pos = root and root.Position or camera.CFrame.Position
		local made = 0
		for _, t in ipairs(Breakables:GetChildren()) do
			local pp = t.PrimaryPart
			if pp then
				local d = (pp.Position - pos).Magnitude
				local tag = tags[t]
				local tagsOn = player:GetAttribute("Pref_ShowTags") ~= false
				if not tagsOn and tag then
					removeTag(t)
				elseif not tag then
					if tagsOn and d < TAG_IN and t:GetAttribute("IsTree") then
						makeTag(t)
						if tags[t] then tags[t].Leaves = leavesOf(t) end
						made += 1
						if made % 40 == 0 then task.wait() end
					end
				elseif d > TAG_OUT then
					removeTag(t)
				elseif tag.Gui.Adornee ~= pp then
					tag.Gui.Adornee = pp
					tag.Gui.StudsOffsetWorldSpace = Vector3.new(0, -pp.Size.Y / 2 + 4.6, 0)
					tag.Leaves = leavesOf(t)
				end
			end
		end
		task.wait(0.4)
	end
end)

local function segDist2D(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-4 then return (p - a).Magnitude, 0 end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude, t
end

local FADE = 0.72
local lastFade = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastFade < 0.08 then return end
	lastFade = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local cam = camera.CFrame.Position
	local cam2 = Vector3.new(cam.X, 0, cam.Z)
	local me2 = Vector3.new(root.Position.X, 0, root.Position.Z)
	for tree, t in pairs(tags) do
		local pp = tree.PrimaryPart
		if pp and t.Leaves then
			local p2 = Vector3.new(pp.Position.X, 0, pp.Position.Z)
			local fade = (p2 - cam2).Magnitude < 15
			if not fade then
				local dseg = segDist2D(p2, cam2, me2)
				fade = dseg < 9 and (p2 - me2).Magnitude < (cam2 - me2).Magnitude + 6
			end
			if fade ~= (t.Faded or false) then
				t.Faded = fade
				local v = fade and FADE or 0
				for _, p in ipairs(t.Leaves) do p.LocalTransparencyModifier = v end
			end
		end
	end
end)

--------------------------------------------------------------------
-- 2) Gates
--------------------------------------------------------------------
local function updateGates()
	local walls = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AreaWalls")
	if not walls then return end
	for _, b in ipairs(walls:GetDescendants()) do
		if b.Name == "Barrier" and b:IsA("BasePart") then
			if not b:GetAttribute("LockedColor") then b:SetAttribute("LockedColor", b.Color) end
			local req = b:GetAttribute("RequiredPower") or 0
			local ok = myPower() >= req
			b.CanCollide = not ok
			b.Transparency = ok and 0.9 or 0.15
			b.Color = ok and GREEN or b:GetAttribute("LockedColor")
			local sign = b.Parent:FindFirstChild("Sign")
			if sign then
				for _, l in ipairs(sign:GetDescendants()) do
					if l:IsA("TextLabel") then
						local area = Config.AreaById[b:GetAttribute("AreaId")]
						l.Text = ok and ("✔ " .. area.Name:upper() .. " UNLOCKED") or string.format("🔒 %s  •  ⚡ %d Power", area.Name:upper(), req)
						l.TextColor3 = ok and GREEN or b:GetAttribute("LockedColor")
					end
				end
			end
		end
	end
end

player:GetAttributeChangedSignal("Power"):Connect(function()
	for tree in pairs(tags) do updateTag(tree) end
	updateGates()
end)
task.defer(updateGates)

--------------------------------------------------------------------
-- 3) Shake + chop sound + combo
--------------------------------------------------------------------
local theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "ChopCombo"
comboLabel.LayoutOrder = 10
comboLabel.Size = UDim2.new(1, 0, 0, 16)
comboLabel.BackgroundColor3 = Color3.fromRGB(41, 32, 28)
comboLabel.BackgroundTransparency = 0.25
comboLabel.Font = F
comboLabel.TextSize = 12
comboLabel.TextXAlignment = Enum.TextXAlignment.Left
comboLabel.TextColor3 = Color3.fromRGB(242, 217, 168)
comboLabel.TextTruncate = Enum.TextTruncate.AtEnd
comboLabel.Interactable = false
comboLabel.Visible = false
comboLabel.Text = ""
comboLabel:SetAttribute("NoTheme", true)
theme.Corner(comboLabel, 4)
local comboPadding = Instance.new("UIPadding")
comboPadding.PaddingLeft = UDim.new(0, 7)
comboPadding.PaddingRight = UDim.new(0, 7)
comboPadding.Parent = comboLabel
theme.AttachToHud(comboLabel, "Toasts")

local shakes = {}
local combo, lastChop, lastSound, lastWeakHint = 0, 0, 0, 0

local function startShake(tree, hitPos, weak)
	local pp = tree.PrimaryPart
	if not pp then return end
	local s = shakes[tree]
	if not s then
		s = { Orig = tree:GetPivot(), Base = pp.Position - Vector3.new(0, pp.Size.Y / 2, 0) }
		shakes[tree] = s
	end
	local away = (s.Base - hitPos) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.05 then away = Vector3.new(1, 0, 0) end
	s.Axis = Vector3.yAxis:Cross(away.Unit)
	s.T0 = os.clock()
	s.Amp = (weak and 0.012 or 0.045) * (player:GetAttribute("Pref_ReducedMotion") and 0.3 or 1)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for tree, s in pairs(shakes) do
		local dt = now - s.T0
		if dt > 0.45 or not tree.Parent then
			if tree.Parent then tree:PivotTo(s.Orig) end
			shakes[tree] = nil
		else
			local ang = s.Amp * math.sin(dt * 42) * math.exp(-dt * 7)
			tree:PivotTo(CFrame.new(s.Base) * CFrame.fromAxisAngle(s.Axis, ang) * CFrame.new(-s.Base) * s.Orig)
		end
	end
	if combo > 0 and now - lastChop > 2.5 then
		combo = 0
		comboLabel.Visible = false
	end
end)

local function onMyChop(pos, weak, tree)
	local now = os.clock()
	combo = (now - lastChop < 2.5) and combo + 1 or 1
	lastChop = now
	if now - lastSound > 0.05 then
		lastSound = now
		if weak then
			sound3D(CHOP_SOUND, pos, 0.3, 0.6)
		else
			sound3D(CHOP_SOUND, pos, 0.55, 0.95 + math.min(combo, 25) * 0.02)
		end
	end
	if weak and now - lastWeakHint > 2.5 then
		lastWeakHint = now
		floatText(pos + Vector3.new(0, 3, 0), string.format("🔒 TOO WEAK — need ⚡%s", Config.FormatNumber(tree:GetAttribute("Strength") or 0)),
			RED, 26, 2, 1.4)
	end
	comboLabel.Visible = combo >= 3
	if comboLabel.Visible then
		comboLabel.Text = string.format("Chop combo ×%d", combo)
	end
end

Remotes.Hits.OnClientEvent:Connect(function(hits)
	for _, h in ipairs(hits) do
		local pos, target, weak, attackerId = h[1], h[3], h[4], h[5]
		if target and target.Parent and target:GetAttribute("IsTree") then
			startShake(target, pos, weak)
			if attackerId == player.UserId then
				onMyChop(pos, weak, target)
			elseif math.random() < 0.3 then
				sound3D(CHOP_SOUND, pos, 0.25, 1)
			end
		end
	end
end)

--------------------------------------------------------------------
-- 4) Falling trees + flying logs
--------------------------------------------------------------------
local function makeLog(cf, scale)
	local log = Instance.new("Part")
	log.Shape = Enum.PartType.Cylinder
	log.Size = Vector3.new(2.4, 1.1, 1.1) * scale
	log.CFrame = cf
	log.Material = Enum.Material.Wood
	log.Color = Color3.fromRGB(150, 95, 55)
	log.Anchored = true
	log.CanCollide, log.CanQuery, log.CanTouch = false, false, false
	log.Parent = fx
	return log
end

local function flyLogsToMe(logs, amount)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		for _, l in ipairs(logs) do l:Destroy() end
		return
	end
	local arrived = 0
	for i, log in ipairs(logs) do
		local p0 = log.Position
		local spin = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		task.delay(0.15 + i * 0.07, function()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local a = math.min((os.clock() - t0) / 0.5, 1)
				local target = root.Parent and root.Position or p0
				local mid = (p0 + target) / 2 + Vector3.new(0, 7, 0)
				local e = a * a
				local pos = p0:Lerp(mid, e):Lerp(mid:Lerp(target, e), e)
				log.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				log.Size = Vector3.new(2.4, 1.1, 1.1) * (1 - a * 0.6)
				if a >= 1 then
					conn:Disconnect()
					log:Destroy()
					arrived += 1
					if arrived == #logs then
						sound3D(POP_SOUND, target, 0.35, 1.4)
						floatText(target + Vector3.new(0, 3.5, 0), "+" .. Config.FormatNumber(amount) .. " Logs", Color3.fromRGB(240, 195, 125), 34, 4, 1.1)
					end
				end
			end)
		end)
	end
end

local function dust(pos, color, n)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Size = NumberSequence.new(1.5, 4)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Color = ColorSequence.new(color)
	e.Parent = att
	e:Emit(n)
	Debris:AddItem(att, 1.2)
end

Remotes.Shatter.OnClientEvent:Connect(function(pos, partsData, kind, info)
	if not (info and info.Tree) then return end

	-- clone the real tree model locally so it can fall
	local tpl = info.Template and TreeModels:FindFirstChild(info.Template)
	if not tpl or not info.Pivot then return end
	local tree = tpl:Clone()
	local parts = {}
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Hitbox" then
				d:Destroy()
			else
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				table.insert(parts, d)
			end
		end
	end
	if info.Scale and math.abs(info.Scale - 1) > 0.001 then tree:ScaleTo(info.Scale) end
	if info.Mutation then Config.ApplyMutationLook(tree, info.Mutation) end
	local origPivot = info.Pivot
	tree:PivotTo(origPivot)
	tree.Parent = fx
	local _, ext = tree:GetBoundingBox()
	local height = math.max(ext.Y, 3)
	local leafColor = tpl:GetAttribute("LeafColor")

	local away = (info.Base - info.From) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.05 then away = Vector3.new(1, 0, 0) end
	away = away.Unit
	local axis = Vector3.yAxis:Cross(away)
	local base = info.Base

	local duration = math.clamp(0.45 + height * 0.025, 0.5, 1.1)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.min((os.clock() - t0) / duration, 1)
		local ang = (math.pi / 2) * 0.92 * a * a -- accelerate like a real fall
		local rot = CFrame.new(base) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-base)
		tree:PivotTo(rot * origPivot)
		if a < 1 then return end
		conn:Disconnect()

		-- impact
		local impact = base + away * height * 0.6
		sound3D(FALL_SOUND, impact, 0.6, math.clamp(1.3 - height / 40, 0.7, 1.2))
		dust(impact, Color3.fromRGB(190, 170, 140), 12)
		if leafColor then dust(base + away * height * 0.9, leafColor, 10) end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("Pref_ScreenShake") ~= false and not player:GetAttribute("Pref_ReducedMotion") and root and (root.Position - impact).Magnitude < 30 and height > 14 then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				task.spawn(function()
					for i = 1, 3 do
						local k = (4 - i) / 3 -- fades out
						hum.CameraOffset = Vector3.new(math.random(-10, 10) / 200 * k, math.random(-10, 10) / 200 * k, 0)
						task.wait(0.03)
					end
					hum.CameraOffset = Vector3.zero
				end)
			end
		end

		-- split into logs along the fallen trunk
		local n = math.clamp(math.floor(math.log10((info.Logs or 1) + 1) * 2) + 1, 2, 6)
		local logs = {}
		local scale = math.clamp(height / 10, 0.7, 2)
		for i = 1, n do
			local p = base + away * (height * i / (n + 1)) + Vector3.new(0, 0.8 * scale, 0)
			table.insert(logs, makeLog(CFrame.lookAt(p, p + away) * CFrame.Angles(0, math.pi / 2, 0), scale))
		end
		if info.Killer == player.UserId then
			flyLogsToMe(logs, info.Logs or 0)
		else
			for _, l in ipairs(logs) do
				TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { Transparency = 1 }):Play()
				Debris:AddItem(l, 2)
			end
		end

		-- the fallen tree fades and sinks away
		for _, d in ipairs(tree:GetDescendants()) do
			if d:IsA("ParticleEmitter") then d.Enabled = false end
		end
		for _, p in ipairs(parts) do
			TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		Debris:AddItem(tree, 0.6)
	end)
end)
