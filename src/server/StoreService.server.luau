-- StoreService: Robux game passes + developer products.
-- IDs live in BladeConfig (Config.GamePasses / Config.DevProducts).
--   * passes are checked on join and applied as Pass_<Id> attributes
--   * every dev product receipt is granted exactly once (saved PurchaseIds)
--   * VIP gets a gold tag + a free Trait Crate every day

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))

local F = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 205, 60)

local function waitLoaded(player)
	while player.Parent and not player:GetAttribute("Loaded") do task.wait(0.2) end
	return player.Parent ~= nil
end

--------------------------------------------------------------------
-- VIP tag (inside the Overhead billboard made by PvPService)
--------------------------------------------------------------------
local function refreshVipTag(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local bb = head and head:WaitForChild("Overhead", 5)
	if not bb then return end
	local tag = bb:FindFirstChild("VIPTag")
	if not player:GetAttribute("Pass_VIP") then
		if tag then tag:Destroy() end
		return
	end
	if tag then return end
	tag = Instance.new("TextLabel")
	tag.Name = "VIPTag"
	tag.LayoutOrder = 0
	tag.Size = UDim2.new(0, 60, 0, 22)
	tag.BackgroundColor3 = Color3.fromRGB(70, 50, 10)
	tag.BackgroundTransparency = 0.1
	tag.Font = F
	tag.TextScaled = true
	tag.TextColor3 = GOLD
	tag.Text = "VIP"
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = tag
	local s = Instance.new("UIStroke") s.Color = GOLD s.Thickness = 2 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = tag
	tag.Parent = bb
end

--------------------------------------------------------------------
-- Free crates / VIP daily
--------------------------------------------------------------------
local function giveCrates(player, n, why)
	local d = DataService.Get(player)
	if not d then return end
	d.FreeCrates = (d.FreeCrates or 0) + n
	DataService.Sync(player)
	NotifyRemote:FireClient(player, string.format("+%d free Trait Crate%s%s! Open them at TRAITS", n, n == 1 and "" or "s", why and (" (" .. why .. ")") or ""), "rare_Epic")
end

local function checkVipDaily(player)
	if not player:GetAttribute("Pass_VIP") then return end
	local d = DataService.Get(player)
	if not d then return end
	if os.time() - (d.LastVipCrate or 0) >= Config.VIPDailyCrateHours * 3600 then
		d.LastVipCrate = os.time()
		giveCrates(player, 1, "VIP daily")
	end
end

--------------------------------------------------------------------
-- Passes
--------------------------------------------------------------------
local function applyPass(player, passKey)
	if player:GetAttribute("Pass_" .. passKey) then return end
	player:SetAttribute("Pass_" .. passKey, true)
	if passKey == "BladeSlot" then
		player:SetAttribute("BonusBlades", (player:GetAttribute("BonusBlades") or 0) + 1)
	elseif passKey == "VIP" then
		task.spawn(refreshVipTag, player)
		checkVipDaily(player)
	end
	DataService.RecalcMultipliers(player)
end

local grantProduct -- forward (Starter Pack is a pass but grants like a product)

local function checkStarterPass(player)
	local sp = Config.ProductById.StarterPack
	local d = DataService.Get(player)
	if not sp.PassId or sp.PassId == 0 or not d or d.StarterPack then return end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, sp.PassId)
	if ok and owns then grantProduct(player, sp) end
end

local function checkPasses(player)
	for _, p in ipairs(Config.GamePasses) do
		if p.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.PassId)
			if ok and owns then applyPass(player, p.Id) end
		end
	end
	checkStarterPass(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	local sp = Config.ProductById.StarterPack
	if sp.PassId == passId then
		local d = DataService.Get(player)
		if d and not d.StarterPack then grantProduct(player, sp) end
		return
	end
	for _, p in ipairs(Config.GamePasses) do
		if p.PassId == passId then
			applyPass(player, p.Id)
			NotifyRemote:FireClient(player, "Thanks for buying " .. p.Name .. "!", "rare_Legendary")
		end
	end
end)

--------------------------------------------------------------------
-- Developer products
--------------------------------------------------------------------
function grantProduct(player, p)
	local d = DataService.Get(player)
	if p.Id == "StarterPack" then
		local b = Config.StarterPackBonus
		if not d.Weapons[b.Weapon] then DataService.AddWeapon(player, b.Weapon) end
		d.StarterPack = true
		DataService.AddBoost(player, b.Boost, b.Seconds)
		giveCrates(player, b.Crates, "Starter Pack")
		NotifyRemote:FireAllClients(player.DisplayName .. " got the Starter Pack and the Founder's Edge!", "rare_Epic")
	elseif p.Boost then
		DataService.AddBoost(player, p.Boost, p.Seconds)
		NotifyRemote:FireClient(player, string.format("%s active for %d min!", p.Name, p.Seconds // 60), "rare_Epic")
	elseif p.PackMult then
		local amt = Config.GetLogPackAmount(p.Id, d.BestArea)
		DataService.AddCoins(player, amt, nil, true)
		NotifyRemote:FireClient(player, string.format("+%s Logs!", Config.FormatNumber(amt)), "rare_Legendary")
	elseif p.Crates then
		giveCrates(player, p.Crates)
	end
	DataService.Sync(player)
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not player:GetAttribute("Loaded") then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataService.Get(player)
	local p = Config.ProductByProductId[receipt.ProductId]
	if not d or not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	d.Purchases = d.Purchases or {}
	if d.Purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end
	local ok, err = pcall(grantProduct, player, p)
	if not ok then
		warn("[Store] grant failed:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	d.Purchases[receipt.PurchaseId] = true
	pcall(DataService.Save, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------
-- Join / respawn
--------------------------------------------------------------------
local function onPlayer(player)
	player.CharacterAdded:Connect(function()
		if player:GetAttribute("Pass_VIP") then task.spawn(refreshVipTag, player) end
	end)
	task.spawn(function()
		if not waitLoaded(player) then return end
		checkPasses(player)
		checkVipDaily(player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- VIP daily crate for long sessions
task.spawn(function()
	while true do
		task.wait(300)
		for _, p in ipairs(Players:GetPlayers()) do checkVipDaily(p) end
	end
end)

-- Studio-only test hook: ServerStorage.DevStore:Invoke(player, "Pass"|"Product", id)
if RunService:IsStudio() then
	local bf = game:GetService("ServerStorage"):FindFirstChild("DevStore") or Instance.new("BindableFunction")
	bf.Name = "DevStore"
	bf.OnInvoke = function(player, kind, id)
		if kind == "Pass" then applyPass(player, id) return true end
		if kind == "Product" then
			local p = Config.ProductById[id]
			if p then grantProduct(player, p) return true end
		end
		return false
	end
	bf.Parent = game:GetService("ServerStorage")
end
