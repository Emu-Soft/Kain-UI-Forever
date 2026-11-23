local _, KUI = ...
local M = KUI.Market
local UI = M.UI
local Plain, Say = M.Plain, M.Say

local W, H = 640, 560
local HEADER = 44
local ROW = 24
local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12
local PAGES = { "Inbox", "Groups", "Send" }

local frame
local pages = {}
local current = 1
local blizzardScale
M.mailUI = function() return frame end

local function Settings()
	local d = M.Settings and M.Settings() or {}
	return d
end

local function HideBlizzard()
	if not MailFrame then return end
	if not blizzardScale then blizzardScale = MailFrame:GetScale() end
	MailFrame:SetScale(0.001)
	MailFrame:SetAlpha(0)
	if frame and frame.back then frame.back:Hide() end
end

local function ShowBlizzard()
	if not MailFrame then return end
	if blizzardScale then MailFrame:SetScale(blizzardScale) end
	blizzardScale = nil
	MailFrame:SetAlpha(1)
end

local function DaysText(days)
	days = Plain(days)
	if type(days) ~= "number" then return "" end
	if days >= 1 then return math.floor(days) .. "d" end
	return math.max(1, math.floor(days * 24)) .. "h"
end

local function InboxItems()
	local list = {}
	local shown, total = GetInboxNumItems()
	shown, total = Plain(shown) or 0, Plain(total)
	for i = 1, shown do
		local package, stationery, sender, subject, money, cod, days, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(i)
		local icon = Plain(package) or Plain(stationery)
		itemCount = Plain(itemCount) or 0
		if itemCount > 0 and GetInboxItem then
			local _, _, texture = GetInboxItem(i, 1)
			icon = Plain(texture) or icon
		end
		list[#list + 1] = {
			index = i, icon = icon, sender = Plain(sender) or "?", subject = Plain(subject) or "",
			money = Plain(money) or 0, cod = Plain(cod) or 0, days = days, items = itemCount, gm = Plain(isGM),
		}
	end
	return list, shown, total
end

local function TakeMail(item)
	if InCombatLockdown() then Say("not in combat."); return end
	if item.cod > 0 then Say("that mail is cash on delivery: open it in the Blizzard UI to pay."); return end
	if item.items > 0 then AutoLootMailItem(item.index) elseif item.money > 0 then TakeInboxMoney(item.index) end
end

local function BuildInbox(page)
	local rows = math.floor((H - HEADER - 40 - 56) / ROW)
	local head = CreateFrame("Frame", nil, page)
	head:SetPoint("TOPLEFT", 12, -10); head:SetPoint("TOPRIGHT", -12, -10)
	head:SetHeight(18)
	local function Col(text, x, w, justify)
		local fs = UI.Text(head, "body/medium/x-small", "textLow", justify)
		fs:SetPoint("LEFT", x, 0); fs:SetWidth(w)
		fs:SetText(text)
	end
	Col("FROM", 30, 150); Col("SUBJECT", 186, 230); Col("CONTENTS", 420, 120, "RIGHT"); Col("LEFT", 556, 50, "RIGHT")
	local listBox = UI.Panel(page, "low", 4)
	listBox:SetPoint("TOPLEFT", 8, -30); listBox:SetPoint("TOPRIGHT", -8, -30)
	listBox:SetHeight(rows * ROW + 4)
	page.list = UI.List(listBox, ROW, rows, function(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18); row.icon:SetPoint("LEFT", 8, 0)
		row.sender = UI.Text(row, "body/regular/small", "text")
		row.sender:SetPoint("LEFT", 34, 0); row.sender:SetWidth(150)
		row.subject = UI.Text(row, "body/regular/small", "textLow")
		row.subject:SetPoint("LEFT", 190, 0); row.subject:SetWidth(230)
		row.what = UI.Text(row, "numeric/regular/small", "text", "RIGHT")
		row.what:SetPoint("LEFT", 424, 0); row.what:SetWidth(120)
		row.days = UI.Text(row, "numeric/regular/x-small", "textLow", "RIGHT")
		row.days:SetPoint("LEFT", 560, 0); row.days:SetWidth(50)
		row:SetScript("OnClick", function(self) TakeMail(self.kmItem) end)
		row:HookScript("OnEnter", function(self)
			local item = self.kmItem
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if item.items > 0 and GameTooltip.SetInboxItem then
				GameTooltip:SetInboxItem(item.index, 1)
			else
				GameTooltip:SetText(item.subject, 1, 1, 1, 1, true)
			end
			GameTooltip:AddLine(item.cod > 0 and "Cash on delivery: open it in the Blizzard UI." or "Click to take it.", 0.6, 0.63, 0.63)
			GameTooltip:Show()
		end)
		row:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end, function(row, item)
		row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Letter_15")
		row.sender:SetText(item.sender)
		row.subject:SetText(item.subject)
		local parts = {}
		if item.cod > 0 then parts[#parts + 1] = UI.Colorize("COD " .. M.ShortMoney(item.cod), "error") end
		if item.money > 0 then parts[#parts + 1] = UI.Colorize(M.ShortMoney(item.money), "accent") end
		if item.items > 0 then parts[#parts + 1] = item.items .. (item.items == 1 and " item" or " items") end
		row.what:SetText(table.concat(parts, "  "))
		row.days:SetText(DaysText(item.days))
	end)
	page.list:SetPoint("TOPLEFT", 0, -2); page.list:SetPoint("TOPRIGHT", 0, -2)
	page.list:SetHeight(rows * ROW)
	page.empty = UI.Text(listBox, "body/regular/small", "textLow", "CENTER")
	page.empty:SetPoint("CENTER")
	page.empty:SetText("No mail.")

	page.summary = UI.Text(page, "body/regular/small", "textLow")
	page.summary:SetPoint("BOTTOMLEFT", 14, 20)
	page.open = UI.Button(page, "Open All", 120, 26, "primary", "KainUIForeverMarketOpenAllButton")
	page.open:SetPoint("BOTTOMRIGHT", -12, 14)
	page.open:SetScript("OnClick", function() M:OpenAllMail() end)
	page.open.kmTip = "Takes everything out of your mail (not cash on delivery), and notes Auction House sales and purchases for the K-Market dashboard."

	function page:Refresh()
		local items, shown, total = InboxItems()
		self.list:SetItems(items)
		self.empty:SetShown(#items == 0)
		local money = 0
		for _, item in ipairs(items) do money = money + item.money end
		local text = string.format("%d mail%s, %s", shown, shown == 1 and "" or "s", M.ShortMoney(money))
		if total and total > shown then text = text .. string.format(" (%d more on the server: take some to see them)", total - shown) end
		self.summary:SetText(text)
		UI.ButtonText(self.open, M.openerState() and "Stop Opening" or "Open All")
	end
end

local function BuildGroups(page)
	page.send = UI.Button(page, "Send Groups", 140, 26, "primary", "KainUIForeverMarketMailButton")
	page.send:SetPoint("TOPLEFT", 12, -12)
	page.send:SetScript("OnClick", function() M:StartMailing() end)
	page.send.kmTip = "Mails your groups' items to the bank alt or crafter their operations name."
	page.status = UI.Text(page, "body/regular/small", "textLow")
	page.status:SetPoint("LEFT", page.send, "RIGHT", 12, 0)
	local sub = UI.Text(page, "body/medium/x-small", "textLow")
	sub:SetPoint("TOPLEFT", 14, -50)
	sub:SetText("TO SEND")
	local rows = math.floor((H - HEADER - 40 - 70) / 20)
	local box = UI.Panel(page, "low", 4)
	box:SetPoint("TOPLEFT", 8, -66); box:SetPoint("TOPRIGHT", -8, -66)
	box:SetHeight(rows * 20 + 4)
	page.list = UI.List(box, 20, rows, function(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", 24, 0)
		row.text = UI.Text(row, "body/regular/small", "text")
		row.text:SetPoint("LEFT", 46, 0)
		row.text:SetPoint("RIGHT", -70, 0)
		row.count = UI.Text(row, "numeric/regular/small", "textLow", "RIGHT")
		row.count:SetPoint("RIGHT", -12, 0)
	end, function(row, item)
		if item.header then
			row.icon:Hide()
			row.text:ClearAllPoints(); row.text:SetPoint("LEFT", 10, 0); row.text:SetPoint("RIGHT", -70, 0)
			row.text:SetText(UI.Colorize(item.header, "accent"))
			row.count:SetText(item.total and (item.total .. " items") or "")
		else
			row.icon:Show()
			row.icon:SetTexture(M.ItemIcon(item.itemID))
			row.text:ClearAllPoints(); row.text:SetPoint("LEFT", 46, 0); row.text:SetPoint("RIGHT", -70, 0)
			row.text:SetText(M.ItemName(item.itemID))
			row.count:SetText("x" .. item.count)
		end
	end)
	page.list:SetPoint("TOPLEFT", 0, -2); page.list:SetPoint("TOPRIGHT", 0, -2)
	page.list:SetHeight(rows * 20)
	page.empty = UI.Text(box, "body/regular/small", "textLow", "CENTER")
	page.empty:SetPoint("CENTER")
	page.empty:SetWidth(W - 80)
	page.empty:SetWordWrap(true)
	page.empty:SetText("Nothing in your bags to send right now.")

	function page:Refresh()
		local run = M.mailRunState()
		if run then
			local left = 0
			for _, n in ipairs(run.needs) do left = left + math.max(n.count, 0) end
			UI.ButtonText(self.send, run.stalled and "No answer: send next" or "Sending...")
			local text = string.format("%d mail(s) sent, %d item(s) to go.", run.mails, left)
			if run.confirming then text = "Confirm the game's popup to send. " .. text end
			self.status:SetText(text)
		else
			UI.ButtonText(self.send, "Send Groups")
			self.status:SetText("")
		end
		local needs = run and run.needs or M:MailNeeds()
		local byTo, order = {}, {}
		for _, n in ipairs(needs) do
			if n.count > 0 then
				if not byTo[n.to] then byTo[n.to] = {}; order[#order + 1] = n.to end
				table.insert(byTo[n.to], n)
			end
		end
		local lines = {}
		for _, to in ipairs(order) do
			local head = { header = to, total = 0 }
			lines[#lines + 1] = head
			for _, n in ipairs(byTo[to]) do
				lines[#lines + 1] = n
				head.total = head.total + n.count
			end
		end
		self.list:SetItems(lines)
		self.empty:SetShown(#lines == 0)
		self.send:SetKMEnabled(#lines > 0 or run ~= nil)
	end
end

local sending

local function BuildSend(page)
	local function Label(text, y)
		local fs = UI.Text(page, "body/medium/x-small", "textLow")
		fs:SetPoint("TOPLEFT", 14, y)
		fs:SetText(text)
		return fs
	end
	Label("TO", -16)
	page.to = UI.Input(page, 220, 26)
	page.to:SetPoint("TOPLEFT", 14, -32)
	page.alts = UI.Choice(page, 200, { { "", "My characters" } }, function(value)
		if value ~= "" then page.to:SetText(value) end
	end)
	page.alts:SetPoint("LEFT", page.to, "RIGHT", 10, 0)
	page.alts:SetKMValue("")
	Label("SUBJECT", -68)
	page.subject = UI.Input(page, W - 28, 26)
	page.subject:SetPoint("TOPLEFT", 14, -84)

	Label("ITEMS (drop an item on a slot; right-click to take it back)", -120)
	page.slots = {}
	local size, gap = 44, 8
	for i = 1, MAX_ATTACH do
		local s = CreateFrame("Button", nil, page)
		s:SetSize(size, size)
		local col, line = (i - 1) % 6, math.floor((i - 1) / 6)
		s:SetPoint("TOPLEFT", 14 + col * (size + gap), -138 - line * (size + gap))
		UI.Rounded(s, "lowest", 4)
		s.icon = s:CreateTexture(nil, "ARTWORK")
		s.icon:SetPoint("TOPLEFT", 3, -3); s.icon:SetPoint("BOTTOMRIGHT", -3, 3)
		s.count = UI.Text(s, "numeric/regular/x-small", "text", "RIGHT", "OVERLAY")
		s.count:SetPoint("BOTTOMRIGHT", -4, 4)
		s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		s:RegisterForDrag("LeftButton")
		local function Drop() if CursorHasItem and CursorHasItem() then ClickSendMailItemButton(i) end end
		s:SetScript("OnReceiveDrag", Drop)
		s:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				if HasSendMailItem(i) then ClickSendMailItemButton(i, true) end
			else
				ClickSendMailItemButton(i)
			end
		end)
		s:SetScript("OnEnter", function(self)
			if HasSendMailItem(i) and GameTooltip.SetSendMailItem then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetSendMailItem(i)
				GameTooltip:Show()
			end
		end)
		s:SetScript("OnLeave", function() GameTooltip:Hide() end)
		page.slots[i] = s
	end

	local moneyY = -138 - 2 * (size + gap) - 8
	Label("GOLD (like 12g 50s)", moneyY)
	page.money = UI.Input(page, 160, 26, true)
	page.money:SetPoint("TOPLEFT", 14, moneyY - 16)
	page.cod = UI.Toggle(page, "Cash on delivery (they pay this to open it)")
	page.cod:SetPoint("LEFT", page.money, "RIGHT", 14, 0)
	page.cod:SetWidth(300)

	page.status = UI.Text(page, "body/regular/small", "textLow")
	page.status:SetPoint("BOTTOMLEFT", 14, 20)
	page.send = UI.Button(page, "Send", 120, 26, "primary", "KainUIForeverMarketSendButton")
	page.send:SetPoint("BOTTOMRIGHT", -12, 14)
	page.send:SetScript("OnClick", function() page:Send() end)

	function page:Send()
		if sending then return end
		if InCombatLockdown() then Say("not in combat."); return end
		local to = M:NormalizeName(self.to:GetText() or "") or ""
		if to == "" then self.status:SetText("Who to? Type a name or pick one of your characters."); return end
		if M.IsMe(to) then self.status:SetText("That's you."); return end
		local copper = 0
		local moneyText = self.money:GetText() or ""
		if moneyText:match("%S") then
			copper = M.ParseMoney(moneyText)
			if not copper then self.status:SetText("Gold like 12g 50s, 75s or 12.5."); return end
		end
		local items, firstName, firstCount = 0, nil, 0
		for i = 1, MAX_ATTACH do
			if HasSendMailItem(i) then
				items = items + 1
				if not firstName then
					local name, _, _, count = GetSendMailItem(i)
					firstName, firstCount = Plain(name), Plain(count) or 1
				end
			end
		end
		local cod = self.cod.kmChecked
		if cod and (items == 0 or copper == 0) then self.status:SetText("Cash on delivery needs an item and an amount."); return end
		if items == 0 and copper == 0 then self.status:SetText("Nothing to send: add an item or some gold."); return end
		local subject = (self.subject:GetText() or ""):match("^%s*(.-)%s*$")
		if subject == "" then
			subject = firstName and (firstCount > 1 and (firstName .. " (" .. firstCount .. ")") or firstName) or M.ShortMoney(copper)
		end
		self.to:SetText(to)
		M:BefriendAlt(to)
		if SetSendMailShowing then SetSendMailShowing(true) end
		SetSendMailCOD(cod and copper or 0)
		SetSendMailMoney(cod and 0 or copper)
		sending = true
		self.status:SetText("Sending...")
		SendMail(to, subject, "")
	end

	function page:Clear()
		self.subject:SetText("")
		self.money:SetText("")
		self.cod:SetKMChecked(false)
	end

	function page:Refresh()
		local choices = { { "", "My characters" } }
		local _, _, myRealm = M:Me()
		local keys = {}
		for key in pairs(M:DB().chars) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local c = M:DB().chars[key]
			if type(c.name) == "string" then
				local name = M.MailName(c, myRealm)
				if not M.IsMe(name) then choices[#choices + 1] = { name, name } end
			end
		end
		self.alts.kmChoices = choices
		self.alts:SetKMValue("")
		for i, s in ipairs(self.slots) do
			local name, _, texture, count = GetSendMailItem(i)
			if HasSendMailItem(i) and Plain(name) then
				s.icon:SetTexture(Plain(texture)); s.icon:Show()
				count = Plain(count) or 1
				s.count:SetText(count > 1 and count or "")
			else
				s.icon:Hide(); s.count:SetText("")
			end
		end
	end
end

local function ShowPage(i)
	current = i
	frame.tabs:Select(i)
end

local function Refresh()
	if not frame or not frame:IsShown() then return end

	local targets = #M:MailTargets() > 0 or M.mailRunState() ~= nil
	frame.tabs.tabs[2]:SetShown(targets)
	if not targets and current == 2 then ShowPage(1); return end
	local page = pages[current]
	if page and page.Refresh then page:Refresh() end
end
function M:RefreshMailPanel() Refresh() end

local function Build()
	if frame or not MailFrame then return end
	frame = CreateFrame("Frame", "KainUIForeverMarketMailFrame", UIParent)
	frame:SetSize(W, H)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -100)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:Hide()
	UI.Rounded(frame, "surface", 6)
	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
	local title = UI.Text(header, "body/bold/p", "accent")
	title:SetPoint("LEFT", 16, 0)
	title:SetText("K-Market Mail")
	local rule = UI.Rule(frame, "low")
	rule:SetPoint("TOPLEFT", 0, -HEADER); rule:SetPoint("TOPRIGHT", 0, -HEADER)
	local close = UI.Button(header, "X", 24, 24, "tertiary", "KainUIForeverMarketMailClose")
	close:SetPoint("RIGHT", -10, 0)
	close:SetScript("OnClick", function() HideUIPanel(MailFrame) end)
	local switch = UI.Button(header, "Blizzard UI", 96, 24, "secondary", "KainUIForeverMarketMailSwitch")
	switch:SetPoint("RIGHT", close, "LEFT", -8, 0)
	switch.kmTip = "Use the game's own mail window instead (K-Market remembers)."
	switch:SetScript("OnClick", function() M:SetMailSkin(false) end)
	frame.tabs = UI.Tabs(header, PAGES, function(i)
		current = i
		for j, p in ipairs(pages) do p:SetShown(j == i) end
		Refresh()
	end)
	frame.tabs:SetPoint("LEFT", title, "RIGHT", 28, 0)
	for i = 1, #PAGES do
		local page = CreateFrame("Frame", nil, frame)
		page:SetPoint("TOPLEFT", 0, -HEADER)
		page:SetPoint("BOTTOMRIGHT")
		page:Hide()
		pages[i] = page
	end
	BuildInbox(pages[1])
	BuildGroups(pages[2])
	BuildSend(pages[3])
	M.mailPages = pages
	M.mailPanel = pages[2]
	frame:SetScript("OnShow", function() ShowPage(current) end)

	frame.back = UI.Button(MailFrame, "K-Market", 90, 22, "primary", "KainUIForeverMarketMailBack")
	frame.back:SetPoint("TOPRIGHT", MailFrame, "BOTTOMRIGHT", 0, -2)
	frame.back:SetScript("OnClick", function() M:SetMailSkin(true) end)
	frame.back:Hide()
end

local function OnMailShown()
	Build()
	if not frame then return end
	if Settings().mailDefault then
		frame:Hide()
		frame.back:Show()
		return
	end
	HideBlizzard()
	current = 1
	frame:Show()
end

local function OnMailHidden()
	if frame then frame:Hide(); frame.back:Hide() end
	ShowBlizzard()
end

function M:SetMailSkin(on)
	Settings().mailDefault = not on or nil
	if not frame then return end
	if on then
		frame.back:Hide()
		HideBlizzard()
		frame:Show()
	else
		frame:Hide()
		ShowBlizzard()
		frame.back:Show()
	end
end

local hooked
local function Hook()
	if hooked or not MailFrame then return end
	hooked = true
	MailFrame:HookScript("OnShow", OnMailShown)
	MailFrame:HookScript("OnHide", OnMailHidden)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
	"MAIL_FAILED", "BAG_UPDATE_DELAYED", "MAIL_CLOSED" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		Hook()
	elseif event == "MAIL_SHOW" then

		Hook()
		if MailFrame and MailFrame:IsShown() then OnMailShown() end
	elseif event == "MAIL_SEND_SUCCESS" then
		if sending then
			sending = false
			if pages[3] then pages[3].status:SetText("Sent."); pages[3]:Clear() end
		end
		Refresh()
	elseif event == "MAIL_FAILED" then
		if sending then
			sending = false
			if pages[3] then pages[3].status:SetText("The mail was refused.") end
		end
		Refresh()
	elseif event == "MAIL_CLOSED" then
		sending = false
		OnMailHidden()
	elseif event == "MAIL_INBOX_UPDATE" then
		if current == 1 then Refresh() end
	elseif event == "MAIL_SEND_INFO_UPDATE" then
		if current == 3 then Refresh() end
	elseif event == "BAG_UPDATE_DELAYED" then
		if current == 2 and not M.mailRunState() then Refresh() end
	end
end)
