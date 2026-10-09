local _, KUI = ...

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"

local ROUND_MASK = 186178
local roundMaskSource = "classic minimap mask by file ID 186178 (confirmed in game with /kainui masktest)"
if _G.Minimap and type(_G.Minimap.GetMaskTexture) == "function" then
	local ok, mask = pcall(_G.Minimap.GetMaskTexture, _G.Minimap)
	if ok and mask ~= nil and not (issecretvalue and issecretvalue(mask)) and mask ~= "" then
		ROUND_MASK, roundMaskSource = mask, "read from the client at load (" .. tostring(mask) .. ")"
	end
end

local MASK_CANDIDATES = {
	{ mask = 186178, label = "Textures\\MinimapMask by file ID 186178" },
	{ mask = "Interface\\CharacterFrame\\TempPortraitAlphaMask", label = "Interface\\CharacterFrame\\TempPortraitAlphaMask" },
	{ mask = "Interface\\Masks\\CircleMask", label = "Interface\\Masks\\CircleMask" },
	{ mask = "Interface\\Masks\\CircleMaskScalable", label = "Interface\\Masks\\CircleMaskScalable (the current one)" },
}
local maskTestIndex = 0
function KUI:MaskTest()
	if not (Minimap and Minimap.SetMaskTexture) then return end
	maskTestIndex = maskTestIndex % #MASK_CANDIDATES + 1
	local c = MASK_CANDIDATES[maskTestIndex]
	local ok, err = pcall(Minimap.SetMaskTexture, Minimap, c.mask)
	print(string.format("|cff33ff99Kain-UI Forever|r mask test %d of %d: %s%s -- run again for the next; /reload restores Blizzard's.",
		maskTestIndex, #MASK_CANDIDATES, c.label, ok and "" or (" (failed: " .. tostring(err) .. ")")))
end

local BORDER_SCALE = 0.5
local BORDER_OUTSET = 4

local LEFT_EXTRA_OUTSET = 3

local LEFT_COVER_PX = -1

local function OnePixel()

	if type(GetPhysicalScreenSize) ~= "function" then return 1 end
	local _, physicalHeight = GetPhysicalScreenSize()
	local scale = Minimap:GetEffectiveScale()
	if not physicalHeight or physicalHeight <= 0 or not scale or scale <= 0 then return 1 end
	return 768 / physicalHeight / scale
end

local CORNERS = {
	{ point = "TOPLEFT", atlas = "UI-Frame-Metal-CornerBottomLeft", flip = true },
	{ point = "TOPRIGHT", atlas = "UI-Frame-Metal-CornerBottomRight", flip = true },
	{ point = "BOTTOMLEFT", atlas = "UI-Frame-Metal-CornerBottomLeft" },
	{ point = "BOTTOMRIGHT", atlas = "UI-Frame-Metal-CornerBottomRight" },
}
local EDGE_TOP, EDGE_TOP_FLIP = "_UI-Frame-Metal-EdgeBottom", true

local FLIP_CORNER_NUDGE = 0
local EDGE_BOTTOM = "_UI-Frame-Metal-EdgeBottom"
local EDGE_LEFT, EDGE_RIGHT = "!UI-Frame-Metal-EdgeLeft", "!UI-Frame-Metal-EdgeRight"

local SHADOW_WIDTH = 6
local SHADOW_UNDER_METAL = 6
local SHADOW_ALPHA = 0.7

local SHADOW_SIDE_SHIFT = { left = 0, right = 2, top = 1, bottom = 0 }

local SHADOW_TOP_EXTRA_PX = 1

local SHADOW_CORNER_CLEAR_PX = 2

local SHADOW_SIDE_STRENGTH = { left = 1, right = 0.75, top = 1, bottom = 0.75 }

local LFG_EYE_NAMES = { "QueueStatusButton", "MiniMapLFGFrame", "LFGMinimapFrame", "QueueStatusMinimapButton" }
local RXP_ICON_NAMES = { "LibDBIcon10_RXPGuides", "LibDBIcon10_RestedXP" }

local FALLBACK_COLOR = { 0.55, 0.42, 0.18, 1 }
local FALLBACK_PX = 2

if KUI.defaults then KUI.defaults.squareMinimap = false end

local border
local active = false

local previousGetMinimapShape = _G.GetMinimapShape
local function SquareWanted()
	local db = KUI.db
	if type(db) ~= "table" and type(KainUIForeverDB) == "table" then db = KainUIForeverDB end
	return type(db) == "table" and db.squareMinimap == true
end
_G.GetMinimapShape = function(...)
	if SquareWanted() then return "SQUARE" end
	if type(previousGetMinimapShape) == "function" then return previousGetMinimapShape(...) end
	return "ROUND"
end

local dbIconHooked = false
local function RefreshMinimapButtons()
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if type(lib) ~= "table" then return end
	if type(lib.GetButtonList) == "function" and type(lib.Refresh) == "function" then
		local okList, names = pcall(lib.GetButtonList, lib)
		if okList and type(names) == "table" then
			for _, name in ipairs(names) do pcall(lib.Refresh, lib, name) end
		end
	end
	if not dbIconHooked and type(lib.Register) == "function" then
		dbIconHooked = true

		hooksecurefunc(lib, "Register", function(_, name)
			if type(name) == "string" and type(lib.Refresh) == "function" then
				pcall(lib.Refresh, lib, name)
			end
		end)
	end
end
local savedBlobScalars

local function AtlasExists(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function RoundRing()
	return _G.MinimapCompassTexture or _G.MinimapBorder
end

local function AtlasPiece(atlas, flip)
	local tex = border:CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(atlas, true)
	local w, h = tex:GetSize()
	tex:SetSize((w or 16) * BORDER_SCALE, (h or 16) * BORDER_SCALE)

	if flip and tex.GetTexCoord then
		local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = tex:GetTexCoord()
		if LRy then tex:SetTexCoord(LLx, LLy, ULx, ULy, LRx, LRy, URx, URy) end
	end
	return tex
end

local function BuildMetalBorder()
	local corner = {}
	for _, c in ipairs(CORNERS) do
		local tex = AtlasPiece(c.atlas, c.flip)
		local nudge = 0
		if c.flip then nudge = (c.point == "TOPLEFT") and FLIP_CORNER_NUDGE or -FLIP_CORNER_NUDGE end
		tex:SetPoint(c.point, border, c.point, nudge, 0)
		corner[c.point] = tex
	end

	local top = AtlasPiece(EDGE_TOP, EDGE_TOP_FLIP)
	top:SetPoint("TOPLEFT", corner.TOPLEFT, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", corner.TOPRIGHT, "TOPLEFT")

	if not EDGE_TOP_FLIP then top:SetHorizTile(true) end
	local bottom = AtlasPiece(EDGE_BOTTOM)
	bottom:SetPoint("BOTTOMLEFT", corner.BOTTOMLEFT, "BOTTOMRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", corner.BOTTOMRIGHT, "BOTTOMLEFT")
	bottom:SetHorizTile(true)
	local left = AtlasPiece(EDGE_LEFT)
	left:SetPoint("TOPLEFT", corner.TOPLEFT, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", corner.BOTTOMLEFT, "TOPLEFT")
	left:SetVertTile(true)
	local right = AtlasPiece(EDGE_RIGHT)
	right:SetPoint("TOPRIGHT", corner.TOPRIGHT, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", corner.BOTTOMRIGHT, "TOPRIGHT")
	right:SetVertTile(true)
	border.style = "metal (character window frame)"

	return { left = left:GetWidth(), right = right:GetWidth(), top = top:GetHeight(), bottom = bottom:GetHeight() }
end

local function BuildFallbackBorder()
	local c = FALLBACK_COLOR
	local function Line(p1, p2, w, h)
		local t = border:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(c[1], c[2], c[3], c[4])
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
	end
	Line("TOPLEFT", "TOPRIGHT", nil, FALLBACK_PX)
	Line("BOTTOMLEFT", "BOTTOMRIGHT", nil, FALLBACK_PX)
	Line("TOPLEFT", "BOTTOMLEFT", FALLBACK_PX, nil)
	Line("TOPRIGHT", "BOTTOMRIGHT", FALLBACK_PX, nil)
	border.style = "plain bronze (metal atlases not on this client)"
	return { left = FALLBACK_PX, right = FALLBACK_PX, top = FALLBACK_PX, bottom = FALLBACK_PX }
end

local function BuildShadow(inset)
	local clear = CreateColor and CreateColor(0, 0, 0, 0)
	local L, R, T, B = inset.left, inset.right, inset.top, inset.bottom

	local OFFSET = {
		TOPLEFT = { L, -T }, TOPRIGHT = { -R, -T },
		BOTTOMLEFT = { L, B }, BOTTOMRIGHT = { -R, B },
	}

	local cornerClear = SHADOW_CORNER_CLEAR_PX * OnePixel()
	local ALONG = {
		vertical = { TOPLEFT = { 0, -cornerClear }, TOPRIGHT = { 0, -cornerClear }, BOTTOMLEFT = { 0, cornerClear }, BOTTOMRIGHT = { 0, cornerClear } },
		horizontal = { TOPLEFT = { cornerClear, 0 }, BOTTOMLEFT = { cornerClear, 0 }, TOPRIGHT = { -cornerClear, 0 }, BOTTOMRIGHT = { -cornerClear, 0 } },
	}
	local function Strip(p1, p2, w, h, orientation, fromEdgeFirst, side)
		local strength = SHADOW_SIDE_STRENGTH[side] or 1

		local sideDark = CreateColor and CreateColor(0, 0, 0, SHADOW_ALPHA * strength)
		local t = border:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)

		local along = w and ALONG.vertical or ALONG.horizontal
		t:SetPoint(p1, Minimap, p1, OFFSET[p1][1] + along[p1][1], OFFSET[p1][2] + along[p1][2])
		t:SetPoint(p2, Minimap, p2, OFFSET[p2][1] + along[p2][1], OFFSET[p2][2] + along[p2][2])
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		if t.SetGradient and sideDark then

			if fromEdgeFirst then t:SetGradient(orientation, sideDark, clear)
			else t:SetGradient(orientation, clear, sideDark) end
		else
			t:SetColorTexture(0, 0, 0, SHADOW_ALPHA * 0.5)
		end
	end
	local W = SHADOW_WIDTH + SHADOW_UNDER_METAL
	Strip("TOPLEFT", "BOTTOMLEFT", W, nil, "HORIZONTAL", true, "left")
	Strip("TOPRIGHT", "BOTTOMRIGHT", W, nil, "HORIZONTAL", false, "right")
	Strip("BOTTOMLEFT", "BOTTOMRIGHT", nil, W, "VERTICAL", true, "bottom")
	Strip("TOPLEFT", "TOPRIGHT", nil, W, "VERTICAL", false, "top")
end

local function EnsureBorder()
	if border or not Minimap then return border end
	border = CreateFrame("Frame", "KainUIForeverSquareMinimapBorder", Minimap)
	border:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	local leftOutset = BORDER_OUTSET + LEFT_EXTRA_OUTSET - LEFT_COVER_PX * OnePixel()
	border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -leftOutset, BORDER_OUTSET)
	border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", BORDER_OUTSET, -BORDER_OUTSET)
	if AtlasExists(CORNERS[1].atlas) and AtlasExists(EDGE_TOP) then
		BuildMetalBorder()
	else
		BuildFallbackBorder()
	end

	local shift = SHADOW_SIDE_SHIFT
	BuildShadow({ left = -shift.left, right = -shift.right,
		top = -shift.top + SHADOW_TOP_EXTRA_PX * OnePixel(), bottom = -shift.bottom })
	border:Hide()
	return border
end

local function RefreshMap()
	if not (Minimap.GetZoom and Minimap.SetZoom) then return end
	local z = Minimap:GetZoom()
	local other = (z > 0) and (z - 1) or (z + 1)
	pcall(Minimap.SetZoom, Minimap, other)
	pcall(Minimap.SetZoom, Minimap, z)
end

local function SetBlobRings(on)
	if on then
		if savedBlobScalars then
			pcall(Minimap.SetArchBlobRingScalar, Minimap, savedBlobScalars.arch)
			pcall(Minimap.SetQuestBlobRingScalar, Minimap, savedBlobScalars.quest)
		end
		return
	end
	if not savedBlobScalars then
		local okA, arch = pcall(function() return Minimap:GetArchBlobRingScalar() end)
		local okQ, quest = pcall(function() return Minimap:GetQuestBlobRingScalar() end)
		savedBlobScalars = { arch = okA and arch or 1, quest = okQ and quest or 1 }
	end
	pcall(Minimap.SetArchBlobRingScalar, Minimap, 0)
	pcall(Minimap.SetQuestBlobRingScalar, Minimap, 0)
end

local function FirstFrame(names)
	for _, n in ipairs(names) do
		local f = _G[n]
		if f and f.GetHeight then return f, n end
	end
end

local eyeOriginalScale
local function ResizeLFGEye(enabled)
	local eye = FirstFrame(LFG_EYE_NAMES)
	if not eye or (InCombatLockdown() and eye.IsProtected and eye:IsProtected()) then return end
	if enabled then
		local rxp = FirstFrame(RXP_ICON_NAMES)
		if not rxp then return end
		local target = rxp:GetHeight() * rxp:GetEffectiveScale()

		local art = (eye.Eye and eye.Eye.GetHeight and eye.Eye) or eye
		local current = art:GetHeight() * art:GetEffectiveScale()
		if not (target and current) or target <= 0 or current <= 0 then return end
		eyeOriginalScale = eyeOriginalScale or eye:GetScale()
		eye:SetScale(eye:GetScale() * target / current)
	elseif eyeOriginalScale then
		eye:SetScale(eyeOriginalScale)
		eyeOriginalScale = nil
	end
end

local DIEL_DEFAULT = { x = -4, y = -4 }

local function DielPos()
	local p = KUI.db and KUI.db.dielPos
	if p and type(p.x) == "number" and type(p.y) == "number" then return p.x, p.y end
	return DIEL_DEFAULT.x, DIEL_DEFAULT.y
end

local diel, dielOriginal

local function FindDiel()
	if diel then return diel end
	for _, child in ipairs({ Minimap:GetChildren() }) do
		local okF, forbidden = pcall(function() return child:IsForbidden() end)
		if okF and not forbidden and child.Background and child.GetPoint then
			local okP, point, rel, relPoint, x, y = pcall(child.GetPoint, child, 1)
			if okP and point == "CENTER" and rel == Minimap and relPoint == "CENTER"
				and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
				diel = child
				return child
			end
		end
	end
end

local placingDiel = false
local dielWatched = false
local PinDiel

local function WatchDiel(f)
	if dielWatched then return end
	dielWatched = true
	hooksecurefunc(f, "SetPoint", function()
		if placingDiel or not active then return end
		C_Timer.After(0, function()
			if active then pcall(PinDiel, true) end
		end)
	end)
end

function PinDiel(enabled)
	local f = FindDiel()
	if not f or (InCombatLockdown() and f.IsProtected and f:IsProtected()) then return end
	WatchDiel(f)
	placingDiel = true
	local ok, err = pcall(function()
	if enabled then
		if not dielOriginal then
			local point, rel, relPoint, x, y = f:GetPoint(1)
			dielOriginal = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
		end

		local x, y = DielPos()
		f:ClearAllPoints()
		f:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", x, y)
	elseif dielOriginal then
		local o = dielOriginal
		f:ClearAllPoints()
		f:SetPoint(o.point, o.rel, o.relPoint, o.x, o.y)
		dielOriginal = nil
	end
	end)
	placingDiel = false

	if not ok then KUI.dielError = tostring(err) end
end

local dielHandle

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local DIEL_OVERHANG = 0

local DIEL_RIGHT_TRIM = 2

local DIEL_EXTRA_PX = 1

local function PlaceDielAt(x, y)
	local f = FindDiel()
	if not f then return end
	local w, h = Minimap:GetWidth(), Minimap:GetHeight()
	local fw, fh = f:GetWidth() * f:GetScale(), f:GetHeight() * f:GetScale()
	x = Clamp(x, -(w - fw), DIEL_OVERHANG + DIEL_RIGHT_TRIM + DIEL_EXTRA_PX * OnePixel())
	y = Clamp(y, -(h - fh), DIEL_OVERHANG)
	placingDiel = true
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", x, y)
	placingDiel = false
	return x, y
end

local function EnsureDielHandle()
	if dielHandle then return dielHandle end
	local f = FindDiel()
	if not f then return nil end
	local h = CreateFrame("Frame", "KainUIForeverDielHandle", Minimap, "BackdropTemplate")
	h:SetFrameLevel(f:GetFrameLevel() + 10)
	h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	h:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -DIEL_RIGHT_TRIM, 0)
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	if h.SetBackdrop then
		h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		h:SetBackdropColor(0.2, 0.6, 1, 0.35)
		h:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
	end
	local dragging, startCX, startCY, startX, startY
	h:SetScript("OnDragStart", function()
		dragging = true
		local cx, cy = GetCursorPosition()
		startCX, startCY = cx, cy
		startX, startY = DielPos()
	end)
	h:SetScript("OnUpdate", function()
		if not dragging then return end
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		PlaceDielAt(startX + (cx - startCX) / scale, startY + (cy - startCY) / scale)
	end)
	h:SetScript("OnDragStop", function()
		dragging = false
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		local x, y = PlaceDielAt(startX + (cx - startCX) / scale, startY + (cy - startCY) / scale)
		if x and KUI.db then KUI.db.dielPos = { x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10 } end
	end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Day/night widget", 1, 1, 1)
		GameTooltip:AddLine("Drag to move. /kainui dielscan prints its position.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", function() GameTooltip:Hide() end)
	h:Hide()
	dielHandle = h
	return h
end

local function UpdateDielHandle()
	local unlocked = KUI.db and KUI.db.headerBarUnlocked
	if active and unlocked then
		local h = EnsureDielHandle()
		if h then h:Show() end
	elseif dielHandle then
		dielHandle:Hide()
	end
end

if KUI.SetMinimapElementsUnlocked then
	hooksecurefunc(KUI, "SetMinimapElementsUnlocked", function() UpdateDielHandle() end)
end

function KUI:SetDielPosition(x, y)
	if not KUI.db or type(x) ~= "number" or type(y) ~= "number" then return end
	KUI.db.dielPos = { x = x, y = y }
	if active then PinDiel(true) end
end

function KUI:DielScanReport()
	local x, y = DielPos()
	local custom = KUI.db and KUI.db.dielPos
	print(string.format("|cff33ff99Kain-UI Forever|r day/night widget: its top-right corner is %.1f across, %.1f up from the square map's top-right corner%s",
		x, y, custom and "" or " (default)"))
	print(string.format("  preset line:  dielPos = { x = %s, y = %s },", tostring(x), tostring(y)))
	if not FindDiel() then print("  (widget not found on this client)") end
	if not active then print("  (Square Minimap is off -- this position applies when it's on)") end
end

local function Refit()
	if KUI.RefitZoneBar then KUI:RefitZoneBar() end
end

local function Apply(enabled)
	if not Minimap or not Minimap.SetMaskTexture then return end
	if enabled then

		local okBorder, borderErr = pcall(EnsureBorder)
		if not okBorder then KUI.squareBorderError = tostring(borderErr) end
		Minimap:SetMaskTexture(SQUARE_MASK)
		local ring = RoundRing()
		if ring and ring.SetAlpha then ring:SetAlpha(0) end
		SetBlobRings(false)
		if border then border:Show() end
		KUI.SquareMinimapBorder = border
		active = true
	else
		if not active then return end
		Minimap:SetMaskTexture(ROUND_MASK)
		local ring = RoundRing()
		if ring and ring.SetAlpha then ring:SetAlpha(1) end
		SetBlobRings(true)
		if border then border:Hide() end
		KUI.SquareMinimapBorder = nil
		active = false
	end
	RefreshMap()
	Refit()

	pcall(RefreshMinimapButtons)
	if C_Timer and C_Timer.After then
		C_Timer.After(2, function() pcall(RefreshMinimapButtons) end)
	end

	pcall(ResizeLFGEye, enabled and true or false)
	pcall(PinDiel, enabled and true or false)
	pcall(UpdateDielHandle)

	if KUI.ApplyGuildDifficulty then pcall(KUI.ApplyGuildDifficulty, KUI) end
	if enabled and C_Timer and C_Timer.After then
		C_Timer.After(2, function()
			if active then pcall(ResizeLFGEye, true); pcall(PinDiel, true) end
		end)
	end
end

function KUI:SetSquareMinimap(enabled)
	if not KUI.db then return end
	KUI.db.squareMinimap = enabled and true or false
	Apply(KUI.db.squareMinimap)

	if KUI.ApplyMinimapButtonBin then KUI:ApplyMinimapButtonBin() end
end

function KUI:ApplySquareMinimap()
	Apply(KUI.db and KUI.db.squareMinimap)
end

function KUI:SquareMinimapScanReport()
	if KUI.squareBorderError then print("|cffff6060Kain-UI Forever:|r square minimap frame error: " .. KUI.squareBorderError) end
	if KUI.dielError then print("|cffff6060Kain-UI Forever:|r day/night widget error: " .. KUI.dielError) end
	print("|cff33ff99Kain-UI Forever|r square minimap: " .. (active and "ON" or "off")
		.. (border and (", border " .. tostring(border.style)) or "")
		.. ", round ring " .. (RoundRing() and "found" or "not found")
		.. ", BORDER_SCALE " .. BORDER_SCALE .. ", BORDER_OUTSET " .. BORDER_OUTSET)
	print("  round mask used when switching back: " .. roundMaskSource)
	local d = FindDiel()
	if d then
		local point, _, _, x, y = d:GetPoint(1)
		print(string.format("  day/night widget: found, now %s %.0f, %.0f%s", tostring(point), x or 0, y or 0,
			dielOriginal and string.format(" (originally %.0f, %.0f)", dielOriginal.x or 0, dielOriginal.y or 0) or ""))
	else
		print("  day/night widget: NOT FOUND")
	end
	local eye, eyeName = FirstFrame(LFG_EYE_NAMES)
	local rxp, rxpName = FirstFrame(RXP_ICON_NAMES)
	print("  LFG eye: " .. (eye and (eyeName .. string.format(" (%.0f tall on screen)", eye:GetHeight() * eye:GetEffectiveScale())) or "NOT FOUND -- /fstack it and send the name")
		.. " | RXP icon: " .. (rxp and (rxpName .. string.format(" (%.0f tall)", rxp:GetHeight() * rxp:GetEffectiveScale())) or "not found"))
end
