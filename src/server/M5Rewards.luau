local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Data=require(script.Parent:WaitForChild("DataService"))
local E=require(ReplicatedStorage:WaitForChild("Economy"))
local Notify=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
local C=require(ReplicatedStorage:WaitForChild("BladeConfig"))
local R={}
function R.Grant(player,d,plan,title,priceTier)
	local tier=priceTier and E.Config.PriceTiers[priceTier]
	local amount=E.M5Reward(tier and tier.Unit or Data.PriceUnit(player),plan)
	if amount.Logs>0 then Data.AddCoins(player,amount.Logs,nil,true) end
	if amount.Souls>0 then Data.AddSouls(player,amount.Souls) end
	if amount.XP>0 then Data.AddMasteryXP(player,amount.XP) end
	if amount.Materials>0 and type(plan.Material)=="string" then
		local bag=d.M5.Materials
		bag[plan.Material]=(bag[plan.Material] or 0)+amount.Materials
	end
	Data.Sync(player)
	if title then
		local show={}
		if amount.Logs>0 then table.insert(show,C.FormatNumber(amount.Logs).." Logs") end
		if amount.Souls>0 then table.insert(show,amount.Souls.." Souls") end
		if amount.XP>0 then table.insert(show,amount.XP.." Mastery XP") end
		if amount.Materials>0 then table.insert(show,amount.Materials.." "..(plan.Material or "Materials")) end
		local text=#show>0 and title.."  •  "..table.concat(show,"  ·  ") or title
		Notify:FireClient(player,text,"rare_Epic")
	end
	return amount
end
return R
