-- Deterministic original Studio geometry. Every walkable surface is anchored.
local A = {}
local V = Vector3.new
local cf = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material
local themes = {
	TimberHaven={ Grass=rgb(85,137,71), Stone=rgb(83,88,69), Soil=rgb(126,101,67), Path=rgb(169,140,98), Wood=rgb(105,67,43), Roof=rgb(155,69,46), Trim=rgb(221,173,97), Light=rgb(255,185,79), Water=rgb(69,174,192) },
	FrostboundReach={ Grass=rgb(220,235,245), Stone=rgb(82,111,139), Soil=rgb(128,158,184), Path=rgb(151,188,207), Wood=rgb(73,83,109), Roof=rgb(42,93,132), Trim=rgb(199,223,235), Light=rgb(147,244,255), Water=rgb(103,187,227) },
	CrystalWilds={ Grass=rgb(111,110,151), Stone=rgb(67,65,106), Soil=rgb(89,88,130), Path=rgb(132,134,174), Wood=rgb(82,67,123), Roof=rgb(49,128,148), Trim=rgb(173,199,228), Light=rgb(130,255,236), Water=rgb(95,209,236) },
}

function A.Part(parent,name,size,frame,color,material,collide,shape)
	local p=Instance.new("Part")
	p.Name=name p.Size=size p.CFrame=frame p.Color=color p.Material=material or M.SmoothPlastic
	p.Anchored=true p.CanCollide=collide==true p.CanTouch=false
	p.CanQuery=collide==true p.CastShadow=collide==true
	p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
	if shape then p.Shape=shape end
	p.Parent=parent
	return p
end
local part=A.Part
local function model(parent,name)
	local p=Instance.new("Model") p.Name=name p.Parent=parent return p
end
local function text(p,title,sub)
	local gui=Instance.new("BillboardGui")
	gui.Name="Navigation" gui.Size=UDim2.fromOffset(210,55) gui.StudsOffset=V(0,2.5,0)
	gui.MaxDistance=100 gui.AlwaysOnTop=false gui.Parent=p
	local label=Instance.new("TextLabel")
	label.Size=UDim2.fromScale(1,1) label.BackgroundColor3=rgb(23,29,40) label.BackgroundTransparency=0.23
	label.Text=title..(sub and "\n"..sub or "") label.TextColor3=rgb(249,238,208)
	label.Font=Enum.Font.GothamBold label.TextScaled=true label.TextWrapped=true label.Parent=gui
	local round=Instance.new("UICorner") round.CornerRadius=UDim.new(0,6) round.Parent=label
end
function A.Sign(parent,point,title,sub,t)
	local m=model(parent,title.." sign")
	for _,x in ipairs({-3,3}) do part(m,"Post",V(.65,6,.65),cf(point+V(x,3,0)),t.Wood,M.Wood) end
	local p=part(m,"Signboard",V(8,2.5,.65),cf(point+V(0,5,0)),t.Roof,M.WoodPlanks)
	text(p,title,sub)
end
local function path(parent,a,b,width,t)
	local c=(a+b)/2
	local length=(a-b).Magnitude
	part(parent,"Packed trail",V(width,.14,length+1),CFrame.lookAt(c+V(0,.08,0),b+V(0,.08,0)),t.Path,M.Ground)
	for i=1,math.floor(length/35) do
		local delta=(b-a).Unit
		local p=a:Lerp(b,i/(math.floor(length/35)+1))+delta:Cross(V(0,1,0))*width*.48
		part(parent,"Waymarker",V(.55,2.5,.55),cf(p+V(0,1.23,0)),t.Trim,M.Wood)
		part(parent,"Painted trail cap",V(.75,.35,.75),cf(p+V(0,2.47,0)),t.Light,M.Neon)
	end
end
local function cottage(parent,center,theme,name,w,d)
	local house=model(parent,name)
	part(house,"Foundation",V(w+4,.75,d+4),cf(center+V(0,.15,0)),theme.Stone,M.Cobblestone,true)
	for _,z in ipairs({-d/2,d/2}) do
		for _,x in ipairs({-w/2,w/2}) do
			part(house,"Timber frame",V(1.6,9,1.6),cf(center+V(x,4.8,z)),theme.Wood,M.Wood,true)
		end
	end
	part(house,"Back wall",V(w,8,1),cf(center+V(0,4.6,d/2)),theme.Wood,M.WoodPlanks,true)
	for _,x in ipairs({-w/2,w/2}) do
		part(house,"Side wall",V(1,8,d),cf(center+V(x,4.6,0)),theme.Wood,M.WoodPlanks,true)
		part(house,"Window",V(1.2,2.1,3.9),cf(center+V(x,4.8,-1)),theme.Light,M.Neon)
	end
	for _,side in ipairs({-1,1}) do
		part(house,"Pitch roof",V(w*.59,1.1,d+4),cf(center+V(side*w*.26,10.4,0))*CFrame.Angles(0,0,math.rad(-side*24)),theme.Roof,M.Slate,true)
		part(house,"Roof trim",V(1.2,.65,d+5),cf(center+V(side*w*.51,8.25,0)),theme.Trim,M.Wood)
	end
	part(house,"Ridge beam",V(1.2,1.1,d+4),cf(center+V(0,12.4,0)),theme.Trim,M.Wood)
	return house
end
function A.Portal(parent,center,t,label,key,value)
	local m=model(parent,label)
	part(m,"Threshold",V(12,.65,9),cf(center+V(0,.3,0)),t.Stone,M.Cobblestone,true)
	for _,x in ipairs({-4.3,4.3}) do
		part(m,"Portal pier",V(1.65,9,1.7),cf(center+V(x,4.5,0)),t.Stone,M.Slate,true)
		part(m,"Portal inlay",V(.4,7,.18),cf(center+V(x,4.5,-.9)),t.Light,M.Neon)
	end
	part(m,"Portal lintel",V(10,1.7,2.2),cf(center+V(0,9,0)),t.Trim,M.Slate,true)
	local anchor=part(m,"Interaction",V(4,.35,4),cf(center+V(0,.76,0)),t.Light,M.Neon)
	text(anchor,label,value and "Interact" or "Reserved")
	if key and value then
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name="WorldPrompt" prompt.ObjectText=label
		prompt.ActionText=key=="TravelTo" and "Travel" or "Open"
		prompt.MaxActivationDistance=10 prompt.RequiresLineOfSight=false
		prompt:SetAttribute(key,value) prompt.Parent=anchor
	end
	return m
end
local function station(parent,center,t,name,service)
	local m=cottage(parent,center,t,name,20,16)
	local counter=part(m,"Service counter",V(7,2.8,2.7),cf(center+V(0,1.9,2.4)),t.Trim,M.Wood,true)
	text(counter,name,service and "Interact" or "Reserved")
	if service then
		local p=Instance.new("ProximityPrompt")
		p.Name=service=="Traits" and "TraitPrompt" or "WorldPrompt"
		p.ActionText="Open" p.ObjectText=name p.RequiresLineOfSight=false p.MaxActivationDistance=12
		p:SetAttribute("OpenPanel",service) p.Parent=counter
	end
	return m
end
local function land(root,plan,t,frost)
	local c,w,d=plan.Center,plan.Width,plan.Depth
	part(root,"Walkable plateau",V(w,10,d),cf(c-V(0,5,0)),t.Grass,frost and M.Snow or M.Grass,true)
	part(root,"Weathered strata",V(w+11,13,d+11),cf(c-V(0,16,0)),t.Soil,M.Rock)
	part(root,"Basalt island shelf",V(w-25,20,d-25),cf(c-V(0,31,0)),t.Stone,M.Slate)
	local rng=Random.new(frost and 645 or 418)
	for i=1,56 do
		local side=(i-1)%4
		local run=rng:NextNumber(-.48,.48)
		local x=(side==0 or side==2) and run*w or (side==1 and w/2-13 or -w/2+13)
		local z=(side==1 or side==3) and run*d or (side==0 and d/2-13 or -d/2+13)
		local high=rng:NextNumber(9,29)
		part(root,frost and "Blue ice bastion" or "Stratified cliff",V(rng:NextNumber(11,25),high,rng:NextNumber(14,30)),
			cf(c+V(x,high*.28,z))*CFrame.Angles(.2,rng:NextNumber(0,6.28),.16),i%4==0 and t.Water or t.Stone,frost and M.Glacier or M.Rock)
	end
end

function A.Arena(parent,center,t,name,radius)
	local m=model(parent,name)
	part(m,"Arena pavers",V(.4,radius*2,radius*2),cf(center+V(0,.18,0))*CFrame.Angles(0,0,math.pi/2),t.Stone,M.Cobblestone,true,Enum.PartType.Cylinder)
	part(m,"Arena inlay",V(.08,radius*1.54,radius*1.54),cf(center+V(0,.43,0))*CFrame.Angles(0,0,math.pi/2),t.Path,M.Slate,false,Enum.PartType.Cylinder)
	for i=1,16 do
		local theta=i*math.pi/8
		local offset=V(math.cos(theta),0,math.sin(theta))
		if i%4~=0 then
			part(m,"Standing stone",V(3.2,7+(i%3),3.2),cf(center+offset*(radius+2)+V(0,3.7,0))*CFrame.Angles(0,-theta,0),t.Stone,M.Slate,true)
			part(m,"Rune cap",V(2.3,.45,2.3),cf(center+offset*(radius+2)+V(0,7.25+i%3/2,0)),t.Light,M.Neon)
		end
	end
	A.Sign(m,center+V(0,0,-radius-4),name,"Arena",t)
	return m
end

local function waterfalls(parent,c,t)
	for i=1,3 do
		local p=part(parent,"Waterfall curtain",V(13-i*2,27+i*2,.65),cf(c+V(i*2,-12,0)),t.Water,M.Glass)
		p.Transparency=.25+i*.12
	end
	local p=part(parent,"Splash pool",V(25,.3,14),cf(c+V(0,-25,5)),t.Water,M.Glass)
	p.Transparency=.16
end

local function ambiance(parent,pos,t,frost)
	local m=model(parent,frost and "Aurora" or "Forest details")
	local rng=Random.new(frost and 342 or 803)
	for i=1,18 do
		local p=pos+V(rng:NextNumber(-25,25),frost and (24+math.sin(i*.55)*6) or .4,(i-9)*2.4)
		local q=part(m,frost and "Aurora ribbon" or "Wildflowers",
			frost and V(20,3.4,4.2) or V(.55,.49,.56),cf(p)*CFrame.Angles(0,math.rad(25),math.rad(i%4*9)),
			frost and Color3.fromHSV(.41+(i%7)*.025,.56,1) or Color3.fromHSV(.04+(i%6)*.065,.66,1), frost and M.Neon or M.Grass)
		if frost then q.Transparency=.58 end
	end
	if frost then
		local volume=part(m,"Snow flurry",V(44,1,34),cf(pos+V(0,19,0)),t.Light,M.SmoothPlastic)
		volume.Transparency=1
		local e=Instance.new("ParticleEmitter") e.Name="Localized snowfall"
		e.Texture="rbxasset://textures/particles/sparkles_main.dds"
		e.Rate=15 e.Lifetime=NumberRange.new(2,3) e.Speed=NumberRange.new(3,6)
		e.EmissionDirection=Enum.NormalId.Bottom e.SpreadAngle=Vector2.new(20,20)
		e.Size=NumberSequence.new(.14) e.Shape=Enum.ParticleEmitterShape.Box
		e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume e.Color=ColorSequence.new(t.Light) e.Parent=volume
	end
end

function A.BuildIsland(parent,plan,layout)
	local root=model(parent,plan.Id)
	local frost=plan.Id=="FrostboundReach"
	local t=themes[plan.Id]
	land(root,plan,t,frost)
	local districts={}
	for i,d in ipairs(plan.Districts) do
		districts[i]=model(root,d[1])
		A.Sign(districts[i],d[2]+V(frost and -15 or -14,0,-8),d[1],d[3],t)
	end
	local points=plan.Districts
	local links=frost and {{1,2},{1,3},{2,4},{3,6},{4,5},{4,7},{7,8},{8,5}} or {{1,2},{1,3},{1,4},{4,5},{5,6},{6,3},{3,7},{7,2},{2,8}}
	for _,link in ipairs(links) do path(root,points[link[1]][2],points[link[2]][2],12,t) end
	local village=points[1][2]
	if not frost then
		station(districts[1],village+V(-16,0,-30),t,"Trail Guide",nil)
		station(districts[1],village+V(13,0,-30),t,"Village Records",nil)
		cottage(districts[1],village+V(-24,0,28),t,"Haven Lodge",30,21)
		A.Sign(districts[1],village+V(27,0,5),"Your first chop","Follow the trail markers east to Sapling Woods",t)
		A.Sign(districts[1],village+V(10,0,-18),"Improve your blade","Visit Crafters’ Plaza for upgrades",t)
		for i,pair in ipairs({{"Log Market","Market"},{"Upgrade Hall","Upgrades"},{"Forge Workshop",nil}}) do
			station(districts[2],points[2][2]+V((i-2)*30,0,13),t,pair[1],pair[2])
		end
		for i,pair in ipairs({{"Weapon Gallery","Gallery"},{"Pet Sanctuary","Pets"},{"Trait Shrine","Traits"},{"Timber Altar","Altar"}}) do
			station(districts[3],points[3][2]+V((i%2==0 and 15 or -15),0,i<3 and -21 or 22),t,pair[1],pair[2])
		end
		for i,c in ipairs(plan.Camps) do cottage(districts[i<=2 and 5 or 6],c,t,"Rogue Camp "..i,15,12) end
		A.Portal(districts[5],V(54,0,-2880),t,"Pinewood · 40 Power",nil,nil)
		A.Portal(districts[6],V(-225,0,-2978),t,"Elderpine · 40 Power",nil,nil)
		A.Arena(districts[7],points[7][2],t,"Kingsfall Arena",48)
		A.Portal(districts[8],points[8][2]+V(-21,0,9),t,"Crystal Wilds","TravelTo","CrystalWilds")
		A.Portal(districts[8],points[8][2]+V(21,0,9),t,"Frostbound Reach","TravelTo","FrostboundReach")
		A.Portal(districts[8],points[8][2]+V(-21,0,-20),t,"Future Passage")
		A.Portal(districts[8],points[8][2]+V(21,0,-20),t,"Future Landing")
		ambiance(root,village+V(12,0,40),t,false)
		waterfalls(root,plan.Center+V(340,0,-319),t)
		waterfalls(root,plan.Center+V(-360,0,319),t)
	else
		A.Portal(districts[1],village+V(-24,0,-20),t,"Timber Haven","TravelTo","TimberHaven")
		A.Portal(districts[1],village+V(-24,0,19),t,"Crystal Wilds","TravelTo","CrystalWilds")
		for i,pair in ipairs({{"Frost Egg","Pets"},{"Frost Altar","Altar"},{"Forge Annex",nil}}) do
			station(districts[1],village+V(28,0,(i-2)*25),t,pair[1],pair[2])
		end
		A.Arena(districts[6],points[6][2],t,"Monarch's Throne",47)
		A.Arena(districts[7],points[7][2],t,"Heart of Winter Sanctum",36)
		A.Portal(districts[7],points[7][2]+V(0,0,24),t,"Winter Key Threshold")
		cottage(districts[7],points[7][2]+V(0,0,-23),t,"Vault of Winter",33,13)
		A.Portal(districts[8],points[8][2]+V(0,0,-11),t,"Expedition Gate")
		A.Portal(districts[8],V(6270,0,218),t,"Future Island Passage")
		ambiance(root,points[4][2]+V(0,0,-28),t,true)
		for _,i in ipairs({2,3,4,5}) do
			local c=points[i][2]
			for j=1,5 do
				local p=c+V(math.cos(j)*13,3+j%3,math.sin(j)*11)
				part(districts[i],"Frozen obelisk",V(3+j%2,8+j%4,3),cf(p)*CFrame.Angles(.19,j,.1),j%2==0 and t.Water or t.Stone,M.Glacier)
			end
		end
	end
	return root
end

function A.BuildCrystal(parent,layout)
	local root=model(parent,"CrystalColossusAnnex")
	local t=themes.CrystalWilds
	local plan=layout.Crystal
	land(root,plan,t,false)
	A.Arena(root,plan.Center,t,"Crystal Colossus",47)
	A.Portal(root,plan.Center+V(19,0,46),t,"Crystal Wilds Plaza","M4Waypoint","CrystalPlaza")
	local gate=model(parent,"CrystalColossusAccess")
	-- A standalone interactable on the edge of the existing arrival floor.
	local anchor=part(gate,"Colossus trial stone",V(3.4,2.8,3.4),cf(plan.Portal),t.Stone,M.Slate)
	text(anchor,"Crystal Colossus","Enter arena")
	local p=Instance.new("ProximityPrompt")
	p.Name="WorldPrompt" p.ObjectText="Crystal Colossus" p.ActionText="Enter arena"
	p.MaxActivationDistance=10 p.RequiresLineOfSight=false p:SetAttribute("M4Waypoint","ColossusArena")
	p.Parent=anchor
	return root,gate
end
return A
