local _, KUI = ...

local BAR_HEIGHT_PX = 6

local HOVER_PAD_Y, HOVER_PAD_X = 6, 4
local TOOLTIP_GAP = 2
local BAR_GAP_PX = 2
local BRONZE_PX = 1
local OUTLINE_PX = 1
local FRAME_PX = BRONZE_PX + OUTLINE_PX
local SQUARE_LEFT = true

local XP_COLOR = { 0.58, 0.0, 0.55 }
local XP_COLOR_RESTED = { 0.0, 0.39, 0.88 }
local RESTED_EXTENSION_COLOR = { 0.36, 0.62, 1.0, 0.6 }
local RESTED_TEXT_COLOR = { 0.4, 0.7, 1.0 }

local DIVIDER_WIDTH_PX = 2
local BACKGROUND = { 0.05, 0.05, 0.05, 1 }
local BRONZE = { 0.55, 0.42, 0.18, 1 }
local OUTLINE = { 0, 0, 0, 1 }
local DIVIDER_COLOR = BRONZE

local FALLBACK_LEFT_FRACTION, FALLBACK_RIGHT_FRACTION = 0.36, 0.03

local bar
local barShowing = false
local anchorNote = "not laid out yet"
local defaultHiddenByUs = false
local defaultHooked = false
local pendingAfterCombat = false
local errorShown = false

local function IsFrame(f)
	local kind = type(f)
	return (kind == "table" or kind == "userdata") and f.SetPoint ~= nil
end

local function Dig(root, ...)
	local node = root
	for i = 1, select("#", ...) do
		local kind = type(node)
		if kind ~= "table" and kind ~= "userdata" then return nil end
		node = node[(select(i, ...))]
	end
	return node
end

local function FormatNumber(n)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function PlayerHasXP()
	if IsXPUserDisabled and IsXPUserDisabled() then return false end
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
	if maxLevel and UnitLevel("player") >= maxLevel then return false end
	local xpMax = UnitXPMax("player")
	return xpMax ~= nil and xpMax > 0
end

local function FindManaBar()
	if type(PlayerFrame_GetManaBar) == "function" then
		local ok, f = pcall(PlayerFrame_GetManaBar)
		if ok and IsFrame(f) then return f, "PlayerFrame_GetManaBar()" end
	end
	local f = Dig(_G.PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain", "ManaBarArea", "ManaBar")
	if IsFrame(f) then return f, "PlayerFrame.PlayerFrameContent...ManaBar" end
	f = Dig(_G.PlayerFrame, "manabar")
	if IsFrame(f) then return f, "PlayerFrame.manabar" end
	f = _G.PlayerFrameManaBar
	if IsFrame(f) then return f, "PlayerFrameManaBar" end
	return nil
end

local function UnitsPerPixel(frame)
	local physicalHeight
	if type(GetPhysicalScreenSize) == "function" then
		local _, h = GetPhysicalScreenSize()
		physicalHeight = h
	end
	local scale = frame:GetEffectiveScale()
	if not physicalHeight or physicalHeight <= 0 or not scale or scale <= 0 then return 1 end
	return 768 / physicalHeight / scale
end

local insetCache = {}
local function PillInsets(height)
	if insetCache[height] then return insetCache[height] end
	local radius = height / 2
	local insets = {}
	for i = 1, height do
		local dy = math.abs(i - 0.5 - radius)
		insets[i] = math.floor(radius - math.sqrt(radius * radius - dy * dy) + 0.5)
	end
	insetCache[height] = insets
	return insets
end

local function SetRowsColor(rows, color)
	for _, row in ipairs(rows) do
		row:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	end
end

local function DrawFill(rows, insets, widthPx, pixel, fraction)
	local filled = fraction and math.floor(widthPx * fraction + 0.5) or 0
	for i, row in ipairs(rows) do
		local left = SQUARE_LEFT and 0 or insets[i]
		local right = widthPx - insets[i]
		local width = math.min(right, filled) - left
		if width > 0 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", bar, "TOPLEFT", left * pixel, -(i - 1) * pixel)
			row:SetSize(width * pixel, pixel)
			row:Show()
		else
			row:Hide()
		end
	end
end

local function DrawDivider()
	local rows = bar.dividerRows
	local insets = bar.layers[#bar.layers].insets
	local widthPx, pixel = bar.widthPx, bar.pixel
	local filled = math.floor(widthPx * (bar.fillFraction or 0) + 0.5)
	local restedEnd = bar.restedFraction and math.floor(widthPx * bar.restedFraction + 0.5) or 0
	local show = bar.hasRested and filled > 0 and restedEnd > filled and filled < widthPx
	for i, row in ipairs(rows) do
		local left = SQUARE_LEFT and 0 or insets[i]
		local right = widthPx - insets[i]

		local x0 = math.max(left, filled)
		local x1 = math.min(right, filled + DIVIDER_WIDTH_PX)
		if show and x1 > x0 then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", bar, "TOPLEFT", x0 * pixel, -(i - 1) * pixel)
			row:SetSize((x1 - x0) * pixel, pixel)
			row:Show()
		else
			row:Hide()
		end
	end
end

local function RenderFill()
	if not (bar and bar.widthPx) then return end
	local insets = bar.layers[#bar.layers].insets
	DrawFill(bar.restedRows, insets, bar.widthPx, bar.pixel, bar.restedFraction)
	DrawFill(bar.fillRows, insets, bar.widthPx, bar.pixel, bar.fillFraction)
	DrawDivider()
end

local function Render()
	if not bar then return end
	local pixel = UnitsPerPixel(bar)
	local width = bar:GetWidth()
	if not width or width <= 0 then return end
	local widthPx = math.max(1, math.floor(width / pixel + 0.5))
	bar.pixel, bar.widthPx = pixel, widthPx

	bar:SetHeight(BAR_HEIGHT_PX * pixel)
	for _, layer in ipairs(bar.layers) do
		for i, row in ipairs(layer.rows) do
			local left = -layer.grow + (SQUARE_LEFT and 0 or layer.insets[i])
			local right = widthPx + layer.grow - layer.insets[i]
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", bar, "TOPLEFT", left * pixel, -(i - 1 - layer.grow) * pixel)
			row:SetSize((right - left) * pixel, pixel)
		end
	end
	RenderFill()
end

local function Layout()
	bar:ClearAllPoints()
	local pixel = UnitsPerPixel(bar)
	local drop = (BAR_GAP_PX + FRAME_PX) * pixel
	local target, source = FindManaBar()
	if target then
		bar:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -drop)
		bar:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -drop)
		anchorNote = "under the power bar, found via " .. source
	else
		local width = _G.PlayerFrame:GetWidth() or 232
		bar:SetPoint("TOPLEFT", _G.PlayerFrame, "BOTTOMLEFT", width * FALLBACK_LEFT_FRACTION, -drop)
		bar:SetPoint("TOPRIGHT", _G.PlayerFrame, "BOTTOMRIGHT", -width * FALLBACK_RIGHT_FRACTION, -drop)
		anchorNote = "FALLBACK: under PlayerFrame by proportion (power bar not found)"
	end
	bar:SetHeight(BAR_HEIGHT_PX * pixel)
	Render()
end

local XP_RATE_MIN_SECONDS = 60
local XP_LABEL_COLOR = { 1, 0.82, 0 }
local lastXP, lastXPMax

local WINDOW_SECONDS = 1800
local BREAK_MAX = 300
local GAP_CAP = 45
local GRIND_WEIGHT = 0.25

local QUEST_AVG_SECONDS = 1800
local MATCH_SECONDS = 3
local MAX_EVENTS = 400
local pendingLump

local function PlainNumber(v)
	if issecretvalue and issecretvalue(v) then return nil end
	if type(v) == "number" then return v end
	return nil
end

local function ReadXP()
	return PlainNumber(UnitXP("player")), PlainNumber(UnitXPMax("player"))
end

local function NewSession()
	return { start = time(), gained = 0, questXP = 0, events = {} }
end

local function XPSession()
	local db = KUI.db
	if not db then return nil end
	local session = db.xpSession
	if type(session) ~= "table" or type(session.start) ~= "number" or type(session.gained) ~= "number" then
		session = NewSession()
		db.xpSession = session
	end
	if type(session.events) ~= "table" then session.events = {} end
	if type(session.questXP) ~= "number" then session.questXP = 0 end
	return session
end

local function ResetXPSession()
	if not KUI.db then return end
	KUI.db.xpSession = NewSession()
	pendingLump = nil
	lastXP, lastXPMax = ReadXP()
end

local function RecordEvent(session, gain)
	local now = time()
	local gap = math.max(0, now - (session.lastEvent or session.start))

	local lumpPart = 0
	if pendingLump and GetTime() - pendingLump.at <= MATCH_SECONDS then
		lumpPart = math.min(gain, pendingLump.xp)
		pendingLump.xp = pendingLump.xp - lumpPart
		if pendingLump.xp <= 0 then pendingLump = nil end
	end
	session.questXP = session.questXP + lumpPart

	local kill = gain - lumpPart
	local active = 0
	if kill > 0 then
		if gap <= GAP_CAP then
			session.typicalGap = (session.typicalGap or 20) * 0.8 + gap * 0.2
			active = gap
		else
			active = session.typicalGap or 20
		end
	end

	local events = session.events
	events[#events + 1] = { t = now, kill = kill, quest = lumpPart, credit = math.min(gap, BREAK_MAX), active = active }
	session.lastEvent = now

	local credit = 0
	for i = #events, 1, -1 do
		local c = type(events[i]) == "table" and events[i].credit
		credit = credit + (type(c) == "number" and c or 0)
		if credit > WINDOW_SECONDS or #events - i >= MAX_EVENTS then
			for _ = 1, i - 1 do table.remove(events, 1) end
			break
		end
	end
end

local function OnQuestTurnedIn(xpReward)
	xpReward = PlainNumber(xpReward)
	if not xpReward or xpReward <= 0 then return end
	local session = XPSession()
	if not session then return end
	local events = session.events
	local last = events[#events]
	if type(last) == "table" and type(last.t) == "number" and type(last.kill) == "number"
		and time() - last.t <= MATCH_SECONDS and last.kill >= xpReward then
		last.kill = last.kill - xpReward
		last.quest = (last.quest or 0) + xpReward
		if last.kill <= 0 then last.active = 0 end
		session.questXP = session.questXP + xpReward
	else
		pendingLump = { xp = xpReward, at = GetTime() }
	end
end

local function TrackXPGain()
	local xp, xpMax = ReadXP()
	if not (xp and xpMax) then return end
	local session = XPSession()
	if session and lastXP then
		local gain
		if xp >= lastXP then
			gain = xp - lastXP
		elseif lastXPMax then
			gain = (lastXPMax - lastXP) + xp
		end
		if gain and gain > 0 then
			session.gained = session.gained + gain
			RecordEvent(session, gain)
		end
	end
	lastXP, lastXPMax = xp, xpMax
end

local function FormatHoursMinutes(seconds, roundUp)
	local minutes = seconds / 60
	minutes = roundUp and math.ceil(minutes) or math.floor(minutes)
	if minutes < 1 then return "<1 min" end
	local hours, mins = math.floor(minutes / 60), minutes % 60
	if hours == 0 then return mins .. " min" end
	if mins == 0 then return hours .. " h" end
	return string.format("%d h %d min", hours, mins)
end

local function XPRate()
	local session = KUI.db and KUI.db.xpSession
	if type(session) ~= "table" or type(session.start) ~= "number" or type(session.gained) ~= "number" then
		return nil, 0, 0
	end
	local now = time()
	local elapsed = now - session.start
	local events = type(session.events) == "table" and session.events or {}

	local kill, quest, credit, active = 0, 0, 0, 0
	for i = #events, 1, -1 do
		if credit >= WINDOW_SECONDS then break end
		local e = events[i]

		if type(e) == "table" and type(e.kill) == "number" and type(e.credit) == "number" and type(e.active) == "number" then
			kill, quest = kill + e.kill, quest + (type(e.quest) == "number" and e.quest or 0)
			credit, active = credit + e.credit, active + e.active
		end
	end

	credit = credit + math.min(math.max(0, now - (session.lastEvent or session.start)), BREAK_MAX)

	if credit < XP_RATE_MIN_SECONDS or kill + quest <= 0 then return nil, elapsed, session.gained end
	local killRate = kill / credit * 3600
	local questRate = quest / math.max(credit, QUEST_AVG_SECONDS) * 3600
	local grindRate = active > 0 and kill / active * 3600 or nil

	local blended = grindRate and (GRIND_WEIGHT * grindRate + (1 - GRIND_WEIGHT) * killRate) or killRate
	return blended + questRate, elapsed, session.gained, grindRate, killRate, questRate
end

local function AddRateLine(label, value)
	GameTooltip:AddDoubleLine(label, value, XP_LABEL_COLOR[1], XP_LABEL_COLOR[2], XP_LABEL_COLOR[3], 1, 1, 1)
end

local function ShowTooltip(self)
	local xp, xpMax = ReadXP()
	if not xp or not xpMax or xpMax <= 0 then return end

	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -TOOLTIP_GAP)
	GameTooltip:SetText("Experience", 1, 1, 1)
	GameTooltip:AddLine(string.format("%s / %s (%d%%)", FormatNumber(xp), FormatNumber(xpMax), math.floor(xp / xpMax * 100)), 1, 1, 1)
	local rested = PlainNumber(GetXPExhaustion and GetXPExhaustion())
	if rested and rested > 0 then
		GameTooltip:AddLine(string.format("Rested: +%s (%d%%)", FormatNumber(rested), math.floor(rested / xpMax * 100)), RESTED_TEXT_COLOR[1], RESTED_TEXT_COLOR[2], RESTED_TEXT_COLOR[3])
	end

	if not IsShiftKeyDown() then
		GameTooltip:Show()
		return
	end
	GameTooltip:AddLine(" ")
	local rate, elapsed, gained, grind, killRate, questRate = XPRate()
	if rate then
		AddRateLine("Kill XP/hr (grinding)", grind and FormatNumber(math.floor(grind + 0.5)) or "...")
		AddRateLine("Kill XP/hr (with travel)", FormatNumber(math.floor(killRate + 0.5)))
		AddRateLine("Quest XP/hr (smoothed)", FormatNumber(math.floor(questRate + 0.5)))
		AddRateLine("Estimated XP/hr", FormatNumber(math.floor(rate + 0.5)))
		AddRateLine("Time to level", FormatHoursMinutes((xpMax - xp) / rate * 3600, true))
	else
		AddRateLine("Estimated XP/hr", "gathering data...")
		AddRateLine("Time to level", "...")
	end
	local session = KUI.db and KUI.db.xpSession
	local questXP = type(session) == "table" and session.questXP or 0
	AddRateLine("This session", string.format("%s XP in %s", FormatNumber(gained), FormatHoursMinutes(elapsed, false)))
	if type(questXP) == "number" and questXP > 0 then
		AddRateLine("  from quests", FormatNumber(questXP))
	end
	GameTooltip:Show()
end

local function CreateBar()
	bar = CreateFrame("Frame", "KainUIForeverXPBar", _G.PlayerFrame)
	bar:SetFrameLevel(_G.PlayerFrame:GetFrameLevel() + 1)
	bar:EnableMouse(true)
	bar:SetHitRectInsets(-HOVER_PAD_X, -HOVER_PAD_X, -HOVER_PAD_Y, -HOVER_PAD_Y)

	local function MakeRows(count, layer, sublevel, color)
		local rows = {}
		for i = 1, count do
			local row = bar:CreateTexture(nil, layer, nil, sublevel)
			row:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
			rows[i] = row
		end
		return rows
	end

	bar.layers = {}
	local shapes = {
		{ grow = FRAME_PX, color = OUTLINE, sublevel = -3 },
		{ grow = BRONZE_PX, color = BRONZE, sublevel = -2 },
		{ grow = 0, color = BACKGROUND, sublevel = -1 },
	}
	for _, shape in ipairs(shapes) do
		local height = BAR_HEIGHT_PX + 2 * shape.grow
		table.insert(bar.layers, {
			grow = shape.grow,
			insets = PillInsets(height),
			rows = MakeRows(height, "BACKGROUND", shape.sublevel, shape.color),
		})
	end
	bar.restedRows = MakeRows(BAR_HEIGHT_PX, "ARTWORK", 0, RESTED_EXTENSION_COLOR)
	bar.fillRows = MakeRows(BAR_HEIGHT_PX, "ARTWORK", 1, XP_COLOR)
	bar.dividerRows = MakeRows(BAR_HEIGHT_PX, "ARTWORK", 2, DIVIDER_COLOR)

	bar:SetScript("OnSizeChanged", function() Render() end)

	local shiftWatcher = CreateFrame("Frame")
	shiftWatcher:SetScript("OnEvent", function(_, _, key)
		if issecretvalue and issecretvalue(key) then return end
		if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
		if bar:IsShown() and GameTooltip:IsOwned(bar) then pcall(ShowTooltip, bar) end
	end)
	bar:SetScript("OnEnter", function(self)
		pcall(shiftWatcher.RegisterEvent, shiftWatcher, "MODIFIER_STATE_CHANGED")
		ShowTooltip(self)
	end)
	bar:SetScript("OnLeave", function()
		shiftWatcher:UnregisterEvent("MODIFIER_STATE_CHANGED")
		GameTooltip:Hide()
	end)
end

local function DefaultShouldBeHidden()
	local db = KUI.db
	return barShowing and db and db.xpBarUnderPortrait and db.xpBarHideDefault
end

local function HideDefaultContainer(container)
	if InCombatLockdown() and container.IsProtected and container:IsProtected() then
		pendingAfterCombat = true
		return
	end
	container:Hide()
	defaultHiddenByUs = true
end

local function ApplyDefaultBar(shouldHide)
	local container = _G.MainStatusTrackingBarContainer
	if not IsFrame(container) then return end
	if shouldHide then
		if not defaultHooked then
			defaultHooked = true

			container:HookScript("OnShow", function(self)
				if DefaultShouldBeHidden() then HideDefaultContainer(self) end
			end)
		end
		if container:IsShown() then HideDefaultContainer(container) end
	elseif defaultHiddenByUs then

		defaultHiddenByUs = false
		if not container:IsShown() then container:Show() end
	end
end

local function Update(relayout)
	local db = KUI.db
	if not db then return end

	local wanted = db.xpBarUnderPortrait and IsFrame(_G.PlayerFrame) and PlayerHasXP()
	if not wanted then
		barShowing = false
		if bar then bar:Hide() end
		ApplyDefaultBar(false)
		return
	end

	if not bar then CreateBar() end

	if relayout or not bar.laidOut or UnitsPerPixel(bar) ~= bar.pixel then
		Layout()
		bar.laidOut = true
	end

	local xp, xpMax = UnitXP("player"), UnitXPMax("player")
	bar.fillFraction = math.max(0, math.min(1, xp / xpMax))

	local rested = GetXPExhaustion and GetXPExhaustion()
	local hasRested = rested ~= nil and rested > 0
	SetRowsColor(bar.fillRows, hasRested and XP_COLOR_RESTED or XP_COLOR)
	bar.restedFraction = hasRested and math.min(xp + rested, xpMax) / xpMax or nil
	bar.hasRested = hasRested

	RenderFill()
	bar:Show()
	barShowing = true
	ApplyDefaultBar(db.xpBarHideDefault and true or false)
end

local function SafeUpdate(relayout)
	local ok, err = pcall(Update, relayout)
	if not ok and not errorShown then
		errorShown = true
		print("|cffff6060Kain-UI Forever:|r the XP bar hit an error and will stay quiet about it: " .. tostring(err))
	end
end

function KUI:ApplyXPBar()
	SafeUpdate(true)
end

function KUI:SetXPBarUnderPortrait(enabled)
	if not KUI.db then return end
	KUI.db.xpBarUnderPortrait = enabled and true or false
	KUI:ApplyXPBar()
end

function KUI:SetHideDefaultXPBar(enabled)
	if not KUI.db then return end
	KUI.db.xpBarHideDefault = enabled and true or false
	KUI:ApplyXPBar()
end

function KUI:XPBarScanReport()
	local db = KUI.db or {}
	print("|cff33ff99Kain-UI Forever|r XP bar scan:")
	print(string.format("  option: %s, hide original: %s", db.xpBarUnderPortrait and "ON" or "OFF", db.xpBarHideDefault and "ON" or "OFF"))
	local xp, xpMax, rested = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion and GetXPExhaustion()
	print(string.format("  level %s of %s | XP %s / %s | rested %s | XP gain disabled: %s",
		tostring(UnitLevel("player")), tostring(GetMaxPlayerLevel and GetMaxPlayerLevel()),
		tostring(xp), tostring(xpMax), tostring(rested), tostring(IsXPUserDisabled and IsXPUserDisabled())))
	print("  XP applies to this character: " .. tostring(PlayerHasXP()))
	local rate, elapsed, gained, grind, killRate, questRate = XPRate()
	print(string.format("  this session: %s XP in %s | total XP/hr: %s (kills w/ travel %s, grinding %s, quests %s) | last reading: %s / %s",
		FormatNumber(gained), FormatHoursMinutes(elapsed, false),
		rate and FormatNumber(math.floor(rate + 0.5)) or "not enough data yet",
		killRate and FormatNumber(math.floor(killRate + 0.5)) or "n/a",
		grind and FormatNumber(math.floor(grind + 0.5)) or "n/a",
		questRate and FormatNumber(math.floor(questRate + 0.5)) or "n/a",
		tostring(lastXP), tostring(lastXPMax)))
	print("  fill: " .. ((rested and rested > 0) and "BLUE (rested XP banked)" or "purple (no rested XP)"))
	print("  player frame: " .. (IsFrame(_G.PlayerFrame) and "found" or "NOT FOUND"))
	print("  our bar: " .. (bar and (bar:IsShown() and "showing" or "created, hidden") or "not created") .. " -- " .. anchorNote)
	if bar and bar.widthPx then
		print(string.format("  shape: pill, %d x %d screen pixels inside a %d px frame (1 pixel = %.3f UI units)",
			bar.widthPx, BAR_HEIGHT_PX, FRAME_PX, bar.pixel))
	end

	for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
		local container = _G[name]
		if IsFrame(container) then
			local parts = {}
			for _, child in ipairs({ container:GetChildren() }) do
				table.insert(parts, string.format("%s%s", child.GetName and child:GetName() or (child.GetObjectType and child:GetObjectType()) or "?", child:IsShown() and "" or " (hidden)"))
			end
			print(string.format("  %s: %s%s; children: %s", name, container:IsShown() and "shown" or "hidden",
				(name == "MainStatusTrackingBarContainer" and defaultHiddenByUs) and " (hidden by Kain-UI)" or "",
				#parts > 0 and table.concat(parts, ", ") or "none"))
		else
			print("  " .. name .. ": not found")
		end
	end
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "QUEST_TURNED_IN" }) do
	KUI:SafeRegisterEvent(eventFrame, event)
end
for _, event in ipairs({ "DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "UPDATE_EXPANSION_LEVEL", "PLAYER_REGEN_ENABLED",
		"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(self, event, ...)

	if event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin = ...
		if isInitialLogin == true then
			ResetXPSession()
		elseif not lastXP then
			lastXP, lastXPMax = ReadXP()
		end
	elseif event == "PLAYER_XP_UPDATE" then
		TrackXPGain()
	elseif event == "QUEST_TURNED_IN" then
		local _, xpReward = ...
		OnQuestTurnedIn(xpReward)
		return
	end
	if not (KUI.db and KUI.db.xpBarUnderPortrait) and not defaultHiddenByUs then return end
	if event == "PLAYER_REGEN_ENABLED" and not pendingAfterCombat then return end
	pendingAfterCombat = false
	local relayout = event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP"
		or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED"
	SafeUpdate(relayout)

	if bar and bar:IsShown() and GameTooltip:IsOwned(bar) then pcall(ShowTooltip, bar) end
end)

function KUI:ResetXPSession()
	ResetXPSession()
	print("|cff33ff99Kain-UI Forever:|r XP per hour restarted from now.")
end
