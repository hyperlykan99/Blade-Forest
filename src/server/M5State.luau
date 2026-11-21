-- Pure quest and contract rules. Profile writes occur in M5Service.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local C=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local S={}

local function sum(values)
	local n=0
	for _,v in pairs(values or {}) do if type(v)=="number" then n+=v end end
	return n
end

function S.Metric(d,kind,filter,bestPower)
	if kind=="Chops" then return d.Stats.TreesChopped or 0 end
	if kind=="Rolls" then return d.Rolls.Total or 0 end
	if kind=="Pets" then return d.Stats.PetsHatched or 0 end
	if kind=="Mutations" then return sum(d.MutationsFound) end
	if kind=="Bosses" then return sum(d.BossKills) end
	if kind=="Boss" then return d.BossKills[filter] or 0 end
	if kind=="Visits" then return d.M5.VisitCount end
	if kind=="Visit" then return d.M5.Visits[filter] and 1 or 0 end
	if kind=="Landmark" then return d.M5.Landmarks[filter] and 1 or 0 end
	if kind=="Unlock" then return d.UnlockedIslands[filter] and 1 or 0 end
	if kind=="TrialFinishes" then return d.M5.TrialFinishes end
	if kind=="Depth" then return d.M5.DepthEver end
	if kind=="Power" then return bestPower end
	if kind=="Trait" then
		return (C.TraitById[d.Trait] and 1 or 0) + (d.UnlockedIslands.FrostboundReach and d.Trait2~=d.Trait and C.TraitById[d.Trait2] and 1 or 0)
	end
	if kind=="Trees" or kind=="Types" then
		local n=0
		for id,count in pairs(d.Trees) do
			local tt=C.TreeTypes[id]
			if tt and count>0 then
				if kind=="Types" and tt.Area==filter then n+=1 end
				if kind=="Trees" and C.AreaIsland[tt.Area]==filter then n+=count end
			end
		end
		return n
	end
	if kind=="PetTypes" or kind=="IslandPet" then
		local n=0
		for _,pet in ipairs(C.Pets) do
			if (kind=="PetTypes" or pet.Island==filter)
				and ((d.Pets[pet.Id] or 0)+(d.PetGolden[pet.Id] or 0)+(d.PetRainbow[pet.Id] or 0)>0) then n+=1 end
		end
		return n
	end
	return 0
end

function S.Quest(d,island,bestPower)
	local defs=M.Chains[island]
	if not defs then return nil end
	local current=d.M5.Quests[island] or 0
	local progress={}
	for i,q in ipairs(defs) do
		progress[i]=math.min(q[4],S.Metric(d,q[2],q[3],bestPower))
	end
	return { Claimed=current, Progress=progress, Open=island=="TimberHaven" or d.UnlockedIslands[island]==true }
end

local function key(period,now)
	return period=="Daily" and M.Day(now) or M.Week(now)
end

local function seed(uid,k,salt)
	return (math.abs(uid)*131+k*313+salt*23)%2147483647
end

local function eligibleOrder(period,tier)
	local ids={}
	for _,id in ipairs(M.ContractOrder[period]) do
		local needsTravel=id=="Movement" or id=="Tour"
		if not needsTravel or tier>1 then table.insert(ids,id) end
	end
	return ids
end

function S.Period(d,period,now,uid,priceTier)
	local def=M.Periods[period]
	if not def then return nil end
	local k=key(period,now)
	local old=d.M5.Contracts[period]
	if old and old.Key==k then return old end
	local tier=M.IslandTier(d.UnlockedIslands)
	local rng=Random.new(seed(uid,k,period=="Daily" and 3 or 7))
	local pile=eligibleOrder(period,tier)
	for i=#pile,2,-1 do
		local j=rng:NextInteger(1,i)
		pile[i],pile[j]=pile[j],pile[i]
	end
	local offers={}
	for i=1,def.Offer do offers[i]={Id=pile[i]} end
	old={Key=k,Tier=tier,PriceTier=priceTier,Offers=offers,Rerolled=false}
	d.M5.Contracts[period]=old
	return old
end

function S.Offer(d,period,state,offer)
	local spec=M.ContractCatalog[period][offer.Id]
	local metric=spec[3]=="current" and M.Islands[state.Tier] or spec[3]
	local have=S.Metric(d,spec[2],metric,0)
	return spec,have,spec[4][state.Tier],metric
end

function S.Accept(d,period,state,index)
	local offer=state.Offers[index]
	if not offer or offer.Start~=nil then return false,"Offer already selected" end
	local picked=0
	for _,v in ipairs(state.Offers) do if v.Start~=nil then picked+=1 end end
	if picked>=M.Periods[period].Pick then return false,"Selection limit reached" end
	local _,have=S.Offer(d,period,state,offer)
	offer.Start=have
	return true
end

function S.Reroll(d,period,state,index,uid)
	local offer=state.Offers[index]
	local needed=period=="Daily" and 15 or 30
	if not offer or offer.Start~=nil or state.Rerolled or d.Mastery.Level<needed then
		return false,"Reroll unavailable for this offer"
	end
	local used={}
	for _,v in ipairs(state.Offers) do used[v.Id]=true end
	local rest={}
	for _,id in ipairs(eligibleOrder(period,state.Tier)) do if not used[id] then table.insert(rest,id) end end
	local rng=Random.new(seed(uid,state.Key,index+74))
	offer.Id=rest[rng:NextInteger(1,#rest)]
	state.Rerolled=true
	return true
end

function S.Claim(d,period,state,index)
	local offer=state.Offers[index]
	if not offer or offer.Start==nil or offer.Claimed then return nil,"Select a new contract first" end
	local spec,have,goal=S.Offer(d,period,state,offer)
	if have-offer.Start<goal then return nil,"Objective is incomplete" end
	offer.Claimed=true
	local plans={Logs=spec[5],Souls=spec[6]}
	if period=="Daily" then
		local complete=0
		for _,v in ipairs(state.Offers) do if v.Claimed then complete+=1 end end
		if complete==3 and d.M5.LastDaily~=state.Key then
			d.M5.Streak=d.M5.LastDaily==state.Key-1 and d.M5.Streak+1 or 1
			d.M5.LastDaily=state.Key
			plans.Logs+=.35
		end
	end
	return plans
end

function S.Weekly(d,now)
	local id=M.Week(now)
	local w=d.M5.Weekly
	if w.Key~=id then
		w={Key=id,Trial=0,Depth=0,Shop={}}
		d.M5.Weekly=w
	end
	return w
end

function S.Budget(d,now)
	local k=M.Day(now)
	local b=d.M5.Budget
	if b.Key~=k then
		b={Key=k,Tokens=0,DepthClaims=0}
		d.M5.Budget=b
	end
	return b
end

return S
