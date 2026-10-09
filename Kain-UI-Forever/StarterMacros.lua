local _, KUI = ...

local STARTER_MACROS = {
	{
		key = "coinflip",
		name = "Coin Flip",
		icon = "INV_Misc_Coin_17",
		body = [[/run local d=random(101)local t=GetUnitName("target",1)local r=d==101 and "The coin landed upright? That's odd.." or d<=50 and "Heads!" or "Tails!" SendChatMessage(format("flips a coin%s. He reveals.. %s", t and " for "..t or "", r), "EMOTE")]],
	},
	{
		key = "skullmarker",
		name = "Skull Marker",
		icon = "INV_Misc_Bone_HumanSkull_02",
		body = "/target [@mouseover,harm,nodead]\n/tm 8",
	},
	{
		key = "crossmarker",
		name = "Cross Marker",
		icon = "Ability_Revendreth_DemonHunter",
		body = "/target [@mouseover,harm,nodead]\n/tm 7",
	},
	{
		key = "guildinviter",
		name = "Guild Inviter",
		icon = "INV_Letter_18",
		body = [[/run local u="mouseover"; if not(UnitExists(u) and UnitIsPlayer(u)) then u="target" end; if UnitExists(u) and UnitIsPlayer(u) then local n,r=UnitFullName(u); C_GuildInfo.Invite(r and n.."-"..r or n) end]],
	},
}

local scanLines = { "starter macros haven't been installed yet this session -- run /kainui installmacros." }
local function ResetScan() scanLines = {} end
local function Note(fmt, ...) table.insert(scanLines, string.format(fmt, ...)) end

function KUI:StarterMacroScanReport()
	print("|cff33ff99Kain-UI Forever|r starter macro scan:")
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
end

function KUI:InstallStarterMacros(isLogin)
	if not KUI.db then return end
	ResetScan()

	local createMacro = _G.CreateMacro or (C_Macro and C_Macro.CreateMacro)
	local getIndexByName = _G.GetMacroIndexByName or (C_Macro and C_Macro.GetMacroIndexByName)
	if not createMacro then
		Note("couldn't find CreateMacro (or C_Macro.CreateMacro) on this client -- starter macros can't be installed.")
		return
	end

	KUI.db.installedStarterMacros = KUI.db.installedStarterMacros or {}

	for _, macro in ipairs(STARTER_MACROS) do
		local existingIndex
		if getIndexByName then
			local ok, idx = pcall(getIndexByName, macro.name)
			if ok and idx and idx > 0 then existingIndex = idx end
		end

		if KUI.db.installedStarterMacros[macro.key] and (isLogin or existingIndex or not getIndexByName) then

			Note("%s: already installed, left alone.", macro.name)
		else
			if existingIndex then
				Note("%s: a macro with this exact name already exists -- left it alone, not duplicated.", macro.name)
				KUI.db.installedStarterMacros[macro.key] = true
			else
				local ok, result = pcall(createMacro, macro.name, macro.icon, macro.body, nil)
				if ok and result then
					Note("%s: installed (icon: %s).", macro.name, macro.icon)
					KUI.db.installedStarterMacros[macro.key] = true
				else
					Note("%s: NOT installed (%s) -- will retry next login or /kainui installmacros. This usually means the account-wide macro slots are full.", macro.name, tostring(result))
				end
			end
		end
	end
end
