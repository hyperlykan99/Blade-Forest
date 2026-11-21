-- BladeEffects: draws every player's + NPC's spinning blades, hit flashes,
-- shatter debris, damage numbers and coin popups. All purely visual.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "LocalEffects"
folder.Parent = workspace

local function vpart(size, color, material, transparency)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

--------------------------------------------------------------------
-- Blade models
--------------------------------------------------------------------
local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function addParticles(body, kind, color, allowLight)
	if kind == "Fire" then
		local f = Instance.new("Fire")
		f.Size = 1.1
		f.Heat = 1
		f.Color = Color3.fromRGB(255, 120, 20)
		f.SecondaryColor = Color3.fromRGB(255, 220, 60)
		f.Parent = body
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE_TEX
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.5, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(color)
	if kind == "Void" then
		e.LightEmission = 0.3
		e.Color = ColorSequence.new(Color3.fromRGB(170, 60, 255), Color3.fromRGB(20, 0, 40))
		e.Size = NumberSequence.new(0.8, 0)
	elseif kind == "Frost" then
		e.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
		e.Acceleration = Vector3.new(0, -4, 0)
	elseif kind == "Holy" then
		e.Rate = 18
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 220), Color3.fromRGB(255, 200, 60))
		if not allowLight then e.Parent = body return end -- M2: one light per wielder at most
		local l = Instance.new("PointLight")
		l.Range = 8
		l.Brightness = 1.5
		l.Color = Color3.fromRGB(255, 230, 150)
		l.Parent = body
	end
	e.Parent = body
end

-- Sword meshes live in ReplicatedStorage.BladeModels (one Model per blade Id).
-- Each template's pivot is the blade's centre, LookVector = tip, UpVector = flat face.
local BladeModels = ReplicatedStorage:WaitForChild("BladeModels")

-- M2: rarity VFX tiers (Config weapon.VfxTier: 0 Common .. 7 Divine). Budgets per wielder:
--   blade 1 gets everything, blades 2-3 get particles, the rest only the trail;
--   other players get blade 1 effects only; Pref_Graphics "Low" = trails only.
--   At most ONE PointLight per wielder (template lights are always removed).
local AURA_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local pulsing = {} -- [emitter] = baseRate (Divine pulse, animated below)
local function tierFx(core, b, tier, idx, isLocal, lowGfx)
	if lowGfx then return end
	local full = isLocal and idx <= 3 or (not isLocal and idx == 1)
	if not full then return end
	if tier >= 4 then -- Legendary+: soft glow aura in the accent colour
		local e = Instance.new("ParticleEmitter")
		e.Name = "TierAura"
		e.Texture = AURA_TEX
		e.Rate = tier >= 6 and 10 or 6
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(0.2, 0.6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.4, 1.1 + 0.15 * (tier - 4)), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.35, 1)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Color = Config.RarityById[b.Rarity].Rainbow and Config.RainbowSequence or ColorSequence.new(b.EdgeColor)
		e.Parent = core
		if tier >= 7 then pulsing[e] = e.Rate end
	end
	if tier >= 5 and idx == 1 then -- Mythic+: one light per wielder
		local l = Instance.new("PointLight")
		l.Name = "TierLight"
		l.Range = tier >= 7 and 10 or 7
		l.Brightness = tier >= 7 and 2 or 1.3
		l.Color = b.EdgeColor
		l.Shadows = false
		l.Parent = core
	end
	if tier >= 6 and idx == 1 then -- Secret/Divine: halo motes rising off the blade
		local e = Instance.new("ParticleEmitter")
		e.Name = "TierHalo"
		e.Texture = AURA_TEX
		e.Rate = tier >= 7 and 14 or 8
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(1, 2.5)
		e.Acceleration = Vector3.new(0, 3, 0)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Size = NumberSequence.new(0.45, 0)
		e.LightEmission = 1
		e.Color = tier >= 7 and ColorSequence.new(Color3.fromRGB(255, 245, 200), b.EdgeColor) or Config.RainbowSequence
		e.Parent = core
	end
end

local function makeBlade(bladeType, scale, shiny, idx, isLocal, stage)
	idx = idx or 1
	local lowGfx = player:GetAttribute("Pref_Graphics") == "Low"
	local tier = bladeType.VfxTier or 0
	local b = bladeType
	local len = b.Length * scale
	local template = BladeModels:FindFirstChild(b.Id) or BladeModels:FindFirstChild("Wooden")
	local model = template:Clone()
	model.Name = "Blade"
	model:PivotTo(CFrame.new())
	model:ScaleTo(model:GetScale() * len / (template:GetAttribute("TemplateLength") or 4))
	-- M2: built-in model effects multiply per blade - keep at most 2 emitters on blade 1, no lights
	local kept = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then
			kept += 1
			if idx > 1 or kept > 2 or lowGfx then d:Destroy() end
		end
	end

	-- remember every part's offset from the pivot so we can move them all at once
	local parts, offsets = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, d.CFrame)
		end
	end

	-- invisible core along the blade: carries the swing trail + tier particles
	local core = vpart(Vector3.new(0.3 * scale, 0.3 * scale, len * 0.8), Color3.new(), nil, 1)
	core.Name = "Core"
	core.Parent = model
	table.insert(parts, core)
	table.insert(offsets, CFrame.new())

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, len * 0.15)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -len / 2)
	a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	-- M2: the trail grows with rarity (longer, brighter, more opaque)
	trail.Lifetime = 0.14 + 0.025 * tier
	trail.Color = b.Trail
	trail.Transparency = NumberSequence.new(math.max(0.45 - 0.04 * tier, 0.15), 1)
	trail.LightEmission = tier >= 4 and 1 or 0.8
	trail.WidthScale = NumberSequence.new(1, tier >= 6 and 0.35 or 0)
	trail.Parent = core

	local particlesOk = not lowGfx and ((isLocal and idx <= 3) or (not isLocal and idx == 1))
	if b.Particle and particlesOk then addParticles(core, b.Particle, b.EdgeColor, idx == 1 and tier < 5) end
	tierFx(core, b, tier, idx, isLocal, lowGfx)
	if shiny and not lowGfx then
		-- crafted SHINY weapon: gold glitter + warm glow
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARKLE_TEX
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.6, 0)
		e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90))
		e.Parent = core
		if idx == 1 and tier < 5 then -- M2: Mythic+ already carries the wielder's one light
			local l = Instance.new("PointLight")
			l.Range = 7
			l.Brightness = 1.2
			l.Color = Color3.fromRGB(255, 215, 110)
			l.Parent = core
		end
		if idx > 1 and not isLocal then e:Destroy() end
	end
	local aura
	if stage>0 and idx==1 then
		local spectral=({Color3.fromRGB(142,221,255),Color3.fromRGB(196,159,255),Color3.fromRGB(255,218,146)})[stage]
		trail.Color=ColorSequence.new(spectral,b.EdgeColor or spectral)
		trail.Lifetime+=.04*stage
		if not lowGfx then
			aura=Instance.new("Highlight")
			aura.Name="AwakeningAura"
			aura.Adornee=model aura.DepthMode=Enum.HighlightDepthMode.Occluded
			aura.OutlineColor=spectral aura.FillColor=spectral aura.FillTransparency=.89
			aura.OutlineTransparency=.31 aura.Parent=model
			for ring=1,stage-1 do
				local radius=(1.1+ring*.26)*scale
				local ringPart=vpart(Vector3.new(.055,radius,radius),spectral,Enum.Material.Neon,.45)
				ringPart.Shape=Enum.PartType.Cylinder ringPart.Name="AwakeningRing" ringPart.Parent=model
				table.insert(parts,ringPart)
				table.insert(offsets,CFrame.new(0,0,-len*.22*ring)*CFrame.Angles(0,math.pi/2,0))
			end
		end
	end
	model.Parent = folder
	return { Model = model, Parts = parts, Offsets = offsets, Len = len, Scale = scale, Aura=aura, Stage=stage }
end

local visuals = {} -- [wielder] = { Key = string, List = {...} }

local function setBlades(wielder, stats)
	local stage=stats.Awakening or 0
	local key = stats.Blade.Id .. "_" .. stage .. "_" .. stats.Scale .. (stats.Shiny and "_S" or "") .. "_" .. tostring(player:GetAttribute("Pref_Graphics"))
	local v = visuals[wielder]
	if v and v.Key ~= key then
		for _, b in ipairs(v.List) do b.Model:Destroy() end
		v = nil
	end
	if not v then
		v = { Key = key, List = {} }
		visuals[wielder] = v
	end
	local n = stats and stats.Blades or 0
	while #v.List < n do table.insert(v.List, makeBlade(stats.Blade, stats.Scale, stats.Shiny, #v.List + 1, wielder == player,stage)) end
	while #v.List > n do table.remove(v.List).Model:Destroy() end
	return v.List
end

local function clearBlades(wielder)
	local v = visuals[wielder]
	if v then
		for _, b in ipairs(v.List) do b.Model:Destroy() end
		visuals[wielder] = nil
	end
end

local function drawWielder(wielder, char, now, seen)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then
		clearBlades(wielder)
		return
	end
	if (root.Position - camera.CFrame.Position).Magnitude > 400 then
		clearBlades(wielder)
		return
	end
	seen[wielder] = true
	local stats = Config.GetStats(wielder)
	local blades = Config.GetBlades(root.CFrame, stats, now)
	local list = setBlades(wielder, stats)
	local first=list[1]
	if first and first.Aura and first.Stage==3 then
		first.Aura.FillTransparency=player:GetAttribute("Pref_ReducedMotion") and .86 or .86+math.sin(now*3)*.07
	end
	local movedParts, movedCFrames = {}, {}
	for i, bl in ipairs(blades) do
		local v = list[i]
		-- slight tilt so the flat of the blade catches the light as it sweeps
		local cf = bl.CFrame * CFrame.Angles(0, 0, 0.35 + math.sin(now * 3 + i) * 0.15)
		for j, part in ipairs(v.Parts) do
			table.insert(movedParts, part)
			table.insert(movedCFrames, cf * v.Offsets[j])
		end
	end
	if #movedParts > 0 then
		workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	-- M2: Divine aura breathes (rate pulse); Reduced Motion keeps it steady
	if next(pulsing) then
		local k = player:GetAttribute("Pref_ReducedMotion") and 1 or (1 + 0.6 * math.sin(now * 3))
		for e, base in pairs(pulsing) do
			if e.Parent then e.Rate = base * k else pulsing[e] = nil end
		end
	end
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Loaded") then
			drawWielder(p, p.Character, now, seen)
		end
	end
	for _, npc in ipairs(CollectionService:GetTagged("BladeNPC")) do
		if npc:IsDescendantOf(workspace) then
			drawWielder(npc, npc, now, seen)
		end
	end
	for w in pairs(visuals) do
		if not seen[w] then clearBlades(w) end
	end
end)

--------------------------------------------------------------------
-- Floating text
--------------------------------------------------------------------
local function floatText(pos, text, color, size, rise, life)
	local anchor = vpart(Vector3.one * 0.1, Color3.new(), nil, 1)
	anchor.Position = pos
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size * 4, size)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = bb
	local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = pos + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(life * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, life * 0.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, life)
end

--------------------------------------------------------------------
-- Hits: flash + sparks + damage numbers
--------------------------------------------------------------------
local flashing = {}
local function flash(target)
	if flashing[target] or not target.Parent then return end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = target
	h.Parent = folder
	flashing[target] = h
	task.delay(0.07, function()
		h:Destroy()
		flashing[target] = nil
	end)
end

local function targetColor(target)
	if target:IsA("BasePart") then return target.Color end
	local pp = target:IsA("Model") and target.PrimaryPart
	if pp then return pp.Color end
	local any = target:FindFirstChildWhichIsA("BasePart", true)
	return any and any.Color or Color3.new(1, 1, 1)
end

local function sparks(pos, color, count)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE_TEX
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Size = NumberSequence.new(0.6, 0)
	e.LightEmission = 0.6
	e.Color = ColorSequence.new(color)
	e.Parent = att
	e:Emit(count)
	Debris:AddItem(att, 0.6)
end

Remotes.Hits.OnClientEvent:Connect(function(hits)
	for _, h in ipairs(hits) do
		local pos, dmg, target, weak = h[1], h[2], h[3], h[4]
		local isMe = target == player.Character
		if target then
			flash(target)
			if player:GetAttribute("Pref_Graphics") ~= "Low" then
				sparks(pos, targetColor(target), weak and 2 or 6)
			end
		end
		if player:GetAttribute("Pref_DamageNumbers") == false and not isMe then continue end
		local jitter = Vector3.new(math.random(-8, 8) / 10, 1.2, math.random(-8, 8) / 10)
		local text = "-" .. (dmg < 10 and string.format("%.1f", dmg):gsub("%.0$", "") or Config.FormatNumber(dmg))
		if weak then
			floatText(pos + jitter, text, Color3.fromRGB(150, 150, 160), 18, 2, 0.5)
		else
			floatText(pos + jitter, text, isMe and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 240, 120), isMe and 34 or 26, 3, 0.7)
		end
	end
end)

Remotes.Reward.OnClientEvent:Connect(function(amount, pos)
	if not pos then return end
	floatText(pos + Vector3.new(0, 3, 0), "+" .. Config.FormatNumber(amount) .. " Logs", Color3.fromRGB(240, 190, 120), 40, 5, 1.2)
end)

--------------------------------------------------------------------
-- Shatter: break the object into flying chunks
--------------------------------------------------------------------
local liveDebris = 0
local MAX_DEBRIS = 350

local function spawnChunk(cf, size, color, material, transparency, shape, from)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	p.Shape = shape
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CollisionGroup = "Debris"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	local dir = (cf.Position - from)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	p.AssemblyLinearVelocity = dir * math.random(14, 30) + Vector3.new(0, math.random(18, 34), 0)
	p.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
	liveDebris += 1
	task.delay(1.8 + math.random() * 0.8, function()
		TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1, Size = size * 0.3 }):Play()
		task.wait(0.6)
		p:Destroy()
		liveDebris -= 1
	end)
end

Remotes.Shatter.OnClientEvent:Connect(function(pos, parts, kind, info)
	if info and info.Tree then return end -- trees get the falling animation in ChopEffects
	-- small "poof"
	local first = parts[1]
	if first then sparks(pos, first[3], 18) end

	local budget = math.min(40, MAX_DEBRIS - liveDebris)
	if budget <= 0 then return end
	local perPart = math.max(1, math.floor(budget / math.max(#parts, 1)))

	for _, data in ipairs(parts) do
		local cf, size, color, matName, shapeName, transparency = data[1], data[2], data[3], data[4], data[5], data[6]
		local material = Enum.Material[matName] or Enum.Material.SmoothPlastic
		local isBall = shapeName == "Ball"
		-- split the part into a grid of chunks along its biggest axes
		local nx, ny, nz = 1, 1, 1
		local function biggest()
			local sx, sy, sz = size.X / nx, size.Y / ny, size.Z / nz
			if sx >= sy and sx >= sz then return "x" elseif sy >= sz then return "y" else return "z" end
		end
		while nx * ny * nz * 2 <= math.min(perPart, 8) do
			local axis = biggest()
			local sx, sy, sz = size.X / nx, size.Y / ny, size.Z / nz
			if math.max(sx, sy, sz) < 1.2 then break end
			if axis == "x" then nx *= 2 elseif axis == "y" then ny *= 2 else nz *= 2 end
		end
		local chunk = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
		for ix = 1, nx do
			for iy = 1, ny do
				for iz = 1, nz do
					local offset = Vector3.new(
						(ix - 0.5) * chunk.X - size.X / 2,
						(iy - 0.5) * chunk.Y - size.Y / 2,
						(iz - 0.5) * chunk.Z - size.Z / 2
					)
					local ccf = cf * CFrame.new(offset) * CFrame.Angles(math.random() * 0.4, math.random() * 0.4, math.random() * 0.4)
					local csize = chunk * 0.92
					local shape = Enum.PartType.Block
					if isBall then
						shape = Enum.PartType.Ball
						local m = math.min(chunk.X, chunk.Y, chunk.Z)
						csize = Vector3.one * m
					end
					spawnChunk(ccf, csize, color, material, transparency, shape, pos)
				end
			end
		end
	end

	-- tiny camera kick if it broke near me (gentle; can be turned off in Settings)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("Pref_ScreenShake") ~= false and not player:GetAttribute("Pref_ReducedMotion") and root and (root.Position - pos).Magnitude < 25 then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			task.spawn(function()
				for i = 1, 3 do
					local k = (4 - i) / 3 -- fades out
					hum.CameraOffset = Vector3.new(math.random(-10, 10) / 250 * k, math.random(-10, 10) / 250 * k, 0)
					task.wait(0.03)
				end
				hum.CameraOffset = Vector3.zero
			end)
		end
	end
end)
