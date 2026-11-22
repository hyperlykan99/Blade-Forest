-- Builds an editable, deterministic private-place package. No legacy geometry is edited.
local W = {}
local V = Vector3.new
local cf = CFrame.new
local palette = {
	Common=Color3.fromRGB(72,147,91), Uncommon=Color3.fromRGB(121,170,81), Rare=Color3.fromRGB(199,129,63),
	Epic=Color3.fromRGB(177,75,98), Legendary=Color3.fromRGB(246,194,76), Mythic=Color3.fromRGB(180,115,231),
	Secret=Color3.fromRGB(242,231,185),
}
local frostPalette = {
	Common=Color3.fromRGB(179,207,222), Uncommon=Color3.fromRGB(109,172,197), Rare=Color3.fromRGB(108,184,229),
	Epic=Color3.fromRGB(130,135,221), Legendary=Color3.fromRGB(94,228,214), Mythic=Color3.fromRGB(194,147,251),
	Secret=Color3.fromRGB(230,242,255),
}

local function folder(parent,name)
	local f=Instance.new("Folder") f.Name=name f.Parent=parent return f
end
local function model(name)
	local m=Instance.new("Model") m.Name=name return m
end
local function leaf(m,A,id,n,size,at,c,shape)
	local p=A.Part(m,id,size,at,c,Enum.Material.SmoothPlastic,false,shape)
	p:SetAttribute("LeafColor",c)
	p.CanQuery=true -- camera occlusion inspects canopy parts
	p:SetAttribute("Leaf",true)
	return p
end

function W.Tree(id, at, scale, config, A, boost)
	local tt=assert(config.TreeTypes[id],id)
	local frost=tt.Area=="FrostPeaks"
	local rar=config.RarityById[tt.Rarity].Order
	local tall=(frost and 12.5 or 10.5)+rar*1.35
	local m=model(id)
	local bark=frost and Color3.fromRGB(95,125,143) or Color3.fromRGB(100,62,38)
	local trunk=A.Part(m,"Trunk",V(1.45,tall,1.45),at*cf(0,tall/2,0),bark,Enum.Material.Wood,true)
	local hit=A.Part(m,"Hitbox",V(2.55,tall,2.55),at*cf(0,tall/2,0),bark,Enum.Material.SmoothPlastic)
	hit.Transparency=1 hit.CanQuery=true hit.PivotOffset=cf(0,-tall/2,0)
	m.PrimaryPart=hit
	local colors=frost and frostPalette or palette
	local color=colors[tt.Rarity]
	for i=1,3 do
		local w=(7+(rar-1)*.22)-(i-1)*1.25
		local y=tall*.61+(i-1)*tall*.19
		local canopy=leaf(m,A,"Canopy "..i,i,V(w,4.7-i*.35,w*.88),
			at*cf((i-2)*.44,y,0)*CFrame.Angles(0,i*.6,frost and .17 or .10),
			color:Lerp(i%2==0 and Color3.new(1,1,1) or Color3.new(.24,.38,.48),.12),Enum.PartType.Ball)
		if frost and rar>=5 and i==3 then canopy.Material=Enum.Material.Ice end
	end
	for k,v in pairs({ IsTree=true, Kind=id, TreeType=id, Rarity=tt.Rarity, TreeName=tt.Name, Strength=tt.Strength,
		Health=tt.Health, MaxHealth=tt.Health, Reward=math.floor(tt.Logs*(boost or 1)), Respawn=tt.Respawn,
		Area=tt.Area, Template=frost and "M4SnowTree" or "M4TimberTree", M4Tree=true }) do m:SetAttribute(k,v) end
	if scale~=1 then m:ScaleTo(scale) end
	m:PivotTo(at)
	return m
end

local treeStyle, frostStyle

function W.SetTreeStyle(style,includeFrost)
	treeStyle,frostStyle=style,includeFrost
end

function W.Regrow(area,at,config,architecture,treekit)
	local treeType=config.PickTreeType(area)
	local boost=area=="FrostPeaks" and 1.35 or 1
	local tree=W.Tree(treeType.Id,at,0.86+math.random()*.24,config,architecture,boost)
	if treeStyle and (frostStyle or area~="FrostPeaks") then treeStyle(tree) end
	local mutation=config.RollMutation()
	if mutation then
		treekit.Mutate(tree,mutation.Id)
		tree:SetAttribute("Reward",math.floor(tree:GetAttribute("Reward")*boost))
		-- Restrict emitters to late mutations in the high-density build.
		if mutation.Id~="Shadow" and mutation.Id~="Rainbow" then
			local fx=tree.PrimaryPart:FindFirstChild("MutationFX")
			if fx then fx:Destroy() end
		end
	end
	return tree
end

local function plots(out,plan,config,A,seed)
	local rng=Random.new(seed)
	local frost=plan.Id=="FrostboundReach"
	local byArea={}
	for id,def in pairs(config.TreeTypes) do
		byArea[def.Area]=byArea[def.Area] or {}
		table.insert(byArea[def.Area],id)
	end
	for _,types in pairs(byArea) do
		table.sort(types,function(a,b)
			return config.RarityById[config.TreeTypes[a].Rarity].Order < config.RarityById[config.TreeTypes[b].Rarity].Order
		end)
	end
	for index,plot in ipairs(plan.Forests) do
		local result=folder(out,plan.Districts[plot.District][1].." "..index)
		local ids=byArea[plot.Area]
		local boost=frost and 1.35 or 1
		for i=1,plot.Count do
			local col=(i-1)%plot.Cols
			local row=math.floor((i-1)/plot.Cols)
			local px=(col-(plot.Cols-1)/2)*plot.Step+rng:NextNumber(-.63,.63)
			local pz=(row-(plot.Rows-1)/2)*plot.Step+rng:NextNumber(-.63,.63)
			-- Seed every legacy category once across the first plot of its area.
			local id=(i<=#ids and (index==1 or (not frost and index==3))) and ids[i] or config.PickTreeType(plot.Area,rng).Id
			local at=cf(plot.Center+V(px,0,pz))*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)
			W.Tree(id,at,rng:NextNumber(.86,1.1),config,A,boost).Parent=result
			if i%100==0 then task.wait() end
		end
	end
end

function W.BuildBatch(root,batch,config,layout,A)
	if batch=="Timber" then
		assert(not root:FindFirstChild("TimberHaven"))
		local building=folder(root,"TimberHaven")
		A.BuildIsland(building,layout.Timber,layout)
		plots(folder(building,"Trees"),layout.Timber,config,A,441028)
	elseif batch=="Frost" then
		assert(not root:FindFirstChild("FrostboundReach"))
		local building=folder(root,"FrostboundReach")
		A.BuildIsland(building,layout.Frost,layout)
		plots(folder(building,"Trees"),layout.Frost,config,A,740013)
	elseif batch=="Crystal" then
		assert(not root:FindFirstChild("CrystalWilds"))
		A.BuildCrystal(folder(root,"CrystalWilds"),layout)
	else
		error("Unknown M4 build batch")
	end
end
return W
