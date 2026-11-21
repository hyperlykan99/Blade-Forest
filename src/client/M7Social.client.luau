local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Prompt=game:GetService("ProximityPromptService")
local T=require(RS:WaitForChild("UITheme"))
local C=require(RS:WaitForChild("BladeConfig"))
local D=require(RS:WaitForChild("M7Design"))
local H=game:GetService("HttpService")
local p=Players.LocalPlayer
local rf=RS:WaitForChild("Remotes"):WaitForChild("M7Social",35)
if not rf then return end
local gold=Color3.fromRGB(242,190,121)
local teal=Color3.fromRGB(129,219,201)
local ink=Color3.fromRGB(35,30,37)
local brown=Color3.fromRGB(58,47,47)
local function new(class,parent,props)
	local o=Instance.new(class)
	for k,v in pairs(props or {}) do o[k]=v end
	o.Parent=parent
	return o
end
local gui=new("ScreenGui",p.PlayerGui,{Name="M7SocialUI",ResetOnSpawn=false,DisplayOrder=17})
local tile=new("TextButton",gui,{Name="M7SocialButton",Text="SOCIAL",Size=UDim2.fromOffset(76,76)})
local panel,body,close=T.Panel(gui,"Social","SOCIAL HALL",gold,840,.9)
panel.Size=UDim2.fromScale(.94,.88)
body.BackgroundTransparency=0 body.BackgroundColor3=ink
local nav=new("Frame",body,{Name="Tabs",BackgroundTransparency=1,Size=UDim2.new(1,-12,0,37),Position=UDim2.fromOffset(6,4)})
local scroll=new("ScrollingFrame",body,{Name="Cards",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
	Size=UDim2.new(1,-12,1,-77),Position=UDim2.fromOffset(6,45),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
new("UIListLayout",scroll,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local footer=T.Label(body,{Position=UDim2.new(0,8,1,-27),Size=UDim2.new(1,-16,0,23),Text="",TextSize=13,TextScaled=false,
	TextColor3=gold,TextWrapped=true})
local state,remoteCard,remoteGuild,leaderboard
local page="Party"
local mode,slot,countdown="Weapon",1,nil
local pending,render
local order=0
local function call(op,a,b,c)
	local called,ok,result=pcall(rf.InvokeServer,rf,op,a,b,c)
	if not called then return false,"Social service unavailable" end
	return ok,result
end
local function refresh()
	local ok,data=call("Read")
	if ok then state=data else footer.Text=tostring(data) end
	return ok
end
local function run(op,a,b,c)
	if pending then return end
	pending=true
	local ok,result=call(op,a,b,c)
	if ok then
		if op=="Inspect" then remoteCard=result
		elseif op=="GuildBoard" then leaderboard=result
		elseif op=="GuildInspect" then remoteGuild=result
		else task.wait(.25) refresh() end
	end
	pending=false
	render()
	footer.Text=ok and "" or tostring(result)
end
local function label(parent,text,x,y,w,h,color,size)
	return T.Label(parent,{Text=text,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,TextScaled=false,
		TextSize=size or 13,TextColor3=color or T.Color.Cream,Position=UDim2.fromOffset(x,y),Size=UDim2.new(w,-x-5,0,h)})
end
local function action(parent,text,x,w,y,callback)
	local b=T.Button(parent,{Text=text,Position=UDim2.new(x,3,0,y),Size=UDim2.new(w,-8,0,32)},T.Color.Teal)
	b.TextWrapped=true b.Activated:Connect(callback)
	return b
end
local function row(title,content,buttons,childHeight)
	order+=1
	local height=childHeight or (buttons and 110 or 74)
	local root=new("Frame",scroll,{Name="SocialCard",BackgroundColor3=brown,Size=UDim2.new(1,-4,0,height),LayoutOrder=order})
	T.Corner(root,8)
	label(root,title,10,4,1,25,gold,17)
	local detail=label(root,content or "",10,31,1,41,nil,13)
	if buttons then
		for i,s in ipairs(buttons) do action(root,s[1],(i-1)/#buttons,1/#buttons,height-37,s[2]) end
	end
	return root,detail
end
local function input(parent,hint,y,limit,initial)
	local b=new("TextBox",parent,{PlaceholderText=hint,Text=initial or "",TextSize=15,BackgroundColor3=ink,
		TextColor3=T.Color.Cream,PlaceholderColor3=teal,ClearTextOnFocus=false,Font=Enum.Font.Gotham,
		Size=UDim2.new(1,-20,0,34),Position=UDim2.fromOffset(10,y)})
	T.Corner(b,5)
	b:GetPropertyChangedSignal("Text"):Connect(function() if #b.Text>limit then b.Text=b.Text:sub(1,limit) end end)
	return b
end
local function button(name,op,a,b,c)
	return {name,function() run(op,a,b,c) end}
end
local function name(id)
	local w=C.WeaponById[id] or C.PetById[id]
	return w and w.Name or "Unselected"
end
local function itemLine(item)
	local w=C.WeaponById[item.Id]
	if item.Kind=="Weapon" and w then
		return (item.Rarity or "").." · ★"..(item.Star or 0)..(item.Shiny and " · Shiny" or "")
			.." · Base Power "..C.FormatNumber(C.GetWeaponPower(item.Id,0))
	end
	local pet=C.PetById[item.Id]
	return (item.Rarity or "Pet").." · "..(item.Stage or "Normal").." · +"..string.format("%.2f",pet and pet.Luck or 0).." Luck"
end
local function builderParty()
	local party=state.Party
	local leader=party.Members[1] and party.Members[1].User==p.UserId
	if #party.Members==0 then
		row("Create a party","Up to four players. Invitations expire after 45 seconds.",{button("Create","PartyCreate")})
	else
		row("Your party · "..#party.Members.."/4",leader and "You lead the party." or "The leader starts group encounters.",{button("Leave party","PartyLeave")})
		for _,m in ipairs(party.Members) do
			local controls
			if leader and m.User~=p.UserId then controls={button("Make leader","PartyLeader",m.User),button("Kick","PartyKick",m.User)} end
			row(m.Name..(m.Leader and " · Leader" or ""), (m.Island or "Travelling")..(m.Run and " · "..m.Run or ""),controls)
		end
		if leader and #party.Members>=2 then
			row("Group encounters","Gather every member at the active raid arena, Frostbound Expedition Gate or Winter Sanctum. Individual requirements still apply.",
				{button("Rally raid","PartyRun","Raid"),button("Expedition","PartyRun","Expedition"),button("Heart of Winter","PartyRun","Heart")})
		end
	end
	if party.Incoming then
		row("Invitation from "..party.Incoming.Name,"Accept to join their party.",{button("Accept","PartyAccept",party.Incoming.User),button("Decline","PartyDecline",party.Incoming.User)})
	end
	if #party.Members==0 or leader and #party.Members<D.PartySize then
		local seen={}
		for _,m in ipairs(party.Members) do seen[m.User]=true end
		for _,m in ipairs(state.Players) do if m.User~=p.UserId and not seen[m.User] then
			row(m.Name,m.Island,{button("Invite","PartyInvite",m.User),{"Profile",function() page="Profiles" run("Inspect",m.User) end}})
		end end
	end
end
local function guildSummary(g,editable)
	row(g.Name.." · Level "..g.Level,g.Description..(g.Description~="" and "\n" or "").."XP "..g.XP.." · Guild code "..g.Id)
	for _,v in ipairs(g.Contracts) do row(v.Name,(v.Done and "Complete · " or "")..v.Count.." / "..v.Target.." · "..v.XP.." Guild XP") end
	for _,m in ipairs(g.Members) do
		local here=Players:GetPlayerByUserId(m.User)
		local totals=m.Contribution
		local controls={{"Profile",function() page="Profiles" run("Inspect",m.User) end}}
		if editable and m.User~=p.UserId then
			if g.Role=="Owner" then
				table.insert(controls,button(m.Role=="Officer" and "Demote" or "Promote","GuildRole",m.User,m.Role=="Officer" and "Member" or "Officer"))
				table.insert(controls,{"Transfer",function()
					local confirm=row("Transfer ownership?","The selected member becomes owner. You stay in the guild.",
						{button("Confirm","GuildTransfer",m.User),{"Cancel",render}})
					scroll.CanvasPosition=Vector2.new(0,math.max(0,confirm.AbsolutePosition.Y-scroll.AbsolutePosition.Y))
				end})
			end
			if g.Role=="Owner" or g.Role=="Officer" and m.Role=="Member" then table.insert(controls,button("Kick","GuildKick",m.User)) end
		end
		row((here and here.DisplayName or "Player "..m.User).." · "..m.Role,
			(totals.Trees or 0).." chops · "..(totals.Boss or 0).." boss credits · "..(totals.Depth or 0).." depths",controls)
	end
end
local function builderGuild()
	local g=state.Guild
	if remoteGuild then
		row("Guild preview","",{ {"Back",function() remoteGuild=nil render() end} })
		guildSummary(remoteGuild,false) return
	end
	if state.GuildIssue then row("Guild status",state.GuildIssue) end
	if not g then
		local create=row("Create a guild","Up to 30 members",nil,160)
		local title=input(create,"Guild name",51,32)
		local desc=input(create,"Description",87,140)
		action(create,"Create",0,1,124,function() run("GuildCreate",title.Text,desc.Text) end)
		local join=row("Find a guild","Enter the code from a guild or a leaderboard entry.",nil,130)
		local id=input(join,"Guild code",55,32)
		action(join,"Apply",0,1/3,94,function() run("GuildApply",id.Text) end)
		action(join,"Accept invite",1/3,1/3,94,function() run("GuildJoin",id.Text) end)
		action(join,"Preview",2/3,1/3,94,function() run("GuildInspect",id.Text) end)
		for _,invite in ipairs(state.Inbox) do row(invite.Name,"Guild invitation",{button("Accept","GuildJoin",invite.Id)}) end
	else
		row("Guild membership · "..g.Role,"Weekly contracts reset on Monday UTC. Guild levels unlock cosmetics.",
			{{"Leave guild",function()
				row("Leave this guild?","Your earned cosmetics stay in your collection.",
					{button("Confirm","GuildLeave"),{"Cancel",render}})
			end}})
		guildSummary(g,true)
		if g.Role=="Owner" then
			local edit=row("Edit guild profile","Public text is filtered by Roblox.",nil,160)
			local title=input(edit,"Guild name",51,32,g.Name)
			local desc=input(edit,"Description",87,140,g.Description)
			action(edit,"Save profile",0,1,124,function() run("GuildEdit",title.Text,desc.Text) end)
		end
		if g.Requests then
			local invite=row("Invite a player","Enter a Roblox user ID.",nil,131)
			local target=input(invite,"Roblox user ID",54,16)
			action(invite,"Invite",0,1,93,function() run("GuildInvite",tonumber(target.Text)) end)
			for key,expires in pairs(g.Requests) do if expires>os.time() then
				local uid=tonumber(key)
				row("Applicant "..uid,"Approve to send a membership invitation.",
					{button("Approve","GuildApprove",uid),button("Reject","GuildReject",uid)})
			end end
			for _,log in ipairs(g.Audit or {}) do
				row(log.Action,string.format("%s UTC · User %d%s",os.date("!%b %d %H:%M",log.At),log.Actor,log.Target and " · "..tostring(log.Target) or ""))
			end
		end
	end
	row("Guild leaderboard","Top guilds by earned XP.",{button("Load ranking","GuildBoard")})
	for i,r in ipairs(leaderboard or {}) do row(i..". "..r.Name,r.XP.." XP · Level "..r.Level,{button("Preview","GuildInspect",r.Id)}) end
end
local function builderProfiles()
	local card=remoteCard or state.Card
	local top=row(card.Name, "Mastery "..card.Mastery.." · "..C.FormatNumber(card.Trees).." trees\n"..card.Island.." · "..(card.Guild or "Unaffiliated"),nil,92)
	for _,child in ipairs(top:GetChildren()) do if child:IsA("TextLabel") then child.Position+=UDim2.fromOffset(84,0) child.Size-=UDim2.fromOffset(84,0) end end
	new("ImageLabel",top,{BackgroundColor3=ink,Size=UDim2.fromOffset(72,72),Position=UDim2.fromOffset(9,9),
		Image="rbxthumb://type=AvatarHeadShot&id="..card.User.."&w=150&h=150"})
	row("Showcase","Favorite weapon · "..name(card.Favorites).."\nPet · "..name(card.Pet))
	local title=D.CosmeticById[card.Title]
	local aura=D.CosmeticById[card.Aura]
	row("Title and aura",(title and title.Title or "No title equipped").." · "..(aura and aura.Aura or "No aura equipped"))
	row("Accomplishments",card.Bosses.." progression bosses · "..card.Raids.." raid clears · "..card.Heart.." Heart victories\nTrial best "..card.Trial.." · Expedition depth "..card.Depth)
	for _,entry in ipairs(card.Vault or {}) do row(name(entry.Id),"Vault showcase · Slot "..entry.Slot) end
	for _,v in ipairs(card.Rare) do row(name(v.Id),"Rare collection · ★"..v.Star..(v.Shiny and " · Shiny" or "")) end
	if remoteCard then row("Your profile","",{ {"Back to my profile",function() remoteCard=nil render() end} })
	else
		local find=row("Inspect another player","Online or previously cached public profile.",nil,130)
		local box=input(find,"Roblox user ID",54,16)
		action(find,"Inspect",0,1,94,function() run("Inspect",tonumber(box.Text)) end)
		for _,person in ipairs(state.Players) do if person.User~=p.UserId then row(person.Name,person.Island,{button("Inspect","Inspect",person.User)}) end end
		for _,item in ipairs(state.Items) do
			row(item.Name,itemLine(item),{button(item.Showcase and "Clear showcase" or "Showcase","Showcase",item.Kind,item.Showcase and "" or item.Id)})
		end
	end
end
local function builderVault()
	for i=1,D.VaultSize do
		local item=state.Vault[tostring(i)]
		if item then
			local preview="Protected "..item.Kind:lower().." · "..name(item.Id)
			for _,owned in ipairs(state.Items) do if owned.Id==item.Id and owned.Kind==item.Kind then preview..="\n"..itemLine(owned) break end end
			row("Slot "..i,preview,{button("Retrieve","VaultMove",i),button(item.Public and "Make private" or "Show publicly","VaultPublic",i,not item.Public)})
		else
			row("Slot "..i,slot==i and "Selected" or "Empty",{{"Select",function() slot=i render() end}})
		end
	end
	row("Choose an item for slot "..slot,"Vaulted items can stay equipped and favorited.",
		{{"Weapons",function() mode="Weapon" render() end},{"Pets",function() mode="Pet" render() end}})
	for _,item in ipairs(state.Items) do if item.Kind==mode and not item.Vault then
		row(item.Name,itemLine(item),{button("Store","VaultMove",slot,item.Kind,item.Id)})
	end end
end
local function builderCosmetics()
	row("Equipped cosmetics","Titles and auras are visual rewards.",{button("Clear title","Cosmetic","Title",""),button("Clear aura","Cosmetic","Aura","")})
	for _,v in ipairs(D.Cosmetics) do
		local choices={}
		if state.Titles[v.Id] then table.insert(choices,button(state.Title==v.Id and "Unequip title" or "Equip title","Cosmetic","Title",state.Title==v.Id and "" or v.Id)) end
		if state.Auras[v.Id] then table.insert(choices,button(state.Aura==v.Id and "Unequip aura" or "Equip aura","Cosmetic","Aura",state.Aura==v.Id and "" or v.Id)) end
		row(v.Title.." · "..v.Aura,"Unlock at "..v.Count.." "..v.Kind:lower(),#choices>0 and choices or nil)
	end
end
local function builderTrade()
	local trade=state.Trade
	row("Trade requests",trade.Execution and "Trade eligible weapons and pets with another player." or "Trading is disabled pending cross-server recovery testing.",
		{button(trade.Enabled and "Block requests" or "Allow requests","TradeSetting",not trade.Enabled)})
	if trade.Request then row("Trade request from "..trade.Request,"",{button("Accept","TradeAccept",trade.Request),button("Decline","TradeDecline",trade.Request)}) end
	if trade.Peer then
		row("Trade with "..trade.Peer,trade.Settling and "Settling inventory" or trade.End and "Final countdown" or "Review both items before confirming.",
			{button("Confirm","TradeConfirm"),button("Cancel","TradeCancel")})
		if trade.End then
			local _,detail=row("Completing trade","")
			countdown=detail
		end
		for _,key in ipairs({"Ours","Theirs"}) do
			local item=trade[key]
			row(key,item and name(item.Id).." · "..(item.Rarity or "").." · "..(item.Power and "Base Power "..C.FormatNumber(item.Power) or item.Kind) or "No item selected")
		end
		for _,item in ipairs(state.Items) do if item.Trade then row(item.Name,itemLine(item),{button("Offer","TradeOffer",item.Kind,item.Id)}) end end
	elseif trade.Execution then
		for _,m in ipairs(state.Players) do if m.User~=p.UserId then row(m.Name,m.Island,{button("Request trade","TradeAsk",m.User)}) end end
	end
	for _,entry in ipairs(trade.History) do row(entry.State,name(entry.Sent)..(entry.Received and " → "..name(entry.Received) or "")) end
	row("Purchase gifting","Real-money gifting is inactive.")
end
local pages={Party=builderParty,Guilds=builderGuild,Profiles=builderProfiles,Vault=builderVault,Cosmetics=builderCosmetics,Trade=builderTrade}
render=function()
	if not panel.Visible then return end
	order=0 countdown=nil
	for _,child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	if state then pages[page]() else row("Loading social hall","") end
end
local function open(tab)
	page=tab or page remoteCard=nil remoteGuild=nil
	panel.Visible=true
	T.Pop(panel)
	render()
	if not pending then pending=true refresh() pending=false render() end
end
for i,tab in ipairs({"Party","Guilds","Profiles","Vault","Cosmetics","Trade"}) do
	action(nav,tab,(i-1)/6,1/6,0,function()
		page=tab remoteCard=nil remoteGuild=nil scroll.CanvasPosition=Vector2.zero footer.Text="" render()
	end)
end
tile.Activated:Connect(function() if panel.Visible then panel.Visible=false else open() end end)
close.Activated:Connect(function() panel.Visible=false end)
Prompt.PromptTriggered:Connect(function(pr,who)
	local tab=pr.Name=="M7SocialPrompt" and pr:GetAttribute("M7Tab")
	if (not who or who==p) and tab and pages[tab] then open(tab) end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(.5)
		if countdown and state and state.Trade.End then
			countdown.Text=tostring(math.max(0,math.ceil(state.Trade.End-workspace:GetServerTimeNow()))).." seconds"
		end
	end
end)
task.spawn(function()
	local previous
	while gui.Parent do
		task.wait(2)
		if panel.Visible and state and not pending and (page=="Party" or page=="Trade") then
			local ok,data=call("Status")
			if ok and panel.Visible then
				state.Party=data.Party state.Trade=data.Trade state.Players=data.Players
				local copy=H:JSONEncode(data)
				if previous~=copy then previous=copy render() end
			end
		end
	end
end)

-- Each visible avatar gets at most one bounded aura and one title. Effects are local.
local visuals={}
local function draw(peer)
	local previous=visuals[peer]
	if previous then previous:Destroy() visuals[peer]=nil end
	local char=peer.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local title=D.CosmeticById[peer:GetAttribute("M7Title") or ""]
	local aura=D.CosmeticById[peer:GetAttribute("M7Aura") or ""]
	if not title and not aura then return end
	local folder=new("Folder",char,{Name="M7Cosmetics"})
	visuals[peer]=folder
	if title then
		local badge=new("BillboardGui",folder,{Adornee=root,Size=UDim2.fromOffset(190,25),StudsOffset=Vector3.new(0,3.9,0),MaxDistance=55})
		new("TextLabel",badge,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.GothamBold,TextScaled=true,
			Text=title.Title,TextColor3=title.Color,TextStrokeTransparency=.36})
	end
	if aura then
		local low=p:GetAttribute("Pref_Graphics")=="Low"
		local static=low or p:GetAttribute("Pref_ReducedMotion")==true
		new("Highlight",folder,{Adornee=char,DepthMode=Enum.HighlightDepthMode.Occluded,OutlineColor=aura.Color,
			OutlineTransparency=.65,FillColor=aura.Color,FillTransparency=.94})
		if not static then
			local light=new("PointLight",folder,{Color=aura.Color,Brightness=aura.Count>=30 and .72 or .52,Range=8})
			-- Highlight carries the aura on clients where the character's root is streamed out.
			light.Parent=root
			folder.Destroying:Connect(function() light:Destroy() end)
		end
	end
end
local function bind(peer)
	peer.CharacterAdded:Connect(function(char)
		task.spawn(function() if char:WaitForChild("HumanoidRootPart",7) and peer.Character==char then draw(peer) end end)
	end)
	peer:GetAttributeChangedSignal("M7Title"):Connect(function() draw(peer) end)
	peer:GetAttributeChangedSignal("M7Aura"):Connect(function() draw(peer) end)
	draw(peer)
end
for _,peer in ipairs(Players:GetPlayers()) do bind(peer) end
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(peer) if visuals[peer] then visuals[peer]:Destroy() visuals[peer]=nil end end)
for _,setting in ipairs({"Pref_Graphics","Pref_ReducedMotion"}) do
	p:GetAttributeChangedSignal(setting):Connect(function() for _,peer in ipairs(Players:GetPlayers()) do draw(peer) end end)
end
