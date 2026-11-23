local _, KUI = ...
local M = KUI.Market
local UI = M.UI
local Plain = M.Plain

local AH_CUT = 0.05
local FRESH = 3 * 86400
local SCAN_AGE = 3600
local WATCH_DAYS = 60

local function Store(key)
	local db = M:DB()
	if type(db[key]) ~= "table" then db[key] = {} end
	return db[key]
end

function M:NotePrice(itemID, copper)
	itemID, copper = Plain(itemID), Plain(copper)
	if type(itemID) ~= "number" then return end
	if type(copper) ~= "number" or copper <= 0 then copper = nil end
	Store("prices")[itemID] = { ah = copper, t = M.Now() }
end

function M:NotedPrice(itemID)
	local p = Store("prices")[itemID]
	if type(p) ~= "table" or type(p.t) ~= "number" then return nil end
	return type(p.ah) == "number" and p.ah or nil, M.Now() - p.t
end

local function Age(seconds)
	if seconds < 3600 then return math.max(1, math.floor(seconds / 60)) .. " min" end
	if seconds < 86400 then return math.floor(seconds / 3600) .. " h" end
	return math.floor(seconds / 86400) .. " d"
end

function M:AHValue(itemID)
	local noted, age = self:NotedPrice(itemID)
	if noted and age < FRESH then return noted, "your AH scan, " .. Age(age) .. " old" end
	if self.MarketPrice then
		local v, label = self:MarketPrice(itemID)
		v = Plain(v)
		if type(v) == "number" and v > 0 then return v, label or "price feed" end
	end
	if noted then return noted, "your AH scan, " .. Age(age) .. " old" end
end

function M:ReagentCost(itemID)
	local vendor = Store("vendor")[itemID]
	local ah, label = self:AHValue(itemID)
	if type(vendor) == "number" and (not ah or vendor <= ah) then return vendor, "vendor" end
	return ah, label
end

function M:SellValue(itemID)
	local ah, label = self:AHValue(itemID)
	if ah then return ah * (1 - AH_CUT), label end
	local sell = C_Item and C_Item.GetItemInfo and Plain(select(11, C_Item.GetItemInfo(itemID)))
	if type(sell) == "number" and sell > 0 then return sell, "vendor" end
end

local BASIC = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

function M:ReadRecipes()
	local list = {}
	local T = C_TradeSkillUI
	if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetRecipeSchematic) then return list end
	local watch = Store("craftItems")
	local now = M.Now()
	for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
		local info = T.GetRecipeInfo(id)
		local s = info and Plain(info.learned) and T.GetRecipeSchematic(id, false)
		local out = s and Plain(s.outputItemID)
		if type(out) == "number" and out > 0 then
			local lo, hi = Plain(s.quantityMin) or 1, Plain(s.quantityMax) or 1
			local r = {
				id = id, name = Plain(info.name) or M.ItemName(out), icon = Plain(info.icon), out = out,
				qty = (lo + math.max(lo, hi)) / 2, available = Plain(info.numAvailable) or 0, reagents = {},
			}
			for _, slot in ipairs(s.reagentSlotSchematics or {}) do
				local first = slot.reagents and slot.reagents[1]
				local rid, n = first and Plain(first.itemID), Plain(slot.quantityRequired)
				if Plain(slot.reagentType) == BASIC and type(rid) == "number" and type(n) == "number" and n > 0 then
					r.reagents[#r.reagents + 1] = { id = rid, n = n }
					watch[rid] = now
				end
			end
			watch[out] = now
			list[#list + 1] = r
		end
	end
	return list
end

function M:PriceRecipe(r)
	local cost, missing = 0, false
	for _, g in ipairs(r.reagents) do
		local c, label = self:ReagentCost(g.id)
		g.cost, g.label = c, label
		if c then cost = cost + c * g.n else missing = true end
	end
	local each, label = self:SellValue(r.out)
	r.cost = (not missing) and cost or nil
	r.value = each and each * r.qty or nil
	r.valueLabel = label
	r.profit = (r.cost and r.value) and (r.value - r.cost) or nil
	return r
end

local panel

local function Settings()
	local db = M:DB()
	if type(db.craft) ~= "table" then db.craft = { canCraft = false, profitable = false } end
	return db.craft
end

local function Money(v) return v and M.ShortMoney(v) or "?" end

local function ShowTooltip(row)
	local r = row.kmItem
	if not r then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(r.name, 1, 1, 1)
	for _, g in ipairs(r.reagents) do
		GameTooltip:AddDoubleLine(g.n .. " x " .. M.ItemName(g.id) .. (g.label and ("  (" .. g.label .. ")") or ""),
			g.cost and M.ShortMoney(g.cost * g.n) or "no price", 0.72, 0.75, 0.75, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine("Reagents", Money(r.cost), 1, 1, 1, 1, 1, 1)
	local qty = r.qty == math.floor(r.qty) and tostring(r.qty) or string.format("%.1f", r.qty)
	GameTooltip:AddDoubleLine("Makes " .. qty .. " x " .. M.ItemName(r.out), Money(r.value), 1, 1, 1, 1, 1, 1)
	if r.valueLabel then GameTooltip:AddLine("Sell price: " .. r.valueLabel .. (r.valueLabel == "vendor" and "" or ", less the 5% Auction House cut"), 0.72, 0.75, 0.75, true) end
	if r.profit then
		local good = r.profit >= 0
		GameTooltip:AddDoubleLine("Profit", (good and "+" or "") .. M.ShortMoney(r.profit), 1, 1, 1, good and 0.03 or 0.99, good and 0.83 or 0.22, good and 0.42 or 0.18)
	else
		GameTooltip:AddLine("Some prices are missing: open the Auction House and press Price Scan in K-Market's panel.", 0.88, 0.73, 0, true)
	end
	GameTooltip:AddLine("Click to open the recipe.", 0.72, 0.75, 0.75)
	GameTooltip:Show()
end

local function OpenRecipe(r)
	local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
	local info = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(r.id)
	if list and list.SelectRecipe and info then
		pcall(list.SelectRecipe, list, info, true)
	elseif C_TradeSkillUI.OpenRecipe then
		pcall(C_TradeSkillUI.OpenRecipe, r.id)
	end
end

local function Better(a, b)
	if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
	if a.profit and a.profit ~= b.profit then return a.profit > b.profit end
	return a.name < b.name
end

function M:RefreshCraftPanel()
	if not panel or not panel:IsShown() then return end
	local set = Settings()
	local rows, priced, total = {}, 0, 0
	for _, r in ipairs(self:ReadRecipes()) do
		self:PriceRecipe(r)
		total = total + 1
		if r.profit then priced = priced + 1 end
		if (not set.canCraft or r.available > 0) and (not set.profitable or (r.profit and r.profit > 0)) then rows[#rows + 1] = r end
	end
	table.sort(rows, Better)
	panel.list:SetItems(rows)
	panel.empty:SetShown(#rows == 0)
	panel.empty:SetText(total == 0 and "No recipes that make an item here." or "Nothing matches the filters.")
	if total > 0 and priced < total then
		panel.status:SetText(string.format("Prices for %d of %d recipes. Open the Auction House and press Price Scan in K-Market's panel for the rest.", priced, total))
	else
		panel.status:SetText(total > 0 and "Every recipe here has prices." or "")
	end
end

function M:BuildCraftPanel()
	if panel or not ProfessionsFrame then return end
	panel = UI.Panel(ProfessionsFrame, "surface", 6)
	panel:SetSize(320, ProfessionsFrame:GetHeight() or 594)
	panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 46, 0)
	panel:EnableMouse(true)
	local title = UI.Text(panel, "body/bold/small", "accent")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("K-Market")
	local sub = UI.Text(panel, "body/regular/x-small", "textLow", "RIGHT")
	sub:SetPoint("TOPRIGHT", -12, -12)
	sub:SetText("Crafting profit")
	local set = Settings()
	panel.canCraft = UI.Toggle(panel, "Can craft now", function(on) Settings().canCraft = on; M:RefreshCraftPanel() end)
	panel.canCraft:SetPoint("TOPLEFT", 12, -34)
	panel.canCraft:SetWidth(140)
	panel.canCraft:SetKMChecked(set.canCraft)
	panel.profitable = UI.Toggle(panel, "Profitable only", function(on) Settings().profitable = on; M:RefreshCraftPanel() end)
	panel.profitable:SetPoint("TOPLEFT", 160, -34)
	panel.profitable:SetWidth(148)
	panel.profitable:SetKMChecked(set.profitable)
	local ROWS = 13
	panel.list = UI.List(panel, 38, ROWS, function(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(26, 26)
		row.icon:SetPoint("LEFT", 10, 0)
		row.name = UI.Text(row, "body/regular/x-small", "text")
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
		row.name:SetPoint("RIGHT", -86, 0)
		row.note = UI.Text(row, "body/regular/x-small", "textLow")
		row.note:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -1)
		row.note:SetPoint("RIGHT", -10, 0)
		row.profit = UI.Text(row, "numeric/regular/x-small", "positive", "RIGHT")
		row.profit:SetPoint("TOPRIGHT", -10, -5)
		row:SetScript("OnEnter", function(b) b.kmHighlight:Show(); ShowTooltip(b) end)
		row:SetScript("OnLeave", function(b) b.kmHighlight:Hide(); GameTooltip:Hide() end)
		row:SetScript("OnClick", function(b) if b.kmItem then OpenRecipe(b.kmItem) end end)
	end, function(row, r)
		row.icon:SetTexture(r.icon or M.ItemIcon(r.out))
		row.name:SetText(r.name .. (r.available > 0 and UI.Colorize("  x" .. r.available, "textLow") or ""))
		row.note:SetText("Cost " .. Money(r.cost) .. "   Sells " .. Money(r.value))
		if r.profit then
			row.profit:SetText((r.profit >= 0 and "+" or "") .. M.ShortMoney(r.profit))
			UI.TextColor(row.profit, r.profit >= 0 and "positive" or "error")
		else
			row.profit:SetText("?")
			UI.TextColor(row.profit, "textLow")
		end
	end)
	panel.list:SetPoint("TOPLEFT", 0, -62)
	panel.list:SetPoint("TOPRIGHT", 0, -62)
	panel.list:SetHeight(38 * ROWS)
	panel.empty = UI.Text(panel, "body/regular/x-small", "textLow", "CENTER")
	panel.empty:SetPoint("TOP", 0, -90)
	panel.status = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.status:SetPoint("BOTTOMLEFT", 12, 10)
	panel.status:SetWidth(296)
	panel.status:SetWordWrap(true)
	panel:SetScript("OnShow", function() M:RefreshCraftPanel() end)
	M.craftPanel = panel
end

local scan

local function ScanButtonText(b)
	UI.ButtonText(b, scan and string.format("Prices %d/%d", scan.done, scan.total) or "Price Scan")
end

function M:StartPriceScan()
	if not (self.QueueSearch and C_AuctionHouse and C_AuctionHouse.MakeItemKey) then return end
	local watch = Store("craftItems")
	local ids = {}
	for id, seen in pairs(watch) do
		local _, age = self:NotedPrice(id)
		if type(seen) == "number" and (not age or age > SCAN_AGE) then ids[#ids + 1] = id end
	end
	table.sort(ids)
	if #ids == 0 then
		M.Say(next(watch) and "Crafting prices are all under an hour old." or "Open a profession window first, so K-Market knows what you craft.")
		return
	end
	scan = { total = #ids, done = 0 }
	local button = self.auctionPanel and self.auctionPanel.priceScan
	for _, id in ipairs(ids) do
		local commodity = self:IsCommodity(id)
		local key
		if commodity then
			key = C_AuctionHouse.MakeItemKey(id)
		else
			local level = Plain(select(4, C_Item.GetItemInfo(id)))
			key = C_AuctionHouse.MakeItemKey(id, type(level) == "number" and level or 0)
		end
		self.QueueSearch({ itemID = id, commodity = commodity, key = key, done = function(r, timedOut)
			if not timedOut then M:NotePrice(id, r and r.lowest) end
			if not scan then return end
			scan.done = scan.done + 1
			if scan.done >= scan.total then
				M.Say(string.format("Price scan done: %d item(s).", scan.total))
				scan = nil
			end
			if button then ScanButtonText(button) end
			M:RefreshCraftPanel()
		end })
	end
	if button then ScanButtonText(button) end
end

local function AddScanButton()
	local p = M.auctionPanel
	if not p or p.priceScan then return end
	local b = UI.Button(p, "Price Scan", 110, 20, "tertiary", "KainUIForeverMarketPriceScanButton")
	b:SetPoint("TOPRIGHT", -12, -6)
	b.kmTip = "Looks up the Auction House price of every reagent and item your recipes make, for the profit list beside the profession window."
	b:SetScript("OnClick", function() if not scan then M:StartPriceScan() end end)
	p.priceScan = b
end

local function NoteBrowse()
	if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
	for _, row in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
		local key = row.itemKey
		local id = key and Plain(key.itemID)
		if type(id) == "number" then M:NotePrice(id, row.minPrice) end
	end
end

local function NoteMerchant()
	if not (GetMerchantNumItems and GetMerchantItemInfo and GetMerchantItemID) then return end
	local vendor = Store("vendor")
	for i = 1, (Plain(GetMerchantNumItems()) or 0) do
		local _, _, price, stack, _, _, _, extended = GetMerchantItemInfo(i)
		local id = Plain(GetMerchantItemID(i))
		price, stack, extended = Plain(price), Plain(stack), Plain(extended)
		if type(id) == "number" and type(price) == "number" and price > 0 and not extended then
			vendor[id] = price / math.max(1, type(stack) == "number" and stack or 1)
		end
	end
end

local function Prune()
	local watch = Store("craftItems")
	local cutoff = M.Now() - WATCH_DAYS * 86400
	for id, t in pairs(watch) do
		if type(id) ~= "number" or type(t) ~= "number" or t < cutoff then watch[id] = nil end
	end
	for _, key in ipairs({ "prices", "vendor" }) do
		for id, v in pairs(Store(key)) do
			if type(id) ~= "number" or (key == "vendor" and type(v) ~= "number") or (key == "prices" and type(v) ~= "table") then
				Store(key)[id] = nil
			end
		end
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "AUCTION_HOUSE_SHOW",
	"AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
	KUI:SafeRegisterEvent(events, e)
end
local refreshPending = false
local function RefreshSoon()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.3, function() refreshPending = false; M:RefreshCraftPanel() end)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "PLAYER_LOGIN" then
		Prune()
	elseif event == "TRADE_SKILL_SHOW" then
		local function Show()
			M:BuildCraftPanel()
			if panel then panel:Show(); RefreshSoon() end
		end
		if ProfessionsFrame then Show() else C_Timer.After(0.1, Show) end
	elseif event == "TRADE_SKILL_LIST_UPDATE" then
		RefreshSoon()
	elseif event == "TRADE_SKILL_CLOSE" then
		if panel then panel:Hide() end
	elseif event == "AUCTION_HOUSE_SHOW" then
		C_Timer.After(0.3, AddScanButton)
	elseif event == "AUCTION_HOUSE_CLOSED" then
		scan = nil
		local b = M.auctionPanel and M.auctionPanel.priceScan
		if b then ScanButtonText(b) end
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		local id = Plain(arg)
		if type(id) == "number" and M.ReadAuctionResults then M:NotePrice(id, M.ReadAuctionResults(id, true).lowest) end
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
		local id = type(arg) == "table" and Plain(arg.itemID)
		if type(id) == "number" and M.ReadAuctionResults then M:NotePrice(id, M.ReadAuctionResults(id, false, arg).lowest) end
	elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		NoteBrowse()
	elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		NoteMerchant()
	end
end)
