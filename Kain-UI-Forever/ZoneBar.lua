local _, KUI = ...

local DEFAULT_POSITION = { from = "TOP", dy = -6 }
local ROW_SLACK = 8

local bar
local active = false

local originals = {}

local vanilla = {}

local function Capture(frame)
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	return { parent = frame:GetParent(), points = points, alpha = frame:GetAlpha(), level = frame:GetFrameLevel(),
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
	if o.level and frame.SetFrameLevel then frame:SetFrameLevel(o.level) end
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
		f:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", MailOffset())
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

local layout = {}
local origin
local skipped = {}

local function Num(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end

local function BoxInCluster(f)
	local cluster = MinimapCluster
	local cl, ct = cluster:GetLeft(), cluster:GetTop()
	local l, t, r, b = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom()
	if not (Num(cl) and Num(ct) and Num(l) and Num(t) and Num(r) and Num(b)) then return nil end
	local k = f:GetEffectiveScale() / cluster:GetEffectiveScale()
	return { l * k - cl, t * k - ct, r * k - cl, b * k - ct }
end

local function Learn(f)
	if not f or layout[f] or (bar and f:GetParent() == bar) then return end

	if f:GetNumPoints() == 0 then skipped[f] = "no anchors (not drawn)"; return end
	local box = BoxInCluster(f)
	if not box then skipped[f] = "no position yet"; return end
	local header = Cluster("ZoneTextButton")
	if f ~= header then
		local hb = header and layout[header]
		if not hb then skipped[f] = "header button not learned yet"; return end
		local mid = (box[2] + box[4]) / 2
		if not f:IsShown() or (box[3] - box[1]) <= 0 then skipped[f] = "not shown"; return end
		if mid > hb[2] + ROW_SLACK or mid < hb[4] - ROW_SLACK then skipped[f] = "not on the header's row"; return end
	end
	box[5] = f:GetFrameLevel() - MinimapCluster:GetFrameLevel()
	layout[f] = box
	skipped[f] = nil
	if origin then
		origin = { math.min(origin[1], box[1]), math.max(origin[2], box[2]), math.max(origin[3], box[3]), math.min(origin[4], box[4]) }
	else
		origin = { box[1], box[2], box[3], box[4] }
	end
end

local PIECES = {
	{ get = function() return Cluster("ZoneTextButton") end, mode = "carry" },
	{ get = function() return Cluster("BorderTop") end, mode = "carry" },
	{ get = function() return _G.TimeManagerClockButton end, mode = "carry" },
	{ get = function() return Cluster("Tracking") end, mode = "carry" },
	{ get = function() return _G.GameTimeFrame end, mode = "carry" },
	{ get = function() return Cluster("IndicatorFrame") end, mode = "move",
		place = function(f) PlaceMail(f) end },
	{ get = function() return Cluster("InstanceDifficulty") end, mode = "move",

		skip = function() return KUI.db and KUI.db.guildDifficultyForced ~= false end,
		place = function(f) f:SetPoint("TOPRIGHT", bar, "BOTTOMLEFT", -2, -3) end },
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

local function SizeBar()
	if not (bar and origin and MinimapCluster) then return end
	local scale = MinimapCluster:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if Num(scale) and scale > 0 and math.abs(bar:GetScale() - scale) > 0.001 then bar:SetScale(scale) end
	local w, h = origin[3] - origin[1], origin[2] - origin[4]
	if math.abs(bar:GetWidth() - w) > 0.01 or math.abs(bar:GetHeight() - h) > 0.01 then bar:SetSize(w, h) end
end

local ApplyPosition

local function PlacePieces()
	if not active or not bar then return end
	placing = true
	local before = origin and { origin[1], origin[2], origin[3], origin[4] }
	for _, piece in ipairs(PIECES) do
		local f = piece.get()
		if f and piece.mode == "carry" then Learn(f) end
	end
	if origin and (not before or before[1] ~= origin[1] or before[2] ~= origin[2] or before[3] ~= origin[3] or before[4] ~= origin[4]) then
		SizeBar()
		if ApplyPosition then ApplyPosition() end
	end
	for _, piece in ipairs(PIECES) do
		local f = piece.get()
		if f and not (piece.skip and piece.skip()) then
			if piece.mode == "carry" then
				local box = layout[f]
				if box and origin then
					Remember(f)
					if f:GetParent() ~= bar then f:SetParent(bar) end
					f:ClearAllPoints()
					f:SetPoint("TOPLEFT", bar, "TOPLEFT", box[1] - origin[1], box[2] - origin[2])
					f:SetPoint("BOTTOMRIGHT", bar, "TOPLEFT", box[3] - origin[1], box[4] - origin[2])
					f:SetFrameLevel(bar:GetFrameLevel() + math.max(1, box[5] or 1))
				end
			elseif piece.mode == "move" then
				Remember(f)
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

function ApplyPosition()
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

local function BuildBar()
	bar = CreateFrame("Frame", "KainUIForeverZoneBar", UIParent)
	bar:SetSize(200, 20)
	bar:SetFrameStrata("MEDIUM")
	bar:SetFrameLevel(20)
	bar:SetMovable(true)
	bar:SetClampedToScreen(false)

	local grip = CreateFrame("Frame", nil, bar)
	grip:SetAllPoints()
	grip:SetFrameLevel(bar:GetFrameLevel() + 50)
	grip:EnableMouse(true)
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", StartDrag)
	grip:SetScript("OnDragStop", StopDrag)
	local tint = grip:CreateTexture(nil, "OVERLAY")
	tint:SetAllPoints()
	tint:SetColorTexture(0.2, 0.85, 0.3, 0.35)
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Zone bar", 1, 1, 1)
		GameTooltip:AddLine("Drag to move. Lock the minimap elements to use it again.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	grip:Hide()
	bar.grip = grip

	local events = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED", "ADDON_LOADED" }) do
		KUI:SafeRegisterEvent(events, e)
	end
	events:SetScript("OnEvent", function(_, event)
		if not active then return end

		WatchPieces()
		ScheduleFix()
		if event ~= "ADDON_LOADED" then
			SizeBar()
			ApplyPosition()
		end
	end)

	if MinimapCluster and MinimapCluster.SetHeaderUnderneath then
		hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", ScheduleFix)
	end
end

function KUI:RefitZoneBar()
	if active then pcall(SizeBar) end
end

local tries = 0
local function Activate()
	if not active then return end
	PlacePieces()
	local header = Cluster("ZoneTextButton")
	if header and not layout[header] and tries < 50 then
		tries = tries + 1
		C_Timer.After(0.2, Activate)
		return
	end
	SizeBar()
	ApplyPosition()
	PlacePieces()
end

function KUI:ApplyZoneBar(enabled)
	if enabled then
		if not MinimapCluster then return end
		if not bar then BuildBar() end
		active = true
		bar:Show()
		WatchPieces()
		tries = 0
		Activate()
		ScheduleMailConversion()
		KUI:SetZoneBarUnlocked(Unlocked())
		if MinimapCluster.HookScript and not bar.clusterHooked then
			bar.clusterHooked = true
			MinimapCluster:HookScript("OnSizeChanged", function() if active then pcall(SizeBar) end end)
		end
	else
		if not active then return end
		active = false
		if bar then bar:Hide() end
		for frame in pairs(originals) do Restore(frame) end
	end
end

function KUI:ZoneBarScanReport()
	print("|cff33ff99Kain-UI Forever|r zone bar: " .. (active and "ACTIVE (carrying Blizzard's header)" or "off (Blizzard's header)")
		.. (origin and string.format(" | bar %.0f x %.0f", origin[3] - origin[1], origin[2] - origin[4]) or " | header not learned yet"))
	for index, piece in ipairs(PIECES) do
		local ok, f = pcall(piece.get)
		if ok and f then
			local name = (f.GetName and f:GetName()) or ("piece " .. index)
			local parent = f:GetParent()
			local pname = parent and ((parent == bar and "zone bar") or (parent.GetName and parent:GetName()) or "unnamed") or "none"
			local box = layout[f]
			local learned = box and string.format("at %.1f, %.1f size %.1f x %.1f", box[1] - (origin and origin[1] or 0), box[2] - (origin and origin[2] or 0), box[3] - box[1], box[2] - box[4])
				or (piece.mode == "carry" and ("NOT CARRIED: " .. (skipped[f] or "not seen yet")) or "")
			print(string.format("  %s (%s): parent %s, anchors %d, alpha %.2f, shown %s, visible %s | %s",
				name, piece.mode, pname, f:GetNumPoints(), f:GetAlpha(), tostring(f:IsShown()), tostring(f:IsVisible()), learned))
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
	bar.grip:SetShown(unlocked and true or false)
	UpdateMailHandle()
end

function KUI:ResetZoneBarPosition()
	if KUI.db and KUI.db.framePositions then KUI.db.framePositions.zonebar = nil end
	if bar then ApplyPosition() end
end
