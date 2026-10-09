local _, KUI = ...

local lastAttempt
local watchEnabled = false
local watchUnit = nil

local lastReason

local function ResolveAuraCasterByIndex(unit, index, filter)
	if not unit or not index then lastReason = "no unit or index" return nil end
	filter = filter or "HELPFUL"
	lastReason = "by index: no API returned a usable caster"

	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
		if ok and data then

			local source = data.sourceUnit
			if type(source) == "nil" then source = data.source end
			if type(source) ~= "nil" and not (issecretvalue and issecretvalue(source)) and UnitExists(source) then
				return source, "C_UnitAuras.GetAuraDataByIndex"
			end
		end
	end

	for _, entry in ipairs({ { UnitAura, "UnitAura" }, { UnitBuff, "UnitBuff" }, { UnitDebuff, "UnitDebuff" } }) do
		local fn, fnName = entry[1], entry[2]
		if type(fn) == "function" then
			local ok, _, _, _, _, _, _, source = pcall(fn, unit, index, filter)
			if ok and source and UnitExists(source) then
				return source, fnName
			end
		end
	end

	return nil
end

local function SourceFromData(data)
	if not data then return nil, "no aura data" end

	local source = data.sourceUnit
	if issecretvalue and issecretvalue(source) then return nil, "caster is secret" end
	if type(source) == "nil" then source = data.source end
	if issecretvalue and issecretvalue(source) then return nil, "caster is secret" end
	if type(source) == "nil" then return nil, "aura data has no caster (sourceUnit nil)" end
	if not UnitExists(source) then return nil, "caster unit '" .. tostring(source) .. "' doesn't exist" end
	return source
end

local function ResolveAuraCasterByInstanceID(unit, auraInstanceID)
	if not unit or not auraInstanceID then lastReason = "no unit or aura ID" return nil end
	if issecretvalue and issecretvalue(auraInstanceID) then lastReason = "aura ID is secret" return nil end

	if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
		local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
		local source, why = SourceFromData(ok and data or nil)
		if source then return source, "C_UnitAuras.GetAuraDataByAuraInstanceID" end
		lastReason = "by ID: " .. (ok and why or "lookup errored")
	end

	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
			for i = 1, 80 do
				local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
				if not ok or not data then break end
				local id = data.auraInstanceID
				if id and not (issecretvalue and issecretvalue(id)) and id == auraInstanceID then
					local source, why = SourceFromData(data)
					if source then return source, "C_UnitAuras.GetAuraDataByIndex (matched by ID)" end
					lastReason = "by scan: " .. why
					return nil
				end
			end
		end
		lastReason = (lastReason or "") .. "; scan: aura ID not found on " .. tostring(unit)
	end

	return nil
end

local CACHE_PERMANENT_MAX_AGE = 24 * 60 * 60

local EXPIRY_TOLERANCE = 2

local LOAD_SETTLE = 10
local LOAD_TOLERANCE = 15
local loading = false
local loadingSince = 0
local settleUntil = 0
local loadRekeyPending = false
local captureStats = { seen = 0, stored = 0, noCaster = 0, rekeyed = 0, loads = 0 }
local byInstance = {}

local function Tolerance()
	return loadRekeyPending and LOAD_TOLERANCE or EXPIRY_TOLERANCE
end

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function CacheTable()
	if not KUI.db then return nil end
	KUI.db.castByCache = KUI.db.castByCache or {}
	return KUI.db.castByCache
end

local function AuraCacheKey(data)
	if not data then return nil end
	local spellId, exp = data.spellId, data.expirationTime
	if not (Plain(spellId) and Plain(exp)) then return nil end
	return format("%s:%.1f", tostring(spellId), exp or 0), exp or 0
end

local function UnitGUIDPlain(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and Plain(guid) then return guid end
end

local function EntrySpell(key, entry)
	if entry.s ~= nil then return tostring(entry.s) end
	return key:match("^([^:]+):")
end

local function CacheStore(unit, data, name, classFile)
	local cache = CacheTable()
	local guid = UnitGUIDPlain(unit)
	local key, exp = AuraCacheKey(data)
	if not (cache and guid and key) then return end
	cache[guid] = cache[guid] or {}
	cache[guid][key] = { n = name, c = classFile, e = exp, t = time(), s = data.spellId }
	local id = data.auraInstanceID
	if unit == "player" and Plain(id) then
		byInstance[id] = { n = name, c = classFile, s = data.spellId, e = exp }
	end
end

local function CacheLookup(unit, data)
	local cache = CacheTable()
	local guid = UnitGUIDPlain(unit)
	if not (cache and guid and data) then return end

	local key, exp = AuraCacheKey(data)
	local id = data.auraInstanceID
	local known = Plain(id) and byInstance[id]
	if unit == "player" and known and Plain(data.spellId) and known.s == data.spellId
		and math.abs((known.e or 0) - (exp or 0)) <= EXPIRY_TOLERANCE then
		return known.n, known.c
	end
	local entries = key and cache[guid]
	if not entries then return end

	if entries[key] then return entries[key].n, entries[key].c end

	local spell = tostring(data.spellId)
	local best, bestGap
	for k, entry in pairs(entries) do
		local gap = math.abs((entry.e or 0) - (exp or 0))
		if EntrySpell(k, entry) == spell and gap <= Tolerance() and (not bestGap or gap < bestGap) then
			best, bestGap = entry, gap
		end
	end
	if best then return best.n, best.c end
end

local function PruneCache()
	local cache = CacheTable()
	if not cache then return end
	local now, epoch = GetTime(), time()
	for guid, entries in pairs(cache) do
		for key, entry in pairs(entries) do
			local timedOut = (entry.e or 0) > 0 and entry.e < now
			local tooOld = epoch - (entry.t or 0) > CACHE_PERMANENT_MAX_AGE
			if timedOut or tooOld then entries[key] = nil end
		end
		if next(entries) == nil then cache[guid] = nil end
	end
end

local function PrunePlayer()
	local cache = CacheTable()
	local guid = UnitGUIDPlain("player")
	local entries = cache and guid and cache[guid]
	if not entries or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end

	if (loading and GetTime() - loadingSince < 120) or GetTime() < settleUntil then return end
	local tolerance = Tolerance()
	local present, current = {}, {}
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 80 do
			local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
			if not ok or not data then break end
			local key, exp = AuraCacheKey(data)
			if not key then return end
			present[key] = true
			current[#current + 1] = { key = key, e = exp, s = tostring(data.spellId) }
		end
	end

	local keys = {}
	for key in pairs(entries) do keys[#keys + 1] = key end
	for _, key in ipairs(keys) do
		local entry = entries[key]
		if entry and not present[key] then

			local spell = EntrySpell(key, entry)
			local target, targetGap
			for _, aura in ipairs(current) do
				local gap = math.abs((entry.e or 0) - (aura.e or 0))
				if aura.s == spell and not entries[aura.key] and gap <= tolerance and (not targetGap or gap < targetGap) then
					target, targetGap = aura, gap
				end
			end
			entries[key] = nil
			if target then
				entry.e = target.e
				entries[target.key] = entry
				for _, known in pairs(byInstance) do
					if known.s ~= nil and tostring(known.s) == spell and math.abs((known.e or 0) - (target.e or 0)) <= tolerance then known.e = target.e end
				end
				captureStats.rekeyed = (captureStats.rekeyed or 0) + 1
			end
		end
	end
	loadRekeyPending = false
	if next(entries) == nil then cache[guid] = nil end
end

local function CaptureCaster(data)
	if type(data) ~= "table" then return end
	captureStats.seen = captureStats.seen + 1
	local source = SourceFromData(data)
	if not source then
		captureStats.noCaster = captureStats.noCaster + 1
		return
	end
	if UnitIsUnit and UnitIsUnit(source, "player") then return end
	local ok, name = pcall(GetUnitName or UnitName, source, true)
	if not (ok and Plain(name) and name ~= "") then return end
	local okClass, _, classFile = pcall(UnitClass, source)
	CacheStore("player", data, name, (okClass and Plain(classFile)) and classFile or nil)
	captureStats.stored = captureStats.stored + 1
end

local function CaptureAllPlayerAuras()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	for i = 1, 80 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not ok or not data then break end
		CaptureCaster(data)
	end
end

local function CaptureFromUpdate(info)
	if type(info) ~= "table" or (issecretvalue and issecretvalue(info)) then return end
	if info.isFullUpdate == true then
		CaptureAllPlayerAuras()
		return
	end
	local added = info.addedAuras
	if type(added) == "table" and not (issecretvalue and issecretvalue(added)) then
		for _, data in ipairs(added) do
			if type(data) == "table" and data.isHelpful ~= false then CaptureCaster(data) end
		end
	end

	local updated = info.updatedAuraInstanceIDs
	if type(updated) == "table" and not (issecretvalue and issecretvalue(updated))
		and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
		for _, id in ipairs(updated) do
			if Plain(id) then
				local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
				if ok and type(data) == "table" and data.isHelpful ~= false then CaptureCaster(data) end
			end
		end
	end

	local removed = info.removedAuraInstanceIDs
	if type(removed) == "table" and not (issecretvalue and issecretvalue(removed)) then
		for _, id in ipairs(removed) do
			if Plain(id) then byInstance[id] = nil end
		end
	end
end

local pruneFrame = CreateFrame("Frame")
pruneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(pruneFrame.RegisterUnitEvent, pruneFrame, "UNIT_AURA", "player")
pcall(pruneFrame.RegisterEvent, pruneFrame, "LOADING_SCREEN_ENABLED")
pcall(pruneFrame.RegisterEvent, pruneFrame, "LOADING_SCREEN_DISABLED")
local prunePending = false

local function StartSettle()
	settleUntil = GetTime() + LOAD_SETTLE
	C_Timer.After(LOAD_SETTLE + 0.5, function() pcall(PrunePlayer) end)
end

pruneFrame:SetScript("OnEvent", function(_, event, unit, info)
	if event == "LOADING_SCREEN_ENABLED" then
		loading = true
		loadingSince = GetTime()
		loadRekeyPending = true
		wipe(byInstance)
		captureStats.loads = (captureStats.loads or 0) + 1
		return
	elseif event == "LOADING_SCREEN_DISABLED" then
		loading = false
		StartSettle()
		return
	end

	if event == "UNIT_AURA" and unit == "player" then
		pcall(CaptureFromUpdate, info)
	elseif event == "PLAYER_ENTERING_WORLD" then

		loadRekeyPending = true
		wipe(byInstance)
		StartSettle()
		pcall(CaptureAllPlayerAuras)
	end
	if prunePending then return end
	prunePending = true
	C_Timer.After(0.5, function()
		prunePending = false
		pcall(PruneCache)
		pcall(PrunePlayer)
	end)
end)

local function AuraDataByIndex(unit, index, filter)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter or "HELPFUL")
	return ok and data or nil
end
local function AuraDataByInstanceID(unit, auraInstanceID)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return nil end
	local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
	return ok and data or nil
end

local function AddCastByLine(tooltip, name, classFile)

	local tipName = tooltip.GetName and tooltip:GetName()
	if tipName and tooltip.NumLines then
		for i = 1, tooltip:NumLines() do
			local fs = _G[tipName .. "TextLeft" .. i]
			local t = fs and fs:GetText()
			if type(t) == "string" and not (issecretvalue and issecretvalue(t)) and t:find("^Cast By: ") then return false end
		end
	end

	local colored = name
	if classFile then
		local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
			or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
		if c then
			if c.WrapTextInColorCode then
				colored = c:WrapTextInColorCode(name)
			elseif c.r then
				colored = format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
			end
		end
	end
	tooltip:AddLine("Cast By: " .. colored, 1, 1, 1)

	local tooltipName = tooltip.GetName and tooltip:GetName()
	if tooltipName and tooltip.NumLines then
		local line = _G[tooltipName .. "TextLeft" .. tooltip:NumLines()]
		if line and line.SetFontObject and GameTooltipTextSmall then
			line:SetFontObject(GameTooltipTextSmall)
		end
	end

	local before = tooltip.GetHeight and tooltip:GetHeight()
	local function Relayout()
		if not tooltip:IsShown() then return end
		pcall(tooltip.Show, tooltip)
		if tooltip.GetPadding and tooltip.SetPadding then
			local r, b, l, t = tooltip:GetPadding()
			if Plain(r) and Plain(b) then
				if l ~= nil and t ~= nil then
					pcall(tooltip.SetPadding, tooltip, r, b, l, t)
				else
					pcall(tooltip.SetPadding, tooltip, r, b)
				end
			end
		end
		tooltip:GetWidth()
	end
	Relayout()
	if C_Timer and C_Timer.After then C_Timer.After(0, Relayout) end
	return true, before, tooltip.GetHeight and tooltip:GetHeight(), tooltip.NumLines and tooltip:NumLines()
end

local function FinishCastBy(tooltip, unit, key, filter, source, api, auraData)
	local info = tooltip and tooltip.processingInfo
	lastAttempt = { unit = unit, index = key, filter = filter, source = source, api = api, sourceName = nil,
		getter = info and info.getterName, reason = (not source) and lastReason or nil }

	if watchEnabled and (watchUnit == nil or watchUnit == unit) then
		local ttName = (tooltip and tooltip.GetName and tooltip:GetName()) or "<unknown tooltip>"
		if source then
			local ok, name = pcall(UnitName, source)
			print(string.format("|cff33ff99Kain-UI Forever|r CastBy watch: tooltip=%s unit=%s key=%s filter=%s => %s via %s",
				ttName, tostring(unit), tostring(key), tostring(filter),
				tostring((ok and name) or source), tostring(api)))
		else
			print(string.format("|cff33ff99Kain-UI Forever|r CastBy watch: tooltip=%s unit=%s key=%s filter=%s => no caster resolved",
				ttName, tostring(unit), tostring(key), tostring(filter)))
		end
	end

	if not tooltip or not tooltip.AddLine then return end

	local name, classFile
	if source then

		local ok, n = pcall(GetUnitName or UnitName, source, true)
		if ok and Plain(n) and n ~= "" then
			name = n
			local okClass, _, cf = pcall(UnitClass, source)
			if okClass and Plain(cf) then classFile = cf end
			CacheStore(unit, auraData, name, classFile)
		else
			lastAttempt.reason = "caster's name unavailable"
		end
	end
	if not name then

		name, classFile = CacheLookup(unit, auraData)
		if name then lastAttempt.api = "cache" end
	end
	if not name then return end
	lastAttempt.sourceName = name
	lastAttempt.classFile = classFile

	local added, before, after, lines = AddCastByLine(tooltip, name, classFile)
	if added then
		lastAttempt.lineAdded = true
		lastAttempt.lines = lines
		lastAttempt.heightBefore = before
		lastAttempt.heightAfter = after
	end
end

local function AppendCastByIndex(tooltip, unit, index, filter)
	local source, api = ResolveAuraCasterByIndex(unit, index, filter)
	local auraData = AuraDataByIndex(unit, index, filter)
	FinishCastBy(tooltip, unit, index, filter, source, api, auraData)
end

local function AppendCastByInstanceID(tooltip, unit, auraInstanceID, filter)
	local source, api = ResolveAuraCasterByInstanceID(unit, auraInstanceID)
	local auraData = AuraDataByInstanceID(unit, auraInstanceID)
	FinishCastBy(tooltip, unit, auraInstanceID, filter, source, api, auraData)
end

local hookedTooltips = {}
local function HookAuraTooltip(tt)
	if not tt or hookedTooltips[tt] then return end
	hookedTooltips[tt] = true

	if tt.SetUnitAura then
		hooksecurefunc(tt, "SetUnitAura", function(self, unit, index, filter)
			AppendCastByIndex(self, unit, index, filter)
		end)
	end
	if tt.SetUnitBuff then
		hooksecurefunc(tt, "SetUnitBuff", function(self, unit, index, filter)
			AppendCastByIndex(self, unit, index, filter)
		end)
	end
	if tt.SetUnitDebuff then
		hooksecurefunc(tt, "SetUnitDebuff", function(self, unit, index, filter)
			AppendCastByIndex(self, unit, index, filter)
		end)
	end
	if tt.SetUnitBuffByAuraInstanceID then
		hooksecurefunc(tt, "SetUnitBuffByAuraInstanceID", function(self, unit, auraInstanceID, filter)
			AppendCastByInstanceID(self, unit, auraInstanceID, filter)
		end)
	end
	if tt.SetUnitAuraByAuraInstanceID then
		hooksecurefunc(tt, "SetUnitAuraByAuraInstanceID", function(self, unit, auraInstanceID, filter)
			AppendCastByInstanceID(self, unit, auraInstanceID, filter)
		end)
	end
	if tt.SetUnitDebuffByAuraInstanceID then
		hooksecurefunc(tt, "SetUnitDebuffByAuraInstanceID", function(self, unit, auraInstanceID, filter)
			AppendCastByInstanceID(self, unit, auraInstanceID, filter)
		end)
	end
end

local usingPostCall = false
local hookCalls = { UnitAura = 0, Spell = 0 }
local lastHookError

local lastSeen

local function Describe(v)
	if v == nil then return "nil" end
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	return tostring(v)
end

local iconRouteLast
local iconRouteRuns = 0

local function Field(frame, key)
	if not frame then return nil end
	local ok, v = pcall(function() return frame[key] end)
	if ok and v ~= nil and not (issecretvalue and issecretvalue(v)) then return v end
end

local function AuraFromOwner(tooltip)
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if not okOwner or not owner then return nil end
	local id = Field(owner, "auraInstanceID") or Field(owner, "auraInstanceId")

	local unit = Field(owner, "unit")
	local f = owner
	for _ = 1, 8 do
		if unit then break end

		local okP, parent = pcall(function() return f:GetParent() end)
		if not okP or not parent then break end
		unit = Field(parent, "unit")
		f = parent
	end
	if not unit then
		local okA, attr = pcall(function() return owner:GetAttribute("unit") end)
		if okA and attr and not (issecretvalue and issecretvalue(attr)) then unit = attr end
	end
	return unit, id, owner
end

local function OnUnitAuraTooltip(tooltip, data, dataTypeName)
	if not tooltip then return end
	local info = tooltip.processingInfo
	local getter = info and info.getterName
	local args = info and info.getterArgs
	local ownerUnit, ownerAuraID, owner = AuraFromOwner(tooltip)

	if dataTypeName == "Spell" and not ownerAuraID then return end
	local ownerName
	if owner then
		local okN, n = pcall(function() return owner:GetName() end)
		if okN then ownerName = n end
	end

	lastSeen = {
		type = dataTypeName or "UnitAura",
		getter = Describe(getter),
		owner = Describe(ownerName or (owner and "<unnamed frame>")),
		ownerUnit = Describe(ownerUnit), ownerAuraID = Describe(ownerAuraID),
	}

	local isAuraGetter = type(getter) == "string" and type(args) == "table"
		and (getter:find("Aura") or getter == "GetUnitBuff" or getter == "GetUnitDebuff")
	if isAuraGetter then
		local unit = args[1]
		if unit and not (issecretvalue and issecretvalue(unit)) then
			lastSeen.tooltipUnit = Describe(unit)
			if getter:find("ByAuraInstanceID") then

				if ownerUnit and ownerUnit ~= unit then

					if AuraDataByInstanceID(ownerUnit, args[2]) then
						lastSeen.result = "used the icon's frame unit (" .. Describe(ownerUnit) .. ") with the tooltip's aura ID"
						AppendCastByInstanceID(tooltip, ownerUnit, args[2], args[3])
						return
					end
					lastSeen.result = "aura ID not on the frame's unit (" .. Describe(ownerUnit) .. "); used the tooltip's unit"
				else
					lastSeen.result = "used processingInfo"
				end
				AppendCastByInstanceID(tooltip, unit, args[2], args[3])
			else
				lastSeen.result = "used processingInfo"
				local filter = args[3]
				if getter == "GetUnitBuff" then filter = filter or "HELPFUL" end
				if getter == "GetUnitDebuff" then filter = filter or "HARMFUL" end
				AppendCastByIndex(tooltip, unit, args[2], filter)
			end
			return
		end
	end

	if ownerUnit and ownerAuraID then
		lastSeen.result = "used the hovered icon's unit + aura ID"
		AppendCastByInstanceID(tooltip, ownerUnit, ownerAuraID, nil)
		return
	end
	lastSeen.result = "stopped: no usable getter record and no unit/aura ID on the hovered icon"
end

local function SafeAuraTooltip(tooltip, data, dataTypeName)
	hookCalls[dataTypeName] = (hookCalls[dataTypeName] or 0) + 1
	local ok, err = pcall(OnUnitAuraTooltip, tooltip, data, dataTypeName)
	if not ok then lastHookError = tostring(err) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
	and Enum.TooltipDataType.UnitAura ~= nil then
	usingPostCall = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.UnitAura,
		function(tooltip, data) SafeAuraTooltip(tooltip, data, "UnitAura") end)

	if Enum.TooltipDataType.Spell ~= nil then
		pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Spell,
			function(tooltip, data) SafeAuraTooltip(tooltip, data, "Spell") end)
	end
end

if not usingPostCall then
	HookAuraTooltip(GameTooltip)

for _, candidate in ipairs({
	"EmbeddedItemTooltip",
	"BuffTooltip",
	"GameTooltip2",
	"ShoppingTooltip1",
	"ShoppingTooltip2",
}) do
	local tt = _G[candidate]
	if tt then
		HookAuraTooltip(tt)
	end
end
end

if not usingPostCall and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
	pcall(function()
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
			HookAuraTooltip(tooltip)
		end)
	end)
end

function KUI:CastByScanReport()
	print(string.format("|cff33ff99Kain-UI Forever|r Cast By, buffs as they land this session: %d seen, %d caster(s) remembered, %d with no caster available, %d kept through a time change, %d loading screen(s)%s",
		captureStats.seen, captureStats.stored, captureStats.noCaster, captureStats.rekeyed or 0, captureStats.loads or 0,
		loading and " (loading now)" or (GetTime() < settleUntil and " (settling after a load)" or "")))
	print(format("|cff33ff99Kain-UI Forever|r Cast By hook calls this session: %d aura, %d spell%s",
		hookCalls.UnitAura or 0, hookCalls.Spell or 0,
		lastHookError and "" or " (no errors)"))
	if lastHookError then print("  |cffff5555last hook error:|r " .. lastHookError) end
	print("  icon route checks this session: " .. tostring(iconRouteRuns)
		.. " (watching: " .. (KUI.CastByIconRouteTooltips and KUI:CastByIconRouteTooltips() or "?") .. ")")
	if iconRouteLast then
		print("  icon route last (" .. tostring(iconRouteLast.tip) .. "): " .. iconRouteLast.step .. " -- unit " .. tostring(iconRouteLast.unit)
			.. ", first line \"" .. tostring(iconRouteLast.text) .. "\"")
		if iconRouteLast.chain then print("    frames above the icon: " .. iconRouteLast.chain) end
	end
	if lastSeen then
		print("|cff33ff99Kain-UI Forever|r Cast By: last aura/spell tooltip seen -- type " .. lastSeen.type
			.. ", getter " .. lastSeen.getter .. ", hovered icon " .. lastSeen.owner
			.. " (frame unit " .. lastSeen.ownerUnit .. ", icon aura ID " .. lastSeen.ownerAuraID
			.. "; tooltip's unit " .. tostring(lastSeen.tooltipUnit or "n/a") .. ")")
		print("  -> " .. tostring(lastSeen.result))
	end
	print("|cff33ff99Kain-UI Forever|r Cast By method: " .. (usingPostCall
		and "Blizzard's unit-aura tooltip post-call (covers every aura tooltip)"
		or "fallback Set* hooks (this client has no unit-aura post-call)"))
	if not lastAttempt then
		print("|cff33ff99Kain-UI Forever|r Cast By: no aura tooltip seen yet this session -- hover a buff/debuff icon, then run this again.")
		return
	end
	print(string.format("|cff33ff99Kain-UI Forever|r Cast By: last aura tooltip -- unit=%s, key=%s, filter=%s",
		tostring(lastAttempt.unit), tostring(lastAttempt.index), tostring(lastAttempt.filter)))
	print("  filled by: " .. tostring(lastAttempt.getter or "(unknown -- a fallback hook)"))
	if lastAttempt.reason then print("  stopped at: " .. lastAttempt.reason) end
	if lastAttempt.lineAdded then
		local function h(v) return (v and Plain(v)) and tostring(math.floor(v + 0.5)) or "?" end
		print("  line added: yes -- tooltip now " .. tostring(lastAttempt.lines) .. " lines, height "
			.. h(lastAttempt.heightBefore) .. " -> " .. h(lastAttempt.heightAfter))
	end
	if lastAttempt.source then
		print("  Resolved caster via " .. tostring(lastAttempt.api) .. ": " .. tostring(lastAttempt.sourceName or lastAttempt.source))
	else
		print("  Could not resolve a caster -- either this client didn't report one for that aura (common for NPC debuffs, or auras from units no longer in range), or none of the tried APIs (C_UnitAuras.GetAuraDataByIndex, C_UnitAuras.GetAuraDataByAuraInstanceID, UnitAura, UnitBuff, UnitDebuff) worked here.")
		print("  Tip: if lastAttempt shows unit=nil, the hook isn't reaching the tooltip object used by this buff frame. Enable /kainui castbywatch to confirm which tooltip object is firing (if any).")
	end

	local hookedNames = {}
	for tt in pairs(hookedTooltips) do
		local name = (tt.GetName and tt:GetName()) or "<unnamed>"
		table.insert(hookedNames, name)
	end
	table.sort(hookedNames)
	print("  Hooked tooltip objects this session: " .. (#hookedNames > 0 and table.concat(hookedNames, ", ") or "(none yet -- did PLAYER_LOGIN fire?)"))
end

function KUI:CastByWatch(arg)
	local requestedUnit = (arg and arg ~= "") and arg or nil

	if watchEnabled and watchUnit == requestedUnit then

		watchEnabled = false
		watchUnit = nil
		print("|cff33ff99Kain-UI Forever|r CastBy watch OFF.")
	else
		watchEnabled = true
		watchUnit = requestedUnit
		if watchUnit then
			print(string.format("|cff33ff99Kain-UI Forever|r CastBy watch ON (unit filter: %s). Hover a buff/debuff icon on that unit to see hook output. Run /kainui castbywatch %s again to turn off.", watchUnit, watchUnit))
		else
			print("|cff33ff99Kain-UI Forever|r CastBy watch ON (all units). Hover any buff/debuff icon to see hook output. Run /kainui castbywatch again to turn off.")
		end
	end
end

local ownerRoute = setmetatable({}, { __mode = "k" })

local function OwnerChain(tip)
	local parts = {}
	local okO, f = pcall(function() return tip:GetOwner() end)
	if not okO then return "(couldn't read the owner)" end
	for _ = 1, 9 do
		if not f then break end
		local okN, n = pcall(function() return f:GetName() end)
		local u = Field(f, "unit")
		parts[#parts + 1] = ((okN and n) or "<unnamed>") .. (u and ("[unit=" .. tostring(u) .. "]") or "")
		local okP, parent = pcall(function() return f:GetParent() end)
		if not okP then parts[#parts + 1] = "<GetParent errored>" break end
		f = parent
	end
	return table.concat(parts, " > ")
end

local function FirstLineText(tip)
	local tipName = tip.GetName and tip:GetName()
	local fs = tipName and _G[tipName .. "TextLeft1"]
	local text = fs and fs:GetText()
	if Plain(text) and text ~= "" then return text end
end

local function FindAuraByName(unit, auraName)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 80 do
			local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
			if not ok or not data then break end
			if Plain(data.name) and data.name == auraName then return data, filter end
		end
	end
end

local function TryOwnerRoute(tip)
	if not (tip and tip:IsShown()) then return end
	iconRouteRuns = iconRouteRuns + 1
	local okTN, tipLabel = pcall(function() return tip:GetName() end)
	tipLabel = okTN and tipLabel or "?"
	local unit = AuraFromOwner(tip)
	local text = FirstLineText(tip)
	if not text then

		local tipNameOk, tipFullName = pcall(function() return tip:GetName() end)
		local fs = tipNameOk and tipFullName and _G[tipFullName .. "TextLeft1"]
		local raw = fs and fs.GetText and fs:GetText()
		local why = (raw == nil and "empty") or ((issecretvalue and issecretvalue(raw)) and "SECRET") or "unreadable"
		local probe = "no unit to probe"
		if unit and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local okP, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL")
			if not okP then probe = "aura lookup errored"
			elseif not d then probe = "no buffs returned"
			else
				local function st(v)
					if v == nil then return "nil" end
					return (issecretvalue and issecretvalue(v)) and "SECRET" or "readable"
				end
				probe = "first buff: name " .. st(d.name) .. ", caster " .. st(d.sourceUnit)
			end
		end
		iconRouteLast = { step = "first line " .. why .. " (" .. probe .. ")", unit = unit,
			chain = OwnerChain(tip), tip = tipLabel }
		return
	end
	if not unit then

		if text then iconRouteLast = { step = "no unit found above the hovered icon", text = text, chain = OwnerChain(tip), tip = tipLabel } end
		return
	end
	if not text then iconRouteLast = { step = "tooltip's first line unreadable", unit = unit, tip = tipLabel } return end
	local key = unit .. "\0" .. text
	local state = ownerRoute[tip]
	if state and state.key == key then

		if state.name then AddCastByLine(tip, state.name, state.classFile) end
		return
	end
	state = { key = key }
	ownerRoute[tip] = state
	local data, filter = FindAuraByName(unit, text)
	if not data then
		iconRouteLast = { step = "no aura named that on " .. tostring(unit), unit = unit, text = text, chain = OwnerChain(tip), tip = tipLabel }
		return
	end
	iconRouteLast = { step = "aura found -- caster lookup ran (see watch/scan)", unit = unit, text = text, tip = tipLabel }
	local source, why = SourceFromData(data)
	if not source then lastReason = "icon route: " .. tostring(why) end
	FinishCastBy(tip, unit, data.auraInstanceID, filter, source,
		source and "icon route (aura found by name on the icon's unit)" or nil, data)
	if lastAttempt and lastAttempt.sourceName then
		state.name, state.classFile = lastAttempt.sourceName, lastAttempt.classFile
	end
end

local ICON_ROUTE_TOOLTIPS = { "GameTooltip", "BuffFrameTooltip" }
local iconRouteHooked = {}
local iconRouteWatched = setmetatable({}, { __mode = "k" })

local function WatchTooltip(tip, label)
	if not tip or iconRouteWatched[tip] then return end
	local okF, forbidden = pcall(function() return tip:IsForbidden() end)
	if not okF or forbidden then return end
	local ok = pcall(function()
		tip:HookScript("OnShow", function(self) pcall(TryOwnerRoute, self) end)
		local elapsedSince = 0
		tip:HookScript("OnUpdate", function(self, elapsed)
			elapsedSince = elapsedSince + (elapsed or 0)
			if elapsedSince < 0.2 then return end
			elapsedSince = 0
			pcall(TryOwnerRoute, self)
		end)
	end)
	if ok then
		iconRouteWatched[tip] = true
		iconRouteHooked[#iconRouteHooked + 1] = label
	end
end

for _, tipName in ipairs(ICON_ROUTE_TOOLTIPS) do
	WatchTooltip(_G[tipName], tipName)
end

do
	local meta = GameTooltip and getmetatable(GameTooltip)
	local methods = meta and meta.__index
	if type(methods) == "table" and type(methods.Show) == "function" then
		pcall(hooksecurefunc, methods, "Show", function(self)
			if iconRouteWatched[self] then return end
			local unit = AuraFromOwner(self)
			if not unit then return end
			local okN, n = pcall(function() return self:GetName() end)
			WatchTooltip(self, ((okN and n) or "<unnamed tooltip>") .. " (found on a unit frame)")
			pcall(TryOwnerRoute, self)
		end)
	end
end

function KUI:CastByIconRouteTooltips()
	return #iconRouteHooked > 0 and table.concat(iconRouteHooked, ", ") or "none"
end
