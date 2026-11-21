local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local Proximity=game:GetService("ProximityPromptService")
local D=require(RS:WaitForChild("M6Design"))
local I=require(RS:WaitForChild("M6Inventory"))
local M5=require(RS:WaitForChild("M5Design"))
local C=require(RS:WaitForChild("BladeConfig"))
local E=require(RS:WaitForChild("Economy"))
local Data=require(script.Parent:WaitForChild("DataService"))
local H=require(script.Parent:WaitForChild("M6Hits"))
local Guard=require(script.Parent:WaitForChild("MovementGuard")).shared
local World=require(script.Parent:WaitForChild("M4WorldRuntime"))
local Parties=require(script.Parent:WaitForChild("M7Parties"))
local Rules=require(script.Parent:WaitForChild("BossRules"))
local Progress=require(script.Parent:WaitForChild("Progress"))
local A=require(Storage:WaitForChild("M4Architecture"))
local Notify=RS:WaitForChild("Remotes"):WaitForChild("Notify")
local random=Random.new()
local V=Vector3.new
local fightRoot=Instance.new("Folder") fightRoot.Name="M6Encounters" fightRoot.Parent=workspace
local jobs={}
local heartLobby,raidJob
local raidCycle,raidDef,raidFinished
local heartSlots={}
local heartholders={}
local rink=Color3.fromRGB(70,74,103)
local function floor(parent,name,pos,size,color)
	return A.Part(parent,name,size,CFrame.new(pos),color,Enum.Material.Slate,true)
end
local function flat(a,b)
	return (V(a.X,0,a.Z)-V(b.X,0,b.Z)).Magnitude
end
local function newModel(parent,name)
	local m=Instance.new("Model") m.Name=name m.Parent=parent return m
end
local function human(p)
	local char=p.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health>0 then return root,hum end
end

local function eligible(job,p,margin)
	if not p.Parent or not p:GetAttribute("Loaded") or p:GetAttribute("Handoff") then return false end
	local root,hum=human(p)
	if not root or flat(root.Position,job.Center)>(margin or 62) or math.abs(root.Position.Y-job.Center.Y)>22 then return false end
	if job.Heart then
		if heartholders[p]~=job or not job.Members[p] or not job.Members[p].Arrived then return false end
	else
		if p:GetAttribute("M5Run") or p:GetAttribute("CurrentIsland")~=job.Spec.Island or (p:GetAttribute("Power") or 0)<job.Spec.Power then return false end
	end
	return true,root,hum
end
local function fighters(job)
	local members={}
	for _,p in ipairs(Players:GetPlayers()) do
		local okay,root,hum=eligible(job,p)
		if okay then table.insert(members,{Player=p,Root=root,Humanoid=hum}) end
	end
	return members
end

local function shape(job,id)
	local s=job.Spec
	local m=newModel(job.Arena,s.Name)
	local at=job.Center
	local theme=job.Heart and Color3.fromRGB(65,40,85) or id=="TreantRaid" and Color3.fromRGB(90,61,41) or rink
	local body=A.Part(m,"Core",V(9,13,7),CFrame.new(at+V(0,7,0)),theme,Enum.Material.Slate)
	body.CanQuery=true m.PrimaryPart=body
	local function bits(name,size,offset,c,mat,rotate)
		return A.Part(m,name,size,CFrame.new(at+offset)*CFrame.Angles(0,0,rotate or 0),c,mat)
	end
	bits("Runic core",V(3.5,4.5,.7),V(0,8,-3.65),s.Color,Enum.Material.Neon)
	for _,side in ipairs({-1,1}) do
		bits("Shoulder",V(5,4,5),V(side*6,10,0),theme,Enum.Material.Slate,side*.24)
		bits("Arm",V(3,7,3.5),V(side*7,6,0),s.Color,id=="TreantRaid" and Enum.Material.Wood or Enum.Material.Glacier,side*.18)
		bits("Greave",V(3.6,5,4),V(side*2.8,2.5,0),theme,Enum.Material.Slate)
	end
	if id=="HydraRaid" then
		for i=-1,1 do
			bits("Hydra neck",V(2.2,9,2.4),V(i*5,14,0),theme,Enum.Material.Slate,i*.32)
			bits("Hydra mask",V(4,3.4,4.8),V(i*6,19-math.abs(i)*2,-1.8),s.Color,Enum.Material.Glacier,i*.18)
			bits("Hydra eyes",V(2.6,.4,.35),V(i*6,19-math.abs(i)*2,-4.2),Color3.new(1,1,1),Enum.Material.Neon)
		end
	else
		bits("Mask",V(5.1,4.5,4.2),V(0,15,0),theme,Enum.Material.Slate)
		bits("Eyes",V(3,.5,.4),V(0,15.6,-2.2),s.Color,Enum.Material.Neon)
		for i=-2,2 do
			bits(id=="TreantRaid" and "Branch crown" or "Frost crown",V(1.3,3+math.abs(i),1.45),V(i*1.56,18,0),
				s.Color,id=="TreantRaid" and Enum.Material.Grass or Enum.Material.Ice,i*.22)
		end
	end
	local box=bits("Blade hit volume",V(15,15,10),V(0,7,0),theme)
	box.CanQuery=true box.Transparency=1
	local gui=Instance.new("BillboardGui") gui.Size=UDim2.fromOffset(247,52)
	gui.StudsOffset=V(0,15,0) gui.MaxDistance=120 gui.Parent=body
	local info=Instance.new("TextLabel") info.Size=UDim2.fromScale(1,1) info.BackgroundColor3=theme
	info.TextColor3=s.Color info.TextScaled=true info.Font=Enum.Font.GothamBold info.Parent=gui
	job.Boss=m job.Caption=info
end

local function display(job)
	if not job.Boss then return end
	local whole=math.max(0,math.ceil(job.HP))
	job.Boss:SetAttribute("Health",whole)
	job.Caption.Text=job.Spec.Name.."\n"..C.FormatNumber(whole).." / "..C.FormatNumber(job.Max)
	if job.Heart then
		for p in pairs(job.Members) do
			if p.Parent then
				p:SetAttribute("M6HeartHP",whole) p:SetAttribute("M6HeartMax",job.Max)
				p:SetAttribute("M6HeartPhase",job.Phase) p:SetAttribute("M6HeartWards",job.WardCount)
			end
		end
	else
		workspace:SetAttribute("M6RaidHP",whole) workspace:SetAttribute("M6RaidMax",job.Max)
	end
end

local function exitHeart(p,job,goBack)
	if heartholders[p]~=job then return end
	heartholders[p]=nil job.Members[p]=nil
	if p.Parent and p:GetAttribute("M5Run")=="Heart" then
		if goBack then
			local root,hum=human(p)
			if root then
				local call=Storage:FindFirstChild("M5Return")
				local called,ok=false,false
				if call then called,ok=pcall(call.Invoke,call,p,"FrostboundReach") end
				if not (called and ok) and hum and hum.Parent then hum.Health=0 end
			end
		end
		for _,key in ipairs({"M5Run","M5RunOrigin","M6HeartHP","M6HeartMax","M6HeartPhase","M6HeartWards","M6HeartEnd","M6HeartWarning"}) do
			p:SetAttribute(key,nil)
		end
		Data.RecalcMultipliers(p)
	end
end

local function payout(job)
	local now=os.time()
	local ranks=Rules.Rank(job.Damage,job.Hits)
	for _,row in ipairs(ranks) do
		local p=Players:GetPlayerByUserId(row[1])
		local d=p and Data.Get(p)
		local recent=job.Recent[row[1]]
		local onsite=p and (job.Heart and job.Members[p] or not job.Heart and p:GetAttribute("CurrentIsland")==job.Spec.Island)
		if d and onsite and recent and os.clock()-recent<=70 and row[2]>0 and not p:GetAttribute("Handoff") then
			local budget=I.Day(d,now)
			local spec=job.Spec
			local week=M5.Week(now)
			local enhanced=job.Heart and d.M6.HeartWeek~=week
			local allowed
			if job.Heart then
				allowed=d.M6.Keys>0 and (enhanced or budget.Heart<D.HeartClaimsPerDay)
				if allowed then
					d.M6.Keys-=1 budget.Heart+=1
					if enhanced then d.M6.HeartWeek=week end
				end
			else
				allowed=budget.Raids<D.RaidClaimsPerDay and (d.M6.RaidSlots[spec.Id] or -1)<job.Cycle
				if allowed then budget.Raids+=1 d.M6.RaidSlots[spec.Id]=job.Cycle end
			end
			if allowed then
				local first=not d.M6.BossClears[spec.Id]
				d.M6.BossClears[spec.Id]=(d.M6.BossClears[spec.Id] or 0)+1
				local reward=E.M6BossReward(Data.PriceUnit(p),row[3],job.Heart,enhanced)
				Data.AddCoins(p,reward.Logs,nil,true)
				Data.AddSouls(p,E.M6CombatSouls(reward.Souls,I.Bonuses(d)),nil)
				Data.AddMasteryXP(p,reward.XP)
				I.AddMaterial(d,spec.Material,reward.Materials)
				if spec.Sigil then d.BossSigils[spec.Sigil]=(d.BossSigils[spec.Sigil] or 0)+1 end
				I.AddRune(d,I.RollRune(enhanced and 4 or job.Heart and 3 or spec.Island=="TimberHaven" and 1 or 2,random),1)
				if (job.Heart and enhanced or not job.Heart and first) and not d.Weapons[spec.Weapon] then
					Data.M6Weapon(p,spec.Weapon,job.Heart and "Winter weekly clear" or "Raid first victory")
				end
				Progress.Add(p,"Boss",1)
				Progress.Add(p,"NPCs",1)
				d.M6.Revision+=1
				Data.Sync(p)
				Notify:FireClient(p,(enhanced and "Weekly Winter victory" or spec.Name.." victory")
					.." · +"..reward.Materials.." "..(D.MaterialNames[spec.Material] or spec.Material).." · Rune acquired","rare_Divine")
			else
				Notify:FireClient(p,"Victory recorded. This reward limit is already reached.","info")
			end
		end
	end
end

local function finish(job,won)
	if job.Closed then return end
	job.Closed=true
	if job.Boss then H.Remove(job.Boss) job.Boss:Destroy() end
	if won then payout(job) end
	if job.Heart then
		if heartLobby==job then heartLobby=nil end
		if won then
			for p in pairs(job.Members) do if p.Parent then p:SetAttribute("M6HeartPhase","Victory") end end
			task.wait(2)
		end
		local members={}
		for p in pairs(job.Members) do table.insert(members,p) end
		for _,p in ipairs(members) do task.spawn(exitHeart,p,job,true) end
		local arena=job.Arena
		task.delay(18,function()
			if arena.Parent then arena:Destroy() end
			heartSlots[job.ArenaSlot]=nil
		end)
	else
		workspace:SetAttribute("M6RaidHP",nil) workspace:SetAttribute("M6RaidMax",nil)
		job.Arena:Destroy()
		if raidJob==job then raidJob=nil end
	end
	jobs[job]=nil
end

local function wards(job)
	job.WardCount=3
	for i=1,3 do
		local a=i*math.pi*2/3
		local part=A.Part(job.Arena,"Winter seal",V(4,10,4),CFrame.new(job.Center+V(math.cos(a)*19,5,math.sin(a)*19)),
			job.Spec.Color,Enum.Material.Neon)
		part.CanQuery=true
		part:SetAttribute("Health",math.ceil(job.Max*.034))
		H.Register(part,function(p,dmg)
			if job.Closed or not eligible(job,p) or not part.Parent then return end
			local hp=part:GetAttribute("Health")-dmg
			part:SetAttribute("Health",hp)
			if hp<=0 then
				H.Remove(part) part:Destroy()
				job.WardCount-=1 display(job)
			end
		end)
	end
end
local function mount(job,amount)
	local mult=math.clamp(amount-1,0,job.Heart and 3 or 7)
	job.Max=math.floor(job.Spec.HP*(1+mult*(job.Heart and .48 or .34)))
	job.HP=job.Max
	job.Phase="I" job.WardCount=0 job.Attack=0
	shape(job,job.Spec.Id)
	display(job)
	H.Register(job.Boss,function(p,dmg)
		if job.Closed or job.Ending or job.WardCount>0 or not eligible(job,p) then return end
		local damage=math.min(job.HP,dmg)
		job.HP-=damage
		local hp=job.HP/job.Max
		job.Damage[p.UserId]=(job.Damage[p.UserId] or 0)+damage
		job.Hits[p.UserId]=(job.Hits[p.UserId] or 0)+1
		job.Recent[p.UserId]=os.clock()
		if job.Heart and job.Phase=="I" and hp<=.67 and hp>0 then
			job.Phase="II" wards(job)
			for member in pairs(job.Members) do
				if member.Parent then Notify:FireClient(member,"The Heart is shielded · break the three Winter Seals","boss") end
			end
		elseif job.Heart and job.Phase=="II" and hp<=.31 and hp>0 then
			job.Phase="III"
			for member in pairs(job.Members) do if member.Parent then Notify:FireClient(member,"Winterfall · evade the rotating frost lanes","boss") end end
		end
		display(job)
		if job.HP<=0 and not job.Ending then
			job.Ending=true
			task.defer(finish,job,true)
		end
	end)
end

local function attack(job,present)
	job.Attack+=1
	local s=job.Spec
	local radius=job.Heart and (job.Phase=="III" and 8 or 11) or s.Id=="HydraRaid" and 7 or s.Id=="GiantRaid" and 16 or 11
	local spots={}
	if s.Id=="HydraRaid" or job.Heart and job.Phase~="I" then
		local lanes=job.Heart and job.Phase=="III" and 4 or 3
		local angle=job.Attack*.66
		for lane=1,lanes do
			local a=angle+lane*2*math.pi/lanes
			for i=1,3 do table.insert(spots,job.Center+V(math.cos(a)*10*i,0,math.sin(a)*10*i)) end
		end
	else
		local focus=present[random:NextInteger(1,#present)].Root.Position
		table.insert(spots,V(focus.X,job.Center.Y,focus.Z))
		if s.Id=="TreantRaid" then
			for i=1,3 do table.insert(spots,job.Center+V(math.cos(i*2.1+job.Attack)*22,0,math.sin(i*2.1+job.Attack)*22)) end
		else table.insert(spots,job.Center) end
	end
	local warning=Instance.new("Folder") warning.Name="Telegraph" warning.Parent=job.Arena
	for _,pos in ipairs(spots) do
		local disk=A.Part(warning,"Warning",V(.13,radius*2,radius*2),CFrame.new(pos+V(0,.55,0))*CFrame.Angles(0,0,math.pi/2),
			s.Color,Enum.Material.Neon,false,Enum.PartType.Cylinder)
		disk.Transparency=.42
	end
	local windup=job.Heart and job.Phase=="III" and 1.10 or 1.65
	if job.Heart then
		for p in pairs(job.Members) do if p.Parent then p:SetAttribute("M6HeartWarning",job.Phase=="III" and "Winterfall · move off the violet lanes" or "Frost impact · step out of the rings") end end
	end
	task.delay(windup,function()
		if job.Closed then return end
		for _,entry in ipairs(fighters(job)) do
			for _,pos in ipairs(spots) do
				if flat(entry.Root.Position,pos)<radius and entry.Root.Position.Y<pos.Y+10 then
					entry.Humanoid:TakeDamage(s.Hit+(job.Heart and job.Phase=="III" and 14 or 0)) break
				end
			end
		end
		for _,obj in ipairs(warning:GetChildren()) do obj.Transparency=.77 end
		task.delay(.3,function() if warning.Parent then warning:Destroy() end end)
		if job.Heart then
			for p in pairs(job.Members) do if p.Parent then p:SetAttribute("M6HeartWarning",nil) end end
		end
	end)
end

local function newJob(spec,at,heart,cycle)
	local arena=newModel(fightRoot,heart and "Private Sanctum" or spec.Name)
	local job={Spec=spec,Center=at,Heart=heart,Cycle=cycle,Arena=arena,Members={},Damage={},Hits={},Recent={},NextAttack=0}
	jobs[job]=true
	return job
end

local function validateHeart(p,point)
	local d=Data.Get(p)
	local root,hum=human(p)
	if not d or not root or not p:GetAttribute("Loaded") or p:GetAttribute("Handoff") or p:GetAttribute("IslandArrivalPending")
		or p:GetAttribute("IslandTravelling") or p:GetAttribute("CurrentIsland")~="FrostboundReach"
		or not d.UnlockedIslands.FrostboundReach or (p:GetAttribute("Power") or 0)<D.Heart.Power
		or (p:GetAttribute("CombatUntil") or 0)>workspace:GetServerTimeNow()
		or p:GetAttribute("M5Run") or d.M6.Keys<1 or (root.Position-point).Magnitude>16 then
		return nil,"Bring a Winter Key and 2,000 Power to the sanctum"
	end
	return {Character=p.Character,Root=root,Humanoid=hum}
end
local function makeHeart(now)
	local slot=1
	while heartSlots[slot] do slot+=1 end
	heartSlots[slot]=true
	local center=V(-13500+((slot-1)%8)*170,81,5900+math.floor((slot-1)/8)*170)
	local job=newJob(D.Heart,center,true,0)
	job.ArenaSlot=slot
	floor(job.Arena,"Winter ring",center-V(0,1,0),V(112,2,112),rink)
	for i=1,8 do
		local a=i*math.pi/4
		local pos=center+V(math.cos(a)*49,7,math.sin(a)*49)
		A.Part(job.Arena,"Ice monolith",V(3,15,3),CFrame.new(pos),D.Heart.Color,Enum.Material.Glacier)
	end
	job.Launch=now+D.HeartQueue job.Deadline=job.Launch+D.HeartLength
	return job
end
local offsets={V(-9,0,27),V(9,0,27),V(-9,0,34),V(9,0,34)}
local function enterGroup(players,point,isParty)
	local info={}
	for _,p in ipairs(players) do
		local ready,why=validateHeart(p,point)
		if not ready then return false,p.DisplayName.." · "..why end
		info[p]=ready
	end
	local now=os.clock()
	local j=isParty and nil or heartLobby
	local count=0
	if j then for _ in pairs(j.Members) do count+=1 end end
	if isParty or not j or now>j.Launch or count>=D.HeartCapacity or j.Closed then
		j=makeHeart(now)
		if not isParty then heartLobby=j end
	end
	local used={}
	for _,member in pairs(j.Members) do used[member.Slot]=true end
	for _,p in ipairs(players) do
		local slot=1 while used[slot] do slot+=1 end
		used[slot]=true
		j.Members[p]={Slot=slot,Arrived=false}
		heartholders[p]=j
		p:SetAttribute("M5Run","Heart") p:SetAttribute("M5RunOrigin","FrostboundReach")
		p:SetAttribute("M6HeartPhase","Gathering") p:SetAttribute("M6HeartEnd",workspace:GetServerTimeNow()+math.max(0,j.Deadline-now))
		Data.RecalcMultipliers(p)
	end
	local streams=0
	for _,p in ipairs(players) do
		streams+=1
		task.spawn(function()
			local data=info[p]
			data.Streamed=pcall(p.RequestStreamAroundAsync,p,j.Center,6)
			streams-=1
		end)
	end
	while streams>0 do task.wait() end
	for _,p in ipairs(players) do
		local data=info[p]
		if not data.Streamed or j.Closed or p.Character~=data.Character or not p.Parent or data.Humanoid.Health<=0 or not j.Members[p] then
			for _,peer in ipairs(players) do exitHeart(peer,j,false) end
			return false,"A player could not load the Sanctum"
		end
	end
	for _,p in ipairs(players) do
		local data=info[p]
		local at=j.Center+offsets[j.Members[p].Slot]+V(0,4,0)
		Guard:Allow(p,3,nil,at,data.Root.Position)
		data.Root.AssemblyLinearVelocity=V(0,0,0) data.Root.AssemblyAngularVelocity=V(0,0,0)
		data.Character:PivotTo(CFrame.new(at)) j.Members[p].Arrived=true
		data.Humanoid.Died:Once(function() exitHeart(p,j,false) end)
	end
	return true
end
local returnSignal=Instance.new("BindableFunction")
returnSignal.Name="M6HeartRetreat"
returnSignal.OnInvoke=function(p)
	local job=heartholders[p]
	if not job or job.Closed then return false,"No active sanctum encounter" end
	exitHeart(p,job,true)
	return true
end
returnSignal.Parent=Storage
Players.PlayerRemoving:Connect(function(p) local j=heartholders[p] if j then exitHeart(p,j,false) end end)

if not World.Active then return end
local pkg=workspace.M4ActiveWorld:FindFirstChild("FrostboundReach")
local hearth=pkg and pkg:FindFirstChild("Winter Key Threshold",true)
local anchor=hearth and hearth:FindFirstChild("Interaction")
if anchor then
	local sign=anchor:FindFirstChildWhichIsA("TextLabel",true)
	if sign then sign.Text="Heart of Winter\nWinter Key · 1–4 players" end
	local prompt=Instance.new("ProximityPrompt") prompt.Name="WinterKeyPrompt"
	prompt.ObjectText="Heart of Winter" prompt.ActionText="Enter Sanctum"
	prompt.HoldDuration=.45 prompt.RequiresLineOfSight=false prompt.MaxActivationDistance=12 prompt.Parent=anchor
	Proximity.PromptTriggered:Connect(function(pr,p)
		if pr~=prompt then return end
		local ok,why=enterGroup({p},anchor.Position,false)
		if not ok then Notify:FireClient(p,why,"death") end
	end)
end
local bridge=newModel(fightRoot,"Hydra Annex")
floor(bridge,"Hydra bridge",V(3061,-1,-350),V(35,2,15),rink)
floor(bridge,"Hydra arena",D.Raids[2].Position-V(0,1,0),V(114,2,102),rink)
workspace:SetAttribute("M6RaidAnnexReady",true)
local function openRaid(spec,start,done)
	if raidCycle==start then return end
	if raidJob then finish(raidJob,false) end
	raidDef,raidCycle,raidFinished=spec,start,false
	workspace:SetAttribute("M6RaidName",spec.Name)
	workspace:SetAttribute("M6RaidIsland",spec.Island)
	workspace:SetAttribute("M6RaidEnd",done)
	workspace:SetAttribute("M6RaidNext",start+D.RaidPeriod)
	if os.time()<done then Notify:FireAllClients(spec.Name.." · raid window is open","boss") end
end
local function startRaid(spec,start,done,near)
	raidJob=newJob(spec,spec.Position,false,start)
	raidFinished=true
	raidJob.Deadline=os.clock()+(done-os.time())
	mount(raidJob,#near)
end
local partyEntry=Instance.new("BindableFunction")
partyEntry.Name="M7EncounterEntry"
partyEntry.OnInvoke=function(leader,mode)
	local members,why=Parties.Ready(leader)
	if not members then return false,why end
	if mode=="Heart" and anchor then return enterGroup(members,anchor.Position,true) end
	if mode~="Raid" then return false,"Encounter unavailable" end
	local utc=os.time()
	local spec,start,done=D.RaidAt(utc)
	if utc>=done then return false,"The raid window is closed" end
	local probe={Spec=spec,Center=spec.Position}
	for _,p in ipairs(members) do
		if not eligible(probe,p) then return false,p.DisplayName.." must meet the raid power minimum and gather at the arena" end
	end
	openRaid(spec,start,done)
	if raidFinished and not raidJob then return false,"This raid is already resolved" end
	if not raidJob then startRaid(spec,start,done,fighters(probe)) end
	for _,p in ipairs(members) do Notify:FireClient(p,"Party rallied · "..spec.Name,"boss") end
	return true
end
partyEntry.Parent=Storage
while true do
	task.wait(.65)
	local utc,now=os.time(),os.clock()
	local spec,start,done=D.RaidAt(utc)
	openRaid(spec,start,done)
	if not raidFinished and not raidJob and utc<done then
		local here=fighters({Spec=raidDef,Center=raidDef.Position})
		if #here>0 then startRaid(raidDef,start,done,here) end
	end
	for job in pairs(jobs) do
		local closing=false
		if not job.Closed and not job.Ending then
			if now>=job.Deadline then
				job.Ending=true task.defer(finish,job,false) closing=true
			elseif job.Heart and next(job.Members)==nil then
				job.Ending=true task.defer(finish,job,false) closing=true
			end
			if not closing then
				local present=fighters(job)
				if job.Heart and not job.Boss and now>=job.Launch and #present>0 then
					mount(job,#present)
				end
				if job.Boss and #present>0 and now>=job.NextAttack then
					job.NextAttack=now+(job.Heart and job.Phase=="III" and 3.1 or job.Spec.Id=="HydraRaid" and 5.2 or 5.8)
					if job.Heart and job.WardCount==0 then
						local angle=job.Attack*.62
						local at=job.Center+V(math.cos(angle)*9,7,math.sin(angle)*9)
						job.Boss:PivotTo(CFrame.new(at)*CFrame.Angles(0,-angle,0))
					end
					attack(job,present)
				end
			end
		end
	end
end
