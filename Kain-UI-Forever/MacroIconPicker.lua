local _, KUI = ...

local scanLines = { "the macro icon popup hasn't been opened yet this session -- open Macros, double-click a macro, click its icon, then run this again." }

local function ResetScan()
	scanLines = {}
end

local function Note(fmt, ...)
	table.insert(scanLines, string.format(fmt, ...))
end

function KUI:MacroIconPickerScanReport()
	print("|cff33ff99Kain-UI Forever|r macro icon picker scan:")
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
end

local hookedButtons = setmetatable({}, { __mode = "k" })

local function ResolveIconName(iconValue)
	if type(iconValue) == "number" and KUI.ICON_NAMES then
		return KUI.ICON_NAMES[iconValue]
	end
	return nil
end

local function IconLabel(iconValue)
	if type(iconValue) == "number" then
		local name = ResolveIconName(iconValue)
		return name or tostring(iconValue)
	elseif type(iconValue) == "string" then
		return (iconValue:gsub("^.*\\", ""))
	end
	return tostring(iconValue)
end

local function ShowIconTooltip(btn)
	if not (btn.GetSelection) then return end
	local ok, icon = pcall(btn.GetSelection, btn)
	if not ok or icon == nil then return end
	GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
	if type(icon) == "number" then
		GameTooltip:AddLine(tostring(icon), 1, 0.82, 0)
		local name = ResolveIconName(icon)
		if name then
			GameTooltip:AddLine(name, 1, 1, 1)
		end
	else
		GameTooltip:AddLine(IconLabel(icon), 1, 1, 1)
	end
	if btn.GetSelectionIndex then
		local okIdx, idx = pcall(btn.GetSelectionIndex, btn)
		if okIdx and idx then
			GameTooltip:AddLine("#" .. tostring(idx), 0.6, 0.6, 0.6)
		end
	end
	GameTooltip:Show()
end

local function HideIconTooltip()
	GameTooltip:Hide()
end

local function HookIconButton(btn)
	if hookedButtons[btn] then return end
	hookedButtons[btn] = true
	btn:HookScript("OnEnter", ShowIconTooltip)
	btn:HookScript("OnLeave", HideIconTooltip)
end

local function HookVisibleIconButtons(popup)
	local scrollBox = popup.IconSelector and popup.IconSelector.ScrollBox
	if not (scrollBox and scrollBox.GetFrames) then
		Note("modern ScrollBox icon grid not found at popup.IconSelector.ScrollBox -- this client may use an older, fixed-grid icon picker instead. If mouseover tooltips aren't showing, hover an icon and run /framestack, then tell me what it reports.")
		return 0
	end
	local ok, frames = pcall(scrollBox.GetFrames, scrollBox)
	if not ok or not frames then return 0 end
	local count = 0
	for _, btn in pairs(frames) do
		HookIconButton(btn)
		count = count + 1
	end
	return count
end

local activeSearchText = ""

local function RefreshPopupDisplay(popup)
	if type(popup.Update) == "function" then
		pcall(popup.Update, popup)
	end
end

local function ApplySearchFilter(popup)
	local provider = popup.iconDataProvider
	if not (provider and provider.GetNumIcons and provider.GetIconByIndex) then
		Note("popup.iconDataProvider (or its GetNumIcons/GetIconByIndex methods) not found -- search can't filter anything on this client without it.")
		return
	end

	if not provider.kainUIOriginalGetNumIcons then
		provider.kainUIOriginalGetNumIcons = provider.GetNumIcons
		provider.kainUIOriginalGetIconByIndex = provider.GetIconByIndex
	end

	if activeSearchText ~= "" then
		if provider.kainUIFilterText ~= activeSearchText then
			local matches = {}
			local ok, total = pcall(provider.kainUIOriginalGetNumIcons, provider)
			if ok and total then
				for i = 1, total do
					local okIcon, icon = pcall(provider.kainUIOriginalGetIconByIndex, provider, i)
					if okIcon and icon ~= nil then
						if IconLabel(icon):lower():find(activeSearchText, 1, true) then
							table.insert(matches, icon)
						end
					end
				end
			end
			provider.kainUIFilteredIcons = matches
			provider.kainUIFilterText = activeSearchText
		end
		provider.GetNumIcons = function() return #provider.kainUIFilteredIcons end
		provider.GetIconByIndex = function(_, index) return provider.kainUIFilteredIcons[index] end
	else
		provider.GetNumIcons = provider.kainUIOriginalGetNumIcons
		provider.GetIconByIndex = provider.kainUIOriginalGetIconByIndex
	end

	RefreshPopupDisplay(popup)
end

local function CreateSearchBox(popup)
	if popup.kainUISearchBox then return popup.kainUISearchBox end
	local borderBox = popup.BorderBox
	local okayButton = borderBox and borderBox.OkayButton
	if not okayButton then
		Note("popup.BorderBox.OkayButton not found -- search box wasn't created (no reliable anchor point on this client).")
		return nil
	end

	local box = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetHeight(15)

	box:SetPoint("BOTTOMLEFT", 74, 15)
	box:SetPoint("RIGHT", okayButton, "LEFT", -4, 0)

	box:SetFrameLevel(borderBox:GetFrameLevel() + 1)
	local searchLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	searchLabel:SetPoint("RIGHT", box, "LEFT", -6, 0)
	searchLabel:SetText(SEARCH or "Search")
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnTextChanged", function(self)
		activeSearchText = self:GetText():lower()
		ApplySearchFilter(popup)
	end)
	popup:HookScript("OnHide", function()
		activeSearchText = ""
		box:SetText("")
	end)

	popup.kainUISearchBox = box
	return box
end

local function SetupPopup(popup)
	ResetScan()
	Note("popup: %s", (popup.GetName and popup:GetName()) or "<unnamed>")

	local hookedCount = HookVisibleIconButtons(popup)
	Note("icon buttons hooked for tooltips: %d", hookedCount)

	CreateSearchBox(popup)
	Note("search box: %s", popup.kainUISearchBox and "created" or "not created")

	if type(popup.Update) == "function" and not popup.kainUIUpdateHooked then
		popup.kainUIUpdateHooked = true
		hooksecurefunc(popup, "Update", function()
			HookVisibleIconButtons(popup)
		end)
	end
end

local function OnMacroUIReady()
	local popup = _G.MacroPopupFrame
	if not popup then
		ResetScan()
		Note("MacroPopupFrame not found even after Blizzard_MacroUI loaded -- this client may name it differently.")
		return
	end
	popup:HookScript("OnShow", function() SetupPopup(popup) end)
	if popup:IsShown() then SetupPopup(popup) end
end

if _G.MacroPopupFrame then
	OnMacroUIReady()
else
	local loadFrame = CreateFrame("Frame")
	KUI:SafeRegisterEvent(loadFrame, "ADDON_LOADED")
	loadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
		if loadedAddonName ~= "Blizzard_MacroUI" then return end
		self:UnregisterEvent("ADDON_LOADED")
		OnMacroUIReady()
	end)
end
