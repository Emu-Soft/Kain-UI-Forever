local addonName, KUI = ...

local KNOWN_HARMLESS_MARKERS = { "EditModeManager", "GetAuraDataByIndex", "ObjectiveTracker", "MawBuffs" }

local function IsKnownHarmlessTaintSpam(msg)
	if type(msg) ~= "string" then return false end
	if not msg:find(addonName, 1, true) then return false end
	for _, marker in ipairs(KNOWN_HARMLESS_MARKERS) do
		if msg:find(marker, 1, true) then return true end
	end
	return false
end

local SUPPRESS_KNOWN_TAINT_SPAM = false

if SUPPRESS_KNOWN_TAINT_SPAM then
	local previousHandler = geterrorhandler()
	seterrorhandler(function(msg, ...)
		if IsKnownHarmlessTaintSpam(msg) then return end
		return previousHandler(msg, ...)
	end)
end

local YARDS_TO_METERS = 0.9144
local hooked = false
local lastYardsText
local lastConvertedText

local function ConvertYardsToMeters()
	local arrowFrame = _G.RXPG_ARROW
	if not arrowFrame or not arrowFrame.text then return end

	local text = arrowFrame.text:GetText()
	if not text then return end

	local metricEnabled = KUI.db and KUI.db.convertImperialToMetric

	if text:find("yd") then

		lastYardsText = text
		if not metricEnabled then return end

		local newText = text:gsub("%((%d+)yd%)", function(yards)
			local meters = math.floor(tonumber(yards) * YARDS_TO_METERS + 0.5)
			if meters >= 1000 then
				return string.format("(%.1f Km)", meters / 1000)
			else
				return string.format("(%dm)", meters)
			end
		end)

		if newText ~= text then
			arrowFrame.text:SetText(newText)
			lastConvertedText = newText
		end
	elseif not metricEnabled and lastYardsText and text == lastConvertedText then

		arrowFrame.text:SetText(lastYardsText)
	end
end

local function SetupHook()
	local arrowFrame = _G.RXPG_ARROW
	if not arrowFrame then return false end

	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", ConvertYardsToMeters)

	return true
end

function KUI:ApplyRXPTweaks()
	if hooked then return end
	hooked = SetupHook()
end

local frame = CreateFrame("Frame")
KUI:SafeRegisterEvent(frame, "ADDON_LOADED")
KUI:SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
	if hooked then return end

	if event == "ADDON_LOADED" and arg1 == "RXPGuides" then
		C_Timer.After(0.5, function() KUI:ApplyRXPTweaks() end)
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function() KUI:ApplyRXPTweaks() end)
	end
end)

function KUI:SetConvertImperialToMetric(checked)
	if not KUI.db then return end
	KUI.db.convertImperialToMetric = checked and true or false
end

function KUI:RXPTweaksScanReport()
	if not _G.RXPG_ARROW then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPG_ARROW not found -- RXPGuides may not be loaded, or hasn't created its arrow yet (enter the world first).")
	elseif hooked then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPG_ARROW found and hooked.")
	else
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPG_ARROW found but not yet hooked -- /kainui rxpscan again in a moment, or /reload.")
	end

	if KUI.RXPProfileReport then KUI:RXPProfileReport() end
end

local followHooked = false

local function ClickRXPFrame()
	local rxpFrame = _G.RXPFrame
	if not rxpFrame then
		print("|cffff6060Kain-UI Forever:|r RXP Tweaks: RXPFrame not found -- couldn't unroll it. /kainui rxpfollowscan for details.")
		return
	end

	local onMouseUp = rxpFrame.GetScript and rxpFrame:GetScript("OnMouseUp")
	if not onMouseUp then
		print("|cffff6060Kain-UI Forever:|r RXP Tweaks: RXPFrame has no OnMouseUp script on this client -- couldn't unroll it. /kainui rxpfollowscan for details.")
		return
	end

	local ok, err = pcall(securecall, onMouseUp, rxpFrame, "LeftButton")
	if not ok then
		print("|cffff6060Kain-UI Forever:|r RXP Tweaks couldn't click RXPFrame: " .. tostring(err))
	end
end

local FOLLOW_INITIAL_DELAY_S = 3.0
local FOLLOW_INITIAL_LOGIN_DELAY_S = 6.0
local RETRY_INTERVAL_S = 1.0
local RETRY_MAX_ATTEMPTS = 20
local WATCH_AFTER_CLICK_S = 10
local MAX_REAPPLIES = 2

local followLog = {}
local function FollowNote(msg) followLog[#followLog + 1] = format("%.1fs: %s", GetTime() % 1000, msg) end

local function FollowTargetsReady()
	local rxpFrame = _G.RXPFrame
	local hasRXPClick = rxpFrame and rxpFrame.GetScript and rxpFrame:GetScript("OnMouseUp")

	return hasRXPClick and true or false
end

local function RXPHeight()
	local f = _G.RXPFrame
	local h = f and f.GetHeight and f:GetHeight()
	if type(h) ~= "number" or (issecretvalue and issecretvalue(h)) then return nil end
	return math.floor(h + 0.5)
end

local trackerBaseAlpha
local savedMouse = {}
local savedAlpha = {}
local trackerTicker

local function CanTouch(f)
	if not f then return false end
	if f.IsForbidden then
		local ok, forbidden = pcall(f.IsForbidden, f)
		if not ok or forbidden then return false end
	end
	if InCombatLockdown() and f.IsProtected and f:IsProtected() then return false end
	return true
end

local function MuteMouse(f)
	if savedMouse[f] or not CanTouch(f) then return end
	local entry = {}
	if f.IsMouseEnabled then entry.mouse = f:IsMouseEnabled() end
	if f.IsMouseWheelEnabled then entry.wheel = f:IsMouseWheelEnabled() end
	savedMouse[f] = entry
	if entry.mouse and f.EnableMouse then f:EnableMouse(false) end
	if entry.wheel and f.EnableMouseWheel then f:EnableMouseWheel(false) end
end

local function MakeInvisible(f)
	if savedAlpha[f] ~= nil or not CanTouch(f) then return end
	savedAlpha[f] = f:GetAlpha()
	f:SetAlpha(0)
	MuteMouse(f)
end

local function IsForbiddenFrame(f)
	if not f then return true end
	if f.IsForbidden then
		local ok, forbidden = pcall(f.IsForbidden, f)
		return not ok or forbidden and true or false
	end
	return false
end

local function EachDescendant(root, fn)
	if IsForbiddenFrame(root) then return end
	local ok, children = pcall(function() return { root:GetChildren() } end)
	if not ok then return end
	for _, child in ipairs(children) do
		if not IsForbiddenFrame(child) then
			fn(child)
			EachDescendant(child, fn)
		end
	end
end

local function AnchoredToTracker(f, tracker)
	if not f.GetNumPoints then return false end
	for i = 1, f:GetNumPoints() do
		local _, rel = f:GetPoint(i)

		if issecretvalue and issecretvalue(rel) then return false end
		local r = rel
		while r do
			if r == tracker then return true end
			r = r.GetParent and r:GetParent()
		end
	end
	return false
end

local function HideTrackerExtras(tracker)
	MuteMouse(tracker)
	EachDescendant(tracker, function(f)
		MuteMouse(f)

		if f.IsIgnoringParentAlpha then
			local ok, ignoring = pcall(f.IsIgnoringParentAlpha, f)
			if ok and ignoring then MakeInvisible(f) end
		end
	end)

	for _, f in ipairs({ UIParent:GetChildren() }) do
		if f ~= tracker and not savedAlpha[f] and not IsForbiddenFrame(f) then
			local okShown, shown = pcall(f.IsShown, f)
			if okShown and shown then
				local ok, anchored = pcall(AnchoredToTracker, f, tracker)
				if ok and anchored then MakeInvisible(f) end
			end
		end
	end
end

local function RestoreTrackerExtras()
	for f, entry in pairs(savedMouse) do
		if CanTouch(f) then
			if entry.mouse ~= nil and f.EnableMouse then f:EnableMouse(entry.mouse) end
			if entry.wheel ~= nil and f.EnableMouseWheel then f:EnableMouseWheel(entry.wheel) end
			savedMouse[f] = nil
		end
	end
	for f, alpha in pairs(savedAlpha) do
		if CanTouch(f) then
			f:SetAlpha(alpha)
			savedAlpha[f] = nil
		end
	end

end

local function UpdateTrackerAlpha()
	local tracker = _G.ObjectiveTrackerFrame
	if not (tracker and tracker.SetAlpha and tracker.GetAlpha) then return end
	local rxp = _G.RXPFrame
	local hide = KUI.db and KUI.db.followRXPObjectives and rxp and rxp:IsShown()
	if hide then
		if trackerBaseAlpha == nil then trackerBaseAlpha = tracker:GetAlpha() end
		tracker:SetAlpha(0)
		HideTrackerExtras(tracker)
	elseif trackerBaseAlpha ~= nil then
		tracker:SetAlpha(trackerBaseAlpha)
		trackerBaseAlpha = nil
		RestoreTrackerExtras()
	else
		RestoreTrackerExtras()
	end

	local busy = hide or next(savedMouse) ~= nil or next(savedAlpha) ~= nil
	if busy and not trackerTicker and C_Timer and C_Timer.NewTicker then
		trackerTicker = C_Timer.NewTicker(0.5, UpdateTrackerAlpha)
	elseif not busy and trackerTicker then
		trackerTicker:Cancel()
		trackerTicker = nil
	end
end

local rxpVisibilityHooked = false
local function HookRXPVisibility()
	if rxpVisibilityHooked then return end
	local rxp = _G.RXPFrame
	if not (rxp and rxp.HookScript) then return end
	rxpVisibilityHooked = true
	rxp:HookScript("OnShow", UpdateTrackerAlpha)
	rxp:HookScript("OnHide", UpdateTrackerAlpha)
end

local function IsRXPLoaded()
	return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides"))
		or (IsAddOnLoaded and IsAddOnLoaded("RXPGuides")) or false
end

function KUI:ApplyFollowRXPObjectives()
	if not (KUI.db and KUI.db.followRXPObjectives) then return end

	if not IsRXPLoaded() then return end
	if followHooked then return end
	followHooked = true

	local followFrame = CreateFrame("Frame")
	KUI:SafeRegisterEvent(followFrame, "PLAYER_ENTERING_WORLD")
	followFrame:SetScript("OnEvent", function(watcher, event, isInitialLogin)

		watcher:UnregisterEvent("PLAYER_ENTERING_WORLD")
		wipe(followLog)
		FollowNote(isInitialLogin and "fresh login" or "reload")

		local attempt, lastHeight, stableChecks = 0, nil, 0

		local function WatchAfterClick(beforeHeight, reapplies)
			local elapsed = 0
			local function Tick()
				elapsed = elapsed + 1
				if not (KUI.db and KUI.db.followRXPObjectives) then return end
				local h = RXPHeight()
				if h and beforeHeight and h == beforeHeight then
					if reapplies < MAX_REAPPLIES then
						FollowNote("RXPFrame went back to height " .. h .. " -- RXPGuides reset it; clicking again")
						ClickRXPFrame()
						C_Timer.After(1, function()
							local after = RXPHeight()
							FollowNote("height after re-click: " .. tostring(after))
							if after ~= beforeHeight then WatchAfterClick(beforeHeight, reapplies + 1) end
						end)
					else
						FollowNote("reset again, but out of re-clicks")
					end
					return
				end
				if elapsed < WATCH_AFTER_CLICK_S then C_Timer.After(1, Tick) end
			end
			C_Timer.After(1, Tick)
		end

		local function TryClick()
			attempt = attempt + 1

			if not (KUI.db and KUI.db.followRXPObjectives) then return end

			local rxp = _G.RXPFrame
			local h = RXPHeight()
			if FollowTargetsReady() and rxp and rxp:IsVisible() and h then
				if h == lastHeight then stableChecks = stableChecks + 1 else stableChecks = 0 end
			else
				stableChecks = 0
			end
			lastHeight = h

			if stableChecks >= 2 then
				FollowNote("ready (height " .. h .. ") after " .. attempt .. " checks; clicking")
				ClickRXPFrame()

				HookRXPVisibility()
				UpdateTrackerAlpha()

				C_Timer.After(1, function()
					local after = RXPHeight()
					FollowNote("height after click: " .. tostring(after))
					if after and after ~= h then
						WatchAfterClick(h, 0)
					else
						FollowNote("height didn't change -- can't tell if it unrolled, so leaving it")
					end
				end)
				return
			end

			if attempt >= RETRY_MAX_ATTEMPTS then
				FollowNote("gave up (visible=" .. tostring(rxp and rxp:IsVisible()) .. ", height=" .. tostring(h) .. ")")
				print("|cffff6060Kain-UI Forever:|r RXP Tweaks: gave up waiting for RXPFrame/the objective tracker to be ready after " .. RETRY_MAX_ATTEMPTS .. " checks -- /kainui rxpfollowscan for details.")
				return
			end

			C_Timer.After(RETRY_INTERVAL_S, TryClick)
		end

		C_Timer.After(isInitialLogin and FOLLOW_INITIAL_LOGIN_DELAY_S or FOLLOW_INITIAL_DELAY_S, TryClick)
	end)
end

function KUI:SetFollowRXPObjectives(checked)
	if not KUI.db then return end
	KUI.db.followRXPObjectives = checked and true or false
	if checked then

		KUI:ApplyFollowRXPObjectives()
	end

	HookRXPVisibility()
	UpdateTrackerAlpha()
end

function KUI:RXPFollowScanReport()
	if #followLog > 0 then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: last unroll attempt this session:")
		for _, line in ipairs(followLog) do print("  " .. line) end
	end
	local rxpFrame = _G.RXPFrame
	if not rxpFrame then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPFrame not found.")
	elseif rxpFrame.GetScript and rxpFrame:GetScript("OnMouseUp") then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPFrame found, with an OnMouseUp script -- unroll click should work.")
	else
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: RXPFrame found, but no OnMouseUp script -- unroll click will not work as written.")
	end

	local tracker = _G.ObjectiveTrackerFrame
	local button = tracker and tracker.Header and tracker.Header.MinimizeButton
	if not button then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: ObjectiveTrackerFrame.Header.MinimizeButton not found.")
	elseif button.Click then
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: minimize button found and clickable -- collapse click should work.")
	else
		print("|cff33ff99Kain-UI Forever|r RXP Tweaks: minimize button found, but it isn't a clickable Button widget -- collapse click will not work as written.")
	end
end

local RXP_PROFILE_NAME = "Kain-UI"
local WatchRXPProfileChanges

local function KainRXPProfile()
	return {
		["tbcStart"] = 2,
		["hardcore"] = false,
		["season"] = 0,
		["lockFrames"] = true,
		["maxSoulShards"] = 6,
		["hideInRaid"] = true,
		["frameSizes"] = {
			["activeTargetFrame"] = { 83.99999237060547, 43 },
			["RXPFrame"] = { 277.0000305175781, 31.00002670288086 },
			["activeItemFrame"] = { 79.16667938232422, 43 },
			["arrowFrame"] = { 40.00000762939453, 40.00000762939453 },
		},
		["arrowScale"] = 1.25,
		["enableLevelUpAnnounceGroup"] = false,
		["goblinTele"] = false,
		["tbcWBF"] = true,
		["gnomeTele"] = false,
		["portalTele"] = false,
		["macroAnnounced"] = true,
		["enableLevelUpAnnounceSolo"] = false,
		["framePositions"] = {
			["activeTargetFrame"] = { { "TOPLEFT", nil, "TOPLEFT", 276, -9 } },
			["RXPFrame"] = { { "TOPLEFT", nil, "TOPLEFT", 2.499982595443726, -27.50006484985352 } },
			["activeItemFrame"] = { { "BOTTOM", nil, "BOTTOM", -362, 199 } },
			["arrowFrame"] = { { "CENTER", nil, "CENTER", 0.1658800840377808, -176.6663055419922 } },
		},
	}
end

local function FindRXPSettingsDB()
	local AceDB = LibStub and LibStub("AceDB-3.0", true)
	if not (AceDB and AceDB.db_registry and type(_G.RXPSettings) == "table") then return nil end
	for db in pairs(AceDB.db_registry) do
		if type(db) == "table" and db.sv == _G.RXPSettings then return db end
	end
	return nil
end

local rxpProfileLog = {}
local function RXPNote(msg) rxpProfileLog[#rxpProfileLog + 1] = format("%.1fs: %s", GetTime() % 1000, msg) end

local applyingOurs = false
local watchedDB
WatchRXPProfileChanges = function(db)
	if watchedDB == db or not (db and db.RegisterCallback) then return end
	watchedDB = db
	local listener = {}
	db.RegisterCallback(listener, "OnProfileChanged", function(_, _, newProfile)
		if applyingOurs then return end
		if newProfile ~= RXP_PROFILE_NAME and KUI.db and KUI.db.rxpKainProfile then
			KUI.db.rxpKainProfile = nil
			RXPNote("player switched RXP to \"" .. tostring(newProfile) .. "\" -- stopped re-applying Kain-UI")
		end
	end)
end

function KUI:ApplyKainRXPProfile()
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides"))
		or (IsAddOnLoaded and IsAddOnLoaded("RXPGuides"))
	if not loaded then return "notloaded" end

	local db = FindRXPSettingsDB()
	if not db or type(db.SetProfile) ~= "function" then
		return "failed", "couldn't find RXP's settings"
	end

	local ok, err = pcall(function()
		db.sv.profiles = db.sv.profiles or {}
		db.sv.profiles[RXP_PROFILE_NAME] = KainRXPProfile()
	end)
	if not ok then return "failed", tostring(err) end

	local charKey = db.keys and db.keys.char
	if KUI.db then
		KUI.db.rxpKainProfile = true
		KUI.db.rxpCharKey = charKey
	end
	if charKey then
		db.sv.profileKeys = db.sv.profileKeys or {}
		db.sv.profileKeys[charKey] = RXP_PROFILE_NAME
	end
	WatchRXPProfileChanges(db)

	local current = db.GetCurrentProfile and db:GetCurrentProfile()
	if current == RXP_PROFILE_NAME then return "updated" end

	applyingOurs = true
	ok, err = pcall(db.SetProfile, db, RXP_PROFILE_NAME)
	applyingOurs = false
	if not ok then return "failed", tostring(err) end
	return "switched"
end

local function WantsKainRXP()
	return KUI.db and KUI.db.rxpKainProfile and true or false
end

local rxpLoginFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(rxpLoginFrame, "ADDON_LOADED")
KUI:SafeRegisterEvent(rxpLoginFrame, "PLAYER_ENTERING_WORLD")
rxpLoginFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "RXPGuides" or not WantsKainRXP() then return end
		local key = KUI.db.rxpCharKey
		local sv = _G.RXPSettings
		if key and type(sv) == "table" then
			local before = sv.profileKeys and sv.profileKeys[key]
			RXPNote("RXP loaded; saved profile for " .. key .. " was \"" .. tostring(before) .. "\"")
			if before ~= RXP_PROFILE_NAME then
				sv.profileKeys = sv.profileKeys or {}
				sv.profileKeys[key] = RXP_PROFILE_NAME
				RXPNote("set it back to Kain-UI before RXP started")
			end
		end
		return
	end

	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if not WantsKainRXP() then return end
	C_Timer.After(2, function()
		local db = FindRXPSettingsDB()
		if not db then return end
		WatchRXPProfileChanges(db)
		local current = db.GetCurrentProfile and db:GetCurrentProfile()
		RXPNote("in world; RXP profile is \"" .. tostring(current) .. "\" (key " .. tostring(db.keys and db.keys.char) .. ")")
		if current ~= RXP_PROFILE_NAME and WantsKainRXP() then
			if db.keys and db.keys.char then KUI.db.rxpCharKey = db.keys.char end
			applyingOurs = true
			local ok = pcall(db.SetProfile, db, RXP_PROFILE_NAME)
			applyingOurs = false
			RXPNote(ok and "switched RXP to Kain-UI" or "switch failed")
		end
	end)
end)

local function WantsKainRXPReport() return KUI.db and KUI.db.rxpKainProfile and true or false end

function KUI:RXPProfileReport()
	local db = FindRXPSettingsDB()
	if not db then
		print("|cff33ff99Kain-UI Forever|r RXP profile: RXP's settings not found (RXPGuides not loaded?).")
		return
	end
	local key = db.keys and db.keys.char
	print("|cff33ff99Kain-UI Forever|r RXP profile: active \"" .. tostring(db.GetCurrentProfile and db:GetCurrentProfile()) .. "\"")
	print("  AceDB character key: " .. tostring(key) .. ", saved profile for it: \"" .. tostring(key and db.sv.profileKeys and db.sv.profileKeys[key]) .. "\"")
	print("  Kain-UI remembered for this character: " .. (WantsKainRXPReport() and "yes" or "no"))
	for _, line in ipairs(rxpProfileLog) do print("  " .. line) end
end
