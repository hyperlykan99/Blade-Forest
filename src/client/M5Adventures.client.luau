local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local T=require(ReplicatedStorage:WaitForChild("UITheme"))
local C=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Adventures")
local rgb=Color3.fromRGB
local ink,plank,rim=rgb(29,28,36),rgb(47,48,55),rgb(102,108,119)
local gold,teal,cream=rgb(239,199,113),rgb(96,185,174),rgb(250,235,204)
local gui=Instance.new("ScreenGui") gui.Name="M5AdventureUI" gui.ResetOnSpawn=false gui.DisplayOrder=16
gui.Parent=player:WaitForChild("PlayerGui")
local tile=Instance.new("TextButton")
tile.Name="M5AdventuresButton" tile.Text="ADVENTURES" tile.Size=UDim2.fromOffset(76,76) tile.Parent=gui
local panel,body,close=T.Panel(gui,"AdventuresPanel","ADVENTURES",teal,780,.86)
panel.Size=UDim2.fromScale(.92,.86)
body.BackgroundColor3=ink body.BackgroundTransparency=0

local function makeLabel(parent,name,pos,size,text,color,font)
	local item=T.Label(parent,{Name=name,Position=pos,Size=size,Text=text,TextScaled=false,
		TextSize=font or 14,TextColor3=color or cream,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
	return item
end
local tabs=Instance.new("Frame")
tabs.Name="AdventureTabs" tabs.BackgroundTransparency=1
tabs.Position=UDim2.fromOffset(7,5) tabs.Size=UDim2.new(1,-14,0,36) tabs.Parent=body
local tabDefs={"Story","Contracts","Trials","Expeditions","Events"}
local tabButtons={}
local content=Instance.new("ScrollingFrame")
content.Name="Contents" content.Position=UDim2.fromOffset(7,49) content.Size=UDim2.new(1,-14,1,-82)
content.BackgroundTransparency=1 content.BorderSizePixel=0
content.ScrollBarThickness=5 content.AutomaticCanvasSize=Enum.AutomaticSize.Y content.CanvasSize=UDim2.new()
content.Parent=body
local scrollLayout=Instance.new("UIListLayout")
scrollLayout.Padding=UDim.new(0,5) scrollLayout.SortOrder=Enum.SortOrder.LayoutOrder scrollLayout.Parent=content
local footer=makeLabel(body,"Status",UDim2.new(0,8,1,-27),UDim2.new(1,-16,0,23),"",gold,13)

local hud=Instance.new("Frame") hud.Name="M5Activity" hud.BackgroundColor3=ink
hud.Size=UDim2.new(1,0,0,29) hud.LayoutOrder=8 hud.Visible=false
T.Corner(hud,6) T.Stroke(hud,rim,1) T.AttachToHud(hud,"StatusRail")
local hudLine=makeLabel(hud,"Activity",UDim2.fromOffset(6,0),UDim2.new(1,-10,1,0),"",cream,12)
local hudBtn=T.Button(hud,{Name="ActivityControls",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=""},teal)
for _,child in ipairs(hudBtn:GetChildren()) do if child:IsA("UIStroke") then child:Destroy() end end

local section,island,period="Story",1,"Daily"
local state,board,message,busy
local rowNumber=0
local render
local function seconds(untilAt)
	local n=math.max(0,math.floor((untilAt or 0)-workspace:GetServerTimeNow()))
	local h=math.floor(n/3600)
	if h>=24 then return string.format("%dd %dh",math.floor(h/24),h%24) end
	if h>0 then return string.format("%dh %02dm",h,math.floor(n/60)%60) end
	return string.format("%d:%02d",math.floor(n/60),n%60)
end
local function request(action,...)
	if busy then return end
	busy=true
	local called,ok,value=pcall(remote.InvokeServer,remote,action,...)
	busy=false
	if called and ok then
		if action=="Board" then board=value
		elseif type(value)=="table" then state=value end
		message=nil
	else
		message=called and tostring(value) or "Server unavailable. Try again."
	end
	if render then render() end
end
local function row(title,detail,actions,accent,height)
	rowNumber+=1
	local f=Instance.new("Frame") f.Name="AdventureRow" f.LayoutOrder=rowNumber
	f.Size=UDim2.new(1,-6,0,height or 65) f.BackgroundColor3=plank f.Parent=content
	T.Corner(f,8) T.Stroke(f,accent or rim,1)
	local a=actions and #actions or 0
	local edge=a==1 and .27 or .40
	local span=a==0 and UDim2.new(1,-17,0,24) or UDim2.new(1-edge,-15,0,24)
	makeLabel(f,"Title",UDim2.fromOffset(8,3),span,title,accent or cream,15)
	makeLabel(f,"Description",UDim2.fromOffset(8,26),UDim2.new(span.X.Scale,span.X.Offset,1,-29),detail,cream,12)
	for i,d in ipairs(actions or {}) do
		local width=edge/a
		local b=T.Button(f,{Name=d[1],Position=UDim2.new(1-edge+(i-1)*width,1,.5,-17),Size=UDim2.new(width,-5,0,34),Text=d[1]},d[3] or teal)
		b.Activated:Connect(d[2])
	end
end
local function head(a,b)
	row(a,b,nil,gold,56)
end
local function boardRows()
	if not board then return end
	head(board.Scope,#board.Rows>0 and "UTC weekly ranking" or "No scores recorded for this week")
	for i,entry in ipairs(board.Rows) do
		local user=Players:GetPlayerByUserId(entry.UserId)
		row(string.format("%d  ·  %s",i,user and user.DisplayName or ("Player "..entry.UserId)),tostring(entry.Value),nil,nil,48)
	end
end

local function showStory()
	local id=M.Islands[island]
	local group=state.Quests[id]
	row(M.Names[id],group.Open and string.format("%d / 10 steps claimed",group.Claimed) or "Unlock this island to claim its steps",{
		{"Previous",function() island=(island-2)%#M.Islands+1 render(true) end},
		{"Next",function() island=island%#M.Islands+1 render(true) end},
	},gold)
	for i,q in ipairs(M.Chains[id]) do
		local have=group.Progress[i] or 0
		local claimed=i<=group.Claimed
		local ready=group.Open and i==group.Claimed+1 and have>=q[4]
		local status=claimed and "Claimed" or string.format("%s / %s",C.FormatNumber(have),C.FormatNumber(q[4]))
		if ready then status..=" · "..(3+i).." Souls · "..(25+i*12).." XP" end
		local act=ready and {{"Claim",function() request("Quest",id,i) end}} or nil
		row(i.."  ·  "..q[1],q[5].."  ·  "..status,act,ready and teal or claimed and gold or nil)
	end
end

local function showContracts()
	local group=state.Contracts[period]
	row(period.." contracts",string.format("%d / %d selected  ·  resets in %s  ·  streak %d",group.Picked,M.Periods[period].Pick,seconds(group.Ends),state.Streak),{
		{period=="Daily" and "Weekly" or "Daily",function() period=period=="Daily" and "Weekly" or "Daily" render(true) end},
	},gold)
	for i,offer in ipairs(group.Offers) do
		local spec=M.ContractCatalog[period][offer.Id]
		local reward=string.format("%s Logs + %d Souls",C.FormatNumber(group.PriceUnit*spec[5]),spec[6])
		local metric=(M.Metrics[offer.Kind] or offer.Kind)..(offer.Filter and " · "..M.Names[offer.Filter] or "")
		local stateText=offer.Claimed and "Claimed" or string.format("%d / %d",offer.Progress,offer.Goal)
		local actions={}
		if not offer.Picked and group.Picked<M.Periods[period].Pick then
			table.insert(actions,{"Select",function() request("Accept",period,i,group.Key) end})
		end
		if not offer.Picked and group.CanReroll then
			table.insert(actions,{"Reroll",function() request("Reroll",period,i,group.Key) end,rim})
		end
		if offer.Picked and not offer.Claimed and offer.Progress>=offer.Goal then
			table.insert(actions,{"Claim",function() request("Claim",period,i,group.Key) end})
		end
		row(offer.Name,metric.."  ·  "..stateText.."\n"..reward,actions,offer.Claimed and gold or nil,74)
	end
end
local function runControls(kind)
	local phase=player:GetAttribute("M5RunPhase")
	local id=player:GetAttribute("M5Run")
	if id~=kind then return false end
	local acts={}
	if phase=="DepthClear" then table.insert(acts,{"Descend",function() request("Next") end}) end
	if phase~="Returning" and phase~="Loading" then table.insert(acts,{"Exit",function() request("Exit") end,rgb(168,84,73)}) end
	local info=id=="Trial" and (player:GetAttribute("M5RunScore") or 0).." trees" or
		"Depth "..(player:GetAttribute("M5RunDepth") or 1).." · "..(player:GetAttribute("M5RunTrees") or 0).." left"
	row(phase=="DepthClear" and "Depth cleared" or "Run in progress",info.."  ·  "..seconds(player:GetAttribute("M5RunEnds")),acts,teal)
	return true
end
local function showTrials()
	if not runControls("Trial") then
		row("60-second Chopping Trial","Solo arena · standardized blades and movement",{{"Enter",function() request("Trial") end}},teal)
	end
	head("Ranks and Tokens",string.format("Weekly best %d  ·  Tokens %d  ·  today %d/%d",state.TrialBest,state.Tokens,state.TrialTokensToday,M.Trial.TokenCap))
	local ranks={}
	for i,label in ipairs(M.Trial.Ranks) do table.insert(ranks,label.." "..M.Trial.Goals[state.Tier][i]) end
	row("Trees needed by rank",table.concat(ranks,"  ·  "),nil,nil,60)
	row("Weekly leaderboard","Resets in "..seconds(state.WeekEnd),{{"View ranks",function() request("Board","Trial") end}},gold)
	boardRows()
	head("Trial reward shop","Earn Tokens from ranked Trials")
	for _,key in ipairs({"Logs","Souls","Seal"}) do
		local item=M.Shop[key]
		local remaining=item.Limit-(state.Shop[key] or 0)
		local line=item.Logs and C.FormatNumber(item.Logs*state.PriceUnit).." Logs" or item.Souls and item.Souls.." Souls" or "1 Trial Seal for future crafting"
		local acts=remaining>0 and state.Tokens>=item.Cost and {{"Redeem",function() request("Shop",key,state.RankWeek,state.Shop[key] or 0) end}} or nil
		row(item.Name,line.."  ·  "..item.Cost.." Tokens  ·  "..remaining.." left this week",acts)
	end
end
local function showExpeditions()
	if not runControls("Expedition") then head("Endless Expeditions","Use the Expedition Gate in Frostbound Reach to enter the solo forest.") end
	head("Depth record",string.format("All-time depth %d  ·  weekly best %d  ·  %d/%d rewards today",state.DepthEver,state.DepthBest,state.DepthClaims,M.Expedition.RewardClaimsPerDay))
	row("Frost Core stash",tostring(state.Materials[M.Expedition.Material] or 0).." earned from eligible depth clears",nil,nil,53)
	row("Weekly depth leaderboard","Resets in "..seconds(state.WeekEnd),{{"View ranks",function() request("Board","Depth") end}},gold)
	boardRows()
end
local function showEvents()
	local active=workspace:GetAttribute("M5EventId")
	local islandId=workspace:GetAttribute("M5EventIsland")
	if active then
		head(workspace:GetAttribute("M5EventName") or active,
			(M.Names[islandId] or "").." · ends in "..seconds(workspace:GetAttribute("M5EventEnd")))
	else
		local nextName=workspace:GetAttribute("M5EventNextName") or "Regional event"
		local nextIsland=M.Names[workspace:GetAttribute("M5EventNextIsland")] or "Forest"
		head(nextName,nextIsland.." · opens in "..seconds(workspace:GetAttribute("M5EventNext")))
	end
	for _,event in ipairs(M.Events) do
		row(event.Name,(M.Names[event.Island] or "Rotating island")..string.format(" · ×%g Logs · ×%g Luck",event.Logs,event.Luck),nil,
			event.Id==active and event.Color or nil)
	end
	local legacy=workspace:GetAttribute("EventId")
	if legacy then row("Server event · "..legacy,"Ends in "..seconds(workspace:GetAttribute("EventEnd")),nil,gold) end
	row("Temporary bonuses","The strongest eligible temporary Logs and Luck effects apply within the existing caps.",nil,nil)
end

render=function(reset)
	if not panel.Visible then return end
	local retain=not reset and content.CanvasPosition or Vector2.zero
	for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	rowNumber=0
	for name,button in pairs(tabButtons) do button.BackgroundColor3=name==section and teal or plank end
	footer.Text=message or ""
	if section=="Events" then showEvents()
	elseif not state then head("Loading Adventures","Waiting for your profile")
	elseif section=="Story" then showStory()
	elseif section=="Contracts" then showContracts()
	elseif section=="Trials" then showTrials()
	else showExpeditions() end
	task.defer(function() content.CanvasPosition=retain end)
end

for i,name in ipairs(tabDefs) do
	local b=T.Button(tabs,{Name=name,Position=UDim2.new((i-1)/5,1,0,1),Size=UDim2.new(1/5,-4,1,-2),Text=name},plank)
	tabButtons[name]=b
	b.Activated:Connect(function() section=name board=nil message=nil render(true) end)
end
tile.Activated:Connect(function()
	panel.Visible=not panel.Visible
	if panel.Visible then T.Pop(panel) render(true) task.spawn(request,"Get") end
end)
close.Activated:Connect(function() panel.Visible=false end)
hudBtn.Activated:Connect(function()
	section=player:GetAttribute("M5Run")=="Trial" and "Trials" or player:GetAttribute("M5Run")=="Expedition" and "Expeditions" or "Events"
	panel.Visible=true
	board=nil
	render(true)
	task.spawn(request,"Get")
end)
local function badge()
	local n=player:GetAttribute("M5Ready") or 0
	tile:SetAttribute("Badge",n>0 and tostring(n) or nil)
end
player:GetAttributeChangedSignal("M5Ready"):Connect(badge)
badge()
player:GetAttributeChangedSignal("M5Run"):Connect(function()
	if player:GetAttribute("M5Run") then panel.Visible=false end
end)
task.spawn(function()
	while true do
		task.wait(1)
		local active=player:GetAttribute("M5Run")
		local regional=workspace:GetAttribute("M5EventIsland")==player:GetAttribute("CurrentIsland") and workspace:GetAttribute("M5EventName")
		hud.Visible=active~=nil or regional~=nil and regional~=false
		if active then
			local detail=active=="Trial" and string.format("%d trees",player:GetAttribute("M5RunScore") or 0)
				or string.format("Depth %d · %d left",player:GetAttribute("M5RunDepth") or 1,player:GetAttribute("M5RunTrees") or 0)
			hudLine.Text=active.."   ·   "..detail.."   ·   "..seconds(player:GetAttribute("M5RunEnds"))
		elseif regional then hudLine.Text=regional.." · "..seconds(workspace:GetAttribute("M5EventEnd")) end
	end
end)
task.spawn(function()
	while true do
		task.wait(3)
		if panel.Visible then request("Get") end
	end
end)
