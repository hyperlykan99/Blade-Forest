-- StoreService: Robux game passes + developer products.
-- IDs live in BladeConfig (Config.GamePasses / Config.DevProducts).
--   * passes are checked on join and applied as Pass_<Id> attributes
--   * every dev product receipt is granted exactly once (saved PurchaseIds)
--   * M0-C: PurchaseGranted is returned only after the grant and its purchase
--     id were written to the DataStore in the SAME atomic save. Purchase ids
--     are kept permanently (no pruning) for deduplication.
--   * VIP gets a gold tag + a free Trait Crate every day

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

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
-- every crate granted here comes from a Robux purchase or a paid pass -> origin "Paid"
local function giveCrates(player, n, why)
	local d = DataService.Get(player)
	if not d then return end
	DataService.AddCrates(player, n, "Paid")
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
	if ok and owns then
		grantProduct(player, sp)
		task.spawn(DataService.SaveNow, player)
	end
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
		if d and not d.StarterPack then
			grantProduct(player, sp)
			task.spawn(DataService.SaveNow, player)
		end
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
		local amt = Config.GetLogPackAmount(p.Id, player) -- M1: progression tier
		DataService.AddCoins(player, amt, nil, true)
		NotifyRemote:FireClient(player, string.format("+%s Logs!", Config.FormatNumber(amt)), "rare_Legendary")
	elseif p.Crates then
		giveCrates(player, p.Crates)
	end
	DataService.Sync(player)
end

--------------------------------------------------------------------
-- Receipts (M0-C)
--   1. Unknown product, player not here, data not loaded, or this server no
--      longer owns the profile -> NotProcessedYet (Roblox retries later, in
--      whichever server the player is in).
--   2. Purchase id already recorded AND durably saved -> PurchaseGranted.
--      Recorded but not yet confirmed (an earlier save failed) -> save again;
--      Granted only if that save is confirmed.
--   3. New receipt: snapshot -> grant + record the purchase id -> SaveNow.
--      If the grant throws, the snapshot is restored (no partial grant).
--      If the save is not confirmed -> NotProcessedYet; the grant and the
--      record stay together in memory, so a retry cannot grant twice.
-- Only receipt fields from Roblox are trusted (ProductId, PurchaseId, PlayerId);
-- nothing comes from the client.
--------------------------------------------------------------------
local ReceiptProcessor = require(script.Parent:WaitForChild("ReceiptProcessor"))
local receipts = ReceiptProcessor.new({
	getPlayer = function(userId) return Players:GetPlayerByUserId(userId) end,
	product = function(productId) return Config.ProductByProductId[productId] end,
	isActive = DataService.IsActive,
	canPersist = DataService.CanPersist,
	getData = DataService.Get,
	grant = function(player, p) grantProduct(player, p) end,
	saveNow = function(player) return DataService.SaveNow(player) end,
	afterRestore = function(player)
		local d = DataService.Get(player)
		local ls = player:FindFirstChild("leaderstats")
		if d and ls then
			if ls:FindFirstChild("Logs") then ls.Logs.Value = d.Logs end
			if ls:FindFirstChild("Souls") then ls.Souls.Value = d.Souls or 0 end
		end
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
	end,
	report = function(player, outcome, key) Analytics.Receipt(player, outcome, key) end,
})

local function processReceipt(receipt)
	local decision, why = receipts.process(receipt)
	if decision ~= Enum.ProductPurchaseDecision.PurchaseGranted then
		warn("[Store] receipt deferred:", why)
	end
	return decision
end

MarketplaceService.ProcessReceipt = processReceipt

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
		-- M0 test: run the real receipt path with a synthetic receipt.
		-- id = { ProductId = number, PurchaseId = string }; returns the decision name
		if kind == "Receipt" and type(id) == "table" then
			local decision = processReceipt({ PlayerId = player.UserId, ProductId = id.ProductId, PurchaseId = id.PurchaseId, CurrencySpent = 0 })
			return decision.Name
		end
		if kind == "Unconfirmed" then return receipts.pending() end
		return false
	end
	bf.Parent = game:GetService("ServerStorage")
end
