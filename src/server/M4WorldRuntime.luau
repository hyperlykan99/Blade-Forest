-- Startup-only reversible switch. The editor keeps the original scene and staged package.
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
local runtime={Active=false,Crystal=false}
local staged=ServerStorage:FindFirstChild("M4WorldSource")
if not staged or staged:GetAttribute("Verified")~=true then return runtime end
local breakables=workspace:WaitForChild("Breakables")
local active=Instance.new("Folder") active.Name="M4ActiveWorld" active.Parent=workspace
local annex=staged:FindFirstChild("CrystalWilds")
if annex then
	annex.Parent=active
	runtime.Crystal=true
end
if not layout.Enabled() then return runtime end
local timber, frost=staged:FindFirstChild("TimberHaven"),staged:FindFirstChild("FrostboundReach")
assert(timber and frost and runtime.Crystal,"Incomplete M4 package; keep legacy layout")
local templates=ReplicatedStorage:WaitForChild("TreeModels")
local builder=require(ServerStorage:WaitForChild("M4Construction"))
local architecture=require(ServerStorage:WaitForChild("M4Architecture"))
local config=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local landscape, visuals, artPlan, artStyle, artStats
local professional, professionalModule
if workspace:GetAttribute("BladeTimberArt")=="v1" then
	local ok,reason=pcall(function()
		local planner=require(ServerStorage.TimberLandscape)
		local plan,stats=planner.Plan(timber,layout)
		assert(plan,("Could not replant %s at %s"):format(tostring(stats.Unplaced),tostring(stats.At)))
		if workspace:GetAttribute("BladeForestAssetArt")=="v1" then
			local available,pack=pcall(function()
				professionalModule=require(ServerStorage.ProfessionalForest)
				return professionalModule.Prepare(ServerStorage:FindFirstChild("ProfessionalArtAssets"))
			end)
			if available and pack then professional=pack end
			if not available then warn("Keeping recorded art build:",pack) end
		end
		local treeArt=require(ServerStorage.TimberVisuals)
		local assets=ServerStorage:FindFirstChild("TimberArtAssets")
		local crowns={}
		if professional then
			crowns=professional.Templates
			artStyle=professional.Apply
		else
			for id in pairs(treeArt.Recipes) do
				local visual=treeArt.Visual(id,assets)
				visual.Name="TimberArt_"..id
				crowns[id]=visual
			end
			artStyle=function(tree) treeArt.Apply(tree,assets,crowns) end
		end
		landscape,visuals,artPlan,artStats=planner,crowns,plan,stats
	end)
	if not ok then warn("Keeping staged Timber art:",reason) end
end
local archived=Instance.new("Folder") archived.Name="M4RuntimeLegacyArchive" archived.Parent=ServerStorage
local function archive(name)
	local f=Instance.new("Folder") f.Name=name f.Parent=archived return f
end
local oldTemplates=archive("TreeTemplates")
local oldTrees,oldSpawns,oldIslands=archive("Breakables"),archive("Spawns"),archive("IslandShells")
for i,obj in ipairs(breakables:GetChildren()) do
	if obj:IsA("Model") or obj:IsA("BasePart") then
		local pos=obj:GetPivot().Position
		-- All the old breakables west of Crystal Wilds belong to the original starter region.
		if pos.X<1000 and math.abs(pos.Z)<1000 then obj.Parent=oldTrees end
	end
	if i%350==0 then task.wait() end
end
for _,obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") and obj.Position.X<1000 and math.abs(obj.Position.Z)<1000 then obj.Parent=oldSpawns end
end
local islands=workspace:WaitForChild("Islands")
for _,id in ipairs({"TimberHaven","FrostboundReach"}) do
	local obj=islands:FindFirstChild(id)
	if obj then obj.Parent=oldIslands end
end
if artPlan then
	for _,visual in pairs(visuals) do visual.Parent=templates end
	for i,entry in ipairs(artPlan) do
		local frame=entry.Tree:GetPivot()
		entry.Tree:PivotTo(CFrame.new(entry.New.X,frame.Position.Y,entry.New.Z)*frame.Rotation)
		artStyle(entry.Tree)
		if i%120==0 then task.wait() end
	end
	builder.SetTreeStyle(artStyle,professional~=nil)
	for key,value in pairs(artStats) do active:SetAttribute("TimberArt"..key,value) end
end
for _,package in ipairs({timber,frost}) do
	local container=package:FindFirstChild("Trees")
	assert(container)
	package.Parent=active
	local n=0
	for _,plot in ipairs(container:GetChildren()) do
		for _,tree in ipairs(plot:GetChildren()) do
			if professional and package==frost then artStyle(tree) end
			tree.Parent=breakables n+=1
			if n%220==0 then task.wait() end
		end
	end
end
-- The inventoried Map children are geographically all in the old starter region.
-- Move its interactive leaderboards within the same folder, which the existing
-- server reads by path. Native Terrain stays physically intact for legacy mode.
local map=workspace:WaitForChild("Map")
local oldMap=archive("Map")
for _,obj in ipairs(map:GetChildren()) do
	if obj.Name~="Leaderboards" then obj.Parent=oldMap end
end
local boardFolder=map:FindFirstChild("Leaderboards")
if landscape then
	landscape.Dress(timber,boardFolder,architecture,visuals)
elseif boardFolder then
	local boards=boardFolder:GetChildren()
	table.sort(boards,function(a,b) return a.Name<b.Name end)
	for i,board in ipairs(boards) do
		if board:IsA("Model") then
			local old=board:GetPivot()
			local center=layout.Timber.Districts[1][2]
			local at=center+Vector3.new((i-2)*16,old.Position.Y,20)
			board:PivotTo(CFrame.new(at)*old.Rotation)
		end
	end
end
-- Runtime spawns are placed only once, in the replacement Haven Village.
for _,offset in ipairs({Vector3.new(-10,0,0),Vector3.new(10,0,0),Vector3.new(0,0,-12),Vector3.new(0,0,12)}) do
	local p=Instance.new("SpawnLocation")
	p.Name="Haven Spawn" p.Anchored=true p.CanCollide=false p.CanTouch=false
	p.Neutral=true p.Transparency=1 p.Size=Vector3.new(5,.5,5)
	p.Position=layout.Timber.Arrival+offset-Vector3.new(0,4.75,0) p.Parent=active
end
local oldMythic=templates:FindFirstChild("Frost_Mythic_1")
if oldMythic then oldMythic.Parent=oldTemplates end
local optimized=builder.Tree("Frost_Mythic",CFrame.new(),1,config,architecture,1.35)
optimized.Name="Frost_Mythic_1"
optimized:SetAttribute("IsTree",nil)
optimized:SetAttribute("LeafColor",Color3.fromRGB(194,147,251))
optimized.Parent=templates
for name,id in pairs({M4TimberTree="Grove_Common",M4SnowTree="Frost_Common"}) do
	local visual=builder.Tree(id,CFrame.new(),1,config,architecture,1)
	visual.Name=name
	visual:SetAttribute("IsTree",nil)
	visual:SetAttribute("TreeType",nil) -- visual-only; keep the existing rarity pools
	visual:SetAttribute("LeafColor",visual:FindFirstChild("Canopy 1").Color)
	visual.Parent=templates
end
if workspace:GetAttribute("BladeForestArt")=="v1" then
	local ok,err=pcall(function()
		if professional then
			professionalModule.Dress(professional,active,timber.TimberHaven,frost.FrostboundReach)
			for channel,value in pairs(professional.Textures) do
				ReplicatedStorage:SetAttribute("ProfessionalForestVFX"..channel,value)
			end
		else
			require(ServerStorage.ForestScenery).Build(active,timber.TimberHaven,frost.FrostboundReach,layout,breakables)
		end
		for _,tree in ipairs(breakables:GetChildren()) do
			if tree:GetAttribute("Mutation") then
				tree:AddTag("ForestMutation")
				local marker=tree.PrimaryPart and tree.PrimaryPart:FindFirstChild("MutationFX")
				if marker then marker:Destroy() end
			end
		end
	end)
	if not ok then warn("Forest scenery:",err) end
end
if professional and workspace:GetAttribute("BladeForestHorizons")=="v1" then
	local success, reason = pcall(function()
		require(ServerStorage.WorldHorizon).Build(active, ServerStorage.ProfessionalArtAssets)
	end)
	if not success then warn("World horizons:", reason) end
end
runtime.Active=true
return runtime
