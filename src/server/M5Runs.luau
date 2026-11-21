-- Arena lease and authoritative scoring for both solo modes. Only CombatServer can score a hit.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local FinalState=require(script.Parent:WaitForChild("M8State"))
local Guilds=require(script.Parent:WaitForChild("M7Guilds"))
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
local R={Root=arenas,PartyCapacity=4}
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
	local health=exp and math.floor(M.DepthHealth(job.Depth)*job.Scale*(index==1 and job.Depth>=8 and 1.6 or 1)) or ({4,6,8})[job.Tier]
	obj.Name=exp and "Frostwood · "..job.Depth or "Trial timber"
	obj:SetAttribute("M5Target",job.Slot)
	obj:SetAttribute("Strength",nil)
	obj:SetAttribute("Health",health)
	obj:SetAttribute("MaxHealth",health)
	obj:SetAttribute("TreeName",obj.Name)
	obj:SetAttribute("Reward",0)
	job.Targets[obj]=index
	obj.Parent=job.Trees
end
local function setAll(job,key,value)
	for p in pairs(job.Participants) do if p.Parent then p:SetAttribute(key,value) end end
end
local function populate(job)
	local n=job.Kind=="Trial" and 12 or M.DepthTrees(job.Depth)
	job.Remaining=n
	job.Participation={} job.DepthDamage=0
	for i=1,n do spawnTree(job,i) end
	setAll(job,"M5RunTrees",n)
end
local function pushPhase(job,phase)
	job.Phase=phase
	setAll(job,"M5RunPhase",phase)
end
local function remove(job,p)
	if active[p]~=job then return end
	active[p]=nil
	job.Participants[p]=nil
	if p.Parent then clearAttributes(p) end
	if next(job.Participants)==nil then
		slots[job.Slot]=nil
		if job.Arena then job.Arena:Destroy() end
	else
		if job.Player==p then
			for _,peer in ipairs(job.Order) do if job.Participants[peer] then job.Player=peer break end end
		end
		if job.Kind=="Expedition" then
			local remaining=0
			for _ in pairs(job.Participants) do remaining+=1 end
			job.Scale=1+.55*(remaining-1)
		end
	end
end

local function writeBoard(p,week,kind,value)
	if value<=0 then return end
	Board.Record(week,kind,p.UserId,value,false)
	task.spawn(function()
		if Data.SaveNow(p) then Board.Record(week,kind,p.UserId,value,true) end
	end)
end

local function finish(job,p,reason,returnPlayer)
	local member=job.Participants[p]
	if active[p]~=job or not member or member.Closing then return end
	member.Closing=true
	if p.Parent then p:SetAttribute("M5RunPhase","Returning") end
	local d=Data.Get(p)
	if d and reason=="Finished" and job.Kind=="Trial" then
		local now=os.time()
		local w=State.Weekly(d,now)
		local budget=State.Budget(d,now)
		local rank=M.TrialRank(job.Tier,job.Score)
		d.M5.TrialFinishes+=1
		if rank>0 and job.Score>0 then FinalState.Record(d,"Trials",1,now) end
		local tokens=math.min(M.Trial.Tokens[rank] or 0,math.max(0,M.Trial.TokenCap-budget.Tokens))
		budget.Tokens+=tokens
		d.M5.Tokens+=tokens
		local best=job.Score>w.Trial
		w.Trial=math.max(w.Trial,job.Score)
		d.M6.TrialBest=math.max(d.M6.TrialBest,job.Score)
		Data.Sync(p)
		if best then writeBoard(p,w.Key,"Trial",w.Trial) end
		notify:FireClient(p,string.format("Trial finished · %s · %d trees · +%d Tokens",M.Trial.Ranks[rank] or "Unranked",job.Score,tokens),"rare_Epic")
	elseif job.Kind=="Expedition" and member.BoardDirty and d then
		local w=State.Weekly(d,os.time())
		writeBoard(p,w.Key,"Depth",w.Depth)
	end
	if returnPlayer and p.Parent and p.Character==member.Character and member.Character:FindFirstChild("HumanoidRootPart") then
		local call=Storage:FindFirstChild("M5Return")
		for _=1,2 do
			local called,ok=false,false
			if call then called,ok=pcall(call.Invoke,call,p,member.Island) end
			if called and ok then break end
			if not p.Parent or p.Character~=member.Character then break end
			task.wait(.35)
		end
		if p.Character==member.Character and (member.Character:GetPivot().Position-job.Center).Magnitude<85 then
			local hum=member.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health=0 end
		end
	end
	remove(job,p)
end

local function depthComplete(job)
	local now=os.time()
	for p,member in pairs(job.Participants) do
		local d=Data.Get(p)
		local performance=job.Participation[p]
		if not d or member.Closing or not performance then continue end
		if performance.Damage<job.DepthDamage*.02 and performance.Hits<12 then continue end
		local w=State.Weekly(d,now)
		local budget=State.Budget(d,now)
		local frontier=job.Depth>w.Depth
		d.M5.DepthEver=math.max(d.M5.DepthEver,job.Depth)
		w.Depth=math.max(w.Depth,job.Depth)
		member.BoardDirty=member.BoardDirty or frontier
		if frontier and budget.DepthClaims<M.Expedition.RewardClaimsPerDay then
			budget.DepthClaims+=1
			FinalState.Record(d,"Depths",1,now)
			local reward=M.DepthReward(job.Depth)
			reward.Material=M.Expedition.Material
			if job.Depth%3==0 then
				M6Inventory.AddRune(d,M6Inventory.RollRune(job.Depth>=15 and 4 or job.Depth>=9 and 3 or 2,Random.new()),1)
			end
			Guilds.Record(d,"Depth",1,p:GetAttribute("M7GuildId"))
			Rewards.Grant(p,d,reward,"Expedition depth "..job.Depth.." cleared")
		else
			Data.Sync(p)
		end
	end
	pushPhase(job,"DepthClear")
	setAll(job,"M5RunTrees",0)
end

function R.Deal(player,target,damage)
	if target:GetAttribute("M5Target")==nil then return false end
	if not player then return true end
	local job=active[player]
	local index=job and job.Targets[target]
	local member=job and job.Participants[player]
	if not member or member.Closing or not index or target:GetAttribute("M5Target")~=job.Slot or job.Phase~="Active"
		or player.Character~=member.Character or os.clock()>=job.Deadline or player:GetAttribute("Handoff") then return true end
	local root=member.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position-job.Center).Magnitude>87 then return true end
	local hp=target:GetAttribute("Health") or 0
	if hp<=0 then return true end
	local hits=job.Kind=="Trial" and 4 or math.clamp(damage,0,1e9)
	if hits<=0 or hits~=hits then return true end
	local actual=math.min(hp,hits)
	local performance=job.Participation[player] or {Damage=0,Hits=0}
	performance.Damage+=actual performance.Hits+=1
	job.Participation[player]=performance job.DepthDamage+=actual
	target:SetAttribute("Health",hp-hits)
	if hp<=hits then
		job.Targets[target]=nil
		target:Destroy()
		job.Score+=1
		setAll(job,"M5RunScore",job.Score)
		if job.Kind=="Trial" then
			task.delay(1.6,function()
				if active[player]==job and job.Phase=="Active" and os.clock()<job.Deadline then
					spawnTree(job,index)
				end
			end)
		else
			job.Remaining-=1
			setAll(job,"M5RunTrees",job.Remaining)
			if job.Remaining==0 then depthComplete(job) end
		end
	end
	return true
end

local function eligible(player,kind)
	if active[player] or player:GetAttribute("M5Run") then return nil,"Finish your current run first" end
	local d=Data.Get(player)
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	local island=player:GetAttribute("CurrentIsland")
	if not d or not player:GetAttribute("Loaded") or not C.IslandById[island] or not root or not hum or hum.Health<=0
		or player:GetAttribute("Handoff") or player:GetAttribute("IslandArrivalPending")
		or player:GetAttribute("IslandTravelling") or (player:GetAttribute("CombatUntil") or 0)>workspace:GetServerTimeNow() then
		return nil,"Return to a safe island area first"
	end
	if kind=="Expedition" and (not Layout.Enabled() or island~="FrostboundReach"
		or not d.UnlockedIslands.FrostboundReach or (player:GetAttribute("Power") or 0)<C.GetIslandRequiredPower(C.IslandById.FrostboundReach)
		or (root.Position-M.Expedition.Entry).Magnitude>18) then
		return nil,"Every member must be at the Frostbound Expedition Gate and meet its requirements"
	end
	return {Island=island,Character=char,Root=root,Humanoid=hum,Tier=M.IslandTier(d.UnlockedIslands)}
end

local function start(players,kind)
	local roster={}
	for _,p in ipairs(players) do
		local member,why=eligible(p,kind)
		if not member then return false,p.DisplayName.." · "..why end
		roster[p]=member
	end
	local leader=players[1]
	local slot=reserve()
	local job={Kind=kind,Slot=slot,Tier=roster[leader].Tier,Phase="Loading",Player=leader,Participants=roster,Order=players,
		Depth=1,Score=0,Targets={},Deadline=math.huge,Scale=1+.55*(#players-1),
		Center=v(15000+((slot-1)%8)*M.Expedition.SlotStride,60,6000+math.floor((slot-1)/8)*M.Expedition.SlotStride)}
	for p,member in pairs(roster) do
		active[p]=job
		p:SetAttribute("M5Run",kind) p:SetAttribute("M5RunOrigin",member.Island)
		Data.RecalcMultipliers(p)
	end
	pushPhase(job,"Loading")
	local built,issue=pcall(function() buildArena(job) populate(job) end)
	if not built then
		for _,p in ipairs(players) do remove(job,p) end
		warn("[M5] Arena construction failed: "..tostring(issue))
		return false,"Arena could not be constructed"
	end
	local pending=0
	for _,p in ipairs(players) do
		local member=roster[p]
		pending+=1
		task.spawn(function()
			local ok=pcall(p.RequestStreamAroundAsync,p,job.Center,7)
			member.Streamed=ok and p.Parent~=nil and active[p]==job and p.Character==member.Character and member.Humanoid.Health>0
			pending-=1
		end)
	end
	while pending>0 do task.wait() end
	for _,p in ipairs(players) do
		local member=roster[p]
		if not member or not member.Streamed or active[p]~=job or member.Humanoid.Health<=0 or p.Character~=member.Character then
			for _,peer in ipairs(players) do remove(job,peer) end
			return false,"A party member could not load the arena"
		end
	end
	for i,p in ipairs(players) do
		local member=roster[p]
		local at=job.Center+v((i-(#players+1)/2)*8,4,28)
		Guard:Allow(p,3,nil,at,member.Root.Position)
		member.Root.AssemblyLinearVelocity=v(0,0,0)
		member.Root.AssemblyAngularVelocity=v(0,0,0)
		member.Character:PivotTo(CFrame.new(at))
		p:SetAttribute("M5RunDepth",job.Depth) p:SetAttribute("M5RunScore",0)
		Data.ApplyMovement(p)
		member.Humanoid.Died:Once(function() if active[p]==job then finish(job,p,"Death",false) end end)
	end
	local seconds=kind=="Trial" and M.Trial.Seconds or M.Expedition.Seconds
	job.Deadline=os.clock()+seconds
	setAll(job,"M5RunEnds",workspace:GetServerTimeNow()+seconds)
	pushPhase(job,"Active")
	task.delay(seconds,function()
		for p in pairs(job.Participants) do task.spawn(finish,job,p,"Finished",true) end
	end)
	return true
end
function R.Enter(player,kind)
	if kind~="Trial" and kind~="Expedition" then return false,"Unknown run" end
	return start({player},kind)
end
function R.EnterParty(players)
	if #players<2 or #players>R.PartyCapacity then return false,"Expedition parties have two to four members" end
	return start(players,"Expedition")
end
function R.Next(player)
	local j=active[player]
	if not j or j.Kind~="Expedition" or j.Phase~="DepthClear" or os.clock()>=j.Deadline then return false,"Clear this depth first" end
	if j.Player~=player then return false,"The expedition leader starts the next depth" end
	j.Depth+=1
	setAll(j,"M5RunDepth",j.Depth)
	populate(j)
	pushPhase(j,"Active")
	return true
end
function R.Exit(player)
	local job=active[player]
	if not job or job.Phase=="Loading" or job.Participants[player].Closing then return false,"No active run to exit" end
	finish(job,player,"Exit",true)
	return true
end
function R.PartyExtension() return {Capacity=R.PartyCapacity,Availability="Solo and party"} end
local function bind(player)
	player.CharacterRemoving:Connect(function(char)
		local job=active[player]
		local member=job and job.Participants[player]
		if member and member.Character==char then
			if member.Closing or job.Phase=="Loading" then remove(job,player) else finish(job,player,"Death",false) end
		end
	end)
end
Players.PlayerAdded:Connect(bind)
for _,p in ipairs(Players:GetPlayers()) do bind(p) end
Players.PlayerRemoving:Connect(function(p)
	local job=active[p]
	if job then remove(job,p) end
end)
return R
