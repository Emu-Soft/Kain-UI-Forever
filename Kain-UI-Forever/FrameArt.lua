local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_ART = MEDIA .. "PlayerFrameOld"
local TEX_W, TEX_H = 256, 128

local ART = {
	piece    = { x = 0,   y = 0,  w = 198, h = 74, cx = 36.40, cy = 37.31, scale = 1 },
	level    = { x = 200, y = 0,  w = 37,  h = 37, cx = 18.49, cy = 18.45, scale = 1 },
	ring     = { x = 200, y = 40, w = 32,  h = 34, cx = 15.43, cy = 15.48, scale = 0.955 },
	Alliance = { x = 200, y = 76, w = 20,  h = 25, cx = 10,    cy = 12.5,  scale = 0.8 },
	Horde    = { x = 222, y = 76, w = 23,  h = 25, cx = 11.5,  cy = 12.5,  scale = 0.8 },
}

local LEVEL_AT = { -20.93, -23.88 }
local FACTION_AT = { -37.06, -6.08 }

local CREST_NUDGE = { -1.07, -0.47 }
local BARS_LEFT = 31.6
local HEALTH_H = 28

local BAR_W = 126
local HEALTH_MID = -0.86
local MANA_MID = -16.4
local NAME_AT = { 35, 15.5 }
local PORTRAIT_SIZE = 60
local MAX_SHIFT = 15

local tex = {}
local applied = false
local pending = false
local note = "not applied yet"
local hidden = {}
local hookedAlpha = {}
local moved = {}
local ours = {}
local sized = {}
local unmasked = {}
local nameJustify
local busy = false
local hooked = false
local factionHooked = false
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

local function Dig(root, ...)
	local node = root
	for i = 1, select("#", ...) do
		if type(node) ~= "table" then return nil end
		node = node[(select(i, ...))]
	end
	return type(node) == "table" and node or nil
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

local function Parts()
	local pf = _G.PlayerFrame
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
		container = container,
		portrait = Dig(container, "PlayerPortrait"),
		frameTexture = Dig(container, "FrameTexture"),
		hide = {
			Dig(container, "FrameTexture"), Dig(container, "AlternatePowerFrameTexture"), Dig(container, "FrameFlash"),
			Dig(main, "StatusTexture"), Dig(contextual, "PlayerPortraitCornerIcon"),
			Dig(main, "LevelBackgroundCircle"), pvpIcon,
		},
		pvpIcon = pvpIcon,
		health = health,
		healthContainer = healthContainer,
		healthMask = Dig(healthContainer, "HealthBarMask"),
		mana = mana,
		manaMask = Dig(mana, "ManaBarMask"),
		name = Dig(main, "PlayerName") or _G.PlayerName,
	}
end

local function InVehicle()
	local pf = _G.PlayerFrame
	return type(pf) == "table" and pf.state == "vehicle"
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
		if busy or hidden[self] == nil then return end
		hidden[self] = alpha
		if applied then SetAlphaQuiet(self, 0) end
	end)
end

local function HideRegion(region)
	if not region then return end
	if hidden[region] == nil then hidden[region] = Ask(region, "GetAlpha") or 1 end
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

local function SavePoints(obj)
	if moved[obj] then return true end
	local list = CurrentPoints(obj)
	for _, p in ipairs(list) do
		if IsSecret(p[4]) or IsSecret(p[5]) then return false end
	end
	if #list == 0 then return false end
	moved[obj] = list
	return true
end

local function SetPoints(obj, list, dx, dy)
	obj:ClearAllPoints()
	for _, p in ipairs(list) do obj:SetPoint(p[1], p[2], p[3], p[4] + (dx or 0), p[5] + (dy or 0)) end
end

local function Shift(obj, dx, dy)
	if not obj then return true end
	if math.abs(dx) > MAX_SHIFT or math.abs(dy) > MAX_SHIFT then return false end
	if not SavePoints(obj) then return false end
	SetPoints(obj, moved[obj], dx, dy)
	ours[obj] = CurrentPoints(obj)
	return true
end

local function Reanchor(obj, point, rel, relPoint, x, y)
	if not SavePoints(obj) then return false end
	obj:ClearAllPoints()
	obj:SetPoint(point, rel, relPoint, x, y)
	ours[obj] = CurrentPoints(obj)
	return true
end

local function Resize(obj, w, h)
	if not sized[obj] then sized[obj] = { Ask(obj, "GetWidth"), Ask(obj, "GetHeight") } end
	if w then obj:SetWidth(w) end
	if h then obj:SetHeight(h) end
end

local function RemoveMask(texture, mask)
	if type(texture) ~= "table" or type(mask) ~= "table" or type(texture.RemoveMaskTexture) ~= "function" then return end
	if pcall(texture.RemoveMaskTexture, texture, mask) then unmasked[#unmasked + 1] = { texture, mask } end
end

local function ForgetReanchored()
	for obj in pairs(moved) do
		if not SamePoints(CurrentPoints(obj), ours[obj]) then moved[obj], ours[obj] = nil, nil end
	end
end

local function MakeTexture(key, container, layer, sublevel)
	if tex[key] then return tex[key] end
	local t = container:CreateTexture(key == "piece" and "KainUIForeverOldPlayerArt" or nil, layer, nil, sublevel)
	t:SetTexture(OLD_ART)
	tex[key] = t
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
	local p = Parts()
	local show = applied and p.pvpIcon and p.pvpIcon:IsShown() and FactionKey() ~= nil
	if tex.ring then tex.ring:SetShown(show and true or false) end
	if tex.crest then tex.crest:SetShown(show and true or false) end
end

local function HookFaction(icon)
	if factionHooked or not icon then return end
	factionHooked = true
	for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
		if type(icon[method]) == "function" then hooksecurefunc(icon, method, UpdateFaction) end
	end
end

local function GiveBack()
	for region, alpha in pairs(hidden) do
		SetAlphaQuiet(region, alpha)
		hidden[region] = nil
	end
	for _, t in pairs(tex) do t:Hide() end
	ForgetReanchored()
	for obj, list in pairs(moved) do
		if #list > 0 then pcall(SetPoints, obj, list, 0, 0) end
		moved[obj], ours[obj] = nil, nil
	end
	for obj, size in pairs(sized) do
		if size[1] then pcall(obj.SetWidth, obj, size[1]) end
		if size[2] then pcall(obj.SetHeight, obj, size[2]) end
		sized[obj] = nil
	end
	for _, pair in ipairs(unmasked) do pcall(pair[1].AddMaskTexture, pair[1], pair[2]) end
	unmasked = {}
	local p = Parts()
	if nameJustify and p.name and p.name.SetJustifyH then pcall(p.name.SetJustifyH, p.name, nameJustify) end
	nameJustify = nil
	applied = false
end

local function Fail(why)
	note = why
	GiveBack()
	return false
end

local function ApplyNow()
	if not Enabled() then
		if InCombatLockdown() and (next(moved) or next(sized)) then pending = true return end
		GiveBack()
		note = "off"
		return
	end
	if InCombatLockdown() then
		pending = true
		note = "waiting for combat to end"
		return
	end
	pending = false
	GiveBack()
	if InVehicle() then note = "in a vehicle: Blizzard's frame shown" return end
	local p = Parts()
	if not (p.container and p.portrait and p.health and p.healthContainer and p.mana and p.frameTexture) then
		return Fail("player frame pieces not found (portrait, bars or frame art) -- old art not shown")
	end
	local pw = Ask(p.portrait, "GetWidth")
	local pcX, pcY = Ask(p.portrait, "GetCenter")
	if type(pw) ~= "number" or pw <= 0 or type(pcX) ~= "number" or type(pcY) ~= "number" then
		return Fail("portrait has no size or position yet")
	end
	local k = pw / PORTRAIT_SIZE

	local layer, sublevel = Ask(p.frameTexture, "GetDrawLayer")
	layer, sublevel = layer or "BACKGROUND", sublevel or 2
	Place(MakeTexture("piece", p.container, layer, sublevel), "piece", p.portrait, 0, 0, k)
	Place(MakeTexture("ring", p.container, layer, math.min(sublevel + 1, 7)), "ring", p.portrait, FACTION_AT[1], FACTION_AT[2], k)
	local crest = MakeTexture("crest", p.container, layer, math.min(sublevel + 2, 7))
	local faction = FactionKey()
	if faction then Place(crest, faction, p.portrait, FACTION_AT[1] + CREST_NUDGE[1], FACTION_AT[2] + CREST_NUDGE[2], k) end
	Place(MakeTexture("level", p.container, layer, math.min(sublevel + 3, 7)), "level", p.portrait, LEVEL_AT[1], LEVEL_AT[2], k)

	local healthTop0, containerTop = Ask(p.health, "GetTop"), Ask(p.healthContainer, "GetTop")
	local healthLeft, manaLeft, manaTop = Ask(p.health, "GetLeft"), Ask(p.mana, "GetLeft"), Ask(p.mana, "GetTop")
	local manaH = Ask(p.mana, "GetHeight")
	if not (healthTop0 and containerTop and healthLeft and manaLeft and manaTop and manaH) then return Fail("bars have no position yet") end
	local healthH = HEALTH_H * k
	local above = healthTop0 - containerTop
	local hdx = pcX + BARS_LEFT * k - healthLeft
	local hdy = (pcY + HEALTH_MID * k + healthH / 2) - healthTop0
	if not Shift(p.healthContainer, hdx, hdy) then return Fail("health bar is not where the measurements expect -- old art not shown") end
	Resize(p.health, BAR_W * k, healthH)
	Resize(p.healthContainer, BAR_W * k, healthH - 2 * above)
	if not Shift(p.mana, pcX + BARS_LEFT * k - manaLeft, (pcY + MANA_MID * k + manaH / 2) - manaTop) then
		return Fail("power bar is not where the measurements expect -- old art not shown")
	end
	Resize(p.mana, BAR_W * k, nil)
	RemoveMask(p.health.GetStatusBarTexture and p.health:GetStatusBarTexture(), p.healthMask)
	RemoveMask(p.mana.GetStatusBarTexture and p.mana:GetStatusBarTexture(), p.manaMask)

	if p.name then
		nameJustify = Ask(p.name, "GetJustifyH") or "CENTER"
		Reanchor(p.name, "LEFT", p.portrait, "CENTER", NAME_AT[1] * k, NAME_AT[2] * k)
		Resize(p.name, 0, nil)
		pcall(p.name.SetJustifyH, p.name, "LEFT")
	end

	for _, region in ipairs(p.hide) do HideRegion(region) end
	tex.piece:Show()
	tex.level:Show()
	applied = true
	HookFaction(p.pvpIcon)
	UpdateFaction()
	note = string.format("showing: old art 1:1 on the portrait's centre (k %.2f); health %.0f tall, bars at %.1f", k, healthH, BARS_LEFT * k)
end

local function InstallHooks()
	if hooked then return end
	hooked = true

	local function Relaid()
		ForgetReanchored()
		if Enabled() then
			if C_Timer and C_Timer.After then C_Timer.After(0, function() KUI:ApplyClassicFrameArt() end) else KUI:ApplyClassicFrameArt() end
		end
	end
	for _, fn in ipairs({ "PlayerFrame_UpdateArt", "PlayerFrame_ToPlayerArt", "PlayerFrame_UpdatePlayerNameTextAnchor" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, Relaid) end
	end
	if type(_G.PlayerFrame_ToVehicleArt) == "function" then
		hooksecurefunc("PlayerFrame_ToVehicleArt", function()
			if applied and not InCombatLockdown() then GiveBack() if KUI.ApplyXPBar then KUI:ApplyXPBar() end end
		end)
	end
end

function KUI:ApplyClassicFrameArt()
	InstallHooks()
	local wasApplied = applied
	local ok, err = pcall(ApplyNow)
	if not ok and not errorShown then
		errorShown = true
		print("|cffff6060Kain-UI Forever:|r restoring the old portrait art hit an error and will stay quiet about it: " .. tostring(err))
	end

	if applied ~= wasApplied and KUI.ApplyXPBar then KUI:ApplyXPBar() end
end

function KUI:SetClassicFrameArt(enabled)
	if not KUI.db then return end
	KUI.db.classicFrameArt = enabled and true or false
	KUI:ApplyClassicFrameArt()
end

function KUI:IsClassicArtShowing()
	return applied
end

function KUI:FrameArtScanReport()
	print("|cff33ff99Kain-UI Forever|r portrait art scan:")
	print("  restore old portrait art: " .. (Enabled() and "ON" or "OFF") .. " | " .. note .. (pending and " (waiting for combat to end)" or ""))
	local p = Parts()
	local function have(v) return v and "found" or "MISSING" end
	print(string.format("  portrait %s, frame art %s, health bar %s (container %s, mask %s), power bar %s (mask %s), name %s, faction icon %s (%s)",
		have(p.portrait), have(p.frameTexture), have(p.health), have(p.healthContainer), have(p.healthMask), have(p.mana), have(p.manaMask),
		have(p.name), have(p.pvpIcon), tostring(FactionKey())))
	local n, m, s = 0, 0, 0
	for _ in pairs(hidden) do n = n + 1 end
	for _ in pairs(moved) do m = m + 1 end
	for _ in pairs(sized) do s = s + 1 end
	print(string.format("  Blizzard art hidden: %d | moved: %d | resized: %d | masks removed: %d | in a vehicle: %s", n, m, s, #unmasked, tostring(InVehicle())))
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

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not pending then return end
	if Enabled() or pending then KUI:ApplyClassicFrameArt() end
end)
