local Art={}
local V=Vector3.new
local CF=CFrame.new
local rgb=Color3.fromRGB
local M=Enum.Material
local buffer=9.5
local spacing=5.55
local north=V(8,0,-2929)
local wood=rgb(90,56,38)
local amber=rgb(204,153,84)
local slate=rgb(64,72,64)
local moss=rgb(72,114,69)

local function flatten(p) return V(p.X,0,p.Z) end
local function getRoads(root)
	local roads={}
	for _,p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") and p.Name=="Packed trail" then table.insert(roads,p) end
	end
	return roads
end
local function roadClearance(p,roads)
	local best=math.huge
	for _,r in ipairs(roads) do
		local q=r.CFrame:PointToObjectSpace(p)
		local x=math.max(0,math.abs(q.X)-r.Size.X*.5)
		local z=math.max(0,math.abs(q.Z)-r.Size.Z*.5)
		best=math.min(best,math.sqrt(x*x+z*z))
	end
	return best
end
Art.RoadClearance=roadClearance
Art.GetRoads=getRoads

function Art.Plan(package,layout)
	local roads=getRoads(package.TimberHaven)
	assert(#roads==9,"Timber route geometry changed")
	local result,grid,suspect={}, {}, {}
	local protected={
		{V(-24,0,-3000),32},{V(0,0,-3125),39},{V(-144,0,-3020),42},
		{V(-250,0,-3230),55},{V(250,0,-3230),55},{north,47},
		{V(54,0,-2880),10},{V(-225,0,-2978),10},{layout.Timber.Treant,29},
	}
	for _,camp in ipairs(layout.Timber.Camps) do table.insert(protected,{camp,14}) end
	local function fits(p,plot)
		local base=layout.Timber.Center
		if math.abs(p.X-base.X)>layout.Timber.Width/2-26 or math.abs(p.Z-base.Z)>layout.Timber.Depth/2-24 then return false end
		if math.abs(p.X-plot.Center.X)>plot.Cols*plot.Step/2+68 or math.abs(p.Z-plot.Center.Z)>plot.Rows*plot.Step/2+64 then return false end
		-- Keep Common Grove trees away from the Pine progression region.
		if layout.TimberArea(p)~=plot.Area then return false end
		for _,zone in ipairs(protected) do if (p-zone[1]).Magnitude<zone[2] then return false end end
		return roadClearance(p,roads)>=buffer
	end
	local function coord(p) return math.floor(p.X/spacing),math.floor(p.Z/spacing) end
	local function bucket(x,z) return x..":"..z end
	local function unoccupied(p)
		local x,z=coord(p)
		for dx=-1,1 do for dz=-1,1 do
			local near=grid[bucket(x+dx,z+dz)]
			if near then for _,q in ipairs(near) do if (p-q).Magnitude<spacing then return false end end end
		end end
		return true
	end
	local function occupy(p)
		local x,z=coord(p)
		local key=bucket(x,z)
		grid[key]=grid[key] or {}
		table.insert(grid[key],p)
	end
	local folders=package.Trees:GetChildren()
	table.sort(folders,function(a,b) return a.Name:sub(-1)<b.Name:sub(-1) end)
	local baseline,visited=0,0
	for index,f in ipairs(folders) do
		local rows=f:GetChildren()
		local plot=assert(layout.Timber.Forests[index])
		table.sort(rows,function(a,b)
			local x,y=a:GetPivot().Position,b:GetPivot().Position
			return x.X<y.X or x.X==y.X and x.Z<y.Z
		end)
		for i,t in ipairs(rows) do
			visited+=1
			if visited%160==0 then task.wait() end
			local home=flatten(t:GetPivot().Position)
			if roadClearance(home,roads)<buffer then baseline+=1 end
			local rare=t:GetAttribute("Rarity")
			local delta=V(math.sin(i*2.2+index)*1.45,0,math.cos(i*1.7-index)*1.45)
			local test=home+delta
			local reserved=rare=="Mythic" or rare=="Secret"
			local entry={Tree=t,Old=home,Plot=plot,Index=i+index*500}
			if not reserved and fits(test,plot) and unoccupied(test) then
				entry.New=test
			elseif fits(home,plot) and unoccupied(home) then
				entry.New=home
			else
				table.insert(suspect,entry)
			end
			if entry.New then occupy(entry.New) end
			table.insert(result,entry)
		end
	end
	-- Nearby clearings fill first. If an original row has no room, use the
	-- nearest remaining position in the same forest rather than dropping a slot.
	local candidates={}
	for _,plot in ipairs(layout.Timber.Forests) do
		candidates[plot]={}
		local spanX=plot.Cols*plot.Step/2+68
		local spanZ=plot.Rows*plot.Step/2+64
		local column=0
		for x=-spanX,spanX,spacing do
			column+=1
			for z=-spanZ,spanZ,spacing do
				local p=plot.Center+V(x,0,z)
				if fits(p,plot) then table.insert(candidates[plot],p) end
			end
			if column%10==0 then task.wait() end
		end
	end
	for index,entry in ipairs(suspect) do
		if index%16==0 then task.wait() end
		for i=1,380 do
			local angle=i*2.399963+entry.Index*.761
			local radius=math.sqrt(i)*2.8
			local p=entry.Old+V(math.cos(angle)*radius,0,math.sin(angle)*radius)
			if fits(p,entry.Plot) and unoccupied(p) then
				entry.New=p
				break
			end
		end
		if not entry.New then
			local closest=math.huge
			for _,p in ipairs(candidates[entry.Plot]) do
				local distance=(p-entry.Old).Magnitude
				if distance<closest and unoccupied(p) then
					closest=distance
					entry.New=p
				end
			end
		end
		if not entry.New then return nil,{Unplaced=entry.Tree.Name,At=tostring(entry.Old)} end
		occupy(entry.New)
	end
	local min=math.huge
	for _,entry in ipairs(result) do min=math.min(min,roadClearance(entry.New,roads)) end
	return result,{Slots=#result,NearRoadBefore=baseline,Replanted=#suspect,RoadMargin=min},roads
end

local function boardPavilion(boards,pavilion,A)
	local ids={Logs="TIMBER HARVEST",Rarest="RARE FINDS",Hours="TRAIL VETERANS"}
	local order={Logs=1,Rarest=2,Hours=3}
	for _,m in ipairs(boards:GetChildren()) do
		if not m:IsA("Model") then continue end
		local id=m:GetAttribute("Board")
		local idx=order[id]
		local face=m:FindFirstChild("Face",true)
		if not idx or not face then continue end
		local at=north+V((idx-2)*23,6.55,.9)
		local rel=m:GetPivot():ToObjectSpace(face.CFrame)
		m:PivotTo(CF(at)*rel:Inverse())
		for _,p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
				if p~=face then p.Transparency=1 end
			end
		end
		face.Color=rgb(36,39,35)
		face.Material=M.WoodPlanks
		local gui=face:FindFirstChild("BoardGui")
		if gui and gui:IsA("SurfaceGui") then
			gui.MaxDistance=85
			gui.LightInfluence=0
			local title=gui:FindFirstChild("Title")
			if title then title.Text=ids[id] end
		end
		A.Part(pavilion,"Board timber frame",V(21.8,13,1.2),CF(at+V(0,0,.56)),wood,M.WoodPlanks)
		for _,side in ipairs({-1,1}) do
			A.Part(pavilion,"Carved side rail",V(.47,12.68,.46),CF(at+V(side*10.58,0,-.23)),amber,M.Wood)
		end
	end
end

function Art.Dress(package,boards,A,visuals)
	local root=package.TimberHaven
	local work=Instance.new("Model")
	work.Name="Timber Haven • trailworks"
	work.Parent=root
	local function p(name,size,offset,color,material,angle)
		local at=CF(north+offset)
		if angle then at*=CFrame.Angles(0,0,angle) end
		return A.Part(work,name,size,at,color,material)
	end
	if boards then boardPavilion(boards,work,A) end
	p("Flush slate forecourt",V(76,.19,21),V(0,.1,-6),rgb(105,105,87),M.Slate)
	p("Records lane",V(10,.13,47),V(-13,.08,-36),rgb(169,140,98),M.Ground)
	p("Lodge eave",V(76,1,4.8),V(0,13.3,-.05),wood,M.WoodPlanks)
	p("Copper-green roof front",V(76,.8,6.2),V(0,14.2,-1.8),rgb(62,111,91),M.Slate)
	p("Copper-green roof rear",V(76,.8,6.2),V(0,14.2,2.1),rgb(53,88,72),M.Slate)
	p("Ridgeline",V(76,.85,.65),V(0,14.85,.13),amber,M.Wood)
	for _,x in ipairs({-35,-11.5,11.5,35}) do
		p("Pavilion stone footing",V(2.6,1.25,2.45),V(x,.65,.15),slate,M.Slate)
		p("Hewn timber column",V(1.52,13.1,1.55),V(x,7,.15),wood,M.Wood)
	end
	for _,x in ipairs({-35,35}) do
		p("Amber lantern",V(.85,1.35,.85),V(x,8,-1.0),amber,M.Neon)
		p("Lantern hood",V(1.08,.28,1.08),V(x,8.83,-1.0),wood,M.Wood)
	end
	A.Sign(work,north+V(33,0,-14),"Haven Records Lodge","Timber harvest • rare finds • trail veterans",
		{Wood=wood,Roof=slate})
	for i,pos in ipairs({V(-31,0,-2936),V(47,0,-2940),V(-4,0,-2968),V(31,0,-2967),V(-41,0,-3148),V(41,0,-3148)}) do
		local id=i%3==0 and "Grove_Rare" or i%2==0 and "Grove_Uncommon" or "Grove_Common"
		local tpl=visuals[id]
		if tpl then
			local model=tpl:Clone()
			model.Name="Village shade tree"
			model:ScaleTo(i<=2 and 1.15 or .86)
			model:PivotTo(CF(pos)*CFrame.Angles(0,i*.82,0))
			for _,b in ipairs(model:GetDescendants()) do if b:IsA("BasePart") then b.CanQuery=false end end
			model.Parent=work
			A.Part(work,"Moss bed",V(5,.12,3.8),CF(pos+V(0,.08,0)),moss,M.Grass)
		end
	end
	for _,point in ipairs({
		{V(4,0,-2987),"Sapling Woods →","Wide trail east"},
		{V(104,0,-2909),"Pinewood Hollow","Follow the open bend north"},
		{V(-179,0,-2996),"Elderpine Ridge","Blue-green pines past Collectors’ Row"},
		{V(53,0,-3132),"Portal Cliffs →","Travel gates ahead"},
	}) do
		A.Sign(work,point[1],point[2],point[3],{Wood=wood,Roof=slate})
	end
end
return Art
