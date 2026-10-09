local CFG = {
	actionKeys = { "SPACE" },
	numKeysForGossip = true,
	numKeysForQuestRewards = true,
	treatNumpadAsNumbers = true,
	spaceSelectsFirstGossip = true,
	ignoreInProgressQuests = true,
	ignoreDisabledButtons = false,
	ignoreWithModifier = false,
	showGlow = true,

	dontAcceptInvite = true,
	dontClickSummons = true,
	dontClickDuels = true,
	dontClickRevives = true,
	dontClickReleases = true,
	dontAcceptInstanceLocks = false,
	dontAcceptAbandonVote = true,
	dontAcceptVoteKick = true,
	useSoulstoneRez = true,
	dialogBlacklist = {},
}

local DEFAULT_POPUP_BLACKLIST = {
	AREA_SPIRIT_HEAL = true,
	TOO_MANY_LUA_ERRORS = true,
	END_BOUND_TRADEABLE = true, EQUIP_BIND_TRADEABLE = true,
	ADDON_ACTION_FORBIDDEN = true,
	CONFIRM_LEAVE_RESTRICTED_CHALLENGE_MODE = true,
	WARN_LEAVE_RESTRICTED_CHALLENGE_MODE = true,
}

local K = {
	frames = {},
	orderedGossipFrames = {},
	itemChoice = nil,
	pendingClear = false,
	last = "(no key pressed yet)",
	stats = { dataProvider = 0, acquired = 0, released = 0, keys = 0, clicks = 0 },
}

local proxy
local clearTimer

local function UseKeyDown()
	if C_CVar and C_CVar.GetCVarBool then
		return C_CVar.GetCVarBool("ActionButtonUseKeyDown")
	end
	return GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false
end

local function StripLinks(s)
	if C_StringUtil and C_StringUtil.StripHyperlinks then return C_StringUtil.StripHyperlinks(s) end
	if StripHyperlinks then return StripHyperlinks(s) end
	return s
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local function GetClickFrameByName(name)
	if GetClickFrame then return GetClickFrame(name) end
	return _G[name]
end

local function RunNext(fn)
	if RunNextFrame then RunNextFrame(fn) else C_Timer.After(0, fn) end
end

local GLOW_COLOR = { 0.2, 0.85, 0.3 }
local GLOW_ALPHA = 0.5
local GLOW_FADE_TIME = 1 / 3
local PILL_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local glow = CreateFrame("Frame", nil, UIParent)
glow:SetFrameStrata("TOOLTIP")
glow:SetSize(50, 50)
glow:Hide()

local function GlowPiece()
	local t = glow:CreateTexture(nil, "ARTWORK")

	t:SetTexture("Interface\\Buttons\\WHITE8x8")
	t:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_ALPHA)
	return t
end

glow.mid = GlowPiece()

local canRound = glow.CreateMaskTexture ~= nil
if canRound then
	glow.left, glow.right = GlowPiece(), GlowPiece()
	glow.leftMask = glow:CreateMaskTexture()
	glow.rightMask = glow:CreateMaskTexture()
	for _, mask in ipairs({ glow.leftMask, glow.rightMask }) do
		mask:SetTexture(PILL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	glow.left:AddMaskTexture(glow.leftMask)
	glow.right:AddMaskTexture(glow.rightMask)
end

local function LayoutPill(width, height)
	glow.mid:ClearAllPoints()
	if not canRound or height <= 0 or width <= 0 then
		glow.mid:SetAllPoints(glow)
		glow.mid:Show()
		if canRound then glow.left:Hide(); glow.right:Hide() end
		return
	end

	local diameter = math.min(height, width)
	local r = math.floor(diameter / 2 + 0.5)
	if r < 1 then r = 1 end

	glow.left:ClearAllPoints()
	glow.left:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
	glow.left:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
	glow.left:SetWidth(r)
	glow.leftMask:ClearAllPoints()
	glow.leftMask:SetPoint("LEFT", glow.left, "LEFT", 0, 0)
	glow.leftMask:SetSize(diameter, diameter)
	glow.left:Show()

	glow.right:ClearAllPoints()
	glow.right:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
	glow.right:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
	glow.right:SetWidth(r)
	glow.rightMask:ClearAllPoints()
	glow.rightMask:SetPoint("RIGHT", glow.right, "RIGHT", 0, 0)
	glow.rightMask:SetSize(diameter, diameter)
	glow.right:Show()

	if width > 2 * r then
		glow.mid:SetPoint("TOPLEFT", glow.left, "TOPRIGHT", 0, 0)
		glow.mid:SetPoint("BOTTOMRIGHT", glow.right, "BOTTOMLEFT", 0, 0)
		glow.mid:Show()
	else
		glow.mid:Hide()
	end
end

glow:SetScript("OnUpdate", function(f, delta)
	local a = f:GetAlpha() - delta / GLOW_FADE_TIME
	if a <= 0 then f:Hide() else f:SetAlpha(a) end
end)

local function Glow(target)
	if not CFG.showGlow or not target then return end
	glow:ClearAllPoints()
	glow:SetAllPoints(target)

	local ratio = 1
	if target.GetEffectiveScale and glow:GetEffectiveScale() > 0 then
		ratio = target:GetEffectiveScale() / glow:GetEffectiveScale()
	end
	LayoutPill((target:GetWidth() or 0) * ratio, (target:GetHeight() or 0) * ratio)
	glow:SetAlpha(1)
	glow:Show()
end

local function ClearProxyBindings()
	if clearTimer then clearTimer:Cancel(); clearTimer = nil end
	if InCombatLockdown() then
		K.pendingClear = true
		return
	end
	K.pendingClear = false
	ClearOverrideBindings(proxy)
end

local function ClickWithKey(button, key)
	if InCombatLockdown() or not button then return end
	proxy:SetAttribute("clickbutton", button)

	SetOverrideBindingClick(proxy, true, key, proxy:GetName(), "LeftButton")

	if clearTimer then clearTimer:Cancel() end
	clearTimer = C_Timer.NewTimer(UseKeyDown() and 0 or 5, function()
		clearTimer = nil
		ClearProxyBindings()
	end)
	K.stats.clicks = K.stats.clicks + 1
end

local function GetPopupButton(popup)
	local fontString = popup.GetTextFontString and popup:GetTextFontString() or popup.text
	local text = fontString and fontString:GetText()
	local which = popup.which

	local button1 = popup.button1 or (popup.GetButton1 and popup:GetButton1())
	local button2 = popup.button2 or (popup.GetButton2 and popup:GetButton2())
	if not button1 then return nil end

	if not text or text == " " or text == "" or IsSecret(text) then return false end

	if CFG.dontAcceptInvite and which == "PARTY_INVITE" then return nil end
	if CFG.dontClickSummons and which == "CONFIRM_SUMMON" then return nil end
	if CFG.dontClickDuels and which == "DUEL_REQUESTED" then return nil end
	if CFG.dontAcceptInstanceLocks and which == "INSTANCE_LOCK" then return nil end
	if CFG.dontAcceptAbandonVote and (which == "VOTE_ABANDON_INSTANCE_VOTE" or which == "VOTE_ABANDON_INSTANCE_WAIT") then return nil end
	if CFG.dontAcceptVoteKick and which == "VOTE_BOOT_PLAYER" then return nil end

	local canRelease = button1:GetText() == DEATH_RELEASE
	if CFG.useSoulstoneRez and canRelease and button2 and button2:IsVisible() then
		return button2
	end

	if CFG.dontClickRevives and (text == RECOVER_CORPSE or which == "RESURRECT_NO_SICKNESS" or which == "RESURRECT_NO_TIMER") then return nil end
	if CFG.dontClickReleases and canRelease then return nil end

	if DEFAULT_POPUP_BLACKLIST[which] or CFG.dialogBlacklist[which] then return nil end
	local lowerText = text:lower()
	for fragment in pairs(CFG.dialogBlacklist) do
		fragment = fragment:gsub("%W", "%%%0"):gsub("%%%%s", ".+")
		if lowerText:find(fragment:lower()) then return nil end
	end

	return button1:IsVisible() and button1 or nil
end

local function GetValidPopupButtons()
	local popups = {}
	if StaticPopup_ForEachShownDialog then
		StaticPopup_ForEachShownDialog(function(p)
			if not p.special then popups[#popups + 1] = p end
		end)
	else
		for i = 1, 4 do
			local p = _G["StaticPopup" .. i]
			if p and p:IsVisible() then popups[#popups + 1] = p end
		end
	end
	table.sort(popups, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)

	local buttons = {}
	for _, p in ipairs(popups) do
		local b = GetPopupButton(p)
		if b then buttons[#buttons + 1] = b end
	end
	return buttons[1] and buttons or nil
end

local function BuildRowText(info, tag, n)
	local text = info[tag] or ""
	if info.flags and FlagsUtil and Enum.GossipOptionRecFlags
		and FlagsUtil.IsSet(info.flags, Enum.GossipOptionRecFlags.QuestLabelPrepend)
		and GOSSIP_QUEST_OPTION_PREPEND then
		text = GOSSIP_QUEST_OPTION_PREPEND:format(text)
	end
	if info.isIgnored and IGNORED_QUEST_DISPLAY then
		text = IGNORED_QUEST_DISPLAY:format(text)
	elseif info.isTrivial and TRIVIAL_QUEST_DISPLAY then
		text = TRIVIAL_QUEST_DISPLAY:format(text)
	end
	return (n % 10) .. ". " .. (text:match("^%d%. (.+)$") or text)
end

function K:OnGossipDataProviderChange()
	self.stats.dataProvider = self.stats.dataProvider + 1
	self.frames = {}
	self.orderedGossipFrames = {}

	local provider = GossipFrame.GreetingPanel.ScrollBox:GetDataProvider()
	if not provider then return end

	local n = 1
	for _, elementData in provider:Enumerate() do
		local info = elementData.info
		local tag
		if elementData.buttonType == GOSSIP_BUTTON_TYPE_OPTION then
			tag = "name"
		elseif elementData.buttonType == GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST then
			tag = "title"
		elseif elementData.buttonType == GOSSIP_BUTTON_TYPE_ACTIVE_QUEST
			and info and (info.isComplete or not CFG.ignoreInProgressQuests) then
			tag = "title"
		end

		if tag and info then
			self.orderedGossipFrames[elementData] = n
			if n <= 10 then
				info.KKey_Text = BuildRowText(info, tag, n)
			end
			n = n + 1
		end

		local calc = elementData.titleOptionButton
			or elementData.availableQuestButton
			or elementData.activeQuestButton
		if calc and not calc.KKey_Hooked then
			hooksecurefunc(calc, "Setup", function(_, rowInfo)
				if CFG.numKeysForGossip and rowInfo and rowInfo.KKey_Text then
					calc:SetTextAndResize(rowInfo.KKey_Text)
				end
			end)
			calc.KKey_Hooked = true
		end
	end
end

function K:OnGossipFrameAcquired(frame, elementData)
	self.stats.acquired = self.stats.acquired + 1
	local n = self.orderedGossipFrames[elementData]
	if not n or n > 10 then return end
	self.frames[n] = frame

	local newText = elementData.info and elementData.info.KKey_Text
	if not (CFG.numKeysForGossip and newText) then return end
	frame:SetTextAndResize(newText)

	if not frame.KKey_Text then
		local function reapply(f, text)
			local saved = f.KKey_Text
			if not saved or saved == "" then return end
			if type(text) ~= "string" or IsSecret(text) then return end
			if StripLinks(saved) == StripLinks(text) then return end
			f:SetTextAndResize(saved)
		end
		hooksecurefunc(frame, "SetText", reapply)
		hooksecurefunc(frame, "SetFormattedText", function(f, fmt, ...)
			if type(fmt) ~= "string" or IsSecret(fmt) then return end
			reapply(f, fmt:format(...))
		end)
	end
	frame.KKey_Text = newText
end

function K:OnGossipFrameReleased(frame)
	self.stats.released = self.stats.released + 1
	if frame.KKey_Text then frame.KKey_Text = "" end

	for n, f in pairs(self.frames) do
		if f == frame then self.frames[n] = nil end
	end
end

function K:EnumerateQuestGreeting()
	if not QuestFrameGreetingPanel or not QuestFrameGreetingPanel:IsVisible() then return end

	local questsToHandle, filter = {}, false
	if CFG.ignoreInProgressQuests then
		filter = true
		local numActive, numAvailable = GetNumActiveQuests(), GetNumAvailableQuests()
		for i = 1, numActive do
			local _, isComplete = GetActiveTitle(i)
			questsToHandle[i] = isComplete
		end
		for i = numActive + 1, numActive + numAvailable do
			questsToHandle[i] = true
		end
	end

	local rows = {}
	if QuestFrameGreetingPanel.titleButtonPool then
		for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
			if button:GetObjectType() == "Button" then rows[#rows + 1] = button end
		end
	elseif QuestGreetingScrollChildFrame then
		for _, child in ipairs({ QuestGreetingScrollChildFrame:GetChildren() }) do
			if child:GetObjectType() == "Button" and child:IsVisible() then rows[#rows + 1] = child end
		end
	else
		return
	end

	table.sort(rows, function(a, b)
		if a.GetOrderIndex then return a:GetOrderIndex() < b:GetOrderIndex() end
		return a:GetTop() > b:GetTop()
	end)

	self.frames = {}
	local n = 1
	for i, row in ipairs(rows) do
		if not filter or questsToHandle[i] then
			if CFG.numKeysForGossip and n <= 10 then
				local old = row:GetText()

				if not (issecretvalue and issecretvalue(old)) then
					old = type(old) == "string" and old or ""
					row:SetText((n % 10) .. ". " .. (old:match("^%d%. (.+)$") or old))
				end

				row:SetHeight(row:GetFontString():GetHeight() + 2)
			end
			self.frames[#self.frames + 1] = row
			n = n + 1
		end
	end
end

local function IsActionKey(key)
	return key == CFG.actionKeys[1] or key == CFG.actionKeys[2]
end

local function ShouldIgnoreInput()
	if InCombatLockdown() then return "in combat" end
	if CFG.ignoreWithModifier and (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
		return "modifier held"
	end

	local focus = GetCurrentKeyBoardFocus()
	if focus then

		if focus.IsForbidden and focus:IsForbidden() then
			return "typing in a protected box"
		end
		local focusName = focus:GetName()
		local mailBox = focusName == "SendMailNameEditBox" or focusName == "SendMailSubjectEditBox"
		if not (mailBox and GetValidPopupButtons()) then return "typing in an edit box" end
	end

	local gossipUp = GossipFrame and GossipFrame:IsVisible()
	local questUp = QuestFrame and QuestFrame:IsVisible()
	if not gossipUp and not questUp and not GetValidPopupButtons() then
		return "nothing to click"
	end
	return nil
end

function K:HandleKey(key)
	if not InCombatLockdown() then proxy:SetPropagateKeyboardInput(true) end

	local doAction = IsActionKey(key)
	local keynum = tonumber(key)
	if doAction then
		keynum = 1
	elseif key == "0" or (key == "NUMPAD0" and CFG.treatNumpadAsNumbers) then
		keynum = 10
	elseif CFG.treatNumpadAsNumbers and key:match("^NUMPAD") then
		keynum = tonumber((key:gsub("NUMPAD", "")))
	end
	if not doAction and not keynum then return end

	self.stats.keys = self.stats.keys + 1
	local ignore = ShouldIgnoreInput()
	if ignore then
		self.last = key .. " -> ignored: " .. ignore
		return
	end

	if doAction then

		local popupButtons = GetValidPopupButtons()
		if popupButtons then
			self.last = key .. " -> popup button"
			ClickWithKey(popupButtons[1], key)
			return
		end

		if QuestFrame and QuestFrame:IsVisible() then
			if QuestFrameProgressPanel:IsVisible() then

				if CFG.ignoreDisabledButtons and not QuestFrameCompleteButton:IsEnabled() then
					self.last = key .. " -> quest progress: Goodbye"
					ClickWithKey(QuestFrameGoodbyeButton, key)
				else
					self.last = key .. " -> quest progress: Continue"
					ClickWithKey(QuestFrameCompleteButton, key)
				end
				return
			elseif QuestFrameDetailPanel:IsVisible() then
				self.last = key .. " -> quest accept"
				ClickWithKey(QuestFrameAcceptButton, key)
				return
			elseif QuestFrameRewardPanel:IsVisible() then

				proxy:SetPropagateKeyboardInput(false)
				C_Timer.After(0.1, function()
					if not InCombatLockdown() then proxy:SetPropagateKeyboardInput(true) end
				end)
				local choice = self.itemChoice
				if not choice or choice < 1 then
					if GetNumQuestChoices() > 1 then
						self.last = key .. " -> quest reward: choose an item first"
						QuestChooseRewardError()
						return
					end
					choice = 1
				end
				self.last = key .. " -> quest reward: complete (item " .. choice .. ")"
				Glow(QuestFrameCompleteQuestButton)
				GetQuestReward(choice)
				return
			end
		end
	end

	if GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel:IsVisible()
		and ((doAction and CFG.spaceSelectsFirstGossip) or (not doAction and CFG.numKeysForGossip)) then
		while keynum and keynum > 0 and keynum <= 10 do
			local row = self.frames[keynum]
			if not row then break end
			local data = row.GetElementData and row:GetElementData()

			if doAction and CFG.ignoreDisabledButtons and data and data.info
				and data.info.questID and data.activeQuestButton and not data.info.isComplete then
				keynum = keynum + 1
			else
				self.last = key .. " -> gossip row " .. keynum
				ClickWithKey(row, key)
				return
			end
		end
	end

	if (doAction and CFG.spaceSelectsFirstGossip or (not doAction and CFG.numKeysForGossip))
		and QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
		while keynum and keynum > 0 and keynum <= #self.frames do
			local _, isComplete = GetActiveTitle(keynum)
			if doAction and CFG.ignoreDisabledButtons and not isComplete and self.frames[keynum].isActive == 1 then
				keynum = keynum + 1
			else
				self.last = key .. " -> quest greeting row " .. keynum
				ClickWithKey(self.frames[keynum], key)
				return
			end
		end
	end

	if not doAction and CFG.numKeysForQuestRewards and keynum
		and QuestFrameRewardPanel and QuestFrameRewardPanel:IsVisible()
		and keynum <= GetNumQuestChoices() then
		local item = GetClickFrameByName("QuestInfoRewardsFrameQuestInfoItem" .. keynum)
		if item then
			self.itemChoice = keynum
			self.last = key .. " -> quest reward item " .. keynum
			ClickWithKey(item, key)
			return
		end
	end

	self.last = key .. " -> no matching target"
end

function K:SelectItemReward()
	for i = 1, GetNumQuestChoices() do
		local item = GetClickFrameByName("QuestInfoRewardsFrameQuestInfoItem" .. i)
		if item and item:IsMouseOver() then
			self.itemChoice = i
			break
		end
	end
end

proxy = CreateFrame("Button", "KKeyClickProxy", UIParent, "InsecureActionButtonTemplate")
proxy:RegisterForClicks("AnyUp", "AnyDown")
proxy:SetAttribute("type", "click")
proxy:SetAttribute("typerelease", "click")
proxy:SetScript("PreClick", function(_, _, down)
	if InCombatLockdown() then return end
	if down ~= UseKeyDown() then return end
	Glow(proxy:GetAttribute("clickbutton"))
end)
proxy:HookScript("OnClick", function(_, _, down)
	if InCombatLockdown() then return end
	if down ~= UseKeyDown() then return end
	ClearProxyBindings()
	proxy:SetAttribute("clickbutton", nil)
	proxy:SetPropagateKeyboardInput(true)
end)
proxy:SetScript("OnKeyDown", function(_, key) K:HandleKey(key) end)
proxy:SetFrameStrata("TOOLTIP")
proxy:EnableKeyboard(true)
proxy:SetPropagateKeyboardInput(true)

local function SetupGossipCallbacks()
	if K.gossipSetupDone then return end
	local scrollBox = GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
	if not (scrollBox and scrollBox.RegisterCallback) then
		print("|cffff8000K-Key:|r gossip ScrollBox or RegisterCallback missing; run /kkey debug")
		return
	end
	K.gossipSetupDone = true
	scrollBox:RegisterCallback("OnAcquiredFrame", K.OnGossipFrameAcquired, K)
	scrollBox:RegisterCallback("OnReleasedFrame", K.OnGossipFrameReleased, K)
	local event = ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnDataProviderReassigned
	if event then
		scrollBox:RegisterCallback(event, K.OnGossipDataProviderChange, K)
	else
		print("|cffff8000K-Key:|r ScrollBoxListMixin.Event.OnDataProviderReassigned missing; run /kkey debug")
	end
end

local function InstallQuestRewardHook()
	if K.rewardHookDone then return end
	if QuestInfoItem_OnClick then
		K.rewardHookDone = true
		hooksecurefunc("QuestInfoItem_OnClick", function() K:SelectItemReward() end)
	end
end

local events = CreateFrame("Frame", "KKeyEvents")
events:RegisterEvent("QUEST_GREETING")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "QUEST_GREETING" or event == "QUEST_LOG_UPDATE" then
		RunNext(function() K:EnumerateQuestGreeting() end)
	elseif event == "QUEST_COMPLETE" then
		K.itemChoice = (GetNumQuestChoices() > 1) and -1 or 1
	elseif event == "PLAYER_REGEN_DISABLED" then
		if not InCombatLockdown() then
			proxy:SetPropagateKeyboardInput(true)
			ClearProxyBindings()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		proxy:SetPropagateKeyboardInput(true)
		if K.pendingClear then ClearProxyBindings() end
	end
end)

local function DebugCommand(msg)
	local function p(...) print("|cffd2b48cK-Key:|r", ...) end
	if msg ~= "debug" then
		p("commands: /kkey debug")
		return
	end
	local sb = GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
	p("ScrollBox:", tostring(sb ~= nil), " RegisterCallback:", tostring(sb and sb.RegisterCallback ~= nil),
		" GetDataProvider:", tostring(sb and sb.GetDataProvider ~= nil))
	p("OnDataProviderReassigned event:", tostring(ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnDataProviderReassigned))
	p("GOSSIP_BUTTON_TYPE_OPTION/AVAILABLE/ACTIVE:", tostring(GOSSIP_BUTTON_TYPE_OPTION),
		tostring(GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST), tostring(GOSSIP_BUTTON_TYPE_ACTIVE_QUEST))
	p("StaticPopup_ForEachShownDialog:", tostring(StaticPopup_ForEachShownDialog ~= nil),
		" StaticPopup1Button1 global:", tostring(_G.StaticPopup1Button1 ~= nil))
	p("setup done -> gossip:", tostring(K.gossipSetupDone == true), " reward hook:", tostring(K.rewardHookDone == true))
	p("callbacks fired -> dataProvider:", K.stats.dataProvider, " acquired:", K.stats.acquired,
		" released:", K.stats.released)
	local tracked = 0
	for _ in pairs(K.frames) do tracked = tracked + 1 end
	p("tracked rows:", tracked, " keys seen:", K.stats.keys, " clicks armed:", K.stats.clicks)
	p("last decision:", K.last)
end

_G.KKey = K
SetupGossipCallbacks()
InstallQuestRewardHook()
SLASH_KKEY1 = "/kkey"
SlashCmdList["KKEY"] = DebugCommand
