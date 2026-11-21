local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Proximity=game:GetService("ProximityPromptService")
local scripts=script.Parent
local Data=require(scripts:WaitForChild("DataService"))
local S=require(scripts:WaitForChild("M5State"))
local Runs=require(scripts:WaitForChild("M5Runs"))
local Rewards=require(scripts:WaitForChild("M5Rewards"))
local Boards=require(scripts:WaitForChild("M5Boards"))
local world=require(scripts:WaitForChild("M4WorldRuntime"))
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local L=require(ReplicatedStorage:WaitForChild("M4Layout"))
local C=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local remotes=ReplicatedStorage:WaitForChild("Remotes")
local notify=remotes:WaitForChild("Notify")
local remote=Instance.new("RemoteFunction")
remote.Name="Adventures"
local rates={}
local readyPulse={}

local function currentProfile(player)
	local d=Data.Get(player)
	if not d or not player:GetAttribute("Loaded") or player:GetAttribute("Handoff") then return nil end
	return d
end

local function price(player)
	return math.clamp(math.floor(player:GetAttribute("PriceTier") or 1),1,#C.Economy.PriceTiers)
end

local function package(player,d,now)
	local rank=S.Weekly(d,now)
	local budget=S.Budget(d,now)
	local info={Quests={},Contracts={},Shop=table.clone(rank.Shop),Tokens=d.M5.Tokens,DepthEver=d.M5.DepthEver,
		TrialBest=rank.Trial,DepthBest=rank.Depth,Tier=M.IslandTier(d.UnlockedIslands),Materials=table.clone(d.M5.Materials),
		Streak=d.M5.LastDaily<M.Day(now)-1 and 0 or d.M5.Streak,TrialTokensToday=budget.Tokens,DepthClaims=budget.DepthClaims,
		WeekEnd=M.Reset("Weekly",rank.Key),PriceUnit=Data.PriceUnit(player),RankWeek=rank.Key}
	local best=Data.BestPower(d)
	for _,id in ipairs(M.Islands) do info.Quests[id]=S.Quest(d,id,best) end
	for period,_ in pairs(M.Periods) do
		local current=S.Period(d,period,now,player.UserId,price(player))
		local output={Key=current.Key,Ends=M.Reset(period,current.Key),Offers={},Picked=0,PriceUnit=C.Economy.PriceTiers[current.PriceTier].Unit,
			CanReroll=not current.Rerolled and d.Mastery.Level>=(period=="Daily" and 15 or 30)}
		for i,offer in ipairs(current.Offers) do
			local spec,have,goal,filter=S.Offer(d,period,current,offer)
			output.Offers[i]={Id=offer.Id,Name=spec[1],Kind=spec[2],Filter=filter,Claimed=offer.Claimed==true,
				Picked=offer.Start~=nil,Goal=goal,Progress=offer.Start and math.clamp(have-offer.Start,0,goal) or 0}
			if offer.Start~=nil then output.Picked+=1 end
		end
		info.Contracts[period]=output
	end
	return info
end

local function refreshVisit(p,d)
	if p:GetAttribute("M5Run") or p:GetAttribute("IslandArrivalPending") or p:GetAttribute("IslandTravelling") then return end
	local island=p:GetAttribute("CurrentIsland")
	if not M.Chains[island] then return end
	local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local actual=C.GetIslandAt(root.Position)
	if not actual or actual.Id~=island then return end
	local state=d.M5
	if state.VisitIsland~=island then
		state.VisitIsland=island
		state.Visits[island]=true
		local now=os.time()
		if now-(state.VisitTimes[island] or 0)>=240 then
			state.VisitTimes[island]=now
			state.VisitCount+=1
		end
	end
	for key,point in pairs(M.Landmarks) do
		if point.Island==island and not state.Landmarks[key] then
			local position=not L.Enabled() and point.Legacy or point.Position
			if (root.Position-position).Magnitude<=point.Radius then state.Landmarks[key]=true end
		end
	end
end

local function act(player,operation,a,b,c)
	local d=currentProfile(player)
	if not d then return false,"Profile loading" end
	local now=os.time()
	if operation=="Get" then return true,package(player,d,now) end
	if operation=="Board" then
		if a~="Trial" and a~="Depth" then return false,"Unknown leaderboard" end
		return true,Boards.Read(M.Week(now),a)
	end
	if operation=="Trial" then return Runs.Enter(player,"Trial") end
	if operation=="Next" then return Runs.Next(player) end
	if operation=="Exit" then return Runs.Exit(player) end
	if operation=="Quest" then
		if type(a)~="string" or not M.Chains[a] or type(b)~="number" or b%1~=0 then return false,"Unknown quest" end
		local st=S.Quest(d,a,Data.BestPower(d))
		local q=M.Chains[a][b]
		if not q or not st.Open or b~=st.Claimed+1 or st.Progress[b]<q[4] then return false,"Complete this step first" end
		d.M5.Quests[a]=b
		Rewards.Grant(player,d,{Logs=.18+b*.055,Souls=3+b,XP=25+b*12},q[1].." complete")
	elseif operation=="Accept" or operation=="Reroll" or operation=="Claim" then
		if type(a)~="string" or not M.Periods[a] or type(b)~="number" or b%1~=0 or b<1 or b>M.Periods[a].Offer then return false,"Unknown contract" end
		local st=S.Period(d,a,now,player.UserId,price(player))
		if c~=st.Key then return false,"Contracts have reset. Refresh the board." end
		if operation=="Accept" then
			local ok,why=S.Accept(d,a,st,b)
			if not ok then return false,why end
		elseif operation=="Reroll" then
			local ok,why=S.Reroll(d,a,st,b,player.UserId)
			if not ok then return false,why end
		else
			local reward,why=S.Claim(d,a,st,b)
			if not reward then return false,why end
			Rewards.Grant(player,d,reward,a.." contract claimed",st.PriceTier)
		end
	elseif operation=="Shop" then
		local def=type(a)=="string" and M.Shop[a]
		local w=S.Weekly(d,now)
		if not def or b~=w.Key or c~=(w.Shop[a] or 0) or (w.Shop[a] or 0)>=def.Limit or d.M5.Tokens<def.Cost then
			return false,"Shop item unavailable or insufficient tokens"
		end
		d.M5.Tokens-=def.Cost
		w.Shop[a]=(w.Shop[a] or 0)+1
		Rewards.Grant(player,d,{Logs=def.Logs,Souls=def.Souls,Material=def.Material,Materials=def.Amount},def.Name.." redeemed")
	else
		return false,"Unknown action"
	end
	Data.Sync(player)
	return true,package(player,d,now)
end

remote.OnServerInvoke=function(player,operation,a,b,c)
	local state=rates[player]
	if not state then state={} rates[player]=state end
	local query=operation=="Get" or operation=="Board"
	local slot=operation=="Board" and "board" or query and "read" or "write"
	local interval=slot=="board" and 3 or query and .65 or .24
	local now=os.clock()
	if state[slot] and now-state[slot]<interval then return false,"Please wait" end
	state[slot]=now
	return act(player,operation,a,b,c)
end
remote.Parent=remotes

local frost=world.Active and workspace.M4ActiveWorld:FindFirstChild("FrostboundReach")
local zone=frost and frost:FindFirstChild("Expedition Gate",true)
local gate=zone and zone:FindFirstChild("Expedition Gate")
local entry=gate and gate:FindFirstChild("Interaction")
if entry then
	local label=entry:FindFirstChildWhichIsA("TextLabel",true)
	if label then label.Text="Endless Expeditions\nEnter solo" end
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="ExpeditionPrompt" prompt.ObjectText="Endless Expeditions" prompt.ActionText="Enter solo"
	prompt.MaxActivationDistance=12 prompt.HoldDuration=.35 prompt.RequiresLineOfSight=false
	prompt.Parent=entry
	Proximity.PromptTriggered:Connect(function(clicked,player)
		if clicked~=prompt then return end
		local ok,why=Runs.Enter(player,"Expedition")
		if not ok then notify:FireClient(player,why,"death") end
	end)
end

local function bind(p)
	p:GetAttributeChangedSignal("CurrentIsland"):Connect(function()
		local d=currentProfile(p)
		if not d then return end
		Data.RecalcMultipliers(p)
		refreshVisit(p,d)
	end)
	task.spawn(function()
		while p.Parent and not p:GetAttribute("Loaded") do task.wait(.35) end
		local d=p.Parent and currentProfile(p)
		if not d then return end
		refreshVisit(p,d)
		local w=S.Weekly(d,os.time())
		-- Loaded records are authoritative and can replenish an unavailable board write from a prior session.
		Boards.Record(w.Key,"Trial",p.UserId,w.Trial,Data.IsActive(p))
		Boards.Record(w.Key,"Depth",p.UserId,w.Depth,Data.IsActive(p))
	end)
end
Players.PlayerAdded:Connect(bind)
for _,p in ipairs(Players:GetPlayers()) do bind(p) end
Players.PlayerRemoving:Connect(function(p) rates[p]=nil readyPulse[p]=nil end)
while true do
	task.wait(3)
	for _,p in ipairs(Players:GetPlayers()) do
		local d=currentProfile(p)
		if d then
			refreshVisit(p,d)
			local best=Data.BestPower(d)
			local n=0
			local reached=readyPulse[p] or {}
			readyPulse[p]=reached
			for _,id in ipairs(M.Islands) do
				local q=S.Quest(d,id,best)
				local i=q.Claimed+1
				if q.Open and M.Chains[id][i] and q.Progress[i]>=M.Chains[id][i][4] then
					n+=1
					if reached[id]~=i then
						reached[id]=i
						notify:FireClient(p,"Adventure step ready · "..M.Chains[id][i][1],"kill")
					end
				end
			end
			p:SetAttribute("M5Ready",n)
		end
	end
end
