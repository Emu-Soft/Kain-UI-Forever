local _, KUI = ...

local PLATER_STYLE_CVARS = {

	UnitNameOwn = "1",
	UnitNamePlayerGuild = "1",
	UnitNamePlayerPVPTitle = "1",
	UnitNameGuildTitle = "1",
	UnitNameNPC = "1",
	UnitNameHostleNPC = "0",
	UnitNameInteractiveNPC = "0",
	UnitNameFriendlySpecialNPCName = "0",
	UnitNameNonCombatCreatureName = "1",
	UnitNameFriendlyPlayerName = "1",
	UnitNameFriendlyMinionName = "1",
	UnitNameFriendlyPetName = "1",
	UnitNameFriendlyGuardianName = "1",
	UnitNameFriendlyTotemName = "1",
	UnitNameEnemyPlayerName = "1",
	UnitNameEnemyMinionName = "1",
	UnitNameEnemyPetName = "1",
	UnitNameEnemyGuardianName = "1",
	UnitNameEnemyTotemName = "1",

	nameplateShowAll = "1",
	nameplateShowEnemies = "1",
	nameplateShowEnemyMinions = "1",
	nameplateShowEnemyPets = "1",
	nameplateShowEnemyGuardians = "1",
	nameplateShowEnemyTotems = "1",
	nameplateShowEnemyMinus = "1",
	nameplateShowFriendlyPlayers = "1",
	nameplateShowFriendlyPlayerMinions = "0",
	nameplateShowFriendlyPlayerPets = "0",
	nameplateShowFriendlyPlayerGuardians = "0",
	nameplateShowFriendlyPlayerTotems = "0",
	nameplateShowOnlyNameForFriendlyPlayerUnits = "1",
	nameplateUseClassColorForFriendlyPlayerUnitNames = "1",
	nameplateShowFriendlyNpcs = "0",
	nameplateShowOffscreen = "0",
	nameplateStackingTypes = "\002A",
	nameplateSize = "2",
	nameplateAuraScale = "1.000000",
	nameplateStyle = "1",
	nameplateInfoDisplay = "\002",
	nameplateCastBarDisplay = "\002[",
	nameplateThreatDisplay = "\002G",
	nameplateEnemyNpcAuraDisplay = "\002G",
	nameplateEnemyPlayerAuraDisplay = "\002G",
	nameplateFriendlyPlayerAuraDisplay = "\002C",
	nameplateDebuffPadding = "0",
	nameplateSimplifiedTypes = "\002",
	nameplateShowClassColor = "1",
	nameplateShowFriendlyClassColor = "1",
}

local CAPTURE_PATTERNS = { "nameplate", "unitname" }

if KUI.defaults then
	KUI.defaults.platerStyle = false
	KUI.defaults.platerStyleBackup = nil
end

local function GetCVarValue(name)
	if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
	return GetCVar and GetCVar(name)
end

local function SetCVarValue(name, value)
	if C_CVar and C_CVar.SetCVar then
		return pcall(C_CVar.SetCVar, name, value)
	end
	return pcall(SetCVar, name, value)
end

local function HasPlaterStyleValues()
	return next(PLATER_STYLE_CVARS) ~= nil
end

function KUI:SetPlaterStyle(enabled)
	if not self.db then return false end
	if InCombatLockdown and InCombatLockdown() then
		print("|cffff6060Kain-UI Forever:|r nameplate settings can't be changed during combat -- try again after.")
		return false
	end

	if enabled then
		if not HasPlaterStyleValues() then
			print("|cffff6060Kain-UI Forever:|r Plater style isn't set up yet -- its nameplate values still need to be captured (/kainui nameplatecapture).")
			return false
		end
		self.db.platerStyleBackup = self.db.platerStyleBackup or {}
		local failed = {}
		for name, value in pairs(PLATER_STYLE_CVARS) do
			if self.db.platerStyleBackup[name] == nil then
				self.db.platerStyleBackup[name] = GetCVarValue(name)
			end
			if not SetCVarValue(name, value) then failed[#failed + 1] = name end
		end
		self.db.platerStyle = true
		if #failed > 0 then
			print("|cffff6060Kain-UI Forever:|r Plater style applied, except: " .. table.concat(failed, ", "))
		else
			print("|cff33ff99Kain-UI Forever|r Plater style nameplates on.")
		end
	else
		local backup = self.db.platerStyleBackup
		if backup then
			for name, value in pairs(backup) do SetCVarValue(name, value) end
		end
		self.db.platerStyleBackup = nil
		self.db.platerStyle = false
		print("|cff33ff99Kain-UI Forever|r Plater style off -- your previous nameplate settings are back.")
	end
	return true
end

local function AllCVarNames()
	local names = {}
	local list
	if C_Console and C_Console.GetAllCommands then
		local ok, result = pcall(C_Console.GetAllCommands)
		if ok then list = result end
	elseif ConsoleGetAllCommands then
		local ok, result = pcall(ConsoleGetAllCommands)
		if ok then list = result end
	end
	local cvarType = Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar
	for _, entry in ipairs(list or {}) do
		if type(entry) == "table" and entry.command
			and (cvarType == nil or entry.commandType == cvarType) then
			names[#names + 1] = entry.command
		end
	end
	return names
end

local function Printable(value)
	return (tostring(value):gsub("[%z\1-\31\127-\255]", function(c)
		return string.format("\\%03d", c:byte())
	end))
end

local function MatchesCapture(name)
	local lower = name:lower()
	for _, pattern in ipairs(CAPTURE_PATTERNS) do
		if lower:find(pattern, 1, true) then return true end
	end
	return false
end

function KUI:NameplateCaptureReport()
	if not self.db then return end
	local names = AllCVarNames()
	if #names == 0 then
		print("|cffff6060Kain-UI Forever:|r couldn't list the client's CVars (C_Console.GetAllCommands missing) -- can't capture.")
		return
	end

	local capture, changed = {}, {}
	for _, name in ipairs(names) do
		if MatchesCapture(name) then
			local value, default
			if C_CVar and C_CVar.GetCVarInfo then
				local ok, v, d = pcall(C_CVar.GetCVarInfo, name)
				if ok then value, default = v, d end
			end
			value = value or GetCVarValue(name)
			if value ~= nil then
				capture[name] = { value = value, default = default }
				if default ~= nil and value ~= default then
					changed[#changed + 1] = name .. " = " .. Printable(value) .. "  (default " .. Printable(default) .. ")"
				end
			end
		end
	end
	table.sort(changed)
	self.db.nameplateCapture = capture

	local count = 0
	for _ in pairs(capture) do count = count + 1 end
	print("|cff33ff99Kain-UI Forever|r nameplate capture: " .. count .. " nameplate CVars saved. Changed from Blizzard's defaults:")
	if #changed == 0 then
		print("  (none)")
	end
	for _, line in ipairs(changed) do print("  " .. line) end
	print("  Log out or /reload so the game writes it to the SavedVariables file, then send Kain-UI-Forever.lua from WTF/Account/.../SavedVariables.")
end
