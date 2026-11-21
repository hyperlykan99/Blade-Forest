local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local BadgeService=game:GetService("BadgeService")
local D=require(RS:WaitForChild("M8Design"))
local E=require(RS:WaitForChild("Economy"))
local C=require(RS:WaitForChild("BladeConfig"))
local L=require(RS:WaitForChild("M4Layout"))
local State=require(script.Parent:WaitForChild("M8State"))
local Data=require(script.Parent:WaitForChild("DataService"))
local Analytics=require(script.Parent:WaitForChild("Analytics"))
local Remotes=RS:WaitForChild("Remotes")
local Notify=Remotes:WaitForChild("Notify")
local Season=Instance.new("RemoteFunction")
Season.Name="M8Progression"
local last={}
local guide={}
for _,q in ipairs(D.Guide) do guide[q.Id]=q end
local function trackLevel(p,s,ledger)
	local level=State.Level(ledger,s)
	if level>ledger.Reported then
		ledger.Reported=level
		Analytics.Custom(p,"SeasonLevelReached",level,{CustomField01=s.Id})
	end
end
local function snapshot(p,d,now)
	local edition=D.Editions[1]
	local ed,rows,m=State.Score(d,edition)
	local active=D.Active(now)
	local seasons={}
	for _,s in ipairs(D.Seasons) do
		local ledger=d.M8.Seasons[s.Id]
		if ledger then trackLevel(p,s,ledger) end
		seasons[s.Id]={XP=ledger and ledger.XP or 0,Level=ledger and State.Level(ledger,s) or 0,
			Claims=ledger and ledger.Claims or {},Weeks=ledger and ledger.Weeks or {},Events=ledger and ledger.Events or {}}
	end
	local editions={}
	for _,e in ipairs(D.Editions) do
		local record,category=ed,rows
		if e~=edition then record,category=State.Score(d,e) end
		editions[e.Id]={Best=record.Best,Claims=record.Claims,Rows=category}
	end
	local claimed={}
	for _,a in ipairs(D.Achievements) do
		claimed[a.Id]={Progress=math.min(m[a.Metric],a.Goal),Claimed=d.M8.AchievementClaims[a.Id]==true}
	end
	return {Editions=editions,Achievements=claimed,Seasons=seasons,Active=active and active.Id or nil,
		Guide=d.M8.Guide,Mastery=d.Mastery.Level,Island=p:GetAttribute("CurrentIsland")}
end
local function grant(p,d,amount,plan,reason)
	if amount.Essence>0 then Data.AddEssence(p,amount.Essence) end
	if amount.Logs>0 then Data.AddCoins(p,amount.Logs,nil,true) end
	if amount.Souls>0 then Data.AddSouls(p,amount.Souls) end
	if amount.XP>0 then Data.AddMasteryXP(p,amount.XP) end
	local weapon=plan.Weapon
	if weapon and C.WeaponById[weapon] and not d.Weapons[weapon] then Data.M6Weapon(p,weapon,reason) end
	if plan.Cosmetic then
		if plan.Title then d.M7.Titles[plan.Cosmetic]=true end
		if plan.Aura then d.M7.Auras[plan.Cosmetic]=true end
	end
	Data.Sync(p)
	Notify:FireClient(p,reason.." claimed","rare_Legendary")
end
local function canGrant(d,amount)
	local essence=d.Essence
	local used=essence.Day==E.EssenceDay() and essence.Today or 0
	return amount.Essence<=math.max(0,C.Attunement.DailyCap-used)
end
local function awardBadge(p,d,a)
	if type(a.BadgeId)~="number" or a.BadgeId<=0 or not Data.CanPersist(p) then return end
	d.M8.BadgePending[a.Id]=true
	task.spawn(function()
		if not Data.SaveNow(p,false) or Data.Get(p)~=d then return end
		local ok,info=pcall(BadgeService.GetBadgeInfoAsync,BadgeService,a.BadgeId)
		if not ok or not info.IsEnabled then return end
		local owned,has=pcall(BadgeService.UserHasBadgeAsync,BadgeService,p.UserId,a.BadgeId)
		local success=owned and has
		if not success then
			local applied,result=pcall(BadgeService.AwardBadgeAsync,BadgeService,p.UserId,a.BadgeId)
			success=applied and result
		end
		if success and Data.Get(p)==d then d.M8.BadgePending[a.Id]=nil Data.Sync(p) end
	end)
end
local function action(p,op,a,b,c,now)
	local d=Data.Get(p)
	if not d or not p:GetAttribute("Loaded") or p:GetAttribute("Handoff") then return false,"Profile loading" end
	if op=="Read" then return true,snapshot(p,d,now) end
	if op=="Guide" then
		if not guide[a] or d.M8.Guide[a] then return false,"Guide tip already recorded or unavailable" end
		d.M8.Guide[a]=true
		Analytics.Custom(p,"FieldGuideTip",1,{CustomField01=a})
		Data.Sync(p)
		return true
	end
	if op=="Challenge" then
		local season=D.BySeason[a]
		if not season or type(c)~="number" or c%1~=0 or c<0 or c>math.ceil((season.Finish-season.Start)/D.Week) then return false,"Unknown seasonal challenge" end
		local okay,name=State.ClaimChallenge(d,season,b,c,now)
		if not okay then return false,name end
		Analytics.Custom(p,"SeasonChallengeClaimed",1,{CustomField01=a,CustomField02=b})
		Data.Sync(p)
		Notify:FireClient(p,name.." · Season XP received","rare_Epic")
		return true,snapshot(p,d,now)
	end
	local plan,claims,key,name,badge
	if op=="Season" then
		local s=D.BySeason[a]
		local ledger=s and d.M8.Seasons[s.Id]
		if not ledger or now<s.Start or now>=s.Finish+s.ClaimGrace or type(b)~="number" or b%1~=0 or b<1
			or b>State.Level(ledger,s) then return false,"Season reward unavailable" end
		plan=s.Track[b] claims=ledger.Claims key=tostring(b) name=s.Name.." Level "..b
	elseif op=="Collection" then
		local target
		for _,e in ipairs(D.Editions) do if e.Id==a then target=e break end end
		plan=type(b)=="number" and D.Milestones[b]
		if not target or not plan then return false,"Unknown collection milestone" end
		local ledger=State.Score(d,target)
		if ledger.Best<plan.Percent*10 then return false,"Collection milestone incomplete" end
		claims=ledger.Claims key=tostring(plan.Percent) name=plan.Percent.."% collection"
	elseif op=="Achievement" then
		badge=D.ByAchievement[a]
		if not badge then return false,"Unknown achievement" end
		local metrics=State.Metrics(d,D.Editions[1])
		if metrics[badge.Metric]<badge.Goal then return false,"Achievement incomplete" end
		claims=d.M8.AchievementClaims key=a plan=D.AchievementRewards[badge.Tier] name=badge.Name
	else
		return false,"Unknown progression request"
	end
	if claims[key] then return false,"Already claimed" end
	local amount=E.M8Reward(Data.PriceUnit(p),plan)
	if not canGrant(d,amount) then return false,"Altar Essence limit reached. Claim after the next UTC reset." end
	claims[key]=true
	grant(p,d,amount,plan,name)
	Analytics.Custom(p,"M8RewardClaimed",1,{CustomField01=op,CustomField02=tostring(a),CustomField03=key})
	if badge then awardBadge(p,d,badge) end
	return true,snapshot(p,d,now)
end
Season.OnServerInvoke=function(p,op,a,b,c)
	if type(op)~="string" or #op>14 or (a~=nil and (type(a)~="string" or #a>48))
		or (type(b)=="string" and #b>48) then return false,"Invalid progression request" end
	local now=os.clock()
	if now<(last[p] or 0) then return false,"Try again in a moment" end
	last[p]=now+.20
	return action(p,op,a,b,c,os.time())
end
Season.Parent=Remotes
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
local function monitor(p)
	task.spawn(function()
		local joined=false
		while p.Parent do
			local d=Data.Get(p)
			if d and p:GetAttribute("Loaded") and not p:GetAttribute("Handoff") then
				local s=D.Active(os.time())
				local ledger=s and d.M8.Seasons[s.Id]
				if ledger then trackLevel(p,s,ledger) end
				for _,e in ipairs(D.Editions) do State.Score(d,e) end
				if not joined then
					joined=true
					for id in pairs(d.M8.BadgePending) do local badge=D.ByAchievement[id] if badge then awardBadge(p,d,badge) end end
				end
			end
			task.wait(40)
		end
	end)
end
Players.PlayerAdded:Connect(monitor)
for _,p in ipairs(Players:GetPlayers()) do monitor(p) end

-- Add navigation to the existing surface. Travel anchors and tree geometry stay under M4.
if L.Enabled() then
	local World=require(script.Parent:WaitForChild("M4WorldRuntime"))
	local A=require(ServerStorage:WaitForChild("M4Architecture"))
	local map=workspace:FindFirstChild("M4ActiveWorld")
	local timber=World.Active and map and map:FindFirstChild("TimberHaven")
	if timber then
		local stand=A.Part(timber,"Season and Collection Board",Vector3.new(6,3,2),CFrame.new(-36,1.5,-2965),
			Color3.fromRGB(86,114,79),Enum.Material.WoodPlanks)
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name="M8SeasonPrompt" prompt.ActionText="Open seasons" prompt.ObjectText="Season and Collection Board"
		prompt.RequiresLineOfSight=false prompt.MaxActivationDistance=12 prompt.Parent=stand
		local sign=Instance.new("BillboardGui")
		sign.Size=UDim2.fromOffset(175,30) sign.MaxDistance=70 sign.StudsOffset=Vector3.new(0,3,0) sign.Parent=stand
		local label=Instance.new("TextLabel")
		label.Size=UDim2.fromScale(1,1) label.BackgroundColor3=Color3.fromRGB(37,49,39) label.TextColor3=Color3.fromRGB(248,224,173)
		label.TextScaled=true label.Font=Enum.Font.GothamBold label.Text="SEASONS & COLLECTION" label.Parent=sign
		local marker=A.Part(timber,"Portal Cliffs field sign",Vector3.new(6,3,1),CFrame.new(215,1.5,-3207),
			Color3.fromRGB(86,114,79),Enum.Material.WoodPlanks)
		local nav=sign:Clone()
		nav.Size=UDim2.fromOffset(212,48)
		nav.MaxDistance=72
		nav.TextLabel.Text="ISLAND GATES  →\nCheck Power and unlock requirements"
		nav.Parent=marker
	end
end
