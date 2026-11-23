-- Static relief made from the verified Kenney mesh bank. Distances are in studs.
local Horizon = {}
local V, R = Vector3.new, Color3.fromRGB
local plans = {
	{ "Woodland Valley", V(0, 0, -3000), 380, 320,
		{R(69,100,62), R(79,111,76), R(108,139,126)}, 65, 88 },
	{ "Grand Crystal Canyon", V(3000, 0, 0), 300, 245,
		{R(65,77,87), R(78,108,124), R(118,143,158)}, 95, 139 },
	{ "Alpine Wilderness", V(6000, 0, 0), 320, 280,
		{R(101,131,151), R(143,172,190), R(172,192,210)}, 105, 157 },
}
-- Independent arcs leave a low view through the valley instead of a uniform skyline.
local sides = {
	{ V(0,0,-1), V(1,0,0), 0, {-1.13,-.56,.05,.66,1.12}, {-.7,-.38,.24,.67,.07} },
	{ V(0,0,1), V(1,0,0), math.pi, {-1.01,-.37,.29,.9}, {.33,-.18,.24,.60} },
	{ V(-1,0,0), V(0,0,1), math.pi/2, {-.86,-.22,.44,.94}, {.56,.15,-.25,.14} },
	{ V(1,0,0), V(0,0,1), -math.pi/2, {-.98,-.45,.19,.77}, {.11,.48,-.38,.29} },
}
local function model(parent, name)
	local node = Instance.new("Model")
	node.Name = name
	node.Parent = parent
	return node
end

local function sculpt(parent, bank, source, name, foot, size, yaw, color, solid)
	local part = assert(bank:FindFirstChild(source), source):Clone()
	part.Name = name
	part.Anchored = true
	part.CanCollide = solid == true
	part.CanTouch = false
	part.CanQuery = solid == true
	part.CastShadow = false
	part.Size = size
	part.CFrame = CFrame.new(foot + V(0,size.Y/2,0)) * CFrame.Angles(0,yaw,0)
	if color then
		part.TextureID = ""
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
	end
	part.Parent = parent
	return part
end

local function buildBiome(root, bank, plan, biome)
	local name, center, halfX, halfZ, inks, low, high = table.unpack(plan)
	local realm = model(root, name)
	for side, spec in ipairs(sides) do
		local forward, across, yaw, sites, profile = table.unpack(spec)
		local depth = side <= 2 and halfZ or halfX
		local span = side <= 2 and halfX or halfZ
		local reach = model(realm, ({"South watershed","North watershed","West slopes","East slopes"})[side])
		for i, offset in ipairs(sites) do
			local height = low + profile[i] * 47
			local radial = depth + 108 + ((side * 7 + i * 13) % 63)
			if biome == 2 and side == 1 then radial += 207 end -- leave both annexes and their bridge clear
			local at = center + forward*radial + across*offset*span
			local turn = yaw + profile[i]*.75
			local width = span*(.57 + (i%3)*.14)
			local relief = i%2==0 and "Boulder" or "Cliff"
			sculpt(reach,bank,relief,"Near escarpment",at-V(0,34,0),V(width,height,138+(i%3)*27),turn,inks[1])
			if i%2==1 then
				sculpt(reach,bank,"Boulder","Outer shelf",at-forward*37-V(0,27,0),V(width*.7,47,92),turn+.6,inks[2])
			end
			if biome == 1 and i%2==0 then
				for j = 1, 3 do
					local treeAt = at - forward*(49+j*3) + across*((j-2)*21)
					sculpt(reach,bank,"Spruce","Pine silhouette",treeAt+V(0,height*.18,0),
						V(18+j*2,38+j*6,17+j*2),turn+j,inks[1]:Lerp(R(32,59,38),.53))
				end
			elseif biome == 2 and i%2==0 then
				sculpt(reach,bank,"CrystalSpine","Mineral face",at-forward*46+V(0,4,0),
					V(25,52,20),turn+.38,inks[2])
			end
		end
		for i = 1, 3 do
			local lateral = (i-2)*span*.94 + (side%2==0 and 75 or -52)
			local at = center + forward*(depth+405+i*31) + across*lateral
			local height = high + ((side*23+i*37)%95)
			if biome==1 and side==1 and i==2 then height *= .67 end
			sculpt(reach,bank,i==2 and "Boulder" or "Cliff","Distant ridge",at-V(0,68,0),
				V(span*1.36,height,255),yaw+(i-2)*.34,inks[3])
		end
	end
end

local function gate(root, bank, anchor, name, destination, appearance)
	local threshold = model(root,name)
	sculpt(threshold,bank,"Pavers","Threshold",anchor+V(0,.04,0),V(11,.19,8),0,appearance)
	sculpt(threshold,bank,"GateArch","Passage",anchor+V(0,.25,-2),V(11,9,1.4),0,appearance)
	local point = Instance.new("Part")
	point.Name = "Portal interaction"
	point.Size = V(1,1,1)
	point.Position = anchor + V(0,2,0)
	point.Anchored = true
	point.Transparency = 1
	point.CanCollide = false
	point.CanTouch = false
	point.CanQuery = false
	point.Parent = threshold
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = name
	prompt.ActionText = "Travel"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("TravelTo",destination)
	prompt.Parent = point
end

function Horizon.Build(world, bank)
	local root = Instance.new("Folder")
	root.Name = "WorldHorizons"
	for biome, plan in ipairs(plans) do buildBiome(root,bank,plan,biome) end
	-- Timber brook outflow and the glacier below the southern escarpment.
	sculpt(root,bank,"Waterfall","Timber River Gorge",V(460,-58,-3369),V(60,82,41),.26,R(103,153,162))
	sculpt(root,bank,"River","Woodland River",V(502,-25,-3477),V(39,2,190),.28,R(86,136,146))
	sculpt(root,bank,"Waterfall","Glacier Fall",V(6395,-47,-350),V(78,115,61),-.34,R(164,197,213))
	sculpt(root,bank,"RuinedWall","Far alpine watch",V(5738,14,394),V(34,26,13),.48,R(125,150,171))

	-- A few reachable boundary outcrops have physical rock, with open views between them.
	sculpt(root,bank,"Boulder","Timber southwest rim",V(370,-11,-3305),V(27,18,19),.45,R(82,101,70),true)
	sculpt(root,bank,"Boulder","Timber northwest rim",V(-369,-9,-2690),V(22,15,22),.55,R(73,98,71),true)
	sculpt(root,bank,"Boulder","Frost north rim",V(6180,-10,273),V(31,19,18),.1,R(145,172,188),true)
	sculpt(root,bank,"Boulder","Frost east rim",V(6313,-11,128),V(20,20,33),.5,R(133,162,184),true)

	-- Surveyed empty part of the existing Crystal arrival floor, away from the arrival ring.
	gate(root,bank,V(2812,2,21),"Frostbound Reach","FrostboundReach",R(124,156,189))
	sculpt(root,bank,"GateArch","Crystal west return arch",V(2775,3,14),V(10,8,1.4),0,R(134,161,180))
	sculpt(root,bank,"GateArch","Frostgate home arch",V(5726,.2,-22),V(11,9.5,1.4),0,R(171,194,206))
	sculpt(root,bank,"GateArch","Frostgate canyon arch",V(5726,.2,17),V(11,9.5,1.4),0,R(138,178,196))
	root.Parent = world
end

return Horizon
