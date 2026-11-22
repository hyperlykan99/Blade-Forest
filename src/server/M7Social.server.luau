local QA=require(script.Parent:WaitForChild("QAIsolation"))
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local DSS=game:GetService("DataStoreService")
local C=require(RS:WaitForChild("BladeConfig"))
local D=require(RS:WaitForChild("M7Design"))
local L=require(RS:WaitForChild("M4Layout"))
local Data=require(script.Parent:WaitForChild("DataService"))
local Guilds=require(script.Parent:WaitForChild("M7Guilds"))
local Parties=require(script.Parent:WaitForChild("M7Parties"))
local Items=require(script.Parent:WaitForChild("M7Items"))
local Trade=require(script.Parent:WaitForChild("M7Trade"))
local Gifts=require(script.Parent:WaitForChild("M7Gifting"))
local Runs=require(script.Parent:WaitForChild("M5Runs"))
local Layout=require(script.Parent:WaitForChild("M4WorldRuntime"))
local profiles=DSS:GetDataStore(QA.StoreName("BladeForest_M7_PublicCards_v1"))
local remotes=RS:WaitForChild("Remotes")
local rf=Instance.new("RemoteFunction")
rf.Name="M7Social"
local notice=remotes:WaitForChild("Notify")
local cache,restricted,profileCache,throttle,busy={},{},{},{},{}
local function numbers(d)
	local n={Mastery=d.Mastery.Level,Trees=d.Stats.TreesChopped or 0,Weapons=0,Bosses=0,Raids=0,Heart=0,Guild=0}
	for _ in pairs(d.Weapons) do n.Weapons+=1 end
	for _,wins in pairs(d.BossKills) do if wins>0 then n.Bosses+=1 end end
	for id,wins in pairs(d.M6.BossClears) do
		if id=="HeartOfWinter" then n.Heart=wins else n.Raids+=wins end
	end
	return n
end
local function cosmetics(p,d,counts)
	local guild=cache[p]
	counts=counts or numbers(d)
	counts.Guild=guild and D.GuildLevel(guild.XP) or 0
	for _,c in ipairs(D.Cosmetics) do
		if counts[c.Kind] and counts[c.Kind]>=c.Count then d.M7.Titles[c.Id]=true d.M7.Auras[c.Id]=true end
	end
	local aura=d.M7.Auras[d.M7.Aura] and d.M7.Aura or ""
	local title=d.M7.Titles[d.M7.Title] and d.M7.Title or ""
	p:SetAttribute("M7Aura",aura)
	p:SetAttribute("M7Title",title)
end
local function updateGuild(p,d,write)
	local g,issue=Guilds.Membership(p.UserId)
	if not p.Parent or Data.Get(p)~=d then return end
	if g and write then g=Guilds.Contribute(g,p.UserId,d.M7.GuildWeek) end
	cache[p]=g restricted[p]=issue
	local id=g and g.Id or nil
	d.M7.ActiveGuild=id
	if id then d.M8.Counts.Guild=1 end
	p:SetAttribute("M7GuildId",id)
	p:SetAttribute("M7GuildName",g and g.Name or nil)
	cosmetics(p,d)
end
local function card(p,d)
	local counts=numbers(d)
	local rare={}
	for id,entry in pairs(d.Weapons) do
		local w=C.WeaponById[id]
		if w then table.insert(rare,{Id=id,Star=entry.Star or 0,Shiny=entry.Shiny==true,Odds=w.OneIn or 0,
			Rank=C.RarityById[w.Rarity].Order}) end
	end
	table.sort(rare,function(a,b) return a.Rank>b.Rank or a.Rank==b.Rank and
		(a.Odds>b.Odds or a.Odds==b.Odds and a.Id<b.Id) end)
	for i=#rare,4,-1 do table.remove(rare,i) end
	local favorite=d.M7.FavoriteWeapon
	if not d.Weapons[favorite] then
		favorite=""
		for id in pairs(d.Favorites) do if d.Weapons[id] then favorite=id break end end
	end
	local pet=Items.Owns(d,"Pet",d.M7.PetShowcase) and d.M7.PetShowcase or d.EquippedPets[1] or ""
	local showcase={}
	for i=1,D.VaultSize do
		local item=d.M7.Vault[tostring(i)]
		if item and item.Public then table.insert(showcase,{Slot=i,Kind=item.Kind,Id=item.Id}) end
	end
	local island="TimberHaven"
	for _,key in ipairs(C.Economy.IslandOrder) do if d.UnlockedIslands[key] then island=key end end
	return {User=p.UserId,Name=p.DisplayName,Mastery=counts.Mastery,Trees=counts.Trees,Island=island,Favorites=favorite,
		Pet=pet,Rare=rare,Vault=showcase,Title=p:GetAttribute("M7Title") or "",Aura=p:GetAttribute("M7Aura") or "",
		Guild=p:GetAttribute("M7GuildName"),Bosses=counts.Bosses,Raids=counts.Raids,Heart=counts.Heart,
		Trial=d.M6.TrialBest,Depth=d.M5.DepthEver or 0}
end
local function publish(p,d)
	if not Data.CanPersist(p) then return end
	local snapshot=card(p,d)
	pcall(profiles.SetAsync,profiles,"U:"..p.UserId,snapshot)
end
local profileOrder={}
local function inspect(uid)
	if type(uid)~="number" or uid%1~=0 or uid<=0 or uid>1e15 then return nil end
	local p=Players:GetPlayerByUserId(uid)
	local d=p and Data.Get(p)
	if d then return card(p,d) end
	local seen=profileCache[uid]
	if seen and seen.Expires>os.clock() then return seen.Card end
	local ok,result=pcall(profiles.GetAsync,profiles,"U:"..uid)
	if ok then
		if not profileCache[uid] then table.insert(profileOrder,uid) end
		profileCache[uid]={Card=result,Expires=os.clock()+60}
		if #profileOrder>128 then profileCache[table.remove(profileOrder,1)]=nil end
		return result
	end
end
local function roster()
	local list={}
	for _,p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Loaded") then
			table.insert(list,{User=p.UserId,Name=p.DisplayName,Island=p:GetAttribute("CurrentIsland")})
		end
	end
	return list
end
local function inventory(d)
	local list={}
	for id,w in pairs(C.WeaponById) do
		local r=d.Weapons[id]
		if r then table.insert(list,{Kind="Weapon",Id=id,Name=w.Name,Rarity=w.Rarity,Star=r.Star or 0,
			Shiny=r.Shiny==true,Showcase=d.M7.FavoriteWeapon==id,Vault=Items.Vaulted(d,"Weapon",id),
			Trade=Items.Select(d,"Weapon",id)~=nil}) end
	end
	for id,p in pairs(C.PetById) do
		if Items.Owns(d,"Pet",id) then
			table.insert(list,{Kind="Pet",Id=id,Name=p.Name,Rarity=p.Rarity,Stage=p.Stage,
				Showcase=d.M7.PetShowcase==id,Vault=Items.Vaulted(d,"Pet",id),Trade=Items.Select(d,"Pet",id)~=nil})
		end
	end
	table.sort(list,function(a,b) return a.Kind==b.Kind and a.Name<b.Name or a.Kind>b.Kind end)
	return list
end
local function action(p,op,a,b,c)
	local d=Data.Get(p)
	if not d or not p:GetAttribute("Loaded") or p:GetAttribute("Handoff") then return false,"Profile unavailable" end
	if op=="Status" then return true,{Party=Parties.View(p),Trade=Trade.View(p,d),Players=roster()} end
	if op=="Read" then
		cosmetics(p,d)
		local guild=cache[p]
		return true,{Party=Parties.View(p),Trade=Trade.View(p,d),Players=roster(),Guild=Guilds.Snapshot(guild,p.UserId),GuildIssue=restricted[p],
			Card=card(p,d),Titles=d.M7.Titles,Auras=d.M7.Auras,Title=d.M7.Title,Aura=d.M7.Aura,Vault=d.M7.Vault,Items=inventory(d),
			Inbox=Guilds.Inbox(p.UserId),PaidGifting=Gifts.CanOffer(0)}
	end
	if op=="Inspect" then
		local result=inspect(a)
		return result~=nil,result or "Public profile unavailable"
	elseif op=="GuildInspect" then
		local result=Guilds.Inspect(a,p.UserId)
		return result~=nil,result or "Guild unavailable"
	elseif op=="GuildBoard" then return true,Guilds.Board()
	elseif op=="PartyRun" then
		if a=="Expedition" then
			local members,why=Parties.Ready(p)
			if members then return Runs.EnterParty(members) end
			return false,why
		end
		local entry=Storage:FindFirstChild("M7EncounterEntry")
		if entry and (a=="Raid" or a=="Heart") then return entry:Invoke(p,a) end
		return false,"Party encounter unavailable"
	elseif op:sub(1,5)=="Party" then
		local okay,msg=Parties.Action(p,op,a)
		if okay and op=="PartyAccept" then d.M8.Counts.Party=1 Data.Sync(p) end
		if okay and op=="PartyInvite" then
			local other=Players:GetPlayerByUserId(a)
			if other then notice:FireClient(other,p.DisplayName.." invited you to a party. Open Social to respond.","info") end
		end
		return okay,msg
	elseif op:sub(1,5)=="Guild" then
		local okay,msg=Guilds.Action(p,op,a,b)
		if okay then
			updateGuild(p,d,true)
			if op=="GuildInvite" or op=="GuildApprove" then
				local other=Players:GetPlayerByUserId(a)
				if other then notice:FireClient(other,"A guild invitation is available in Social.","info") end
			end
			return true
		end
		return false,msg
	elseif op:sub(1,5)=="Trade" then
		local ok,msg=Trade.Action(p,op,a,b)
		if ok and op=="TradeAsk" then
			local other=Players:GetPlayerByUserId(a)
			if other then notice:FireClient(other,"A trade request is available in Social.","info") end
		end
		return ok,msg
	elseif op=="VaultMove" then
		if b~=nil and (b~="Weapon" and b~="Pet" or type(c)~="string" or #c>64) then return false,"Select an owned item" end
		local ok,why=Items.Move(d,a,b,c)
		if not ok then return false,why end
		if b then d.M8.Counts.Showcase=1 end
	elseif op=="VaultPublic" then
		if type(a)~="number" or a%1~=0 or a<1 or a>D.VaultSize or type(b)~="boolean" then return false,"Select a showcase slot" end
		local item=d.M7.Vault[tostring(a)]
		if not item then return false,"Slot is empty" end
		item.Public=b
	elseif op=="Showcase" then
		if (a~="Weapon" and a~="Pet") or type(b)~="string" or #b>64 or b~="" and not Items.Owns(d,a,b) then return false,"Select an owned item" end
		d.M7[a=="Weapon" and "FavoriteWeapon" or "PetShowcase"]=b
		if b~="" then d.M8.Counts.Showcase=1 end
	elseif op=="Cosmetic" then
		if type(b)~="string" or #b>32 or a~="Title" and a~="Aura" then return false,"Select an earned cosmetic" end
		cosmetics(p,d)
		if b~="" and not d.M7[a=="Title" and "Titles" or "Auras"][b] then return false,"Cosmetic not earned" end
		d.M7[a]=b
		cosmetics(p,d)
	else
		return false,"Unknown social action"
	end
	Data.Sync(p)
	return true
end
rf.OnServerInvoke=function(p,op,a,b,c)
	if type(op)~="string" or #op>20 then return false,"Invalid social action" end
	if busy[p] or (throttle[p] or 0)>os.clock() then return false,"Social is busy" end
	busy[p]=true
	throttle[p]=os.clock()+.22
	local clean,ok,out=pcall(action,p,op,a,b,c)
	busy[p]=nil
	if not clean then warn("[M7 Social] "..tostring(ok)) return false,"Social request unavailable" end
	return ok,out
end
rf.Parent=remotes

local function online(p)
	task.spawn(function()
		while p.Parent and not p:GetAttribute("Loaded") do task.wait(.4) end
		if not p.Parent then return end
		local tick=0
		while p.Parent do
			local d=Data.Get(p)
			if d and not p:GetAttribute("Handoff") then
				if tick%6==0 then updateGuild(p,d,true) end
				cosmetics(p,d)
				if tick%18==0 then publish(p,d) end
			end
			tick+=1
			task.wait(10)
		end
	end)
end
Players.PlayerAdded:Connect(online)
for _,p in ipairs(Players:GetPlayers()) do online(p) end
Players.PlayerRemoving:Connect(function(p)
	cache[p]=nil restricted[p]=nil throttle[p]=nil busy[p]=nil
end)

if Layout.Active and L.Enabled() then
	local Art=require(Storage:WaitForChild("M4Architecture"))
	local sites={TimberHaven={Vector3.new(-76,0,-2976),Vector3.new(-92,0,-2976),Vector3.new(-108,0,-2976),Vector3.new(-124,0,-2976)},
		FrostboundReach={Vector3.new(5777,0,-32),Vector3.new(5793,0,-32),Vector3.new(5809,0,-32),Vector3.new(5825,0,-32)}}
	local stations={{"Guild Hall","Guilds"},{"Collection Vault","Vault"},{"Player Showcase","Profiles"},{"Party Rally","Party"}}
	local kinds={Color3.fromRGB(168,98,57),Color3.fromRGB(68,110,124)}
	for island,points in pairs(sites) do
		local pkg=workspace.M4ActiveWorld:FindFirstChild(island)
		if not pkg then continue end
		local clr=kinds[island=="TimberHaven" and 1 or 2]
		local hub=Instance.new("Model") hub.Name="M7 Social Stations" hub.Parent=pkg
		for i,point in ipairs(points) do
			local spec=stations[i]
			local stand=Art.Part(hub,spec[1],Vector3.new(7,3.2,3),CFrame.new(point+Vector3.new(0,1.6,0)),clr,Enum.Material.WoodPlanks)
			Art.Part(hub,"Roof",Vector3.new(8,1,4),CFrame.new(point+Vector3.new(0,4.7,0)),clr,Enum.Material.Slate)
			local sign=Instance.new("BillboardGui") sign.Name="M7Sign" sign.MaxDistance=65
			sign.Size=UDim2.fromOffset(175,33) sign.StudsOffset=Vector3.new(0,4.4,0) sign.Parent=stand
			local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=.22
			label.BackgroundColor3=Color3.fromRGB(32,30,35) label.TextColor3=Color3.fromRGB(249,224,179)
			label.TextScaled=true label.Font=Enum.Font.GothamBold label.Text=spec[1] label.Parent=sign
			local pr=Instance.new("ProximityPrompt") pr.Name="M7SocialPrompt" pr.ActionText="Open"
			pr.ObjectText=spec[1] pr.MaxActivationDistance=12 pr.RequiresLineOfSight=false pr:SetAttribute("M7Tab",spec[2])
			pr.Parent=stand
		end
	end
end
