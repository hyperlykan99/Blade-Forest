-- Art-only tree surfaces. M4 continues to own the interaction model and its attributes.
local Art={}
local V=Vector3.new
local CF=CFrame.new
local rgb=Color3.fromRGB
local bark=rgb(100,61,40)
local wood=Enum.Material.Wood
local matte=Enum.Material.SmoothPlastic
local recipes={
	Grove_Common={"Broadleaf",8,6,rgb(99,166,83),rgb(154,194,100)},
	Grove_Uncommon={"Broadleaf",10,7,rgb(100,149,65),rgb(192,211,121)},
	Grove_Rare={"Broadleaf",12,8,rgb(188,114,41),rgb(243,176,70)},
	Grove_Epic={"Broadleaf",14,8.6,rgb(152,56,49),rgb(221,108,67)},
	Grove_Legendary={"Oak",16,9.8,rgb(184,121,36),rgb(250,206,105)},
	Grove_Mythic={"Boughs",18,10,rgb(155,82,123),rgb(244,164,199)},
	Grove_Secret={"Boughs",20,10.2,rgb(131,123,214),rgb(234,208,130)},
	Pine_Common={"PineFaceted",13,6.6,rgb(41,91,65),rgb(72,137,88)},
	Pine_Uncommon={"PineTall",16,7.2,rgb(45,106,88),rgb(106,164,129)},
	Pine_Rare={"PineFaceted",15,7.5,rgb(59,112,98),rgb(126,176,141)},
	Pine_Epic={"PineTall",17,8.2,rgb(134,76,53),rgb(226,128,62)},
	Pine_Legendary={"PineTall",20,9,rgb(171,117,50),rgb(248,200,101)},
	Pine_Mythic={"Shelf",16,10,rgb(166,89,60),rgb(227,158,105)},
	Pine_Secret={"Boughs",22,10.4,rgb(52,125,96),rgb(145,214,154)},
}
Art.Recipes=recipes

local function part(root,name,size,frame,color,material,geometry,leaf)
	local p=Instance.new(geometry=="Wedge" and "WedgePart" or geometry=="Corner" and "CornerWedgePart" or "Part")
	p.Name=name
	p.Size=size
	p.CFrame=frame
	p.Color=color
	p.Material=material
	p.Anchored=true
	p.CanCollide=false
	p.CanTouch=false
	p.CanQuery=true
	p.CastShadow=false
	if geometry=="Ball" then p.Shape=Enum.PartType.Ball end
	if geometry=="Cylinder" then p.Shape=Enum.PartType.Cylinder end
	if leaf then p:SetAttribute("Leaf",true) p:SetAttribute("LeafColor",color) end
	p.Parent=root
	return p
end
local function limb(root,name,a,b,width,color)
	return part(root,name,V((a-b).Magnitude,width,width),CFrame.lookAt(a:Lerp(b,.5),b)*CFrame.Angles(0,math.pi/2,0),color,wood,"Cylinder")
end
local function canopy(root,name,x,y,z,w,h,d,c,angle)
	return part(root,name,V(w,h,d),CF(x,y,z)*CFrame.Angles(0,angle or 0,0),c,matte,"Ball",true)
end

local function imported(root,assets,spec)
	local template=assets and assets:FindFirstChild(spec[1])
	if not template then return false end
	local _,size=template:GetBoundingBox()
	local lateral=spec[3]/math.max(size.X,size.Z)
	local proportion=V(lateral,spec[2]/size.Y,lateral)
	local foot=template:GetPivot()
	for _,source in ipairs(template:GetChildren()) do
		if source:IsA("MeshPart") then
			local p=source:Clone()
			local relative=foot:ToObjectSpace(source.CFrame)
			p.Size=source.Size*proportion
			p.CFrame=CF(relative.Position*proportion)*relative.Rotation
			local isLeaf=p.Name=="Crown"
			p.Color=isLeaf and spec[4] or bark
			p:SetAttribute("Leaf",isLeaf)
			if isLeaf then p:SetAttribute("LeafColor",p.Color) end
			p.Parent=root
		end
	end
	return true
end

function Art.Visual(id,assets)
	local spec=assert(recipes[id],id)
	local form,h,w,color,tip=table.unpack(spec)
	local root=Instance.new("Model")
	root.Name="Timber crown"
	if not imported(root,assets,spec) then
		limb(root,"Tapered trunk",V(0,0,0),V(.3,h*.75,.16),math.clamp(h*.085,.75,1.7),bark)
		if form=="PineFaceted" or form=="PineTall" then
			for i=1,3 do
				local span=w*(1-(i-1)*.23)
				local y=h*(.48+i*.16)
				part(root,"Faceted needles",V(span,h*.35,span),CF(0,y,0)*CFrame.Angles(0,i*.72,0),
					color:Lerp(tip,(i-1)*.33),matte,"Corner",true)
				part(root,"Needle skirt",V(span*.84,h*.22,span*.82),CF(0,y-h*.055,0)*CFrame.Angles(0,.4+i*.72,0),
					color:Lerp(tip,(i-1)*.23),matte,"Ball",true)
			end
		elseif form=="Boughs" then
			limb(root,"Swept bough",V(0,h*.34,0),V(w*.33,h*.65,.6),.82,bark)
			limb(root,"Forked crown",V(.2,h*.48,0),V(-w*.33,h*.79,-.5),.72,bark)
			limb(root,"Visible root",V(-1.95,.12,-.8),V(.18,h*.23,.05),.68,bark)
			canopy(root,"High crown",-.95,h*.90,-.3,w*.77,h*.23,w*.71,tip,.35)
			canopy(root,"Swept crown",w*.27,h*.71,.46,w*.60,h*.19,w*.60,color,.56)
			canopy(root,"Counter crown",-w*.24,h*.76,-.5,w*.57,h*.2,w*.52,color,-.68)
			part(root,"Crown facet",V(w*.42,h*.21,w*.4),CF(-.62,h*.975,.38)*CFrame.Angles(0,.72,.13),tip,matte,"Corner",true)
		elseif form=="Shelf" then
			limb(root,"Crooked shelf",V(0,h*.44,0),V(w*.36,h*.67,.4),.89,bark)
			canopy(root,"Lower fan",w*.19,h*.58,.2,w*.74,h*.15,w*.70,color,.24)
			canopy(root,"High fan",-.66,h*.86,-.5,w*.91,h*.19,w*.82,tip,-.38)
			canopy(root,"Fan lip",-w*.25,h*.75,1.15,w*.53,h*.12,w*.49,color,.40)
		else
			limb(root,"Low bough",V(.09,h*.42,0),V(-w*.24,h*.66,.2),.55,bark)
			canopy(root,"Low canopy",-w*.19,h*.65,.28,w*.66,h*.34,w*.58,color,.08)
			canopy(root,"Main canopy",w*.13,h*.79,-.35,w*.74,h*.34,w*.65,tip,.71)
			canopy(root,"Canopy shadow",w*.23,h*.62,.7,w*.48,h*.26,w*.51,color:Lerp(bark,.19),-.2)
			if form=="Oak" then
				limb(root,"Second fork",V(.1,h*.37,.04),V(w*.31,h*.69,-.55),.85,bark)
				canopy(root,"Broad crown",-w*.24,h*.77,-1.15,w*.64,h*.24,w*.57,color,.9)
			end
		end
	end
	root.WorldPivot=CF()
	root:SetAttribute("LeafColor",spec[4])
	return root
end

function Art.Apply(tree,assets,visuals)
	local id=tree:GetAttribute("TreeType")
	if not recipes[id] then return end
	for _,p in ipairs(tree:GetChildren()) do
		if p.Name=="Trunk" and p:IsA("BasePart") then
			-- Keep the exact original blocker and chopping hitbox.
			p.Transparency=1
		elseif p:IsA("BasePart") and p:GetAttribute("Leaf") then
			p:Destroy()
		end
	end
	local crown=visuals and visuals[id] and visuals[id]:Clone() or Art.Visual(id,assets)
	crown:ScaleTo(tree:GetScale())
	crown:PivotTo(tree:GetPivot())
	crown.Parent=tree
	tree:SetAttribute("Template","TimberArt_"..id)
	tree:SetAttribute("TimberArt",true)
	tree:SetAttribute("LeafColor",recipes[id][4])
end
return Art
