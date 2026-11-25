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
local BIG_CD = 60
local DEFAULT_WINDOW = 15
local PRIOR_GAIN = 0.25
local PRIOR_WEIGHT = 0.15
local MAX_GAIN = 2

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

local BIG_COOLDOWNS = {
	["Recklessness"] = 15, ["Death Wish"] = 30, ["Bestial Wrath"] = 18, ["Rapid Fire"] = 15,
	["Blade Flurry"] = 15, ["Adrenaline Rush"] = 15, ["Cold Blood"] = 3, ["Arcane Power"] = 15,
	["Combustion"] = 10, ["Presence of Mind"] = 3, ["Power Infusion"] = 15, ["Inner Focus"] = 3,
	["Blood Fury"] = 15, ["Berserking"] = 15, ["Rage of the Farseer"] = 25,
}

local OFFENSIVE_WORDS = { "damage", "attack speed", "haste", "critical", "energy regeneration",
	"attack power", "spell power", "casting speed", "cast time" }

local function ReadOffense(s, id)
	if s.cd == nil or s.cd < BIG_CD or s.offense ~= nil then return end
	local known = s.name and BIG_COOLDOWNS[s.name]
	local text = Plain(Call(C_Spell and C_Spell.GetSpellDescription, id))
	if type(text) ~= "string" or text == "" then
		if known then s.offense, s.window = true, known end
		return
	end
	local lower = text:lower()
	local secs = tonumber(lower:match("for (%d+) sec")) or tonumber(lower:match("lasts (%d+) sec"))
	if known then
		s.offense, s.window = true, known
	else
		lower = lower:gsub("damage taken", ""):gsub("damage you take", ""):gsub("reduc%a* [%a ]-damage", "")
		local hit = false
		for _, w in ipairs(OFFENSIVE_WORDS) do if lower:find(w, 1, true) then hit = true end end
		if lower:find("heal") or lower:find("stealth") or lower:find("dodge") then hit = false end
		s.offense = hit
		if hit then s.window = secs or DEFAULT_WINDOW end
	end
end

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
	ReadOffense(s, id)
	return s
end

local function IsBigOffense(id)
	local s = db and db.spells[id]
	return s ~= nil and s.offense == true and (s.cd or 0) >= BIG_CD
end
L.IsBigOffense = IsBigOffense

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
local readyAt = {}

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
		if IsBigOffense(id) then readyAt[id] = now + db.spells[id].cd end
		return
	end
	if #fight.presses < MAX_SEQUENCE then
		fight.presses[#fight.presses + 1] = NewPress(id, now)
	elseif IsBigOffense(id) then
		fight.late[#fight.late + 1] = { id = id, at = now }
	end
	if IsBigOffense(id) then readyAt[id] = now + db.spells[id].cd end
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
		presses = {}, pressCount = 0, late = {},
		ready = {},
	}

	for id, at in pairs(readyAt) do fight.ready[id] = at end
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
	local function T(at) return math.floor((at - origin) * 100 + 0.5) / 100 end
	for _, p in ipairs(f.presses) do
		pull.presses[#pull.presses + 1] = { id = p.id, t = T(p.at), cp = p.cp }
		LearnSpell(p.id)
	end

	local uses, ready = {}, {}
	for _, p in ipairs(f.presses) do
		if IsBigOffense(p.id) then uses[#uses + 1] = { id = p.id, t = T(p.at) } end
	end
	for _, p in ipairs(f.late) do uses[#uses + 1] = { id = p.id, t = T(p.at) } end
	for id, at in pairs(f.ready) do
		if at > origin then ready[id] = T(at) end
	end
	for _, u in ipairs(uses) do
		local at = origin + u.t + db.spells[u.id].cd
		if not readyAt[u.id] or readyAt[u.id] < at then readyAt[u.id] = at end
	end
	if #uses > 0 then pull.cdUses = uses end
	if next(ready) then pull.cdReady = ready end
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

local POSITIONAL = { Ambush = true, Backstab = true, Garrote = true, Shred = true, Ravage = true, Pounce = true }
local POSITION_TIME = 2

function L:Timeline(pull)
	local out = { idle = 0, capped = 0, longestIdle = 0, longestAt = nil, active = 0, gcdPresses = 0, spans = {} }
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
					local chain, mixed = 0, false
					for k = i + 1, math.min(#presses, i + 4) do
						local q = presses[k]
						if q.t - nextP.t > 4 then break end
						if q.id ~= nextP.id then mixed = true end
						local qs = SpellInfo(q.id)
						chain = chain + ((qs.costType == ENERGY and qs.cost) or 0)
					end
					if mixed and chain >= 60 then need = math.max(need, chain) end
					need = math.min(need, max)
					local afterGcd = math.min(max, energy + regen * gcd)
					if need > afterGcd then wait = (need - afterGcd) / regen end

					local toFull = (max - energy) / regen
					if gap > toFull then out.capped = out.capped + (gap - math.max(toFull, gcd)) end
				end

				if nextP and POSITIONAL[SpellInfo(nextP.id).name or ""] then wait = wait + POSITION_TIME end
				local idle = math.max(0, spare - wait)
				if not nextP then idle = math.min(idle, 2) end
				out.idle = out.idle + idle
				if idle > 0 then
					local from = t + gcd + wait
					out.spans[#out.spans + 1] = { from = from, to = from + idle }
				end
				if idle > out.longestIdle then out.longestIdle, out.longestAt = idle, t + gcd end
			end
		end
	end
	out.capped = math.max(0, out.capped)
	out.activeShare = pull.length > 0 and math.min(1, out.active / pull.length) or 0
	return out
end

local function Windows(pull)
	local out = {}
	if type(pull.cdUses) ~= "table" then return out end
	for _, u in ipairs(pull.cdUses) do
		if type(u) == "table" and type(u.id) == "number" and type(u.t) == "number" and IsBigOffense(u.id) then
			local w = db.spells[u.id].window or DEFAULT_WINDOW
			out[#out + 1] = { id = u.id, from = math.max(0, u.t), to = math.min(pull.length, u.t + w) }
		end
	end
	return out
end
L.Windows = Windows

local function Coverage(pull)
	local cov = {}
	if not pull.length or pull.length <= 0 then return cov end
	local byID = {}
	for _, w in ipairs(Windows(pull)) do
		byID[w.id] = byID[w.id] or {}
		table.insert(byID[w.id], w)
	end
	for id, list in pairs(byID) do
		table.sort(list, function(a, b) return a.from < b.from end)
		local total, reach = 0, 0
		for _, w in ipairs(list) do
			local from = math.max(w.from, reach)
			if w.to > from then total = total + (w.to - from) end
			reach = math.max(reach, w.to)
		end
		cov[id] = math.min(1, total / pull.length)
	end
	return cov
end

local function Solve(A, b)
	local n = #b
	local M = {}
	for i = 1, n do M[i] = {}; for j = 1, n do M[i][j] = A[i][j] end; M[i][n + 1] = b[i] end
	for c = 1, n do
		local piv = c
		for r = c + 1, n do if math.abs(M[r][c]) > math.abs(M[piv][c]) then piv = r end end
		if math.abs(M[piv][c]) < 1e-12 then return nil end
		M[c], M[piv] = M[piv], M[c]
		for r = 1, n do
			if r ~= c then
				local f = M[r][c] / M[c][c]
				for k = c, n + 1 do M[r][k] = M[r][k] - f * M[c][k] end
			end
		end
	end
	local x = {}
	for i = 1, n do x[i] = M[i][n + 1] / M[i][i] end
	return x
end

local modelCache = {}

function L:CooldownModel(spec)
	local key = tostring(spec) .. "#" .. #db.pulls .. "#" .. tostring(db.pulls[1])
	if modelCache.key == key then return modelCache.model end
	local rows, ids, index = {}, {}, {}
	for _, p in ipairs(db.pulls) do
		if p.spec == spec and p.dps and p.dps > 0 and p.length and p.length > 0 then
			local cov = Coverage(p)
			for id in pairs(cov) do
				if not index[id] and #ids < 8 then ids[#ids + 1] = id; index[id] = #ids end
			end
			rows[#rows + 1] = { pull = p, cov = cov }
		end
	end
	local g = {}
	for i = 1, #ids do g[i] = PRIOR_GAIN end
	for _, r in ipairs(rows) do r.w = 1 end
	local base = {}
	local function BoostOf(r)
		local boost = 0
		for id, c in pairs(r.cov) do if index[id] then boost = boost + g[index[id]] * c end end
		return boost
	end
	for _ = 1, 40 do

		local sum, n = {}, {}
		for _, r in ipairs(rows) do
			local k = r.pull.kind or "world"
			sum[k] = (sum[k] or 0) + r.w * r.pull.dps / (1 + BoostOf(r)); n[k] = (n[k] or 0) + r.w
		end
		for k, v in pairs(sum) do base[k] = v / n[k] end

		for _, r in ipairs(rows) do
			local resid = r.pull.dps / (base[r.pull.kind or "world"] * (1 + BoostOf(r))) - 1
			r.w = 1 / (1 + (resid / 0.25) ^ 2)
		end
		if #ids == 0 then break end

		local A, b = {}, {}
		for i = 1, #ids do
			A[i] = {}
			for j = 1, #ids do A[i][j] = (i == j) and PRIOR_WEIGHT or 0 end
			b[i] = PRIOR_WEIGHT * PRIOR_GAIN
		end
		for _, r in ipairs(rows) do
			local y = r.pull.dps / base[r.pull.kind or "world"] - 1
			for id, ci in pairs(r.cov) do
				local i = index[id]
				if i then
					b[i] = b[i] + r.w * ci * y
					for jd, cj in pairs(r.cov) do
						local j = index[jd]
						if j then A[i][j] = A[i][j] + r.w * ci * cj end
					end
				end
			end
		end
		local x = Solve(A, b)
		if not x then break end
		for i = 1, #ids do g[i] = math.max(0, math.min(MAX_GAIN, x[i])) end
	end
	local gains = {}
	for id, i in pairs(index) do gains[id] = g[i] end
	local model = { gains = gains, base = base, pulls = #rows }
	modelCache.key, modelCache.model = key, model
	return model
end

function L:Boost(pull)
	local model = self:CooldownModel(pull.spec)
	local boost = 0
	for id, c in pairs(Coverage(pull)) do
		boost = boost + (model.gains[id] or PRIOR_GAIN) * c
	end
	return boost, model
end

function L:RotationDPS(pull)
	if not pull.dps then return nil end
	return pull.dps / (1 + self:Boost(pull))
end

function L:CooldownUse(pull)
	local out = {}
	if not pull.dps then return out end
	local model = self:CooldownModel(pull.spec)
	local rdps = self:RotationDPS(pull) or 0
	local used = {}
	for _, w in ipairs(Windows(pull)) do used[w.id] = (used[w.id] or 0) + 1 end

	local known = {}
	for _, p in ipairs(db.pulls) do
		if p.spec == pull.spec then
			for _, w in ipairs(Windows(p)) do known[w.id] = true end
		end
	end
	for id in pairs(known) do
		local s = db.spells[id]
		local readyFrom = 0
		if type(pull.cdReady) == "table" and type(pull.cdReady[id]) == "number" then readyFrom = pull.cdReady[id] end
		local left = pull.length - readyFrom
		if left > 3 then
			local possible = math.floor(left / s.cd) + 1
			local n = used[id] or 0
			if possible > n then
				local w = math.min(s.window or DEFAULT_WINDOW, left)
				local gain = model.gains[id] or PRIOR_GAIN
				out[#out + 1] = { id = id, ready = possible, used = n, worth = (possible - n) * gain * w * rdps }
			end
		end
	end
	table.sort(out, function(a, b) return a.worth > b.worth end)
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
	local best, bestR
	for _, p in ipairs(list) do
		local r = self:RotationDPS(p)
		dps[#dps + 1] = r
		if not best or r > bestR then best, bestR = p, r end
	end
	table.sort(dps)
	local mid = #dps % 2 == 1 and dps[(#dps + 1) / 2] or (dps[#dps / 2] + dps[#dps / 2 + 1]) / 2
	return { best = best, bestRotation = bestR, usual = mid, count = #list }
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

	local model = self:CooldownModel(pull.spec)
	local windows = Windows(pull)
	local idleInCd, extra, cdName = 0, 0, nil
	for _, sp in ipairs(tl.spans) do
		for _, w in ipairs(windows) do
			local o = math.min(sp.to, w.to) - math.max(sp.from, w.from)
			if o > 0 then
				idleInCd = idleInCd + o
				extra = extra + o * (model.gains[w.id] or PRIOR_GAIN)
				cdName = cdName or self:SpellName(w.id)
			end
		end
	end
	if tl.idle >= 1 and perActiveSecond > 0 then
		local gain = (tl.idle + extra) * perActiveSecond
		local text = string.format("You pressed nothing for %.1f s while you could have (longest pause %.1f s). Filling those gaps is the easiest damage there is.", tl.idle, tl.longestIdle)
		if idleInCd >= 0.5 then
			text = text .. string.format(" %.1f s of it was while %s was up, when every second is worth more.", idleInCd, cdName)
		end
		tips[#tips + 1] = { dps = gain / pull.length, text = text }
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
		if r.presses > 0 and r.perPress and s.cd and s.cd >= 8 and pull.length >= s.cd and not IsBigOffense(r.id) then
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

	local anyPull = pull.kind == "boss" or pull.kind == "dummy"
	for _, c in ipairs(self:CooldownUse(pull)) do
		local s = SpellInfo(c.id)
		if anyPull or (s.cd <= 120 and pull.length >= 20) then
			local text
			if c.used == 0 then
				text = string.format("%s was ready but you didn't press it. It's worth about %d damage each time here.", self:SpellName(c.id), math.floor(c.worth / (c.ready - c.used) + 0.5))
			else
				text = string.format("%s was ready %d times but you pressed it %d. Use it as soon as it's back.", self:SpellName(c.id), c.ready, c.used)
			end
			tips[#tips + 1] = { dps = c.worth / pull.length, text = text }
		end
	end

	table.sort(tips, function(a, b) return a.dps > b.dps end)
	while #tips > 3 do table.remove(tips) end

	local cmp = self:Compare(pull)
	if cmp and cmp.count >= 2 and cmp.bestRotation > (self:RotationDPS(pull) or 0) * 1.1 then
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
	local byTag, boostOf, order = {}, {}, {}
	for _, p in ipairs(db and db.pulls or {}) do
		if type(p.lab) == "string" and p.dps then
			if not byTag[p.lab] then byTag[p.lab] = {}; boostOf[p.lab] = 0; order[#order + 1] = p.lab end
			table.insert(byTag[p.lab], self:RotationDPS(p))
			boostOf[p.lab] = boostOf[p.lab] + self:Boost(p)
		end
	end
	local groups = {}
	for _, tag in ipairs(order) do
		local n, mean, var = Stats(byTag[tag])
		groups[#groups + 1] = { tag = tag, n = n, mean = mean, var = var, sd = math.sqrt(var), boost = boostOf[tag] / n }
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

			local cdGap = math.abs(a.boost - b.boost)
			if cdGap >= 0.05 and z >= 1 then
				local more = a.boost > b.boost and a or b
				out.verdict = string.format("%s is ahead of %s by %.1f%% with big cooldowns taken out, but %s had them up a lot more, so this rests on K-Lift's estimate of what they add. For a clean test use the same cooldowns on both sides.", a.tag, b.tag, pct, more.tag)
			elseif z >= 2 then
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
