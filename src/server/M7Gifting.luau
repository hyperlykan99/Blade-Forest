-- Future gift receipts share the M0 processor and confirmed buyer profile writer.
-- A supported product requires its own allow-listed developer product ID.
local Policy=game:GetService("PolicyService")
local Flags=require(script.Parent:WaitForChild("M7Flags"))
local Receipts=require(script.Parent:WaitForChild("ReceiptProcessor"))
local G={}
local supported=table.freeze({})

function G.CanOffer(productId)
	return Flags.PaidGifting and supported[productId]~=nil
end
function G.StageIntent(buyer,recipient,productId,data,save)
	if not G.CanOffer(productId) or buyer==recipient or not buyer.Parent or not recipient.Parent then return false end
	for _,p in ipairs({buyer,recipient}) do
		local ok,info=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,p)
		if not ok or type(info)~="table" or info.IsPaidItemTradingAllowed~=true then return false end
	end
	if not buyer.Parent or not recipient.Parent or buyer:GetAttribute("Handoff")
		or data.M7.Gifting.Intent then return false end
	data.M7.Gifting.Intent={Product=productId,Buyer=buyer.UserId,Recipient=recipient.UserId,At=os.time()}
	return save(buyer)==true
end
function G.ValidateIntent(intent,receipt,buyer)
	if not G.CanOffer(receipt.ProductId) or not intent then return nil end
	if intent.Product~=receipt.ProductId or intent.Buyer~=receipt.PlayerId or intent.Buyer~=buyer.UserId
		or type(intent.Recipient)~="number" or intent.Recipient==intent.Buyer
		or type(receipt.PurchaseId)~="string" or receipt.PurchaseId=="" then return nil end
	return {Receipt=receipt.PurchaseId,Product=intent.Product,Recipient=intent.Recipient,Buyer=intent.Buyer,State="PendingDelivery"}
end
function G.New(deps)
	return function(receipt)
		if not G.CanOffer(receipt.ProductId) then return nil end
		local buyer=deps.getPlayer(receipt.PlayerId)
		local profile=buyer and deps.getData(buyer)
		if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet,"gift_buyer_unavailable" end
		local key=receipt.PurchaseId
		local pending=type(key)=="string" and profile.M7.Gifting.Outbox[key]
		local record=pending or G.ValidateIntent(profile.M7.Gifting.Intent,receipt,buyer)
		if not record or record.Buyer~=receipt.PlayerId or record.Product~=receipt.ProductId then
			return Enum.ProductPurchaseDecision.NotProcessedYet,"gift_intent_missing"
		end
		-- A single long-lived M0 processor retains unconfirmed receipt state.
		return deps.processor.process(receipt)
	end
end
function G.Processor(deps)
	local adapter=table.clone(deps)
	adapter.product=function(id) return G.CanOffer(id) and {Id=id} or nil end
	adapter.grant=function(p,product)
		local data=deps.getData(p)
		local intent=data.M7.Gifting.Intent
		local receipt=deps.current[p]
		local record=G.ValidateIntent(intent,receipt,p)
		assert(record and product.Id==record.Product,"Gift receipt consent mismatch")
		data.M7.Gifting.Outbox[record.Receipt]=record
		data.M7.Gifting.Intent=nil
	end
	return Receipts.new(adapter)
end
return G
