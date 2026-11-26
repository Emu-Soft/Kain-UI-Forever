local _, KUI = ...

local Sim = {}
if type(KUI) == "table" then KUI.Sim = Sim end
Sim.Classes = {}

local random, sqrt = math.random, math.sqrt
local min, max = math.min, math.max
local huge = math.huge

local AP_PER_DPS = 14
local NORMALIZED = { Dagger = 1.7, OneHand = 2.4, TwoHand = 3.3, Ranged = 2.8 }

Sim.MH, Sim.OH = "MH", "OH"

local function HandTable(level, skill, tlevel)
	local base = level * 5
	local def = tlevel * 5
	local d = def - skill
	local t = {}
	if d > 10 then
		t.hitSupp = (d - 10) * 0.002
		t.miss = 0.05 + d * 0.002
	else
		t.hitSupp = 0
		t.miss = 0.05 + d * 0.001
	end
	if def - base > 10 then
		t.parry = 0.05 + (def - base) * 0.006
	else
		t.parry = 0.05 + (def - base) * 0.001
	end
	t.dodge = 0.05 + d * 0.001
	t.block = 0.05
	t.glance = max(0, 0.1 + (def - base) * 0.02)
	t.glanceMin = max(min(1.3 - 0.05 * d, 0.91), 0.01)
	t.glanceMax = max(min(1.2 - 0.03 * d, 0.99), 0.2)
	if def > base then t.critSupp = (def - base) * 0.002 else t.critSupp = (def - base) * 0.0004 end
	if tlevel - level >= 3 then t.critSupp = t.critSupp + 0.018 end
	return t
end

local SPELL_MISS = { [0] = 0.04, 0.05, 0.06, 0.17 }

local Fight = {}
Fight.__index = Fight
Sim.Fight = Fight

function Sim.NewFight(cfg)
	local p = cfg.player
	local f = setmetatable({}, Fight)
	f.cfg = cfg
	f.p = p
	f.tgt = cfg.target
	f.level = p.level or 60
	f.dw = p.oh ~= nil and p.oh.speed ~= nil
	local tl = f.tgt.level or (f.level + 3)
	f.tables = {
		MH = HandTable(f.level, (p.mh and p.mh.skill) or f.level * 5, tl),
		OH = f.dw and HandTable(f.level, p.oh.skill or f.level * 5, tl) or nil,
	}
	local diff = max(0, min(3, tl - f.level))
	f.spellMissBase = (tl - f.level > 3) and (0.17 + 0.11 * (tl - f.level - 3)) or SPELL_MISS[diff]
	f.resistAvg = (tl > f.level) and (0.02 * (tl - f.level)) or 0
	f.spells, f.rules, f.procs = {}, {}, {}
	f.onLand, f.onCast = {}, {}
	f.critBonus = {}
	f.armorPenPct = 0
	f.dmgMult = 1
	f.physMult = 1
	f.offhandMult = 0.5
	f.whiteOHMult = 1
	local class = Sim.Classes[p.class]
	if class and class.Setup then class.Setup(f) end
	return f
end

function Fight:After(delay, fn, arg)
	local e = { at = self.t + delay, fn = fn, arg = arg }
	local q = self.queue
	q[#q + 1] = e
	return e
end

function Fight:At(at, fn, arg)
	local e = { at = at, fn = fn, arg = arg }
	local q = self.queue
	q[#q + 1] = e
	return e
end

function Fight:Cancel(e) if e then e.dead = true end end

local function PopNext(q)
	local best, bi = nil, nil
	local i = 1
	while i <= #q do
		local e = q[i]
		if e.dead then
			q[i] = q[#q]; q[#q] = nil
		else
			if not best or e.at < best.at then best, bi = e, i end
			i = i + 1
		end
	end
	if bi then q[bi] = q[#q]; q[#q] = nil end
	return best
end

function Fight:Energy()
	if self.cfg.energyTicks then return self.energy end
	return min(self.maxEnergy, self.energy + self.regen * self.regenMult * (self.t - self.eT))
end

function Fight:SetEnergy(v)
	self.energy = max(0, min(self.maxEnergy, v))
	self.eT = self.t
end

function Fight:AddEnergy(n) self:SetEnergy(self:Energy() + n) end
function Fight:SpendEnergy(n) self:SetEnergy(self:Energy() - n) end

function Fight:SetRegenMult(m)
	self:SetEnergy(self:Energy())
	self.regenMult = m
end

function Fight:AddCP(n) self.cp = min(5, self.cp + n) end

function Fight:AuraUp(name)
	local a = self.auras[name]
	return a ~= nil and a > self.t
end

function Fight:AuraLeft(name)
	local a = self.auras[name]
	if not a or a <= self.t then return 0 end
	return a - self.t
end

local function ExpireAura(f, a)
	if f.auras[a.name] == a.at then
		f.auras[a.name] = nil
		if a.off then a.off(f) end
	end
end

function Fight:AuraOn(name, dur, on, off)
	local up = self:AuraUp(name)
	local at = self.t + dur
	self.auras[name] = at
	if not up and on then on(self) end
	self:At(at, ExpireAura, { name = name, at = at, off = off })
end

function Fight:AuraOff(name, off)
	if self:AuraUp(name) then
		self.auras[name] = nil
		if off then off(self) end
	end
end

function Fight:Ready(name) return (self.cds[name] or 0) <= self.t + 1e-9 end
function Fight:CDLeft(name) return max(0, (self.cds[name] or 0) - self.t) end
function Fight:StartCD(name, dur) self.cds[name] = self.t + dur end

function Fight:Deal(src, dmg)
	if dmg <= 0 then return end
	self.dmg[src] = (self.dmg[src] or 0) + dmg
	self.total = self.total + dmg
end

function Fight:Count(src) self.casts[src] = (self.casts[src] or 0) + 1 end

function Fight:ArmorMult()
	local armor = max(0, (self.tgt.armor or 0) * (1 - self.armorPenPct) - (self.p.armorPen or 0))
	return 1 - armor / (armor + 400 + 85 * self.level)
end

function Fight:WeaponDamage(hand, normalized, ap)
	local w = self.p[hand == "OH" and "oh" or "mh"]
	if not w then return 0 end
	local speed = normalized and (NORMALIZED[w.type] or (w.twoHand and 3.3 or 2.4)) or w.speed
	local d = w.min + (w.max - w.min) * random() + speed * (ap or self:AP()) / AP_PER_DPS
	if hand == "OH" then d = d * self.offhandMult end
	return d
end

function Fight:AP() return self.p.ap + (self.apBonus or 0) end

function Fight:Strike(a)
	local hand = a.hand or "MH"
	local tb = self.tables[hand] or self.tables.MH
	local hitEff = (self.p.hit or 0) / 100 - tb.hitSupp
	local miss = a.noMiss and 0 or max(0, tb.miss - hitEff + ((a.white and self.dw) and 0.19 or 0))
	local exp = (self.p.expertise or 0) / 100
	local dodge = a.noDodge and 0 or max(0, tb.dodge - exp)
	local front = self.tgt.front
	local parry = (front and not a.noParry) and max(0, tb.parry - exp) or 0
	local block = (front and not a.noBlock) and tb.block or 0
	local crit = a.noCrit and 0 or ((self.p.crit or 0) + (self.critBonus[hand] or 0) + (self.critAll or 0) + (a.critBonus or 0)) / 100 - tb.critSupp
	local roll = random()
	local outcome
	local dmg = a.dmg or 0
	local c = miss
	if roll < c then
		outcome = "miss"
	else
		c = c + dodge
		if roll < c then
			outcome = "dodge"
		else
			c = c + parry
			if roll < c then
				outcome = "parry"
			elseif a.white then
				c = c + tb.glance
				if roll < c then
					outcome = "glance"
					dmg = dmg * (tb.glanceMin + random() * (tb.glanceMax - tb.glanceMin))
				else
					c = c + block
					if roll < c then
						outcome = "block"
					else
						c = c + max(0, crit)
						if roll < c then outcome = "crit" else outcome = "hit" end
					end
				end
			else

				c = c + block
				if roll < c then
					outcome = "block"
				elseif random() < crit then
					outcome = "crit"
				else
					outcome = "hit"
				end
			end
		end
	end
	if outcome == "miss" or outcome == "dodge" or outcome == "parry" then
		dmg = 0
	else
		if outcome == "crit" then dmg = dmg * (a.critMult or 2) end
		dmg = dmg * self.dmgMult * self.physMult * (a.mult or 1)
		if not a.noArmor then dmg = dmg * self:ArmorMult() end
		if outcome == "block" then dmg = max(0, dmg - (self.tgt.blockValue or 0)) end
	end
	if a.src then
		if a.count ~= false then self:Count(a.src) end
		self:Deal(a.src, dmg)
	end
	if dmg > 0 or (outcome ~= "miss" and outcome ~= "dodge" and outcome ~= "parry") then
		if a.proc ~= false then
			local kind = a.white and "auto" or "special"
			for i = 1, #self.onLand do self.onLand[i](self, hand, kind, outcome, a) end
		end
	end
	return outcome, dmg
end

function Fight:Landed(outcome) return outcome ~= "miss" and outcome ~= "dodge" and outcome ~= "parry" end

function Fight:SpellHit(s)
	local hit = (self.p.spellHit or 0) / 100
	if self.cfg.spellHitFromMelee then hit = (self.p.hit or 0) / 100 end
	local miss = max(0.01, self.spellMissBase - hit)
	if self.cfg.parity then miss = max(0, self.spellMissBase - hit) end
	if s.src then self:Count(s.src) end
	if random() < miss then return "miss", 0 end
	local dmg = (s.dmg or 0) * self.dmgMult * (s.mult or 1)
	local outcome = "hit"
	if not s.noCrit and random() < (self.p.spellCrit or 0) / 100 then
		outcome = "crit"
		dmg = dmg * (s.critMult or 1.5)
	end
	local res = (self.tgt.resist and self.tgt.resist[s.school or "nature"]) or 0
	local coef = min(1, res / (self.level * 5) + self.resistAvg / 0.75)
	dmg = dmg * (1 - 0.75 * coef)
	if s.src then self:Deal(s.src, dmg) end
	return outcome, dmg
end

local function DotTick(f, d)
	if f.dots[d.src] ~= d then return end
	f:Deal(d.src, d.tick)
	d.left = d.left - 1
	if d.left > 0 then f:After(d.every, DotTick, d) else f.dots[d.src] = nil end
end

function Fight:Dot(d)
	d.left = d.ticks
	self.dots[d.src] = d
	self:After(d.every, DotTick, d)
end

function Fight:DotUp(src) return self.dots[src] ~= nil end

function Fight:SwingSpeed(hand)
	local w = self.p[hand == "OH" and "oh" or "mh"]
	return w.speed / ((self.p.haste or 1) * self.speedMult)
end

local Swing

local function ScheduleSwing(f, hand, at)
	f:Cancel(f.swings[hand])
	f.swings[hand] = f:At(at, Swing, hand)
end

Swing = function(f, hand)
	f.swings[hand] = nil
	if not f.autos then return end
	f.lastSwing[hand] = f.t
	ScheduleSwing(f, hand, f.t + f:SwingSpeed(hand))
	local dmg = f:WeaponDamage(hand)
	if hand == "OH" then dmg = dmg * f.whiteOHMult end
	f:Strike({ src = "Melee " .. hand, hand = hand, dmg = dmg, white = true })
end

function Fight:StartAutos()
	if self.autos then return end
	self.autos = true
	ScheduleSwing(self, "MH", self.t)
	if self.dw then ScheduleSwing(self, "OH", self.t) end
end

function Fight:StopAutos()
	self.autos = false
	self:Cancel(self.swings.MH); self.swings.MH = nil
	self:Cancel(self.swings.OH); self.swings.OH = nil
end

function Fight:ExtraAttack(src)
	if not self.autos then return end
	self:Count(src)
	ScheduleSwing(self, "MH", self.t)
end

function Fight:MultiplySpeed(m)
	self.speedMult = self.speedMult * m
	for _, hand in ipairs({ "MH", "OH" }) do
		local e = self.swings[hand]
		if e and not e.dead then
			ScheduleSwing(self, hand, self.t + (e.at - self.t) / m)
		end
	end
end

function Fight:AddProc(p)
	p.ready = 0
	self.procs[#self.procs + 1] = p
end

local function RunProcs(f, hand, kind)
	local procs = f.procs
	for i = 1, #procs do
		local p = procs[i]
		if (not p.hands or p.hands[hand]) and (not p.kinds or p.kinds[kind]) and f.t >= p.ready then
			local chance = p.chance
			if p.ppm then
				local w = f.p[hand == "OH" and "oh" or "mh"]
				chance = p.ppm * w.speed / 60
			end
			if random() < chance then
				if p.icd then p.ready = f.t + p.icd end
				p.fn(f, hand)
			end
		end
	end
end

function Fight:AddSpell(s)
	s.gcd = s.gcd or 1
	self.spells[s.name] = s
	return s
end

function Fight:Cost(s)
	local c = s.costFn and s.costFn(self) or (s.cost or 0)
	if self.costMod then c = self.costMod(self, s, c) end
	return max(0, c)
end

function Fight:CanCast(s, ignoreEnergy)
	if s.gcd > 0 and self.t < self.gcdAt - 1e-9 then return false end
	if s.cd and not self:Ready(s.name) then return false end
	if s.usable and not s.usable(self) then return false end
	if not ignoreEnergy and self:Cost(s) > self:Energy() + 1e-9 then return false end
	return true
end

function Fight:Cast(s)
	local cost = self:Cost(s)
	self:SpendEnergy(cost)
	if s.cd then self:StartCD(s.name, s.cd) end
	if s.gcd > 0 then
		self.gcdAt = self.t + s.gcd
		self:At(self.gcdAt, self.Decide)
	end
	self:Count(s.name)
	for i = 1, #self.onCast do self.onCast[i](self, s, cost) end
	s.cast(self, cost)
end

function Fight:Refund(cost, part) self:AddEnergy(cost * (part or 0.8)) end

function Fight:Decide()
	if self.t >= self.endT then return end
	for _ = 1, 8 do
		local cast = false
		for i = 1, #self.rules do
			local r = self.rules[i]
			local s = self.spells[r.spell]
			if s and self:CanCast(s) and (not r.minEnergy or self:Energy() >= r.minEnergy - 1e-9) and (not r.when or r.when(self)) then
				self:Cast(s)
				cast = true
				break
			end
		end
		if not cast then break end
	end

	if self.t >= self.gcdAt - 1e-9 then
		local wait = huge
		local e = self:Energy()
		local rate = self.regen * self.regenMult
		for i = 1, #self.rules do
			local r = self.rules[i]
			local s = self.spells[r.spell]
			if s and (not s.usable or s.usable(self)) and (not r.when or r.when(self)) then
				local w = s.cd and self:CDLeft(s.name) or 0
				if not self.cfg.energyTicks then
					local need = max(self:Cost(s), r.minEnergy or 0) - e
					if need > 0 then w = max(w, need / rate) end
				end
				if w > 0 then wait = min(wait, w) end
			end
		end
		if wait < huge then
			self:Cancel(self.wake)
			self.wake = self:After(wait + 1e-6, self.Decide)
		end
	end
end

local function EnergyTick(f)
	f.energy = min(f.maxEnergy, f.energy + 20.2 * f.regenMult)
	f:After(2.02, EnergyTick)
end

function Fight:Run(duration)
	self.t = 0
	self.endT = duration
	self.queue = {}
	self.auras, self.cds, self.dots = {}, {}, {}
	self.dmg, self.casts = {}, {}
	self.total = 0
	self.swings, self.lastSwing = {}, {}

	self.speedMult = 1
	self.apBonus = 0
	self.critAll = 0
	self.gcdAt = 0
	self.cp = 0
	self.maxEnergy = self.p.maxEnergy or 100
	self.energy = self.maxEnergy
	self.eT = 0
	self.regen = self.p.energyRegen or 10
	self.regenMult = 1
	self.autos = false
	for _, p in ipairs(self.procs) do p.ready = 0 end
	local class = Sim.Classes[self.p.class]
	if class and class.Reset then class.Reset(self) end
	if self.cfg.energyTicks then self:At(2.02 * random(), EnergyTick) end
	if not self.noAutosAtStart then self:StartAutos() end
	self:Decide()
	local q = self.queue
	while true do
		local e = PopNext(q)
		if not e or e.at > duration then break end
		self.t = e.at
		e.fn(self, e.arg)
		if self.t >= self.gcdAt - 1e-9 then self:Decide() end
	end
	self.t = duration
	return self.total / duration
end

Sim.Items = {
	[11815] = function(f)
		f:AddProc({ chance = 0.02, icd = 2, fn = function(x) x:ExtraAttack("Hand of Justice") end })
	end,
}
Sim.WeaponItems = {
	[17705] = function(f, hand)
		f:AddProc({ hands = { [hand] = true }, ppm = 1, fn = function(x) x:ExtraAttack("Thrash Blade") end })
	end,
}
Sim.Enchants = {
	[803] = function(f, hand)
		f:AddProc({ hands = { [hand] = true }, ppm = 6, fn = function(x) x:SpellHit({ src = "Fiery Weapon", dmg = 40, school = "fire" }) end })
	end,
	[1900] = function(f, hand)
		f:AddProc({ hands = { [hand] = true }, ppm = 1, fn = function(x)
			local key = "Crusader " .. hand
			if not x:AuraUp(key) then x.apBonus = (x.apBonus or 0) + 100 * (x.p.apPerStr or 1) end
			x:AuraOn(key, 15, nil, function(y) y.apBonus = (y.apBonus or 0) - 100 * (y.p.apPerStr or 1) end)
		end })
	end,
}

local function Gear(f)
	local p = f.p
	for _, id in ipairs(p.items or {}) do
		if Sim.Items[id] then Sim.Items[id](f) end
	end
	for _, hand in ipairs({ "MH", "OH" }) do
		local w = p[hand == "MH" and "mh" or "oh"]
		if w then
			if w.id and Sim.WeaponItems[w.id] then Sim.WeaponItems[w.id](f, hand) end
			if w.enchant and Sim.Enchants[w.enchant] then Sim.Enchants[w.enchant](f, hand) end
		end
	end
end

local function Finish(f)
	Gear(f)
	f.onLand[#f.onLand + 1] = function(fight, hand, kind) RunProcs(fight, hand, kind) end
end

function Sim.NewFightFor(cfg)
	if cfg.spellHitFromMelee == nil and not cfg.parity then cfg.spellHitFromMelee = true end
	local f = Sim.NewFight(cfg)
	Finish(f)
	return f
end

function Sim.Run(cfg)
	local f = Sim.NewFightFor(cfg)
	local n = cfg.iterations or 1000
	local sum, sum2 = 0, 0
	local dmg, casts = {}, {}
	local secs = 0
	for _ = 1, n do
		local d = cfg.duration or 60
		if cfg.variation and cfg.variation > 0 then d = d - cfg.variation + 2 * cfg.variation * random() end
		local dps = f:Run(d)
		sum, sum2 = sum + dps, sum2 + dps * dps
		secs = secs + d
		for k, v in pairs(f.dmg) do dmg[k] = (dmg[k] or 0) + v end
		for k, v in pairs(f.casts) do casts[k] = (casts[k] or 0) + v end
	end
	local mean = sum / n
	local sd = sqrt(max(0, sum2 / n - mean * mean))
	local total = 0
	for _, v in pairs(dmg) do total = total + v end
	local rows = {}
	local seen = {}
	for k, v in pairs(dmg) do
		rows[#rows + 1] = { src = k, dps = v / secs, share = total > 0 and v / total or 0, casts = (casts[k] or 0) / n, perCast = casts[k] and v / casts[k] or nil }
		seen[k] = true
	end
	for k, v in pairs(casts) do
		if not seen[k] then rows[#rows + 1] = { src = k, dps = 0, share = 0, casts = v / n } end
	end
	table.sort(rows, function(a, b) if a.dps ~= b.dps then return a.dps > b.dps end return a.src < b.src end)
	return { dps = mean, ci = 1.96 * sd / sqrt(n), rows = rows }
end

return Sim
