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

local function addParticles(body, kind, color)
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

local function makeBlade(bladeType, scale, shiny)
	local b = bladeType
	local len = b.Length * scale
	local template = BladeModels:FindFirstChild(b.Id) or BladeModels:FindFirstChild("Wooden")
	local model = template:Clone()
	model.Name = "Blade"
	model:PivotTo(CFrame.new())
	model:ScaleTo(model:GetScale() * len / (template:GetAttribute("TemplateLength") or 4))

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
	trail.Lifetime = 0.16
	trail.Color = b.Trail
	trail.Transparency = NumberSequence.new(0.45, 1)
	trail.LightEmission = 0.8
	trail.Parent = core

	if b.Particle then addParticles(core, b.Particle, b.EdgeColor) end
	if shiny then
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
		local l = Instance.new("PointLight")
		l.Range = 7
		l.Brightness = 1.2
		l.Color = Color3.fromRGB(255, 215, 110)
		l.Parent = core
	end
	model.Parent = folder
	return { Model = model, Parts = parts, Offsets = offsets, Len = len, Scale = scale }
end

local visuals = {} -- [wielder] = { Key = string, List = {...} }

local function setBlades(wielder, stats)
	local key = stats.Blade.Id .. "_" .. stats.Scale .. (stats.Shiny and "_S" or "")
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
	while #v.List < n do table.insert(v.List, makeBlade(stats.Blade, stats.Scale, stats.Shiny)) end
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
