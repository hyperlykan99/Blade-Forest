local RS=game:GetService("ReplicatedStorage")
local D=require(RS:WaitForChild("M8Design"))
local S={}
S.Default={Schema=1,Seasons={},Editions={},AchievementClaims={},Guide={},Counts={},BadgePending={},PetDiscoveries={Normal={},Golden={},Rainbow={}}}
local function count(t)
	local n=0
	for _,v in pairs(t or {}) do if v==true or type(v)=="number" and v>0 or type(v)=="table" then n+=1 end end
	return n
end
local function among(keys,t)
	local n=0
	for _,id in ipairs(keys) do
		local v=t[id]
		if v==true or type(v)=="number" and v>0 or type(v)=="table" then n+=1 end
	end
	return n
end
local function boss(data,id)
	return math.max(data.BossKills[id] or 0,data.BossFirstClears[id] and 1 or 0)
end
function S.MarkPets(d)
	local old=d.M8.PetDiscoveries
	for id,n in pairs(d.Pets) do if n>0 then old.Normal[id]=true end end
	for id,n in pairs(d.PetGolden) do if n>0 then old.Normal[id]=true old.Golden[id]=true end end
	for id,n in pairs(d.PetRainbow) do if n>0 then old.Normal[id]=true old.Golden[id]=true old.Rainbow[id]=true end end
end
function S.Metrics(d,e)
	local w=d.M6.BossClears
	local raids=(w.TreantRaid or 0)+(w.HydraRaid or 0)+(w.GiantRaid or 0)
	local awakened,legacyCraft=0,0
	for _,item in pairs(d.WeaponItems) do if (item.Stage or 0)>0 then awakened+=1 end end
	for _,route in pairs(d.M6.Acquired) do if route=="Forge commission" then legacyCraft+=1 end end
	S.MarkPets(d)
	local old=d.M8.PetDiscoveries
	local normal,petsEvolved=among(e.Pets,old.Normal),among(e.Pets,old.Golden)+among(e.Pets,old.Rainbow)
	return {
		Chops=d.Stats.TreesChopped or 0,Trees=among(e.Trees,d.Trees),Indexes=among(e.Areas,d.TreeIndexDone),
		Mutations=count(d.MutationsFound),Rarest=d.Stats.RarestOneIn or 0,Weapons=among(e.Weapons,d.Weapons),
		Pets=normal,PetForms=normal+petsEvolved,Evolved=petsEvolved,Mastery=d.Mastery.Level,
		BladeKing=boss(d,"BladeKing"),FrostMonarch=boss(d,"FrostMonarch"),Colossus=boss(d,"CrystalColossus"),
		Raids=raids,RaidKinds=among({"TreantRaid","HydraRaid","GiantRaid"},w),Heart=w.HeartOfWinter or 0,
		Trials=d.M5.TrialFinishes,TrialBest=d.M6.TrialBest,Depth=d.M5.DepthEver,
		Crafts=math.max(d.M8.Counts.Crafts or 0,legacyCraft+awakened),Awakened=awakened,
		Showcase=math.max(d.M8.Counts.Showcase or 0,(#d.M7.FavoriteWeapon>0 or #d.M7.PetShowcase>0 or next(d.M7.Vault)~=nil) and 1 or 0),
		Party=d.M8.Counts.Party or 0,Guild=math.max(d.M8.Counts.Guild or 0,d.M7.ActiveGuild and 1 or 0),
	}
end
local function add(scores,category,num,den,weight)
	table.insert(scores,{Name=category,Count=num,Target=den,Weight=weight,Points=math.floor(math.min(num,den)*weight/den)})
end
function S.Score(d,e)
	local m=S.Metrics(d,e)
	local bossCount=(m.BladeKing>0 and 1 or 0)+(m.Colossus>0 and 1 or 0)+(m.FrostMonarch>0 and 1 or 0)
		+m.RaidKinds+(m.Heart>0 and 1 or 0)
	local achievements=0
	for _,a in ipairs(D.Achievements) do if m[a.Metric]>=a.Goal or d.M8.AchievementClaims[a.Id] then achievements+=1 end end
	local cosmetics={"FirstGrowth","BladeArchivist","MasterPath","IslandGuard","RaidVanguard","WinterVictor","GuildBanner","SeasonedGuild"}
	local rows={}
	add(rows,"Weapon catalogue",m.Weapons,119,370)
	add(rows,"Pet forms",m.PetForms,63,235)
	add(rows,"Tree discoveries",m.Trees,#e.Trees,90)
	add(rows,"Completed tree indexes",m.Indexes,#e.Areas,45)
	add(rows,"Boss and raid victories",bossCount,7,85)
	add(rows,"Mastery",m.Mastery-1,99,65)
	add(rows,"Titles and auras",among(cosmetics,d.M7.Titles)+among(cosmetics,d.M7.Auras),10,50)
	add(rows,"Achievement goals",achievements,24,60)
	local sum=0
	for _,r in ipairs(rows) do sum+=r.Points end
	local ed=d.M8.Editions[e.Id]
	if not ed then ed={Best=0,Claims={}} d.M8.Editions[e.Id]=ed end
	ed.Best=math.max(ed.Best,sum)
	return ed,rows,m
end
function S.Season(d,s)
	local data=d.M8.Seasons[s.Id]
	if not data then
		data={XP=0,Claims={},Weeks={},Events={},Day=-1,Today={},Steps={},Reported=0}
		d.M8.Seasons[s.Id]=data
	end
	return data
end
local function progression(rows,id,target,amount)
	local row=rows[id]
	if not row then row={Count=0} rows[id]=row end
	row.Count=math.min(target,row.Count+amount)
end
function S.Record(d,kind,amount,now)
	if not d or not d.M8 or type(amount)~="number" or amount<=0 or amount~=amount then return 0 end
	local s=D.Active(now)
	local rule=D.Sources[kind]
	if not s or not rule then return 0 end
	local data=S.Season(d,s)
	local day=math.floor(now/D.Day)
	if data.Day~=day then data.Day=day data.Today={} data.Steps={} end
	local track=kind=="Daily" or kind=="Weekly"
	local source=track and "Contracts" or kind
	local week=D.WeekAt(s,now)
	local key=tostring(week)
	local weekly=data.Weeks[key]
	if not weekly then weekly={} data.Weeks[key]=weekly end
	for _,v in ipairs(s.Challenges) do if v.Source==source then progression(weekly,v.Id,v.Goal,amount) end end
	for _,v in ipairs(s.Events) do
		if v.Source==source and week>=v.FromWeek and week<=v.ThroughWeek then
			progression(data.Events,v.Id,v.Goal,amount)
		end
	end
	local steps=(data.Steps[kind] or 0)+amount
	local interval=rule.Every or 1
	data.Steps[kind]=steps%interval
	local earned=math.min(math.floor(steps/interval)*rule.XP,rule.Cap-(data.Today[kind] or 0),#s.Track*s.XPPerLevel-data.XP)
	earned=math.max(0,earned)
	data.Today[kind]=(data.Today[kind] or 0)+earned
	data.XP+=earned
	return earned
end
function S.Level(data,s)
	return math.min(#s.Track,math.floor(data.XP/s.XPPerLevel))
end
function S.ClaimChallenge(d,s,id,week,now)
	if now<s.Start or now>=s.Finish+s.ClaimGrace then return false,"Claim period closed" end
	local data=d.M8.Seasons[s.Id]
	if not data then return false,"No progress recorded" end
	local definitions=week==0 and s.Events or s.Challenges
	local rows=week==0 and data.Events or data.Weeks[tostring(week)]
	for _,q in ipairs(definitions) do
		if q.Id==id then
			local progress=rows and rows[id]
			if not progress or progress.Claimed or progress.Count<q.Goal then return false,"Challenge incomplete or already claimed" end
			progress.Claimed=true
			data.XP=math.min(#s.Track*s.XPPerLevel,data.XP+q.XP)
			return true,q.Name
		end
	end
	return false,"Unknown challenge"
end
return S
