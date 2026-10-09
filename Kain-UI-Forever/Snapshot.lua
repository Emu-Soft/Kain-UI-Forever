local _, KUI = ...

local EXCLUDE = {
	castByCache = true, chatHistory = true, contrastSavedValues = true,
	lootRollScreenBase = true, lootRollRawBase = true, rxpCharKey = true,
	emojiProbeLog = true,
	xpSession = true,
}

local function Excluded(key)
	if EXCLUDE[key] then return true end
	if type(key) == "string" and (key:find("Log$") or key:find("Probe")) then return true end
	return false
end

local LIVE_EXTRA = { "Minimap", "MinimapCluster", "QuickJoinToastButton", "BNToastFrame" }

local function FormatNumber(n)
	if n == math.floor(n) then return tostring(n) end
	return string.format("%.1f", n)
end

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" or ta == "string" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function KeyText(k)
	if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
	if type(k) == "number" then return "[" .. FormatNumber(k) .. "]" end
	return "[" .. string.format("%q", tostring(k)) .. "]"
end

local INLINE_LIMIT = 100

local function SerializeString(v)

	local out = { '"' }
	for i = 1, #v do
		local b = v:byte(i)
		if b == 34 then out[#out + 1] = '\\"'
		elseif b == 92 then out[#out + 1] = "\\\\"
		elseif b == 124 then out[#out + 1] = "\\124"
		elseif b >= 32 and b <= 126 then out[#out + 1] = string.char(b)
		else out[#out + 1] = string.format("\\%03d", b) end
	end
	out[#out + 1] = '"'
	return table.concat(out)
end

local Serialize
local function SerializeInline(v, depth)
	local keys = SortedKeys(v)
	local parts = {}
	for _, k in ipairs(keys) do
		local x = v[k]
		local s
		if type(x) == "table" and not (issecretvalue and issecretvalue(x)) then
			if x.GetObjectType or depth > 6 then s = nil else s = SerializeInline(x, depth + 1) end
		else
			s = Serialize(x, 0, depth + 1)
		end
		if s then parts[#parts + 1] = KeyText(k) .. " = " .. s end
	end
	if #parts == 0 then return "{}" end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

function Serialize(v, indent, depth)
	if issecretvalue and issecretvalue(v) then return nil end
	local t = type(v)
	if t == "number" then return FormatNumber(v) end
	if t == "string" then return SerializeString(v) end
	if t == "boolean" then return tostring(v) end
	if t ~= "table" or depth > 6 then return nil end
	if v.GetObjectType then return nil end
	local inline = SerializeInline(v, depth)
	if #inline <= INLINE_LIMIT then return inline end
	local pad = string.rep("  ", indent + 1)
	local parts = {}
	for _, k in ipairs(SortedKeys(v)) do
		local s = Serialize(v[k], indent + 1, depth + 1)
		if s then parts[#parts + 1] = pad .. KeyText(k) .. " = " .. s .. "," end
	end
	if #parts == 0 then return "{}" end
	return "{\n" .. table.concat(parts, "\n") .. "\n" .. string.rep("  ", indent) .. "}"
end

local function ScreenTopLeft(f)
	local ok, left, top, scale = pcall(function() return f:GetLeft(), f:GetTop(), f:GetEffectiveScale() end)
	if not ok or type(left) ~= "number" or type(top) ~= "number" or type(scale) ~= "number" then return nil end
	local ratio = scale / UIParent:GetEffectiveScale()
	return left * ratio, top * ratio
end

local sizes = {}

local function PlayerFullName()
	if GetUnitName then
		local ok, n = pcall(GetUnitName, "player", true)
		if ok and type(n) == "string" and not (issecretvalue and issecretvalue(n)) and n ~= "" then return n end
	end
	local ok, n = pcall(UnitName, "player")
	return ok and n or "?"
end

local function NowWhere()
	local parts = {}
	local okZ, zone = pcall(GetRealZoneText)
	parts[#parts + 1] = (okZ and type(zone) == "string" and not (issecretvalue and issecretvalue(zone)) and zone ~= "" and zone) or "unknown zone"
	local okI, inInstance, kind = pcall(IsInInstance)
	if okI and inInstance == true then parts[#parts + 1] = "in a " .. tostring(kind or "instance") end
	local okC, combat = pcall(InCombatLockdown)
	if okC and combat == true then parts[#parts + 1] = "in combat" end
	return table.concat(parts, ", ")
end

local function OtherAddons()
	local list = {}
	local num = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
	local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if not (num and info and isLoaded) then return list end
	local okN, count = pcall(num)
	if not okN or type(count) ~= "number" then return list end
	for i = 1, count do
		local okI, name = pcall(info, i)
		if okI and type(name) == "string" and name ~= "Kain-UI-Forever" then
			local okL, loadedNow = pcall(isLoaded, name)
			if okL and loadedNow then
				local okV, v = pcall(meta, name, "Version")
				list[#list + 1] = name .. ((okV and type(v) == "string" and v ~= "") and (" " .. v) or "")
			end
		end
	end
	table.sort(list)
	return list
end

local function BuildSnapshot()
	sizes = {}
	local lines = {}
	local function Add(s) lines[#lines + 1] = s end

	local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Kain-UI-Forever", "Version"))
		or (GetAddOnMetadata and GetAddOnMetadata("Kain-UI-Forever", "Version")) or "?"

	local name = PlayerFullName()
	local realm = GetRealmName and GetRealmName()
	local pw, ph = 0, 0
	if GetPhysicalScreenSize then pw, ph = GetPhysicalScreenSize() end
	Add("-- Kain-UI Forever snapshot")
	Add(string.format("-- version %s, taken %s", tostring(version), date and date("%Y-%m-%d %H:%M") or "?"))
	Add(string.format("-- character: %s - %s", tostring(name), tostring(realm)))
	Add(string.format("-- screen: %dx%d pixels, UI %sx%s units, UI scale %s",
		pw or 0, ph or 0, FormatNumber(UIParent:GetWidth()), FormatNumber(UIParent:GetHeight()),
		FormatNumber(UIParent:GetEffectiveScale() * 100) .. "%"))

	local okB, gameVersion, build, buildDate, iface = pcall(GetBuildInfo)
	if okB then
		Add(string.format("-- game: %s (build %s, %s), interface %s", tostring(gameVersion), tostring(build), tostring(buildDate), tostring(iface)))
	end
	Add("-- right now: " .. NowWhere())
	Add("")

	local errors = KUI.GetErrorLog and KUI:GetErrorLog() or {}

	for i, e in ipairs(errors) do e.__order = i end
	table.sort(errors, function(a, b)
		if (a.l or 0) ~= (b.l or 0) then return (a.l or 0) > (b.l or 0) end
		return a.__order > b.__order
	end)
	for _, e in ipairs(errors) do e.__order = nil end
	if #errors == 0 then
		Add("-- errors: none caught from this addon")
	else
		Add(string.format("-- errors from this addon (%d, newest first). After sending this, /kui clearerrors empties the list.", #errors))
		Add("errors = {")
		for _, e in ipairs(errors) do
			local when = (e.l and date) and date("%Y-%m-%d %H:%M", e.l) or e.when or "?"

			local fields = {
				Serialize(e.k == "blocked" and "blocked action" or "error", 0, 1),
				"times = " .. (tonumber(e.n) or 1),
				"last = " .. Serialize(when, 0, 1),
			}
			for _, f in ipairs({ { "version", e.v }, { "where", e.w }, { "character", e.c }, { "from", e.from } }) do
				if type(f[2]) == "string" and f[2] ~= "" and f[2] ~= "?" then fields[#fields + 1] = f[1] .. " = " .. Serialize(f[2], 0, 1) end
			end
			Add("  { " .. table.concat(fields, ", ") .. ",")
			Add("    message = " .. (Serialize(e.m or "?", 0, 1) or '"?"') .. ",")
			if type(e.s) == "table" and #e.s > 0 then
				Add("    stack = {")
				for _, line in ipairs(e.s) do Add("      " .. (Serialize(line, 0, 1) or '"?"') .. ",") end
				Add("    },")
			end
			Add("  },")
		end
		Add("}")
	end
	Add("")

	local others = OtherAddons()
	Add(string.format("-- other addons loaded (%d): %s", #others, #others > 0 and table.concat(others, ", ") or "none"))
	Add("")

	Add("settings = {")
	local db = KUI.db or {}
	for _, k in ipairs(SortedKeys(db)) do
		if not Excluded(k) then
			local s = Serialize(db[k], 1, 1)
			if s then
				Add("  " .. KeyText(k) .. " = " .. s .. ",")
				sizes[#sizes + 1] = { key = k, size = #s }
			end
		end
	end
	Add("}")
	Add("")

	Add("-- where each frame's top-left is on screen right now (from the bottom-left)")
	Add("live = {")
	local names = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and k:find("^KainUIForever") and type(v) == "table" and v.GetLeft then names[#names + 1] = k end
	end
	table.sort(names)
	for _, n in ipairs(LIVE_EXTRA) do names[#names + 1] = n end
	for _, n in ipairs(names) do
		local f = _G[n]
		if f and f.IsShown then
			local left, top = ScreenTopLeft(f)
			local shown = f:IsShown() and "shown" or "hidden"
			if left then
				Add(string.format("  %s = { left = %s, top = %s }, -- %s", n, FormatNumber(left), FormatNumber(top), shown))
			else
				Add(string.format("  -- %s: no position (%s)", n, shown))
			end
		end
	end
	Add("}")
	return table.concat(lines, "\n")
end

local PAGE_LIMIT = 12000

local function SplitPages(text)
	local pages, current = {}, {}
	local size = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		if size > 0 and size + #line + 1 > PAGE_LIMIT then
			pages[#pages + 1] = table.concat(current, "\n")
			current, size = {}, 0
		end
		current[#current + 1] = line
		size = size + #line + 1
	end
	if #current > 0 then pages[#pages + 1] = table.concat(current, "\n") end
	return pages
end

local function CleanText(text)
	if not text:find("[^\n\032-\126]") then return text end
	local out, i, n = {}, 1, #text
	while i <= n do
		local b = text:byte(i)
		local piece, len
		if b == 10 or (b >= 32 and b <= 126) then
			piece, len = string.char(b), 1
		else
			len = (b >= 194 and b < 224 and 2) or (b >= 224 and b < 240 and 3) or (b >= 240 and b < 245 and 4)
			if len and i + len - 1 <= n then
				piece = text:sub(i, i + len - 1)
				for j = 2, len do
					local c = piece:byte(j)
					if c < 128 or c >= 192 then piece = nil break end
				end
			end
		end
		if piece then
			out[#out + 1] = piece
			i = i + len
		else
			out[#out + 1] = "?"
			i = i + 1
		end
	end
	return table.concat(out)
end

function KUI:ShowSnapshot(arg)
	local ok, text = pcall(BuildSnapshot)
	if not ok then
		print("|cffff6060Kain-UI Forever:|r couldn't build the snapshot: " .. tostring(text))
		return
	end
	text = text:gsub("\t", "  ")

	text = text:gsub("|", "/")
	text = CleanText(text)
	local pages = SplitPages(text)
	local page = math.max(1, math.min(#pages, tonumber(arg) or 1))
	local body = pages[page]
	if #pages > 1 then
		body = string.format("-- page %d of %d (paste every page, in order)\n", page, #pages) .. body
	end

	table.sort(sizes, function(a, b) return a.size > b.size end)
	local big = {}
	for i = 1, math.min(3, #sizes) do big[i] = string.format("%s (%d)", tostring(sizes[i].key), sizes[i].size) end
	print(string.format("|cff33ff99Kain-UI Forever|r snapshot: %d characters in %d page(s), showing page %d%s. Biggest: %s",
		#text, #pages, page, (#pages > 1 and page < #pages) and (" -- /kui snapshot " .. (page + 1) .. " for the next") or "",
		#big > 0 and table.concat(big, ", ") or "-"))
	if KUI.ShowCopyText then
		local title = "Kain-UI snapshot" .. (#pages > 1 and string.format(" -- page %d of %d", page, #pages) or "") .. " -- Ctrl+C to copy"
		KUI:ShowCopyText(title, body)
	else
		print("|cffff6060Kain-UI Forever:|r the copy window isn't available (Chat.lua not loaded).")
	end
end
