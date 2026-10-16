local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_PLAYER = MEDIA .. "PlayerFrameOld"
local TEX_W, TEX_H = 512, 256
local PIECE_W, PIECE_H = 392, 140
local RING_X, RING_Y, RING_R = 69.96, 70.06, 66.63
local MIN_HIDE_WIDTH = 50

local NAME_2X, NAME_1X = "uiunitframe2xc60", "uiunitframec60"

local KNOWN_FILE_IDS = {}

local hidden = {}
local hookedAlpha = {}
local learned = {}
local learnedFromPlayerFrame = false
local matchMode = "not applied yet"
local layoutNote = "not laid out yet"
local overlay
local manaHooked = false
local busy = false
local errorShown = false

local function Enabled()
	return KUI.db and KUI.db.classicFrameArt == true
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function Ask(obj, method, ...)
	local fn = obj[method]
	if type(fn) ~= "function" then return nil end
	local ok, v, v2 = pcall(fn, obj, ...)
	if not ok or IsSecret(v) then return nil end
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

local function NameMatches(names)
	for _, n in ipairs(names) do
		if n:find(NAME_2X, 1, true) or n:find(NAME_1X, 1, true) then return true end
	end
	return false
end

local function FromUnitFrameFile(region)
	local names, ids = FileClues(region)
	if NameMatches(names) then
		for _, id in ipairs(ids) do learned[id] = true end
		return true, true
	end
	for _, id in ipairs(ids) do
		if KNOWN_FILE_IDS[id] or learned[id] then return true, false end
	end
	return false, false
end

local function PlayerFrameTexture()
	local container = _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContainer
	local tex = container and container.FrameTexture
	return type(tex) == "table" and tex or nil
end

local function LearnFromPlayerFrame()
	local tex = PlayerFrameTexture()
	if not tex then return false end
	local _, ids = FileClues(tex)
	for _, id in ipairs(ids) do learned[id] = true end
	learnedFromPlayerFrame = #ids > 0
	return learnedFromPlayerFrame
end

local function Walk(frame, depth, out)
	if depth > 8 or type(frame) ~= "table" then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	if Ask(frame, "GetObjectType") == "StatusBar" then return end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region ~= overlay and Ask(region, "GetObjectType") == "Texture" then out[#out + 1] = region end
		end
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do Walk(child, depth + 1, out) end
	end
end

local function FindFrameArt()
	local all = {}
	if type(_G.PlayerFrame) == "table" then Walk(_G.PlayerFrame, 0, all) end
	local fromFile, sawName = {}, false
	local function collect()
		fromFile = {}
		for _, region in ipairs(all) do
			local yes, byName = FromUnitFrameFile(region)
			if yes then fromFile[#fromFile + 1] = region end
			if byName then sawName = true end
		end
	end
	collect()
	if sawName then
		collect()
		matchMode = "by file name"
	elseif next(KNOWN_FILE_IDS) then
		matchMode = "by known file IDs"
	elseif learnedFromPlayerFrame or (not next(learned) and LearnFromPlayerFrame()) then
		collect()
		matchMode = "LAST RESORT: by the player frame's own art (no file names readable)"
	elseif next(learned) then
		matchMode = "by file IDs learned from names earlier"
	else
		matchMode = "nothing to match: no file names, no known IDs, no player frame art found"
	end
	local wide = {}
	for _, region in ipairs(fromFile) do
		local w = Ask(region, "GetWidth")
		if type(w) == "number" and w >= MIN_HIDE_WIDTH then wide[#wide + 1] = region end
	end
	return wide, fromFile
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
		if Enabled() then SetAlphaQuiet(self, 0) end
	end)
end

local function Hide(region)
	if hidden[region] == nil then
		hidden[region] = Ask(region, "GetAlpha") or 1
	end
	HookAlpha(region)
	SetAlphaQuiet(region, 0)
end

local function GiveBackAll()
	for region, alpha in pairs(hidden) do
		SetAlphaQuiet(region, alpha)
		hidden[region] = nil
	end
	if overlay then overlay:Hide() end
end

local function Layout()
	if not overlay then return false end
	local find = KUI.FindPlayerManaBar
	local mana = find and find()
	local ring = KUI.PORTRAIT_RING
	if not (mana and ring) then
		layoutNote = "power bar not found -- old art not shown"
		return false
	end
	local W = Ask(mana, "GetWidth")
	if type(W) ~= "number" or W <= 0 then
		layoutNote = "power bar has no width yet"
		return false
	end
	local pixel = KUI.UnitsPerPixel and KUI.UnitsPerPixel(mana) or 1
	local k = ring.r * W / RING_R
	local cx = ring.cx * W
	local cyUp = ring.up * W - ring.dropPx * pixel
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", cx - RING_X * k, cyUp + RING_Y * k)
	overlay:SetSize(PIECE_W * k, PIECE_H * k)
	layoutNote = string.format("%.1f x %.1f UI units, top-left %.1f, %.1f from the power bar's bottom-left (power bar %.1f wide)",
		PIECE_W * k, PIECE_H * k, cx - RING_X * k, cyUp + RING_Y * k, W)
	if not manaHooked and mana.HookScript then
		manaHooked = true
		mana:HookScript("OnSizeChanged", function() if Enabled() and overlay and overlay:IsShown() then Layout() end end)
	end
	return true
end

local function MakeOverlay(likeRegion)
	if overlay then return end
	local holder = (likeRegion and likeRegion.GetParent and likeRegion:GetParent()) or _G.PlayerFrame
	local layer, sublevel = Ask(likeRegion or holder, "GetDrawLayer")
	overlay = holder:CreateTexture("KainUIForeverOldPlayerArt", layer or "BORDER", nil, sublevel or 0)
	overlay:SetTexture(OLD_PLAYER)
	overlay:SetTexCoord(0, PIECE_W / TEX_W, 0, PIECE_H / TEX_H)
end

local function ApplyNow()
	if not Enabled() then
		GiveBackAll()
		return
	end
	local wide = FindFrameArt()
	if #wide == 0 then
		GiveBackAll()
		layoutNote = "Blizzard's ring and panel not recognised -- old art not shown"
		return
	end
	MakeOverlay(PlayerFrameTexture() or wide[1])
	if not Layout() then
		GiveBackAll()
		return
	end
	for _, region in ipairs(wide) do Hide(region) end
	overlay:Show()
end

function KUI:ApplyClassicFrameArt()
	local ok, err = pcall(ApplyNow)
	if not ok and not errorShown then
		errorShown = true
		print("|cffff6060Kain-UI Forever:|r restoring the old portrait art hit an error and will stay quiet about it: " .. tostring(err))
	end
end

function KUI:SetClassicFrameArt(enabled)
	if not KUI.db then return end
	KUI.db.classicFrameArt = enabled and true or false
	KUI:ApplyClassicFrameArt()
end

local function Describe(region)
	local w, h = Ask(region, "GetWidth"), Ask(region, "GetHeight")
	return string.format("%s %sx%s atlas %s alpha %s", (region.GetDebugName and region:GetDebugName()) or "?",
		w and string.format("%.0f", w) or "?", h and string.format("%.0f", h) or "?",
		tostring(Ask(region, "GetAtlas")), tostring(Ask(region, "GetAlpha")))
end

function KUI:FrameArtScanReport()
	print("|cff33ff99Kain-UI Forever|r portrait art scan:")
	local wide, fromFile = FindFrameArt()
	print("  restore old portrait art: " .. (Enabled() and "ON" or "OFF") .. " | uiunitframe file matched " .. matchMode)
	local ids = {}
	for id in pairs(learned) do ids[#ids + 1] = tostring(id) end
	table.sort(ids)
	print("  file IDs learned: " .. (#ids > 0 and table.concat(ids, ", ") or "none"))
	print(string.format("  PlayerFrame textures from that file: %d (wide enough to hide: %d)", #fromFile, #wide))
	for _, region in ipairs(fromFile) do
		print("    " .. (hidden[region] ~= nil and "[hidden] " or "") .. Describe(region))
	end
	print("  old art: " .. (overlay and (overlay:IsShown() and "showing" or "made, hidden") or "not made") .. " -- " .. layoutNote)
	local tex = PlayerFrameTexture()
	if tex then
		local names, fileIds = FileClues(tex)
		print(string.format("  PlayerFrame FrameTexture: %s | names: %s | IDs: %s", Describe(tex),
			#names > 0 and table.concat(names, ", ") or "none", #fileIds > 0 and table.concat(fileIds, ", ") or "none"))
	else
		print("  PlayerFrame FrameTexture: not found")
	end
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function()
	if Enabled() then KUI:ApplyClassicFrameArt() end
end)
