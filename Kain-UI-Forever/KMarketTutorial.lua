local _, KUI = ...
local M = KUI.Market
local UI = M.UI

local PAGES = {
	{
		title = "What is this?",
		text = "K-Market is a trading helper built into K-UI.\n\n"
			.. "It remembers your gold on every character, sorts the items you trade into groups, "
			.. "and does the slow mailbox and Auction House clicking for you.\n\n"
			.. "If you have used TradeSkillMaster, it works the same way, with fewer knobs.",
	},
	{
		title = "How does it work?",
		text = "Two things: groups and operations.\n\n"
			.. "|cffe0bb00Groups|r are lists of items, sorted however suits you: Cloth, Herbs, Greens, Potions. "
			.. "An item sits in one group. A group can have subgroups.\n\n"
			.. "|cffe0bb00Operations|r are jobs: \"mail to my bank alt\", \"send to my crafter\", "
			.. "\"post on the Auction House at these prices\".\n\n"
			.. "Give a group an operation, and K-Market does that job for every item in it. "
			.. "Subgroups use their parent's operations unless you give them their own.",
	},
	{
		title = "How can it help you?",
		text = "Make groups from how you already play.\n\n"
			.. "Things you always send to your bank alt? Put them in a group: call it A.\n"
			.. "Greens you send to your disenchanter? Make a Greens group.\n"
			.. "Ore and bars for your blacksmith? A Mining group.\n\n"
			.. "Then make operations to close the circle: one mails group A to the bank alt, "
			.. "one mails Greens to the disenchanter, one sends Mining to the blacksmith, "
			.. "and one posts the bank alt's stock on the Auction House.\n\n"
			.. "After that, a trip to the mailbox is one click instead of fifty.",
	},
	{
		title = "Day to day",
		text = "|cffe0bb00At a mailbox:|r Send Groups mails everything your operations ask for, "
			.. "in as few mails as it can. Open All empties your inbox and notes your Auction House sales.\n\n"
			.. "|cffe0bb00At the Auction House|r (on your bank alt): Post Scan checks the prices, "
			.. "then each click of Post puts up one auction at your price. "
			.. "Cancel Scan finds your auctions that were undercut.\n\n"
			.. "|cffe0bb00In this window:|r the Dashboard shows your gold over time, "
			.. "and what you sold and bought.",
	},
	{
		title = "Getting started",
		text = "1. |cffe0bb00Groups|r page: New Group, then click items in your bags to add them "
			.. "(or Import a TradeSkillMaster list).\n\n"
			.. "2. |cffe0bb00Operations|r page: + New next to Mailing, Crafter or Auctioning. "
			.. "Set who it goes to and how many to keep.\n\n"
			.. "3. Back on |cffe0bb00Groups|r: pick that operation for the group.\n\n"
			.. "That's it. Your own alts are added to your friends list "
			.. "so the game doesn't ask \"are you sure?\" every time you mail them.",
	},
}
M.TUTORIAL_PAGES = PAGES

local panel
local at = 1

local function Seen() return M.Settings and M.Settings().tutorialSeen end

local function ShowAt(i)
	at = math.max(1, math.min(#PAGES, i))
	panel.title:SetText(PAGES[at].title)
	panel.text:SetText(PAGES[at].text)
	panel.step:SetText(at .. " / " .. #PAGES)
	panel.back:SetKMEnabled(at > 1)
	UI.ButtonText(panel.next, at == #PAGES and "Done" or "Next")
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
	local card = UI.Panel(panel, "medium", 6)
	card:SetSize(560, 420)
	card:SetPoint("CENTER")
	panel.title = UI.Text(card, "body/bold/h6", "accent")
	panel.title:SetPoint("TOPLEFT", 24, -22)
	panel.text = UI.Text(card, "body/regular/small", "text")
	panel.text:SetPoint("TOPLEFT", 24, -60)
	panel.text:SetPoint("RIGHT", -24, 0)
	panel.text:SetWordWrap(true)
	panel.text:SetJustifyV("TOP")
	panel.text:SetSpacing(3)
	panel.step = UI.Text(card, "numeric/regular/x-small", "textLow")
	panel.step:SetPoint("BOTTOMLEFT", 24, 22)
	panel.next = UI.Button(card, "Next", 100, 26, "primary", "KainUIForeverMarketTutorialNext")
	panel.next:SetPoint("BOTTOMRIGHT", -20, 16)
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
