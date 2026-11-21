-- Arena lease and authoritative scoring for both solo modes. Only CombatServer can score a hit.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local M6Inventory=require(ReplicatedStorage:WaitForChild("M6Inventory"))
local C=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
local Data=require(script.Parent:WaitForChild("DataService"))
local State=require(script.Parent:WaitForChild("M5State"))
local Rewards=require(script.Parent:WaitForChild("M5Rewards"))
local Board=require(script.Parent:WaitForChild("M5Boards"))
local Guard=require(script.Parent:WaitForChild("MovementGuard")).shared
local Tree=require(Storage:WaitForChild("M4Construction"))
local Art=require(Storage:WaitForChild("M4Architecture"))
local notify=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
local v=Vector3.new
local arenas=Instance.new("Folder")
arenas.Name="M5RunArenas"
arenas.Parent=workspace
local R={Root=arenas,PartyCapacity=1}
local active,slots={},{}

local function clearAttributes(p)
	for _,name in ipairs({"M5Run","M5RunPhase","M5RunEnds","M5RunScore","M5RunDepth","M5RunTrees","M5RunOrigin"}) do
		p:SetAttribute(name,nil)
	end
	Data.RecalcMultipliers(p)
end
local function reserve()
	local i=1
	while slots[i] do i+=1 end
	slots[i]=true
	return i
end
local function color(job)
	return job.Kind=="Trial" and Color3.fromRGB(109,148,96) or Color3.fromRGB(128,174,207)
end
local function buildArena(job)
	local arena=Instance.new("Model")
	job.Arena=arena
	arena.Name="Private "..job.Kind.." "..job.Slot
	arena.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
	local at=job.Center
	local ground=Art.Part(arena,"Run arena",v(108,2,108),CFrame.new(at-v(0,1,0)),color(job),Enum.Material.Slate,true)
	arena.PrimaryPart=ground
	for i=1,4 do
		local r=(i-1)*math.pi/2
		Art.Part(arena,"Arena border",v(108,6,2),CFrame.new(at)*CFrame.Angles(0,r,0)*CFrame.new(0,2,53),color(job),Enum.Material.Rock,true)
	end
	for i=1,4 do
		local a=(i-1)*math.pi/2+math.pi/4
		local point=at+v(math.cos(a)*54,3.1,math.sin(a)*54)
		Art.Part(arena,"Run beacon",v(1.3,5.8,1.3),CFrame.new(point),Color3.fromRGB(160,246,249),Enum.Material.Neon)
	end
	local trees=Instance.new("Folder")
	trees.Name="RunTrees"
	trees.Parent=arena
	arena.Parent=arenas
	job.Arena,job.Trees=arena,trees
end

local function spawnTree(job,index)
	local exp=job.Kind=="Expedition"
	local ids=exp and {"Frost_Common","Frost_Uncommon","Frost_Rare","Frost_Epic"} or {"Grove_Common","Pine_Common","Crystal_Common"}
	local id=exp and ids[(index+job.Depth-2)%#ids+1] or ids[job.Tier]
	local gridColumns=4
	local x=((index-1)%gridColumns-1.5)*13
	local z=(math.floor((index-1)/gridColumns)-1)*13
	local angle=(job.Depth+job.Score+index)%4*math.pi/2
	local spot=job.Center+v(x,0,z)
	local obj=Tree.Tree(id,CFrame.new(spot)*CFrame.Angles(0,angle,0),.78,C,Art,1)
	local health=exp and math.floor(M.DepthHealth(job.Depth)*(index==1 and job.Depth>=8 and 1.6 or 1)) or ({4,6,8})[job.Tier]
	obj.Name=exp and "Frostwood · "..job.Depth or "Trial timber"
	obj:SetAttribute("M5Target",job.Player.UserId)
	obj:SetAttribute("Strength",nil)
	obj:SetAttribute("Health",health)
	obj:SetAttribute("MaxHealth",health)
	obj:SetAttribute("TreeName",obj.Name)
	obj:SetAttribute("Reward",0)
	job.Targets[obj]=index
	obj.Parent=job.Trees
end
local function populate(job)
	local n=job.Kind=="Trial" and 12 or M.DepthTrees(job.Depth)
	job.Remaining=n
	for i=1,n do spawnTree(job,i) end
	job.Player:SetAttribute("M5RunTrees",n)
end
local function pushPhase(job,phase)
	job.Phase=phase
	job.Player:SetAttribute("M5RunPhase",phase)
end
local function dispose(job)
	local p=job.Player
	if active[p]~=job then return end
	active[p]=nil
	slots[job.Slot]=nil
	if job.Arena then job.Arena:Destroy() end
	if p.Parent then clearAttributes(p) end
end

local function writeBoard(p,week,kind,value)
	if value<=0 then return end
	Board.Record(week,kind,p.UserId,value,false)
	task.spawn(function()
		if Data.SaveNow(p) then Board.Record(week,kind,p.UserId,value,true) end
	end)
end

local finish
finish=function(job,reason,returnPlayer)
	local p=job.Player
	if active[p]~=job or job.Closing then return end
	job.Closing=true
	pushPhase(job,"Returning")
	local d=Data.Get(p)
	if d and reason=="Finished" and job.Kind=="Trial" then
		local now=os.time()
		local w=State.Weekly(d,now)
		local budget=State.Budget(d,now)
		local rank=M.TrialRank(job.Tier,job.Score)
		d.M5.TrialFinishes+=1
		local tokens=math.min(M.Trial.Tokens[rank] or 0,math.max(0,M.Trial.TokenCap-budget.Tokens))
		budget.Tokens+=tokens
		d.M5.Tokens+=tokens
		local best=job.Score>w.Trial
		w.Trial=math.max(w.Trial,job.Score)
		d.M6.TrialBest=math.max(d.M6.TrialBest,job.Score)
		Data.Sync(p)
		if best then writeBoard(p,w.Key,"Trial",w.Trial) end
		notify:FireClient(p,string.format("Trial finished · %s · %d trees · +%d Tokens",M.Trial.Ranks[rank] or "Unranked",job.Score,tokens),"rare_Epic")
	elseif job.Kind=="Expedition" and job.BoardDirty and d then
		local w=State.Weekly(d,os.time())
		writeBoard(p,w.Key,"Depth",w.Depth)
	end
	if returnPlayer and p.Parent and p.Character==job.Character and p.Character:FindFirstChild("HumanoidRootPart") then
		local call=Storage:FindFirstChild("M5Return")
		for _=1,2 do
			local called,ok=false,false
			if call then called,ok=pcall(call.Invoke,call,p,job.Island) end
			if called and ok then break end
			if not p.Parent or p.Character~=job.Character then break end
			task.wait(.35)
		end
		if p.Character==job.Character and (p.Character:GetPivot().Position-job.Center).Magnitude<85 then
			-- Guaranteed recovery through the normal authoritative CharacterAdded path.
			local hum=p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health=0 end
		end
	end
	dispose(job)
end

local function depthComplete(job)
	local p=job.Player
	local d=Data.Get(p)
	if not d then return end
	local now=os.time()
	local w=State.Weekly(d,now)
	local budget=State.Budget(d,now)
	local frontier=job.Depth>w.Depth
	d.M5.DepthEver=math.max(d.M5.DepthEver,job.Depth)
	w.Depth=math.max(w.Depth,job.Depth)
	job.BoardDirty=job.BoardDirty or frontier
	if frontier and budget.DepthClaims<M.Expedition.RewardClaimsPerDay then
		budget.DepthClaims+=1
		local reward=M.DepthReward(job.Depth)
		reward.Material=M.Expedition.Material
		if job.Depth%3==0 then
			M6Inventory.AddRune(d,M6Inventory.RollRune(job.Depth>=15 and 4 or job.Depth>=9 and 3 or 2,Random.new()),1)
		end
		Rewards.Grant(p,d,reward,"Expedition depth "..job.Depth.." cleared")
	else
		Data.Sync(p)
	end
	pushPhase(job,"DepthClear")
	p:SetAttribute("M5RunTrees",0)
end

function R.Deal(player,target,damage)
	if target:GetAttribute("M5Target")==nil then return false end
	if not player then return true end
	local job=active[player]
	local index=job and job.Targets[target]
	if not job or not index or target:GetAttribute("M5Target")~=player.UserId or job.Phase~="Active"
		or player.Character~=job.Character or os.clock()>=job.Deadline or player:GetAttribute("Handoff") then return true end
	local root=player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position-job.Center).Magnitude>87 then return true end
	local hp=target:GetAttribute("Health") or 0
	if hp<=0 then return true end
	local hits=job.Kind=="Trial" and 4 or math.clamp(damage,0,1e9)
	target:SetAttribute("Health",hp-hits)
	if hp<=hits then
		job.Targets[target]=nil
		target:Destroy()
		job.Score+=1
		player:SetAttribute("M5RunScore",job.Score)
		if job.Kind=="Trial" then
			task.delay(1.6,function()
				if active[player]==job and job.Phase=="Active" and os.clock()<job.Deadline then
					spawnTree(job,index)
				end
			end)
		else
			job.Remaining-=1
			player:SetAttribute("M5RunTrees",job.Remaining)
			if job.Remaining==0 then depthComplete(job) end
		end
	end
	return true
end

function R.Enter(player,kind)
	if kind~="Trial" and kind~="Expedition" then return false,"Unknown run" end
	if active[player] or player:GetAttribute("M5Run") then return false,"Finish your current run first" end
	local d=Data.Get(player)
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	local island=player:GetAttribute("CurrentIsland")
	if not d or not player:GetAttribute("Loaded") or not C.IslandById[island] or not root or not hum or hum.Health<=0
		or player:GetAttribute("Handoff") or player:GetAttribute("IslandArrivalPending")
		or player:GetAttribute("IslandTravelling") or (player:GetAttribute("CombatUntil") or 0)>workspace:GetServerTimeNow() then
		return false,"Return to a safe island area first"
	end
	if kind=="Expedition" and (not Layout.Enabled() or island~="FrostboundReach"
		or not d.UnlockedIslands.FrostboundReach or (player:GetAttribute("Power") or 0)<C.GetIslandRequiredPower(C.IslandById.FrostboundReach)
		or (root.Position-M.Expedition.Entry).Magnitude>18) then
		return false,"Enter from the Frostbound Expedition Gate"
	end
	local slot=reserve()
	local job={Kind=kind,Slot=slot,Tier=M.IslandTier(d.UnlockedIslands),Phase="Loading",Island=island,
		Player=player,Character=char,Depth=1,Score=0,Targets={},Deadline=math.huge,
		Center=v(15000+((slot-1)%8)*M.Expedition.SlotStride,60,6000+math.floor((slot-1)/8)*M.Expedition.SlotStride)}
	active[player]=job
	player:SetAttribute("M5Run",kind)
	player:SetAttribute("M5RunOrigin",island)
	Data.RecalcMultipliers(player)
	pushPhase(job,"Loading")
	local built,issue=pcall(function()
		buildArena(job)
		populate(job)
	end)
	if not built then
		dispose(job)
		warn("[M5] Arena construction failed: "..tostring(issue))
		return false,"Arena could not be constructed"
	end
	local streamed=pcall(player.RequestStreamAroundAsync,player,job.Center,7)
	if not streamed or active[player]~=job or player.Character~=char or hum.Health<=0 or not player.Parent then
		dispose(job)
		return false,"Arena could not load"
	end
	local at=job.Center+v(0,4,28)
	Guard:Allow(player,3,nil,at,root.Position)
	root.AssemblyLinearVelocity=v(0,0,0)
	root.AssemblyAngularVelocity=v(0,0,0)
	char:PivotTo(CFrame.new(at))
	local seconds=kind=="Trial" and M.Trial.Seconds or M.Expedition.Seconds
	job.Deadline=os.clock()+seconds
	player:SetAttribute("M5RunEnds",workspace:GetServerTimeNow()+seconds)
	player:SetAttribute("M5RunDepth",job.Depth)
	player:SetAttribute("M5RunScore",0)
	Data.ApplyMovement(player)
	pushPhase(job,"Active")
	task.delay(seconds,function() if active[player]==job then finish(job,"Finished",true) end end)
	hum.Died:Once(function() if active[player]==job then finish(job,"Death",false) end end)
	return true
end

function R.Next(player)
	local j=active[player]
	if not j or j.Kind~="Expedition" or j.Phase~="DepthClear" or os.clock()>=j.Deadline then return false,"Clear this depth first" end
	j.Depth+=1
	player:SetAttribute("M5RunDepth",j.Depth)
	populate(j)
	pushPhase(j,"Active")
	return true
end

function R.Exit(player)
	local job=active[player]
	if not job or job.Phase=="Loading" or job.Closing then return false,"No active run to exit" end
	finish(job,"Exit",true)
	return true
end

function R.PartyExtension() return { Capacity=R.PartyCapacity, Availability="Solo" } end
local function bind(player)
	player.CharacterRemoving:Connect(function(char)
		local job=active[player]
		if job and job.Character==char then
			if job.Closing then dispose(job) else finish(job,"Death",false) end
		end
	end)
end
Players.PlayerAdded:Connect(bind)
for _,p in ipairs(Players:GetPlayers()) do bind(p) end
Players.PlayerRemoving:Connect(function(p)
	local job=active[p]
	if job then dispose(job) end
end)
return R
