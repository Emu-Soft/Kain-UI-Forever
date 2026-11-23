local _, KUI = ...
local M = KUI.Market
if not M then return end

local W, H = 680, 470
local DAY = 86400
local COLUMNS = 120
local GRAPH_W, GRAPH_H = 600, 250
local ICON, ICON_COLS, ICON_ROWS = 34, 11, 5
local LIST_ROWS = 13

local RANGES = {
	{ key = "day", label = "Day", span = DAY },
	{ key = "week", label = "Week", span = 7 * DAY },
	{ key = "month", label = "Month", span = 30 * DAY },
	{ key = "all", label = "All" },
}

local frame
local pages, tabs = {}, {}
local refreshers = {}
local state = { tab = "gold", range = "week", char = nil, group = nil, op = nil, groupOffset = 0, opOffset = 0, itemOffset = 0 }
M.windowState = state

local function Now() return M.clock and M.clock() or time() end

local function Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, h or 22)
	b:SetText(text)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", onClick)
	return b
end

local function Label(parent, text, template)
	local t = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	t:SetText(text or "")
	t:SetJustifyH("LEFT")
	return t
end

local function EditBox(parent, w)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return e
end

local function ConfirmButton(parent, text, w, onConfirm)
	local armed
	local b
	b = Button(parent, text, w, 22, function()
		if armed and GetTime() - armed < 3 then
			armed = nil
			b:SetText(text)
			onConfirm()
		else
			armed = GetTime()
			b:SetText("Sure?")
			C_Timer.After(3, function() armed = nil; b:SetText(text) end)
		end
	end)
	return b
end

local function Refresh()
	if not frame or not frame:IsShown() then return end
	for _, fn in ipairs(refreshers) do fn() end
end
M.RefreshWindow = function() Refresh() end

local function ItemIcon(id)
	local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
	if not icon and GetItemInfoInstant then icon = select(5, GetItemInfoInstant(id)) end
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function CharLabel(key)
	if not key then return "All characters" end
	return (key:gsub("%-", " - ", 1))
end

local function BuildGold(page)
	local x = 16
	local rangeButtons = {}
	for _, r in ipairs(RANGES) do
		local b = Button(page, r.label, 64, 22, function() state.range = r.key; Refresh() end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", x, -8)
		rangeButtons[r.key] = b
		x = x + 68
	end
	local charButton = Button(page, "All characters", 210, 22, function(_, mouse)
		local list = M:GoldCharacters()
		if mouse == "RightButton" then state.char = nil; Refresh(); return end
		local idx = 0
		for i, k in ipairs(list) do if k == state.char then idx = i end end
		state.char = list[idx + 1]
		Refresh()
	end)
	charButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -8)

	local summary = Label(page, "", "GameFontNormal")
	summary:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -40)

	local graph = CreateFrame("Frame", "KainUIForeverMarketGraph", page)
	graph:SetSize(GRAPH_W, GRAPH_H)
	graph:SetPoint("TOPLEFT", page, "TOPLEFT", 60, -66)
	graph:EnableMouse(true)
	local bg = graph:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(graph)
	bg:SetColorTexture(1, 1, 1, 0.05)
	local colW = GRAPH_W / COLUMNS
	local bars, caps = {}, {}
	for i = 1, COLUMNS do
		local bar = graph:CreateTexture(nil, "ARTWORK")
		bar:SetColorTexture(1, 0.82, 0, 0.35)
		bar:SetWidth(colW)
		bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * colW, 0)
		local cap = graph:CreateTexture(nil, "OVERLAY")
		cap:SetColorTexture(1, 0.85, 0.2, 1)
		cap:SetSize(colW, 2)
		bars[i], caps[i] = bar, cap
	end
	local highText = Label(page, "")
	highText:SetPoint("TOPRIGHT", graph, "TOPLEFT", -4, 0)
	local lowText = Label(page, "")
	lowText:SetPoint("BOTTOMRIGHT", graph, "BOTTOMLEFT", -4, 0)
	local fromText = Label(page, "")
	fromText:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", 0, -4)
	local toText = Label(page, "")
	toText:SetPoint("TOPRIGHT", graph, "BOTTOMRIGHT", 0, -4)
	local empty = Label(page, "No gold readings yet for this range.", "GameFontDisable")
	empty:SetPoint("CENTER", graph, "CENTER")

	local shown = {}
	local function Range()
		local now = Now()
		for _, r in ipairs(RANGES) do
			if r.key == state.range then
				if r.span then return now - r.span, now end
			end
		end
		local first = now
		local db = M:DB()
		for _, key in ipairs(state.char and { state.char } or M:GoldCharacters()) do
			local c = db.gold[key]
			local p = c and c.points[1]
			if p and p[1] < first then first = p[1] end
		end
		return math.min(first, now - 3600), now
	end

	table.insert(refreshers, function()
		if state.tab ~= "gold" then return end
		if state.char and not M:DB().gold[state.char] then state.char = nil end
		for key, b in pairs(rangeButtons) do b:SetEnabled(key ~= state.range) end
		charButton:SetText(CharLabel(state.char))
		local from, to = Range()
		local values, low, high = M:Series(state.char and { state.char } or nil, from, to, COLUMNS)
		shown.values, shown.from, shown.to = values, from, to
		empty:SetShown(low == nil)
		if not low then
			for i = 1, COLUMNS do bars[i]:Hide(); caps[i]:Hide() end
			summary:SetText("")
			highText:SetText(""); lowText:SetText(""); fromText:SetText(""); toText:SetText("")
			return
		end
		local pad = math.max((high - low) * 0.1, 10000)
		local bottom = math.max(0, low - pad)
		local top = high + pad
		for i = 1, COLUMNS do
			local v = values[i]
			if v then
				local h = math.max(1, (v - bottom) / (top - bottom) * GRAPH_H)
				bars[i]:SetHeight(h)
				bars[i]:Show()
				caps[i]:ClearAllPoints()
				caps[i]:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * colW, h - 1)
				caps[i]:Show()
			else
				bars[i]:Hide(); caps[i]:Hide()
			end
		end
		local firstValue
		for i = 1, COLUMNS do if values[i] then firstValue = values[i]; break end end
		local last = values[COLUMNS] or 0
		local change = last - (firstValue or last)
		summary:SetText(string.format("%s: %s    Change: %s%s", CharLabel(state.char), M.FormatMoney(last),
			change >= 0 and "|cff40ff40+" or "|cffff5050", M.FormatMoney(change) .. "|r"))
		highText:SetText(M.FormatMoney(top, true))
		lowText:SetText(M.FormatMoney(bottom, true))
		local fmt = (to - from > 2 * DAY) and "%d %b" or "%H:%M"
		fromText:SetText(date(fmt, from))
		toText:SetText(date(fmt, to))
	end)

	graph:SetScript("OnUpdate", function(self)
		if not self:IsMouseOver() or not shown.values then
			if self.tipShown then GameTooltip:Hide(); self.tipShown = nil end
			return
		end
		local cx = GetCursorPosition() / self:GetEffectiveScale()
		local i = math.floor((cx - self:GetLeft()) / colW) + 1
		i = math.max(1, math.min(COLUMNS, i))
		local v = shown.values[i]
		local t = shown.from + (shown.to - shown.from) * (i - 1) / (COLUMNS - 1)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetText(date("%d %b %H:%M", t), 1, 1, 1)
		GameTooltip:AddLine(v and M.FormatMoney(v) or "no reading", 1, 0.82, 0)
		GameTooltip:Show()
		self.tipShown = true
	end)
end

local function BuildList(page, x, y, width, names, getSelected, pick, offsetKey, labelOf)
	local rows = {}
	local holder = CreateFrame("Frame", nil, page)
	holder:SetSize(width, LIST_ROWS * 22)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	holder:EnableMouseWheel(true)
	for i = 1, LIST_ROWS do
		local r = CreateFrame("Button", nil, holder)
		r:SetSize(width, 20)
		r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * 22)
		local hl = r:CreateTexture(nil, "BACKGROUND")
		hl:SetAllPoints(r)
		hl:SetColorTexture(1, 0.82, 0, 0.25)
		r.hl = hl
		r.text = Label(r, "", "GameFontHighlight")
		r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
		r:SetScript("OnClick", function(self) if self.name then pick(self.name); Refresh() end end)
		rows[i] = r
	end
	holder:SetScript("OnMouseWheel", function(_, delta)
		state[offsetKey] = math.max(0, math.min(#names() - LIST_ROWS, state[offsetKey] - delta))
		Refresh()
	end)
	return function()
		local list = names()
		state[offsetKey] = math.max(0, math.min(state[offsetKey], #list - LIST_ROWS))
		for i, r in ipairs(rows) do
			local name = list[i + state[offsetKey]]
			r.name = name
			r.text:SetText(name and (labelOf and labelOf(name) or name) or "")
			r:SetShown(name ~= nil)
			r.hl:SetShown(name ~= nil and name == getSelected())
		end
	end
end

local function BuildGroups(page)
	local nameBox = EditBox(page, 180)
	nameBox:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -10)
	local function Typed() return nameBox:GetText() end
	local newB = Button(page, "New", 60, 22, function()
		local ok, name = M:NewGroup(Typed())
		if ok then state.group = name; nameBox:SetText(""); nameBox:ClearFocus() end
		Refresh()
	end)
	newB:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -34)
	local renameB = Button(page, "Rename", 64, 22, function()
		if state.group then
			local ok, name = M:RenameGroup(state.group, Typed())
			if ok then state.group = name; nameBox:SetText(""); nameBox:ClearFocus() end
		end
		Refresh()
	end)
	renameB:SetPoint("LEFT", newB, "RIGHT", 2, 0)
	local deleteB = ConfirmButton(page, "Delete", 60, function()
		if state.group then M:DeleteGroup(state.group); state.group = nil end
		Refresh()
	end)
	deleteB:SetPoint("LEFT", renameB, "RIGHT", 2, 0)

	local refreshList = BuildList(page, 16, -64, 190, function() return M:GroupNames() end,
		function() return state.group end, function(name) state.group = name; state.itemOffset = 0 end, "groupOffset")

	local title = Label(page, "", "GameFontNormal")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 222, -10)

	local grid = CreateFrame("Button", "KainUIForeverMarketItemGrid", page)
	grid:SetSize(ICON_COLS * (ICON + 4), ICON_ROWS * (ICON + 4))
	grid:SetPoint("TOPLEFT", page, "TOPLEFT", 222, -32)
	grid:EnableMouseWheel(true)
	local gbg = grid:CreateTexture(nil, "BACKGROUND")
	gbg:SetAllPoints(grid)
	gbg:SetColorTexture(1, 1, 1, 0.04)
	local hint = Label(grid, "Drop items here to add them. Right-click an item to take it out.", "GameFontDisable")
	hint:SetPoint("CENTER", grid, "CENTER")
	local function TakeCursorItem()
		local kind, id = GetCursorInfo()
		if kind == "item" and state.group then
			M:AddItem(state.group, id)
			ClearCursor()
			Refresh()
		end
	end
	grid:SetScript("OnReceiveDrag", TakeCursorItem)
	grid:SetScript("OnMouseUp", TakeCursorItem)
	local icons = {}
	for i = 1, ICON_COLS * ICON_ROWS do
		local b = CreateFrame("Button", nil, grid)
		b:SetSize(ICON, ICON)
		local col, row = (i - 1) % ICON_COLS, math.floor((i - 1) / ICON_COLS)
		b:SetPoint("TOPLEFT", grid, "TOPLEFT", 2 + col * (ICON + 4), -2 - row * (ICON + 4))
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(self, mouse)
			if GetCursorInfo() then TakeCursorItem() return end
			if mouse == "RightButton" and self.itemID and state.group then
				M:RemoveItem(state.group, self.itemID)
				Refresh()
			end
		end)
		b:SetScript("OnReceiveDrag", TakeCursorItem)
		b:SetScript("OnEnter", function(self)
			if not self.itemID then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetText("Item " .. self.itemID) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		icons[i] = b
	end
	grid:SetScript("OnMouseWheel", function(_, delta)
		state.itemOffset = math.max(0, state.itemOffset - delta * ICON_COLS)
		Refresh()
	end)

	local pasteBox = EditBox(page, 300)
	pasteBox:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 6, -10)
	local status = Label(page, "")
	status:SetPoint("TOPLEFT", pasteBox, "BOTTOMLEFT", -6, -6)
	local importB = Button(page, "Import", 64, 22, function()
		if not state.group then return end
		local n = M:ImportItems(state.group, pasteBox:GetText())
		status:SetText(n .. " item(s) added.")
		pasteBox:SetText("")
		pasteBox:ClearFocus()
		Refresh()
	end)
	importB:SetPoint("LEFT", pasteBox, "RIGHT", 6, 0)
	local exportB = Button(page, "Export", 64, 22, function()
		if not state.group then return end
		pasteBox:SetText(M:ExportItems(state.group))
		pasteBox:SetFocus()
		pasteBox:HighlightText()
		status:SetText("Copy the list with Ctrl+C.")
	end)
	exportB:SetPoint("LEFT", importB, "RIGHT", 2, 0)

	local opButtons = {}
	local prev
	for _, kind in ipairs(M.KINDS) do
		local b = Button(page, "", 140, 22, function(_, mouse)
			local g = state.group and M:DB().groups[state.group]
			if not g then return end
			if mouse == "RightButton" then M:AssignOp(state.group, kind, nil); Refresh(); return end
			local list = M:OpNames(kind)
			local idx = 0
			for i, n in ipairs(list) do if n == g.ops[kind] then idx = i end end
			M:AssignOp(state.group, kind, list[idx + 1])
			Refresh()
		end)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10) end
		prev = b
		opButtons[kind] = b
	end

	table.insert(refreshers, function()
		if state.tab ~= "groups" then return end
		if state.group and not M:DB().groups[state.group] then state.group = nil end
		refreshList()
		local g = state.group and M:DB().groups[state.group]
		local items = g and M:GroupItems(state.group) or {}
		title:SetText(g and (state.group .. "  (" .. #items .. " item" .. (#items == 1 and "" or "s") .. ")") or "Make or pick a group on the left.")
		local maxOffset = math.max(0, math.ceil(#items / ICON_COLS) - ICON_ROWS) * ICON_COLS
		state.itemOffset = math.max(0, math.min(state.itemOffset, maxOffset))
		for i, b in ipairs(icons) do
			local id = items[i + state.itemOffset]
			b.itemID = id
			if id then b.icon:SetTexture(ItemIcon(id)) end
			b:SetShown(id ~= nil)
		end
		hint:SetShown(g ~= nil and #items == 0)
		grid:SetShown(g ~= nil)
		renameB:SetEnabled(g ~= nil)
		deleteB:SetEnabled(g ~= nil)
		for _, w in ipairs({ pasteBox, importB, exportB }) do w:SetShown(g ~= nil) end
		for kind, b in pairs(opButtons) do
			b:SetShown(g ~= nil)
			b:SetText(M.KIND_LABEL[kind] .. ": " .. ((g and g.ops[kind]) or "none"))
		end
		if not g then status:SetText("") end
	end)
end

local DURATIONS = { [1] = "12 hours", [2] = "24 hours", [3] = "48 hours" }

local FIELDS = {
	mail = {
		{ key = "to", label = "Send to", kind = "text" },
		{ key = "keep", label = "Keep in bags", kind = "number" },
	},
	crafter = {
		{ key = "profession", label = "Profession", kind = "profession" },
		{ key = "to", label = "Send to (blank = your crafter)", kind = "text" },
		{ key = "keep", label = "Keep in bags", kind = "number" },
	},
	post = {
		{ key = "keep", label = "Keep in bags", kind = "number" },
		{ key = "duration", label = "Duration", kind = "duration" },
		{ key = "undercut", label = "Undercut by", kind = "money" },
		{ key = "minPrice", label = "Minimum price (each)", kind = "money" },
		{ key = "normalPrice", label = "Normal price (each)", kind = "money" },
	},
}
M.FIELDS = FIELDS

local function ShowField(op, f)
	local v = op[f.key]
	if f.kind == "money" then return M.FormatMoney(tonumber(v) or 0) end
	if f.kind == "number" then return tostring(tonumber(v) or 0) end
	if f.kind == "duration" then return DURATIONS[v] or DURATIONS[2] end
	if f.kind == "profession" then return (v ~= "" and v) or "pick one" end
	return v or ""
end

function M.ReadField(f, text)
	if f.kind == "money" then return M.ParseMoney(text) end
	if f.kind == "number" then
		local n = tonumber(text)
		return n and n >= 0 and math.floor(n) or nil
	end
	return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function BuildOps(page)
	local nameBox = EditBox(page, 180)
	nameBox:SetPoint("TOPLEFT", page, "TOPLEFT", 22, -10)
	local x = 16
	for _, kind in ipairs(M.KINDS) do
		local b = Button(page, "New " .. M.KIND_LABEL[kind], 62, 22, function()
			local ok, name = M:NewOp(nameBox:GetText(), kind)
			if ok then state.op = name; nameBox:SetText(""); nameBox:ClearFocus() end
			Refresh()
		end)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", x, -34)
		x = x + 64
	end
	local renameB = Button(page, "Rename", 94, 22, function()
		if state.op then
			local ok, name = M:RenameOp(state.op, nameBox:GetText())
			if ok then state.op = name; nameBox:SetText(""); nameBox:ClearFocus() end
		end
		Refresh()
	end)
	renameB:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -58)
	local deleteB = ConfirmButton(page, "Delete", 94, function()
		if state.op then M:DeleteOp(state.op); state.op = nil end
		Refresh()
	end)
	deleteB:SetPoint("LEFT", renameB, "RIGHT", 2, 0)

	local refreshList = BuildList(page, 16, -88, 190, function() return M:OpNames() end,
		function() return state.op end, function(name) state.op = name end, "opOffset",
		function(name) local op = M:DB().ops[name]; return "|cffffd100" .. M.KIND_LABEL[op.kind] .. "|r  " .. name end)

	local title = Label(page, "", "GameFontNormal")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 232, -10)
	local info = Label(page, "")
	info:SetPoint("TOPLEFT", page, "TOPLEFT", 232, -32)
	info:SetWidth(420)

	local rowsByKind = {}
	for kind, fields in pairs(FIELDS) do
		local rows = {}
		for i, f in ipairs(fields) do
			local y = -60 - (i - 1) * 32
			local label = Label(page, f.label)
			label:SetPoint("TOPLEFT", page, "TOPLEFT", 232, y - 4)
			local widget
			if f.kind == "profession" or f.kind == "duration" then
				widget = Button(page, "", 160, 22, function(_, mouse)
					local op = state.op and M:DB().ops[state.op]
					if not op then return end
					if f.kind == "duration" then
						op.duration = ((tonumber(op.duration) or 2) % 3) + 1
					else
						local list, idx = M.PROFESSIONS, 0
						for j, p in ipairs(list) do if p == op.profession then idx = j end end
						idx = mouse == "RightButton" and (idx - 2) % #list + 1 or idx % #list + 1
						op.profession = list[idx]
					end
					Refresh()
				end)
			else
				widget = EditBox(page, 150)
				local function Save(self)
					local op = state.op and M:DB().ops[state.op]
					if not op then return end
					local v = M.ReadField(f, self:GetText())
					if v ~= nil then op[f.key] = v end
					self:SetText(ShowField(op, f))
					Refresh()
				end
				widget:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
				widget:SetScript("OnEditFocusLost", Save)
			end
			widget:SetPoint("TOPLEFT", page, "TOPLEFT", 440, y)
			rows[i] = { field = f, label = label, widget = widget }
		end
		rowsByKind[kind] = rows
	end

	table.insert(refreshers, function()
		if state.tab ~= "ops" then return end
		if state.op and not M:DB().ops[state.op] then state.op = nil end
		refreshList()
		local op = state.op and M:DB().ops[state.op]
		renameB:SetEnabled(op ~= nil)
		deleteB:SetEnabled(op ~= nil)
		for kind, rows in pairs(rowsByKind) do
			for _, r in ipairs(rows) do
				local show = op ~= nil and op.kind == kind
				r.label:SetShown(show)
				r.widget:SetShown(show)
				if show and not (r.widget.HasFocus and r.widget:HasFocus()) then r.widget:SetText(ShowField(op, r.field)) end
			end
		end
		if not op then
			title:SetText("Make or pick an operation on the left.")
			info:SetText("Type a name, then New Mail, New Crafter or New Post. Give it to groups on the Groups tab.")
			return
		end
		title:SetText(M.KIND_LABEL[op.kind] .. ": " .. state.op)
		local users = {}
		for _, gname in ipairs(M:GroupNames()) do
			if M:DB().groups[gname].ops[op.kind] == state.op then users[#users + 1] = gname end
		end
		local line = "Used by: " .. (#users > 0 and table.concat(users, ", ") or "no groups yet")
		if op.kind == "crafter" then
			local to = M:Recipient(op)
			line = line .. "\nGoes to: " .. (to or ("none of your characters has " .. ((op.profession ~= "" and op.profession) or "that profession") .. " yet (log in on them once)"))
		elseif op.kind == "post" then
			line = line .. "\nPosts at the lowest price minus the undercut, never under the minimum, and at the normal price when nothing is up."
		end
		info:SetText(line)
	end)
end

local function ShowTab(key)
	state.tab = key
	for k, p in pairs(pages) do p:SetShown(k == key) end
	for k, t in pairs(tabs) do t:SetEnabled(k ~= key) end
	Refresh()
end

local function Build()
	frame = CreateFrame("Frame", "KainUIForeverMarketFrame", UIParent, "BackdropTemplate")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()
	table.insert(UISpecialFrames, "KainUIForeverMarketFrame")
	if KUI.DressOptionsPanel then
		KUI.DressOptionsPanel(frame, "KainUIForeverMarketCloseGem")
	else
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(frame)
		bg:SetColorTexture(0, 0, 0, 0.85)
		local close = Button(frame, "X", 24, 22, function() frame:Hide() end)
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
	end
	local titleText = Label(frame, "K-Market", "GameFontNormalLarge")
	titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)

	local x = 130
	for _, t in ipairs({ { "gold", "Gold" }, { "groups", "Groups" }, { "ops", "Operations" } }) do
		local b = Button(frame, t[2], 96, 22, function() ShowTab(t[1]) end)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -12)
		tabs[t[1]] = b
		x = x + 100
		local page = CreateFrame("Frame", nil, frame)
		page:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -44)
		page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		pages[t[1]] = page
	end
	BuildGold(pages.gold)
	BuildGroups(pages.groups)
	BuildOps(pages.ops)
	frame:SetScript("OnShow", function() M:RecordMoney(); ShowTab(state.tab) end)
end

function M:ToggleWindow(tab)
	if not frame then Build() end
	if tab then state.tab = tab end
	if frame:IsShown() and not tab then frame:Hide() else frame:Show(); ShowTab(state.tab) end
end
