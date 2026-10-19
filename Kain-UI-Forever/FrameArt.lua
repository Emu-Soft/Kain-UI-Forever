local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_ART = MEDIA .. "PlayerFrameOld"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local TEX_W, TEX_H = 512, 128
local LIFT = 3

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

local SLOTS = {
	player = { health = { 68, 29, 192, 49 }, mana = { 68, 50, 192, 60 } },
	target = { health = { 4, 27, 130, 46 }, numbers = { 4, 27, 126, 46 }, mana = { 4, 48, 135, 57 }, band = { 4, 12, 127, 25 } },
	party  = { health = { 44, 17, 113, 26 }, mana = { 44, 28, 113, 34 } },
}

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
	local content = Dig(pf, "PlayerFrameContent")
	local main = Dig(content, "PlayerFrameContentMain")
	local contextual = Dig(content, "PlayerFrameContentContextual")
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

			Dig(healthContainer, "PlayerFrameHealthBarAnimatedLoss") or _G.PlayerFrameHealthBarAnimatedLoss,
		},
		lift = { content },
		pvpIcon = pvpIcon,
		health = health, healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = mana, manaMask = Dig(mana, "ManaBarMask"),
		name = Dig(main, "PlayerName") or _G.PlayerName,
	}
end

local function TargetParts(tf)
	local container = Dig(tf, "TargetFrameContainer")
	local content = Dig(tf, "TargetFrameContent")
	local main = Dig(content, "TargetFrameContentMain")
	local healthContainer = Dig(main, "HealthBarsContainer")
	local band = Dig(main, "ReputationColor")
	return {
		holder = container,
		portrait = Dig(container, "Portrait"),
		frameTexture = Dig(container, "FrameTexture"),
		hide = { Dig(container, "FrameTexture"), Dig(container, "Flash"), Dig(main, "LevelBackgroundCircle"), band },
		lift = { content },
		health = Dig(healthContainer, "HealthBar"), healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = Dig(main, "ManaBar"), manaMask = Dig(main, "ManaBar", "ManaBarMask"),
		name = Dig(main, "Name"),
		band = band,
	}
end

local function PartyParts(member)
	local healthContainer = Dig(member, "HealthBarContainer")
	return {
		holder = member,
		portrait = Dig(member, "portrait"),
		frameTexture = Dig(member, "Texture"),
		hide = { Dig(member, "Texture"), Dig(member, "Flash"), Dig(member, "PartyMemberOverlay", "Status") },
		liftChildren = member,
		health = Dig(healthContainer, "HealthBar"), healthContainer = healthContainer, healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = Dig(member, "manabar"), manaMask = Dig(member, "manabar", "ManaBarMask"),
		name = Dig(member, "name"),
	}
end

local TARGET_LAYOUT = {
	piece = "target", portrait = 58, cap = true,
	name = { -150.2, 15.43 },
	level = { 22.99, -25.32 },
}
local PARTY_LAYOUT = {
	piece = "party", portrait = 37,
	name = { 21.8, 12.7 },
}

local FRAMES = {
	{
		key = "player", unit = "player", root = function() return _G.PlayerFrame end, parts = PlayerParts,
		layout = {
			piece = "player", portrait = 60,
			name = { 35, 15.5, auto = true },
			level = { -20.93, -23.88 },
			faction = { at = { -37.06, -6.08 }, crestNudge = { -1.07, -0.47 } },
		},
		vehicle = function() local pf = _G.PlayerFrame return type(pf) == "table" and pf.state == "vehicle" end,
	},
	{ key = "target", unit = "target", root = function() return _G.TargetFrame end, parts = TargetParts, layout = TARGET_LAYOUT },
	{ key = "focus", unit = "focus", root = function() return _G.FocusFrame end, parts = TargetParts, layout = TARGET_LAYOUT },
}
for i = 1, 4 do
	FRAMES[#FRAMES + 1] = { key = "party" .. i, unit = "party" .. i, root = function() return Dig(_G.PartyFrame, "MemberFrame" .. i) end,
		parts = PartyParts, layout = PARTY_LAYOUT }
end
local FRAME_BY_KEY = {}
for _, f in ipairs(FRAMES) do FRAME_BY_KEY[f.key] = f end

local states = {}
local function State(key)
	local st = states[key]
	if not st then
		st = { applied = false, note = "not applied yet", tex = {}, hidden = {}, moved = {}, ours = {}, sized = {}, lifted = {}, unmasked = {} }
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
	if type(region) ~= "table" then return end
	if st.hidden[region] == nil then st.hidden[region] = Ask(region, "GetAlpha") or 1 end
	hiddenBy[region] = st
	HookAlpha(region)
	SetAlphaQuiet(region, 0)
end

local function BarFill(bar)
	local fill = Ask(bar, "GetStatusBarTexture")
	return type(fill) == "table" and fill or nil
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

local function SetPoints(obj, list)
	if SamePoints(CurrentPoints(obj), list) then return end
	obj:ClearAllPoints()
	for _, p in ipairs(list) do obj:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
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

local function SaveSize(st, obj)
	if not st.sized[obj] then st.sized[obj] = { Ask(obj, "GetWidth"), Ask(obj, "GetHeight") } end
end

local function Reanchor(st, obj, list)
	if not SavePoints(st, obj) then return false, "the game won't say where they are" end
	SaveSize(st, obj)
	local ok, err = pcall(SetPoints, obj, list)
	if not ok then
		pcall(function() obj:ClearAllPoints(); for _, q in ipairs(st.moved[obj]) do obj:SetPoint(q[1], q[2], q[3], q[4], q[5]) end end)
		st.moved[obj] = nil
		return false, tostring(err)
	end
	st.ours[obj] = CurrentPoints(obj)
	return true
end

local function Corners(target)
	return { { "TOPLEFT", target, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0 } }
end

local function SetLevel(frame, level)
	if Ask(frame, "GetFrameLevel") ~= level then pcall(frame.SetFrameLevel, frame, level) end
end

local function Descend(frame, list, skip)
	if type(frame) ~= "table" or skip[frame] then return end
	list[#list + 1] = frame
	if type(frame.GetChildren) == "function" then
		for _, child in ipairs({ frame:GetChildren() }) do Descend(child, list, skip) end
	end
end

local function Lift(st, frames, minLevel, skip)
	local list = {}
	for _, frame in ipairs(frames) do Descend(frame, list, skip) end
	local low
	for _, frame in ipairs(frames) do
		local level = Ask(frame, "GetFrameLevel")
		if level and (not low or level < low) then low = level end
	end
	if not low or low >= minLevel then return end
	local by = minLevel - low
	local was = {}
	for _, frame in ipairs(list) do was[frame] = Ask(frame, "GetFrameLevel") end
	for _, frame in ipairs(list) do
		if was[frame] then
			st.lifted[#st.lifted + 1] = { frame, was[frame], was[frame] + by }
			SetLevel(frame, was[frame] + by)
		end
	end
end

local function PortraitAt(root, portrait)
	local x, y = Ask(portrait, "GetCenter")
	local l, b = Ask(root, "GetLeft"), Ask(root, "GetBottom")
	if type(x) ~= "number" or type(y) ~= "number" or type(l) ~= "number" or type(b) ~= "number" then return nil end
	return { x - l, y - b }
end

local function Drifted(st)
	for obj in pairs(st.moved) do
		if not SamePoints(CurrentPoints(obj), st.ours[obj]) then return true end
	end
	for _, l in ipairs(st.lifted) do
		if Ask(l[1], "GetFrameLevel") ~= l[3] then return true end
	end
	local f = st.frame
	if f and st.portraitAt then
		local root = f.root()
		local now = root and PortraitAt(root, f.parts(root).portrait)
		if not now or math.abs(now[1] - st.portraitAt[1]) > 0.01 or math.abs(now[2] - st.portraitAt[2]) > 0.01 then return true end
	end
	return false
end

local function ForgetReanchored(st)
	for obj in pairs(st.moved) do
		if st.ours[obj] and not SamePoints(CurrentPoints(obj), st.ours[obj]) then st.moved[obj], st.ours[obj] = nil, nil end
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
	SetPoints(t, { { "TOPLEFT", portrait, "CENTER", x * k - a.cx * s, y * k + a.cy * s } })
	t:SetSize(a.w * s, a.h * s)
end

local function PlaceRect(obj, artKey, r, frame, at, k)
	local a = ART[artKey]
	local s = a.scale * k
	SetPoints(obj, {
		{ "TOPLEFT", frame, "BOTTOMLEFT", at[1] + (r[1] - a.cx) * s, at[2] + (a.cy - r[2]) * s },
		{ "BOTTOMRIGHT", frame, "BOTTOMLEFT", at[1] + (r[3] - a.cx) * s, at[2] + (a.cy - r[4]) * s },
	})
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

local function Flag(fn, unit)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, unit)
	if not ok or IsSecret(v) then return nil end
	return v and true or false
end

local function Fill(bar, maxFn, curFn, unit)
	if type(maxFn) ~= "function" or type(curFn) ~= "function" then return end
	pcall(function()
		bar:SetMinMaxValues(0, maxFn(unit))
		bar:SetValue(curFn(unit))
	end)
end

local function PowerColour(unit)
	local ok, kind, token = pcall(UnitPowerType or function() end, unit)
	local colours = type(PowerBarColor) == "table" and PowerBarColor or nil
	local c
	if ok and colours then
		if type(token) == "string" and not IsSecret(token) then c = colours[token] end
		if not c and type(kind) == "number" and not IsSecret(kind) then c = colours[kind] end
	end
	if type(c) ~= "table" or type(c.r) ~= "number" then return 0, 0, 1 end
	return c.r, c.g, c.b
end

local function RefreshBars(st)
	local u = st.unit
	if not (st.applied and st.bar and u) then return end
	local health, mana = st.bar.health, st.bar.mana
	Fill(health, UnitHealthMax, UnitHealth, u)
	Fill(mana, UnitPowerMax, UnitPower, u)

	if st.ownColour.health then
		if (u ~= "player" and Flag(UnitIsTapDenied, u)) or (Flag(UnitIsConnected, u) == false and Flag(UnitExists, u)) then
			health:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			health:SetStatusBarColor(0, 1, 0)
		end
	end
	if st.ownColour.mana then mana:SetStatusBarColor(PowerColour(u)) end
end

local function CopyFill(st, which, blizzard)
	local ours = st.bar[which]
	local atlas = Ask(BarFill(blizzard), "GetAtlas")
	if type(atlas) == "string" and atlas ~= "" and pcall(ours.SetStatusBarTexture, ours, atlas) and Ask(BarFill(ours), "GetAtlas") == atlas then
		st.ownColour[which] = false
		local colour = { pcall(blizzard.GetStatusBarColor, blizzard) }
		if table.remove(colour, 1) and colour[1] ~= nil then
			pcall(ours.SetStatusBarColor, ours, unpack(colour))
		else
			ours:SetStatusBarColor(1, 1, 1)
		end
		local grey = { pcall(blizzard.GetStatusBarDesaturated or function() end, blizzard) }
		if grey[1] and grey[2] ~= nil and ours.SetStatusBarDesaturated then pcall(ours.SetStatusBarDesaturated, ours, grey[2]) end
	else
		ours:SetStatusBarTexture(BAR_TEXTURE)
		st.ownColour[which] = true
	end
end

local function Unmask(st, bar, mask)
	if type(bar) ~= "table" or type(mask) ~= "table" then return end
	local frames = {}
	Descend(bar, frames, {})
	for _, frame in ipairs(frames) do
		for _, region in ipairs({ frame:GetRegions() }) do
			local count = Ask(region, "GetNumMaskTextures")
			for i = (type(count) == "number" and count or 0), 1, -1 do
				if Ask(region, "GetMaskTexture", i) == mask and pcall(region.RemoveMaskTexture, region, mask) then
					st.unmasked[#st.unmasked + 1] = { region, mask }
				end
			end
		end
	end
end

local function MakeLayer(st, root)
	if st.layer then return end
	st.layer = CreateFrame("Frame", nil, root)
	st.capFrame = CreateFrame("Frame", nil, root)
	st.bar = {}
	for _, which in ipairs({ "health", "mana" }) do
		local bar = CreateFrame("StatusBar", nil, st.layer)
		bar:SetStatusBarTexture(BAR_TEXTURE)
		st.ownColour = st.ownColour or {}
		st.ownColour[which] = true
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		st.bar[which] = bar
	end
end

local barOf = setmetatable({}, { __mode = "k" })
local barHooked = setmetatable({}, { __mode = "k" })
local function Follow(st, blizzard, ours, kind, which, also)
	barOf[blizzard] = { st = st, ours = ours, which = which, also = also }
	if barHooked[blizzard] then return end
	barHooked[blizzard] = true
	local function shown(self)
		local b = barOf[self]
		if b and b.st.applied then
			local show = Ask(self, "IsShown") and true or false
			b.ours:SetShown(show)
			if b.also then b.also:SetShown(show) end
		end
	end
	for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
		if type(blizzard[method]) == "function" then hooksecurefunc(blizzard, method, shown) end
	end
	if kind == "bar" and type(blizzard.SetStatusBarTexture) == "function" then
		hooksecurefunc(blizzard, "SetStatusBarTexture", function(self)
			local b = barOf[self]
			if b and b.st.applied then
				HideRegion(b.st, BarFill(self))
				CopyFill(b.st, b.which, self)
				RefreshBars(b.st)
			end
		end)
		for _, method in ipairs({ "SetStatusBarColor", "SetStatusBarDesaturated" }) do
			if type(blizzard[method]) == "function" then
				hooksecurefunc(blizzard, method, function(self, ...)
					local b = barOf[self]
					if b and b.st.applied and not b.st.ownColour[b.which] and type(b.ours[method]) == "function" then pcall(b.ours[method], b.ours, ...) end
				end)
			end
		end
	elseif kind == "band" and type(blizzard.SetVertexColor) == "function" then
		hooksecurefunc(blizzard, "SetVertexColor", function(self, ...)
			local b = barOf[self]
			if b and b.st.applied then pcall(b.ours.SetVertexColor, b.ours, ...) end
		end)
	end
end

local function GiveBack(st, p)
	for region, alpha in pairs(st.hidden) do
		SetAlphaQuiet(region, alpha)
		st.hidden[region] = nil
		hiddenBy[region] = nil
	end
	for _, t in pairs(st.tex) do t:Hide() end
	if st.layer then st.layer:Hide() end
	if st.capFrame then st.capFrame:Hide() end
	ForgetReanchored(st)
	for obj, list in pairs(st.moved) do
		if #list > 0 then pcall(SetPoints, obj, list) end
		st.moved[obj], st.ours[obj] = nil, nil
	end
	for obj, size in pairs(st.sized) do
		if size[1] then pcall(obj.SetWidth, obj, size[1]) end
		if size[2] then pcall(obj.SetHeight, obj, size[2]) end
		st.sized[obj] = nil
	end
	for _, l in ipairs(st.lifted) do SetLevel(l[1], l[2]) end
	st.lifted = {}
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
	return next(st.moved) or next(st.sized) or #st.lifted > 0
end

local function UnitOf(f, root)
	local u = root and root.unit
	if type(u) == "string" and not IsSecret(u) and u ~= "" then return u end
	return f.unit
end

local function ApplyFrame(f)
	local st = State(f.key)
	st.frame = f
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
	local slots = SLOTS[L.piece]
	local pw = Ask(p.portrait, "GetWidth")
	if type(pw) ~= "number" or pw <= 0 then return Fail(st, p, "portrait has no size yet") end
	local k = pw / L.portrait
	local at = PortraitAt(root, p.portrait)
	if not at then return Fail(st, p, "portrait has no position yet") end
	st.portraitAt = at
	local base = Ask(p.holder, "GetFrameLevel")
	if type(base) ~= "number" then return Fail(st, p, "frame has no level yet") end

	local layer, sublevel = Ask(p.frameTexture, "GetDrawLayer")
	layer, sublevel = layer or "BACKGROUND", sublevel or 2
	local function Sub(n) return math.min(sublevel + n, 7) end
	Place(MakeTexture(st, "piece", p.holder, layer, sublevel, f.key == "player" and "KainUIForeverOldPlayerArt" or nil), L.piece, p.portrait, 0, 0, k)
	if L.level then Place(MakeTexture(st, "level", p.holder, layer, Sub(4)), "level", p.portrait, L.level[1], L.level[2], k) end
	if L.faction then
		local spot, nudge = L.faction.at, L.faction.crestNudge
		Place(MakeTexture(st, "ringFill", p.holder, layer, Sub(1)), "ringFill", p.portrait, spot[1], spot[2], k)
		Place(MakeTexture(st, "ring", p.holder, layer, Sub(2)), "ring", p.portrait, spot[1], spot[2], k)
		local crest = MakeTexture(st, "crest", p.holder, layer, Sub(3))
		local faction = FactionKey()
		if faction then Place(crest, faction, p.portrait, spot[1] + nudge[1], spot[2] + nudge[2], k) end
	end

	MakeLayer(st, root)
	SetLevel(st.layer, base + 1)
	SetLevel(st.capFrame, base + 2)
	SetPoints(st.layer, Corners(root))
	SetPoints(st.capFrame, Corners(root))
	for _, which in ipairs({ "health", "mana" }) do
		SetLevel(st.bar[which], base + 1)
		PlaceRect(st.bar[which], L.piece, slots[which], root, at, k)
	end

	local skip = { [st.layer] = true, [st.capFrame] = true }
	local lift = p.lift
	if p.liftChildren then
		lift = {}
		for _, child in ipairs({ p.liftChildren:GetChildren() }) do
			if not skip[child] then lift[#lift + 1] = child end
		end
	end
	Lift(st, lift or {}, base + LIFT, skip)

	local numbers = st.numbers
	if slots.numbers then
		if not numbers then numbers = CreateFrame("Frame", nil, st.layer); st.numbers = numbers end
		PlaceRect(numbers, L.piece, slots.numbers, root, at, k)
	end
	for _, pair in ipairs({ { p.healthContainer, slots.numbers and numbers or st.bar.health }, { p.health, st.bar.health }, { p.mana, st.bar.mana } }) do
		local moved, why = Reanchor(st, pair[1], Corners(pair[2]))
		if not moved then return Fail(st, p, "bars can't be moved (" .. why .. ") -- old art not shown") end
	end
	HideRegion(st, BarFill(p.health))
	HideRegion(st, BarFill(p.mana))
	Follow(st, p.health, st.bar.health, "bar", "health")
	Follow(st, p.mana, st.bar.mana, "bar", "mana")
	CopyFill(st, "health", p.health)
	CopyFill(st, "mana", p.mana)
	Unmask(st, p.health, p.healthMask)
	Unmask(st, p.mana, p.manaMask)
	st.bar.health:SetShown(Ask(p.health, "IsShown") ~= false)
	st.bar.mana:SetShown(Ask(p.mana, "IsShown") ~= false)

	if p.name then
		st.justify = Ask(p.name, "GetJustifyH") or "CENTER"
		Reanchor(st, p.name, { { "LEFT", p.portrait, "CENTER", L.name[1] * k, L.name[2] * k } })
		if L.name.auto then SaveSize(st, p.name); p.name:SetWidth(0) end
		pcall(p.name.SetJustifyH, p.name, "LEFT")
	end

	if slots.band and p.band then
		local band, shade = st.tex.band, st.tex.bandShade
		if not band then
			band = st.layer:CreateTexture(nil, "BACKGROUND", nil, 0)
			band:SetColorTexture(1, 1, 1, 1)
			band:SetAlpha(0.7)
			shade = st.layer:CreateTexture(nil, "BACKGROUND", nil, 1)
			shade:SetColorTexture(1, 1, 1, 1)
			if not (CreateColor and pcall(shade.SetGradient, shade, "VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.5))) then
				shade:SetColorTexture(0, 0, 0, 0.2)
			end
			st.tex.band, st.tex.bandShade = band, shade
		end
		PlaceRect(band, L.piece, slots.band, root, at, k)
		PlaceRect(shade, L.piece, slots.band, root, at, k)
		local colour = { pcall(p.band.GetVertexColor, p.band) }
		if table.remove(colour, 1) then pcall(band.SetVertexColor, band, unpack(colour)) end
		Reanchor(st, p.band, Corners(band))
		Follow(st, p.band, band, "band", nil, shade)
		band:SetShown(Ask(p.band, "IsShown") ~= false)
		shade:SetShown(band:IsShown())
	end

	if L.cap then Place(MakeTexture(st, "cap", st.capFrame, "OVERLAY", 7), "cap", p.portrait, 0, 0, k) end

	for _, region in ipairs(p.hide) do HideRegion(st, region) end
	for key, t in pairs(st.tex) do
		if key ~= "ringFill" and key ~= "ring" and key ~= "crest" and key ~= "band" and key ~= "bandShade" then t:Show() end
	end
	st.layer:Show()
	st.capFrame:Show()
	st.unit = UnitOf(f, root)
	st.applied = true
	RefreshBars(st)
	if f.key == "player" then
		HookFaction(p.pvpIcon)
		UpdateFaction()
	end
	st.note = string.format("showing: old art 1:1 on the portrait's centre (k %.2f), our bars in its slots", k)
end

local function Relaid(key)
	if not Enabled() then return end
	local st = State(key)
	if st.applied and not Drifted(st) then
		st.unit = UnitOf(FRAME_BY_KEY[key], FRAME_BY_KEY[key].root())
		RefreshBars(st)
		return
	end
	ForgetReanchored(st)
	local function again() KUI:ApplyClassicFrameArt(key) end
	if C_Timer and C_Timer.After then C_Timer.After(0, again) else again() end
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
					st.note = "in a vehicle: Blizzard's frame shown"
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
			for _, part in ipairs({ "portrait", "frameTexture", "health", "healthContainer", "mana", "name" }) do
				if not p[part] then missing[#missing + 1] = part end
			end
		end
		local n, m = 0, 0
		for _ in pairs(st.hidden) do n = n + 1 end
		for _ in pairs(st.moved) do m = m + 1 end
		print(string.format("  %s: %s | hidden/faded %d, moved %d, lifted %d%s%s", f.key, st.note, n, m, #st.lifted,
			st.applied and Drifted(st) and " | MOVED BY THE GAME since" or "",
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
local UNIT_EVENT = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true,
	UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UNIT_CONNECTION = true, UNIT_FACTION = true }
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
		"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
for event in pairs(UNIT_EVENT) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, unit)
	if UNIT_EVENT[event] then
		for _, f in ipairs(FRAMES) do
			local st = states[f.key]
			if st and st.applied and st.unit == unit then RefreshBars(st) end
		end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then KUI:ApplyClassicFrameArt() end
		return
	end
	if not Enabled() then return end
	if FOR_EVENT[event] then
		Relaid(FOR_EVENT[event])
	elseif event == "GROUP_ROSTER_UPDATE" then
		for i = 1, 4 do Relaid("party" .. i) end
	elseif InCombatLockdown() then
		pending = true
	else
		KUI:ApplyClassicFrameArt()
	end
end)
