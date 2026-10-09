local _, KUI = ...

local GRID_SPACING = 100
local SNAP_DISTANCE = 10
local CENTER_SNAP_DISTANCE = 20

local ELEMENT_NAMES = {
	"KainUIForeverZoneBar",
	"KainUIForeverTooltipAnchor",
	"KainUIForeverLootRollAnchor",
}

if KUI.defaults then
	KUI.defaults.snapToElements = false
end

local LINE_COLOR = { 1, 1, 1, 0.12 }
local CENTER_LINE_COLOR = { 0.6, 0.3, 1, 0.7 }
local SNAP_COLOR = { 1, 0.82, 0, 0.9 }

local grid
local lines = {}
local guideX, guideY
local dragging

local function Pixel()

	if type(GetPhysicalScreenSize) ~= "function" then return 1 end
	local _, physH = GetPhysicalScreenSize()
	local scale = UIParent:GetEffectiveScale()
	if physH and physH > 0 and scale > 0 then return 768 / physH / scale end
	return 1
end

local function Line(i)
	local t = lines[i]
	if not t then
		t = grid:CreateTexture(nil, "BACKGROUND")
		lines[i] = t
	end
	t:Show()
	return t
end

local function DrawGrid()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local px = Pixel()
	local n = 0
	local function Vertical(x, color, thick)
		n = n + 1
		local t = Line(n)
		t:SetColorTexture(color[1], color[2], color[3], color[4])
		t:ClearAllPoints()
		t:SetPoint("TOP", UIParent, "TOPLEFT", x, 0)
		t:SetSize(px * thick, h)
	end
	local function Horizontal(y, color, thick)
		n = n + 1
		local t = Line(n)
		t:SetColorTexture(color[1], color[2], color[3], color[4])
		t:ClearAllPoints()
		t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, y)
		t:SetSize(w, px * thick)
	end
	local k = 1
	while w / 2 + k * GRID_SPACING < w do
		Vertical(w / 2 + k * GRID_SPACING, LINE_COLOR, 1)
		Vertical(w / 2 - k * GRID_SPACING, LINE_COLOR, 1)
		k = k + 1
	end
	k = 1
	while h / 2 + k * GRID_SPACING < h do
		Horizontal(h / 2 + k * GRID_SPACING, LINE_COLOR, 1)
		Horizontal(h / 2 - k * GRID_SPACING, LINE_COLOR, 1)
		k = k + 1
	end
	Vertical(w / 2, CENTER_LINE_COLOR, 2)
	Horizontal(h / 2, CENTER_LINE_COLOR, 2)
	for i = n + 1, #lines do lines[i]:Hide() end
end

local function Bounds(f)
	local left, right, top, bottom = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not left then return nil end
	local r = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return left * r, right * r, bottom * r, top * r
end

local function IsPartOf(f, frame)
	while f do
		if f == frame then return true end
		f = f:GetParent()
	end
	return false
end

local function ElementBounds(frame)
	local list = {}
	if not (KUI.db and KUI.db.snapToElements) then return list end
	local frames = {}
	if Minimap and KUI.db.minimapDetached then frames[#frames + 1] = Minimap end
	for _, name in ipairs(ELEMENT_NAMES) do
		if _G[name] then frames[#frames + 1] = _G[name] end
	end
	for _, f in ipairs(frames) do
		if f:IsVisible() and not IsPartOf(f, frame) and not IsPartOf(frame, f) then
			local l, r, b, t = Bounds(f)
			if l then list[#list + 1] = { l = l, r = r, b = b, t = t } end
		end
	end
	return list
end

local function SnapTargets(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not left then return end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	left, right, top, bottom = left * ratio, right * ratio, top * ratio, bottom * ratio
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()

	local elements = ElementBounds(frame)

	local function Best(lowEdge, highEdge, size, screenCentre, elemMids, elemEdges)
		local mid = (lowEdge + highEdge) / 2
		local candidates = { screenCentre }
		local k = 1
		while k * GRID_SPACING < size do
			candidates[#candidates + 1] = screenCentre + k * GRID_SPACING
			candidates[#candidates + 1] = screenCentre - k * GRID_SPACING
			k = k + 1
		end

		local d = screenCentre - mid
		if math.abs(d) <= CENTER_SNAP_DISTANCE then return d, screenCentre end

		local function Nearest(values, targets, limit)
			local bestDelta, bestLine
			for _, v in ipairs(values) do
				for _, t in ipairs(targets) do
					local dd = t - v
					if math.abs(dd) <= limit and (not bestDelta or math.abs(dd) < math.abs(bestDelta)) then
						bestDelta, bestLine = dd, t
					end
				end
			end
			return bestDelta, bestLine
		end

		local ed, el = Nearest({ mid }, elemMids, SNAP_DISTANCE)
		if ed then return ed, el end

		local cd, cl = Nearest({ mid }, candidates, SNAP_DISTANCE)
		if cd then return cd, cl end

		local edgeTargets = { 0, size }
		for _, t in ipairs(elemEdges) do edgeTargets[#edgeTargets + 1] = t end
		for _, t in ipairs(candidates) do edgeTargets[#edgeTargets + 1] = t end
		return Nearest({ lowEdge, highEdge }, edgeTargets, SNAP_DISTANCE)
	end

	local midsX, edgesX, midsY, edgesY = {}, {}, {}, {}
	for _, e in ipairs(elements) do
		midsX[#midsX + 1] = (e.l + e.r) / 2
		edgesX[#edgesX + 1] = e.l
		edgesX[#edgesX + 1] = e.r
		midsY[#midsY + 1] = (e.b + e.t) / 2
		edgesY[#edgesY + 1] = e.b
		edgesY[#edgesY + 1] = e.t
	end

	local dx, lineX = Best(left, right, w, w / 2, midsX, edgesX)
	local dy, lineY = Best(bottom, top, h, h / 2, midsY, edgesY)
	return dx, dy, lineX, lineY, left, top, ratio
end

local function FreeX() return IsControlKeyDown() end
local function FreeY() return IsShiftKeyDown() end

local function UpdateGuides()
	if not dragging then
		guideX:Hide()
		guideY:Hide()
		return
	end
	local _, _, lineX, lineY = SnapTargets(dragging)
	if FreeX() then lineX = nil end
	if FreeY() then lineY = nil end
	local px = Pixel() * 2
	if lineX then
		guideX:ClearAllPoints()
		guideX:SetPoint("TOP", UIParent, "TOPLEFT", lineX, 0)
		guideX:SetSize(px, UIParent:GetHeight())
		guideX:Show()
	else
		guideX:Hide()
	end
	if lineY then
		guideY:ClearAllPoints()
		guideY:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, lineY)
		guideY:SetSize(UIParent:GetWidth(), px)
		guideY:Show()
	else
		guideY:Hide()
	end
end

local function BuildGrid()
	grid = CreateFrame("Frame", "KainUIForeverAlignGrid", UIParent)
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid:SetFrameLevel(0)
	grid:EnableMouse(false)
	grid:Hide()
	guideX = grid:CreateTexture(nil, "OVERLAY")
	guideX:SetColorTexture(SNAP_COLOR[1], SNAP_COLOR[2], SNAP_COLOR[3], SNAP_COLOR[4])
	guideX:Hide()
	guideY = grid:CreateTexture(nil, "OVERLAY")
	guideY:SetColorTexture(SNAP_COLOR[1], SNAP_COLOR[2], SNAP_COLOR[3], SNAP_COLOR[4])
	guideY:Hide()
	grid:SetScript("OnShow", DrawGrid)
	grid:SetScript("OnUpdate", UpdateGuides)
	grid:RegisterEvent("UI_SCALE_CHANGED")
	grid:RegisterEvent("DISPLAY_SIZE_CHANGED")
	grid:SetScript("OnEvent", function(self) if self:IsShown() then DrawGrid() end end)
end

local function AnyUnlocked()
	local db = KUI.db
	if not db then return false end
	return db.emojiButtonUnlocked
		or db.socialButtonUnlocked
		or db.tooltipAnchorLocked == false
		or db.lootRollAnchorLocked == false
end

function KUI:RefreshAlignGrid()
	if not grid then BuildGrid() end
	local panel = _G.KainUIForeverOptionsFrame
	local arranging = panel and panel:IsShown() and AnyUnlocked()
	grid:SetShown(dragging ~= nil or arranging and true or false)
end

function KUI:BeginAlignDrag(frame)
	if not frame then return end
	dragging = frame
	KUI:RefreshAlignGrid()
end

function KUI:EndAlignDrag(frame)
	if not frame or dragging ~= frame then return end
	dragging = nil
	do
		local dx, dy, _, _, left, top, ratio = SnapTargets(frame)
		if FreeX() then dx = nil end
		if FreeY() then dy = nil end
		if (dx or dy) and left then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
				(left + (dx or 0)) / ratio, (top + (dy or 0)) / ratio)
		end
	end
	if guideX then guideX:Hide(); guideY:Hide() end
	KUI:RefreshAlignGrid()
end

function KUI:SetSnapToElements(enabled)
	if KUI.db then KUI.db.snapToElements = enabled and true or false end
end

for _, name in ipairs({ "SetEmojiButtonUnlocked", "SetTooltipAnchorLocked", "SetLootRollAnchorLocked" }) do
	if type(KUI[name]) == "function" then
		hooksecurefunc(KUI, name, function() KUI:RefreshAlignGrid() end)
	end
end
