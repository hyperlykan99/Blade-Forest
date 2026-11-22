-- Client cosmetics shared by blade, forest and encounter presentation.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local V=Vector3.new
local R=Color3.fromRGB
local CF=CFrame.new
local FX={}

FX.Mutations={
	Golden={R(255,192,78),R(255,238,158),"Glint"},
	Frozen={R(130,209,247),R(227,247,255),"Snow"},
	Shadow={R(142,76,213),R(66,43,102),"Dust"},
	Rainbow={R(145,238,225),R(251,167,218),"Glint"},
}
FX.Bosses={
	BladeKing={R(250,182,91),"Blade King","The fallen guard"},
	CrystalColossus={R(120,229,234),"Crystal Colossus","Warden of the split geode"},
	FrostMonarch={R(163,225,255),"Frost Monarch","The shattered crown"},
	TreantRaid={R(194,218,115),"Ancient Treant","The oldest roots awaken"},
	HydraRaid={R(166,137,248),"Crystal Hydra","Three voices beneath the stone"},
	GiantRaid={R(151,207,238),"Frost Giant","The glacier stirs"},
	HeartOfWinter={R(217,174,253),"Heart of Winter","Beyond the frozen gate"},
}
local pop={
	Chip={"sparkles_main.dds",.22,.39,7,13,.28,-23,88,.1},
	Leaf={"sparkles_main.dds",.35,.68,3,8,.24,-4,130,.1},
	Glint={"sparkles_main.dds",.38,.82,6,13,.38,4,95,.73},
	Snow={"sparkles_main.dds",.72,1.15,2,6,.29,-2,80,.25},
	Dust={"smoke_main.dds",.43,.90,4,10,.88,3,118,.08},
}
local folder
local pool={}
local rings={}
local budget,timestamp=90,0

function FX.Enabled()
	return workspace:GetAttribute("BladeForestArt")=="v1"
end
function FX.Quality()
	local level=player:GetAttribute("Pref_Graphics")
	return level=="Low" and 1 or level=="Medium" and 2 or 3
end
function FX.Reduced()
	return player:GetAttribute("Pref_ReducedMotion")==true
end
function FX.Near(pos,distance)
	local camera=workspace.CurrentCamera
	return camera and (camera.CFrame.Position-pos).Magnitude<=distance
end

local function root()
	if not folder then
		folder=Instance.new("Folder")
		folder.Name="ForestLocalEffects"
		folder.Parent=workspace
	end
	return folder
end

local function take(kind,now)
	for _,record in ipairs(pool) do
		if record.Kind==kind and now>=record.Ready then return record end
	end
	if #pool>=18 then
		for _,record in ipairs(pool) do
			if now>=record.Ready then
				record.Kind=kind
				return record
			end
		end
		return
	end
	local marker=Instance.new("Part")
	marker.Name="Pooled burst" marker.Size=V(.05,.05,.05) marker.Transparency=1
	marker.Anchored=true marker.CanCollide=false marker.CanTouch=false marker.CanQuery=false marker.CastShadow=false
	marker.Parent=root()
	local emitter=Instance.new("ParticleEmitter")
	emitter.Enabled=false emitter.Rate=0 emitter.LightInfluence=.35 emitter.LockedToPart=false
	emitter.Parent=marker
	local entry={Kind=kind,Marker=marker,Emitter=emitter,Ready=0}
	table.insert(pool,entry)
	return entry
end

function FX.Burst(kind,pos,color,count,distance)
	local q=FX.Quality()
	if not FX.Enabled() or q==1 or not FX.Near(pos,distance or 105) then return end
	local now=os.clock()
	budget=math.min(90,budget+math.min(2,now-timestamp)*45)
	timestamp=now
	if FX.Reduced() then count=math.min(count,4) elseif q==2 then count=math.ceil(count*.6) end
	count=math.min(count,math.floor(budget))
	if count<=0 then return end
	local entry=take(kind,now)
	if not entry then return end
	budget-=count
	local d=pop[kind]
	local e=entry.Emitter
	entry.Marker.CFrame=CF(pos)
	e.Texture=ReplicatedStorage:GetAttribute("ProfessionalForestVFX"..kind) or "rbxasset://textures/particles/"..d[1]
	e.Lifetime=NumberRange.new(d[2],d[3])
	e.Speed=NumberRange.new(d[4],d[5])
	e.Size=NumberSequence.new(d[6],0)
	e.EmissionDirection=Enum.NormalId.Top
	e.Acceleration=V(0,d[7],0)
	e.SpreadAngle=Vector2.new(d[8],d[8])
	e.LightEmission=d[9]
	e.Color=ColorSequence.new(color)
	e.Rotation=NumberRange.new(0,360)
	e.Transparency=NumberSequence.new(.14,1)
	entry.Ready=now+d[3]+.035
	e:Emit(count)
end

function FX.Ring(pos,color,radius,life)
	if not FX.Enabled() or not FX.Near(pos,115) or FX.Quality()<2 or FX.Reduced() then return end
	local now=os.clock()
	local record
	for _,r in ipairs(rings) do
		if now>=r.Ready then record=r break end
	end
	if not record then
		if #rings>=3 then return end
		local m=Instance.new("Folder") m.Name="Pooled ground pulse" m.Parent=root()
		local nodes={}
		for i=1,12 do
			local p=Instance.new("Part") p.Name="Pulse dash" p.Size=V(.22,.08,1)
			p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
			p.Material=Enum.Material.Neon p.Transparency=1 p.Parent=m
			nodes[i]=p
		end
		record={Nodes=nodes}
		table.insert(rings,record)
	end
	record.Ready=now+life+.05
	for i,p in ipairs(record.Nodes) do
		local a=i*math.pi/6
		local direction=V(math.cos(a),0,math.sin(a))
		local origin=pos+V(0,.25,0)
		local c0=origin+direction*radius*.44
		local c1=origin+direction*radius
		local tangent=V(-direction.Z,0,direction.X)
		p.CFrame=CFrame.lookAt(c0,c0+tangent)
		p.Color=color p.Transparency=.27 p.Size=V(.16,.095,math.max(.44,radius*.16))
		TweenService:Create(p,TweenInfo.new(life,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
			CFrame=CFrame.lookAt(c1,c1+tangent),
			Transparency=1,
		}):Play()
	end
end

function FX.TreeHit(pos,tree,weak,mine)
	if weak or not FX.Enabled() then return end
	local typeId=tree:GetAttribute("Rarity")
	local mutation=FX.Mutations[tree:GetAttribute("Mutation") or ""]
	local leaf=tree:GetAttribute("LeafColor") or R(121,150,75)
	local ore=tree:GetAttribute("Area")=="CrystalCanyon" or tree:GetAttribute("Area")=="FrostPeaks"
	local rare=typeId=="Legendary" or typeId=="Mythic" or typeId=="Secret" or typeId=="Divine"
	FX.Burst(ore and "Glint" or "Chip",pos,ore and (mutation and mutation[1] or R(157,216,244)) or R(198,139,77),mine and 4 or 2,80)
	if mine then FX.Burst(mutation and mutation[3] or "Leaf",pos,mutation and mutation[2] or leaf,rare and 5 or 3,85) end
end

function FX.TreeFall(pos,info,leaf)
	if not FX.Enabled() then return end
	local mutation=FX.Mutations[info.Mutation or ""]
	local high=info.Rarity=="Legendary" or info.Rarity=="Mythic" or info.Rarity=="Secret" or info.Rarity=="Divine"
	FX.Burst("Dust",pos,R(155,124,88),high and 7 or 4)
	FX.Burst(mutation and mutation[3] or "Leaf",pos,mutation and mutation[1] or leaf or R(157,166,100),high and 11 or 5)
	if high or mutation then
		local color=mutation and mutation[2] or leaf or R(255,210,119)
		FX.Burst("Glint",pos+V(0,1.3,0),color,info.Rarity=="Secret" and 17 or 10)
		if info.Killer==player.UserId then FX.Ring(pos,color,high and 8 or 5,.55) end
	end
end
return FX
