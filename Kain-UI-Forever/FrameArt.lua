local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_ART = MEDIA .. "PlayerFrameOld"
local TEX_W, TEX_H = 512, 128

local ART = {
	player   = { x = 0,   y = 0,  w = 198, h = 74, cx = 36.40,  cy = 37.31, scale = 1 },
	level    = { x = 200, y = 0,  w = 37,  h = 37, cx = 18.49,  cy = 18.45, scale = 1 },
	ring     = { x = 200, y = 40, w = 32,  h = 34, cx = 15.43,  cy = 15.48, scale = 0.955 },
	ringFill = { x = 200, y = 0,  w = 37,  h = 37, cx = 18.49,  cy = 18.45, scale = 0.80 },
	Alliance = { x = 200, y = 76, w = 20,  h = 25, cx = 10,     cy = 12.5,  scale = 0.8 },
	Horde    = { x = 222, y = 76, w = 23,  h = 25, cx = 11.5,   cy = 12.5,  scale = 0.8 },
	target   = { x = 240, y = 0,  w = 194, h = 69, cx = 157.59, cy = 33.93, scale = 1 },
	cap      = { x = 440, y = 0,  w = 64,  h = 66, cx = 31.59,  cy = 32.93, scale = 1 },
	party    = { x = 240, y = 72, w = 119, h = 46, cx = 23.38,  cy = 22.40, scale = 1 },
}
local MAX_SHIFT = 15

local function Dig(root, ...)
	local node = root
	for i = 1, select("#", ...) do
		if type(node) ~= "table" then return nil end
		node = node[(select(i, ...))]
	end
	return type(node) == "table" and node or nil
end

local function PlayerParts(pf)
	local container = Dig(pf, "PlayerFrameContainer")
	local main = Dig(pf, "PlayerFrameContent", "PlayerFrameContentMain")
	local contextual = Dig(pf, "PlayerFrameContent", "PlayerFrameContentContextual")
	local health = (type(PlayerFrame_GetHealthBar) == "function" and select(2, pcall(PlayerFrame_GetHealthBar)))
	if type(health) ~= "table" then health = Dig(main, "HealthBarsContainer", "HealthBar") end
	local mana = KUI.FindPlayerManaBar and KUI.FindPlayerManaBar()
	if type(mana) ~= "table" then mana = Dig(main, "ManaBarArea", "ManaBar") end
	local healthContainer = Dig(main, "HealthBarsContainer") or (health and health.GetParent and health:GetParent())
	local pvpIcon = Dig(main, "PvpBackgroundIcon")
	return {
		holder = container,
		portrait = Dig(container, "PlayerPortrait"),
		frameTexture = Dig(container, "FrameTexture"),
		hide = {
			Dig(container, "FrameTexture"), Dig(container, "AlternatePowerFrameTexture"), Dig(container, "FrameFlash"),
			Dig(main, "StatusTexture"), Dig(contextual, "PlayerPortraitCornerIcon"),
			Dig(main, "LevelBackgroundCircle"), pvpIcon,
		},
		pvpIcon = pvpIcon,
		health = health, healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = mana, manaMask = Dig(mana, "ManaBarMask"),
		name = Dig(main, "PlayerName") or _G.PlayerName,
	}
end

local function TargetParts(tf)
	local container = Dig(tf, "TargetFrameContainer")
	local main = Dig(tf, "TargetFrameContent", "TargetFrameContentMain")
	local healthContainer = Dig(main, "HealthBarsContainer")
	local mana = Dig(main, "ManaBar")
	return {
		holder = container,
		portrait = Dig(container, "Portrait"),
		frameTexture = Dig(container, "FrameTexture"),
		hide = { Dig(container, "FrameTexture"), Dig(container, "Flash"), Dig(main, "LevelBackgroundCircle") },
		health = Dig(healthContainer, "HealthBar"), healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = mana, manaMask = Dig(mana, "ManaBarMask"),
		name = Dig(main, "Name"),
		band = Dig(main, "ReputationColor"),
	}
end

local function PartyParts(member)
	local healthContainer = Dig(member, "HealthBarContainer")
	local mana = Dig(member, "manabar")
	return {
		holder = member,
		portrait = Dig(member, "portrait"),
		frameTexture = Dig(member, "Texture"),
		hide = { Dig(member, "Texture"), Dig(member, "Flash"), Dig(member, "PartyMemberOverlay", "Status") },
		health = Dig(healthContainer, "HealthBar"), healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = mana, manaMask = Dig(mana, "ManaBarMask"),
		name = Dig(member, "name"),
	}
end

local TARGET_LAYOUT = {
	piece = "target", portrait = 58, cap = true,
	bars = { left = -152 },
	health = { w = 126, cw = 122, h = 28.5, mid = -2.57 },
	mana = { w = 128, mid = -18.57 },
	name = { -150.2, 15.43 },
	band = { -152, 21.93, -26, 8.93 },
	level = { 22.99, -25.32 },
}
local PARTY_LAYOUT = {
	piece = "party", portrait = 37,
	bars = { left = 22.8 },
	health = { w = 66, cw = 66, mid = 0.9 },
	mana = { w = 66, mid = -8.6 },
	name = { 21.8, 12.7 },
}

local FRAMES = {
	{
		key = "player", root = function() return _G.PlayerFrame end, parts = PlayerParts,
		layout = {
			piece = "player", portrait = 60,
			bars = { left = 31.6 },
			health = { w = 127.5, cw = 127.5, h = 28, mid = -0.86 },
			mana = { w = 127.5, mid = -16.4 },
			name = { 35, 15.5, auto = true },
			level = { -20.93, -23.88 },
			faction = { at = { -37.06, -6.08 }, crestNudge = { -1.07, -0.47 } },
		},
		vehicle = function() local pf = _G.PlayerFrame return type(pf) == "table" and pf.state == "vehicle" end,
	},
	{ key = "target", root = function() return _G.TargetFrame end, parts = TargetParts, layout = TARGET_LAYOUT },
	{ key = "focus", root = function() return _G.FocusFrame end, parts = TargetParts, layout = TARGET_LAYOUT },
}
for i = 1, 4 do
	FRAMES[#FRAMES + 1] = { key = "party" .. i, root = function() return Dig(_G.PartyFrame, "MemberFrame" .. i) end,
		parts = PartyParts, layout = PARTY_LAYOUT }
end
local FRAME_BY_KEY = {}
for _, f in ipairs(FRAMES) do FRAME_BY_KEY[f.key] = f end

local states = {}
local function State(key)
	local st = states[key]
	if not st then
		st = { applied = false, note = "not applied yet", tex = {}, hidden = {}, moved = {}, ours = {}, sized = {}, unmasked = {} }
		states[key] = st
	end
	return st
end
local hiddenBy = {}
local hookedAlpha = {}
local pending = false
local busy = false
local hooked = {}
local errorShown = false

local function Enabled()
	return KUI.db and KUI.db.classicFrameArt == true
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function Ask(obj, method, ...)
	if type(obj) ~= "table" then return nil end
	local fn = obj[method]
	if type(fn) ~= "function" then return nil end
	local ok, v, v2 = pcall(fn, obj, ...)
	if not ok or IsSecret(v) or IsSecret(v2) then return nil end
	return v, v2
end

local function FileClues(region)
	local names, ids = {}, {}
	local function add(v)
		if IsSecret(v) then return end
		if type(v) == "string" and v ~= "" then
			local n = tonumber(v)
			if n then ids[#ids + 1] = n else names[#names + 1] = v:lower() end
		elseif type(v) == "number" then
			ids[#ids + 1] = v
		end
	end
	local atlas = Ask(region, "GetAtlas")
	if type(atlas) == "string" and C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
		if ok and type(info) == "table" then
			add(info.filename)
			add(info.file)
		end
	end
	add(Ask(region, "GetTextureFilePath"))
	add(Ask(region, "GetTextureFileID"))
	add(Ask(region, "GetTexture"))
	return names, ids
end

local function SetAlphaQuiet(region, alpha)
	busy = true
	pcall(region.SetAlpha, region, alpha)
	busy = false
end

local function HookAlpha(region)
	if hookedAlpha[region] or type(region.SetAlpha) ~= "function" then return end
	hookedAlpha[region] = true
	hooksecurefunc(region, "SetAlpha", function(self, alpha)
		local st = hiddenBy[self]
		if busy or not st or st.hidden[self] == nil then return end
		st.hidden[self] = alpha
		if st.applied then SetAlphaQuiet(self, 0) end
	end)
end

local function HideRegion(st, region)
	if not region then return end
	if st.hidden[region] == nil then st.hidden[region] = Ask(region, "GetAlpha") or 1 end
	hiddenBy[region] = st
	HookAlpha(region)
	SetAlphaQuiet(region, 0)
end

local function CurrentPoints(obj)
	local list = {}
	for i = 1, (Ask(obj, "GetNumPoints") or 0) do
		local ok, point, rel, relPoint, x, y = pcall(obj.GetPoint, obj, i)
		if ok then list[#list + 1] = { point, rel, relPoint, x, y } end
	end
	return list
end

local function SamePoints(a, b)
	if not a or not b or #a ~= #b then return false end
	for i = 1, #a do
		for j = 1, 3 do if a[i][j] ~= b[i][j] then return false end end
		for j = 4, 5 do
			if IsSecret(a[i][j]) or IsSecret(b[i][j]) or math.abs((a[i][j] or 0) - (b[i][j] or 0)) > 0.001 then return false end
		end
	end
	return true
end

local function SavePoints(st, obj)
	if st.moved[obj] then return true end
	local list = CurrentPoints(obj)
	for _, p in ipairs(list) do
		if IsSecret(p[4]) or IsSecret(p[5]) then return false end
	end
	if #list == 0 then return false end
	st.moved[obj] = list
	return true
end

local function SetPoints(obj, list, dx, dy)
	obj:ClearAllPoints()
	for _, p in ipairs(list) do obj:SetPoint(p[1], p[2], p[3], p[4] + (dx or 0), p[5] + (dy or 0)) end
end

local function Shift(st, obj, dx, dy)
	if not obj then return true end
	if math.abs(dx) > MAX_SHIFT or math.abs(dy) > MAX_SHIFT then return false end
	if not SavePoints(st, obj) then return false end
	SetPoints(obj, st.moved[obj], dx, dy)
	st.ours[obj] = CurrentPoints(obj)
	return true
end

local function Reanchor(st, obj, list)
	if not SavePoints(st, obj) then return false end
	SetPoints(obj, list, 0, 0)
	st.ours[obj] = CurrentPoints(obj)
	return true
end

local function Resize(st, obj, w, h)
	if not obj then return end
	if not st.sized[obj] then st.sized[obj] = { Ask(obj, "GetWidth"), Ask(obj, "GetHeight") } end
	if w then obj:SetWidth(w) end
	if h then obj:SetHeight(h) end
end

local function RemoveMask(st, texture, mask)
	if type(texture) ~= "table" or type(mask) ~= "table" or type(texture.RemoveMaskTexture) ~= "function" then return end
	if pcall(texture.RemoveMaskTexture, texture, mask) then st.unmasked[#st.unmasked + 1] = { texture, mask } end
end

local function ForgetReanchored(st)
	for obj in pairs(st.moved) do
		if not SamePoints(CurrentPoints(obj), st.ours[obj]) then st.moved[obj], st.ours[obj] = nil, nil end
	end
end

local function MakeTexture(st, key, parent, layer, sublevel, name)
	if st.tex[key] then return st.tex[key] end
	local t = parent:CreateTexture(name, layer, nil, sublevel)
	t:SetTexture(OLD_ART)
	st.tex[key] = t
	return t
end

local function Place(t, artKey, portrait, x, y, k)
	local a = ART[artKey]
	local s = a.scale * k
	t:SetTexCoord(a.x / TEX_W, (a.x + a.w) / TEX_W, a.y / TEX_H, (a.y + a.h) / TEX_H)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", portrait, "CENTER", x * k - a.cx * s, y * k + a.cy * s)
	t:SetSize(a.w * s, a.h * s)
end

local function FactionKey()
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	return (faction == "Alliance" or faction == "Horde") and faction or nil
end

local function UpdateFaction()
	local st = State("player")
	local p = PlayerParts(_G.PlayerFrame)
	local show = st.applied and p.pvpIcon and p.pvpIcon:IsShown() and FactionKey() ~= nil and true or false
	for _, key in ipairs({ "ringFill", "ring", "crest" }) do
		if st.tex[key] then st.tex[key]:SetShown(show) end
	end
end

local factionHooked = false
local function HookFaction(icon)
	if factionHooked or not icon then return end
	factionHooked = true
	for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
		if type(icon[method]) == "function" then hooksecurefunc(icon, method, UpdateFaction) end
	end
end

local function GiveBack(st, p)
	for region, alpha in pairs(st.hidden) do
		SetAlphaQuiet(region, alpha)
		st.hidden[region] = nil
		hiddenBy[region] = nil
	end
	for _, t in pairs(st.tex) do t:Hide() end
	if st.capFrame then st.capFrame:Hide() end
	ForgetReanchored(st)
	for obj, list in pairs(st.moved) do
		if #list > 0 then pcall(SetPoints, obj, list, 0, 0) end
		st.moved[obj], st.ours[obj] = nil, nil
	end
	for obj, size in pairs(st.sized) do
		if size[1] then pcall(obj.SetWidth, obj, size[1]) end
		if size[2] then pcall(obj.SetHeight, obj, size[2]) end
		st.sized[obj] = nil
	end
	for _, pair in ipairs(st.unmasked) do pcall(pair[1].AddMaskTexture, pair[1], pair[2]) end
	st.unmasked = {}
	if st.justify and p and p.name and p.name.SetJustifyH then pcall(p.name.SetJustifyH, p.name, st.justify) end
	st.justify = nil
	st.applied = false
end

local function Fail(st, p, why)
	st.note = why
	GiveBack(st, p)
	return false
end

local function Busy(st)
	return next(st.moved) or next(st.sized) or #st.unmasked > 0
end

local function ApplyFrame(f)
	local st = State(f.key)
	local root = f.root()
	local p = root and f.parts(root)
	if not Enabled() then
		if Busy(st) and InCombatLockdown() then pending = true return end
		GiveBack(st, p)
		st.note = "off"
		return
	end
	if InCombatLockdown() then
		pending = true
		st.note = "waiting for combat to end"
		return
	end
	GiveBack(st, p)
	if not root then st.note = "frame not on this client" return end
	if f.vehicle and f.vehicle() then st.note = "in a vehicle: Blizzard's frame shown" return end
	if not (p.holder and p.portrait and p.health and p.healthContainer and p.mana and p.frameTexture) then
		return Fail(st, p, "frame pieces not found (portrait, bars or frame art) -- old art not shown")
	end
	local L = f.layout
	local pw = Ask(p.portrait, "GetWidth")
	local pcX, pcY = Ask(p.portrait, "GetCenter")
	if type(pw) ~= "number" or pw <= 0 or type(pcX) ~= "number" or type(pcY) ~= "number" then
		return Fail(st, p, "portrait has no size or position yet")
	end
	local k = pw / L.portrait

	local layer, sublevel = Ask(p.frameTexture, "GetDrawLayer")
	layer, sublevel = layer or "BACKGROUND", sublevel or 2
	local function Sub(n) return math.min(sublevel + n, 7) end
	Place(MakeTexture(st, "piece", p.holder, layer, sublevel, f.key == "player" and "KainUIForeverOldPlayerArt" or nil), L.piece, p.portrait, 0, 0, k)
	if L.level then Place(MakeTexture(st, "level", p.holder, layer, Sub(4)), "level", p.portrait, L.level[1], L.level[2], k) end
	if L.faction then
		local at, nudge = L.faction.at, L.faction.crestNudge
		Place(MakeTexture(st, "ringFill", p.holder, layer, Sub(1)), "ringFill", p.portrait, at[1], at[2], k)
		Place(MakeTexture(st, "ring", p.holder, layer, Sub(2)), "ring", p.portrait, at[1], at[2], k)
		local crest = MakeTexture(st, "crest", p.holder, layer, Sub(3))
		local faction = FactionKey()
		if faction then Place(crest, faction, p.portrait, at[1] + nudge[1], at[2] + nudge[2], k) end
	end

	local healthTop0, containerTop0, healthH0 = Ask(p.health, "GetTop"), Ask(p.healthContainer, "GetTop"), Ask(p.health, "GetHeight")
	if not (healthTop0 and containerTop0 and healthH0) then return Fail(st, p, "bars have no position yet") end
	local above = healthTop0 - containerTop0
	local healthH = L.health.h and L.health.h * k or healthH0
	Resize(st, p.health, L.health.w * k, L.health.h and healthH or nil)
	Resize(st, p.healthContainer, L.health.cw * k, L.health.h and (healthH - 2 * above) or nil)
	Resize(st, p.mana, L.mana.w * k, nil)
	local healthLeft, healthTop = Ask(p.health, "GetLeft"), Ask(p.health, "GetTop")
	if not (healthLeft and healthTop) then return Fail(st, p, "bars have no position yet") end
	if not Shift(st, p.healthContainer, pcX + L.bars.left * k - healthLeft, (pcY + L.health.mid * k + healthH / 2) - healthTop) then
		return Fail(st, p, "health bar is not where the measurements expect -- old art not shown")
	end
	local manaLeft, manaTop, manaH = Ask(p.mana, "GetLeft"), Ask(p.mana, "GetTop"), Ask(p.mana, "GetHeight")
	if not (manaLeft and manaTop and manaH) then return Fail(st, p, "bars have no position yet") end
	if not Shift(st, p.mana, pcX + L.bars.left * k - manaLeft, (pcY + L.mana.mid * k + manaH / 2) - manaTop) then
		return Fail(st, p, "power bar is not where the measurements expect -- old art not shown")
	end
	RemoveMask(st, p.health.GetStatusBarTexture and p.health:GetStatusBarTexture(), p.healthMask)
	RemoveMask(st, p.mana.GetStatusBarTexture and p.mana:GetStatusBarTexture(), p.manaMask)

	if p.name then
		st.justify = Ask(p.name, "GetJustifyH") or "CENTER"
		Reanchor(st, p.name, { { "LEFT", p.portrait, "CENTER", L.name[1] * k, L.name[2] * k } })
		if L.name.auto then Resize(st, p.name, 0, nil) end
		pcall(p.name.SetJustifyH, p.name, "LEFT")
	end

	if L.band and p.band then
		local b = L.band
		Reanchor(st, p.band, { { "TOPLEFT", p.portrait, "CENTER", b[1] * k, b[2] * k }, { "BOTTOMRIGHT", p.portrait, "CENTER", b[3] * k, b[4] * k } })
	end

	if L.cap then
		if not st.capFrame then st.capFrame = CreateFrame("Frame", nil, root) end
		local level = math.max(Ask(p.health, "GetFrameLevel") or 1, Ask(p.mana, "GetFrameLevel") or 1)
		st.capFrame:SetFrameLevel(level + 1)
		st.capFrame:SetAllPoints(root)
		Place(MakeTexture(st, "cap", st.capFrame, "OVERLAY", 7), "cap", p.portrait, 0, 0, k)
		st.capFrame:Show()
	end

	for _, region in ipairs(p.hide) do HideRegion(st, region) end
	for key, t in pairs(st.tex) do
		if key ~= "ringFill" and key ~= "ring" and key ~= "crest" then t:Show() end
	end
	st.applied = true
	if f.key == "player" then
		HookFaction(p.pvpIcon)
		UpdateFaction()
	end
	st.note = string.format("showing: old art 1:1 on the portrait's centre (k %.2f); bars at %.1f", k, L.bars.left * k)
end

local function Relaid(key)
	local st = State(key)
	ForgetReanchored(st)
	if Enabled() then
		local function again() KUI:ApplyClassicFrameArt(key) end
		if C_Timer and C_Timer.After then C_Timer.After(0, again) else again() end
	end
end

local function HookMethod(obj, method, fn)
	if type(obj) == "table" and type(obj[method]) == "function" then pcall(hooksecurefunc, obj, method, fn) end
end

local function InstallHooks()
	if not hooked.player then
		hooked.player = true
		for _, fn in ipairs({ "PlayerFrame_UpdateArt", "PlayerFrame_ToPlayerArt", "PlayerFrame_UpdatePlayerNameTextAnchor" }) do
			if type(_G[fn]) == "function" then hooksecurefunc(fn, function() Relaid("player") end) end
		end
		if type(_G.PlayerFrame_ToVehicleArt) == "function" then
			hooksecurefunc("PlayerFrame_ToVehicleArt", function()
				local st = State("player")
				if st.applied and not InCombatLockdown() then
					GiveBack(st, PlayerParts(_G.PlayerFrame))
					if KUI.ApplyXPBar then KUI:ApplyXPBar() end
				end
			end)
		end
	end
	for _, key in ipairs({ "target", "focus" }) do
		local frame = FRAME_BY_KEY[key].root()
		if frame and not hooked[key] then
			hooked[key] = true
			for _, method in ipairs({ "CheckClassification", "Update", "CheckFaction" }) do
				HookMethod(frame, method, function() Relaid(key) end)
			end
		end
	end
	local party = _G.PartyFrame
	if party and not hooked.party then
		hooked.party = true
		HookMethod(party, "UpdatePartyFrames", function() for i = 1, 4 do Relaid("party" .. i) end end)
		for i = 1, 4 do
			local member = Dig(party, "MemberFrame" .. i)
			for _, method in ipairs({ "UpdateArt", "ToPlayerArt", "ToVehicleArt" }) do
				HookMethod(member, method, function() Relaid("party" .. i) end)
			end
		end
	end
end

function KUI:ApplyClassicFrameArt(onlyKey)
	InstallHooks()
	local wasPlayer = State("player").applied
	if not InCombatLockdown() then pending = false end
	for _, f in ipairs(FRAMES) do
		if not onlyKey or f.key == onlyKey then
			local ok, err = pcall(ApplyFrame, f)
			if not ok and not errorShown then
				errorShown = true
				print("|cffff6060Kain-UI Forever:|r restoring the old portrait art hit an error and will stay quiet about it: " .. tostring(err))
			end
		end
	end

	if State("player").applied ~= wasPlayer and KUI.ApplyXPBar then KUI:ApplyXPBar() end
end

function KUI:SetClassicFrameArt(enabled)
	if not KUI.db then return end
	KUI.db.classicFrameArt = enabled and true or false
	KUI:ApplyClassicFrameArt()
end

function KUI:IsClassicArtShowing()
	return State("player").applied
end

function KUI:FrameArtScanReport()
	print("|cff33ff99Kain-UI Forever|r portrait art scan: restore old portrait art " .. (Enabled() and "ON" or "OFF") .. (pending and " (waiting for combat to end)" or ""))
	for _, f in ipairs(FRAMES) do
		local st = State(f.key)
		local root = f.root()
		local p = root and f.parts(root)
		local missing = {}
		if p then
			for _, part in ipairs({ "portrait", "frameTexture", "health", "healthContainer", "healthMask", "mana", "manaMask", "name" }) do
				if not p[part] then missing[#missing + 1] = part end
			end
		end
		local n, m, s = 0, 0, 0
		for _ in pairs(st.hidden) do n = n + 1 end
		for _ in pairs(st.moved) do m = m + 1 end
		for _ in pairs(st.sized) do s = s + 1 end
		print(string.format("  %s: %s | hidden %d, moved %d, resized %d, masks off %d%s", f.key, st.note, n, m, s, #st.unmasked,
			not root and " | frame not found" or (#missing > 0 and (" | MISSING " .. table.concat(missing, ", ")) or "")))
	end
end

local DUMP_ROOTS = { [""] = "PlayerFrame", player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame",
	party = "PartyFrame", tot = "TargetFrameToT", boss = "Boss1TargetFrame" }
function KUI:PlayerFrameDump(which)
	which = type(which) == "string" and which:lower() or ""
	local rootName = DUMP_ROOTS[which]
	if not rootName then
		print("|cffff6060Kain-UI Forever:|r usage: /kainui portraitdump [player|target|focus|party|tot|boss]")
		return
	end
	local root = _G[rootName]
	if type(root) ~= "table" then print("|cffff6060Kain-UI Forever:|r " .. rootName .. " not found.") return end
	local lines, paths = {}, {}
	local function add(s) lines[#lines + 1] = s end

	local function str(v) if IsSecret(v) then return "secret" end return tostring(v) end
	local function num(v) if IsSecret(v) then return "secret" end return type(v) == "number" and string.format("%.1f", v) or tostring(v) end
	local function NameOf(obj)
		if obj == nil then return "nil" end
		if IsSecret(obj) then return "secret" end
		if paths[obj] then return paths[obj] end
		local n = Ask(obj, "GetName")
		return type(n) == "string" and n or "?"
	end

	local function KeyMap(frame)
		local map = {}
		pcall(function() for k, v in pairs(frame) do if type(v) == "table" then map[v] = k end end end)
		return map
	end
	local queue = { { root, rootName, 0 } }
	local i = 1
	while queue[i] do
		local frame, path, depth = queue[i][1], queue[i][2], queue[i][3]
		i = i + 1
		paths[frame] = path
		if depth < 7 and not (frame.IsForbidden and frame:IsForbidden()) then
			local keys = KeyMap(frame)
			if frame.GetRegions then
				for n, region in ipairs({ frame:GetRegions() }) do
					paths[region] = path .. "." .. tostring(keys[region] or Ask(region, "GetName") or ("#r" .. n))
				end
			end
			if frame.GetChildren then
				for n, child in ipairs({ frame:GetChildren() }) do
					queue[#queue + 1] = { child, path .. "." .. tostring(keys[child] or Ask(child, "GetName") or ("#c" .. n)), depth + 1 }
				end
			end
		end
	end
	local function Points(obj)
		local out = {}
		local count = Ask(obj, "GetNumPoints") or 0
		for p = 1, count do
			local ok, point, rel, relPoint, x, y = pcall(obj.GetPoint, obj, p)
			if ok then
				out[#out + 1] = string.format("%s>%s:%s(%s,%s)", str(point), NameOf(rel), str(relPoint), num(x), num(y))
			end
		end
		return #out > 0 and table.concat(out, " ") or "no points"
	end
	local function Size(obj)
		return num(Ask(obj, "GetWidth")) .. "x" .. num(Ask(obj, "GetHeight"))
	end
	local _, physicalH = (GetPhysicalScreenSize or function() end)()
	add(string.format("Kain-UI portrait dump of %s | screen height %s | UIParent scale %s | effective scale %s | unit %s exists %s, classification %s",
		rootName, str(physicalH), num(Ask(_G.UIParent, "GetScale")), num(Ask(root, "GetEffectiveScale")), str(root.unit),
		str(root.unit and UnitExists and UnitExists(root.unit)), str(root.unit and UnitClassification and UnitClassification(root.unit))))
	local fns = {}
	for _, n in ipairs({ "PlayerFrame_GetHealthBar", "PlayerFrame_GetManaBar", "PlayerFrame_GetAlternatePowerBar", "PlayerFrame_UpdateArt",
			"PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt", "PlayerFrame_UpdatePlayerNameTextAnchor", "PlayerFrame_UpdateLevelTextAnchor",
			"PlayerFrame_UpdateStatus", "PlayerFrame_OnEvent", "UnitFrame_Update", "UnitFrameHealthBar_Update", "TextStatusBar_UpdateTextString",
			"TargetFrame_Update", "TargetFrame_CheckClassification", "TargetFrame_CheckFaction", "TargetFrame_UpdateLevelTextAnchor",
			"PartyMemberFrame_UpdateArt", "PartyFrame_UpdatePartyFrames", "UpdatePartyFrames" }) do
		fns[#fns + 1] = n .. "=" .. (type(_G[n]) == "function" and "yes" or "no")
	end
	add("functions: " .. table.concat(fns, " "))
	for n = 1, i - 1 do
		local frame, path = queue[n][1], queue[n][2]
		if frame.IsForbidden and frame:IsForbidden() then
			add(path .. " <forbidden>")
		else
			add(string.format("%s [%s] %s level %s shown %s protected %s alpha %s | %s", path, str(Ask(frame, "GetObjectType")),
				Size(frame), str(Ask(frame, "GetFrameLevel")), str(Ask(frame, "IsShown")), str(Ask(frame, "IsProtected")),
				num(Ask(frame, "GetAlpha")), Points(frame)))
			if frame.GetRegions then
				for _, region in ipairs({ frame:GetRegions() }) do
					local kind = Ask(region, "GetObjectType")
					local layer, sub = Ask(region, "GetDrawLayer")
					local extra = ""
					if kind == "Texture" or kind == "MaskTexture" then
						local names, ids = FileClues(region)
						local c = { pcall(region.GetTexCoord, region) }
						local cok = table.remove(c, 1)
						if not cok then c = {} end
						for k2 = 1, #c do
							local v = c[k2]
							c[k2] = IsSecret(v) and "secret" or (type(v) == "number" and string.format("%.3f", v) or "?")
						end
						local masks = {}
						for m = 1, (Ask(region, "GetNumMaskTextures") or 0) do
							masks[#masks + 1] = NameOf(Ask(region, "GetMaskTexture", m))
						end
						extra = string.format(" atlas %s file %s%s coords %s%s", str(Ask(region, "GetAtlas")),
							#names > 0 and names[1] or "?", #ids > 0 and ("/" .. str(ids[1])) or "", table.concat(c, ","),
							#masks > 0 and (" masks " .. table.concat(masks, ",")) or "")
					elseif kind == "FontString" then
						local text = Ask(region, "GetText")
						extra = " text " .. (type(text) == "string" and ("'" .. text:sub(1, 20) .. "'") or "?")
					end
					add(string.format("  %s (%s %s/%s) %s shown %s alpha %s | %s%s", paths[region] or "?", str(kind), str(layer),
						str(sub), Size(region), str(Ask(region, "IsShown")), num(Ask(region, "GetAlpha")), Points(region), extra))
				end
			end
		end
	end
	local text = table.concat(lines, "\n")
	if KUI.ShowCopyText then
		KUI:ShowCopyText("Kain-UI portrait dump -- Ctrl+C to copy", text)
	else
		print(text)
	end
	print(string.format("|cff33ff99Kain-UI Forever|r portrait dump: %d lines, %d characters -- in the copy window.", #lines, #text))
end

local FOR_EVENT = { PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus" }
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
		"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then KUI:ApplyClassicFrameArt() end
		return
	end
	if not Enabled() then return end
	if InCombatLockdown() then pending = true return end
	if FOR_EVENT[event] then
		KUI:ApplyClassicFrameArt(FOR_EVENT[event])
	elseif event == "GROUP_ROSTER_UPDATE" then
		for i = 1, 4 do KUI:ApplyClassicFrameArt("party" .. i) end
	else
		KUI:ApplyClassicFrameArt()
	end
end)
