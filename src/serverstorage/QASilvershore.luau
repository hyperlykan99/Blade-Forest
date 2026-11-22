-- Reproducible authoring for the Silvershore Saber replacement in the private editor.
return function()
	local model=Instance.new("Model")
	model.Name="SilvershoreSaber"
	model:SetAttribute("M2",true)
	model:SetAttribute("TemplateLength",4)
	model:SetAttribute("SourceCreator","Blade Forest")
	model:SetAttribute("SourceKind","StudioGeometry")
	model:SetAttribute("SourceTitle","Blade Forest QA original geometry")
	local function add(name,size,frame,color,material,wedge)
		local part=Instance.new(wedge and "WedgePart" or "Part")
		part.Name=name
		part.Size=size
		part.CFrame=frame
		part.Color=color
		part.Material=material
		part.Anchored=true
		part.CanCollide=false
		part.CanTouch=false
		part.CanQuery=false
		part.CastShadow=false
		part.Parent=model
	end
	local silver=Color3.fromRGB(192,216,221)
	local teal=Color3.fromRGB(31,102,118)
	local brass=Color3.fromRGB(220,185,109)
	add("Silver blade",Vector3.new(.42,.12,2.38),CFrame.new(0,0,-.34),silver,Enum.Material.Metal)
	add("Sharpened point",Vector3.new(.42,.12,.46),CFrame.new(0,0,-1.76)*CFrame.Angles(0,math.pi,0),silver,Enum.Material.Metal,true)
	add("Waterline fuller",Vector3.new(.105,.145,2.04),CFrame.new(0,0,-.36),teal,Enum.Material.SmoothPlastic)
	add("Brass guard",Vector3.new(.93,.18,.22),CFrame.new(0,0,.93)*CFrame.Angles(0,.18,0),brass,Enum.Material.Metal)
	add("Sea leather grip",Vector3.new(.22,.19,.71),CFrame.new(0,0,1.43),teal,Enum.Material.SmoothPlastic)
	add("Pommel",Vector3.new(.29,.2,.2),CFrame.new(0,0,1.88),brass,Enum.Material.Metal)
	model.WorldPivot=CFrame.new()
	return model
end
