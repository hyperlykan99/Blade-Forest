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
-- 1) Strength tags + canopy visibility
--------------------------------------------------------------------
-- P1b.2r camera-visibility fix (client-only).
--   * `reg` is a nearby-tree visibility registry, independent of the tag preference,
--     so canopies keep fading when "Tree Strength Tags" is OFF.
--   * Canopy-aware line-of-sight test: a tree "blocks" when its canopy cylinder crosses
--     the camera->head or camera->hip segment (strong fade). Near misses get the old mild
--     fade; every other tree stays fully opaque. Up-fades are quick; un-fades wait briefly
--     (hysteresis), then ease out. LocalTransparencyModifier is only written on real changes.
--   * Labels (StrengthTag BillboardGuis) are created once per nearby tree and shown/hidden
--     with .Enabled by a priority pass: tier 1 (Legendary+ or mutated) is uncapped, tiers 2-3
--     share a cap (16 compact / 24 otherwise). Labels covering the character are hidden.
local GREEN = Color3.fromRGB(110, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)
local tags = {}
local reg = {}
local lastStruck = setmetatable({}, { __mode = "k" })

local function updateTag(tree)
	local t = tags[tree]
	if not t then return end
	local s = tree:GetAttribute("Strength") or 0
	local ok = myPower() >= s
	t.Locked = not ok
	t.Label.Text = (ok and "⚡ " or "🔒 ") .. Config.FormatNumber(s)
	t.Label.TextColor3 = ok and GREEN or RED
	t.Stroke.Color = ok and GREEN or RED
end

local function tierOf(tree)
	local rdef = Config.RarityById[tree:GetAttribute("Rarity") or "Common"]
	local mut = Config.MutationById[tree:GetAttribute("Mutation") or ""]
	local order = rdef and rdef.Order or 1
	if mut or order >= 5 then return 1 end -- Legendary, Mythic, Secret, Divine, any mutation
	if order >= 3 then return 2 end -- Rare, Epic
	return 3 -- Common, Uncommon
end
local TIER_CREATE = { 90, 52, 48 } -- create a tag inside this distance...
local TIER_DROP = 12 -- ...and drop it beyond create + this (hysteresis)

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
	bb.Enabled = false -- the label pass decides
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
	tags[tree] = { Gui = bb, Label = label, Stroke = st, Tier = tierOf(tree), Shown = false }
	updateTag(tree)
end

local function removeTag(tree)
	local t = tags[tree]
	if not t then return end
	t.Gui:Destroy()
	tags[tree] = nil
end

-- Visibility registry ----------------------------------------------
local REG_IN, REG_OUT = 90, 110
local FADE_BLOCK, FADE_NEAR = 0.9, 0.72

local function setFade(e, v)
	if math.abs(v - e.Applied) < 0.02 and not (v == 0 and e.Applied ~= 0) then return end
	e.Applied = v
	for _, p in ipairs(e.Leaves) do
		if p.Parent then p.LocalTransparencyModifier = v end
	end
end

-- leaves + canopy cylinder (radius around the trunk axis, vertical span), cached per tree
local function measure(tree, e)
	local piv = tree:GetPivot().Position
	local leaves, r, lo, hi = {}, 0, math.huge, -math.huge
	for _, d in ipairs(tree:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Hitbox" then
			table.insert(leaves, d)
			local cf, sz = d.CFrame, d.Size
			local hx = math.abs(cf.RightVector.X) * sz.X / 2 + math.abs(cf.UpVector.X) * sz.Y / 2 + math.abs(cf.LookVector.X) * sz.Z / 2
			local hy = math.abs(cf.RightVector.Y) * sz.X / 2 + math.abs(cf.UpVector.Y) * sz.Y / 2 + math.abs(cf.LookVector.Y) * sz.Z / 2
			local hz = math.abs(cf.RightVector.Z) * sz.X / 2 + math.abs(cf.UpVector.Z) * sz.Y / 2 + math.abs(cf.LookVector.Z) * sz.Z / 2
			local dxz = Vector2.new(cf.X - piv.X, cf.Z - piv.Z).Magnitude
			r = math.max(r, dxz + math.max(hx, hz))
			lo = math.min(lo, cf.Y - hy)
			hi = math.max(hi, cf.Y + hy)
		end
	end
	if e.Leaves then
		-- release parts that are no longer part of the tree
		local keep = {}
		for _, p in ipairs(leaves) do keep[p] = true end
		for _, p in ipairs(e.Leaves) do if not keep[p] and p.Parent then p.LocalTransparencyModifier = 0 end end
	end
	e.Leaves, e.R, e.Lo, e.Hi = leaves, r, lo, hi
	e.X, e.Z = piv.X, piv.Z
	e.Scale = tree:GetScale()
	e.PP = tree.PrimaryPart
	if e.Applied and e.Applied > 0 then
		for _, p in ipairs(leaves) do p.LocalTransparencyModifier = e.Applied end
	end
end

local function unregister(tree)
	local e = reg[tree]
	if not e then return end
	reg[tree] = nil
	if e.Conn then e.Conn:Disconnect() end
	for _, p in ipairs(e.Leaves or {}) do
		if p.Parent then p.LocalTransparencyModifier = 0 end
	end
	removeTag(tree)
end

local function register(tree)
	if reg[tree] then return end
	local e = { Applied = 0, Target = 0, ClearAt = 0 }
	reg[tree] = e
	measure(tree, e)
	e.Conn = tree.AncestryChanged:Connect(function()
		if not tree:IsDescendantOf(workspace) then unregister(tree) end
	end)
end

-- Tags and the registry only exist near you (thousands of trees!).
task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pos = root and root.Position or camera.CFrame.Position
		local tagsOn = player:GetAttribute("Pref_ShowTags") ~= false
		local made = 0
		for _, t in ipairs(Breakables:GetChildren()) do
			local pp = t.PrimaryPart
			local e = reg[t]
			if not pp then
				if e then unregister(t) end -- streamed out
			elseif t:GetAttribute("IsTree") then
				local d = (pp.Position - pos).Magnitude
				if not e then
					if d < REG_IN then
						register(t)
						made += 1
						if made % 40 == 0 then task.wait() end
					end
				elseif d > REG_OUT then
					unregister(t)
				else
					if e.PP ~= pp or math.abs(t:GetScale() - e.Scale) > 0.01 then
						measure(t, e) -- re-streamed or still growing in after a respawn
						local tag = tags[t]
						if tag then
							tag.Gui.Adornee = pp
							tag.Gui.StudsOffsetWorldSpace = Vector3.new(0, -pp.Size.Y / 2 + 4.6, 0)
						end
					end
					local tag = tags[t]
					if not tagsOn then
						if tag then removeTag(t) end
					elseif not tag then
						if d < TIER_CREATE[tierOf(t)] then makeTag(t) end
					elseif d > TIER_CREATE[tag.Tier] + TIER_DROP then
						removeTag(t)
					end
				end
			end
		end
		task.wait(0.4)
	end
end)

-- Canopy fade (~11 Hz) ----------------------------------------------
-- distance from 2-D point p to 2-D segment a-b, plus the segment parameter t
local function segDist2D(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local len2 = abx * abx + abz * abz
	local t = 0
	if len2 > 1e-4 then t = math.clamp(((px - ax) * abx + (pz - az) * abz) / len2, 0, 1) end
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2), t
end

-- how strongly a canopy cylinder obstructs segment cam->target: 2 = blocks, 1 = near miss, 0 = clear
local NEAR_BAND = 3.5
local function obstruction(e, cam, target)
	local d, t = segDist2D(e.X, e.Z, cam.X, cam.Z, target.X, target.Z)
	if d > e.R + NEAR_BAND then return 0 end
	local y = cam.Y + (target.Y - cam.Y) * t
	if y < e.Lo - 0.5 or y > e.Hi + 0.5 then return 0 end
	return d <= e.R + 0.75 and 2 or 1
end

local FADE_HOLD = 0.35 -- seconds a tree must stay clear before un-fading
local STEP_UP, STEP_DOWN = 0.45, 0.25
local fadeCostAcc, fadeTicks, fadedNow = 0, 0, 0
local lastFade = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastFade < 0.09 then return end
	lastFade = now
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local t0 = os.clock()
	local cam = camera.CFrame.Position
	local head = char:FindFirstChild("Head")
	local headPos = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local hipPos = root.Position - Vector3.new(0, 1, 0)
	local faded = 0
	for tree, e in pairs(reg) do
		if e.R then
			local o = math.max(obstruction(e, cam, headPos), obstruction(e, cam, hipPos))
			local want = o == 2 and FADE_BLOCK or (o == 1 and FADE_NEAR or 0)
			if want >= e.Target then
				e.Target = want
				e.ClearAt = now
			elseif now - e.ClearAt >= FADE_HOLD then
				e.Target = want
			end
			local v = e.Applied
			if v < e.Target then v = math.min(e.Target, v + STEP_UP)
			elseif v > e.Target then v = math.max(e.Target, v - STEP_DOWN) end
			if v ~= e.Applied then setFade(e, v) end
			if e.Applied > 0 then faded += 1 end
		end
	end
	fadedNow = faded
	fadeCostAcc += os.clock() - t0
	fadeTicks += 1
end)

-- Label priority (~3.3 Hz) -------------------------------------------
local UIS = game:GetService("UserInputService")
local function isCompact()
	local size = camera.ViewportSize
	return size.Y < 560 or size.X < 780 or (UIS.TouchEnabled and not UIS.KeyboardEnabled)
end
local STRUCK_HOLD = 3

-- screen rectangle covered by the character (for hiding labels drawn over it)
local function charRect(char, root)
	local minX, minY, maxX, maxY, depth = math.huge, math.huge, -math.huge, -math.huge, math.huge
	local right = camera.CFrame.RightVector
	for _, off in ipairs({ Vector3.new(0, 2.6, 0), Vector3.new(0, -3, 0) }) do
		for _, s in ipairs({ -1.3, 1.3 }) do
			local p, on = camera:WorldToViewportPoint(root.Position + off + right * s)
			if p.Z > 0 then
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
				depth = math.min(depth, p.Z)
			end
		end
	end
	if minX == math.huge then return nil end
	return minX - 8, minY - 8, maxX + 8, maxY + 8, depth
end

local labelStats = { tier1 = 0, ordinary = 0, hiddenOverChar = 0, cap = 24 }
task.spawn(function()
	while true do
		task.wait(0.3)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local now = os.clock()
			local pos = root.Position
			local cap = isCompact() and 16 or 24
			local rx0, ry0, rx1, ry1, rdepth = charRect(char, root)
			local ordinary, show = {}, {}
			local hidden, t1 = 0, 0
			for tree, t in pairs(tags) do
				local pp = tree.PrimaryPart
				if pp then
					local d = (pp.Position - pos).Magnitude
					local slack = t.Shown and 4 or 0
					local struck = lastStruck[tree] and now - lastStruck[tree] < STRUCK_HOLD
					local eligible
					if t.Tier == 1 then
						eligible = d <= 90 + slack
					elseif t.Tier == 2 then
						eligible = d <= 48 + slack
					else
						eligible = d <= 24 + slack or ((t.Locked or struck) and d <= 48 + slack)
					end
					if eligible then
						-- hide a label that sits on top of the character (in front of it, overlapping)
						local over = false
						if rx0 then
							local w = t.Gui.Size.X.Offset / 2
							local h = t.Gui.Size.Y.Offset / 2
							local sp = camera:WorldToViewportPoint(pp.Position + t.Gui.StudsOffsetWorldSpace)
							if sp.Z > 0 and sp.Z < rdepth + 1 and sp.X + w > rx0 and sp.X - w < rx1 and sp.Y + h > ry0 and sp.Y - h < ry1 then
								over = true
							end
						end
						if over then
							hidden += 1
						elseif t.Tier == 1 then
							show[tree] = true
							t1 += 1
						else
							-- tier 2 before tier 3; locked/struck tier 3 before plain tier 3; nearer first; keep shown ones
							local rank = (t.Tier == 2 and 0 or ((t.Locked or struck) and 1000 or 2000)) + d - slack
							table.insert(ordinary, { tree, rank })
						end
					end
				end
			end
			table.sort(ordinary, function(a, b) return a[2] < b[2] end)
			for i = 1, math.min(cap, #ordinary) do show[ordinary[i][1]] = true end
			for tree, t in pairs(tags) do
				local on = show[tree] == true
				if t.Shown ~= on then
					t.Shown = on
					t.Gui.Enabled = on
				end
			end
			labelStats.tier1 = t1
			labelStats.ordinary = math.min(cap, #ordinary)
			labelStats.hiddenOverChar = hidden
			labelStats.cap = cap
		end
	end
end)

-- lightweight diagnostics for testing (attributes on this LocalScript; no gameplay effect)
task.spawn(function()
	while true do
		task.wait(2)
		local n, nt = 0, 0
		for _ in pairs(reg) do n += 1 end
		for _ in pairs(tags) do nt += 1 end
		script:SetAttribute("VisRegistry", n)
		script:SetAttribute("VisTags", nt)
		script:SetAttribute("VisFaded", fadedNow)
		script:SetAttribute("VisLabelsTier1", labelStats.tier1)
		script:SetAttribute("VisLabelsOrdinary", labelStats.ordinary)
		script:SetAttribute("VisLabelsHiddenOverChar", labelStats.hiddenOverChar)
		script:SetAttribute("VisLabelCap", labelStats.cap)
		script:SetAttribute("VisFadeMsPerTick", fadeTicks > 0 and fadeCostAcc / fadeTicks * 1000 or 0)
		fadeCostAcc, fadeTicks = 0, 0
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
				lastStruck[target] = os.clock()
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
