local _, KUI = ...
local L = KUI.Lift
local Sim = KUI.Sim
if not L or not Sim then return end

local Plain, PlainNumber, Call = L.Plain, L.PlainNumber, L.Call

local LENGTHS = { 15, 30, 60, 120 }
local FIGHTS = 400
local SLICE = 0.008

Sim.Targets = {
	boss = { name = "a boss (level 63, 3731 armor)", level = 63, armor = 3731, type = "Humanoid" },
	trash = { name = "open-world mobs (level 61, 3000 armor)", level = 61, armor = 3000, type = "Humanoid" },
}

local WEAPON_TYPES = { [0] = "Axe", [1] = "Axe", [4] = "Mace", [5] = "Mace", [7] = "Sword", [8] = "Sword",
	[15] = "Dagger", [13] = "Fist", [6] = "Polearm", [10] = "Staff", [2] = "Bow", [3] = "Gun", [18] = "Crossbow" }
local TWO_HAND = { [1] = true, [5] = true, [8] = true, [6] = true, [10] = true }

local POISONS = {
	[323] = "instant", [324] = "instant", [325] = "instant", [623] = "instant", [624] = "instant", [625] = "instant",
	[7] = "deadly", [8] = "deadly", [626] = "deadly", [627] = "deadly", [2630] = "deadly",
}

local function Weapon(slot, ap, damageMin, damageMax, speed, offhand, dws)
	local link = Plain(Call(GetInventoryItemLink, "player", slot))
	if type(link) ~= "string" or not damageMin or not speed or speed <= 0 then return nil end
	local id = tonumber(link:match("item:(%d+)"))
	local enchant = tonumber(link:match("item:%d+:(%d*)") or "")
	local _, _, _, _, _, classID, subclassID = Call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, id)
	classID, subclassID = PlainNumber(classID), PlainNumber(subclassID)
	if classID ~= 2 then return nil end

	local scale = offhand and (0.5 * dws) or 1
	local apPart = ap * speed / 14
	return {
		id = id, enchant = enchant, speed = speed,
		type = WEAPON_TYPES[subclassID] or "OneHand", twoHand = TWO_HAND[subclassID] or false,
		min = math.max(0, damageMin / scale - apPart), max = math.max(0, damageMax / scale - apPart),
	}
end

function L:SimPlayer()
	if self:InCombat() then return nil, "Leave combat first: your stats are hidden from addons during a fight." end
	local _, class = Call(UnitClass, "player")
	class = Plain(class)
	if not Sim.Classes[class] then
		return nil, "There's no simulator for your class yet. The rogue is first; warrior and hunter are next."
	end
	local talents = self:Talents()
	local base, pos, neg = Call(UnitAttackPower, "player")
	local ap = (PlainNumber(base) or 0) + (PlainNumber(pos) or 0) + (PlainNumber(neg) or 0)
	local mhMin, mhMax, ohMin, ohMax = Call(UnitDamage, "player")
	local mhSpeed, ohSpeed = Call(UnitAttackSpeed, "player")
	local dws = 1 + 0.25 * (talents["Dual Wield Specialization"] or 0)
	local p = {
		class = class,
		level = PlainNumber((Call(UnitLevel, "player"))) or 60,
		ap = ap,
		crit = PlainNumber((Call(GetCritChance))) or 5,
		hit = PlainNumber((Call(GetHitModifier))) or 0,
		spellHit = PlainNumber((Call(GetSpellHitModifier))) or 0,
		spellCrit = PlainNumber((Call(GetSpellCritChance, 4))) or 0,
		expertise = PlainNumber((Call(GetExpertise))) or 0,
		energyRegen = self:EnergyRegen() or 10,
		maxEnergy = 100,
		talents = talents,
		items = {},
		poisons = {},
		build = {},
	}
	p.mh = Weapon(16, ap, PlainNumber(mhMin), PlainNumber(mhMax), PlainNumber(mhSpeed), false, dws)
	p.oh = Weapon(17, ap, PlainNumber(ohMin), PlainNumber(ohMax), PlainNumber(ohSpeed), true, dws)
	if not p.mh then return nil, "Equip a weapon first." end
	for slot = 1, 18 do
		local id = PlainNumber((Call(GetInventoryItemID, "player", slot)))
		if id then p.items[#p.items + 1] = id end
	end
	local hasMH, _, _, mhEnchant, hasOH, _, _, ohEnchant = Call(GetWeaponEnchantInfo)
	p.notes = {}
	local function Poison(has, id, hand)
		if Plain(has) ~= true then return end
		id = PlainNumber(id)
		local kind = id and POISONS[id]
		if not kind then
			kind = "instant"
			p.notes[#p.notes + 1] = string.format("%s temporary enchant %s taken as Instant Poison", hand, tostring(id))
		end
		p.poisons[hand] = kind
	end
	Poison(hasMH, mhEnchant, "MH")
	if p.oh then Poison(hasOH, ohEnchant, "OH") end

	local db = self:DB()
	p.build.swapDagger = not (db and db.simNoSwap)
	return p
end

local job

local function Line(row, cols)
	local out = { string.format("%-32s", row) }
	for _, c in ipairs(cols) do out[#out + 1] = string.format("%8s", c) end
	return table.concat(out, "")
end

local function Finish(j)
	local out = {}
	out[#out + 1] = string.format("K-Lift sim %s: rotation DPS against %s, %d fights each", tostring(Plain(Call(date, "%Y-%m-%d %H:%M"))), j.target.name, FIGHTS)
	local p = j.player
	out[#out + 1] = string.format("Your character: %s, %d attack power, %.2f%% crit, %.2f%% hit, expertise %s", p.class, p.ap, p.crit, p.hit, tostring(p.expertise))
	out[#out + 1] = string.format("Main hand %s %.2f s%s", p.mh.type, p.mh.speed, p.oh and string.format(", off hand %s %.2f s", p.oh.type, p.oh.speed) or "")
	for _, n in ipairs(p.notes or {}) do out[#out + 1] = "Note: " .. n end
	out[#out + 1] = ""
	local head = {}
	for _, l in ipairs(LENGTHS) do head[#head + 1] = l .. " s" end
	out[#out + 1] = Line("Fight length", head)
	local best = {}
	for li in ipairs(LENGTHS) do
		local b
		for ri = 1, #j.rotations do
			if not b or j.results[ri][li] > j.results[b][li] then b = ri end
		end
		best[li] = b
	end
	for ri, r in ipairs(j.rotations) do
		local cols = {}
		for li in ipairs(LENGTHS) do
			cols[li] = string.format("%.0f%s", j.results[ri][li], best[li] == ri and "*" or " ")
		end
		out[#out + 1] = Line(r.name, cols)
	end
	out[#out + 1] = ""
	out[#out + 1] = "* best at that length. Differences under about 2% are within the noise of this many fights."
	out[#out + 1] = "Rotation DPS: big cooldowns are only used where WoWSims would (Blade Flurry only if another one fits)."
	j.done(table.concat(out, "\n"))
end

local function Step()
	local j = job
	if not j then return end
	if L:InCombat() then
		job = nil
		j.done(nil, "Stopped: you entered combat. Run /kl sim again afterwards.")
		return
	end
	local t0 = debugprofilestop and debugprofilestop() or 0
	repeat
		local r = j.rotations[j.ri]
		local len = LENGTHS[j.li]
		if not j.fight then
			j.player.rotation = r.key
			j.fight = Sim.NewFightFor({ player = j.player, target = j.target })
			j.sum, j.n = 0, 0
		end
		local d = len - len / 10 + 2 * (len / 10) * math.random()
		j.sum = j.sum + j.fight:Run(d)
		j.n = j.n + 1
		if j.n >= FIGHTS then
			j.results[j.ri][j.li] = j.sum / j.n
			j.fight = nil
			j.li = j.li + 1
			if j.li > #LENGTHS then
				j.li = 1
				j.ri = j.ri + 1
				if j.ri > #j.rotations then
					job = nil
					Finish(j)
					return
				end
			end
		end
	until not debugprofilestop or (debugprofilestop() - t0) / 1000 > SLICE
	C_Timer.After(0, Step)
end

function L:RunSim(targetKey, done)
	if job then return false, "A sim is already running." end
	local p, why = self:SimPlayer()
	if not p then return false, why end
	local target = Sim.Targets[targetKey] or Sim.Targets.boss
	local class = Sim.Classes[p.class]
	local rotations = class.RotationsFor and class.RotationsFor(p) or {}
	if #rotations == 0 then return false, "No rotations to sim for this build." end
	local results = {}
	for i = 1, #rotations do results[i] = {} end
	job = { player = p, target = target, rotations = rotations, results = results, ri = 1, li = 1, done = done }
	C_Timer.After(0, Step)
	return true, string.format("simming %d rotations at %d fight lengths against %s...", #rotations, #LENGTHS, target.name)
end

function L:SimRunning() return job ~= nil end
