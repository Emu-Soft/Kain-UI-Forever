local _, KUI = ...

local minimapClusterDragHooked = false

function KUI:ResolveScreenPosition(spec)
	if not spec then return nil end
	if spec.x and spec.y then return spec end
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local from = spec.from or "CENTER"
	local baseX = from:find("LEFT") and 0 or from:find("RIGHT") and w or w / 2
	local baseY = from:find("TOP") and h or from:find("BOTTOM") and 0 or h / 2
	return { x = baseX + (spec.dx or 0), y = baseY + (spec.dy or 0) }
end

local DEFAULT_MINIMAP_POSITION = { from = "TOPRIGHT", dx = -204.8, dy = -26.0 }
local DEFAULT_MINIMAPCLUSTER_POSITION = { from = "TOP", dx = -150.7, dy = 271.7 }

local MINIMAP_STRATA = "MEDIUM"
local originalMinimapStrata

local function ScaleRatio(frame)
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if not ratio or ratio <= 0 then ratio = 1 end
	return ratio
end

local function SaveDraggedPosition(frame, key)
	if not KUI.db then return end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not left or not top then return end
	local ratio = ScaleRatio(frame)
	KUI.db.framePositions = KUI.db.framePositions or {}
	KUI.db.framePositions[key] = { x = left * ratio, y = top * ratio }

	pcall(frame.SetUserPlaced, frame, false)
end

local function MinimapHomeAnchor()
	local container = MinimapCluster and MinimapCluster.MinimapContainer
	if container then
		return { parent = container, point = "CENTER", relativeTo = container, relativePoint = "CENTER", x = 0, y = 0 }
	end
end

local CLUSTER_DEFAULT_POINTS = { { "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 } }
local originalMinimapClusterPoints
do
	local cluster = MinimapCluster
	if cluster and cluster.GetNumPoints then
		local userPlaced = cluster.IsUserPlaced and cluster:IsUserPlaced()
		if not userPlaced and cluster:GetNumPoints() > 0 then
			originalMinimapClusterPoints = {}
			for i = 1, cluster:GetNumPoints() do originalMinimapClusterPoints[i] = { cluster:GetPoint(i) } end
		end
	end
end

local function RestoreClusterHome()
	if not MinimapCluster then return end
	local points = (originalMinimapClusterPoints and #originalMinimapClusterPoints > 0) and originalMinimapClusterPoints
		or CLUSTER_DEFAULT_POINTS
	MinimapCluster:ClearAllPoints()
	for _, p in ipairs(points) do MinimapCluster:SetPoint(unpack(p)) end
	pcall(MinimapCluster.SetUserPlaced, MinimapCluster, false)
end

local function ApplySavedPosition(frame, key, fallback)
	local pos = (KUI.db and KUI.db.framePositions and KUI.db.framePositions[key])
		or KUI:ResolveScreenPosition(fallback)
	if not pos then return false end
	local ratio = ScaleRatio(frame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / ratio, pos.y / ratio)

	if frame.SetUserPlaced then

		if frame.SetMovable then pcall(frame.SetMovable, frame, true) end
		pcall(frame.SetUserPlaced, frame, true)
	end
	return true
end

function KUI:ApplyMinimapClamp()
	local unclamped = KUI.db and KUI.db.minimapUnclamped
	for _, frame in ipairs({ Minimap, MinimapCluster }) do
		if frame and frame.SetClampedToScreen then
			frame:SetClampedToScreen(not unclamped)
		end
	end
end

function KUI:SetMinimapUnclamped(unclamped)
	if not KUI.db then return end
	KUI.db.minimapUnclamped = unclamped
	KUI:ApplyMinimapClamp()
end

local originalMinimapPosition
local originalDielFramePosition
local originalQueueStatusPosition

local function ApplyQueueStatusDetach(detached)
	local btn = _G.QueueStatusButton
	if not btn then return end

	if detached then
		if not originalQueueStatusPosition then
			local point, relativeTo, relativePoint, x, y = btn:GetPoint(1)
			if point then
				originalQueueStatusPosition = { parent = btn:GetParent(), point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
			end
		end
		if originalQueueStatusPosition then
			btn:SetParent(Minimap)
			btn:SetFrameStrata("HIGH")
			btn:SetFrameLevel(Minimap:GetFrameLevel() + 50)
			btn:ClearAllPoints()
			btn:SetPoint(originalQueueStatusPosition.point, Minimap, originalQueueStatusPosition.relativePoint, originalQueueStatusPosition.x, originalQueueStatusPosition.y)
		end
	else
		if originalQueueStatusPosition then
			btn:SetParent(originalQueueStatusPosition.parent)
			btn:ClearAllPoints()
			btn:SetPoint(originalQueueStatusPosition.point, originalQueueStatusPosition.relativeTo, originalQueueStatusPosition.relativePoint, originalQueueStatusPosition.x, originalQueueStatusPosition.y)
		end
	end
end

function KUI:DetachMinimap(detached)
	if not Minimap then
		print("|cffff6060Kain-UI Forever:|r couldn't find the Minimap frame on this build.")
		return
	end

	Minimap:SetMovable(true)
	Minimap:RegisterForDrag("LeftButton")

	Minimap:HookScript("OnDragStart", function(map)
		if KUI.db and not KUI.db.anchorsLocked then

			map:SetMovable(true)
			map:StartMoving()
			if KUI.BeginAlignDrag then KUI:BeginAlignDrag(map) end
		end
	end)
	Minimap:HookScript("OnDragStop", function(map)
		map:StopMovingOrSizing()
		if KUI.EndAlignDrag then KUI:EndAlignDrag(map) end
		SaveDraggedPosition(map, "minimap")
	end)

	local dielFrame = MinimapCluster and MinimapCluster.DielFrame
	local minimapContainer = MinimapCluster and MinimapCluster.MinimapContainer

	if detached then

		if not originalMinimapPosition then
			local point, relativeTo, relativePoint, x, y = Minimap:GetPoint(1)
			if point then
				originalMinimapPosition = { parent = Minimap:GetParent(), point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
			end

			local home = MinimapHomeAnchor()
			if home and (not originalMinimapPosition or originalMinimapPosition.relativeTo == UIParent
				or originalMinimapPosition.parent == UIParent) then
				originalMinimapPosition = home
			end
		end
		if not originalMinimapStrata then
			originalMinimapStrata = Minimap:GetFrameStrata()
		end
		Minimap:SetParent(UIParent)
		Minimap:SetFrameStrata(MINIMAP_STRATA)

		ApplySavedPosition(Minimap, "minimap", DEFAULT_MINIMAP_POSITION)

		if dielFrame then
			if not originalDielFramePosition then
				local point, relativeTo, relativePoint, x, y = dielFrame:GetPoint(1)
				if point then
					originalDielFramePosition = { parent = dielFrame:GetParent(), point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
				end
			end

			if originalDielFramePosition then
				dielFrame:SetParent(Minimap)
				dielFrame:SetFrameStrata("HIGH")

				dielFrame:SetFrameLevel(Minimap:GetFrameLevel() + 50)
				dielFrame:ClearAllPoints()
				dielFrame:SetPoint(originalDielFramePosition.point, Minimap, originalDielFramePosition.relativePoint, originalDielFramePosition.x, originalDielFramePosition.y)
			end
		end

		if minimapContainer then
			minimapContainer:SetAlpha(0)
			minimapContainer:EnableMouse(false)
		end

		ApplyQueueStatusDetach(true)
	else
		if originalMinimapPosition then
			Minimap:SetParent(originalMinimapPosition.parent)
			if originalMinimapStrata then
				Minimap:SetFrameStrata(originalMinimapStrata)
			end
			Minimap:ClearAllPoints()
			Minimap:SetPoint(originalMinimapPosition.point, originalMinimapPosition.relativeTo, originalMinimapPosition.relativePoint, originalMinimapPosition.x, originalMinimapPosition.y)
			pcall(Minimap.SetUserPlaced, Minimap, false)
		end
		if dielFrame and originalDielFramePosition then
			dielFrame:SetParent(originalDielFramePosition.parent)
			dielFrame:ClearAllPoints()
			dielFrame:SetPoint(originalDielFramePosition.point, originalDielFramePosition.relativeTo, originalDielFramePosition.relativePoint, originalDielFramePosition.x, originalDielFramePosition.y)
		end
		if minimapContainer then
			minimapContainer:SetAlpha(1)
			minimapContainer:EnableMouse(true)
		end
		ApplyQueueStatusDetach(false)

		if not (KUI.db and KUI.db.headerBarUnlocked) then RestoreClusterHome() end
	end

	if KUI.ApplyZoneBar then KUI:ApplyZoneBar(detached) end
end

function KUI:SetMinimapDetached(detached)
	if not KUI.db then return end
	KUI.db.minimapDetached = detached
	KUI:DetachMinimap(detached)

	if KUI.ApplyMinimapButtonBin then KUI:ApplyMinimapButtonBin() end
end

function KUI:SetMinimapAnchorsLocked(locked)
	if not KUI.db then return end
	KUI.db.anchorsLocked = locked
	if not Minimap or not KUI.db.minimapDetached then return end

	Minimap:EnableMouse(true)
end

local HEADER_BAR_DRAG_SOURCES = {
	function() return MinimapCluster and MinimapCluster.ZoneTextButton end,
	function() return MinimapCluster and MinimapCluster.Tracking end,
	function() return _G.GameTimeFrame end,
	function() return _G.TimeManagerClockButton end,
}

local originalMinimapClusterSize

function KUI:SetHeaderBarUnlocked(unlocked)
	if not KUI.db then return end
	KUI.db.headerBarUnlocked = unlocked

	if KUI.IsZoneBarActive and KUI:IsZoneBarActive() then
		KUI:SetZoneBarUnlocked(unlocked)
		return
	end
	if not MinimapCluster then return end

	if not minimapClusterDragHooked then
		minimapClusterDragHooked = true

		originalMinimapClusterSize = { w = MinimapCluster:GetWidth(), h = MinimapCluster:GetHeight() }
		MinimapCluster:SetMovable(true)
		MinimapCluster:RegisterForDrag("LeftButton")

		MinimapCluster:HookScript("OnDragStart", function(cluster)
			if KUI.db and KUI.db.headerBarUnlocked then
				cluster:SetMovable(true)
				cluster:StartMoving()
			end
		end)
		MinimapCluster:HookScript("OnDragStop", function(cluster)
			cluster:StopMovingOrSizing()
			SaveDraggedPosition(cluster, "minimapcluster")
		end)

		for _, getSource in ipairs(HEADER_BAR_DRAG_SOURCES) do
			local source = getSource()
			if source and source.RegisterForDrag then
				source:RegisterForDrag("LeftButton")
				source:HookScript("OnDragStart", function()
					if KUI.db and KUI.db.headerBarUnlocked then
						MinimapCluster:SetMovable(true)
						MinimapCluster:StartMoving()
					end
				end)
				source:HookScript("OnDragStop", function()
					MinimapCluster:StopMovingOrSizing()
					SaveDraggedPosition(MinimapCluster, "minimapcluster")
				end)
			end
		end
	end

	if unlocked then
		ApplySavedPosition(MinimapCluster, "minimapcluster", DEFAULT_MINIMAPCLUSTER_POSITION)
	else

		RestoreClusterHome()
	end
	MinimapCluster:EnableMouse(unlocked)
end

function KUI:SetMinimapElementsUnlocked(unlocked)
	if not KUI.db then return end
	KUI:SetMinimapAnchorsLocked(not unlocked)
	KUI:SetHeaderBarUnlocked(unlocked)
end

function KUI:SetMinimapElementsDetached(enabled)
	if not KUI.db then return end
	KUI:SetMinimapDetached(enabled)
	KUI:SetMinimapElementsUnlocked(enabled)
end

local mmWatching = false
local mmHooked = {}

local function MMShortStack()
	if not debugstack then return {} end
	local ok, stack = pcall(debugstack, 3, 8, 0)
	if not ok or type(stack) ~= "string" then return {} end
	local lines = {}
	for line in stack:gmatch("[^\n]+") do
		line = line:gsub("Interface[\\/]AddOns[\\/]", ""):gsub("Interface[\\/]", "")
		lines[#lines + 1] = line
	end
	if lines[1] and lines[1]:find("Minimap%.lua") then table.remove(lines, 1) end
	return lines
end

local function MMPrintStack()
	for _, line in ipairs(MMShortStack()) do
		local colour = line:find("Kain%-UI") and "|cffff6060" or "|cff999999"
		print("    " .. colour .. line .. "|r")
	end
end

local function MMPointString(frame)
	if not frame or not frame.GetPoint then return "?" end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not point then return "(no point)" end
	local relName
	if relativeTo then
		relName = (relativeTo.GetName and relativeTo:GetName())
			or (relativeTo.GetDebugName and select(1, pcall(relativeTo.GetDebugName, relativeTo)) and relativeTo:GetDebugName())
			or tostring(relativeTo)
	else
		relName = "?"
	end
	return string.format("%s, %s, %s, %.1f, %.1f", point, relName, relativePoint or "?", x or 0, y or 0)
end

local function MMVisualState(frame)
	if not frame or not frame.GetAlpha then return "" end
	local left, top, right, bottom = frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom()
	return string.format(
		" alpha=%.2f scale=%.2f effScale=%.2f w=%.0f h=%.0f rect(L=%s,T=%s,R=%s,B=%s)",
		frame:GetAlpha(), frame:GetScale(), frame:GetEffectiveScale(), frame:GetWidth() or 0, frame:GetHeight() or 0,
		left and string.format("%.1f", left) or "?",
		top and string.format("%.1f", top) or "?",
		right and string.format("%.1f", right) or "?",
		bottom and string.format("%.1f", bottom) or "?"
	)
end

local function HookFrameVisibilityAndAnchor(frame, label)
	if not frame or mmHooked[frame] then return end
	mmHooked[frame] = true

	frame:HookScript("OnShow", function(self)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s OnShow -- point=%s%s", label, MMPointString(self), MMVisualState(self)))
		MMPrintStack()
	end)
	frame:HookScript("OnHide", function(self)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s OnHide -- point=%s%s", label, MMPointString(self), MMVisualState(self)))
		MMPrintStack()
	end)

	pcall(hooksecurefunc, frame, "SetPoint", function(self, ...)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetPoint -> %s", label, MMPointString(self)))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "ClearAllPoints", function(self)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s ClearAllPoints", label))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetClampedToScreen", function(self, clamped)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetClampedToScreen(%s)", label, tostring(clamped)))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetAlpha(%.2f)", label, alpha))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetScale", function(self, scale)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetScale(%.2f)", label, scale))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetSize", function(self, w, h)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetSize(%.0f, %.0f)", label, w or 0, h or 0))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetWidth", function(self, w)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetWidth(%.0f)", label, w or 0))
		MMPrintStack()
	end)
	pcall(hooksecurefunc, frame, "SetHeight", function(self, h)
		if not mmWatching then return end
		print(string.format("|cff33ff99[minimapwatch]|r %s SetHeight(%.0f)", label, h or 0))
		MMPrintStack()
	end)
end

function KUI:MinimapClusterWatch(arg)
	if arg == "off" then
		mmWatching = false
		print("|cff33ff99Kain-UI Forever|r minimapwatch stopped.")
		return
	end
	mmWatching = true

	HookFrameVisibilityAndAnchor(MinimapCluster, "MinimapCluster")
	HookFrameVisibilityAndAnchor(Minimap, "Minimap")

	if MinimapCluster and MinimapCluster.GetChildren then
		for _, child in ipairs({ MinimapCluster:GetChildren() }) do
			local name = (child.GetName and child:GetName()) or "<unnamed child>"
			HookFrameVisibilityAndAnchor(child, "MinimapCluster." .. name)
		end
	end

	HookFrameVisibilityAndAnchor(MinimapCluster and MinimapCluster.DielFrame, "DielFrame")
	HookFrameVisibilityAndAnchor(_G.QueueStatusButton, "QueueStatusButton")

	print("|cff33ff99Kain-UI Forever|r minimapwatch: watching MinimapCluster + Minimap + MinimapCluster's children + DielFrame + QueueStatusButton for Show/Hide/SetPoint/ClearAllPoints/SetClampedToScreen/SetAlpha/SetScale/SetSize/SetWidth/SetHeight. Now do the ctrl-Z, ctrl-Z repro with clip off-screen RE-ENABLED, then copy what printed here. /kainui minimapwatch off to stop.")
end

if type(_G.SetUIVisibility) == "function" then
	local ok = pcall(hooksecurefunc, "SetUIVisibility", function(shown)
		if shown == false then return end

		C_Timer.After(0, function()
			if not KUI.db then return end
			KUI:DetachMinimap(KUI.db.minimapDetached)
			KUI:SetMinimapAnchorsLocked(KUI.db.anchorsLocked)
			KUI:SetHeaderBarUnlocked(KUI.db.headerBarUnlocked)

			if MinimapCluster and originalMinimapClusterSize then
				MinimapCluster:SetSize(originalMinimapClusterSize.w, originalMinimapClusterSize.h)
			end
		end)
	end)
	if not ok then
		print("|cffff6060Kain-UI Forever:|r couldn't hook SetUIVisibility on this client build -- the minimap/header bar position may need a manual /reload after toggling the UI (alt-Z) until this is looked at again.")
	end
else

	print("|cffff6060Kain-UI Forever:|r no global SetUIVisibility function found on this client build -- couldn't install the post-UI-toggle reposition fix. Re-run /kainui minimapwatch and check the stack trace if the header bar clips up after alt-Z.")
end

local minimapLoadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(minimapLoadFrame, "ADDON_LOADED")
minimapLoadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if loadedAddonName ~= "Blizzard_Minimap" then return end
	self:UnregisterEvent("ADDON_LOADED")
	if not KUI.db then return end
	KUI:ApplyMinimapClamp()
	KUI:DetachMinimap(KUI.db.minimapDetached)
	KUI:SetMinimapAnchorsLocked(KUI.db.anchorsLocked)
	KUI:SetHeaderBarUnlocked(KUI.db.headerBarUnlocked)

	C_Timer.After(0, function()
		if not KUI.db then return end
		KUI:DetachMinimap(KUI.db.minimapDetached)
		KUI:SetMinimapAnchorsLocked(KUI.db.anchorsLocked)
		KUI:SetHeaderBarUnlocked(KUI.db.headerBarUnlocked)
	end)
end)

local queueBtnHooked = false
local function HookQueueStatusButton()
	if queueBtnHooked then return end
	local btn = _G.QueueStatusButton
	if not btn then return end
	queueBtnHooked = true
	btn:HookScript("OnShow", function()
		if KUI.db and KUI.db.minimapDetached then
			ApplyQueueStatusDetach(true)
		end
	end)
end

HookQueueStatusButton()
local queueLoadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(queueLoadFrame, "ADDON_LOADED")
queueLoadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	HookQueueStatusButton()
	if queueBtnHooked then
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

function KUI:MinimapPositionScanReport()
	print("|cff33ff99Kain-UI Forever|r minimap position scan:")
	local function ReportFrame(frame, label)
		if not frame then
			print("  " .. label .. ": frame not found.")
			return
		end
		local left, top = frame:GetLeft(), frame:GetTop()
		if not left or not top then
			print("  " .. label .. ": no current position (not shown, or not yet positioned).")
			return
		end
		local ratio = ScaleRatio(frame)
		print(string.format("  %s: x=%.1f, y=%.1f, w=%.1f, h=%.1f", label, left * ratio, top * ratio, frame:GetWidth() or 0, frame:GetHeight() or 0))
	end
	ReportFrame(Minimap, "Minimap (detached map)")
	ReportFrame(MinimapCluster, "MinimapCluster (header bar)")
end

function KUI:MinimapStrataScanReport()
	print("|cff33ff99Kain-UI Forever|r minimap strata scan:")
	local function Line(label, frame)
		if not frame or not frame.GetFrameStrata then
			print("  " .. label .. ": not found.")
			return
		end
		print(string.format("  %s: strata=%s level=%d shown=%s", label,
			frame:GetFrameStrata(), frame:GetFrameLevel(), tostring(frame:IsShown())))
	end
	Line("Minimap", Minimap)
	Line("MinimapCluster", MinimapCluster)
	Line("DielFrame", MinimapCluster and MinimapCluster.DielFrame)
	Line("QueueStatusButton", _G.QueueStatusButton)
	Line("MinimapBackdrop", _G.MinimapBackdrop)
	if Minimap and Minimap.GetChildren then
		local children = { Minimap:GetChildren() }
		print("  Minimap children (" .. #children .. "):")
		for i, child in ipairs(children) do
			local name = child.GetName and child:GetName() or "<unnamed>"
			Line("    [" .. i .. "] " .. name, child)
		end
	end
end

local GUILD_DIFF_MARGIN = 10
local FRAME_API = getmetatable(CreateFrame("Frame")).__index

local guildDiffLocked = false
local guildDiffInternal = false
local guildDiffDragging = false
local guildDiffHighlight
local guildDiffOverrides = {}

local function GetInstanceDifficultyFrame()
	return MinimapCluster and MinimapCluster.InstanceDifficulty
end

local function GuildDiffUnlocked()
	return KUI.db and KUI.db.headerBarUnlocked and true or false
end

local function GuildDiffManaged()
	return KUI.db and KUI.db.guildDifficultyForced ~= false
end

local function GuildDiffForced()
	return GuildDiffManaged() and GuildDiffUnlocked()
end
local guildDiffWasForced

local function Override(obj, name, shouldBlock)
	local orig = FRAME_API[name]
	if not obj or not orig then return end
	obj[name] = function(self, ...)
		if shouldBlock(...) then return end
		return orig(self, ...)
	end
	guildDiffOverrides[#guildDiffOverrides + 1] = { obj, name }
end

local function BlockOutsiders() return not guildDiffInternal end
local function BlockHide() return GuildDiffForced() end
local function BlockHideSetShown(shown) return GuildDiffForced() and not shown end
local function BlockShow() return GuildDiffForced() end
local function BlockShowSetShown(shown) return GuildDiffForced() and shown and true or false end

local function InstallGuildDiffLocks(d)
	if guildDiffLocked then return end
	guildDiffLocked = true

	for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetParent", "SetAlpha", "SetFrameStrata" }) do
		Override(d, name, BlockOutsiders)
	end

	Override(d, "Hide", BlockHide)
	Override(d, "SetShown", BlockHideSetShown)
	Override(d.Guild, "Hide", BlockHide)
	Override(d.Guild, "SetShown", BlockHideSetShown)

	for _, child in ipairs({ d.Default, d.ChallengeMode }) do
		Override(child, "Show", BlockShow)
		Override(child, "SetShown", BlockShowSetShown)
	end
end

local function RemoveGuildDiffLocks()
	for _, entry in ipairs(guildDiffOverrides) do
		entry[1][entry[2]] = nil
	end
	wipe(guildDiffOverrides)
	guildDiffLocked = false
end

local function GuildDiffKey()
	return (KUI.db and KUI.db.squareMinimap) and "guilddifficultysquare" or "guilddifficulty"
end

local function GuildDiffTarget(d)
	local ratio = ScaleRatio(d)
	local positions = KUI.db.framePositions
	local pos = positions and (positions[GuildDiffKey()] or positions.guilddifficulty)
	if not pos then
		local w = (d:GetWidth() or 40) * ratio
		pos = KUI:ResolveScreenPosition({ from = "TOPRIGHT", dx = -(w + GUILD_DIFF_MARGIN), dy = -GUILD_DIFF_MARGIN })
	end
	return pos.x / ratio, pos.y / ratio
end

local function WithRawAccess(fn, ...)
	guildDiffInternal = true
	local ok, err = pcall(fn, ...)
	guildDiffInternal = false
	if not ok then geterrorhandler()(err) end
end

local function PlaceAndShow(d, forceVisible)
	local g = d.Guild
	if FRAME_API.GetParent(d) ~= UIParent then FRAME_API.SetParent(d, UIParent) end
	FRAME_API.SetFrameStrata(d, MINIMAP_STRATA)
	FRAME_API.SetAlpha(d, 1)
	if (d:GetWidth() or 0) < 1 or (d:GetHeight() or 0) < 1 then d:SetSize(40, 46) end

	local x, y = GuildDiffTarget(d)
	FRAME_API.ClearAllPoints(d)
	FRAME_API.SetPoint(d, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

	if not forceVisible then return end
	FRAME_API.Show(d)
	FRAME_API.Show(g)
	if d.Default then FRAME_API.Hide(d.Default) end
	if d.ChallengeMode then FRAME_API.Hide(d.ChallengeMode) end
end

local function RefreshBlizzardDifficulty(d)
	local fn = d.UpdateInstanceDifficulty or d.Update
	if type(fn) == "function" then
		pcall(fn, d)
	else
		local onEvent = d:GetScript("OnEvent")
		if onEvent then pcall(onEvent, d, "PLAYER_DIFFICULTY_CHANGED") end
	end
end

local function SetupGuildDiffDragging(d)
	if d.kainUIGuildDragHooked then return end
	d.kainUIGuildDragHooked = true

	d:SetMovable(true)

	local function OnDragStart()
		if not GuildDiffUnlocked() or guildDiffDragging then return end
		guildDiffDragging = true
		d:StartMoving()
		if KUI.BeginAlignDrag then KUI:BeginAlignDrag(d) end
	end
	local function OnDragStop()
		if not guildDiffDragging then return end
		d:StopMovingOrSizing()
		if KUI.EndAlignDrag then KUI:EndAlignDrag(d) end
		SaveDraggedPosition(d, GuildDiffKey())
		guildDiffDragging = false
		KUI:ApplyGuildDifficulty()
	end

	for _, f in ipairs({ d, d.Guild }) do
		f:RegisterForDrag("LeftButton")
		f:HookScript("OnDragStart", OnDragStart)
		f:HookScript("OnDragStop", OnDragStop)
	end

	guildDiffHighlight = d:CreateTexture(nil, "OVERLAY")
	guildDiffHighlight:SetAllPoints(d)
	guildDiffHighlight:SetColorTexture(0.2, 1, 0.4, 0.25)
	guildDiffHighlight:Hide()
end

local function ReleaseGuildDifficulty(d)
	local wasLocked = guildDiffLocked
	if guildDiffLocked then RemoveGuildDiffLocks() end
	if guildDiffHighlight then guildDiffHighlight:Hide() end
	d:EnableMouse(false)

	if MinimapCluster and d:GetParent() ~= MinimapCluster then d:SetParent(MinimapCluster) end
	if d.UpdateInstanceDifficulty then d:UpdateInstanceDifficulty() end

	if wasLocked and KUI.IsZoneBarActive and KUI:IsZoneBarActive() then KUI:ApplyZoneBar(true) end
end

function KUI:ApplyGuildDifficulty()
	local d = GetInstanceDifficultyFrame()
	if not d or not d.Guild or not KUI.db or guildDiffDragging then return end

	if not GuildDiffManaged() then
		ReleaseGuildDifficulty(d)
		return
	end

	SetupGuildDiffDragging(d)
	InstallGuildDiffLocks(d)

	local unlocked = GuildDiffUnlocked()
	d:SetClampedToScreen(not KUI.db.minimapUnclamped)
	d:EnableMouse(unlocked)
	if guildDiffHighlight then guildDiffHighlight:SetShown(unlocked) end

	WithRawAccess(PlaceAndShow, d, unlocked)

	if not unlocked and guildDiffWasForced ~= false then
		RefreshBlizzardDifficulty(d)
	end
	guildDiffWasForced = unlocked
end

function KUI:SetGuildDifficultyForced(enabled)
	if not KUI.db then return end
	KUI.db.guildDifficultyForced = enabled and true or false
	KUI:ApplyGuildDifficulty()
end

hooksecurefunc(KUI, "SetHeaderBarUnlocked", function() KUI:ApplyGuildDifficulty() end)
hooksecurefunc(KUI, "SetMinimapAnchorsLocked", function() KUI:ApplyGuildDifficulty() end)

if type(_G.SetUIVisibility) == "function" then
	pcall(hooksecurefunc, "SetUIVisibility", function(shown)
		if shown == false then return end
		C_Timer.After(0, function() KUI:ApplyGuildDifficulty() end)
	end)
end

local guildDiffLoadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(guildDiffLoadFrame, "ADDON_LOADED")
KUI:SafeRegisterEvent(guildDiffLoadFrame, "PLAYER_ENTERING_WORLD")
guildDiffLoadFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Minimap" then return end
	KUI:ApplyGuildDifficulty()

	if event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function() KUI:ApplyGuildDifficulty() end)
	end
end)

function KUI:GuildDifficultyScanReport()
	local d = GetInstanceDifficultyFrame()
	if not d then
		print("|cffff6060Kain-UI Forever:|r couldn't find MinimapCluster.InstanceDifficulty on this client build.")
		return
	end
	local left, top = d:GetLeft(), d:GetTop()
	if not left or not top then
		print("|cffff6060Kain-UI Forever:|r the icon has no on-screen position yet (try again after it has loaded).")
		return
	end
	local ratio = ScaleRatio(d)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local dx = math.floor((left * ratio - sw) * 10 + 0.5) / 10
	local dy = math.floor((top * ratio - sh) * 10 + 0.5) / 10
	local parent = d:GetParent()
	local key = GuildDiffKey()
	local saved = KUI.db and KUI.db.framePositions and KUI.db.framePositions[key]
	print("|cff33ff99Kain-UI Forever|r guild difficulty icon (" .. (key == "guilddifficultysquare" and "SQUARE" or "round") .. " minimap position):")
	print(string.format("  parent: %s, strata: %s, shown: %s, size: %.1f x %.1f",
		parent and (parent:GetName() or "<unnamed>") or "nil", d:GetFrameStrata(),
		tostring(d:IsShown()), d:GetWidth() or 0, d:GetHeight() or 0))
	print(string.format("  screen: %.1f x %.1f, top-left at (%.1f, %.1f) from bottom-left%s",
		sw, sh, left * ratio, top * ratio, saved and " (saved position)" or " (default position)"))
	print("  paste into KUI.KAIN_PRESET.minimapPositions in Core.lua:")
	print(string.format("|cffffff00%s = { from = \"TOPRIGHT\", dx = %s, dy = %s },|r", key, dx, dy))
	if not GuildDiffUnlocked() then
		print("  note: tick \"Unlock minimap elements\" first if you want to drag it before scanning.")
	end
end
