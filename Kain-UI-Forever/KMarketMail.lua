local _, KUI = ...
local M = KUI.Market
local UI = M.UI
local Plain, Say = M.Plain, M.Say

local SEND_TIMEOUT = 10
local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12

local function SameName(a, b) return type(a) == "string" and type(b) == "string" and a:lower() == b:lower() end

local function IsMe(to)
	local _, name, realm = M:Me()
	if not to or not name then return true end
	return SameName(to, name) or SameName(to, name .. "-" .. tostring(realm):gsub("%s", ""))
end

function M:MailNeeds(bags)
	bags = bags or self:ScanBags()
	local needs = {}
	local ids = {}
	for id in pairs(bags) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local path = self:ItemGroup(id)
		if path then
			local ops = {}
			for _, kind in ipairs({ "crafter", "mail" }) do
				local op = self:EffectiveOp(path, kind)
				if op then ops[#ops + 1] = op end
			end
			local keep = 0
			for _, op in ipairs(ops) do keep = math.max(keep, tonumber(op.keep) or 0) end
			local left = bags[id].count - keep
			for _, op in ipairs(ops) do
				local to = self:Recipient(op)
				if left > 0 and to and not IsMe(to) then
					local amount = left
					local cap = tonumber(op.maxQty) or 0
					if cap > 0 then
						if op.restock then cap = cap - self:CharCount(self:CharKeyFor(to), id) end
						amount = math.min(amount, math.max(cap, 0))
					end
					if amount > 0 then
						needs[#needs + 1] = { to = to, itemID = id, count = amount }
						left = left - amount
					end
				end
			end
		end
	end
	return needs
end

function M:NextMail(needs)
	local to
	for _, n in ipairs(needs) do if n.count > 0 then to = n.to; break end end
	if not to then return nil end
	local bags = self:ScanBags()
	local list = {}
	for _, n in ipairs(needs) do
		if n.to == to and n.count > 0 and bags[n.itemID] then
			local want = n.count
			local slots = {}
			for _, s in ipairs(bags[n.itemID].slots) do slots[#slots + 1] = s end
			table.sort(slots, function(a, b) return a.count > b.count end)

			for _, s in ipairs(slots) do
				if #list >= MAX_ATTACH or want <= 0 then break end
				if s.count <= want then
					list[#list + 1] = { bag = s.bag, slot = s.slot, count = s.count, itemID = n.itemID, need = n }
					want = want - s.count
					s.used = true
				end
			end

			if want > 0 and #list < MAX_ATTACH then
				for i = #slots, 1, -1 do
					local s = slots[i]
					if not s.used and s.count > want then
						list[#list + 1] = { bag = s.bag, slot = s.slot, count = want, itemID = n.itemID, need = n, split = true }
						break
					end
				end
			end
		end
		if #list >= MAX_ATTACH then break end
	end
	return to, (#list > 0 and list or nil)
end

local run
M.mailRunState = function() return run end

local function Finish(why)
	if run then
		Say(string.format("%s %d mail(s), %d item(s).", why or "Sent", run.mails, run.items))
	end
	run = nil
	if M.RefreshMailPanel then M:RefreshMailPanel() end
end

local function Attachments()
	local n = 0
	for i = 1, MAX_ATTACH do if HasSendMailItem(i) then n = n + 1 end end
	return n
end

function M:SendNextMail()
	if not run or run.waiting then return end
	if InCombatLockdown() then Say("not in combat."); return end
	local to, list = self:NextMail(run.needs)
	if not to then Finish(); return end
	if not list then

		run.tries = (run.tries or 0) + 1
		if run.tries > 6 then Finish("Stopped (the items to send couldn't be picked up). Sent"); return end
		C_Timer.After(0.5, function() if run and not run.waiting then M:SendNextMail() end end)
		return
	end
	run.tries = 0
	ClearCursor()
	local slot = 0
	for _, a in ipairs(list) do
		slot = slot + 1
		if a.split then
			C_Container.SplitContainerItem(a.bag, a.slot, a.count)
		else
			C_Container.PickupContainerItem(a.bag, a.slot)
		end
		ClickSendMailItemButton(slot)
	end
	ClearCursor()
	if Attachments() == 0 then Finish("Stopped (nothing could be attached). Sent"); return end
	run.waiting, run.sentAt, run.to, run.attached = true, GetTime(), to, list
	local subject = (KUI.GetMailAutoSubject and KUI:GetMailAutoSubject()) or "K-Market"
	SendMail(to, subject, "")
	self:RefreshMailPanel()
	local asked = run
	C_Timer.After(SEND_TIMEOUT, function()
		if run == asked and run.waiting and GetTime() - run.sentAt >= SEND_TIMEOUT - 0.01 then
			run.waiting = false
			run.stalled = true
			M:RefreshMailPanel()
		end
	end)
end

function M:StartMailing()
	if run then
		if not run.waiting then run.stalled = nil; self:SendNextMail() end
		return
	end
	if InCombatLockdown() then Say("not in combat."); return end
	if Attachments() > 0 then Say("take the attachments off the mail first."); return end
	local needs = self:MailNeeds()
	if #needs == 0 then
		Say("nothing to send: no item in your bags is in a group with a Mailing or Crafter operation (above its Keep amount).")
		return
	end
	run = { needs = needs, mails = 0, items = 0 }
	self:SendNextMail()
end

local function OnSent()
	if not run or not run.waiting then return end
	run.waiting, run.stalled = false, nil
	run.mails = run.mails + 1
	for _, a in ipairs(run.attached) do
		a.need.count = a.need.count - a.count
		run.items = run.items + a.count
		M:AddInTransit(run.to, a.itemID, a.count)
	end
	run.attached = nil
	M:RefreshMailPanel()
	C_Timer.After(0.5, function() if run and not run.waiting then M:SendNextMail() end end)
end

local opener
M.openerState = function() return opener end

local function FreeBagSlots()
	local free = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local n, family = C_Container.GetContainerNumFreeSlots(bag)
		if (Plain(family) or 0) == 0 then free = free + (Plain(n) or 0) end
	end
	return free
end

local function StopOpening(why)
	if opener then
		Say(string.format("%s %d mail(s) opened, %s taken.", why or "Done:", opener.taken, M.FormatMoney(opener.money)))
	end
	opener = nil
	if M.RefreshMailPanel then M:RefreshMailPanel() end
end

local function RecordInvoice(i)
	if not GetInboxInvoiceInfo then return end
	local kind, itemName, _, bid, _, _, _, _, _, _, count = GetInboxInvoiceInfo(i)
	kind, itemName, bid, count = Plain(kind), Plain(itemName), Plain(bid), Plain(count)
	if type(bid) ~= "number" or bid <= 0 then return end
	if kind == "seller" then
		M:RecordLedger("sale", itemName, count or 1, bid)
	elseif kind == "buyer" then
		M:RecordLedger("buy", itemName, count or 1, bid)
	end
end

function M:OpenNextMail()
	if not opener or opener.waiting then return end
	local total = Plain(GetInboxNumItems()) or 0
	for i = 1, total do
		local _, _, sender, subject, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(i)
		money, cod, itemCount = Plain(money) or 0, Plain(cod) or 0, Plain(itemCount) or 0
		local key = tostring(Plain(sender)) .. "|" .. tostring(Plain(subject)) .. "|" .. money .. "|" .. itemCount
		local tries = opener.tries[key] or 0
		if cod == 0 and not Plain(isGM) and (money > 0 or itemCount > 0) and tries < 3 then
			if itemCount > 0 and FreeBagSlots() == 0 then StopOpening("Bags full:"); return end
			opener.tries[key] = tries + 1
			if tries == 0 then
				RecordInvoice(i)
				opener.taken = opener.taken + 1
				opener.money = opener.money + money
			end
			opener.waiting = true
			if itemCount > 0 then AutoLootMailItem(i) else TakeInboxMoney(i) end
			local asked = opener
			C_Timer.After(2, function()
				if opener == asked and opener.waiting then opener.waiting = false; M:OpenNextMail() end
			end)
			return
		end
	end
	StopOpening()
end

function M:OpenAllMail()
	if opener then StopOpening("Stopped:"); return end
	if InCombatLockdown() then Say("not in combat."); return end
	opener = { taken = 0, money = 0, tries = {} }
	self:RefreshMailPanel()
	self:OpenNextMail()
end

function M:OnInboxUpdate()
	if opener and opener.waiting then
		opener.waiting = false
		C_Timer.After(0.15, function() if opener and not opener.waiting then M:OpenNextMail() end end)
	end
end

local panel

function M:RefreshMailPanel()
	if not panel or not panel:IsShown() then return end
	if run then
		local left = 0
		for _, n in ipairs(run.needs) do left = left + math.max(n.count, 0) end
		UI.ButtonText(panel.send, run.waiting and "Sending..." or run.stalled and "No answer: send next" or "Sending...")
		panel.status:SetText(string.format("%d mail(s) sent, %d item(s) to go.", run.mails, left))
	else
		UI.ButtonText(panel.send, "Send Groups")
		panel.status:SetText("")
	end
	UI.ButtonText(panel.open, opener and "Stop Opening" or "Open All")

	local needs = run and run.needs or self:MailNeeds()
	local byTo, order = {}, {}
	for _, n in ipairs(needs) do
		if n.count > 0 then
			if not byTo[n.to] then byTo[n.to] = {}; order[#order + 1] = n.to end
			table.insert(byTo[n.to], n)
		end
	end
	local lines = {}
	for _, to in ipairs(order) do
		lines[#lines + 1] = { header = to }
		for _, n in ipairs(byTo[to]) do lines[#lines + 1] = n end
	end
	panel.list:SetItems(lines)
	panel.empty:SetShown(#lines == 0)
end

function M:BuildMailPanel()
	if panel or not MailFrame then return end
	panel = UI.Panel(MailFrame, "surface", 6)
	panel:SetSize(250, 420)
	panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
	panel:EnableMouse(true)
	local title = UI.Text(panel, "body/bold/small", "accent")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("K-Market")
	panel.send = UI.Button(panel, "Send Groups", 108, 24, "primary", "KainUIForeverMarketMailButton")
	panel.send:SetPoint("TOPLEFT", 12, -32)
	panel.send:SetScript("OnClick", function() M:StartMailing() end)
	panel.send.kmTip = "Mails your groups' items to the bank alt or crafter their operations name."
	panel.open = UI.Button(panel, "Open All", 108, 24, "secondary", "KainUIForeverMarketOpenAllButton")
	panel.open:SetPoint("TOPRIGHT", -12, -32)
	panel.open:SetScript("OnClick", function() M:OpenAllMail() end)
	panel.open.kmTip = "Takes everything out of your mail (not cash on delivery), and notes Auction House sales and purchases for the K-Market dashboard."
	panel.status = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.status:SetPoint("TOPLEFT", 12, -62)
	local sub = UI.Text(panel, "body/medium/x-small", "textLow")
	sub:SetPoint("TOPLEFT", 12, -80)
	sub:SetText("TO SEND")
	panel.empty = UI.Text(panel, "body/regular/x-small", "textLow")
	panel.empty:SetPoint("TOPLEFT", 12, -100)
	panel.empty:SetWidth(226)
	panel.empty:SetWordWrap(true)
	panel.empty:SetText("Nothing: give a group a Mailing or Crafter operation in K-Market and have its items in your bags.")
	panel.list = UI.List(panel, 20, 15, function(row)
		row.text = UI.Text(row, "body/regular/x-small", "text")
		row.text:SetPoint("LEFT", 12, 0)
		row.text:SetPoint("RIGHT", -50, 0)
		row.count = UI.Text(row, "numeric/regular/x-small", "textLow", "RIGHT")
		row.count:SetPoint("RIGHT", -12, 0)
	end, function(row, item)
		if item.header then
			row.text:SetText(UI.Colorize(item.header, "accent"))
			row.count:SetText("")
		else
			row.text:SetText("  " .. M.ItemName(item.itemID))
			row.count:SetText("x" .. item.count)
		end
	end)
	panel.list:SetPoint("TOPLEFT", 0, -96)
	panel.list:SetPoint("TOPRIGHT", 0, -96)
	panel.list:SetHeight(300)
	panel:SetScript("OnShow", function() M:RefreshMailPanel() end)
	M.mailPanel = panel
	self:RefreshMailPanel()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "MAIL_SHOW", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED", "BAG_UPDATE_DELAYED" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event)
	if event == "MAIL_SHOW" then
		if MailFrame then
			M:BuildMailPanel()
		else
			C_Timer.After(0.1, function() M:BuildMailPanel() end)
		end
		M:RecordInventory(false)
		if panel then panel:Show(); M:RefreshMailPanel() end
	elseif event == "MAIL_SEND_SUCCESS" then
		OnSent()
	elseif event == "MAIL_FAILED" then
		if run then Finish("Stopped (the mail was refused). Sent") end
	elseif event == "MAIL_CLOSED" then
		if run then Finish("Mailbox closed. Sent") end
		if opener then StopOpening("Mailbox closed:") end
	elseif event == "BAG_UPDATE_DELAYED" then
		if not run then M:RefreshMailPanel() end
	end
end)
