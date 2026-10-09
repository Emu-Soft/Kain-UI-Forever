local _, KUI = ...

local CANDIDATE_BUTTONS = {
	{ key = "character", label = "Character Info", names = { "CharacterMicroButton" } },
	{ key = "profession", label = "Professions", names = { "ProfessionMicroButton" } },
	{ key = "spellbook", label = "Spellbook", names = { "SpellbookMicroButton" } },
	{ key = "talent", label = "Talents", names = { "TalentMicroButton" } },
	{ key = "legacy", label = "Legacy", names = { "LegacyMicroButton" } },
	{ key = "questlog", label = "Quest Log", names = { "QuestLogMicroButton" } },
	{ key = "guild", label = "Guild & Communities", names = { "GuildMicroButton" } },
	{ key = "lfd", label = "Group Finder", names = { "LFDMicroButton", "PVPMicroButton" } },
	{ key = "collections", label = "Account Collections", names = { "CollectionsMicroButton" } },
	{ key = "store", label = "Shop", names = { "StoreMicroButton" } },
	{ key = "mainmenu", label = "Game Menu (escape)", names = { "MainMenuMicroButton" } },
}

local CANDIDATE_CONTAINERS = { "MicroMenuContainer", "MicroButtonAndBagsBar" }

local resolvedButtons
local resolvedContainer

local function ResolveButtons()
	if resolvedButtons then return resolvedButtons end
	resolvedButtons = {}
	for _, candidate in ipairs(CANDIDATE_BUTTONS) do
		for _, name in ipairs(candidate.names) do
			local frame = _G[name]
			if frame then
				table.insert(resolvedButtons, { key = candidate.key, label = candidate.label, frame = frame, name = name })
				break
			end
		end
	end
	return resolvedButtons
end

local function ResolveContainer()
	if resolvedContainer ~= nil then return resolvedContainer or nil end
	for _, name in ipairs(CANDIDATE_CONTAINERS) do
		local frame = _G[name]
		if frame then
			resolvedContainer = frame
			return frame
		end
	end
	resolvedContainer = false
	return nil
end

function KUI:MicroMenuScanReport()
	local buttons = ResolveButtons()
	print("|cff33ff99Kain-UI Forever|r micro menu scan:")
	if #buttons == 0 then
		print("  No candidate micro menu button frames found on this client.")
	end
	for _, btn in ipairs(buttons) do
		print(string.format("  %s -> found as %s", btn.key, btn.name))
	end
	local foundKeys = {}
	for _, btn in ipairs(buttons) do foundKeys[btn.key] = true end
	for _, candidate in ipairs(CANDIDATE_BUTTONS) do
		if not foundKeys[candidate.key] then
			print(string.format("  %s -> not found (tried: %s)", candidate.key, table.concat(candidate.names, ", ")))
		end
	end
	local container = ResolveContainer()
	print("  whole-menu container -> " .. (container and container:GetName() or "not found (tried: " .. table.concat(CANDIDATE_CONTAINERS, ", ") .. ")"))
end

local hookedButtons = setmetatable({}, { __mode = "k" })
local blizzardRefreshHooked = false
local pendingAfterCombat = false
local pendingFullApply = false

local function EnforceButton(btn)
	local hidden = KUI.db and KUI.db.hiddenMicroButtons
	if not (hidden and hidden[btn.key]) or not btn.frame:IsShown() then return end
	if InCombatLockdown() and btn.frame.IsProtected and btn.frame:IsProtected() then
		pendingAfterCombat = true
		return
	end
	btn.frame:Hide()
end

function KUI:EnforceMicroButtonVisibility()
	for _, btn in ipairs(ResolveButtons()) do
		EnforceButton(btn)
	end
end

local function InstallEnforcement()
	for _, btn in ipairs(ResolveButtons()) do
		if not hookedButtons[btn.frame] then
			hookedButtons[btn.frame] = true
			btn.frame:HookScript("OnShow", function() EnforceButton(btn) end)
		end
	end
	if not blizzardRefreshHooked and type(_G.UpdateMicroButtons) == "function" then
		blizzardRefreshHooked = true
		hooksecurefunc("UpdateMicroButtons", function() KUI:EnforceMicroButtonVisibility() end)
	end
end

local regenFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(regenFrame, "PLAYER_REGEN_ENABLED")
regenFrame:SetScript("OnEvent", function()
	if pendingAfterCombat then
		pendingAfterCombat = false
		if pendingFullApply then
			pendingFullApply = false
			KUI:ApplyMicroMenuVisibility()
		else
			KUI:EnforceMicroButtonVisibility()
		end
	end
end)

function KUI:ApplyMicroMenuVisibility()
	if not KUI.db then return end
	InstallEnforcement()

	local container = ResolveContainer()

	if InCombatLockdown() then
		local protected = container and container.IsProtected and container:IsProtected()
		if not protected then
			for _, btn in ipairs(ResolveButtons()) do
				if btn.frame.IsProtected and btn.frame:IsProtected() then protected = true; break end
			end
		end
		if protected then
			pendingAfterCombat = true
			pendingFullApply = true
			return
		end
	end
	if container then
		if KUI.db.microMenuHidden then
			container:Hide()
			return
		else
			container:Show()
		end
	end

	local hidden = KUI.db.hiddenMicroButtons
	for _, btn in ipairs(ResolveButtons()) do
		if hidden[btn.key] then
			btn.frame:Hide()
		else
			btn.frame:Show()
		end
	end
end

function KUI:SetMicroButtonHidden(buttonKey, isHidden)
	if not KUI.db then return end

	KUI.db.hiddenMicroButtons[buttonKey] = isHidden and true or false
	KUI:ApplyMicroMenuVisibility()
end

function KUI:SetMicroMenuHidden(isHidden)
	if not KUI.db then return end
	KUI.db.microMenuHidden = isHidden
	KUI:ApplyMicroMenuVisibility()
end

function KUI:GetMicroButtonOptions()
	local options = {}
	for _, btn in ipairs(ResolveButtons()) do
		table.insert(options, btn)
	end
	return options
end
