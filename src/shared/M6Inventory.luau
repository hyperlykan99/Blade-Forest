-- An awakened representative is linked to the same owned catalog stack.
-- Copies, Pulled, Stars, Shiny and entitlements keep their original authority.
local D=require(script.Parent:WaitForChild("M6Design"))
local I={}
function I.Item(d,id)
	local map=d.M6 and d.M6.ItemByWeapon
	local key=map and map[id]
	local item=key and d.WeaponItems and d.WeaponItems[key]
	if type(item)=="table" and item.Schema==1 and item.WeaponId==id and type(item.Sockets)=="table" then return item end
end
function I.Stage(d,id)
	local item=I.Item(d,id)
	return item and math.clamp(math.floor(tonumber(item.Stage) or 0),0,3) or 0
end
function I.Bonuses(d)
	local item=I.Item(d,d.Equipped)
	if not item or not d.Weapons[d.Equipped] then return {} end
	local bonus={}
	for slot=1,I.Stage(d,d.Equipped) do
		local rune=D.RuneById[item.Sockets[tostring(slot)] or ""]
		if rune then bonus[rune.Channel]=math.min(rune.Cap,(bonus[rune.Channel] or 0)+rune.Amount) end
	end
	return bonus
end
function I.Remainder(data,kind)
	if kind=="Souls" then return data.Souls end
	if kind=="Essence" then return data.Essence.Total end
	if kind=="TrialToken" then return data.M5.Tokens end
	if kind=="ExpeditionFrostCore" or kind=="TrialSeal" then return data.M5.Materials[kind] or 0 end
	if kind:sub(1,5)=="Sigil" then return data.BossSigils[kind:sub(6)] or 0 end
	return data.M6.Materials[kind] or 0
end
function I.Check(data,costs)
	for kind,quantity in pairs(costs) do
		if I.Remainder(data,kind)<quantity then return false,"Need "..quantity.." "..(D.MaterialNames[kind] or kind) end
	end
	return true
end
function I.ApplyCosts(d,costs)
	for kind,n in pairs(costs) do
		if kind=="Souls" then d.Souls-=n
		elseif kind=="Essence" then d.Essence.Total-=n
		elseif kind=="TrialToken" then d.M5.Tokens-=n
		elseif kind=="ExpeditionFrostCore" or kind=="TrialSeal" then d.M5.Materials[kind]-=n
		elseif kind:sub(1,5)=="Sigil" then d.BossSigils[kind:sub(6)]-=n
		else d.M6.Materials[kind]-=n end
	end
end
function I.AddRune(d,id,n)
	if not D.RuneById[id] then return end
	local stock=d.M6.Runes
	stock[id]=(stock[id] or 0)+(n or 1)
end
function I.AddMaterial(d,id,n)
	d.M6.Materials[id]=(d.M6.Materials[id] or 0)+n
end
function I.Day(d,now)
	local day=math.floor(now/86400)
	if d.M6.Daily.Key~=day then d.M6.Daily={Key=day,ChopGrants={},ChopCount={},Salvage=0,Raids=0,Heart=0} end
	return d.M6.Daily
end
function I.RollRune(rank,random)
	return D.RuneTypes[random:NextInteger(1,#D.RuneTypes)].Id..rank
end
return I
