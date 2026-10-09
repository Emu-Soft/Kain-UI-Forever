local _, KUI = ...

local STEP_DELAY = 0.15
local COMBAT_DELAY = 0.05
local FOLDER = "Kain%-UI%-Forever"
local PREFIX = "|cff33ff99Kain-UI Forever|r stress test: "

local run
local eventFrame = CreateFrame("Frame")

local function Say(msg)
	local f = DEFAULT_CHAT_FRAME
	if f and f.AddMessage then pcall(f.AddMessage, f, PREFIX .. msg) end
end

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, val in pairs(v) do out[DeepCopy(k)] = DeepCopy(val) end
	return out
end

local LEARNED = { castByCache = true, chatHistory = true, xpSession = true, lootRollScreenBase = true,
	lootRollRawBase = true, rxpCharKey = true }

local function PutBack(backup)
	local keep = {}
	for key in pairs(LEARNED) do keep[key] = KUI.db[key] end
	wipe(KUI.db)
	for k, v in pairs(DeepCopy(backup)) do KUI.db[k] = v end
	for key, value in pairs(keep) do KUI.db[key] = value end
end

local function AccountDB()
	if type(_G.KainUIForeverAccountDB) ~= "table" then _G.KainUIForeverAccountDB = {} end
	return _G.KainUIForeverAccountDB
end

local function Who()
	local ok, name = pcall(UnitName, "player")
	local okR, realm = pcall(GetRealmName)
	return ((ok and Plain(name) and name) or "?") .. "-" .. ((okR and Plain(realm) and realm) or "?")
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function ErrorTotals()
	local totals, stacks = {}, {}
	if KUI.GetErrorLog then
		local ok, log = pcall(KUI.GetErrorLog, KUI)
		if ok and type(log) == "table" then
			for _, e in ipairs(log) do
				if type(e.m) == "string" then
					totals[e.m] = (totals[e.m] or 0) + (tonumber(e.n) or 1)
					stacks[e.m] = type(e.s) == "table" and e.s or {}
				end
			end
		end
	end
	return totals, stacks
end

local function TestCaused(msg, stack)
	if msg:find("^[%w_]+%.lua:%d+:") then return false end
	if #stack == 0 then return false end
	for _, line in ipairs(stack) do
		if not tostring(line):find("^StressTest%.lua") then return false end
	end
	return true
end

local function NewErrors(before, after, stacks)
	local list = {}
	for msg, n in pairs(after) do
		local was = before[msg] or 0
		if n > was then
			list[#list + 1] = { m = msg, n = n - was, test = TestCaused(msg, stacks and stacks[msg] or {}) }
		end
	end
	table.sort(list, function(a, b) return a.n > b.n end)
	return list
end

local function IsOurs(text)
	if not Plain(text) then return false end
	for line in tostring(text):gmatch("[^\n]+") do
		if line:find(FOLDER .. "[/\\]") and not line:find("StressTest%.lua") then return true end
	end
	return false
end

local currentLabel
local function Handler(err)
	local stack = ""
	if debugstack then
		local ok, s = pcall(debugstack, 2, 30, 10)
		if ok and Plain(s) then stack = s end
	end
	if run then
		if IsOurs(err) or IsOurs(stack) then
			run.ourThrows[#run.ourThrows + 1] = (currentLabel or "?") .. ": " .. (Plain(err) and tostring(err) or "(secret)")
			local okH, h = pcall(geterrorhandler)
			if okH and type(h) == "function" then pcall(h, err) end
		else
			run.gameThrows[#run.gameThrows + 1] = (currentLabel or "?") .. ": " .. (Plain(err) and tostring(err) or "(secret)")
		end
	end
	return err
end

local function Check(label, ok, detail)
	if run and not ok then
		run.checksFailed[#run.checksFailed + 1] = label .. (detail and (": " .. detail) or "")
	end
end

local function ValidUTF8(text)
	if type(text) ~= "string" then return true end
	local i, n = 1, #text
	while i <= n do
		local b = text:byte(i)
		local len = (b < 128 and 1) or (b >= 194 and b < 224 and 2) or (b >= 224 and b < 240 and 3) or (b >= 240 and b < 245 and 4)
		if not len or i + len - 1 > n then return false end
		for j = i + 1, i + len - 1 do
			local c = text:byte(j)
			if c < 128 or c >= 192 then return false end
		end
		i = i + len
	end
	return true
end

local function Try(label, fn, ...)
	currentLabel = label
	local args, n = { ... }, select("#", ...)
	local ok = xpcall(function() return fn(unpack(args, 1, n)) end, Handler)
	currentLabel = nil
	return ok
end

local SUSPICIOUS = { "fail", "error", "invalid", "couldn't" }

local BENIGN = { "%f[%d]0 failed", "%f[%d]0 call%(s%) failed", "no errors", "%f[%d]0 caught", "%f[%d]0 errors",
	"%f[%d]0 blocked", "%f[%d]0 noted", "error announcements", "errorsframe", "error log:" }

local LISTING_STEPS = { "^/kui dumpframe", "^/kui errorscan", "^KAINUIEMOJI list" }

local function Mute()
	if not run or run.muted or not (getprinthandler and setprinthandler) then return end
	local ok, real = pcall(getprinthandler)
	if not ok or type(real) ~= "function" then return end
	run.realPrint = real
	setprinthandler(function(...)
		if not run then return real(...) end
		run.printed = run.printed + 1
		local parts = {}
		for i = 1, select("#", ...) do
			local v = select(i, ...)
			parts[#parts + 1] = Plain(v) and tostring(v) or "?"
		end
		local line = table.concat(parts, " ")
		local low = line:lower()
		for _, pattern in ipairs(BENIGN) do
			if low:find(pattern) then low = "" break end
		end
		for _, pattern in ipairs(LISTING_STEPS) do
			if (currentLabel or ""):find(pattern) then low = "" break end
		end
		for _, word in ipairs(SUSPICIOUS) do
			if low:find(word, 1, true) then
				if not run.suspiciousSeen[line] and #run.suspicious < 10 then
					run.suspiciousSeen[line] = true
					run.suspicious[#run.suspicious + 1] = (currentLabel or "?") .. ": " .. line
				end
				break
			end
		end
	end)
	run.muted = true
end

local function Unmute()
	if run and run.muted and setprinthandler then
		pcall(setprinthandler, run.realPrint)
		run.muted = false
	end
end

local function NotFalse(key) return function(db) return db[key] ~= false end end

local TOGGLES = {
	{ key = "minimapUnclamped", set = "SetMinimapUnclamped" },
	{ key = "minimapDetached", set = "SetMinimapDetached" },
	{ key = "squareMinimap", set = "SetSquareMinimap" },
	{ key = "headerBarUnlocked", set = "SetMinimapElementsUnlocked" },
	{ key = "guildDifficultyForced", set = "SetGuildDifficultyForced" },
	{ key = "chatEnhanced", set = "SetChatEnhanced", get = NotFalse("chatEnhanced") },
	{ key = "emojiChat", set = "SetEmojiChatEnabled", get = NotFalse("emojiChat") },
	{ key = "emojiButtonUnlocked", set = "SetEmojiButtonUnlocked" },
	{ key = "socialButtonUnlocked", set = "SetSocialButtonUnlocked" },
	{ key = "levelUpScreenshot", set = "SetLevelUpScreenshot" },
	{ key = "platerStyle", set = "SetPlaterStyle", cvars = true },
	{ key = "snapToElements", set = "SetSnapToElements" },
	{ key = "bagChrome", set = "SetBagBarChromeHidden",
		get = function(db) return db.hideBagBarBorderArt or db.hideBagBarDividers end,
		raw = function(db, on) db.hideBagBarBorderArt = on; db.hideBagBarDividers = on end },
	{ key = "autoSellGreys", set = "SetAutoSellGreys" },
	{ key = "autoRepair", set = "SetAutoRepair" },
	{ key = "autoRepairUseGuildFunds", set = "SetAutoRepairUseGuildFunds" },
	{ key = "convertImperialToMetric", set = "SetConvertImperialToMetric" },
	{ key = "followRXPObjectives", set = "SetFollowRXPObjectives" },
	{ key = "lfgShowZone", set = "SetLFGZoneShown", get = NotFalse("lfgShowZone") },
	{ key = "microMenuHidden", set = "SetMicroMenuHidden" },
	{ key = "contrastEnabled", set = "SetContrastEnabled", cvars = true },
	{ key = "fastLoot", set = "SetFastLoot" },
	{ key = "lootRollDragging", set = "SetLootRollDragging", get = NotFalse("lootRollDragging") },
	{ key = "lootRollAnchorLocked", set = "SetLootRollAnchorLocked", get = NotFalse("lootRollAnchorLocked") },
	{ key = "globalDragging", set = "SetGlobalDragging" },
	{ key = "xpBarUnderPortrait", set = "SetXPBarUnderPortrait" },
	{ key = "xpBarHideDefault", set = "SetHideDefaultXPBar" },
	{ key = "tooltipAnchorLocked", set = "SetTooltipAnchorLocked", get = NotFalse("tooltipAnchorLocked") },
	{ key = "tooltipAnchorMode", set = "SetTooltipAnchorMode",
		get = function(db) return db.tooltipAnchorMode == "growRight" end,
		value = function(on) return on and "growRight" or "default" end },
}

local function AllToggles()
	local list = {}
	for _, t in ipairs(TOGGLES) do list[#list + 1] = t end
	local function Slots(options, tableKey, setter)
		for _, opt in ipairs(options or {}) do
			local slot = opt.key
			list[#list + 1] = {
				key = tableKey .. "." .. tostring(slot), set = setter, slot = slot,
				get = function(db) return type(db[tableKey]) == "table" and db[tableKey][slot] == true end,
				raw = function(db, on)
					db[tableKey] = type(db[tableKey]) == "table" and db[tableKey] or {}
					db[tableKey][slot] = on or nil
				end,
			}
		end
	end
	local okB, bags = pcall(function() return KUI.GetBagSlotOptions and KUI:GetBagSlotOptions() end)
	Slots(okB and bags, "hiddenBagSlots", "SetBagSlotHidden")
	local okM, micro = pcall(function() return KUI.GetMicroButtonOptions and KUI:GetMicroButtonOptions() end)
	Slots(okM and micro, "hiddenMicroButtons", "SetMicroButtonHidden")
	return list
end

local function IsOn(t, db)
	db = db or KUI.db
	if not db then return false end
	if t.get then return t.get(db) and true or false end
	return db[t.key] == true
end

local function SetToggle(t, on)
	local fn = KUI[t.set]
	if type(fn) ~= "function" then return end
	local value = t.value and t.value(on) or on
	if t.slot ~= nil then fn(KUI, t.slot, value) else fn(KUI, value) end
end

local SCANS = {
	"bagscan", "bagdebug", "microscan", "bagdividerscan", "xpscan", "socialscan", "allynotescan",
	"levelshotscan", "wowheadscan", "errorscan", "sparklescan", "dragscan", "vendorscan",
	"iconpickerscan", "macroscan", "fastlootscan", "contrastscan", "minimapposscan",
	"chatshorthandscan", "chatnumscan", "chathistoryscan", "chatlinkscan", "minimapstratascan",
	"tooltipscan", "borderscan", "actionbarscan", "rxpscan", "rxpfollowscan", "castbyscan",
	"dielscan", "bagfixscan", "zonebarscan", "binscan", "squarescan", "lfgfieldscan", "diffscan",

	"", "", "help", "help", "notacommand", "SNAPSHOT", "snapshot 2", "snapshot 99", "snapshot x",
	"dumpframe", "dumpframe UIParent", "dumpframe NoSuchFrame_KUIStress", "factoryreset",
	"factoryreset nope", "   bagscan   ",
}

local OTHER_SLASH = {
	{ "KTARGETER", "probe" }, { "KTARGETER", "regen" }, { "KTARGETER", "nonsense words" },
	{ "KTARGETER", "source no arrow" }, { "KTARGETER", "gui" }, { "KTARGETER", "gui" },
	{ "KKEY", "" }, { "KKEY", "debug" }, { "KKEY", "junk" },
	{ "KAINUIEMOJI", "scan" }, { "KAINUIEMOJI", "list" }, { "KAINUIEMOJI", "junk" }, { "KAINUIEMOJI", "" },
	{ "KUISPECPROBE", "" },
}

local function Call(...)
	for i = 1, select("#", ...) do
		local path = select(i, ...)
		local fn = _G
		for part in path:gmatch("[^%.]+") do fn = type(fn) == "table" and fn[part] or nil end
		if type(fn) == "function" then return fn end
	end
end

local OUR_POPUPS = { "KAINUIFOREVER_WOWHEAD", "KAINUIFOREVER_RECENT_ALLY_NOTE", "KAINUIFOREVER_APPLY_PRESET",
	"KAINUIFOREVER_APPLY_LAYOUT", "KAINUIFOREVER_IMPORT_RELOAD" }
local OUR_WINDOWS = { "KainUIForeverChatCopyPopup", "KainUIForeverLinkPopup", "KainUIForeverPatchNotesFrame",
	"KainUIForeverHelpFrame", "KainUIForeverOptionsFrame", "KainUIForeverEmojiPicker", "KTargeterGUIFrame",
	"KainUIForeverMinimapButtonBin" }

local function CloseOurs()
	for _, name in ipairs(OUR_POPUPS) do if StaticPopup_Hide then pcall(StaticPopup_Hide, name) end end
	for _, name in ipairs(OUR_WINDOWS) do
		local f = _G[name]
		if f and f.Hide then pcall(f.Hide, f) end
	end
	if GameTooltip then pcall(GameTooltip.Hide, GameTooltip) end
	if ItemRefTooltip then pcall(ItemRefTooltip.Hide, ItemRefTooltip) end
end

local HEARTHSTONE = 6948
local AUTO_ATTACK = 6603
local ITEM_LINK = "|cffffffff|Hitem:6948::::::::1:::::::::|h[Hearthstone]|h|r"

local CHAT_LINES = {
	"https://www.wowhead.com/classic/item=6948/hearthstone?a=1&b=2#top",
	"www.example.com and example.org/path and not.a.link",
	":smile: :heart: :not_an_emoji: :: ::: :smile:smile: :) ;) :D :P :/ :| :( :'( D: :O",
	"|cffff0000red|r |cff00ff00green|r unclosed |cff0000ff blue",
	ITEM_LINK .. " " .. ITEM_LINK .. " and |Hquest:176:10|h[Wanted: \"Hogger\"]|h",
	"|Hplayer:Nobody|h[Nobody]|h whispers: 100% %s %d %% %",
	"[1. General] [2. Trade] [Guild] [Party Leader] [Raid] [Instance]",
	"| || ||| |",
	"{skull} {cross} {rt8} {star}",
	"",
	" ",
	string.rep("long text ", 40),
	string.rep(":smile:", 30),
	"日本語 Ünïcödé Ελληνικά العربية",

	"|Hplayer:Bóbsson-Mañana|h[Bóbsson]|h: Ça va? Łukasz, Žofie, Ångström, ÆØÅ, Straße, ÿ",
	"https://www.example.com/bóbsson/" .. string.rep("é", 40),
	string.rep("Bóbsson ", 40),
}

local ACCENTED_NAMES = {
	"Bóbsson", "BÓBSSON", "Élise Dûrand", "Łukasz Żółć", "Šárka Ěřů", "Őrző's Fist", "ÅSA ÆØ", "Straße",
	"Ÿvonne", "Bob × 2",
}

local WHISPERS = {
	"K-UI stress test https://www.wowhead.com/item=6948 :smile: :)",
	"K-UI stress test {skull} [1] 100% %s done",
	"K-UI stress test " .. string.rep(":heart:", 12),
	"K-UI stress test Bóbsson Łukasz Ça va? Ångström",
}

local function OurNamedFrames()
	local list = {}
	for name, obj in pairs(_G) do
		if type(name) == "string" and type(obj) == "table"
			and (name:find("^KainUIForever") or name:find("^KTargeter") or name:find("^KKey"))
			and type(obj.GetObjectType) == "function" then
			list[#list + 1] = obj
		end
	end
	table.sort(list, function(a, b) return tostring(a:GetName()) < tostring(b:GetName()) end)
	return list
end

local function PanelWidgets()
	local boxes, sliders = {}, {}
	local root = _G.KainUIForeverOptionsFrame
	if not root then return boxes, sliders end
	local function Walk(frame, depth)
		if depth > 8 then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			local okT, kind = pcall(child.GetObjectType, child)
			if okT and kind == "CheckButton" then boxes[#boxes + 1] = child
			elseif okT and kind == "Slider" then sliders[#sliders + 1] = child end
			Walk(child, depth + 1)
		end
	end
	Walk(root, 0)
	return boxes, sliders
end

local function Add(steps, label, fn, delay) steps[#steps + 1] = { label = label, fn = fn, delay = delay } end
local function Phase(steps, text) steps[#steps + 1] = { phase = text } end

local function AddScans(steps)
	for _, cmd in ipairs(SCANS) do
		Add(steps, "/kui " .. cmd, function() SlashCmdList.KAINUIFOREVER(cmd) end)
	end
	for _, s in ipairs(OTHER_SLASH) do
		Add(steps, s[1] .. " " .. s[2], function()
			local fn = SlashCmdList[s[1]]
			if fn then fn(s[2]) end
		end)
	end
	Add(steps, "close windows", CloseOurs)
end

local function AddFlips(steps, toggles, tag)
	for _, t in ipairs(toggles) do
		Add(steps, tag .. " flip " .. t.key, function() SetToggle(t, not IsOn(t)) end)
		Add(steps, tag .. " flip back " .. t.key, function() SetToggle(t, not IsOn(t)) end)
	end
end

local function AddSetAll(steps, toggles, on)
	Add(steps, "everything " .. (on and "on" or "off"), function()
		for _, t in ipairs(toggles) do
			Try("everything " .. (on and "on" or "off") .. ": " .. t.key, SetToggle, t, on)
		end
	end, 1)
end

local function AddPanel(steps, inCombat)
	Add(steps, "open options", function()
		if not (_G.KainUIForeverOptionsFrame and _G.KainUIForeverOptionsFrame:IsShown()) then KUI:ToggleOptions() end
	end, 0.5)
	Add(steps, "options: click every box", function()
		local boxes, sliders = PanelWidgets()
		run.panelBoxes, run.panelSliders = boxes, sliders
	end)

	for i = 1, 100 do
		Add(steps, "options box " .. i, function()
			local box = run.panelBoxes and run.panelBoxes[i]
			if box and box:IsVisible() then box:Click(); box:Click() end
		end, 0.05)
	end
	if not inCombat then
		for i = 1, 6 do
			Add(steps, "options slider " .. i, function()
				local s = run.panelSliders and run.panelSliders[i]
				if not s then return end
				local value = s:GetValue()
				local lo, hi = s:GetMinMaxValues()
				s:SetValue(lo); s:SetValue(hi); s:SetValue(value)
			end, 0.05)
		end
	end
	Add(steps, "patch notes", function() KUI:TogglePatchNotes() end)
	Add(steps, "patch notes again", function() KUI:TogglePatchNotes() end)
	Add(steps, "help", function() KUI:ToggleHelp() end)
	Add(steps, "help again", function() KUI:ToggleHelp() end)
	Add(steps, "close options", function()
		if _G.KainUIForeverOptionsFrame and _G.KainUIForeverOptionsFrame:IsShown() then KUI:ToggleOptions() end
	end)
end

local function AddOurWindows(steps)
	Add(steps, "snapshot window", function() KUI:ShowSnapshot("") end)
	Add(steps, "snapshot page 2", function() KUI:ShowSnapshot("2") end)
	Add(steps, "copy chat window", function() KUI:ShowChatCopyPopup(DEFAULT_CHAT_FRAME) end)
	Add(steps, "link popup", function() KUI:ShowLinkPopup("https://www.example.com/test?a=1&b=2") end)
	Add(steps, "link popup, empty", function() KUI:ShowLinkPopup("") end)
	Add(steps, "emoji picker", function()
		local p = _G.KainUIForeverEmojiPicker
		if p then p:Show() end
	end)
	Add(steps, "button bin", function()
		local b = _G.KainUIForeverMinimapButtonBin
		if b then b:Show() end
	end)
	Add(steps, "close windows", CloseOurs)
end

local function DefaultAnchor()
	if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	else GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR") end
end

local function Tip(method, ...)
	if type(GameTooltip[method]) ~= "function" then return end
	DefaultAnchor()
	GameTooltip[method](GameTooltip, ...)
	GameTooltip:Show()
end

local function AddTooltips(steps, inCombat)
	Add(steps, "tooltip: you", function() Tip("SetUnit", "player") end)
	Add(steps, "tooltip: target", function() Tip("SetUnit", UnitExists("target") and "target" or "player") end)
	Add(steps, "tooltip: nobody", function() Tip("SetUnit", "none") end)
	for i = 1, inCombat and 0 or 3 do
		Add(steps, "tooltip: your buff " .. i, function()
			if GameTooltip.SetUnitBuff then Tip("SetUnitBuff", "player", i) else Tip("SetUnitAura", "player", i, "HELPFUL") end
		end)
	end
	if not inCombat then Add(steps, "tooltip: target debuff", function()
		local unit = UnitExists("target") and "target" or "player"
		if GameTooltip.SetUnitDebuff then Tip("SetUnitDebuff", unit, 1) else Tip("SetUnitAura", unit, 1, "HARMFUL") end
	end) end
	Add(steps, "tooltip: spell", function() Tip("SetSpellByID", AUTO_ATTACK) end)
	Add(steps, "tooltip: item", function()
		if GameTooltip.SetItemByID then Tip("SetItemByID", HEARTHSTONE) else Tip("SetHyperlink", "item:6948") end
	end)
	Add(steps, "Wowhead on the item", function() KUI:WowheadSearch() end)
	Add(steps, "close Wowhead", function() StaticPopup_Hide("KAINUIFOREVER_WOWHEAD") end)
	Add(steps, "tooltip: item link", function() Tip("SetHyperlink", "item:6948") end)
	Add(steps, "tooltip: spell link", function() Tip("SetHyperlink", "spell:6603") end)
	Add(steps, "tooltip: quest link", function() Tip("SetHyperlink", "quest:176:10") end)
	Add(steps, "tooltip: hide", function() GameTooltip:Hide() end)
	Add(steps, "Wowhead with nothing hovered", function() KUI:WowheadSearch() end)
	Add(steps, "close Wowhead", function() StaticPopup_Hide("KAINUIFOREVER_WOWHEAD") end)
	Add(steps, "clicked item link", function()
		if SetItemRef then SetItemRef("item:6948", ITEM_LINK, "LeftButton", DEFAULT_CHAT_FRAME) end
	end)
	Add(steps, "close item link", function() if ItemRefTooltip then ItemRefTooltip:Hide() end end)
	Add(steps, "hover a chat link", function()
		local f = DEFAULT_CHAT_FRAME
		local enter = f:GetScript("OnHyperlinkEnter")
		if enter then enter(f, "item:6948", ITEM_LINK) end
	end)
	Add(steps, "Wowhead on the chat link", function() KUI:WowheadSearch() end)
	Add(steps, "leave the chat link", function()
		local f = DEFAULT_CHAT_FRAME
		local leave = f:GetScript("OnHyperlinkLeave")
		if leave then leave(f, "item:6948", ITEM_LINK) end
		StaticPopup_Hide("KAINUIFOREVER_WOWHEAD")
		GameTooltip:Hide()
	end)
end

local function AddChat(steps, whispers)
	for i, line in ipairs(CHAT_LINES) do
		Add(steps, "chat line " .. i, function() DEFAULT_CHAT_FRAME:AddMessage(line) end, 0.05)
	end
	if whispers then
		for i, line in ipairs(WHISPERS) do
			Add(steps, "whisper yourself " .. i, function()
				local me = UnitName("player")
				local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
				if Plain(me) then send(line, "WHISPER", nil, me) end
			end, 0.6)
		end
	end
	Add(steps, "type in the chat box", function()
		local open = Call("ChatFrame_OpenChat", "ChatFrameUtil.OpenChat")
		if open then open(":smi", DEFAULT_CHAT_FRAME) end
	end, 0.3)
	Add(steps, "close the chat box", function()
		local active = Call("ChatEdit_GetActiveWindow", "ChatFrameUtil.GetActiveWindow")
		local eb = active and active()
		if not eb then return end
		eb:SetText("")
		local close = Call("ChatEdit_DeactivateChat", "ChatFrameUtil.DeactivateChat")
		if close then close(eb) else eb:ClearFocus() end
	end)
end

local function AddCopyCheck(steps)
	Add(steps, "copy chat: colours closed per line", function()
		KUI:ShowChatCopyPopup(DEFAULT_CHAT_FRAME)
		local popup = _G.KainUIForeverChatCopyPopup
		local box = popup and popup.editBox
		local text = box and box.GetText and box:GetText()
		if not Plain(text) or type(text) ~= "string" then return end
		for line in text:gmatch("[^\n]+") do
			local probe = line:gsub("||", "")
			local _, opened = probe:gsub("|c%x%x%x%x%x%x%x%x", "")
			local _, named = probe:gsub("|cn[^:|]*:", "")
			local _, closed = probe:gsub("|r", "")
			if opened + named > closed then
				Check("copy chat: a line leaves a colour open", false, line:gsub("|", "/"))
				break
			end
		end
	end)
	Add(steps, "close copy chat", CloseOurs)
end

local function AddHover(steps)
	Add(steps, "find our frames", function() run.frames = OurNamedFrames() end)
	for i = 1, 100 do
		Add(steps, "hover frame " .. i, function()
			local f = run.frames and run.frames[i]
			if not (f and f.IsVisible and f:IsVisible() and f.GetScript) then return end
			currentLabel = "hover " .. tostring(f:GetName())
			local enter = f:HasScript("OnEnter") and f:GetScript("OnEnter")
			if enter then enter(f) end
			local leave = f:HasScript("OnLeave") and f:GetScript("OnLeave")
			if leave then leave(f) end
		end, 0.03)
	end
	Add(steps, "xp bar tooltip", function()
		local bar = _G.KainUIForeverXPBar
		if bar and bar:IsVisible() and bar:GetScript("OnEnter") then bar:GetScript("OnEnter")(bar) end
	end)
	Add(steps, "xp bar tooltip off", function()
		local bar = _G.KainUIForeverXPBar
		if bar and bar:GetScript("OnLeave") then bar:GetScript("OnLeave")(bar) end
		GameTooltip:Hide()
	end)
end

local function AddRandom(steps, toggles, count)
	for i = 1, count do
		Add(steps, "random flip " .. i, function()
			local t = toggles[math.random(#toggles)]
			currentLabel = "random flip " .. t.key
			SetToggle(t, not IsOn(t))
		end, 0)
	end
end

local function AddAccents(steps)
	Add(steps, "accents: Wowhead search text", function()
		for _, name in ipairs(ACCENTED_NAMES) do
			local q = KUI:WowheadQuery(name)
			local letters = q and q:gsub("%%%x%x", "")
			Check("Wowhead text for " .. name, q and not q:find("[\128-\255]") and letters == letters:lower(), tostring(q))
		end
		Check("Wowhead: capitals and small letters give the same search", KUI:WowheadQuery("BÓBSSON") == KUI:WowheadQuery("bóbsson"))
	end)
	Add(steps, "accents: cutting text to length", function()
		for _, name in ipairs(ACCENTED_NAMES) do
			for n = 1, #name do
				local cut = KUI.CutText(name, n)
				if not ValidUTF8(cut) or #cut > n then
					Check("cut " .. name .. " to " .. n .. " bytes", false, cut)
					return
				end
			end
		end
	end)
	Add(steps, "accents: small letters", function()
		Check("lowercase of accented capitals", KUI.LowerText("BÓBSSON ŁUKASZ ŻÓŁĆ ŠÁRKA ĚŘŮ ŐRZŐ ÅSA ÆØ Ÿ ×") == "bóbsson łukasz żółć šárka ěřů őrző åsa æø ÿ ×",
			KUI.LowerText("BÓBSSON ŁUKASZ ŻÓŁĆ ŠÁRKA ĚŘŮ ŐRZŐ ÅSA ÆØ Ÿ ×"))
	end)
	Add(steps, "accents: hover a player link", function()
		local f = DEFAULT_CHAT_FRAME
		local enter = f:GetScript("OnHyperlinkEnter")
		if enter then enter(f, "player:Bóbsson-Mañana", "|Hplayer:Bóbsson-Mañana|h[Bóbsson]|h") end
	end)
	Add(steps, "accents: leave the player link", function()
		local f = DEFAULT_CHAT_FRAME
		local leave = f:GetScript("OnHyperlinkLeave")
		if leave then leave(f, "player:Bóbsson-Mañana", "|Hplayer:Bóbsson-Mañana|h[Bóbsson]|h") end
		GameTooltip:Hide()
	end)
	Add(steps, "accents: error log text", function()
		local log = KUI.GetErrorLog and KUI:GetErrorLog() or {}
		for _, e in ipairs(log) do
			Check("error log message is whole characters", ValidUTF8(e.m), tostring(e.m))
			for _, line in ipairs(type(e.s) == "table" and e.s or {}) do
				Check("error log stack line is whole characters", ValidUTF8(line), line)
			end
		end
	end)
end

local function LiveSteps(toggles)
	local steps = {}
	Phase(steps, "running every scan and slash command")
	AddScans(steps)
	Phase(steps, "accented names")
	AddAccents(steps)
	Phase(steps, "flipping every option from your settings")
	AddFlips(steps, toggles, "yours")
	Phase(steps, "everything on")
	AddSetAll(steps, toggles, true)
	AddPanel(steps)
	AddOurWindows(steps)
	AddTooltips(steps)
	AddChat(steps, true)
	AddCopyCheck(steps)
	AddHover(steps)
	AddFlips(steps, toggles, "all on")
	Phase(steps, "everything off")
	AddSetAll(steps, toggles, false)
	AddTooltips(steps)
	AddChat(steps, false)
	AddHover(steps)
	Phase(steps, "Kain's preset")
	Add(steps, "Kain's preset", function() KUI:ApplyKainPreset() end, 1)
	Add(steps, "ApplyAll", function() KUI:ApplyAll() end, 0.5)
	Add(steps, "ApplyAll again", function() KUI:ApplyAll() end, 1.5)
	AddOurWindows(steps)
	AddTooltips(steps)
	Phase(steps, "rapid random changes")
	AddRandom(steps, toggles, 60)
	Add(steps, "settle", function() end, 1)
	Phase(steps, "hiding and showing the whole interface")
	Add(steps, "hide the interface", function() UIParent:Hide() end, 0.5)
	Add(steps, "show the interface", function() UIParent:Show() end, 0.5)
	return steps
end

local function CombatSteps(toggles)
	local steps = {}
	Phase(steps, "in combat: scans")
	AddScans(steps)
	Phase(steps, "in combat: accented names")
	AddAccents(steps)
	Phase(steps, "in combat: tooltips, chat, hovering")
	AddTooltips(steps, true)
	AddChat(steps, false)
	AddCopyCheck(steps)
	AddHover(steps)
	Phase(steps, "in combat: options panel and windows of ours")
	AddPanel(steps, true)
	AddOurWindows(steps)
	Phase(steps, "in combat: flipping every option")
	AddFlips(steps, toggles, "combat")
	return steps
end

local function ReadCVar(name)
	local ok, v = pcall(GetCVar, name)
	if ok and Plain(v) then return v end
end

local function RestoreSettings(backup, cvars)
	if not (KUI.db and backup) then return end

	for _, t in ipairs(AllToggles()) do
		local want = IsOn(t, backup)
		if IsOn(t) ~= want then Try("restore " .. t.key, SetToggle, t, want) end
	end

	PutBack(backup)
	if cvars then
		for name, value in pairs(cvars) do pcall(SetCVar, name, value) end
	end
	Try("restore: ApplyAll", function() KUI:ApplyAll() end)
end

StaticPopupDialogs["KAINUIFOREVER_STRESS_RELOAD"] = {
	text = "%s",
	button1 = RELOADUI or "Reload",
	button2 = "Later",
	OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["KAINUIFOREVER_STRESS_ROUND"] = {
	text = "%s",
	button1 = RELOADUI or "Reload",
	button2 = "Stop test",
	OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end,
	OnCancel = function(_, _, reason)
		if reason == "clicked" then KUI:StressTest("stop") end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = false,
	preferredIndex = 3,
}

local function Short(text, n)
	text = tostring(text):gsub("\n", " ")
	if #text > n then text = KUI.CutText(text, n - 3) .. "..." end
	return text
end

local function Report(allErrors, extra)
	extra = extra or {}
	local newErrors, testErrors = {}, {}
	for _, e in ipairs(allErrors) do
		if e.test then testErrors[#testErrors + 1] = e else newErrors[#newErrors + 1] = e end
	end
	local total = 0
	for _, e in ipairs(newErrors) do total = total + e.n end
	if total == 0 then
		Say("|cff00ff00no new errors from this addon.|r")
	else
		Say(string.format("|cffff6060%d error%s from this addon (%d different):|r", total, total == 1 and "" or "s", #newErrors))
		for i = 1, math.min(#newErrors, 8) do
			Say(string.format("  x%d %s", newErrors[i].n, Short(newErrors[i].m, 160)))
		end
	end
	if #testErrors > 0 then
		Say(#testErrors .. " error(s) in the game's own code were set off by the test itself (no player could cause them; /kui clearerrors removes them from the snapshot):")
		for i = 1, math.min(#testErrors, 4) do
			Say(string.format("  x%d %s", testErrors[i].n, Short(testErrors[i].m, 140)))
		end
	end
	if extra.ourThrows and #extra.ourThrows > 0 then
		Say(#extra.ourThrows .. " step(s) failed in our code:")
		for i = 1, math.min(#extra.ourThrows, 6) do Say("  " .. Short(extra.ourThrows[i], 160)) end
	end
	if extra.checksFailed and #extra.checksFailed > 0 then
		Say("|cffff6060" .. #extra.checksFailed .. " check(s) failed:|r")
		for i = 1, math.min(#extra.checksFailed, 6) do Say("  " .. Short(extra.checksFailed[i], 160)) end
	end
	if extra.gameThrows and #extra.gameThrows > 0 then
		Say(#extra.gameThrows .. " step(s) were refused by the game (usually a window or API this client doesn't have):")
		for i = 1, math.min(#extra.gameThrows, 4) do Say("  " .. Short(extra.gameThrows[i], 140)) end
	end
	if extra.suspicious and #extra.suspicious > 0 then
		Say("chat lines that mention a failure:")
		for _, line in ipairs(extra.suspicious) do Say("  " .. Short(line, 160)) end
	end
	Say("full details: |cffffff00/kui snapshot|r.")
end

local function Finish(reason)
	local r = run
	if not r then return end
	r.stopped = true
	if r.restoreTimer then return end
	if InCombat() then
		Say((reason and (reason .. "; ") or "") .. "settings go back once you're out of combat.")
		r.waitForCombatEnd = true
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	r.restoreTimer = true
	pcall(UIParent.Show, UIParent)
	CloseOurs()
	RestoreSettings(r.backup, r.cvars)
	AccountDB().stressLive = nil
	Unmute()
	local seconds = (GetTime() - r.started)
	Say(string.format("%s %d of %d steps in %.0f s. %d chat lines swallowed. Your settings are back.",
		reason or "finished:", r.done, r.total, seconds, r.printed))
	Report(NewErrors(r.before, ErrorTotals()), r)
	if r.mode == "live" then
		Say("not covered (try by hand): the game's own windows (Character, Spellbook, Talents, Map, Quest Log, bags, Social, professions, Macros), vendors, looting and loot rolls, quests and gossip (K-Key), levelling up, groups and dungeons. |cffffff00/kui stresstest combat|r covers combat.")
	elseif r.mode == "combat" then
		Say("by hand, in a fight: hover your buffs and your target's debuffs (Cast By) -- the game won't let the test show aura tooltips in combat.")
	end
	run = nil
	StaticPopup_Show("KAINUIFOREVER_STRESS_RELOAD", "Stress test finished. Reload now to start from a clean slate?")
end

local function Tick()
	local r = run
	if not r or r.stopped or r.mode == "armed" then return end
	local step = r.steps[r.i]
	if not step then return Finish() end
	r.i = r.i + 1
	if step.phase then
		Say(step.phase .. " ...")
		return C_Timer.After(0, Tick)
	end
	if r.mode == "combat" and not InCombat() then

		r.i = r.i - 1
		r.paused = true
		Unmute()
		Say(string.format("the fight ended at step %d of %d. Pull another mob to carry on, or |cffffff00/kui stresstest stop|r.", r.done, r.total))
		return
	end
	Try(step.label, step.fn)
	r.done = r.done + 1
	local delay = step.delay or STEP_DELAY
	if r.mode == "combat" then delay = math.min(step.delay or COMBAT_DELAY, 0.2) end
	C_Timer.After(delay, Tick)
end

local function Begin(mode, steps)
	local cvars = {}
	for _, name in ipairs({ "cameraDistanceMaxZoomFactor", "weatherDensity" }) do cvars[name] = ReadCVar(name) end
	run = {
		mode = mode, steps = steps, i = 1, done = 0, total = 0, printed = 0,
		backup = DeepCopy(KUI.db), cvars = cvars, before = ErrorTotals(),
		ourThrows = {}, gameThrows = {}, suspicious = {}, suspiciousSeen = {}, checksFailed = {},
		started = GetTime(),
	}
	for _, s in ipairs(steps) do if not s.phase then run.total = run.total + 1 end end

	AccountDB().stressLive = { who = Who(), backup = run.backup, cvars = cvars }
	if mode ~= "armed" then Mute() end
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	Tick()
end

local function Randomize()
	local db = KUI.db
	for _, t in ipairs(AllToggles()) do
		if not t.cvars then
			local on = math.random(2) == 1
			if t.raw then t.raw(db, on)
			elseif t.value then db[t.key] = t.value(on)
			else db[t.key] = on end
		end
	end
end

local function ReloadRound()
	local state = AccountDB().stressReload
	if not (state and state.who == Who()) then return end
	state.left = state.left - 1
	if state.left > 0 then
		Randomize()
		local round = state.total - state.left + 1
		Say(string.format("reload round %d of %d: settings randomised.", round, state.total))
		StaticPopup_Show("KAINUIFOREVER_STRESS_ROUND",
			string.format("K-UI stress test: round %d of %d.\n\nSettings have been randomised. Reload to load the addon with them.", round, state.total))
		return
	end
	PutBack(state.backup)
	AccountDB().stressReload = nil
	Say(string.format("reload test finished after %d rounds. Your settings are back once you reload.", state.total))
	Report(NewErrors(state.before or {}, ErrorTotals()))
	StaticPopup_Show("KAINUIFOREVER_STRESS_RELOAD", "Stress test finished. Reload now to put your settings back?")
end

local function RecoverLive()
	local live = AccountDB().stressLive
	if not (live and live.who == Who() and KUI.db) then return end
	AccountDB().stressLive = nil
	PutBack(live.backup)
	if live.cvars then for name, value in pairs(live.cvars) do pcall(SetCVar, name, value) end end
	Say("the last stress test was interrupted by a reload; your settings are back once you reload.")
	StaticPopup_Show("KAINUIFOREVER_STRESS_RELOAD", "The last K-UI stress test was cut short. Reload now to put your settings back?")
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then

		C_Timer.After(4, function()
			Try("recover", RecoverLive)
			Try("reload round", ReloadRound)
		end)
	elseif event == "PLAYER_REGEN_DISABLED" then
		if run and run.mode == "live" and not run.stopped then
			Finish("stopped: you entered combat.")
		elseif run and run.mode == "armed" then
			run.mode = "combat"
			run.started = GetTime()
			Say("combat! running " .. run.total .. " steps (about 20 s of fighting).")
			Mute()
			Tick()
		elseif run and run.mode == "combat" and run.paused then
			run.paused = nil
			Say(string.format("combat again: carrying on from step %d of %d.", run.done + 1, run.total))
			Mute()
			Tick()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if run and run.waitForCombatEnd then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			run.waitForCombatEnd = nil
			Finish()
		end
	end
end)

function KUI:StressTest(arg)
	local cmd, rest = (arg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if not self.db then
		Say("settings aren't loaded yet; try again in a moment.")
		return
	end

	if cmd == "stop" then
		if run then
			Finish("stopped:")
		elseif AccountDB().stressReload then
			AccountDB().stressReload.left = 1
			Try("reload round", ReloadRound)
		else
			Say("nothing is running.")
		end
		return
	end

	if run or AccountDB().stressReload then
		Say("a test is already running. |cffffff00/kui stresstest stop|r ends it.")
		return
	end

	if cmd == "reload" then
		if InCombat() then Say("not during combat.") return end
		local rounds = math.max(1, math.min(10, tonumber(rest) or 3))
		AccountDB().stressReload = { who = Who(), total = rounds, left = rounds + 1,
			backup = DeepCopy(self.db), before = ErrorTotals() }
		Try("reload round", ReloadRound)
		return
	end

	local toggles = AllToggles()
	if cmd == "combat" then
		if InCombat() then Say("start it out of combat, then pull something.") return end
		Begin("armed", CombatSteps(toggles))

		Say("armed: pull any mob -- a low-level one is best, it keeps you in combat without much danger (stop attacking and let it hit you to make the fight last). If the fight ends first, the test pauses and carries on at the next pull. Settings go back afterwards.")
		return
	end

	if cmd ~= "" then
		Say("usage: /kui stresstest, /kui stresstest combat, /kui stresstest reload [rounds], /kui stresstest stop.")
		return
	end
	if InCombat() then Say("not during combat; try |cffffff00/kui stresstest combat|r instead.") return end
	Say("starting: about " .. math.floor(#LiveSteps(toggles) * STEP_DELAY / 10 + 0.5) * 10 .. " s. Don't move your mouse over the UI meanwhile; |cffffff00/kui stresstest stop|r ends it early.")
	Begin("live", LiveSteps(toggles))
end
