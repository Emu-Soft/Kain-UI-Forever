local addonName, KUI = ...

KUI.defaults = {
	minimapUnclamped = false,
	minimapDetached = false,
	anchorsLocked = false,
	headerBarUnlocked = false,
	chatEnhanced = false,
	hiddenBagSlots = {},
	hideBagBarBorderArt = false,
	hideBagBarDividers = false,
	hiddenMicroButtons = {},
	microMenuHidden = false,
	globalDragging = false,
	xpBarUnderPortrait = false,
	xpBarHideDefault = false,
	framePositions = {},
	autoSellGreys = false,
	autoRepair = false,
	autoRepairUseGuildFunds = false,
	fastLoot = false,
	installedStarterMacros = {},
	weaponSwap = {},
	contrastEnabled = false,
	tooltipAnchorMode = "default",
	tooltipAnchorLocked = true,
	tooltipAnchorPos = { point = "BOTTOMRIGHT", x = -20, y = 250 },
	lootRollDragging = false,
	lootRollAnchorLocked = true,
	lootRollOffset = { x = 0, y = 0 },
	hiddenUtilityIcons = {},
	convertImperialToMetric = false,
	followRXPObjectives = false,
	lfgShowZone = true,
	levelUpScreenshot = false,
}

KUI.KAIN_PRESET = {
	minimapUnclamped = true,
	minimapDetached = true,

	minimapPositions = {
		minimap = { from = "TOPRIGHT", dx = -204.8, dy = -25.8 },
		minimapcluster = { from = "TOP", dx = -150.7, dy = 271.7 },
		zonebar = { from = "TOPRIGHT", dx = -105.8, dy = -1.7 },

		guilddifficulty = { from = "TOPRIGHT", dx = -33.8, dy = 0 },

		guilddifficultysquare = { from = "TOPRIGHT", dx = -202.1, dy = -28.3 },
	},
	chatEnhanced = true,
	hiddenBagSlots = { keyring = true },
	hideBagBarChrome = true,
	autoSellGreys = true,
	autoRepair = true,
	autoRepairUseGuildFunds = false,
	convertImperialToMetric = true,
	followRXPObjectives = true,
	lfgShowZone = true,
	microMenuHidden = false,
	hiddenMicroButtons = {
		character = true, profession = true, spellbook = true, talent = true,
		legacy = true, questlog = true, guild = true, lfd = true,
		collections = true, store = true,
	},
	contrastEnabled = true,
	cameraMaxZoomFactor = 2.0,
	fastLoot = true,
	lootRollDragging = true,
	lootRollAnchorLocked = true,
	globalDragging = true,
	xpBarUnderPortrait = true,
	xpBarHideDefault = true,

	minimapElementsUnlocked = false,
	platerStyle = true,
	tooltipAnchorMode = "growRight",
	tooltipAnchorLocked = true,

	tooltipAnchorPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 289.2, y = 1.7 },
	snapToElements = true,

	mailIconScreenPos = { left = 2106, top = 995.2 },

	squareMinimap = true,
	emojiChat = true,
	lootRollTarget = { left = 927.3, top = 343.5 },
	dielPos = { x = 2.8, y = 0 },

	emojiButtonOffset = { x = 0, y = 6 },

	socialButtonPos = { x = 0, y = 219 },
	socialButtonUnlocked = false,
}

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			CopyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function KUI:SafeRegisterEvent(frame, eventName)
	local ok = pcall(function()
		frame:RegisterEvent(eventName)
	end)
	if not ok then
		print("|cffff6060Kain-UI Forever:|r couldn't register event '" .. eventName .. "' on this client build -- that feature's update source is unavailable, but the rest of the addon is unaffected.")
	end
	return ok
end

local TABLE_FIELDS = {
	"framePositions", "tooltipAnchorPos", "mailIconPos", "emojiButtonOffset", "dielPos", "contrastSavedValues",
	"weaponSwap", "lootRollScreenBase", "lootRollRawBase", "lootRollOffset", "lootRollTarget", "hiddenMicroButtons",
	"hiddenBagSlots", "castByCache", "mailIconScreenPos", "xpSession", "socialButtonPos",
}
local NUMERIC_FIELDS = {
	lootRollOffset = { "x", "y" }, emojiButtonOffset = { "x", "y" }, dielPos = { "x", "y" }, mailIconPos = { "x", "y" },
	lootRollTarget = { "left", "top" }, lootRollScreenBase = { "left", "top" }, mailIconScreenPos = { "left", "top" },
	xpSession = { "start", "gained" }, socialButtonPos = { "x", "y" },
}

function KUI:SanitizeSavedSettings(db, defaults)
	local dropped = 0
	for k, default in pairs(defaults) do
		if db[k] ~= nil and type(db[k]) ~= type(default) then db[k] = nil; dropped = dropped + 1 end
	end
	for _, k in ipairs(TABLE_FIELDS) do
		if db[k] ~= nil and type(db[k]) ~= "table" then db[k] = nil; dropped = dropped + 1 end
	end

	if type(db.framePositions) == "table" then
		for key, pos in pairs(db.framePositions) do
			local okPos = type(pos) == "table" and type(pos.y) == "number"
				and (type(pos.x) == "number" or type(pos.cx) == "number" or type(pos.dx) == "number")
			if not okPos then db.framePositions[key] = nil; dropped = dropped + 1 end
		end
	end
	if type(db.castByCache) == "table" then
		for guid, entries in pairs(db.castByCache) do
			if type(guid) ~= "string" or type(entries) ~= "table" then
				db.castByCache[guid] = nil; dropped = dropped + 1
			else
				for key, e in pairs(entries) do
					if type(e) ~= "table" or type(e.n) ~= "string" or type(e.e) ~= "number" then entries[key] = nil end
				end
			end
		end
	end
	for k, keys in pairs(NUMERIC_FIELDS) do
		local t = db[k]
		if type(t) == "table" then
			for _, key in ipairs(keys) do
				if type(t[key]) ~= "number" then db[k] = nil; dropped = dropped + 1; break end
			end
		end
	end
	return dropped
end

local eventFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(eventFrame, "ADDON_LOADED")
KUI:SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event == "ADDON_LOADED" then
		if loadedAddonName ~= addonName then return end
		if type(KainUIForeverDB) ~= "table" then KainUIForeverDB = {} end
		local dropped = KUI:SanitizeSavedSettings(KainUIForeverDB, KUI.defaults)
		if dropped > 0 then
			print("|cffff6060Kain-UI Forever:|r " .. dropped .. " damaged saved setting(s) were reset to their defaults.")
		end
		CopyDefaults(KainUIForeverDB, KUI.defaults)
		KUI.db = KainUIForeverDB
	elseif event == "PLAYER_LOGIN" then
		print("|cff33ff99Kain-UI Forever|r loaded. Type /kainui to open settings.")
		if KUI.ApplyAll then
			KUI:ApplyAll()
		end
	end
end)

local LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local LFG_ZONE_MAX_WIDTH = 180
local LFG_ZONE_GAP = 3
local LFG_ZONE_ROW_HEIGHT = 15

local lfgZoneParts = setmetatable({}, { __mode = "k" })
local lfgZoneHooked = false

local function GetLFGScrollBox()
	return _G.LFGBrowseFrameScrollBox or (_G.LFGBrowseFrame and _G.LFGBrowseFrame.ScrollBox)
end

local function GetLFGZoneParts(row)
	local parts = lfgZoneParts[row]
	if parts then return parts end
	local activity = row.ActivityName
	if not activity then return nil end

	local sep = row:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	sep:SetText("-")
	sep:SetWordWrap(false)
	sep:SetPoint("BOTTOMLEFT", activity, "BOTTOMRIGHT", LFG_ZONE_GAP, 0)

	local zone = row:CreateFontString(nil, "ARTWORK", "GameFontDisableLeft")
	zone:SetSize(LFG_ZONE_MAX_WIDTH, LFG_ZONE_ROW_HEIGHT)
	zone:SetWordWrap(false)
	zone:SetJustifyH("LEFT")

	parts = { sep = sep, zone = zone }
	lfgZoneParts[row] = parts
	return parts
end

local function HideLFGZone(row)
	local parts = lfgZoneParts[row]
	if parts then
		parts.sep:Hide()
		parts.zone:Hide()
	end
end

local function LFGRowResultID(row, elementData)
	local data = elementData
	if type(data) == "table" and type(data.GetData) == "function" then
		data = data:GetData()
	end
	if type(data) == "table" then data = data.resultID end
	if type(data) == "number" then return data end
	if type(row.resultID) == "number" then return row.resultID end
	return nil
end

local function UpdateLFGZone(row, elementData)
	if not row or not row.ActivityName then return end
	if not (KUI.db and KUI.db.lfgShowZone ~= false) or not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		HideLFGZone(row)
		return
	end

	local resultID = LFGRowResultID(row, elementData)
	local info = resultID and C_LFGList.GetSearchResultPlayerInfo(resultID, 1)
	local areaName = info and info.areaName

	if not areaName then
		HideLFGZone(row)
		return
	end
	if canaccessvalue(areaName) and areaName == "" then
		HideLFGZone(row)
		return
	end

	local parts = GetLFGZoneParts(row)
	if not parts then return end

	local activityText = row.ActivityName:GetText()
	local hasActivity = not (canaccessvalue(activityText) and (activityText == nil or activityText == ""))

	parts.zone:ClearAllPoints()
	if hasActivity then
		parts.zone:SetPoint("BOTTOMLEFT", parts.sep, "BOTTOMRIGHT", LFG_ZONE_GAP, 0)
	else
		parts.zone:SetPoint("BOTTOMLEFT", row.ActivityName, "BOTTOMLEFT", 0, 0)
	end

	local r, g, b = row.ActivityName:GetTextColor()
	if r then
		parts.sep:SetTextColor(r, g, b)
		parts.zone:SetTextColor(r, g, b)
	end

	parts.zone:SetText(areaName)
	parts.sep:SetShown(hasActivity)
	parts.zone:Show()
end

local function OnLFGRowAcquired(_, row, elementData)
	HideLFGZone(row)
	C_Timer.After(0, function() UpdateLFGZone(row, elementData) end)
end

local function HookLFGBrowseList()
	if lfgZoneHooked then return end
	local scrollBox = GetLFGScrollBox()
	if not scrollBox then
		print("|cffff6060Kain-UI Forever:|r couldn't find the Group Finder list (LFGBrowseFrameScrollBox) -- zone text won't show.")
		return
	end
	if not (ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then
		print("|cffff6060Kain-UI Forever:|r ScrollUtil.AddAcquiredFrameCallback isn't available on this client build -- Group Finder zone text won't show.")
		return
	end
	lfgZoneHooked = true
	ScrollUtil.AddAcquiredFrameCallback(scrollBox, OnLFGRowAcquired, KUI, true)
end

local function RefreshLFGZones()
	local scrollBox = GetLFGScrollBox()
	if scrollBox and scrollBox.ForEachFrame then
		scrollBox:ForEachFrame(function(row)
			UpdateLFGZone(row, type(row.GetElementData) == "function" and row:GetElementData() or nil)
		end)
	end
end

function KUI:SetLFGZoneShown(enabled)
	if not KUI.db then return end
	KUI.db.lfgShowZone = enabled and true or false
	RefreshLFGZones()
end

local function LFGScanValue(v)
	if not canaccessvalue(v) then return "|cffff9900<secret>|r" end
	if type(v) ~= "table" then return tostring(v) end
	local parts, n = {}, 0
	for k, x in pairs(v) do
		n = n + 1
		if n > 8 then parts[#parts + 1] = "..."; break end
		parts[#parts + 1] = tostring(k) .. "=" .. (canaccessvalue(x) and type(x) ~= "table" and tostring(x) or (type(x) == "table" and "{...}" or "<secret>"))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function LFGScanDump(label, value)
	if type(value) ~= "table" then
		print("  " .. label .. ": " .. tostring(value))
		return
	end
	print("  |cffffff00" .. label .. "|r")
	local keys = {}
	for k in pairs(value) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = value[k]
		print(string.format("    %s = %s  (%s)", tostring(k), LFGScanValue(v), canaccessvalue(v) and type(v) or "secret"))
	end
end

function KUI:LFGFieldScanReport()
	print("|cff33ff99Kain-UI Forever|r Group Finder field scan:")

	local globals = {
		{ "GetCurrentRegion", GetCurrentRegion },
		{ "GetCurrentRegionName", GetCurrentRegionName },
		{ "RegionalUniqueNamesEnabled", RegionalUniqueNamesEnabled },
		{ "GetRealmName", GetRealmName },
		{ "GetNormalizedRealmName", GetNormalizedRealmName },
	}
	for _, entry in ipairs(globals) do
		local ok, result = false, nil
		if type(entry[2]) == "function" then ok, result = pcall(entry[2]) end
		print("  " .. entry[1] .. "(): " .. (ok and tostring(result) or "not available"))
	end
	if type(GetNetStats) == "function" then
		local _, _, home, world = GetNetStats()
		print("  your own latency (GetNetStats): home " .. tostring(home) .. " ms, world " .. tostring(world) .. " ms")
	end

	if not (C_LFGList and C_LFGList.GetSearchResultInfo) then
		print("  C_LFGList.GetSearchResultInfo isn't available on this client.")
		return
	end

	local ids = {}
	local scrollBox = GetLFGScrollBox()
	if scrollBox and scrollBox.ForEachFrame then
		scrollBox:ForEachFrame(function(row)
			if #ids < 2 then
				local id = LFGRowResultID(row, type(row.GetElementData) == "function" and row:GetElementData() or nil)
				if id then ids[#ids + 1] = id end
			end
		end)
	end
	if #ids == 0 and C_LFGList.GetSearchResults then
		local _, results = C_LFGList.GetSearchResults()
		for i = 1, math.min(2, results and #results or 0) do ids[#ids + 1] = results[i] end
	end
	if #ids == 0 then
		print("  no results to scan -- open the Group Finder list and run a search first.")
		return
	end

	for _, id in ipairs(ids) do
		print("|cff33ff99--- result " .. id .. " ---|r")
		local ok, err = pcall(function()
			LFGScanDump("GetSearchResultInfo", C_LFGList.GetSearchResultInfo(id))
			if C_LFGList.GetSearchResultLeaderInfo then
				LFGScanDump("GetSearchResultLeaderInfo", C_LFGList.GetSearchResultLeaderInfo(id))
			end
			if C_LFGList.GetSearchResultPlayerInfo then
				LFGScanDump("GetSearchResultPlayerInfo(id, 1)", C_LFGList.GetSearchResultPlayerInfo(id, 1))
			end
		end)
		if not ok then print("  scan failed: " .. tostring(err)) end
	end
end

local lfgZoneEvents = CreateFrame("Frame")
KUI:SafeRegisterEvent(lfgZoneEvents, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
KUI:SafeRegisterEvent(lfgZoneEvents, "LFG_LIST_SEARCH_RESULT_UPDATED")
lfgZoneEvents:SetScript("OnEvent", function()
	if lfgZoneHooked then C_Timer.After(0, RefreshLFGZones) end
end)

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded(LFG_ADDON, HookLFGBrowseList)
end

local function FindOwnText(frame)
	if frame.GetText then
		local ok, text = pcall(frame.GetText, frame)
		if ok and text and text ~= "" then return text end
	end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText then
				local ok, text = pcall(region.GetText, region)
				if ok and text and text ~= "" then return text end
			end
		end
	end
	return nil
end

function KUI:DumpFrameChildren(frameName)
	if not frameName or frameName == "" then
		print("|cffff6060Kain-UI Forever:|r usage: /kainui dumpframe <FrameName> (e.g. /kainui dumpframe MinimapCluster, or a dotted path through named parentKeys like /kainui dumpframe EditModeManagerFrame.AccountSettings.SettingsContainer)")
		return
	end

	local segments = {}
	for segment in frameName:gmatch("[^%.]+") do
		table.insert(segments, segment)
	end

	local frame = _G[segments[1]]
	if not frame then
		print("|cffff6060Kain-UI Forever:|r no global frame named '" .. segments[1] .. "' found.")
		return
	end
	local walkedPath = segments[1]
	for i = 2, #segments do
		if type(frame) ~= "table" and type(frame) ~= "userdata" then
			print("|cffff6060Kain-UI Forever:|r '" .. walkedPath .. "' isn't a table/frame -- can't continue to '" .. segments[i] .. "'.")
			return
		end
		local nextFrame = frame[segments[i]]
		if nextFrame == nil then
			print("|cffff6060Kain-UI Forever:|r '" .. walkedPath .. "' has no field '" .. segments[i] .. "'.")
			return
		end
		frame = nextFrame
		walkedPath = walkedPath .. "." .. segments[i]
	end

	if not frame.GetChildren then
		print("|cffff6060Kain-UI Forever:|r '" .. frameName .. "' exists but doesn't look like a frame (no GetChildren method).")
		return
	end

	local keyByChild = {}
	pcall(function()
		for k, v in pairs(frame) do
			if type(v) == "table" or type(v) == "userdata" then
				keyByChild[v] = k
			end
		end
	end)

	print("|cff33ff99Kain-UI Forever|r children of " .. frameName .. ":")
	local children = { frame:GetChildren() }
	if #children == 0 then
		print("  (no child frames)")
	end
	for i, child in ipairs(children) do
		local name = child.GetName and child:GetName()
		local objType = (child.GetObjectType and child:GetObjectType()) or "?"
		local shown = child.IsShown and child:IsShown()
		local key = keyByChild[child]
		local label = name or "<unnamed>"
		local keyNote = key and (" (childKey: " .. tostring(key) .. ")") or ""
		local hiddenNote = (shown == false) and " -- hidden" or ""
		local ownText = FindOwnText(child)
		local textNote = ownText and (" text: \"" .. ownText .. "\"") or ""
		print(string.format("  [%d] %s%s (%s)%s%s", i, label, keyNote, objType, hiddenNote, textNote))
	end

	if frame.GetRegions then
		local regions = { frame:GetRegions() }
		if #regions > 0 then
			print("|cff33ff99Kain-UI Forever|r regions (text/textures, not frames) of " .. frameName .. ":")
			for i, region in ipairs(regions) do
				local name = region.GetName and region:GetName()
				local objType = (region.GetObjectType and region:GetObjectType()) or "?"
				local key = keyByChild[region]
				local keyNote = key and (" (childKey: " .. tostring(key) .. ")") or ""
				print(string.format("  [%d] %s%s (%s)", i, name or "<unnamed>", keyNote, objType))
			end
		end
	end
end

SLASH_KAINUIRELOAD1 = "/rl"
SlashCmdList["KAINUIRELOAD"] = function()
	if type(ReloadUI) == "function" then
		ReloadUI()
	elseif C_UI and C_UI.Reload then
		C_UI.Reload()
	end
end

local LEVEL_SHOT_DELAY = 1.0
local LEVEL_SHOT_COOLDOWN = 5
local lastLevelShot = 0
local levelShotStats = { taken = 0, failed = 0 }

local function TakeLevelUpScreenshot()
	if type(Screenshot) ~= "function" then
		levelShotStats.failed = levelShotStats.failed + 1
		return
	end
	local ok = pcall(Screenshot)
	if ok then
		levelShotStats.taken = levelShotStats.taken + 1
	else
		levelShotStats.failed = levelShotStats.failed + 1
	end
end

local levelShotFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(levelShotFrame, "PLAYER_LEVEL_UP")
levelShotFrame:SetScript("OnEvent", function()
	if not (KUI.db and KUI.db.levelUpScreenshot) then return end
	local now = GetTime()
	if now - lastLevelShot < LEVEL_SHOT_COOLDOWN then return end
	lastLevelShot = now
	C_Timer.After(LEVEL_SHOT_DELAY, TakeLevelUpScreenshot)
end)

function KUI:SetLevelUpScreenshot(enabled)
	if KUI.db then KUI.db.levelUpScreenshot = enabled and true or false end
end

function KUI:LevelShotScanReport()
	print(string.format("|cff33ff99Kain-UI Forever|r screenshot on level up: %s | this session: %d taken, %d failed",
		(KUI.db and KUI.db.levelUpScreenshot) and "ON" or "off", levelShotStats.taken, levelShotStats.failed))
end

local SPARKLE_SETTINGS = {
	outlineModeShowLootEffectWhenDisabled = "1",
	graphicsOutlineMode = "0",
	OutlineEngineMode = "0",
	raidGraphicsOutlineMode = "0",
	RAIDOutlineEngineMode = "0",
}

local SPARKLE_WATCH = { graphicsquality = true, raidgraphicsquality = true }
for name in pairs(SPARKLE_SETTINGS) do SPARKLE_WATCH[name:lower()] = true end

local sparkleWriting = false
local sparkleQueued = false
local sparkleAfterCombat = false
local sparkleStats = { applied = 0, changed = 0, deferred = 0 }

local function ReadSetting(name)
	local get = C_CVar and C_CVar.GetCVar or GetCVar
	local ok, value = pcall(get, name)
	if not ok or (issecretvalue and issecretvalue(value)) then return nil end
	return value
end

local function ApplySparkles()
	if InCombatLockdown and InCombatLockdown() then
		sparkleAfterCombat = true
		sparkleStats.deferred = sparkleStats.deferred + 1
		return
	end
	local set = C_CVar and C_CVar.SetCVar or SetCVar
	sparkleWriting = true
	for name, want in pairs(SPARKLE_SETTINGS) do
		local current = ReadSetting(name)

		if current ~= nil and current ~= want and pcall(set, name, want) then
			sparkleStats.changed = sparkleStats.changed + 1
		end
	end
	sparkleWriting = false
	sparkleStats.applied = sparkleStats.applied + 1
end

local function QueueSparkles(delay)
	if sparkleQueued then return end
	sparkleQueued = true
	C_Timer.After(delay, function()
		sparkleQueued = false
		ApplySparkles()
	end)
end

local sparkleFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(sparkleFrame, "PLAYER_LOGIN")
KUI:SafeRegisterEvent(sparkleFrame, "PLAYER_REGEN_ENABLED")
KUI:SafeRegisterEvent(sparkleFrame, "CVAR_UPDATE")
sparkleFrame:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		ApplySparkles()
		C_Timer.After(5, ApplySparkles)
	elseif event == "PLAYER_REGEN_ENABLED" then
		if sparkleAfterCombat then
			sparkleAfterCombat = false
			ApplySparkles()
		end
	elseif event == "CVAR_UPDATE" and not sparkleWriting then
		if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return end
		if SPARKLE_WATCH[name:lower()] then QueueSparkles(1) end
	end
end)

function KUI:SparkleScanReport()
	print(string.format("|cff33ff99Kain-UI Forever|r quest item sparkles: applied %d time(s), %d setting change(s), %d wait(s) for combat to end",
		sparkleStats.applied, sparkleStats.changed, sparkleStats.deferred))
	local names = {}
	for name in pairs(SPARKLE_SETTINGS) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local current = ReadSetting(name)
		print(string.format("  %s = %s (want %s)%s", name, tostring(current), SPARKLE_SETTINGS[name],
			current == nil and "  -- not on this client" or (current == SPARKLE_SETTINGS[name] and "" or "  -- DIFFERENT")))
	end
end

SLASH_KAINUICOINFLIP1 = "/flip"
SLASH_KAINUICOINFLIP2 = "/coinflip"
SLASH_KAINUICOINFLIP3 = "/coin"
SlashCmdList["KAINUICOINFLIP"] = function()
	local d = random(101)
	local t = GetUnitName("target", true)

	if issecretvalue and issecretvalue(t) then t = nil end
	local r = d == 101 and "The coin landed upright? That's odd.." or d <= 50 and "Heads!" or "Tails!"
	SendChatMessage(format("flips a coin%s. He reveals.. %s", t and " for " .. t or "", r), "EMOTE")
end

KUI.USER_COMMANDS = {
	[""] = true, help = true, snapshot = true, factoryreset = true,
	resetdrag = true, resetlootroll = true, zonebarreset = true, xpreset = true,
	installmacros = true, weaponswap = true, linksoff = true, clearerrors = true,
	enabledev = true, disabledev = true,
}

function KUI:IsDevMode()
	local db = _G.KainUIForeverAccountDB
	return type(db) == "table" and db.devMode == true
end

function KUI:SetDevMode(on)
	if type(_G.KainUIForeverAccountDB) ~= "table" then _G.KainUIForeverAccountDB = {} end
	_G.KainUIForeverAccountDB.devMode = on and true or nil
	print("|cff33ff99Kain-UI Forever|r developer commands are now " .. (on and "|cff00ff00ON|r. |cffffff00/kui disabledev|r (or /kui enabledev again) turns them off." or "|cffff6060OFF|r."))
end

SLASH_KAINUIFOREVER1 = "/kainui"
SLASH_KAINUIFOREVER2 = "/kui"
SlashCmdList["KAINUIFOREVER"] = function(msg)
	msg = msg or ""

	local command, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	command = (command or ""):lower()

	if command == "enabledev" then
		KUI:SetDevMode(not KUI:IsDevMode())
		return
	elseif command == "disabledev" then
		KUI:SetDevMode(false)
		return
	elseif command == "help" then
		if KUI.ToggleHelp then KUI:ToggleHelp() end
		return
	end
	if not KUI.USER_COMMANDS[command] and not KUI:IsDevMode() then
		print("|cff33ff99Kain-UI Forever|r unknown command. Type |cffffff00/kui help|r for the list of commands.")
		return
	end

	if command == "bagscan" and KUI.BagScanReport then
		KUI:BagScanReport()
	elseif command == "bagdebug" and KUI.BagDebugReport then
		KUI:BagDebugReport()
	elseif command == "bagwatch" and KUI.BagWatch then
		KUI:BagWatch(rest)
	elseif command == "microscan" and KUI.MicroMenuScanReport then
		KUI:MicroMenuScanReport()
	elseif command == "bagdividerscan" and KUI.BagDividerScanReport then
		KUI:BagDividerScanReport()
	elseif command == "xpscan" and KUI.XPBarScanReport then
		KUI:XPBarScanReport()
	elseif command == "socialscan" and KUI.SocialButtonScanReport then
		KUI:SocialButtonScanReport()
	elseif command == "allynotescan" and KUI.AllyNoteScanReport then
		KUI:AllyNoteScanReport()
	elseif command == "levelshotscan" and KUI.LevelShotScanReport then
		KUI:LevelShotScanReport()
	elseif command == "wowheadscan" and KUI.WowheadScanReport then
		KUI:WowheadScanReport()
	elseif command == "clearerrors" and KUI.ClearErrorLog then
		KUI:ClearErrorLog()
	elseif command == "errorscan" and KUI.ErrorLogScanReport then
		KUI:ErrorLogScanReport()
	elseif command == "sparklescan" and KUI.SparkleScanReport then
		KUI:SparkleScanReport()
	elseif command == "xpreset" and KUI.ResetXPSession then
		KUI:ResetXPSession()
	elseif command == "dragscan" and KUI.DragScanReport then
		KUI:DragScanReport()
	elseif command == "resetdrag" and KUI.ResetDragPositions then
		KUI:ResetDragPositions()
	elseif command == "vendorscan" and KUI.VendorScanReport then
		KUI:VendorScanReport()
	elseif command == "iconpickerscan" and KUI.MacroIconPickerScanReport then
		KUI:MacroIconPickerScanReport()
	elseif command == "installmacros" and KUI.InstallStarterMacros then
		KUI:InstallStarterMacros()
		if KUI.StarterMacroScanReport then KUI:StarterMacroScanReport() end
	elseif command == "weaponswap" and KUI.WeaponSwapRebuild then
		KUI:WeaponSwapRebuild()
	elseif command == "macroscan" and KUI.StarterMacroScanReport then
		KUI:StarterMacroScanReport()
	elseif command == "fastlootscan" and KUI.FastLootScanReport then
		KUI:FastLootScanReport()
	elseif command == "contrastscan" and KUI.ContrastScanReport then
		KUI:ContrastScanReport()
	elseif command == "minimapposscan" and KUI.MinimapPositionScanReport then
		KUI:MinimapPositionScanReport()
	elseif command == "chatshorthandscan" and KUI.ChatShorthandScanReport then
		KUI:ChatShorthandScanReport()
	elseif command == "chatnumscan" and KUI.ChatChannelNumberScanReport then
		KUI:ChatChannelNumberScanReport()
	elseif command == "chathistoryscan" and KUI.ChatHistoryRecallScanReport then
		KUI:ChatHistoryRecallScanReport()
	elseif command == "chatlinkscan" and KUI.ChatLinkifyScanReport then
		KUI:ChatLinkifyScanReport()
	elseif command == "linksoff" then

		if KUI.db then
			KUI.db.chatEnhanced = false
			print("|cff33ff99Kain-UI Forever|r Enhance Chat turned OFF.")
		else
			print("|cffff6060Kain-UI Forever:|r settings aren't loaded yet -- wait a moment and try again, or /reload.")
		end
	elseif command == "minimapstratascan" and KUI.MinimapStrataScanReport then
		KUI:MinimapStrataScanReport()
	elseif command == "minimapwatch" and KUI.MinimapClusterWatch then
		KUI:MinimapClusterWatch(rest)
	elseif command == "resetlootroll" and KUI.ResetLootRollPosition then
		KUI:ResetLootRollPosition()
	elseif command == "tooltipscan" and KUI.TooltipScanReport then
		KUI:TooltipScanReport()
	elseif command == "borderscan" and KUI.BorderScanReport then
		KUI:BorderScanReport()
	elseif command == "actionbarscan" then
		if KUI.ActionBarScanReport then
			KUI:ActionBarScanReport()
		else
			print("|cffff6060Kain-UI Forever:|r ActionBarScanReport not found -- ActionBars.lua may have failed to load. Check /kainui for any earlier errors.")
		end
	elseif command == "rxpscan" and KUI.RXPTweaksScanReport then
		KUI:RXPTweaksScanReport()
	elseif command == "rxpfollowscan" and KUI.RXPFollowScanReport then
		KUI:RXPFollowScanReport()
	elseif command == "castbyscan" and KUI.CastByScanReport then
		KUI:CastByScanReport()
	elseif command == "castbywatch" and KUI.CastByWatch then
		KUI:CastByWatch(rest)
	elseif command == "dielscan" and KUI.DielScanReport then
		KUI:DielScanReport()
	elseif command == "bagfixscan" and KUI.BackpackFixScanReport then
		KUI:BackpackFixScanReport()
	elseif command == "snapshot" and KUI.ShowSnapshot then
		KUI:ShowSnapshot(rest)
	elseif command == "masktest" and KUI.MaskTest then
		KUI:MaskTest()
	elseif command == "zonebarscan" and KUI.ZoneBarScanReport then
		KUI:ZoneBarScanReport()
	elseif command == "binscan" and KUI.MinimapButtonBinScanReport then
		KUI:MinimapButtonBinScanReport()
	elseif command == "squarescan" and KUI.SquareMinimapScanReport then
		KUI:SquareMinimapScanReport()
	elseif command == "lfgfieldscan" and KUI.LFGFieldScanReport then
		KUI:LFGFieldScanReport()
	elseif command == "diffscan" and KUI.GuildDifficultyScanReport then
		KUI:GuildDifficultyScanReport()
	elseif command == "zonebarreset" and KUI.ResetZoneBarPosition then
		KUI:ResetZoneBarPosition()
	elseif command == "nameplatecapture" and KUI.NameplateCaptureReport then
		KUI:NameplateCaptureReport()
	elseif command == "dumpframe" then
		KUI:DumpFrameChildren(rest)
	elseif command == "factoryreset" then

		if rest:lower() ~= "confirm" then
			print("|cff33ff99Kain-UI Forever|r this erases every Kain-UI setting (window positions included) and reloads. Type |cffffff00/kainui factoryreset confirm|r to go ahead.")
		elseif InCombatLockdown() then
			print("|cffff6060Kain-UI Forever:|r can't reset during combat.")
		elseif KUI.db then
			wipe(KUI.db)
			if type(ReloadUI) == "function" then ReloadUI() elseif C_UI and C_UI.Reload then C_UI.Reload() end
		end
	elseif command == "" and KUI.ToggleOptions then
		KUI:ToggleOptions()
	else
		print("|cffff6060Kain-UI Forever:|r unrecognized command. Type /kui help for the player commands; developer commands are the scans and watches listed in the comments doc.")
	end
end
