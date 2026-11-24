local _, KUI = ...
local M = KUI.Market
local UI = M.UI
local Plain, Say = M.Plain, M.Say

local SCAN_TIMEOUT = 5

local function Enum2(t, k, default) return (Enum and Enum[t] and Enum[t][k]) or default end

local RESET = { minPrice = "minPrice", normalPrice = "normalPrice", maxPrice = "maxPrice" }

function M:PostPrice(op, lowest, ours, itemID)
	local function Price(key)
		local v = op[key]
		if type(v) == "string" then
			local copper = M.Prices and M.Prices:Resolve(v, itemID)
			if not copper then return nil, "no " .. v .. " price for it (K-Market Prices app)" end
			return copper
		end
		return tonumber(v) or 0
	end
	local min, why = Price("minPrice")
	if not min then return nil, why end
	local normal, why2 = Price("normalPrice")
	if not normal then return nil, why2 end
	local max, why3 = Price("maxPrice")
	if not max then return nil, why3 end
	local undercut = tonumber(op.undercut) or 0
	local prices = { minPrice = min, normalPrice = normal, maxPrice = max > 0 and max or normal }
	local price, how
	if not lowest then
		if normal <= 0 then return nil, "nobody is selling it and no normal price is set" end
		price, how = normal, "normal price (nobody else selling)"
	elseif lowest - undercut < min then
		local reset = RESET[op.belowMin]
		if not reset then return nil, "the going price is under your minimum" end
		price, how = prices[reset], "below your minimum: " .. reset:gsub("Price", " price")
	elseif ours then
		price, how = lowest, "matching your own lowest auction"
	elseif max > 0 and lowest - undercut > max then
		local reset = RESET[op.aboveMax]
		if not reset then return nil, "the going price is over your maximum" end
		price, how = prices[reset], "above your maximum: " .. reset:gsub("Price", " price")
	else
		price, how = lowest - undercut, "undercutting"
	end
	price = math.max(price, min)
	if price >= 100 then price = math.floor(price / 100) * 100 end
	if price < 100 then return nil, "the price would be under 1 silver" end
	return price, how
end

local function SlotLocation(s)
	return ItemLocation and ItemLocation.CreateFromBagAndSlot and ItemLocation:CreateFromBagAndSlot(s.bag, s.slot)
end

local function SlotWith(itemID)
	local e = M:ScanBags()[itemID]
	return e and e.slots[1]
end

local function KeyFor(itemID, slot)
	local loc = slot and SlotLocation(slot)
	local status = loc and C_AuctionHouse.GetItemCommodityStatus and C_AuctionHouse.GetItemCommodityStatus(loc)
	local commodity = status == Enum2("ItemCommodityStatus", "Commodity", 2)
	local key = (not commodity and loc and C_AuctionHouse.GetItemKeyFromItem and C_AuctionHouse.GetItemKeyFromItem(loc))
		or C_AuctionHouse.MakeItemKey(itemID)
	return commodity, key
end

function M:IsCommodity(itemID)
	local slot = SlotWith(itemID)
	if slot then return (KeyFor(itemID, slot)) end
	local stack = C_Item and C_Item.GetItemMaxStackSizeByID and Plain(C_Item.GetItemMaxStackSizeByID(itemID))
	if type(stack) ~= "number" then stack = Plain(select(8, C_Item.GetItemInfo(itemID))) end
	return type(stack) == "number" and stack > 1
end

local function Search(key)
	local sorts = { { sortOrder = Enum2("AuctionHouseSortOrder", "Price", 0), reverseSort = false } }
	if C_AuctionHouse.SendSellSearchQuery then
		C_AuctionHouse.SendSellSearchQuery(key, sorts, true)
	else
		C_AuctionHouse.SendSearchQuery(key, sorts, true)
	end
end

local function ReadResults(itemID, commodity, key)
	local r = { owned = 0 }
	if commodity then
		local n = Plain(C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID)) or 0
		for i = 1, n do
			local row = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
			local price = row and Plain(row.unitPrice)
			if type(price) == "number" then
				local mine = Plain(row.numOwnerItems) or (Plain(row.containsOwnerItem) and Plain(row.quantity)) or 0
				local qty = Plain(row.quantity) or 0
				if not r.lowest then r.lowest = price; r.ours = mine > 0 end
				if price == r.lowest then r.owned = r.owned + mine end
				if not r.othersLowest and qty > mine then r.othersLowest = price end
			end
		end
	else
		local n = Plain(C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(key)) or 0
		for i = 1, n do
			local row = C_AuctionHouse.GetItemSearchResultInfo(key, i)
			local price = row and Plain(row.buyoutAmount)
			if type(price) == "number" and price > 0 then
				local mine = Plain(row.containsOwnerItem) and true or false
				if not r.lowest then r.lowest = price; r.ours = mine end
				if mine and price == r.lowest then r.owned = r.owned + (Plain(row.quantity) or 1) end
				if not mine and not r.othersLowest then r.othersLowest = price end
			end
		end
	end
	return r
end
M.ReadAuctionResults = ReadResults

local searcher = { queue = {}, current = nil }
M.searcher = searcher

local function NextSearch()
	if searcher.current then return end
	local job = table.remove(searcher.queue, 1)
	if not job then return end
	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		table.insert(searcher.queue, 1, job)
		C_Timer.After(0.25, NextSearch)
		return
	end
	searcher.current = job
	Search(job.key)
	C_Timer.After(SCAN_TIMEOUT, function()
		if searcher.current == job then
			searcher.current = nil
			job.done(ReadResults(job.itemID, job.commodity, job.key), true)
			NextSearch()
		end
	end)
end

local function Queue(job)
	searcher.queue[#searcher.queue + 1] = job
	NextSearch()
end
M.QueueSearch = Queue

local function SameKey(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	return a.itemID == b.itemID and (a.itemLevel or 0) == (b.itemLevel or 0) and (a.itemSuffix or 0) == (b.itemSuffix or 0)
end

local function OnResults(event, arg)
	local job = searcher.current
	if not job then return end
	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		if not job.commodity or (arg ~= nil and arg ~= job.itemID) then return end
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
		if job.commodity or (arg ~= nil and not SameKey(arg, job.key)) then return end
	end
	searcher.current = nil
	job.done(ReadResults(job.itemID, job.commodity, job.key))
	C_Timer.After(0.1, NextSearch)
end

local function ClearSearches()
	wipe(searcher.queue)
	searcher.current = nil
end

local sell
M.sellState = function() return sell end

local function SellFrame()
	local ah = AuctionHouseFrame
	if not ah then return nil end
	for _, key in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
		local f = ah[key]
		if f and f:IsShown() and f.GetItem then
			local loc = f:GetItem()
			if loc and (not loc.IsValid or loc:IsValid()) then return f, loc, key == "CommoditiesSellFrame" end
		end
	end
	return nil
end
M.SellFrame = SellFrame

local function LocItemID(loc)
	if not loc then return nil end
	if C_Item and C_Item.GetItemID then
		local id = Plain(C_Item.GetItemID(loc))
		if id then return id end
	end
	local bag, slot = loc.bagID or loc.bag, loc.slotIndex or loc.slot
	local info = bag and C_Container.GetContainerItemInfo(bag, slot)
	return info and Plain(info.itemID)
end

function M:BuildPostQueue()
	local bags = self:ScanBags()
	local ids = {}
	for id in pairs(bags) do ids[#ids + 1] = id end
	table.sort(ids)
	local entries = {}
	for _, id in ipairs(ids) do
		local path = self:ItemGroup(id)
		local op = path and self:EffectiveOp(path, "post")
		if op then
			local have = bags[id].count - (tonumber(op.keep) or 0)
			if have > 0 then
				entries[#entries + 1] = { itemID = id, op = op, have = have, left = have, state = "todo" }
			end
		end
	end
	return entries
end

function M:DecidePost(e, results)
	local price, how = self:PostPrice(e.op, results.lowest, results.ours, e.itemID)
	if not price then return nil, how end
	local cap = tonumber(e.op.postCap) or 0
	local up = (results.ours and results.lowest and price == results.lowest) and results.owned or 0
	local count = math.min(e.left or e.have, cap - up - (e.posted or 0))
	if count <= 0 then return nil, "you already have " .. (up + (e.posted or 0)) .. " up (post cap " .. cap .. ")" end
	return price, how, count
end

local function EntryFor(itemID)
	if not sell then return nil end
	for _, e in ipairs(sell.entries) do if e.itemID == itemID then return e end end
end

local function StartSell()
	sell = { entries = M:BuildPostQueue(), posted = 0 }
end

local function Track()
	if not sell then StartSell() end
	local frame, loc, commodity = SellFrame()
	if not frame then sell.current = nil; M:RefreshAuctionPanel(); return end
	local id = LocItemID(loc)
	if sell.current and sell.current.itemID == id and sell.current.loc == loc then return end
	local e = EntryFor(id)
	sell.current = { itemID = id, loc = loc, commodity = commodity, entry = e, frame = frame, asked = GetTime() }
	if not e then
		sell.current.ready = true
		if commodity and frame.SetToMaxQuantity then frame:SetToMaxQuantity() end
	end
	M:RefreshAuctionPanel()
	if e then

		C_Timer.After(0.2, function() M:PriceCurrent(false) end)
		local cur = sell.current
		C_Timer.After(SCAN_TIMEOUT, function()
			if sell and sell.current == cur and not cur.ready and not cur.reason then M:PriceCurrent(true) end
		end)
	end
end
M.TrackSellItem = Track

function M:PriceCurrent(timedOut)
	local cur = sell and sell.current
	if not cur or not cur.entry or cur.ready then return end
	local _, loc = SellFrame()
	if loc ~= cur.loc then return end
	local key
	if not cur.commodity and C_AuctionHouse.GetItemKeyFromItem then
		local ok, k = pcall(C_AuctionHouse.GetItemKeyFromItem, cur.loc)
		key = ok and k or nil
	end
	key = key or C_AuctionHouse.MakeItemKey(cur.itemID)
	local results = ReadResults(cur.itemID, cur.commodity, key)
	if not results.lowest and not timedOut then return end
	local price, how, count = self:DecidePost(cur.entry, results)
	if not price then
		cur.reason = how
		cur.entry.state, cur.entry.reason = "skip", how
	else
		cur.ready, cur.price, cur.count, cur.how = true, price, count, how
		cur.entry.price, cur.entry.reason = price, how
		self:FillSellFrame()
	end
	self:RefreshAuctionPanel()
end

function M:FillSellFrame()
	local cur = sell and sell.current
	if not cur or not cur.price then return end
	local f = cur.frame
	if f.PriceInput and f.PriceInput.SetAmount then f.PriceInput:SetAmount(cur.price) end
	local max = f.GetMaxQuantity and f:GetMaxQuantity() or cur.count
	local count = math.min(cur.count, max or cur.count)
	if f.QuantityInput and f.QuantityInput.SetQuantity then f.QuantityInput:SetQuantity(count) end
	cur.count = count
	local d = tonumber(cur.entry.op.duration)
	if d and f.Duration and f.Duration.SetDuration and f.Duration.GetDuration and f.Duration:GetDuration() ~= d then f.Duration:SetDuration(d) end
	if f.UpdatePostState then f:UpdatePostState() end
end

local function WarningShown()
	return StaticPopup_Visible and StaticPopup_Visible("AUCTION_HOUSE_POST_WARNING")
end

function M:LoadNextSell(fromEntry)
	if not sell then StartSell() end
	if not AuctionHouseFrame or not AuctionHouseFrame.SetPostItem then return false end
	local bags = self:ScanBags()
	for _, e in ipairs(sell.entries) do
		if (fromEntry == nil or e == fromEntry) and (e.state == "todo" or (fromEntry and e.state == "skip")) and e.left > 0 then
			local b = bags[e.itemID]
			local s = b and b.slots[1]
			if s then
				if e.state == "skip" then e.state, e.reason = "todo", nil end
				local loc = SlotLocation(s)
				if loc then AuctionHouseFrame:SetPostItem(loc); Track(); return true end
			else
				e.state, e.reason = "done", nil
			end
		end
	end
	self:RefreshAuctionPanel()
	return false
end

function M:PostClick()
	if InCombatLockdown() then Say("not in combat."); return end
	if WarningShown() then
		local ah = AuctionHouseFrame
		if not (ah.CommoditiesSellFrame and ah.CommoditiesSellFrame:ConfirmPost()) and ah.ItemSellFrame then ah.ItemSellFrame:ConfirmPost() end
		StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING")
		self:RefreshAuctionPanel()
		return
	end
	if not sell then StartSell() end
	Track()
	local cur = sell.current
	if not cur then
		if not self:LoadNextSell() then Say("right-click an item in your bags to put it in the Sell tab.") end
		return
	end
	if not cur.ready then
		if cur.reason then self:SkipPost() end
		return
	end
	if cur.entry then self:FillSellFrame() end
	local f = cur.frame
	local ok, why = true, nil
	if f.CanPostItem then ok, why = f:CanPostItem() end
	if not ok then
		Say("the game won't list it yet" .. (type(why) == "string" and (": " .. why) or "") .. ".")
		return
	end
	local count = (f.GetQuantity and f:GetQuantity()) or cur.count or 1
	cur.posting = true
	f:PostItem()
	sell.posted = sell.posted + 1
	if cur.entry then
		cur.entry.left = cur.entry.left - count
		cur.entry.posted = (cur.entry.posted or 0) + count
		if cur.entry.left <= 0 then cur.entry.state = "done" end
	end
	self:RefreshAuctionPanel()
end

function M:OnAuctionCreated()
	local cur = sell and sell.current
	if not cur or not cur.posting then return end
	local function Next()
		if not sell or sell.current ~= cur then return end

		if AuctionHouseMultisellProgressFrame and AuctionHouseMultisellProgressFrame:IsShown() then C_Timer.After(0.3, Next); return end
		sell.current = nil
		local e = cur.entry
		if e and e.state ~= "done" and e.left > 0 then
			if M:LoadNextSell(e) then return end
		end
		M:LoadNextSell()
		M:RefreshAuctionPanel()
	end
	C_Timer.After(0.3, Next)
end

function M:SkipPost()
	local cur = sell and sell.current
	if cur and cur.entry and cur.entry.state ~= "done" then
		cur.entry.state = "skip"
		cur.entry.reason = cur.entry.reason or "skipped"
	end
	if sell then sell.current = nil end
	if AuctionHouseFrame and AuctionHouseFrame.ClearPostItem then AuctionHouseFrame:ClearPostItem() end
	self:LoadNextSell()
	self:RefreshAuctionPanel()
end

local cancel
M.cancelState = function() return cancel end

function M:StopCancelScan()
	cancel = nil
end

function M:StartCancelScan()
	if InCombatLockdown() then Say("not in combat."); return end
	if not (C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions) then Say("the auction house can't be read."); return end
	ClearSearches()
	cancel = { waitingOwned = true, entries = {} }
	C_AuctionHouse.QueryOwnedAuctions({ { sortOrder = Enum2("AuctionHouseSortOrder", "Name", 1), reverseSort = false } })
	local run = cancel
	C_Timer.After(SCAN_TIMEOUT, function()
		if cancel == run and cancel.waitingOwned then M:OnOwnedAuctions() end
	end)
	self:RefreshAuctionPanel()
end

function M:OnOwnedAuctions()
	if not cancel or not cancel.waitingOwned then return end
	cancel.waitingOwned = false
	local byItem = {}
	local n = Plain(C_AuctionHouse.GetNumOwnedAuctions()) or 0
	for i = 1, n do
		local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
		local key = info and info.itemKey
		local id = key and Plain(key.itemID)
		local status, price = info and Plain(info.status), info and Plain(info.buyoutAmount)
		if id and status == 0 and type(price) == "number" then
			local path = self:ItemGroup(id)
			local op = path and self:EffectiveOp(path, "post")
			if op and op.cancelUndercut then
				local e = { auctionID = Plain(info.auctionID), itemID = id, price = price, quantity = Plain(info.quantity) or 1, op = op, state = "scanning" }
				cancel.entries[#cancel.entries + 1] = e
				local list = byItem[id]
				if not list then
					list = {}
					byItem[id] = list
					list.commodity = M:IsCommodity(id)
					list.key = key
				end
				list[#list + 1] = e
			end
		end
	end
	local run = cancel
	for id, list in pairs(byItem) do
		local commodity = list.commodity
		Queue({ itemID = id, commodity = commodity, key = commodity and C_AuctionHouse.MakeItemKey(id) or list.key, done = function(results)
			if cancel ~= run then return end
			for _, e in ipairs(list) do
				local others = results.othersLowest
				local undercut = tonumber(e.op.undercut) or 0
				if others and others < e.price and others - undercut >= (tonumber(e.op.minPrice) or 0) then
					e.state, e.reason = "ready", "undercut: lowest is " .. M.ShortMoney(others)
				else
					e.state = "fine"
				end
			end
			M:RefreshAuctionPanel()
		end })
	end
	if #cancel.entries == 0 then Say("none of your auctions are in a group whose Auctioning operation cancels undercut auctions.") end
	self:RefreshAuctionPanel()
end

function M:CancelClick()
	if InCombatLockdown() then Say("not in combat."); return end
	if not cancel then return end
	for _, e in ipairs(cancel.entries) do
		if e.state == "ready" then
			C_AuctionHouse.CancelAuction(e.auctionID)
			e.state = "done"
			break
		end
		if e.state == "scanning" then break end
	end
	self:RefreshAuctionPanel()
end

function M:SkipCancel()
	if not cancel then return end
	for _, e in ipairs(cancel.entries) do
		if e.state == "ready" then e.state = "skip"; break end
	end
	self:RefreshAuctionPanel()
end

local panel
local STATE_TEXT = { scanning = "scanning...", ready = nil, skip = nil, done = "listed", fine = "not undercut" }

function M:RefreshAuctionPanel()
	if not panel or not panel:IsShown() then return end
	local rows = {}
	local action, enabled, status
	if cancel then
		for _, e in ipairs(cancel.entries) do rows[#rows + 1] = e end
		local ready, scanning = 0, 0
		for _, e in ipairs(cancel.entries) do
			if e.state == "ready" then ready = ready + 1 elseif e.state == "scanning" then scanning = scanning + 1 end
		end
		action, enabled = "Cancel Auction", ready > 0
		status = cancel.waitingOwned and "Reading your auctions..." or scanning > 0 and string.format("Scanning: %d to go.", scanning)
			or string.format("%d undercut auction(s) to cancel.", ready)
		panel.mode = "cancel"
	else
		panel.mode = "sell"
		if not sell then StartSell() end
		for _, e in ipairs(sell.entries) do rows[#rows + 1] = e end
		local cur = sell.current
		local todo = 0
		for _, e in ipairs(sell.entries) do if e.state == "todo" and e.left > 0 then todo = todo + 1 end end
		if WarningShown() then
			action, enabled = "Confirm Post", true
		elseif cur and cur.ready then
			local f = cur.frame
			local price = cur.price or (f.PriceInput and f.PriceInput.GetAmount and f.PriceInput:GetAmount())
			local count = cur.count or (f.GetQuantity and f:GetQuantity()) or 1
			action = "Post " .. (price and price > 0 and M.ShortMoney(price) or "") .. " x" .. count
			enabled = true
		elseif cur and cur.reason then
			action, enabled = "Skip", true
		elseif cur then
			action, enabled = "Checking prices...", false
		elseif todo > 0 then
			action, enabled = "Load Next", true
		else
			action, enabled = "Right-click an item", false
		end
		if cur and cur.reason then
			status = M.ItemName(cur.itemID) .. ": " .. cur.reason
		elseif cur and cur.entry then
			status = M.ItemName(cur.itemID) .. ": " .. (cur.how or "checking the price")
		elseif cur then
			status = M.ItemName(cur.itemID) .. ": the Sell tab's price (not in an Auctioning group)"
		else
			status = string.format("%d listed. %d item(s) from your groups to go.", sell.posted, todo)
		end
	end
	UI.ButtonText(panel.action, action)
	panel.action:SetKMEnabled(enabled)
	panel.skip:SetKMEnabled(panel.mode == "cancel" and enabled or (panel.mode == "sell" and sell and sell.current ~= nil))
	panel.status:SetText(status)
	panel.list:SetItems(rows)
	panel.empty:SetShown(#rows == 0)
end

function M:BuildAuctionPanel()
	if panel or not AuctionHouseFrame then return end
	panel = UI.Panel(AuctionHouseFrame, "surface", 6)
	panel:SetSize(300, AuctionHouseFrame:GetHeight() or 538)
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
	panel:EnableMouse(true)
	local title = UI.Text(panel, "body/bold/small", "accent")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("K-Market")
	panel.action = UI.Button(panel, "Post", 200, 28, "primary", "KainUIForeverMarketPostButton")
	panel.action:SetPoint("TOPLEFT", 12, -32)
	panel.action.kmTip = "Lists the item in the Sell tab (one click a listing), then loads the next item from your Auctioning groups. Right-click any bag item to sell it instead."
	panel.action:SetScript("OnClick", function()
		if panel.mode == "cancel" then M:CancelClick() else M:PostClick() end
	end)
	panel.skip = UI.Button(panel, "Skip", 68, 28, "secondary", "KainUIForeverMarketSkipButton")
	panel.skip:SetPoint("TOPRIGHT", -12, -32)
	panel.skip:SetScript("OnClick", function()
		if panel.mode == "cancel" then M:SkipCancel() else M:SkipPost() end
	end)
	panel.cancelScan = UI.Button(panel, "Cancel Scan", 134, 22, "secondary", "KainUIForeverMarketCancelScanButton")
	panel.cancelScan:SetPoint("TOPLEFT", 12, -66)
	panel.cancelScan:SetScript("OnClick", function()
		if cancel then cancel = nil; M:RefreshAuctionPanel() else M:StartCancelScan() end
	end)
	panel.status = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.status:SetPoint("TOPLEFT", 12, -98)
	panel.status:SetPoint("RIGHT", -12, 0)
	panel.empty = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.empty:SetPoint("TOPLEFT", 12, -124)
	panel.empty:SetWidth(276)
	panel.empty:SetWordWrap(true)
	panel.empty:SetText("Right-click an item in your bags to put it in the Sell tab, then press Post. Items in a group with an Auctioning operation are listed here and go in one after another. Cancel Scan finds your auctions someone has undercut.")
	panel.list = UI.List(panel, 34, 12, function(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(24, 24)
		row.icon:SetPoint("LEFT", 10, 0)
		row.name = UI.Text(row, "body/regular/x-small", "text")
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
		row.name:SetPoint("RIGHT", -90, 0)
		row.note = UI.Text(row, "body/regular/x-small", "textLow")
		row.note:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
		row.note:SetPoint("RIGHT", -10, 0)
		row.price = UI.Text(row, "numeric/regular/x-small", "accent", "RIGHT")
		row.price:SetPoint("TOPRIGHT", -10, -4)
		row:SetScript("OnClick", function(clicked)
			if panel.mode == "sell" and clicked.kmItem and clicked.kmItem.op then M:LoadNextSell(clicked.kmItem) end
		end)
	end, function(row, e)
		row.icon:SetTexture(M.ItemIcon(e.itemID))
		local qty = e.left or e.have or e.quantity
		row.name:SetText(M.ItemName(e.itemID) .. (qty and ("  x" .. qty) or ""))
		row.price:SetText(e.price and M.ShortMoney(e.price) or "")
		local note = STATE_TEXT[e.state] or e.reason or ""
		if e.op and e.state == "todo" then note = (sell and sell.current and sell.current.entry == e) and "in the Sell tab" or "click to load" end
		row.note:SetText(note)
		UI.TextColor(row.note, e.state == "skip" and "error" or e.state == "ready" and "positive" or "textLow")
		row:SetAlpha((e.state == "done" or e.state == "skip" or e.state == "fine") and 0.55 or 1)
	end)
	panel.list:SetPoint("TOPLEFT", 0, -118)
	panel.list:SetPoint("TOPRIGHT", 0, -118)
	panel.list:SetHeight(34 * 12)
	panel:SetScript("OnShow", function() M:RefreshAuctionPanel() end)
	M.auctionPanel = panel

	if AuctionHouseFrame.SetPostItem and hooksecurefunc then
		hooksecurefunc(AuctionHouseFrame, "SetPostItem", function()
			cancel = nil
			C_Timer.After(0, Track)
		end)
	end
	if AuctionHouseFrame.ClearPostItem and hooksecurefunc then
		hooksecurefunc(AuctionHouseFrame, "ClearPostItem", function()
			C_Timer.After(0, function() if sell and sell.current and not SellFrame() then sell.current = nil; M:RefreshAuctionPanel() end end)
		end)
	end
	self:RefreshAuctionPanel()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"AUCTION_HOUSE_POST_WARNING", "OWNED_AUCTIONS_UPDATED", "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "AUCTION_HOUSE_SHOW" then
		local function Show()
			M:BuildAuctionPanel()
			StartSell()
			if panel then panel:Show(); M:RefreshAuctionPanel() end
		end
		if AuctionHouseFrame then Show() else C_Timer.After(0.1, Show) end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		sell, cancel = nil, nil
		ClearSearches()
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
		OnResults(event, arg)
		local cur = sell and sell.current
		if cur and cur.entry and not cur.ready then C_Timer.After(0, function() M:PriceCurrent(false) end) end
	elseif event == "AUCTION_HOUSE_POST_WARNING" then
		C_Timer.After(0, function() M:RefreshAuctionPanel() end)
	elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
		M:OnAuctionCreated()
	elseif event == "OWNED_AUCTIONS_UPDATED" then
		M:OnOwnedAuctions()
	end
end)
