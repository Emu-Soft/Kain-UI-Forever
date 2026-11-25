local _, KUI = ...

local L = {}
KUI.Lift = L

local MAX_PULLS = 300
local MAX_SEQUENCE = 150
local PRECAST_WINDOW = 2
local MELEE_ID = 6603
local DEFAULT_GCD = 1.5
local ENERGY = 3
local COMBO = 4
local SESSION_CURRENT, TYPE_DAMAGE = 1, 0

local issecret = issecretvalue or function() return false end

local function Plain(v)
	if v == nil or issecret(v) then return nil end
	return v
end

local function PlainNumber(v)
	v = Plain(v)
	if type(v) == "number" then return v end
	return nil
end

local function Field(t, k)
	if type(t) ~= "table" or issecret(t) then return nil end
	if issecrettable and issecrettable(t) then return nil end
	local ok, v = pcall(function() return t[k] end)
	if not ok then return nil end
	return Plain(v)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e
end

local function Len(list)
	if type(list) ~= "table" or issecret(list) then return 0 end
	local ok, n = pcall(function() return #list end)
	return ok and type(n) == "number" and n or 0
end

L.Plain, L.Field = Plain, Field

local db

local function SaneDB(d)
	if type(d) ~= "table" then d = {} end
	if type(d.pulls) ~= "table" then d.pulls = {} end
	if type(d.spells) ~= "table" then d.spells = {} end
	if d.enabled ~= false then d.enabled = true end

	for i = #d.pulls, 1, -1 do
		local p = d.pulls[i]
		if type(p) ~= "table" or type(p.length) ~= "number" or type(p.presses) ~= "table" then
			table.remove(d.pulls, i)
		end
	end
	for id, s in pairs(d.spells) do
		if type(id) ~= "number" or type(s) ~= "table" then d.spells[id] = nil end
	end
	if d.labTag ~= nil and (type(d.labTag) ~= "string" or d.labTag == "") then d.labTag = nil end
	d.v = 1
	return d
end

function L:DB() return db end
function L:IsEnabled() return db ~= nil and db.enabled == true end

local function LearnSpell(id)
	if type(id) ~= "number" then return nil end
	local s = db.spells[id]
	if not s then s = {}; db.spells[id] = s end
	if not s.name then
		local name = Plain(Call(C_Spell and C_Spell.GetSpellName, id))
		if type(name) == "string" then s.name = name end
	end
	if s.cd == nil then
		local cdMs, gcdMs = Call(GetSpellBaseCooldown, id)
		cdMs, gcdMs = PlainNumber(cdMs), PlainNumber(gcdMs)
		if cdMs then s.cd = cdMs / 1000 end
		if gcdMs then s.gcd = gcdMs / 1000 end
	end
	if s.costType == nil then
		local costs = Call(C_Spell and C_Spell.GetSpellPowerCost, id)
		if type(costs) == "table" and not issecret(costs) then
			local first = Field(costs, 1)
			local kind, cost = Field(first, "type"), Field(first, "cost")
			if type(kind) == "number" and type(cost) == "number" then
				s.costType, s.cost = kind, cost
			elseif Len(costs) == 0 then
				s.costType, s.cost = -1, 0
			end
		end
	end
	return s
end

function L:SpellName(id)
	local s = db and db.spells[id]
	if s and s.name then return s.name end
	local name = Plain(Call(C_Spell and C_Spell.GetSpellName, id))
	return type(name) == "string" and name or ("Spell " .. tostring(id))
end

function L:SpellIcon(id)
	local icon = Plain(Call(C_Spell and C_Spell.GetSpellTexture, id))
	if icon then return icon end
	return Plain(Call(GetSpellTexture, id))
end

local power = { value = nil, max = nil, kind = nil, regen = nil }

local function ReadPower()
	local kind = PlainNumber(Call(UnitPowerType, "player"))
	local value = PlainNumber(Call(UnitPower, "player"))
	local max = PlainNumber(Call(UnitPowerMax, "player"))
	if kind then power.kind = kind end
	if value then power.value = value end
	if max and max > 0 then power.max = max end
	local _, active = Call(GetPowerRegen)
	active = PlainNumber(active)
	if active and active > 0 then power.regen = active end
end

local function ComboPoints()
	return PlainNumber(Call(UnitPower, "player", COMBO))
end

local function SpecKey()
	local _, class = Call(UnitClass, "player")
	class = Plain(class) or "UNKNOWN"
	local bestName, bestPoints = nil, -1
	local tabs = PlainNumber(Call(GetNumTalentTabs)) or 0
	for i = 1, math.min(tabs, 4) do
		local r = { Call(GetTalentTabInfo, i) }
		local name, points
		for j = 1, 5 do
			local v = Plain(r[j])
			if type(v) == "string" and not name and not v:find("[/\\]") then name = v end
			if type(v) == "number" and j >= 3 and (points == nil or v > points) and v <= 61 then points = v end
		end
		if name and points and points > bestPoints then bestName, bestPoints = name, points end
	end
	if bestName and bestPoints > 0 then return class .. ":" .. bestName end
	return class
end

local function Kind(fight)
	if fight.boss then return "boss" end
	if fight.instanceType == "party" or fight.instanceType == "raid" then return "dungeon" end
	if fight.dummy then return "dummy" end
	return "world"
end

L.KIND_NAMES = { boss = "Boss", dungeon = "Dungeon", dummy = "Target dummy", world = "Open world" }

local function TargetIsDummy()
	local name = Plain(Call(UnitName, "target"))
	return type(name) == "string" and name:lower():find("dummy") ~= nil
end

local fight
local recent = {}
local inCombat = false
local pendingReads = {}

local function NewPress(id, now)
	return { id = id, at = now, cp = ComboPoints() }
end

local function OnPress(spellID)
	if not L:IsEnabled() then return end
	local id = PlainNumber(spellID)
	if not id then return end
	local now = GetTime()
	if not inCombat or not fight then
		recent[#recent + 1] = NewPress(id, now)
		while recent[1] and now - recent[1].at > PRECAST_WINDOW + 1 do table.remove(recent, 1) end
		if not inCombat then LearnSpell(id) end
		return
	end
	if #fight.presses < MAX_SEQUENCE then
		fight.presses[#fight.presses + 1] = NewPress(id, now)
	end
	fight.pressCount = fight.pressCount + 1
	if not fight.boss and Plain(Call(IsEncounterInProgress)) == true then fight.boss = true end
end

local function StartFight()
	local now = GetTime()
	local _, instanceType = Call(IsInInstance)
	fight = {
		start = now,
		date = Plain(Call(date, "%Y-%m-%d %H:%M")),
		zone = Plain(Call(GetRealZoneText)),
		instanceType = Plain(instanceType),
		boss = Plain(Call(IsEncounterInProgress)) == true,
		dummy = TargetIsDummy(),
		spec = SpecKey(),
		energy = power.kind == ENERGY and power.value or nil,
		energyMax = power.kind == ENERGY and power.max or nil,
		regen = power.kind == ENERGY and power.regen or nil,
		powerKind = power.kind,
		presses = {}, pressCount = 0,
	}
	for _, p in ipairs(recent) do
		if now - p.at <= PRECAST_WINDOW then
			fight.presses[#fight.presses + 1] = p
			fight.pressCount = fight.pressCount + 1
		end
	end
	wipe(recent)
end

local function ReadSource(src)
	if src == nil then return nil end
	local total = PlainNumber(Field(src, "totalAmount"))
	local list = Field(src, "combatSpells")
	if total == nil or (list ~= nil and type(list) ~= "table") then return nil end
	local spells = {}
	for i = 1, Len(list) do
		local row = Field(list, i)
		local id, amount = PlainNumber(Field(row, "spellID")), PlainNumber(Field(row, "totalAmount"))
		if id and amount then spells[#spells + 1] = { id = id, amount = amount } end
	end
	return total, spells
end

local function ReadMeter(pull)
	local dm = C_DamageMeter
	if not dm then return false end
	local guid = Plain(Call(UnitGUID, "player"))
	if type(guid) ~= "string" then return false end
	local src
	if pull.sessionID then
		src = Call(dm.GetCombatSessionSourceFromID, pull.sessionID, TYPE_DAMAGE, guid)
	else
		src = Call(dm.GetCombatSessionSourceFromType, SESSION_CURRENT, TYPE_DAMAGE, guid)
	end
	local total, spells = ReadSource(src)
	if not total then return false end
	pull.damage, pull.spells = total, spells
	pull.dps = pull.length > 0 and total / pull.length or 0
	return true
end

local function NewestSessionID()
	local list = Call(C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions)
	local n = Len(list)
	if n == 0 then return nil end
	return PlainNumber(Field(Field(list, n), "sessionID"))
end

local function KeepPull(pull)

	if pull.pressCount == 0 and (pull.damage or 0) == 0 then return false end
	if db.labTag and pull.lab == nil then pull.lab = db.labTag end
	table.insert(db.pulls, 1, pull)
	while #db.pulls > MAX_PULLS do table.remove(db.pulls) end
	if L.OnNewPull then pcall(L.OnNewPull, pull) end
	return true
end

local function FinishRead(pull)
	if ReadMeter(pull) then
		pendingReads[pull] = nil
		KeepPull(pull)
		return true
	end
	return false
end

local function EndFight()
	local f = fight
	fight = nil
	if not f then return end
	local now = GetTime()
	local first = f.presses[1] and f.presses[1].at or f.start
	local origin = math.min(first, f.start)
	local pull = {
		date = f.date, zone = f.zone, kind = Kind(f), spec = f.spec,
		length = math.max(0.5, now - origin),
		pressCount = f.pressCount,
		energy = f.energy, energyMax = f.energyMax, regen = f.regen, powerKind = f.powerKind,
		presses = {},
	}
	for _, p in ipairs(f.presses) do
		pull.presses[#pull.presses + 1] = { id = p.id, t = math.floor((p.at - origin) * 100 + 0.5) / 100, cp = p.cp }
		LearnSpell(p.id)
	end
	pull.sessionID = NewestSessionID()
	if FinishRead(pull) then return end

	pendingReads[pull] = true
	C_Timer.After(0.5, function()
		if pendingReads[pull] then FinishRead(pull) end
	end)
end

local function RetryPending()
	for pull in pairs(pendingReads) do
		if not FinishRead(pull) then
			pull.tries = (pull.tries or 0) + 1
			if pull.tries > 3 then

				pendingReads[pull] = nil
				KeepPull(pull)
			end
		end
	end
end

local function SpellInfo(id) return (db and db.spells[id]) or {} end

local function GCDOf(id)
	local s = SpellInfo(id)
	if s.gcd ~= nil then return s.gcd end
	return DEFAULT_GCD
end

function L:SpellRows(pull)
	local rows, byID = {}, {}
	for _, s in ipairs(pull.spells or {}) do
		local r = { id = s.id, damage = s.amount, presses = 0 }
		rows[#rows + 1] = r
		byID[s.id] = r
	end
	for _, p in ipairs(pull.presses) do
		local r = byID[p.id]
		if not r then
			r = { id = p.id, damage = 0, presses = 0 }
			rows[#rows + 1] = r
			byID[p.id] = r
		end
		r.presses = r.presses + 1
	end
	for _, r in ipairs(rows) do
		if r.presses > 0 and r.damage > 0 then r.perPress = r.damage / r.presses end
		r.perMinute = r.presses * 60 / pull.length
	end
	table.sort(rows, function(a, b)
		if a.damage ~= b.damage then return a.damage > b.damage end
		return a.presses > b.presses
	end)
	return rows, byID
end

function L:Timeline(pull)
	local out = { idle = 0, capped = 0, longestIdle = 0, longestAt = nil, active = 0, gcdPresses = 0 }
	local presses = pull.presses
	local energyUser = pull.powerKind == ENERGY
	local regen = pull.regen or 10
	local max = pull.energyMax or 100
	local energy = pull.energy or max
	local lastT = 0
	for i, p in ipairs(presses) do
		local t = math.max(p.t, lastT)
		if energyUser then
			energy = math.min(max, energy + regen * (t - lastT))
			local s = SpellInfo(p.id)
			if s.costType == ENERGY and s.cost then energy = math.max(0, energy - s.cost) end
		end
		lastT = t
		local gcd = GCDOf(p.id)
		if gcd > 0 then
			out.gcdPresses = out.gcdPresses + 1
			local nextP = presses[i + 1]
			local gapEnd = nextP and math.max(nextP.t, t) or pull.length
			local gap = gapEnd - t
			out.active = out.active + math.min(gcd, gap)
			local spare = gap - gcd
			if spare > 0.3 then
				local wait = 0
				if energyUser and nextP then
					local ns = SpellInfo(nextP.id)
					local need = (ns.costType == ENERGY and ns.cost) or 0
					local afterGcd = math.min(max, energy + regen * gcd)
					if need > afterGcd then wait = (need - afterGcd) / regen end

					local toFull = (max - energy) / regen
					if gap > toFull then out.capped = out.capped + (gap - math.max(toFull, gcd)) end
				end
				local idle = math.max(0, spare - wait)
				if not nextP then idle = math.min(idle, 2) end
				out.idle = out.idle + idle
				if idle > out.longestIdle then out.longestIdle, out.longestAt = idle, t + gcd end
			end
		end
	end
	out.capped = math.max(0, out.capped)
	out.activeShare = pull.length > 0 and math.min(1, out.active / pull.length) or 0
	return out
end

function L:Similar(pull)
	local list = {}
	for _, p in ipairs(db.pulls) do
		if p ~= pull and p.spec == pull.spec and p.kind == pull.kind and p.dps
			and p.length >= pull.length * 0.5 and p.length <= pull.length * 2 then
			list[#list + 1] = p
		end
	end
	return list
end

function L:Compare(pull)
	local list = self:Similar(pull)
	if #list == 0 then return nil end
	local dps = {}
	local best
	for _, p in ipairs(list) do
		dps[#dps + 1] = p.dps
		if not best or p.dps > best.dps then best = p end
	end
	table.sort(dps)
	local mid = #dps % 2 == 1 and dps[(#dps + 1) / 2] or (dps[#dps / 2] + dps[#dps / 2 + 1]) / 2
	return { best = best, usual = mid, count = #list }
end

local function OpenerOf(pull, n)
	local ids = {}
	for _, p in ipairs(pull.presses) do
		if GCDOf(p.id) > 0 then ids[#ids + 1] = p.id end
		if #ids >= n then break end
	end
	return ids
end
L.OpenerOf = OpenerOf

local function SameList(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

function L:Tips(pull)
	if not pull.damage or pull.damage <= 0 then return {} end
	local tips = {}
	local rows, byID = self:SpellRows(pull)
	local tl = self:Timeline(pull)
	local abilityDamage = pull.damage - ((byID[MELEE_ID] and byID[MELEE_ID].damage) or 0)
	local perActiveSecond = tl.active > 0 and abilityDamage / tl.active or 0

	if tl.idle >= 1 and perActiveSecond > 0 then
		local gain = tl.idle * perActiveSecond
		tips[#tips + 1] = {
			dps = gain / pull.length,
			text = string.format("You pressed nothing for %.1f s while you could have (longest pause %.1f s). Filling those gaps is the easiest damage there is.", tl.idle, tl.longestIdle),
		}
	end

	if pull.powerKind == ENERGY and tl.capped >= 1 then
		local spent, presses = 0, 0
		for _, r in ipairs(rows) do
			local s = SpellInfo(r.id)
			if r.presses > 0 and s.costType == ENERGY and (s.cost or 0) > 0 then
				spent = spent + s.cost * r.presses; presses = presses + r.presses
			end
		end
		if spent > 0 and presses > 0 then
			local perEnergy = abilityDamage / spent
			local gain = tl.capped * (pull.regen or 10) * perEnergy
			tips[#tips + 1] = {
				dps = gain / pull.length,
				text = string.format("You sat at full energy for %.1f s, so that energy was lost. Spend it before you reach full.", tl.capped),
			}
		end
	end

	for _, r in ipairs(rows) do
		local s = SpellInfo(r.id)
		if r.presses > 0 and r.perPress and s.cd and s.cd >= 8 and pull.length >= s.cd then
			local possible = math.floor(pull.length / s.cd) + 1
			local missed = possible - r.presses
			if missed >= 1 then
				tips[#tips + 1] = {
					dps = missed * r.perPress / pull.length,
					text = string.format("%s was ready %d times but you pressed it %d. Each press did about %d damage.", self:SpellName(r.id), possible, r.presses, math.floor(r.perPress + 0.5)),
				}
			end
		end
	end

	table.sort(tips, function(a, b) return a.dps > b.dps end)
	while #tips > 3 do table.remove(tips) end

	local cmp = self:Compare(pull)
	if cmp and cmp.count >= 2 and cmp.best.dps > pull.dps * 1.1 then
		local mine, best = OpenerOf(pull, 3), OpenerOf(cmp.best, 3)
		if #best == 3 and not SameList(mine, best) then
			local names = {}
			for i, id in ipairs(best) do names[i] = self:SpellName(id) end
			local tip = { text = "Your best pull like this one opened with " .. table.concat(names, ", ") .. "." }
			if #tips >= 3 then tips[3] = tip else tips[#tips + 1] = tip end
		end
	end
	return tips
end

local frame = CreateFrame("Frame")
KUI:SafeRegisterEvent(frame, "ADDON_LOADED")
KUI:SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
KUI:SafeRegisterEvent(frame, "PLAYER_REGEN_DISABLED")
KUI:SafeRegisterEvent(frame, "PLAYER_REGEN_ENABLED")
KUI:SafeRegisterEvent(frame, "ENCOUNTER_START")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_POWER_FREQUENT", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_MAXPOWER", "player")

frame:SetScript("OnEvent", function(_, event, a1, _, a3)
	local ok, err = pcall(function()
		if event == "ADDON_LOADED" then
			if a1 ~= "Kain-UI-Forever" then return end
			KainUIForeverLiftDB = SaneDB(KainUIForeverLiftDB)
			db = KainUIForeverLiftDB
			return
		end
		if not db then return end
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			OnPress(a3)
		elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "PLAYER_ENTERING_WORLD" then
			if not inCombat then ReadPower() end
		elseif event == "PLAYER_REGEN_DISABLED" then
			inCombat = true
			if L:IsEnabled() then StartFight() end
		elseif event == "PLAYER_REGEN_ENABLED" then
			inCombat = false
			ReadPower()
			EndFight()
			RetryPending()
		elseif event == "ENCOUNTER_START" then
			if fight then fight.boss = true end
		end
	end)

	if not ok and geterrorhandler then pcall(geterrorhandler(), err) end
end)

function L:SetEnabled(on)
	if not db then return end
	db.enabled = on and true or false
	if not db.enabled then fight = nil end
end

function L:SetLabTag(tag)
	if not db then return end
	if type(tag) == "string" then tag = tag:sub(1, 16) end
	db.labTag = (tag ~= nil and tag ~= "") and tag or nil
end

function L:LabTag() return db and db.labTag end

local function Stats(list)
	local n, sum = #list, 0
	for _, v in ipairs(list) do sum = sum + v end
	local mean = n > 0 and sum / n or 0
	local sq = 0
	for _, v in ipairs(list) do sq = sq + (v - mean) ^ 2 end
	local var = n > 1 and sq / (n - 1) or 0
	return n, mean, var
end

function L:LabResults()
	local byTag, order = {}, {}
	for _, p in ipairs(db and db.pulls or {}) do
		if type(p.lab) == "string" and p.dps then
			if not byTag[p.lab] then byTag[p.lab] = {}; order[#order + 1] = p.lab end
			table.insert(byTag[p.lab], p.dps)
		end
	end
	local groups = {}
	for _, tag in ipairs(order) do
		local n, mean, var = Stats(byTag[tag])
		groups[#groups + 1] = { tag = tag, n = n, mean = mean, var = var, sd = math.sqrt(var) }
	end
	table.sort(groups, function(a, b) return a.mean > b.mean end)
	local out = { groups = groups }
	local a, b = groups[1], groups[2]
	if a and b then
		if a.n < 2 or b.n < 2 then
			out.verdict = "Do at least 2 fights of each to compare."
		else
			local diff = a.mean - b.mean
			local se = math.sqrt(a.var / a.n + b.var / b.n)
			local pct = b.mean > 0 and diff / b.mean * 100 or 0
			local z = se > 0 and diff / se or (diff > 0 and math.huge or 0)
			if z >= 2 then
				out.verdict = string.format("%s beats %s by %.1f%%, and that's very likely real.", a.tag, b.tag, pct)
			else
				local more = ""
				if diff > 0 then
					local k = (2 * se / diff) ^ 2
					local need = math.ceil(math.max(a.n, b.n) * k) - math.max(a.n, b.n)
					if need > 0 and need < 200 then
						more = string.format(" About %d more fights of each should settle it.", need)
					elseif need >= 200 then
						more = " Telling them apart would take hundreds of fights, so for practical purposes they're equal."
					end
				end
				if z >= 1 then
					out.verdict = string.format("%s is ahead of %s by %.1f%%, but it could still be luck.%s", a.tag, b.tag, pct, more)
				else
					out.verdict = string.format("Too close to call: %s and %s are %.1f%% apart.%s", a.tag, b.tag, pct, more)
				end
			end
		end
	end
	return out
end

function L:ClearLab()
	if not db then return end
	for _, p in ipairs(db.pulls) do p.lab = nil end
	db.labTag = nil
end

function L:Reset()
	if not db then return end
	wipe(db.pulls)
	wipe(pendingReads)
end

L._test = { ReadPower = ReadPower, power = power }
