-- Scenery only. The V2 package still owns the terrain, traversal and encounter models.
local Scenery={}
local V=Vector3.new
local CF=CFrame.new
local R=Color3.fromRGB
local M=Enum.Material
local wood=R(76,48,32)
local trim=R(149,111,60)
local leaf=R(64,89,50)
local moss=R(92,117,66)
local stone=R(76,83,76)
local amber=R(248,197,115)
local deep=R(37,45,73)
local teal=R(91,207,198)
local violet=R(129,112,193)
local frost=R(195,224,233)
local slate=R(60,79,99)

local function model(parent,name)
	local m=Instance.new("Model")
	m.Name=name
	m.Parent=parent
	return m
end

local function piece(parent,name,frame,size,color,material,form)
	local p=Instance.new(form or "Part")
	p.Name=name
	p.Size=size p.CFrame=frame p.Color=color p.Material=material
	p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
	p.Parent=parent
	return p
end

local function rod(parent,name,a,b,width,depth,color,material)
	return piece(parent,name,CFrame.lookAt(a:Lerp(b,.5),b),V(width,depth,(b-a).Magnitude),color,material)
end

local function lettering(board,face,title,subtitle)
	local gui=Instance.new("SurfaceGui")
	gui.Face=face gui.LightInfluence=.16 gui.MaxDistance=65
	gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize gui.CanvasSize=Vector2.new(464,144)
	gui.Parent=board
	for _,data in ipairs({{title,.10,.40,Enum.Font.GothamBold,amber},{subtitle,.57,.33,Enum.Font.GothamMedium,R(242,232,207)}}) do
		local label=Instance.new("TextLabel")
		label.BackgroundTransparency=1 label.Size=UDim2.fromScale(.94,data[3])
		label.Position=UDim2.fromScale(.03,data[2]) label.TextScaled=true label.TextWrapped=true
		label.Text=data[1] label.Font=data[4] label.TextColor3=data[5] label.Parent=gui
	end
end

local function plaque(parent,frame,title,subtitle,w)
	local board=piece(parent,title,frame,V(w,3.4,.6),wood,M.WoodPlanks)
	lettering(board,Enum.NormalId.Front,title,subtitle)
end

function Scenery.Restyle(root,winterTheme)
	for _,part in ipairs(root:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		if not winterTheme and part.Name=="Pitch roof" then
			part.Color=R(107,77,60)
		end
		local gui=part:FindFirstChild("Navigation")
		if not gui or not gui:IsA("BillboardGui") then continue end
		if part.Name=="Signboard" and gui.Enabled then
			local old=gui:FindFirstChildWhichIsA("TextLabel")
			local heading,body=string.match(old and old.Text or "","^([^\n]+)\n?(.*)$")
			if heading then
				if heading=="Heart of Winter Sanctum" then body="Winter Key  /  1–4 players" end
				if heading=="Your first chop" then body="Sapling Woods  /  East trail" end
				gui.Enabled=false
				part.Color=winterTheme and R(35,53,74) or wood
				lettering(part,Enum.NormalId.Front,heading,body)
				lettering(part,Enum.NormalId.Back,heading,body)
			end
		elseif part.Name=="Interaction" or part.Name=="Service counter" then
			-- Keep service names and prompts visible at interaction distance.
			gui.MaxDistance=24
		end
	end
end

local function lamp(parent,at)
	piece(parent,"Iron lantern hood",CF(at+V(0,.62,0)),V(.92,.24,.92),wood,M.Metal)
	piece(parent,"Honey glass",CF(at),V(.57,.96,.57),amber,M.Neon)
	piece(parent,"Iron lantern foot",CF(at-V(0,.56,0)),V(.89,.22,.89),wood,M.Metal)
end

local function arch(parent,at,span,height)
	for _,side in ipairs({-1,1}) do
		local foot=at+V(side*span/2,.43,0)
		piece(parent,"Fieldstone foot",CF(foot),V(2.45,1.1,2.45),stone,M.Cobblestone)
		piece(parent,"Hewn oak",CF(foot+V(0,height/2,0)),V(1.55,height,1.65),wood,M.Wood)
		rod(parent,"Curved-brace timber",foot+V(0,height-3.7,0),foot+V(-side*3.6,height-.25,0),.8,.76,trim,M.Wood)
		lamp(parent,foot+V(0,height-2.1,-1.13))
	end
	piece(parent,"Hammerbeam",CF(at+V(0,height+.45,0)),V(span+3,1.05,2.15),wood,M.Wood)
	for _,side in ipairs({-1,1}) do
		local peak=at+V(0,height+3.7,0)
		local tip=at+V(side*(span/2+1.7),height+.45,0)
		rod(parent,"Copper shingle line",peak,tip,2.7,.57,moss,M.Slate)
		rod(parent,"Carved fascia",peak-V(0,.28,1.41),tip-V(0,.28,1.41),.43,.52,trim,M.Wood)
	end
end

local function crop(parent,p,rng,size)
	local h=size*rng:NextNumber(.6,1.3)
	piece(parent,"Mossy fieldstone",CF(p+V(0,h*.31,0))*CFrame.Angles(0,rng:NextNumber(0,6),.19),V(size*1.55,h,size),stone,M.Rock,"CornerWedgePart")
	piece(parent,"Moss cap",CF(p+V(0,h*.52,0))*CFrame.Angles(0,.4,0),V(size*1.2,h*.26,size*.78),moss,M.Grass,"WedgePart")
end

local function shard(parent,p,h,w,c,yaw,lean)
	local f=CF(p)*CFrame.Angles(0,yaw,lean)
	local core=piece(parent,"Mineral face",f*CF(0,h*.38,0),V(w,h*.76,w*.62),c,M.Glacier,"WedgePart")
	piece(parent,"Split facet",f*CF(w*.17,h*.63,-w*.07)*CFrame.Angles(0,math.pi,0),V(w*.74,h*.74,w*.42),c:Lerp(frost,.42),M.Ice,"CornerWedgePart")
	piece(parent,"Mineral seam",core.CFrame*CF(w*.19,-h*.03,-w*.35),V(w*.12,h*.51,.13),c:Lerp(teal,.52),M.SmoothPlastic)
end

local function ring(parent,center,r,count,width,color)
	for i=1,count do
		local angle=i*math.pi*2/count
		local p=center+V(math.cos(angle)*r,0,math.sin(angle)*r)
		piece(parent,"Carved floor mark",CF(p)*CFrame.Angles(0,-angle,0),V(width,.09,2.6),color,M.Slate)
	end
end

local function gateFrame(parent,source,name,color)
	local gate=source:FindFirstChild(name,true)
	local foot=gate and gate:FindFirstChild("Interaction")
	if not foot then return end
	local at=foot.Position-V(0,.75,0)
	local m=model(parent,name.." · gate crown")
	for _,side in ipairs({-1,1}) do
		local x=side*4.3
		piece(m,"Carved cornerstone",CF(at+V(x,1,-.05)),V(2.42,1.6,2.4),stone,M.Slate)
		piece(m,"Gate mineral inlay",CF(at+V(x,4.7,-1.04)),V(.27,5.5,.13),color,M.Neon)
		rod(m,"Chiseled arch",at+V(x,8.8,.11),at+V(side*.7,11.0,.11),.91,.84,stone,M.Slate)
	end
	local seal=piece(m,"Gate keystone",CF(at+V(0,10.69,-.29))*CFrame.Angles(0,0,math.pi/4),V(1.22,1.22,.46),color,M.Ice)
	seal.CastShadow=false
end

local function timber(parent,root,layout,breakables)
	local village=model(parent,"Lanternwood · cedar and copper")
	local arrival=V(2,0,-2991)
	arch(village,arrival,17,10.5)
	plaque(village,CF(arrival+V(0,9.9,-1.43)),"HAVEN VILLAGE","Sapling Woods  /  Records Lodge",12.2)
	-- Dress the edge of the existing forecourt, with a clear middle aisle.
	local lodge=model(parent,"Haven Records Lodge · carpenter's canopy")
	for _,x in ipairs({-25,-4,20,41}) do
		local at=V(x,0,-2933)
		piece(lodge,"Cobble pillar base",CF(at+V(0,.46,0)),V(2.1,.94,2.1),stone,M.Cobblestone)
		piece(lodge,"Covered gallery post",CF(at+V(0,5.7,0)),V(1.16,10.6,1.16),wood,M.Wood)
		lamp(lodge,at+V(0,7,-.83))
	end
	for _,side in ipairs({-1,1}) do
		local at=V(8,15.45,-2929)
		rod(lodge,"Copper standing seam roof",at+V(-38,2,side*.2),at+V(38,2,side*.2),.44,.36,trim,M.Wood)
		piece(lodge,"Sloping shingle canopy",CF(at+V(0,.05,side*3.2))*CFrame.Angles(side*.27,0,0),V(77,.74,6.8),side<0 and R(65,101,83) or R(45,74,62),M.Slate)
	end
	plaque(lodge,CF(8,13.55,-2935),"HAVEN RECORDS LODGE","Harvest  /  Rare finds  /  Trail veterans",16.5)
	local previous=root:FindFirstChild("Haven Records Lodge sign",true)
	if previous then
		for _,d in ipairs(previous:GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency=1 elseif d:IsA("LayerCollector") then d.Enabled=false end
		end
	end

	local brook=model(parent,"Alder Brook · mill footbridge")
	local a,b=V(-38,.15,-2960),V(59,.15,-2960)
	rod(brook,"Shallow alder water",a,b,6.6,.16,R(66,115,106),M.SmoothPlastic)
	for _,z in ipairs({-2964,-2956}) do
		rod(brook,"Flat mossy bank",V(-38,.11,z),V(59,.11,z),1.45,.21,R(112,103,73),M.Cobblestone)
	end
	for z=-2965,-2955,1.06 do
		piece(brook,"Flush bridge tread",CF(-5,.28,z),V(9,.23,.96),wood:Lerp(trim,(math.floor(z)%4)*.13),M.WoodPlanks)
	end
	for _,x in ipairs({-10,0}) do
		for _,z in ipairs({-2966,-2954}) do
			piece(brook,"Low oak bollard",CF(x,.9,z),V(.58,1.8,.58),wood,M.Wood)
		end
	end
	for i=1,9 do
		local x=i*10-40
		rod(brook,"Narrow water glint",V(x,.25,-2960+(i%3)-1),V(x+2.3,.25,-2960+(i%3)-1),.1,.045,R(136,174,139),M.SmoothPlastic)
	end

	local rng=Random.new(234)
	local trees={}
	for _,tree in ipairs(breakables:GetChildren()) do
		local area=tree:GetAttribute("Area")
		if area=="StarterGrove" or area=="PineForest" then table.insert(trees,tree:GetPivot().Position) end
	end
	local roads=require(script.Parent.TimberLandscape)
	local route=roads.GetRoads(root)
	for _,data in ipairs({
		{"Foxglove garden",V(24,0,-2971),12,11},
		{"Firefly dell",V(19,0,-2879),21,16},
		{"Elderpine nurse log",V(-314,0,-2910),17,18},
		{"Mill courtyard",V(41,0,-3098),16,10},
	}) do
		local stand=model(parent,data[1])
		for i=1,data[4]*3 do
			if #stand:GetChildren()>=data[4]*2 then break end
			local point=data[2]+V(rng:NextNumber(-data[3],data[3]),0,rng:NextNumber(-data[3],data[3]))
			if roads.RoadClearance(point,route)<6 then continue end
			local clear=true
			for _,t in ipairs(trees) do if (point-t).Magnitude<3.6 then clear=false break end end
			if not clear then continue end
			if i%4==0 then
				crop(stand,point,rng,rng:NextNumber(.75,1.9))
			else
				local h=rng:NextNumber(.27,.88)
				piece(stand,"Fern frond",CF(point+V(0,.24,0))*CFrame.Angles(0,i*2.39,-.43),V(.34,.48,.82),leaf:Lerp(moss,(i%4)*.16),M.Grass,"WedgePart")
				local bud=piece(stand,"Foxglove",CF(point+V(.18,h,0)),V(.23,.35,.23),i%3==0 and R(210,143,166) or amber,M.SmoothPlastic)
				bud.Shape=Enum.PartType.Ball
			end
		end
		if data[1]=="Elderpine nurse log" then
			local q=data[2]
			local log=rod(stand,"Ancient nurse log",q+V(-6,1,4),q+V(5,1.35,-1),1.42,1.38,wood,M.Wood)
			log.Shape=Enum.PartType.Cylinder
			log.Size=V(log.Size.Z,1.42,1.38) log.CFrame*=CFrame.Angles(0,math.pi/2,0)
			for j=1,3 do
				piece(stand,"Shelf mushroom",CF(q+V(-4+j*2,1.6,3-j)),V(.9,.22,.7),R(181,128,79),M.SmoothPlastic,"WedgePart")
			end
		end
	end
	local portals=model(parent,"Portal Cliffs · carved thresholds")
	gateFrame(portals,root,"Crystal Wilds",teal)
	gateFrame(portals,root,"Frostbound Reach",frost)
	local arena=model(parent,"Kingsfall · last stand")
	local king=layout.Timber.Districts[7][2]
	ring(arena,king+V(0,.53,0),35,12,.48,trim)
	for _,side in ipairs({-1,1}) do
		local at=king+V(side*29,0,-29)
		piece(arena,"Old guard obelisk",CF(at+V(0,3,0))*CFrame.Angles(0,.23,side*.14),V(2.1,6.3,2.85),stone,M.Slate)
		piece(arena,"Watch fire",CF(at+V(0,6.35,0)),V(.69,1.25,.69),amber,M.Neon)
	end
end

local function crystal(parent,layout)
	local geode=model(parent,"Prismglass · the split geode")
	local c=layout.Crystal.Center
	local rng=Random.new(532)
	for i=1,18 do
		local angle=math.pi*.08+i*.166
		local p=c+V(math.cos(angle)*51,0,-math.sin(angle)*51)
		local h=rng:NextNumber(i<=4 and 2.6 or 4,i<=4 and 5 or 11)+(i==9 and 9 or 0)
		shard(geode,p,h,rng:NextNumber(1.8,3.7),i%3==0 and violet or teal,angle,i%2==0 and .22 or -.31)
	end
	ring(geode,c+V(0,.53,0),34,16,.65,violet)
	local entry=model(parent,"Prismglass · trail stones")
	for i=1,5 do
		local p=layout.Crystal.Portal+V(7+i*1.1,-.9,-4-i*.62)
		shard(entry,p,1.75+i*.44,.8+i*.15,i%2==0 and violet or teal,i*.85,.21)
	end
	local fall=model(parent,"Prismglass · mineral cascade")
	for i=1,4 do
		local x=3037+i*2.25
		local strip=piece(fall,"Cold mineral runoff",CF(x,-6,-407)*CFrame.Angles(.12,0,i*.015),V(1.5,16+i*2,.36),teal:Lerp(violet,i*.14),M.Ice)
		strip.Transparency=.16
	end
end

local function winter(parent,root,layout)
	local skyline=model(parent,"The Crown of Winter · icebound horizon")
	local rng=Random.new(812)
	for i=1,19 do
		local p=V(5690+(i-1)*35,-7,-282-rng:NextNumber(3,12))
		local h=rng:NextNumber(20,62)
		local w=rng:NextNumber(15,37)
		piece(skyline,"Glacier shoulder",CF(p+V(0,h*.31,0))*CFrame.Angles(0,i*.47,.08),V(w,h,w*.76),slate,M.Rock,"CornerWedgePart")
		piece(skyline,"Wind-scoured snow",CF(p+V(-w*.12,h*.43,.6))*CFrame.Angles(0,i*.47,-.29),V(w*.63,h*.68,w*.64),frost,M.Snow,"WedgePart")
	end
	local outpost=model(parent,"Frostgate · expedition braziers")
	gateFrame(outpost,root,"Timber Haven",amber)
	gateFrame(outpost,root,"Crystal Wilds",teal)
	for _,z in ipairs({-29,28}) do
		local a=V(5766,0,z)
		piece(outpost,"Weathered outpost beacon",CF(a+V(0,2.5,0)),V(2,5.2,2.1),slate,M.Slate)
		piece(outpost,"Amber refuge",CF(a+V(0,5.25,0)),V(.95,.93,.95),amber,M.Neon)
		piece(outpost,"Snow cap",CF(a+V(0,5.84,0)),V(1.8,.26,1.8),frost,M.Snow)
	end
	local monarch=model(parent,"Monarch's Throne · shattered crown")
	local crown=layout.Frost.Districts[6][2]
	for i=1,9 do
		if i==5 then continue end -- leave a clear view down the central approach
		local a=-1.37+(i-1)*.34
		local p=crown+V(math.sin(a)*46,0,-math.cos(a)*46)
		shard(monarch,p,8+11*(1-math.abs(a)/1.6),3.7,i%2==0 and frost or slate,a,a*.28)
	end
	ring(monarch,crown+V(0,.53,0),32,12,.52,frost)
	local sanctum=model(parent,"Heart of Winter · frozen cathedral")
	local c=layout.Frost.Districts[7][2]
	for _,side in ipairs({-1,1}) do
		local f=CF(c+V(side*19,0,-21))*CFrame.Angles(0,0,-side*.11)
		piece(sanctum,"Cathedral buttress",f*CF(0,8,0),V(4.7,16,5.2),deep,M.Slate)
		piece(sanctum,"Glacier mullion",f*CF(0,8,2.7),V(.57,12,.49),frost,M.Ice)
		shard(sanctum,c+V(side*25,0,-19),16,4.5,violet,side*.4,side*.16)
		rod(sanctum,"Broken vaulted rib",c+V(side*18,14,-21),c+V(side*4,22,-21),1.8,1.6,slate,M.Slate)
		local ice=c+V(side*27,-4,-27)
		for j=1,3 do
			piece(sanctum,"Hanging frozen fall",CF(ice+V(j*1.4,1+j*.6,j*.6))*CFrame.Angles(.12,0,.03*j),V(1.1,12+j*2,.69),frost:Lerp(teal,.38),M.Glacier,"WedgePart")
		end
	end
	for i=1,8 do
		local z=c.Z-15+i*2.9
		local tile=piece(sanctum,"Inlaid pilgrimage mark",CF(c.X,.54,z)*CFrame.Angles(0,math.pi/4,0),V(.62,.075,.62),frost,M.Ice)
		tile.Transparency=.08
	end
	local core=piece(sanctum,"Suspended winter heart",CF(c+V(0,18,-21.25))*CFrame.Angles(0,.3,math.pi/4),V(3.65,3.65,2.1),R(169,194,238),M.Ice)
	core.Transparency=.06
	piece(sanctum,"Unlit keystone halo",CF(c+V(0,18,-22.4))*CFrame.Angles(0,.25,math.pi/4),V(5.35,5.35,.34),slate,M.Slate)
	local old=root:FindFirstChild("Aurora")
	if old then
		for _,d in ipairs(old:GetDescendants()) do
			if d:IsA("ParticleEmitter") then d.Enabled=false elseif d:IsA("BasePart") then d.Transparency=1 end
		end
	end
end

function Scenery.Build(world,timberRoot,frostRoot,layout,breakables)
	local root=Instance.new("Folder")
	root.Name="BladeForestScenery"
	timber(model(root,"Timber Haven"),timberRoot,layout,breakables)
	crystal(model(root,"Crystal Wilds"),layout)
	winter(model(root,"Frostbound Reach"),frostRoot,layout)
	Scenery.Restyle(timberRoot,false)
	Scenery.Restyle(frostRoot,true)
	root.Parent=world
	return root
end
return Scenery
