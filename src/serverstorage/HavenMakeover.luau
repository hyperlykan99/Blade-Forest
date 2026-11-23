-- HavenMakeover (Claude, Blade-Forest issue #1, M1 vertical slice).
-- Startup-only and reversible: clear Workspace attribute BladeHavenMakeover and restart.
-- Visual only: no colliders, rewards, tree rules, prompts or saves are changed.
local ServerStorage=game:GetService("ServerStorage")
local Players=game:GetService("Players")
local M={}
local V,R=Vector3.new,Color3.fromRGB
local terrain=workspace.Terrain

-- Timber Haven plateau footprint (from M4Layout: centre 0,0,-3000, 760 x 640, top at y=0).
local CENTER,SIZE=V(0,0,-3000),V(760,0,640)

local MAT=Enum.Material
local palette={
	[MAT.Grass]=R(124,164,70), [MAT.LeafyGrass]=R(112,152,66), [MAT.Ground]=R(146,116,80),
	[MAT.Mud]=R(110,88,64), [MAT.Cobblestone]=R(146,138,124), [MAT.Rock]=R(120,112,100),
}
-- Terrain sits 0.4 above the (still visible) plateau part, so there is no z-fighting and the
-- plain plateau remains a graceful fallback wherever terrain has not streamed in.
local TOP=.4
local LIFT=TOP+.02

local function rng(seed) return Random.new(seed) end

-- FillCylinder over-fills the top voxel (it raised soft mounds), so round shapes are built from
-- flush FillBlocks (octagon) and material-only patches use ReplaceMaterial.
local function flatDisc(x,z,radius,material)
	for _,a in ipairs({0,math.pi/4}) do
		terrain:FillBlock(CFrame.new(x,TOP-2,z)*CFrame.Angles(0,a,0),V(radius*1.66,4,radius*1.66),material)
	end
end
local function recolorPatch(x,z,radius,r,from,to)
	for _=1,4 do
		local cx,cz=x+r:NextNumber(-radius,radius)*.6,z+r:NextNumber(-radius,radius)*.6
		local hx,hz=r:NextNumber(.45,.9)*radius,r:NextNumber(.45,.9)*radius
		local reg=Region3.new(V(cx-hx,TOP-4,cz-hz),V(cx+hx,TOP+4,cz+hz)):ExpandToGrid(4)
		terrain:ReplaceMaterial(reg,4,from,to)
	end
end

local function flatPaint(cf,size,material)
	-- Fill a 4-stud slab whose top is flush with y=0 under the given footprint.
	local at=CFrame.new(cf.Position.X,TOP-2,cf.Position.Z)*(cf-cf.Position)
	terrain:FillBlock(at,V(size.X,4,size.Z),material)
end

-- Keep-clear test for tall decorated grass: paths, buildings, plazas and choppable forest stay readable.
local function clearZones(timber,layout)
	local segs,boxes,discs={},{},{}
	for _,p in ipairs(timber:GetChildren()) do
		if p:IsA("BasePart") and p.Name=="Packed trail" then
			local half=p.CFrame.LookVector*p.Size.Z/2
			table.insert(segs,{p.Position-half,p.Position+half,p.Size.X/2+16})
		end
	end
	for _,p in ipairs(timber:GetDescendants()) do
		if p:IsA("BasePart") and p.Name=="Foundation" then table.insert(discs,{p.Position,math.max(p.Size.X,p.Size.Z)/2+18}) end
	end
	if layout then
		for _,f in ipairs(layout.Timber.Forests or {}) do
			local w,d=f.Cols*f.Step/2+14,f.Rows*f.Step/2+14
			table.insert(boxes,{f.Center,w,d})
		end
		for i,dist in ipairs(layout.Timber.Districts or {}) do
			if i<=3 or i>=7 then table.insert(discs,{dist[2],i<=3 and 46 or 40}) end
		end
		table.insert(discs,{layout.Timber.Arrival,30})
	end
	return function(x,z)
		local p=V(x,0,z)
		for _,s in ipairs(segs) do
			local a,b=V(s[1].X,0,s[1].Z),V(s[2].X,0,s[2].Z)
			local ab=b-a
			local t=math.clamp((p-a):Dot(ab)/math.max(ab:Dot(ab),1e-3),0,1)
			if (a+ab*t-p).Magnitude<s[3] then return false end
		end
		for _,d in ipairs(discs) do if (V(d[1].X,0,d[1].Z)-p).Magnitude<d[2] then return false end end
		for _,b in ipairs(boxes) do if math.abs(x-b[1].X)<b[2] and math.abs(z-b[1].Z)<b[3] then return false end end
		return true
	end
end

local function ground(timber,stats)
	for m,c in pairs(palette) do terrain:SetMaterialColor(m,c) end
	-- 1. Living ground: a short leafy lawn everywhere, plus tall wind-blown meadow tufts only where
	--    they cannot hide paths, stations, drops or choppable trees.
	terrain:FillBlock(CFrame.new(CENTER.X,TOP-2,CENTER.Z),V(SIZE.X,4,SIZE.Z),MAT.LeafyGrass)
	local okLayout,layout=pcall(require,game:GetService("ReplicatedStorage"):WaitForChild("M4Layout"))
	local free=clearZones(timber,okLayout and layout or nil)
	local r=rng(1123)
	local tufts=0
	for i=1,900 do
		local x=CENTER.X+r:NextNumber(-SIZE.X/2+14,SIZE.X/2-14)
		local z=CENTER.Z+r:NextNumber(-SIZE.Z/2+14,SIZE.Z/2-14)
		if free(x,z) then
			recolorPatch(x,z,r:NextNumber(5,11),r,MAT.LeafyGrass,MAT.Grass)
			tufts+=1
			if tufts>=140 then break end
		end
		if i%150==0 then task.wait() end
	end
	stats.MeadowTufts=tufts
	local plateau=timber:FindFirstChild("Walkable plateau")
	if plateau then plateau.Color=palette[MAT.LeafyGrass] plateau.Material=MAT.Grass end
end

local HIDE_TRAIL={["Packed trail"]=true,["Painted trail cap"]=true}
local function paths(timber,scenery,stats)
	-- 2. Paths become worn earth carved into the grass, with soft shoulders.
	local n=0
	for _,p in ipairs(timber:GetChildren()) do
		if p:IsA("BasePart") and HIDE_TRAIL[p.Name] then
			local cf=p.CFrame
			if p.Name=="Packed trail" then
				flatPaint(cf,V(p.Size.X+5,0,p.Size.Z+2),MAT.LeafyGrass)
				flatPaint(cf,V(p.Size.X+1.5,0,p.Size.Z+1),MAT.Ground)
				flatPaint(cf,V(math.max(2,p.Size.X*.35),0,p.Size.Z),MAT.Mud)
			else
				flatDisc(cf.Position.X,cf.Position.Z,math.max(p.Size.X,p.Size.Z)/2+1,MAT.Ground)
			end
			p.Transparency=1
			n+=1
		end
	end
	stats.Trails=n
	-- Flat scenery (rivers, pavers, trail meshes, bridge) and building pads get grass-free ground beneath them.
	local pads=0
	local function under(part,material,margin)
		local cf,size=part.CFrame,part.Size
		if part.Position.Y-size.Y/2>1.5 then return end
		flatPaint(cf,V(size.X+margin,0,size.Z+margin),material)
		pads+=1
	end
	if scenery then
		for _,p in ipairs(scenery:GetDescendants()) do
			if p:IsA("BasePart") then
				local flat=p.Name=="River" or p.Name=="Pavers" or p.Name=="Trail" or p.Name=="Bridge"
				if p.Name=="River" then under(p,MAT.Mud,3)
				elseif flat then under(p,MAT.Ground,2) end
				-- Ground-hugging scenery rides on top of the new terrain surface (purely visual meshes).
				if flat and p.Position.Y-p.Size.Y/2<.6 then p.CFrame=p.CFrame+V(0,LIFT,0) end
			end
		end
	end
	for _,p in ipairs(timber:GetDescendants()) do
		if p:IsA("BasePart") and p.Name=="Foundation" then under(p,MAT.Cobblestone,3) end
	end
	stats.Pads=pads
	-- Arrival square and Crafters' Plaza read as cobbled village hearts.
	flatDisc(-20,-3000,15,MAT.Cobblestone)
	flatDisc(0,-3092,13,MAT.Cobblestone)
end

-- 3. Trail Guide keeper: a script-free R15 rig from ServerStorage.NPCModels, re-dressed as a friendly ranger.
local OUTFIT={
	UpperTorso=R(58,98,66), LowerTorso=R(96,64,40),
	LeftUpperArm=R(58,98,66), RightUpperArm=R(58,98,66), LeftLowerArm=R(70,112,76), RightLowerArm=R(70,112,76),
	LeftUpperLeg=R(188,164,120), RightUpperLeg=R(188,164,120), LeftLowerLeg=R(86,58,38), RightLowerLeg=R(86,58,38),
	LeftFoot=R(60,40,28), RightFoot=R(60,40,28),
}
local ANIM={Idle="rbxassetid://507766388",Wave="rbxassetid://507770239"}

local function plate(head,title,role)
	local bb=Instance.new("BillboardGui")
	bb.Name="HavenNameplate" bb.Size=UDim2.fromOffset(170,46) bb.StudsOffsetWorldSpace=V(0,2.35,0)
	bb.MaxDistance=42 bb.LightInfluence=0 bb.Adornee=head bb.Parent=head
	local t=Instance.new("TextLabel")
	t.BackgroundTransparency=1 t.Size=UDim2.new(1,0,.58,0) t.Text=title
	t.FontFace=Font.fromEnum(Enum.Font.FredokaOne) t.TextScaled=true t.TextColor3=R(255,232,168) t.Parent=bb
	local s=Instance.new("UIStroke") s.Color=R(36,24,16) s.Thickness=2 s.Parent=t
	local r=Instance.new("TextLabel")
	r.BackgroundTransparency=1 r.Position=UDim2.fromScale(0,.58) r.Size=UDim2.new(1,0,.42,0) r.Text=role
	r.FontFace=Font.fromEnum(Enum.Font.GothamBold) r.TextScaled=true r.TextColor3=R(214,236,196) r.Parent=bb
	local s2=Instance.new("UIStroke") s2.Color=R(26,40,28) s2.Thickness=1.5 s2.Parent=r
end

local function keeper(parent,at,facing,stats)
	local src=ServerStorage:FindFirstChild("NPCModels") and ServerStorage.NPCModels:FindFirstChild("RogueLumberjack")
	if not src then return end
	local npc=src:Clone()
	for _,d in ipairs(npc:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end -- defensive; the template has none
	end
	for _,d in ipairs(npc:GetChildren()) do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("BodyColors") or d:IsA("ShirtGraphic") then d:Destroy() end
	end
	npc.Name="Ranger Wren"
	for name,color in pairs(OUTFIT) do
		local p=npc:FindFirstChild(name)
		if p and p:IsA("BasePart") then p.Color=color end
	end
	local hum=npc:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath=false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false)
	for _,p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide=false p.CanTouch=false p.CanQuery=false p.Massless=true p.Anchored=false
		end
	end
	local root=npc:FindFirstChild("HumanoidRootPart")
	root.Anchored=true
	-- Lantern from the already-uploaded professional set, carried in the left hand.
	local lantern=ServerStorage:FindFirstChild("ProfessionalArtAssets") and ServerStorage.ProfessionalArtAssets:FindFirstChild("Lantern")
	local hand=npc:FindFirstChild("LeftHand")
	if lantern and hand then
		local l=lantern:Clone()
		l.Size=V(.8,1.5,.8) l.Anchored=false l.CanCollide=false l.CanQuery=false l.CanTouch=false l.Massless=true
		l.CFrame=hand.CFrame*CFrame.new(0,-.95,0)
		local w=Instance.new("WeldConstraint") w.Part0=hand w.Part1=l w.Parent=l
		local glow=Instance.new("PointLight") glow.Color=R(255,196,120) glow.Range=9 glow.Brightness=.9 glow.Shadows=false glow.Parent=l
		l.Name="Lantern" l.Parent=npc
	end
	npc:PivotTo(CFrame.lookAt(at,at+facing))
	-- Stand the feet exactly on the ground (y = at.Y is the floor height).
	local box,size=npc:GetBoundingBox()
	local lift=at.Y-(box.Position.Y-size.Y/2)
	npc:PivotTo(npc:GetPivot()+V(0,lift,0))
	at=root.Position
	npc:SetAttribute("HavenNPC","TrailGuide")
	npc:SetAttribute("HomeYaw",math.atan2(-facing.X,-facing.Z))
	npc.Parent=parent
	plate(npc:FindFirstChild("Head"),"Ranger Wren","Trail Guide")
	-- Rig-compatible stock R15 animations (Roblox catalog idle + wave).
	local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
	local tracks={}
	for k,id in pairs(ANIM) do
		local a=Instance.new("Animation") a.AnimationId=id
		local ok,track=pcall(function() return animator:LoadAnimation(a) end)
		if ok then tracks[k]=track end
	end
	if tracks.Idle then tracks.Idle.Looped=true tracks.Idle:Play(.3) end
	stats.NPC=npc:GetFullName()
	-- Nonverbal personality: turns to greet the nearest player and waves (server, 4 Hz, one rig).
	task.spawn(function()
		local lastWave,greeted=0,{}
		local home=CFrame.lookAt(at,at+facing)
		while npc.Parent do
			task.wait(.25)
			local best,dist=nil,22
			for _,pl in ipairs(Players:GetPlayers()) do
				local r=pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if r then
					local d=(r.Position-at).Magnitude
					if d<dist then best,dist=pl,d end
				end
			end
			local target=home
			if best then
				local p=best.Character.HumanoidRootPart.Position
				local flat=V(p.X,at.Y,p.Z)
				if (flat-at).Magnitude>1 then target=CFrame.lookAt(at,flat) end
				if dist<16 and tracks.Wave and os.clock()-lastWave>9 and (greeted[best] or 0)<os.clock()-25 then
					lastWave=os.clock() greeted[best]=os.clock()
					tracks.Wave:Play(.2)
				end
			end
			root.CFrame=root.CFrame:Lerp(target,.35)
		end
	end)
end

function M.Apply(active)
	local stats={}
	local pkg=active:FindFirstChild("TimberHaven")
	local timber=pkg and pkg:FindFirstChild("TimberHaven")
	assert(timber,"Timber Haven package not active")
	local sceneryRoot=active:FindFirstChild("ProfessionalForestScenery")
	local scenery=sceneryRoot and sceneryRoot:FindFirstChild("Timber Haven")
	local root=Instance.new("Folder") root.Name="HavenMakeover" root.Parent=active
	ground(timber,stats)
	paths(timber,scenery,stats)
	keeper(root,V(-40,TOP,-3044),V(0,0,-1),stats)
	for _,prompt in ipairs(timber:GetDescendants()) do
		-- Only station counters (OpenPanel); travel prompts keep their own portal controller.
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("OpenPanel")~=nil and prompt:GetAttribute("TravelTo")==nil then
			prompt.Style=Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("HavenCard",true)
			stats.Prompts=(stats.Prompts or 0)+1
		end
	end
	for k,v in pairs(stats) do root:SetAttribute(k,v) end
	return stats
end

return M
