local _, KUI = ...
local M = KUI.Market
local UI = M.UI
local C = UI.C

local W, H = 940, 680
local HEADER = 44
local DAY = 86400

local frame
local pages = {}
local state = { page = 1, group = nil, op = nil, zoomed = false }
M.windowState = state

local Now = M.Now

local function Settings()
	local db = M:DB()
	if type(db.dash) ~= "table" then db.dash = {} end
	local d = db.dash
	if type(d.unselected) ~= "table" then d.unselected = {} end
	if type(d.range) ~= "string" then d.range = "ALL" end
	return d
end
M.Settings = Settings

local function ItemName(id)
	local name = C_Item and C_Item.GetItemInfo and M.Plain((C_Item.GetItemInfo(id)))
	return type(name) == "string" and name or ("item " .. id)
end
M.ItemName = ItemName

local function ItemIcon(id)
	local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
M.ItemIcon = ItemIcon

local function ShortMoney(copper)
	if not copper then return "-" end
	local neg = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	local g, s = math.floor(copper / 10000), math.floor(copper / 100) % 100
	local gold = (BreakUpLargeNumbers and BreakUpLargeNumbers(g)) or tostring(g)
	local text
	if g > 0 then text = gold .. "g " .. s .. "s" elseif s > 0 then text = s .. "s" else text = (copper % 100) .. "c" end
	return (neg and "-" or "") .. text
end
M.ShortMoney = ShortMoney

local function Confirming(b, text, onConfirm)
	local armed
	b:SetScript("OnClick", function()
		if armed and GetTime() - armed < 3 then
			armed = nil
			UI.ButtonText(b, text)
			onConfirm()
		else
			armed = GetTime()
			UI.ButtonText(b, "Sure?")
			C_Timer.After(3, function() armed = nil; UI.ButtonText(b, text) end)
		end
	end)
end

local function Refresh()
	if not frame or not frame:IsShown() then return end
	frame.total:SetText(ShortMoney(M:GoldAt(nil, Now()) or 0))
	if M.RefreshTutorialButton then M:RefreshTutorialButton() end
	local page = pages[state.page]
	if page and page.Refresh then page:Refresh() end
end
function M:RefreshWindow() Refresh() end

local Y_LABEL_W, X_LABEL_H, X_LABEL_W = 48, 16, 48
local HOVER_TEXT_H, PLOT_TOP_MARGIN, EXTRA_HIT = 16, 4, 4
local HOVER_TEXT_W = 160
local LINE_THICKNESS, MAX_POINTS = 3, 300
local MIN_X_SPACING = X_LABEL_W * 1.5 + 8
local MIN_Y_SPACING = X_LABEL_H * 1.5 + 8
local GOLD = 10000

local function Scale(v, a, b, lo, hi)
	if b == a then return lo end
	return lo + (v - a) / (b - a) * (hi - lo)
end

local function CeilTo(v, step) return math.ceil(v / step) * step end
local function FloorTo(v, step) return math.floor(v / step) * step end

local function YRange(yMin, yMax, maxSteps)
	local minStep = math.max((yMax - yMin) / math.max(maxSteps, 1) / 10, yMax / 200)
	local step = GOLD
	while step < minStep do step = step * 10 end
	yMin = FloorTo(yMin, step)
	yMax = CeilTo(yMax + step / 3, step)
	if yMin == yMax then yMax = yMax + step end
	return yMin, yMax, step
end

local function YLines(yMin, yMax, step, height)
	local mult = { 1, 2, 5 }
	local i, scale = 1, 1
	local gap = step
	while (yMax - yMin) > 0 and gap / (yMax - yMin) * height < MIN_Y_SPACING do
		i = i + 1
		if i > 3 then i, scale = 1, scale * 10 end
		gap = step * mult[i] * scale
	end
	local list = {}
	local v = CeilTo(yMin, gap)
	while v <= yMax do
		list[#list + 1] = v
		v = v + gap
	end
	return list
end
M.GraphYRange, M.GraphYLines = YRange, YLines

local function XNext(t, suggested)
	local d = date("*t", t)
	if suggested > DAY * 14 then
		return time({ year = d.year, month = d.month + 1, day = 1, hour = 0 })
	elseif suggested > DAY / 6 then
		return time({ year = d.year, month = d.month, day = d.day + 1, hour = 0 })
	end
	return time({ year = d.year, month = d.month, day = d.day, hour = d.hour - d.hour % 2 + 2 })
end
local function XLabel(t, suggested)
	if suggested > DAY * 14 then return date("%b '%y", t) end
	if suggested > DAY * 2 then return date("%m/%d", t) end
	if suggested > DAY / 6 then return date("%a", t) end
	return date("%H:%M", t)
end
M.GraphXLabel = XLabel

local function NewGraph(parent, width, height)
	local g = { xs = {}, ys = {}, lines = {}, yLines = {}, xLabels = {}, yAxis = {}, xAxis = {} }
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	g.frame = f
	local plot = CreateFrame("Frame", nil, f)
	plot:SetPoint("BOTTOMLEFT", Y_LABEL_W, X_LABEL_H)
	plot:SetPoint("TOPRIGHT", -EXTRA_HIT, -HOVER_TEXT_H - PLOT_TOP_MARGIN)
	plot:SetHitRectInsets(-EXTRA_HIT, -EXTRA_HIT, 0, 0)
	plot:EnableMouse(true)
	g.plot = plot
	g.w, g.h = width - Y_LABEL_W - EXTRA_HIT, height - X_LABEL_H - HOVER_TEXT_H - PLOT_TOP_MARGIN

	plot.dot = plot:CreateTexture(nil, "OVERLAY", nil, 3)
	plot.dot:SetTexture(UI.DOT)
	plot.dot:SetSize(10, 10)
	UI.Tint(plot.dot, "accent")
	plot.dot:Hide()
	plot.hoverLine = plot:CreateTexture(nil, "ARTWORK", nil, 2)
	plot.hoverLine:SetWidth(1)
	UI.Fill(plot.hoverLine, "accent")
	plot.hoverLine:Hide()
	plot.hoverText = UI.Text(plot, "numeric/regular/x-small", "accent", "CENTER")
	plot.hoverText:SetHeight(HOVER_TEXT_H)
	plot.hoverText:Hide()
	plot.selection = plot:CreateTexture(nil, "ARTWORK", nil, 2)
	plot.selection:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.2)
	plot.selection:Hide()
	g.empty = UI.Text(plot, "body/regular/small", "textLow", "CENTER")
	g.empty:SetPoint("CENTER")
	g.empty:SetText("No gold recorded yet for these characters.")
	g.empty:Hide()

	function g:SetRange(xMin, xMax, step)
		self.xMin, self.xMax, self.step = xMin, math.max(xMax, xMin + 1), step
		self.zoomStart, self.zoomEnd = self.xMin, self.xMax
	end
	function g:SetZoom(a, b) self.zoomStart, self.zoomEnd = a, math.max(b, a + 1) end
	function g:GetZoom() return self.zoomStart, self.zoomEnd end

	function g:Compute()
		wipe(self.xs); wipe(self.ys); wipe(self.yAxis); wipe(self.xAxis)
		local a, b = self.zoomStart, self.zoomEnd
		local minStep = CeilTo((b - a) / math.min(self.w / 3, MAX_POINTS), self.step)
		local yMin, yMax = math.huge, -math.huge
		local x = a
		while true do
			local prev = self.xs[#self.xs]
			if not prev or x == b or (x - prev > minStep and b - x > minStep) then
				local y = self.valueFunc(x) or 0
				self.xs[#self.xs + 1] = x
				self.ys[#self.ys + 1] = y
				yMin, yMax = math.min(yMin, y), math.max(yMax, y)
			end
			if x >= b then break end
			x = math.min(x + minStep, b)
		end
		local step
		self.yMin, self.yMax, step = YRange(yMin, yMax, math.floor(self.h / MIN_Y_SPACING))
		for _, v in ipairs(YLines(self.yMin, self.yMax, step, self.h)) do self.yAxis[#self.yAxis + 1] = v end
		self.suggested = Scale(MIN_X_SPACING, 0, self.w, 0, b - a)
		local lastOffset = -math.huge
		local t = XNext(a, self.suggested)
		while t <= b do
			local off = Scale(t, a, b, 0, self.w)
			if off - lastOffset > MIN_X_SPACING then
				self.xAxis[#self.xAxis + 1] = t
				lastOffset = off
			end
			t = XNext(t, self.suggested)
		end
	end

	local function Line(layer)
		local l = plot:CreateLine(nil, layer)
		l:SetTexture(UI.LINE)
		return l
	end

	function g:Draw()
		self.drawn = false
		if not self.xMin or self.noData then
			for _, l in ipairs(self.lines) do l:Hide() end
			for _, l in ipairs(self.yLines) do l:Hide(); l.text:Hide() end
			for _, l in ipairs(self.xLabels) do l:Hide() end
			self.empty:Show()
			return
		end
		self.empty:Hide()
		self:Compute()

		for i, v in ipairs(self.yAxis) do
			local line = self.yLines[i]
			if not line then
				line = Line("BACKGROUND")
				line:SetThickness(1)
				UI.Tint(line, "outline")
				line.text = UI.Text(plot, "numeric/regular/x-small", "textLow", "RIGHT")
				line.text:SetSize(Y_LABEL_W, X_LABEL_H)
				self.yLines[i] = line
			end
			local off = Scale(v, self.yMin, self.yMax, 0, self.h)
			line:SetStartPoint("BOTTOMLEFT", plot, 0, off)
			line:SetEndPoint("BOTTOMLEFT", plot, self.w, off)
			line:Show()
			local shift = 0
			if X_LABEL_H / 2 > off then
				line.text:SetJustifyV("BOTTOM"); shift = X_LABEL_H / 2 - off
			elseif off + X_LABEL_H / 2 > self.h then
				line.text:SetJustifyV("TOP"); shift = self.h - off - X_LABEL_H / 2
			else
				line.text:SetJustifyV("MIDDLE")
			end
			line.text:ClearAllPoints()
			line.text:SetPoint("RIGHT", plot, "BOTTOMLEFT", -4, off + shift)
			line.text:SetText(M.FormatAxisGold(v))
			line.text:Show()
		end
		for i = #self.yAxis + 1, #self.yLines do self.yLines[i]:Hide(); self.yLines[i].text:Hide() end

		for i, t in ipairs(self.xAxis) do
			local label = self.xLabels[i]
			if not label then
				label = UI.Text(plot, "body/regular/x-small", "textLow", "CENTER")
				label:SetSize(X_LABEL_W, X_LABEL_H)
				label:SetJustifyV("TOP")
				self.xLabels[i] = label
			end
			local off = Scale(t, self.zoomStart, self.zoomEnd, 0, self.w)
			local shift = 0
			if X_LABEL_W / 2 > off then
				label:SetJustifyH("LEFT"); shift = X_LABEL_W / 2 - off
			elseif off + X_LABEL_W / 2 > self.w then
				label:SetJustifyH("RIGHT"); shift = self.w - off - X_LABEL_W / 2
			else
				label:SetJustifyH("CENTER")
			end
			label:ClearAllPoints()
			label:SetPoint("TOP", plot, "BOTTOMLEFT", off + shift, -6)
			label:SetText(XLabel(t, self.suggested))
			label:Show()
		end
		for i = #self.xAxis + 1, #self.xLabels do self.xLabels[i]:Hide() end

		local color
		if self.hovered then
			color = "accent"
		elseif self.ys[1] <= self.ys[#self.ys] then
			color = "positive"
		else
			color = "error"
		end
		self.color = color
		local px, py
		for i, x in ipairs(self.xs) do
			local cx = Scale(x, self.zoomStart, self.zoomEnd, 0, self.w)
			local cy = Scale(self.ys[i], self.yMin, self.yMax, 0, self.h)
			if i > 1 then
				local line = self.lines[i - 1]
				if not line then line = Line("ARTWORK"); self.lines[i - 1] = line end
				line:SetThickness(LINE_THICKNESS)
				line:SetStartPoint("BOTTOMLEFT", plot, px, py)
				line:SetEndPoint("BOTTOMLEFT", plot, cx, cy)
				UI.Tint(line, color)
				line:Show()
			end
			px, py = cx, cy
		end
		for i = #self.xs, #self.lines do self.lines[i]:Hide() end
		self.drawn = true
	end

	function g:Closest()
		local scale = plot:GetEffectiveScale() or 1
		local cx = GetCursorPosition() / scale
		local left, right = plot:GetLeft(), plot:GetRight()
		if not left or not right or right <= left then return nil end
		cx = math.max(left, math.min(right, cx))
		local t = Scale(cx, left, right, self.zoomStart, self.zoomEnd)
		local best
		for i, x in ipairs(self.xs) do
			if not best or math.abs(x - t) < math.abs(self.xs[best] - t) then best = i end
		end
		return best
	end

	local function OnUpdate()
		local i = g:Closest()
		if not i then return end
		local x, y = g.xs[i], g.ys[i]
		local cx = Scale(x, g.zoomStart, g.zoomEnd, 0, g.w)
		local cy = Scale(y, g.yMin, g.yMax, 0, g.h)
		if g.mouseOver then
			plot.dot:ClearAllPoints(); plot.dot:SetPoint("CENTER", plot, "BOTTOMLEFT", cx, cy); plot.dot:Show()
			plot.hoverLine:ClearAllPoints()
			plot.hoverLine:SetPoint("TOP", plot, "TOPLEFT", cx, 0)
			plot.hoverLine:SetPoint("BOTTOM", plot, "BOTTOMLEFT", cx, 0)
			plot.hoverLine:Show()

			local text = ShortMoney(y)
			plot.hoverText:SetText(text)
			local tw = math.max(plot.hoverText:GetStringWidth() or 0, #text * 7)
			plot.hoverText:SetWidth(HOVER_TEXT_W)
			plot.hoverText:ClearAllPoints()
			if cx - tw / 2 < 0 then
				plot.hoverText:SetJustifyH("LEFT")
				plot.hoverText:SetPoint("BOTTOMLEFT", plot, "TOPLEFT", 0, PLOT_TOP_MARGIN)
			elseif cx + tw / 2 > g.w then
				plot.hoverText:SetJustifyH("RIGHT")
				plot.hoverText:SetPoint("BOTTOMRIGHT", plot, "TOPRIGHT", 0, PLOT_TOP_MARGIN)
			else
				plot.hoverText:SetJustifyH("CENTER")
				plot.hoverText:SetPoint("BOTTOM", plot, "TOPLEFT", cx, PLOT_TOP_MARGIN)
			end
			plot.hoverText:Show()
		else
			plot.dot:Hide(); plot.hoverLine:Hide(); plot.hoverText:Hide()
		end
		if g.selectStart then
			local sx = Scale(g.xs[g.selectStart] or x, g.zoomStart, g.zoomEnd, 0, g.w)
			plot.selection:ClearAllPoints()
			plot.selection:SetPoint("TOPLEFT", plot, "TOPLEFT", math.min(sx, cx), 0)
			plot.selection:SetPoint("BOTTOMRIGHT", plot, "BOTTOMLEFT", math.max(sx, cx), 0)
			plot.selection:Show()
		else
			plot.selection:Hide()
		end
		local hovered = g.mouseOver or g.selectStart ~= nil
		if not hovered then
			g.hovered = false
			g:Draw()
			plot:SetScript("OnUpdate", nil)
		end
		if g.onHover then g.onHover(hovered and x or nil, hovered and y or nil) end
	end
	g.OnUpdate = OnUpdate

	plot:SetScript("OnEnter", function()
		if not g.drawn then return end
		g.mouseOver, g.hovered = true, true
		g:Draw()
		plot:SetScript("OnUpdate", OnUpdate)
	end)
	plot:SetScript("OnLeave", function() g.mouseOver = false end)
	plot:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and g.drawn then g.selectStart = g:Closest() end
	end)
	plot:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or not g.selectStart then return end
		local i = g:Closest() or g.selectStart
		local a, b = g.xs[math.min(i, g.selectStart)], g.xs[math.max(i, g.selectStart)]
		g.selectStart = nil
		plot.selection:Hide()
		if a and b and a ~= b and (a ~= g.zoomStart or b ~= g.zoomEnd) then
			g:SetZoom(a, b)
			g:Draw()
			if g.onZoom then g.onZoom() end
		end
	end)
	return g
end
M.NewGraph = NewGraph

local RANGES = {
	{ "1D", DAY }, { "1W", DAY * 7 }, { "1M", DAY * 30 }, { "3M", DAY * 91 }, { "6M", DAY * 183 },
	{ "1Y", DAY * 365 }, { "2Y", DAY * 730 }, { "ALL", -1 },
}
local RANGE_SECONDS = {}
for _, r in ipairs(RANGES) do RANGE_SECONDS[r[1]] = r[2] end
M.RANGE_SECONDS = RANGE_SECONDS

function M:DashboardCharacters()
	local un = Settings().unselected
	local list = {}
	for _, key in ipairs(self:GoldCharacters()) do
		if not un[key] then list[#list + 1] = key end
	end
	return list
end

local function CharName(key)
	local c = M:DB().gold[key]
	local ch = M:DB().chars[key]
	local name = (ch and ch.surname and (ch.name .. " " .. ch.surname)) or key:gsub("%-", " - ", 1)
	local color = c and c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
	if color and color.colorStr then return "|c" .. color.colorStr .. name .. "|r" end
	return name
end

local function DateText(t) return date("%b %d, %Y", t) end
local function DateTimeText(t) return date("%b %d, %Y %H:%M", t) end

local function BuildFeed(page, height)
	local feed = UI.Panel(page, "low", 4)
	feed:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
	feed:SetSize(200, height)
	local title = UI.Text(feed, "body/bold/small", "text")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Gold Activity")
	local rule = UI.Rule(feed, "accent")
	rule:SetHeight(2)
	rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	rule:SetWidth(title:GetStringWidth() or 80)
	local empty = UI.Text(feed, "body/regular/x-small", "textLow", "LEFT")
	empty:SetPoint("TOPLEFT", 10, -44)
	empty:SetWidth(180)
	empty:SetWordWrap(true)
	empty:SetText("Sales and purchases show here once K-Market opens your Auction House mail (Open All at the mailbox).")
	local CARD_H, cards = 76, {}
	local visible = math.floor((height - 44) / (CARD_H + 6))
	for i = 1, visible do
		local card = UI.Panel(feed, "medium", 4)
		card:SetSize(184, CARD_H)
		card:SetPoint("TOPLEFT", feed, "TOPLEFT", 8, -40 - (i - 1) * (CARD_H + 6))
		card.date = UI.Text(card, "body/medium/small", "text")
		card.date:SetPoint("TOPLEFT", 8, -6)
		card.sold = UI.Text(card, "body/regular/x-small", "textLow")
		card.sold:SetPoint("TOPLEFT", 8, -26)
		card.soldAmount = UI.Text(card, "numeric/regular/x-small", "text", "RIGHT")
		card.soldAmount:SetPoint("TOPRIGHT", -8, -26)
		card.bought = UI.Text(card, "body/regular/x-small", "textLow")
		card.bought:SetPoint("TOPLEFT", 8, -42)
		card.boughtAmount = UI.Text(card, "numeric/regular/x-small", "text", "RIGHT")
		card.boughtAmount:SetPoint("TOPRIGHT", -8, -42)
		card.net = UI.Text(card, "numeric/regular/x-small", "positive", "RIGHT")
		card.net:SetPoint("BOTTOMRIGHT", -8, 6)
		cards[i] = card
	end
	feed.offset = 0
	feed:EnableMouseWheel(true)
	function feed:Refresh()
		local days = M:LedgerDays(60)
		self.offset = math.max(0, math.min(self.offset, #days - visible))
		empty:SetShown(#days == 0)
		for i, card in ipairs(cards) do
			local d = days[self.offset + i]
			card:SetShown(d ~= nil)
			if d then
				card.date:SetText(DateText(d.day))
				card.sold:SetText(d.soldCount .. " Sold")
				card.soldAmount:SetText(ShortMoney(d.sold))
				card.bought:SetText(d.boughtCount .. " Bought")
				card.boughtAmount:SetText(ShortMoney(d.bought))
				local net = d.sold - d.bought
				card.net:SetText((net > 0 and "+" or "") .. ShortMoney(net))
				UI.TextColor(card.net, net >= 0 and "positive" or "error")
			end
		end
		self.days = days
	end
	feed:SetScript("OnMouseWheel", function(self, delta)
		self.offset = self.offset - delta
		self:Refresh()
	end)
	return feed
end

local function BuildCharPicker(page, button, onChange)
	local pop = UI.Panel(page, "high", 4)
	pop:SetFrameStrata("DIALOG")
	pop:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
	pop:SetWidth(220)
	pop:EnableMouse(true)
	pop:Hide()
	pop.toggles = {}
	local all = UI.Button(pop, "Select All", 96, 20, "tertiary")
	all:SetPoint("TOPLEFT", 8, -6)
	local none = UI.Button(pop, "Deselect All", 100, 20, "tertiary")
	none:SetPoint("TOPRIGHT", -8, -6)
	local function SetAll(off)
		local un = Settings().unselected
		for _, key in ipairs(M:GoldCharacters()) do un[key] = off or nil end
		pop:Refresh()
		onChange()
	end
	all:SetScript("OnClick", function() SetAll(false) end)
	none:SetScript("OnClick", function() SetAll(true) end)
	function pop:Refresh()
		local keys = M:GoldCharacters()
		local un = Settings().unselected
		for i, key in ipairs(keys) do
			local t = self.toggles[i]
			if not t then
				t = UI.Toggle(self, "", function(on)
					Settings().unselected[t.kmKey] = (not on) or nil
					onChange()
				end)
				t:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 22)
				self.toggles[i] = t
			end
			t.kmKey = key
			t.kmText:SetText(CharName(key))
			t:SetKMChecked(not un[key])
			t:Show()
		end
		for i = #keys + 1, #self.toggles do self.toggles[i]:Hide() end
		self:SetHeight(36 + #keys * 22)
	end
	button:SetScript("OnClick", function()
		if pop:IsShown() then pop:Hide() else pop:Refresh(); pop:Show() end
	end)
	return pop
end

local function SummaryCell(parent, x, width, top, bottom)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetPoint("TOPLEFT", x, -4)
	cell:SetSize(width, 42)
	local function Row(y, label)
		local l = UI.Text(cell, "body/medium/small", "text")
		l:SetPoint("TOPLEFT", 0, y)
		l:SetText(label)
		local v = UI.Text(cell, "body/regular/small", "accent", "RIGHT")
		v:SetPoint("TOPRIGHT", -8, y)
		return v
	end
	cell.top = Row(0, top)
	cell.bottom = Row(-22, bottom)
	return cell
end

local function DetailsColumn(parent, x, width, heading, totalLabel, avgLabel, withTop)
	local col = CreateFrame("Frame", nil, parent)
	col:SetPoint("TOPLEFT", x, -8)
	col:SetSize(width, 88)
	local h = UI.Text(col, "body/medium/small", "text")
	h:SetPoint("TOPLEFT", 0, 0)
	h:SetText(heading)
	local function Row(y, label)
		local l = UI.Text(col, "body/regular/small", "textLow")
		l:SetPoint("TOPLEFT", 0, y)
		l:SetText(label)
		local v = UI.Text(col, "numeric/regular/small", "textLow", "RIGHT")
		v:SetPoint("TOPRIGHT", 0, y)
		v:SetWidth(width - (l:GetStringWidth() or 100) - 8)
		return v
	end
	col.total = Row(-24, totalLabel)
	col.avg = Row(-44, avgLabel)
	if withTop then col.top = Row(-64, "Top Item:") end
	return col
end

local function MoneyColored(v)
	local text = ShortMoney(v)
	if v < 0 then return UI.Colorize(text, "error") end
	return text
end

local function BuildDashboard(page)
	local contentH = H - HEADER - 16
	page.feed = BuildFeed(page, contentH)
	local content = CreateFrame("Frame", nil, page)
	content:SetPoint("TOPLEFT", page, "TOPLEFT", 222, -8)
	content:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 8)
	local CW = W - 222 - 12

	local title = UI.Text(content, "body/bold/p", "text")
	title:SetPoint("TOPLEFT", 0, -4)
	title:SetText("Player Gold")
	page.dateText = UI.Text(content, "body/regular/x-small", "textLow")
	page.dateText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	page.charButton = UI.Button(content, "All Characters", 160, 24, "secondary")
	page.charButton:SetPoint("TOPRIGHT", 0, -8)
	page.picker = BuildCharPicker(content, page.charButton, function() page:Refresh() end)

	page.rangeButtons = {}
	local x = 0
	for i = #RANGES, 1, -1 do
		local r = RANGES[i]
		local b = CreateFrame("Button", nil, content)
		b:SetSize(22, 22)
		b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8 - x, -60)
		x = x + 22 + 6
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetTexture(UI.CIRCLE)
		b.bg:SetAllPoints()
		UI.Tint(b.bg, "accent")
		b.text = UI.Text(b, "body/regular/x-small", "text", "CENTER")
		b.text:SetPoint("CENTER")
		b.text:SetText(r[1])
		b.range = r[1]
		b:SetScript("OnClick", function()
			Settings().range = r[1]
			state.zoomed = false
			page:Refresh()
		end)
		b:SetScript("OnEnter", function(self) if Settings().range ~= self.range then UI.TextColor(self.text, "accent") end end)
		b:SetScript("OnLeave", function(self) if Settings().range ~= self.range then UI.TextColor(self.text, "text") end end)
		page.rangeButtons[r[1]] = b
	end
	page.resetZoom = UI.Button(content, "Reset Zoom", 100, 22, "tertiary")
	page.resetZoom:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -60)
	page.resetZoom:SetScript("OnClick", function()
		Settings().range = "ALL"
		state.zoomed = false
		page:Refresh()
	end)

	local summaryH, detailsH = 50, 104
	local graphH = contentH - 84 - 2 - 16 - summaryH - 16 - detailsH - 8
	page.graph = NewGraph(content, CW, graphH)
	page.graph.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -86)
	page.graph.valueFunc = function(t) return M:GoldAt(page.keys, t) end
	page.graph.onHover = function(t, copper)
		if t then
			page.dateText:SetText(DateTimeText(t) .. "   " .. ShortMoney(copper))
		else
			page.dateText:SetText(DateText(Now()))
		end
	end
	page.graph.onZoom = function()
		state.zoomed = true
		page.zoomA, page.zoomB = page.graph:GetZoom()
		page:RefreshHeader()
		page:RefreshDetails()
	end

	local summary = CreateFrame("Frame", nil, content)
	summary:SetPoint("TOPLEFT", page.graph.frame, "BOTTOMLEFT", 0, -16)
	summary:SetSize(CW, summaryH)
	local third = math.floor(CW / 3)
	page.range = SummaryCell(summary, 8, third - 16, "52W HIGH", "52W LOW")
	page.daily = SummaryCell(summary, third + 8, third - 16, "AVG DAILY SALES", "DAILY CHANGE")
	page.tops = SummaryCell(summary, 2 * third + 8, third - 16, "TOP SALE", "TOP PURCHASE")
	for i = 1, 2 do
		local r = UI.Rule(summary, "outline", true)
		r:SetPoint("TOPLEFT", summary, "TOPLEFT", i * third - 1, -4)
		r:SetHeight(summaryH - 8)
	end

	local details = UI.Panel(content, "medium", 4)
	details:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -16)
	details:SetSize(CW, detailsH)
	local colW = math.floor((CW - 16 - 2 * 24) / 3)
	page.sale = DetailsColumn(details, 8, colW, "SALES", "Total Gold Earned", "Average Earned per Day", true)
	page.buy = DetailsColumn(details, 8 + colW + 24, colW, "EXPENSES", "Total Gold Spent", "Average Spent per Day", true)
	page.profit = DetailsColumn(details, 8 + 2 * (colW + 24), colW, "PROFIT", "Total Profit", "Average Profit per Day", false)

	function page:RefreshHeader()
		local range = Settings().range
		for key, b in pairs(self.rangeButtons) do
			local on = key == range and not state.zoomed
			b:SetShown(not state.zoomed)
			b.bg:SetShown(on)
			UI.TextColor(b.text, on and "onAccent" or "text")
		end
		self.resetZoom:SetShown(state.zoomed)
		local all, keys = #M:GoldCharacters(), #self.keys
		UI.ButtonText(self.charButton, keys == 0 and "No Characters" or keys == all and "All Characters" or (keys .. " Characters"))
	end

	function page:Period()
		local now = Now()
		if state.zoomed then
			local a, b = self.graph:GetZoom()
			return a, b, math.max(1, math.ceil((b - a) / DAY))
		end
		local seconds = RANGE_SECONDS[Settings().range] or -1
		if seconds < 0 then
			local first = self.firstTime or now
			return nil, nil, math.max(1, math.ceil((now - first) / DAY))
		end
		return now - seconds, now, math.max(1, math.ceil(seconds / DAY))
	end

	function page:RefreshDetails()
		local from, to, days = self:Period()
		local s = M:LedgerSummary(from, to)
		self.daily.top:SetText(string.format("%.1f", math.floor(s.soldCount / days * 10 + 0.5) / 10))
		self.tops.top:SetText(ShortMoney(s.topSaleUnit))
		self.tops.bottom:SetText(ShortMoney(s.topBuyUnit))
		self.sale.total:SetText(ShortMoney(s.sales))
		self.sale.avg:SetText(ShortMoney(s.sales / days))
		self.sale.top:SetText(s.topSale or "-")
		self.buy.total:SetText(ShortMoney(s.buys))
		self.buy.avg:SetText(ShortMoney(s.buys / days))
		self.buy.top:SetText(s.topBuy or "-")
		self.profit.total:SetText(MoneyColored(s.profit))
		self.profit.avg:SetText(MoneyColored(s.profit / days))
		self.summaryData = s
	end

	function page:Refresh()
		local now = Now()
		self.keys = M:DashboardCharacters()
		local first = M:FirstGoldTime(self.keys)
		self.firstTime = first
		self.dateText:SetText(DateText(now))
		local g = self.graph
		g.noData = not first
		if first then
			local span = now - first
			g:SetRange(first, now, span > 2 * DAY and 3600 or 60)
			local seconds = RANGE_SECONDS[Settings().range] or -1
			if state.zoomed and self.zoomA then
				g:SetZoom(math.max(self.zoomA, first), math.min(self.zoomB, now))
			elseif seconds > 0 then
				g:SetZoom(math.max(now - seconds, first), now)
			end

			local current = M:GoldAt(self.keys, now) or 0
			local low, high = current, current
			for t = math.max(now - 52 * 7 * DAY, first), now, 6 * 3600 do
				local v = M:GoldAt(self.keys, t) or 0
				low, high = math.min(low, v), math.max(high, v)
			end
			self.range.top:SetText(ShortMoney(high))
			self.range.bottom:SetText(ShortMoney(low))
			self.daily.bottom:SetText(ShortMoney(current - (M:GoldAt(self.keys, math.max(now - DAY, first)) or 0)))
			self.stats = { low = low, high = high, current = current }
		else
			self.range.top:SetText("-"); self.range.bottom:SetText("-"); self.daily.bottom:SetText("-")
			self.stats = nil
		end
		g:Draw()
		self:RefreshHeader()
		self:RefreshDetails()
		self.feed:Refresh()
		if self.picker:IsShown() then self.picker:Refresh() end
	end
end

local ROW = 22

local function ItemRow(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 4, 0)
	row.text = UI.Text(row, "body/regular/small", "text")
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.text:SetPoint("RIGHT", -40, 0)
	row.count = UI.Text(row, "numeric/regular/x-small", "textLow", "RIGHT")
	row.count:SetPoint("RIGHT", -6, 0)
	row:SetScript("OnEnter", function(self)
		self.kmHighlight:Show()
		if self.kmItem then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.kmItem.id) else GameTooltip:SetText(ItemName(self.kmItem.id)) end
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self) self.kmHighlight:Hide(); GameTooltip:Hide() end)
end
local function FillItemRow(row, item)
	row.icon:SetTexture(ItemIcon(item.id))
	row.text:SetText(ItemName(item.id))
	row.count:SetText(item.count and tostring(item.count) or "")
end

local dialog
local function Dialog()
	if dialog then return dialog end
	dialog = UI.Panel(frame, "high", 6)
	dialog:SetSize(460, 250)
	dialog:SetPoint("CENTER", frame, "CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true)
	dialog.title = UI.Text(dialog, "body/bold/small", "text")
	dialog.title:SetPoint("TOPLEFT", 12, -12)
	dialog.help = UI.Text(dialog, "body/regular/x-small", "textLow")
	dialog.help:SetPoint("TOPLEFT", 12, -32)
	dialog.help:SetWidth(436)
	dialog.help:SetWordWrap(true)
	local box = UI.Input(dialog, 436, 130)
	box:SetPoint("TOPLEFT", 12, -64)
	box:SetMultiLine(true)
	box:SetMaxLetters(0)
	box:SetScript("OnEnterPressed", nil)
	dialog.box = box
	dialog.go = UI.Button(dialog, "Import", 100, 24, "primary")
	dialog.go:SetPoint("BOTTOMRIGHT", -12, 12)
	dialog.close = UI.Button(dialog, "Close", 80, 24, "secondary")
	dialog.close:SetPoint("RIGHT", dialog.go, "LEFT", -8, 0)
	dialog.close:SetScript("OnClick", function() dialog:Hide() end)
	dialog.result = UI.Text(dialog, "body/regular/x-small", "textLow")
	dialog.result:SetPoint("BOTTOMLEFT", 12, 18)
	dialog:Hide()
	M.dialog = dialog
	return dialog
end

function M:ShowImport(path)
	local d = Dialog()
	d.title:SetText("Import into " .. (path and M.FormatPath(path) or "the top level"))
	d.help:SetText("Paste a TSM group list (\"i:2589,group:Cloth`Linen,i:2592\"), item links, or item numbers. Items move here from any other group.")
	d.box:SetText("")
	d.result:SetText("")
	d.go:Show()
	d.go:SetScript("OnClick", function()
		local added, made = M:ImportGroups(path, d.box:GetText())
		if not added then
			d.result:SetText(UI.Colorize(made, "error"))
		else
			d.result:SetText(string.format("%d item(s) added, %d group(s) made.", added, made))
			Refresh()
		end
	end)
	d:Show()
	d.box:SetFocus()
end

function M:ShowExport(path)
	local d = Dialog()
	d.title:SetText("Export " .. M.FormatPath(path))
	d.help:SetText("TSM's group list format, with subgroups. Press Ctrl+C to copy.")
	d.box:SetText(M:ExportGroups(path))
	d.result:SetText("")
	d.go:Hide()
	d:Show()
	d.box:SetFocus()
	d.box:HighlightText()
end

function M:OpButtonText(path, kind)
	local own = self:DB().groups[path].ops[kind]
	if own == false then return UI.Colorize("None", "textLow") end
	if own then return own end
	local op, name, from = self:EffectiveOp(path, kind)
	if op then return name .. UI.Colorize("  (from " .. M.GroupName(from) .. ")", "textLow") end
	return UI.Colorize("Not set", "textLow")
end

function M:CycleGroupOp(path, kind, back)
	local g = self:DB().groups[path]
	if not g then return end
	if back then self:AssignOp(path, kind, nil); return end
	local names = self:OpNames(kind)
	local own = g.ops[kind]
	local nextName = false
	if own == nil or own == false then
		nextName = names[1] or false
	else
		for i, n in ipairs(names) do if n == own then nextName = names[i + 1] or false end end
	end
	self:AssignOp(path, kind, nextName)
end

local function BuildGroups(page)
	local left = UI.Panel(page, "low", 4)
	left:SetPoint("TOPLEFT", 8, -8)
	left:SetSize(260, H - HEADER - 16)
	local title = UI.Text(left, "body/bold/small", "text")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Groups")
	local search = UI.Input(left, 240, 24)
	search:SetPoint("TOPLEFT", 10, -32)
	search:SetScript("OnTextChanged", function() page:Refresh() end)
	page.search = search
	local treeRows = math.floor((H - HEADER - 16 - 64 - 40) / ROW)
	page.tree = UI.List(left, ROW, treeRows, function(row)
		row.text = UI.Text(row, "body/regular/small", "text")
		row.count = UI.Text(row, "numeric/regular/x-small", "textLow", "RIGHT")
		row.count:SetPoint("RIGHT", -8, 0)
		row:SetScript("OnClick", function(self) state.group = self.kmItem; page:Refresh() end)
	end, function(row, path)
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", 8 + M.Depth(path) * 14, 0)
		row.text:SetText(M.GroupName(path))
		local n = #M:GroupItems(path, true)
		row.count:SetText(n > 0 and tostring(n) or "")
		row:SetKMSelected(path == state.group)
		UI.TextColor(row.text, path == state.group and "accent" or "text")
	end)
	page.tree:SetPoint("TOPLEFT", left, "TOPLEFT", 2, -64)
	page.tree:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, -64)
	page.tree:SetHeight(treeRows * ROW)
	local function Unique(base, parent)
		local groups = M:DB().groups
		local name, n = base, 1
		while groups[parent and (parent .. M.SEP .. name) or name] do n = n + 1; name = base .. " " .. n end
		return name
	end
	local function Made(ok, path)
		if not ok then return end
		state.group = path
		page:Refresh()
		page.name:SetFocus()
		page.name:HighlightText()
	end
	local newGroup = UI.Button(left, "New Group", 116, 24, "primary")
	newGroup:SetPoint("BOTTOMLEFT", 10, 10)
	newGroup:SetScript("OnClick", function() Made(M:NewGroup(Unique("New Group"))) end)
	page.newGroup = newGroup
	local newSub = UI.Button(left, "New Subgroup", 116, 24, "secondary")
	newSub:SetPoint("BOTTOMRIGHT", -10, 10)
	newSub:SetScript("OnClick", function()
		if state.group then Made(M:NewGroup(Unique("New Group", state.group), state.group)) end
	end)
	page.newSub = newSub

	local right = CreateFrame("Frame", nil, page)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
	right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 8)
	page.right = right
	local RW = W - 8 - 260 - 12 - 12
	page.none = UI.Text(page, "body/regular/small", "textLow", "CENTER")
	page.none:SetPoint("CENTER", right, "CENTER")
	page.none:SetText("Make a group on the left, or pick one.")
	page.path = UI.Text(right, "body/regular/x-small", "textLow")
	page.path:SetPoint("TOPLEFT", 0, -4)
	page.name = UI.Input(right, 260, 26)
	page.name:SetPoint("TOPLEFT", 0, -20)
	page.name:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:ClearFocus()
		if state.group then
			local ok, newPath = M:RenameGroup(state.group, text)
			if ok then state.group = newPath end
			page:Refresh()
		end
	end)
	page.name:SetScript("OnEditFocusLost", function(self)
		if state.group then self:SetText(M.GroupName(state.group)) end
	end)
	local del = UI.Button(right, "Delete", 80, 24, "secondary")
	del:SetPoint("TOPRIGHT", 0, -21)
	Confirming(del, "Delete", function()
		if state.group then
			local parent = M.ParentPath(state.group)
			M:DeleteGroup(state.group)
			state.group = parent
			page:Refresh()
		end
	end)
	del.kmTip = "Deletes the group and its subgroups. Their items go to the group above (or out of K-Market's groups)."
	page.delete = del
	local export = UI.Button(right, "Export", 80, 24, "secondary")
	export:SetPoint("RIGHT", del, "LEFT", -8, 0)
	export:SetScript("OnClick", function() if state.group then M:ShowExport(state.group) end end)
	local import = UI.Button(right, "Import", 80, 24, "secondary")
	import:SetPoint("RIGHT", export, "LEFT", -8, 0)
	import:SetScript("OnClick", function() M:ShowImport(state.group) end)

	local opsBox = UI.Panel(right, "low", 4)
	opsBox:SetPoint("TOPLEFT", 0, -58)
	opsBox:SetSize(RW, 116)
	local opsTitle = UI.Text(opsBox, "body/bold/small", "text")
	opsTitle:SetPoint("TOPLEFT", 10, -8)
	opsTitle:SetText("Operations")
	local opsHelp = UI.Text(opsBox, "body/regular/x-small", "textLow", "RIGHT")
	opsHelp:SetPoint("TOPRIGHT", -10, -10)
	opsHelp:SetText("Click: next operation or none.  Right-click: use the parent group's.")
	page.opButtons = {}
	for i, kind in ipairs(M.KINDS) do
		local label = UI.Text(opsBox, "body/regular/small", "textLow")
		label:SetPoint("TOPLEFT", 10, -32 - (i - 1) * 26)
		label:SetText(M.KIND_LABEL[kind])
		local b = UI.Button(opsBox, "", 300, 22, "secondary")
		b:SetPoint("TOPLEFT", 110, -28 - (i - 1) * 26)
		b.kmText:SetJustifyH("LEFT")
		b:SetScript("OnClick", function(_, button)
			if not state.group then return end
			M:CycleGroupOp(state.group, kind, button == "RightButton")
			page:Refresh()
		end)
		local edit = UI.Button(opsBox, "Edit", 60, 22, "tertiary")
		edit:SetPoint("LEFT", b, "RIGHT", 6, 0)
		edit:SetScript("OnClick", function()
			local _, name = M:EffectiveOp(state.group, kind)
			if name then state.op = name; M:ToggleWindow(3) end
		end)
		b.kmEdit = edit
		page.opButtons[kind] = b
	end

	local listW = math.floor((RW - 12) / 2)
	local listTop = -58 - 116 - 12
	local itemRows = math.floor((H - HEADER - 16 + listTop - 64) / ROW)
	local function ListBox(x, titleText)
		local box = UI.Panel(right, "low", 4)
		box:SetPoint("TOPLEFT", x, listTop)
		box:SetSize(listW, itemRows * ROW + 64)
		box.title = UI.Text(box, "body/bold/small", "text")
		box.title:SetPoint("TOPLEFT", 10, -8)
		box.title:SetText(titleText)
		return box
	end
	local bagBox = ListBox(0, "Ungrouped Items")
	page.bagSearch = UI.Input(bagBox, listW - 20, 22)
	page.bagSearch:SetPoint("TOPLEFT", 10, -28)
	page.bagSearch:SetScript("OnTextChanged", function() page:RefreshItems() end)
	page.bagList = UI.List(bagBox, ROW, itemRows, ItemRow, FillItemRow)
	page.bagList:SetPoint("TOPLEFT", 2, -56)
	page.bagList:SetPoint("TOPRIGHT", -2, -56)
	page.bagList:SetHeight(itemRows * ROW)
	for _, row in ipairs(page.bagList.rows) do
		row:SetScript("OnClick", function(self)
			if state.group and M:AddItem(state.group, self.kmItem.id) then page:Refresh() end
		end)
	end
	page.addAll = UI.Button(bagBox, "Add All", 70, 20, "tertiary")
	page.addAll:SetPoint("TOPRIGHT", -8, -6)
	page.addAll:SetScript("OnClick", function()
		if not state.group then return end
		for _, item in ipairs(page.bagList.items) do M:AddItem(state.group, item.id) end
		page:Refresh()
	end)

	local groupBox = ListBox(listW + 12, "Group Items")
	page.groupBox = groupBox
	page.groupHint = UI.Text(groupBox, "body/regular/x-small", "textLow")
	page.groupHint:SetPoint("TOPLEFT", 10, -32)
	page.groupHint:SetText("Click an item to take it out. Drop an item here to add it.")
	page.groupList = UI.List(groupBox, ROW, itemRows, ItemRow, FillItemRow)
	page.groupList:SetPoint("TOPLEFT", 2, -56)
	page.groupList:SetPoint("TOPRIGHT", -2, -56)
	page.groupList:SetHeight(itemRows * ROW)
	for _, row in ipairs(page.groupList.rows) do
		row:SetScript("OnClick", function(self)
			if state.group and M:RemoveItem(state.group, self.kmItem.id) then page:Refresh() end
		end)
	end
	local function Drop()
		local kind, id = GetCursorInfo()
		if kind == "item" and state.group and id then
			M:AddItem(state.group, id)
			ClearCursor()
			page:Refresh()
		end
	end
	groupBox:EnableMouse(true)
	groupBox:SetScript("OnReceiveDrag", Drop)
	groupBox:SetScript("OnMouseUp", Drop)
	page.Drop = Drop

	if M.BuildGroupAuto then M:BuildGroupAuto(page, left, right) end

	function page:RefreshItems()
		local bags = M:ScanBags()
		local filter = (self.bagSearch:GetText() or ""):lower()
		local loose = {}
		for id, e in pairs(bags) do
			if not M:ItemGroup(id) and (filter == "" or ItemName(id):lower():find(filter, 1, true)) then
				loose[#loose + 1] = { id = id, count = e.count }
			end
		end
		table.sort(loose, function(a, b)
			local na, nb = ItemName(a.id), ItemName(b.id)
			if na ~= nb then return na < nb end
			return a.id < b.id
		end)
		self.bagList:SetItems(loose)
		local mine = {}
		if state.group then
			for _, id in ipairs(M:GroupItems(state.group)) do mine[#mine + 1] = { id = id, count = bags[id] and bags[id].count } end
			table.sort(mine, function(a, b)
				local na, nb = ItemName(a.id), ItemName(b.id)
				if na ~= nb then return na < nb end
				return a.id < b.id
			end)
		end
		self.groupList:SetItems(mine)
	end

	function page:Refresh()
		local groups = M:DB().groups
		if state.group and not groups[state.group] then state.group = nil end
		local filter = (self.search:GetText() or ""):lower()
		local list = {}
		for _, path in ipairs(M:GroupPaths()) do
			if filter == "" or path:lower():find(filter, 1, true) then list[#list + 1] = path end
		end
		self.tree:SetItems(list)
		local has = state.group ~= nil
		self.right:SetShown(has)
		self.none:SetShown(not has)
		self.newSub:SetKMEnabled(has)
		if has then
			self.path:SetText(M.FormatPath(state.group))
			if not self.name:HasFocus() then self.name:SetText(M.GroupName(state.group)) end
			for kind, b in pairs(self.opButtons) do
				UI.ButtonText(b, M:OpButtonText(state.group, kind))
				b.kmEdit:SetShown(M:EffectiveOp(state.group, kind) ~= nil)
			end
			self.groupBox.title:SetText("Group Items (" .. #M:GroupItems(state.group) .. ")")
		end
		if M.RefreshGroupAuto then M:RefreshGroupAuto(self, state.group) end
		self:RefreshItems()
	end
end

local DURATIONS = { { 1, "12 hours" }, { 2, "24 hours" }, { 3, "48 hours" } }
local PRICE_CHOICES = {
	{ "none", "Don't post" }, { "minPrice", "Post at minimum price" },
	{ "normalPrice", "Post at normal price" }, { "maxPrice", "Post at maximum price" },
}
local PROFESSION_CHOICES = { { "", "Pick a profession" } }
for _, p in ipairs(M.PROFESSIONS) do PROFESSION_CHOICES[#PROFESSION_CHOICES + 1] = { p, p } end

M.OP_FIELDS = {
	mail = {
		{ "to", "Send to", "text", "Your bank alt's name, surname included (First Surname)." },
		{ "keep", "Keep in bags", "number", "How many of each item to keep." },
		{ "maxQty", "Send up to", "number", "At most this many of each item (0 = everything above Keep)." },
		{ "restock", "Restock", "toggle", "Only send what tops the target up to \"Send up to\", counting what they already have." },
	},
	crafter = {
		{ "profession", "Profession", "choice", "Sends to your character with this profession.", PROFESSION_CHOICES },
		{ "to", "Or send to", "text", "Leave blank to find your crafter by profession." },
		{ "keep", "Keep in bags", "number", "How many of each item to keep." },
		{ "maxQty", "Send up to", "number", "At most this many of each item (0 = everything above Keep)." },
		{ "restock", "Restock", "toggle", "Only send what tops the crafter up to \"Send up to\", counting what they already have." },
	},
	post = {
		{ "duration", "Duration", "choice", "How long auctions stay up.", DURATIONS },
		{ "postCap", "Post cap", "number", "How many auctions to have up at once (for stackable goods: how many items)." },
		{ "keep", "Keep in bags", "number", "How many of each item not to post." },
		{ "undercut", "Undercut", "money", "How far under the lowest auction to post. Your own lowest auction is matched, not undercut." },
		{ "minPrice", "Minimum price", "price", "Never post under this (per item). An amount, or a price like 80% market." },
		{ "normalPrice", "Normal price", "price", "Used when nobody else is selling (per item). An amount, or market." },
		{ "maxPrice", "Maximum price", "price", "The most to post at (0 = no maximum). An amount, or 200% market." },
		{ "belowMin", "Below minimum", "choice", "When the lowest auction is under your minimum.", PRICE_CHOICES },
		{ "aboveMax", "Above maximum", "choice", "When the lowest auction is over your maximum.", PRICE_CHOICES },
		{ "cancelUndercut", "Cancel undercut", "toggle", "A cancel scan offers to cancel your auctions that someone has undercut." },
	},
}

function M.ReadField(f, text)
	if f[3] == "number" then
		local n = tonumber(text)
		return n and n >= 0 and math.floor(n) or nil
	elseif f[3] == "money" then
		return M.ParseMoney(text)
	elseif f[3] == "price" then
		return M.Prices.ParseInput(text)
	end
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ShowField(op, f)
	local v = op[f[1]]
	if f[3] == "money" then return v and v > 0 and M.FormatMoney(v) or "0" end
	if f[3] == "price" then return M.Prices.Show(v) end
	return tostring(v or "")
end

local function BuildOpFields(parent, kind, onChange)
	local box = CreateFrame("Frame", nil, parent)
	box:SetAllPoints()
	box.widgets = {}
	for i, f in ipairs(M.OP_FIELDS[kind]) do
		local y = -(i - 1) * 40
		local label = UI.Text(box, "body/medium/small", "text")
		label:SetPoint("TOPLEFT", 0, y - 4)
		label:SetText(f[2])
		local help = UI.Text(box, "body/regular/x-small", "textLow")
		help:SetPoint("TOPLEFT", 0, y - 21)
		help:SetText(f[4])
		local w
		if f[3] == "toggle" then
			w = UI.Toggle(box, "On", function(on) state.opTable[f[1]] = on; onChange() end)
			w:SetWidth(80)
		elseif f[3] == "choice" then
			w = UI.Choice(box, 200, f[5], function(value) state.opTable[f[1]] = value; onChange() end)
		else
			w = UI.Input(box, 200, 24, f[3] ~= "text")
			local function Save(self)
				local op = state.opTable
				if not op then return end
				local value = M.ReadField(f, self:GetText())
				if value ~= nil then op[f[1]] = value end
				self:SetText(ShowField(op, f))
				onChange()
			end
			w:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
			w:SetScript("OnEditFocusLost", Save)
		end
		w:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, y)
		w.kmField = f
		box.widgets[#box.widgets + 1] = w
	end
	function box:ShowOp(op)
		for _, w in ipairs(self.widgets) do
			local f = w.kmField
			if f[3] == "toggle" then w:SetKMChecked(op[f[1]])
			elseif f[3] == "choice" then w:SetKMValue(op[f[1]])
			elseif not w:HasFocus() then w:SetText(ShowField(op, f)) end
		end
	end
	return box
end

function M:OpGroups(name)
	local list = {}
	for path, g in pairs(self:DB().groups) do
		for _, n in pairs(g.ops) do if n == name then list[#list + 1] = path; break end end
	end
	table.sort(list)
	return list
end

local function BuildOps(page)
	local left = UI.Panel(page, "low", 4)
	left:SetPoint("TOPLEFT", 8, -8)
	left:SetSize(260, H - HEADER - 16)
	local title = UI.Text(left, "body/bold/small", "text")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Operations")
	local rows = math.floor((H - HEADER - 16 - 40) / ROW)
	page.list = UI.List(left, ROW, rows, function(row)
		row.text = UI.Text(row, "body/regular/small", "text")
		row.text:SetPoint("LEFT", 10, 0)
		row.add = UI.Button(row, "+ New", 56, 18, "tertiary")
		row.add:SetPoint("RIGHT", -6, 0)
		row:SetScript("OnClick", function(self)
			if self.kmItem.name then state.op = self.kmItem.name; page:Refresh() end
		end)
	end, function(row, item)
		row.text:ClearAllPoints()
		if item.kind then
			row.text:SetPoint("LEFT", 10, 0)
			UI.Font(row.text, "body/bold/x-small")
			UI.TextColor(row.text, "textLow")
			row.text:SetText(M.KIND_LABEL[item.kind]:upper())
			row.add:Show()
			row.add:SetScript("OnClick", function() page:New(item.kind) end)
			row:SetKMSelected(false)
		else
			row.text:SetPoint("LEFT", 22, 0)
			UI.Font(row.text, "body/regular/small")
			UI.TextColor(row.text, item.name == state.op and "accent" or "text")
			row.text:SetText(item.name)
			row.add:Hide()
			row:SetKMSelected(item.name == state.op)
		end
	end)
	page.list:SetPoint("TOPLEFT", 2, -34)
	page.list:SetPoint("TOPRIGHT", -2, -34)
	page.list:SetHeight(rows * ROW)

	local right = CreateFrame("Frame", nil, page)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, -4)
	right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 8)
	page.right = right
	page.none = UI.Text(page, "body/regular/small", "textLow", "CENTER")
	page.none:SetPoint("CENTER", right, "CENTER")
	page.none:SetText("Make an operation with \"+ New\" on the left, or pick one.")
	page.kind = UI.Text(right, "body/regular/x-small", "textLow")
	page.kind:SetPoint("TOPLEFT", 0, 0)
	page.name = UI.Input(right, 260, 26)
	page.name:SetPoint("TOPLEFT", 0, -16)
	page.name:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:ClearFocus()
		if state.op then
			local ok, new = M:RenameOp(state.op, text)
			if ok then state.op = new end
			page:Refresh()
		end
	end)
	page.name:SetScript("OnEditFocusLost", function(self) if state.op then self:SetText(state.op) end end)
	local del = UI.Button(right, "Delete", 80, 24, "secondary")
	del:SetPoint("TOPRIGHT", 0, -17)
	Confirming(del, "Delete", function()
		if state.op then M:DeleteOp(state.op); state.op = nil; page:Refresh() end
	end)
	page.delete = del
	local rule = UI.Rule(right, "outline")
	rule:SetPoint("TOPLEFT", 0, -52)
	rule:SetPoint("TOPRIGHT", 0, -52)
	page.fields = {}
	local fieldArea = CreateFrame("Frame", nil, right)
	fieldArea:SetPoint("TOPLEFT", 0, -64)
	fieldArea:SetPoint("TOPRIGHT", 0, -64)
	fieldArea:SetHeight(420)
	for _, kind in ipairs(M.KINDS) do
		page.fields[kind] = BuildOpFields(fieldArea, kind, function() M:RefreshWindow() end)
		page.fields[kind]:Hide()
	end
	page.used = UI.Text(right, "body/regular/x-small", "textLow")
	page.used:SetPoint("BOTTOMLEFT", 0, 8)
	page.used:SetPoint("BOTTOMRIGHT", 0, 8)
	page.used:SetWordWrap(true)

	function page:New(kind)
		local base = "New " .. M.KIND_LABEL[kind]
		local name, n = base, 1
		while M:DB().ops[name] do n = n + 1; name = base .. " " .. n end
		if M:NewOp(name, kind) then
			state.op = name
			self:Refresh()
			self.name:SetFocus()
			self.name:HighlightText()
		end
	end

	function page:Refresh()
		local ops = M:DB().ops
		if state.op and not ops[state.op] then state.op = nil end
		local items = {}
		for _, kind in ipairs(M.KINDS) do
			items[#items + 1] = { kind = kind }
			for _, name in ipairs(M:OpNames(kind)) do items[#items + 1] = { name = name } end
		end
		self.list:SetItems(items)
		local op = state.op and ops[state.op]
		state.opTable = op
		self.right:SetShown(op ~= nil)
		self.none:SetShown(op == nil)
		for kind, box in pairs(self.fields) do box:SetShown(op ~= nil and op.kind == kind) end
		if op then
			self.kind:SetText(M.KIND_LABEL[op.kind] .. " operation")
			if not self.name:HasFocus() then self.name:SetText(state.op) end
			self.fields[op.kind]:ShowOp(op)
			local used = M:OpGroups(state.op)
			for i, p in ipairs(used) do used[i] = M.FormatPath(p) end
			self.used:SetText(#used > 0 and ("Used by: " .. table.concat(used, ", ") .. " (and their subgroups that don't set their own).")
				or "No group uses this yet: pick one on the Groups page.")
		end
	end
end

local PAGE_NAMES = { "Dashboard", "Groups", "Operations" }

local function ShowPage(i)
	state.page = i
	frame.tabs:Select(i)
end

local function Build()
	frame = CreateFrame("Frame", "KainUIForeverMarketFrame", UIParent)
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:Hide()
	table.insert(UISpecialFrames, "KainUIForeverMarketFrame")
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
	title:SetText("K-Market")
	local rule = UI.Rule(frame, "low")
	rule:SetPoint("TOPLEFT", 0, -HEADER); rule:SetPoint("TOPRIGHT", 0, -HEADER)
	local close = UI.Button(header, "X", 24, 24, "tertiary", "KainUIForeverMarketClose")
	close:SetPoint("RIGHT", -10, 0)
	close:SetScript("OnClick", function() frame:Hide() end)

	local help = UI.Button(header, "Tutorial", 84, 24, "secondary", "KainUIForeverMarketTutorialButton")
	help:SetPoint("RIGHT", close, "LEFT", -8, 0)
	help.kmTip = "What K-Market is, how it works and how to set it up."
	help:SetScript("OnClick", function() if M.ShowTutorial then M:ShowTutorial() end end)
	frame.help = help

	frame.total = UI.Text(header, "numeric/regular/small", "text", "RIGHT")
	frame.total:SetPoint("RIGHT", help, "LEFT", -16, 0)
	frame.totalLabel = UI.Text(header, "body/medium/x-small", "textLow", "RIGHT")
	frame.totalLabel:SetPoint("RIGHT", frame.total, "LEFT", -6, 0)
	frame.totalLabel:SetText("TOTAL GOLD")
	frame.tabs = UI.Tabs(header, PAGE_NAMES, function(i)
		state.page = i
		for j, p in ipairs(pages) do p:SetShown(j == i) end
		Refresh()
	end)
	frame.tabs:SetPoint("LEFT", title, "RIGHT", 28, 0)
	for i = 1, #PAGE_NAMES do
		local page = CreateFrame("Frame", nil, frame)
		page:SetPoint("TOPLEFT", 0, -HEADER)
		page:SetPoint("BOTTOMRIGHT")
		page:Hide()
		pages[i] = page
	end
	BuildDashboard(pages[1])
	BuildGroups(pages[2])
	BuildOps(pages[3])
	M.pages = pages
	frame:SetScript("OnShow", function() M:RecordMoney(); ShowPage(state.page) end)
	M.frame = frame
end

function M:ToggleWindow(page)
	if not frame then Build() end
	if page then state.page = page end
	if frame:IsShown() and not page then frame:Hide() return end
	if frame:IsShown() then ShowPage(state.page) else frame:Show() end
end

local nameEvents = CreateFrame("Frame")
KUI:SafeRegisterEvent(nameEvents, "GET_ITEM_INFO_RECEIVED")
local namePending
nameEvents:SetScript("OnEvent", function()
	if namePending or not frame or not frame:IsShown() then return end
	namePending = true
	C_Timer.After(0.5, function() namePending = false; Refresh() end)
end)
