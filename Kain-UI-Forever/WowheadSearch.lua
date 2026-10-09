local _, KUI = ...

local SEARCH_URL = "https://www.wowhead.com/forever/search?q="
local BINDING_ACTION = "KAINUIFOREVER_WOWHEAD"
local DEFAULT_KEY = "CTRL-SHIFT-W"

_G.BINDING_HEADER_KAINUIFOREVER = "K-UI: Forever"
_G["BINDING_NAME_" .. BINDING_ACTION] = "Wowhead search (hovered item, spell or quest)"

local lastLookup
local bindStatus = "not checked yet"

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Text(v)
	if not Plain(v) or type(v) ~= "string" then return nil end
	v = v:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if v == "" then return nil end
	return v
end

function KUI:WowheadQuery(name)
	name = Text(name)
	if not name then return nil end
	local s = name:lower()

	s = s:gsub("\226\128\153", ""):gsub("\226\128\152", ""):gsub("['`]", "")
	local out, pendingGap = {}, false
	for i = 1, #s do
		local b = s:byte(i)
		local c = s:sub(i, i)
		local piece
		if c:match("[%w%-]") then
			piece = c
		elseif b >= 128 then
			piece = format("%%%02X", b)
		end
		if piece then
			if pendingGap and #out > 0 then out[#out + 1] = "+" end
			pendingGap = false
			out[#out + 1] = piece
		else
			pendingGap = true
		end
	end
	local q = table.concat(out)
	if q == "" then return nil end
	return q
end

function KUI:WowheadURL(name)
	local q = self:WowheadQuery(name)
	return q and (SEARCH_URL .. q) or nil
end

local function TooltipTopLine(tip)
	local okN, tipName = pcall(function() return tip:GetName() end)
	local fs = okN and tipName and _G[tipName .. "TextLeft1"]
	if not fs then return nil end
	local ok, t = pcall(fs.GetText, fs)
	return ok and Text(t) or nil
end

local function NameFromLink(link)
	link = Text(link)
	return link and Text(link:match("%[(.-)%]")) or nil
end

local function SpellName(id)
	if not Plain(id) then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and Text(n) then return Text(n) end
	end
	if GetSpellInfo then
		local ok, n = pcall(GetSpellInfo, id)
		if ok and Text(n) then return Text(n) end
	end
end

local function ItemName(id)
	if not Plain(id) then return nil end
	if C_Item and C_Item.GetItemNameByID then
		local ok, n = pcall(C_Item.GetItemNameByID, id)
		if ok and Text(n) then return Text(n) end
	end
	if GetItemInfo then
		local ok, n = pcall(GetItemInfo, id)
		if ok and Text(n) then return Text(n) end
	end
end

local function QuestName(id)
	if not Plain(id) then return nil end
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, n = pcall(C_QuestLog.GetTitleForQuestID, id)
		if ok and Text(n) then return Text(n) end
	end
	if C_QuestLog and C_QuestLog.GetQuestInfo then
		local ok, n = pcall(C_QuestLog.GetQuestInfo, id)
		if ok and Text(n) then return Text(n) end
	end
end

local function CleanQuestTitle(t)
	t = Text(t)
	if not t then return nil end
	t = t:gsub("^%[[^%]]*%]%s*", ""):gsub("%s*%([^%)]*%)$", "")
	return Text(t)
end

local function TypeIs(dataType, name)
	local enum = Enum and Enum.TooltipDataType
	return enum and enum[name] ~= nil and dataType == enum[name]
end

local function FromTooltip(tip)
	if not tip then return nil end
	local okShown, shown = pcall(tip.IsShown, tip)
	if not (okShown and shown) then return nil end

	local data
	for _, getter in ipairs({ "GetPrimaryTooltipData", "GetTooltipData" }) do
		if not data and tip[getter] then
			local ok, d = pcall(tip[getter], tip)
			if ok and type(d) == "table" and not (issecretvalue and issecretvalue(d)) then data = d end
		end
	end
	local dataType = data and Plain(data.type) and data.type
	local id = data and Plain(data.id) and data.id

	if dataType ~= nil and TypeIs(dataType, "Item") then
		local okI, n, link = pcall(tip.GetItem, tip)
		local name = (okI and (Text(n) or NameFromLink(link))) or ItemName(id) or TooltipTopLine(tip)
		if name then return name, "item", "tooltip (item)" end

	elseif dataType ~= nil and (TypeIs(dataType, "Spell") or TypeIs(dataType, "UnitAura")) then
		local name = SpellName(id) or TooltipTopLine(tip)
		if name then return name, "spell", "tooltip (spell)" end
	elseif dataType ~= nil and TypeIs(dataType, "Quest") then
		local name = QuestName(id) or TooltipTopLine(tip)
		if name then return name, "quest", "tooltip (quest)" end
	end

	if tip.GetItem then
		local ok, n, link = pcall(tip.GetItem, tip)
		local name = ok and (Text(n) or NameFromLink(link))
		if name then return name, "item", "tooltip:GetItem" end
	end
	if tip.GetSpell then
		local ok, n, spellId = pcall(tip.GetSpell, tip)
		local name = ok and (Text(n) or SpellName(spellId))
		if name then return name, "spell", "tooltip:GetSpell" end
	end
	return nil
end

local function MouseFocus()
	if GetMouseFoci then
		local ok, foci = pcall(GetMouseFoci)
		if ok and type(foci) == "table" then return foci[1] end
	end
	if GetMouseFocus then
		local ok, f = pcall(GetMouseFocus)
		if ok then return f end
	end
end

local function Field(frame, key)
	local ok, v = pcall(function() return frame[key] end)
	if ok and Plain(v) then return v end
end

local lastMouseCheck = "not used yet"
local function IsUnderMouse(frame)
	if not frame then return false end
	local okS, shown = pcall(frame.IsVisible, frame)
	if not (okS and shown) then return false end
	if frame.IsMouseOver then
		local ok, over = pcall(frame.IsMouseOver, frame)
		if ok and Plain(over) then
			lastMouseCheck = "IsMouseOver said " .. tostring(over)
			return over == true
		end
	end
	if MouseIsOver then
		local ok, over = pcall(MouseIsOver, frame)
		if ok and Plain(over) then
			lastMouseCheck = "MouseIsOver said " .. tostring(over)
			return over == true
		end
	end
	lastMouseCheck = "no working mouse check"
	return false
end

local function SafeText(obj)
	if not obj then return nil end
	local ok, t = pcall(function() return obj:GetText() end)
	if ok then return t end
end

local function FromQuestFrames()
	local focus = MouseFocus()
	local f = focus
	for _ = 1, 3 do
		if not f then break end

		local questID = Field(f, "questID") or Field(f, "questId")
		local name = questID and QuestName(questID)
		if name then return name, "quest", "quest log row (quest ID)" end
		local index = Field(f, "questLogIndex")
		if index then
			if C_QuestLog and C_QuestLog.GetInfo then
				local ok, info = pcall(C_QuestLog.GetInfo, index)
				if ok and type(info) == "table" and not info.isHeader and Text(info.title) then
					return Text(info.title), "quest", "quest log row (index)"
				end
			end
			if GetQuestLogTitle then
				local ok, title, _, _, isHeader = pcall(GetQuestLogTitle, index)
				if ok and not isHeader and Text(title) then return CleanQuestTitle(title), "quest", "quest log row (index)" end
			end
		end

		local okN, fname = pcall(function() return f:GetName() end)
		if okN and type(fname) == "string" and (fname:match("^QuestLogTitle%d+$") or fname:match("^QuestLogListScrollFrameButton%d+$")) then
			local isHeader = Field(f, "isHeader")
			if not isHeader then
				local title = CleanQuestTitle(SafeText(f))
				if title then return title, "quest", "quest log title button" end
			end
		end
		local okP, parent = pcall(function() return f:GetParent() end)
		f = okP and parent or nil
	end

	if IsUnderMouse(_G.QuestLogDetailScrollFrame) or IsUnderMouse(_G.QuestLogDetailFrame) then
		local title = CleanQuestTitle(SafeText(_G.QuestLogQuestTitle))
		if title then return title, "quest", "quest log details" end
	end
	if IsUnderMouse(_G.QuestFrame) then
		local title
		if GetTitleText then
			local okT, v = pcall(GetTitleText)
			if okT then title = CleanQuestTitle(v) end
		end
		title = title or CleanQuestTitle(SafeText(_G.QuestInfoTitleHeader))
		if title then return title, "quest", "quest giver window" end
	end
end

local CHAT_LINK_KINDS = {
	item = "item", spell = "spell", enchant = "spell", talent = "spell", trade = "spell",
	quest = "quest", achievement = "other", currency = "other",
}
local chatLink
local chatHooked = setmetatable({}, { __mode = "k" })

local chatStats = { hooked = 0, hookFailed = 0, enters = 0, leaves = 0, names = {} }

local function FrameLabel(f)
	local ok, n = pcall(function() return f:GetName() end)
	return (ok and Plain(n) and n) or "<unnamed>"
end

local function ChatLinkName(linkType, link, text)

	local shown = Text(text) and Text(text):match("%[(.*)%]")
	if linkType == "quest" then shown = CleanQuestTitle(shown) end
	if Text(shown) then return Text(shown) end
	local id = tonumber(link:match("^[^:]+:(%d+)"))
	if linkType == "item" then return ItemName(id) end
	if linkType == "quest" then return QuestName(id) end
	if linkType == "spell" or linkType == "enchant" then return SpellName(id) end
end

local function OnChatLinkEnter(frame, link, text)
	chatLink = nil
	chatStats.enters = chatStats.enters + 1
	local seen = { frame = FrameLabel(frame), at = GetTime() }
	chatStats.lastEnter = seen
	if not Plain(link) then seen.result = "the link itself is secret" return end
	if type(link) ~= "string" then seen.result = "link is a " .. type(link) .. ", not text" return end
	local linkType = link:match("^([^:]+)")
	seen.linkType = tostring(linkType)
	seen.textState = (text == nil and "none") or (not Plain(text) and "secret") or "readable"
	local kind = linkType and CHAT_LINK_KINDS[linkType]
	if not kind then seen.result = "not a searchable link type" return end
	local ok, name = pcall(ChatLinkName, linkType, link, Plain(text) and text or nil)
	if not ok then seen.result = "error: " .. tostring(name) return end
	if not name then seen.result = "no name in the link text or by ID" return end
	seen.result = "remembered: " .. name
	chatLink = { frame = frame, name = name, kind = kind, linkType = linkType }
end

local function HookChatFrame(frame)
	if not frame or chatHooked[frame] or not frame.HookScript then return end
	local okEnter = pcall(frame.HookScript, frame, "OnHyperlinkEnter", function(self, link, text)
		pcall(OnChatLinkEnter, self, link, text)
	end)
	if not okEnter then
		chatStats.hookFailed = chatStats.hookFailed + 1
		return
	end
	chatHooked[frame] = true
	chatStats.hooked = chatStats.hooked + 1
	chatStats.names[#chatStats.names + 1] = FrameLabel(frame)
	pcall(frame.HookScript, frame, "OnHyperlinkLeave", function(self)
		chatStats.leaves = chatStats.leaves + 1
		chatStats.lastLeave = GetTime()
		if chatLink and chatLink.frame == self then chatLink = nil end
	end)
	pcall(frame.HookScript, frame, "OnHide", function(self)
		if chatLink and chatLink.frame == self then chatLink = nil end
	end)
end

local function HookAllChatFrames()
	if type(_G.CHAT_FRAMES) == "table" then
		for _, name in ipairs(_G.CHAT_FRAMES) do HookChatFrame(_G[name]) end
	end
	for i = 1, math.max(_G.NUM_CHAT_WINDOWS or 10, 10) + 20 do
		HookChatFrame(_G["ChatFrame" .. i])
	end
end

pcall(HookAllChatFrames)
local chatHookFrame = CreateFrame("Frame")
chatHookFrame:RegisterEvent("PLAYER_LOGIN")
chatHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(chatHookFrame.RegisterEvent, chatHookFrame, "UPDATE_CHAT_WINDOWS")
chatHookFrame:SetScript("OnEvent", function() pcall(HookAllChatFrames) end)
if type(FCF_OpenTemporaryWindow) == "function" then
	hooksecurefunc("FCF_OpenTemporaryWindow", function() pcall(HookAllChatFrames) end)
end

local function ChatFrameUnderMouse()
	for frame in pairs(chatHooked) do
		if IsUnderMouse(frame) then return FrameLabel(frame) end
	end
end

local function FromChatLink()
	if chatLink then
		return chatLink.name, chatLink.kind, "chat link (" .. chatLink.linkType .. ")"
	end
end

function KUI:WowheadHovered()

	local linkName, linkKind, linkHow = FromChatLink()
	if linkName then return linkName, linkKind, linkHow end

	if IsUnderMouse(_G.ItemRefTooltip) then
		local name, kind, how = FromTooltip(_G.ItemRefTooltip)
		if name then return name, kind, "chat link " .. how end
	end
	local name, kind, how = FromTooltip(GameTooltip)
	if name then return name, kind, how end
	name, kind, how = FromQuestFrames()
	if name then return name, kind, how end

	local okShown, shown = pcall(GameTooltip.IsShown, GameTooltip)
	if okShown and shown then
		local top = TooltipTopLine(GameTooltip)
		if top then return top, "other", "tooltip top line" end
	end
	return nil
end

local function DialogEditBox(dialog)
	if not dialog then return nil end
	if dialog.GetEditBox then
		local ok, eb = pcall(dialog.GetEditBox, dialog)
		if ok and eb then return eb end
	end
	if dialog.editBox then return dialog.editBox end
	if dialog.EditBox then return dialog.EditBox end
	local okN, n = pcall(function() return dialog:GetName() end)
	return okN and n and _G[n .. "EditBox"] or nil
end

local function FillBox(dialog, url)
	local eb = DialogEditBox(dialog)
	if not eb then return end
	eb.kuiWowheadURL = url
	eb:SetText(url or "")
	eb:SetFocus()
	eb:HighlightText()
	if eb.SetCursorPosition then eb:SetCursorPosition(0) eb:HighlightText() end
end

StaticPopupDialogs["KAINUIFOREVER_WOWHEAD"] = {
	text = "Wowhead search: |cffffd100%s|r\nPress Ctrl+C to copy, then paste it into your browser.",
	button1 = CLOSE or "Close",
	hasEditBox = 1,
	editBoxWidth = 360,
	maxLetters = 0,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
	OnShow = function(dialog, data)
		data = data or dialog.data
		FillBox(dialog, type(data) == "table" and data.url or nil)
	end,
	OnHide = function(dialog)
		local eb = DialogEditBox(dialog)
		if eb then eb.kuiWowheadURL = nil eb:SetText("") end
	end,

	EditBoxOnTextChanged = function(editBox)
		local url = editBox.kuiWowheadURL
		if url and editBox:GetText() == "" then
			editBox.kuiWowheadURL = nil
			C_Timer.After(0, function() StaticPopup_Hide("KAINUIFOREVER_WOWHEAD") end)
			return
		end
		if url and editBox:GetText() ~= url then
			editBox:SetText(url)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function(editBox) editBox:GetParent():Hide() end,
	EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

local function Say(msg) print("|cff33ff99Kain-UI Forever|r " .. msg) end

function KUI:WowheadSearch()
	local name, kind, how = self:WowheadHovered()
	local url = name and self:WowheadURL(name)
	lastLookup = { name = name, kind = kind, how = how, url = url, at = time and time(),
		chatUnder = ChatFrameUnderMouse(), chatLinkHeld = chatLink and chatLink.name or nil, mouseCheck = lastMouseCheck }
	if not url then
		local okShown, shown = pcall(GameTooltip.IsShown, GameTooltip)
		local secretTop
		if okShown and shown then
			local okN, tipName = pcall(function() return GameTooltip:GetName() end)
			local fs = okN and tipName and _G[tipName .. "TextLeft1"]
			local okT, t = pcall(function() return fs and fs:GetText() end)
			secretTop = okT and issecretvalue and issecretvalue(t)
		end
		if secretTop then
			Say("Wowhead search: the game is hiding that tooltip right now (combat). Try again out of combat.")
		else
			Say("Wowhead search: hover an item, spell or quest first, then press the key.")
		end
		return
	end
	StaticPopup_Hide("KAINUIFOREVER_WOWHEAD")
	local dialog = StaticPopup_Show("KAINUIFOREVER_WOWHEAD", name, nil, { url = url, name = name })

	if dialog then
		dialog.data = dialog.data or { url = url, name = name }
		FillBox(dialog, url)
	end
end

function KainUIForever_WowheadSearch()
	KUI:WowheadSearch()
end

local function BindStore()
	local set = GetCurrentBindingSet and GetCurrentBindingSet() or 1
	if set == 2 then

		return KUI.db, set
	end
	if type(_G.KainUIForeverAccountDB) ~= "table" then _G.KainUIForeverAccountDB = {} end
	return _G.KainUIForeverAccountDB, set
end

local function EnsureDefaultKey()
	if not (GetBindingKey and SetBinding) then bindStatus = "no key binding API" return true end
	if InCombatLockdown and InCombatLockdown() then bindStatus = "waiting for combat to end" return false end
	local store, set = BindStore()
	if type(store) ~= "table" then bindStatus = "settings not ready" return false end
	local key = GetBindingKey(BINDING_ACTION)
	if Plain(key) and key then
		store.wowheadKeySet = true
		bindStatus = "bound to " .. tostring(key)
		return true
	end
	if store.wowheadKeySet then
		bindStatus = "no key (cleared by you on the Key Bindings screen; left alone)"
		return true
	end
	local current = GetBindingAction and GetBindingAction(DEFAULT_KEY)
	if Plain(current) and current ~= nil and current ~= "" then
		store.wowheadKeySet = true
		bindStatus = DEFAULT_KEY .. " is already used by " .. tostring(current) .. " (left alone)"
		Say("Wowhead search: " .. DEFAULT_KEY .. " is already in use, so no key was set. Pick one under Key Bindings > AddOns > K-UI: Forever.")
		return true
	end
	local ok = pcall(SetBinding, DEFAULT_KEY, BINDING_ACTION)
	if ok and SaveBindings then pcall(SaveBindings, set) end
	store.wowheadKeySet = true
	bindStatus = ok and ("set to " .. DEFAULT_KEY .. " (first time)") or "setting the key failed"
	return true
end

local bindFrame = CreateFrame("Frame")
bindFrame:RegisterEvent("PLAYER_LOGIN")
bindFrame:SetScript("OnEvent", function(self, event)

	C_Timer.After(2, function()
		local okRun, done = pcall(EnsureDefaultKey)
		if okRun and not done then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:SetScript("OnEvent", function(f)
				local okAgain, doneAgain = pcall(EnsureDefaultKey)
				if not okAgain or doneAgain then f:UnregisterEvent("PLAYER_REGEN_ENABLED") end
			end)
		end
	end)
end)

function KUI:WowheadScanReport()
	local key = GetBindingKey and GetBindingKey(BINDING_ACTION)
	Say("Wowhead search key: " .. tostring(key or "none") .. " -- " .. bindStatus)
	local name, kind, how = self:WowheadHovered()
	Say("Hovered right now: " .. (name and (name .. " (" .. tostring(kind) .. ", from " .. tostring(how) .. ")") or "nothing usable"))
	if lastLookup then
		Say("Last search: " .. tostring(lastLookup.name or "nothing found") .. (lastLookup.how and (" via " .. lastLookup.how) or "")
			.. (lastLookup.url and (" -> " .. lastLookup.url) or ""))
		Say("  at the key press: chat window under the mouse " .. tostring(lastLookup.chatUnder or "none")
			.. ", chat link held " .. tostring(lastLookup.chatLinkHeld or "none") .. " (mouse check: " .. tostring(lastLookup.mouseCheck) .. ")")
	else
		Say("Last search: none this session.")
	end

	Say("Chat links: " .. chatStats.hooked .. " chat window(s) hooked (" .. table.concat(chatStats.names, ", ") .. ")"
		.. (chatStats.hookFailed > 0 and (", " .. chatStats.hookFailed .. " hook(s) refused") or "")
		.. "; mouse-on-link reports " .. chatStats.enters .. ", mouse-off-link reports " .. chatStats.leaves)
	local e = chatStats.lastEnter
	if e then
		Say(format("  last mouse-on-link: %s, type %s, shown text %s -> %s (%.1fs ago)%s", e.frame, tostring(e.linkType or "?"),
			tostring(e.textState or "?"), tostring(e.result), GetTime() - e.at,
			(chatStats.lastLeave and chatStats.lastLeave >= e.at) and format("; mouse left it %.1fs later", chatStats.lastLeave - e.at) or "; no mouse-off since"))
	else
		Say("  the game hasn't reported the mouse on any chat link this session.")
	end

	local meta = ChatFrame1 and getmetatable(ChatFrame1)
	local methods = meta and type(meta.__index) == "table" and meta.__index
	local found = {}
	if methods then
		for k in pairs(methods) do
			if type(k) == "string" and k:find("Hyperlink") then found[#found + 1] = k end
		end
		table.sort(found)
	end
	Say("  ChatFrame1 link functions: " .. (#found > 0 and table.concat(found, ", ") or "none found"))
end
