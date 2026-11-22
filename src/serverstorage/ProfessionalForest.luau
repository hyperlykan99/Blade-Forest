-- Presentation of the reviewed Kenney catalog. Existing world objects still own interaction.
local Art={}
local V=Vector3.new
local CF=CFrame.new
local TreeSources={
	Grove_Common="Sapling",Grove_Uncommon="Blossom",Grove_Rare="AutumnMaple",Grove_Epic="RubyMaple",
	Grove_Legendary="GoldenOak",Grove_Mythic="Sakura",Grove_Secret="AncientCrown",
	Pine_Common="Spruce",Pine_Uncommon="TallPine",Pine_Rare="FrostSpruce",Pine_Epic="EmberPine",
	Pine_Legendary="GoldenPine",Pine_Mythic="GiantMushroom",Pine_Secret="MoonlitBonsai",
	Frost_Common="SnowPine",Frost_Uncommon="GlacierPine",Frost_Rare="Frostwood",Frost_Epic="AuroraPine",
	Frost_Legendary="Starfrost",Frost_Mythic="Frostleaf",Frost_Secret="FrostGiant",
}
local Props={
	"Bridge","Trail","River","Waterfall","Boulder","Cliff","Crystal","CrystalSpine","Fern","Foxglove","Fence",
	"NurseLog","Cart","Lantern","MarketStall","GateArch","RuinedWall","WinterArch","Pavers","TimberSign",
	"Cottage","Workshop","RecordsHall",
}
local Textures={"Chip","Leaf","Glint","Snow","Dust"}
local Buildings={
	["Haven Lodge"]="Cottage",["Trail Guide"]="Cottage",["Village Records"]="Cottage",
	["Log Market"]="Workshop",["Upgrade Hall"]="Workshop",["Forge Workshop"]="Workshop",
	["Weapon Gallery"]="Workshop",["Pet Sanctuary"]="Cottage",["Trait Shrine"]="Cottage",["Timber Altar"]="Cottage",
	["Frost Egg"]="Cottage",["Frost Altar"]="Cottage",["Forge Annex"]="Workshop",["Vault of Winter"]="RecordsHall",
}
local Surfaces={
	["Timber frame"]=true,["Back wall"]=true,["Side wall"]=true,Window=true,
	["Pitch roof"]=true,["Roof trim"]=true,["Ridge beam"]=true,
}

local function place(root,source,name,base,dimensions,rotation,query)
	local part=source:Clone()
	part.Name=name
	part.Size=dimensions
	part.CFrame=CF(base+V(0,dimensions.Y*.5,0))*CF.Angles(0,rotation or 0,0)
	part.Anchored=true
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=query==true
	part.CastShadow=false
	part.Parent=root
	return part
end

local function visualTemplate(name,source)
	local model=Instance.new("Model")
	model.Name="Professional_"..name
	local original=source.Size
	local limit=name:sub(1,5)=="Frost" and 11 or 9
	local width=math.max(original.X,original.Z)
	local factor=math.min(3.57,limit/width)
	local part=place(model,source,"Choppable crown",V.zero,original*factor,0,true)
	part:SetAttribute("Leaf",true)
	part:SetAttribute("LeafColor",part.Color)
	model.WorldPivot=CF()
	model:SetAttribute("LeafColor",part.Color)
	return model
end

function Art.Prepare(bank)
	if not bank or bank:GetAttribute("Verified")~=true then return nil end
	local meshes={}
	for _,p in ipairs(bank:GetChildren()) do
		if p:IsA("MeshPart") then
			local skin=p:FindFirstChildWhichIsA("SurfaceAppearance")
			assert(p.MeshId~="" and (p.TextureID~="" or skin and skin.ColorMap~=""),p.Name.." is missing authored geometry or palette")
			for _,child in ipairs(p:GetChildren()) do
				assert(child:IsA("SurfaceAppearance"),p.Name.." has an unexpected dependency")
			end
			assert(not meshes[p.Name],"Duplicate asset "..p.Name)
			meshes[p.Name]=p
		end
	end
	local textures={}
	for _,channel in ipairs(Textures) do
		local id=bank:GetAttribute(channel)
		assert(typeof(id)=="string" and id:match("^rbxassetid://%d+$"),"Missing licensed VFX "..channel)
		textures[channel]=id
	end
	for _,name in ipairs(Props) do assert(meshes[name],"Missing prop "..name) end

	local templates={}
	for id,name in pairs(TreeSources) do templates[id]=visualTemplate(id,assert(meshes[name],"Missing tree "..name)) end
	local function style(tree)
		local source=templates[tree:GetAttribute("TreeType")]
		if not source then return end
		for _,part in ipairs(tree:GetChildren()) do
			if part:IsA("BasePart") then
				if part.Name=="Trunk" then part.Transparency=1
				elseif part:GetAttribute("Leaf") then part:Destroy() end
			end
		end
		local replacement=source:Clone()
		replacement:ScaleTo(tree:GetScale())
		replacement:PivotTo(tree:GetPivot())
		replacement.Parent=tree
		tree:SetAttribute("Template",source.Name)
		tree:SetAttribute("LeafColor",source:GetAttribute("LeafColor"))
	end
	return {Meshes=meshes,Templates=templates,Apply=style,Textures=textures}
end

local function props(set,root,rows)
	for _,r in ipairs(rows) do
		local src=set.Meshes[r[1]]
		local dimensions=r[4] or src.Size*3.57
		place(root,src,r[1],r[2],dimensions,r[3])
	end
end

local function dressBuilding(set,scope)
	-- Foundations and shells still carry their original collision. Navigation and prompts stay in place.
	for _,obj in ipairs(scope:GetDescendants()) do
		local key=obj:IsA("Model") and (Buildings[obj.Name] or obj.Name:match("^Rogue Camp %d+$") and "Cottage")
		local foot=key and obj:FindFirstChild("Foundation")
		if not foot or not foot:IsA("BasePart") then continue end
		local source=set.Meshes[key]
		local width,depth=foot.Size.X-2,foot.Size.Z-2
		place(obj,source,"Authored building shell",foot.Position+V(0,foot.Size.Y/2,0),
			V(width,14.1,depth),0)
		for _,child in ipairs(obj:GetChildren()) do
			if child:IsA("BasePart") and Surfaces[child.Name] then child.Transparency=1 end
		end
	end
end

local function regional(parent,n)
	local m=Instance.new("Model")
	m.Name=n
	m.Parent=parent
	return m
end

function Art.Dress(set,world,timber,frost)
	local root=Instance.new("Folder")
	root.Name="ProfessionalForestScenery"
	local t=regional(root,"Timber Haven")
	local c=regional(root,"Crystal Wilds")
	local f=regional(root,"Frostbound Reach")
	dressBuilding(set,timber)
	dressBuilding(set,frost)
	local decorations=timber:FindFirstChild("Timber Haven • trailworks")
	if decorations then
		for _,part in ipairs(decorations:GetChildren()) do
			if part:IsA("BasePart") and (part.Name:find("roof",1,true) or part.Name:find("Pavilion",1,true)
				or part.Name:find("Lodge eave",1,true) or part.Name=="Hewn timber column" or part.Name=="Ridgeline") then
				part.Transparency=1
			end
		end
	end
	props(set,t,{
		-- Haven village and Records Lodge. Open lane runs through the bridge to the boards.
		{"GateArch",V(2,0,-2991),0,V(18,10,1.7)},
		{"RecordsHall",V(8,0,-2921),0,V(76,16.3,10.5)},
		{"Cart",V(38,0,-2948),.56,V(4.6,3.2,2.8)},
		{"Fence",V(-35,0,-2954),0,V(11,2.6,1.1)},
		{"Fence",V(42,0,-2954),0,V(11,2.6,1.1)},
		{"Bridge",V(-5,-1.22,-2960),math.pi/2,V(13,2.8,8.5)},
		{"River",V(-21,.04,-2960),math.pi/2,V(5,.18,25)},
		{"River",V(18,.04,-2960),math.pi/2,V(5,.18,34)},
		{"Boulder",V(38,0,-2964),.3,V(4.5,1.8,3.8)},
		{"Lantern",V(-28,4.4,-2938),0,V(.7,1.35,.7)},
		{"Lantern",V(43,4.4,-2938),0,V(.7,1.35,.7)},
		{"GoldenOak",V(-39,0,-2934),.5,V(11,15,11)},
		{"Blossom",V(49,0,-2940),.8,V(9,12,9)},
		{"Fern",V(-39,0,-2938),.8,V(2.5,1.0,3.5)},
		{"Foxglove",V(43,0,-2945),.8,V(1.5,1.6,1.5)},
		-- Crafters' Plaza and Collectors' Row.
		{"MarketStall",V(47,0,-3113),-.2,V(7,6,5)},
		{"Cart",V(-49,0,-3124),.7,V(4.2,3,3)},
		{"Trail",V(2,.025,-3106),0,V(11,.12,15)},
		{"MarketStall",V(-129,0,-3034),math.pi/2,V(6,5,4)},
		{"Fern",V(-154,0,-3030),.32,V(2.2,1.6,2.5)},
		-- Forest trailheads and ridge details.
		{"TimberSign",V(142,0,-2969),.5,V(2.6,4,.25)},
		{"Boulder",V(120,0,-2976),.42,V(5,3,4)},
		{"NurseLog",V(22,0,-2858),.59,V(7,1.8,1.8)},
		{"GiantMushroom",V(-313,0,-2913),.4,V(3,2.8,3)},
		{"NurseLog",V(-314,0,-2910),.85,V(9,2,2)},
		{"Fern",V(-313,0,-2908),.58,V(3,2,3)},
		-- Kingsfall and the gate plaza.
		{"RuinedWall",V(-285,0,-3242),.3,V(6,6,2.8)},
		{"RuinedWall",V(-215,0,-3242),-.3,V(6,6,2.8)},
		{"Pavers",V(-250,.44,-3230),0,V(15,.12,15)},
		{"GateArch",V(228,0,-3221),0,V(12,11,2.5)},
		{"GateArch",V(271,0,-3221),0,V(12,11,2.5)},
		{"Cliff",V(337,-4,-3253),-.38,V(38,23,18)},
		{"Waterfall",V(347,-4,-3283),0,V(21,22,18)},
	})
	-- Keep the established Crystal forest and camera clear. Features hug the annex rim.
	props(set,c,{
		{"Crystal",V(2809,2,-15),.82,V(4,6,4)},
		{"CrystalSpine",V(2814,2,-20),.34,V(4,7,3)},
		{"Crystal",V(2955,0,-369),.12,V(8,10,5)},
		{"CrystalSpine",V(2951,0,-342),.5,V(7,13,6)},
		{"Crystal",V(2968,0,-311),.8,V(10,18,7)},
		{"CrystalSpine",V(3016,0,-304),.2,V(8,13,7)},
		{"Crystal",V(3044,0,-329),.62,V(8,13,7)},
		{"CrystalSpine",V(3048,0,-354),.3,V(6,8,6)},
		{"Waterfall",V(3047,-8,-397),.7,V(15,16,11)},
		{"RuinedWall",V(3023,0,-397),.2,V(6,8,3)},
		{"Pavers",V(3000,.44,-350),0,V(14,.12,14)},
	})
	props(set,f,{
		{"GateArch",V(5748,0,-26),0,V(16,11,2)},
		{"Fence",V(5790,0,23),.4,V(12,2.4,1.2)},
		{"Boulder",V(5775,0,-30),.62,V(5,3,5)},
		{"Lantern",V(5773,4,0),-.2,V(.72,1.4,.72)},
		{"Cliff",V(6100,-7,-285),.35,V(65,36,34)},
		{"Cliff",V(6168,-6,-292),.58,V(68,45,32)},
		{"Cliff",V(6227,-7,-286),-.2,V(61,38,36)},
		{"Cliff",V(6278,-6,-287),.2,V(62,42,32)},
		{"Waterfall",V(6241,-6,-272),.1,V(31,27,15)},
		{"Bridge",V(5950,-.89,-52),1.4,V(11,2.0,10)},
		{"WinterArch",V(6126,0,-217),math.pi/2,V(6,14,3)},
		{"WinterArch",V(6175,0,-220),math.pi/2,V(6,14,3)},
		{"CrystalSpine",V(6127,0,-213),.4,V(5,12,4)},
		{"CrystalSpine",V(6172,0,-214),-.4,V(5,12,4)},
		{"RuinedWall",V(6241,0,-88),.24,V(8,19,4)},
		{"RuinedWall",V(6284,0,-88),-.24,V(8,19,4)},
		{"WinterArch",V(6262,0,-79),0,V(23,18,3)},
		{"CrystalSpine",V(6240,0,-83),-.52,V(8,14,6)},
		{"Crystal",V(6280,0,-75),.41,V(8,15,7)},
		{"Pavers",V(6262,.45,-59),0,V(20,.14,20)},
	})
	root.Parent=world
end

return Art
