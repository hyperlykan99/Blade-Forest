local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local D=require(RS:WaitForChild("M6Design"))
local I=require(RS:WaitForChild("M6Inventory"))
local C=require(RS:WaitForChild("BladeConfig"))
local Data=require(script.Parent:WaitForChild("DataService"))
local Rules=require(script.Parent:WaitForChild("M6ForgeRules"))
local Runtime=require(script.Parent:WaitForChild("M4WorldRuntime"))
local Policy=require(script.Parent:WaitForChild("PaidRandomPolicy"))
local Remotes=RS:WaitForChild("Remotes")
local Notify=Remotes:WaitForChild("Notify")
local action=Instance.new("RemoteFunction") action.Name="ForgeWorkshop"
local fx=Instance.new("RemoteEvent") fx.Name="ForgeEffects" fx.Parent=Remotes
local anchors={}
local locked,last={},{}

local function atForge(player)
	if player:GetAttribute("M5Run") or player:GetAttribute("IslandTravelling") then return false end
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	local anchor=anchors[player:GetAttribute("CurrentIsland")]
	return anchor and root and hum and hum.Health>0 and (root.Position-anchor.Position).Magnitude<=24
end
local function snapshot(p,d)
	local growth=d.M6
	local items={}
	for id,bag in pairs(d.Weapons) do
		local item=I.Item(d,id)
		items[id]={Copies=bag.Copies or 0,Star=bag.Star or 0,Shiny=bag.Shiny==true,Favorite=d.Favorites[id]==true,
			Stage=I.Stage(d,id),Sockets=item and table.clone(item.Sockets) or {}}
	end
	local balance={}
	for kind in pairs(D.MaterialNames) do balance[kind]=I.Remainder(d,kind) end
	return {Revision=growth.Revision,Items=items,Balance=balance,Runes=table.clone(growth.Runes),Keys=growth.Keys,
		Islands=table.clone(d.UnlockedIslands),Mastery=d.Mastery.Level,AtForge=atForge(p) and true or false,
		Equipped=d.Equipped,TrialBest=math.max(growth.TrialBest,d.M5.Weekly.Trial or 0),WinterWeek=growth.HeartWeek}
end
local function execute(p,op,id,arg,revision)
	local d=Data.Get(p)
	if not d or not p:GetAttribute("Loaded") or p:GetAttribute("Handoff") then return false,"Profile unavailable" end
	if op=="Read" then return true,snapshot(p,d) end
	if op=="Retreat" then
		local exit=Storage:FindFirstChild("M6HeartRetreat")
		if exit then return exit:Invoke(p) end
		return false,"No Heart of Winter run"
	end
	if not atForge(p) then return false,"Visit a Forge Workshop first" end
	if type(id)~="string" or #id>64 or revision~=d.M6.Revision then return false,"Refresh the Forge and try again" end
	if op=="Reroll" then
		local allowed,why=Policy.CheckCurrencySpend(p,"TraitCrate_Souls")
		if not allowed then return false,why end
		if d~=Data.Get(p) or p:GetAttribute("Handoff") or revision~=d.M6.Revision or not atForge(p) then
			return false,"Forge request expired"
		end
	end
	local ok,result
	local rng=Random.new()
	if op=="Recipe" then ok,result=Rules.Recipe(d,id,function(weapon,source) Data.M6Weapon(p,weapon,source) end)
	elseif op=="Salvage" then ok,result=Rules.Salvage(d,id,arg,os.time())
	elseif op=="Awaken" then ok,result=Rules.Awaken(d,id)
	elseif op=="Socket" and type(arg)=="table" then
		local rune=arg.Rune
		if rune~=nil and (type(rune)~="string" or #rune>64) then return false,"Unknown rune" end
		ok,result=Rules.Socket(d,id,arg.Slot,rune)
	elseif op=="CreateRune" then ok,result=Rules.CreateRune(d,id)
	elseif op=="Reroll" then ok,result=Rules.Reroll(d,id,rng)
	else return false,"Unknown Forge action" end
	if not ok then return false,result end
	if op=="Recipe" or op=="Awaken" or op=="CreateRune" then
		d.M8.Counts.Crafts=(d.M8.Counts.Crafts or 0)+1
	end
	d.M6.Revision+=1
	Data.RefreshM6(p)
	local anchor=anchors[p:GetAttribute("CurrentIsland")]
	if anchor then fx:FireClient(p,anchor.Position,op) end
	Notify:FireClient(p,result,"rare_Epic")
	return true,snapshot(p,d)
end

action.OnServerInvoke=function(player,op,id,arg,revision)
	if locked[player] or (last[player] and os.clock()-last[player]<.22) then return false,"Forge is busy" end
	last[player]=os.clock()
	locked[player]=true
	local called,ok,res=pcall(execute,player,op,id,arg,revision)
	locked[player]=nil
	if not called then warn("[M6 Forge] "..tostring(ok)) return false,"Forge request failed" end
	return ok,res
end
action.Parent=Remotes
Players.PlayerRemoving:Connect(function(p) locked[p]=nil last[p]=nil end)
if Runtime.Active then
	for island,name in pairs({TimberHaven="Forge Workshop",FrostboundReach="Forge Annex"}) do
		local pkg=workspace.M4ActiveWorld:FindFirstChild(island)
		local model=pkg and pkg:FindFirstChild(name,true)
		local anchor=model and model:FindFirstChild("Service counter")
		if anchor then
			anchors[island]=anchor
			local label=anchor:FindFirstChildWhichIsA("TextLabel",true)
			if label then label.Text=name.."\nCraft · Salvage · Awaken" end
			local prompt=Instance.new("ProximityPrompt")
			prompt.Name="ForgeWorkshopPrompt" prompt.ObjectText=name prompt.ActionText="Open Forge"
			prompt.RequiresLineOfSight=false prompt.MaxActivationDistance=13 prompt.Parent=anchor
		end
	end
end
