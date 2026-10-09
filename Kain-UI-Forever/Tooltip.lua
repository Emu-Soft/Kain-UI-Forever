local addonName, KUI = ...

local TOOLTIP_FRAMES = {
	"GameTooltip",
}

local DENIED_DATA_TYPES = { "Item" }

local scanLines = {}
local lastForceError
local function ResetScan() scanLines = {} end
local function Note(fmt, ...) table.insert(scanLines, string.format(fmt, ...)) end

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

local CURSOR_TOOLTIP_WINDOWS = { "^NamePlate%d+$", "^LegacySystemFrame$" }

local function IsInsideCursorTooltipWindow(frame)
	local ok, result = pcall(function()
		local f, depth = frame, 0
		while f and depth < 12 do
			if f.IsForbidden and f:IsForbidden() then return false end
			local name = f.GetName and f:GetName()
			if type(name) == "string" then
				for _, pattern in ipairs(CURSOR_TOOLTIP_WINDOWS) do
					if name:find(pattern) then return true end
				end
			end
			f = f.GetParent and f:GetParent()
			depth = depth + 1
		end
		return false
	end)
	return ok and result == true
end

local lastWorldTooltip

local extraAnchorFixes = 0
local instantAnchorFixes = 0
local worldTooltipLog = {}

local trainerGateHides = 0
local trainerGateShows = 0

function KUI:TooltipScanReport()
	print("|cff33ff99Kain-UI Forever|r tooltip scan:")
	if #scanLines == 0 then
		print("  (nothing to report yet -- open the options panel or /reload, then run this again)")
		return
	end
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
	if lastForceError then
		print("  |cffff5555last positioning error:|r " .. tostring(lastForceError))
	end
	if lastWorldTooltip then
		print("  last world tooltip: " .. lastWorldTooltip)
	end
	print("  extra tooltip anchors removed: " .. instantAnchorFixes .. " instantly (SetPoint hook), " .. extraAnchorFixes .. " a frame late (OnUpdate)")
	print("  trainer tooltips (icon only): hidden off the icon " .. trainerGateHides .. "x, shown on the icon " .. trainerGateShows .. "x")
	if KUI.TooltipLastResize then
		local r = KUI:TooltipLastResize()
		if r then print("  last re-measure: " .. r) end
	end
	if #worldTooltipLog > 0 then
		print("  recent world tooltips (newest last) -- what Blizzard sent with each:")
		for _, line in ipairs(worldTooltipLog) do print("    " .. line) end
	end
end

local hooked = {}
local tracked = {}
local applying = {}
local anchorFrame

local function IsTouchable(tip)
	if not tip then return false end
	if tip.IsForbidden and tip:IsForbidden() then return false end
	return true
end

local allowedContent = {}

local healthBars = {}

local BAR_HEIGHT = 10
local BAR_INSET_X = 10
local BAR_INSET_Y = 8
local BAR_RESERVE = BAR_HEIGHT + 4
local barPadding = {}

local HideHealthBar

local EXCLUDED_FRAMES = {
	"PlayerTalentFrame",
	"ClassTalentFrame",
	"PlayerSpellsFrame",
}

local function IsInExcludedFrame(tip)
	local owner = tip.GetOwner and tip:GetOwner()
	local depth = 0
	while owner and depth < 30 do
		if owner.IsForbidden and owner:IsForbidden() then return false end
		for _, name in ipairs(EXCLUDED_FRAMES) do
			if owner == _G[name] then return true end
		end
		owner = owner.GetParent and owner:GetParent()
		depth = depth + 1
	end
	return false
end

local function IsAllowedContent(tip)
	return allowedContent[tip] == true and not IsInExcludedFrame(tip)
end

local function MarkDenied(tip)
	allowedContent[tip] = false
	HideHealthBar(tip)
end

local function IsGrowRightActive()
	return KUI.db and KUI.db.tooltipAnchorMode == "growRight"
end

local ForcePosition
local RestoreCompareTooltips
local RefreshTooltipSize
local FitTooltipToText

local TRAINER_FRAME_NAMES = { "ClassTrainerFrame", "TrainerFrame", "ProfessionTrainerFrame" }

local function IsTrainerOwner(tip)
	local ok, result = pcall(function()
		local f = tip.GetOwner and tip:GetOwner()
		local depth = 0
		while f and depth < 25 do
			for _, name in ipairs(TRAINER_FRAME_NAMES) do
				if _G[name] and f == _G[name] then return true end
			end
			f = f.GetParent and f:GetParent()
			depth = depth + 1
		end
		return false
	end)
	return ok and result == true
end

local COMPARE_TOOLTIPS = { "ShoppingTooltip1", "ShoppingTooltip2" }
local compareHidden = false

local function HideCompareTooltips()
	for _, name in ipairs(COMPARE_TOOLTIPS) do
		local t = _G[name]
		if t and t.SetAlpha then t:SetAlpha(0) end
	end
	compareHidden = true
end

function RestoreCompareTooltips()
	if not compareHidden then return end
	for _, name in ipairs(COMPARE_TOOLTIPS) do
		local t = _G[name]
		if t and t.SetAlpha then t:SetAlpha(1) end
	end
	compareHidden = false
end

local trainerGated = false
local gateOwner, gateIcon

local function TrainerRowIcon(tip)
	local okO, owner = pcall(tip.GetOwner, tip)
	if not okO or not owner then return nil end
	if owner == gateOwner then return gateIcon or nil end

	gateOwner, gateIcon = owner, false
	local okI, icon = pcall(function() return owner.icon end)
	if okI and type(icon) == "table" and icon.IsMouseOver and IsTrainerOwner(tip) then
		gateIcon = icon
	end
	return gateIcon or nil
end

local function UpdateTrainerIconGate(tip)
	if tip ~= _G.GameTooltip or not IsTouchable(tip) then return end
	local icon
	if IsGrowRightActive() and tip:IsShown() then icon = TrainerRowIcon(tip) end
	if icon then
		local okM, over = pcall(icon.IsMouseOver, icon)
		local want = (okM and over == true) and 1 or 0
		if tip:GetAlpha() ~= want then
			tip:SetAlpha(want)
			if want == 0 then trainerGateHides = trainerGateHides + 1 else trainerGateShows = trainerGateShows + 1 end
		end
		trainerGated = true
	elseif trainerGated then

		trainerGated = false
		tip:SetAlpha(1)
	end
end

local function MarkAllowed(tip)
	if IsTrainerOwner(tip) then
		HideCompareTooltips()
		allowedContent[tip] = false
		if IsGrowRightActive() then
			tip:ClearAllPoints()
			pcall(tip.SetAnchorType, tip, "ANCHOR_CURSOR")
		end
		UpdateTrainerIconGate(tip)
		return
	end
	allowedContent[tip] = true
	if tracked[tip] and IsGrowRightActive() and IsAllowedContent(tip) then
		ForcePosition(tip)
	end
end

local function OnContentAllowed(tip)
	MarkAllowed(tip)
	HideHealthBar(tip)
end

local function IsActionButtonOwner(tip)
	local ok, result = pcall(function()
		local owner = tip.GetOwner and tip:GetOwner()
		if not owner then return false end
		if owner.action ~= nil then return true end
		if owner.GetAttribute and owner:GetAttribute("action") ~= nil then return true end
		return false
	end)
	return ok and result == true
end

local function OnItemContent(tip)
	if IsActionButtonOwner(tip) then
		OnContentAllowed(tip)
	else
		MarkDenied(tip)
	end
end

local function IsWorldObjectTooltip(tip)
	local owner = tip.GetOwner and tip:GetOwner()
	if owner ~= UIParent then return false end
	local hasUnit = UnitExists("mouseover")
	if issecretvalue and issecretvalue(hasUnit) then return false end
	return not hasUnit
end

local PINNED_OBJECT_WORDS = {
	"chair", "bench", "stool",

	"campfire", "cozy fire", "cookie", "iron oven",
	"fish bowl", "fishing rack", "fishing hut",
	"first aid kit", "toxin study", "laboratory",
	"mana well", "fermenter",
	"faction banner", "camp tent", "field guide",
	"sharpening wheel", "anvil", "forge",
	"enchanted lute", "arcane salvager", "workbench",
	"incense candle", "greenhouse", "seed hybridizer",
	"tanning rack", "sewing machine", "lodestone",
	"rock garden", "molten foundry", "spinning wheel", "loom",
	"mailbox", "cookpot",
	"hot coals", "dwarven brazier",
}

local function FirstLine(tip)
	local tipName = tip.GetName and tip:GetName()
	local line = tipName and _G[tipName .. "TextLeft1"]
	local text = line and line:GetText()
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return nil end
	return text
end

local function ToMouse(tip)
	if not IsGrowRightActive() then return end
	tip:ClearAllPoints()
	pcall(tip.SetAnchorType, tip, "ANCHOR_CURSOR")
end

local function Printable(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
	return "<" .. t .. ">"
end

local function RecordWorldTooltip(tip, data)
	local name = FirstLine(tip)
	local parts = {}
	if type(data) == "table" and not (issecretvalue and issecretvalue(data)) then
		local keys = {}
		pcall(function() for k in pairs(data) do if type(k) == "string" then keys[#keys + 1] = k end end end)
		table.sort(keys)
		for _, k in ipairs(keys) do
			if k ~= "lines" then parts[#parts + 1] = k .. "=" .. Printable(data[k]) end
		end
		if type(data.lines) == "table" then
			local lineTypes = {}
			for i, line in ipairs(data.lines) do
				lineTypes[#lineTypes + 1] = Printable(type(line) == "table" and line.type or nil)
				if i >= 6 then break end
			end
			parts[#parts + 1] = "lines=" .. #data.lines .. " [" .. table.concat(lineTypes, ",") .. "]"
		end
	else
		parts[#parts + 1] = "(no content data)"
	end
	parts[#parts + 1] = "numLines=" .. Printable(tip.NumLines and tip:NumLines())
	table.insert(worldTooltipLog, "\"" .. tostring(name) .. "\": " .. table.concat(parts, " "))
	while #worldTooltipLog > 6 do table.remove(worldTooltipLog, 1) end
end

local function OnWorldObjectContent(tip)
	if IsAllowedContent(tip) or not IsWorldObjectTooltip(tip) then return end
	local name = FirstLine(tip)
	local pinned = false
	if name then
		local lower = name:lower()

		if lower:find("^corpse of") then pinned = true end
		for _, word in ipairs(PINNED_OBJECT_WORDS) do

			if lower:find("%f[%w]" .. word .. "%f[%W]") then pinned = true break end
		end
	end
	if pinned then
		lastWorldTooltip = "\"" .. name .. "\" -- matches the pinned list: pinned to the anchor"
		OnContentAllowed(tip)
		FitTooltipToText(tip)
		if IsGrowRightActive() and tip:IsShown() then ForcePosition(tip) end
		RefreshTooltipSize(tip)
		return
	end
	lastWorldTooltip = "\"" .. tostring(name) .. "\" -- on the mouse"
	ToMouse(tip)
end

local function OnObjectContent(tip, data)
	if IsWorldObjectTooltip(tip) then RecordWorldTooltip(tip, data) end
	OnWorldObjectContent(tip)
end

local function OnActionBarOnlyContent(tip)
	if IsActionButtonOwner(tip) then OnContentAllowed(tip) end
end

local COLOR_FRIENDLY_SOLO  = { 0x00 / 0xFF, 0xCC / 0xFF, 0xFF / 0xFF }
local COLOR_FRIENDLY_GROUP = { 0xAA / 0xFF, 0xAB / 0xFF, 0xFE / 0xFF }

local COLOR_FRIENDLY_PVP_FALLBACK = { 0, 0.6, 26 / 255 }
local function FriendlyPvPColor()
	local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[6]
	if c and c.r and c.g and c.b then return { c.r, c.g, c.b } end
	return COLOR_FRIENDLY_PVP_FALLBACK
end

local function GetNameLineColor(unit)
	if not unit or not Plain(UnitExists(unit)) then return nil end
	if not Plain(UnitIsPlayer(unit)) then return nil end
	if not Plain(UnitIsFriend("player", unit)) then return nil end
	if Plain(UnitIsPVP(unit)) then
		return FriendlyPvPColor()
	end
	if Plain(UnitInParty(unit)) or Plain(UnitInRaid(unit)) then
		return COLOR_FRIENDLY_GROUP
	end
	return COLOR_FRIENDLY_SOLO
end

local function ColorNameLine(tip, unit)
	local color = GetNameLineColor(unit)
	if not color then return end
	if not tip or not tip.GetName then return end
	local tipName = tip:GetName()
	if not tipName then return end
	local fs = _G[tipName .. "TextLeft1"]
	if fs then
		fs:SetTextColor(unpack(color))
	end
end

local GUILD_LINE_COLOR = { 1, 1, 1 }

local function GetGuildLineText(unit)
	if not unit or not Plain(UnitExists(unit)) then return nil end
	local guildName, guildRankName, guildRankIndex = GetGuildInfo(unit)
	if not guildName then return nil end
	return string.format("<%s> %s (%d)", guildName, guildRankName or "", guildRankIndex or 0)
end

local function InsertLine2(tip, text, r, g, b)
	if not tip.GetName or not tip:GetName() then return end
	local tipName = tip:GetName()
	local numLines = tip:NumLines()
	if numLines < 2 then return end

	tip:AddLine("")
	for i = numLines + 1, 3, -1 do
		local srcLeft, srcRight = _G[tipName .. "TextLeft" .. (i - 1)], _G[tipName .. "TextRight" .. (i - 1)]
		local dstLeft, dstRight = _G[tipName .. "TextLeft" .. i], _G[tipName .. "TextRight" .. i]
		if srcLeft and dstLeft then
			dstLeft:SetText(srcLeft:GetText())
			dstLeft:SetTextColor(srcLeft:GetTextColor())
		end
		if srcRight and dstRight then
			dstRight:SetText(srcRight:GetText())
			dstRight:SetTextColor(srcRight:GetTextColor())
		end
	end

	local left2 = _G[tipName .. "TextLeft2"]
	if left2 then
		left2:SetText(text)
		left2:SetTextColor(r, g, b)
	end
	tip:Show()
end

local CLASS_HEX = {
	DRUID   = "FF7C0A",
	HUNTER  = "AAD372",
	MAGE    = "3FC7EB",
	PALADIN = "F48CBA",
	PRIEST  = "FFFFFF",
	ROGUE   = "FFF468",
	SHAMAN  = "0070DD",
	WARLOCK = "8788EE",
	WARRIOR = "C69B6D",
}

local function ApplyGuildLine(tip, unit)
	local guildLine = GetGuildLineText(unit)
	if not guildLine then return end
	local tipName = tip.GetName and tip:GetName()
	if not tipName then return end
	local guildName = GetGuildInfo(unit)

	local nativeIdx
	for i = 2, tip:NumLines() do
		local fs = _G[tipName .. "TextLeft" .. i]
		local text = fs and fs:GetText()

		if not (issecretvalue and issecretvalue(text)) then
			if text == guildLine then return end
			if not nativeIdx and (text == guildName or text == "<" .. guildName .. ">") then
				nativeIdx = i
			end
		end
	end

	if nativeIdx then
		local fs = _G[tipName .. "TextLeft" .. nativeIdx]
		fs:SetText(guildLine)
		fs:SetTextColor(GUILD_LINE_COLOR[1], GUILD_LINE_COLOR[2], GUILD_LINE_COLOR[3])
		tip:Show()
	else
		InsertLine2(tip, guildLine, GUILD_LINE_COLOR[1], GUILD_LINE_COLOR[2], GUILD_LINE_COLOR[3])
	end
end

local function RemoveLine(tip, idx)
	local tipName = tip:GetName()
	local n = tip:NumLines()
	for i = idx, n - 1 do
		local srcL, srcR = _G[tipName .. "TextLeft" .. (i + 1)], _G[tipName .. "TextRight" .. (i + 1)]
		local dstL, dstR = _G[tipName .. "TextLeft" .. i], _G[tipName .. "TextRight" .. i]
		if srcL and dstL then
			dstL:SetText(srcL:GetText())
			dstL:SetTextColor(srcL:GetTextColor())
		end
		if srcR and dstR then
			dstR:SetText(srcR:GetText())
			dstR:SetTextColor(srcR:GetTextColor())
		end
	end
	local lastL, lastR = _G[tipName .. "TextLeft" .. n], _G[tipName .. "TextRight" .. n]
	if lastL then lastL:SetText(nil) lastL:Hide() end
	if lastR then lastR:SetText(nil) lastR:Hide() end
end

local function ApplyClassOnLevelLine(tip, unit)
	if not Plain(UnitIsPlayer(unit)) then return end
	local className, classFile = UnitClass(unit)
	local hex = classFile and CLASS_HEX[classFile]
	if not className or not hex then return end
	local tipName = tip.GetName and tip:GetName()
	if not tipName then return end

	local marker = "(" .. PLAYER .. ")"
	local levelIdx, classIdx
	for i = 2, tip:NumLines() do
		local fs = _G[tipName .. "TextLeft" .. i]
		local text = fs and fs:GetText()

		if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
			if not levelIdx and text:find(marker, 1, true) then
				levelIdx = i
			elseif text == className then
				classIdx = i
			end
		end
	end
	if not levelIdx then return end

	local fs = _G[tipName .. "TextLeft" .. levelIdx]
	local text = fs:GetText()
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	local s, e = text:find(marker, 1, true)
	if not s then return end
	fs:SetText(text:sub(1, s - 1) .. "|cff" .. hex .. className .. "|r" .. text:sub(e + 1))

	if classIdx then RemoveLine(tip, classIdx) end
	tip:Show()
end

local function UsableWidth(value)
	if value == nil then return 0 end
	if issecretvalue and issecretvalue(value) then return 0 end
	return value
end

local function EnsureTooltipWidth(tip)
	local tipName = tip.GetName and tip:GetName()
	if not tipName then return end

	local maxWidth = 0
	for i = 1, tip:NumLines() do
		local left = _G[tipName .. "TextLeft" .. i]
		local right = _G[tipName .. "TextRight" .. i]
		local w = 0

		if left and left:IsShown() and type(left:GetText()) ~= "nil" then
			w = w + UsableWidth(left:GetStringWidth())
		end
		if right and right:IsShown() and type(right:GetText()) ~= "nil" then

			local rw = UsableWidth(right:GetStringWidth())
			if rw > 0 then w = w + rw + 20 end
		end
		if w > maxWidth then maxWidth = w end
	end
	if maxWidth <= 0 then return end

	local padded = maxWidth + 30

	if tip.SetMinimumWidth then

		pcall(tip.SetMinimumWidth, tip, padded)
	elseif padded > UsableWidth(tip:GetWidth()) then
		pcall(tip.SetWidth, tip, padded)
	end
	tip:Show()
end

local SPEC_PREFIX = "|cffe6cc80Specialization:|r"
local SPEC_ICON_SIZE = 14

local INSPECT_GAP = 1.5
local INSPECT_TIMEOUT = 2
local INSPECT_RETRY_AFTER = 4
local SPEC_CACHE_TTL = 300
local PARTIAL_CACHE_TTL = 15
local POLL_INTERVAL = 0.2
local POLL_TRIES = 8

local ROLE_ATLASES = {
	TANK    = { "roleicon-tiny-tank", "UI-LFG-RoleIcon-Tank-Micro", "UI-LFG-RoleIcon-Tank" },
	HEALER  = { "roleicon-tiny-healer", "UI-LFG-RoleIcon-Healer-Micro", "UI-LFG-RoleIcon-Healer" },
	DAMAGER = { "roleicon-tiny-dps", "UI-LFG-RoleIcon-DPS-Micro", "UI-LFG-RoleIcon-DPS" },
}
local roleMarkupCache = {}

local function RoleMarkup(role)
	if not role then return "" end
	if roleMarkupCache[role] ~= nil then return roleMarkupCache[role] end
	local markup = ""
	if C_Texture and C_Texture.GetAtlasInfo then
		for _, atlas in ipairs(ROLE_ATLASES[role] or {}) do
			if C_Texture.GetAtlasInfo(atlas) then
				markup = format("|A:%s:%d:%d|a", atlas, SPEC_ICON_SIZE, SPEC_ICON_SIZE)
				break
			end
		end
	end
	roleMarkupCache[role] = markup
	return markup
end

local function IconMarkup(icon)
	if type(icon) ~= "number" and type(icon) ~= "string" then return "" end

	return format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(icon), SPEC_ICON_SIZE, SPEC_ICON_SIZE)
end

local TREE_INFO = {
	WARRIOR = { { "Arms", "Ability_Rogue_Eviscerate", "DAMAGER" }, { "Fury", "Ability_Warrior_InnerRage", "DAMAGER" }, { "Protection", "INV_Shield_06", "TANK" } },
	PALADIN = { { "Holy", "Spell_Holy_HolyBolt", "HEALER" }, { "Protection", "Spell_Holy_DevotionAura", "TANK" }, { "Retribution", "Spell_Holy_AuraOfLight", "DAMAGER" } },
	HUNTER  = { { "Beast Mastery", "Ability_Hunter_BeastTaming", "DAMAGER" }, { "Marksmanship", "Ability_Marksmanship", "DAMAGER" }, { "Survival", "Ability_Hunter_SwiftStrike", "DAMAGER" } },
	ROGUE   = { { "Assassination", "Ability_Rogue_Eviscerate", "DAMAGER" }, { "Combat", "Ability_BackStab", "DAMAGER" }, { "Subtlety", "Ability_Stealth", "DAMAGER" } },
	PRIEST  = { { "Discipline", "Spell_Holy_WordFortitude", "HEALER" }, { "Holy", "Spell_Holy_HolyBolt", "HEALER" }, { "Shadow", "Spell_Shadow_ShadowWordPain", "DAMAGER" } },
	SHAMAN  = { { "Elemental", "Spell_Nature_Lightning", "DAMAGER" }, { "Enhancement", "Spell_Nature_LightningShield", "DAMAGER" }, { "Restoration", "Spell_Nature_MagicImmunity", "HEALER" } },
	MAGE    = { { "Arcane", "Spell_Holy_MagicalSentry", "DAMAGER" }, { "Fire", "Spell_Fire_FireBolt02", "DAMAGER" }, { "Frost", "Spell_Frost_FrostBolt02", "DAMAGER" } },
	WARLOCK = { { "Affliction", "Spell_Shadow_DeathCoil", "DAMAGER" }, { "Demonology", "Spell_Shadow_Metamorphosis", "DAMAGER" }, { "Destruction", "Spell_Shadow_RainOfFire", "DAMAGER" } },
	DRUID   = { { "Balance", "Spell_Nature_StarFall", "DAMAGER" }, { "Feral", "Ability_Racial_BearForm", "DAMAGER" }, { "Restoration", "Spell_Nature_HealingTouch", "HEALER" } },
}

local TREE_GAP_FACTOR = 2

local INSPECT_CONFIG_ID = Constants and Constants.TraitConsts
	and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1

local function ReadTreePoints(isInspect, expectedName)
	local traits = C_Traits
	if not traits or not traits.GetConfigInfo or not traits.GetTreeNodes or not traits.GetNodeInfo then return nil end

	local configID
	if isInspect then
		if traits.HasValidInspectData and not traits.HasValidInspectData() then return nil end
		configID = INSPECT_CONFIG_ID
	else
		configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
	end
	if not configID then return nil end

	local okInfo, info = pcall(traits.GetConfigInfo, configID)
	local treeID = okInfo and info and info.treeIDs and info.treeIDs[1]
	if not treeID then return nil end

	if expectedName and info.name ~= expectedName then return nil end
	local okNodes, nodes = pcall(traits.GetTreeNodes, treeID)
	if not okNodes or type(nodes) ~= "table" then return nil end

	local spentAt = {}
	for _, nodeID in ipairs(nodes) do
		local ok, node = pcall(traits.GetNodeInfo, configID, nodeID)
		if ok and node and node.ID and node.ID ~= 0 and node.isVisible ~= false and type(node.posX) == "number" then
			spentAt[node.posX] = (spentAt[node.posX] or 0) + (node.activeRank or 0)
		end
	end
	local xs = {}
	for x in pairs(spentAt) do xs[#xs + 1] = x end
	if #xs == 0 then return nil end
	table.sort(xs)

	if #xs < 3 then return nil end

	local gapList = {}
	for i = 2, #xs do gapList[#gapList + 1] = xs[i] - xs[i - 1] end
	table.sort(gapList)
	local typical = gapList[math.ceil(#gapList / 2)]
	local threshold = math.max(typical * TREE_GAP_FACTOR, 1)

	local groups = { { first = xs[1], last = xs[1], columns = 1, spent = spentAt[xs[1]] } }
	for i = 2, #xs do
		local x = xs[i]
		local g = groups[#groups]
		if x - g.last > threshold then
			groups[#groups + 1] = { first = x, last = x, columns = 1, spent = spentAt[x] }
		else
			g.last, g.columns, g.spent = x, g.columns + 1, g.spent + spentAt[x]
		end
	end

	while #groups > 3 do
		local smallest = 1
		for i = 2, #groups do
			if groups[i].columns < groups[smallest].columns then smallest = i end
		end
		local g = groups[smallest]
		local left, right = groups[smallest - 1], groups[smallest + 1]
		local into
		if left and right then
			into = (g.first - left.last) <= (right.first - g.last) and left or right
		else
			into = left or right
		end
		into.first = math.min(into.first, g.first)
		into.last = math.max(into.last, g.last)
		into.columns = into.columns + g.columns
		into.spent = into.spent + g.spent
		table.remove(groups, smallest)
	end
	if #groups ~= 3 then return nil end

	return { groups[1].spent, groups[2].spent, groups[3].spent }
end

local function ClassSpecInfo(unit, isInspect)
	local csi = C_SpecializationInfo
	if isInspect then
		local getInspect = (csi and csi.GetInspectSpecialization) or GetInspectSpecialization
		local specID = getInspect and getInspect(unit)
		if not specID or specID == 0 or not GetSpecializationInfoByID then return nil end
		local _, name, _, icon, role = GetSpecializationInfoByID(specID)
		return name, icon, role
	elseif csi and csi.GetSpecialization and csi.GetSpecializationInfo then
		local index = csi.GetSpecialization()
		if not index or index == 0 then return nil end
		local _, name, _, icon, role = csi.GetSpecializationInfo(index)
		return name, icon, role
	end
end

local function ReadSpec(unit, isInspect)
	local _, classFile = UnitClass(unit)
	local specName, specIcon, specRole = ClassSpecInfo(unit, isInspect)
	if isInspect and (not specName or specName == "") then return nil, false end

	local points = ReadTreePoints(isInspect, isInspect and specName or nil)
	local trees = classFile and TREE_INFO[classFile]
	if points and trees and #points == #trees then
		local best, bestPoints = nil, 0
		for i, spent in ipairs(points) do
			if spent > bestPoints then best, bestPoints = i, spent end
		end
		if not best then return false, true end
		local tree = trees[best]
		return {
			name = tree[1], icon = "Interface\\Icons\\" .. tree[2], role = tree[3],
			classFile = classFile, points = points,
		}, true
	end

	if not specName or specName == "" then return nil, false end
	return { name = specName, icon = specIcon, role = specRole, classFile = classFile, points = points }, points ~= nil
end

local function FormatSpecLine(spec)
	local hex = spec.classFile and CLASS_HEX[spec.classFile]
	local name = hex and ("|cff" .. hex .. spec.name .. "|r") or spec.name
	local text = SPEC_PREFIX .. " " .. RoleMarkup(spec.role) .. IconMarkup(spec.icon) .. " " .. name
	if spec.points and #spec.points > 0 then
		text = text .. " (" .. table.concat(spec.points, "/") .. ")"
	end
	return text
end

local specCache = {}
local failedAt = {}
local pendingGUID, pendingSince
local weInitiated = false
local lastInspect = 0
local inspectQueued = false

local function SafeGUID(unit)
	local guid = UnitGUID(unit)
	if not guid or (issecretvalue and issecretvalue(guid)) then return nil end
	return guid
end

local function InspectFrameOpen()
	return InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()
end

local function SetSpecLine(tip, text)
	local tipName = tip.GetName and tip:GetName()
	if not tipName then return false end
	for i = 2, tip:NumLines() do
		local fs = _G[tipName .. "TextLeft" .. i]
		local current = fs and fs:GetText()

		if type(current) == "string" and not (issecretvalue and issecretvalue(current))
			and current:find(SPEC_PREFIX, 1, true) == 1 then
			if current == text then return false end
			fs:SetText(text)
			return true
		end
	end
	tip:AddLine(text)
	return true
end

local function GetKnownSpec(unit)
	if Plain(UnitIsUnit(unit, "player")) then
		return (ReadSpec("player", false))
	end
	local guid = SafeGUID(unit)
	local entry = guid and specCache[guid]
	local ttl = entry and (entry.partial and PARTIAL_CACHE_TTL or SPEC_CACHE_TTL)
	if entry and GetTime() - entry.time < ttl then
		return entry.spec
	end
	return nil
end

local RequestInspect

local function ApplySpecLine(tip, unit)
	if not Plain(UnitIsPlayer(unit)) then return end
	local spec = GetKnownSpec(unit)
	if spec then
		SetSpecLine(tip, FormatSpecLine(spec))
	elseif spec == nil and Plain(UnitIsUnit(unit, "player")) == false then
		RequestInspect()
	end
end

local function CurrentTooltipPlayer()
	local tip = GameTooltip
	if not tip or not IsTouchable(tip) or not tip:IsShown() or not tip.GetUnit then return nil end
	local _, unit = tip:GetUnit()
	if not unit or (issecretvalue and issecretvalue(unit)) then return nil end
	if not Plain(UnitExists(unit)) or not Plain(UnitIsPlayer(unit)) then return nil end
	return tip, unit
end

local function TryInspect()
	inspectQueued = false
	if pendingGUID and GetTime() - pendingSince < INSPECT_TIMEOUT then return end
	if pendingGUID then
		failedAt[pendingGUID] = GetTime()
		pendingGUID = nil
	end
	if InspectFrameOpen() then return end

	local _, unit = CurrentTooltipPlayer()
	if not unit or Plain(UnitIsUnit(unit, "player")) ~= false then return end
	local guid = SafeGUID(unit)
	if not guid or GetKnownSpec(unit) ~= nil then return end
	if failedAt[guid] and GetTime() - failedAt[guid] < INSPECT_RETRY_AFTER then return end
	if not CanInspect or not NotifyInspect then return end
	local okCan, can = pcall(CanInspect, unit, false)
	if not okCan or not can then
		failedAt[guid] = GetTime()
		return
	end

	pendingGUID, pendingSince = guid, GetTime()
	weInitiated = true
	lastInspect = GetTime()
	if not pcall(NotifyInspect, unit) then
		pendingGUID, weInitiated = nil, false
		failedAt[guid] = GetTime()
	end
end

function RequestInspect()
	if inspectQueued then return end
	inspectQueued = true
	local wait = math.max(0, INSPECT_GAP - (GetTime() - lastInspect))
	if C_Timer and C_Timer.After then
		C_Timer.After(wait, TryInspect)
	else
		TryInspect()
	end
end

local inspectFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(inspectFrame, "INSPECT_READY")

local function FinishOurInspect(guid)
	if guid ~= pendingGUID then return end
	pendingGUID = nil
	if weInitiated and not InspectFrameOpen() and ClearInspectPlayer then
		pcall(ClearInspectPlayer)
	end
	weInitiated = false
end

local polling = {}

local function PollInspect(guid, attempt)
	local tip, unit = CurrentTooltipPlayer()
	if not unit or SafeGUID(unit) ~= guid then

		polling[guid] = nil
		FinishOurInspect(guid)
		return
	end

	local spec, complete = ReadSpec(unit, true)
	local canWait = C_Timer and C_Timer.After and attempt < POLL_TRIES
	if not complete and canWait then

		if guid == pendingGUID then pendingSince = GetTime() end
		C_Timer.After(POLL_INTERVAL, function() PollInspect(guid, attempt + 1) end)
		return
	end

	polling[guid] = nil
	if spec ~= nil then
		specCache[guid] = { spec = spec, time = GetTime(), partial = not complete }
		failedAt[guid] = nil
	else
		failedAt[guid] = GetTime()
	end
	FinishOurInspect(guid)

	if spec and IsTouchable(tip) and SetSpecLine(tip, FormatSpecLine(spec)) then
		EnsureTooltipWidth(tip)
		if IsGrowRightActive() and IsAllowedContent(tip) then ForcePosition(tip) end
	end
end

inspectFrame:SetScript("OnEvent", function(self, event, guid)
	if not guid or (issecretvalue and issecretvalue(guid)) then return end

	if polling[guid] then return end
	polling[guid] = true
	PollInspect(guid, 1)
end)

local function EnsureHealthBar(tip)
	local bar = healthBars[tip]
	if bar then return bar end

	bar = CreateFrame("StatusBar", nil, tip)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetPoint("BOTTOMLEFT", tip, "BOTTOMLEFT", BAR_INSET_X, BAR_INSET_Y)
	bar:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -BAR_INSET_X, BAR_INSET_Y)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bg:SetColorTexture(0, 0, 0, 0.5)

	local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetFrameLevel(bar:GetFrameLevel() > 0 and bar:GetFrameLevel() - 1 or 0)
	if border.SetBackdrop then
		border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		border:SetBackdropBorderColor(0, 0, 0, 0.8)
	end

	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	bar.text = text

	healthBars[tip] = bar
	return bar
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local resizePending = setmetatable({}, { __mode = "k" })
local lastResize

function FitTooltipToText(tip)
	if not IsTouchable(tip) then return end
	if tip.SetMinimumWidth then pcall(tip.SetMinimumWidth, tip, 0) end
	if tip.GetPadding and tip.SetPadding then
		local r, b, l, t = tip:GetPadding()
		if not (IsSecret(r) or IsSecret(b)) then
			if l ~= nil and t ~= nil then
				pcall(tip.SetPadding, tip, r, b, l, t)
			else
				pcall(tip.SetPadding, tip, r or 0, b or 0)
			end
			tip:GetWidth()
		end
	end
end

function KUI:TooltipLastResize() return lastResize end

function RefreshTooltipSize(tip)
	if resizePending[tip] or not (C_Timer and C_Timer.After) then return end
	resizePending[tip] = true
	C_Timer.After(0, function()
		resizePending[tip] = nil
		if tip:IsShown() and IsTouchable(tip) then
			local before = tip:GetHeight()

			local relaid = false
			if tip.GetPadding and tip.SetPadding then
				local r, b, l, t = tip:GetPadding()
				if not (IsSecret(r) or IsSecret(b)) then
					if l ~= nil and t ~= nil then
						relaid = pcall(tip.SetPadding, tip, r, b, l, t)
					else
						relaid = pcall(tip.SetPadding, tip, r or 0, b or 0)
					end
					tip:GetWidth()
				end
			end
			if not relaid then pcall(tip.Show, tip) end

			local tipName = tip.GetName and tip:GetName()
			local first = tipName and _G[tipName .. "TextLeft1"]
			local text = first and first:GetText()
			if issecretvalue and issecretvalue(text) then text = "<secret>" end
			local after = tip:GetHeight()
			local function h(v) return (issecretvalue and issecretvalue(v)) and "?" or tostring(math.floor((v or 0) + 0.5)) end
			lastResize = format("\"%s\" lines=%s height %s -> %s", tostring(text),
				tostring(tip.NumLines and tip:NumLines()), h(before), h(after))
		end
	end)
end

local function SetBottomPadding(tip, bottom)
	if not tip.GetPadding or not tip.SetPadding then return false end
	local right, oldBottom, left, top = tip:GetPadding()
	if IsSecret(right) or IsSecret(oldBottom) then return false end
	right = right or 0
	if math.abs((oldBottom or 0) - bottom) < 0.5 then return true end
	local ok
	if left ~= nil and top ~= nil then
		ok = pcall(tip.SetPadding, tip, right, bottom, left, top)
	else
		ok = pcall(tip.SetPadding, tip, right, bottom)
	end

	if ok then tip:GetWidth() end

	if ok and bottom == 0 then RefreshTooltipSize(tip) end
	return ok
end

local function ReservePaddingForBar(tip)
	if SetBottomPadding(tip, BAR_RESERVE) then barPadding[tip] = true end
end

function HideHealthBar(tip)
	local bar = healthBars[tip]
	if bar then bar:Hide() end
	if barPadding[tip] then
		barPadding[tip] = nil
		if IsTouchable(tip) then SetBottomPadding(tip, 0) end
	end
end

local function GetHealthValues(unit)
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)

	if type(cur) == "nil" or type(max) == "nil" then return nil end
	return cur, max
end

local NOT_SPECIFIED_TYPE_ID = 10
local notSpecifiedName

local function HasCreatureType(unit)
	local creatureType = UnitCreatureType and UnitCreatureType(unit)

	if issecretvalue and issecretvalue(creatureType) then return true end
	if type(creatureType) ~= "string" or creatureType == "" then return false end
	if notSpecifiedName == nil then
		local info = C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo
			and C_CreatureInfo.GetCreatureTypeInfo(NOT_SPECIFIED_TYPE_ID)
		notSpecifiedName = (info and info.name) or "Not specified"
	end
	return creatureType ~= notSpecifiedName
end

local function ShouldShowHealthBar(unit)
	if Plain(UnitIsPlayer(unit)) then

		local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
		if dead and not (issecretvalue and issecretvalue(dead)) then return false end
		return true
	end
	if not Plain(UnitCanAttack("player", unit)) then return false end
	return HasCreatureType(unit)
end

local function ApplyHealthBar(tip, unit)
	if not ShouldShowHealthBar(unit) then
		HideHealthBar(tip)
		return
	end

	local cur, max = GetHealthValues(unit)
	if not cur then
		HideHealthBar(tip)
		return
	end

	local bar = EnsureHealthBar(tip)

	ReservePaddingForBar(tip)

	local okMM = pcall(bar.SetMinMaxValues, bar, 0, max)
	local okVal = pcall(bar.SetValue, bar, cur)
	if not okMM or not okVal then

		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
	end

	if Plain(UnitIsDeadOrGhost(unit)) then
		bar:SetStatusBarColor(0.5, 0.1, 0.1)
		bar.text:SetText(DEAD or "Dead")
	else
		bar:SetStatusBarColor(0.1, 0.8, 0.1)

		local okCur, curText = pcall(string.format, "%d", cur)
		local okMax, maxText = pcall(string.format, "%d", max)

		local curShown, maxShown = "?", "?"
		if okCur then curShown = curText end
		if okMax then maxShown = maxText end
		bar.text:SetText(curShown .. " / " .. maxShown)
	end
	bar:Show()
end

local function OnUnitContentAllowed(tip)
	MarkAllowed(tip)
	if not IsTouchable(tip) then return end

	local unit
	if tip.GetUnit then
		local _, unitId = tip:GetUnit()
		unit = unitId
	end
	if not unit or (issecretvalue and issecretvalue(unit)) or not Plain(UnitExists(unit)) then

		HideHealthBar(tip)
		return
	end

	local tipName = tip.GetName and tip:GetName()
	local first = tipName and _G[tipName .. "TextLeft1"]
	local firstText = first and first:GetText()
	if type(firstText) == "string" and not (issecretvalue and issecretvalue(firstText))
		and firstText:lower():find("^corpse of") then
		HideHealthBar(tip)
		FitTooltipToText(tip)
		return
	end

	ColorNameLine(tip, unit)
	ApplyGuildLine(tip, unit)
	ApplyClassOnLevelLine(tip, unit)
	ApplySpecLine(tip, unit)
	ApplyHealthBar(tip, unit)
	EnsureTooltipWidth(tip)

	if IsGrowRightActive() and IsAllowedContent(tip) then
		ForcePosition(tip)
	end
end

local dataTypesRegistered = {}
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	local function register(names, handler)
		for _, typeName in ipairs(names) do
			local dataType = Enum.TooltipDataType[typeName]
			if dataType ~= nil and pcall(TooltipDataProcessor.AddTooltipPostCall, dataType, handler) then
				table.insert(dataTypesRegistered, typeName)
			end
		end
	end
	register({ "Unit" }, OnUnitContentAllowed)
	register({ "Spell" }, OnContentAllowed)

	register(DENIED_DATA_TYPES, OnItemContent)
	register({ "Macro", "Toy", "Mount" }, OnActionBarOnlyContent)

	register({ "Object" }, OnObjectContent)
end

local LEGACY_CONTENT_SCRIPTS = {
	{ "OnTooltipSetUnit",  OnUnitContentAllowed },
	{ "OnTooltipSetSpell", OnContentAllowed },
	{ "OnTooltipSetItem",  OnItemContent },
}

local DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y = "CENTER", "CENTER", 0, 0

local function GetAnchorPos()
	local pos = KUI.db and KUI.db.tooltipAnchorPos
	if not pos then
		return DEFAULT_POINT, DEFAULT_REL_POINT, DEFAULT_X, DEFAULT_Y
	end
	local point = pos.point or DEFAULT_POINT
	return point, pos.relPoint or point, pos.x or 0, pos.y or 0
end

local function EnsureAnchorFrame()
	if anchorFrame then return anchorFrame end

	local f = CreateFrame("Button", "KainUIForeverTooltipAnchor", UIParent, "BackdropTemplate")
	f:SetSize(18, 18)
	f:SetFrameStrata("TOOLTIP")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(false)
	f:RegisterForDrag("LeftButton")

	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		f:SetBackdropColor(0.2, 0.6, 1, 0.85)
		f:SetBackdropBorderColor(1, 1, 1, 0.9)
	end

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("BOTTOM", f, "TOP", 0, 4)
	label:SetText("Tooltip anchor -- drag me")
	f.label = label

	f:SetScript("OnDragStart", function(self)
		self:StartMoving()
		if KUI.BeginAlignDrag then KUI:BeginAlignDrag(self) end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if KUI.EndAlignDrag then KUI:EndAlignDrag(self) end
		if not KUI.db then return end

		local point, _, relPoint, x, y = self:GetPoint(1)
		point = point or DEFAULT_POINT
		KUI.db.tooltipAnchorPos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
		KUI:PositionAllTooltips()
	end)

	local point, relPoint, x, y = GetAnchorPos()
	f:SetPoint(point, UIParent, relPoint, x, y)
	f:Hide()

	anchorFrame = f
	return f
end

local function ApplyPoints(tip)

	if tip.GetAnchorType and tip.SetAnchorType then
		local anchorType = tip:GetAnchorType()
		if anchorType and anchorType ~= "ANCHOR_NONE" then
			pcall(tip.SetAnchorType, tip, "ANCHOR_NONE")
		end
	end

	if tip.SetClampedToScreen then
		pcall(tip.SetClampedToScreen, tip, true)
	end

	local point = "TOPLEFT"
	local _, anchorY = anchorFrame:GetCenter()
	local _, screenMidY = UIParent:GetCenter()
	if anchorY and screenMidY then
		anchorY = anchorY * anchorFrame:GetEffectiveScale()
		screenMidY = screenMidY * UIParent:GetEffectiveScale()
		if anchorY < screenMidY then point = "BOTTOMLEFT" end
	end
	tip:ClearAllPoints()
	tip:SetPoint(point, anchorFrame, point, 0, 0)
end

function ForcePosition(tip)

	local okO, owner = pcall(function() return tip:GetOwner() end)
	if okO and owner and IsInsideCursorTooltipWindow(owner) then
		tip:ClearAllPoints()
		pcall(tip.SetAnchorType, tip, "ANCHOR_CURSOR")
		return
	end
	if not anchorFrame or applying[tip] or not IsTouchable(tip) then return end
	applying[tip] = true
	local ok, err = pcall(ApplyPoints, tip)
	applying[tip] = nil
	if not ok then lastForceError = err end

	if RefreshTooltipSize then RefreshTooltipSize(tip) end
end

do
	local nativeBar = _G.GameTooltipStatusBar or (GameTooltip and GameTooltip.StatusBar)
	if nativeBar and nativeBar.SetAlpha then nativeBar:SetAlpha(0) end
end

local function DropExtraAnchors(tip)
	if applying[tip] or not anchorFrame or not IsGrowRightActive() then return false end
	if not IsTouchable(tip) or not tip.GetNumPoints then return false end
	if tip.IsAnchoringSecret and tip:IsAnchoringSecret() then return false end
	local count = tip:GetNumPoints()
	if IsSecret(count) or count < 2 then return false end
	local point, rel, relPoint, x, y = tip:GetPoint(1)
	if IsSecret(point) or IsSecret(rel) or IsSecret(relPoint) or IsSecret(x) or IsSecret(y) then return false end
	if rel ~= anchorFrame then return false end
	applying[tip] = true
	tip:ClearAllPoints()
	tip:SetPoint(point, rel, relPoint, x, y)
	applying[tip] = nil
	return true
end

local hookedDefaultAnchor = false

local function HookTooltip(name)
	if hooked[name] then return true end
	local tip = _G[name]
	if type(tip) ~= "table" and type(tip) ~= "userdata" then return false end
	if not tip.SetPoint or not tip.HookScript then return false end

	tracked[tip] = true

	if not hookedDefaultAnchor and type(GameTooltip_SetDefaultAnchor) == "function" then
		hookedDefaultAnchor = true
		hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
			if not (tooltip and tracked[tooltip] and IsGrowRightActive()) then return end
			if IsAllowedContent(tooltip) then
				ForcePosition(tooltip)
				return
			end

			if parent and parent == _G.MainMenuMicroButton then
				tooltip:ClearAllPoints()
				pcall(tooltip.SetAnchorType, tooltip, "ANCHOR_RIGHT")
				return
			end

			if IsInsideCursorTooltipWindow(parent) then
				tooltip:ClearAllPoints()
				pcall(tooltip.SetAnchorType, tooltip, "ANCHOR_CURSOR")
				return
			end

		end)
	end

	tip:HookScript("OnShow", function(self)

		UpdateTrainerIconGate(self)
		if IsGrowRightActive() and IsAllowedContent(self) then
			ForcePosition(self)
		else

			local okO, owner = pcall(function() return self:GetOwner() end)
			if IsGrowRightActive() and okO and owner and IsInsideCursorTooltipWindow(owner) then
				self:ClearAllPoints()
				pcall(self.SetAnchorType, self, "ANCHOR_CURSOR")
				return
			end

			OnWorldObjectContent(self)
			if IsGrowRightActive() and IsAllowedContent(self) then ForcePosition(self) end
		end
	end)

	pcall(hooksecurefunc, tip, "SetPoint", function(self)
		if DropExtraAnchors(self) then instantAnchorFixes = instantAnchorFixes + 1 end
	end)

	tip:HookScript("OnUpdate", function(self)
		if DropExtraAnchors(self) then extraAnchorFixes = extraAnchorFixes + 1 end
		UpdateTrainerIconGate(self)
	end)

	for _, entry in ipairs(LEGACY_CONTENT_SCRIPTS) do
		local script, handler = entry[1], entry[2]
		if not tip.HasScript or tip:HasScript(script) then
			pcall(tip.HookScript, tip, script, handler)
		end
	end

	tip:HookScript("OnHide", function(self)
		MarkDenied(self)
		RestoreCompareTooltips()
		UpdateTrainerIconGate(self)
	end)

	if not tip.HasScript or tip:HasScript("OnTooltipCleared") then
		pcall(tip.HookScript, tip, "OnTooltipCleared", function(self)

			allowedContent[self] = false

			RestoreCompareTooltips()

			UpdateTrainerIconGate(self)

			if self.SetMinimumWidth then pcall(self.SetMinimumWidth, self, 0) end
			HideHealthBar(self)
		end)
	end

	hooked[name] = true
	return true
end

function KUI:PositionAllTooltips()
	if not anchorFrame then return end
	local point, relPoint, x, y = GetAnchorPos()
	anchorFrame:ClearAllPoints()
	anchorFrame:SetPoint(point, UIParent, relPoint, x, y)

	if not IsGrowRightActive() then return end
	for _, name in ipairs(TOOLTIP_FRAMES) do
		local tip = _G[name]
		if tip and tracked[tip] and IsTouchable(tip) and tip:IsShown() and IsAllowedContent(tip) then
			ForcePosition(tip)
		end
	end
end

function KUI:ApplyTooltipAnchor()
	if not KUI.db then return end
	ResetScan()
	EnsureAnchorFrame()

	local mode = KUI.db.tooltipAnchorMode == "growRight" and "growRight" or "default"
	KUI.db.tooltipAnchorMode = mode
	Note("mode: %s", mode == "growRight" and "Grow Right (static left edge)" or "Default (Blizzard) behavior")
	if #dataTypesRegistered > 0 then
		Note("content detection: TooltipDataProcessor (%s) + any classic OnTooltipSet* scripts the frame has",
			table.concat(dataTypesRegistered, ", "))
	else
		Note("content detection: classic OnTooltipSet* scripts only (no TooltipDataProcessor)")
	end

	for _, name in ipairs(TOOLTIP_FRAMES) do
		local ok = HookTooltip(name)
		if ok then
			Note("%s: hooked", name)
		else
			Note("%s: not found on this client yet (fine -- some only load on first use)", name)
		end
	end

	local point, relPoint, x, y = GetAnchorPos()
	Note("anchor: %s to UIParent %s, offset (%.0f, %.0f), %s", point, relPoint, x, y,
		KUI.db.tooltipAnchorLocked and "locked" or "UNLOCKED -- drag the blue square on screen")

	local unlocked = (mode == "growRight") and not KUI.db.tooltipAnchorLocked
	if anchorFrame then
		anchorFrame:EnableMouse(unlocked)
		if unlocked then anchorFrame:Show() else anchorFrame:Hide() end
	end

	KUI:PositionAllTooltips()
end

function KUI:SetTooltipAnchorMode(mode)
	if not KUI.db then return end
	KUI.db.tooltipAnchorMode = (mode == "growRight") and "growRight" or "default"
	KUI:ApplyTooltipAnchor()
end

function KUI:SetTooltipAnchorLocked(locked)
	if not KUI.db then return end
	KUI.db.tooltipAnchorLocked = locked and true or false
	KUI:ApplyTooltipAnchor()
end

function KUI:ResetTooltipAnchorPosition()
	if not KUI.db then return end
	KUI.db.tooltipAnchorPos = nil
	KUI:ApplyTooltipAnchor()
	print("|cff33ff99Kain-UI Forever|r tooltip anchor position reset.")
end

local loadFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(loadFrame, "ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if loadedAddonName == addonName then return end
	if not KUI.db then return end
	for _, name in ipairs(TOOLTIP_FRAMES) do
		if not hooked[name] and _G[name] then
			KUI:ApplyTooltipAnchor()
			break
		end
	end
end)

if type(GameTooltip_CalculatePadding) == "function" then
	hooksecurefunc("GameTooltip_CalculatePadding", function(tip)
		if not barPadding[tip] or not IsTouchable(tip) then return end
		local bar = healthBars[tip]
		if bar and bar:IsShown() then
			SetBottomPadding(tip, BAR_RESERVE)
		end
	end)
end

local ProbeTreeLayout
local function ProbeValue(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do
			if #parts >= 12 then table.insert(parts, "...") break end
			table.insert(parts, tostring(k) .. "=" .. tostring(x))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function ProbeCall(label, fn, ...)
	if type(fn) ~= "function" then
		print("  " .. label .. ": (missing)")
		return
	end
	local results = { pcall(fn, ...) }
	if not results[1] then
		print("  " .. label .. ": ERROR " .. tostring(results[2]))
		return
	end
	local out = {}
	for i = 2, math.max(2, #results) do out[#out + 1] = ProbeValue(results[i]) end
	print("  " .. label .. ": " .. table.concat(out, ", "))
	return select(2, unpack(results))
end

local function ProbeNamespace(name)
	local ns = _G[name]
	if type(ns) ~= "table" then
		print("  " .. name .. ": (missing)")
		return
	end
	local keys = {}
	for k, v in pairs(ns) do
		if type(v) == "function" then keys[#keys + 1] = k end
	end
	table.sort(keys)
	print("  " .. name .. " (" .. #keys .. "): " .. table.concat(keys, ", "))
end

local function NodeSpellName(configID, info)
	local traits = C_Traits
	local entryID = info.activeEntry and info.activeEntry.entryID or (info.entryIDs and info.entryIDs[1])
	if not entryID or not traits.GetEntryInfo or not traits.GetDefinitionInfo then return "?" end
	local okE, entry = pcall(traits.GetEntryInfo, configID, entryID)
	local defID = okE and entry and entry.definitionID

	local okD, def = false, nil
	if defID then okD, def = pcall(traits.GetDefinitionInfo, defID) end
	local spellID = okD and def and (def.spellID or def.overriddenSpellID)
	if not spellID then return "?" end
	local spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID))
		or (GetSpellInfo and GetSpellInfo(spellID))
	return tostring(spellName or spellID)
end

function ProbeTreeLayout(configID, treeID)
	local traits = C_Traits
	if not traits.GetTreeNodes or not traits.GetNodeInfo then
		print("    tree layout: GetTreeNodes/GetNodeInfo missing")
		return
	end
	local okN, nodes = pcall(traits.GetTreeNodes, treeID)
	if not okN or type(nodes) ~= "table" then
		print("    tree layout: GetTreeNodes failed")
		return
	end
	local columns, subTrees, spentNodes, visible = {}, {}, {}, 0
	for _, nodeID in ipairs(nodes) do
		local okI, info = pcall(traits.GetNodeInfo, configID, nodeID)
		if okI and info and info.ID and info.ID ~= 0 and info.isVisible ~= false then
			visible = visible + 1
			local x = info.posX or -1
			local col = columns[x] or { nodes = 0, spent = 0 }
			columns[x] = col
			col.nodes = col.nodes + 1
			col.spent = col.spent + (info.activeRank or info.currentRank or 0)
			local st = tostring(info.subTreeID or "none")
			subTrees[st] = (subTrees[st] or 0) + 1
			if (info.activeRank or 0) > 0 then
				spentNodes[#spentNodes + 1] = format("x=%s y=%s rank=%s %s", tostring(info.posX), tostring(info.posY),
					tostring(info.activeRank), NodeSpellName(configID, info))
			end
		end
	end
	print(format("    tree %s: %d nodes (%d visible)", tostring(treeID), #nodes, visible))
	local xs = {}
	for x in pairs(columns) do xs[#xs + 1] = x end
	table.sort(xs)
	local parts = {}
	for _, x in ipairs(xs) do parts[#parts + 1] = format("%s:%d/%d", tostring(x), columns[x].nodes, columns[x].spent) end
	print("    columns x:nodes/spent -> " .. table.concat(parts, "  "))
	local stParts = {}
	for st, n in pairs(subTrees) do stParts[#stParts + 1] = st .. "=" .. n end
	print("    subTreeIDs: " .. table.concat(stParts, ", "))
	for _, line in ipairs(spentNodes) do print("    spent: " .. line) end
end

SLASH_KUISPECPROBE1 = "/kuispec"
SlashCmdList.KUISPECPROBE = function()
	if not (KUI.IsDevMode and KUI:IsDevMode()) then
		print("|cff33ff99Kain-UI Forever|r unknown command. Type |cffffff00/kui help|r for the list of commands.")
		return
	end
	print("|cff33ff99Kain-UI Forever|r talent API probe:")
	for _, n in ipairs({ "GetNumTalentTabs", "GetTalentTabInfo", "GetActiveTalentGroup",
		"GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoByID",
		"GetInspectSpecialization", "GetNumSpecializations", "GetSpecializationRole",
		"CanInspect", "NotifyInspect", "ClearInspectPlayer", "GetTalentInfo", "GetNumTalents" }) do
		print("  " .. n .. ": " .. (type(_G[n]) == "function" and "yes" or "no"))
	end
	ProbeNamespace("C_SpecializationInfo")
	ProbeNamespace("C_ClassTalents")
	ProbeNamespace("C_Talent")
	ProbeNamespace("C_TalentTree")
	local traits = _G.C_Traits
	print("  C_Traits: " .. (type(traits) == "table" and "present" or "(missing)"))

	print(" your own spec:")
	local idx = ProbeCall("GetSpecialization()", _G.GetSpecialization)
	if idx then ProbeCall("GetSpecializationInfo(" .. tostring(idx) .. ")", _G.GetSpecializationInfo, idx) end
	local csi = _G.C_SpecializationInfo
	if csi then
		local cidx = ProbeCall("C_SpecializationInfo.GetSpecialization()", csi.GetSpecialization)
		if cidx then ProbeCall("C_SpecializationInfo.GetSpecializationInfo(" .. tostring(cidx) .. ")", csi.GetSpecializationInfo, cidx) end
	end
	local configID
	if _G.C_ClassTalents then
		configID = ProbeCall("C_ClassTalents.GetActiveConfigID()", C_ClassTalents.GetActiveConfigID)
	end
	if configID and traits then
		local info = ProbeCall("C_Traits.GetConfigInfo", traits.GetConfigInfo, configID)
		local treeID = info and info.treeIDs and info.treeIDs[1]
		if treeID then
			local currencies = ProbeCall("C_Traits.GetTreeCurrencyInfo", traits.GetTreeCurrencyInfo, configID, treeID, false)
			for i, c in ipairs(currencies or {}) do print("    currency " .. i .. ": " .. ProbeValue(c)) end
			ProbeTreeLayout(configID, treeID)
		end
	end
	ProbeCall("GetNumTalentTabs()", _G.GetNumTalentTabs)
	ProbeCall("GetTalentTabInfo(1)", _G.GetTalentTabInfo, 1)

	if Plain(UnitExists("target")) and Plain(UnitIsPlayer("target")) and Plain(UnitIsUnit("target", "player")) == false then
		print(" target (" .. tostring(UnitName("target")) .. "):")
		ProbeCall("CanInspect(target)", _G.CanInspect, "target", false)
		ProbeCall("GetInspectSpecialization(target)", _G.GetInspectSpecialization, "target")
		if traits then
			local valid = ProbeCall("C_Traits.HasValidInspectData()", traits.HasValidInspectData)
			if valid then
				local info = ProbeCall("C_Traits.GetConfigInfo(inspect)", traits.GetConfigInfo, INSPECT_CONFIG_ID)
				local treeID = info and info.treeIDs and info.treeIDs[1]
				if treeID then
					local currencies = ProbeCall("GetTreeCurrencyInfo(inspect)", traits.GetTreeCurrencyInfo, INSPECT_CONFIG_ID, treeID, false)
					for i, c in ipairs(currencies or {}) do print("    currency " .. i .. ": " .. ProbeValue(c)) end
					ProbeTreeLayout(INSPECT_CONFIG_ID, treeID)
				end
			else
				print("  (no inspect data held right now -- mouse over them first, then run this again)")
			end
		end
		print("  tooltip spec cache for target: " .. ProbeValue(specCache[SafeGUID("target")] and specCache[SafeGUID("target")].spec))
	else
		print(" (target another player within ~28 yd and run again to test inspecting)")
	end
end
