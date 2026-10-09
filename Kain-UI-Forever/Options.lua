local addonName, KUI = ...

KUI.SKIP = {
	minimap = false,
	chat = false,
	bags = false,
	micro = false,
	dragging = false,
	xpbar = false,
	vendor = false,
	macros = false,
	loot = false,
	contrast = false,
	tooltip = false,
	border = false,
	rxptweaks = false,
	camera = false,
}

local function Run(group, funcName, ...)
	if KUI.SKIP[group] then return end
	local fn = KUI[funcName]
	if fn then fn(KUI, ...) end
end

function KUI:ApplyAll()
	Run("minimap", "ApplyMinimapClamp")
	Run("minimap", "DetachMinimap", KUI.db.minimapDetached)
	Run("minimap", "SetMinimapAnchorsLocked", KUI.db.anchorsLocked)
	Run("minimap", "SetHeaderBarUnlocked", KUI.db.headerBarUnlocked)
	Run("minimap", "ApplyGuildDifficulty")
	Run("minimap", "ApplySquareMinimap")
	Run("minimap", "ApplyMinimapButtonBin")
	Run("chat", "ApplyChatClamp")
	Run("chat", "ApplyChatTimestamps")
	Run("chat", "ApplyChatChannelShorthands")
	Run("chat", "ApplyChatChannelNumberFilter")
	Run("chat", "ApplyChatLinkify")
	Run("chat", "EnsureChatCopyButton")
	Run("chat", "EnsureChatHistoryRecall")
	Run("chat", "ApplySocialButton")
	Run("bags", "ApplyBagSlotVisibility")
	Run("bags", "ApplyBagBarBorderArt")
	Run("bags", "ApplyBagBarDividers")
	Run("bags", "InstallBackpackCountFix")
	Run("micro", "ApplyMicroMenuVisibility")
	Run("dragging", "ApplyGlobalDragging")
	Run("xpbar", "ApplyXPBar")
	Run("vendor", "ApplyAutoSellGreys")
	Run("vendor", "ApplyAutoRepair")
	Run("loot", "ApplyLootRollDragging")

	if C_Timer and C_Timer.After then
		C_Timer.After(1, function()
			Run("macros", "InstallStarterMacros", true)

			Run("macros", "SyncWeaponSwapMacro", false, true)
		end)
	else
		Run("macros", "InstallStarterMacros", true)
		Run("macros", "SyncWeaponSwapMacro", false, true)
	end
	Run("contrast", "ApplyContrast")
	Run("tooltip", "ApplyTooltipAnchor")
	Run("rxptweaks", "ApplyRXPTweaks")
	Run("rxptweaks", "ApplyFollowRXPObjectives")
	Run("camera", "ApplyCameraTweaks")
end

local panel

local COL1_X = 16
local COL2_X = 318
local COL3_X, COL3_W = 526, 192
local COL4_X = 734

local PANEL_WIDTH = 1000
local PANEL_HEIGHT = 500

local refreshers = {}
local function RefreshPanel()
	for _, refresh in ipairs(refreshers) do pcall(refresh) end
end

local function CreateCheckbox(parent, label, x, y, getChecked, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	check:SetSize(22, 22)
	local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", check, "RIGHT", 2, 0)
	text:SetText(label)
	check.label = text
	check:SetChecked(getChecked())
	check:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)

	table.insert(refreshers, function() check:SetChecked(getChecked() and true or false) end)
	return check
end

local INFO_ICON = "Interface\\FriendsFrame\\InformationIcon"
local INFO_ICON_HIGHLIGHT = "Interface\\FriendsFrame\\InformationIcon-Highlight"
local INFO_ICON_SIZE = 16

local function AddInfoButton(parent, anchor, title, text)
	local info = CreateFrame("Button", nil, parent)
	info:SetSize(INFO_ICON_SIZE, INFO_ICON_SIZE)
	info:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
	info:SetNormalTexture(INFO_ICON)
	info:SetHighlightTexture(INFO_ICON_HIGHLIGHT, "ADD")
	info:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		GameTooltip:AddLine(text, 1, 0.82, 0, true)
		GameTooltip:Show()
	end)
	info:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return info
end

local function CreateSlider(parent, x, y, width, minValue, maxValue, step)
	local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetPoint("TOPLEFT", x, y)
	slider:SetSize(width, 17)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

	local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
	if thumb and thumb.SetSize then thumb:SetSize(32, 32) end
	if slider.SetBackdrop then
		slider:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		})
	end
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta * step)
	end)

	slider:HookScript("OnShow", function(self)
		local function Reseat()
			local value = self:GetValue()
			local lo, hi = self:GetMinMaxValues()
			if type(value) ~= "number" or type(lo) ~= "number" or type(hi) ~= "number" or lo == hi then return end
			local handler = self:GetScript("OnValueChanged")
			self:SetScript("OnValueChanged", nil)
			self:SetValue(value == hi and lo or hi)
			self:SetValue(value)
			self:SetScript("OnValueChanged", handler)
		end
		if C_Timer and C_Timer.After then C_Timer.After(0, Reseat) else Reseat() end
	end)
	return slider
end

local function CreateSectionHeader(parent, label, x, y)
	local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", x, y)
	header:SetText(label)
	return header
end

function KUI:ApplyKainPreset()
	if not self.db then return end
	if InCombatLockdown() then
		print("|cffff6060Kain-UI Forever:|r can't apply the preset during combat -- try again once you're out.")
		return
	end
	local p = self.KAIN_PRESET
	if not p then return end

	local failed = {}
	local function Set(name, ...)
		local fn = self[name]
		if type(fn) ~= "function" then return end
		local ok, err = pcall(fn, self, ...)
		if not ok then failed[#failed + 1] = name .. " (" .. tostring(err) .. ")" end
	end

	Set("SetMinimapUnclamped", p.minimapUnclamped)

	if p.minimapPositions then
		self.db.framePositions = self.db.framePositions or {}
		for key, spec in pairs(p.minimapPositions) do

			local pos = self.ResolveScreenPosition and self:ResolveScreenPosition(spec)

			if pos and key == "zonebar" then
				self.db.framePositions[key] = { cx = pos.x, y = pos.y }
			elseif pos then
				self.db.framePositions[key] = { x = pos.x, y = pos.y }
			end
		end
	end
	Set("SetMinimapElementsDetached", p.minimapDetached)

	if p.minimapElementsUnlocked ~= nil then
		Set("SetMinimapElementsUnlocked", p.minimapElementsUnlocked)
	end
	if p.squareMinimap ~= nil then Set("SetSquareMinimap", p.squareMinimap) end
	Set("ApplyGuildDifficulty")
	Set("SetChatEnhanced", p.chatEnhanced)
	if p.emojiChat ~= nil then Set("SetEmojiChatEnabled", p.emojiChat) end

	for _, slot in ipairs(self.GetBagSlotOptions and self:GetBagSlotOptions() or {}) do
		Set("SetBagSlotHidden", slot.key, p.hiddenBagSlots[slot.key] == true)
	end
	Set("SetBagBarChromeHidden", p.hideBagBarChrome)

	Set("SetAutoSellGreys", p.autoSellGreys)
	Set("SetAutoRepair", p.autoRepair)
	Set("SetAutoRepairUseGuildFunds", p.autoRepairUseGuildFunds)
	Set("SetConvertImperialToMetric", p.convertImperialToMetric)
	Set("SetFollowRXPObjectives", p.followRXPObjectives)
	Set("SetLFGZoneShown", p.lfgShowZone)

	Set("SetMicroMenuHidden", p.microMenuHidden)
	for _, btn in ipairs(self.GetMicroButtonOptions and self:GetMicroButtonOptions() or {}) do
		Set("SetMicroButtonHidden", btn.key, p.hiddenMicroButtons[btn.key] == true)
	end

	Set("SetContrastEnabled", p.contrastEnabled)
	Set("SetCameraMaxZoom", p.cameraMaxZoomFactor)

	Set("SetFastLoot", p.fastLoot)
	Set("SetLootRollDragging", p.lootRollDragging)
	Set("SetLootRollAnchorLocked", p.lootRollAnchorLocked)
	if p.lootRollTarget then Set("SetLootRollTarget", p.lootRollTarget.left, p.lootRollTarget.top) end
	Set("SetGlobalDragging", p.globalDragging)
	Set("SetXPBarUnderPortrait", p.xpBarUnderPortrait)
	Set("SetHideDefaultXPBar", p.xpBarHideDefault)
	Set("SetTooltipAnchorMode", p.tooltipAnchorMode)
	Set("SetTooltipAnchorLocked", p.tooltipAnchorLocked)
	if p.tooltipAnchorPos then
		local pos = p.tooltipAnchorPos
		self.db.tooltipAnchorPos = { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y }
		Set("PositionAllTooltips")
	end

	if p.platerStyle ~= nil then Set("SetPlaterStyle", p.platerStyle) end
	if p.mailIconScreenPos then
		Set("SetMailIconScreenPosition", p.mailIconScreenPos.left, p.mailIconScreenPos.top)
	elseif p.mailIconPos then
		Set("SetMailIconPosition", p.mailIconPos.x, p.mailIconPos.y)
	end
	if p.dielPos then
		Set("SetDielPosition", p.dielPos.x, p.dielPos.y)
	end
	if p.emojiButtonOffset then
		Set("SetEmojiButtonOffset", p.emojiButtonOffset.x, p.emojiButtonOffset.y)
	end

	if p.socialButtonPos then
		Set("SetSocialButtonPosition", p.socialButtonPos.x, p.socialButtonPos.y)
	end
	if p.socialButtonUnlocked ~= nil then Set("SetSocialButtonUnlocked", p.socialButtonUnlocked) end
	Set("SetSnapToElements", p.snapToElements)

	RefreshPanel()
	if #failed > 0 then
		print("|cffff6060Kain-UI Forever:|r Kain's preset applied, except: " .. table.concat(failed, "; "))
	else
		print("|cff33ff99Kain-UI Forever|r Kain's preset applied. If anything looks half-changed, /reload.")
	end
end

StaticPopupDialogs["KAINUIFOREVER_APPLY_PRESET"] = {
	text = "Apply Kain's preset?\n\nEvery option on this panel will be switched to Kain's layout, replacing your current choices.",
	button1 = "Apply",
	button2 = CANCEL or "Cancel",
	OnAccept = function() KUI:ApplyKainPreset() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["KAINUIFOREVER_APPLY_LAYOUT"] = {
	text = "Apply Kain's layout?\n\nSwitches on action bars 2-6 and makes \"Kain-UI Forever\" your active Edit Mode layout on this character. Your other layouts stay available in Edit Mode.",
	button1 = "Apply",
	button2 = CANCEL or "Cancel",
	OnAccept = function() KUI:SetupCleanFrames() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function BuildPanel()
	local f = CreateFrame("Frame", "KainUIForeverOptionsFrame", UIParent, "BackdropTemplate")
	f:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetFrameStrata("HIGH")
	f:Hide()

	table.insert(UISpecialFrames, "KainUIForeverOptionsFrame")

	local PANEL_BG_ALPHA = 0.85
	local PANEL_CORNER_RADIUS = 14
	local MOTIF_BRIGHTNESS = 1
	local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

	local MOTIF2_PIXELS, MOTIF2_CANVAS = 282, 512
	local BL_SPIKE_X, BL_SPIKE_Y = 19.0, 25.6

	local MOTIF3_PIXELS, MOTIF3_CANVAS = 282, 512
	local TR_SPIKE_X, TR_SPIKE_Y = 17.4, 23.6
	local GEM_X, GEM_Y, GEM_SIZE = 35.0, 41.3, 22
	local M3 = MOTIF3_PIXELS / MOTIF3_CANVAS

	local unitsPerPixel = 213.3 / 256
	if type(GetPhysicalScreenSize) == "function" then
		local _, physH = GetPhysicalScreenSize()
		local scale = f:GetEffectiveScale()
		if type(physH) == "number" and physH > 0 and type(scale) == "number" and scale > 0 then
			unitsPerPixel = 768 / physH / scale
		end
	end
	local px = function(n) return n * unitsPerPixel end

	local R = PANEL_CORNER_RADIUS
	local function Fill()
		local t = f:CreateTexture(nil, "BACKGROUND")
		t:SetTexture("Interface\\Buttons\\WHITE8x8")
		t:SetVertexColor(0, 0, 0, PANEL_BG_ALPHA)
		return t
	end
	local middle = Fill()
	middle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -R)
	middle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, R)
	local topStrip = Fill()
	topStrip:SetPoint("TOPLEFT", f, "TOPLEFT", R, 0)
	topStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	topStrip:SetHeight(R)
	local bottomStrip = Fill()
	bottomStrip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	bottomStrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -R, 0)
	bottomStrip:SetHeight(R)
	local function RoundCorner(point, cx, cy)
		local t = Fill()
		t:SetPoint(point, f, point, 0, 0)
		t:SetSize(R, R)
		if f.CreateMaskTexture and t.AddMaskTexture then
			local mask = f:CreateMaskTexture()
			mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetSize(2 * R, 2 * R)
			mask:SetPoint("CENTER", f, point, cx, cy)
			t:AddMaskTexture(mask)
		end
	end
	RoundCorner("TOPLEFT", R, -R)
	RoundCorner("BOTTOMRIGHT", -R, R)

	local EDGE_FADE_BL_LENGTH, EDGE_FADE_TR_LENGTH = 240, 225
	local function EdgeFade(point, lengthPx, pieces)
		if not (f.CreateMaskTexture and middle.AddMaskTexture) then return end
		local mask = f:CreateMaskTexture()
		mask:SetTexture(MEDIA .. "Panel_EdgeFade.tga", "CLAMPTOWHITE", "CLAMPTOWHITE")
		mask:SetSize(2 * px(lengthPx), 2 * px(lengthPx))
		mask:SetPoint("CENTER", f, point, 0, 0)
		for _, piece in ipairs(pieces) do piece:AddMaskTexture(mask) end
	end
	EdgeFade("BOTTOMLEFT", EDGE_FADE_BL_LENGTH, { middle, bottomStrip })
	EdgeFade("TOPRIGHT", EDGE_FADE_TR_LENGTH, { middle, topStrip })

	local motifBL = f:CreateTexture(nil, "BORDER", nil, 7)
	motifBL:SetTexture(MEDIA .. "Corner_Motif2.tga")
	motifBL:SetTexCoord(0, MOTIF2_PIXELS / MOTIF2_CANVAS, 0, MOTIF2_PIXELS / MOTIF2_CANVAS)
	motifBL:SetSize(px(MOTIF2_PIXELS), px(MOTIF2_PIXELS))
	motifBL:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -px(BL_SPIKE_X), -px(BL_SPIKE_Y))
	motifBL:SetVertexColor(MOTIF_BRIGHTNESS, MOTIF_BRIGHTNESS, MOTIF_BRIGHTNESS)

	local motifTR = f:CreateTexture(nil, "BORDER", nil, 7)
	motifTR:SetTexture(MEDIA .. "Corner_Motif3.tga")
	motifTR:SetTexCoord(M3, 0, M3, 0)
	motifTR:SetSize(px(MOTIF3_PIXELS), px(MOTIF3_PIXELS))
	motifTR:SetPoint("TOPRIGHT", f, "TOPRIGHT", px(TR_SPIKE_X), px(TR_SPIKE_Y))
	motifTR:SetVertexColor(MOTIF_BRIGHTNESS, MOTIF_BRIGHTNESS, MOTIF_BRIGHTNESS)

	local gemGlow = f:CreateTexture(nil, "OVERLAY", nil, 7)
	local glowLoaded = gemGlow:SetTexture(MEDIA .. "Corner_Motif3_GemGlow.tga")
	gemGlow:SetTexCoord(M3, 0, M3, 0)
	gemGlow:SetAllPoints(motifTR)
	gemGlow:SetBlendMode("ADD")
	gemGlow:Hide()
	KUI.optionsGemGlowFallback = false
	if glowLoaded == false then
		KUI.optionsGemGlowFallback = true
		gemGlow:SetTexture(MEDIA .. "Corner_Motif3.tga")
		gemGlow:SetTexCoord(M3, 0, M3, 0)
		if f.CreateMaskTexture and gemGlow.AddMaskTexture then
			local gemMask = f:CreateMaskTexture()
			gemMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			gemMask:SetSize(px(GEM_SIZE - 4), px(GEM_SIZE - 4))
			gemMask:SetPoint("CENTER", motifTR, "TOPRIGHT", -px(GEM_X), -px(GEM_Y))
			gemGlow:AddMaskTexture(gemMask)
		end
	end
	local closeGem = CreateFrame("Button", "KainUIForeverOptionsCloseGem", f)
	closeGem:SetSize(px(GEM_SIZE), px(GEM_SIZE))
	closeGem:SetPoint("CENTER", motifTR, "TOPRIGHT", -px(GEM_X), -px(GEM_Y))
	closeGem:SetFrameLevel(f:GetFrameLevel() + 50)
	closeGem:SetScript("OnEnter", function(self)
		gemGlow:SetAlpha(1)
		gemGlow:Show()
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Close", 1, 1, 1)
		GameTooltip:Show()
	end)
	closeGem:SetScript("OnLeave", function()
		gemGlow:Hide()
		GameTooltip:Hide()
	end)
	closeGem:SetScript("OnMouseDown", function() gemGlow:SetAlpha(0.55) end)
	closeGem:SetScript("OnMouseUp", function() gemGlow:SetAlpha(1) end)
	closeGem:SetScript("OnClick", function()
		gemGlow:Hide()
		GameTooltip:Hide()
		f:Hide()
	end)

	local BL_GEM_X, BL_GEM_Y, BL_GEM_SIZE = 31.7, 244.4, 17
	local M3_GEM_X, M3_GEM_Y, M3_GLOW_HALF = 35.0, 240.7, 14
	local blGlowSize = 2 * M3_GLOW_HALF * BL_GEM_SIZE / 16
	local blGlow = f:CreateTexture(nil, "OVERLAY", nil, 7)
	local blGlowLoaded = blGlow:SetTexture(MEDIA .. "Corner_Motif3_GemGlow.tga")
	blGlow:SetTexCoord((M3_GEM_X - M3_GLOW_HALF) / 512, (M3_GEM_X + M3_GLOW_HALF) / 512,
		(M3_GEM_Y - M3_GLOW_HALF) / 512, (M3_GEM_Y + M3_GLOW_HALF) / 512)
	blGlow:SetSize(px(blGlowSize), px(blGlowSize))
	blGlow:SetPoint("CENTER", motifBL, "TOPLEFT", px(BL_GEM_X), -px(BL_GEM_Y))
	blGlow:SetBlendMode("ADD")
	blGlow:Hide()
	if blGlowLoaded == false and f.CreateMaskTexture and blGlow.AddMaskTexture then

		blGlow:SetTexture(MEDIA .. "Corner_Motif2.tga")
		blGlow:ClearAllPoints()
		blGlow:SetAllPoints(motifBL)
		blGlow:SetTexCoord(0, MOTIF2_PIXELS / MOTIF2_CANVAS, 0, MOTIF2_PIXELS / MOTIF2_CANVAS)
		local blMask = f:CreateMaskTexture()
		blMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		blMask:SetSize(px(BL_GEM_SIZE), px(BL_GEM_SIZE))
		blMask:SetPoint("CENTER", motifBL, "TOPLEFT", px(BL_GEM_X), -px(BL_GEM_Y))
		blGlow:AddMaskTexture(blMask)
	end
	local notesGem = CreateFrame("Button", "KainUIForeverOptionsPatchNotesGem", f)
	notesGem:SetSize(px(BL_GEM_SIZE + 6), px(BL_GEM_SIZE + 6))
	notesGem:SetPoint("CENTER", motifBL, "TOPLEFT", px(BL_GEM_X), -px(BL_GEM_Y))
	notesGem:SetFrameLevel(f:GetFrameLevel() + 50)
	notesGem:SetScript("OnEnter", function(self)
		blGlow:SetAlpha(1)
		blGlow:Show()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Patch notes", 1, 1, 1)
		GameTooltip:Show()
	end)
	notesGem:SetScript("OnLeave", function()
		blGlow:Hide()
		GameTooltip:Hide()
	end)
	notesGem:SetScript("OnMouseDown", function() blGlow:SetAlpha(0.55) end)
	notesGem:SetScript("OnMouseUp", function() blGlow:SetAlpha(1) end)
	notesGem:SetScript("OnClick", function()
		GameTooltip:Hide()
		if KUI.TogglePatchNotes then KUI:TogglePatchNotes() end
	end)

	local versionText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	versionText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 10)

	versionText:SetText("v" .. ((KUI.GetNotesVersion and KUI:GetNotesVersion()) or (KUI.GetAddonVersion and KUI:GetAddonVersion()) or "?"))

	local logo = f:CreateTexture(nil, "OVERLAY")
	logo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Logo.blp")
	logo:SetPoint("TOP", f, "TOP", 0, -6)
	logo:SetSize(280, 100)

	local presetButton = CreateFrame("Button", "KainUIForeverPresetButton", f, "UIPanelButtonTemplate")
	presetButton:SetSize(150, 24)
	presetButton:SetPoint("TOP", logo, "BOTTOM", 0, -2)
	presetButton:SetText("Kain's preset")
	presetButton:SetScript("OnClick", function()
		StaticPopup_Show("KAINUIFOREVER_APPLY_PRESET")
	end)
	AddInfoButton(f, presetButton, "Kain's preset", "Recommended settings for this mod.")

	f:SetScript("OnShow", RefreshPanel)

	f:HookScript("OnShow", function() if KUI.RefreshAlignGrid then KUI:RefreshAlignGrid() end end)
	f:HookScript("OnHide", function() if KUI.RefreshAlignGrid then KUI:RefreshAlignGrid() end end)

	local content = f
	local yTop = -142

	if KUI.BuildWeaponSwapWidgets then

		local refreshWeaponSwap = KUI:BuildWeaponSwapWidgets(content, COL1_X + 6, -16)
		if refreshWeaponSwap then table.insert(refreshers, refreshWeaponSwap) end
	end

	local y1 = yTop
	CreateSectionHeader(content, "Minimap", COL1_X, y1)
	y1 = y1 - 22
	CreateCheckbox(content, "Allow minimap to clip off-screen", COL1_X, y1,
		function() return KUI.db.minimapUnclamped end,
		function(checked) KUI:SetMinimapUnclamped(checked) end)
	y1 = y1 - 26
	local detachCheck = CreateCheckbox(content, "Detach minimap elements", COL1_X, y1,
		function() return KUI.db.minimapDetached end,
		function(checked) KUI:SetMinimapDetached(checked) end)
	AddInfoButton(content, detachCheck.label, "Detach minimap elements",
		"Separates the header bar from the minimap.")
	y1 = y1 - 24
	if KUI.SetSquareMinimap then
		local squareCheck = CreateCheckbox(content, "Square Minimap", COL1_X, y1,
			function() return KUI.db.squareMinimap end,
			function(checked) KUI:SetSquareMinimap(checked) end)
		AddInfoButton(content, squareCheck.label, "Square Minimap",
			"This option will also vanish all addon minimap buttons. Right-click the minimap to see them.")
		y1 = y1 - 24
	end

	CreateCheckbox(content, "Unlock minimap elements", COL1_X, y1,
		function() return KUI.db.headerBarUnlocked end,
		function(checked) KUI:SetMinimapElementsUnlocked(checked) end)
	y1 = y1 - 24

	CreateSectionHeader(content, "Chat", COL1_X, y1)
	y1 = y1 - 22
	if KUI.SetChatEnhanced then
		local enhanceChatCheck = CreateCheckbox(content, "Enhance Chat", COL1_X, y1,
			function() return KUI.db.chatEnhanced ~= false end,
			function(checked) KUI:SetChatEnhanced(checked) end)
		AddInfoButton(content, enhanceChatCheck.label, "Enhance Chat",
			"Prat style chat enhancement; allows you to copy chat & click web links.")
		y1 = y1 - 24

	end

	if KUI.SetEmojiButtonUnlocked then
		CreateCheckbox(content, "Unlock emoji picker (drag to reposition)", COL1_X, y1,
			function() return KUI.db.emojiButtonUnlocked end,
			function(checked) KUI:SetEmojiButtonUnlocked(checked) end)
		y1 = y1 - 28
		local resetEmoji = CreateFrame("Button", "KainUIForeverResetEmojiButton", content, "UIPanelButtonTemplate")
		resetEmoji:SetSize(180, 22)
		resetEmoji:SetPoint("TOPLEFT", COL1_X, y1)
		resetEmoji:SetText("Reset emoji picker position")
		resetEmoji:SetScript("OnClick", function() KUI:ResetEmojiButtonPosition() end)
		y1 = y1 - 28

		if KUI.SetSocialButtonUnlocked then
			CreateCheckbox(content, "Unlock Social Button", COL1_X, y1,
				function() return KUI.db.socialButtonUnlocked end,
				function(checked) KUI:SetSocialButtonUnlocked(checked) end)
			y1 = y1 - 28
			local resetSocial = CreateFrame("Button", "KainUIForeverResetSocialButton", content, "UIPanelButtonTemplate")
			resetSocial:SetSize(180, 22)
			resetSocial:SetPoint("TOPLEFT", COL1_X, y1)
			resetSocial:SetText("Reset social button position")
			resetSocial:SetScript("OnClick", function() KUI:ResetSocialButtonPosition() end)
			y1 = y1 - 28
		end
	end
	y1 = y1 - 8

	if KUI.SetupCleanFrames then
		CreateSectionHeader(content, "User Interface", COL1_X, y1)
		y1 = y1 - 24
		local layoutButton = CreateFrame("Button", "KainUIForeverApplyLayoutButton", content, "UIPanelButtonTemplate")
		layoutButton:SetSize(180, 24)
		layoutButton:SetPoint("TOPLEFT", COL1_X, y1)
		layoutButton:SetText("Import Kain-UI Profile")
		layoutButton:SetScript("OnClick", function()
			StaticPopup_Show("KAINUIFOREVER_APPLY_LAYOUT")
		end)
		AddInfoButton(content, layoutButton, "Import Kain-UI Profile",
			"Also enables extra action bars")
		y1 = y1 - 30

		if KUI.SetLevelUpScreenshot then
			local shotCheck = CreateCheckbox(content, "Screenshot on level up", COL1_X, y1,
				function() return KUI.db.levelUpScreenshot end,
				function(checked) KUI:SetLevelUpScreenshot(checked) end)
			AddInfoButton(content, shotCheck.label, "Screenshot on level up",
				"Saved to your World of Warcraft Screenshots folder.")
			y1 = y1 - 26
		end
	end

	if KUI.SetPlaterStyle then
		CreateSectionHeader(content, "Nameplates", COL1_X, y1)
		y1 = y1 - 22
		local platerCheck
		platerCheck = CreateCheckbox(content, "Plater style", COL1_X, y1,
			function() return KUI.db.platerStyle end,
			function(checked)

				if not KUI:SetPlaterStyle(checked) then
					platerCheck:SetChecked(KUI.db.platerStyle and true or false)
				end
			end)
		AddInfoButton(content, platerCheck.label, "Plater style",
			"Configures Blizzard's nameplates to resemble Plater. Unticking restores your previous nameplate settings.")
		y1 = y1 - 24
	end

	if KUI.SetSnapToElements then
		local snapCheck = CreateCheckbox(content, "Snap to elements", COL4_X, 0,
			function() return KUI.db.snapToElements end,
			function(checked) KUI:SetSnapToElements(checked) end)
		snapCheck:ClearAllPoints()
		snapCheck:SetPoint("TOPLEFT", f, "TOPLEFT", COL4_X, -34)
		AddInfoButton(content, snapCheck.label, "Snap to elements",
			"Only affects Kain-UI elements. While dragging, hold Shift to move freely up and down, or Ctrl to move freely left and right.")
	end

	local y2 = yTop
	CreateSectionHeader(content, "Bag slots (unchecked = hidden)", COL2_X, y2)
	y2 = y2 - 22
	local bagOptions = KUI.GetBagSlotOptions and KUI:GetBagSlotOptions() or {}
	if #bagOptions == 0 then
		local none = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		none:SetPoint("TOPLEFT", COL2_X, y2)
		none:SetText("None found -- try /kainui bagscan")
		y2 = y2 - 20
	else
		for _, slot in ipairs(bagOptions) do
			CreateCheckbox(content, slot.label or slot.key, COL2_X, y2,
				function() return not KUI.db.hiddenBagSlots[slot.key] end,
				function(checked) KUI:SetBagSlotHidden(slot.key, not checked) end)
			y2 = y2 - 24
		end
	end
	local hasBorderArt = KUI.HasBagBarBorderArt and KUI:HasBagBarBorderArt()
	local hasDividers = KUI.HasBagBarDividers and KUI:HasBagBarDividers()
	if hasBorderArt or hasDividers then
		CreateCheckbox(content, "Hide background art & dividers", COL2_X, y2,
			function() return KUI.db.hideBagBarBorderArt or KUI.db.hideBagBarDividers end,
			function(checked) KUI:SetBagBarChromeHidden(checked) end)
		y2 = y2 - 24
	end

	if KUI.SetAutoSellGreys or KUI.SetAutoRepair then
		y2 = y2 - 12
		CreateSectionHeader(content, "Vendor", COL2_X, y2)
		y2 = y2 - 22
		if KUI.SetAutoSellGreys then
			CreateCheckbox(content, "Auto-sell grey items", COL2_X, y2,
				function() return KUI.db.autoSellGreys end,
				function(checked) KUI:SetAutoSellGreys(checked) end)
			y2 = y2 - 26
		end
		if KUI.SetAutoRepair then
			CreateCheckbox(content, "Auto-repair", COL2_X, y2,
				function() return KUI.db.autoRepair end,
				function(checked) KUI:SetAutoRepair(checked) end)
			y2 = y2 - 24
			local guildFundsCheck = CreateCheckbox(content, "Use guild funds", COL2_X + 16, y2,
				function() return KUI.db.autoRepairUseGuildFunds end,
				function(checked) KUI:SetAutoRepairUseGuildFunds(checked) end)
			AddInfoButton(content, guildFundsCheck.label, "Use guild funds",
				"Repairs from the guild bank when you have permission and it can cover the cost. Falls back to your own gold otherwise.")
			y2 = y2 - 24
		end
	end

	if KUI.SetConvertImperialToMetric then

		local rxpLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides"))
			or (IsAddOnLoaded and IsAddOnLoaded("RXPGuides")) or false

		local function ShowDisabledTip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Module Disabled", 1, 1, 1)
			GameTooltip:AddLine("RXP addon not detected", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end
		local function GreyOutIfNoRXP(check)
			if rxpLoaded or not check then return end
			check:Disable()
			local labelWidth = 0
			if check.label then
				check.label:SetTextColor(0.5, 0.5, 0.5)
				labelWidth = check.label:GetStringWidth() + 4
			end
			if check.SetMotionScriptsWhileDisabled then
				check:SetMotionScriptsWhileDisabled(true)
				check:SetHitRectInsets(0, -labelWidth, 0, 0)
				check:SetScript("OnEnter", ShowDisabledTip)
				check:SetScript("OnLeave", function() GameTooltip:Hide() end)
			else
				local cover = CreateFrame("Frame", nil, check:GetParent())
				cover:SetPoint("TOPLEFT", check, "TOPLEFT")
				cover:SetPoint("BOTTOMLEFT", check, "BOTTOMLEFT")
				cover:SetWidth(check:GetWidth() + labelWidth)
				cover:SetFrameLevel(check:GetFrameLevel() + 2)
				cover:EnableMouse(true)
				cover:SetScript("OnEnter", ShowDisabledTip)
				cover:SetScript("OnLeave", function() GameTooltip:Hide() end)
			end
		end

		y2 = y2 - 12
		CreateSectionHeader(content, "RXP Tweaks", COL2_X, y2)
		y2 = y2 - 22
		local metricCheck = CreateCheckbox(content, "Convert Arrow Output", COL2_X, y2,
			function() return rxpLoaded and KUI.db.convertImperialToMetric end,
			function(checked) KUI:SetConvertImperialToMetric(checked) end)
		GreyOutIfNoRXP(metricCheck)

		AddInfoButton(content, metricCheck.label, "Convert Arrow Output",
			"Toggles RXP navigation arrow from imperial to metric.")
		y2 = y2 - 24

		if KUI.SetFollowRXPObjectives then
			local followCheck = CreateCheckbox(content, "Toggle Objective Tracker", COL2_X, y2,
				function() return rxpLoaded and KUI.db.followRXPObjectives end,
				function(checked) KUI:SetFollowRXPObjectives(checked) end)
			GreyOutIfNoRXP(followCheck)
			AddInfoButton(content, followCheck.label, "Toggle Objective Tracker",
				"Vanishes the Blizzard objective tracker - so you can focus on RXP.\n/rxp toggle swaps between them.")
			y2 = y2 - 24
		end
	end

	local y3 = yTop
	CreateSectionHeader(content, "Micro menu", COL3_X, y3)
	y3 = y3 - 22
	CreateCheckbox(content, "Hide entire menu", COL3_X, y3,
		function() return KUI.db.microMenuHidden end,
		function(checked) KUI:SetMicroMenuHidden(checked) end)
	y3 = y3 - 26
	local microOptions = KUI.GetMicroButtonOptions and KUI:GetMicroButtonOptions() or {}
	if #microOptions == 0 then
		local none = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		none:SetPoint("TOPLEFT", COL3_X, y3)
		none:SetText("None found -- try /kainui microscan")
		y3 = y3 - 20
	else
		for _, btn in ipairs(microOptions) do
			CreateCheckbox(content, btn.label or btn.key, COL3_X, y3,
				function() return not KUI.db.hiddenMicroButtons[btn.key] end,
				function(checked) KUI:SetMicroButtonHidden(btn.key, not checked) end)
			y3 = y3 - 22
		end
	end

	if KUI.SetContrastEnabled then
		y3 = y3 - 12
		CreateSectionHeader(content, "Graphics", COL3_X, y3)
		y3 = y3 - 22

		local contrastCheck
		contrastCheck = CreateCheckbox(content, "Contrast", COL3_X, y3,
			function()
				return KUI.db.contrastEnabled or (KUI.IsContrastAtRecommendedValues and KUI:IsContrastAtRecommendedValues())
			end,
			function(checked) KUI:SetContrastEnabled(checked) end)
		AddInfoButton(content, contrastCheck.label, "Contrast",
			"Contrast 100%, Brightness 60%. \"Restore your contrast\" puts your own values back.")
		y3 = y3 - 28
		local restoreContrastButton = CreateFrame("Button", "KainUIForeverRestoreContrastButton", content, "UIPanelButtonTemplate")
		restoreContrastButton:SetSize(150, 22)
		restoreContrastButton:SetPoint("TOPLEFT", COL3_X, y3)
		restoreContrastButton:SetText("Restore your contrast")
		restoreContrastButton:SetScript("OnClick", function()
			if KUI.RestoreContrast then KUI:RestoreContrast() end

			if contrastCheck then contrastCheck:SetChecked(false) end
		end)
		y3 = y3 - 30
	end

	local weatherProbe = GetCVar("weatherDensity")
	if weatherProbe ~= nil or (issecretvalue and issecretvalue(weatherProbe)) then
		local WEATHER_NAMES = { [0] = "Disabled", [1] = "Low", [2] = "Medium", [3] = "Maximum" }

		y3 = y3 - 8
		local weatherLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		weatherLabel:SetPoint("TOPLEFT", COL3_X + 4, y3)
		weatherLabel:SetText("Weather Intensity")
		AddInfoButton(content, weatherLabel, "Weather Intensity", "Affects rain, snow, and fog.")

		local weatherValue = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		weatherValue:SetPoint("TOPLEFT", content, "TOPLEFT", COL3_X + 4, y3 - 14)
		weatherValue:SetJustifyH("LEFT")
		y3 = y3 - 30

		local weatherSlider = CreateSlider(content, COL3_X + 4, y3, COL3_W - 12, 0, 3, 1)
		local function ShowWeatherValue(level)
			weatherValue:SetText(format("%d (%s)", level, WEATHER_NAMES[level] or "?"))
		end

		local weatherSyncing = false
		local function SyncWeatherSlider()

			local raw = GetCVar("weatherDensity")
			local level
			if not (issecretvalue and issecretvalue(raw)) then level = tonumber(raw) end
			if not level then
				local def = GetCVarDefault and GetCVarDefault("weatherDensity")
				if not (issecretvalue and issecretvalue(def)) then level = tonumber(def) end
			end
			level = level or 3
			level = math.max(0, math.min(3, math.floor(level + 0.5)))
			weatherSyncing = true
			weatherSlider:SetValue(level)
			weatherSyncing = false
			ShowWeatherValue(level)
		end
		weatherSlider:SetScript("OnValueChanged", function(self, value)
			if weatherSyncing then return end
			local level = math.max(0, math.min(3, math.floor(value + 0.5)))
			pcall(SetCVar, "weatherDensity", level)
			ShowWeatherValue(level)
		end)
		weatherSlider:SetScript("OnShow", SyncWeatherSlider)
		table.insert(refreshers, SyncWeatherSlider)
		SyncWeatherSlider()
		y3 = y3 - 24
	end

	if KUI.SetCameraMaxZoom then
		y3 = y3 - 12
		CreateSectionHeader(content, "Camera", COL3_X, y3)
		y3 = y3 - 22
		local zoomLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		zoomLabel:SetPoint("TOPLEFT", COL3_X + 4, y3)
		zoomLabel:SetText("Max zoom distance")
		AddInfoButton(content, zoomLabel, "Max zoom distance",
			"The camera follows the slider as you drag. The client stops at 50 yd, so the top of the slider is the real limit.")

		local zoomValue = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		zoomValue:SetPoint("TOPLEFT", content, "TOPLEFT", COL3_X + 4, y3 - 14)
		zoomValue:SetJustifyH("LEFT")
		y3 = y3 - 30

		local zoomSlider = CreateSlider(content, COL3_X + 4, y3, COL3_W - 12,
			KUI.CAMERA_ZOOM_MIN, KUI.CAMERA_ZOOM_MAX, KUI.CAMERA_ZOOM_STEP)
		local function ShowZoomValue(factor)
			zoomValue:SetText(format("%.1fx (%d yd)", factor, KUI:CameraZoomToYards(factor)))
		end

		local syncing = false
		local function SyncZoomSlider()
			local current = KUI:GetCameraMaxZoom()
			syncing = true
			zoomSlider:SetValue(current)
			syncing = false
			ShowZoomValue(current)
		end
		zoomSlider:SetScript("OnValueChanged", function(self, value)
			if syncing then return end
			ShowZoomValue(KUI:SetCameraMaxZoom(value))
			KUI:ZoomCameraToMax()
		end)

		zoomSlider:SetScript("OnShow", SyncZoomSlider)
		table.insert(refreshers, SyncZoomSlider)
		SyncZoomSlider()
		y3 = y3 - 28

		local resetZoomButton = CreateFrame("Button", "KainUIForeverResetCameraZoomButton", content, "UIPanelButtonTemplate")
		resetZoomButton:SetSize(150, 22)
		resetZoomButton:SetPoint("TOPLEFT", COL3_X, y3)
		resetZoomButton:SetText("Reset to default")
		resetZoomButton:SetScript("OnClick", function()
			KUI:ResetCameraMaxZoom()
			SyncZoomSlider()
			KUI:ZoomCameraToMax()
		end)
		y3 = y3 - 30
	end

	local y4 = yTop

	if KUI.SetFastLoot or KUI.SetLootRollDragging then
		CreateSectionHeader(content, "Loot", COL4_X, y4)
		y4 = y4 - 22
		if KUI.SetFastLoot then
			CreateCheckbox(content, "Fast loot (skip the reveal animation)", COL4_X, y4,
				function() return KUI.db.fastLoot end,
				function(checked) KUI:SetFastLoot(checked) end)
			y4 = y4 - 26
		end
		if KUI.SetLootRollDragging then
			local lootRollAnchorCheck
			local lootRollCheck = CreateCheckbox(content, "Draggable loot roll frames", COL4_X, y4,
				function() return KUI.db.lootRollDragging ~= false end,
				function(checked)
					KUI:SetLootRollDragging(checked)

					if not checked and lootRollAnchorCheck then lootRollAnchorCheck:SetChecked(false) end
				end)
			AddInfoButton(content, lootRollCheck.label, "Draggable loot roll frames",
				"Drag any need/greed roll window to move the whole stack, or unlock the anchor to position it without waiting for a roll.")
			y4 = y4 - 24
			if KUI.SetLootRollAnchorLocked then
				lootRollAnchorCheck = CreateCheckbox(content, "Unlock anchor (drag to reposition)", COL4_X, y4,
					function() return KUI.db.lootRollAnchorLocked == false end,
					function(checked)

						if KUI:SetLootRollAnchorLocked(not checked) == false then
							lootRollAnchorCheck:SetChecked(false)
						end
					end)
				y4 = y4 - 26
			end
			local resetLootRollButton = CreateFrame("Button", "KainUIForeverResetLootRollButton", content, "UIPanelButtonTemplate")
			resetLootRollButton:SetSize(150, 22)
			resetLootRollButton:SetPoint("TOPLEFT", COL4_X, y4)
			resetLootRollButton:SetText("Reset anchor position")
			resetLootRollButton:SetScript("OnClick", function()
				if KUI.ResetLootRollPosition then KUI:ResetLootRollPosition() end
			end)
			y4 = y4 - 30
		end
	end

	if KUI.SetGlobalDragging then
		y4 = y4 - 12
		CreateSectionHeader(content, "Windows", COL4_X, y4)
		y4 = y4 - 22
		local dragCheck = CreateCheckbox(content, "Enable Global Dragging", COL4_X, y4,
			function() return KUI.db.globalDragging end,
			function(checked) KUI:SetGlobalDragging(checked) end)
		AddInfoButton(content, dragCheck.label, "Enable Global Dragging",
			"Drag the Character, Macro, Spellbook/Talents, Map/Quest Log, Combined Bags, professions, quest dialogue, vendor, calendar and Social windows by their title bar. /kainui resetdrag puts them back.")
		y4 = y4 - 26
	end

	if KUI.SetXPBarUnderPortrait then
		y4 = y4 - 12
		CreateSectionHeader(content, "Unit Frames", COL4_X, y4)
		y4 = y4 - 22
		local xpBarCheck = CreateCheckbox(content, "XP bar under portrait", COL4_X, y4,
			function() return KUI.db.xpBarUnderPortrait end,
			function(checked) KUI:SetXPBarUnderPortrait(checked) end)
		AddInfoButton(content, xpBarCheck.label, "XP bar under portrait",
			"Hold Shift to see XP per hour & time to level.")
		y4 = y4 - 24
		CreateCheckbox(content, "Hide the original XP bar", COL4_X + 16, y4,
			function() return KUI.db.xpBarHideDefault end,
			function(checked) KUI:SetHideDefaultXPBar(checked) end)
		y4 = y4 - 26
	end

	if KUI.SetTooltipAnchorMode then
		y4 = y4 - 12
		CreateSectionHeader(content, "Tooltips", COL4_X, y4)
		y4 = y4 - 22
		local tooltipDefaultCheck, tooltipGrowCheck
		tooltipDefaultCheck = CreateCheckbox(content, "Default (Blizzard) behavior", COL4_X, y4,
			function() return (KUI.db.tooltipAnchorMode or "default") == "default" end,
			function(checked)
				if checked then
					KUI:SetTooltipAnchorMode("default")
					if tooltipGrowCheck then tooltipGrowCheck:SetChecked(false) end
				else

					tooltipDefaultCheck:SetChecked(true)
				end
			end)
		y4 = y4 - 24
		tooltipGrowCheck = CreateCheckbox(content, "Grow right (static left edge)", COL4_X, y4,
			function() return KUI.db.tooltipAnchorMode == "growRight" end,
			function(checked)
				if checked then
					KUI:SetTooltipAnchorMode("growRight")
					if tooltipDefaultCheck then tooltipDefaultCheck:SetChecked(false) end
				else
					KUI:SetTooltipAnchorMode("default")
					if tooltipDefaultCheck then tooltipDefaultCheck:SetChecked(true) end
				end
			end)
		AddInfoButton(content, tooltipGrowCheck.label, "Grow right (static left edge)",
			"Grow Right pins every tooltip's top-left corner to one fixed spot, so the left edge never moves no matter how wide the content gets -- line it up with another UI element and it won't clip over it.")
		y4 = y4 - 24
		local tooltipUnlockCheck = CreateCheckbox(content, "Unlock anchor (drag to reposition)", COL4_X, y4,
			function() return not KUI.db.tooltipAnchorLocked end,
			function(checked) KUI:SetTooltipAnchorLocked(not checked) end)
		AddInfoButton(content, tooltipUnlockCheck.label, "Unlock anchor",
			"Only affects tooltips when Grow Right is selected.")
		y4 = y4 - 26
		local resetAnchorButton = CreateFrame("Button", "KainUIForeverResetTooltipAnchorButton", content, "UIPanelButtonTemplate")
		resetAnchorButton:SetSize(150, 22)
		resetAnchorButton:SetPoint("TOPLEFT", COL4_X, y4)
		resetAnchorButton:SetText("Reset anchor position")
		resetAnchorButton:SetScript("OnClick", function()
			if KUI.ResetTooltipAnchorPosition then KUI:ResetTooltipAnchorPosition() end
		end)
		y4 = y4 - 30
	end

	local tallestY = math.min(y1, y2, y3, y4)
	local neededHeight = math.abs(tallestY) + 20
	if neededHeight > PANEL_HEIGHT then
		f:SetHeight(neededHeight)
	end

	panel = f
	return f
end

function KUI:ToggleOptions()
	local f = panel or BuildPanel()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end
