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
local BAG = "Interface\\Icons\\INV_Misc_Bag_08"

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

local function Box(target, pad)
	pad = pad or 3
	local parent = target:GetParent()
	local f = CreateFrame("Frame", nil, parent)
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

local PAGES = {
	{
		title = "What K-Market does",
		text = Y .. "Gold" .. R .. "    Tracks the gold on every character you log in.\n"
			.. Y .. "Groups" .. R .. "    Sorts the items you trade into lists.\n"
			.. Y .. "Clicks" .. R .. "    Mails and lists those items for you.\n\n"
			.. "It works like TradeSkillMaster, with fewer settings.",
		picture = function(stage)
			local gold = Tile(stage, "Dashboard")
			Label(gold, Coins(3018220), "numeric/regular/p", "text", "CENTER"):SetPoint("CENTER", 0, 14)
			local groups = Tile(stage, "Groups")
			Icons(groups, { LINEN, WOOL, SILK, PEACEBLOOM }, 28):SetPoint("CENTER", 0, 14)
			local clicks = Tile(stage, "Mailbox and Auction House")
			Icons(clicks, { LETTER, COIN }, 32, 16):SetPoint("CENTER", 0, 14)
			Flow(stage, { gold, groups, clicks })
		end,
	},
	{
		title = "Groups",
		text = "A group is a list of items you handle the same way: Cloth, Herbs, Greens.\n"
			.. "Each item is in one group. A subgroup does what its parent does, unless you change it.\n\n"
			.. Y .. "Default Groups" .. R .. " makes a starter set (reagents by profession, cloth, "
			.. "bind-on-equip gear, consumables) and fills it from your bags.",
		picture = function(stage)
			local list = UI.Panel(stage, "medium", 6)
			list:SetSize(380, 190)
			list:SetPoint("LEFT", 20, 0)
			local rows = {
				{ "Cloth", { LINEN, WOOL, SILK, MAGEWEAVE }, 0 },
				{ "Runecloth  (subgroup of Cloth)", { RUNECLOTH }, 24 },
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
		text = "An operation is a job you give a group. A group can have one of each kind:\n\n"
			.. Y .. "Mailing" .. R .. "    Send to an alt. Keep some back.\n"
			.. Y .. "Crafter" .. R .. "    Send reagents to whoever crafts with them.\n"
			.. Y .. "Auctioning" .. R .. "    List at the going price, between your minimum and maximum.",
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
				Chip(stage, "Auctioning: going price, min 50s", 220, 32, nil, "accentDark"),
				Chip(stage, "Auction House", 140, 32, COIN),
			}, 180)
		end,
	},
	{
		title = "At the mailbox",
		text = "K-Market's mailbox window opens instead of the game's. " .. Y .. "Blizzard UI" .. R .. " switches back, and it remembers.\n\n"
			.. Y .. "Send Groups" .. R .. "    Mails what your Mailing and Crafter operations ask for, in as few mails as it can.\n"
			.. Y .. "Open All" .. R .. "    Takes everything from your inbox and records your sales.\n\n"
			.. "Your alts go on your friends list, so the game doesn't ask \"are you sure?\" each time.",
		picture = function(stage)
			local win = UI.Panel(stage, "medium", 6)
			win:SetSize(420, 196)
			win:SetPoint("LEFT", 20, 0)
			Label(win, "Inbox     Groups     Send", "body/medium/small", "textLow"):SetPoint("TOPLEFT", 14, -12)
			local send = Mock(win, "Send Groups", 120, 26, "primary")
			send:SetPoint("TOPLEFT", 14, -40)
			Box(send)
			local openAll = Mock(win, "Open All", 90, 26)
			openAll:SetPoint("LEFT", send, "RIGHT", 10, 0)
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
		text = "The K-Market panel sits to the right of the Auction House.\n\n"
			.. Y .. "1" .. R .. "  " .. Y .. "Load Next" .. R .. " puts your next group item in the Sell tab at the going price. Or right-click any bag item.\n"
			.. Y .. "2" .. R .. "  " .. Y .. "Post" .. R .. " lists it. The next item loads by itself.\n"
			.. Y .. "3" .. R .. "  Keep clicking Post: one click, one listing. If the game says you're too fast, click again.\n\n"
			.. Y .. "Skip" .. R .. " passes an item. " .. Y .. "Next Item" .. R .. " shows when an item has no price.",
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
			Note(stage, "click, click, click"):SetPoint("LEFT", p, "TOPRIGHT", 12, -63)
			Note(stage, "click a row to load that one"):SetPoint("LEFT", p, "TOPRIGHT", 12, -130)
		end,
	},
	{
		title = "Prices",
		text = "Auctioning lists at the going price: the cheapest auction up. No undercutting: the game sells the cheapest first anyway, so going lower only drops the price.\n"
			.. "Minimum, normal (nobody selling) and maximum can be fixed (1g 50s) or follow the market (90% market).\n\n"
			.. "Market prices come from the free " .. Y .. "K-Market Prices" .. R .. " app: github.com/Emu-Soft/K-Market-Prices. "
			.. "Tooltips show the K-Market Value and its age: green is fresh, red is a day old.\n\n"
			.. Y .. "Cancel Scan" .. R .. " finds your auctions with a cheaper one up, to list again at the going price.",
		picture = function(stage)
			local tip = UI.Panel(stage, "high", 6)
			tip:SetSize(220, 96)
			Label(tip, "Runecloth", "body/medium/small", "text"):SetPoint("TOPLEFT", 12, -12)
			local value = Label(tip, "K-Market Value", "body/regular/x-small", "textLow")
			value:SetPoint("TOPLEFT", 12, -40)
			Label(tip, Coins(4500), "numeric/regular/x-small", "text", "RIGHT"):SetPoint("TOPRIGHT", -12, -40)
			Label(tip, G .. "Updated 12 min ago" .. R, "body/regular/x-small", "text"):SetPoint("TOPLEFT", 12, -62)
			local rule = Chip(stage, "Cheapest up: " .. M.ShortMoney(4500), 170, 32, RUNECLOTH, "accentDark")
			local post = Chip(stage, "Post " .. M.ShortMoney(4500) .. " each", 140, 32, COIN)
			Flow(stage, { tip, rule, post })
		end,
	},
	{
		title = "Dashboard",
		text = "Your gold on all characters over time. Pick a range at the top right of the graph.\n"
			.. "Under it: what you sold, what you bought, and the profit for that range.\n\n"
			.. "Hover " .. Y .. "Total Gold" .. R .. " (top right of the window) to see each character's gold.",
		picture = function(stage)
			local graph = UI.Panel(stage, "medium", 6)
			graph:SetSize(360, 190)
			graph:SetPoint("LEFT", 20, 0)
			local heights = { 30, 34, 33, 40, 46, 44, 52, 60, 58, 66, 75, 72, 80, 92, 88, 100, 112, 108, 120, 134 }
			local barW = 14
			for i, h in ipairs(heights) do
				local bar = graph:CreateTexture(nil, "ARTWORK")
				UI.Fill(bar, "accent", 0.35 + 0.65 * i / #heights)
				bar:SetSize(barW, h)
				bar:SetPoint("BOTTOMLEFT", 16 + (i - 1) * (barW + 2), 22)
			end
			local axis = UI.Rule(graph, "outline")
			axis:SetPoint("BOTTOMLEFT", 12, 20); axis:SetPoint("BOTTOMRIGHT", -12, 20)
			local tip = UI.Panel(stage, "high", 6)
			tip:SetSize(220, 112)
			tip:SetPoint("TOPLEFT", graph, "TOPRIGHT", 24, 0)
			Label(tip, "TOTAL GOLD  " .. Coins(3018220), "body/medium/x-small", "textLow"):SetPoint("TOPLEFT", 12, -10)
			local chars = { { "Main", 2984855 }, { "Crafter", 32469 }, { "Bank alt", 896 } }
			for i, c in ipairs(chars) do
				local y = -34 - (i - 1) * 20
				Label(tip, c[1], "body/regular/x-small", "text"):SetPoint("TOPLEFT", 12, y)
				Label(tip, Coins(c[2]), "numeric/regular/x-small", "text", "RIGHT"):SetPoint("TOPRIGHT", -12, y)
			end
			Note(stage, "hover"):SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -8)
		end,
	},
	{
		title = "Set it up",
		text = Y .. "1" .. R .. "  " .. Y .. "Groups" .. R .. " page: Default Groups, or New Group and click items in the bag list. "
			.. "Import takes a TradeSkillMaster list.\n"
			.. Y .. "2" .. R .. "  " .. Y .. "Operations" .. R .. " page: + New beside Mailing, Crafter or Auctioning. Fill in who and how many.\n"
			.. Y .. "3" .. R .. "  Back on " .. Y .. "Groups" .. R .. ": pick that operation for the group.\n"
			.. Y .. "4" .. R .. "  Log in once on each alt, so K-Market knows them.\n\n"
			.. "Then: at the mailbox, Send Groups. At the Auction House, Post until it's done.",
		picture = function(stage)
			local steps = {
				Mock(stage, "1  Default Groups", 140, 30, "secondary"),
				Mock(stage, "2  + New", 100, 30, "secondary"),
				Mock(stage, "3  Pick operation", 140, 30, "secondary"),
				Chip(stage, "4  Log in alts", 120, 30, BAG),
			}
			Flow(stage, steps, 70)
			local mail = Mock(stage, "Send Groups", 130, 30, "primary")
			local post = Mock(stage, "Post", 130, 30, "primary")
			Flow(stage, { mail, post }, 160)
		end,
	},
}
M.TUTORIAL_PAGES = PAGES

local panel
local at = 1

local function Seen() return M.Settings and M.Settings().tutorialSeen end

local function ShowAt(i)
	at = math.max(1, math.min(#PAGES, i))
	local page = PAGES[at]
	panel.title:SetText(page.title)
	panel.text:SetText(page.text)
	panel.step:SetText(at .. " / " .. #PAGES)
	panel.back:SetKMEnabled(at > 1)
	UI.ButtonText(panel.next, at == #PAGES and "Done" or "Next")
	for j, s in pairs(panel.stages) do s:SetShown(j == at) end
	if not panel.stages[at] and page.picture then
		local stage = CreateFrame("Frame", nil, panel.stageBox)
		stage:SetAllPoints()
		page.picture(stage)
		panel.stages[at] = stage
	end
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
	panel.next = UI.Button(card, "Next", 100, 26, "primary", "KainUIForeverMarketTutorialNext")
	panel.next:SetPoint("BOTTOMRIGHT", -24, 16)
	panel.next:SetScript("OnClick", function()
		if at == #PAGES then panel:Hide() else ShowAt(at + 1) end
	end)
	panel.back = UI.Button(card, "Back", 100, 26, "secondary")
	panel.back:SetPoint("RIGHT", panel.next, "LEFT", -8, 0)
	panel.back:SetScript("OnClick", function() ShowAt(at - 1) end)
	local close = UI.Button(card, "X", 24, 24, "tertiary")
	close:SetPoint("TOPRIGHT", -10, -10)
	close:SetScript("OnClick", function() panel:Hide() end)
	M.tutorial = panel
end

function M:ShowTutorial()
	if not (self.frame and self.frame:IsShown()) then self:ToggleWindow(1) end
	if not panel then Build() end
	if M.Settings then M.Settings().tutorialSeen = true end
	self:RefreshTutorialButton()
	ShowAt(1)
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
