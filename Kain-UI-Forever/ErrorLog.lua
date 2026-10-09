local addonName, KUI = ...
addonName = addonName or "Kain-UI-Forever"

local MAX_ENTRIES = 15
local MAX_AGE_DAYS = 14
local MAX_MESSAGE = 400
local MAX_STACK_LINES = 6

local pending = {}
local loaded = false
local busy = false
local lastMsg, lastAt
local stats = { caught = 0, ignored = 0, blocked = 0 }

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local FOLDER_PATTERN = addonName:gsub("%-", "%%-")

local function Store()
	if not loaded then return pending end
	if type(_G.KainUIForeverAccountDB) ~= "table" then _G.KainUIForeverAccountDB = {} end
	local db = _G.KainUIForeverAccountDB
	if type(db.errorLog) ~= "table" then db.errorLog = {} end
	return db.errorLog
end

local function Version()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local ok, v = pcall(get, addonName, "Version")
	return (ok and Plain(v) and v) or "?"
end

local function Who()

	local ok, name = false, nil
	if GetUnitName then ok, name = pcall(GetUnitName, "player", true) end
	if not (ok and Plain(name) and name ~= "") then ok, name = pcall(UnitName, "player") end
	local okR, realm = pcall(GetRealmName)
	name = (ok and Plain(name) and name) or "?"
	realm = (okR and Plain(realm) and realm) or "?"
	return name .. "-" .. realm
end

local function Where()
	local parts = {}
	local okZ, zone = pcall(GetRealZoneText)
	parts[#parts + 1] = (okZ and Plain(zone) and zone ~= "" and zone) or "unknown zone"
	local okI, inInstance, kind = pcall(IsInInstance)
	if okI and Plain(inInstance) and inInstance then
		parts[#parts + 1] = "in a " .. ((Plain(kind) and kind) or "instance")
	end
	local okC, combat = pcall(InCombatLockdown)
	if okC and Plain(combat) and combat then parts[#parts + 1] = "in combat" end
	return table.concat(parts, ", ")
end

local function ShortPath(text)
	text = text:gsub("^.-" .. FOLDER_PATTERN .. "[/\\]", "")

	text = text:gsub('^([^%]:"]+%.lua)"?%]', "%1")
	return text
end

local function OurLines(stack)
	local lines = {}
	if type(stack) ~= "string" then return lines end
	for line in stack:gmatch("[^\n]+") do

		if line:find(FOLDER_PATTERN) and not line:find("ErrorLog%.lua") then

			line = ShortPath(line)
			lines[#lines + 1] = line:sub(1, 200)
			if #lines >= MAX_STACK_LINES then break end
		end
	end
	return lines
end

local function ShortMessage(msg)
	msg = ShortPath(msg)
	if #msg > MAX_MESSAGE then msg = msg:sub(1, MAX_MESSAGE) .. "..." end
	return msg
end

local function Prune(log)
	local now = time and time() or 0
	for i = #log, 1, -1 do
		local e = log[i]
		if type(e) ~= "table" or (now - (e.l or 0)) > MAX_AGE_DAYS * 86400 then table.remove(log, i) end
	end
	while #log > MAX_ENTRIES do
		local oldest, oldestAt = 1, math.huge
		for i, e in ipairs(log) do
			if (e.l or 0) < oldestAt then oldest, oldestAt = i, e.l or 0 end
		end
		table.remove(log, oldest)
	end
end

local function Note(kind, msg, stackLines, times)
	times = tonumber(times) or 1
	local log = Store()
	local now = time and time() or 0
	for _, e in ipairs(log) do
		if e.m == msg and e.k == kind then
			e.n = (e.n or 1) + times
			e.l = now
			e.v = Version()
			return
		end
	end
	log[#log + 1] = { k = kind, m = msg, s = stackLines, n = times, f = now, l = now, v = Version(), w = Where(), c = Who() }
	if loaded then Prune(log) end
end

local function Capture(msg, givenStack)
	if busy then return end
	busy = true
	pcall(function()
		if not Plain(msg) then stats.ignored = stats.ignored + 1 return end
		msg = tostring(msg)
		local okGT, now = pcall(GetTime)
		if msg == lastMsg and okGT and now == lastAt then return end
		lastMsg, lastAt = msg, okGT and now or nil
		local stack = ""
		if type(givenStack) == "string" and Plain(givenStack) then
			stack = givenStack
		elseif debugstack then
			local okS, s = pcall(debugstack, 1, 30, 10)
			if okS and Plain(s) and type(s) == "string" then stack = s end
		end
		local ours = OurLines(stack)
		if not msg:find(FOLDER_PATTERN) and #ours == 0 then
			stats.ignored = stats.ignored + 1
			return
		end
		stats.caught = stats.caught + 1
		Note("error", ShortMessage(msg), ours)
	end)
	busy = false
end

local ourHandlers = {}
local function Wrap()
	if not (geterrorhandler and seterrorhandler) then return false end
	local okG, current = pcall(geterrorhandler)
	if not okG or ourHandlers[current] then return false end
	local previous = current
	local handler = function(msg, ...)
		Capture(msg)
		if previous then return previous(msg, ...) end
	end
	ourHandlers[handler] = true
	pcall(seterrorhandler, handler)

	local okC, now = pcall(geterrorhandler)
	return okC and now == handler
end
local wrappedAtLoad = Wrap()

local bugRoute = "none"
local bugNoted = 0

local function FromBugObject(errorObject, times)
	if type(errorObject) ~= "table" then return end
	local msg = errorObject.message
	if not (Plain(msg) and type(msg) == "string") then return end
	if msg:find("^%[ADDON_ACTION_") then return end
	local stack = (Plain(errorObject.stack) and type(errorObject.stack) == "string") and errorObject.stack or ""
	if not msg:find(FOLDER_PATTERN) and #OurLines(stack) == 0 then
		stats.ignored = stats.ignored + 1
		return
	end
	bugNoted = bugNoted + 1
	stats.caught = stats.caught + 1
	busy = true
	pcall(Note, "error", ShortMessage(msg), OurLines(stack), times)
	busy = false
end

if EventRegistry and EventRegistry.RegisterCallback then
	local owner = {}
	local okReg = pcall(EventRegistry.RegisterCallback, EventRegistry, "BugGrabber.BugGrabbed", function(_, tableID)
		pcall(function()
			local bg = _G.BugGrabber
			if type(bg) ~= "table" or not Plain(tableID) then return end
			local okE, errorObject = pcall(bg.GetErrorByID, bg, tableID)
			if okE then FromBugObject(errorObject, 1) end
		end)
	end, owner)
	if okReg then bugRoute = "event" end
end

local POLL_SECONDS = 1
local pollCounts = setmetatable({}, { __mode = "k" })
local function PollBugGrabber()
	local bg = _G.BugGrabber
	if type(bg) ~= "table" then return end
	local okD, db = pcall(bg.GetDB, bg)
	local okS, session = pcall(bg.GetSessionId, bg)
	if not (okD and type(db) == "table" and okS) then return end

	for i = #db, 1, -1 do
		local e = db[i]
		if type(e) ~= "table" or e.session ~= session then break end
		local count = tonumber(e.counter) or 1
		local seen = pollCounts[e]
		if seen == nil then
			FromBugObject(e, count)
			pollCounts[e] = count
		elseif count > seen then
			FromBugObject(e, count - seen)
			pollCounts[e] = count
		end
	end
end

local function StartBugGrabberPoll()
	if bugRoute ~= "none" then return end
	if type(_G.BugGrabber) ~= "table" or not (C_Timer and C_Timer.NewTicker) then return end
	local okG, current = pcall(geterrorhandler)
	if okG and ourHandlers[current] then return end
	bugRoute = "poll"
	C_Timer.NewTicker(POLL_SECONDS, function() pcall(PollBugGrabber) end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
pcall(events.RegisterEvent, events, "ADDON_ACTION_BLOCKED")
pcall(events.RegisterEvent, events, "ADDON_ACTION_FORBIDDEN")
local wrappedAtLogin = false
events:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" and a1 == addonName then
		loaded = true

		local db = _G.KainUIForeverAccountDB
		if type(db) == "table" then
			local v = Version()
			if db.errorLogVersion ~= v or type(db.errorLogSince) ~= "number" then
				db.errorLogVersion, db.errorLogSince = v, time and time() or 0
			end
		end
		local log = Store()
		for _, e in ipairs(pending) do log[#log + 1] = e end
		pending = {}
		Prune(log)
	elseif event == "PLAYER_LOGIN" then
		wrappedAtLogin = Wrap()
		StartBugGrabberPoll()
	elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and a1 == addonName then
		busy = true
		pcall(function()
			stats.blocked = stats.blocked + 1
			local what = Plain(a2) and tostring(a2) or "?"
			local label = event == "ADDON_ACTION_FORBIDDEN" and "The game forbade " or "The game blocked "
			Note("blocked", label .. what, {})
		end)
		busy = false
	end
end)

local function BugTime(t)
	if not Plain(t) then return nil end
	if type(t) == "number" then return t end
	if type(t) == "string" and time then
		local y, mo, d, h, mi, se = t:match("(%d+)[/%-](%d+)[/%-](%d+)%s+(%d+):(%d+):?(%d*)")
		if y then
			local ok, v = pcall(time, { year = tonumber(y), month = tonumber(mo), day = tonumber(d),
				hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) or 0 })
			if ok then return v end
		end
	end
end

local function FromBugGrabber()
	local list = {}
	local bg = _G.BugGrabber
	if type(bg) ~= "table" or type(bg.GetDB) ~= "function" then return list end
	local ok, db = pcall(bg.GetDB, bg)
	if not ok or type(db) ~= "table" then return list end
	local acct = _G.KainUIForeverAccountDB
	local since = type(acct) == "table" and tonumber(acct.errorLogSince) or nil
	if not since then return list end
	for _, e in ipairs(db) do
		if type(e) == "table" and Plain(e.message) and type(e.message) == "string" then
			local at = BugTime(e.time)
			local ours = OurLines(Plain(e.stack) and e.stack or nil)
			if at and at >= since and (e.message:find(FOLDER_PATTERN) or #ours > 0) then
				list[#list + 1] = { k = "error", m = ShortMessage(e.message), s = ours, n = tonumber(e.counter) or 1,
					l = at, v = Version(), from = "BugSack" }
			end
		end
	end
	return list
end

function KUI:GetErrorLog()
	local all = {}
	local seen = {}
	for _, e in ipairs(Store()) do
		all[#all + 1] = e
		seen[e.m] = true
	end
	for _, e in ipairs(FromBugGrabber()) do
		if not seen[e.m] then all[#all + 1] = e seen[e.m] = true end
	end
	return all
end

function KUI:ClearErrorLog()
	local log = Store()
	for i = #log, 1, -1 do log[i] = nil end
	print("|cff33ff99Kain-UI Forever|r cleared the saved errors.")
end

function KUI:ErrorLogScanReport()
	local okG, current = pcall(geterrorhandler)
	print(string.format("|cff33ff99Kain-UI Forever|r error log: %d kept, this session %d caught, %d other addons' ignored, %d blocked actions",
		#Store(), stats.caught, stats.ignored, stats.blocked))
	print("  handler: " .. ((okG and ourHandlers[current]) and "ours is on top" or "another addon's is on top (ours may be underneath)")
		.. "; wrapped at load " .. tostring(wrappedAtLoad) .. ", at login " .. tostring(wrappedAtLogin)
		.. "; BugGrabber " .. (type(_G.BugGrabber) == "table" and "installed" or "not installed"))
	if type(_G.BugGrabber) == "table" then
		local route = (bugRoute == "event" and "listening to BugSack's error announcements")
			or (bugRoute == "poll" and "checking BugSack's list every second")
			or "no route to BugSack's errors"
		local bg = _G.BugGrabber
		local has = {}
		for _, name in ipairs({ "GetDB", "GetErrorByID", "GetSessionId" }) do
			local okF, fn = pcall(function() return bg[name] end)
			has[#has + 1] = name .. ((okF and type(fn) == "function") and " yes" or " no")
		end
		print("  BugSack: " .. route .. " (" .. bugNoted .. " noted); offers " .. table.concat(has, ", "))
	end
end
