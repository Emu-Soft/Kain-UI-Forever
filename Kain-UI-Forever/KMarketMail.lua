local _, KUI = ...
local M = KUI.Market
local Plain, Say = M.Plain, M.Say

local SEND_TIMEOUT = 10
local CONFIRM_TIMEOUT = 60
local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12

local function IsMe(to)
	local key, name, realm = M:Me()
	if not to or not name then return true end
	local want = to:match("^%s*(.-)%s*$"):gsub("%s+", " "):lower()
	local me = { name = name, realm = realm, surname = M:MySurname() }
	for _, form in ipairs(M.NameForms(me)) do
		if form == want then return true end
	end
	return key ~= nil and key:lower() == want
end
M.IsMe = IsMe

function M:MailTargets()
	local seen, list = {}, {}
	for name, op in pairs(self:DB().ops) do
		if (op.kind == "mail" or op.kind == "crafter") and #self:OpGroups(name) > 0 then
			local to = self:Recipient(op)
			if to and not IsMe(to) and not seen[to:lower()] then
				seen[to:lower()] = true
				list[#list + 1] = to
			end
		end
	end
	table.sort(list)
	return list
end

local befriended = {}
function M:BefriendAlt(to)
	if type(to) ~= "string" or IsMe(to) or befriended[to:lower()] then return end
	if not C_FriendList or not C_FriendList.AddFriend or not C_FriendList.GetFriendInfo then return end
	local key = self:CharKeyFor(to)
	local c = key and self:DB().chars[key]
	if not c then return end
	local mine = Plain((UnitFactionGroup("player")))
	if c.faction and mine and c.faction ~= mine then return end

	if not c.surname and self:MySurname() then return end
	befriended[to:lower()] = true
	to = M.MailName(c, select(3, self:Me())) or to
	if Plain(C_FriendList.GetFriendInfo(to)) then return end
	local count = C_FriendList.GetNumFriends and Plain(C_FriendList.GetNumFriends()) or 0
	if count >= 100 then return end

	C_FriendList.AddFriend(to, "K-Market: my alt")
end

function M:BefriendAlts()
	for _, to in ipairs(self:MailTargets()) do self:BefriendAlt(to) end
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
	run.waiting, run.sentAt, run.to, run.attached, run.confirming = true, GetTime(), to, list, nil
	local subject = (KUI.GetMailAutoSubject and KUI:GetMailAutoSubject()) or "K-Market"
	SendMail(to, subject, "")
	if self.RefreshMailPanel then self:RefreshMailPanel() end

	local asked = run
	local function Check()
		if run ~= asked or not run.waiting then return end
		local limit = run.confirming and CONFIRM_TIMEOUT or SEND_TIMEOUT
		if GetTime() - run.sentAt >= limit - 0.01 then
			run.waiting = false
			run.stalled = true
			if M.RefreshMailPanel then M:RefreshMailPanel() end
		else
			C_Timer.After(1, Check)
		end
	end
	C_Timer.After(1, Check)
end

function M:StartMailing()
	if run then
		if not run.waiting then run.stalled = nil; self:SendNextMail() end
		return
	end
	if InCombatLockdown() then Say("not in combat."); return end
	if Attachments() > 0 then Say("take the attachments off the mail first."); return end
	if SetSendMailShowing then SetSendMailShowing(true) end
	self:BefriendAlts()
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
	if M.RefreshMailPanel then M:RefreshMailPanel() end
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
				if opener == asked and opener.waiting and not opener.confirming then opener.waiting = false; M:OpenNextMail() end
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
	if self.RefreshMailPanel then self:RefreshMailPanel() end
	self:OpenNextMail()
end

function M:OnInboxUpdate()
	if opener and opener.waiting then
		opener.waiting, opener.confirming = false, nil
		C_Timer.After(0.15, function() if opener and not opener.waiting then M:OpenNextMail() end end)
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED",
	"SECURE_TRANSFER_CONFIRM_SEND_MAIL", "SECURE_TRANSFER_CONFIRM_TAKE_MAIL_MONEY" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(8, function() M:BefriendAlts() end)
	elseif event == "MAIL_SHOW" then
		M:RecordInventory(false)
		M:BefriendAlts()
	elseif event == "MAIL_SEND_SUCCESS" then
		OnSent()
	elseif event == "MAIL_FAILED" then
		if run then Finish("Stopped (the mail was refused). Sent") end
	elseif event == "MAIL_CLOSED" then
		if run then Finish("Mailbox closed. Sent") end
		if opener then StopOpening("Mailbox closed:") end
	elseif event == "SECURE_TRANSFER_CONFIRM_SEND_MAIL" then
		if run and run.waiting then
			run.confirming = true
			if M.RefreshMailPanel then M:RefreshMailPanel() end
		end
	elseif event == "SECURE_TRANSFER_CONFIRM_TAKE_MAIL_MONEY" then

		if opener then opener.confirming = true end
	end
end)
