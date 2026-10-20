local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local BAR_TEXTURE = MEDIA .. "KainedBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local LOOK = {
	font = "Fonts\\ARIALN.TTF",
	fontSize = 12,
	shadow = 1.5,
	inset = 3,
	clip = 4,
	gap = 1.25,
	barAlpha = 1,
	bgAlpha = 0.2,
	panel = { 0, 0, 0, 0.8 },
	portraitWidth = 0.22,
	portraitCutoff = 50,
	auraSize = 16,
	auraSpacing = 2,
	xpHeight = 5,
	xpRestedAlpha = 0.45,
}

local function RGB(r, g, b) return { r, g, b } end
local COLORS = {
	health = {
		friendly = RGB(0.2, 0.9, 0.2), neutral = RGB(0.93, 0.93, 0), hostile = RGB(0.9, 0, 0),
		tapped = RGB(0.5, 0.5, 0.5), offline = RGB(0.5, 0.5, 0.5), enemyUnattack = RGB(0.6, 0.2, 0.2),
	},
	class = {
		DEATHKNIGHT = RGB(0.77, 0.12, 0.23), DEMONHUNTER = RGB(0.64, 0.19, 0.79), DRUID = RGB(1, 0.49, 0.04),
		EVOKER = RGB(0.2, 0.58, 0.5), HUNTER = RGB(0.67, 0.83, 0.45), MAGE = RGB(0.41, 0.8, 0.94),
		MONK = RGB(0, 1, 0.59), PALADIN = RGB(0.96, 0.55, 0.73), PET = RGB(0.2, 0.9, 0.2),
		PRIEST = RGB(1, 1, 1), ROGUE = RGB(1, 0.96, 0.41), SHAMAN = RGB(0.14, 0.35, 1),
		WARLOCK = RGB(0.58, 0.51, 0.79), WARRIOR = RGB(0.78, 0.61, 0.43),
	},
	power = {
		MANA = RGB(0.3, 0.5, 0.85), RAGE = RGB(0.9, 0.2, 0.3), FOCUS = RGB(1, 0.5, 0.25), ENERGY = RGB(1, 0.85, 0.1),
		RUNIC_POWER = RGB(0.35, 0.45, 0.6), LUNAR_POWER = RGB(0.3, 0.52, 0.9), INSANITY = RGB(0.4, 0, 0.8),
		MAELSTROM = RGB(0, 0.5, 1), FURY = RGB(0.788, 0.259, 0.992), PAIN = RGB(1, 0, 0), FUEL = RGB(0.85, 0.47, 0.36),
		AMMOSLOT = RGB(0.85, 0.6, 0.55), COMBOPOINTS = RGB(1, 0.8, 0),
	},
}

local IND = {
	raid = { "CENTER", "CENTER", 0, 0, 20 },
	leader = { "BOTTOMLEFT", "TOPLEFT", 2, -12, 14 },
	pvp = { "BOTTOMRIGHT", "TOPRIGHT", 11, -21, 22 },
	status = { "BOTTOMRIGHT", "BOTTOMLEFT", 12, -2, 16 },
	ready = { "RIGHT", "LEFT", 35, 0, 24 },
	happy = { "BOTTOMRIGHT", "TOPRIGHT", -6, -2, 34 },
}

local UNITS = {
	{ key = "player", unit = "player", width = 190, height = 45, scale = 1.01,
		point = { "CENTER", "CENTER", -132.72284444348, -97.872558822901 },
		portrait = "LEFT", health = 1.2, power = 1.0,
		texts = { hl = "nameGroup", hr = "curmaxhpPerhp", pl = "perpp", pr = "curmaxpp" },
		fader = true, combo = true, druidMana = true,
		indicators = { "raid", "leader", "pvp", "status", "ready" },
		auras = {
			{ filter = "HELPFUL", side = "LEFT", below = true, max = 5, cancel = true },
			{ filter = "HARMFUL", side = "RIGHT", below = true, max = 5 },
		} },
	{ key = "pet", unit = "pet", width = 173, height = 30, scale = 1,
		point = { "BOTTOM", "BOTTOM", 282.56642928212, -1.5329070877259 },
		health = 1.2, power = 0.7, petColor = true,
		texts = { hl = "name", hr = "curmaxhp", pl = "perpp", pr = "curmaxpp" },
		indicators = { "raid", "happy" } },
	{ key = "target", unit = "target", width = 190, height = 45, scale = 1.01,
		point = { "CENTER", "CENTER", 133.05492569986, -98.583207440859 },
		portrait = "RIGHT", health = 1.2, power = 1.0,
		texts = { hl = "name", hr = "curmaxhpPerhp", pl = "levelClassPerpp", pr = "curmaxpp" },
		indicators = { "raid", "leader", "pvp" },
		auras = {
			{ filter = "HELPFUL", side = "LEFT", below = false, max = 10 },
			{ filter = "HARMFUL", side = "LEFT", below = true, max = 10 },
		} },
	{ key = "targettarget", unit = "targettarget", width = 110, height = 30, scale = 1,
		point = { "CENTER", "CENTER", 264.16663728908, -107.50001622571 },
		health = 1.2, power = 0.6, poll = true,
		texts = { hl = "name", hr = "curhp", pl = "perpp", pr = "curpp" },
		indicators = { "raid" } },
	{ key = "focus", unit = "focus", width = 120, height = 28, scale = 1,
		point = { "CENTER", "CENTER", -268.38925985789, -106.27775978836 },
		health = 1.2, power = 0.6,
		texts = { hl = "name", hr = "curhp", pl = "perpp", pr = "curpp" },
		indicators = { "raid", "leader", "pvp" } },
	{ key = "focustarget", unit = "focustarget", width = 120, height = 25, scale = 1,
		point = { "CENTER", "CENTER", -269.10062458513, -129.36109886802 },
		health = 1.2, power = 0.6, poll = true,
		texts = { hl = "name", hr = "curhp" },
		indicators = { "raid" } },
}

local PARTY = { width = 190, height = 45, scale = 1, spacing = 23,
	point = { "TOPLEFT", "BOTTOMLEFT", 2.2222807057094, 477.80001175668 },
	portrait = "LEFT", health = 1.2, power = 1.0,
	texts = { hl = "name", hr = "curmaxhpPerhp", pl = "levelPerpp", pr = "curmaxpp" },
	indicators = { "raid", "leader", "pvp", "ready" },
	auras = {
		{ filter = "HELPFUL", side = "LEFT", below = true, max = 5 },
		{ filter = "HARMFUL", side = "RIGHT", below = true, max = 5 },
	} }
for i = 1, 4 do
	local spec = {}
	for k, v in pairs(PARTY) do spec[k] = v end
	spec.key, spec.unit, spec.party = "party" .. i, "party" .. i, i
	UNITS[#UNITS + 1] = spec
end

local ORDER = { health = 10, power = 20, combo = 60, druid = 70 }
local EXTRA_WEIGHT = 0.4
local POLL = 0.2
local POWER = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBO = 4 }

local frames = {}
local holder
local built = false
local pending = false
local tookBlizzard = false
local hiddenParent
local hiddenBlizzard = {}
local hookedCompact = false
local errorShown = false
local aurasAvailable

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Yes(v) return Plain(v) and v == true end
local function PlainNumber(v) return Plain(v) and type(v) == "number" end

local function Enabled()
	return KUI.db and KUI.db.kainedFrames == true
end

local function Showing()
	return built and (Enabled() or tookBlizzard)
end

local function Report(err)
	if errorShown then return end
	errorShown = true
	print("|cffff6060Kain-UI Forever:|r Kained Unit Frames hit an error and will stay quiet about it: " .. tostring(err))
end

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then Report(err) end
	return ok
end

local function Short(n)
	if type(AbbreviateNumbers) == "function" then
		local ok, s = pcall(AbbreviateNumbers, n)
		if ok and type(s) ~= "nil" then return s end
	end
	if PlainNumber(n) then
		if n >= 1000000 then return string.format("%.1fM", math.floor(n / 100000) / 10) end
		if n >= 1000 then return string.format("%.1fK", math.floor(n / 100) / 10) end
		return string.format("%d", n)
	end
	return n
end

local function ScaleTo100()
	return type(CurveConstants) == "table" and CurveConstants.ScaleTo100 or 100
end

local function HealthPercent(unit)
	if type(UnitHealthPercent) == "function" then
		local ok, pct = pcall(UnitHealthPercent, unit, true, ScaleTo100())
		if ok and type(pct) == "number" then return string.format("%d%%", pct) end
	end
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	if PlainNumber(cur) and PlainNumber(max) and max > 0 then return string.format("%d%%", math.floor(cur / max * 100 + 0.5)) end
	return ""
end

local function PowerPercent(unit, ptype)
	if type(UnitPowerPercent) == "function" then
		local ok, pct = pcall(UnitPowerPercent, unit, ptype, true, ScaleTo100())
		if ok and type(pct) == "number" then return string.format("%d%%", pct) end
	end
	local cur, max = UnitPower(unit, ptype), UnitPowerMax(unit, ptype)
	if PlainNumber(cur) and PlainNumber(max) then
		if max > 0 then return string.format("%d%%", math.floor(cur / max * 100 + 0.5)) end
		return "0%"
	end
	return ""
end

local function DeadText(unit)
	local connected = UnitIsConnected(unit)
	if Plain(connected) and connected == false then return "Offline" end
	local ghost = UnitIsGhost and UnitIsGhost(unit)
	if Yes(ghost) then return "Ghost" end
	if Yes(UnitIsDead and UnitIsDead(unit)) then return "Dead" end
	if Yes(UnitIsDeadOrGhost(unit)) then return "Dead" end
	return nil
end

local function Text(v)
	if type(v) == "string" or type(v) == "number" then return v end
	return ""
end

local function PowerType(unit)
	local ok, ptype, token = pcall(UnitPowerType, unit)
	if not ok then return POWER.MANA, "MANA" end
	return ptype, token
end

local function AfkPrefix(unit)
	local afk = UnitIsAFK and UnitIsAFK(unit)
	if Yes(afk) then return "(AFK) " end
	local dnd = UnitIsDND and UnitIsDND(unit)
	if Yes(dnd) then return "(DND) " end
	return ""
end

local function GroupSuffix(unit)
	local index = UnitInRaid and UnitInRaid(unit)
	if not PlainNumber(index) or type(GetRaidRosterInfo) ~= "function" then return "" end
	local group = select(3, GetRaidRosterInfo(index))
	if PlainNumber(group) then return " (" .. group .. ")" end
	return ""
end

local CLASSIFICATION = { rare = "Rare", rareelite = "Rare Elite", elite = "Elite", worldboss = "Boss", minus = "Minion" }

local function LevelText(unit)
	local level = UnitLevel(unit)
	if not PlainNumber(level) then return Text(level), " " end
	if level > 0 then return tostring(level), " " end
	local class = UnitClassification(unit)
	if Plain(class) and class == "worldboss" then return "", "" end
	return "??", " "
end
local function ClassText(unit)
	local class = UnitClassification(unit)
	if not Plain(class) or type(class) ~= "string" then return "" end
	return CLASSIFICATION[class] or ""
end

local TEXT = {}

local function FullName(unit)
	if type(GetUnitName) == "function" then
		local ok, name = pcall(GetUnitName, unit, true)
		if ok and type(name) == "string" then return name end
	end
	return Text(UnitName(unit))
end
TEXT.name = function(fs, unit)
	fs:SetFormattedText("%s%s", AfkPrefix(unit), FullName(unit))
end
TEXT.nameGroup = function(fs, unit)
	fs:SetFormattedText("%s%s%s", AfkPrefix(unit), FullName(unit), GroupSuffix(unit))
end
TEXT.curhp = function(fs, unit)
	local dead = DeadText(unit)
	if dead then fs:SetText(dead) return end
	fs:SetFormattedText("%s", Short(UnitHealth(unit)))
end
TEXT.curmaxhp = function(fs, unit)
	local dead = DeadText(unit)
	if dead then fs:SetText(dead) return end
	fs:SetFormattedText("%s/%s", Short(UnitHealth(unit)), Short(UnitHealthMax(unit)))
end
TEXT.curmaxhpPerhp = function(fs, unit)
	local dead = DeadText(unit)
	if dead then fs:SetText(dead) return end
	fs:SetFormattedText("%s/%s %s", Short(UnitHealth(unit)), Short(UnitHealthMax(unit)), HealthPercent(unit))
end
local function NoPower(unit, ptype)
	local max = UnitPowerMax(unit, ptype)
	return PlainNumber(max) and max <= 0
end
TEXT.perpp = function(fs, unit)
	local ptype = PowerType(unit)
	if DeadText(unit) then fs:SetText("0%") return end
	fs:SetFormattedText("%s", PowerPercent(unit, ptype))
end
TEXT.curpp = function(fs, unit)
	local ptype = PowerType(unit)
	if DeadText(unit) then fs:SetText("0") return end
	fs:SetFormattedText("%s", Short(UnitPower(unit, ptype)))
end
TEXT.curmaxpp = function(fs, unit)
	local ptype = PowerType(unit)
	if NoPower(unit, ptype) then fs:SetText("") return end
	if DeadText(unit) then fs:SetFormattedText("0/%s", Short(UnitPowerMax(unit, ptype))) return end
	fs:SetFormattedText("%s/%s", Short(UnitPower(unit, ptype)), Short(UnitPowerMax(unit, ptype)))
end

TEXT.levelClassPerpp = function(fs, unit)
	local level, space = LevelText(unit)
	local class = ClassText(unit)
	local ptype = PowerType(unit)
	local pct = DeadText(unit) and "0%" or PowerPercent(unit, ptype)
	fs:SetFormattedText("%s%s%s%s%s", level, space, class, class ~= "" and " " or "", pct)
end

TEXT.levelPerpp = function(fs, unit)
	local level, space = LevelText(unit)
	local ptype = PowerType(unit)
	local pct = DeadText(unit) and "0%" or PowerPercent(unit, ptype)
	fs:SetFormattedText("%s%s%s", level, space, pct)
end

local function Tint(bar, r, g, b)
	bar:GetStatusBarTexture():SetVertexColor(r, g, b, LOOK.barAlpha)
	bar.bg:SetVertexColor(r, g, b, LOOK.bgAlpha)
end
local function TintColor(bar, c) Tint(bar, c[1], c[2], c[3]) end

local function ClassTint(bar, unit)
	local _, class = UnitClass(unit)
	if Plain(class) then
		local c = type(class) == "string" and COLORS.class[class]
		if c then TintColor(bar, c) return true end
		return false
	end
	if C_ClassColor and C_ClassColor.GetClassColor then
		local ok, color = pcall(C_ClassColor.GetClassColor, class)
		if ok and color and color.GetRGB then
			Tint(bar, color:GetRGB())
			return true
		end
	end
	return false
end

local function ReactionTint(bar, unit)
	local reaction = UnitReaction(unit, "player")
	if PlainNumber(reaction) then
		TintColor(bar, reaction > 4 and COLORS.health.friendly or reaction == 4 and COLORS.health.neutral or COLORS.health.hostile)
		return
	end
	if type(UnitSelectionColor) == "function" then
		local ok, r, g, b = pcall(UnitSelectionColor, unit)
		if ok and type(r) == "number" then Tint(bar, r, g, b) return end
	end
	TintColor(bar, COLORS.health.hostile)
end

local function InGroup(unit)
	return Yes(UnitPlayerOrPetInParty and UnitPlayerOrPetInParty(unit)) or Yes(UnitPlayerOrPetInRaid and UnitPlayerOrPetInRaid(unit))
end

local function UpdateHealthColor(f)
	local unit, bar = f.unit, f.health
	local connected = UnitIsConnected(unit)
	if Plain(connected) and connected == false then TintColor(bar, COLORS.health.offline) return end
	if f.spec.petColor then TintColor(bar, COLORS.class.PET) return end
	local controlled = UnitPlayerControlled(unit)
	if Plain(controlled) and controlled == false and Yes(UnitIsTapDenied(unit)) and Yes(UnitCanAttack("player", unit)) then
		TintColor(bar, COLORS.health.tapped)
		return
	end
	if Yes(UnitIsPlayer(unit)) or InGroup(unit) then
		if ClassTint(bar, unit) then return end
		TintColor(bar, COLORS.health.friendly)
		return
	end

	ReactionTint(bar, unit)
end

local function UpdatePowerColor(f)
	local _, token = PowerType(f.unit)
	local c = Plain(token) and type(token) == "string" and COLORS.power[token]
	if not c and Plain(token) and type(token) == "string" and type(PowerBarColor) == "table" then
		local pc = PowerBarColor[token]
		if type(pc) == "table" and pc.r then c = { pc.r, pc.g, pc.b } end
	end
	TintColor(f.power, c or COLORS.power.MANA)
end

local function UpdateHealth(f)
	local unit, bar = f.unit, f.health
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	local connected = UnitIsConnected(unit)
	if Plain(connected) and connected == false then
		bar:SetValue(UnitHealthMax(unit))
	elseif DeadText(unit) then
		bar:SetValue(0)
	else
		bar:SetValue(UnitHealth(unit))
	end
end

local function UpdatePower(f)
	local unit, bar = f.unit, f.power
	if not bar then return end
	local ptype = PowerType(unit)
	bar:SetMinMaxValues(0, UnitPowerMax(unit, ptype))
	if DeadText(unit) then bar:SetValue(0) else bar:SetValue(UnitPower(unit, ptype)) end
end

local function UpdateTexts(f)
	for slot, fs in pairs(f.texts) do
		local fn = TEXT[f.spec.texts[slot]]
		if fn then
			local ok = pcall(fn, fs, f.unit)
			if not ok then fs:SetText("") end
		end
	end
end

local function Cover(tex, ratio)
	if ratio >= 1 then
		local half = 0.40 / ratio
		tex:SetTexCoord(0.10, 0.90, 0.50 - half, 0.50 + half)
	else
		local half = 0.40 * ratio
		tex:SetTexCoord(0.50 - half, 0.50 + half, 0.10, 0.90)
	end
end

local function UpdatePortrait(f)
	if not f.portrait then return end
	if type(SetPortraitTexture) == "function" then
		pcall(SetPortraitTexture, f.portrait, f.unit)
	end
	if f.portraitRatio then Cover(f.portrait, f.portraitRatio) end
end

local function Layout(f)
	local spec = f.spec
	local W, H = spec.width, spec.height
	local bars = {
		{ bar = f.health, weight = spec.health, order = ORDER.health },
		{ bar = f.power, weight = spec.power, order = ORDER.power },
	}
	if f.combo and f.combo.wanted then bars[#bars + 1] = { bar = f.combo, weight = EXTRA_WEIGHT, order = ORDER.combo } end
	if f.druid and f.druid.wanted then bars[#bars + 1] = { bar = f.druid, weight = EXTRA_WEIGHT, order = ORDER.druid } end
	if f.combo then f.combo:SetShown(f.combo.wanted and true or false) end
	if f.druid then f.druid:SetShown(f.druid.wanted and true or false) end

	local portraitW = spec.portrait and (math.floor(W * LOOK.portraitWidth) - LOOK.inset) or 0
	local besideX = spec.portrait == "LEFT" and (LOOK.clip + portraitW) or LOOK.clip
	local total = 0
	for _, b in ipairs(bars) do total = total + b.weight end
	local available = H - 2 * LOOK.clip - LOOK.gap * (#bars - 1)
	local y, besideH, hasFull = -LOOK.clip, 0, false
	for _, b in ipairs(bars) do
		local h = available * b.weight / total
		local full = spec.portrait == nil or b.order > LOOK.portraitCutoff
		local x, width
		if full then
			x, width, hasFull = LOOK.clip, W - 2 * LOOK.clip, true
		else
			x, width = besideX, W - portraitW - 2 * LOOK.clip
			besideH = besideH + h
		end
		b.bar:ClearAllPoints()
		b.bar:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		b.bar:SetSize(width, h)
		b.bar.layoutWidth = width
		if b.bar.Segments then b.bar:Segments(width, h) end
		y = y - h - LOOK.gap
	end

	if f.portrait then
		local ph = hasFull and besideH or (H - 2 * LOOK.clip)
		local pw = portraitW - (spec.portrait == "RIGHT" and 1 or 0.5)
		f.portrait:ClearAllPoints()
		if spec.portrait == "LEFT" then
			f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", LOOK.clip, -LOOK.clip)
		else
			f.portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -LOOK.clip, -LOOK.clip)
		end
		f.portrait:SetSize(pw, ph)
		f.portraitRatio = (pw > 0 and ph > 0) and pw / ph or nil
		if f.portraitRatio then Cover(f.portrait, f.portraitRatio) end
	end

	local function Place(fs, bar, side)
		if not fs or not bar then return end
		local width = bar.layoutWidth or 0
		fs:ClearAllPoints()
		if side == "LEFT" then
			fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
			fs:SetWidth(width * 0.5)
		else
			fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
			fs:SetWidth(width * 0.6)
		end
	end
	Place(f.texts.hl, f.health, "LEFT")
	Place(f.texts.hr, f.health, "RIGHT")
	Place(f.texts.pl, f.power, "LEFT")
	Place(f.texts.pr, f.power, "RIGHT")
end

local MAX_COMBO = 7

local function ComboWanted()
	local _, class = UnitClass("player")
	if not Plain(class) then return false end
	if class == "ROGUE" then return true end
	if class == "DRUID" then
		local ptype = PowerType("player")
		return Plain(ptype) and ptype == POWER.ENERGY
	end
	return false
end

local function UpdateCombo(f)
	local combo = f.combo
	if not combo then return false end
	local wanted = ComboWanted()
	local points = UnitPower("player", POWER.COMBO)
	if wanted and PlainNumber(points) and points <= 0 then wanted = false end
	local max = UnitPowerMax("player", POWER.COMBO)
	if not PlainNumber(max) or max < 1 then max = 5 end
	if max > MAX_COMBO then max = MAX_COMBO end
	local changed = (combo.wanted and true or false) ~= wanted or combo.count ~= max
	combo.wanted, combo.count = wanted, max
	for i = 1, MAX_COMBO do
		local seg = combo.segs[i]
		seg:SetShown(i <= max)

		seg:SetMinMaxValues(i - 1, i)
		seg:SetValue(points)
	end
	return changed
end

local function UpdateDruid(f)
	local druid = f.druid
	if not druid then return false end
	local _, class = UnitClass("player")
	local ptype = PowerType("player")
	local wanted = Plain(class) and class == "DRUID" and Plain(ptype) and ptype ~= POWER.MANA
	local changed = (druid.wanted and true or false) ~= (wanted and true or false)
	druid.wanted = wanted and true or false
	if wanted then
		druid:SetMinMaxValues(0, UnitPowerMax("player", POWER.MANA))
		druid:SetValue(UnitPower("player", POWER.MANA))
	end
	return changed
end

local function UpdateExtras(f)
	local a = UpdateCombo(f)
	local b = UpdateDruid(f)
	if a or b then Layout(f) end
end

local function SetIcon(icon, shown, texture, l, r, t, b)
	if not icon then return end
	if not shown then icon:Hide() return end
	icon:SetTexture(texture)
	icon:SetTexCoord(l or 0, r or 1, t or 0, b or 1)
	icon:Show()
end

local INDICATOR = {}
INDICATOR.raid = function(f, icon)
	local index = GetRaidTargetIndex and GetRaidTargetIndex(f.unit)
	if not PlainNumber(index) or index < 1 or index > 8 then icon:Hide() return end
	local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
	SetIcon(icon, true, "Interface\\TargetingFrame\\UI-RaidTargetingIcons", col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
end
INDICATOR.leader = function(f, icon)
	if Yes(UnitIsGroupLeader and UnitIsGroupLeader(f.unit)) then
		SetIcon(icon, true, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
	elseif Yes(UnitIsGroupAssistant and UnitIsGroupAssistant(f.unit)) then
		SetIcon(icon, true, "Interface\\GroupFrame\\UI-Group-AssistantIcon")
	else
		icon:Hide()
	end
end
INDICATOR.pvp = function(f, icon)
	if Yes(UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(f.unit)) then
		SetIcon(icon, true, "Interface\\TargetingFrame\\UI-PVP-FFA", 0, 0.62, 0, 0.62)
		return
	end
	local faction = UnitFactionGroup(f.unit)
	if Yes(UnitIsPVP(f.unit)) and Plain(faction) and (faction == "Alliance" or faction == "Horde") then
		SetIcon(icon, true, "Interface\\TargetingFrame\\UI-PVP-" .. faction, 0, 0.62, 0, 0.62)
	else
		icon:Hide()
	end
end
INDICATOR.status = function(f, icon)
	if Yes(UnitAffectingCombat("player")) then
		SetIcon(icon, true, "Interface\\CharacterFrame\\UI-StateIcon", 0.5, 1, 0, 0.49)
	elseif Yes(IsResting and IsResting()) then
		SetIcon(icon, true, "Interface\\CharacterFrame\\UI-StateIcon", 0, 0.5, 0, 0.421875)
	else
		icon:Hide()
	end
end
local READY = {
	ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
INDICATOR.ready = function(f, icon)
	if f.readyDone then return end
	local status = GetReadyCheckStatus and GetReadyCheckStatus(f.unit)
	local texture = Plain(status) and type(status) == "string" and READY[status]
	SetIcon(icon, texture and true or false, texture)
end
INDICATOR.happy = function(f, icon)
	local _, class = UnitClass("player")
	local happiness = Plain(class) and class == "HUNTER" and GetPetHappiness and GetPetHappiness()
	if not PlainNumber(happiness) or happiness < 1 or happiness > 3 then icon:Hide() return end
	local left = ({ 0.375, 0.1875, 0 })[happiness]
	SetIcon(icon, true, "Interface\\PetPaperDollFrame\\UI-PetHappiness", left, left + 0.1875, 0, 0.359375)
end

local function UpdateIndicators(f, only)
	for name, icon in pairs(f.icons) do
		if not only or only == name then
			local ok = pcall(INDICATOR[name], f, icon)
			if not ok then icon:Hide() end
		end
	end
end

local DEPLETES = { [POWER.MANA] = true, [POWER.ENERGY] = true, [POWER.FOCUS] = true }

local function FadeTo(f, alpha, fast)
	local fade = f.fade
	if fade.target == alpha then return end
	fade.from = fade.target or 1
	fade.target = alpha
	fade.elapsed = 0
	fade.time = fast and 0.15 or (alpha > fade.from and 0.25 or 0.75)
	fade:Show()
end

local previewingNow
local function UpdateFade(f)
	if not f.fade then return end
	if previewingNow and previewingNow() then FadeTo(f, 1) return end
	if InCombatLockdown() or f.fade.casting then FadeTo(f, 1, f.fade.casting) return end
	local unit = f.unit
	local ptype = PowerType(unit)
	local power, powerMax = UnitPower(unit), UnitPowerMax(unit)
	local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
	local active = false
	if Plain(ptype) and DEPLETES[ptype] then
		active = not (PlainNumber(power) and PlainNumber(powerMax)) or power ~= powerMax
	end
	if not active then
		active = not (PlainNumber(health) and PlainNumber(healthMax)) or health ~= healthMax
	end
	if not active then active = Yes(UnitExists("target")) end
	FadeTo(f, active and 1 or 0)
end

local function FadeOnUpdate(fade, elapsed)
	fade.elapsed = fade.elapsed + elapsed
	local f = fade.owner
	if fade.elapsed >= fade.time then
		f:SetAlpha(fade.target)
		fade:Hide()
		return
	end
	f:SetAlpha(fade.from + (fade.target - fade.from) * (fade.elapsed / fade.time))
end

local function AurasAvailable()
	if aurasAvailable == nil then
		if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
		aurasAvailable = type(AnchorUtil) == "table" and type(AnchorUtil.FlowDirection) == "table"
	end
	return aurasAvailable
end

local function InitAuraButton(button, harmful, cancel)
	local size = LOOK.auraSize
	button:SetSize(size, size)
	local edge = button:CreateTexture(nil, "BACKGROUND")
	edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
	edge:SetTexture(WHITE)
	if harmful then edge:SetVertexColor(0.8, 0, 0) else edge:SetVertexColor(0.6, 0.6, 0.6) end
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button:SetIcon(icon)
	if harmful and button.AddDispelTypeTexture then
		local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3
		pcall(button.AddDispelTypeTexture, button, edge, { style = style, showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = true })
	end
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	if cooldown.SetReverse then cooldown:SetReverse(true) end
	if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
	if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
	if button.SetDurationCooldown then pcall(button.SetDurationCooldown, button, cooldown) end
	local stack = button:CreateFontString(nil, "OVERLAY")
	stack:SetFont(LOOK.font, 10, "OUTLINE")
	stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -1)
	stack:SetJustifyH("RIGHT")
	if button.SetApplicationCount then pcall(button.SetApplicationCount, button, stack, {}) end
	if cancel and button.SetCancelAuraButtons then pcall(button.SetCancelAuraButtons, button, "RightButtonUp") end
	if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(true) end
	if button.SetHideTooltipInCombat then pcall(button.SetHideTooltipInCombat, button, false) end
end

local function PlaceAuraRow(f, row)
	local def = row.def
	local inset = LOOK.inset
	local drop = 1
	if f.xpShown then drop = 1 - (LOOK.gap + LOOK.xpHeight) end
	local v = def.below and "TOP" or "BOTTOM"
	local rv = def.below and "BOTTOM" or "TOP"
	local point, rel = v .. def.side, rv .. def.side
	local x = def.side == "LEFT" and inset or -inset
	local y = def.below and drop or -1
	row.container:ClearAllPoints()
	row.container:SetPoint(point, f, rel, x, y)
	if row.container.SetFlowLayoutAnchorPoint then pcall(row.container.SetFlowLayoutAnchorPoint, row.container, point) end
	if row.container.SetFlowLayoutGrowthDirection then
		pcall(row.container.SetFlowLayoutGrowthDirection, row.container,
			AnchorUtil.FlowDirection[def.side == "LEFT" and "Right" or "Left"], AnchorUtil.FlowDirection[def.below and "Down" or "Up"])
	end
	if row.container.SetFlowLayoutMaximumLineSize then
		pcall(row.container.SetFlowLayoutMaximumLineSize, row.container, def.max * (LOOK.auraSize + LOOK.auraSpacing) + 2)
	end
end

local function BuildAuraRow(f, def)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
	if not ok or not container then return nil end
	if container.SetEditModePreviewEnabled then pcall(container.SetEditModePreviewEnabled, container, false) end
	container:SetFrameLevel(f:GetFrameLevel() + 6)

	container:SetEnabled(false)
	local harmful = def.filter == "HARMFUL"
	local added = pcall(container.AddAuraGroup, container, "auras", def.filter, {
		maxFrameCount = def.max,
		layout = { elementSpacing = LOOK.auraSpacing, lineSpacing = LOOK.auraSpacing },
		initializeFrame = function(button) pcall(InitAuraButton, button, harmful, def.cancel) end,
	})
	if not added then return nil end
	local row = { container = container, def = def }
	PlaceAuraRow(f, row)
	container:Show()
	if pcall(container.SetUnit, container, f.unit) then container:SetEnabled(true) end
	return row
end

local function RefreshAuras(f)
	for _, row in ipairs(f.auraRows) do
		if row.container.UpdateAllAuras then pcall(row.container.UpdateAllAuras, row.container) end
	end
end

local FullUpdate, PlacePanel

local function OnePixel(f)
	local _, height = 0, nil
	if type(GetPhysicalScreenSize) == "function" then _, height = GetPhysicalScreenSize() end
	local scale = f:GetEffectiveScale()
	if not (PlainNumber(height) and height > 0 and PlainNumber(scale) and scale > 0) then return 1 end
	return 768 / (height * scale)
end

PlacePanel = function(f)
	local edge = LOOK.clip - OnePixel(f)
	local bottom = edge - (f.xpShown and (LOOK.gap + LOOK.xpHeight) or 0)
	f.panel:ClearAllPoints()
	f.panel:SetPoint("TOPLEFT", f, "TOPLEFT", edge, -edge)
	f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -edge, bottom)
end

local function NewBar(parent, level)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(BAR_TEXTURE)
	bar:SetStatusBarColor(1, 1, 1, 1)
	bar:SetFrameLevel(level)
	local fill = bar:GetStatusBarTexture()
	if fill.SetHorizTile then fill:SetHorizTile(false) end
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetTexture(BAR_TEXTURE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

local textFont
local function TextFont()
	if not textFont then
		textFont = CreateFont("KainUIForeverKainedFont")
		textFont:SetFont(LOOK.font, LOOK.fontSize, "")
		textFont:SetShadowColor(0, 0, 0, 1)
		textFont:SetShadowOffset(LOOK.shadow, -LOOK.shadow)
		textFont:SetTextColor(1, 1, 1, 1)
	end
	return textFont
end

local function NewText(layer)
	local fs = layer:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(TextFont())
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(LOOK.shadow, -LOOK.shadow)
	fs:SetWordWrap(false)
	return fs
end

local function TitleCase(key) return (key:gsub("^%l", string.upper)) end

local function ShowTooltip(self)
	if not GameTooltip then return end
	if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) else GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT") end
	GameTooltip:SetUnit(self.unit)
	GameTooltip:Show()
end

local function Build(spec, parent)
	local f = CreateFrame("Button", "KainUIForeverKained" .. TitleCase(spec.key), parent, "SecureUnitButtonTemplate")
	f.spec, f.unit = spec, spec.unit
	f:SetAttribute("unit", spec.unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:RegisterForClicks("AnyUp")
	f:SetSize(spec.width, spec.height)
	f:SetScale(spec.scale or 1)
	f:SetHitRectInsets(LOOK.inset, LOOK.inset, LOOK.inset, LOOK.inset)
	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	_G.ClickCastFrames = _G.ClickCastFrames or {}
	_G.ClickCastFrames[f] = true

	local panel = f:CreateTexture(nil, "BACKGROUND")
	panel:SetColorTexture(LOOK.panel[1], LOOK.panel[2], LOOK.panel[3], LOOK.panel[4])
	f.panel = panel
	PlacePanel(f)

	local level = f:GetFrameLevel()
	f.health = NewBar(f, level + 1)
	f.power = NewBar(f, level + 1)
	if spec.portrait then
		f.portrait = f:CreateTexture(nil, "ARTWORK")
	end
	if spec.combo then
		local combo = CreateFrame("Frame", nil, f)
		combo:SetFrameLevel(level + 1)
		combo.segs = {}
		for i = 1, MAX_COMBO do
			local seg = NewBar(combo, level + 2)
			TintColor(seg, COLORS.power.COMBOPOINTS)
			combo.segs[i] = seg
		end

		function combo:Segments(width, height)
			local n = self.count or 5
			local w = (width - (n - 1)) / n
			for i = 1, MAX_COMBO do
				local seg = self.segs[i]
				seg:ClearAllPoints()
				seg:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (w + 1), 0)
				seg:SetSize(w, height)
			end
		end
		combo.count = 5
		f.combo = combo
	end
	if spec.druidMana then
		f.druid = NewBar(f, level + 1)
		TintColor(f.druid, COLORS.power.MANA)
	end

	local layer = CreateFrame("Frame", nil, f)
	layer:SetAllPoints(f)
	layer:SetFrameLevel(level + 4)
	f.textLayer = layer
	f.texts = {}
	for slot in pairs(spec.texts) do
		local fs = NewText(layer)
		fs:SetJustifyH((slot == "hl" or slot == "pl") and "LEFT" or "RIGHT")
		f.texts[slot] = fs
	end

	f.icons = {}
	for _, name in ipairs(spec.indicators or {}) do
		local p = IND[name]
		local icon = layer:CreateTexture(nil, "OVERLAY")
		icon:SetSize(p[5], p[5])
		icon:SetPoint(p[1], f, p[2], p[3], p[4])
		icon:Hide()
		f.icons[name] = icon
	end

	if spec.fader then
		local fade = CreateFrame("Frame", nil, f)
		fade.owner, fade.elapsed, fade.time, fade.target = f, 0, 0, 1
		fade:SetScript("OnUpdate", FadeOnUpdate)
		fade:Hide()
		f.fade = fade
	end

	f.auraRows = {}
	if spec.auras and AurasAvailable() then
		for _, def in ipairs(spec.auras) do
			local row = BuildAuraRow(f, def)
			if row then f.auraRows[#f.auraRows + 1] = row end
		end
	end

	if spec.poll then
		local elapsed = 0
		f:SetScript("OnUpdate", function(self, dt)
			elapsed = elapsed + dt
			if elapsed < POLL then return end
			elapsed = 0
			FullUpdate(self)
		end)
	end
	f:HookScript("OnShow", function(self) FullUpdate(self) end)

	Layout(f)
	return f
end

FullUpdate = function(f)
	if not built then return end
	if f.preview then

		local real = UnitExists(f.spec.unit)
		f.unit = (Plain(real) and real) and f.spec.unit or "player"
	end
	local exists = UnitExists(f.unit)
	if Plain(exists) and not exists then return end
	Safe(function()
		UpdateHealthColor(f)
		UpdateHealth(f)
		UpdatePowerColor(f)
		UpdatePower(f)
		if f.combo or f.druid then UpdateExtras(f) end
		UpdatePortrait(f)
		UpdateTexts(f)
		UpdateIndicators(f)
		UpdateFade(f)
	end)
end

local UNIT_EVENTS = {
	UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health", UNIT_CONNECTION = "full",
	UNIT_POWER_UPDATE = "power", UNIT_POWER_FREQUENT = "power", UNIT_MAXPOWER = "power", UNIT_DISPLAYPOWER = "full",
	UNIT_NAME_UPDATE = "texts", UNIT_LEVEL = "texts", UNIT_CLASSIFICATION_CHANGED = "texts", PLAYER_FLAGS_CHANGED = "texts",
	UNIT_FACTION = "color", UNIT_PORTRAIT_UPDATE = "portrait", UNIT_MODEL_CHANGED = "portrait",
	UNIT_HAPPINESS = "happy",
}

local function OnUnitEvent(f, event, unit)
	if not built or not f:IsVisible() then return end
	local what = UNIT_EVENTS[event]
	if what == "health" then
		Safe(function()
			UpdateHealth(f)
			UpdateTexts(f)
			if f.fade then UpdateFade(f) end
		end)
	elseif what == "power" then
		Safe(function()
			UpdatePower(f)
			UpdateTexts(f)
			if f.combo or f.druid then UpdateExtras(f) end
			if f.fade then UpdateFade(f) end
			if f.icons.happy then UpdateIndicators(f, "happy") end
		end)
	elseif what == "texts" then
		Safe(UpdateTexts, f)
	elseif what == "color" then
		Safe(function() UpdateHealthColor(f); UpdateIndicators(f, "pvp") end)
	elseif what == "portrait" then
		Safe(UpdatePortrait, f)
	elseif what == "happy" then
		Safe(UpdateIndicators, f, "happy")
	else
		FullUpdate(f)
	end
end

local function RegisterUnitEvents(f)
	if f.spec.poll then return end
	f:SetScript("OnEvent", OnUnitEvent)
	for event in pairs(UNIT_EVENTS) do
		pcall(f.RegisterUnitEvent, f, event, f.unit)
	end
end

local function Each(fn)
	for _, spec in ipairs(UNITS) do
		local f = frames[spec.key]
		if f then fn(f) end
	end
end

local function AllIndicators(name)
	Each(function(f)
		if f.icons[name] and f:IsVisible() then pcall(UpdateIndicators, f, name) end
	end)
end

local function HideBlizzard(frame, keepEvents)
	if type(frame) ~= "table" or hiddenBlizzard[frame] then return end
	hiddenBlizzard[frame] = true
	if UnregisterUnitWatch then pcall(UnregisterUnitWatch, frame) end
	if frame.UnregisterAllEvents then pcall(frame.UnregisterAllEvents, frame) end
	for _, event in ipairs(keepEvents or {}) do pcall(frame.RegisterEvent, frame, event) end
	for _, bar in ipairs({ "healthbar", "manabar", "spellbar", "powerBarAlt" }) do
		local b = rawget(frame, bar)
		if type(b) == "table" and b.UnregisterAllEvents then pcall(b.UnregisterAllEvents, b) end
	end
	pcall(frame.Hide, frame)
	pcall(frame.SetParent, frame, hiddenParent)

	pcall(hooksecurefunc, frame, "SetParent", function(self, parent)
		if parent ~= hiddenParent and not InCombatLockdown() then self:SetParent(hiddenParent) end
	end)
end

local function TakeBlizzardFrames()
	hiddenParent = hiddenParent or CreateFrame("Frame", nil, UIParent)
	hiddenParent:Hide()
	HideBlizzard(_G.PlayerFrame, { "PLAYER_ENTERING_WORLD", "UNIT_ENTERING_VEHICLE", "UNIT_ENTERED_VEHICLE",
		"UNIT_EXITING_VEHICLE", "UNIT_EXITED_VEHICLE" })
	HideBlizzard(_G.AlternatePowerBar)
	HideBlizzard(_G.PetFrame)
	HideBlizzard(_G.TargetFrame)
	HideBlizzard(_G.TargetFrameToT)
	HideBlizzard(_G.ComboFrame)
	HideBlizzard(_G.FocusFrame)
	HideBlizzard(_G.FocusFrameToT)
	local party = _G.PartyFrame
	if type(party) == "table" then
		HideBlizzard(party)
		local pool = rawget(party, "PartyMemberFramePool")
		if type(pool) == "table" and pool.EnumerateActive then
			pcall(function()
				for member in pool:EnumerateActive() do HideBlizzard(member) end
			end)
		end
		for i = 1, 4 do
			local member = rawget(party, "MemberFrame" .. i)
			if type(member) == "table" then HideBlizzard(member) end
		end
	end
	for i = 1, 4 do HideBlizzard(_G["PartyMemberFrame" .. i]) end

	HideBlizzard(_G.CompactPartyFrame)
	if not hookedCompact and type(CompactPartyFrame_Generate) == "function" then
		hookedCompact = true
		hooksecurefunc("CompactPartyFrame_Generate", function()
			if not InCombatLockdown() then HideBlizzard(_G.CompactPartyFrame) end
		end)
	end
	tookBlizzard = true
end

local function SavedSpot(key)
	local all = KUI.db and KUI.db.kainedPositions
	local p = type(all) == "table" and all[key]
	if type(p) == "table" and PlainNumber(p.x) and PlainNumber(p.y) then return p end
	return nil
end

local function UIScale()
	local uiScale = UIParent:GetScale()
	if not PlainNumber(uiScale) or uiScale <= 0 then uiScale = 1 end
	return uiScale
end

local function Place(f, spec, key)
	local scale = spec.scale or 1
	f:ClearAllPoints()
	local saved = SavedSpot(key)
	if saved then
		f:SetPoint("CENTER", UIParent, "CENTER", saved.x / scale, saved.y / scale)
		return
	end
	local p = spec.point
	scale = scale * UIScale()
	f:SetPoint(p[1], UIParent, p[2], p[3] / scale, p[4] / scale)
end

local function BuildAll()
	holder = CreateFrame("Frame", "KainUIForeverKainedParty", UIParent, "SecureHandlerStateTemplate")
	holder:SetSize(PARTY.width, 4 * PARTY.height + 3 * PARTY.spacing)
	Place(holder, PARTY, "party")
	if RegisterStateDriver then RegisterStateDriver(holder, "visibility", "[group:raid] hide; show") end
	for _, spec in ipairs(UNITS) do
		local f = Build(spec, spec.party and holder or UIParent)
		if spec.party then
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(spec.party - 1) * (PARTY.height + PARTY.spacing))
		else
			Place(f, spec, spec.key)
		end
		RegisterUnitEvents(f)
		frames[spec.key] = f
	end
	built = true
end

local function Activate()
	for _, spec in ipairs(UNITS) do
		local f = frames[spec.key]
		if spec.unit == "player" then
			f:Show()
		elseif RegisterUnitWatch then
			RegisterUnitWatch(f)
		end
	end
	Each(FullUpdate)
end

function KUI:ApplyKainedFrames()
	if KUI.SKIP and KUI.SKIP.kained then return end
	if not Enabled() then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local ok, err = pcall(function()
		if KUI.ApplyClassicFrameArt and KUI.db and KUI.db.classicFrameArt then

			KUI:ApplyClassicFrameArt()
		end
		TakeBlizzardFrames()
		if not built then BuildAll() end
		Activate()
	end)
	if not ok then Report(err) end
	if KUI.ApplyXPBar then KUI:ApplyXPBar() end
end

function KUI:KainedFramesActive()
	return Showing() and true or false
end
function KUI:KainedHoldsBlizzardFrames()
	return tookBlizzard
end

local XP_LOOK = { clip = LOOK.clip, gap = LOOK.gap, height = LOOK.xpHeight, texture = BAR_TEXTURE,
	bgAlpha = LOOK.bgAlpha, restedAlpha = LOOK.xpRestedAlpha }
function KUI:KainedXPAnchor()
	if not Showing() then return nil end
	return frames.player, XP_LOOK
end

function KUI:KainedXPShown(shown)
	local f = frames.player
	if not f then return end
	shown = shown and Showing() and true or false
	if f.xpShown == shown then return end
	f.xpShown = shown
	pcall(PlacePanel, f)
	KUI:KainedXPChanged()
end
function KUI:KainedXPChanged()
	local f = frames.player
	if not f then return end
	if InCombatLockdown() then pending = true return end
	for _, row in ipairs(f.auraRows) do pcall(PlaceAuraRow, f, row) end
end

KUI.UNIT_FRAME_STYLES = {
	{ value = "launch", label = "Forever Launch", tip = "Blizzard's unit frames, as Forever shipped them." },
	{ value = "beta", label = "Forever Beta", tip = "Blizzard's unit frames with the earlier look: thin bronze rings, names on a band, bars filling their slots." },
	{ value = "kained", label = "Kained Unit Frames", tip = "A lite recreation of Shadowed Unit Frames from Kain's own setup: compact dark frames with class-coloured health, portraits, auras and the player fading out of combat. Player, pet, target, target of target, focus and party. Going back to the others needs a /reload." },
}

function KUI:GetUnitFrameStyle()
	local db = KUI.db
	if not db then return "launch" end
	if db.kainedFrames == true then return "kained" end
	if db.classicFrameArt == true then return "beta" end
	return "launch"
end

StaticPopupDialogs["KAINUIFOREVER_RELOAD_UNITFRAMES"] = {
	text = "Your unit frames switch after a reload.\n\nReload now?",
	button1 = RELOADUI or "Reload",
	button2 = CANCEL or "Cancel",
	OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function KUI:SetUnitFrameStyle(style)
	local db = KUI.db
	if not db then return end
	if style ~= "launch" and style ~= "beta" and style ~= "kained" then return end
	local wasKained = db.kainedFrames == true
	if style == "kained" then
		db.kainedFrames = true
	else
		db.kainedFrames = false
		db.classicFrameArt = (style == "beta")
	end
	if InCombatLockdown() and (style == "kained") ~= wasKained then
		print("|cff33ff99Kain-UI Forever|r unit frames change once you're out of combat.")
	end
	KUI:ApplyKainedFrames()
	if style ~= "kained" and tookBlizzard then
		if StaticPopup_Show then StaticPopup_Show("KAINUIFOREVER_RELOAD_UNITFRAMES") end
		return
	end
	if style ~= "kained" and KUI.ApplyClassicFrameArt then KUI:ApplyClassicFrameArt() end
end

local movers = {}
local unlocked = false
local placePending = false
local previewing = false
local previewPending = false
previewingNow = function() return previewing end

local function Movable()
	local list = {}
	for _, spec in ipairs(UNITS) do
		if not spec.party then
			list[#list + 1] = { key = spec.key, spec = spec, label = spec.label or TitleCase(spec.key) }
		end
	end
	list[#list + 1] = { key = "party", spec = PARTY, label = "Party", height = 4 * PARTY.height + 3 * PARTY.spacing }
	return list
end
local LABELS = { player = "Player", pet = "Pet", target = "Target", targettarget = "Target of target",
	focus = "Focus", focustarget = "Focus target", party = "Party" }

local function PlaceFrames()
	if InCombatLockdown() then placePending = true return end
	placePending = false
	for _, m in ipairs(Movable()) do
		local f = m.key == "party" and holder or frames[m.key]
		if f then Place(f, m.spec, m.key) end
	end
end

local function PlaceMover(box)
	local m = box.item
	local scale = m.spec.scale or 1
	box:SetSize(m.spec.width * scale, (m.height or m.spec.height) * scale)
	box:ClearAllPoints()
	local saved = SavedSpot(m.key)
	if saved then
		box:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
	else
		local p, uiScale = m.spec.point, UIScale()
		box:SetPoint(p[1], UIParent, p[2], p[3] / uiScale, p[4] / uiScale)
	end
end

local function SaveMover(box)
	local cx, cy = box:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not (PlainNumber(cx) and PlainNumber(cy) and PlainNumber(ux) and PlainNumber(uy)) then return end
	KUI.db.kainedPositions = type(KUI.db.kainedPositions) == "table" and KUI.db.kainedPositions or {}
	KUI.db.kainedPositions[box.item.key] = { x = math.floor((cx - ux) * 10 + 0.5) / 10, y = math.floor((cy - uy) * 10 + 0.5) / 10 }
	PlaceMover(box)
	PlaceFrames()
end

local function NewMover(m)
	local box = CreateFrame("Frame", "KainUIForeverKainedMover" .. TitleCase(m.key), UIParent)
	box.item = m
	box:SetFrameStrata("DIALOG")
	box:SetMovable(true)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	box:RegisterForDrag("LeftButton")
	local bg = box:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(box)
	bg:SetColorTexture(0.1, 0.7, 0.2, 0.25)
	for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = box:CreateTexture(nil, "BORDER")
		t:SetColorTexture(0.3, 1, 0.4, 0.9)
		t:SetPoint(side[1], box, side[1])
		t:SetPoint(side[2], box, side[2])
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
	end

	local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOM", box, "TOP", 0, 1)
	label:SetText(LABELS[m.key] or m.label)
	box:SetScript("OnDragStart", function(self)
		self:StartMoving()
		if KUI.BeginAlignDrag then pcall(KUI.BeginAlignDrag, KUI, self) end
	end)
	box:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if KUI.EndAlignDrag then pcall(KUI.EndAlignDrag, KUI, self) end
		SaveMover(self)
		if InCombatLockdown() then
			print("|cff33ff99Kain-UI Forever|r the frame moves there once you're out of combat.")
		end
	end)
	box:SetScript("OnMouseUp", function(self, button)
		if button ~= "RightButton" then return end
		if type(KUI.db.kainedPositions) == "table" then KUI.db.kainedPositions[self.item.key] = nil end
		PlaceMover(self)
		PlaceFrames()
	end)
	box:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(LABELS[self.item.key] or self.item.label, 1, 1, 1)
		GameTooltip:AddLine("Drag to move. Right-click: back to the starting spot. /kuf lock when done.", 1, 0.82, 0, true)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	box:Hide()
	return box
end

local function StartPreview()
	if previewing or InCombatLockdown() then return end
	previewing = true
	for _, spec in ipairs(UNITS) do
		local f = frames[spec.key]
		if f and spec.unit ~= "player" then
			if UnregisterUnitWatch then pcall(UnregisterUnitWatch, f) end
			f.preview = true
			f:Show()
			FullUpdate(f)
		end
	end
	local player = frames.player
	if player and player.fade then
		player.fade:Hide()
		player.fade.target = 1
		player:SetAlpha(1)
	end
end

local function StopPreview()
	if not previewing then return end
	if InCombatLockdown() then previewPending = true return end
	previewing, previewPending = false, false
	for _, spec in ipairs(UNITS) do
		local f = frames[spec.key]
		if f and f.preview then
			f.preview = nil
			f.unit = spec.unit
			if RegisterUnitWatch then RegisterUnitWatch(f) end
			FullUpdate(f)
		end
	end
	if frames.player then pcall(UpdateFade, frames.player) end
end

local function SnapElements(on)
	KUI.AlignElements = KUI.AlignElements or {}
	for i = #KUI.AlignElements, 1, -1 do
		if KUI.AlignElements[i].item then table.remove(KUI.AlignElements, i) end
	end
	if on then
		for _, box in pairs(movers) do KUI.AlignElements[#KUI.AlignElements + 1] = box end
	end
end

function KUI:SetKainedUnlocked(on)
	on = on and true or false
	if on and not Showing() then
		print("|cff33ff99Kain-UI Forever|r Kained Unit Frames aren't on. Pick them under Style in /kui (Unit Frames).")
		return false
	end
	unlocked = on
	for _, m in ipairs(Movable()) do
		local box = movers[m.key]
		if on and not box then
			box = NewMover(m)
			movers[m.key] = box
		end
		if box then
			if on then PlaceMover(box); box:Show() else box:Hide() end
		end
	end
	SnapElements(on)
	if on then StartPreview() else StopPreview() end
	return true
end

function KUI:ResetKainedPositions()
	if KUI.db then KUI.db.kainedPositions = {} end
	for _, box in pairs(movers) do PlaceMover(box) end
	PlaceFrames()
end

function KUI:IsKainedUnlocked() return unlocked end

SLASH_KAINUIKUF1 = "/kuf"
SlashCmdList["KAINUIKUF"] = function(msg)
	local command = (type(msg) == "string" and msg:match("^%s*(%S*)") or ""):lower()
	if command == "unlock" then
		if KUI:SetKainedUnlocked(true) then
			print("|cff33ff99Kain-UI Forever|r Kained Unit Frames unlocked: drag the green boxes, right-click one to put it back. |cffffff00/kuf lock|r when done.")
		end
	elseif command == "lock" then
		KUI:SetKainedUnlocked(false)
		print("|cff33ff99Kain-UI Forever|r Kained Unit Frames locked.")
	elseif command == "reset" then
		KUI:ResetKainedPositions()
		print("|cff33ff99Kain-UI Forever|r Kained Unit Frames are back in their starting spots" .. (InCombatLockdown() and " (once you're out of combat)." or "."))
	else
		print("|cff33ff99Kain-UI Forever|r Kained Unit Frames: |cffffff00/kuf unlock|r to move them, |cffffff00/kuf lock|r when done, |cffffff00/kuf reset|r to put them all back.")
	end
end

function KUI:KainedScanReport()
	local state = Enabled() and "picked" or (tookBlizzard and "not picked (still showing until /reload)" or "not picked")
	print("|cff33ff99Kain-UI Forever|r Kained Unit Frames: " .. state .. (pending and " (waiting for combat to end)" or "")
		.. " | built " .. tostring(built) .. " | Blizzard's frames hidden " .. tostring(tookBlizzard)
		.. " | auras " .. (AurasAvailable() and "yes" or "NO (no Blizzard_AuraContainer)"))
	for _, spec in ipairs(UNITS) do
		local f = frames[spec.key]
		if f then
			print(string.format("  %s: shown %s, aura rows %d", spec.key, tostring(f:IsShown()), #f.auraRows))
		end
	end
	local missing = {}
	for _, name in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "TargetFrameToT" }) do
		if not _G[name] then missing[#missing + 1] = name end
	end
	if #missing > 0 then print("  not in this client: " .. table.concat(missing, ", ")) end
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
		"GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_UPDATE_RESTING",
		"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "UNIT_PET", "PLAYER_ENTERING_WORLD",
		"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_REGEN_ENABLED" and pending then
		KUI:ApplyKainedFrames()
		KUI:KainedXPChanged()
	end
	if event == "PLAYER_REGEN_ENABLED" and placePending then PlaceFrames() end
	if event == "PLAYER_REGEN_DISABLED" and previewing then StopPreview() end
	if event == "PLAYER_REGEN_ENABLED" then

		if unlocked then
			previewPending = false
			StartPreview()
		elseif previewPending then
			StopPreview()
		end
	end
	if not Showing() then return end
	if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then

		Each(function(f) pcall(PlacePanel, f) end)
		return
	end
	local player = frames.player
	if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_UPDATE_RESTING" then
		if player then
			pcall(UpdateIndicators, player, "status")
			pcall(UpdateFade, player)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		local target = frames.target
		if target and target:IsVisible() then
			FullUpdate(target)
			RefreshAuras(target)
		end
		if player then
			pcall(UpdateFade, player)
			Safe(UpdateExtras, player)
		end
	elseif event == "PLAYER_FOCUS_CHANGED" then
		if frames.focus and frames.focus:IsVisible() then FullUpdate(frames.focus) end
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		Each(function(f)
			if f:IsVisible() then
				FullUpdate(f)
				if f.spec.party then RefreshAuras(f) end
			end
		end)
	elseif event == "PARTY_LEADER_CHANGED" then
		AllIndicators("leader")
	elseif event == "RAID_TARGET_UPDATE" then
		AllIndicators("raid")
	elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
		Each(function(f) f.readyDone = nil end)
		AllIndicators("ready")
	elseif event == "READY_CHECK_FINISHED" then
		AllIndicators("ready")
		if C_Timer and C_Timer.After then
			C_Timer.After(6, function()
				Each(function(f)
					f.readyDone = true
					if f.icons.ready then f.icons.ready:Hide() end
				end)
			end)
		end
	elseif event == "UNIT_PET" then
		if unit == "player" and frames.pet and frames.pet:IsVisible() then FullUpdate(frames.pet) end
	elseif unit == "player" and player and player.fade then

		player.fade.casting = (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") or nil
		pcall(UpdateFade, player)
	end
end)
