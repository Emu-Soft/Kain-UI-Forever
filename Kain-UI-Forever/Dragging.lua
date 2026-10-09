local addonName, KUI = ...

local DRAG_STRIP_HEIGHT = 30

local DRAG_TARGETS = {

	{ key = "character", label = "Character", names = { "CharacterFrame" },
		surfaces = { "PaperDollFrame", "ReputationFrame", "TokenFrame", "PaperDollItemsFrame",
			"CharacterFrameLeftPaneHost", "CharacterFrameRightPaneHost" } },
	{ key = "macro", label = "Macros", names = { "MacroFrame" } },
	{ key = "spellbook", label = "Spellbook", names = { "PlayerSpellsFrame", "SpellBookFrame" } },

	{ key = "talents", label = "Talents", names = { "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame", "TalentFrame" } },
	{ key = "map", label = "Map & Quest Log", names = { "WorldMapFrame" } },

	{ key = "bags", label = "Combined Bags", names = { "ContainerFrameCombinedBags" },
		forceSurfaces = {
			"ContainerFrameCombinedBags.TitleContainer",
			"ContainerFrameCombinedBags.TitleText",
		} },

	{ key = "professions", label = "Professions", names = { "ProfessionsFrame", "TradeSkillFrame" } },

	{ key = "craft", label = "Enchanting / Craft", names = { "CraftFrame" } },

	{ key = "quest", label = "Quest dialogue", names = { "QuestFrame" }, posKey = "npc" },

	{ key = "gossip", label = "NPC dialogue", names = { "GossipFrame" }, posKey = "npc" },
	{ key = "vendor", label = "Vendor", names = { "MerchantFrame" }, posKey = "npc" },
	{ key = "trainer", label = "Trainer", names = { "ClassTrainerFrame" }, posKey = "npc" },
	{ key = "guildregistrar", label = "Guild Registrar", names = { "GuildRegistrarFrame" }, posKey = "npc" },

	{ key = "calendar", label = "Calendar", names = { "CalendarFrame" } },

	{ key = "legacy", label = "Legacy Tree", names = { "LegacySystemFrame" } },

	{ key = "social", label = "Social", names = { "SocialUIFrame" } },
}

local states = setmetatable({}, { __mode = "k" })
local applyAfterCombat = false

local function IsEnabled()
	return KUI.db and KUI.db.globalDragging
end

local function ResolveTargets()
	local list, claimed = {}, {}
	for _, target in ipairs(DRAG_TARGETS) do
		local entry = { target = target }
		for _, name in ipairs(target.names) do
			local frame = _G[name]
			local kind = type(frame)
			if (kind == "table" or kind == "userdata") and frame.SetMovable then
				if claimed[frame] then
					entry.sharedWith = claimed[frame]
				else
					claimed[frame] = target.key
					entry.frame, entry.name = frame, name
				end
				break
			end
		end
		table.insert(list, entry)
	end
	return list
end

local function IsBlocked(frame)
	if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
		return true
	end
	if frame.IsMaximized and frame:IsMaximized() then
		return true
	end
	return false
end

local function ScaleRatio(frame)
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if not ratio or ratio <= 0 then ratio = 1 end
	return ratio
end

local function WritePosition(frame, state, pos, ratio)

	state.applying = true
	pcall(function()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / ratio, pos.y / ratio)
	end)
	state.applying = false
end

local pendingCorrections = {}
local correctionDriver = CreateFrame("Frame")
correctionDriver:Hide()
correctionDriver:SetScript("OnUpdate", function(self)
	self:Hide()
	local queue = pendingCorrections
	pendingCorrections = {}
	for _, item in ipairs(queue) do
		WritePosition(item.frame, item.state, item.pos, item.ratio)
	end
end)

local function QueueCorrection(frame, state, pos, ratio)
	table.insert(pendingCorrections, { frame = frame, state = state, pos = pos, ratio = ratio })
	correctionDriver:Show()
end

local function ApplyPosition(frame, state, deferred)
	if not IsEnabled() or state.moving or state.applying then return end
	if not frame:IsShown() or IsBlocked(frame) then return end
	local pos = KUI.db.framePositions and KUI.db.framePositions[state.key]
	if not pos then return end

	local ratio = ScaleRatio(frame)

	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top and math.abs(left * ratio - pos.x) < 0.5 and math.abs(top * ratio - pos.y) < 0.5 then
		return
	end

	if deferred then
		QueueCorrection(frame, state, pos, ratio)
	else
		WritePosition(frame, state, pos, ratio)
	end
end

local function SavePosition(frame, state)
	if not KUI.db then return end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not left or not top then return end
	local ratio = ScaleRatio(frame)
	KUI.db.framePositions = KUI.db.framePositions or {}
	KUI.db.framePositions[state.key] = { x = left * ratio, y = top * ratio }
end

local function IsProtectedWindow(frame)
	return frame.IsProtected and frame:IsProtected() and true or false
end

local function SafeSetMovable(frame, movable)
	if IsProtectedWindow(frame) and InCombatLockdown() then return false end
	frame:SetMovable(movable)
	return true
end

local function SafeSetClamped(frame, clamped)
	if IsProtectedWindow(frame) then return end
	frame:SetClampedToScreen(clamped)
end

local function StartDrag(frame, state)
	if not IsEnabled() or state.moving or IsBlocked(frame) then return end

	SafeSetMovable(frame, true)
	SafeSetClamped(frame, true)
	state.moving = true
	local ok = pcall(frame.StartMoving, frame)
	if not ok then state.moving = false end
end

local function StopDrag(frame, state)
	if not state.moving then return end
	state.moving = false
	frame:StopMovingOrSizing()

	pcall(frame.SetUserPlaced, frame, false)
	SavePosition(frame, state)

	for otherFrame, other in pairs(states) do
		if otherFrame ~= frame and not other.failed and other.key == state.key then
			ApplyPosition(otherFrame, other, false)
		end
	end
end

local MAX_SCAN_DEPTH = 3
local MAX_SCAN_FRAMES = 400
local OWN_MOUSE_SCRIPTS = { "OnDragStart", "OnMouseDown", "OnMouseUp", "OnMouseWheel" }

local function HasOwnMouseBehaviour(f)
	for _, script in ipairs(OWN_MOUSE_SCRIPTS) do
		if f:GetScript(script) then return true end
	end
	return false
end

local function CoversTitleArea(window, child)
	local wTop, wLeft, wRight = window:GetTop(), window:GetLeft(), window:GetRight()
	local cTop, cLeft, cRight = child:GetTop(), child:GetLeft(), child:GetRight()
	if not (wTop and wLeft and wRight and cTop and cLeft and cRight) then
		return window:IsShown() and true or false
	end
	local overlapsBand = cTop >= wTop - DRAG_STRIP_HEIGHT
	local wide = (cRight - cLeft) >= (wRight - wLeft) * 0.4
	return overlapsBand and wide
end

local function HookDragSurface(frame, state, surface, how)
	if surface == frame or surface == state.strip or state.surfaces[surface] then return end
	state.surfaces[surface] = how
	table.insert(state.surfaceNames, (surface.GetName and surface:GetName()) or "(unnamed frame)")
	surface:RegisterForDrag("LeftButton")
	surface:HookScript("OnDragStart", function() StartDrag(frame, state) end)
	surface:HookScript("OnDragStop", function() StopDrag(frame, state) end)
end

local function ScanDescendants(window, frame, depth, state, budget)
	local children = { frame:GetChildren() }
	for _, child in ipairs(children) do
		budget.n = budget.n + 1
		if budget.n > MAX_SCAN_FRAMES then return end
		if child ~= state.strip then
			if child:GetObjectType() == "Frame" and child:IsMouseEnabled()
				and not HasOwnMouseBehaviour(child) and CoversTitleArea(window, child) then
				HookDragSurface(window, state, child, "scan")
			end
			if depth < MAX_SCAN_DEPTH then
				ScanDescendants(window, child, depth + 1, state, budget)
			end
		end
	end
end

local function ResolveDotPath(dotpath)
	local segments = {}
	for seg in dotpath:gmatch("[^%.]+") do table.insert(segments, seg) end
	local obj = _G[segments[1]]
	if not obj then return nil end
	for i = 2, #segments do
		obj = obj[segments[i]]
		if obj == nil then return nil end
	end
	return obj
end

local function HookForcedDragSurface(window, state, surface)
	if surface == window or surface == state.strip or state.surfaces[surface] then return end

	if not surface.HookScript then return end
	state.surfaces[surface] = "forced"
	table.insert(state.surfaceNames, (surface.GetName and surface:GetName()) or "(unnamed forced surface)")
	if surface.RegisterForDrag then
		surface:RegisterForDrag("LeftButton")
	end
	surface:HookScript("OnDragStart", function() StartDrag(window, state) end)
	surface:HookScript("OnDragStop", function() StopDrag(window, state) end)
	surface:HookScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and IsEnabled() then
			StartDrag(window, state)
		end
	end)
	surface:HookScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			StopDrag(window, state)
		end
	end)
end

local function RescanSurfaces(frame, state)
	for _, name in ipairs(state.explicitSurfaces or {}) do
		local surface = _G[name]
		local kind = type(surface)
		if (kind == "table" or kind == "userdata") and surface.RegisterForDrag and not surface:GetScript("OnDragStart") then
			HookDragSurface(frame, state, surface, "named")
		end
	end
	for _, dotpath in ipairs(state.forcedSurfacePaths or {}) do
		local surface = ResolveDotPath(dotpath)
		if surface then
			HookForcedDragSurface(frame, state, surface)
		end
	end
	ScanDescendants(frame, frame, 1, state, { n = 0 })
end

local function QueueRescan(frame, state)
	if state.rescanQueued or not IsEnabled() then return end
	if not (C_Timer and C_Timer.After) then
		RescanSurfaces(frame, state)
		return
	end
	state.rescanQueued = true
	C_Timer.After(0, function()
		state.rescanQueued = false
		if IsEnabled() then RescanSurfaces(frame, state) end
	end)
end

local failureShown = {}

local function SetupFrame(target, frame, name)
	local state = { key = target.posKey or target.key, label = target.label, name = name,
		surfaces = {}, surfaceNames = {}, explicitSurfaces = target.surfaces,
		forcedSurfacePaths = target.forceSurfaces }
	states[frame] = state
	state.origMovable = (frame.IsMovable and frame:IsMovable()) and true or false
	state.origClamped = (frame.IsClampedToScreen and frame:IsClampedToScreen()) and true or false

	local strip = CreateFrame("Frame", nil, frame)
	strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	strip:SetHeight(DRAG_STRIP_HEIGHT)
	strip:SetFrameLevel(frame:GetFrameLevel())
	strip:EnableMouse(true)
	strip:RegisterForDrag("LeftButton")
	strip:SetScript("OnDragStart", function() StartDrag(frame, state) end)
	strip:SetScript("OnDragStop", function() StopDrag(frame, state) end)
	state.strip = strip

	if frame.IsMouseEnabled and frame:IsMouseEnabled() then
		frame:RegisterForDrag("LeftButton")
		frame:HookScript("OnDragStart", function() StartDrag(frame, state) end)
		frame:HookScript("OnDragStop", function() StopDrag(frame, state) end)
	end

	frame:HookScript("OnHide", function() StopDrag(frame, state) end)

	frame:HookScript("OnShow", function()
		ApplyPosition(frame, state, true)
		QueueRescan(frame, state)
	end)
	hooksecurefunc(frame, "SetPoint", function()
		if not state.applying and not state.moving then
			ApplyPosition(frame, state, false)
		end
	end)

	RescanSurfaces(frame, state)
end

local function ActivateFrame(frame, state)
	SafeSetMovable(frame, true)
	SafeSetClamped(frame, true)
	state.strip:Show()
	RescanSurfaces(frame, state)
	ApplyPosition(frame, state, false)
end

local function DeactivateFrame(frame, state)
	StopDrag(frame, state)
	state.strip:Hide()
	SafeSetMovable(frame, state.origMovable)
	SafeSetClamped(frame, state.origClamped)
end

function KUI:ApplyGlobalDragging()
	if not KUI.db then return end

	if InCombatLockdown() then
		applyAfterCombat = true
		return
	end
	local enabled = KUI.db.globalDragging

	for _, entry in ipairs(ResolveTargets()) do
		local frame = entry.frame
		if frame then
			local state = states[frame]
			if enabled and not state then
				local ok, err = pcall(SetupFrame, entry.target, frame, entry.name)
				if not ok then
					states[frame] = { failed = true }
					if not failureShown[entry.name] then
						failureShown[entry.name] = true
						print("|cffff6060Kain-UI Forever:|r couldn't make " .. entry.name .. " draggable (" .. tostring(err) .. ") -- the other windows are unaffected.")
					end
				end
				state = states[frame]
			end
			if state and not state.failed then
				if enabled then
					ActivateFrame(frame, state)
				else
					DeactivateFrame(frame, state)
				end
			end
		end
	end
end

function KUI:SetGlobalDragging(enabled)
	if not KUI.db then return end
	KUI.db.globalDragging = enabled and true or false
	KUI:ApplyGlobalDragging()
end

function KUI:ResetDragPositions()
	if not KUI.db then return end
	KUI.db.framePositions = {}
	print("|cff33ff99Kain-UI Forever|r saved window positions cleared -- each window returns to its normal spot the next time it opens (or after /reload).")
end

function KUI:DragScanReport()
	print("|cff33ff99Kain-UI Forever|r window drag scan (global dragging is " .. ((KUI.db and KUI.db.globalDragging) and "ON" or "OFF") .. "):")
	local claimedNames = {}
	for _, entry in ipairs(ResolveTargets()) do
		local target = entry.target
		if entry.frame then
			claimedNames[entry.name] = true
			local state = states[entry.frame]
			local status = "found, not hooked yet"
			if state then status = state.failed and "SETUP FAILED" or "hooked" end
			local saved = KUI.db and KUI.db.framePositions and KUI.db.framePositions[target.posKey or target.key]
			print(string.format("  %s -> found as %s (%s)%s", target.key, entry.name, status, saved and ", has a saved position" or ""))
			if state and state.surfaceNames and #state.surfaceNames > 0 then
				print("      also draggable from: " .. table.concat(state.surfaceNames, ", "))
			end
		elseif entry.sharedWith then
			print(string.format("  %s -> same window as %s", target.key, entry.sharedWith))
		else
			print(string.format("  %s -> not found (tried: %s). If it's a load-on-demand window, open it once and run this again.", target.key, table.concat(target.names, ", ")))
		end
	end

	local others = {}
	if type(UIPanelWindows) == "table" then
		for name in pairs(UIPanelWindows) do
			if type(name) == "string" and not claimedNames[name] and _G[name] then
				table.insert(others, name)
			end
		end
	end
	if #others > 0 then
		table.sort(others)
		local shown = {}
		for i = 1, math.min(#others, 30) do shown[i] = others[i] end
		print("  other panel windows present right now: " .. table.concat(shown, ", ") .. (#others > 30 and ", ..." or ""))
	end
end

local loadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(loadFrame, "ADDON_LOADED")
KUI:SafeRegisterEvent(loadFrame, "PLAYER_REGEN_ENABLED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event == "PLAYER_REGEN_ENABLED" then
		if applyAfterCombat then
			applyAfterCombat = false
			if KUI.db and KUI.db.globalDragging then KUI:ApplyGlobalDragging() end
		end
		return
	end
	if loadedAddonName == addonName then return end
	if not KUI.db or not KUI.db.globalDragging then return end
	KUI:ApplyGlobalDragging()
end)
