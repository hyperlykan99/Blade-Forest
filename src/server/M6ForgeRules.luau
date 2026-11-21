-- Atomic, no-yield profile transformations. The request wrapper owns synchronization.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local D=require(RS:WaitForChild("M6Design"))
local I=require(RS:WaitForChild("M6Inventory"))
local C=require(RS:WaitForChild("BladeConfig"))
local SocialItems=require(script.Parent:WaitForChild("M7Items"))
local F={}
local function payable(d,costs)
	local ok,why=I.Check(d,costs)
	if not ok then return false,why end
	I.ApplyCosts(d,costs)
	return true
end
function F.Recipe(d,id,reward)
	local r=D.ByRecipe[id]
	if not r or not d.UnlockedIslands[r.Island] or d.Mastery.Level<r.Mastery then return false,"Discover this recipe through island and Mastery progression" end
	if r.TrialScore and math.max(d.M5.Weekly.Trial or 0,d.M6.TrialBest or 0)<r.TrialScore then return false,"Reach the required Trial score" end
	if r.Weapon and (not C.WeaponById[r.Weapon] or d.Weapons[r.Weapon]) then return false,"This weapon is already owned or unavailable" end
	if r.Key and d.M6.Keys>=12 then return false,"Winter Key stock is full" end
	local ok,why=payable(d,r.Costs)
	if not ok then return false,why end
	if r.Key then d.M6.Keys+=1
	else reward(r.Weapon,r.TrialScore and "Trial commission" or "Forge commission") end
	return true,r.Name
end
function F.Salvage(d,weaponId,count,now)
	local w=C.WeaponById[weaponId]
	local entry=w and d.Weapons[weaponId]
	if type(count)~="number" or count%1~=0 or count<1 or count>10 then return false,"Select 1–10 duplicates" end
	if not entry or w.Exclusive or not w.Future.Forgeable or d.Favorites[weaponId] or SocialItems.Protected(d,"Weapon",weaponId) or (entry.Copies or 0)<count then
		return false,"Only spare, non-favorite eligible copies can be salvaged"
	end
	local budget=I.Day(d,now)
	if budget.Salvage+count>D.SalvagesPerDay then return false,"Daily salvage budget exceeded" end
	local rarity=C.RarityById[w.Rarity].Order
	local before=entry.Copies
	entry.Copies-=count budget.Salvage+=count
	SocialItems.Credit(d,"Weapon",weaponId,before,entry.Copies,false)
	local material=D.MaterialByIsland[w.Island] or "Bark"
	I.AddMaterial(d,material,count*math.clamp(math.ceil(rarity/2),1,4))
	d.Essence.Total+=count*math.clamp(rarity*3,3,24)
	return true,"Duplicates salvaged"
end
function F.Awaken(d,weaponId)
	local w=C.WeaponById[weaponId]
	local entry=w and d.Weapons[weaponId]
	local stage=I.Stage(d,weaponId)+1
	local rule=D.Awakening[stage]
	if not rule or not entry or (entry.Star or 0)<C.MaxStar or stage>w.Future.MaxAwakening or not d.UnlockedIslands[rule.Island] then
		return false,"Requires an eligible five-star weapon and the corresponding island"
	end
	local ok,why=I.Check(d,rule.Costs)
	if not ok then return false,why end
	local item=I.Item(d,weaponId)
	if not item then
		local key=Http:GenerateGUID(false)
		item={Schema=1,WeaponId=weaponId,Stage=0,Sockets={},TradeLocked=true,Bound=true}
		d.WeaponItems[key]=item d.M6.ItemByWeapon[weaponId]=key
	end
	I.ApplyCosts(d,rule.Costs)
	item.Stage=stage
	item.TradeLocked=true item.Bound=true
	return true,"Awakening "..({"I","II","III"})[stage]
end
function F.Socket(d,weaponId,slot,runeId)
	local item=I.Item(d,weaponId)
	if not d.Weapons[weaponId] or not item or type(slot)~="number" or slot%1~=0 or slot<1 or slot>I.Stage(d,weaponId) then
		return false,"Socket unavailable"
	end
	local key=tostring(slot)
	local old=item.Sockets[key]
	if runeId==old then return false,"Socket unchanged" end
	if runeId then
		local rune=D.RuneById[runeId]
		if not rune or (d.M6.Runes[runeId] or 0)<1 then return false,"Rune is unavailable" end
		d.M6.Runes[runeId]-=1
	end
	if old then I.AddRune(d,old,1) end
	item.Sockets[key]=runeId
	return true,runeId and "Rune socketed" or "Rune returned"
end
local function runeCost(rank,souls)
	local cost=table.clone(D.RuneCraft[rank])
	cost.Souls=souls
	return cost
end
function F.CreateRune(d,runeId)
	local rune=D.RuneById[runeId]
	if not rune or not d.UnlockedIslands[({"TimberHaven","CrystalWilds","FrostboundReach","FrostboundReach"})[rune.Rank]] then
		return false,"Rune recipe locked"
	end
	local stock=d.M6.Runes
	local prev=rune.Type..(rune.Rank-1)
	if rune.Rank>1 and (stock[prev] or 0)<3 then return false,"Need three loose runes of the previous rank" end
	local ok,why=payable(d,runeCost(rune.Rank,D.RunecraftSoul[rune.Rank]))
	if not ok then return false,why end
	if rune.Rank>1 then stock[prev]-=3 end
	I.AddRune(d,runeId,1)
	return true,rune.Name
end
function F.Reroll(d,runeId,random)
	local rune=D.RuneById[runeId]
	if not rune or (d.M6.Runes[runeId] or 0)<1 then return false,"Select a loose rune" end
	local cost=runeCost(rune.Rank,D.RerollSoul[rune.Rank])
	for key,amount in pairs(cost) do if key~="Souls" then cost[key]=math.max(1,math.ceil(amount/3)) end end
	local ok,why=payable(d,cost)
	if not ok then return false,why end
	local choices={}
	for _,group in ipairs(D.RuneTypes) do if group.Id~=rune.Type then table.insert(choices,group.Id..rune.Rank) end end
	local result=choices[random:NextInteger(1,#choices)]
	d.M6.Runes[runeId]-=1 I.AddRune(d,result,1)
	return true,D.RuneById[result].Name
end
return F
