local Rules={}
function Rules.Damage(hp,maxHP,phase,damage)
	local floor=phase=="I" and math.floor(maxHP*.67) or phase=="II" and math.floor(maxHP*.31) or 0
	return math.clamp(damage,0,math.max(0,hp-floor))
end
return table.freeze(Rules)
