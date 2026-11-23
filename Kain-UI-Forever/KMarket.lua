local _, KUI = ...
local M = {}
KUI.Market = M

local HOUR, DAY = 3600, 86400
local MERGE_SECONDS = 60
local SEND_TIMEOUT = 10
local KINDS = { "mail", "crafter", "post" }
M.KINDS = KINDS
local KIND_LABEL = { mail = "Mail", crafter = "Crafter", post = "Post" }
M.KIND_LABEL = KIND_LABEL

M.PROFESSIONS = { "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First Aid", "Fishing",
	"Herbalism", "Inscription", "Jewelcrafting", "Leatherworking", "Mining", "Skinning", "Tailoring" }
local IS_PROFESSION = {}
for _, p in ipairs(M.PROFESSIONS) do IS_PROFESSION[p] = true end

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

local function Say(msg)
	print("|cff33ff99K-Market:|r " .. msg)
end

local function Now() return M.clock and M.clock() or time() end

local function Sanitize(m)
	for _, k in ipairs({ "gold", "groups", "ops", "chars" }) do
		if type(m[k]) ~= "table" then m[k] = {} end
	end
	for key, c in pairs(m.gold) do
		if type(key) ~= "string" or type(c) ~= "table" or type(c.points) ~= "table" then
			m.gold[key] = nil
		else
			local good = {}
			for _, p in ipairs(c.points) do
				if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then good[#good + 1] = p end
			end
			c.points = good
		end
	end
	for name, g in pairs(m.groups) do
		if type(name) ~= "string" or type(g) ~= "table" then
			m.groups[name] = nil
		else
			if type(g.items) ~= "table" then g.items = {} end
			if type(g.ops) ~= "table" then g.ops = {} end
			for id in pairs(g.items) do if type(id) ~= "number" then g.items[id] = nil end end
		end
	end
	for name, op in pairs(m.ops) do
		if type(name) ~= "string" or type(op) ~= "table" or not KIND_LABEL[op.kind] then m.ops[name] = nil end
	end
	for key, c in pairs(m.chars) do
		if type(key) ~= "string" or type(c) ~= "table" then
			m.chars[key] = nil
		elseif type(c.professions) ~= "table" then
			c.professions = {}
		end
	end
	m.checked = true
end

function M:DB()
	local acct = _G.KainUIForeverAccountDB
	if type(acct) ~= "table" then acct = {}; _G.KainUIForeverAccountDB = acct end
	local m = acct.market
	if type(m) ~= "table" then m = {}; acct.market = m end
	if not m.checked then Sanitize(m) end
	return m
end

function M:Me()
	local name, realm = Plain(UnitName("player")), Plain(GetRealmName())
	if type(name) ~= "string" or name == "" or type(realm) ~= "string" then return nil end
	return name .. "-" .. realm, name, realm
end

function M:Thin(points, now)
	local out = {}
	for i, p in ipairs(points) do
		local age = now - p[1]
		local bucket = (age > 60 * DAY and DAY) or (age > 7 * DAY and HOUR) or nil
		local nxt = points[i + 1]
		if not (bucket and nxt and math.floor(nxt[1] / bucket) == math.floor(p[1] / bucket)) then
			out[#out + 1] = p
		end
	end
	return out
end

function M:RecordMoney()
	local key = self:Me()
	if not key then return end
	local copper = Plain(GetMoney())
	if type(copper) ~= "number" then return end
	local now = Now()
	local db = self:DB()
	local c = db.gold[key]
	if not c then c = { points = {} }; db.gold[key] = c end
	local _, class = UnitClass("player")
	c.class = Plain(class) or c.class
	local pts = c.points
	local last = pts[#pts]
	if last and last[2] == copper then return end
	if last and now - last[1] < MERGE_SECONDS then
		last[1], last[2] = now, copper
		local before = pts[#pts - 1]
		if before and before[2] == copper then pts[#pts] = nil end
	else
		pts[#pts + 1] = { now, copper }
	end
	if self.RefreshWindow then self:RefreshWindow() end
end

function M:GoldCharacters()
	local list = {}
	for key in pairs(self:DB().gold) do list[#list + 1] = key end
	table.sort(list)
	return list
end

local function ValueAt(points, t)
	local v
	for _, p in ipairs(points) do
		if p[1] > t then break end
		v = p[2]
	end
	return v
end

function M:Series(keys, from, to, columns)
	local db = self:DB()
	keys = keys or self:GoldCharacters()
	local values, low, high = {}, nil, nil
	for i = 1, columns do
		local t = from + (to - from) * (i - 1) / math.max(columns - 1, 1)
		local sum
		for _, key in ipairs(keys) do
			local c = db.gold[key]
			local v = c and ValueAt(c.points, t)
			if v then sum = (sum or 0) + v end
		end
		values[i] = sum
		if sum then
			low = math.min(low or sum, sum)
			high = math.max(high or sum, sum)
		end
	end
	return values, low, high
end

function M.FormatMoney(copper, short)
	local neg = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local gold = (BreakUpLargeNumbers and BreakUpLargeNumbers(g)) or tostring(g)
	local text
	if short then
		text = gold .. "g"
	elseif g > 0 then
		text = string.format("%sg %ds %dc", gold, s, c)
	elseif s > 0 then
		text = string.format("%ds %dc", s, c)
	else
		text = c .. "c"
	end
	return (neg and "-" or "") .. text
end

function M.ParseMoney(text)
	if type(text) ~= "string" then return nil end
	text = text:lower():gsub(",", "")
	if text:match("^%s*$") then return 0 end
	local plain = text:match("^%s*(%d+%.?%d*)%s*$")
	if plain then return math.floor(tonumber(plain) * 10000 + 0.5) end
	local total, any = 0, false
	for num, unit in text:gmatch("(%d+%.?%d*)%s*([gsc])") do
		total = total + tonumber(num) * ({ g = 10000, s = 100, c = 1 })[unit]
		any = true
	end
	local rest = text:gsub("%d+%.?%d*%s*[gsc]", ""):gsub("%s", "")
	if not any or rest ~= "" then return nil end
	return math.floor(total + 0.5)
end

local function CleanName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 40 then return nil end
	return name
end

function M:GroupNames()
	local list = {}
	for name in pairs(self:DB().groups) do list[#list + 1] = name end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function M:NewGroup(name)
	name = CleanName(name)
	local groups = self:DB().groups
	if not name or groups[name] then return false end
	groups[name] = { items = {}, ops = {} }
	return true, name
end

function M:RenameGroup(old, new)
	new = CleanName(new)
	local groups = self:DB().groups
	if not new or not groups[old] or groups[new] then return false end
	groups[new], groups[old] = groups[old], nil
	return true, new
end

function M:DeleteGroup(name)
	local groups = self:DB().groups
	if not groups[name] then return false end
	groups[name] = nil
	return true
end

function M:AddItem(group, itemID)
	local g = self:DB().groups[group]
	itemID = tonumber(itemID)
	if not g or not itemID or itemID <= 0 or itemID ~= math.floor(itemID) then return false end
	if g.items[itemID] then return false end
	g.items[itemID] = true
	return true
end

function M:RemoveItem(group, itemID)
	local g = self:DB().groups[group]
	if not g or not g.items[itemID] then return false end
	g.items[itemID] = nil
	return true
end

function M:GroupItems(group)
	local g = self:DB().groups[group]
	local list = {}
	if g then for id in pairs(g.items) do list[#list + 1] = id end end
	table.sort(list)
	return list
end

function M.ParseItemList(text)
	local ids, seen = {}, {}
	local function Add(id)
		id = tonumber(id)
		if id and id > 0 and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
	end
	if type(text) ~= "string" then return ids end
	local found = false
	for id in text:gmatch("item:(%d+)") do Add(id); found = true end
	for id in text:gsub("item:%d+", ""):gmatch("i:(%d+)") do Add(id); found = true end
	if not found and text:match("^[%d%s,;]+$") then
		for id in text:gmatch("%d+") do Add(id) end
	end
	return ids
end

function M:ImportItems(group, text)
	local added = 0
	for _, id in ipairs(M.ParseItemList(text)) do
		if self:AddItem(group, id) then added = added + 1 end
	end
	return added
end

function M:ExportItems(group)
	local parts = {}
	for _, id in ipairs(self:GroupItems(group)) do parts[#parts + 1] = "i:" .. id end
	return table.concat(parts, ",")
end

local OP_DEFAULTS = {
	mail = { to = "", keep = 0 },
	crafter = { profession = "", to = "", keep = 0 },

	post = { keep = 0, duration = 2, undercut = 100, minPrice = 0, normalPrice = 0 },
}

function M:OpNames(kind)
	local list = {}
	for name, op in pairs(self:DB().ops) do
		if not kind or op.kind == kind then list[#list + 1] = name end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function M:NewOp(name, kind)
	name = CleanName(name)
	local ops = self:DB().ops
	if not name or ops[name] or not OP_DEFAULTS[kind] then return false end
	local op = { kind = kind }
	for k, v in pairs(OP_DEFAULTS[kind]) do op[k] = v end
	ops[name] = op
	return true, name
end

function M:DeleteOp(name)
	local db = self:DB()
	if not db.ops[name] then return false end
	db.ops[name] = nil
	for _, g in pairs(db.groups) do
		for kind, opName in pairs(g.ops) do if opName == name then g.ops[kind] = nil end end
	end
	return true
end

function M:RenameOp(old, new)
	new = CleanName(new)
	local db = self:DB()
	if not new or not db.ops[old] or db.ops[new] then return false end
	db.ops[new], db.ops[old] = db.ops[old], nil
	for _, g in pairs(db.groups) do
		for kind, opName in pairs(g.ops) do if opName == old then g.ops[kind] = new end end
	end
	return true, new
end

function M:AssignOp(group, kind, opName)
	local db = self:DB()
	local g = db.groups[group]
	if not g or not KIND_LABEL[kind] then return false end
	if opName ~= nil then
		local op = db.ops[opName]
		if not op or op.kind ~= kind then return false end
	end
	g.ops[kind] = opName
	return true
end

function M:GroupOp(g, kind)
	local name = g.ops[kind]
	local op = name and self:DB().ops[name]
	if op and op.kind == kind then return op end
end

function M:RecordProfessions()
	local key, name, realm = self:Me()
	if not key then return end
	local found = {}
	if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
		for _, index in ipairs({ GetProfessions() }) do
			local prof = Plain((GetProfessionInfo(index)))
			if IS_PROFESSION[prof] then found[prof] = true end
		end
	end
	if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
		for i = 1, (Plain(GetNumSkillLines()) or 0) do
			local skill = Plain((GetSkillLineInfo(i)))
			if IS_PROFESSION[skill] then found[skill] = true end
		end
	end
	local db = self:DB()
	local c = db.chars[key] or {}
	c.name, c.realm, c.professions = name, realm, found
	db.chars[key] = c
end

local function RecipientFor(c, myRealm)
	if c.realm == myRealm then return c.name end
	return c.name .. "-" .. tostring(c.realm):gsub("%s", "")
end

function M:Recipient(op)
	if type(op.to) == "string" and op.to:match("%S") then return (op.to:gsub("%s", "")) end
	if op.kind ~= "crafter" or not IS_PROFESSION[op.profession] then return nil end
	local me, _, myRealm = self:Me()
	local best, bestKey
	for key, c in pairs(self:DB().chars) do
		if key ~= me and c.professions[op.profession] and type(c.name) == "string" then
			local better = not best or (c.realm == myRealm and best.realm ~= myRealm)
				or ((c.realm == myRealm) == (best.realm == myRealm) and key < bestKey)
			if better then best, bestKey = c, key end
		end
	end
	return best and RecipientFor(best, myRealm)
end

local function LastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

function M:ScanBags()
	local out = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
	for bag = 0, LastBag() do
		for slot = 1, (Plain(C_Container.GetContainerNumSlots(bag)) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and Plain(info.itemID)
			local count = info and Plain(info.stackCount)
			if type(id) == "number" and type(count) == "number" and not Plain(info.isBound) and not Plain(info.isLocked) then
				local e = out[id]
				if not e then e = { count = 0, slots = {} }; out[id] = e end
				e.count = e.count + count
				e.slots[#e.slots + 1] = { bag = bag, slot = slot, count = count }
			end
		end
	end
	return out
end

local function SameName(a, b) return type(a) == "string" and type(b) == "string" and a:lower() == b:lower() end

function M:BuildMailPlan()
	local _, myName, myRealm = self:Me()
	local bags = self:ScanBags()
	local taken = {}
	local per, order = {}, {}
	for _, gname in ipairs(self:GroupNames()) do
		local g = self:DB().groups[gname]
		for _, kind in ipairs({ "crafter", "mail" }) do
			local op = self:GroupOp(g, kind)
			local to = op and self:Recipient(op)
			local isMe = not to or SameName(to, myName) or (myName and SameName(to, myName .. "-" .. tostring(myRealm):gsub("%s", "")))
			if not isMe then
				for _, id in ipairs(self:GroupItems(gname)) do
					local e = bags[id]
					if e then
						local left = 0
						for _, s in ipairs(e.slots) do if not taken[s] then left = left + s.count end end
						local send = left - (tonumber(op.keep) or 0)
						for _, s in ipairs(e.slots) do
							if not taken[s] and s.count <= send then
								taken[s] = true
								send = send - s.count
								if not per[to] then per[to] = {}; order[#order + 1] = to end
								table.insert(per[to], { bag = s.bag, slot = s.slot, itemID = id, count = s.count })
							end
						end
					end
				end
			end
		end
	end
	local batches = {}
	local max = ATTACHMENTS_MAX_SEND or 12
	for _, to in ipairs(order) do
		local list = per[to]
		for i = 1, #list, max do
			local b = { to = to, slots = {} }
			for j = i, math.min(i + max - 1, #list) do b.slots[#b.slots + 1] = list[j] end
			batches[#batches + 1] = b
		end
	end
	return batches
end

local mailRun

local function MailButtonText()
	if not mailRun then return "K-Market: Send groups" end
	if mailRun.waiting then return "Sending " .. mailRun.i .. " of " .. #mailRun.batches .. "..." end
	return "Send next mail (" .. (#mailRun.batches - mailRun.i) .. " left)"
end

function M:RefreshMailButton()
	if self.mailButton then self.mailButton:SetText(MailButtonText()) end
end

local function FinishMail(why)
	if mailRun then
		Say(string.format("%s %d mail(s), %d stack(s).", why or "Sent", mailRun.mails, mailRun.items))
	end
	mailRun = nil
	M:RefreshMailButton()
end

function M:SendNextMail()
	if not mailRun then return end
	if InCombatLockdown() then Say("not in combat."); return end
	mailRun.i = mailRun.i + 1
	local b = mailRun.batches[mailRun.i]
	if not b then FinishMail(); return end
	local attached = 0
	for _, s in ipairs(b.slots) do
		local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
		if info and Plain(info.itemID) == s.itemID and not Plain(info.isLocked) then
			attached = attached + 1
			C_Container.PickupContainerItem(s.bag, s.slot)
			ClickSendMailItemButton(attached)
		end
	end
	ClearCursor()
	if attached == 0 then self:SendNextMail(); return end
	local subject = (KUI.GetMailAutoSubject and KUI:GetMailAutoSubject()) or "K-Market"
	mailRun.waiting, mailRun.sentAt, mailRun.pending = true, GetTime(), attached
	SendMail(b.to, subject, "")
	self:RefreshMailButton()
	C_Timer.After(SEND_TIMEOUT, function()
		if mailRun and mailRun.waiting and GetTime() - mailRun.sentAt >= SEND_TIMEOUT - 0.01 then
			mailRun.waiting = false
			mailRun.i = mailRun.i - 1
			M:RefreshMailButton()
		end
	end)
end

function M:StartMailing()
	if mailRun then
		if not mailRun.waiting then self:SendNextMail() end
		return
	end
	if InCombatLockdown() then Say("not in combat."); return end
	for i = 1, ATTACHMENTS_MAX_SEND or 12 do
		if HasSendMailItem(i) then Say("take the attachments off the mail first."); return end
	end
	local batches = self:BuildMailPlan()
	if #batches == 0 then Say("nothing to send: no group with a Mail or Crafter operation has items in your bags."); return end
	mailRun = { batches = batches, i = 0, mails = 0, items = 0 }
	self:SendNextMail()
end

local function OnMailEvent(event)
	if not mailRun then return end
	if event == "MAIL_SEND_SUCCESS" and mailRun.waiting then
		mailRun.waiting = false
		mailRun.mails = mailRun.mails + 1
		mailRun.items = mailRun.items + (mailRun.pending or 0)
		C_Timer.After(0.3, function() if mailRun and not mailRun.waiting then M:SendNextMail() end end)
	elseif event == "MAIL_FAILED" then
		FinishMail("Stopped (the mail was refused). Sent")
	elseif event == "MAIL_CLOSED" then
		FinishMail("Mailbox closed. Sent")
	end
end

function M:BuildMailButton()
	if self.mailButton or not SendMailFrame then return end
	local b = CreateFrame("Button", "KainUIForeverMarketMailButton", SendMailFrame, "UIPanelButtonTemplate")
	b:SetSize(170, 24)
	b:SetPoint("TOPLEFT", MailFrame or SendMailFrame, "TOPRIGHT", 6, -30)
	b:SetScript("OnClick", function() M:StartMailing() end)
	self.mailButton = b
	self:RefreshMailButton()
end

function M:PickPrice(op, lowest, ours)
	local min, normal = tonumber(op.minPrice) or 0, tonumber(op.normalPrice) or 0
	local price
	if not lowest then
		if normal <= 0 then return nil, "no auctions up and no normal price set" end
		price = normal
	elseif ours then
		price = lowest
	else
		price = lowest - (tonumber(op.undercut) or 0)
	end
	if price < min then return nil, "the going price is below your minimum" end
	price = math.floor(price / 100) * 100
	if price < 100 then return nil, "the price is under 1 silver" end
	return price
end

function M:BuildPostPlan()
	local bags = self:ScanBags()
	local queue, seen = {}, {}
	for _, gname in ipairs(self:GroupNames()) do
		local op = self:GroupOp(self:DB().groups[gname], "post")
		if op then
			for _, id in ipairs(self:GroupItems(gname)) do
				local e = bags[id]
				local quantity = e and (e.count - (tonumber(op.keep) or 0)) or 0
				if quantity > 0 and not seen[id] then
					seen[id] = true
					queue[#queue + 1] = { itemID = id, op = op, quantity = quantity, slots = e.slots }
				end
			end
		end
	end
	return queue
end

local postRun

local function ItemName(id)
	local name = C_Item and C_Item.GetItemInfo and Plain((C_Item.GetItemInfo(id)))
	return type(name) == "string" and name or ("item " .. id)
end

local function Entry() return postRun and postRun.queue[postRun.i] end

local function PostButtonText()
	local e = Entry()
	if postRun and postRun.phase == "confirm" then return "Confirm post" end
	if not e then return "K-Market: Post groups" end
	if postRun.phase == "waiting" then return "Scanning " .. ItemName(e.itemID) .. "..." end
	if postRun.phase == "post" then
		local n = postRun.commodity and e.quantity or e.slots[postRun.slot].count
		return "Post " .. ItemName(e.itemID) .. " x" .. n .. " at " .. M.FormatMoney(postRun.price)
	end
	return "Scan " .. ItemName(e.itemID) .. " (" .. postRun.i .. " of " .. #postRun.queue .. ")"
end

function M:RefreshPostButton()
	if self.postButton then self.postButton:SetText(PostButtonText()) end
end

local function NextItem()
	postRun.i = postRun.i + 1
	postRun.phase, postRun.price, postRun.slot = "scan", nil, 1
	postRun.left = Entry() and Entry().quantity
	if not Entry() then
		Say(string.format("Posted %d auction(s).", postRun.posted))
		postRun.done = true
	end
	M:RefreshPostButton()
end

local function SlotLocation(s)
	return ItemLocation and ItemLocation.CreateFromBagAndSlot and ItemLocation:CreateFromBagAndSlot(s.bag, s.slot)
end

local function FittingSlot(e, from)
	for j = from, #e.slots do
		if e.slots[j].count <= postRun.left then return j end
	end
end

function M:OnScanResult(lowest, ours)
	if not postRun or postRun.phase ~= "waiting" then return end
	local e = Entry()
	local price, why = self:PickPrice(e.op, lowest, ours)
	if not price then
		Say(ItemName(e.itemID) .. " skipped: " .. why .. ".")
		NextItem()
		return
	end
	if not postRun.commodity then
		postRun.slot = FittingSlot(e, 1)
		if not postRun.slot then
			Say(ItemName(e.itemID) .. " skipped: every stack is bigger than what's above your keep amount.")
			NextItem()
			return
		end
	end
	postRun.price, postRun.phase = price, "post"
	self:RefreshPostButton()
end

local function Scan()
	local e = Entry()
	local loc = SlotLocation(e.slots[1])
	local status = loc and C_AuctionHouse.GetItemCommodityStatus and C_AuctionHouse.GetItemCommodityStatus(loc)
	postRun.commodity = Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity
	postRun.key = (not postRun.commodity and loc and C_AuctionHouse.GetItemKeyFromItem and C_AuctionHouse.GetItemKeyFromItem(loc))
		or C_AuctionHouse.MakeItemKey(e.itemID)
	postRun.phase = "waiting"
	local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false } }
	C_AuctionHouse.SendSearchQuery(postRun.key, sorts, true)
	local asked = postRun
	C_Timer.After(5, function()
		if postRun == asked and postRun.phase == "waiting" and Entry() == e then M:OnScanResult(nil, false) end
	end)
end

local function Post()
	local e = Entry()
	local s = e.slots[postRun.slot]
	local loc = SlotLocation(s)
	local duration = tonumber(e.op.duration) or 2
	local ok, args
	if postRun.commodity then
		args = { loc, duration, e.quantity, postRun.price }
		ok = C_AuctionHouse.PostCommodity(unpack(args))
	else
		args = { loc, duration, s.count, nil, postRun.price * s.count }
		ok = C_AuctionHouse.PostItem(loc, duration, s.count, nil, postRun.price * s.count)
	end
	if not ok then
		Say(ItemName(e.itemID) .. " couldn't be posted.")
		NextItem()
		return
	end
	postRun.posted = postRun.posted + 1
	postRun.pending = { commodity = postRun.commodity, args = args }

	local nextSlot
	if not postRun.commodity then
		postRun.left = postRun.left - s.count
		nextSlot = FittingSlot(e, postRun.slot + 1)
	end
	if nextSlot then
		postRun.slot = nextSlot
		M:RefreshPostButton()
	else
		NextItem()
	end
end

function M:PostClick()
	if InCombatLockdown() then Say("not in combat."); return end
	if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then Say("the auction house can't be read."); return end
	if not postRun or (postRun.done and postRun.phase ~= "confirm") then
		local queue = self:BuildPostPlan()
		if #queue == 0 then Say("nothing to post: no group with a Post operation has items in your bags."); return end
		postRun = { queue = queue, i = 1, phase = "scan", slot = 1, posted = 0, left = queue[1].quantity }
	end
	if postRun.phase == "confirm" and postRun.pending then
		local p = postRun.pending
		if p.commodity then C_AuctionHouse.ConfirmPostCommodity(unpack(p.args)) else C_AuctionHouse.ConfirmPostItem(unpack(p.args, 1, 5)) end
		postRun.pending = nil
		postRun.phase = postRun.resumePhase or "scan"
		if postRun.done then postRun = nil end
	elseif postRun.phase == "scan" then
		Scan()
	elseif postRun.phase == "post" then
		Post()
	end
	self:RefreshPostButton()
end

local function FirstResult()
	local e = Entry()
	if not e or not postRun.key then return end
	if postRun.commodity then
		local r = C_AuctionHouse.GetCommoditySearchResultInfo and C_AuctionHouse.GetCommoditySearchResultInfo(e.itemID, 1)
		if r then return Plain(r.unitPrice), Plain(r.containsOwnerItem) end
	else
		local r = C_AuctionHouse.GetItemSearchResultInfo and C_AuctionHouse.GetItemSearchResultInfo(postRun.key, 1)
		if r then return Plain(r.buyoutAmount), Plain(r.containsOwnerItem) end
	end
end

local function OnAuctionEvent(event, arg)
	if event == "AUCTION_HOUSE_CLOSED" then
		postRun = nil
		return
	end
	if not postRun then return end
	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
		local e = Entry()
		if postRun.phase == "waiting" and e and (event == "COMMODITY_SEARCH_RESULTS_UPDATED") == (postRun.commodity and true or false) then
			if event == "COMMODITY_SEARCH_RESULTS_UPDATED" and arg ~= nil and arg ~= e.itemID then return end
			local price, ours = FirstResult()
			M:OnScanResult(type(price) == "number" and price or nil, ours and true or false)
		end
	elseif event == "AUCTION_HOUSE_POST_WARNING" and postRun.pending then
		postRun.resumePhase = postRun.phase
		postRun.phase = "confirm"
		M:RefreshPostButton()
	end
end

function M:BuildPostButton()
	if self.postButton or not AuctionHouseFrame then return end
	local b = CreateFrame("Button", "KainUIForeverMarketPostButton", AuctionHouseFrame, "UIPanelButtonTemplate")
	b:SetSize(230, 24)
	b:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, -30)
	b:SetScript("OnClick", function() M:PostClick() end)
	self.postButton = b
	self:RefreshPostButton()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LOGOUT", "SKILL_LINES_CHANGED", "MAIL_SHOW", "MAIL_SEND_SUCCESS",
	"MAIL_FAILED", "MAIL_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED",
	"ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_POST_WARNING" }) do
	KUI:SafeRegisterEvent(events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "PLAYER_LOGIN" then
		local db = M:DB()
		local now = Now()
		for _, c in pairs(db.gold) do c.points = M:Thin(c.points, now) end
		M:RecordProfessions()
		C_Timer.After(2, function() M:RecordMoney() end)
	elseif event == "PLAYER_MONEY" or event == "PLAYER_LOGOUT" then
		M:RecordMoney()
	elseif event == "SKILL_LINES_CHANGED" then
		M:RecordProfessions()
	elseif event == "MAIL_SHOW" then
		M:BuildMailButton()
	elseif event == "AUCTION_HOUSE_SHOW" then
		M:BuildPostButton()
		M:RefreshPostButton()
	elseif event:find("^MAIL_") then
		OnMailEvent(event)
	else
		OnAuctionEvent(event, arg)
	end
end)

SLASH_KAINUIMARKET1 = "/kmarket"
SlashCmdList["KAINUIMARKET"] = function() if M.ToggleWindow then M:ToggleWindow() end end
