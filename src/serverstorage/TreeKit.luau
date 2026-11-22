-- TreeKit: builds choppable trees from the Creator Store templates in
-- ReplicatedStorage.TreeModels (each template's pivot = trunk base on the ground,
-- PrimaryPart = invisible Hitbox, the only part blades/players touch).
-- Used at runtime by CombatServer (respawns) and at edit time by the forest spawner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Models = ReplicatedStorage:WaitForChild("TreeModels")

local K = {}
local rng = Random.new()
local variants = {}

local function getVariants(typeId)
	local list = variants[typeId]
	if not list then
		list = {}
		for _, m in ipairs(Models:GetChildren()) do
			if m:GetAttribute("TreeType") == typeId then table.insert(list, m) end
		end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		variants[typeId] = list
	end
	return list
end

-- groundCF: where the trunk meets the ground (any Y rotation)
-- add / change a mutation on an already built tree (also used at edit time)
function K.Mutate(m, mutId)
	local mut = Config.MutationById[mutId]
	local tt = Config.TreeTypes[m:GetAttribute("TreeType") or ""]
	if not mut or not tt then return end
	Config.ApplyMutationLook(m, mutId)
	m:SetAttribute("Mutation", mutId)
	local polished=workspace:GetAttribute("BladeForestArt")=="v1"
	if polished then m:AddTag("ForestMutation") end
	m:SetAttribute("Health", math.floor(tt.Health * mut.HealthMult))
	m:SetAttribute("MaxHealth", math.floor(tt.Health * mut.HealthMult))
	m:SetAttribute("Reward", math.floor(tt.Logs * mut.LogMult))
	m:SetAttribute("TreeName", mut.Name .. " " .. tt.Name)
	local pp = m.PrimaryPart
	if not polished and pp and not pp:FindFirstChild("MutationFX") then
		local _, ext = m:GetBoundingBox()
		local att = Instance.new("Attachment")
		att.Name = "MutationFX"
		att.Position = Vector3.new(0, ext.Y * 0.55 - pp.Size.Y / 2, 0)
		att.Parent = pp
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 6 + mut.Order * 3
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.7, 0)
		e.LightEmission = mut.Id == "Shadow" and 0.2 or 1
		e.Color = mut.Rainbow and Config.RainbowSequence or ColorSequence.new(mut.Id == "Shadow" and Color3.fromRGB(170, 80, 255) or mut.Color)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = att
		if mut.Order >= 2 then
			local l = Instance.new("PointLight")
			l.Color = mut.Id == "Shadow" and Color3.fromRGB(150, 60, 255) or mut.Color
			l.Range = 14
			l.Brightness = 1
			l.Parent = att
		end
	end
end

function K.Build(typeId, groundCF, scale, noMutation)
	local tt = Config.TreeTypes[typeId]
	assert(tt, "unknown tree type " .. tostring(typeId))
	local list = getVariants(typeId)
	assert(#list > 0, "no TreeModels for " .. typeId)
	local tpl = list[rng:NextInteger(1, #list)]
	local m = tpl:Clone()
	m.Name = typeId
	local s = scale or rng:NextNumber(0.85, 1.15)
	-- ScaleTo is absolute (vs the original store asset), templates are already resized
	if math.abs(s - 1) > 0.001 then m:ScaleTo(tpl:GetScale() * s) end
	m:PivotTo(groundCF)
	m:SetAttribute("IsTree", true)
	m:SetAttribute("Kind", typeId)
	m:SetAttribute("TreeType", typeId)
	m:SetAttribute("Rarity", tt.Rarity)
	m:SetAttribute("TreeName", tt.Name)
	m:SetAttribute("Strength", tt.Strength)
	m:SetAttribute("Health", tt.Health)
	m:SetAttribute("MaxHealth", tt.Health)
	m:SetAttribute("Reward", tt.Logs)
	m:SetAttribute("Respawn", tt.Respawn)
	m:SetAttribute("Area", tt.Area)
	m:SetAttribute("Template", tpl.Name)
	-- Mythic / Secret trees glow + sparkle so players can spot them from afar
	if (tt.Rarity == "Mythic" or tt.Rarity == "Secret") and m.PrimaryPart then
		local r = Config.RarityById[tt.Rarity]
		local color = tt.Rarity == "Secret" and Color3.fromRGB(255, 245, 200) or r.Color
		local _, ext = m:GetBoundingBox()
		local att = Instance.new("Attachment")
		att.Name = "RareFX"
		att.Position = Vector3.new(0, ext.Y * 0.6 - m.PrimaryPart.Size.Y / 2, 0)
		att.Parent = m.PrimaryPart
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = tt.Rarity == "Secret" and 14 or 8
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.9, 0)
		e.LightEmission = 1
		e.Color = tt.Rarity == "Secret" and Config.RainbowSequence or ColorSequence.new(color)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = att
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 18
		l.Brightness = 1.2
		l.Parent = att
	end
	if not noMutation then
		local mut = Config.RollMutation(rng)
		if mut then K.Mutate(m, mut.Id) end
	end
	return m
end

-- random tree for an area (rarity rolled by weight)
function K.BuildRandom(areaId, groundCF, scale, rngOverride)
	return K.Build(Config.PickTreeType(areaId, rngOverride or rng).Id, groundCF, scale)
end

return K
