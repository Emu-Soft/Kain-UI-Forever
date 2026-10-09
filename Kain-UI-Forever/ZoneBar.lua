local _, KUI = ...

local PILL_WIDTH = 200
local MIN_PILL_WIDTH = 100
local WIDTH_ADJUST = 0
local PILL_HEIGHT = 20
local SIDE_GAP = 3
local SHADOW = 2
local PILL_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local PILL_TOP = { 0.05, 0.11, 0.13, 0.92 }
local PILL_BOTTOM = { 0.01, 0.04, 0.05, 0.92 }
local SHADOW_COLOR = { 0, 0, 0, 0.35 }

local DEFAULT_POSITION = { from = "TOP", dy = -6 }

local bar
local active = false
local FitToMinimap

local function Tint(tex, top, bottom)
	tex:SetTexture("Interface\\Buttons\\WHITE8x8")
	local ok = false
	if tex.SetGradient and CreateColor then
		ok = pcall(tex.SetGradient, tex, "VERTICAL",
			CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
			CreateColor(top[1], top[2], top[3], top[4]))
	end
	if not ok then
		tex:SetVertexColor((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2,
			(top[3] + bottom[3]) / 2, top[4])
	end
end

local function MakePill(parent, width, height, level, top, bottom)
	local r = math.floor(height / 2 + 0.5)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	holder:SetPoint("CENTER")
	holder:SetFrameLevel(parent:GetFrameLevel() + level)
	local layer, sublevel = "BACKGROUND", 0

	local canRound = holder.CreateMaskTexture ~= nil
	local left = holder:CreateTexture(nil, layer, nil, sublevel)
	local right = holder:CreateTexture(nil, layer, nil, sublevel)
	local mid = holder:CreateTexture(nil, layer, nil, sublevel)
	for _, t in ipairs({ left, right, mid }) do Tint(t, top, bottom) end

	if canRound then
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT")
		left:SetWidth(r)
		right:SetPoint("TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT")
		right:SetWidth(r)
		for _, pair in ipairs({ { left, "LEFT" }, { right, "RIGHT" } }) do
			local mask = holder:CreateMaskTexture()
			mask:SetTexture(PILL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetPoint(pair[2], pair[1], pair[2])
			mask:SetSize(height, height)
			pair[1]:AddMaskTexture(mask)
		end
		mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
		mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	else
		left:Hide()
		right:Hide()
		mid:SetAllPoints()
	end
	return holder
end

local function ZonePvPType()
	if C_PvP and C_PvP.GetZonePVPInfo then return C_PvP.GetZonePVPInfo() end
	if GetZonePVPInfo then return GetZonePVPInfo() end
end

local function ZoneColor(pvpType)
	if pvpType == "sanctuary" then return 0.41, 0.8, 0.94 end
	if pvpType == "arena" or pvpType == "hostile" or pvpType == "combat" then return 1, 0.1, 0.1 end
	if pvpType == "friendly" then return 0.1, 1, 0.1 end
	if pvpType == "contested" then return 1, 0.7, 0 end
	return 1, 0.82, 0
end

local function UpdateZone()
	if not bar then return end
	local text = (GetMinimapZoneText and GetMinimapZoneText()) or ""
	bar.zoneText:SetText(text)
	bar.zoneText:SetTextColor(ZoneColor(ZonePvPType()))
end

local function ClockString()
	if GameTime_GetTime then
		local ok, t = pcall(GameTime_GetTime, false)
		if ok and t then return t end
	end
	return date("%H:%M")
end

local function UpdateClock()
	if bar then bar.clockText:SetText(ClockString()) end
end

local hider = CreateFrame("Frame")
hider:Hide()

local originals = {}

local vanilla = {}

local function Capture(frame)
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	return { parent = frame:GetParent(), points = points, alpha = frame:GetAlpha(),
		mouse = frame.IsMouseEnabled and frame:IsMouseEnabled(), shown = frame:IsShown() }
end

local function Remember(frame)
	if not frame or originals[frame] then return end
	local v = vanilla[frame]
	originals[frame] = (v and #v.points > 0) and v or Capture(frame)
end

local function Restore(frame)
	local o = originals[frame]
	if not o then return end
	frame:SetParent(o.parent)

	if #o.points > 0 then
		frame:ClearAllPoints()
		for _, p in ipairs(o.points) do frame:SetPoint(unpack(p)) end
	end
	frame:SetAlpha(o.alpha or 1)
	if o.shown then frame:Show() end
	if o.mouse ~= nil and frame.EnableMouse then frame:EnableMouse(o.mouse) end
	originals[frame] = nil
end

local function Cluster(key) return MinimapCluster and MinimapCluster[key] end

local MAIL_DEFAULT = { x = 0, y = -3 }
local function MailOffset()
	local p = KUI.db and KUI.db.mailIconPos
	if p and type(p.x) == "number" and type(p.y) == "number" then return p.x, p.y end
	return MAIL_DEFAULT.x, MAIL_DEFAULT.y
end

local function MailScreenPos()
	local p = KUI.db and KUI.db.mailIconScreenPos
	if type(p) == "table" and type(p.left) == "number" and type(p.top) == "number" then return p.left, p.top end
end

local function ScreenRatio(f)
	local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if not ratio or ratio <= 0 then ratio = 1 end
	return ratio
end

local function PlaceMail(f)
	local left, top = MailScreenPos()
	if left then
		local ratio = ScreenRatio(f)
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / ratio, top / ratio)
	else
		f:SetPoint("TOPLEFT", bar.pill, "BOTTOMLEFT", MailOffset())
	end
end

local function ConvertMailToScreen()
	if not KUI.db or MailScreenPos() then return end
	local indicator = Cluster("IndicatorFrame")
	if not indicator then return end
	local left, top = indicator:GetLeft(), indicator:GetTop()
	if type(left) ~= "number" or type(top) ~= "number" then return end
	local ratio = ScreenRatio(indicator)
	KUI.db.mailIconScreenPos = { left = math.floor(left * ratio * 10 + 0.5) / 10, top = math.floor(top * ratio * 10 + 0.5) / 10 }
end

local ScheduleMailConversion

local PIECES = {
	{ get = function() return Cluster("BorderTop") end, mode = "hide" },
	{ get = function() return Cluster("ZoneTextButton") end, mode = "hide" },
	{ get = function() return _G.TimeManagerClockButton end, mode = "invisible" },
	{ get = function() return Cluster("Tracking") end, mode = "move",
		place = function(f) f:SetPoint("RIGHT", bar.pill, "LEFT", -SIDE_GAP, 0) end },
	{ get = function() return _G.GameTimeFrame end, mode = "move",
		place = function(f) f:SetPoint("LEFT", bar.pill, "RIGHT", SIDE_GAP, 0) end },
	{ get = function() return Cluster("IndicatorFrame") end, mode = "move",
		place = function(f) PlaceMail(f) end },
	{ get = function() return Cluster("InstanceDifficulty") end, mode = "move",

		skip = function() return KUI.db and KUI.db.guildDifficultyForced ~= false end,
		place = function(f) f:SetPoint("TOPRIGHT", bar.pill, "BOTTOMLEFT", -2, -3) end },
}

local function SnapshotVanilla(onlyMissing)
	for _, piece in ipairs(PIECES) do
		local ok, f = pcall(piece.get)
		if ok and f and f.GetNumPoints and not originals[f] then
			local v = vanilla[f]
			if not onlyMissing or not v or #v.points == 0 then vanilla[f] = Capture(f) end
		end
	end
end
SnapshotVanilla(false)
do
	local snapFrame = CreateFrame("Frame")
	KUI:SafeRegisterEvent(snapFrame, "PLAYER_ENTERING_WORLD")
	snapFrame:SetScript("OnEvent", function(self)
		SnapshotVanilla(true)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end)
end

local placing = false

local function PlacePieces()
	if not active or not bar then return end
	placing = true
	for _, piece in ipairs(PIECES) do
		local f = piece.get()
		if f and not (piece.skip and piece.skip()) then
			Remember(f)
			if piece.mode == "hide" then
				if f:GetParent() ~= hider then f:SetParent(hider) end
			elseif piece.mode == "invisible" then
				f:SetAlpha(0)
				if f.EnableMouse then f:EnableMouse(false) end
			elseif piece.mode == "move" then
				if f:GetParent() ~= bar then f:SetParent(bar) end
				f:ClearAllPoints()
				piece.place(f)
				f:SetFrameLevel(bar:GetFrameLevel() + 5)
			end
		end
	end
	placing = false
end

function ScheduleMailConversion()
	local function Run()
		local had = (KUI.db and KUI.db.mailIconScreenPos) ~= nil
		pcall(ConvertMailToScreen)
		if not had and KUI.db and KUI.db.mailIconScreenPos and active then PlacePieces() end
	end
	if C_Timer and C_Timer.After then C_Timer.After(1, Run) else Run() end
end

local pendingFix = false
local function ScheduleFix()
	if placing or not active or pendingFix then return end
	pendingFix = true
	C_Timer.After(0, function()
		pendingFix = false
		PlacePieces()
	end)
end

local watched = {}
local function WatchPieces()
	for _, piece in ipairs(PIECES) do
		local f = piece.get()
		if f and not watched[f] and not (piece.skip and piece.skip()) then
			watched[f] = true
			hooksecurefunc(f, "SetPoint", ScheduleFix)
			hooksecurefunc(f, "SetParent", ScheduleFix)
			if piece.mode == "invisible" then hooksecurefunc(f, "SetAlpha", ScheduleFix) end
		end
	end
end

local function Unlocked()
	return KUI.db and KUI.db.headerBarUnlocked and true or false
end

local function SavePosition()
	if not KUI.db then return end
	local left, top = bar:GetLeft(), bar:GetTop()
	if not left then return end
	local ratio = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
	KUI.db.framePositions = KUI.db.framePositions or {}
	KUI.db.framePositions.zonebar = { cx = (left + bar:GetWidth() / 2) * ratio, y = top * ratio }
end

local function ApplyPosition()
	local ratio = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local pos = KUI.db and KUI.db.framePositions and KUI.db.framePositions.zonebar

	if pos and pos.cx == nil and pos.x then
		pos.cx = pos.x + bar:GetWidth() / 2 * ratio
		pos.x = nil
	end
	if not pos and KUI.ResolveScreenPosition then
		local def = KUI:ResolveScreenPosition({ from = DEFAULT_POSITION.from, dx = 0, dy = DEFAULT_POSITION.dy })
		pos = def and { cx = def.x, y = def.y }
	end
	if not pos then return end
	bar:ClearAllPoints()
	bar:SetPoint("TOP", UIParent, "BOTTOMLEFT", pos.cx / ratio, pos.y / ratio)
end

local function StartDrag()
	if Unlocked() then
		bar:StartMoving()
		if KUI.BeginAlignDrag then KUI:BeginAlignDrag(bar) end
	end
end
local function StopDrag()
	bar:StopMovingOrSizing()
	if KUI.EndAlignDrag then KUI:EndAlignDrag(bar) end
	if bar.SetUserPlaced then bar:SetUserPlaced(false) end
	SavePosition()
	ApplyPosition()
end

local function BarButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetFrameLevel(parent:GetFrameLevel() + 5)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", StartDrag)
	b:SetScript("OnDragStop", StopDrag)
	return b
end

local function BuildBar()
	bar = CreateFrame("Frame", "KainUIForeverZoneBar", UIParent)
	bar:SetSize(PILL_WIDTH, PILL_HEIGHT)
	bar:SetFrameStrata("MEDIUM")
	bar:SetFrameLevel(20)
	bar:SetMovable(true)
	bar:SetClampedToScreen(false)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", StartDrag)
	bar:SetScript("OnDragStop", StopDrag)

	bar.unlockTint = MakePill(bar, PILL_WIDTH + 6, PILL_HEIGHT + 6, 0,
		{ 0.2, 0.85, 0.3, 0.35 }, { 0.2, 0.85, 0.3, 0.35 })
	bar.shadow = MakePill(bar, PILL_WIDTH + SHADOW * 2, PILL_HEIGHT + SHADOW * 2, 1,
		SHADOW_COLOR, SHADOW_COLOR)

	bar.pill = MakePill(bar, PILL_WIDTH, PILL_HEIGHT, 2, PILL_TOP, PILL_BOTTOM)

	local clock = BarButton(bar)
	clock:SetPoint("TOPRIGHT", bar.pill, "TOPRIGHT", -8, 0)
	clock:SetPoint("BOTTOMRIGHT", bar.pill, "BOTTOMRIGHT", -8, 0)
	clock:SetWidth(44)
	local clockText = clock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	clockText:SetPoint("RIGHT")
	clockText:SetJustifyH("RIGHT")
	bar.clockText = clockText
	clock:SetScript("OnClick", function()
		if not _G.TimeManager_Toggle and C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
		end
		if _G.TimeManager_Toggle then TimeManager_Toggle() end
	end)
	clock:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine(TIMEMANAGER_TITLE or "Clock")
		if GameTime_GetLocalTime and GameTime_GetGameTime then
			GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME or "Local time:", GameTime_GetLocalTime(true), 1, 0.82, 0, 1, 1, 1)
			GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME or "Realm time:", GameTime_GetGameTime(true), 1, 0.82, 0, 1, 1, 1)
		end
		GameTooltip:AddLine("Click to show the clock options.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	clock:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local zone = BarButton(bar)
	zone:SetPoint("TOPLEFT", bar.pill, "TOPLEFT", 10, 0)
	zone:SetPoint("BOTTOMRIGHT", clock, "BOTTOMLEFT", -6, 0)
	local zoneText = zone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	zoneText:SetPoint("LEFT")
	zoneText:SetPoint("RIGHT")
	zoneText:SetJustifyH("LEFT")
	zoneText:SetWordWrap(false)
	bar.zoneText = zoneText
	zone:SetScript("OnClick", function()
		if ToggleWorldMap then ToggleWorldMap() end
	end)
	zone:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		if Minimap_SetTooltip then
			pcall(Minimap_SetTooltip, ZonePvPType())
		else

			local real = GetRealZoneText and GetRealZoneText()
			if type(real) ~= "nil" then GameTooltip:AddLine(real, 1, 1, 1) end
			local sub = GetSubZoneText and GetSubZoneText()
			if issecretvalue and issecretvalue(sub) then
				GameTooltip:AddLine(sub, 1, 0.82, 0)
			elseif type(sub) == "string" and sub ~= "" then
				GameTooltip:AddLine(sub, 1, 0.82, 0)
			end
		end
		GameTooltip:Show()
	end)
	zone:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local elapsed = 0
	bar:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then
			elapsed = 0
			UpdateClock()
		end
	end)

	local events = CreateFrame("Frame")
	for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
		"PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED", "ADDON_LOADED" }) do
		KUI:SafeRegisterEvent(events, e)
	end
	events:SetScript("OnEvent", function(_, event)
		if not active then return end
		UpdateZone()
		if event ~= "ZONE_CHANGED" and event ~= "ZONE_CHANGED_INDOORS" then

			WatchPieces()
			ScheduleFix()
			if event ~= "ADDON_LOADED" then ApplyPosition() end
			C_Timer.After(0, FitToMinimap)
		end
	end)

	if MinimapCluster and MinimapCluster.SetHeaderUnderneath then
		hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", ScheduleFix)
	end
end

local function MinimapVisibleWidth()
	if not Minimap then return nil end

	local square = KUI.SquareMinimapBorder
	if square and square:IsShown() and square:GetWidth() > 0 then
		return square:GetWidth() * square:GetEffectiveScale() / bar:GetEffectiveScale()
	end
	local ring = _G.MinimapCompassTexture or _G.MinimapBorder
	local source = ring and ring.GetWidth and ring:GetWidth() > 0 and ring or Minimap
	local width = source:GetWidth()
	if not width or width <= 0 then return nil end
	local scale = source:GetEffectiveScale() / bar:GetEffectiveScale()
	return width * scale
end

local function SideWidth(getPiece)
	local f = getPiece()
	if f and f:GetParent() == bar and f:IsShown() then return f:GetWidth() + SIDE_GAP end
	return 0
end

local function SetPillWidth(width)
	bar:SetWidth(width)
	bar.pill:SetWidth(width)
	bar.shadow:SetWidth(width + SHADOW * 2)
	bar.unlockTint:SetWidth(width + 6)
end

function KUI:RefitZoneBar()
	if FitToMinimap then pcall(FitToMinimap) end
end

function FitToMinimap()
	if not active or not bar then return end
	local total = MinimapVisibleWidth()
	if not total then return end
	local sides = SideWidth(function() return Cluster("Tracking") end)
		+ SideWidth(function() return _G.GameTimeFrame end)
	local width = math.max(MIN_PILL_WIDTH, math.floor(total + WIDTH_ADJUST - sides + 0.5))
	if math.abs(bar:GetWidth() - width) < 0.5 then return end
	SetPillWidth(width)
end

function KUI:ApplyZoneBar(enabled)
	if enabled then
		if not MinimapCluster then return end
		if not bar then BuildBar() end
		active = true
		bar:Show()
		ApplyPosition()
		UpdateZone()
		UpdateClock()
		WatchPieces()
		PlacePieces()
		ScheduleMailConversion()
		FitToMinimap()
		KUI:SetZoneBarUnlocked(Unlocked())

		if Minimap and not bar.minimapSizeHooked then
			bar.minimapSizeHooked = true
			Minimap:HookScript("OnSizeChanged", function() if active then FitToMinimap() end end)
		end
	else
		if not active then return end
		active = false
		if bar then bar:Hide() end
		for frame in pairs(originals) do Restore(frame) end
	end
end

function KUI:ZoneBarScanReport()
	print("|cff33ff99Kain-UI Forever|r zone bar: " .. (active and "ACTIVE (header pieces taken over)" or "off (Blizzard's header)"))
	for index, piece in ipairs(PIECES) do
		local ok, f = pcall(piece.get)
		if ok and f then
			local name = (f.GetName and f:GetName()) or ("piece " .. index)
			local parent = f:GetParent()
			local pname = parent and ((parent == bar and "zone bar") or (parent.GetName and parent:GetName()) or "unnamed") or "none"
			local v = vanilla[f]
			print(string.format("  %s (%s): parent %s, anchors %d, alpha %.2f, shown %s, visible %s | recorded anchors %s",
				name, piece.mode, pname, f:GetNumPoints(), f:GetAlpha(), tostring(f:IsShown()), tostring(f:IsVisible()),
				v and tostring(#v.points) or "none"))
		else
			print("  piece " .. index .. ": not found on this client")
		end
	end
end

function KUI:IsZoneBarActive()
	return active
end

local mailHandle

local function EnsureMailHandle()
	if mailHandle or not bar then return mailHandle end
	local indicator = Cluster("IndicatorFrame")
	if not indicator then return nil end
	local mail = indicator.MailFrame or _G.MiniMapMailFrame
	local h = CreateFrame("Frame", "KainUIForeverMailHandle", bar, "BackdropTemplate")
	h:SetFrameLevel(bar:GetFrameLevel() + 20)
	h:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
	local w = (mail and mail:GetWidth() > 0) and mail:GetWidth() or 22
	local hgt = (mail and mail:GetHeight() > 0) and mail:GetHeight() or 22
	h:SetSize(w, hgt)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	if h.SetBackdrop then
		h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		h:SetBackdropColor(0.2, 0.6, 1, 0.35)
		h:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
	end

	local dragging, startCX, startCY, startLeft, startTop
	local function MoveTo()
		if not startLeft then return end
		local cx, cy = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		local left = startLeft + (cx - startCX) / scale
		local top = startTop + (cy - startCY) / scale
		if KUI.db then KUI.db.mailIconScreenPos = { left = math.floor(left * 10 + 0.5) / 10, top = math.floor(top * 10 + 0.5) / 10 } end
		PlacePieces()
	end
	h:SetScript("OnDragStart", function()
		startCX, startCY = GetCursorPosition()
		startLeft, startTop = MailScreenPos()
		if not startLeft then

			local l, t = indicator:GetLeft(), indicator:GetTop()
			if type(l) == "number" and type(t) == "number" then
				local ratio = ScreenRatio(indicator)
				startLeft, startTop = l * ratio, t * ratio
			end
		end
		dragging = startLeft ~= nil
	end)
	h:SetScript("OnUpdate", function() if dragging then MoveTo() end end)
	h:SetScript("OnDragStop", function() dragging = false; MoveTo() end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Mail indicator", 1, 1, 1)
		GameTooltip:AddLine("Drag to move. /kainui mailpos prints its position.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", function() GameTooltip:Hide() end)
	h:Hide()
	mailHandle = h
	return h
end

local function UpdateMailHandle()
	if active and Unlocked() then
		local h = EnsureMailHandle()
		if h then h:Show() end
	elseif mailHandle then
		mailHandle:Hide()
	end
end

function KUI:SetMailIconPosition(x, y)
	if not KUI.db or type(x) ~= "number" or type(y) ~= "number" then return end
	KUI.db.mailIconPos = { x = x, y = y }
	KUI.db.mailIconScreenPos = nil
	PlacePieces()
	ScheduleMailConversion()
end

function KUI:SetMailIconScreenPosition(left, top)
	if not KUI.db or type(left) ~= "number" or type(top) ~= "number" then return end
	KUI.db.mailIconScreenPos = { left = left, top = top }
	PlacePieces()
end

function KUI:SetZoneBarUnlocked(unlocked)
	if not bar then return end
	bar.unlockTint:SetShown(unlocked and true or false)
	UpdateMailHandle()
end

function KUI:ResetZoneBarPosition()
	if KUI.db and KUI.db.framePositions then KUI.db.framePositions.zonebar = nil end
	if bar then ApplyPosition() end
end
