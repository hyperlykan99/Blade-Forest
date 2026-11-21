local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Prompts=game:GetService("ProximityPromptService")
local Tween=game:GetService("TweenService")
local T=require(RS:WaitForChild("UITheme"))
local D=require(RS:WaitForChild("M8Design"))
local C=require(RS:WaitForChild("BladeConfig"))
local p=Players.LocalPlayer
local remote=RS:WaitForChild("Remotes"):WaitForChild("M8Progression",30)
if not remote then return end
local function new(class,where,props)
	local o=Instance.new(class)
	for k,v in pairs(props) do o[k]=v end
	o.Parent=where return o
end
local gold=Color3.fromRGB(245,197,116)
local sage=Color3.fromRGB(134,223,169)
local dark=Color3.fromRGB(29,43,36)
local forest=Color3.fromRGB(51,67,53)
local layer=new("ScreenGui",p:WaitForChild("PlayerGui"),{Name="M8JournalUI",DisplayOrder=18,ResetOnSpawn=false})
local tile=new("TextButton",layer,{Name="M8SeasonButton",Text="SEASONS",Size=UDim2.fromOffset(76,76)})
local panel,body,close=T.Panel(layer,"Journal","FOREST JOURNAL",gold,790,.9)
panel.Size=UDim2.fromScale(.93,.87)
body.BackgroundTransparency=0 body.BackgroundColor3=dark
local tabs=new("Frame",body,{Size=UDim2.new(1,-12,0,37),Position=UDim2.fromOffset(6,4),BackgroundTransparency=1})
local scroll=new("ScrollingFrame",body,{Name="Entries",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,
	Position=UDim2.fromOffset(7,51),Size=UDim2.new(1,-14,1,-88),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
new("UIListLayout",scroll,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local footer=T.Label(body,{Position=UDim2.new(0,8,1,-31),Size=UDim2.new(1,-16,0,25),
	Text="",TextColor3=gold,TextSize=13,TextScaled=false,TextWrapped=true})
local sound=new("Sound",layer,{SoundId="rbxasset://sounds/electronicpingshort.wav"})
local page,selected,edition,category="Season",#D.Seasons,1,nil
local state,running,render
local order=0
local function call(op,a,b,c)
	if running then return end
	running=true
	local invoked,ok,value=pcall(remote.InvokeServer,remote,op,a,b,c)
	running=false
	if not invoked or not ok then footer.Text=invoked and tostring(value) or "Journal unavailable" return end
	if type(value)=="table" then state=value end
	if op~="Read" and op~="Guide" then
		footer.Text="Reward claimed"
		sound.Volume=math.clamp(tonumber(p:GetAttribute("Pref_SFX")) or .8,0,1)*.32
		if sound.Volume>0 then sound:Play() end
		if not p:GetAttribute("Pref_ReducedMotion") and p:GetAttribute("Pref_Graphics")~="Low" then
			footer.TextColor3=Color3.new(1,1,1)
			Tween:Create(footer,TweenInfo.new(.55),{TextColor3=gold}):Play()
		end
	end
	render()
end
local function label(where,text,x,y,width,height,color,size)
	return T.Label(where,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.new(width,-x-6,0,height),
		TextColor3=color,TextScaled=false,TextSize=size,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function action(where,text,x,y,w,fn)
	local b=T.Button(where,{Text=text,Position=UDim2.new(x,3,0,y),Size=UDim2.new(w,-7,0,32)},T.Color.Teal)
	b.TextWrapped=true b.Activated:Connect(fn) return b
end
local function row(title,info,status,fn,progress)
	order+=1
	local root=new("Frame",scroll,{Name="JournalEntry",Size=UDim2.new(1,-4,0,progress and 92 or 78),
		BackgroundColor3=forest,LayoutOrder=order})
	T.Corner(root,8)
	label(root,title,9,4,1,24,gold,16)
	local width=status and .73 or 1
	local detail=label(root,info,9,29,width,43,T.Color.Cream,13)
	if status then
		if fn then action(root,status,.73,32,.27,fn)
		else label(root,status,0,32,1,35,sage,13).TextXAlignment=Enum.TextXAlignment.Right end
	end
	if progress then
		local track=new("Frame",root,{Size=UDim2.new(1,-18,0,6),Position=UDim2.fromOffset(9,79),BackgroundColor3=dark})
		T.Corner(track,3)
		local fill=new("Frame",track,{Size=UDim2.fromScale(math.clamp(progress,0,1),1),BackgroundColor3=sage,BorderSizePixel=0})
		T.Corner(fill,3)
	end
	return detail
end
local function preview(detail,id,folderName)
	local source=RS:FindFirstChild(folderName)
	local template=source and source:FindFirstChild(id)
	if not template or not template:IsA("Model") then return end
	local row=detail.Parent
	local viewport=new("ViewportFrame",row,{Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(62,62),
		BackgroundColor3=dark,Ambient=Color3.fromRGB(175,181,168),LightColor=Color3.fromRGB(255,234,197)})
	T.Corner(viewport,6)
	local model=template:Clone()
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("LuaSourceContainer") or part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Light") then part:Destroy() end
	end
	model.Parent=viewport
	model:PivotTo(CFrame.new())
	local center,size=model:GetBoundingBox()
	local dist=math.max(size.X,size.Y,size.Z)*1.65+1
	local camera=new("Camera",viewport,{FieldOfView=36,CFrame=CFrame.lookAt(center.Position+Vector3.new(dist*.76,dist*.45,dist*.76),center.Position)})
	viewport.CurrentCamera=camera
	for _,child in ipairs(row:GetChildren()) do
		if child:IsA("TextLabel") and child.TextXAlignment==Enum.TextXAlignment.Left then
			child.Position+=UDim2.fromOffset(65,0)
			child.Size-=UDim2.fromOffset(65,0)
		end
	end
end
local function rewards(item)
	local parts={}
	if item.Weapon then table.insert(parts,C.WeaponById[item.Weapon].Name) end
	if item.Cosmetic then
		for _,cosmetic in ipairs(D.Cosmetics) do
			if cosmetic.Id==item.Cosmetic then table.insert(parts,item.Title and cosmetic.Title or cosmetic.Aura) end
		end
	end
	if item.Essence then table.insert(parts,item.Essence.." Essence") end
	if item.Souls then table.insert(parts,item.Souls.." Souls") end
	if item.XP then table.insert(parts,item.XP.." Mastery XP") end
	if item.Logs then table.insert(parts,item.Logs.." × your Logs reward unit") end
	return table.concat(parts," · ")
end
local clockLabel
local function remaining(seconds)
	local sec=math.max(0,math.floor(seconds))
	return string.format("%dd %02dh %02dm %02ds",sec//86400,sec//3600%24,sec//60%60,sec%60)
end
local function seasonStatus(s,now)
	if now<s.Start then return "Starts in "..remaining(s.Start-now) end
	if now<s.Finish then return "Ends in "..remaining(s.Finish-now) end
	if now<s.Finish+s.ClaimGrace then return "Reward claims close in "..remaining(s.Finish+s.ClaimGrace-now) end
	return "Archived · Earned cosmetics stay in Social"
end
local function season()
	local s=D.Seasons[selected]
	local ledger=state.Seasons[s.Id]
	local now=workspace:GetServerTimeNow()
	local canClaim=now>=s.Start and now<s.Finish+s.ClaimGrace
	if #D.Seasons>1 then
		row("Season history",s.Name,"Next season",function() selected=selected%#D.Seasons+1 render() end)
	end
	row(s.Name,s.Description)
	clockLabel=row("Season countdown",seasonStatus(s,now))
	local threshold=s.XPPerLevel*#s.Track
	row("Level "..ledger.Level.." / "..#s.Track,ledger.XP.." / "..threshold.." Season XP · Free track",nil,nil,ledger.XP/threshold)
	local function challenge(q,progress,week)
		local n=progress and progress.Count or 0
		local claimed=progress and progress.Claimed
		local fn=canClaim and n>=q.Goal and not claimed and function() call("Challenge",s.Id,q.Id,week) end or nil
		row(q.Name,n.." / "..q.Goal.." · +"..q.XP.." Season XP",claimed and "Claimed" or fn and "Claim",fn,n/q.Goal)
	end
	if now>=s.Start and now<s.Finish+s.ClaimGrace then
		local week=D.WeekAt(s,now)
		local current=ledger.Weeks[tostring(week)] or {}
		row("Week "..week,"Complete challenges alongside Contracts, Trials and forest play.")
		for _,q in ipairs(s.Challenges) do challenge(q,current[q.Id],week) end
		for i=1,week-1 do
			local old=ledger.Weeks[tostring(i)]
			if old then for _,q in ipairs(s.Challenges) do
				local record=old[q.Id]
				if record and record.Count>=q.Goal and not record.Claimed then challenge(q,record,i) end
			end end
		end
		for _,q in ipairs(s.Events) do
			if week>=q.FromWeek and (week<=q.ThroughWeek or ledger.Events[q.Id]) then challenge(q,ledger.Events[q.Id],0)
			elseif week<q.FromWeek then row(q.Name,"Limited challenge begins in week "..q.FromWeek) end
		end
	end
	for i,v in ipairs(s.Track) do
		local claimed=ledger.Claims[tostring(i)]
		local ready=canClaim and ledger.Level>=i and not claimed
		local detail=row("Level "..i,rewards(v),claimed and "Claimed" or ready and "Claim" or "Locked",ready and function() call("Season",s.Id,i) end or nil)
		if v.Weapon then preview(detail,v.Weapon,"BladeModels") end
	end
end
local function collection()
	local v=D.Editions[edition]
	local e=state.Editions[v.Id]
	if #D.Editions>1 then row("Collection edition",v.Id,"Next edition",function() edition=edition%#D.Editions+1 render() end) end
	row("Foundations collection",string.format("%.1f%% · Personal best for this edition",e.Best/10),nil,nil,e.Best/1000)
	for i,m in ipairs(D.Milestones) do
		local claimed=e.Claims[tostring(m.Percent)]
		local ready=e.Best>=m.Percent*10 and not claimed
		local detail=row(m.Percent.."% milestone",rewards(m),claimed and "Claimed" or ready and "Claim" or "Locked",ready and function() call("Collection",v.Id,i) end or nil)
		if m.Weapon then preview(detail,m.Weapon,"BladeModels") end
	end
	for _,r in ipairs(e.Rows) do
		local detail=row(r.Name,r.Count.." / "..r.Target.." · "..r.Points.." / "..r.Weight.." points",nil,nil,r.Points/r.Weight)
		if r.Name=="Pet forms" then preview(detail,v.Pets[1],"PetModels") end
	end
end
local function achievements()
	local categories,seen={},{}
	for _,a in ipairs(D.Achievements) do if not seen[a.Category] then seen[a.Category]=true table.insert(categories,a.Category) end end
	row("Achievement categories",categories[category or 0] or "All categories","Next filter",function()
		category=((category or 0)+1)%(#categories+1) render()
	end)
	for _,a in ipairs(D.Achievements) do
		if category and category>0 and a.Category~=categories[category] then continue end
		local entry=state.Achievements[a.Id]
		local ready=entry.Progress>=a.Goal and not entry.Claimed
		row(a.Name,a.Category.." · "..C.FormatNumber(entry.Progress).." / "..C.FormatNumber(a.Goal).."\n"..rewards(D.AchievementRewards[a.Tier]),
			entry.Claimed and "Claimed" or ready and "Claim" or nil,ready and function() call("Achievement",a.Id) end or nil,entry.Progress/a.Goal)
	end
end
local function guide()
	for _,q in ipairs(D.Guide) do
		if q.Mastery and state.Mastery<q.Mastery then continue end
		row(({Move="Movement and chopping",Upgrade="Upgrade Shop",Roll="Weapons and rolling",Pets="Pet companions",Traits="Traits",
			Mastery="Mastery and Tech Tree",Contracts="Contracts and Trials",Portals="Island unlocks",Forge="Forge Workshop",Social="Social Hall"})[q.Id],
			q.Text)
	end
	row("Boss warnings","Move out of warning circles. In Heart of Winter, break all three Winter Seals before attacking the shielded boss.")
end
local screens={Season=season,Collection=collection,Achievements=achievements,Guide=guide}
render=function()
	if not panel.Visible then return end
	clockLabel=nil order=0
	for _,o in ipairs(scroll:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end
	if state then screens[page]() else row("Forest Journal","Loading your progression.") end
end
local function open()
	panel.Visible=true footer.Text=""
	T.Pop(panel)
	render()
	call("Read")
end
for i,k in ipairs({"Season","Collection","Achievements","Guide"}) do
	action(tabs,k,(i-1)/4,0,.25,function()
		page=k scroll.CanvasPosition=Vector2.zero footer.Text="" render() call("Read")
	end)
end
tile.Activated:Connect(function() if panel.Visible then panel.Visible=false else open() end end)
close.Activated:Connect(function() panel.Visible=false end)
Prompts.PromptTriggered:Connect(function(pr,who) if pr.Name=="M8SeasonPrompt" and (not who or who==p) then open() end end)
task.spawn(function()
	local ticks=0
	while layer.Parent do
		task.wait(1)
		if panel.Visible then
			if clockLabel then clockLabel.Text=seasonStatus(D.Seasons[selected],workspace:GetServerTimeNow()) end
			ticks+=1
			if ticks%18==0 and not running then call("Read") end
		end
	end
end)
