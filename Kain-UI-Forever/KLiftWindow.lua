local _, KUI = ...
local L = KUI.Lift

local W, H = 660, 470
local BORDER_GREY = { 0.35, 0.35, 0.38, 1 }
local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.35, 0.9, 0.45 }
local GREY = { 0.65, 0.65, 0.68 }
local BAR = { 0.85, 0.55, 0.15 }
local MAX_SPELL_ROWS = 13
local MAX_HISTORY_ROWS = 14
local MAX_TIPS = 3

local win
local selected
local page = "last"

local function Commas(n)
	n = math.floor((n or 0) + 0.5)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function Seconds(s) return string.format("%.1f s", s or 0) end

local function Text(parent, font, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if r then fs:SetTextColor(r, g, b) end
	return fs
end

local function Pull()
	local db = L:DB()
	if not db then return nil end
	if selected then
		for _, p in ipairs(db.pulls) do if p == selected then return p end end
		selected = nil
	end
	return db.pulls[1]
end

local function BuildLast(p)
	local f = CreateFrame("Frame", nil, p)
	f:SetAllPoints()
	f.dps = Text(f, "GameFontNormalHuge")
	f.dps:SetPoint("TOPLEFT", 0, 0)
	f.compare = Text(f, "GameFontHighlight", unpack(GREY))
	f.compare:SetPoint("TOPLEFT", f.dps, "BOTTOMLEFT", 0, -6)
	f.compare:SetWidth(W - 40)
	f.stats = {}
	for i = 1, 6 do
		local label = Text(f, "GameFontHighlight", unpack(GREY))
		label:SetPoint("TOPLEFT", 0, -64 - (i - 1) * 20)
		local value = Text(f, "GameFontHighlight")
		value:SetPoint("TOPLEFT", 220, -64 - (i - 1) * 20)
		f.stats[i] = { label = label, value = value }
	end
	f.opener = Text(f, "GameFontHighlight")
	f.opener:SetPoint("TOPLEFT", 0, -190)
	f.opener:SetWidth(W - 40)
	f.tipsHead = Text(f, "GameFontNormal", unpack(GOLD))
	f.tipsHead:SetPoint("TOPLEFT", 0, -216)
	f.tipsHead:SetText("Tips")
	f.tips = {}
	for i = 1, MAX_TIPS do
		local gain = Text(f, "GameFontNormal", unpack(GREEN))
		gain:SetPoint("TOPLEFT", 0, -238 - (i - 1) * 44)
		gain:SetWidth(90)
		local tip = Text(f, "GameFontHighlight")
		tip:SetPoint("TOPLEFT", 96, -238 - (i - 1) * 44)
		tip:SetWidth(W - 140)
		tip:SetWordWrap(true)
		f.tips[i] = { gain = gain, text = tip }
	end
	return f
end

local function FillLast(f, pull)
	if pull.dps then
		f.dps:SetText(Commas(pull.dps) .. " DPS")
	else
		f.dps:SetText("Damage not read")
	end
	local cmp = L:Compare(pull)
	if not pull.dps then
		f.compare:SetText("The game didn't hand over the damage for this pull (combat started again too soon).")
	elseif cmp then

		local mine = L:RotationDPS(pull) or pull.dps
		local best = cmp.best
		local bestText = cmp.bestRotation > mine and (Commas(cmp.bestRotation) .. " (" .. (best.date or "?") .. ")") or "this one"
		f.compare:SetText(string.format("Rotation DPS (big cooldowns taken out): %s.  Best like this: %s.  Usual: %s.  From %d similar pulls.",
			Commas(mine), bestText, Commas(cmp.usual), cmp.count))
	else
		f.compare:SetText("The first pull of its kind. K-Lift compares from the next one like it.")
	end
	local tl = L:Timeline(pull)
	local rows = {
		{ "Fight", string.format("%s, %s, %s", L.KIND_NAMES[pull.kind] or pull.kind or "?", pull.zone or "?", Seconds(pull.length)) },
		{ "Damage", pull.damage and Commas(pull.damage) or "unknown" },
		{ "Time pressing buttons", string.format("%d%%", math.floor(tl.activeShare * 100 + 0.5)) },
		{ "Pauses with nothing pressed", string.format("%s (longest %s)", Seconds(tl.idle), Seconds(tl.longestIdle)) },
	}
	if pull.powerKind == 3 then rows[#rows + 1] = { "Time at full energy", Seconds(tl.capped) } end
	local boost = pull.dps and L:Boost(pull) or 0
	if boost >= 0.005 then rows[#rows + 1] = { "Added by big cooldowns", string.format("about %d%%", math.floor(boost * 100 + 0.5)) } end
	for i, s in ipairs(f.stats) do
		local r = rows[i]
		s.label:SetText(r and r[1] or "")
		s.value:SetText(r and r[2] or "")
	end
	local names = {}
	for i, id in ipairs(L.OpenerOf(pull, 5)) do names[i] = L:SpellName(id) end
	f.opener:SetText(#names > 0 and ("Opener: " .. table.concat(names, "  >  ")) or "")
	local tips = L:Tips(pull)
	for i, t in ipairs(f.tips) do
		local tip = tips[i]
		if tip then
			t.gain:SetText(tip.dps and tip.dps >= 1 and ("+" .. Commas(tip.dps) .. " DPS") or "")
			t.text:SetText(tip.text)
		else
			t.gain:SetText("")
			t.text:SetText(i == 1 and #tips == 0 and "Nothing stood out in this pull. Nice." or "")
		end
	end
end

local function BuildSpells(p)
	local f = CreateFrame("Frame", nil, p)
	f:SetAllPoints()
	local cols = { { "Spell", 0 }, { "Damage", 250 }, { "Share", 330 }, { "Per press", 430 }, { "Presses", 510 }, { "Per min", 570 } }
	for _, c in ipairs(cols) do
		local h = Text(f, "GameFontNormal", unpack(GOLD))
		h:SetPoint("TOPLEFT", c[2], 0)
		h:SetText(c[1])
	end
	f.rows = {}
	for i = 1, MAX_SPELL_ROWS do
		local y = -22 - (i - 1) * 22
		local row = {}
		row.icon = f:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("TOPLEFT", 0, y + 2)
		row.name = Text(f); row.name:SetPoint("TOPLEFT", 24, y); row.name:SetWidth(220)
		row.damage = Text(f); row.damage:SetPoint("TOPLEFT", 250, y)
		row.bar = f:CreateTexture(nil, "ARTWORK")
		row.bar:SetColorTexture(BAR[1], BAR[2], BAR[3], 0.8)
		row.bar:SetPoint("TOPLEFT", 330, y - 2)
		row.bar:SetHeight(10)
		row.share = Text(f); row.share:SetPoint("TOPLEFT", 390, y)
		row.perPress = Text(f); row.perPress:SetPoint("TOPLEFT", 430, y)
		row.presses = Text(f); row.presses:SetPoint("TOPLEFT", 510, y)
		row.perMin = Text(f); row.perMin:SetPoint("TOPLEFT", 570, y)
		f.rows[i] = row
	end
	f.note = Text(f, "GameFontHighlightSmall", unpack(GREY))
	f.note:SetPoint("BOTTOMLEFT", 0, 0)
	f.note:SetWidth(W - 40)
	f.note:SetText("Rows with no presses are auto attacks, poisons, procs and cleave, which the game lists under their own names.")
	return f
end

local function FillSpells(f, pull)
	local rows = L:SpellRows(pull)
	local total = pull.damage or 0
	for i, r in ipairs(f.rows) do
		local s = rows[i]
		local shown = s ~= nil
		for _, k in ipairs({ "icon", "name", "damage", "bar", "share", "perPress", "presses", "perMin" }) do
			if shown then r[k]:Show() else r[k]:Hide() end
		end
		if shown then
			r.icon:SetTexture(L:SpellIcon(s.id) or 134400)
			r.name:SetText(L:SpellName(s.id))
			r.damage:SetText(s.damage > 0 and Commas(s.damage) or "-")
			local share = total > 0 and s.damage / total or 0
			r.bar:SetWidth(math.max(1, 56 * share))
			r.share:SetText(string.format("%d%%", math.floor(share * 100 + 0.5)))
			r.perPress:SetText(s.perPress and Commas(s.perPress) or "-")
			r.presses:SetText(s.presses > 0 and tostring(s.presses) or "-")
			r.perMin:SetText(s.presses > 0 and string.format("%.1f", s.perMinute) or "-")
		end
	end
end

local function BuildHistory(p)
	local f = CreateFrame("Frame", nil, p)
	f:SetAllPoints()
	local cols = { { "When", 0 }, { "Where", 120 }, { "Kind", 300 }, { "Length", 400 }, { "DPS", 470 } }
	for _, c in ipairs(cols) do
		local h = Text(f, "GameFontNormal", unpack(GOLD))
		h:SetPoint("TOPLEFT", c[2], 0)
		h:SetText(c[1])
	end
	f.rows = {}
	for i = 1, MAX_HISTORY_ROWS do
		local y = -22 - (i - 1) * 22
		local b = CreateFrame("Button", nil, f)
		b:SetPoint("TOPLEFT", 0, y + 3)
		b:SetSize(W - 40, 20)
		b.hl = b:CreateTexture(nil, "BACKGROUND")
		b.hl:SetAllPoints()
		b.hl:SetColorTexture(1, 1, 1, 0.08)
		b.hl:Hide()
		b.when = Text(b); b.when:SetPoint("TOPLEFT", 0, -3)
		b.zone = Text(b); b.zone:SetPoint("TOPLEFT", 120, -3); b.zone:SetWidth(170)
		b.kind = Text(b); b.kind:SetPoint("TOPLEFT", 300, -3)
		b.len = Text(b); b.len:SetPoint("TOPLEFT", 400, -3)
		b.dps = Text(b); b.dps:SetPoint("TOPLEFT", 470, -3)
		b.bar = b:CreateTexture(nil, "ARTWORK")
		b.bar:SetColorTexture(BAR[1], BAR[2], BAR[3], 0.8)
		b.bar:SetPoint("TOPLEFT", 530, -6)
		b.bar:SetHeight(10)
		b:SetScript("OnEnter", function(self) self.hl:Show() end)
		b:SetScript("OnLeave", function(self) if self.pull ~= Pull() then self.hl:Hide() end end)
		b:SetScript("OnClick", function(self)
			selected = self.pull
			page = "last"
			KUI.LiftWindowRefresh()
		end)
		f.rows[i] = b
	end
	return f
end

local function FillHistory(f, current)
	local pulls = L:DB().pulls
	local top = 0
	for i = 1, math.min(#pulls, MAX_HISTORY_ROWS) do top = math.max(top, pulls[i].dps or 0) end
	for i, b in ipairs(f.rows) do
		local p = pulls[i]
		b.pull = p
		if p then
			b:Show()
			b.when:SetText(p.date or "?")
			b.zone:SetText(p.zone or "?")
			b.kind:SetText(L.KIND_NAMES[p.kind] or p.kind or "?")
			b.len:SetText(Seconds(p.length))
			b.dps:SetText(p.dps and Commas(p.dps) or "-")
			b.bar:SetWidth(math.max(1, 80 * ((p.dps or 0) / math.max(top, 1))))
			if p == current then b.hl:Show() else b.hl:Hide() end
		else
			b:Hide()
		end
	end
end

local MAX_LAB_ROWS = 6
local function BuildLab(p)
	local f = CreateFrame("Frame", nil, p)
	f:SetAllPoints()
	f.status = Text(f, "GameFontNormal", unpack(GOLD))
	f.status:SetPoint("TOPLEFT", 0, 0)
	f.status:SetWidth(W - 40)
	local cols = { { "Test", 0 }, { "Fights", 200 }, { "Average DPS", 280 }, { "Spread (+/-)", 400 } }
	for _, c in ipairs(cols) do
		local h = Text(f, "GameFontNormal", unpack(GREY))
		h:SetPoint("TOPLEFT", c[2], -30)
		h:SetText(c[1])
	end
	f.rows = {}
	for i = 1, MAX_LAB_ROWS do
		local y = -52 - (i - 1) * 22
		local r = {}
		r.tag = Text(f); r.tag:SetPoint("TOPLEFT", 0, y); r.tag:SetWidth(190)
		r.n = Text(f); r.n:SetPoint("TOPLEFT", 200, y)
		r.mean = Text(f); r.mean:SetPoint("TOPLEFT", 280, y)
		r.sd = Text(f); r.sd:SetPoint("TOPLEFT", 400, y)
		f.rows[i] = r
	end
	f.verdict = Text(f, "GameFontHighlightLarge", unpack(GREEN))
	f.verdict:SetPoint("TOPLEFT", 0, -52 - MAX_LAB_ROWS * 22 - 12)
	f.verdict:SetWidth(W - 40)
	f.verdict:SetWordWrap(true)
	f.help = Text(f, "GameFontHighlightSmall", unpack(GREY))
	f.help:SetPoint("BOTTOMLEFT", 0, 0)
	f.help:SetWidth(W - 40)
	f.help:SetWordWrap(true)
	f.help:SetText("How to test: on a target dummy, type /kl lab A and play one way for a few fights of about the same length, then /kl lab B and play the other way. Swap back and forth a few times. /kl lab stop ends tagging; /kl lab clear forgets the tests.")
	return f
end

local function FillLab(f)
	local tag = L:LabTag()
	f.status:SetText(tag and ("Now testing: " .. tag .. ".  Every fight is tagged until /kl lab stop.") or "Not testing. Type /kl lab A to start.")
	local res = L:LabResults()
	for i, r in ipairs(f.rows) do
		local g = res.groups[i]
		r.tag:SetText(g and g.tag or "")
		r.n:SetText(g and tostring(g.n) or "")
		r.mean:SetText(g and Commas(g.mean) or "")
		r.sd:SetText(g and g.n > 1 and Commas(g.sd) or "")
	end
	f.verdict:SetText(res.verdict or (#res.groups == 1 and "Now do some fights the other way under another name." or ""))
end

local PAGES = { { key = "last", label = "Last pull" }, { key = "spells", label = "Spells" }, { key = "history", label = "History" }, { key = "lab", label = "Lab" } }

local function Build()
	local f = CreateFrame("Frame", "KainUIForeverLiftFrame", UIParent, "BackdropTemplate")
	f:SetSize(W, H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		f:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
		f:SetBackdropBorderColor(unpack(BORDER_GREY))
	end
	table.insert(UISpecialFrames, "KainUIForeverLiftFrame")

	local title = Text(f, "GameFontNormalLarge", unpack(GOLD))
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("K-Lift")
	f.sub = Text(f, "GameFontHighlightSmall", unpack(GREY))
	f.sub:SetPoint("LEFT", title, "RIGHT", 10, -1)

	local close = CreateFrame("Button", nil, f)
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -8, -8)
	local x = Text(close, "GameFontHighlight")
	x:SetPoint("CENTER")
	x:SetText("x")
	close:SetScript("OnClick", function() f:Hide() end)

	f.tabs = {}
	for i, pg in ipairs(PAGES) do
		local b = CreateFrame("Button", nil, f, "BackdropTemplate")
		b:SetSize(100, 22)
		b:SetPoint("TOPLEFT", 16 + (i - 1) * 106, -42)
		if b.SetBackdrop then
			b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
			b:SetBackdropBorderColor(unpack(BORDER_GREY))
		end
		b.label = Text(b, "GameFontHighlight")
		b.label:SetPoint("CENTER")
		b.label:SetText(pg.label)
		b.key = pg.key
		b:SetScript("OnClick", function(self) page = self.key; KUI.LiftWindowRefresh() end)
		f.tabs[i] = b
	end

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 20, -80)
	body:SetPoint("BOTTOMRIGHT", -20, 16)
	f.pages = { last = BuildLast(body), spells = BuildSpells(body), history = BuildHistory(body), lab = BuildLab(body) }
	f.empty = Text(body, "GameFontHighlight", unpack(GREY))
	f.empty:SetPoint("TOPLEFT", 0, 0)
	f.empty:SetWidth(W - 40)
	f.empty:SetText("No fights recorded yet. K-Lift watches quietly while you play: fight something, then open /kl again.")
	f:Hide()
	return f
end

function KUI.LiftWindowRefresh()
	if not win or not win:IsShown() then return end
	local db = L:DB()
	local pull = Pull()
	for _, b in ipairs(win.tabs) do
		if b.SetBackdropColor then
			if b.key == page then b:SetBackdropColor(0.25, 0.2, 0.08, 1) else b:SetBackdropColor(0, 0, 0, 0.6) end
		end
	end
	local off = db and not db.enabled
	win.sub:SetText(off and "Recording is off (/kl on)" or (pull and (pull.date or "") or ""))
	for key, pg in pairs(win.pages) do
		if key == page and (pull or key == "lab") then pg:Show() else pg:Hide() end
	end
	if page == "lab" then win.empty:Hide(); FillLab(win.pages.lab) return end
	if not pull then win.empty:Show() return end
	win.empty:Hide()
	if page == "last" then FillLast(win.pages.last, pull)
	elseif page == "spells" then FillSpells(win.pages.spells, pull)
	else FillHistory(win.pages.history, pull) end
end

function KUI:ToggleLiftWindow()
	if not win then win = Build() end
	if win:IsShown() then win:Hide() return end
	selected = nil
	page = "last"
	win:Show()
	KUI.LiftWindowRefresh()
end

L.OnNewPull = function()
	if win and win:IsShown() then
		selected = nil
		KUI.LiftWindowRefresh()
	end
end

local exportBox
local function ShowExport()
	local text, why = L:ExportText()
	if not text then print("|cff33ff99K-Lift|r " .. why) return end
	if not exportBox then
		local f = CreateFrame("Frame", "KainUIForeverLiftExport", UIParent, "BackdropTemplate")
		f:SetSize(560, 400)
		f:SetPoint("CENTER")
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
			f:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
			f:SetBackdropBorderColor(unpack(BORDER_GREY))
		end
		table.insert(UISpecialFrames, "KainUIForeverLiftExport")
		local title = Text(f, "GameFontNormal", unpack(GOLD))
		title:SetPoint("TOPLEFT", 14, -12)
		title:SetText("K-Lift export: press Ctrl+C to copy it")
		local close = CreateFrame("Button", nil, f)
		close:SetSize(20, 20)
		close:SetPoint("TOPRIGHT", -8, -8)
		local x = Text(close, "GameFontHighlight")
		x:SetPoint("CENTER")
		x:SetText("x")
		close:SetScript("OnClick", function() f:Hide() end)
		local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 14, -36)
		scroll:SetPoint("BOTTOMRIGHT", -32, 14)
		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(500)
		edit:SetScript("OnEscapePressed", function() f:Hide() end)
		edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.text or ""); self:HighlightText() end end)
		scroll:SetScrollChild(edit)
		f.edit = edit
		exportBox = f
	end
	exportBox.text = text
	exportBox.edit:SetText(text)
	exportBox:Show()
	exportBox.edit:SetFocus()
	exportBox.edit:HighlightText()
end
KUI.LiftShowExport = ShowExport

SLASH_KAINUILIFT1 = "/kl"
SLASH_KAINUILIFT2 = "/klift"
SlashCmdList["KAINUILIFT"] = function(msg)
	local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
	if cmd == "off" then
		L:SetEnabled(false)
		print("|cff33ff99K-Lift|r stopped recording. /kl on starts it again.")
	elseif cmd == "on" then
		L:SetEnabled(true)
		print("|cff33ff99K-Lift|r is recording your fights.")
	elseif cmd == "lab" then
		local arg = (msg or ""):match("^%s*%S+%s+(.-)%s*$") or ""
		local low = arg:lower()
		if low == "stop" then
			L:SetLabTag(nil)
			print("|cff33ff99K-Lift lab|r: stopped tagging fights.")
		elseif low == "clear" then
			L:ClearLab()
			print("|cff33ff99K-Lift lab|r: forgot every test.")
		elseif arg ~= "" then
			L:SetLabTag(arg)
			print("|cff33ff99K-Lift lab|r: fights are now tagged '" .. L:LabTag() .. "'. Switch with /kl lab <name>, end with /kl lab stop.")
		end
		if not win then win = Build() end
		page = "lab"
		win:Show()
		KUI.LiftWindowRefresh()
	elseif cmd == "export" then
		ShowExport()
	elseif cmd == "reset" then
		L:Reset()
		print("|cff33ff99K-Lift|r forgot every recorded pull.")
		KUI.LiftWindowRefresh()
	else
		KUI:ToggleLiftWindow()
	end
end
