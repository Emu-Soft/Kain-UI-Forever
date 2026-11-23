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

local post
M.postState = function() return post end

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
				local commodity, key = KeyFor(id, bags[id].slots[1])
				entries[#entries + 1] = { itemID = id, op = op, have = have, commodity = commodity, key = key, state = "scanning" }
			end
		end
	end
	return entries
end

function M:DecidePost(e, results)
	local price, how = self:PostPrice(e.op, results.lowest, results.ours, e.itemID)
	if not price then e.state, e.reason = "skip", how; return end
	local cap = tonumber(e.op.postCap) or 0
	local up = (results.ours and results.lowest and price == results.lowest) and results.owned or 0
	local count = math.min(e.have, cap - up)
	if count <= 0 then
		e.state, e.reason = "skip", "you already have " .. up .. " up (post cap " .. cap .. ")"
		return
	end
	e.state, e.price, e.left, e.reason = "ready", price, count, how
	e.lowest = results.lowest
end

local function FirstReady()
	if not post then return nil end
	for _, e in ipairs(post.entries) do
		if e.state == "ready" then return e end
		if e.state == "scanning" then return nil end
	end
end

function M:StartPostScan()
	if InCombatLockdown() then Say("not in combat."); return end
	if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then Say("the auction house can't be read."); return end
	self:StopCancelScan()
	ClearSearches()
	local entries = self:BuildPostQueue()
	if #entries == 0 then
		Say("nothing to post: no item in your bags is in a group with an Auctioning operation (above its Keep amount).")
		post = nil
		self:RefreshAuctionPanel()
		return
	end
	post = { entries = entries, posted = 0 }
	local run = post
	for _, e in ipairs(entries) do
		Queue({ itemID = e.itemID, commodity = e.commodity, key = e.key, done = function(results)
			if post ~= run then return end
			M:DecidePost(e, results)
			M:RefreshAuctionPanel()
		end })
	end
	self:RefreshAuctionPanel()
end

function M:PostClick()
	if InCombatLockdown() then Say("not in combat."); return end
	if not post then return end
	if post.pending then
		local p = post.pending
		post.pending = nil
		if p.commodity then C_AuctionHouse.ConfirmPostCommodity(unpack(p.args, 1, 4)) else C_AuctionHouse.ConfirmPostItem(unpack(p.args, 1, 5)) end
		self:RefreshAuctionPanel()
		return
	end
	local e = FirstReady()
	if not e then return end
	local slot = SlotWith(e.itemID)
	if not slot then Say(M.ItemName(e.itemID) .. " isn't ready in your bags yet; try again in a moment."); return end
	local loc = SlotLocation(slot)
	local duration = tonumber(e.op.duration) or 2
	local args, ok, amount
	if e.commodity then
		amount = e.left
		args = { loc, duration, amount, e.price }
		ok = C_AuctionHouse.PostCommodity(loc, duration, amount, e.price)
	else
		amount = 1
		args = { loc, duration, 1, nil, e.price }
		ok = C_AuctionHouse.PostItem(loc, duration, 1, nil, e.price)
	end
	if ok == false then
		e.state, e.reason = "skip", "the game wouldn't post it"
	else
		post.posted = post.posted + 1
		post.last = { commodity = e.commodity, args = args }
		e.left = e.left - amount
		e.posted = (e.posted or 0) + amount
		if e.left <= 0 then e.state = "done" end
	end
	self:RefreshAuctionPanel()
end

function M:SkipPost()
	local e = FirstReady()
	if e then e.state, e.reason = "skip", "skipped" end
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
	post = nil
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
local STATE_TEXT = { scanning = "scanning...", ready = nil, skip = nil, done = "done", fine = "not undercut" }

function M:RefreshAuctionPanel()
	if not panel or not panel:IsShown() then return end
	local rows = {}
	local action, enabled, status = "Post", false, ""
	if post then
		for _, e in ipairs(post.entries) do rows[#rows + 1] = e end
		local scanning = 0
		for _, e in ipairs(post.entries) do if e.state == "scanning" then scanning = scanning + 1 end end
		local e = FirstReady()
		if post.pending then
			action, enabled = "Confirm Post", true
		elseif e then
			action, enabled = string.format("Post %s x%d", M.ShortMoney(e.price), e.commodity and e.left or 1), true
		end
		status = scanning > 0 and string.format("Scanning: %d to go.", scanning) or string.format("%d auction(s) posted.", post.posted)
		panel.mode = "post"
	elseif cancel then
		for _, e in ipairs(cancel.entries) do rows[#rows + 1] = e end
		local ready, scanning = 0, 0
		for _, e in ipairs(cancel.entries) do
			if e.state == "ready" then ready = ready + 1 elseif e.state == "scanning" then scanning = scanning + 1 end
		end
		action, enabled = "Cancel Auction", ready > 0
		status = cancel.waitingOwned and "Reading your auctions..." or scanning > 0 and string.format("Scanning: %d to go.", scanning)
			or string.format("%d undercut auction(s) to cancel.", ready)
		panel.mode = "cancel"
	end
	UI.ButtonText(panel.action, action)
	panel.action:SetKMEnabled(enabled)
	panel.skip:SetKMEnabled(enabled)
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
	panel.postScan = UI.Button(panel, "Post Scan", 134, 24, "secondary", "KainUIForeverMarketPostScanButton")
	panel.postScan:SetPoint("TOPLEFT", 12, -32)
	panel.postScan:SetScript("OnClick", function() M:StartPostScan() end)
	panel.cancelScan = UI.Button(panel, "Cancel Scan", 134, 24, "secondary", "KainUIForeverMarketCancelScanButton")
	panel.cancelScan:SetPoint("TOPRIGHT", -12, -32)
	panel.cancelScan:SetScript("OnClick", function() M:StartCancelScan() end)
	panel.action = UI.Button(panel, "Post", 200, 28, "primary", "KainUIForeverMarketPostButton")
	panel.action:SetPoint("TOPLEFT", 12, -64)
	panel.action:SetScript("OnClick", function()
		if panel.mode == "cancel" then M:CancelClick() else M:PostClick() end
	end)
	panel.skip = UI.Button(panel, "Skip", 68, 28, "secondary", "KainUIForeverMarketSkipButton")
	panel.skip:SetPoint("TOPRIGHT", -12, -64)
	panel.skip:SetScript("OnClick", function()
		if panel.mode == "cancel" then M:SkipCancel() else M:SkipPost() end
	end)
	panel.status = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.status:SetPoint("TOPLEFT", 12, -100)
	panel.empty = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.empty:SetPoint("TOPLEFT", 12, -124)
	panel.empty:SetWidth(276)
	panel.empty:SetWordWrap(true)
	panel.empty:SetText("Post Scan prices everything in your bags that's in a group with an Auctioning operation. Cancel Scan finds your auctions someone has undercut.")
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
	end, function(row, e)
		row.icon:SetTexture(M.ItemIcon(e.itemID))
		local qty = e.left or e.have or e.quantity
		row.name:SetText(M.ItemName(e.itemID) .. (qty and ("  x" .. qty) or ""))
		row.price:SetText(e.price and M.ShortMoney(e.price) or "")
		row.note:SetText(STATE_TEXT[e.state] or e.reason or "")
		UI.TextColor(row.note, e.state == "skip" and "error" or e.state == "ready" and "positive" or "textLow")
		row:SetAlpha((e.state == "done" or e.state == "skip" or e.state == "fine") and 0.55 or 1)
	end)
	panel.list:SetPoint("TOPLEFT", 0, -118)
	panel.list:SetPoint("TOPRIGHT", 0, -118)
	panel.list:SetHeight(34 * 12)
	panel:SetScript("OnShow", function() M:RefreshAuctionPanel() end)
	M.auctionPanel = panel
	self:RefreshAuctionPanel()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"AUCTION_HOUSE_POST_WARNING", "OWNED_AUCTIONS_UPDATED", "AUCTION_CANCELED" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "AUCTION_HOUSE_SHOW" then
		local function Show()
			M:BuildAuctionPanel()
			if panel then panel:Show(); M:RefreshAuctionPanel() end
		end
		if AuctionHouseFrame then Show() else C_Timer.After(0.1, Show) end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		post, cancel = nil, nil
		ClearSearches()
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
		OnResults(event, arg)
	elseif event == "AUCTION_HOUSE_POST_WARNING" then
		if post and post.last then
			post.pending = post.last
			M:RefreshAuctionPanel()
		end
	elseif event == "OWNED_AUCTIONS_UPDATED" then
		M:OnOwnedAuctions()
	end
end)
