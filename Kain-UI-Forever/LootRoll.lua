local _, KUI = ...

local CANDIDATE_NAMES = {
	"GroupLootFrame1",
	"GroupLootFrame2",
	"GroupLootFrame3",
	"GroupLootFrame4",
}

local resolvedFrames
local hookedFrames = {}
local draggableFrames = {}
local active = false
local rawBase = nil
local RefreshMarker

local function ResolveFrames()
	if resolvedFrames then return resolvedFrames end
	resolvedFrames = {}
	for _, name in ipairs(CANDIDATE_NAMES) do
		local f = _G[name]
		if f then
			table.insert(resolvedFrames, f)
		end
	end
	return resolvedFrames
end

local function GetSavedOffset()
	if KUI.db and KUI.db.lootRollOffset then
		local o = KUI.db.lootRollOffset
		local x = type(o) == "table" and type(o.x) == "number" and o.x or 0
		local y = type(o) == "table" and type(o.y) == "number" and o.y or 0
		return x, y
	end
	return 0, 0
end

local function SaveOffset(x, y)
	if not KUI.db then return end
	KUI.db.lootRollOffset = { x = x, y = y }
end

local function ScreenTopLeft(f)
	local left, top = f:GetLeft(), f:GetTop()
	if not (left and top) then return nil end
	local r = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return left * r, top * r
end

local function GetTarget()
	local t = KUI.db and KUI.db.lootRollTarget

	if type(t) == "table" and type(t.left) == "number" and type(t.top) == "number" then return t end
end

local function SaveTarget(left, top)
	if not KUI.db or not left or not top then return end
	KUI.db.lootRollTarget = { left = left, top = top }
end

local function OnScreen(left, top)
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	return left > -50 and left < w - 50 and top > 50 and top < h + 10
end

local function OffsetFromTarget()
	local t, base = GetTarget(), KUI.db and KUI.db.lootRollScreenBase
	if t and type(base) == "table" and type(base.left) == "number" and type(base.top) == "number" then
		SaveOffset(t.left - base.left, t.top - base.top)
	end
end

local applyingOffset = false

local function ShiftFrame(frame, dx, dy)
	if dx == 0 and dy == 0 then return end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point then return end
	applyingOffset = true
	frame:SetPoint(point, relativeTo, relativePoint, (x or 0) + dx, (y or 0) + dy)
	applyingOffset = false
end

local function ApplyOffsetToFrame(frame)
	if not active then return end
	local ox, oy = GetSavedOffset()
	ShiftFrame(frame, ox, oy)
end

local function ShiftShownFrames(dx, dy)
	for _, f in ipairs(ResolveFrames()) do
		if f:IsShown() then
			ShiftFrame(f, dx, dy)
		end
	end
end

local function HookFrameSetPoint(frame)
	if hookedFrames[frame] then return end
	hookedFrames[frame] = true
	hooksecurefunc(frame, "SetPoint", function(f)
		if applyingOffset then return end
		if f == ResolveFrames()[1] then

			local point, relativeTo, relativePoint, x, y = f:GetPoint(1)
			if point then
				rawBase = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x or 0, y = y or 0 }

				local relName = relativeTo and relativeTo.GetName and relativeTo:GetName()
				if KUI.db and (relName or relativeTo == nil) then
					KUI.db.lootRollRawBase = { point = point, relName = relName, relPoint = relativePoint, x = x or 0, y = y or 0 }
				end

				local left, top = f:GetLeft(), f:GetTop()
				if KUI.db and left and top then
					local r = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
					KUI.db.lootRollScreenBase = { left = left * r, top = top * r }
					OffsetFromTarget()
				end
			end
		end
		ApplyOffsetToFrame(f)
		RefreshMarker()
	end)
end

local dragFrame = nil
local dragStartX = nil
local dragStartY = nil
local dragBasePositions = {}

local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function()
	if not dragFrame then updater:Hide(); return end
	local cx, cy = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	local dx = cx - dragStartX
	local dy = cy - dragStartY

	applyingOffset = true
	for frame, base in pairs(dragBasePositions) do
		if frame:IsShown() then
			frame:SetPoint(base.point, base.relativeTo, base.relativePoint,
				base.x + dx, base.y + dy)
		end
	end
	applyingOffset = false
end)

local function StartDrag(frame)

	dragBasePositions = {}
	for _, f in ipairs(ResolveFrames()) do
		if f:IsShown() then
			local point, relativeTo, relativePoint, x, y = f:GetPoint(1)
			if point then
				dragBasePositions[f] = {
					point = point,
					relativeTo = relativeTo,
					relativePoint = relativePoint,
					x = x or 0,
					y = y or 0,
				}
			end
		end
	end
	local cx, cy = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	dragStartX = cx / scale
	dragStartY = cy / scale
	dragFrame = frame
	updater:Show()
end

local function StopDrag()
	if not dragFrame then return end
	updater:Hide()

	local cx, cy = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local dx = (cx / scale) - dragStartX
	local dy = (cy / scale) - dragStartY

	local ox, oy = GetSavedOffset()
	SaveOffset(ox + dx, oy + dy)

	local f1 = ResolveFrames()[1]
	if f1 and f1:IsShown() then SaveTarget(ScreenTopLeft(f1)) end

	dragFrame = nil
	dragStartX = nil
	dragStartY = nil
	dragBasePositions = {}
	RefreshMarker()
end

local function MakeFrameDraggable(frame)
	if draggableFrames[frame] then return end
	draggableFrames[frame] = true
	frame:EnableMouse(true)
	frame:SetMovable(true)

	frame:SetClampedToScreen(true)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and active then
			StartDrag(self)
		end
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			StopDrag()
		end
	end)

	local existingOnHide = frame:GetScript("OnHide")
	frame:SetScript("OnHide", function(self)
		if dragFrame == self then StopDrag() end
		if existingOnHide then existingOnHide(self) end
	end)
end

local marker = nil
local markerDragging = false
local markerStartLeft, markerStartTop

local function SavedRawBase()
	local saved = KUI.db and KUI.db.lootRollRawBase
	if not saved or not saved.point then return nil end
	local rel = saved.relName and _G[saved.relName] or UIParent
	return { point = saved.point, relativeTo = rel, relativePoint = saved.relPoint or saved.point,
		x = saved.x or 0, y = saved.y or 0 }
end

local function PositionMarker()
	if not marker then return end
	marker:ClearAllPoints()
	local f1 = ResolveFrames()[1]
	if f1 and f1:IsShown() then
		local point, relativeTo, relativePoint, x, y = f1:GetPoint(1)
		if point then
			marker:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
			return
		end
	end

	local target = GetTarget()
	if target then
		marker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", target.left, target.top)
		return
	end
	local ox, oy = GetSavedOffset()

	local screen = KUI.db and KUI.db.lootRollScreenBase
	if screen and screen.left and screen.top then
		marker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screen.left + ox, screen.top + oy)
		return
	end

	local base = rawBase or SavedRawBase()
	local rel = base and base.relativeTo
	local relVisible = rel == nil or rel == UIParent or (rel.IsVisible and rel:IsVisible())
	if base and relVisible then
		marker:SetPoint(base.point, base.relativeTo, base.relativePoint, base.x + ox, base.y + oy)
	else
		marker:SetPoint("CENTER", UIParent, "CENTER", ox, oy + 200)
	end
end

RefreshMarker = function()
	if marker and marker:IsShown() and not markerDragging then
		PositionMarker()
	end
end

local function EnsureMarker()
	if marker then return marker end
	local m = CreateFrame("Frame", "KainUIForeverLootRollAnchor", UIParent, "BackdropTemplate")
	local f1 = ResolveFrames()[1]
	local w, h = 250, 70
	if f1 and f1.GetSize then
		local fw, fh = f1:GetSize()
		if fw and fw > 20 then w = fw end
		if fh and fh > 20 then h = fh end
	end
	m:SetSize(w, h)
	m:SetFrameStrata("DIALOG")
	m:SetClampedToScreen(true)
	m:SetMovable(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	if m.SetBackdrop then
		m:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		m:SetBackdropColor(0.2, 0.6, 1, 0.35)
		m:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
	end
	local label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER")
	label:SetText("Loot roll anchor -- drag me")

	m:SetScript("OnDragStart", function(self)
		markerDragging = true
		markerStartLeft, markerStartTop = self:GetLeft(), self:GetTop()
		self:StartMoving()
		if KUI.BeginAlignDrag then KUI:BeginAlignDrag(self) end
	end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if KUI.EndAlignDrag then KUI:EndAlignDrag(self) end
		markerDragging = false
		local left, top = ScreenTopLeft(self)
		local dx = (left and markerStartLeft) and (self:GetLeft() - markerStartLeft) or 0
		local dy = (top and markerStartTop) and (self:GetTop() - markerStartTop) or 0
		if active then ShiftShownFrames(dx, dy) end

		if left and top then SaveTarget(left, top) end
		local ox, oy = GetSavedOffset()
		SaveOffset(ox + dx, oy + dy)
		OffsetFromTarget()
		PositionMarker()
	end)
	m:Hide()
	marker = m
	return m
end

function KUI:SetLootRollTarget(left, top)
	if not KUI.db or type(left) ~= "number" or type(top) ~= "number" then return end
	SaveTarget(left, top)
	KUI.db.lootRollTargetMigrated = true
	OffsetFromTarget()
	RefreshMarker()
end

function KUI:SetLootRollAnchorLocked(locked)
	locked = locked and true or false
	if not locked and not active then
		print("|cffff6060Kain-UI Forever:|r turn on \"Draggable loot roll frames\" first.")
		return false
	end
	if KUI.db then KUI.db.lootRollAnchorLocked = locked end
	if locked then
		if marker then marker:Hide() end
	else
		local m = EnsureMarker()
		PositionMarker()
		m:Show()
	end
	return true
end

local function MigrateToTarget()
	if not KUI.db or GetTarget() or KUI.db.lootRollTargetMigrated then return end
	KUI.db.lootRollTargetMigrated = true
	local base = KUI.db.lootRollScreenBase
	local ox, oy = GetSavedOffset()
	if type(base) == "table" and type(base.left) == "number" and type(base.top) == "number" and (ox ~= 0 or oy ~= 0) then
		local left, top = base.left + ox, base.top + oy
		if OnScreen(left, top) then
			SaveTarget(left, top)
		else
			SaveOffset(0, 0)
		end
	end
end

function KUI:ApplyLootRollDragging()
	MigrateToTarget()
	for _, frame in ipairs(ResolveFrames()) do
		HookFrameSetPoint(frame)
		MakeFrameDraggable(frame)
	end
	local enabled = not KUI.db or KUI.db.lootRollDragging ~= false
	if enabled and not active then
		active = true
		local ox, oy = GetSavedOffset()
		ShiftShownFrames(ox, oy)
	end
	if active and KUI.db and KUI.db.lootRollAnchorLocked == false then
		KUI:SetLootRollAnchorLocked(false)
	end
end

function KUI:SetLootRollDragging(enabled)
	enabled = enabled and true or false
	if KUI.db then KUI.db.lootRollDragging = enabled end

	for _, frame in ipairs(ResolveFrames()) do
		HookFrameSetPoint(frame)
		MakeFrameDraggable(frame)
	end
	if enabled == active then return end
	if not enabled then
		StopDrag()
		local ox, oy = GetSavedOffset()
		ShiftShownFrames(-ox, -oy)
		active = false
		KUI:SetLootRollAnchorLocked(true)
	else
		active = true
		local ox, oy = GetSavedOffset()
		ShiftShownFrames(ox, oy)
	end
end

function KUI:ResetLootRollPosition()
	if active then
		local ox, oy = GetSavedOffset()
		ShiftShownFrames(-ox, -oy)
	end
	SaveOffset(0, 0)
	if KUI.db then KUI.db.lootRollTarget = nil end
	RefreshMarker()
	print("|cff33ff99Kain-UI Forever|r Loot roll position reset.")
end
