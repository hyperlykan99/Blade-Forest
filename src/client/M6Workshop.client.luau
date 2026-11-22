local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Proximity=game:GetService("ProximityPromptService")
local Tween=game:GetService("TweenService")
local D=require(RS:WaitForChild("M6Design"))
local C=require(RS:WaitForChild("BladeConfig"))
local T=require(RS:WaitForChild("UITheme"))
local remotes=RS:WaitForChild("Remotes")
local remote=remotes:WaitForChild("ForgeWorkshop",35)
if not remote then return end
local p=Players.LocalPlayer
local gold,ice,ink,stone=Color3.fromRGB(244,188,109),Color3.fromRGB(122,218,236),Color3.fromRGB(31,28,38),Color3.fromRGB(58,48,51)
local gui=Instance.new("ScreenGui") gui.Name="M6WorkshopUI" gui.ResetOnSpawn=false gui.DisplayOrder=17 gui.Parent=p:WaitForChild("PlayerGui")
local tile=Instance.new("TextButton") tile.Name="M6ForgeButton" tile.Text="FORGE" tile.Size=UDim2.fromOffset(76,76) tile.Parent=gui
local panel,body,close=T.Panel(gui,"Workshop","FORGE & ENDGAME",gold,780,.86)
panel.Size=UDim2.fromScale(.93,.86) body.BackgroundColor3=ink body.BackgroundTransparency=0
local tabs=Instance.new("Frame") tabs.Name="Tabs" tabs.BackgroundTransparency=1
tabs.Size=UDim2.new(1,-10,0,39) tabs.Position=UDim2.fromOffset(5,4) tabs.Parent=body
local scroll=Instance.new("ScrollingFrame")
scroll.Name="Rows" scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=5
scroll.Size=UDim2.new(1,-12,1,-79) scroll.Position=UDim2.fromOffset(6,48)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new() scroll.Parent=body
local list=Instance.new("UIListLayout") list.Padding=UDim.new(0,6) list.SortOrder=Enum.SortOrder.LayoutOrder list.Parent=scroll
local status=T.Label(body,{Name="Status",Position=UDim2.new(0,8,1,-25),Size=UDim2.new(1,-16,0,22),
	Text="",TextColor3=gold,TextScaled=false,TextSize=13,TextWrapped=true})
local tabsByName,seq={},0
local state,busy,note,confirm
local page="Forge"
local weapon,selectedRune,socket="","Harvest1",1
local render
local function request(op,id,arg)
	if busy then return end
	busy=true
	local called,ok,out=pcall(remote.InvokeServer,remote,op,id,arg,state and state.Revision)
	busy=false
	if called and ok then
		if type(out)=="table" then state=out end
		note=nil
	else
		note=called and tostring(out) or "Workshop unavailable"
	end
	if render then render() end
end
local function label(parent,text,pos,size,color,point)
	return T.Label(parent,{Text=text,Position=pos,Size=size,TextColor3=color,TextWrapped=true,TextScaled=false,
		TextSize=point,TextXAlignment=Enum.TextXAlignment.Left})
end
local function row(title,line,button,callback,accent)
	seq+=1
	local r=Instance.new("Frame") r.Name="WorkshopRow" r.LayoutOrder=seq r.BackgroundColor3=stone
	r.Size=UDim2.new(1,-5,0,75) r.Parent=scroll T.Corner(r,8) T.Stroke(r,accent or ink,1)
	local scale=button and .71 or 1
	label(r,title,UDim2.fromOffset(8,4),UDim2.new(scale,-15,0,22),accent or gold,15)
	label(r,line,UDim2.fromOffset(8,28),UDim2.new(scale,-16,0,42),T.Color.Cream,12)
	if button then
		local b=T.Button(r,{Name=button,Text=button,Position=UDim2.new(.71,1,.5,-18),Size=UDim2.new(.29,-7,0,36)},accent or ice)
		b.Activated:Connect(callback)
	end
end
local function cost(costs)
	local rows={}
	for name,n in pairs(costs) do
		table.insert(rows,C.FormatNumber(n).." "..(D.MaterialNames[name] or name))
	end
	table.sort(rows)
	return table.concat(rows," · ")
end
local Clock=require(game.ReplicatedStorage:WaitForChild("CalendarClock"))
local function clock(untilAt,utc)
	local n=math.max(0,math.floor((untilAt or 0)-(utc and Clock.UTC() or workspace:GetServerTimeNow())))
	return string.format("%d:%02d",math.floor(n/60),n%60)
end
local function actionLabel(op,id,arg,title)
	return title,function()
		local marker=op..":"..id..":"..tostring(arg or "")
		if op=="Salvage" or op=="Awaken" or op=="Recipe" or op=="Reroll" then
			if confirm~=marker then confirm=marker note="Press again to confirm "..title render() return end
		end
		confirm=nil
		request(op,id,arg)
	end
end
local function currentWeapon()
	if weapon=="" or not state.Items[weapon] then weapon=state.Equipped end
	return state.Items[weapon]
end
local function showWeapons(salvage)
	local ids={}
	for id,entry in pairs(state.Items) do
		if not salvage or entry.Copies>0 then table.insert(ids,id) end
	end
	table.sort(ids)
	for _,id in ipairs(ids) do
		local equipped=state.Items[id]
		local profile=C.WeaponById[id]
		local text=equipped.Star.."★ · "..equipped.Copies.." spare · "..(equipped.Favorite and "Favorite · " or "").."Awakening "..equipped.Stage
		row(profile and profile.Name or id,text,"Select",function() weapon=id socket=1 render() end,id==weapon and ice or nil)
	end
end
local function recipes(items)
	for _,q in ipairs(items) do
		local found=state.Islands[q.Island] and state.Mastery>=q.Mastery and (not q.TrialScore or state.TrialBest>=q.TrialScore)
		local heading=q.Name
		local description=cost(q.Costs)
		if q.Weapon then
			local def=C.WeaponById[q.Weapon]
			if def then heading=def.Name description=q.Name.." · "..C.FormatNumber(def.Power).." Power\n"..description end
		end
		if not found then description="Requires "..q.Island.." · Mastery "..q.Mastery..(q.TrialScore and " · Trial score "..q.TrialScore or "") end
		if state.Items[q.Weapon] then description="Already in your collection" end
		local b,cb
		if found and not state.Items[q.Weapon] and state.AtForge then b,cb=actionLabel("Recipe",q.Id,nil,confirm=="Recipe:"..q.Id..":" and "Confirm" or "Craft") end
		row(heading,description,b,cb)
	end
end
local function inventory()
	local display={}
	for _,name in ipairs({"Bark","Crystal","Frost","ExpeditionFrostCore","Essence","Souls","TrialToken","TrialSeal","SigilBark","SigilCrystal","SigilFrost"}) do
		table.insert(display,C.FormatNumber(state.Balance[name]).." "..D.MaterialNames[name])
	end
	row(state.AtForge and "Workshop inventory" or "Workshop preview",table.concat(display," · "),nil,nil,ice)
end
local function runeScreen()
	local item=currentWeapon()
	if item then
		row(C.WeaponById[weapon].Name,"Awakening "..item.Stage.." unlocks "..item.Stage.." rune slots.",nil,nil,ice)
		for slotIndex=1,item.Stage do
			local r=D.RuneById[item.Sockets[tostring(slotIndex)] or ""]
			row("Socket "..slotIndex,r and (r.Name.." · +"..string.format("%g%%",r.Amount*100)) or "Empty",
				"Select",function() socket=slotIndex render() end,socket==slotIndex and ice or nil)
		end
		if item.Stage>0 and item.Sockets[tostring(socket)] and state.AtForge then
			row("Remove rune","Return the selected socket's rune to your inventory","Remove",function() request("Socket",weapon,{Slot=socket}) end)
		end
	end
	local picked=D.RuneById[selectedRune]
	local n=state.Runes[picked.Id] or 0
	if state.AtForge then
		local fee=table.clone(D.RuneCraft[picked.Rank]) fee.Souls=D.RunecraftSoul[picked.Rank]
		row("Craft "..picked.Name,cost(fee)..(picked.Rank>1 and " · 3 loose previous-rank runes" or ""),"Craft",function() request("CreateRune",picked.Id) end)
		if n>0 then
			local b,cb=actionLabel("Reroll",picked.Id,nil,confirm=="Reroll:"..picked.Id..":" and "Confirm" or "Reroll")
			row("Reroll "..picked.Name,"Same rarity, different category · "..D.RerollSoul[picked.Rank].." Souls plus materials",b,cb)
			if item and item.Stage>=socket then
				row("Socket "..picked.Name,"Selected weapon · socket "..socket,"Socket",function()
					request("Socket",weapon,{Slot=socket,Rune=picked.Id})
				end)
			end
		end
	end
	for _,r in ipairs(D.Runes) do
		row(r.Name,"+"..string.format("%g%%",r.Amount*100).." "..r.Channel.." pool · "..(state.Runes[r.Id] or 0).." loose","Select",
			function() selectedRune=r.Id render() end,r==picked and ice or nil)
	end
end
local function encounterScreen()
	local raid=workspace:GetAttribute("M6RaidName")
	if raid then
		local stop=workspace:GetAttribute("M6RaidEnd")
		local active=(stop or 0)>Clock.UTC()
		local point
		for _,r in ipairs(D.Raids) do if r.Name==raid then point=r.Position break end end
		row(raid,(workspace:GetAttribute("M6RaidIsland") or "")..
			(point and string.format(" · (%d, %d)",point.X,point.Z) or "")..
			" · "..(active and "window "..clock(stop,true) or "next rotation "..clock(workspace:GetAttribute("M6RaidNext"),true)),nil,nil,ice)
	end
	if p:GetAttribute("M5Run")=="Heart" then
		row("Heart of Winter · "..(p:GetAttribute("M6HeartPhase") or "Gathering"),
			(p:GetAttribute("M6HeartWarning") or ("HP "..C.FormatNumber(p:GetAttribute("M6HeartHP") or 0).." · seals "..(p:GetAttribute("M6HeartWards") or 0))),
			"Retreat",function() request("Retreat") end,ice)
	else
		row("Heart of Winter","1–4 players · Frostbound Sanctum · 2,000 Power. A Key is spent on an eligible victory.",nil,nil,ice)
		if state then
			local q=D.ByRecipe.WinterKey
			local b,cb
			if state.AtForge then b,cb=actionLabel("Recipe","WinterKey",nil,confirm=="Recipe:WinterKey:" and "Confirm" or "Craft") end
			row("Winter Keys · "..state.Keys,cost(q.Costs),b,cb)
		end
	end
end
render=function(reset)
	if not panel.Visible then return end
	local position=reset and Vector2.zero or scroll.CanvasPosition
	for _,r in ipairs(scroll:GetChildren()) do if r:IsA("GuiObject") then r:Destroy() end end
	seq=0
	for tab,b in pairs(tabsByName) do b.BackgroundColor3=tab==page and gold or stone end
	status.Text=note or (state and not state.AtForge and page~="Raids" and "Visit Timber's Forge Workshop or Frostgate's Forge Annex to craft." or "")
	if page=="Raids" then encounterScreen()
	elseif not state then row("Loading workshop","Waiting for your profile")
	elseif page=="Forge" then inventory() recipes(D.Recipes)
	elseif page=="Trials" then row("Trial commissions","All rewards use existing weapon identities · personal best "..state.TrialBest,nil,nil,ice) recipes(D.Trials)
	elseif page=="Salvage" or page=="Awaken" then
		local item=currentWeapon()
		if item then
			local w=C.WeaponById[weapon]
			local title=w and w.Name or weapon
			if page=="Salvage" then
				local b,cb
				if state.AtForge and item.Copies>0 and not item.Favorite then
					b,cb=actionLabel("Salvage",weapon,math.min(item.Copies,5),confirm=="Salvage:"..weapon..":"..math.min(item.Copies,5) and "Confirm" or "Salvage")
				end
				row(title,"Salvage up to five spare copies per request. Stars, Shiny, ownership, and favorites are protected.",b,cb,ice)
			else
				local level=item.Stage+1
				local next=D.Awakening[level]
				local b,cb
				if next and state.AtForge and item.Star>=C.MaxStar then b,cb=actionLabel("Awaken",weapon,nil,confirm=="Awaken:"..weapon..":" and "Confirm" or "Awaken") end
				row(title,next and ("Stage "..level.." · ×"..D.AwakeningMultiplier[level].." Power · "..level.." slots\n"..cost(next.Costs)) or "Maximum Awakening",b,cb,ice)
			end
		end
		showWeapons(page=="Salvage")
	else runeScreen() showWeapons(false) end
	task.defer(function() scroll.CanvasPosition=position end)
end

for i,name in ipairs({"Forge","Salvage","Awaken","Runes","Raids","Trials"}) do
	local b=T.Button(tabs,{Name=name,Text=name,Position=UDim2.new((i-1)/6,1,0,0),Size=UDim2.new(1/6,-4,1,0)},stone)
	tabsByName[name]=b
	b.Activated:Connect(function() page=name confirm=nil note=nil render(true) end)
end
local function open(tab)
	page=tab or page panel.Visible=true confirm=nil T.Pop(panel) render(true)
	task.spawn(request,"Read")
end
tile.Activated:Connect(function() if panel.Visible then panel.Visible=false else open() end end)
close.Activated:Connect(function() panel.Visible=false end)
Proximity.PromptTriggered:Connect(function(prompt)
	if prompt.Name=="ForgeWorkshopPrompt" then open("Forge") end
end)
local hud=Instance.new("Frame") hud.Name="M6EncounterStatus" hud.Size=UDim2.new(1,0,0,33)
hud.BackgroundColor3=ink hud.LayoutOrder=9 hud.Visible=false T.Corner(hud,6) T.AttachToHud(hud,"StatusRail")
local hudText=T.Label(hud,{Name="Encounter",Text="",Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(4,0),TextColor3=ice})
local tap=Instance.new("TextButton") tap.Name="Open" tap.Text="" tap.BackgroundTransparency=1 tap.Size=UDim2.fromScale(1,1) tap.Parent=hud
tap.Activated:Connect(function() open("Raids") end)
task.spawn(function()
	while true do
		task.wait(.8)
		local op=p:GetAttribute("M5Run")
		local heart=op=="Heart"
		local raid=workspace:GetAttribute("M6RaidName")
		local same=p:GetAttribute("CurrentIsland")==workspace:GetAttribute("M6RaidIsland")
		hud.Visible=heart or not op and same and raid~=nil
		if heart then
			hudText.Text="Heart · "..(p:GetAttribute("M6HeartPhase") or "Gathering").." · "..
				(p:GetAttribute("M6HeartWarning") or ("HP "..C.FormatNumber(p:GetAttribute("M6HeartHP") or 0).." · "..clock(p:GetAttribute("M6HeartEnd"))))
		elseif raid then
			local endAt=workspace:GetAttribute("M6RaidEnd")
			local hp=workspace:GetAttribute("M6RaidHP")
			hudText.Text=raid.." · "..(hp and C.FormatNumber(hp).." HP · " or "")..
				((endAt or 0)>Clock.UTC() and clock(endAt,true) or "next "..clock(workspace:GetAttribute("M6RaidNext"),true))
		end
		if panel.Visible and page=="Raids" then render() end
	end
end)
local effects=remotes:WaitForChild("ForgeEffects",25)
if effects then effects.OnClientEvent:Connect(function(at,kind)
	if typeof(at)~="Vector3" then return end
	local light=Instance.new("Part") light.Name="Forge Sigil" light.Shape=Enum.PartType.Ball
	light.Size=Vector3.new(.7,.7,.7) light.Position=at+Vector3.new(0,2,0) light.Color=kind=="Awaken" and ice or gold
	light.Material=Enum.Material.Neon light.Transparency=.22 light.Anchored=true light.CanCollide=false light.CanQuery=false light.CanTouch=false
	light.Parent=workspace
	local reduced=p:GetAttribute("Pref_ReducedMotion") or p:GetAttribute("Pref_Graphics")=="Low"
	local target=reduced and {Transparency=1} or {Size=Vector3.new(6,6,6),Transparency=1,Position=light.Position+Vector3.new(0,2,0)}
	Tween:Create(light,TweenInfo.new(.46),target):Play()
	task.delay(.5,function() light:Destroy() end)
end) end
