local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_PLAYER = MEDIA .. "PlayerFrameOld"
local TEX_W, TEX_H = 256, 128
local PIECE_W, PIECE_H = 198, 77
local RING_X, RING_Y = 37.24, 37.98
local PORTRAIT_SIZE = 60

local PIECE_SX = 1.0177

local HEALTH_TOP = RING_Y - 29
local MANA_TOP = RING_Y - 50
local NAME_MID = RING_Y - 20.5
local XP_SLOT = { left = (66 - RING_X) * PIECE_SX, right = (192 - RING_X) * PIECE_SX, top = RING_Y - 61, bottom = RING_Y - 71 }
local MAX_SHIFT = 15

local overlay
local applied = false
local pending = false
local note = "not applied yet"
local hidden = {}
local hookedAlpha = {}
local moved = {}
local ours = {}
local unmasked = {}
local nameJustify
local busy = false
local hooked = false
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
	if not ok or IsSecret(v) then return nil end
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
	return {
		container = container,
		portrait = Dig(container, "PlayerPortrait"),
		frameTexture = Dig(container, "FrameTexture"),
		vehicleTexture = Dig(container, "VehicleFrameTexture"),
		hide = {
			Dig(container, "FrameTexture"), Dig(container, "AlternatePowerFrameTexture"), Dig(container, "FrameFlash"),
			Dig(main, "StatusTexture"), Dig(contextual, "PlayerPortraitCornerIcon"),
		},
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
	if hidden[region] == nil then hidden[region] = Ask(region, "GetAlpha") or 1 end
	HookAlpha(region)
	SetAlphaQuiet(region, 0)
end

local function SavePoints(obj)
	if moved[obj] then return end
	local list = {}
	for i = 1, (Ask(obj, "GetNumPoints") or 0) do
		local ok, point, rel, relPoint, x, y = pcall(obj.GetPoint, obj, i)
		if ok and not IsSecret(x) and not IsSecret(y) then list[#list + 1] = { point, rel, relPoint, x, y } end
	end
	moved[obj] = list
end

local function SetPoints(obj, list, dy)
	obj:ClearAllPoints()
	for _, p in ipairs(list) do obj:SetPoint(p[1], p[2], p[3], p[4], p[5] + (dy or 0)) end
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

local function ForgetReanchored()
	for obj in pairs(moved) do
		if not SamePoints(CurrentPoints(obj), ours[obj]) then moved[obj], ours[obj] = nil, nil end
	end
end

local function Shift(obj, dy)
	if not obj or not dy or dy == 0 then return true end
	if math.abs(dy) > MAX_SHIFT then return false end
	SavePoints(obj)
	if #moved[obj] == 0 then moved[obj] = nil return false end
	SetPoints(obj, moved[obj], dy)
	ours[obj] = CurrentPoints(obj)
	return true
end

local function RemoveMask(texture, mask)
	if type(texture) ~= "table" or type(mask) ~= "table" or type(texture.RemoveMaskTexture) ~= "function" then return end
	if pcall(texture.RemoveMaskTexture, texture, mask) then unmasked[#unmasked + 1] = { texture, mask } end
end

local function GiveBack()
	for region, alpha in pairs(hidden) do
		SetAlphaQuiet(region, alpha)
		hidden[region] = nil
	end
	if overlay then overlay:Hide() end
	ForgetReanchored()
	for obj, list in pairs(moved) do
		if #list > 0 then pcall(SetPoints, obj, list, 0) end
		moved[obj], ours[obj] = nil, nil
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
		if InCombatLockdown() and next(moved) then pending = true return end
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
	if not (p.container and p.portrait and p.health and p.mana and p.frameTexture) then
		return Fail("player frame pieces not found (portrait, bars or frame art) -- old art not shown")
	end
	local pw = Ask(p.portrait, "GetWidth")
	local _, pcY = p.portrait:GetCenter()
	if type(pw) ~= "number" or pw <= 0 or type(pcY) ~= "number" or IsSecret(pcY) then
		return Fail("portrait has no size or position yet")
	end
	local k = pw / PORTRAIT_SIZE

	if not overlay then
		local layer, sublevel = Ask(p.frameTexture, "GetDrawLayer")
		overlay = p.container:CreateTexture("KainUIForeverOldPlayerArt", layer or "BACKGROUND", nil, sublevel or 2)
		overlay:SetTexture(OLD_PLAYER)
		overlay:SetTexCoord(0, PIECE_W / TEX_W, 0, PIECE_H / TEX_H)
	end
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", p.portrait, "CENTER", -RING_X * PIECE_SX * k, RING_Y * k)
	overlay:SetSize(PIECE_W * PIECE_SX * k, PIECE_H * k)

	local healthTop, manaTop = Ask(p.health, "GetTop"), Ask(p.mana, "GetTop")
	if type(healthTop) ~= "number" or type(manaTop) ~= "number" then return Fail("bars have no position yet") end
	if not Shift(p.healthContainer, pcY + HEALTH_TOP * k - healthTop) then return Fail("health bar is not where the measurements expect -- old art not shown") end
	if not Shift(p.mana, pcY + MANA_TOP * k - manaTop) then return Fail("power bar is not where the measurements expect -- old art not shown") end
	RemoveMask(p.health.GetStatusBarTexture and p.health:GetStatusBarTexture(), p.healthMask)
	RemoveMask(p.mana.GetStatusBarTexture and p.mana:GetStatusBarTexture(), p.manaMask)

	if p.name then
		local _, nameY = p.name:GetCenter()
		if type(nameY) == "number" and not IsSecret(nameY) then Shift(p.name, pcY + NAME_MID * k - nameY) end
		nameJustify = Ask(p.name, "GetJustifyH") or "CENTER"
		pcall(p.name.SetJustifyH, p.name, "LEFT")
	end

	for _, region in ipairs(p.hide) do HideRegion(region) end
	overlay:Show()
	applied = true
	note = string.format("showing: piece %.1f x %.1f on the portrait's centre; health moved %s, power %s",
		PIECE_W * PIECE_SX * k, PIECE_H * k, moved[p.healthContainer] and "up" or "no", moved[p.mana] and "nudged" or "not moved")
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

	if (applied or wasApplied) and KUI.ApplyXPBar then KUI:ApplyXPBar() end
end

function KUI:SetClassicFrameArt(enabled)
	if not KUI.db then return end
	KUI.db.classicFrameArt = enabled and true or false
	KUI:ApplyClassicFrameArt()
end

function KUI:GetClassicXPSlot()
	if not applied then return nil end
	local p = Parts()
	local pw = p.portrait and Ask(p.portrait, "GetWidth")
	if type(pw) ~= "number" or pw <= 0 then return nil end
	local k = pw / PORTRAIT_SIZE
	return {
		anchor = p.portrait,
		left = XP_SLOT.left * k, right = XP_SLOT.right * k, top = XP_SLOT.top * k, bottom = XP_SLOT.bottom * k,
		level = (Ask(p.container, "GetFrameLevel") or 1) + 2,
	}
end

function KUI:FrameArtScanReport()
	print("|cff33ff99Kain-UI Forever|r portrait art scan:")
	print("  restore old portrait art: " .. (Enabled() and "ON" or "OFF") .. " | " .. note .. (pending and " (waiting for combat to end)" or ""))
	local p = Parts()
	local function have(v) return v and "found" or "MISSING" end
	print(string.format("  portrait %s, frame art %s, health bar %s (container %s, mask %s), power bar %s (mask %s), name %s",
		have(p.portrait), have(p.frameTexture), have(p.health), have(p.healthContainer), have(p.healthMask), have(p.mana), have(p.manaMask), have(p.name)))
	local n = 0
	for _ in pairs(hidden) do n = n + 1 end
	local m = 0
	for _ in pairs(moved) do m = m + 1 end
	print(string.format("  Blizzard art hidden: %d | moved: %d | masks removed: %d | in a vehicle: %s", n, m, #unmasked, tostring(InVehicle())))
	local slot = KUI:GetClassicXPSlot()
	print("  XP bar slot: " .. (slot and string.format("%.1f to %.1f across, %.1f to %.1f down from the portrait's centre", slot.left, slot.right, -slot.top, -slot.bottom) or "not in use"))
end

function KUI:PlayerFrameDump()
	local root = _G.PlayerFrame
	if type(root) ~= "table" then print("|cffff6060Kain-UI Forever:|r PlayerFrame not found.") return end
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
	local queue = { { root, "PlayerFrame", 0 } }
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
	add(string.format("Kain-UI portrait dump | screen height %s | UIParent scale %s | PlayerFrame effective scale %s",
		str(physicalH), num(Ask(_G.UIParent, "GetScale")), num(Ask(root, "GetEffectiveScale"))))
	local fns = {}
	for _, n in ipairs({ "PlayerFrame_GetHealthBar", "PlayerFrame_GetManaBar", "PlayerFrame_GetAlternatePowerBar", "PlayerFrame_UpdateArt",
			"PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt", "PlayerFrame_UpdatePlayerNameTextAnchor", "PlayerFrame_UpdateLevelTextAnchor",
			"PlayerFrame_UpdateStatus", "PlayerFrame_OnEvent", "UnitFrame_Update", "UnitFrameHealthBar_Update", "TextStatusBar_UpdateTextString" }) do
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
