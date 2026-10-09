local _, KUI = ...

local LAYOUT_NAME = "Kain-UI Forever"

local EXTRA_BAR_COUNT = 5

local EXTRA_BAR_FRAMES = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5" }

local function EnableBarsPersistently(count)
	if GetActionBarToggles and SetActionBarToggles then
		local toggles = { GetActionBarToggles() }
		if #toggles > 0 then
			for i = 1, math.min(count, #toggles) do toggles[i] = true end
			local alwaysShow = GetCVarBool and GetCVarBool("alwaysShowActionBars") or false
			toggles[#toggles + 1] = alwaysShow
			if pcall(SetActionBarToggles, unpack(toggles)) then
				return "toggles"
			end
		end
	end

	if Settings and Settings.GetSetting then
		local found = 0
		for i = 2, count + 1 do
			local ok, setting = pcall(Settings.GetSetting, "PROXY_SHOW_ACTIONBAR_" .. i)
			if ok and setting and setting.SetValue then
				if pcall(setting.SetValue, setting, true) then found = found + 1 end
			end
		end
		if found == count then return "settings" end
	end
	return nil
end

local function NumPresetLayouts()
	local meta = Enum.EditModePresetLayoutsMeta
	if meta and meta.NumValues then return meta.NumValues end
	local presets = Enum.EditModePresetLayouts
	if presets then
		local n = 0
		for _ in pairs(presets) do n = n + 1 end
		return n
	end
	return 0
end

local function ActiveLayoutName()
	local ok, info = pcall(C_EditMode.GetLayouts)
	if not ok or not info or not info.layouts or not info.activeLayout then return nil end
	return info.layouts[info.activeLayout - NumPresetLayouts()]
		and info.layouts[info.activeLayout - NumPresetLayouts()].layoutName
end

local function ImportLayout(str)
	if not C_EditMode or not C_EditMode.ConvertStringToLayoutInfo
		or not C_EditMode.GetLayouts or not C_EditMode.SaveLayouts then
		return false, "C_EditMode functions not found on this client"
	end
	if type(str) ~= "string" or str == "" then
		return false, "no layout string (LayoutImport.lua)"
	end

	local ok, layoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, str)
	if not ok or not layoutInfo then
		return false, "couldn't read the layout string"
	end
	layoutInfo.layoutName = LAYOUT_NAME

	layoutInfo.layoutType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character
		or layoutInfo.layoutType

	local okGet, current = pcall(C_EditMode.GetLayouts)
	if not okGet or not current or not current.layouts then
		return false, "couldn't read the current layouts"
	end

	if layoutInfo.interfaceStyle == nil then
		local style
		for _, existing in ipairs(current.layouts) do
			if existing.interfaceStyle ~= nil then style = existing.interfaceStyle break end
		end
		layoutInfo.interfaceStyle = style or 0
	end

	local slot
	for i, existing in ipairs(current.layouts) do
		if existing.layoutName == LAYOUT_NAME then slot = i break end
	end
	if slot then
		current.layouts[slot] = layoutInfo
	else
		table.insert(current.layouts, layoutInfo)
		slot = #current.layouts
	end
	current.activeLayout = slot + NumPresetLayouts()

	local okSave, err = pcall(C_EditMode.SaveLayouts, current)
	if not okSave then return false, "SaveLayouts failed: " .. tostring(err) end

	if C_EditMode.SetActiveLayout then
		pcall(C_EditMode.SetActiveLayout, slot + NumPresetLayouts())
		if ActiveLayoutName() ~= LAYOUT_NAME then
			pcall(C_EditMode.SetActiveLayout, slot)
		end
	end
	if ActiveLayoutName() ~= LAYOUT_NAME then
		return false, "saved the layout but couldn't make it active -- pick \"" .. LAYOUT_NAME .. "\" in Edit Mode's layout dropdown"
	end
	return true
end

function KUI:ActionBarScanReport()
	print("|cff33ff99Kain-UI Forever|r -- Action Bar Scan --")

	if not EditModeManagerFrame then
		print("  EditModeManagerFrame: NOT FOUND")
		print("|cff33ff99Kain-UI Forever|r -- End --")
		return
	end

	local rsf = EditModeManagerFrame.registeredSystemFrames
	if not rsf then
		print("  registeredSystemFrames: nil")
	else
		print("  registeredSystemFrames: " .. #rsf .. " entries")
		local actionBarSystem = Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
		for i, f in ipairs(rsf) do
			if f.system == actionBarSystem then
				local name = f.GetName and f:GetName() or "<unnamed>"
				local shown = f.IsShown and f:IsShown()
				print(string.format("    [%d] %s  systemIndex=%s  shown=%s  ApplySetting=%s  SavedSettings=%s",
					i, name, tostring(f.systemIndex), tostring(shown),
					tostring(f.ApplySetting ~= nil), tostring(f.SavedSettings ~= nil)))
			end
		end
	end

	local li = EditModeManagerFrame.layoutInfo
	if not li then
		print("  layoutInfo: nil")
	else
		print("  layoutInfo type: " .. type(li))

		local keys = {}
		pcall(function() for k in pairs(li) do keys[#keys+1] = tostring(k) end end)
		table.sort(keys)
		print("  layoutInfo keys: " .. table.concat(keys, ", "))

		if li.layouts then
			print("  layoutInfo.layouts count: " .. #li.layouts)
			local activeIdx = li.activeLayout or 1
			local active = li.layouts[activeIdx]
			if active then
				print("  active layout [" .. activeIdx .. "] keys:")
				local ak = {}
				pcall(function() for k in pairs(active) do ak[#ak+1] = tostring(k) end end)
				table.sort(ak)
				print("    " .. table.concat(ak, ", "))

				if active.systems then
					print("  active layout systems (ActionBar only):")
					local actionBarSystem = Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
					for _, sys in ipairs(active.systems) do
						if sys.system == actionBarSystem then
							print(string.format("    system=%s  systemIndex=%s  settings=%s",
								tostring(sys.system), tostring(sys.systemIndex), tostring(sys.settings ~= nil)))
							if sys.settings then
								local ss = {}
								pcall(function() for k, v in pairs(sys.settings) do ss[#ss+1] = tostring(k).."="..tostring(v) end end)
								table.sort(ss)
								print("      settings keys: " .. table.concat(ss, ", "))

								local firstKey, firstVal
								pcall(function()
									firstKey, firstVal = next(sys.settings)
								end)
								if firstVal and type(firstVal) == "table" then
									local inner = {}
									pcall(function() for k, v in pairs(firstVal) do inner[#inner+1] = tostring(k).."="..tostring(v) end end)
									table.sort(inner)
									print("      first entry [" .. tostring(firstKey) .. "] inner: " .. table.concat(inner, ", "))
								elseif firstVal ~= nil then
									print("      first entry [" .. tostring(firstKey) .. "] = " .. tostring(firstVal) .. " (type: " .. type(firstVal) .. ")")
								end
							end
						end
					end
				end
			end
		end
	end

	local E = Enum.EditModeActionBarSetting
	print("  VisibleSetting enum value: " .. tostring(E and E.VisibleSetting))
	local barGlobals = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6" }
	print("  Per-bar SavedSettings[VisibleSetting]:")
	for _, name in ipairs(barGlobals) do
		local f = _G[name]
		if f and f.SavedSettings and E and E.VisibleSetting then
			print(string.format("    %s: %s", name, tostring(f.SavedSettings[E.VisibleSetting])))
		elseif f then
			print(string.format("    %s: SavedSettings=%s", name, tostring(f.SavedSettings)))
		end
	end

	print("  Deep peek: systemIndex=2 settings sub-tables:")
	local li2 = EditModeManagerFrame and EditModeManagerFrame.layoutInfo
	if li2 and li2.layouts then
		local active2 = li2.layouts[li2.activeLayout]
		local actionBarSystem = Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
		if active2 and active2.systems then
			for _, sys in ipairs(active2.systems) do
				if sys.system == actionBarSystem and sys.systemIndex == 2 then
					for settingKey, settingVal in pairs(sys.settings) do
						if type(settingVal) == "table" then
							local inner = {}
							for k, v in pairs(settingVal) do
								inner[#inner+1] = tostring(k) .. "=" .. tostring(v) .. "(" .. type(v) .. ")"
							end
							table.sort(inner)
							print(string.format("    settings[%s]: { %s }", tostring(settingKey), table.concat(inner, ", ")))
						else
							print(string.format("    settings[%s] = %s (%s)", tostring(settingKey), tostring(settingVal), type(settingVal)))
						end
					end
				end
			end
		end
	end

	print("  Bar on/off switches:")
	print("    GetActionBarToggles: " .. (GetActionBarToggles and "yes" or "missing")
		.. "  SetActionBarToggles: " .. (SetActionBarToggles and "yes" or "missing"))
	if GetActionBarToggles then
		local t = { GetActionBarToggles() }
		local parts = {}
		for i, v in ipairs(t) do parts[#parts + 1] = i .. "=" .. tostring(v) end
		print("    current: " .. table.concat(parts, " "))
	end
	if Settings and Settings.GetSetting then
		local parts = {}
		for i = 2, 8 do
			local ok, st = pcall(Settings.GetSetting, "PROXY_SHOW_ACTIONBAR_" .. i)
			local val = ok and st and st.GetValue and st:GetValue()
			parts[#parts + 1] = i .. "=" .. (ok and st and tostring(val) or "none")
		end
		print("    PROXY_SHOW_ACTIONBAR_*: " .. table.concat(parts, " "))
	else
		print("    Settings.GetSetting: missing")
	end
	local vis = Enum.ActionBarVisibleSetting
	if vis then
		local parts = {}
		for k, v in pairs(vis) do parts[#parts + 1] = k .. "=" .. tostring(v) end
		table.sort(parts)
		print("    Enum.ActionBarVisibleSetting: " .. table.concat(parts, " "))
	end
	local li3 = EditModeManagerFrame and EditModeManagerFrame.layoutInfo
	local activeLayout = li3 and li3.layouts and li3.layouts[li3.activeLayout]
	if activeLayout then
		print(string.format("    active Edit Mode layout: %s (layoutType=%s, preset=%s)",
			tostring(activeLayout.layoutName), tostring(activeLayout.layoutType),
			tostring(Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset)))
	end

	print("|cff33ff99Kain-UI Forever|r -- End of Action Bar Scan --")
end

function KUI:SetupCleanFrames()
	if InCombatLockdown and InCombatLockdown() then
		print("|cffff6060Kain-UI Forever:|r can't apply the layout during combat -- try again after.")
		return
	end

	local enabledVia = EnableBarsPersistently(EXTRA_BAR_COUNT)
	local imported, reason = ImportLayout(KUI.LAYOUT_IMPORT_STRING)

	if not enabledVia then
		print("|cffff6060Kain-UI Forever:|r couldn't switch the extra action bars on (no SetActionBarToggles or Action Bar settings found). Run /kainui actionbarscan and send the output.")
	end
	if imported then
		print("|cff33ff99Kain-UI Forever|r Kain's layout applied (Edit Mode layout \"" .. LAYOUT_NAME .. "\").")
	else
		print("|cffff6060Kain-UI Forever:|r Kain's layout not applied -- " .. tostring(reason) .. ".")
	end

	local rxpResult, rxpReason
	if KUI.ApplyKainRXPProfile then rxpResult, rxpReason = KUI:ApplyKainRXPProfile() end
	if rxpResult == "switched" or rxpResult == "updated" then
		print("|cff33ff99Kain-UI Forever|r RXP profile \"Kain-UI\" applied.")
	elseif rxpResult == "failed" then
		print("|cffff6060Kain-UI Forever:|r RXP profile not applied -- " .. tostring(rxpReason) .. ".")
	end

	local rxpNeedsReload = (rxpResult == "switched" or rxpResult == "updated")
	local function Check()
		local barsMissing = false
		if enabledVia then
			for _, name in ipairs(EXTRA_BAR_FRAMES) do
				local bar = _G[name]
				if bar and bar.IsShown and not bar:IsShown() then barsMissing = true end
			end
		end
		local reasons = {}
		if barsMissing then reasons[#reasons + 1] = "The new action bars appear after a reload." end
		if rxpNeedsReload then reasons[#reasons + 1] = "RXP's new profile takes effect after a reload." end
		if #reasons > 0 then
			StaticPopup_Show("KAINUIFOREVER_IMPORT_RELOAD", table.concat(reasons, "\n"))
		end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.5, Check) else Check() end
end

StaticPopupDialogs["KAINUIFOREVER_IMPORT_RELOAD"] = {
	text = "Kain's profile is applied.\n\n%s\n\nReload now?",
	button1 = "Reload",
	button2 = "Later",
	OnAccept = function()
		if type(ReloadUI) == "function" then ReloadUI() elseif C_UI and C_UI.Reload then C_UI.Reload() end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
