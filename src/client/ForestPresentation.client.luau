local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local CollectionService=game:GetService("CollectionService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local FX=require(script.Parent:WaitForChild("ForestEffects"))
local player=Players.LocalPlayer
if not FX.Enabled() then return end

local V=Vector3.new
local R=Color3.fromRGB
local CF=CFrame.new
local palette={
	TimberHaven={16.7,R(153,137,107),R(161,143,123),R(255,235,199),R(225,209,175),R(135,151,116),.19,.72,.23,.075,-.045},
	CrystalWilds={16.1,R(119,124,158),R(121,154,181),R(225,239,255),R(153,184,209),R(108,100,166),.17,.62,.09,.065,-.10},
	FrostboundReach={17.86,R(120,148,179),R(126,153,184),R(226,241,255),R(185,213,239),R(106,119,179),.22,.85,.10,.08,-.10},
}
-- Claude issue #1: Timber Haven golden-hour grade (warm key light, cool shadow fill, gentle haze).
local haven=workspace:GetAttribute("BladeHavenMakeover")~=nil
if haven then
	palette.TimberHaven={16.85,R(96,104,132),R(140,132,146),R(255,236,206),R(236,212,178),R(132,146,120),.26,.62,.34,.14,.0}
end
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere=Instance.new("Atmosphere")
	atmosphere.Name="Forest horizon"
	atmosphere.Parent=Lighting
end
local tone=Instance.new("ColorCorrectionEffect")
tone.Name="Forest color grade" tone.Parent=Lighting
local rays=Instance.new("SunRaysEffect")
rays.Name="Haven golden hour" rays.Spread=.68 rays.Intensity=.075 rays.Parent=Lighting
local bloom=Instance.new("BloomEffect")
bloom.Name="Forest highlights" bloom.Intensity=.12 bloom.Size=20 bloom.Threshold=1.72 bloom.Parent=Lighting
local transitions={}
local function grade(object,values)
	if transitions[object] then transitions[object]:Cancel() end
	if FX.Reduced() then
		for key,value in pairs(values) do object[key]=value end
	else
		local tween=TweenService:Create(object,TweenInfo.new(.8,Enum.EasingStyle.Sine),values)
		transitions[object]=tween tween:Play()
	end
end

local group=Instance.new("Folder")
group.Name="Forest local scenery"
group.Parent=workspace

local function marker(name,position)
	local part=Instance.new("Part")
	part.Name=name part.Size=V(.05,.05,.05) part.Transparency=1
	part.Position=position part.Anchored=true
	part.CanCollide=false part.CanQuery=false part.CanTouch=false part.CastShadow=false
	part.Parent=group
	return part
end

local snowfall=marker("Near-camera flurries",Vector3.zero)
snowfall.Size=V(31,.05,27)
local e=Instance.new("ParticleEmitter")
e.Name="Alpine powder"
e.Texture="rbxasset://textures/particles/sparkles_main.dds"
e.Rate=0 e.Enabled=false
e.Lifetime=NumberRange.new(1.4,2.1) e.Speed=NumberRange.new(3,5)
e.EmissionDirection=Enum.NormalId.Bottom e.Acceleration=V(1,-2,.5)
e.SpreadAngle=Vector2.new(27,22)
e.Size=NumberSequence.new(.13,.03)
e.Shape=Enum.ParticleEmitterShape.Box e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
e.Transparency=NumberSequence.new(.15,1) e.Color=ColorSequence.new(R(209,234,255))
e.Parent=snowfall

local ribbons={}
local function makeAurora()
	-- Two long ribbons sit behind the walkable horizon and need no emitter or light.
	for i=1,2 do
		local a=marker("Aurora west",V(5672+i*55,67+i*9,-338-i*21))
		local b=marker("Aurora east",V(6510-i*40,86+i*12,-359-i*20))
		local from=Instance.new("Attachment") from.Parent=a
		local to=Instance.new("Attachment") to.Parent=b
		from.CFrame=CFrame.Angles(0,.16+i*.16,.35+i*.08)
		to.CFrame=CFrame.Angles(0,-.25,-.31)
		local beam=Instance.new("Beam")
		beam.Attachment0=from beam.Attachment1=to
		beam.FaceCamera=true beam.Segments=19
		beam.Width0=8+i*5 beam.Width1=17+i*5
		beam.CurveSize0=72 beam.CurveSize1=-95
		beam.LightEmission=.63 beam.LightInfluence=0
		beam.Color=ColorSequence.new(i==1 and R(73,211,163) or R(144,129,241),R(90,177,229))
		beam.Transparency=NumberSequence.new({
			NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.21,.52),
			NumberSequenceKeypoint.new(.68,.43),NumberSequenceKeypoint.new(1,1),
		})
		beam.Parent=a
		table.insert(ribbons,beam)
	end
end

local function winterStorm()
	return player:GetAttribute("CurrentIsland")=="FrostboundReach"
		and not player:GetAttribute("M5Run")
		and workspace:GetAttribute("M5EventId")=="Blizzard"
		and workspace:GetAttribute("M5EventIsland")=="FrostboundReach"
		and (workspace:GetAttribute("M5EventEnd") or 0)>workspace:GetServerTimeNow()
end

local function refresh()
	local island=player:GetAttribute("CurrentIsland")
	local p=palette[island] or palette.TimberHaven
	local q=FX.Quality()
	local frosty=island=="FrostboundReach"
	local storm=winterStorm()
	local inHeart=player:GetAttribute("M5Run")=="Heart"
	Lighting.ClockTime=p[1]
	local havenHere=haven and island=="TimberHaven"
	grade(Lighting,{Ambient=p[2],OutdoorAmbient=p[3],Brightness=frosty and 2.1 or havenHere and 2.75 or 2.45,ExposureCompensation=frosty and -.06 or havenHere and -.03 or .05})
	if havenHere then Lighting.ShadowSoftness=.18 Lighting.EnvironmentDiffuseScale=.55 Lighting.EnvironmentSpecularScale=.4 end
	rays.Intensity=havenHere and .11 or .075
	grade(tone,{TintColor=inHeart and R(222,225,255) or p[4],Contrast=p[10],Saturation=p[11]-(storm and .06 or 0)})
	grade(atmosphere,{Color=p[5],Decay=p[6],Density=p[7]+(storm and .08 or 0),Haze=p[8]+(storm and .5 or 0),Glare=q==3 and p[9] or 0,Offset=.10})
	rays.Enabled=island=="TimberHaven" and q==3 and not FX.Reduced()
	bloom.Enabled=q==3 and not FX.Reduced()
	if frosty and q>1 and #ribbons==0 then makeAurora() end
	for _,beam in ipairs(ribbons) do beam.Enabled=frosty and q>1 and not inHeart end
	e.Enabled=frosty and q>1 and not FX.Reduced() and not inHeart and not storm
	e.Rate=e.Enabled and (q==3 and 9 or 4) or 0
end
for _,attr in ipairs({"CurrentIsland","M5Run","Pref_Graphics","Pref_ReducedMotion"}) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
for _,attr in ipairs({"M5EventId","M5EventEnd","M5EventIsland"}) do
	workspace:GetAttributeChangedSignal(attr):Connect(refresh)
end

local mutations={}
local bosses={}
local function connectTag(name,registry)
	for _,obj in ipairs(CollectionService:GetTagged(name)) do registry[obj]={} end
	CollectionService:GetInstanceAddedSignal(name):Connect(function(obj) registry[obj]={} end)
	CollectionService:GetInstanceRemovedSignal(name):Connect(function(obj) registry[obj]=nil end)
end
connectTag("ForestMutation",mutations)
connectTag("ForestBoss",bosses)

local title=Instance.new("ScreenGui")
title.Name="ForestEncounterCue" title.ResetOnSpawn=false title.DisplayOrder=10
title.Enabled=false title.Parent=player:WaitForChild("PlayerGui")
local card=Instance.new("Frame")
card.AnchorPoint=Vector2.new(1,1) card.Position=UDim2.fromScale(.98,.82)
card.Size=UDim2.new(.57,0,0,54)
card.BackgroundColor3=R(22,28,34) card.BackgroundTransparency=.17 card.BorderSizePixel=0
card.Parent=title
local max=Instance.new("UISizeConstraint") max.MaxSize=Vector2.new(300,54) max.Parent=card
local outline=Instance.new("UIStroke") outline.Thickness=1.2 outline.Parent=card
local round=Instance.new("UICorner") round.CornerRadius=UDim.new(0,6) round.Parent=card
local main=Instance.new("TextLabel")
main.TextColor3=R(248,241,227) main.TextSize=20 main.Font=Enum.Font.GothamBold
main.Size=UDim2.fromScale(1,.56) main.BackgroundTransparency=1 main.Parent=card
local detail=Instance.new("TextLabel")
detail.TextColor3=R(210,220,223) detail.TextSize=13 detail.Font=Enum.Font.GothamMedium
detail.Size=UDim2.fromScale(1,.40) detail.Position=UDim2.fromScale(0,.56)
detail.BackgroundTransparency=1 detail.Parent=card

local function banner(preset,subtitle)
	main.Text=preset[2] detail.Text=subtitle
	outline.Color=preset[1]
	title:SetAttribute("Until",os.clock()+2)
	title.Enabled=true
end

local lastIsland=player:GetAttribute("CurrentIsland")
player:GetAttributeChangedSignal("CurrentIsland"):Connect(function()
	local island=player:GetAttribute("CurrentIsland")
	local previous=lastIsland
	lastIsland=island
	if not previous or not palette[island] then return end
	task.delay(.22,function()
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or player:GetAttribute("CurrentIsland")~=island then return end
		local color=palette[island][4]
		FX.Burst("Glint",root.Position,color,11,75)
		FX.Ring(root.Position-V(0,2.6,0),color,6,.48)
	end)
end)
local function victoryCue(message,kind)
	if kind~="boss" and kind~="rare_Divine" or typeof(message)~="string" then return end
	local lower=string.lower(message)
	if not string.find(lower,"defeated",1,true) and not string.find(lower,"victory",1,true) and not string.find(lower,"has fallen",1,true) then return end
	for id,preset in pairs(FX.Bosses) do
		if string.find(lower,string.lower(preset[2]),1,true) or id=="HeartOfWinter" and string.find(lower,"winter victory",1,true) then
			banner(preset,"Victory")
			local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then FX.Burst("Glint",root.Position+V(0,2,0),preset[1],12,80) end
			break
		end
	end
end
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(victoryCue)

local function bossObserver()
	local shown=false
	for obj,seen in pairs(bosses) do
		if not obj:IsDescendantOf(workspace) then continue end
		local p=FX.Bosses[obj:GetAttribute("ForestBossId") or ""]
		if not p then continue end
		local position=obj:GetPivot().Position
		if not FX.Near(position,100) then continue end
		local phase=obj:GetAttribute("ForestBossPhase") or "I"
		if seen.Phase~=phase and not shown then
			local description=phase=="Victory" and "The arena falls quiet" or phase=="I" and p[3]
				or phase=="Frenzy" and "Frenzy"
				or phase=="III" and "Winterfall"
				or obj:GetAttribute("ForestBossId")=="HeartOfWinter" and "Winter Seals"
				or "Attack pattern intensified"
			banner(p,description)
			FX.Burst("Glint",position+V(0,2,0),p[1],phase=="Victory" and 18 or 9)
			FX.Ring(position-V(0,math.max(0,obj.PrimaryPart and obj.PrimaryPart.Size.Y*.48 or 0),0),p[1],phase=="Victory" and 13 or 8,.65)
			shown=true
			seen.Phase=phase
		end
	end
	if title.Enabled and os.clock()>title:GetAttribute("Until") then title.Enabled=false end
end

-- One accent per wind-up or impact survives even in a multi-lane attack.
local warnedAt=0
local function warning(part)
	if not part:IsA("BasePart") or not FX.Near(part.Position,85) or os.clock()-warnedAt<.22 then return end
	warnedAt=os.clock()
	FX.Burst("Glint",part.Position+V(0,.13,0),part.Color,4,85)
end
CollectionService:GetInstanceAddedSignal("ForestWindup"):Connect(warning)
CollectionService:GetInstanceAddedSignal("ForestImpact"):Connect(function(part)
	if not part:IsA("BasePart") or not FX.Near(part.Position,95) then return end
	FX.Burst("Dust",part.Position,part.Color,7,95)
	FX.Ring(part.Position-V(0,.35,0),part.Color,math.min(13,part.Size.Y*.51),.38)
end)

local ambient={
	{V(26,4,-2964),R(255,219,121),"Glint",3},
	{V(19,3,-2879),R(215,236,119),"Glint",4},
	{V(-315,4,-2913),R(197,228,128),"Leaf",3},
	{V(2992,3,-381),R(129,232,226),"Glint",3},
	{V(6262,7,-77),R(157,210,250),"Snow",4},
}
local lastMood=0
refresh()
task.spawn(function()
	while task.wait(.48) do
		if e.Enabled and workspace.CurrentCamera then
			local c=workspace.CurrentCamera
			snowfall.Position=c.Focus.Position+V(0,16,0)+c.CFrame.LookVector*7
		end
		bossObserver()
		if FX.Quality()<2 or FX.Reduced() or os.clock()-lastMood<1.4 then continue end
		lastMood=os.clock()
		local camera=workspace.CurrentCamera
		if not camera then continue end
		local nearest,best=nil,69
		for tree,entry in pairs(mutations) do
			if tree:IsDescendantOf(workspace) and lastMood-(entry.Last or 0)>3 then
				local pos=tree:GetPivot().Position
				local range=(pos-camera.CFrame.Position).Magnitude
				if range<best and FX.Mutations[tree:GetAttribute("Mutation") or ""] then nearest,best=tree,range end
			end
		end
		if nearest then
			local m=FX.Mutations[nearest:GetAttribute("Mutation")]
			local pos=nearest:GetPivot().Position+V(0,nearest.PrimaryPart and nearest.PrimaryPart.Size.Y*.65 or 6,0)
			FX.Burst(m[3],pos,m[1],m[3]=="Dust" and 3 or 6,72)
			mutations[nearest].Last=lastMood
		end
		for _,a in ipairs(ambient) do
			if FX.Near(a[1],54) then FX.Burst(a[3],a[1],a[2],a[4],54) break end
		end
	end
end)
