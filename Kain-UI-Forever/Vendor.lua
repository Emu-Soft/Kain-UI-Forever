local _, KUI = ...

local NUM_BAGS = 4

local function GetNumBagSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
		if ok then return n end
	end
	if GetContainerNumSlots then
		local ok, n = pcall(GetContainerNumSlots, bag)
		if ok then return n end
	end
	return 0
end

local function GetBagItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and info then
			return {
				hyperlink = info.hyperlink or info.itemLink,
				quality = info.quality,
				stackCount = info.stackCount,
			}
		end
	end
	if GetContainerItemInfo then
		local ok, _, itemCount, _, quality, _, _, itemLink =
			pcall(GetContainerItemInfo, bag, slot)
		if ok and itemLink then
			return { hyperlink = itemLink, quality = quality, stackCount = itemCount }
		end
	end
	return nil
end

local function SellBagItem(bag, slot)
	if C_Container and C_Container.UseContainerItem then
		local ok = pcall(C_Container.UseContainerItem, bag, slot)
		return ok
	end
	if UseContainerItem then
		local ok = pcall(UseContainerItem, bag, slot)
		return ok
	end
	return false
end

local function ResolveItemID(hyperlink)
	if not hyperlink then return nil end
	local itemID = hyperlink:match("item:(%d+)")
	return itemID and tonumber(itemID) or nil
end

local function GetQualityAndSellPrice(info)
	if not info then return nil, nil end
	local quality = info.quality
	local sellPrice
	local itemID = ResolveItemID(info.hyperlink)
	if itemID and GetItemInfo then
		local ok, _, _, q, _, _, _, _, _, _, price = pcall(GetItemInfo, itemID)
		if ok then
			if quality == nil then quality = q end
			sellPrice = price
		end
	end
	return quality, sellPrice
end

local function IsGreyAndSellable(quality, sellPrice)
	if quality ~= 0 then return false end
	if sellPrice ~= nil and sellPrice <= 0 then return false end
	return true
end

local function SellAllGreyItems()

	for bag = 0, NUM_BAGS do
		local numSlots = GetNumBagSlots(bag)
		for slot = 1, numSlots do
			local info = GetBagItemInfo(bag, slot)
			if info and info.hyperlink then
				local quality, sellPrice = GetQualityAndSellPrice(info)
				if IsGreyAndSellable(quality, sellPrice) then
					SellBagItem(bag, slot)
				end
			end
		end
	end
end

function KUI:ApplyAutoSellGreys()
end

function KUI:SetAutoSellGreys(enabled)
	if not KUI.db then return end
	KUI.db.autoSellGreys = enabled and true or false
end

local function RepairEverything()
	if not (CanMerchantRepair and CanMerchantRepair()) then return end

	local cost
	if GetRepairAllCost then
		local ok, totalCost = pcall(GetRepairAllCost)
		if ok and type(totalCost) == "number" then cost = totalCost end
	end

	local useGuildFunds = false
	if KUI.db.autoRepairUseGuildFunds and CanGuildBankRepair then
		local ok, canGuildRepair = pcall(CanGuildBankRepair)
		if ok and canGuildRepair then useGuildFunds = true end
	end

	if cost and cost > 0 and GetCoinTextureString then
		print("You spent: " .. GetCoinTextureString(cost) .. " on repairs")
	end

	if RepairAllItems then
		pcall(RepairAllItems, useGuildFunds)
	end
end

function KUI:ApplyAutoRepair()
end

function KUI:SetAutoRepair(enabled)
	if not KUI.db then return end
	KUI.db.autoRepair = enabled and true or false
end

function KUI:SetAutoRepairUseGuildFunds(enabled)
	if not KUI.db then return end
	KUI.db.autoRepairUseGuildFunds = enabled and true or false
end

local vendorEventFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(vendorEventFrame, "MERCHANT_SHOW")
vendorEventFrame:SetScript("OnEvent", function(self, event)
	if event ~= "MERCHANT_SHOW" then return end
	if not KUI.db then return end
	if KUI.db.autoRepair then RepairEverything() end
	if KUI.db.autoSellGreys then SellAllGreyItems() end
end)

function KUI:VendorScanReport()
	print("|cff33ff99Kain-UI Forever|r vendor auto-sell diagnostics:")
	print("  C_Container available: " .. tostring(C_Container ~= nil))
	print("  C_Container.GetContainerItemInfo: " .. tostring(C_Container and C_Container.GetContainerItemInfo ~= nil))
	print("  C_Container.UseContainerItem: " .. tostring(C_Container and C_Container.UseContainerItem ~= nil))
	print("  legacy GetContainerNumSlots global: " .. tostring(GetContainerNumSlots ~= nil))
	print("  legacy GetContainerItemInfo global: " .. tostring(GetContainerItemInfo ~= nil))

	local foundAny = false
	for bag = 0, NUM_BAGS do
		local numSlots = GetNumBagSlots(bag)
		for slot = 1, numSlots do
			local info = GetBagItemInfo(bag, slot)
			if info and info.hyperlink then
				local quality, sellPrice = GetQualityAndSellPrice(info)
				if quality == 0 then
					foundAny = true
					print(("  bag %d slot %d: %s -- quality=%s sellPrice=%s stackCount=%s (would sell: %s)"):format(
						bag, slot, info.hyperlink, tostring(quality), tostring(sellPrice),
						tostring(info.stackCount), tostring(IsGreyAndSellable(quality, sellPrice))))
				end
			end
		end
	end
	if not foundAny then
		print("  No grey-quality items currently in bags 0-" .. NUM_BAGS .. " -- pick up some vendor trash and try again.")
	end
end
