local _, KUI = ...
if type(KUI) ~= "table" then KUI = {} end
local Sim = KUI.Sim
if not Sim then return end

local random = math.random

local R = {}
Sim.Classes.ROGUE = R

local function T(f, name) return (f.p.talents and f.p.talents[name]) or 0 end
local function B(f, name) return f.p.build and f.p.build[name] end
local function IsDagger(w) return w ~= nil and w.type == "Dagger" end

local function Swapped(f, ambush)
	if B(f, "swapAmbushOnly") and not ambush then return false end
	return B(f, "swapDagger") and not IsDagger(f.p.mh) and IsDagger(f.p.oh)
end

local function DaggerForSpecials(f, ambush)
	return IsDagger(f.p.mh) or Swapped(f, ambush)
end

local function SpecialWeaponDamage(f, normalized, ambush)
	if Swapped(f, ambush) then

		return f:WeaponDamage("OH", normalized) / f.offhandMult
	end
	return f:WeaponDamage("MH", normalized)
end

local function Stealthed(f) return f.stealth end

local function BreakStealth(f)
	if f.stealth then
		f.stealth = false
		f:StartAutos()
	end
end

local function CanOpen(f)
	if f.stealth then return true end
	return f:AuraUp("Ghostly Opening")
end

local function UseOpening(f)
	if not f.stealth and not f.cfg.parity then f:AuraOff("Ghostly Opening") end
end

local function OnFinisher(f, cp)
	local rs = T(f, "Relentless Strikes")
	if rs > 0 and random() < 0.2 * cp then f:AddEnergy(25) end
	local ruth = T(f, "Ruthlessness")
	if ruth > 0 and random() < 0.2 * ruth then f.cp = 1 else f.cp = 0 end
end

local function Builder(f, outcome, cost, cps)
	if f:Landed(outcome) then
		f:AddCP(cps or 1)
		if outcome == "crit" then
			local sf = T(f, "Seal Fate")
			if sf > 0 and f.t >= (f.sealFateReady or 0) and random() < 0.2 * sf then
				f:AddCP(1)
				f.sealFateReady = f.t + 0.5
			end
		end
		return true
	end
	f:Refund(cost)
	return false
end

local function Initiative(f, outcome)
	local r = T(f, "Initiative")
	if r > 0 and f:Landed(outcome) and random() < r / 3 then f:AddCP(1) end
end

local function ColdBlood(f)
	if f:AuraUp("Cold Blood") then
		f:AuraOff("Cold Blood")
		return 100
	end
	return 0
end

local function Lethality(f) return 2 + 0.06 * T(f, "Lethality") end

function R.Setup(f)
	local p = f.p

	local hs = T(f, "Hack and Slash")
	f.critBonus.MH, f.critBonus.OH = 0, 0
	if hs > 0 then
		local mhDagger = p.mh and (p.mh.type == "Dagger" or p.mh.type == "Fist")
		local ohDagger = p.oh and (p.oh.type == "Dagger" or p.oh.type == "Fist")
		if ohDagger and not mhDagger then f.critBonus.OH = hs end
		if mhDagger and p.oh and not ohDagger then f.critBonus.OH = -hs end
		if p.mh and (p.mh.type == "Sword" or p.mh.type == "Axe") then
			f:AddProc({ hands = { MH = true }, chance = 0.01 * hs, icd = 0.2,
				fn = function(fight) fight:ExtraAttack("Hack and Slash") end })
		end
		if p.oh and (p.oh.type == "Sword" or p.oh.type == "Axe") then
			f:AddProc({ hands = { OH = true }, chance = 0.01 * hs, icd = 0.2,
				fn = function(fight) fight:ExtraAttack("Hack and Slash") end })
		end
	end
	f.armorPenPct = 0.03 * T(f, "Serrated Blades")
	local dws = 1 + 0.25 * T(f, "Dual Wield Specialization")
	f.whiteOHMult = dws
	f.dws = dws
	if T(f, "Murder") > 0 and (f.tgt.type == "Humanoid" or f.tgt.type == "Giant") then
		f.dmgMult = f.dmgMult * (1 + 0.02 * T(f, "Murder"))
	end

	local ipChance = 0.2 + 0.02 * T(f, "Improved Poisons")
	local vile = 1 + 0.04 * T(f, "Vile Poisons")
	for _, hand in ipairs({ "MH", "OH" }) do
		if p.poisons and p.poisons[hand] == "instant" then
			f:AddProc({ hands = { [hand] = true }, chance = ipChance,
				fn = function(fight)
					local mult = vile
					if fight:AuraUp("Venom") then mult = mult * 1.3 end
					fight:SpellHit({ src = "Instant Poison", dmg = 112 + 36 * random(), school = "nature", mult = mult })
				end })
		end
	end

	local cut = 10 + 5 * T(f, "Composure")
	f.costMod = function(fight, s, c)
		if fight.poised and c > 0 and s.energy ~= false then return c - cut end
		return c
	end
	f.onCast[#f.onCast + 1] = function(fight, s)
		if fight.poised and s.energy ~= false and ((s.costFn and s.costFn(fight)) or s.cost or 0) > 0 then fight.poised = false end
	end

	R.Spells(f)
	R.Rotation(f, p.rotation or "auto")
end

function R.Reset(f)
	f.cp = 0
	f.poised = true
	f.sealFateReady = 0
	f.stealth = false
	f.noAutosAtStart = false
	if B(f, "startStealthed") or f.rotStealth then
		f.stealth = true
		f.noAutosAtStart = true
	end
end

function R.Spells(f)
	local opp = 1 + 0.02 * T(f, "Opportunity")
	local es = T(f, "Efficient Strikes")

	f:AddSpell({ name = "Ambush", cost = 60,
		usable = function(fight)
			if not DaggerForSpecials(fight, true) and not B(fight, "ambushAnyWeapon") then return false end
			return CanOpen(fight) and not fight.tgt.front
		end,
		cast = function(fight, cost)
			UseOpening(fight)
			BreakStealth(fight)
			local dmg = 116 + SpecialWeaponDamage(fight, true, true)
			local o = fight:Strike({ src = "Ambush", count = false, hand = "MH", dmg = dmg, mult = 2.5 * opp,
				noDodge = true, noParry = true, noBlock = true,
				critBonus = 15 * T(fight, "Improved Ambush") + ColdBlood(fight) })
			Builder(fight, o, cost)
			Initiative(fight, o)
		end })

	f:AddSpell({ name = "Garrote", cost = 50 - 10 * T(f, "Dirty Deeds"),
		usable = function(fight) return CanOpen(fight) and (not fight.tgt.front or T(fight, "Dirty Deeds") > 0) end,
		cast = function(fight, cost)
			UseOpening(fight)
			BreakStealth(fight)
			local o = fight:Strike({ src = "Garrote", count = false, hand = "MH", dmg = 0, noDodge = true, noParry = true, noBlock = true, noCrit = true })
			if Builder(fight, o, cost) then
				local bleed = fight:AuraUp("Hemorrhage") and 1.15 or 1
				local tick = (92 + fight:AP() * 0.03) * bleed * opp * fight.dmgMult
				fight:Dot({ src = "Garrote", tick = tick, ticks = 6, every = 3 })
			end
			Initiative(fight, o)
		end })

	if T(f, "Ghostly Strike") > 0 then
		f:AddSpell({ name = "Ghostly Strike", cost = 40, cd = 20,
			cast = function(fight, cost)
				BreakStealth(fight)
				local mult = DaggerForSpecials(fight, false) and 1.8 or 1.25
				local o = fight:Strike({ src = "Ghostly Strike", count = false, hand = "MH", dmg = SpecialWeaponDamage(fight, false, false),
					mult = mult, critMult = Lethality(fight) })
				fight:AuraOn("Ghostly Opening", 7)
				Builder(fight, o, cost)
			end })
	end

	if T(f, "Hemorrhage") > 0 then
		f:AddSpell({ name = "Hemorrhage", cost = 35 - 2.5 * es,
			cast = function(fight, cost)
				BreakStealth(fight)
				local mult = DaggerForSpecials(fight, false) and 1.45 or 1
				local o = fight:Strike({ src = "Hemorrhage", count = false, hand = "MH", dmg = SpecialWeaponDamage(fight, false, false),
					mult = mult, critMult = Lethality(fight) })
				if Builder(fight, o, cost) then fight:AuraOn("Hemorrhage", 15) end
			end })
	end

	f:AddSpell({ name = "Sinister Strike", cost = ({ [0] = 45, 42, 40 })[T(f, "Improved Sinister Strike")] - 2.5 * es,
		cast = function(fight, cost)
			BreakStealth(fight)
			local o = fight:Strike({ src = "Sinister Strike", count = false, hand = "MH", dmg = 68 + fight:WeaponDamage("MH", true),
				mult = 1 + 0.02 * T(fight, "Aggression"), critMult = Lethality(fight), critBonus = ColdBlood(fight) })
			Builder(fight, o, cost)
		end })

	f:AddSpell({ name = "Backstab", cost = 60,
		usable = function(fight) return IsDagger(fight.p.mh) and not fight.tgt.front end,
		cast = function(fight, cost)
			BreakStealth(fight)
			local o = fight:Strike({ src = "Backstab", count = false, hand = "MH", dmg = 150 + fight:WeaponDamage("MH", true),
				mult = 1.5 * opp, critMult = Lethality(fight),
				critBonus = 10 * T(fight, "Improved Backstab") + ColdBlood(fight) })
			Builder(fight, o, cost)
		end })

	f:AddSpell({ name = "Eviscerate",
		costFn = function(fight) return 35 - (T(fight, "Flawless Execution") > 0 and 15 or 0) end,
		usable = function(fight) return fight.cp > 0 end,
		cast = function(fight)
			BreakStealth(fight)
			local cp = fight.cp
			local base = 54 + 170 * cp
			local dmg = base + 108 * random() + 0.03 * cp * fight:AP()
			local mult = 1 + 0.05 * T(fight, "Improved Eviscerate") + 0.02 * T(fight, "Aggression") + 0.2 * T(fight, "Coup de Grace") / 3
			local o = fight:Strike({ src = "Eviscerate", count = false, hand = "MH", dmg = dmg, mult = mult, critBonus = ColdBlood(fight) })
			if fight:Landed(o) then OnFinisher(fight, cp) end
		end })

	local sndHaste = 1.3
	local sndMult = 1 + 0.05 * T(f, "Improved Slice and Dice")
	f:AddSpell({ name = "Slice and Dice", cost = 25,
		usable = function(fight) return fight.cp > 0 end,
		cast = function(fight)
			BreakStealth(fight)
			local cp = fight.cp
			fight:AuraOn("Slice and Dice", (6 + 3 * cp) * sndMult,
				function(x) x:MultiplySpeed(sndHaste) end,
				function(x) x:MultiplySpeed(1 / sndHaste) end)
			OnFinisher(fight, cp)
		end })

	f:AddSpell({ name = "Rupture", cost = 25,
		usable = function(fight) return fight.cp > 0 end,
		cast = function(fight)
			BreakStealth(fight)
			local cp = fight.cp
			local o = fight:Strike({ src = "Rupture", count = false, hand = "MH", dmg = 0, noCrit = true })
			if fight:Landed(o) then
				local apc = ({ 0.04 / 4, 0.10 / 5, 0.18 / 6, 0.21 / 7, 0.24 / 8 })[cp]
				local bleed = fight:AuraUp("Hemorrhage") and 1.15 or 1
				local tick = (60 + 8 * cp + apc * fight:AP()) * (1 + 0.1 * T(fight, "Serrated Blades")) * bleed * fight.dmgMult
				fight:Dot({ src = "Rupture", tick = tick, ticks = 3 + cp, every = 2 })
				OnFinisher(fight, cp)
			end
		end })

	if f.dw then
		local fos = T(f, "Flash of Steel")
		f:AddSpell({ name = "Shank", cost = 5, cd = 10 - 0.5 * fos,
			cast = function(fight)
				BreakStealth(fight)
				fight:Strike({ src = "Shank", count = false, hand = "OH", dmg = fight:WeaponDamage("OH"), mult = 0.5 * fight.dws,
					noMiss = true, noDodge = true, noParry = true, critMult = Lethality(fight) })
				fight:AddEnergy(25 + 3 * fos)
				local bk = T(fight, "Boot Knife")
				if bk > 0 and random() < 0.2 * bk then fight:AddCP(2) end
				if T(fight, "Venom") > 0 then fight:AuraOn("Venom", 6) end
			end })
	end

	if T(f, "Premeditation") > 0 then
		f:AddSpell({ name = "Premeditation", cost = 0, gcd = 0, cd = 120, energy = false,
			usable = Stealthed,
			cast = function(fight) fight:AddCP(2) end })
	end
	if T(f, "Blade Flurry") > 0 then
		f:AddSpell({ name = "Blade Flurry", cost = 25, cd = 120,
			cast = function(fight)
				BreakStealth(fight)
				fight:AuraOn("Blade Flurry", 15, function(x) x:MultiplySpeed(1.2) end, function(x) x:MultiplySpeed(1 / 1.2) end)
			end })
	end
	if T(f, "Adrenaline Rush") > 0 then
		f:AddSpell({ name = "Adrenaline Rush", cost = 0, cd = 300, energy = false,
			cast = function(fight)
				fight:AuraOn("Adrenaline Rush", 15, function(x) x:SetRegenMult(2) end, function(x) x:SetRegenMult(1) end)
			end })
	end
	if T(f, "Cold Blood") > 0 then
		f:AddSpell({ name = "Cold Blood", cost = 0, gcd = 0, cd = 180, energy = false,
			cast = function(fight) fight:AuraOn("Cold Blood", 600) end })
	end
end

local function E(f) return f:Energy() end

local function Cooldowns()
	return {
		{ spell = "Blade Flurry", when = function(f) return (f.endT - f.t) > 135 or f:AuraLeft("Slice and Dice") >= 1 end },
		{ spell = "Adrenaline Rush" },
		{ spell = "Cold Blood" },
		{ spell = "Premeditation" },
	}
end

local function Join(...)
	local out = {}
	for _, list in ipairs({ ... }) do for _, r in ipairs(list) do out[#out + 1] = r end end
	return out
end

local SHANK_LOW = { spell = "Shank", when = function(f) return E(f) < 40 end }
local EVISC5 = { spell = "Eviscerate", when = function(f) return f.cp >= 5 end }
local AMBUSH = { spell = "Ambush" }
local GHOSTLY_AMBUSH = { spell = "Ghostly Strike", minEnergy = 80 }

local HEMO_SPARE = { spell = "Hemorrhage", when = function(f) return f:CDLeft("Ghostly Strike") > 4 end }
local HEMO_FULL = { spell = "Hemorrhage", minEnergy = 95 }

R.Rotations = {

	hemo = { name = "Hemorrhage only", rules = Join(Cooldowns(), { SHANK_LOW, EVISC5, { spell = "Hemorrhage" } }) },
	ghostly = { name = "Ghostly Strike on cooldown", rules = Join(Cooldowns(), { SHANK_LOW, EVISC5, { spell = "Ghostly Strike" }, { spell = "Hemorrhage" } }) },
	ghostlyAmbush = { name = "Ghostly Strike > Ambush", rules = Join(Cooldowns(), { SHANK_LOW, EVISC5, AMBUSH, GHOSTLY_AMBUSH, HEMO_SPARE, HEMO_FULL }) },
	ambushOpener = { name = "Ambush opener", stealth = true, rules = Join(Cooldowns(), { SHANK_LOW, EVISC5, AMBUSH, GHOSTLY_AMBUSH, HEMO_SPARE, HEMO_FULL }) },
	garroteOpener = { name = "Garrote opener", stealth = true, rules = Join({ { spell = "Garrote", when = function(f) return f.stealth end } }, Cooldowns(), { SHANK_LOW, EVISC5, AMBUSH, GHOSTLY_AMBUSH, HEMO_SPARE, HEMO_FULL }) },

	combat = { name = "Sinister Strike, Slice and Dice", rules = Join(Cooldowns(), {
		{ spell = "Slice and Dice", when = function(f) return f:AuraLeft("Slice and Dice") < 1 and f.cp >= 2 end },
		SHANK_LOW, EVISC5, { spell = "Sinister Strike" } }) },
	daggers = { name = "Backstab, Slice and Dice", rules = Join(Cooldowns(), {
		{ spell = "Slice and Dice", when = function(f) return f:AuraLeft("Slice and Dice") < 1 and f.cp >= 2 end },
		SHANK_LOW, EVISC5, { spell = "Backstab" } }) },
}

function R.RotationsFor(p)
	local t = p.talents or {}
	local dagger = IsDagger(p.mh) or (p.build and p.build.swapDagger and IsDagger(p.oh))
	local keys
	if (t["Hemorrhage"] or 0) > 0 and (t["Ghostly Strike"] or 0) > 0 then
		keys = { "hemo", "ghostly", "ghostlyAmbush", "ambushOpener", "garroteOpener" }
	elseif (t["Hemorrhage"] or 0) > 0 then
		keys = { "hemo", "ambushOpener", "garroteOpener" }
	elseif IsDagger(p.mh) then
		keys = { "daggers", "combat", "ambushOpener", "garroteOpener" }
	else
		keys = { "combat", "garroteOpener" }
	end
	local out = {}
	for _, k in ipairs(keys) do
		if k ~= "ambushOpener" or dagger then out[#out + 1] = { key = k, name = R.Rotations[k].name } end
	end
	return out
end

function R.Rotation(f, key)
	if key == "auto" then
		if T(f, "Hemorrhage") > 0 then key = "hemo"
		elseif IsDagger(f.p.mh) and not f.tgt.front then key = "daggers"
		else key = "combat" end
	end
	local rot = R.Rotations[key] or R.Rotations.combat
	f.rules = rot.rules

	if rot.stealth and T(f, "Hemorrhage") == 0 then
		local base = (IsDagger(f.p.mh) and not f.tgt.front) and R.Rotations.daggers or R.Rotations.combat
		local first = key == "garroteOpener" and { { spell = "Garrote", when = function(x) return x.stealth end } } or { AMBUSH }
		f.rules = Join(first, base.rules)
	end
	f.rotationName = rot.name
	f.rotStealth = rot.stealth
end

return R
