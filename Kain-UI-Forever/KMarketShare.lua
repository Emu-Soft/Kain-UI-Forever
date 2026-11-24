local _, KUI = ...
local M = KUI.Market
local P = M.Prices
local S = {}
P.Share = S

local PREFIX = "KUIPX"
local SEND_INTERVAL = 1
local CHUNK = 200
local MAX_PARTS = 3000
local ANNOUNCE_EVERY = 20 * 60
local FUTURE_SLACK = 3600
local STREAM_TIMEOUT = 15 * 60

S.PREFIX = PREFIX

local Plain = M.Plain
local registered = false
local queue, ticker = {}, nil
local blockedUntil = 0
local sending = nil
local streams = {}
local seen = {}
local nextAnnounce = nil
local wantSentAt = {}
local answeredAt = {}
S.stats = { sent = 0, received = 0 }

local function Now() return time() end
local function Clock() return GetTime() end

local function On()
	local db = M.DB and M:DB()
	return not (type(db) == "table" and db.priceShare == false)
end
S.On = On

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function To36(n)
	n = math.floor(n)
	if n <= 0 then return "0" end
	local out = {}
	while n > 0 do
		local r = n % 36
		out[#out + 1] = DIGITS:sub(r + 1, r + 1)
		n = (n - r) / 36
	end
	return string.reverse(table.concat(out))
end
local function From36(s) return tonumber(s, 36) end
S.To36, S.From36 = To36, From36

local function Hash(s)
	local h = 5381
	local byte = string.byte
	for i = 1, #s, 64 do
		local a = { byte(s, i, i + 63) }
		for j = 1, #a do h = (h * 33 + a[j]) % 2147483647 end
	end
	return To36(h)
end
S.Hash = Hash

function S.Encode(d)
	local rows = {}
	for id, mn, mk in d:gmatch("(%d+),(%d+),(%d+),%d+,%d+") do
		rows[#rows + 1] = { tonumber(id), tonumber(mn), tonumber(mk) }
	end
	table.sort(rows, function(a, b) return a[1] < b[1] end)
	local out, last = {}, 0
	for i, r in ipairs(rows) do
		out[i] = To36(r[1] - last) .. "," .. To36(r[2]) .. "," .. To36(r[3])
		last = r[1]
	end
	return table.concat(out, ";"), #rows
end

function S.Decode(text)
	local out, id = {}, 0
	for step, mn, mk in text:gmatch("([%w]+),([%w]+),([%w]+)") do
		local a, b, c = From36(step), From36(mn), From36(mk)
		if not (a and b and c) then return nil end
		id = id + a
		out[#out + 1] = string.format("%d,%d,%d,%d,0", id, b, c, c)
	end
	if #out == 0 then return nil end
	return table.concat(out, ";"), #out
end

local function ResultName(result)
	if result == nil or result == true then return "Success" end
	if result == false then return "Failed" end
	local results = Enum and Enum.SendAddonMessageResult
	if results then
		for k, v in pairs(results) do
			if v == result then return k end
		end
	end
	return tostring(result)
end

local function Pump()
	if #queue == 0 then
		if ticker then ticker:Cancel(); ticker = nil end
		return
	end
	if Clock() < blockedUntil or (InCombatLockdown and InCombatLockdown()) then return end
	local text = queue[1]
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "GUILD")
	local name = ok and ResultName(Plain(result)) or "Error"
	S.lastResult = name
	if name:find("Throttle") then return end
	if name:find("Lockdown") or name:find("Restrict") or name:find("Disallow") then
		blockedUntil = Clock() + 5
		return
	end
	table.remove(queue, 1)
	if name == "Success" then S.stats.sent = S.stats.sent + 1 end
	if sending and text:sub(1, 2) == "D:" then sending.sent = sending.sent + 1 end
	if sending and text:sub(1, 2) == "E:" then
		answeredAt[sending.faction .. sending.t] = Clock()
		sending = nil
	end
end

local function Queue(text, front)
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage and C_Timer and C_Timer.NewTicker) then return end
	if front then table.insert(queue, 1, text) else queue[#queue + 1] = text end
	if not ticker then ticker = C_Timer.NewTicker(SEND_INTERVAL, Pump) end
end

local function CanTalk()
	return registered and On() and IsInGuild and IsInGuild()
end

local function Mine()
	local faction = P.Faction()
	local _, h = P:House()
	if not (faction and h and type(h.t) == "number" and type(h.d) == "string" and h.d ~= "") then return nil end
	return faction, h.t, h
end

local function After(seconds, fn)
	if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) end
end

function S:Announce()
	nextAnnounce = Clock() + ANNOUNCE_EVERY
	if not CanTalk() then return end
	local faction, t, h = Mine()
	if not faction then return end

	Queue(string.format("H:%s:%d:%d", faction, t, P.Count(h.d)), true)
end

function S:Stream()
	if sending or not CanTalk() then return end
	local faction, t, h = Mine()
	if not faction then return end
	local text = S.Encode(h.d)
	local of = math.ceil(#text / CHUNK)
	if of < 1 or of > MAX_PARTS then return end
	sending = { faction = faction, t = t, sent = 0, total = of }
	for n = 1, of do
		Queue(string.format("D:%s:%d:%d:%d:%s", faction, t, n, of, text:sub((n - 1) * CHUNK + 1, n * CHUNK)))
	end
	Queue(string.format("E:%s:%d:%d:%s", faction, t, of, Hash(text)))
end

local function Keep(faction, t, d, from)
	local db = M:DB()
	if type(db.peerPrices) ~= "table" then db.peerPrices = {} end

	local id = P.AppHouse and P:AppHouse()
	db.peerPrices[faction] = { house = id or faction, faction = faction, t = t, d = d, from = from }
	S.stats.received = S.stats.received + 1
	S.lastFrom, S.lastAt = from, Now()
	if M.Say then M.Say(string.format("auction house prices from your guildmate %s loaded (%d items).", from, P.Count(d))) end
end

local function Newer(faction, t)
	if faction ~= P.Faction() or type(t) ~= "number" then return false end
	if t > Now() + FUTURE_SLACK then return false end
	local _, mt = Mine()
	return not mt or t > mt
end

local function OnHave(faction, t, sender)
	local mf, mt = Mine()
	if mf == faction and mt and t >= mt then

		nextAnnounce = Clock() + ANNOUNCE_EVERY
	end
	if not Newer(faction, t) then

		if mf == faction and mt and t < mt and CanTalk() then
			nextAnnounce = math.min(nextAnnounce or math.huge, Clock() + 3 + math.random() * 7)
		end
		return
	end
	local key = faction .. t
	if wantSentAt[key] and Clock() - wantSentAt[key] < 90 then return end
	for _, st in pairs(streams) do
		if st.faction == faction and st.t >= t then return end
	end
	wantSentAt[key] = Clock()
	After(2 + math.random() * 4, function()
		if wantSentAt[key .. "seen"] then return end
		if CanTalk() and Newer(faction, t) then Queue(string.format("W:%s:%d", faction, t), true) end
	end)
	S.lastOffer = sender
end

local function OnWant(faction, t)
	wantSentAt[faction .. t] = Clock()
	wantSentAt[faction .. t .. "seen"] = true
	local mf, mt = Mine()
	if mf ~= faction or not mt or mt < t or sending then return end
	local done = answeredAt[faction .. mt]
	if done and Clock() - done < 60 then return end
	local waitFrom = Clock()
	After(0.5 + math.random() * 2.5, function()

		local other = seen[faction]
		if other and other.t >= mt and other.last >= waitFrom then return end
		S:Stream()
	end)
end

local function OnData(sender, faction, t, n, of, chunk)
	local st = streams[sender]
	if not st or st.faction ~= faction or st.t ~= t or st.of ~= of then
		if of < 1 or of > MAX_PARTS then return end
		st = { faction = faction, t = t, of = of, parts = {}, got = 0 }
		streams[sender] = st
	end
	st.last = Clock()
	if n >= 1 and n <= of and not st.parts[n] then
		st.parts[n] = chunk
		st.got = st.got + 1
	end
end

local function OnEnd(sender, faction, t, of, hash)
	local st = streams[sender]
	streams[sender] = nil
	if not st or st.faction ~= faction or st.t ~= t or st.of ~= of or st.got ~= of then return end
	if not Newer(faction, t) then return end
	local text = table.concat(st.parts, "", 1, of)
	if Hash(text) ~= hash then return end
	local d = S.Decode(text)
	if d then Keep(faction, t, d, sender) end
end

function S:OnMessage(prefix, text, channel, sender)
	prefix, text, channel, sender = Plain(prefix), Plain(text), Plain(channel), Plain(sender)
	if prefix ~= PREFIX or channel ~= "GUILD" or type(text) ~= "string" or type(sender) ~= "string" then return end
	if not On() then return end
	local short = sender:match("^([^%-]+)") or sender
	local _, myName = M:Me()
	if myName and (short == myName or sender == myName) then return end
	local kind = text:sub(1, 1)
	if kind == "H" then
		local faction, t = text:match("^H:(%a+):(%d+):%d+$")
		if faction then OnHave(faction, tonumber(t), short) end
	elseif kind == "W" then
		local faction, t = text:match("^W:(%a+):(%d+)$")
		if faction then OnWant(faction, tonumber(t)) end
	elseif kind == "D" then
		local faction, t, n, of, chunk = text:match("^D:(%a+):(%d+):(%d+):(%d+):(.*)$")
		t = tonumber(t)
		local o = faction and seen[faction]
		if t and t <= Now() + FUTURE_SLACK and (not o or t >= o.t or Clock() - o.last > 30) then
			seen[faction] = { t = t, last = Clock() }
		end
		if faction and Newer(faction, tonumber(t)) then OnData(short, faction, tonumber(t), tonumber(n), tonumber(of), chunk) end
	elseif kind == "E" then
		local faction, t, of, hash = text:match("^E:(%a+):(%d+):(%d+):(%w+)$")
		if faction then OnEnd(short, faction, tonumber(t), tonumber(of), hash) end
	end
end

function S:StatusText()
	if not On() then return "Guild sharing is off (/km prices share on)." end
	if not (IsInGuild and IsInGuild()) then return "Guild sharing: not in a guild." end
	local parts = {}
	if sending then
		parts[#parts + 1] = string.format("sending to the guild (%d of %d)", sending.sent, sending.total)
	end
	for who, st in pairs(streams) do
		parts[#parts + 1] = string.format("receiving from %s (%d of %d)", who, st.got, st.of)
	end
	if #parts == 0 then parts[1] = "on" end
	return "Guild sharing: " .. table.concat(parts, ", ") .. "."
end

function S:SettingChanged()
	if not On() then
		queue, sending, streams = {}, nil, {}
	else
		nextAnnounce = Clock() + 2
	end
end

local function Tick()
	local now = Clock()
	for who, st in pairs(streams) do
		if now - (st.last or now) > STREAM_TIMEOUT then streams[who] = nil end
	end
	if nextAnnounce and now >= nextAnnounce then S:Announce() end
end

local lastT
local function Start()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local ok = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
		registered = ok
	end
	nextAnnounce = Clock() + 30 + math.random() * 30
	local _, t = Mine()
	lastT = t
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(5, function()

			local _, nt = Mine()
			if nt and nt ~= lastT then
				lastT = nt
				nextAnnounce = math.min(nextAnnounce or math.huge, Clock() + 5 + math.random() * 10)
			end
			Tick()
		end)
	end
end

local events = CreateFrame("Frame")
KUI:SafeRegisterEvent(events, "PLAYER_LOGIN")
KUI:SafeRegisterEvent(events, "CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		Start()
	elseif event == "CHAT_MSG_ADDON" then
		pcall(S.OnMessage, S, ...)
	end
end)
