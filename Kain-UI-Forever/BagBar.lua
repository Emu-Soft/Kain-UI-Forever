local _, KUI = ...

local CANDIDATE_SLOTS = {
	{ key = "bag1", label = "Bag 1 (Quiver for Hunters)", names = { "CharacterBag0Slot" } },
	{ key = "bag2", label = "Bag 2", names = { "CharacterBag1Slot" } },
	{ key = "bag3", label = "Bag 3", names = { "CharacterBag2Slot" } },
	{ key = "bag4", label = "Bag 4", names = { "CharacterBag3Slot" } },
	{ key = "reagentbag", label = "Reagent Bag", names = { "CharacterReagentBag0Slot" } },

	{ key = "keyring", label = "Keyring", names = { "KeyRingButton", "CharacterKeyRingSlot" } },
}

local resolvedSlots

local function ResolveSlots()
	if resolvedSlots then return resolvedSlots end
	resolvedSlots = {}
	for _, candidate in ipairs(CANDIDATE_SLOTS) do
		for _, name in ipairs(candidate.names) do
			local frame = _G[name]
			if frame then
				table.insert(resolvedSlots, { key = candidate.key, label = candidate.label, frame = frame, name = name })
				break
			end
		end
	end
	return resolvedSlots
end

function KUI:BagScanReport()
	local slots = ResolveSlots()
	print("|cff33ff99Kain-UI Forever|r bag slot scan:")
	if #slots == 0 then
		print("  No candidate bag slot frames found on this client. The bag bar may use a different naming scheme than expected -- let me know and I'll adjust.")
		return
	end
	for _, slot in ipairs(slots) do
		print(string.format("  %s -> found as %s", slot.key, slot.name))
	end
	local foundKeys = {}
	for _, slot in ipairs(slots) do foundKeys[slot.key] = true end
	for _, candidate in ipairs(CANDIDATE_SLOTS) do
		if not foundKeys[candidate.key] then
			print(string.format("  %s -> not found (tried: %s)", candidate.key, table.concat(candidate.names, ", ")))
		end
	end
end

local hiddenByUs = {}

local function SetHiddenByUs(frame, wantHidden)
	if wantHidden then
		if frame:IsShown() then
			hiddenByUs[frame] = true
			frame:Hide()
		end
	elseif hiddenByUs[frame] then
		hiddenByUs[frame] = nil
		frame:Show()
	end
end

function KUI:ApplyBagSlotVisibility()
	if not KUI.db then return end
	local hidden = KUI.db.hiddenBagSlots
	for _, slot in ipairs(ResolveSlots()) do
		SetHiddenByUs(slot.frame, hidden[slot.key] and true or false)
	end
end

function KUI:SetBagSlotHidden(slotKey, isHidden)
	if not KUI.db then return end

	KUI.db.hiddenBagSlots[slotKey] = isHidden and true or false
	KUI:ApplyBagSlotVisibility()
end

function KUI:GetBagSlotOptions()

	local options = {}
	for _, slot in ipairs(ResolveSlots()) do
		table.insert(options, slot)
	end
	return options
end

local DEBUG_BUILD = "bagdebug-2"

function KUI:BagDebugReport()
	print("|cff33ff99Kain-UI Forever|r bag debug (" .. DEBUG_BUILD .. "):")

	local function label(frame, keyByChild)
		local name = (frame.GetDebugName and frame:GetDebugName()) or (frame.GetName and frame:GetName())
		local key = keyByChild and keyByChild[frame]
		return (name or "<unnamed>") .. (key and (" [key=" .. tostring(key) .. "]") or "")
	end

	local function describe(frame, keyByChild)
		local left = frame.GetLeft and frame:GetLeft()
		local top = frame.GetTop and frame:GetTop()
		left = left and math.floor(left + 0.5)
		top = top and math.floor(top + 0.5)
		local id = frame.GetID and frame:GetID()
		print(string.format("  %s (%s) id=%s shown=%s left=%s top=%s hiddenByKainUI=%s",
			label(frame, keyByChild), frame.GetObjectType and frame:GetObjectType() or "?",
			tostring(id), tostring(frame.IsShown and frame:IsShown()), tostring(left), tostring(top),
			tostring(hiddenByUs[frame] == true)))

		local fieldOf = {}
		pcall(function()
			for k, v in pairs(frame) do
				if type(v) == "table" or type(v) == "userdata" then fieldOf[v] = k end
			end
		end)
		if frame.GetRegions then
			for _, region in ipairs({ frame:GetRegions() }) do
				if region.GetText then
					local ok, text = pcall(region.GetText, region)
					if ok and text and text ~= "" then
						print(string.format("      text %s = \"%s\" (region shown=%s)",
							tostring(fieldOf[region] or (region.GetName and region:GetName()) or "<unnamed>"),
							tostring(text), tostring(region.IsShown and region:IsShown())))
					end
				end
			end
		end
		return left, top
	end

	local seen, at = {}, {}
	local function visit(frame, keyByChild)
		if not frame or seen[frame] then return end
		seen[frame] = true
		local left, top = describe(frame, keyByChild)
		if frame.IsShown and frame:IsShown() and left and top then
			local key = left .. "," .. top
			at[key] = at[key] or {}
			table.insert(at[key], label(frame, keyByChild))
		end
	end

	local bagsBar = _G.BagsBar
	if bagsBar and bagsBar.GetChildren then
		local keyByChild = {}
		pcall(function()
			for k, v in pairs(bagsBar) do
				if type(v) == "table" or type(v) == "userdata" then keyByChild[v] = k end
			end
		end)
		print("  -- children of BagsBar --")
		for _, child in ipairs({ bagsBar:GetChildren() }) do visit(child, keyByChild) end
	else
		print("  BagsBar not found.")
	end

	print("  -- named bag frames (if not already listed) --")
	visit(_G.MainMenuBarBackpackButton)
	visit(_G.BackpackButton)
	for _, candidate in ipairs(CANDIDATE_SLOTS) do
		for _, name in ipairs(candidate.names) do visit(_G[name]) end
	end

	local anyStacked = false
	for key, names in pairs(at) do
		if #names > 1 then
			anyStacked = true
			print(string.format("  |cffff6060STACKED at %s:|r %s", key, table.concat(names, " + ")))
		end
	end
	if not anyStacked then print("  No shown buttons share a position.") end
end

function KUI:ApplyBagBarBorderArt()
	if not KUI.db then return end
	local borderArt = _G.BagsBar and _G.BagsBar.BorderArt
	if not borderArt then return end
	SetHiddenByUs(borderArt, KUI.db.hideBagBarBorderArt and true or false)
end

function KUI:SetBagBarBorderArtHidden(isHidden)
	if not KUI.db then return end
	KUI.db.hideBagBarBorderArt = isHidden
	KUI:ApplyBagBarBorderArt()
end

function KUI:HasBagBarBorderArt()
	return (_G.BagsBar and _G.BagsBar.BorderArt) and true or false
end

local resolvedDividers

local function ResolveDividers()
	if resolvedDividers then return resolvedDividers end
	resolvedDividers = {}
	local bagsBar = _G.BagsBar
	if not bagsBar or not bagsBar.GetChildren then return resolvedDividers end

	for _, child in ipairs({ bagsBar:GetChildren() }) do
		local isDivider = false
		if child.GetRegions then
			for _, region in ipairs({ child:GetRegions() }) do
				local atlas = region.GetAtlas and region:GetAtlas()
				if atlas and atlas:lower():find("divider") then
					isDivider = true
					break
				end
			end
		end

		if not isDivider and child.GetAtlas then
			local atlas = child:GetAtlas()
			if atlas and atlas:lower():find("divider") then
				isDivider = true
			end
		end
		if isDivider then
			table.insert(resolvedDividers, child)
		end
	end
	return resolvedDividers
end

function KUI:BagDividerScanReport()
	local dividers = ResolveDividers()
	print("|cff33ff99Kain-UI Forever|r bag bar divider scan:")
	if #dividers == 0 then
		print("  No divider textures found under BagsBar on this client (matched by atlas name containing \"divider\"). Try /kainui dumpframe BagsBar to see what's actually there.")
		return
	end
	print(string.format("  Found %d divider(s).", #dividers))
end

function KUI:ApplyBagBarDividers()
	if not KUI.db then return end
	for _, divider in ipairs(ResolveDividers()) do
		SetHiddenByUs(divider, KUI.db.hideBagBarDividers and true or false)
	end
end

function KUI:SetBagBarDividersHidden(isHidden)
	if not KUI.db then return end
	KUI.db.hideBagBarDividers = isHidden
	KUI:ApplyBagBarDividers()
end

function KUI:HasBagBarDividers()
	return #ResolveDividers() > 0
end

function KUI:SetBagBarChromeHidden(isHidden)
	if not KUI.db then return end
	KUI:SetBagBarBorderArtHidden(isHidden)
	KUI:SetBagBarDividersHidden(isHidden)
end

local watching = false
local lastText = setmetatable({}, { __mode = "k" })
local hookedRegions = setmetatable({}, { __mode = "k" })

local function ShortStack()
	if not debugstack then return {} end
	local ok, stack = pcall(debugstack, 3, 6, 0)
	if not ok or type(stack) ~= "string" then return {} end
	local lines = {}
	for line in stack:gmatch("[^\n]+") do
		line = line:gsub("Interface[\\/]AddOns[\\/]", ""):gsub("Interface[\\/]", "")
		lines[#lines + 1] = line
	end

	if lines[1] and lines[1]:find("BagBar%.lua") then table.remove(lines, 1) end
	return lines
end

local function FrameLabel(frame)
	local name = (frame.GetDebugName and frame:GetDebugName()) or (frame.GetName and frame:GetName())
	return name or "<unnamed>"
end

local function FieldNameOf(owner, region)
	local found
	pcall(function()
		for k, v in pairs(owner) do
			if v == region then found = tostring(k); return end
		end
	end)
	return found or (region.GetName and region:GetName()) or "<region>"
end

local function HookRegion(region, label)
	if hookedRegions[region] then return end
	hookedRegions[region] = true

	local function onSet(r, text)
		if not watching then return end
		if issecretvalue and issecretvalue(text) then return end
		local shown = tostring(text)
		if lastText[r] == shown then return end
		lastText[r] = shown
		print(string.format("|cff33ff99[bagwatch]|r %s := \"%s\"", label, shown))
		for _, line in ipairs(ShortStack()) do
			local colour = line:find("Kain%-UI") and "|cffff6060" or "|cff999999"
			print("    " .. colour .. line .. "|r")
		end
	end
	pcall(hooksecurefunc, region, "SetText", onSet)
	pcall(hooksecurefunc, region, "SetFormattedText", function(r, fmt, ...)
		if type(fmt) ~= "string" then return end
		local ok, text = pcall(string.format, fmt, ...)
		if ok then onSet(r, text) end
	end)
end

function KUI:BagWatch(arg)
	if arg == "off" then
		watching = false
		print("|cff33ff99Kain-UI Forever|r bagwatch stopped.")
		return
	end
	watching = true

	local count = 0
	local function addFrame(frame, depth)
		if not frame or not frame.GetRegions then return end
		local frameLabel = FrameLabel(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText and region.SetText then
				HookRegion(region, frameLabel .. "." .. FieldNameOf(frame, region))
				local ok, text = pcall(region.GetText, region)
				if ok and text then lastText[region] = tostring(text) end
				count = count + 1
			end
		end
		if depth < 2 and frame.GetChildren then
			for _, child in ipairs({ frame:GetChildren() }) do addFrame(child, depth + 1) end
		end
	end

	if _G.BagsBar then addFrame(_G.BagsBar, 0) end
	addFrame(_G.MainMenuBarBackpackButton, 1)
	addFrame(_G.BackpackButton, 1)
	for _, candidate in ipairs(CANDIDATE_SLOTS) do
		for _, name in ipairs(candidate.names) do addFrame(_G[name], 1) end
	end

	print(string.format("|cff33ff99Kain-UI Forever|r bagwatch: watching %d text regions. Now trigger the glitch (delete an item), then copy what printed here. /kainui bagwatch off to stop.", count))
end

local backpackFixInstalled = false
local backpackFixFrame

local function ComputeFreeSlots()
	local total = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		local ok, free, family = pcall(C_Container.GetContainerNumFreeSlots, bag)

		if ok and free and (family == 0 or family == nil) then total = total + free end
	end
	return total
end

local function RefreshBackpackFreeSlots()
	local button = _G.MainMenuBarBackpackButton
	if not button then return end
	if type(button.UpdateFreeSlots) == "function" then
		pcall(button.UpdateFreeSlots, button)
	elseif button.Count and C_Container and C_Container.GetContainerNumFreeSlots then
		button.Count:SetText("(" .. ComputeFreeSlots() .. ")")
	end

	if button.Count and not button.Count:IsShown() then
		button.Count:Show()
	end
end

local function FindBackpackIcon(button)
	local icon = button.icon or button.Icon or _G.MainMenuBarBackpackButtonIconTexture
	if icon then return icon end
	if button.GetRegions then
		for _, region in ipairs({ button:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture and region:GetTexture() then
				return region
			end
		end
	end
end

local backpackIcon, backpackSaved
local backpackStats = { rehidden = 0, paperDollHooked = false, regionHooked = false }

local function SnapshotBackpackIcon()
	local button = _G.MainMenuBarBackpackButton
	if not button then return end
	local icon = FindBackpackIcon(button)
	if not icon then return end
	backpackIcon = icon
	local points = {}
	for i = 1, icon:GetNumPoints() do points[i] = { icon:GetPoint(i) } end
	local layer, sublevel
	if icon.GetDrawLayer then layer, sublevel = icon:GetDrawLayer() end

	local mask = button.SquareMask
	if not mask and icon.GetNumMaskTextures and icon:GetNumMaskTextures() > 0 then mask = icon:GetMaskTexture(1) end
	local maskAtlas, maskW, maskH
	if mask then
		if mask.GetAtlas then maskAtlas = mask:GetAtlas() end
		maskW, maskH = mask:GetWidth(), mask:GetHeight()
	end
	backpackSaved = {
		texture = icon.GetTexture and icon:GetTexture() or nil,
		coords = icon.GetTexCoord and { icon:GetTexCoord() } or nil,
		w = icon:GetWidth(), h = icon:GetHeight(),
		points = points,
		layer = layer, sublevel = sublevel,
		maskAtlas = maskAtlas, maskW = maskW, maskH = maskH,
	}
end
SnapshotBackpackIcon()

local standIn
local standInMask
local hidingRealIcon = false

local function KeepRealIconHidden()
	local icon = backpackIcon
	if not icon or hidingRealIcon or not icon.GetAlpha then return end
	if icon:GetAlpha() ~= 0 then
		hidingRealIcon = true
		icon:SetAlpha(0)
		hidingRealIcon = false
		backpackStats.rehidden = (backpackStats.rehidden or 0) + 1
	end
end

local function MirrorIconLook()
	local icon = backpackIcon
	if not (standIn and icon) then return end
	pcall(function()
		if icon.IsDesaturated and standIn.SetDesaturated then standIn:SetDesaturated(icon:IsDesaturated() and true or false) end

		if icon.GetVertexColor and standIn.SetVertexColor then
			local r, g, b = icon:GetVertexColor()
			if type(r) == "number" and type(g) == "number" and type(b) == "number" then
				standIn:SetVertexColor(r, g, b, 1)
			end
		end
	end)
end

local function CreateBackpackStandIn(button)
	if standIn then return standIn end
	local icon, saved = backpackIcon, backpackSaved
	if not (icon and saved) then return nil end
	local t = button:CreateTexture(nil, saved.layer or "ARTWORK", nil, saved.sublevel or 0)
	if saved.texture then t:SetTexture(saved.texture) end
	if saved.coords and #saved.coords == 8 then t:SetTexCoord(unpack(saved.coords)) end

	local placed = false
	for _, p in ipairs(saved.points) do
		local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
		if rel == icon or rel == nil then rel = button end
		t:SetPoint(point, rel, relPoint, x, y)
		placed = true
	end
	if not placed then t:SetPoint("CENTER", button, "CENTER") end
	if type(saved.w) == "number" and saved.w > 0 and type(saved.h) == "number" and saved.h > 0 then
		t:SetSize(saved.w, saved.h)
	end

	if button.CreateMaskTexture and t.AddMaskTexture then
		local mask = button:CreateMaskTexture()
		local atlas = saved.maskAtlas or "UI-HUD-ActionBar-IconFrame-Mask"

		local mw, mh
		if mask.SetAtlas then
			mask:SetAtlas(atlas, true)
			mw, mh = mask:GetWidth(), mask:GetHeight()
		end
		if not (type(mw) == "number" and mw > 0 and type(mh) == "number" and mh > 0) then
			local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
			if type(info) == "table" and type(info.width) == "number" and info.width > 0 then
				mw, mh = info.width, info.height
			else
				mw, mh = 64, 64
			end
		end
		mask:SetSize(mw, mh)
		mask:SetPoint("CENTER", t, "CENTER", 0, 0)
		t:AddMaskTexture(mask)
		standInMask = mask
	end
	standIn = t
	MirrorIconLook()
	return t
end

local function HookPaperDoll(button)
	if backpackStats.paperDollHooked or type(_G.PaperDollItemSlotButton_Update) ~= "function" then return end
	backpackStats.paperDollHooked = true
	hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
		if btn and btn == button then
			KeepRealIconHidden()
			RefreshBackpackFreeSlots()
		end
	end)
end

function KUI:InstallBackpackCountFix()
	if backpackFixInstalled then return end
	local button = _G.MainMenuBarBackpackButton
	if not button then return end
	if not backpackSaved then SnapshotBackpackIcon() end
	if not backpackIcon then return end
	if not CreateBackpackStandIn(button) then return end
	backpackFixInstalled = true

	KeepRealIconHidden()
	if not backpackStats.regionHooked then
		backpackStats.regionHooked = true
		if backpackIcon.SetAlpha then
			hooksecurefunc(backpackIcon, "SetAlpha", function() KeepRealIconHidden() end)
		end
		for _, method in ipairs({ "SetDesaturated", "SetVertexColor" }) do
			if backpackIcon[method] then hooksecurefunc(backpackIcon, method, MirrorIconLook) end
		end
	end

	HookPaperDoll(button)

	local function DeferredRefresh()
		C_Timer.After(0, function()
			KeepRealIconHidden()
			RefreshBackpackFreeSlots()
		end)
	end

	if not backpackFixFrame then
		backpackFixFrame = CreateFrame("Frame")
		for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_INVENTORY_CHANGED", "ADDON_LOADED" }) do
			KUI:SafeRegisterEvent(backpackFixFrame, event)
		end
		backpackFixFrame:SetScript("OnEvent", function(_, event)
			if event == "ADDON_LOADED" then HookPaperDoll(button); return end
			DeferredRefresh()
		end)
	end

	RefreshBackpackFreeSlots()
end

local BAGBAR_REV = 142
function KUI:BackpackFixScanReport()
	local icon, saved = backpackIcon, backpackSaved
	print("|cff33ff99Kain-UI Forever|r backpack icon (BagBar.lua rev " .. BAGBAR_REV .. "): " .. (backpackFixInstalled and "STAND-IN active" or "not installed")
		.. " | paper-doll hook " .. (backpackStats.paperDollHooked and "on" or "off (function not found yet)")
		.. " | Blizzard icon re-hidden " .. (backpackStats.rehidden or 0) .. "x")
	if not (icon and saved) then print("  icon not found / not recorded"); return end
	local function coords(t)
		if not t then return "?" end
		local o = {}
		for i = 1, #t do o[i] = string.format("%.3f", t[i]) end
		return table.concat(o, " ")
	end
	print(string.format("  recorded at load: %.1f x %.1f, anchors %d, coords %s, layer %s %s", saved.w or 0, saved.h or 0, #saved.points, coords(saved.coords), tostring(saved.layer), tostring(saved.sublevel)))
	if standIn then
		local _, _, _, va = standIn:GetVertexColor()
		print(string.format("  Kain-UI's icon:   %.1f x %.1f, coords %s, shown %s, visible %s, alpha %.2f, colour alpha %s", standIn:GetWidth(), standIn:GetHeight(), coords({ standIn:GetTexCoord() }), tostring(standIn:IsShown()), tostring(standIn.IsVisible and standIn:IsVisible()), standIn.GetAlpha and standIn:GetAlpha() or -1, va and string.format("%.2f", va) or "?"))
	end
	if standInMask then
		print(string.format("  Kain-UI's mask:   %.1f x %.1f (%s), recorded from Blizzard's %.1f x %.1f", standInMask:GetWidth(), standInMask:GetHeight(), tostring(saved.maskAtlas), saved.maskW or 0, saved.maskH or 0))
	end
	local bmask = _G.MainMenuBarBackpackButton and _G.MainMenuBarBackpackButton.SquareMask
	if bmask then

		print(string.format("  Blizzard's mask:  %.1f x %.1f, anchors %d", bmask:GetWidth(), bmask:GetHeight(), bmask.GetNumPoints and bmask:GetNumPoints() or -1))
	end

	print(string.format("  Blizzard's icon:  %.1f x %.1f, coords %s, alpha %.2f (hidden)", icon:GetWidth(), icon:GetHeight(), coords({ icon:GetTexCoord() }), icon.GetAlpha and icon:GetAlpha() or -1))
end
