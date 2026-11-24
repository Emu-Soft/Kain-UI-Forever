local _, KUI = ...
local M = KUI.Market
local UI = M.UI

local CARD_W, CARD_H = 680, 520
local STAGE_W, STAGE_H = 632, 230
local Y = "|cffe0bb00"
local G = "|cff08d36b"
local R = "|r"

local LINEN, WOOL, SILK, MAGEWEAVE, RUNECLOTH = 2589, 2592, 4306, 4338, 14047
local PEACEBLOOM, SILVERLEAF, COPPER_BAR = 2447, 765, 2840
local LETTER = "Interface\\Icons\\INV_Letter_15"
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"

local function Coins(copper)
	return (M.Prices and M.Prices.Coins or M.ShortMoney)(copper)
end

local function Label(parent, text, style, color, justify)
	local fs = UI.Text(parent, style or "body/regular/x-small", color or "text", justify)
	fs:SetText(text)
	return fs
end

local function Mock(parent, text, w, h, kind)
	local b = UI.Button(parent, text, w, h or 24, kind or "secondary")
	b:EnableMouse(false)
	return b
end

local function Icon(parent, what, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size or 24, size or 24)
	t:SetTexture(type(what) == "number" and M.ItemIcon(what) or what)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return t
end

local function Icons(parent, list, size, gap)
	local row = CreateFrame("Frame", nil, parent)
	size, gap = size or 24, gap or 4
	row:SetSize(#list * (size + gap) - gap, size)
	for i, what in ipairs(list) do
		Icon(row, what, size):SetPoint("LEFT", (i - 1) * (size + gap), 0)
	end
	return row
end

local function Chip(parent, text, w, h, icon, key)
	local f = UI.Panel(parent, key or "high", 4)
	f:SetSize(w, h or 30)
	local x = 8
	if icon then
		Icon(f, icon, 20):SetPoint("LEFT", 6, 0)
		x = 32
	end
	local fs = Label(f, text, "body/regular/x-small", "text")
	fs:SetPoint("LEFT", x, 0); fs:SetPoint("RIGHT", -6, 0)
	f.text = fs
	return f
end

local function Outline(target, pad, holder)
	pad = pad or 3
	local f = CreateFrame("Frame", nil, holder or target:GetParent())
	f:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
	f:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
	f:SetFrameLevel(target:GetFrameLevel() + 2)
	local top, bottom = UI.Rule(f, "accent"), UI.Rule(f, "accent")
	local left, right = UI.Rule(f, "accent", true), UI.Rule(f, "accent", true)
	for _, t in ipairs({ top, bottom, left, right }) do t:SetDrawLayer("OVERLAY") end
	top:SetHeight(2); bottom:SetHeight(2); left:SetWidth(2); right:SetWidth(2)
	top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")
	bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT")
	left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
	right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
	return f
end

local function Box(target, pad) return Outline(target, pad) end

local function Arrow(parent)
	return Label(parent, ">", "body/bold/h6", "accent", "CENTER")
end

local function Note(parent, text)
	return Label(parent, "<  " .. text, "body/medium/x-small", "accent")
end

local function Flow(stage, frames, y)
	local gap, arrowW = 10, 14
	local total = 0
	for _, f in ipairs(frames) do total = total + f:GetWidth() end
	total = total + (#frames - 1) * (gap * 2 + arrowW)
	local x = (STAGE_W - total) / 2
	for i, f in ipairs(frames) do
		f:SetPoint("LEFT", stage, "TOPLEFT", x, -(y or STAGE_H / 2))
		x = x + f:GetWidth()
		if i < #frames then
			Arrow(stage):SetPoint("CENTER", stage, "TOPLEFT", x + gap + arrowW / 2, -(y or STAGE_H / 2))
			x = x + gap * 2 + arrowW
		end
	end
end

local function Tile(stage, caption, w, h)
	local f = UI.Panel(stage, "medium", 6)
	f:SetSize(w or 170, h or 120)
	local c = Label(f, caption, "body/medium/x-small", "textLow", "CENTER")
	c:SetPoint("BOTTOM", 0, 10)
	return f
end

local function AnyGroupHasOp()
	for _, g in pairs(M:DB().groups) do
		if type(g) == "table" and type(g.ops) == "table" then
			for _, op in pairs(g.ops) do if type(op) == "string" then return true end end
		end
	end
	return false
end

local function CharacterCount()
	local n = 0
	for _ in pairs(M:DB().chars) do n = n + 1 end
	return n
end

local STEPS = {
	{ text = "Make your groups: Default Groups, or New Group", go = 2, button = "Start with Groups",
		done = function() return #M:GroupPaths() > 0 end },
	{ text = "Make an operation: + New beside Mailing, Crafter or Auctioning", go = 3, button = "Go to Operations",
		done = function() return next(M:DB().ops) ~= nil end },
	{ text = "Pick that operation for a group, on the Groups page", go = 2, button = "Go to Groups",
		done = AnyGroupHasOp },
	{ text = "Log in once on each alt, so K-Market knows them",
		done = function() return CharacterCount() > 1 end,
		status = function() local n = CharacterCount() return n .. (n == 1 and " character" or " characters") end },
}
M.TUTORIAL_STEPS = STEPS

local function NextStep()
	for _, s in ipairs(STEPS) do
		if s.go and not s.done() then return s end
	end
end

local panel
local GoTo

local PAGES = {
	{
		title = "What K-Market does",
		text = Y .. "Sort" .. R .. "    Put the items you trade into groups.\n"
			.. Y .. "Send and post" .. R .. "    At the mailbox and Auction House, one button does the work.\n"
			.. Y .. "Watch your gold" .. R .. "    The Dashboard graphs the gold on every character you log in.\n\n"
			.. "It works like TradeSkillMaster, with fewer settings.",
		picture = function(stage)
			local groups = Tile(stage, "Groups")
			Icons(groups, { LINEN, WOOL, SILK, PEACEBLOOM }, 28):SetPoint("CENTER", 0, 14)
			local clicks = Tile(stage, "Mailbox and Auction House")
			Icons(clicks, { LETTER, COIN }, 32, 16):SetPoint("CENTER", 0, 14)
			local gold = Tile(stage, "Dashboard")
			Label(gold, Coins(3018220), "numeric/regular/p", "text", "CENTER"):SetPoint("CENTER", 0, 14)
			Flow(stage, { groups, clicks, gold })
		end,
	},
	{
		title = "Groups",
		show = 2,
		text = "A group is a list of items you handle the same way: Cloth, Herbs, Greens. Each item is in one group.\n\n"
			.. Y .. "Default Groups" .. R .. " makes a starter set (reagents by profession, cloth, "
			.. "bind-on-equip gear, consumables) and fills it from your bags.",
		picture = function(stage)
			local list = UI.Panel(stage, "medium", 6)
			list:SetSize(380, 190)
			list:SetPoint("LEFT", 20, 0)
			local rows = {
				{ "Cloth", { LINEN, WOOL, SILK, MAGEWEAVE }, 0 },
				{ "Runecloth", { RUNECLOTH }, 24 },
				{ "Herbs", { PEACEBLOOM, SILVERLEAF }, 0 },
				{ "Smithing", { COPPER_BAR }, 0 },
			}
			for i, r in ipairs(rows) do
				local y = -14 - (i - 1) * 44
				local name = Label(list, r[1], "body/medium/small", i == 1 and "accent" or "text")
				name:SetPoint("TOPLEFT", 14 + r[3], y)
				Icons(list, r[2], 20):SetPoint("TOPLEFT", 14 + r[3], y - 18)
			end
			local new = Mock(stage, "New Group", 130, 26, "primary")
			new:SetPoint("TOPLEFT", list, "TOPRIGHT", 30, -20)
			local defaults = Mock(stage, "Default Groups", 130, 26)
			defaults:SetPoint("TOPLEFT", new, "BOTTOMLEFT", 0, -14)
			Box(defaults)
			Note(stage, "start here"):SetPoint("LEFT", defaults, "RIGHT", 10, 0)
		end,
	},
	{
		title = "Operations",
		show = 3,
		text = "An operation is a job you give a group. A group can have one of each kind:\n\n"
			.. Y .. "Mailing" .. R .. "    Send to an alt. Keep some back.\n"
			.. Y .. "Crafter" .. R .. "    Send reagents to whoever crafts with them.\n"
			.. Y .. "Auctioning" .. R .. "    Your price: undercut, minimum, maximum.\n\n"
			.. "An operation does nothing until a group uses it: pick it on the Groups page.",
		picture = function(stage)
			Flow(stage, {
				Chip(stage, "Cloth", 120, 32, LINEN),
				Chip(stage, "Mailing: to Bankie Vault, keep 0", 220, 32, nil, "accentDark"),
				Chip(stage, "Bankie Vault", 140, 32, LETTER),
			}, 50)
			Flow(stage, {
				Chip(stage, "Smithing", 120, 32, COPPER_BAR),
				Chip(stage, "Crafter: to your blacksmith", 220, 32, nil, "accentDark"),
				Chip(stage, "Blacksmith", 140, 32, LETTER),
			}, 115)
			Flow(stage, {
				Chip(stage, "Herbs", 120, 32, PEACEBLOOM),
				Chip(stage, "Auctioning: 1c under, min 50s", 220, 32, nil, "accentDark"),
				Chip(stage, "Auction House", 140, 32, COIN),
			}, 180)
		end,
	},
	{
		title = "At the mailbox",
		text = "K-Market's mailbox window opens instead of the game's. " .. Y .. "Blizzard UI" .. R .. " switches back, and it remembers.\n\n"
			.. Y .. "Send Groups" .. R .. "    On the Groups tab. Mails what your Mailing and Crafter operations ask for, in as few mails as it can.\n"
			.. Y .. "Open All" .. R .. "    Takes everything from your inbox and records your sales.\n\n"
			.. "K-Market adds your alts to your friends list, so the game doesn't ask \"are you sure?\" each time.",
		picture = function(stage)
			local win = UI.Panel(stage, "medium", 6)
			win:SetSize(420, 196)
			win:SetPoint("LEFT", 20, 0)
			Label(win, "Inbox     " .. Y .. "Groups" .. R .. "     Send", "body/medium/small", "textLow"):SetPoint("TOPLEFT", 14, -12)
			local send = Mock(win, "Send Groups", 120, 26, "primary")
			send:SetPoint("TOPLEFT", 14, -40)
			Box(send)
			local rows = {
				{ "Bankie Vault", { LINEN, WOOL, SILK, PEACEBLOOM }, "2 mails" },
				{ "Blacksmith", { COPPER_BAR }, "1 mail" },
			}
			for i, r in ipairs(rows) do
				local y = -84 - (i - 1) * 50
				Label(win, r[1], "body/medium/small", "text"):SetPoint("TOPLEFT", 14, y)
				Label(win, r[3], "body/regular/x-small", "textLow", "RIGHT"):SetPoint("TOPRIGHT", -14, y)
				Icons(win, r[2], 20):SetPoint("TOPLEFT", 14, y - 18)
			end
			Note(stage, "one click"):SetPoint("LEFT", win, "RIGHT", 12, 45)
		end,
	},
	{
		title = "At the Auction House",
		text = "The K-Market panel sits to the right of the Auction House. One button does the selling, and its label changes as you go:\n\n"
			.. Y .. "1" .. R .. "  " .. Y .. "Load Next" .. R .. " puts your next group item in the Sell tab at your price.\n"
			.. Y .. "2" .. R .. "  " .. Y .. "Post" .. R .. " lists it, and the next item loads by itself.\n"
			.. Y .. "3" .. R .. "  Keep clicking Post: one click, one listing. If the game says you're too fast, click again.\n\n"
			.. Y .. "Skip" .. R .. " passes an item. " .. Y .. "Next Item" .. R .. " shows when an item has no price. "
			.. "Right-click any bag item to sell it instead.",
		picture = function(stage)
			local p = UI.Panel(stage, "surface", 6)
			p:SetSize(280, 214)
			p:SetPoint("LEFT", 20, 0)
			Label(p, "K-Market", "body/bold/small", "accent"):SetPoint("TOPLEFT", 12, -10)
			local sum = Label(p, "Posted " .. Coins(34200) .. "    Sold " .. Coins(26800), "numeric/regular/x-small", "text")
			sum:SetPoint("TOPLEFT", 12, -30)
			local post = Mock(p, "Post " .. M.ShortMoney(15400) .. " x20", 186, 26, "primary")
			post:SetPoint("TOPLEFT", 12, -50)
			Box(post)
			local skip = Mock(p, "Skip", 62, 26)
			skip:SetPoint("TOPRIGHT", -12, -50)
			local rows = {
				{ LINEN, "Linen Cloth  x20", "in the Sell tab", "positive" },
				{ WOOL, "Wool Cloth  x40", "click to load", "textLow" },
				{ SILK, "Silk Cloth  x12", "listed", "textLow" },
			}
			for i, r in ipairs(rows) do
				local y = -92 - (i - 1) * 38
				Icon(p, r[1], 24):SetPoint("TOPLEFT", 12, y)
				Label(p, r[2], "body/regular/x-small", "text"):SetPoint("TOPLEFT", 44, y)
				Label(p, r[3], "body/regular/x-small", r[4]):SetPoint("TOPLEFT", 44, y - 13)
			end
			Note(stage, "your auctions: up for sale, and sold"):SetPoint("LEFT", p, "TOPRIGHT", 12, -36)
			Note(stage, "Load Next, then Post, Post, Post"):SetPoint("LEFT", p, "TOPRIGHT", 12, -63)
			Note(stage, "click a row to load that one"):SetPoint("LEFT", p, "TOPRIGHT", 12, -130)
		end,
	},
	{
		title = "Prices",
		text = "Auctioning prices can be fixed (1g 50s) or follow the market (90% market).\n\n"
			.. "Market prices come from the free " .. Y .. "K-Market Prices" .. R .. " app (its address is below). "
			.. "Item tooltips then show the K-Market Value and how old it is: green when it's fresh, red when it's a day old.",
		picture = function(stage)
			local tip = UI.Panel(stage, "high", 6)
			tip:SetSize(220, 96)
			Label(tip, "Runecloth", "body/medium/small", "text"):SetPoint("TOPLEFT", 12, -12)
			local value = Label(tip, "K-Market Value", "body/regular/x-small", "textLow")
			value:SetPoint("TOPLEFT", 12, -40)
			Label(tip, Coins(4500), "numeric/regular/x-small", "text", "RIGHT"):SetPoint("TOPRIGHT", -12, -40)
			Label(tip, G .. "Updated 12 min ago" .. R, "body/regular/x-small", "text"):SetPoint("TOPLEFT", 12, -62)
			local rule = Chip(stage, "Post at: 90% market", 170, 32, RUNECLOTH, "accentDark")
			local post = Chip(stage, "Post " .. M.ShortMoney(4050) .. " each", 140, 32, COIN)
			Flow(stage, { tip, rule, post }, 82)

			local label = Label(stage, "K-Market Prices app:", "body/medium/x-small", "textLow")
			label:SetPoint("TOPLEFT", 24, -176)
			local box = UI.Input(stage, 330, 26)
			box:SetPoint("LEFT", label, "RIGHT", 10, 0)

			local edge = UI.Panel(stage, "outline", 5)
			edge:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
			edge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
			edge:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
			box:SetText(M.PRICES_APP_ADDRESS)
			box:SetScript("OnTextChanged", function(self, typed) if typed then self:SetText(M.PRICES_APP_ADDRESS); self:HighlightText() end end)
			box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
			box:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
			Label(stage, "click, then Ctrl+C", "body/medium/x-small", "accent"):SetPoint("LEFT", box, "RIGHT", 10, 0)
			stage.address = box
		end,
	},
	{
		title = "Set it up",
		checklist = true,
		text = "Four steps, ticked off as you do them. " .. Y .. "Go" .. R .. " takes you there.\n\n"
			.. "Then: at the mailbox, " .. Y .. "Send Groups" .. R .. ". At the Auction House, " .. Y .. "Post" .. R .. " until it's done.",
		picture = function(stage)
			stage.rows = {}
			for i, s in ipairs(STEPS) do
				local row = CreateFrame("Frame", nil, stage)
				row:SetSize(STAGE_W - 40, 40)
				row:SetPoint("TOPLEFT", 20, -14 - (i - 1) * 52)
				UI.Rounded(row, "medium", 6)
				row.mark = row:CreateTexture(nil, "ARTWORK")
				row.mark:SetSize(16, 16)
				row.mark:SetPoint("LEFT", 14, 0)
				row.num = Label(row, tostring(i), "numeric/regular/x-small", "textLow", "CENTER")
				row.num:SetPoint("CENTER", row.mark, "CENTER", 0, 0)
				row.text = Label(row, s.text, "body/regular/small", "text")
				row.text:SetPoint("LEFT", 42, 0)
				row.text:SetPoint("RIGHT", -110, 0)
				row.state = Label(row, "", "body/medium/x-small", "positive", "RIGHT")
				row.state:SetPoint("RIGHT", -14, 0)
				if s.go then
					row.go = UI.Button(row, "Go", 72, 24, "secondary")
					row.go:SetPoint("RIGHT", -10, 0)
					row.go:SetScript("OnClick", function() GoTo(s.go) end)
				end
				stage.rows[i] = row
			end
		end,
		refresh = function(stage)
			for i, s in ipairs(STEPS) do
				local row, done = stage.rows[i], s.done()
				row.mark:SetTexture(done and UI.ROUND or UI.CIRCLE)
				UI.Tint(row.mark, done and "positive" or "textLow")
				row.num:SetShown(not done)
				UI.TextColor(row.text, done and "textLow" or "text")
				if row.go then row.go:SetShown(not done) end
				row.state:SetText(done and "Done" or (s.status and s.status() or ""))
				UI.TextColor(row.state, done and "positive" or "textLow")
				row.done = done
			end
		end,
	},
}
M.TUTORIAL_PAGES = PAGES
M.PRICES_APP_ADDRESS = "github.com/Emu-Soft/K-Market-Prices"

local at = 1

local function Seen() return M.Settings and M.Settings().tutorialSeen end

local function LastAction()
	local s = NextStep()
	return s and s.button or "Done", s and s.go
end

local function ShowAt(i)
	at = math.max(1, math.min(#PAGES, i))
	local page = PAGES[at]
	panel.title:SetText(page.title)
	panel.text:SetText(page.text)
	panel.step:SetText(at .. " / " .. #PAGES)
	panel.back:SetKMEnabled(at > 1)
	panel.show:SetShown(page.show ~= nil)
	for j, s in pairs(panel.stages) do s:SetShown(j == at) end
	if not panel.stages[at] and page.picture then
		local stage = CreateFrame("Frame", nil, panel.stageBox)
		stage:SetAllPoints()
		page.picture(stage)
		panel.stages[at] = stage
	end
	if page.refresh then page.refresh(panel.stages[at]) end
	UI.ButtonText(panel.next, at == #PAGES and (LastAction()) or "Next")
end

GoTo = function(page)
	panel:Hide()
	M:ToggleWindow(page)
end

local function Build()
	local parent = M.frame
	panel = CreateFrame("Frame", "KainUIForeverMarketTutorial", parent)
	panel:SetPoint("TOPLEFT", 0, -44)
	panel:SetPoint("BOTTOMRIGHT")
	panel:SetFrameLevel(parent:GetFrameLevel() + 40)
	panel:EnableMouse(true)
	local shade = panel:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints()
	UI.Fill(shade, "lowest", 0.85)
	local card = UI.Panel(panel, "low", 6)
	card:SetSize(CARD_W, CARD_H)
	card:SetPoint("CENTER")
	panel.title = UI.Text(card, "body/bold/h6", "accent")
	panel.title:SetPoint("TOPLEFT", 24, -22)
	panel.text = UI.Text(card, "body/regular/small", "text")
	panel.text:SetPoint("TOPLEFT", 24, -58)
	panel.text:SetPoint("RIGHT", -24, 0)
	panel.text:SetWordWrap(true)
	panel.text:SetJustifyV("TOP")
	panel.text:SetSpacing(4)

	panel.stageBox = UI.Panel(card, "lowest", 6)
	panel.stageBox:SetSize(STAGE_W, STAGE_H)
	panel.stageBox:SetPoint("BOTTOM", 0, 56)
	panel.stages = {}
	panel.step = UI.Text(card, "numeric/regular/x-small", "textLow")
	panel.step:SetPoint("BOTTOMLEFT", 24, 22)

	panel.show = UI.Button(card, "Show me", 100, 26, "secondary", "KainUIForeverMarketTutorialShowMe")
	panel.show:SetPoint("BOTTOMLEFT", 72, 16)
	panel.show:SetScript("OnClick", function() GoTo(PAGES[at].show) end)
	panel.next = UI.Button(card, "Next", 150, 26, "primary", "KainUIForeverMarketTutorialNext")
	panel.next:SetPoint("BOTTOMRIGHT", -24, 16)
	panel.next:SetScript("OnClick", function()
		if at < #PAGES then ShowAt(at + 1) return end
		local _, go = LastAction()
		if go then GoTo(go) else panel:Hide() end
	end)
	panel.back = UI.Button(card, "Back", 100, 26, "secondary")
	panel.back:SetPoint("RIGHT", panel.next, "LEFT", -8, 0)
	panel.back:SetScript("OnClick", function() ShowAt(at - 1) end)
	local close = UI.Button(card, "X", 24, 24, "tertiary")
	close:SetPoint("TOPRIGHT", -10, -10)
	close:SetScript("OnClick", function() panel:Hide() end)

	panel:SetScript("OnHide", function() M:RefreshWindow() end)
	M.tutorial = panel
end

function M:ShowTutorial()
	if not (self.frame and self.frame:IsShown()) then self:ToggleWindow(1) end
	if not panel then Build() end
	local start = (Seen() and #self:GroupPaths() == 0) and #PAGES or 1
	if M.Settings then M.Settings().tutorialSeen = true end
	self:RefreshTutorialButton()
	ShowAt(start)
	panel:Show()
end

function M:RefreshTutorialButton()
	local b = self.frame and self.frame.help
	if not b then return end
	if Seen() then
		b:SetScript("OnUpdate", nil)
		b.kmBg:SetColor("high", 1)
		UI.TextColor(b.kmText, "text")
		return
	end
	if b.kmPulsing then return end
	b.kmPulsing = true
	local t = 0
	b:SetScript("OnUpdate", function(button, elapsed)
		t = t + elapsed
		local a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 4))
		button.kmBg:SetColor("accent", a)
		UI.TextColor(button.kmText, a > 0.6 and "onAccent" or "text")
		if Seen() then button.kmPulsing = nil; M:RefreshTutorialButton() end
	end)
end

local callout, current, ShowNextHint
local queue = {}

local function HintsSeen()
	local d = M.Settings()
	if type(d.hints) ~= "table" then d.hints = {} end
	return d.hints
end

local function TargetOf(h)
	local t = h[2]
	if type(t) == "function" then t = t() end
	return t
end

local function BuildCallout()
	callout = UI.Panel(UIParent, "high", 6)
	callout:SetFrameStrata("DIALOG")
	callout:SetSize(260, 80)
	callout:SetClampedToScreen(true)
	callout:EnableMouse(true)
	callout:Hide()
	Outline(callout, 0, callout)
	callout.text = UI.Text(callout, "body/regular/small", "text")
	callout.text:SetPoint("TOPLEFT", 12, -12)
	callout.text:SetWidth(236)
	callout.text:SetWordWrap(true)
	callout.text:SetJustifyH("LEFT")
	callout.ok = UI.Button(callout, "Got it", 70, 22, "primary", "KainUIForeverMarketHintOK")
	callout.ok:SetPoint("BOTTOMRIGHT", -10, 10)
	callout.arrow = Label(callout, "", "body/bold/h6", "accent", "CENTER")
	callout:SetScript("OnUpdate", function()
		local t = current and TargetOf(current)
		if not (t and t:IsVisible()) then ShowNextHint() end
	end)
	M.hintCallout = callout
end

ShowNextHint = function()
	callout:Hide()
	current = nil
	local seen = HintsSeen()
	while #queue > 0 do
		local h = table.remove(queue, 1)
		local target = TargetOf(h)
		if not seen[h[1]] and target and target:IsVisible() then
			current = h
			callout.key = h[1]
			callout.text:SetText(h[3])
			callout:SetHeight((callout.text:GetStringHeight() or 30) + 54)
			callout:ClearAllPoints()
			callout.arrow:ClearAllPoints()
			if type(h[4]) == "table" then
				local dx = (h[4]:GetRight() or 0) - (target:GetRight() or 0)
				callout:SetPoint("LEFT", target, "RIGHT", dx + 18, 0)
				callout.arrow:SetText("<")
				callout.arrow:SetPoint("RIGHT", callout, "LEFT", -2, 0)
			elseif h[4] then
				callout:SetPoint("BOTTOM", target, "TOP", 0, 18)
				callout.arrow:SetText("v")
				callout.arrow:SetPoint("TOP", callout, "BOTTOM", 0, -1)
			else
				callout:SetPoint("TOP", target, "BOTTOM", 0, -18)
				callout.arrow:SetText("^")
				callout.arrow:SetPoint("BOTTOM", callout, "TOP", 0, -2)
			end
			callout.ok:SetScript("OnClick", function()
				HintsSeen()[h[1]] = true
				ShowNextHint()
			end)
			callout:Show()
			return
		end
	end
end

function M:Hint(list)
	local seen = HintsSeen()
	for _, h in ipairs(list) do
		local queued = current and current[1] == h[1]
		for _, q in ipairs(queue) do if q[1] == h[1] then queued = true end end
		if not seen[h[1]] and not queued then queue[#queue + 1] = h end
	end
	if not callout then BuildCallout() end
	if not callout:IsShown() then ShowNextHint() end
end

function M:HintMailbox(window, tabs, openAll)
	if not (window and window:IsShown()) then return end
	self:Hint({
		{ "mailGroups", tabs.tabs[2], "Your mail for alts is on the Groups tab: press Send Groups there and K-Market mails it all." },
		{ "mailOpen", openAll, "Open All takes everything from your inbox and records your sales for the Dashboard.", true },
	})
end

function M:HintMailGroups(send)
	self:Hint({ { "mailSend", send, "One click mails everything on this list, in as few mails as it can." } })
end

function M:HintAuctionHouse(panelAH)
	if not panelAH then return end
	self:Hint({
		{ "ahPost", panelAH.action, "This one button does the selling. Load Next puts your next group item in the Sell tab "
			.. "at your price, then Post lists it. One click a listing.", panelAH },
		{ "ahCancel", panelAH.cancelScan, "Cancel Scan finds your auctions someone has undercut. Then one click cancels each.", panelAH },
		{ "ahPrice", function() return panelAH.priceScan end, "Price Scan prices your recipes for the profit list beside the profession window.", panelAH },
	})
end

function M:HintDashboard(window)
	if not (window and window.totalHover) then return end
	self:Hint({ { "gold", window.totalHover, "Hover Total Gold to see each character's gold." } })
end
