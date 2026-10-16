local addonName, KUI = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\UnitFrames\\"
local OLD_ART = {
	["1x"] = MEDIA .. "uiunitframec60",
	["2x"] = MEDIA .. "uiunitframe2xc60",
}

local NAME_2X, NAME_1X = "uiunitframe2xc60", "uiunitframec60"

local KNOWN_FILE_IDS = {}

local ROOTS = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
	"TargetFrameToT", "FocusFrameToT", "PartyFrame" }
local MAX_DEPTH = 8

local tracked = {}
local hooked = {}
local learned = {}
local matchMode = "not scanned yet"
local busy = false
local errorShown = false

local function Enabled()
	return KUI.db and KUI.db.classicFrameArt == true
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function Ask(region, method)
	local fn = region[method]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, region)
	if not ok or IsSecret(v) then return nil end
	return v
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

local function VariantFromNames(names)
	for _, n in ipairs(names) do
		if n:find(NAME_2X, 1, true) then return "2x" end
		if n:find(NAME_1X, 1, true) then return "1x" end
	end
	return nil
end

local function VariantFromIDs(ids)
	for _, id in ipairs(ids) do
		local v = KNOWN_FILE_IDS[id] or learned[id]
		if v then return v end
	end
	return nil
end

local OUR_PREFIX = MEDIA:lower()
local function ShowingOurs(region)
	local tex = Ask(region, "GetTexture")
	return type(tex) == "string" and tex:lower():sub(1, #OUR_PREFIX) == OUR_PREFIX
end

local function Identify(region)
	if ShowingOurs(region) then return nil end
	local names, ids = FileClues(region)
	local variant = VariantFromNames(names)
	if variant then
		for _, id in ipairs(ids) do learned[id] = learned[id] or variant end
		return variant, "name"
	end
	variant = VariantFromIDs(ids)
	if variant then return variant, "file ID" end
	return nil
end

local function IsTexture(region)
	local kind = Ask(region, "GetObjectType")
	return kind == "Texture"
end

local function Walk(frame, depth, rootName, out)
	if depth > MAX_DEPTH or type(frame) ~= "table" then return end
	if frame.IsForbidden and frame:IsForbidden() then return end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if IsTexture(region) then out[#out + 1] = { region, rootName } end
		end
	end
	if Ask(frame, "GetObjectType") == "StatusBar" and frame.GetStatusBarTexture then
		local ok, tex = pcall(frame.GetStatusBarTexture, frame)
		if ok and type(tex) == "table" then out[#out + 1] = { tex, rootName, frame } end
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			Walk(child, depth + 1, rootName, out)
		end
	end
end

local function AllTextures()
	local out = {}
	for _, name in ipairs(ROOTS) do
		local root = _G[name]
		if type(root) == "table" then Walk(root, 0, name, out) end
	end
	return out
end

local function IsWholeFile(c)
	return #c == 8 and c[1] == 0 and c[2] == 0 and c[3] == 0 and c[4] == 1
		and c[5] == 1 and c[6] == 0 and c[7] == 1 and c[8] == 1
end

local function CurrentCoords(region, atlas)
	local c = { region:GetTexCoord() }
	if #c == 8 and not IsWholeFile(c) then return c end
	if atlas and C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
		if ok and type(info) == "table" then
			local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
			if type(l) == "number" and type(r) == "number" and type(t) == "number" and type(b) == "number" then
				return { l, t, l, b, r, t, r, b }
			end
		end
	end
	return c
end

local Recheck

local function Swap(region, variant, how, rootName)
	local st = tracked[region] or {}
	tracked[region] = st
	st.root = rootName or st.root
	st.atlas = Ask(region, "GetAtlas")
	st.file = (not st.atlas) and (Ask(region, "GetTextureFileID") or Ask(region, "GetTexture")) or nil
	st.coords = CurrentCoords(region, st.atlas)
	st.variant, st.how = variant, how
	region:SetTexture(OLD_ART[variant])
	if #st.coords == 8 then region:SetTexCoord(unpack(st.coords)) end
	st.swapped = true
end

local function Restore(region)
	local st = tracked[region]
	if not (st and st.swapped) then return end
	busy = true
	local ok = pcall(function()
		if st.atlas then
			region:SetAtlas(st.atlas)
		elseif st.file then
			region:SetTexture(st.file)
			if #st.coords == 8 then region:SetTexCoord(unpack(st.coords)) end
		end
	end)
	busy = false
	if ok then st.swapped = false end
end

local function HookTexture(region)
	if hooked[region] or type(region.SetAtlas) ~= "function" then return end
	hooked[region] = true
	hooksecurefunc(region, "SetAtlas", function(self)
		if busy then return end
		local st = tracked[self]
		if st then st.swapped = false end
		if Enabled() then Recheck(self) end
	end)
end

local function HookStatusBar(statusBar)
	if hooked[statusBar] or type(statusBar.SetStatusBarTexture) ~= "function" then return end
	hooked[statusBar] = true
	hooksecurefunc(statusBar, "SetStatusBarTexture", function(self)
		if busy or not Enabled() then return end
		local ok, tex = pcall(self.GetStatusBarTexture, self)
		if ok and type(tex) == "table" and not ShowingOurs(tex) then
			local st = tracked[tex]
			if st then st.swapped = false end
			Recheck(tex)
		end
	end)
end

Recheck = function(region, rootName)
	local st = tracked[region]
	if st and st.swapped then return end
	local variant, how = Identify(region)
	if not variant then return end
	local ok = pcall(Swap, region, variant, how, rootName)
	if ok then HookTexture(region) end
	return ok
end

local learnedFromPlayerFrame = false
local function LearnFromPlayerFrame()
	local container = _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContainer
	local tex = container and container.FrameTexture
	if type(tex) ~= "table" or ShowingOurs(tex) then return false end
	local _, ids = FileClues(tex)
	for _, id in ipairs(ids) do learned[id] = learned[id] or "2x" end
	learnedFromPlayerFrame = #ids > 0
	return learnedFromPlayerFrame
end

local function ApplyNow()
	local textures = AllTextures()
	if not Enabled() then
		for region in pairs(tracked) do Restore(region) end
		return
	end

	local sawName = false
	for _, entry in ipairs(textures) do
		if not ShowingOurs(entry[1]) and VariantFromNames((FileClues(entry[1]))) then sawName = true end
		Recheck(entry[1], entry[2])
	end
	if sawName then
		matchMode = "by file name"
	elseif next(KNOWN_FILE_IDS) then
		matchMode = "by known file IDs"
	elseif learnedFromPlayerFrame or (not next(learned) and LearnFromPlayerFrame()) then
		matchMode = "LAST RESORT: by the player frame's own art (no file names readable)"
	elseif next(learned) then
		matchMode = "by file IDs learned from names earlier"
	else
		matchMode = "nothing to match: no file names, no known IDs, no player frame art found"
	end

	for _, entry in ipairs(textures) do
		Recheck(entry[1], entry[2])
		HookTexture(entry[1])
		if entry[3] then HookStatusBar(entry[3]) end
	end
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

function KUI:FrameArtScanReport()
	print("|cff33ff99Kain-UI Forever|r frame art scan:")
	print("  restore old portrait art: " .. (Enabled() and "ON" or "OFF") .. " | matched " .. matchMode)
	local ids = {}
	for id, v in pairs(learned) do ids[#ids + 1] = tostring(id) .. "=" .. v end
	table.sort(ids)
	print("  uiunitframe file IDs learned: " .. (#ids > 0 and table.concat(ids, ", ") or "none"))
	local perRoot, swapped, total = {}, 0, 0
	for region, st in pairs(tracked) do
		total = total + 1
		if st.swapped then swapped = swapped + 1 end
		local key = st.root or "?"
		perRoot[key] = perRoot[key] or {}
		table.insert(perRoot[key], string.format("%s%s (%s, %s)",
			(region.GetDebugName and region:GetDebugName()) or "?",
			st.swapped and "" or " [Blizzard's]", tostring(st.atlas or st.file), st.variant or "?"))
	end
	print(string.format("  textures from the uiunitframe file: %d, showing the old art: %d", total, swapped))
	for _, name in ipairs(ROOTS) do
		local list = perRoot[name]
		if list then
			table.sort(list)
			print("  " .. name .. ": " .. table.concat(list, "; "))
		elseif _G[name] == nil then
			print("  " .. name .. ": not on this client")
		end
	end

	local container = _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContainer
	local tex = container and container.FrameTexture
	if type(tex) == "table" then
		local names, fileIds = FileClues(tex)
		print(string.format("  PlayerFrame FrameTexture: atlas %s | names: %s | IDs: %s", tostring(Ask(tex, "GetAtlas")),
			#names > 0 and table.concat(names, ", ") or "none", #fileIds > 0 and table.concat(fileIds, ", ") or "none"))
	else
		print("  PlayerFrame FrameTexture: not found")
	end
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function()
	if Enabled() then KUI:ApplyClassicFrameArt() end
end)
