-- Original M3 pet geometry. No imported assets or scripts.
local Factory = {}
local gold = Color3.fromRGB(244, 171, 52)
local dark = Color3.fromRGB(27, 32, 51)

local function part(model, name, size, position, color, shape, angles, glow)
	local p = shape == "wedge" and Instance.new("WedgePart") or Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(table.unpack(size))
	p.CFrame = CFrame.new(Vector3.new(table.unpack(position)))
		* (angles and CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3])) or CFrame.identity)
	if shape == "ball" then p.Shape = Enum.PartType.Ball end
	p.Color = color
	p.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Legs, ears, wings and tails vary in silhouette as well as palette.
local silhouettes = {
	hare = { limb = "hop", crown = "long", tail = "puff" },
	tortoise = { limb = "crawl", crown = "shell", tail = "puff", wide = 1.32 },
	mantis = { limb = "pincer", crown = "feelers", tail = "blade", wide = 0.80 },
	bat = { limb = "wings", crown = "long", tail = "blade", wide = 0.78 },
	ram = { limb = "walk", crown = "horns", tail = "puff", wide = 1.2 },
	stag = { limb = "tall", crown = "antlers", tail = "puff" },
	wyvern = { limb = "wings", crown = "horns", tail = "long" },
	pika = { limb = "hop", crown = "round", tail = "puff", wide = 1.14 },
	seal = { limb = "flippers", crown = "none", tail = "fan", wide = 1.27 },
	wolf = { limb = "walk", crown = "point", tail = "long" },
	mammoth = { limb = "walk", crown = "round", tail = "trunk", wide = 1.43 },
	ray = { limb = "fins", crown = "none", tail = "long", wide = 1.18 },
	phoenix = { limb = "wings", crown = "crest", tail = "fan" },
	lindwyrm = { limb = "crawl", crown = "crest", tail = "long", wide = 0.84 },
}

function Factory.Create(pet)
	local style = assert(silhouettes[pet.Shape])
	local model = Instance.new("Model")
	model.Name = pet.Id
	model:SetAttribute("Origin", "Blade Forest original Studio geometry")
	model:SetAttribute("Island", pet.Island)
	local body, accent = pet.Body, pet.Accent
	local wide = style.wide or 1
	local flying = style.limb == "wings" or style.limb == "fins"
	part(model, "Body", {wide, flying and 0.48 or 0.83, 1.25}, {0, 0.60, 0.12}, body, "ball")
	part(model, "Head", {0.67, 0.65, 0.62}, {0, 0.82, -0.51}, body, "ball")
	part(model, "Face", {0.42, 0.24, 0.34}, {0, 0.72, -0.78}, accent, "ball")
	for _, side in ipairs({-1, 1}) do
		part(model, "Eye", {0.10, 0.12, 0.08}, {side * 0.22, 0.90, -0.78}, dark, "ball")
		local crown = style.crown
		local rotation = {0, 0, -18 * side}
		if crown == "long" or crown == "point" or crown == "round" then
			local h = crown == "long" and 0.73 or crown == "point" and 0.39 or 0.30
			part(model, "Ear", {0.22, h, 0.23}, {side * 0.24, 1.10 + h / 3, -0.47}, accent,
				crown == "point" and "wedge" or "ball", rotation)
		elseif crown == "horns" or crown == "antlers" or crown == "feelers" then
			local h = crown == "antlers" and 0.57 or 0.38
			part(model, "Horn", {0.14, h, 0.15}, {side * 0.29, 1.25, -0.48}, accent, "ball", rotation)
			part(model, "Horn tip", {0.12, h * 0.65, 0.15}, {side * 0.40, 1.40, -0.51}, accent, "ball", {0, 0, -40 * side})
		elseif crown == "shell" then
			part(model, "Shell crystal", {0.34, 0.62, 0.44}, {side * 0.28, 0.95, 0.18}, accent, "wedge", rotation)
		elseif crown == "crest" then
			part(model, "Crest", {0.19, 0.44, 0.43}, {side * 0.18, 1.23, -0.38}, accent, "wedge", rotation)
		end
		local limb = style.limb
		if flying or limb == "flippers" or limb == "pincer" then
			local span = limb == "wings" and 0.97 or limb == "fins" and 0.82 or 0.45
			part(model, "Fin", {span, 0.18, limb == "pincer" and 0.40 or 0.68},
				{side * (wide / 2 + span * 0.24), flying and 0.64 or 0.33, 0.13}, accent, "wedge", {0, -25 * side, 14 * side})
		else
			for _, z in ipairs({-0.3, 0.49}) do
				part(model, "Paw", {0.28, limb == "tall" and 0.57 or 0.35, limb == "hop" and 0.42 or 0.31},
					{side * wide * 0.33, 0.29, z}, body, "ball")
			end
		end
	end
	if style.tail == "trunk" then
		part(model, "Trunk", {0.26, 0.54, 0.20}, {0, 0.52, -0.87}, body, "ball", {18, 0, 0})
		part(model, "Tusks", {0.58, 0.12, 0.19}, {0, 0.57, -0.84}, accent, "ball")
	elseif style.tail == "fan" then
		part(model, "Tail fan", {0.68, 0.18, 0.58}, {0, 0.58, 0.89}, accent, "wedge", {-18, 180, 0})
	else
		local span = style.tail == "long" and 0.72 or 0.34
		part(model, "Tail", {0.22, 0.27, span}, {0, 0.70, 0.65 + span / 3}, accent,
			style.tail == "blade" and "wedge" or "ball", {-25, 0, 0})
	end
	return model
end

function Factory.Evolve(template, variant)
	-- Only clone curated templates. The existing seven were verified script-free.
	for _, item in ipairs(template:GetDescendants()) do
		assert(not item:IsA("LuaSourceContainer"), "Unexpected source in pet template")
	end
	local model = template:Clone()
	model.Name = variant.Id
	model:SetAttribute("Evolution", variant.Stage)
	model:SetAttribute("BasePet", variant.BaseId)
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local center = pivot:PointToObjectSpace(box.Position)
	local rainbow = variant.Stage == "Rainbow"
	local n = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			n += 1
			local tint = rainbow and Color3.fromHSV((n * 0.17) % 1, 0.63, 1) or gold
			p.Color = p.Color:Lerp(tint, 0.53)
			if p:IsA("MeshPart") then p.TextureID = "" end
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			if mesh then mesh.TextureId = "" end
			p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
			p.Anchored = true
		elseif p:IsA("SurfaceAppearance") or p:IsA("Texture") or p:IsA("Decal") then
			p:Destroy()
		end
	end
	for i = 1, rainbow and 3 or 1 do
		local offset = center + Vector3.new((i - (rainbow and 2 or 1)) * size.X * 0.25, size.Y * 0.61, 0)
		local tint = rainbow and Color3.fromHSV(0.46 + i * 0.15, 0.64, 1) or gold
		local gem = part(model, "Evolution sigil", {0.15, 0.15, 0.15}, {0, 0, 0}, tint, nil, nil, true)
		gem.CFrame = pivot * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(45))
	end
	return model
end

function Factory.Populate(folder, config)
	for _, pet in ipairs(config.Pets) do
		local template = folder:FindFirstChild(pet.Id)
		if not template and pet.Shape then
			template = Factory.Create(pet)
			template.Parent = folder
		end
		assert(template, "Missing pet template " .. pet.Id)
		for _, suffix in ipairs({ "_G", "_R" }) do
			local id = pet.Id .. suffix
			if not folder:FindFirstChild(id) then
				Factory.Evolve(template, config.PetById[id]).Parent = folder
			end
		end
	end
end

return Factory
