-- Run inside the private Studio Server DataModel using execute_luau.
-- Each simulated boundary reloads detached profiles. This fixture uses no live trade journal.
assert(game:GetService("RunService"):IsStudio() and game.PlaceId==103379930563763 and game.GameId==10777797608)
local root=game.ServerScriptService
local Flags=require(root.M7Flags)
assert(not Flags.TradeExecution and not Flags.PaidGifting)
local Items=require(root.M7Items)
local Journal=require(root.M7Journal)
local Data=require(root.DataService)
local Heart=require(root.HeartPhaseRules)
local Config=require(game.ReplicatedStorage.BladeConfig)
local Http=game.HttpService
local firstId,secondId=301,302
local weapon="FurnacecoreLongsword"
local pet=Config.PetEggs.TimberHaven[1].Id
local function copy(x) return Http:JSONDecode(Http:JSONEncode(x)) end
local function build(x)
	local ok,d=Data.BuildProfile(x and copy(x))
	assert(ok)
	return d
end
local function pair()
	local first,second=build(nil),build(nil)
	first.Weapons[weapon]={Copies=1,Star=0,Pulled=2}
	second.Pets[pet]=1
	Items.Credit(first,"Weapon",weapon,0,1,true)
	Items.Credit(second,"Pet",pet,0,1,true)
	local a,b=Items.Select(first,"Weapon",weapon),Items.Select(second,"Pet",pet)
	assert(a and b and a.Serial~=b.Serial)
	a.Owner=firstId b.Owner=secondId
	local journal={Id="QAProtocol",State="Preparing",Expires=200,Users={[tostring(firstId)]=a,[tostring(secondId)]=b},Prepared={}}
	return first,second,journal,a,b
end
local function prepare(d,item,other,journal)
	Items.Escrow(d,item)
	d.M7.Trade.Pending={Id=journal.Id,Item=item,Incoming=other}
	return build(d)
end
local tested={}
local function scenario(name,fn)
	local ok,err=pcall(fn)
	table.insert(tested,{Case=name,Passed=ok,Error=not ok and tostring(err) or nil})
end
scenario("Disconnect before escrow",function()
	local d,b,j,w,p=pair()
	j=Journal.Change(j,"Abort",firstId,100)
	assert(j.State=="Aborted" and Items.Settle(d,firstId,j) and Items.Settle(b,secondId,j))
	assert(Items.Select(d,"Weapon",weapon).Serial==w.Serial and Items.Select(b,"Pet",pet).Serial==p.Serial)
end)
scenario("One escrow saved, second untouched",function()
	local a,b,j,w,p=pair()
	a=prepare(a,w,p,j)
	j=Journal.Change(j,"Abort",secondId,105)
	assert(Items.Settle(a,firstId,j) and Items.Settle(b,secondId,j))
	assert(Items.Select(a,"Weapon",weapon).Serial==w.Serial and Items.Select(b,"Pet",pet).Serial==p.Serial)
end)
scenario("Both escrows, first acknowledged twice, then abort",function()
	local a,b,j,w,p=pair()
	a,b=prepare(a,w,p,j),prepare(b,p,w,j)
	j=Journal.Change(j,"Prepared",firstId,110)
	assert(Journal.Change(j,"Prepared",firstId,111).State=="Preparing")
	j=Journal.Change(j,"Abort",secondId,112)
	assert(Journal.Change(j,"Prepared",secondId,113).State=="Aborted")
	assert(Items.Settle(a,firstId,j) and Items.Settle(b,secondId,j))
	assert(Items.Select(a,"Weapon",weapon).Serial==w.Serial and Items.Select(b,"Pet",pet).Serial==p.Serial)
end)
scenario("Both saves and commit, restart before either settlement",function()
	local a,b,j,w,p=pair()
	a,b=prepare(a,w,p,j),prepare(b,p,w,j)
	j=Journal.Change(j,"Prepared",firstId,110)
	j=Journal.Change(j,"Prepared",secondId,120)
	assert(j.State=="Committed" and Journal.Change(j,"Abort",firstId,122).State=="Committed")
	assert(Items.Settle(a,firstId,copy(j)))
	a=build(a)
	assert(Items.Settle(b,secondId,copy(j)) and Items.Settle(a,firstId,copy(j)))
	b=build(b)
	assert(Items.Settle(b,secondId,copy(j)))
	assert(a.Pets[pet]==1 and a.Weapons[weapon].Copies==0 and b.Pets[pet]==0)
	assert(Items.Select(a,"Pet",pet).Serial==p.Serial and b.M6.ItemByWeapon[weapon]==w.Serial)
	assert(#a.M7.Trade.History==1 and #b.M7.Trade.History==1)
end)
scenario("Journal expiry and absent journal",function()
	local a,_,j,w,p=pair()
	a=prepare(a,w,p,j)
	assert(Journal.Change(nil,"Abort",firstId,201)==nil)
	assert(a.M7.Trade.Pending and a.Weapons[weapon].Copies==0)
	j=Journal.Change(j,"Prepared",firstId,201)
	assert(j.State=="Aborted" and Items.Settle(a,firstId,j) and a.Weapons[weapon].Copies==1)
end)
scenario("Large Heart hits preserve both transitions",function()
	assert(Heart.Damage(10000,10000,"I",1e9)==3300)
	assert(Heart.Damage(6700,10000,"II",1e9)==3600)
	assert(Heart.Damage(3100,10000,"III",1e9)==3100)
end)
scenario("Vault and favorites block eligible weapon serial",function()
	local a,_,_,w=pair()
	a.Favorites[weapon]=true
	assert(not Items.Select(a,"Weapon",weapon))
	a.Favorites[weapon]=nil
	assert(Items.Move(a,1,"Weapon",weapon))
	assert(not Items.Select(a,"Weapon",weapon))
	assert(Items.Move(a,1,nil) and Items.Select(a,"Weapon",weapon).Serial==w.Serial)
end)
return tested
