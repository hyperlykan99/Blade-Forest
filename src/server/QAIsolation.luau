-- Test profiles use a separate namespace only in Studio for the authorized development place.
local enabled=game:GetService("RunService"):IsStudio()
	and game.PlaceId==103379930563763 and game.GameId==10777797608
	and workspace:GetAttribute("BladeForestQAProfile")==true
local QA={Enabled=enabled}
function QA.StoreName(name)
	if enabled then return "BF_QA1_"..name end
	return name
end
return table.freeze(QA)
