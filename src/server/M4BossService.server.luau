-- Server-controlled, in-place island encounters. Damage comes from CombatServer.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
local Data=require(script.Parent:WaitForChild("DataService"))
local Runtime=require(script.Parent:WaitForChild("M4WorldRuntime"))
local Config=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Economy=require(ReplicatedStorage:WaitForChild("Economy"))
local Rules=require(script.Parent:WaitForChild("BossRules"))
local Progress=require(script.Parent:WaitForChild("Progress"))
local Telemetry=require(script.Parent:WaitForChild("EconomyTelemetry"))
local A=require(ServerStorage:WaitForChild("M4Architecture"))
local notify=ReplicatedStorage.Remotes.Notify
local breakables=workspace:WaitForChild("Breakables")
local v=Vector3.new
local state={}
local rng=Random.new()

local function localPlayers(spec)
	local found={}
	for _,p in ipairs(Players:GetPlayers()) do
		local char=p.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local hum=char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health>0 and p:GetAttribute("CurrentIsland")==spec.Island
			and (root.Position-spec.Center).Magnitude<spec.Radius+10 and not p:GetAttribute("Handoff") then
			table.insert(found,{Player=p,Root=root,Humanoid=hum})
		end
	end
	return found
end

local function create(id,spec,number)
	local model=Instance.new("Model")
	model.Name=spec.Name
	local height=id=="CrystalColossus" and 12 or 9
	local at=spec.Center
	local core=A.Part(model,"Core",v(6,9,4),CFrame.new(at+v(0,5,0)),spec.Dark,Enum.Material.Slate,false)
	core.CanQuery=true
	model.PrimaryPart=core
	A.Part(model,"Mask",v(4.5,3.7,3.6),CFrame.new(at+v(0,height,0)),spec.Dark,Enum.Material.Slate)
	A.Part(model,"Core crystal",v(2.5,4,1),CFrame.new(at+v(0,6,-2.2)),spec.Color,Enum.Material.Neon)
	for _,side in ipairs({-1,1}) do
		A.Part(model,"Pauldrons",v(3.8,4.3,3.2),CFrame.new(at+v(side*4.5,8,0))*CFrame.Angles(0,0,side*.24),spec.Dark,Enum.Material.Slate)
		A.Part(model,"Arm",v(2.6,5.4,2.6),CFrame.new(at+v(side*4.7,5.2,-.45)),spec.Color,Enum.Material.Glacier)
		A.Part(model,"Greave",v(2.7,4.4,3.5),CFrame.new(at+v(side*1.8,2,0)),spec.Dark,Enum.Material.Slate)
		A.Part(model,"Rune eye",v(.7,.4,.22),CFrame.new(at+v(side*.8,height,-1.88)),spec.Color,Enum.Material.Neon)
	end
	for i=1,5 do
		A.Part(model,"Crown shard",v(.85,1.4+(3-math.abs(3-i))*.6,.8),
			CFrame.new(at+v((i-3)*.8,height+2.1,0))*CFrame.Angles(0,0,(i-3)*.22),spec.Color,Enum.Material.Ice)
	end
	local hit=A.Part(model,"Blade hitbox",v(12,12,8),CFrame.new(at+v(0,5.7,0)),spec.Color,Enum.Material.SmoothPlastic)
	hit.Transparency=1 hit.CanQuery=true
	local hp=spec.HP+math.clamp(number-1,0,7)*spec.HPPerPlayer
	model:SetAttribute("M4Boss",id)
	model:SetAttribute("Health",hp)
	model:SetAttribute("MaxHealth",hp)
	local gui=Instance.new("BillboardGui")
	gui.Size=UDim2.fromOffset(246,60) gui.StudsOffset=v(0,height+1.5,0) gui.MaxDistance=95
	gui.Parent=core
	local label=Instance.new("TextLabel")
	label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=.22 label.BackgroundColor3=spec.Dark
	label.TextColor3=spec.Color label.TextScaled=true label.Font=Enum.Font.GothamBold label.Parent=gui
	local function update()
		label.Text=spec.Name.."\n"..Config.FormatNumber(math.max(0,model:GetAttribute("Health") or 0)).." / "..Config.FormatNumber(hp)
	end
	update()
	model:GetAttributeChangedSignal("Health"):Connect(update)
	model.Parent=breakables
	return model
end

local function flat(a,b)
	return (v(a.X,0,a.Z)-v(b.X,0,b.Z)).Magnitude
end
local function telegraph(id,spec,current,players)
	local positions={}
	local radius
	if id=="CrystalColossus" then
		radius=12
		local p=players[rng:NextInteger(1,#players)].Root.Position
		table.insert(positions,v(p.X,spec.Center.Y,p.Z))
		if current:GetAttribute("Health")<current:GetAttribute("MaxHealth")*.48 then table.insert(positions,spec.Center) end
	else
		radius=7.5
		-- Telegraph three alternating wedge lanes as overlapping ice circles.
		local angle=rng:NextNumber(0,math.pi*2)
		for i=1,3 do
			local a=angle+i*math.pi*2/3
			local direction=v(math.cos(a),0,math.sin(a))
			for j=1,4 do table.insert(positions,spec.Center+direction*(8*j)) end
		end
		if current:GetAttribute("Health")<current:GetAttribute("MaxHealth")*.5 then table.insert(positions,spec.Center) end
	end
	local signals=Instance.new("Folder") signals.Name="Boss telegraph" signals.Parent=current
	for _,p in ipairs(positions) do
		local part=A.Part(signals,"Warning",v(.12,radius*2,radius*2),CFrame.new(p+v(0,.6,0))*CFrame.Angles(0,0,math.pi/2),
			id=="CrystalColossus" and Color3.fromRGB(255,159,108) or spec.Color,Enum.Material.Neon,false,Enum.PartType.Cylinder)
		part.Transparency=.52
	end
	task.delay(spec.Windup,function()
		if not current.Parent or (current:GetAttribute("Health") or 0)<=0 then return end
		for _,entry in ipairs(localPlayers(spec)) do
			for _,pos in ipairs(positions) do
				if flat(entry.Root.Position,pos)<=radius and entry.Root.Position.Y<pos.Y+12 then
					entry.Humanoid:TakeDamage(spec.Hit)
					break
				end
			end
		end
		signals:Destroy()
	end)
end

local function payout(current)
	local id=current:GetAttribute("M4Boss")
	local encounter=id and state[id]
	if not encounter or encounter.Model~=current or encounter.Paid or (current:GetAttribute("Health") or 1)>0 then return false end
	encounter.Paid=true
	local spec=Layout.Bosses[id]
	local shares,hits,players={},{},{}
	for _,entry in ipairs(localPlayers(spec)) do
		local p=entry.Player
		local damage=current:GetAttribute("Dmg_"..p.UserId)
		if damage and damage>0 and Data.Get(p) then
			shares[p.UserId]=damage hits[p.UserId]=current:GetAttribute("Hits_"..p.UserId) or 0 players[p.UserId]=p
		end
	end
	local rank=Rules.Rank(shares,hits)
	for i,row in ipairs(rank) do
		local p=players[row[1]]
		local rewards=Economy.BossReward(id,Data.PriceUnit(p),row[3],i==1,p:GetAttribute("LogMultBase"))
		local logs=Data.AddCoins(p,rewards.Logs,spec.Center,true)
		Data.AddSouls(p,rewards.Souls,spec.Center)
		Data.AddBossKill(p,id)
		local first,weapon=Data.GrantM4FirstClear(p,id)
		Progress.Add(p,"Boss",1)
		Progress.Add(p,"NPCs",1)
		Telemetry.Logs(p,logs,"boss") Telemetry.Souls(p,rewards.Souls)
		Data.Sync(p)
		if first then
			notify:FireClient(p,string.format("%s first clear • %s Sigil • %s",spec.Name,spec.Sigil,Config.WeaponById[weapon].Name),"boss")
		end
		notify:FireClient(p,string.format("%s defeated • %s Logs • %d Souls",spec.Name,Config.FormatNumber(logs),rewards.Souls),"boss")
	end
	return true
end

local down=Instance.new("BindableFunction")
down.Name="M4BossDown" down.OnInvoke=payout down.Parent=ServerStorage
local annex=workspace:FindFirstChild("M4ActiveWorld")
local crystal=annex and annex:FindFirstChild("CrystalWilds")
local crystalAvailable=Runtime.Crystal and crystal and crystal:FindFirstChild("CrystalColossusAnnex")
	and crystal:FindFirstChild("CrystalColossusAccess")
workspace:SetAttribute("M4ColossusReady",crystalAvailable and true or nil)
for id,spec in pairs(Layout.Bosses) do
	if (id=="CrystalColossus" and crystalAvailable) or (id=="FrostMonarch" and Runtime.Active) then
		local encounter={NextSpawn=0,NextAttack=0,Paid=false,LastPresence=0}
		state[id]=encounter
		task.spawn(function()
			while true do
				task.wait(.8)
				local now=os.clock()
				local present=localPlayers(spec)
				local model=encounter.Model
				if model and not model.Parent then
					encounter.Model=nil
					encounter.NextSpawn=now+spec.Respawn
				elseif model and #present==0 and now-encounter.LastPresence>35 then
					model:Destroy()
				elseif model and #present>0 then
					encounter.LastPresence=now
					if (model:GetAttribute("Health") or 0)>0 and now>encounter.NextAttack then
						encounter.NextAttack=now+spec.Cooldown
						telegraph(id,spec,model,present)
					end
				elseif not model and #present>0 and now>=encounter.NextSpawn then
					encounter.Model=create(id,spec,#present)
					encounter.Paid=false encounter.LastPresence=now encounter.NextAttack=now+3
					for _,player in ipairs(present) do notify:FireClient(player.Player,spec.Name.." awakens.","boss") end
				end
			end
		end)
	end
end
