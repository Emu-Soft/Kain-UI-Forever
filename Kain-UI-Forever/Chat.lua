local _, KUI = ...

local function tInsertIfMissing(t, value)
	for _, v in ipairs(t) do
		if v == value then return end
	end
	table.insert(t, value)
end

local WrapChatFrameAddMessage, GetAllChatFrames, WrapAllChatFrames

function KUI:ApplyChatEnhancements()
	KUI:ApplyChatClamp()
	KUI:ApplyChatTimestamps()
	KUI:ApplyChatChannelNumberFilter()
	KUI:ApplyChatLinkify()
	KUI:EnsureChatCopyButton()
	KUI:EnsureChatHistoryRecall()
	KUI:ApplyChatScrollBars()
end

function KUI:SetChatEnhanced(enabled)
	if not KUI.db then return end
	KUI.db.chatEnhanced = enabled and true or false
	KUI:ApplyChatEnhancements()
end

function KUI:ApplyChatClamp()
	local unclamped = KUI.db and KUI.db.chatEnhanced
	if ChatFrame1 and ChatFrame1.SetClampedToScreen then
		ChatFrame1:SetClampedToScreen(not unclamped)
	end
end

function KUI:ApplyChatTimestamps()
	local enabled = KUI.db and KUI.db.chatEnhanced
	local value = enabled and "%H:%M:%S " or "none"
	if SetCVar then
		pcall(SetCVar, "showTimestamps", value)
	elseif C_CVar and C_CVar.SetCVar then
		pcall(C_CVar.SetCVar, "showTimestamps", value)
	end
end

local scanLines = { "hasn't run yet this session." }
local function Note(fmt, ...) table.insert(scanLines, string.format(fmt, ...)) end

function KUI:ChatShorthandScanReport()
	print("|cff33ff99Kain-UI Forever|r chat channel shorthand scan:")
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
end

local CHANNEL_PREFIX_SHORTHANDS = {
	CHAT_GUILD_GET = "G",
	CHAT_OFFICER_GET = "O",
	CHAT_PARTY_GET = "P",
	CHAT_PARTY_LEADER_GET = "P",
	CHAT_PARTY_GUIDE_GET = "P",
	CHAT_RAID_GET = "R",
	CHAT_RAID_LEADER_GET = "R",
	CHAT_RAID_WARNING_GET = "RW",
	CHAT_INSTANCE_CHAT_GET = "I",
	CHAT_INSTANCE_CHAT_LEADER_GET = "I",
}

function KUI:IsChatLockedDown()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and locked ~= nil then return locked and true or false end
	end
	if IsEncounterInProgress and IsEncounterInProgress() then return true end
	if InCombatLockdown() and IsInInstance and IsInInstance() then return true end
	return false
end

KUI.CHAT_ADDMESSAGE_WRAPS = false

local addMessageOrigin = setmetatable({}, { __mode = "k" })
local wrapResetters = {}
local wrapReinstallers = {}

function KUI:RememberChatAddMessage(frame)
	if addMessageOrigin[frame] then return end
	addMessageOrigin[frame] = { own = rawget(frame, "AddMessage") ~= nil, fn = rawget(frame, "AddMessage") }
end

function KUI:RegisterChatWrap(reset, reinstall)
	table.insert(wrapResetters, reset)
	table.insert(wrapReinstallers, reinstall)
end

local wrapsSuspended = false

function KUI:SuspendChatWraps()
	if wrapsSuspended then return end
	wrapsSuspended = true
	for frame, origin in pairs(addMessageOrigin) do
		if origin.own then
			frame.AddMessage = origin.fn
		else
			rawset(frame, "AddMessage", nil)
		end
	end
	for _, reset in ipairs(wrapResetters) do pcall(reset) end
end

function KUI:ResumeChatWraps()
	if not wrapsSuspended then return end
	wrapsSuspended = false
	for _, reinstall in ipairs(wrapReinstallers) do pcall(reinstall) end
end

local lastLocked
local function CheckChatLockdown()
	local locked = KUI:IsChatLockedDown()
	if locked == lastLocked then return end
	lastLocked = locked
	if locked then KUI:SuspendChatWraps() else KUI:ResumeChatWraps() end
end
local lockdownWatcher = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START",
	"ENCOUNTER_END", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"ADDON_RESTRICTION_STATE_CHANGED", "CVAR_UPDATE" }) do

	pcall(lockdownWatcher.RegisterEvent, lockdownWatcher, e)
end
lockdownWatcher:SetScript("OnEvent", function()

	CheckChatLockdown()
	if C_Timer and C_Timer.After then C_Timer.After(0, CheckChatLockdown) end
end)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, CheckChatLockdown) end

local shorthandSwaps = {}

function KUI:ApplyChatChannelShorthands()
	scanLines = {}
	shorthandSwaps = {}
	local foundCount, missingNames = 0, {}
	for globalName, shorthand in pairs(CHANNEL_PREFIX_SHORTHANDS) do
		local original = _G[globalName]
		local prefix = type(original) == "string" and original:match("^(.-)%%s")
		if prefix and prefix ~= "" then
			local short, n = prefix:gsub("%[[^%]]+%]", "[" .. shorthand .. "]", 1)
			if n > 0 and short ~= prefix then
				table.insert(shorthandSwaps, { from = prefix, to = short })
			end
			foundCount = foundCount + 1
		else
			table.insert(missingNames, globalName)
		end
	end

	table.sort(shorthandSwaps, function(a, b) return #a.from > #b.from end)
	Note("named channels (Guild/Party/Raid/etc): %d of %d global string(s) found and overridden.", foundCount, foundCount + #missingNames)
	if #missingNames > 0 then
		Note("not found on this client: %s", table.concat(missingNames, ", "))
	end
end

local copyPopup

local function GetChatHistoryText(frame)
	if not (frame and frame.GetNumMessages and frame.GetMessageInfo) then
		return nil, "GetNumMessages/GetMessageInfo not found on this chat frame."
	end
	local ok, count = pcall(frame.GetNumMessages, frame)
	if not ok or not count then
		return nil, "GetNumMessages failed."
	end
	local lines = {}
	for i = 1, count do
		local okMsg, text = pcall(frame.GetMessageInfo, frame, i)

		if okMsg and issecretvalue and issecretvalue(text) then
			table.insert(lines, "[this line can't be copied]")
		elseif okMsg and type(text) == "string" then

			text = text:gsub("[%z\1-\8\11-\31\127]", "?")

			text = text:gsub("|K.-|k", "[hidden text]")

			local probe = text:gsub("||", "")
			local _, opened = probe:gsub("|c%x%x%x%x%x%x%x%x", "")
			local _, openedNamed = probe:gsub("|cn[^:|]*:", "")
			local _, closed = probe:gsub("|r", "")
			local missing = opened + openedNamed - closed
			if missing > 0 then text = text .. string.rep("|r", missing) end
			table.insert(lines, text)
		end
	end
	if #lines == 0 then
		return nil, "no messages found in the chat buffer."
	end
	return table.concat(lines, "\n")
end

local function GetChatFrameLabel(frame)
	local tabName = frame:GetName() and (frame:GetName() .. "Tab")
	local tab = tabName and _G[tabName]
	if tab and tab.GetText then
		local ok, text = pcall(tab.GetText, tab)

		if ok and text and not (issecretvalue and issecretvalue(text)) and text ~= "" then return text end
	end
	return (frame.GetName and frame:GetName()) or "Chat"
end

local function EnsureCopyPopup()
	if copyPopup then return copyPopup end
	local popup = CreateFrame("Frame", "KainUIForeverChatCopyPopup", UIParent, "BackdropTemplate")
	popup:SetSize(500, 400)
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("DIALOG")
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	if popup.SetBackdrop then
		popup:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		popup:SetBackdropColor(0, 0, 0, 0.9)
		popup:SetBackdropBorderColor(1, 1, 1, 0.5)
	end
	if KUI.ApplyDiamondBorder then KUI:ApplyDiamondBorder(popup) end

	local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -18)
	title:SetText("Copy Chat Text")
	popup.title = title

	local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -2, -2)
	closeButton:SetScript("OnClick", function() popup:Hide() end)

	local editBoxBackdrop = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	editBoxBackdrop:SetPoint("TOPLEFT", 10, -42)
	editBoxBackdrop:SetPoint("BOTTOMRIGHT", -10, 10)
	if editBoxBackdrop.SetBackdrop then
		editBoxBackdrop:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})

		editBoxBackdrop:SetBackdropColor(0.18, 0.18, 0.18, 1)
		editBoxBackdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	local editScrollFrame = CreateFrame("ScrollFrame", nil, editBoxBackdrop, "UIPanelScrollFrameTemplate")
	editScrollFrame:SetPoint("TOPLEFT",     editBoxBackdrop, "TOPLEFT",  8, -6)
	editScrollFrame:SetPoint("BOTTOMRIGHT", editBoxBackdrop, "BOTTOMRIGHT", -24, 6)

	local scrollBarBacking = editBoxBackdrop:CreateTexture(nil, "ARTWORK")
	scrollBarBacking:SetPoint("TOPRIGHT", editBoxBackdrop, "TOPRIGHT", -2, -2)
	scrollBarBacking:SetPoint("BOTTOMRIGHT", editBoxBackdrop, "BOTTOMRIGHT", -2, 2)
	scrollBarBacking:SetWidth(20)
	scrollBarBacking:SetColorTexture(0, 0, 0, 1)

	local editBox = CreateFrame("EditBox", nil, editScrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetFontObject("ChatFontNormal")
	editBox:SetWidth(editScrollFrame:GetWidth() or 430)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	editScrollFrame:SetScrollChild(editBox)
	popup.editBox = editBox
	popup.editScrollFrame = editScrollFrame

	copyPopup = popup

	tInsertIfMissing(UISpecialFrames, "KainUIForeverChatCopyPopup")

	return popup
end

function KUI:ShowCopyText(titleText, text)
	local popup = EnsureCopyPopup()
	popup.title:SetText(titleText or "Copy Text")
	popup.editBox:SetText(text or "")
	popup:Show()
	popup.editBox:SetFocus()
	popup.editBox:HighlightText()
	local scrollFrame = popup.editScrollFrame
	if scrollFrame and C_Timer and C_Timer.After then
		C_Timer.After(0, function() scrollFrame:SetVerticalScroll(0) end)
	end
end

function KUI:ShowChatCopyPopup(frame)
	frame = frame or ChatFrame1
	local text, err = GetChatHistoryText(frame)
	local popup = EnsureCopyPopup()
	if not text then
		text = "(" .. tostring(err) .. ")"
	end
	popup.title:SetText("Copy Chat Text -- " .. GetChatFrameLabel(frame))
	popup.editBox:SetText(text)
	popup:Show()
	popup.editBox:SetFocus()
	popup.editBox:HighlightText()

	local scrollFrame = popup.editScrollFrame
	if scrollFrame then
		C_Timer.After(0, function()
			scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
		end)
	end
end

local scanBuffer = {}
local MAX_SCAN_LINES = 6

local function RecordScan(before, after)
	table.insert(scanBuffer, 1, { before = before, after = after })
	while #scanBuffer > MAX_SCAN_LINES do
		table.remove(scanBuffer)
	end
end

local changedNoticePrefix
local function GetChangedNoticePrefix()
	if changedNoticePrefix == nil then
		local fmt = type(CHAT_YOU_CHANGED_NOTICE) == "string" and CHAT_YOU_CHANGED_NOTICE or ""
		local prefix = fmt:match("^(.-)|H") or fmt:match("^(.-)%%") or ""
		if prefix == "" then prefix = "Changed Channel:" end
		changedNoticePrefix = prefix:gsub("%s+$", "")
	end
	return changedNoticePrefix
end

local function ShortenNumberedChannelText(text)
	if type(text) ~= "string" then return text, false end
	if text:find(GetChangedNoticePrefix(), 1, true) then

		local shortened, count = text:gsub("%[(%d+)%.%s([^%]]-)%]", "[%1] %2", 1)
		return shortened, count > 0
	end
	local shortened, count = text:gsub("%[(%d+)%.%s[^%]]-%]", "[%1]")
	return shortened, count > 0
end

local wrappedFrames = setmetatable({}, { __mode = "k" })

local URL_TLDS = {
	com = true, net = true, org = true, io = true, ai = true, gg = true,
	tv = true, co = true, me = true, dev = true, app = true, info = true,
	biz = true, us = true, uk = true, ca = true, au = true, de = true,
	nz = true, eu = true, xyz = true, edu = true, gov = true, wiki = true,
	tw = true, jp = true, kr = true, ru = true, fr = true, es = true,
	it = true, nl = true, se = true, pl = true, br = true, shop = true,
	online = true, store = true,
}

local URL_TAIL_CHARS = "[%w%-._~:/?#%[%]@!$&'()*+,;=%%]"

local function IsWordChar(c)
	return c ~= "" and c:match("%w") ~= nil
end

local function TryMatchBareDomain(text, pos)
	local runEnd = pos - 1
	while runEnd < #text and text:sub(runEnd + 1, runEnd + 1):match("[%w%-%.]") do
		runEnd = runEnd + 1
	end
	if runEnd < pos then return nil end

	local run = text:sub(pos, runEnd):gsub("%.+$", "")
	if run == "" then return nil end

	local labels = {}
	for label in run:gmatch("[^%.]+") do labels[#labels + 1] = label end
	if #labels < 2 then return nil end

	local tld = labels[#labels]
	if not (tld:match("^%a%a+$") and URL_TLDS[tld:lower()]) then return nil end

	local matchEnd = pos + #run - 1
	local before = pos > 1 and text:sub(pos - 1, pos - 1) or ""
	local after = text:sub(matchEnd + 1, matchEnd + 1)
	if IsWordChar(before) or IsWordChar(after) then return nil end

	return matchEnd, run
end

local function TryMatchURL(text, pos)
	local s, e, m = text:find("^(https?://" .. URL_TAIL_CHARS .. "+)", pos)
	if s then return e, m end

	s, e, m = text:find("^(www%.[%w%-]+%.%a%a" .. URL_TAIL_CHARS .. "*)", pos)
	if s then return e, m end

	return TryMatchBareDomain(text, pos)
end

local function ShortenURLLabel(url)
	local label = url:gsub("^https?://", ""):gsub("^www%.", "")
	if #label > 45 then
		label = KUI.CutText(label, 42) .. "..."
	end
	return label
end

local function LinkifyURLs(text)
	if type(text) ~= "string" then return text, false end
	local len = #text
	if len == 0 then return text, false end

	local out, changed = {}, false
	local i = 1
	while i <= len do
		local two = text:sub(i, i + 1)
		if two == "|H" then
			local firstH = text:find("|h", i + 2, true)
			local secondH = firstH and text:find("|h", firstH + 2, true)
			if secondH then
				out[#out + 1] = text:sub(i, secondH + 1)
				i = secondH + 2
			else
				out[#out + 1] = text:sub(i)
				i = len + 1
			end
		elseif two == "|T" then
			local closeT = text:find("|t", i + 2, true)
			if closeT then
				out[#out + 1] = text:sub(i, closeT + 1)
				i = closeT + 2
			else
				out[#out + 1] = text:sub(i)
				i = len + 1
			end
		else
			local matchEnd, url = TryMatchURL(text, i)
			if matchEnd then
				out[#out + 1] = "|cffffffff|Hkainuiurl:" .. url .. "|h[" .. ShortenURLLabel(url) .. "]|h|r"
				changed = true
				i = matchEnd + 1
			else
				out[#out + 1] = text:sub(i, i)
				i = i + 1
			end
		end
	end
	return table.concat(out), changed
end

local linkScanBuffer = {}
local MAX_LINK_SCAN_LINES = 6
local function RecordLinkScan(before, after)
	table.insert(linkScanBuffer, 1, { before = before, after = after })
	while #linkScanBuffer > MAX_LINK_SCAN_LINES do
		table.remove(linkScanBuffer)
	end
end

function KUI:ChatLinkifyScanReport()
	print("|cff33ff99Kain-UI Forever|r chat weblink scan:")
	print("  setting: " .. ((not KUI.db or KUI.db.chatEnhanced ~= false) and "ON" or "off") .. " (via Enhance Chat)")
	if #linkScanBuffer == 0 then
		print("  no links linkified yet this session -- paste a URL in chat (or wait for one), then run this again.")
	else
		for i, entry in ipairs(linkScanBuffer) do
			print(string.format("  [%d] %q -> %q", i, entry.before, entry.after))
		end
	end
end

local linkPopup

local function EnsureLinkPopup()
	if linkPopup then return linkPopup end
	local popup = CreateFrame("Frame", "KainUIForeverLinkPopup", UIParent, "BackdropTemplate")
	popup:SetSize(420, 90)
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("DIALOG")
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	if popup.SetBackdrop then
		popup:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		popup:SetBackdropColor(0, 0, 0, 0.9)
		popup:SetBackdropBorderColor(1, 1, 1, 0.5)
	end
	if KUI.ApplyDiamondBorder then KUI:ApplyDiamondBorder(popup) end

	local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -10)
	title:SetText("Copy Link")

	local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -2, -2)
	closeButton:SetScript("OnClick", function() popup:Hide() end)

	local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOP", 0, -30)
	hint:SetText("Already selected -- Ctrl+C to copy.")

	local editBoxBackdrop = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	editBoxBackdrop:SetSize(388, 28)
	editBoxBackdrop:SetPoint("TOP", 0, -46)
	if editBoxBackdrop.SetBackdrop then
		editBoxBackdrop:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})

		editBoxBackdrop:SetBackdropColor(0.18, 0.18, 0.18, 1)
		editBoxBackdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	local editBox = CreateFrame("EditBox", nil, editBoxBackdrop)
	editBox:SetSize(374, 20)
	editBox:SetPoint("CENTER", 0, 0)
	editBox:SetFontObject("ChatFontNormal")
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	popup.editBox = editBox

	linkPopup = popup
	tInsertIfMissing(UISpecialFrames, "KainUIForeverLinkPopup")
	return popup
end

function KUI:ShowLinkPopup(url)
	local popup = EnsureLinkPopup()
	popup.editBox:SetText(url or "")
	popup:Show()
	popup.editBox:SetFocus()
	popup.editBox:HighlightText()
end

hooksecurefunc("SetItemRef", function(link)
	if type(link) == "string" then
		local url = link:match("^kainuiurl:(.+)$")
		if url then
			KUI:ShowLinkPopup(url)
		end
	end
end)

local tooltipFrames = setmetatable({}, { __mode = "k" })
local function InstallLinkTooltip(frame)
	if not frame or tooltipFrames[frame] then return end
	tooltipFrames[frame] = true
	frame:HookScript("OnHyperlinkEnter", function(self, link)
		if type(link) == "string" and link:match("^kainuiurl:") then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Click to copy this link")
			GameTooltip:Show()
		end
	end)
	frame:HookScript("OnHyperlinkLeave", function()
		GameTooltip:Hide()
	end)
end

function KUI:EnsureChatLinkTooltips()
	for _, frame in ipairs(GetAllChatFrames()) do
		InstallLinkTooltip(frame)
	end
end

function KUI:ApplyChatLinkify()
	WrapAllChatFrames()
	KUI:EnsureChatLinkTooltips()
end

local function EnhanceChatText(text)
	if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then

		local enhanced = not KUI.db or KUI.db.chatEnhanced ~= false
		if enhanced then

			for _, swap in ipairs(shorthandSwaps) do
				local s, e = text:find(swap.from, 1, true)
				if s then
					text = text:sub(1, s - 1) .. swap.to .. text:sub(e + 1)
					break
				end
			end

			local ok, result, matched = pcall(ShortenNumberedChannelText, text)
			if ok and result then
				if matched then RecordScan(text, result) end
				text = result
			end

			local okLink, resultLink, changed = pcall(LinkifyURLs, text)
			if okLink and resultLink then
				if changed then RecordLinkScan(text, resultLink) end
				text = resultLink
			end

			local nativeTimestamp = text:match("^(%d%d:%d%d:%d%d )")
			local timestamp = nativeTimestamp or date("%H:%M:%S ")
			local rest = nativeTimestamp and text:sub(#nativeTimestamp + 1) or text
			text = "|cff9d9d9d" .. timestamp .. "|r" .. rest
		end
	end
	return text
end

local lineTransforms = {}
function KUI:RegisterChatLineTransform(fn, first)
	if type(fn) ~= "function" then return end
	if first then table.insert(lineTransforms, 1, fn) else table.insert(lineTransforms, fn) end
end
KUI:RegisterChatLineTransform(EnhanceChatText)

local postStats = { changed = 0, secret = 0, paused = 0, missed = 0 }

local function ChatLinesPaused()
	if IsInInstance then
		local ok, inInstance = pcall(IsInInstance)
		if ok and not (issecretvalue and issecretvalue(inInstance)) and inInstance == true then return true end
	end
	return KUI:IsChatLockedDown()
end

local function PostProcessChatLine(frame, text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		postStats.secret = postStats.secret + 1
		return
	end
	if ChatLinesPaused() then
		postStats.paused = postStats.paused + 1
		return
	end
	local buffer = frame.historyBuffer
	if type(buffer) ~= "table" or type(buffer.GetEntryAtIndex) ~= "function" then return end
	local ok, entry = pcall(buffer.GetEntryAtIndex, buffer, 1)
	if not ok or type(entry) ~= "table" then return end
	local current = entry.message
	if issecretvalue and issecretvalue(current) then return end
	if current ~= text then
		postStats.missed = postStats.missed + 1
		return
	end
	local newText = text
	for _, transform in ipairs(lineTransforms) do
		local okT, result = pcall(transform, newText)
		if okT and type(result) == "string" then newText = result end
	end
	if newText ~= text then
		entry.message = newText
		postStats.changed = postStats.changed + 1
	end
end

local lineHookedFrames = setmetatable({}, { __mode = "k" })
local function HookChatFrameLines(frame)
	if not frame or lineHookedFrames[frame] or type(frame.AddMessage) ~= "function" then return end
	lineHookedFrames[frame] = true
	hooksecurefunc(frame, "AddMessage", PostProcessChatLine)
end

function KUI:ChatPostProcessStats()
	local n = 0
	for _ in pairs(lineHookedFrames) do n = n + 1 end
	return n, postStats, ChatLinesPaused()
end

function WrapChatFrameAddMessage(frame)

	if not KUI.CHAT_ADDMESSAGE_WRAPS then
		HookChatFrameLines(frame)
		return
	end
	if not frame or wrappedFrames[frame] or type(frame.AddMessage) ~= "function" then return end

	if KUI.IsChatLockedDown and KUI:IsChatLockedDown() then return end
	KUI:RememberChatAddMessage(frame)
	wrappedFrames[frame] = true
	local original = frame.AddMessage
	frame.AddMessage = function(self, text, ...)

		text = EnhanceChatText(text)

		return original(self, text, ...)
	end
end

local usedChatFramesGlobal = false

function GetAllChatFrames()
	local frames = {}
	if type(_G.CHAT_FRAMES) == "table" then
		for _, name in ipairs(_G.CHAT_FRAMES) do
			local frame = _G[name]
			if frame then table.insert(frames, frame) end
		end
	end
	if #frames > 0 then
		usedChatFramesGlobal = true
		return frames
	end
	usedChatFramesGlobal = false

	local upper = math.max(_G.NUM_CHAT_WINDOWS or 10, 10) + 20
	for i = 1, upper do
		local frame = _G["ChatFrame" .. i]
		if frame then table.insert(frames, frame) end
	end
	return frames
end

function WrapAllChatFrames()
	for _, frame in ipairs(GetAllChatFrames()) do
		WrapChatFrameAddMessage(frame)
	end
end

KUI:RegisterChatWrap(function() wipe(wrappedFrames) end, function() WrapAllChatFrames() end)

function KUI:ApplyChatChannelNumberFilter()
	WrapAllChatFrames()
end

local scrollBarHider = CreateFrame("Frame")
scrollBarHider:Hide()
local scrollBarParents = setmetatable({}, { __mode = "k" })

local function ChatScrollElements(frame)
	return { frame.ScrollBar, frame.ScrollToBottomButton }
end

function KUI:ApplyChatScrollBars()
	local hide = KUI.db and KUI.db.chatEnhanced
	local names = type(_G.CHAT_FRAMES) == "table" and _G.CHAT_FRAMES or {}
	for _, name in ipairs(names) do
		local frame = _G[name]
		if frame then
			for _, element in ipairs(ChatScrollElements(frame)) do
				if element and element.SetParent then
					if hide then
						if not scrollBarParents[element] then
							scrollBarParents[element] = element:GetParent()
							element:SetParent(scrollBarHider)
						end
					elseif scrollBarParents[element] then
						element:SetParent(scrollBarParents[element])
						scrollBarParents[element] = nil
					end
				end
			end
		end
	end
end

local function RefreshChatFrameFeatures()
	WrapAllChatFrames()
	KUI:ApplyChatScrollBars()
	KUI:EnsureChatCopyButton()

	KUI:EnsureChatHistoryRecall()
end

local chatWindowFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(chatWindowFrame, "UPDATE_CHAT_WINDOWS")
chatWindowFrame:SetScript("OnEvent", RefreshChatFrameFeatures)

if type(FCF_OpenTemporaryWindow) == "function" then
	hooksecurefunc("FCF_OpenTemporaryWindow", function() RefreshChatFrameFeatures() end)
end

local whisperFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(whisperFrame, "CHAT_MSG_WHISPER")
KUI:SafeRegisterEvent(whisperFrame, "CHAT_MSG_WHISPER_INFORM")
whisperFrame:SetScript("OnEvent", function()
	RefreshChatFrameFeatures()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, RefreshChatFrameFeatures)
	end
end)

function KUI:ChatChannelNumberScanReport()
	print("|cff33ff99Kain-UI Forever|r numbered channel shortening scan:")
	print("  setting: " .. ((not KUI.db or KUI.db.chatEnhanced ~= false) and "ON" or "off") .. " (via Enhance Chat)")
	if KUI.CHAT_ADDMESSAGE_WRAPS then
		print("  mechanism: AddMessage text wrap (old; taints chat in combat)")
	else
		local hooked, st, paused = KUI:ChatPostProcessStats()
		print(string.format("  mechanism: post-processing hook on %d chat window(s); %s", hooked,
			paused and "PAUSED now (instance or chat lockdown)" or "active"))
		print(string.format("  this session: %d line(s) changed, %d skipped while paused, %d secret, %d not found",
			st.changed, st.paused, st.secret, st.missed))
	end
	print("  frame enumeration: " .. (usedChatFramesGlobal and "CHAT_FRAMES global (covers temporary windows)" or "fallback numeric scan (CHAT_FRAMES not found/empty -- temporary windows past the scan range may be missed)"))
	local wrappedCount = 0
	for _ in pairs(wrappedFrames) do wrappedCount = wrappedCount + 1 end
	print("  chat frames wrapped: " .. wrappedCount)
	if #scanBuffer == 0 then
		print("  no numbered-channel bracket actually shortened yet this session -- turn the setting on, say something in (or wait for activity in) a numbered channel, then run this again.")
	else
		for i, entry in ipairs(scanBuffer) do
			print(string.format("  [%d] %q -> %q", i, entry.before, entry.after))
		end
	end
end

local function InstallCopyButtonOnFrame(frame)
	if not frame or frame.kainUICopyButton then return end
	local btn = CreateFrame("Button", nil, frame)
	btn:SetSize(16, 16)
	btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	btn:SetFrameStrata("HIGH")

	local back = btn:CreateTexture(nil, "ARTWORK")
	back:SetPoint("TOPLEFT", 3, -3)
	back:SetSize(10, 10)
	back:SetColorTexture(1, 1, 1, 0.35)
	local front = btn:CreateTexture(nil, "OVERLAY")
	front:SetPoint("TOPLEFT", 0, 0)
	front:SetSize(10, 10)
	front:SetColorTexture(1, 1, 1, 0.55)
	btn:SetAlpha(0.55)

	btn:SetScript("OnClick", function() KUI:ShowChatCopyPopup(frame) end)
	btn:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Copy chat text")
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function(self)
		self:SetAlpha(0.55)
		GameTooltip:Hide()
	end)

	frame.kainUICopyButton = btn
end

function KUI:EnsureChatCopyButton()
	local enhanced = not KUI.db or KUI.db.chatEnhanced ~= false
	for _, frame in ipairs(GetAllChatFrames()) do
		InstallCopyButtonOnFrame(frame)
		if frame.kainUICopyButton then
			frame.kainUICopyButton:SetShown(enhanced)
		end
	end
end
KUI:EnsureChatCopyButton()

local sentMessageHistory = {}
local MAX_CHAT_HISTORY = 50

local function RecordSentMessage(text)
	if type(text) ~= "string" or text == "" then return end

	if sentMessageHistory[#sentMessageHistory] == text then return end
	table.insert(sentMessageHistory, text)
	while #sentMessageHistory > MAX_CHAT_HISTORY do
		table.remove(sentMessageHistory, 1)
	end
end

local function IsPlayerSender(sender)

	if issecretvalue and issecretvalue(sender) then return false end
	if type(sender) ~= "string" then return false end
	local playerName = UnitName("player")
	if sender == playerName then return true end
	local base = sender:match("^([^%-]+)")
	return base == playerName
end

local SENDER_CHECKED_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
}

local SELF_ONLY_EVENTS = {
	"CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER_INFORM",
}

local SELF_ONLY_LOOKUP = {}
for _, event in ipairs(SELF_ONLY_EVENTS) do
	SELF_ONLY_LOOKUP[event] = true
end

local CHAT_ECHO_CAPTURE = false
if CHAT_ECHO_CAPTURE then
	local chatHistoryCaptureFrame = CreateFrame("Frame")
	for _, event in ipairs(SENDER_CHECKED_EVENTS) do
		KUI:SafeRegisterEvent(chatHistoryCaptureFrame, event)
	end
	for _, event in ipairs(SELF_ONLY_EVENTS) do
		KUI:SafeRegisterEvent(chatHistoryCaptureFrame, event)
	end
	chatHistoryCaptureFrame:SetScript("OnEvent", function(self, event, text, sender)
		if issecretvalue and issecretvalue(text) then return end
		if SELF_ONLY_LOOKUP[event] or IsPlayerSender(sender) then
			RecordSentMessage(text)
		end
	end)
end

local historyCursor = setmetatable({}, { __mode = "k" })
local draftText = setmetatable({}, { __mode = "k" })

local function ChatHistory_OnKeyDown(editBox, key)

	if key == "ENTER" or key == "NUMPADENTER" then
		local text = editBox:GetText()
		if type(text) == "string" and not (issecretvalue and issecretvalue(text))
			and text:match("%S") then
			RecordSentMessage(text)
		end
		return
	end
	if key ~= "UP" and key ~= "DOWN" then return end

	if KUI:IsChatLockedDown() then return end

	local enhanced = not KUI.db or KUI.db.chatEnhanced ~= false
	if not enhanced then return end
	if #sentMessageHistory == 0 then return end

	local cursor = historyCursor[editBox]
	if key == "UP" then
		if cursor == nil then

			draftText[editBox] = editBox:GetText()
			cursor = #sentMessageHistory + 1
		end
		cursor = math.max(1, cursor - 1)
		historyCursor[editBox] = cursor
		editBox:SetText(sentMessageHistory[cursor])
	else
		if cursor == nil then return end
		cursor = cursor + 1
		if cursor > #sentMessageHistory then

			historyCursor[editBox] = nil
			editBox:SetText(draftText[editBox] or "")
			draftText[editBox] = nil
		else
			historyCursor[editBox] = cursor
			editBox:SetText(sentMessageHistory[cursor])
		end
	end
	editBox:SetCursorPosition(#editBox:GetText())
end

local function GetChatEditBox(frame)
	local name = frame.GetName and frame:GetName()
	local byName = name and _G[name .. "EditBox"]
	if byName then return byName end
	return frame.editBox
end

local editBoxStatusByFrame = {}

local function InstallHistoryRecallOnFrame(frame)
	local frameName = frame.GetName and frame:GetName()
	local editBox = GetChatEditBox(frame)
	if not editBox then
		if frameName then editBoxStatusByFrame[frameName] = false end
		return
	end
	if frameName then editBoxStatusByFrame[frameName] = true end
	if editBox.kainUIHistoryHooked then return end
	editBox.kainUIHistoryHooked = true

	if editBox.SetAltArrowKeyMode then
		editBox:SetAltArrowKeyMode(false)
	end

	editBox:HookScript("OnKeyDown", ChatHistory_OnKeyDown)

	editBox:HookScript("OnEnterPressed", function(self)
		historyCursor[self] = nil
		draftText[self] = nil
	end)
	editBox:HookScript("OnEscapePressed", function(self)
		historyCursor[self] = nil
		draftText[self] = nil
	end)
end

function KUI:EnsureChatHistoryRecall()
	for _, frame in ipairs(GetAllChatFrames()) do
		InstallHistoryRecallOnFrame(frame)
	end
end
KUI:EnsureChatHistoryRecall()

function KUI:ChatHistoryRecallScanReport()
	print("|cff33ff99Kain-UI Forever|r chat history recall scan:")
	print("  messages captured this session: " .. #sentMessageHistory)
	if #sentMessageHistory == 0 then
		print("  none yet -- say something in any channel, then run this again.")
	else
		local shown = math.min(3, #sentMessageHistory)
		for i = #sentMessageHistory, #sentMessageHistory - shown + 1, -1 do
			print(string.format("  [%d] %s", i, sentMessageHistory[i]))
		end
	end
	local hooked, missing = {}, {}
	for frameName, found in pairs(editBoxStatusByFrame) do
		table.insert(found and hooked or missing, frameName)
	end
	print("  edit boxes hooked: " .. table.concat(hooked, ", "))
	if #missing > 0 then
		print("  no edit box found for: " .. table.concat(missing, ", "))
	end
end

if KUI.defaults then
	KUI.defaults.socialButtonUnlocked = false
end

local socialHandle
local socialHooked = false
local socialReapplied = 0

local function SocialFrames()
	return _G.ChatAlertFrame, _G.QuickJoinToastButton
end

local function SavedSocialPos()
	local p = KUI.db and KUI.db.socialButtonPos
	if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then return p end
	return nil
end

local function PlaceSocialButton()
	local _, button = SocialFrames()
	local pos = SavedSocialPos()
	if not (button and pos) then return false end
	button:ClearAllPoints()
	button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	return true
end

local function HookSocialAnchors()
	if socialHooked then return end
	local container = SocialFrames()
	if not (container and type(container.UpdateAnchors) == "function") then return end
	socialHooked = true
	hooksecurefunc(container, "UpdateAnchors", function()
		if PlaceSocialButton() then socialReapplied = socialReapplied + 1 end
	end)
end

function KUI:ApplySocialButtonPosition()
	local container = SocialFrames()
	HookSocialAnchors()
	if not PlaceSocialButton() and container and container.UpdateAnchors then
		pcall(container.UpdateAnchors, container)
	end
end

local function PlaceHandleOnButton()
	local _, button = SocialFrames()
	if not (socialHandle and button) then return end
	socialHandle:ClearAllPoints()
	socialHandle:SetAllPoints(button)
end

local socialDrag = { downs = 0, starts = 0, stops = 0, lastError = nil }

local function CursorInUIParent()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	if not (x and y and scale and scale > 0) then return nil end
	return x / scale, y / scale
end

local function SocialDragStart(self)
	local _, b = SocialFrames()
	local left, bottom = self:GetLeft(), self:GetBottom()
	local cx, cy = CursorInUIParent()
	if not (b and left and bottom and cx) then
		socialDrag.lastError = "social button, handle or cursor has no position yet"
		return
	end
	socialDrag.starts = socialDrag.starts + 1
	local w, h = self:GetWidth(), self:GetHeight()
	if not (w and w > 0) then w, h = b:GetWidth(), b:GetHeight() end
	self:SetSize(w, h)

	self.grabX, self.grabY = cx - left, cy - bottom
	self.dragLeft, self.dragBottom = left, bottom
	self:ClearAllPoints()
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	self.moving = true
	if KUI.BeginAlignDrag then pcall(KUI.BeginAlignDrag, KUI, self) end
	GameTooltip:Hide()
	self:SetScript("OnUpdate", function(s)
		local x, y = CursorInUIParent()
		if not x then return end
		local l, bt = x - s.grabX, y - s.grabY
		s.dragLeft, s.dragBottom = l, bt
		s:ClearAllPoints()
		s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
		local _, bb = SocialFrames()
		if bb then
			bb:ClearAllPoints()
			bb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
		end
	end)
end

local function SocialDragStop(self)
	if not self.moving then return end
	self.moving = false
	socialDrag.stops = socialDrag.stops + 1
	self:SetScript("OnUpdate", nil)
	if KUI.EndAlignDrag then pcall(KUI.EndAlignDrag, KUI, self) end

	local l, bt = self:GetLeft(), self:GetBottom()
	if not (l and bt) then l, bt = self.dragLeft, self.dragBottom end
	if l and bt and KUI.db then
		KUI.db.socialButtonPos = { x = math.floor(l + 0.5), y = math.floor(bt + 0.5) }
	else
		socialDrag.lastError = "couldn't read the handle's position to save it"
	end
	KUI:ApplySocialButtonPosition()

	local container = SocialFrames()
	if container and container.UpdateAnchors then pcall(container.UpdateAnchors, container) end
	PlaceHandleOnButton()
end

local function RaiseSocialHandle(h)

	h:SetFrameStrata("HIGH")
	h:SetToplevel(true)
	h:Raise()
end

local function EnsureSocialHandle()
	if socialHandle then return socialHandle end
	local _, button = SocialFrames()
	if not button then return nil end
	local h = CreateFrame("Frame", "KainUIForeverSocialButtonHandle", UIParent)
	RaiseSocialHandle(h)
	h:SetMovable(true)
	h:SetClampedToScreen(true)
	h:EnableMouse(true)
	local tint = h:CreateTexture(nil, "OVERLAY")
	tint:SetAllPoints()
	tint:SetColorTexture(0.2, 0.85, 0.3, 0.35)
	h:SetScript("OnShow", RaiseSocialHandle)
	h:SetScript("OnEnter", function(self)
		if self.moving then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Social button", 1, 1, 1)
		GameTooltip:AddLine("Drag to move. Lock it again in /kui.", 1, 0.82, 0, true)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", function() GameTooltip:Hide() end)

	h:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton ~= "LeftButton" then return end
		socialDrag.downs = socialDrag.downs + 1
		local okStart, err = pcall(SocialDragStart, self)
		if not okStart then socialDrag.lastError = tostring(err) end
	end)
	h:SetScript("OnMouseUp", function(self)
		local okStop, err = pcall(SocialDragStop, self)
		if not okStop then socialDrag.lastError = tostring(err) end
	end)
	h:SetScript("OnHide", function(self)
		if self.moving then pcall(SocialDragStop, self) end
	end)
	socialHandle = h
	PlaceHandleOnButton()
	h:Hide()
	return h
end

function KUI:SetSocialButtonUnlocked(unlocked)
	if not KUI.db then return end
	KUI.db.socialButtonUnlocked = unlocked and true or false
	local h = EnsureSocialHandle()
	if h then
		PlaceHandleOnButton()
		h:SetShown(KUI.db.socialButtonUnlocked)
		if h:IsShown() then RaiseSocialHandle(h) end
	end
	if KUI.RefreshAlignGrid then KUI:RefreshAlignGrid() end
end

function KUI:ResetSocialButtonPosition()
	if not KUI.db then return end
	KUI.db.socialButtonPos = nil
	KUI:ApplySocialButtonPosition()
	PlaceHandleOnButton()
end

function KUI:SetSocialButtonPosition(x, y)
	if not KUI.db or type(x) ~= "number" or type(y) ~= "number" then return end
	KUI.db.socialButtonPos = { x = x, y = y }
	KUI:ApplySocialButtonPosition()
	local container = SocialFrames()
	if container and container.UpdateAnchors then pcall(container.UpdateAnchors, container) end
	PlaceHandleOnButton()
end

function KUI:ApplySocialButton()
	KUI:ApplySocialButtonPosition()
	KUI:SetSocialButtonUnlocked(KUI.db and KUI.db.socialButtonUnlocked)
end

function KUI:SocialButtonScanReport()
	local container, button = SocialFrames()
	local toast = _G.BNToastFrame
	local pos = SavedSocialPos()
	print("|cff33ff99Kain-UI Forever|r social button: " .. (pos and string.format("moved to (%d, %d)", pos.x, pos.y) or "Blizzard's position")
		.. " | " .. ((KUI.db and KUI.db.socialButtonUnlocked) and "UNLOCKED" or "locked")
		.. " | re-chain hook " .. (socialHooked and "on" or "OFF") .. ", put back " .. socialReapplied .. "x")
	local function where(name, f)
		if not f then print("  " .. name .. ": not found"); return end
		local p, rel, rp, x, y = f:GetPoint(1)
		local relName = rel and (rel.GetName and rel:GetName() or "?") or "nil"
		print(string.format("  %s: %s to %s %s (%.0f, %.0f), %d anchor(s), shown %s", name, tostring(p), relName, tostring(rp), x or 0, y or 0, f:GetNumPoints(), tostring(f:IsShown())))
	end
	where("ChatAlertFrame", container)
	where("TextToSpeechButtonFrame", _G.TextToSpeechButtonFrame)
	where("QuickJoinToastButton", button)
	where("BNToastFrame", toast)
	local h = socialHandle
	if h then
		print(string.format("  handle: shown %s, strata %s level %d, mouse %s, size %.0f x %.0f | button strata %s level %d",
			tostring(h:IsShown()), tostring(h:GetFrameStrata()), h:GetFrameLevel() or -1, tostring(h:IsMouseEnabled()),
			h:GetWidth() or 0, h:GetHeight() or 0,
			button and tostring(button:GetFrameStrata()) or "?", button and button:GetFrameLevel() or -1))
	else
		print("  handle: not created yet (unlock it in /kui)")
	end
	print(string.format("  this session: %d press(es), %d drag(s) started, %d finished%s", socialDrag.downs, socialDrag.starts, socialDrag.stops,
		socialDrag.lastError and (" | last problem: " .. socialDrag.lastError) or ""))
end

local ALLY_NOTE_MAX = 127

local function PlainText(v)
	if issecretvalue and issecretvalue(v) then return nil end
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

local function AllyNotes()
	local db = _G.KainUIForeverAccountDB
	if type(db) ~= "table" then
		db = {}
		_G.KainUIForeverAccountDB = db
	end
	if type(db.recentAllyNotes) ~= "table" then db.recentAllyNotes = {} end
	return db.recentAllyNotes
end

local function AllyIdentity(recentAllyData)
	local cd = type(recentAllyData) == "table" and recentAllyData.characterData
	if type(cd) ~= "table" then return nil end
	return PlainText(cd.guid), PlainText(cd.fullName) or PlainText(cd.name)
end

function KUI:GetRecentAllyNote(guid)
	if not guid then return nil end
	local entry = AllyNotes()[guid]
	return type(entry) == "table" and PlainText(entry.note) or nil
end

function KUI:SetRecentAllyNote(guid, name, note)
	if not guid then return end
	note = type(note) == "string" and note:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if note == "" then
		AllyNotes()[guid] = nil
	else
		AllyNotes()[guid] = { note = KUI.CutText(note, ALLY_NOTE_MAX), name = name }
	end
end

local function SaveFromDialog(dialog, data)
	local editBox = dialog and (dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox)
	data = data or (dialog and dialog.data)
	if editBox and type(data) == "table" then
		KUI:SetRecentAllyNote(data.guid, data.name, editBox:GetText())
	end
end

StaticPopupDialogs["KAINUIFOREVER_RECENT_ALLY_NOTE"] = {
	text = SET_FRIENDNOTE_LABEL or "Set notes for %s:",
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
	hasEditBox = 1,
	maxLetters = ALLY_NOTE_MAX,
	countInvisibleLetters = true,
	editBoxWidth = 350,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog, data)
		data = data or dialog.data
		local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if editBox then
			editBox:SetText(type(data) == "table" and KUI:GetRecentAllyNote(data.guid) or "")
			editBox:SetFocus()
		end
	end,
	OnAccept = function(dialog, data) SaveFromDialog(dialog, data) end,
	OnHide = function(dialog)
		local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if editBox then editBox:SetText("") end
		if ChatFrameUtil and ChatFrameUtil.FocusActiveWindow then pcall(ChatFrameUtil.FocusActiveWindow) end
	end,
	EditBoxOnEnterPressed = function(editBox, data)
		local dialog = editBox:GetParent()
		SaveFromDialog(dialog, data)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

local allyMenuStats = { added = 0, skippedBlizzard = 0 }

local function AddAllyNoteButton(_owner, rootDescription, contextData)
	local guid, name = AllyIdentity(contextData and contextData.recentAllyData)
	if not guid or not rootDescription then return end

	if C_RecentAllies and C_RecentAllies.CanSetRecentAllyNote then
		local ok, can = pcall(C_RecentAllies.CanSetRecentAllyNote, guid)
		if ok and can == true then
			allyMenuStats.skippedBlizzard = allyMenuStats.skippedBlizzard + 1
			return
		end
	end
	allyMenuStats.added = allyMenuStats.added + 1
	rootDescription:CreateDivider()
	local label = RECENT_ALLIES_MENU_BUTTON_LABEL_SET_NOTE or SET_NOTE or "Set Note"
	local button = rootDescription:CreateButton(label, function()
		StaticPopup_Show("KAINUIFOREVER_RECENT_ALLY_NOTE", name or "", nil, { guid = guid, name = name })
	end)

	if button and button.AddInitializer and contextData.menuElementPreInitializer then
		button:AddInitializer(contextData.menuElementPreInitializer)
	end
end

if Menu and Menu.ModifyMenu then
	Menu.ModifyMenu("MENU_UNIT_RECENT_ALLY", AddAllyNoteButton)
	Menu.ModifyMenu("MENU_UNIT_RECENT_ALLY_OFFLINE", AddAllyNoteButton)
end

local function AddAllyNoteToTooltip(self, tooltip)
	local data = self and self.elementData
	local guid = AllyIdentity(data)
	local note = KUI:GetRecentAllyNote(guid)
	if not (note and tooltip) then return end

	if type(data.interactionData) == "table" and PlainText(data.interactionData.note) then return end
	local online = type(data.stateData) == "table" and data.stateData.isOnline
	local fmt = (online and SOCIAL_UI_RECENT_ALLIES_NOTE_FORMAT or SOCIAL_UI_RECENT_ALLIES_NOTE_OFFLINE_FORMAT)
		or RECENT_ALLY_NOTE_FORMAT or "Note: %s"
	local color = (online and NORMAL_FONT_COLOR) or FRIENDS_GRAY_COLOR or NORMAL_FONT_COLOR
	local ok, text = pcall(string.format, fmt, note)
	if not ok then text = "Note: " .. note end
	if color then tooltip:AddLine(text, color.r, color.g, color.b, true) else tooltip:AddLine(text, 1, 0.82, 0, true) end
end

local allyTooltipHooked = {}
local function HookAllyTooltips()
	for _, mixinName in ipairs({ "RecentAlliesSocialCardMixin", "RecentAlliesEntryMixin" }) do
		local mixin = _G[mixinName]
		if not allyTooltipHooked[mixinName] and type(mixin) == "table" and type(mixin.AddInteractionDataToTooltip) == "function" then
			allyTooltipHooked[mixinName] = true
			hooksecurefunc(mixin, "AddInteractionDataToTooltip", AddAllyNoteToTooltip)
		end
	end
end
HookAllyTooltips()

local allyLoadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(allyLoadFrame, "ADDON_LOADED")
allyLoadFrame:SetScript("OnEvent", function(_, _, loaded)
	if loaded == "Blizzard_RecentAllies" or loaded == "Blizzard_SocialUI" then HookAllyTooltips() end
end)

function KUI:AllyNoteScanReport()
	local n = 0
	for _ in pairs(AllyNotes()) do n = n + 1 end
	print("|cff33ff99Kain-UI Forever|r Recent Allies notes: " .. n .. " saved (account-wide)"
		.. " | menu " .. ((Menu and Menu.ModifyMenu) and "hooked" or "NOT hooked (Menu.ModifyMenu missing)")
		.. " | tooltips: card " .. (allyTooltipHooked.RecentAlliesSocialCardMixin and "hooked" or "not hooked")
		.. ", list " .. (allyTooltipHooked.RecentAlliesEntryMixin and "hooked" or "not hooked"))
	print(string.format("  this session: \"Set Note\" added to %d menu(s), left to Blizzard in %d (server notes allowed)", allyMenuStats.added, allyMenuStats.skippedBlizzard))
	for guid, entry in pairs(AllyNotes()) do
		if type(entry) == "table" then print(string.format("  %s: %s", tostring(entry.name or guid), tostring(entry.note))) end
	end
end
