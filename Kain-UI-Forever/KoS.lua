local ADDON_NAME, KUI = ...

local ns = {
	embedded = true,
	VERSION = "1.4.0",
	DB_NAME = "KainUIForeverKoSDB",
	SOUND_DIR = "Interface\\AddOns\\Kain-UI-Forever\\Media\\KoS\\",
	FRAME_PREFIX = "KainUIForeverKoS",
	POPUP_PREFIX = "KAINUIFOREVER_KOS_",
}
if type(KUI) == "table" then KUI.KoS = ns end

do

ns.ADDON_NAME = ADDON_NAME
ns.DB_NAME = ns.DB_NAME or "BHGKillListDB"
ns.SOUND_DIR = ns.SOUND_DIR or ("Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\")
ns.FRAME_PREFIX = ns.FRAME_PREFIX or "BHGKillList"
ns.POPUP_PREFIX = ns.POPUP_PREFIX or "BHGKOS_"
ns.active = false
ns.TITLE = "BH&G Kill List"
ns.PREFIX = "|cffe03c3cBH&G Kill List:|r "

ns.VERSION = ns.VERSION or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
	or (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "?"

local function IsSecret(v)
	if issecretvalue and issecretvalue(v) then return true end
	if type(v) == "table" and issecrettable and issecrettable(v) then return true end
	return false
end

function ns.Plain(v)
	if IsSecret(v) then return nil end
	return v
end
local Plain = ns.Plain

function ns.PlainText(v)
	v = Plain(v)
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

ns.errorCounts = {}
function ns.Guarded(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			local n = (ns.errorCounts[label] or 0) + 1
			ns.errorCounts[label] = n
			if n == 1 then
				print(ns.PREFIX .. "'" .. label .. "' hit an error (further ones are counted, not printed): " .. tostring(err))
			end
		end
	end
end

function ns.Print(msg)
	print(ns.PREFIX .. msg)
end

function ns.CutText(s, n)
	if type(s) ~= "string" or #s <= n then return s end
	s = s:sub(1, n)
	local i = #s
	while i > 0 do
		local b = s:byte(i)
		if b < 128 then break end
		if b >= 192 then
			local need = (b >= 240 and 4) or (b >= 224 and 3) or 2
			if #s - i + 1 < need then s = s:sub(1, i - 1) end
			break
		end
		i = i - 1
	end
	return s
end

function ns.Clean(s, maxBytes)
	if type(s) ~= "string" then return nil end
	s = s:gsub("[~%^|%c]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	s = ns.CutText(s, maxBytes or 80)
	if s == "" then return nil end
	return s
end

function ns.Now()
	return (GetServerTime and GetServerTime()) or time()
end

local function StripRealm(realm)
	if type(realm) ~= "string" then return nil end
	realm = realm:gsub("[%s%-]", "")
	if realm == "" then return nil end
	return realm
end

function ns.MyRealm()
	local r = Plain(GetNormalizedRealmName and GetNormalizedRealmName())
	r = StripRealm(r)
	if not r then r = StripRealm(Plain(GetRealmName and GetRealmName())) end
	return r or "Unknown"
end

function ns.MyName()
	local n = ns.PlainText(UnitName("player"))
	return n or "Unknown"
end

function ns.MyFullName()
	return ns.MyName() .. "-" .. ns.MyRealm()
end

function ns.ProperName(name)
	if type(name) ~= "string" or name == "" then return name end
	local first, rest = name:sub(1, 1), name:sub(2)
	if first:byte() < 128 then
		return first:upper() .. rest:lower()
	end
	return name
end

function ns.SplitName(full)
	if type(full) ~= "string" then return nil end
	full = full:gsub("^%s+", ""):gsub("%s+$", "")
	local name, realm = full:match("^([^%-]+)%-(.+)$")
	if not name then name, realm = full:match("^(%S+)%s+(%S+)$") end
	if not name then name = full end
	name = ns.Clean(name, 48)
	if not name or name:find(" ") then return nil end
	return ns.ProperName(name), StripRealm(realm) or ns.MyRealm()
end

function ns.Key(name, realm)
	return (name .. "-" .. (StripRealm(realm) or ns.MyRealm())):lower()
end

function ns.FullName(name, realm)
	if type(name) ~= "string" then return "?" end
	return ns.ProperName(name) .. " " .. (StripRealm(realm) or ns.MyRealm())
end

function ns.DisplayName(e)
	if not e then return "?" end
	return ns.FullName(e.n, e.r)
end

function ns.TargetName(e)
	if e.r and e.r:lower() ~= ns.MyRealm():lower() then
		return e.n .. " " .. e.r
	end
	return e.n
end

function ns.ClassColor(classFile)
	local c = classFile and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
	if c then return c.r, c.g, c.b end
	return 0.85, 0.85, 0.85
end

function ns.ColorName(e)
	local r, g, b = ns.ClassColor(e and e.c)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, ns.DisplayName(e))
end

function ns.SenderName(sender)
	if type(sender) ~= "string" then return "?" end
	local name, realm = sender:match("^([^%-]+)%-(.+)$")
	return ns.FullName(name or sender, realm)
end

function ns.Ago(t)
	if not t then return "never" end
	local d = ns.Now() - t
	if d < 0 then d = 0 end
	if d < 60 then return "just now" end
	if d < 3600 then return math.floor(d / 60) .. "m ago" end
	if d < 86400 then return math.floor(d / 3600) .. "h ago" end
	return math.floor(d / 86400) .. "d ago"
end

ns.DEFAULTS = {
	sound = true,
	nearbySound = true,
	farPlates = true,
	banner = true,
	chat = true,
	shareSightings = true,
	guildSightings = true,
	nearby = true,
	hideInDungeons = true,
	nearbyAll = true,
	nearbyTime = 60,
	alertCooldown = 60,
	blackWarn = true,
	blackChat = true,
	leavePrompt = true,
}

function ns.InitDB()
	if type(_G[ns.DB_NAME]) ~= "table" then _G[ns.DB_NAME] = {} end
	local db = _G[ns.DB_NAME]
	ns.loadedWithData = type(db.entries) == "table" and next(db.entries) ~= nil
	if type(db.entries) ~= "table" then db.entries = {} end
	if type(db.guilds) ~= "table" then db.guilds = {} end
	if type(db.black) ~= "table" then db.black = {} end
	if type(db.settings) ~= "table" then db.settings = {} end
	if type(db.pos) ~= "table" then db.pos = {} end
	for k, v in pairs(ns.DEFAULTS) do
		if db.settings[k] == nil then db.settings[k] = v end
	end
	db.schema = 1
	ns.db = db

	for _, list in ipairs({ db.entries, db.black }) do
		for key, e in pairs(list) do
			if type(e) ~= "table" or type(e.n) ~= "string" or type(e.t) ~= "number" then
				list[key] = nil
			end
		end
	end
	for key, g in pairs(db.guilds) do
		if type(g) ~= "table" or type(g.n) ~= "string" or type(g.t) ~= "number" then
			db.guilds[key] = nil
		end
	end
	ns.InvalidateHashes()
end

function ns.Setting(k)
	local s = ns.db and ns.db.settings
	if s and s[k] ~= nil then return s[k] end
	return ns.DEFAULTS[k]
end

function ns.SetSetting(k, v)
	ns.db.settings[k] = v
	ns.Fire("SETTINGS_CHANGED", k, v)
end

local listeners = {}
function ns.Listen(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end
function ns.Fire(name, ...)
	for _, fn in ipairs(listeners[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then
			ns.errorCounts["listener " .. name] = (ns.errorCounts["listener " .. name] or 0) + 1
			if ns.errorCounts["listener " .. name] == 1 then ns.Print("error in " .. name .. ": " .. tostring(err)) end
		end
	end
end

local SHARED = { "n", "r", "c", "g", "w", "b", "a", "t", "x", "y" }
local GUILD_SHARED = { "n", "w", "b", "a", "t", "x", "y" }
local NUMERIC = { a = true, t = true }
ns.SHARED_FIELDS = SHARED

local function ToB36(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return "0" end
	local digits, s = "0123456789abcdefghijklmnopqrstuvwxyz", ""
	while n > 0 do
		local d = n % 36
		s = digits:sub(d + 1, d + 1) .. s
		n = (n - d) / 36
	end
	return s
end
ns.ToB36 = ToB36

local function SerializeWith(fields, e)
	local parts = {}
	for i, f in ipairs(fields) do
		local v = e[f]
		if NUMERIC[f] then
			parts[i] = ToB36(v)
		elseif f == "x" then
			parts[i] = v and "1" or ""
		else
			parts[i] = v or ""
		end
	end
	return table.concat(parts, "~")
end

function ns.Serialize(e) return SerializeWith(SHARED, e) end
function ns.SerializeGuild(g) return SerializeWith(GUILD_SHARED, g) end

local LIMITS = { n = 48, r = 64, c = 20, g = 64, w = 80, b = 80, y = 80 }
local GUILD_LIMITS = { n = 64, w = 80, b = 80, y = 80 }

local function DeserializeWith(fields, limits, s)
	if type(s) ~= "string" then return nil end
	local parts, i = {}, 1
	for field in (s .. "~"):gmatch("([^~]*)~") do
		parts[i] = field
		i = i + 1
	end
	if #parts ~= #fields then return nil end
	local e = {}
	for idx, f in ipairs(fields) do
		local v = parts[idx]
		if NUMERIC[f] then
			e[f] = tonumber(v, 36)
			if not e[f] then return nil end
		elseif f == "x" then
			e[f] = (v == "1") or nil
		elseif v ~= "" then
			if #v > limits[f] then return nil end
			e[f] = v
		end
	end
	if not e.n or e.n:find("[~%^|]") then return nil end

	if e.t > ns.Now() + 86400 then return nil end
	return e
end

function ns.Deserialize(s)
	local e = DeserializeWith(SHARED, LIMITS, s)
	if not e or not e.r or e.n:find("%s") then return nil end
	return e
end

function ns.DeserializeGuild(s)
	return DeserializeWith(GUILD_SHARED, GUILD_LIMITS, s)
end

function ns.IsNewer(a, b, serialize)
	if not b then return true end
	if a.t ~= b.t then return a.t > b.t end
	serialize = serialize or ns.Serialize
	return serialize(a) > serialize(b)
end

ns.BUCKETS = 16
ns.BLACK_BUCKETS = 4

local function Hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return h
end
ns.Hash = Hash

function ns.BucketOf(key, buckets)
	return (Hash(key) % (buckets or ns.BUCKETS)) + 1
end

local hashCache, blackCache, guildDigest
function ns.InvalidateHashes()
	hashCache, blackCache, guildDigest = nil, nil, nil
end

function ns.GuildDigest()
	if guildDigest then return guildDigest end
	local sum = 0
	for key, g in pairs(ns.db.guilds) do
		sum = (sum + Hash(key .. "=" .. ns.SerializeGuild(g))) % 4294967296
	end
	guildDigest = sum
	return sum
end

function ns.AllGuildEntries()
	local list = {}
	for _, g in pairs(ns.db.guilds) do list[#list + 1] = g end
	table.sort(list, function(a, b) return a.n:lower() < b.n:lower() end)
	return list
end

local function Sums(entries, buckets)
	local sums = {}
	for i = 1, buckets do sums[i] = 0 end
	for key, e in pairs(entries) do
		local b = ns.BucketOf(key, buckets)
		sums[b] = (sums[b] + Hash(key .. "=" .. ns.Serialize(e))) % 4294967296
	end
	return sums
end

local function InBucket(entries, buckets, i)
	local list = {}
	for key, e in pairs(entries) do
		if ns.BucketOf(key, buckets) == i then list[#list + 1] = e end
	end
	table.sort(list, function(a, b) return ns.Key(a.n, a.r) < ns.Key(b.n, b.r) end)
	return list
end

function ns.BucketHashes()
	hashCache = hashCache or Sums(ns.db.entries, ns.BUCKETS)
	return hashCache
end

function ns.BlackHashes()
	blackCache = blackCache or Sums(ns.db.black, ns.BLACK_BUCKETS)
	return blackCache
end

function ns.EntriesInBucket(i)
	return InBucket(ns.db.entries, ns.BUCKETS, i)
end

function ns.BlackInBucket(i)
	return InBucket(ns.db.black, ns.BLACK_BUCKETS, i)
end

local KILL = { field = "entries", send = "SendUpdate", added = "ADDED_BY_GUILD", removed = "REMOVED_BY_GUILD" }
local BLACK = { field = "black", send = "SendBlackUpdate", added = "BLACK_ADDED_BY_GUILD", removed = "BLACK_REMOVED_BY_GUILD" }

local function GetIn(list, key)
	local e = key and ns.db and ns.db[list.field][key]
	if e and not e.x then return e end
	return nil
end

local function ListOf(list)
	local out = {}
	for _, e in pairs(ns.db[list.field]) do
		if not e.x then out[#out + 1] = e end
	end
	table.sort(out, function(a, b) return ns.DisplayName(a):lower() < ns.DisplayName(b):lower() end)
	return out
end

function ns.Get(key) return GetIn(KILL, key) end
function ns.GetBlack(key) return GetIn(BLACK, key) end

function ns.GetByName(name, realm)
	return ns.Get(ns.Key(name, realm))
end

function ns.List() return ListOf(KILL) end
function ns.BlackList() return ListOf(BLACK) end
local function CountIn(list)
	local n = 0
	for _, e in pairs(ns.db[list.field]) do
		if not e.x then n = n + 1 end
	end
	return n
end

function ns.Count() return CountIn(KILL) end
function ns.BlackCount() return CountIn(BLACK) end

local function Stamp(old)
	local t = ns.Now()
	if old and old.t and t <= old.t then t = old.t + 1 end
	return t
end

local function Commit(list, key, e, fromSync)
	local old = ns.db[list.field][key]

	if old then
		for k, v in pairs(old) do
			if e[k] == nil and not ns.IsSharedField(k) then e[k] = v end
		end
	end
	ns.db[list.field][key] = e
	ns.InvalidateHashes()
	ns.Fire("LIST_CHANGED", key, e, fromSync)
	if not fromSync and ns[list.send] then ns[list.send](e) end
end

local sharedSet = {}
for _, f in ipairs(SHARED) do sharedSet[f] = true end
function ns.IsSharedField(k) return sharedSet[k] or false end

local function CopyShared(e)
	local c = {}
	for _, f in ipairs(SHARED) do c[f] = e[f] end
	return c
end

local function SameShared(a, b)
	for _, f in ipairs(SHARED) do
		if f ~= "t" and a[f] ~= b[f] then return false end
	end
	return true
end

local function AddTo(list, info, reason)
	local name, realm = info.name, info.realm or ns.MyRealm()
	if type(name) ~= "string" or name == "" then return nil end
	local key = ns.Key(name, realm)
	local old = ns.db[list.field][key]
	local e = old and CopyShared(old) or {}
	local wasListed = old and not old.x
	e.n = ns.Clean(name, LIMITS.n)
	e.r = StripRealm(realm) or ns.MyRealm()
	e.c = ns.Clean(info.class, LIMITS.c) or e.c
	e.g = ns.Clean(info.guild, LIMITS.g) or e.g
	if reason ~= nil then e.w = ns.Clean(reason, LIMITS.w) end
	if not wasListed then
		e.b = ns.Clean(ns.MyFullName(), LIMITS.b)
		e.a = ns.Now()
	end
	e.x, e.y = nil, nil
	e.t = Stamp(old)
	if wasListed and SameShared(old, e) then

		return old, false
	end
	local localInfo = { lv = info.level, race = info.race }
	for k, v in pairs(localInfo) do e[k] = v end
	Commit(list, key, e)
	return e, not wasListed
end

local function SetReasonIn(list, key, reason)
	local old = GetIn(list, key)
	if not old then return end
	local e = CopyShared(old)
	e.w = ns.Clean(reason, LIMITS.w)
	if e.w == old.w then return end
	e.t = Stamp(old)
	Commit(list, key, e)
end

local function RemoveFrom(list, key)
	local old = GetIn(list, key)
	if not old then return nil end
	local e = CopyShared(old)
	e.x = true
	e.y = ns.Clean(ns.MyFullName(), LIMITS.y)
	e.t = Stamp(old)
	Commit(list, key, e)
	return e
end

local function MergeInto(list, e)
	local key = ns.Key(e.n, e.r)
	local old = ns.db[list.field][key]
	if old and not ns.IsNewer(e, old) then return false end
	local wasListed = old and not old.x
	Commit(list, key, e, true)
	if not e.x and not wasListed then
		ns.Fire(list.added, key, e)
	elseif e.x and wasListed then
		ns.Fire(list.removed, key, e)
	end
	return true
end

function ns.Add(info, reason) return AddTo(KILL, info, reason) end
function ns.SetReason(key, reason) return SetReasonIn(KILL, key, reason) end
function ns.Remove(key) return RemoveFrom(KILL, key) end
function ns.MergeIncoming(e) return MergeInto(KILL, e) end

function ns.AddBlack(info, reason) return AddTo(BLACK, info, reason) end
function ns.SetBlackReason(key, reason) return SetReasonIn(BLACK, key, reason) end
function ns.RemoveBlack(key) return RemoveFrom(BLACK, key) end
function ns.MergeIncomingBlack(e) return MergeInto(BLACK, e) end

function ns.LearnDetails(key, class, guild)
	local old = ns.Get(key)
	if not old then return end
	class, guild = ns.Clean(class, LIMITS.c), ns.Clean(guild, LIMITS.g)
	local needClass = class and old.c ~= class
	local needGuild = guild and old.g ~= guild
	if not (needClass or needGuild) then return end
	local e = CopyShared(old)
	if needClass then e.c = class end
	if needGuild then e.g = guild end
	e.t = Stamp(old)
	Commit(KILL, key, e)
end

function ns.CleanGuildName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("^%s*<", ""):gsub(">%s*$", "")
	return ns.Clean(name, GUILD_LIMITS.n)
end

function ns.GuildKey(name)
	name = ns.CleanGuildName(name)
	return name and name:lower()
end

function ns.GetGuild(name)
	local key = ns.GuildKey(name)
	local g = key and ns.db and ns.db.guilds[key]
	if g and not g.x then return g end
	return nil
end

function ns.GuildList()
	local list = {}
	for _, g in ipairs(ns.AllGuildEntries()) do
		if not g.x then list[#list + 1] = g end
	end
	return list
end

function ns.GuildCount()
	return #ns.GuildList()
end

local function CopyGuild(g)
	local c = {}
	for _, f in ipairs(GUILD_SHARED) do c[f] = g[f] end
	return c
end

local function CommitGuild(key, g, fromSync)
	ns.db.guilds[key] = g
	ns.InvalidateHashes()
	ns.Fire("LIST_CHANGED", nil, nil, fromSync)
	if not fromSync and ns.SendGuildUpdate then ns.SendGuildUpdate(g) end
end

function ns.AddGuild(name, reason)
	name = ns.CleanGuildName(name)
	if not name then return nil end
	local key = name:lower()
	local old = ns.db.guilds[key]
	local wasListed = old and not old.x
	local g = old and CopyGuild(old) or {}
	g.n = (wasListed and old.n) or name
	if reason ~= nil then g.w = ns.Clean(reason, GUILD_LIMITS.w) end
	if not wasListed then
		g.b = ns.Clean(ns.MyFullName(), GUILD_LIMITS.b)
		g.a = ns.Now()
	end
	g.x, g.y = nil, nil
	if wasListed and g.w == old.w then return old, false end
	g.t = Stamp(old)
	CommitGuild(key, g)
	return g, not wasListed
end

function ns.SetGuildReason(name, reason)
	local old = ns.GetGuild(name)
	if not old then return end
	local g = CopyGuild(old)
	g.w = ns.Clean(reason, GUILD_LIMITS.w)
	if g.w == old.w then return end
	g.t = Stamp(old)
	CommitGuild(old.n:lower(), g)
end

function ns.RemoveGuild(name)
	local old = ns.GetGuild(name)
	if not old then return nil end
	local g = CopyGuild(old)
	g.x = true
	g.y = ns.Clean(ns.MyFullName(), GUILD_LIMITS.y)
	g.t = Stamp(old)
	CommitGuild(old.n:lower(), g)
	return g
end

function ns.LearnGuildSpelling(name)
	local old = ns.GetGuild(name)
	name = ns.CleanGuildName(name)
	if not old or not name or old.n == name then return end
	local g = CopyGuild(old)
	g.n = name
	g.t = Stamp(old)
	CommitGuild(name:lower(), g)
end

function ns.MergeIncomingGuild(g)
	local key = g.n:lower()
	local old = ns.db.guilds[key]
	if old and not ns.IsNewer(g, old, ns.SerializeGuild) then return false end
	local wasListed = old and not old.x
	CommitGuild(key, g, true)
	if not g.x and not wasListed then
		ns.Fire("GUILD_ADDED_BY_GUILD", key, g)
	elseif g.x and wasListed then
		ns.Fire("GUILD_REMOVED_BY_GUILD", key, g)
	end
	return true
end

local frame = CreateFrame("Frame")
ns.frame = frame
local handlers = {}

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		pcall(frame.RegisterEvent, frame, event)
	end
	table.insert(handlers[event], ns.Guarded(event, fn))
end

local STARTUP_EVENTS = { ADDON_LOADED = true, PLAYER_LOGIN = true }
frame:SetScript("OnEvent", function(_, event, ...)
	if not ns.active and not STARTUP_EVENTS[event] then return end
	for _, fn in ipairs(handlers[event] or {}) do fn(...) end
end)

local function Start()
	if ns.active then return end
	ns.InitDB()
	ns.active = true
	ns.Fire("DB_READY")
end

local function EmbeddedEnabled()
	local saved = _G[ns.DB_NAME]
	return not (type(saved) == "table" and saved.enabled == false)
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON_NAME then return end
	if ns.embedded then
		_G.KainUIForeverKoS = ns
		if EmbeddedEnabled() then Start() else ns.disabled = true end
	end
end)

ns.On("PLAYER_LOGIN", function()
	if ns.embedded then
		if ns.active then ns.ImportStandalone() end
		ns.Fire("LOGIN")
		return
	end
	_G.BHGKillListStandalone = ns
	local master = _G.KainUIForeverKoS
	if master and master.active then
		ns.slaved = true
		return
	end
	Start()
	ns.Fire("LOGIN")
end)

function ns.SetEnabled(on)
	if not ns.embedded then return end
	if type(_G[ns.DB_NAME]) ~= "table" then _G[ns.DB_NAME] = {} end
	_G[ns.DB_NAME].enabled = on and true or false
	ns.Print("K-UI's kill list is " .. (on and "on" or "off") .. " from your next /reload or login."
		.. (on and "" or " If the standalone BH&G Kill List addon is installed, it takes over then."))
end

function ns.ImportStandalone()
	local old = _G.BHGKillListDB
	if type(old) ~= "table" or old == ns.db then return end
	local db = ns.db
	if type(old.entries) == "table" then
		ns.syncQuiet = true
		for field, merge in pairs({ entries = ns.MergeIncoming, black = ns.MergeIncomingBlack }) do
			for _, e in pairs(type(old[field]) == "table" and old[field] or {}) do
				local copy = type(e) == "table" and type(e.n) == "string" and type(e.t) == "number"
					and ns.Deserialize(ns.Serialize(e))
				if copy then
					for k, v in pairs(e) do
						if copy[k] == nil and not ns.IsSharedField(k) then copy[k] = v end
					end
					merge(copy)
				end
			end
		end
		if type(old.guilds) == "table" then
			for _, g in pairs(old.guilds) do
				local copy = type(g) == "table" and type(g.n) == "string" and type(g.t) == "number"
					and ns.DeserializeGuild(ns.SerializeGuild(g))
				if copy then ns.MergeIncomingGuild(copy) end
			end
		end
		ns.syncQuiet = false
	end
	if type(old.enemies) == "table" then
		db.enemies = db.enemies or {}
		for key, rec in pairs(old.enemies) do
			if type(rec) == "table" and type(rec.n) == "string" then
				local mine = db.enemies[key]
				if not mine then
					mine = {}
					for k, v in pairs(rec) do mine[k] = v end
					db.enemies[key] = mine
				else
					for _, f in ipairs({ "w", "l", "times", "last", "lastWin", "lastLoss" }) do
						if type(rec[f]) == "number" and (mine[f] or 0) < rec[f] then mine[f] = rec[f] end
					end
					if type(rec.first) == "number" and (not mine.first or rec.first < mine.first) then mine.first = rec.first end
					for _, f in ipairs({ "c", "lv", "race", "g", "zone" }) do
						if mine[f] == nil then mine[f] = rec[f] end
					end
				end
			end
		end
	end

	if not db.imported then
		db.imported = true
		if type(old.settings) == "table" then
			for k, v in pairs(old.settings) do db.settings[k] = v end
		end
		if type(old.pos) == "table" then
			for k, v in pairs(old.pos) do db.pos[k] = v end
		end
	end
	ns.Fire("LIST_CHANGED")
end
end

do

local Plain, PlainText = ns.Plain, ns.PlainText

local COMM_PREFIX = "BHGKOS1"
local CHANNEL = "GUILD"
local MAX_MESSAGE = 250
local SEND_INTERVAL = 0.3
local SEND_QUEUE_MAX = 2000
local HELLO_AFTER_LOGIN = 8
local HELLO_EVERY = 20 * 60
local QUIET_TIME = 4
local BUCKET_RESEND = 20

ns.sync = {
	sent = 0, received = 0, merged = 0, queuedPeak = 0,
	lastHello = nil, peers = {},
}
local stats = ns.sync
local GUILD_BUCKET = ns.BUCKETS + 1
local BLACK_FIRST = GUILD_BUCKET + 1
local LAST_BUCKET = GUILD_BUCKET + ns.BLACK_BUCKETS

local function Digest(i)
	if i == GUILD_BUCKET then return ns.GuildDigest() end
	if i >= BLACK_FIRST then return ns.BlackHashes()[i - GUILD_BUCKET] end
	return ns.BucketHashes()[i]
end

local function BucketContents(i)
	if i == GUILD_BUCKET then return "E~", ns.SerializeGuild, ns.AllGuildEntries() end
	if i >= BLACK_FIRST then return "F~", ns.Serialize, ns.BlackInBucket(i - GUILD_BUCKET) end
	return "D~", ns.Serialize, ns.EntriesInBucket(i)
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX)
elseif RegisterAddonMessagePrefix then
	pcall(RegisterAddonMessagePrefix, COMM_PREFIX)
end

local sendQueue, sendTicker = {}, nil

local RESTRICTION_CHECKS = { "InChatMessagingLockdown", "AreOutgoingAddonChatMessagesRestricted" }
function ns.CommChecks()
	local ci, out = C_ChatInfo, {}
	for _, name in ipairs(RESTRICTION_CHECKS) do
		local v = "n/a"
		if ci and ci[name] then
			local ok, r = pcall(ci[name])
			r = ok and Plain(r)
			v = not ok and "error" or (r == true and "yes" or (r == false and "no" or "?"))
		end
		out[#out + 1] = name .. " " .. v
	end
	return table.concat(out, ", ")
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

local blockedUntil = 0
local function CommRestricted()
	return GetTime() < blockedUntil
end
ns.CommRestricted = CommRestricted

local function SendFunc()
	return (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
end

local OnQueueDrained

local function PumpSendQueue()
	if #sendQueue == 0 then
		if sendTicker then sendTicker:Cancel() sendTicker = nil end
		OnQueueDrained()
		return
	end
	if CommRestricted() or not IsInGuild() then return end
	local item = sendQueue[1]
	local ok, result = pcall(SendFunc(), COMM_PREFIX, item.text, CHANNEL)
	local name = ok and ResultName(Plain(result)) or "Error"
	stats.lastResult = name
	if name:find("Throttle") then
		return
	end
	if name:find("Lockdown") or name:find("Restrict") or name:find("Disallow") then
		blockedUntil = GetTime() + 5
		return
	end
	table.remove(sendQueue, 1)
	if name == "Success" then stats.sent = stats.sent + 1 else stats.failed = (stats.failed or 0) + 1 end
end

local function Send(text, bucket)
	if not SendFunc() or not (C_Timer and C_Timer.NewTicker) then return end
	if #text > MAX_MESSAGE then return end
	if #sendQueue >= SEND_QUEUE_MAX then return end
	sendQueue[#sendQueue + 1] = { text = text, bucket = bucket }
	if #sendQueue > stats.queuedPeak then stats.queuedPeak = #sendQueue end
	if not sendTicker then
		sendTicker = C_Timer.NewTicker(SEND_INTERVAL, PumpSendQueue)
		PumpSendQueue()
	end
end

local function DropQueuedBucket(i)
	for idx = #sendQueue, 1, -1 do
		if sendQueue[idx].bucket == i then table.remove(sendQueue, idx) end
	end
end

function ns.QueueLength() return #sendQueue end

local function HashList(sums)
	local out = {}
	for i, h in ipairs(sums) do out[i] = ns.ToB36(h) end
	return table.concat(out, ",")
end

function ns.SendUpdate(e)
	if not IsInGuild() then return end
	Send("U~" .. ns.Serialize(e))
end

function ns.SendGuildUpdate(g)
	if not IsInGuild() then return end
	Send("G~" .. ns.SerializeGuild(g))
end

function ns.SendBlackUpdate(e)
	if not IsInGuild() then return end
	Send("K~" .. ns.Serialize(e))
end

function ns.SendHello()
	if not IsInGuild() then return false end
	stats.lastHello = GetTime()
	Send("H~" .. HashList(ns.BucketHashes()))
	Send("Q~" .. ns.ToB36(ns.GuildDigest()))
	Send("W~" .. HashList(ns.BlackHashes()))
	return true
end

local lastBucketSent = {}
local inFlight = {}

local function SendBucket(i)
	local digest = Digest(i)
	lastBucketSent[i] = GetTime()
	inFlight[i] = digest
	Send("B~" .. i .. "~" .. ns.ToB36(digest), i)
	local kind, serialize, entries = BucketContents(i)
	local chunk, size = {}, 2
	for _, e in ipairs(entries) do
		local s = serialize(e)
		if size + #s + 1 > MAX_MESSAGE and #chunk > 0 then
			Send(kind .. table.concat(chunk, "^"), i)
			chunk, size = {}, 2
		end
		if 2 + #s <= MAX_MESSAGE then
			chunk[#chunk + 1] = s
			size = size + #s + 1
		end
	end
	if #chunk > 0 then Send(kind .. table.concat(chunk, "^"), i) end
end

function ns.SendSighting(e, zone)
	if not IsInGuild() then return end
	Send("S~" .. e.n .. "~" .. e.r .. "~" .. (ns.Clean(zone, 60) or ""))
end

local offers, offerTimer = {}, nil
local announced = {}
local quietTimer = nil

local RunOffer

local function ScheduleOffer()
	if offerTimer or #sendQueue > 0 or not next(offers) or not C_Timer then return end
	offerTimer = C_Timer.NewTimer(1 + math.random() * 5, RunOffer)
end

RunOffer = function()
	offerTimer = nil
	if #sendQueue > 0 then return end
	local order = {}
	for i in pairs(offers) do order[#order + 1] = i end
	table.sort(order)
	for _, i in ipairs(order) do
		local heardSame = offers[i][Digest(i)]
		local recently = lastBucketSent[i] and (GetTime() - lastBucketSent[i]) < BUCKET_RESEND
		offers[i] = nil
		if not heardSame and not recently then
			SendBucket(i)
			return
		end
	end
end

OnQueueDrained = function()
	inFlight = {}
	ScheduleOffer()
end

local function Offer(i)
	if not offers[i] then offers[i] = {} end
	ScheduleOffer()
end

local function CheckSendBack()
	quietTimer = nil
	local heard = announced
	announced = {}
	for i, digests in pairs(heard) do
		for digest in pairs(digests) do
			if digest ~= Digest(i) then
				Offer(i)
				break
			end
		end
	end
	ns.Fire("SYNC_SETTLED")
end

local function TrafficSeen()
	if quietTimer then quietTimer:Cancel() end
	if C_Timer then quietTimer = C_Timer.NewTimer(QUIET_TIME, CheckSendBack) end
end

local function IsMe(sender)
	if type(sender) ~= "string" then return true end
	local me = ns.MyFullName():lower()
	local s = sender:lower()
	if not s:find("-", 1, true) then s = s .. "-" .. ns.MyRealm():lower() end
	return s == me
end

local READERS = {
	U = { "Deserialize", "MergeIncoming" }, D = { "Deserialize", "MergeIncoming" },
	G = { "DeserializeGuild", "MergeIncomingGuild" }, E = { "DeserializeGuild", "MergeIncomingGuild" },
	K = { "Deserialize", "MergeIncomingBlack" }, F = { "Deserialize", "MergeIncomingBlack" },
}

local function Merge(s, sender, kind)
	local reader = READERS[kind]
	local e = ns[reader[1]](s)
	if not e then return end
	if ns[reader[2]](e) then
		stats.merged = stats.merged + 1
		ns.lastMergeFrom = sender
	end
end

local function ReadDigests(body, n)
	local out = {}
	for d in body:gmatch("[^,]+") do out[#out + 1] = tonumber(d, 36) end
	if #out ~= n then return nil end
	return out
end

local function OnMessage(text, sender)
	stats.received = stats.received + 1
	local kind, body = text:match("^(%u)~(.*)$")
	if not kind then return end
	stats.peers[sender] = GetTime()

	if kind == "U" or kind == "G" or kind == "K" then
		Merge(body, sender, kind)

	elseif kind == "D" or kind == "E" or kind == "F" then
		ns.syncQuiet = true
		for s in (body .. "^"):gmatch("([^%^]*)%^") do
			if s ~= "" then Merge(s, sender, kind) end
		end
		ns.syncQuiet = false
		TrafficSeen()

	elseif kind == "Q" then
		local digest = tonumber(body, 36)
		if digest and digest ~= ns.GuildDigest() then Offer(GUILD_BUCKET) end

	elseif kind == "B" then
		local i, digest = body:match("^(%d+)~(%w+)$")
		i, digest = tonumber(i), digest and tonumber(digest, 36)
		if i and digest and i >= 1 and i <= LAST_BUCKET then
			announced[i] = announced[i] or {}
			announced[i][digest] = true
			if offers[i] then offers[i][digest] = true end

			if inFlight[i] == digest and sender:lower() < ns.MyFullName():lower() then
				DropQueuedBucket(i)
				inFlight[i] = nil
			end
			TrafficSeen()
		end

	elseif kind == "H" or kind == "W" then
		local players = kind == "H"
		local mine = players and ns.BucketHashes() or ns.BlackHashes()
		local theirs = ReadDigests(body, #mine)
		if not theirs then return end
		for i = 1, #mine do
			if theirs[i] ~= mine[i] then Offer(players and i or (GUILD_BUCKET + i)) end
		end

	elseif kind == "S" then
		local name, realm, zone = body:match("^([^~]+)~([^~]+)~(.*)$")
		if name then
			ns.Fire("GUILD_SIGHTING", ns.Key(name, realm), PlainText(zone), sender)
		end
	end
end

ns.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	prefix, text, channel, sender = Plain(prefix), Plain(text), Plain(channel), Plain(sender)
	if prefix ~= COMM_PREFIX or type(text) ~= "string" or channel ~= CHANNEL then return end
	if not ns.db or IsMe(sender) then return end
	OnMessage(text, sender)
end)

local helloStarted = false
ns.On("PLAYER_ENTERING_WORLD", function()
	if helloStarted or not C_Timer then return end
	helloStarted = true
	local function TryHello(attempt)
		if ns.SendHello() then return end

		if attempt < 6 then
			C_Timer.After(10, function() TryHello(attempt + 1) end)
		end
	end
	C_Timer.After(HELLO_AFTER_LOGIN + math.random() * 7, function() TryHello(1) end)
	C_Timer.NewTicker(HELLO_EVERY, function() ns.SendHello() end)
end)

function ns.SyncNow()
	return ns.SendHello()
end

ns._sync = { OnMessage = OnMessage, Pump = PumpSendQueue, CheckSendBack = CheckSendBack, queue = sendQueue }
end

do

local Plain, PlainText = ns.Plain, ns.PlainText

ns.nearby = {}
local lastAlert = {}
local lastShared = {}
local lastGuildNote = {}
local lastGuildAlert = {}

local SOUNDS = {
	kos = "detected-kos.mp3",
	nearby = "detected-nearby.mp3",
	add = "list-add.mp3",
	remove = "list-remove.mp3",
}
function ns.PlaySound(which)
	local file = SOUNDS[which]
	if not file or not PlaySoundFile then return end
	pcall(PlaySoundFile, ns.SOUND_DIR .. file, "Master")
end

local SHARE_COOLDOWN = 60
local GUILD_NOTE_COOLDOWN = 30

local function Call(fn, ...)
	if not fn then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return Plain(a), Plain(b), Plain(c)
end
ns.Call = Call

ns.allies = {}
ns.allyGuilds = {}

local guildKeys, guildKeysDirty = {}, true
local function GuildKeys()
	if not guildKeysDirty then return guildKeys end
	guildKeysDirty = false
	guildKeys = {}
	local count = Call(GetNumGuildMembers) or 0
	for i = 1, math.min(count, 1000) do
		local full = Call(GetGuildRosterInfo, i)
		local n, r = ns.SplitName(PlainText(full))
		if n then guildKeys[ns.Key(n, r or ns.MyRealm())] = true end
	end
	return guildKeys
end
ns.On("GUILD_ROSTER_UPDATE", function() guildKeysDirty = true end)
ns.On("PLAYER_GUILD_UPDATE", function() guildKeysDirty = true end)

function ns.IsGuildmate(key)
	return GuildKeys()[key] or false
end

function ns.IsEnemy(info)
	return info.ally == false or (info.ally == nil and info.hostile == true)
end

function ns.IsAlly(info)
	if type(info) ~= "table" or not info.name then return false end
	if info.ally ~= nil then return info.ally end
	local key = ns.Key(info.name, info.realm or ns.MyRealm())
	if ns.allies[key] or GuildKeys()[key] then return true end
	local who, who2 = info.name, nil
	if info.realm and info.realm:lower() ~= ns.MyRealm():lower() then
		who, who2 = info.name .. "-" .. info.realm, info.name .. " " .. info.realm
	end
	if Call(UnitInParty, who) or Call(UnitInRaid, who) then return true end
	if who2 and (Call(UnitInParty, who2) or Call(UnitInRaid, who2)) then return true end
	return false
end

function ns.IsAllyGuild(name)
	local key = ns.GuildKey(name)
	if not key then return false end
	local mine = PlainText(Call(GetGuildInfo, "player"))
	return ns.allyGuilds[key] or (mine and mine:lower() == key) or false
end

function ns.RefuseAlly(info)
	if not ns.IsAlly(info) then return false end
	ns.Print(ns.FullName(info.name, info.realm) .. " is on our side, so they can't go on the kill list.")
	return true
end

function ns.ReadUnit(unit)
	if not Call(UnitExists, unit) then return nil end
	local isPlayer = Call(UnitIsPlayer, unit)
	if isPlayer == false then return nil end
	if Call(UnitIsUnit, unit, "player") then return nil end
	local name, realm = Call(UnitName, unit)

	if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT or name == UNKNOWN then return nil, true end
	if not isPlayer then return nil, true end
	if type(realm) ~= "string" or realm == "" then realm = nil end
	local _, classFile = Call(UnitClass, unit)
	local level = Call(UnitLevel, unit)
	local race = Call(UnitRace, unit)
	local guild = Call(GetGuildInfo, unit)
	local dead = Call(UnitIsDeadOrGhost, unit)
	local hostile = Call(UnitIsEnemy, "player", unit)
	if hostile == nil then hostile = Call(UnitCanAttack, "player", unit) end
	local theirFaction = Call(UnitFactionGroup, unit)
	local myFaction = Call(UnitFactionGroup, "player")
	if theirFaction and myFaction and theirFaction ~= myFaction and theirFaction ~= "Neutral" then hostile = true end

	local ally
	if theirFaction and myFaction and theirFaction ~= "Neutral" then
		ally = theirFaction == myFaction
	elseif not hostile then
		ally = Call(UnitIsFriend, "player", unit) and true or nil
	end
	if ally then
		ns.allies[ns.Key(name, realm or ns.MyRealm())] = true
		if type(guild) == "string" and guild ~= "" then ns.allyGuilds[guild:lower()] = true end
	end
	return {
		name = name,
		realm = realm or ns.MyRealm(),
		class = type(classFile) == "string" and classFile or nil,
		level = type(level) == "number" and level or nil,
		race = type(race) == "string" and race or nil,
		guild = type(guild) == "string" and guild ~= "" and guild or nil,
		hostile = hostile and true or false,
		ally = ally,
		dead = dead and true or false,
		unit = unit,
	}
end

function ns.WhereAmI()
	local zone = PlainText(GetRealZoneText and GetRealZoneText()) or PlainText(GetZoneText and GetZoneText()) or ""
	local sub = PlainText(GetSubZoneText and GetSubZoneText())
	local text = zone
	if sub and sub ~= zone then text = sub .. ", " .. zone end
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
		local ok, pos = pcall(function()
			local mapID = Plain(C_Map.GetBestMapForUnit("player"))
			if not mapID then return nil end
			local p = C_Map.GetPlayerMapPosition(mapID, "player")
			if not p then return nil end
			local x, y = p:GetXY()
			x, y = Plain(x), Plain(y)
			if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
				return string.format(" (%.0f, %.0f)", x * 100, y * 100)
			end
		end)
		if ok and pos then text = text .. pos end
	end
	return text
end

function ns.Alert(e, info, test, quiet)
	local key = ns.Key(e.n, e.r)
	local now = GetTime()
	if not test and lastAlert[key] and now - lastAlert[key] < (ns.Setting("alertCooldown") or 60) then return end
	lastAlert[key] = now
	local level = (info and info.level) or e.lv
	local levelText = (level and level > 0) and (" (" .. level .. ")") or ""
	if ns.Setting("chat") then
		local why = e.w and (" - " .. e.w) or ""
		ns.Print("|cffff2020KILL ON SIGHT:|r " .. ns.ColorName(e) .. levelText .. why .. " |cff999999(added by " .. ns.SenderName(e.b) .. ")|r")
	end
	if quiet then return end
	if ns.Setting("sound") then ns.PlaySound("kos") end
	if FlashClientIcon then pcall(FlashClientIcon) end
	if ns.Setting("banner") and ns.ShowBanner then ns.ShowBanner(e, level) end
end

function ns.GuildMemberEntry(g, info)
	return {
		n = ns.ProperName(info.name), r = info.realm, c = info.class, g = info.guild or g.n,
		w = "whole guild <" .. g.n .. "> is on the list" .. (g.w and (": " .. g.w) or ""), b = g.b,
	}
end

local function GuildAlert(g, info)
	local gkey = g.n:lower()
	local loud = not lastGuildAlert[gkey] or GetTime() - lastGuildAlert[gkey] >= (ns.Setting("alertCooldown") or 60)
	if loud then lastGuildAlert[gkey] = GetTime() end
	ns.Alert(ns.GuildMemberEntry(g, info), info, false, not loud)
end

local lastNearbySound = 0
local allyNoted = {}
local WHERE_EVERY = 5

local function Seen(info, fromCombatLog)
	local key = ns.Key(info.name, info.realm)
	local e = ns.Get(key)
	if info.ally then

		if e and not allyNoted[key] then
			allyNoted[key] = true
			ns.Print(ns.ColorName(e) .. " is on the kill list but is on our side. Type |cffffd200/kos remove "
				.. ns.DisplayName(e) .. "|r to take them off.")
		end
		return
	end
	local g = not e and ns.GetGuild(info.guild)
	if not e and not g and not info.hostile then return end

	local n = ns.nearby[key]
	local isNewcomer = not n
	if not n then
		n = {}
		ns.nearby[key] = n
		n.first = GetTime()
		ns.nearbyDirty = true
	end
	if ns.RecordEnemy then ns.RecordEnemy(info, isNewcomer) end
	if isNewcomer and not e and not g and info.hostile and not info.dead and ns.Setting("nearbySound")
		and GetTime() - lastNearbySound > 2 then
		lastNearbySound = GetTime()
		ns.PlaySound("nearby")
	end
	n.name, n.realm = ns.ProperName(info.name), info.realm
	n.class = info.class or n.class
	n.level = info.level or n.level
	n.guild = info.guild or n.guild
	n.race = info.race or n.race
	n.hostile = info.hostile or n.hostile
	n.seen = GetTime()

	if g then
		if not fromCombatLog then ns.LearnGuildSpelling(info.guild) end
		if not info.dead then GuildAlert(ns.GetGuild(info.guild), info) end
		return
	end
	if not e then return end

	e.lv = info.level or e.lv
	e.race = info.race or e.race
	local fresh = not n.whereAt or GetTime() - n.whereAt > WHERE_EVERY
	if fresh then
		n.whereAt = GetTime()
		n.where = ns.WhereAmI()
		e.seen, e.sz, e.sb = ns.Now(), n.where, ns.SenderName(ns.MyFullName())
	end
	if not fromCombatLog then ns.LearnDetails(key, info.class, info.guild) end
	e = ns.Get(key) or e

	if info.dead then return end
	ns.Alert(e, info)
	if ns.Setting("shareSightings") and (not lastShared[key] or GetTime() - lastShared[key] > SHARE_COOLDOWN) then
		lastShared[key] = GetTime()
		if ns.SendSighting then ns.SendSighting(e, n.where or ns.WhereAmI()) end
	end
	if fresh then ns.Fire("SEEN", key) end
end

function ns.CheckUnit(unit)
	local info, retry = ns.ReadUnit(unit)
	if info then Seen(info) end
	return info, retry
end

function ns.NearbyList()
	local list, now, keep = {}, GetTime(), ns.Setting("nearbyTime") or 60
	for key, n in pairs(ns.nearby) do
		if now - n.seen > keep then
			ns.nearby[key] = nil
			ns.nearbyDirty = true
		else
			local e = ns.Get(key)
			local g = not e and ns.GetGuild(n.guild) or nil
			if e or g or ns.Setting("nearbyAll") then
				list[#list + 1] = { key = key, n = n, e = e, g = g }
			end
		end
	end
	table.sort(list, function(a, b)
		local la, lb = (a.e or a.g) ~= nil, (b.e or b.g) ~= nil
		if la ~= lb then return la end
		return a.n.seen > b.n.seen
	end)
	return list
end

local pending = {}
local pendingFrame = CreateFrame("Frame")
pendingFrame:Hide()
pendingFrame:SetScript("OnUpdate", ns.Guarded("plates", function(self)
	local now, any = GetTime(), false
	for unit, t in pairs(pending) do
		local info, retry = ns.CheckUnit(unit)
		if info or not retry or now - t > 3 then
			pending[unit] = nil
		else
			any = true
		end
	end
	if not any then self:Hide() end
end))

ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
	local info, retry = ns.CheckUnit(unit)
	if not info and retry and type(unit) == "string" then
		pending[unit] = GetTime()
		pendingFrame:Show()
	end
end)
ns.On("NAME_PLATE_UNIT_REMOVED", function(unit) pending[unit] = nil end)
ns.On("PLAYER_TARGET_CHANGED", function() ns.CheckUnit("target") end)
ns.On("PLAYER_FOCUS_CHANGED", function() ns.CheckUnit("focus") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() ns.CheckUnit("mouseover") end)

local QUICK_UNITS = { "target", "mouseover", "focus", "softenemy", "targettarget" }
local SCAN_EVERY = 0.2

local function ScanPlates()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" then return end
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		unit = Plain(unit)
		if type(unit) == "string" then ns.CheckUnit(unit) end
	end
end

local function ScanGroupTargets()
	local raid = Plain(IsInRaid and IsInRaid())
	local count = Plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if raid then
		for i = 1, math.min(count, 40) do ns.CheckUnit("raid" .. i .. "target") end
	else
		for i = 1, math.min(count, 4) do ns.CheckUnit("party" .. i .. "target") end
	end
	ns.CheckUnit("pettarget")
end

local scanTicker
ns.Listen("DB_READY", function()
	if scanTicker or not C_Timer then return end
	local slow = 0
	scanTicker = C_Timer.NewTicker(SCAN_EVERY, ns.Guarded("scan", function()
		ScanPlates()
		for _, unit in ipairs(QUICK_UNITS) do ns.CheckUnit(unit) end
		slow = slow + SCAN_EVERY
		if slow >= 1 then
			slow = 0
			ScanGroupTargets()
			ns.Fire("TICK")
		end
	end))
end)

function ns.EnemyPlatesOn()
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, v = pcall(get, "nameplateShowEnemies")
	if not ok then return nil end
	return v == "1"
end

local function GetCV(name)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, v = pcall(get, name)
	if ok then return Plain(v) end
end

local function SetCV(name, value)
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, name, value) end
end

function ns.PlateRange()
	return tonumber(GetCV("nameplateMaxDistance"))
end

local FAR = "100"
function ns.ApplyPlateRange()
	if not ns.db then return end
	if InCombatLockdown() then
		ns.plateRangePending = true
		return
	end
	ns.plateRangePending = nil
	local now = GetCV("nameplateMaxDistance")
	if now == nil then return end
	if ns.Setting("farPlates") then
		if ns.db.plateRangeWas == nil then ns.db.plateRangeWas = now end
		if now ~= FAR then SetCV("nameplateMaxDistance", FAR) end
	elseif ns.db.plateRangeWas ~= nil then
		SetCV("nameplateMaxDistance", ns.db.plateRangeWas)
		ns.db.plateRangeWas = nil
	end
end

ns.On("PLAYER_ENTERING_WORLD", function() ns.ApplyPlateRange() end)
ns.On("PLAYER_REGEN_ENABLED", function()
	if ns.plateRangePending then ns.ApplyPlateRange() end
end)
ns.Listen("SETTINGS_CHANGED", function(k)
	if k == "farPlates" then ns.ApplyPlateRange() end
end)

function ns.TurnOnEnemyPlates()
	if InCombatLockdown() then
		ns.Print("can't change nameplates in combat; try again after.")
		return
	end
	SetCV("nameplateShowEnemies", "1")
	if ns.Setting("farPlates") then ns.ApplyPlateRange() end
	local range = ns.PlateRange()
	ns.Print(ns.EnemyPlatesOn() and ("enemy nameplates are on: enemies are spotted as soon as they're in range"
		.. (range and (" (" .. range .. " yards)") or "") .. ".") or "couldn't turn enemy nameplates on.")
end

ns.On("PLAYER_ENTERING_WORLD", function()
	if ns.platesTipShown or not C_Timer then return end
	ns.platesTipShown = true
	C_Timer.After(12, function()
		if ns.EnemyPlatesOn() == false then
			ns.Print("enemy nameplates are off, so enemies are only spotted when you target or mouse over them. Type |cffffd200/kos plates|r to turn them on and spot them as soon as they're in range.")
		end
	end)
end)

if CombatLogGetCurrentEventInfo then
	local TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
	local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
	local band = bit and bit.band
	local function FromLog(name, flags)
		name, flags = Plain(name), Plain(flags)
		if type(name) ~= "string" or type(flags) ~= "number" or not band then return end
		if band(flags, TYPE_PLAYER) == 0 or band(flags, HOSTILE) == 0 then return end
		local n, realm = ns.SplitName(name)
		if not n then return end
		Seen({ name = n, realm = realm, hostile = true }, true)
	end
	ns.On("COMBAT_LOG_EVENT_UNFILTERED", function()
		local _, _, _, _, srcName, srcFlags, _, _, dstName, dstFlags = CombatLogGetCurrentEventInfo()
		FromLog(srcName, srcFlags)
		FromLog(dstName, dstFlags)
	end)
end

ns.Listen("GUILD_SIGHTING", function(key, zone, sender)
	local e = ns.Get(key)
	if not e then return end
	e.seen, e.sz, e.sb = ns.Now(), zone, ns.SenderName(sender)
	if not ns.Setting("guildSightings") then return end
	if lastGuildNote[key] and GetTime() - lastGuildNote[key] < GUILD_NOTE_COOLDOWN then return end
	lastGuildNote[key] = GetTime()
	local where = (zone and zone ~= "") and (" in " .. zone) or ""

	ns.Print(ns.ColorName(e) .. " spotted by " .. ns.SenderName(sender) .. where .. ".")
	ns.Fire("SEEN", key)
end)

local caughtUp = 0
ns.Listen("ADDED_BY_GUILD", function(_, e)
	if ns.syncQuiet then
		caughtUp = caughtUp + 1
		return
	end
	ns.Print(ns.ColorName(e) .. " was added by " .. ns.SenderName(e.b) .. (e.w and (": " .. e.w) or "."))
end)
ns.Listen("GUILD_ADDED_BY_GUILD", function(_, g)
	ns.Print("the whole guild |cffffd200<" .. g.n .. ">|r was put on the list by " .. ns.SenderName(g.b) .. (g.w and (": " .. g.w) or "."))
end)
ns.Listen("GUILD_REMOVED_BY_GUILD", function(_, g)
	if ns.syncQuiet then return end
	ns.Print("the guild <" .. g.n .. "> was taken off the list by " .. ns.SenderName(g.y) .. ".")
end)
ns.Listen("SYNC_SETTLED", function()
	if caughtUp > 0 then
		ns.Print("caught up with the guild: " .. caughtUp .. " player" .. (caughtUp == 1 and "" or "s") .. " added to your list (" .. ns.Count() .. " in all).")
		caughtUp = 0
	end
end)

local function OnUnitTooltip(tooltip)
	if not ns.active then return end
	if tooltip ~= GameTooltip or not tooltip.GetUnit then return end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	unit = ok and Plain(unit) or nil
	if type(unit) ~= "string" then return end
	local info = ns.ReadUnit(unit)
	if not info then return end
	local key = ns.Key(info.name, info.realm)
	local e = ns.Get(key)
	local g = not e and not info.ally and ns.GetGuild(info.guild)
	if e then
		tooltip:AddLine("Kill on sight" .. (e.w and (": " .. e.w) or ""), 1, 0.15, 0.15, true)
		tooltip:AddLine("BH&G Kill List, added by " .. ns.SenderName(e.b), 0.6, 0.6, 0.6)
	elseif g then
		tooltip:AddLine("Kill on sight: the whole guild <" .. g.n .. ">" .. (g.w and (": " .. g.w) or ""), 1, 0.15, 0.15, true)
		tooltip:AddLine("BH&G Kill List, added by " .. ns.SenderName(g.b), 0.6, 0.6, 0.6)
	end
	local black = not ns.IsEnemy(info) and ns.GetBlack(key)
	if black then
		tooltip:AddLine("On the guild Blacklist: " .. (black.w or "no reason given"), 1, 0.6, 0.1, true)
		tooltip:AddLine("BH&G Kill List, added by " .. ns.SenderName(black.b), 0.6, 0.6, 0.6)
	end
	local rec = ns.Enemy and ns.Enemy(key)
	if rec and (e or info.hostile) and ((rec.w or 0) + (rec.l or 0)) > 0 then
		tooltip:AddLine("Your record: " .. ns.Score(rec), 1, 1, 1)
	end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ns.Guarded("tooltip", OnUnitTooltip))
elseif GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnTooltipSetUnit", ns.Guarded("tooltip", OnUnitTooltip))
end

local MENUS = {
	"MENU_UNIT_PLAYER", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS",
	"MENU_UNIT_FRIEND", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_CHAT_ROSTER",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
}

local function MenuTarget(contextData)
	if type(contextData) ~= "table" then return nil end
	local unit = PlainText(contextData.unit)
	if unit then
		if Call(UnitIsUnit, unit, "player") then return nil end
		local info = ns.ReadUnit(unit)
		if info then return info end
	end
	local n, realm = ns.SplitName(PlainText(contextData.name))
	if not n then return nil end
	local server = PlainText(contextData.server)
	if server then realm = server:gsub("[%s%-]", "") end
	if ns.Key(n, realm) == ns.MyFullName():lower() then return nil end
	return { name = n, realm = realm }
end

local function AddMenuButton(_, rootDescription, contextData)
	if not rootDescription or not ns.active then return end
	local info = MenuTarget(contextData)
	if not info then return end
	local key = ns.Key(info.name, info.realm)
	local killButtons = ns.Get(key) or not ns.IsAlly(info)
	local blackButton = ns.CanBlacklist(info)
	if not killButtons and not blackButton then return end
	rootDescription:CreateDivider()
	if blackButton then
		if ns.GetBlack(key) then
			rootDescription:CreateButton("|cffff9900Remove from the guild Blacklist|r", function() ns.AskBlackRemove(key) end)
		else
			rootDescription:CreateButton("|cffff9900Add to the guild Blacklist|r", function() ns.AskBlackReason(info) end)
		end
	end
	if not killButtons then return end
	if ns.Get(key) then
		rootDescription:CreateButton("|cffe03c3cRemove from BH&G Kill List|r", function()
			ns.RemoveWithMessage(key)
		end)
	elseif not ns.IsAlly(info) then
		rootDescription:CreateButton("|cffe03c3cAdd to BH&G Kill List|r", function()
			ns.AskReason(info)
		end)
	end
	if info.guild and not ns.IsAlly(info) then
		if ns.GetGuild(info.guild) then
			rootDescription:CreateButton("|cffe03c3cRemove guild <" .. info.guild .. "> from BH&G Kill List|r", function()
				ns.AskRemoveGuild(info.guild)
			end)
		else
			rootDescription:CreateButton("|cffe03c3cAdd the whole guild <" .. info.guild .. "> to BH&G Kill List|r", function()
				ns.AskGuildReason(info.guild)
			end)
		end
	end
end

if Menu and Menu.ModifyMenu then
	for _, tag in ipairs(MENUS) do
		pcall(Menu.ModifyMenu, tag, ns.Guarded("menu", AddMenuButton))
	end
end

function ns.AddWithMessage(info, reason)
	if ns.RefuseAlly(info) then return end
	local e, isNew = ns.Add(info, reason)
	if not e then
		ns.Print("couldn't add that player.")
		return
	end
	if isNew then
		if ns.Setting("sound") then ns.PlaySound("add") end
		ns.Print("added " .. ns.ColorName(e) .. (e.w and (": " .. e.w) or "") .. ". Guild members with the addon get it too.")
	else
		ns.Print(ns.ColorName(e) .. " is on the list" .. (e.w and (": " .. e.w) or "") .. ".")
	end
	return e
end

function ns.RemoveWithMessage(key)
	local e = ns.Remove(key)
	if e then
		if ns.Setting("sound") then ns.PlaySound("remove") end
		ns.Print("removed " .. ns.ColorName(e) .. " from the list.")
	else
		ns.Print("that player isn't on the list.")
	end
end

function ns.RefuseAllyGuild(name)
	if not ns.IsAllyGuild(name) then return false end
	ns.Print("<" .. ns.CleanGuildName(name) .. "> is on our side, so it can't go on the kill list.")
	return true
end

function ns.AddGuildWithMessage(name, reason)
	if not ns.CleanGuildName(name) then
		ns.Print("that isn't a guild name.")
		return
	end
	if ns.RefuseAllyGuild(name) then return end
	local g, isNew = ns.AddGuild(name, reason)
	if not g then return end
	if isNew then
		if ns.Setting("sound") then ns.PlaySound("add") end
		ns.Print("added the whole guild |cffffd200<" .. g.n .. ">|r" .. (g.w and (": " .. g.w) or "")
			.. ". Every member you come across is kill on sight, and guild members with the addon get it too.")
	else
		ns.Print("<" .. g.n .. "> is on the list" .. (g.w and (": " .. g.w) or "") .. ".")
	end
	return g
end

function ns.RemoveGuildWithMessage(name)
	local g = ns.RemoveGuild(name)
	if g then
		if ns.Setting("sound") then ns.PlaySound("remove") end
		ns.Print("removed the guild <" .. g.n .. "> from the list. Players added one by one stay on it.")
	else
		ns.Print("that guild isn't on the list.")
	end
end

function ns.TargetGuild()
	local info = ns.ReadUnit("target")
	if not info then return nil, "target an enemy player first." end
	if not info.guild then return nil, ns.FullName(info.name, info.realm) .. " isn't in a guild (or the game isn't showing it)." end
	if ns.IsAlly(info) then return nil, ns.FullName(info.name, info.realm) .. " is on our side." end
	return info.guild
end

function ns.TargetInfo()
	return ns.ReadUnit("target")
end
end

do

local Plain = ns.Plain

local ENGAGED_FOR = 30
local KILLED_BY_FOR = 12
local RECOUNT_AFTER = 60
local NEW_ENCOUNTER = 300
local MAX_ENEMIES = 5000

local engaged = {}
local attacker = {}
local lastWin = {}

local function Call(fn, ...)
	if not fn then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return Plain(a), Plain(b)
end

function ns.Enemies()
	return ns.db.enemies
end

function ns.Enemy(key)
	return ns.db and ns.db.enemies[key]
end

ns.Listen("DB_READY", function()
	local db = ns.db
	if type(db.enemies) ~= "table" then db.enemies = {} end
	local n, list = 0, {}
	for key, rec in pairs(db.enemies) do
		if type(rec) ~= "table" or type(rec.n) ~= "string" then
			db.enemies[key] = nil
		else
			n = n + 1
			list[n] = key
		end
	end

	if n > MAX_ENEMIES then
		table.sort(list, function(a, b) return (db.enemies[a].last or 0) < (db.enemies[b].last or 0) end)
		for i = 1, n do
			if n <= MAX_ENEMIES then break end
			local rec = db.enemies[list[i]]
			if (rec.w or 0) + (rec.l or 0) == 0 then
				db.enemies[list[i]] = nil
				n = n - 1
			end
		end
	end
end)

local function Record(key, name, realm)
	local enemies = ns.db.enemies
	local rec = enemies[key]
	if not rec then
		rec = { n = name, r = realm, first = ns.Now(), times = 0, w = 0, l = 0 }
		enemies[key] = rec
	end
	return rec
end

local function Score(rec)
	return "|cff40ff40" .. (rec.w or 0) .. "W|r / |cffff4040" .. (rec.l or 0) .. "L|r"
end
ns.Score = Score

local function Win(key, how)
	local rec = ns.Enemy(key)
	if not rec then return end
	if lastWin[key] and GetTime() - lastWin[key] < RECOUNT_AFTER then return end
	lastWin[key] = GetTime()
	engaged[key], attacker[key] = nil, nil
	rec.w = (rec.w or 0) + 1
	rec.lastWin = ns.Now()
	if ns.Setting("chat") then
		ns.Print("you killed " .. ns.ColorName({ n = rec.n, r = rec.r, c = rec.c }) .. ". Your record against them: " .. Score(rec) .. ".")
	end
	ns.Fire("STATS_CHANGED", key, how)
end

function ns.RecordEnemy(info, isNewcomer)
	local key = ns.Key(info.name, info.realm)
	local rec = Record(key, ns.ProperName(info.name), info.realm)
	local now = ns.Now()
	if isNewcomer or not rec.last or now - rec.last > NEW_ENCOUNTER then
		rec.times = (rec.times or 0) + 1
		rec.zone = ns.WhereAmI()
	end
	rec.last = now
	rec.c = info.class or rec.c
	rec.lv = info.level or rec.lv
	rec.race = info.race or rec.race
	rec.g = info.guild or rec.g

	local unit = info.unit
	if not unit then return rec end
	local t = GetTime()
	if Call(UnitIsUnit, unit .. "target", "player") then
		engaged[key], attacker[key] = t, t
	elseif Call(UnitAffectingCombat, "player") and (Call(UnitIsUnit, unit, "target") or Call(UnitIsUnit, unit, "softenemy")) then
		engaged[key] = t
	end
	if info.dead and engaged[key] and t - engaged[key] < ENGAGED_FOR then
		Win(key, "death")
	end
	return rec
end

function ns.CheckDeath(unit)
	if not Call(UnitIsPlayer, unit) then return end
	if not Call(UnitIsDeadOrGhost, unit) then return end
	local name, realm = Call(UnitName, unit)
	if type(name) ~= "string" or name == "" then return end
	local key = ns.Key(name, (type(realm) == "string" and realm ~= "") and realm or nil)
	if engaged[key] and GetTime() - engaged[key] < ENGAGED_FOR and ns.Enemy(key) then
		Win(key, "death")
	end
end

local function IsWatchedUnit(unit)
	return type(unit) == "string" and (unit:find("^nameplate%d") or unit == "target" or unit == "focus" or unit == "softenemy")
end

ns.On("UNIT_HEALTH", function(unit)
	unit = Plain(unit)
	if IsWatchedUnit(unit) then ns.CheckDeath(unit) end
end)
ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
	unit = Plain(unit)
	if IsWatchedUnit(unit) then ns.CheckDeath(unit) end
end)

local honorPattern
do
	local fmt = _G.COMBATLOG_HONORGAIN or _G.COMBATLOG_HONORGAIN_NO_RANK
	if type(fmt) == "string" then
		local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
		p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "%%d+"):gsub("%%%%%.%%d+f", "[%%d%%.]+")
		honorPattern = "^" .. p
	end
end
ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(msg)
	msg = Plain(msg)
	if type(msg) ~= "string" or not honorPattern then return end
	local victim = msg:match(honorPattern)
	local name, realm = ns.SplitName(victim)
	if not name then return end
	local key = ns.Key(name, realm)
	if not ns.Enemy(key) then Record(key, name, realm).last = ns.Now() end
	Win(key, "honor")
end)

ns.On("PLAYER_DEAD", function()
	local t = GetTime()
	local bestKey, bestTime
	for key, at in pairs(attacker) do
		if t - at < KILLED_BY_FOR and (not bestTime or at > bestTime) then bestKey, bestTime = key, at end
	end
	if not bestKey then
		for key, at in pairs(engaged) do
			if t - at < KILLED_BY_FOR and (not bestTime or at > bestTime) then bestKey, bestTime = key, at end
		end
	end
	if not bestKey then return end
	local rec = ns.Enemy(bestKey)
	if not rec then return end
	for k in pairs(engaged) do engaged[k] = nil end
	for k in pairs(attacker) do attacker[k] = nil end
	rec.l = (rec.l or 0) + 1
	rec.lastLoss = ns.Now()
	if ns.Setting("chat") then
		ns.Print("killed by " .. ns.ColorName({ n = rec.n, r = rec.r, c = rec.c }) .. ". Your record against them: " .. Score(rec) .. ".")
	end
	ns.Fire("STATS_CHANGED", bestKey, "loss")
end)

function ns.EnemyList()
	local list = {}
	for key, rec in pairs(ns.db.enemies) do
		list[#list + 1] = { key = key, rec = rec }
	end
	table.sort(list, function(a, b) return (a.rec.last or 0) > (b.rec.last or 0) end)
	return list
end

function ns.Totals()
	local w, l, n = 0, 0, 0
	for _, rec in pairs(ns.db.enemies) do
		w, l, n = w + (rec.w or 0), l + (rec.l or 0), n + 1
	end
	return w, l, n
end

function ns.AddStatsLines(tooltip, key)
	local rec = ns.Enemy(key)
	if not rec then return end
	tooltip:AddLine("Your record: " .. Score(rec), 1, 1, 1)
	local seen = "Seen " .. (rec.times or 1) .. " time" .. ((rec.times or 1) == 1 and "" or "s") .. ", first " .. ns.Ago(rec.first)
	tooltip:AddLine(seen, 0.6, 0.6, 0.6)
end

ns._stats = { engaged = engaged, attacker = attacker }
end

do

local Plain, PlainText = ns.Plain, ns.PlainText
local Call = ns.Call

local LEAVE_WAIT = 10
local GROUP_COOLDOWN = 300
local INVITE_COOLDOWN = 30
local CHAT_COOLDOWN = 600

local function WhyNot(info)
	if type(info) ~= "table" or type(info.name) ~= "string" then return "that isn't a player name." end
	local key = ns.Key(info.name, info.realm)
	local name = ns.FullName(info.name, info.realm)
	if key == ns.MyFullName():lower() then return "you can't put yourself on the Blacklist." end
	if ns.IsEnemy(info) then
		return name .. " is on the other side. The Blacklist is for players on ours; enemies go on the kill list."
	end
	if ns.IsGuildmate(key) then return name .. " is in our guild, so they can't go on the Blacklist." end
	return nil
end

function ns.CanBlacklist(info)
	if type(info) ~= "table" or type(info.name) ~= "string" then return false end
	return ns.GetBlack(ns.Key(info.name, info.realm)) ~= nil or WhyNot(info) == nil
end

function ns.RefuseBlack(info)
	local why = WhyNot(info)
	if why then ns.Print(why) end
	return why ~= nil
end

function ns.AddBlackWithMessage(info, reason)
	if ns.RefuseBlack(info) then return end
	local e, isNew = ns.AddBlack(info, reason)
	if not e then
		ns.Print("couldn't add that player.")
		return
	end
	if isNew then
		ns.Print("put " .. ns.ColorName(e) .. " on the guild Blacklist" .. (e.w and (": " .. e.w) or "") .. ". Guild members with the addon get it too.")
	else
		ns.Print(ns.ColorName(e) .. " is on the guild Blacklist" .. (e.w and (": " .. e.w) or "") .. ".")
	end
	return e
end

function ns.RemoveBlackWithMessage(key)
	local e = ns.RemoveBlack(key)
	if e then
		ns.Print("took " .. ns.ColorName(e) .. " off the guild Blacklist.")
	else
		ns.Print("that player isn't on the guild Blacklist.")
	end
end

local function FromName(text)
	text = PlainText(text)
	if not text then return nil end
	text = text:match("|h%[?(.-)%]?|h") or text
	local name, realm = ns.SplitName(text)
	if not name then return nil end
	return ns.Key(name, realm), { name = name, realm = realm }
end

local lastWarn = {}

local function Warn(e, how, kind, cooldown, loud)
	if not ns.Setting(kind == "chat" and "blackChat" or "blackWarn") then return end
	local id = ns.Key(e.n, e.r) .. "|" .. kind
	if lastWarn[id] and GetTime() - lastWarn[id] < cooldown then return end
	lastWarn[id] = GetTime()
	ns.Print("|cffff9900BLACKLISTED:|r " .. ns.ColorName(e) .. " " .. how .. (e.w and (" - " .. e.w) or "")
		.. " |cff999999(added by " .. ns.SenderName(e.b) .. ")|r")
	if not loud then return end
	if FlashClientIcon then pcall(FlashClientIcon) end
	if ns.Setting("banner") and ns.ShowBanner then ns.ShowBanner(e, nil, "BLACKLISTED", how) end
end

local function InGroup(key)
	local e = ns.GetBlack(key)
	if not e then return end
	e.gs = ns.Now()
	Warn(e, "is in your group", "group", GROUP_COOLDOWN, true)
	ns.Fire("LIST_CHANGED")
end

ns.On("PARTY_INVITE_REQUEST", function(inviter)
	local key = FromName(inviter)
	local e = key and ns.GetBlack(key)
	if e then Warn(e, "invited you to a group", "invite", INVITE_COOLDOWN, true) end
end)

local function OnChat(how)
	return function(_, sender, _, _, _, _, _, _, channelName)
		local key = FromName(sender)
		local e = key and ns.GetBlack(key)
		if not e then return end
		local channel = PlainText(channelName)
		Warn(e, how or ("is talking in " .. (channel or "a chat channel")), "chat", CHAT_COOLDOWN, false)
	end
end
ns.On("CHAT_MSG_WHISPER", OnChat("is whispering you"))
ns.On("CHAT_MSG_CHANNEL", OnChat(nil))

local function InDungeon()
	if not IsInInstance then return false end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and Plain(inside) and Plain(kind) == "party" or false
end

local function Zone()
	return PlainText(GetRealZoneText and GetRealZoneText()) or "a dungeon"
end

local pending, quietUntil = nil, 0

local function Left(key, info)
	if not ns.Setting("leavePrompt") or not InDungeon() then return end
	if ns.GetBlack(key) or ns.IsGuildmate(key) or key == ns.MyFullName():lower() then return end
	if pending and pending.key == key then return end
	local now = GetTime()
	if pending or now < quietUntil then
		pending, quietUntil = nil, now + LEAVE_WAIT
		return
	end
	local mine = { key = key, info = info, zone = Zone() }
	pending = mine
	C_Timer.After(LEAVE_WAIT, function()
		if pending ~= mine then return end
		pending = nil
		if not InDungeon() or (Call(GetNumGroupMembers) or 0) < 2 then return end
		if ns.GetBlack(key) then return end
		ns.AskBlackLeaver(mine.info, "Left " .. mine.zone .. " early")
	end)
end

local function ReadGroup()
	local members, unreadable = {}, false
	local count = Call(GetNumGroupMembers) or 0
	if count == 0 then return members, false, 0 end
	local raid = Call(IsInRaid)
	local last, prefix = math.min(count - 1, 4), "party"
	if raid then last, prefix = math.min(count, 40), "raid" end
	local me = ns.MyFullName():lower()
	for i = 1, last do
		local unit = prefix .. i
		local name, realm = Call(UnitName, unit)
		if type(name) == "string" and name ~= "" and name ~= UNKNOWNOBJECT and name ~= UNKNOWN then
			if type(realm) ~= "string" or realm == "" then realm = nil end
			local key = ns.Key(name, realm)
			if key ~= me then
				local _, class = Call(UnitClass, unit)
				members[key] = { name = name, realm = realm or ns.MyRealm(), class = class, guild = Call(GetGuildInfo, unit), ally = true }
			end
		else
			unreadable = true
		end
	end
	return members, unreadable, count
end

local roster = {}

ns.On("GROUP_ROSTER_UPDATE", function()
	local members, unreadable, count = ReadGroup()
	if count == 0 then
		roster = {}
		return
	end
	for key in pairs(members) do
		if not roster[key] then InGroup(key) end
	end
	if unreadable then

		for key, info in pairs(members) do roster[key] = info end
		return
	end
	local gone = {}
	for key, info in pairs(roster) do
		if not members[key] then gone[key] = info end
	end
	roster = members
	for key, info in pairs(gone) do Left(key, info) end
end)

local function Pattern(fmt, fallback)
	fmt = type(fmt) == "string" and fmt or fallback
	local escaped = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	return "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

local JOINED = {
	Pattern(_G.ERR_JOINED_GROUP_S, "%s joins the party."),
	Pattern(_G.ERR_RAID_MEMBER_ADDED_S, "%s has joined the raid group."),
}
local LEFT = Pattern(_G.ERR_LEFT_GROUP_S, "%s leaves the party.")

ns.On("CHAT_MSG_SYSTEM", function(text)
	text = PlainText(text)
	if not text then return end
	for _, pattern in ipairs(JOINED) do
		local key = FromName(text:match(pattern))
		if key then InGroup(key) return end
	end
	local key, info = FromName(text:match(LEFT))
	if key then Left(key, info) end
end)

local caughtUp = 0
ns.Listen("BLACK_ADDED_BY_GUILD", function(_, e)
	if ns.syncQuiet then
		caughtUp = caughtUp + 1
		return
	end
	ns.Print(ns.ColorName(e) .. " was put on the guild Blacklist by " .. ns.SenderName(e.b) .. (e.w and (": " .. e.w) or "."))
end)
ns.Listen("BLACK_REMOVED_BY_GUILD", function(_, e)
	if ns.syncQuiet then return end
	ns.Print(ns.ColorName(e) .. " was taken off the guild Blacklist by " .. ns.SenderName(e.y) .. ".")
end)
ns.Listen("SYNC_SETTLED", function()
	if caughtUp > 0 then
		ns.Print("caught up with the guild: " .. caughtUp .. " player" .. (caughtUp == 1 and "" or "s")
			.. " added to your Blacklist (" .. ns.BlackCount() .. " in all).")
		caughtUp = 0
	end
end)
end

do

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 0.88, 0.24, 0.24 }

local function Backdrop(f, alpha)
	if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.06, alpha or 0.9)
	f:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function SavePos(f, key, topLeft)
	if topLeft then
		local x, y = f:GetLeft(), f:GetTop()
		if x and y then ns.db.pos[key] = { left = x, top = y } end

		if x and y and not InCombatLockdown() then
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		end
		return
	end
	local x, y = f:GetCenter()
	if x and y then ns.db.pos[key] = { x = x, y = y } end
end

local function RestorePos(f, key, point, rel, relPoint, dx, dy)
	f:ClearAllPoints()
	local p = ns.db.pos[key]
	if p and p.left and p.top then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left, p.top)
	elseif p and p.x and p.y then
		if point == "TOPLEFT" then

			local w, h = f:GetWidth() or 0, f:GetHeight() or 0
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x - w / 2, p.y + h / 2)
		else
			f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
		end
	else
		f:SetPoint(point, rel, relPoint, dx, dy)
	end
end

local function Text(parent, template, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function NameColor(classFile, name)
	local r, g, b = ns.ClassColor(classFile)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

local function EditBoxOf(dialog)
	return dialog and ((dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox)
end

local function TextPopup(id, def, onAccept, start)
	def.button1 = def.button1 or ACCEPT or "Accept"
	def.button2 = def.button2 or CANCEL or "Cancel"
	def.hasEditBox = 1
	def.timeout = def.timeout or 0
	def.whileDead, def.hideOnEscape = 1, 1
	if def.exclusive == nil then def.exclusive = 1 end
	def.OnShow = function(dialog, data)
		local eb = EditBoxOf(dialog)
		if eb then
			eb:SetText(start and start(data or dialog.data) or "")
			eb:SetFocus()
		end
	end
	def.OnAccept = function(dialog, data)
		local eb = EditBoxOf(dialog)
		onAccept(eb and eb:GetText() or "", data or dialog.data)
	end
	def.EditBoxOnEnterPressed = function(eb)
		local dialog = eb:GetParent()
		def.OnAccept(dialog, dialog.data)
		dialog:Hide()
	end
	def.EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end
	StaticPopupDialogs[ns.POPUP_PREFIX .. id] = def
end

local function AskName(id, text, andThen)
	TextPopup(id, { text = text, maxLetters = 60 }, function(typed)
		local name, realm = ns.SplitName(typed)
		if not name then ns.Print("that isn't a player name.") return end
		C_Timer.After(0.05, function() andThen({ name = name, realm = realm }) end)
	end)
end

AskName("ADD_NAME", "Add a player to the BH&G Kill List.\nName (or Name-Realm):", function(info) ns.AskReason(info) end)
AskName("BLACK_NAME", "Put a player on the guild Blacklist.\nName (or Name-Realm):", function(info) ns.AskBlackReason(info) end)

TextPopup("ADD_GUILD", {
	text = "Put a whole guild on the BH&G Kill List.\nEvery member you come across counts as kill on sight.\nGuild name:",
	maxLetters = 64,
}, function(typed)
	local name = ns.CleanGuildName(typed)
	if not name then ns.Print("that isn't a guild name.") return end
	C_Timer.After(0.05, function() ns.AskGuildReason(name) end)
end, function() return ns.TargetGuild() end)

TextPopup("REASON", { text = "Why is %s kill on sight? (optional)", maxLetters = 80, editBoxWidth = 300 }, function(reason, data)
	if not data then return end
	if data.guild and data.edit then
		ns.SetGuildReason(data.guild, reason)
	elseif data.guild then
		ns.AddGuildWithMessage(data.guild, reason)
	elseif data.edit then
		ns.SetReason(data.key, reason)
	else
		ns.AddWithMessage(data.info, reason)
	end
end, function(data)
	local e = data and ((data.key and ns.Get(data.key)) or (data.guild and ns.GetGuild(data.guild)))
	return e and e.w
end)

TextPopup("BLACK_REASON", { text = "Why put %s on the guild Blacklist? (optional)", maxLetters = 80, editBoxWidth = 300 }, function(reason, data)
	if not data then return end
	if data.edit then
		ns.SetBlackReason(data.key, reason)
	else
		ns.AddBlackWithMessage(data.info, reason)
	end
end, function(data)
	local e = data and data.key and ns.GetBlack(data.key)
	return e and e.w or (data and data.reason)
end)

TextPopup("BLACK_LEAVER", {
	text = "%s left your dungeon group (or was removed from it).\nPut them on the guild Blacklist? Reason:",
	button1 = "Blacklist", button2 = NO or "No",
	maxLetters = 80, editBoxWidth = 300, timeout = 60, exclusive = false,
}, function(reason, data)
	if data then ns.AddBlackWithMessage(data.info, reason) end
end, function(data) return data and data.reason end)

local function YesNoPopup(id, text, onAccept)
	StaticPopupDialogs[ns.POPUP_PREFIX .. id] = {
		text = text,
		button1 = YES or "Yes",
		button2 = NO or "No",
		timeout = 0, whileDead = 1, hideOnEscape = 1, exclusive = 1,
		OnAccept = function(dialog, data) onAccept(data or dialog.data) end,
	}
end

YesNoPopup("REMOVE", "Remove %s from the BH&G Kill List?\nThis takes them off everyone's list.", function(data)
	if data and data.guild then
		ns.RemoveGuildWithMessage(data.guild)
	elseif data and data.key then
		ns.RemoveWithMessage(data.key)
	end
end)

YesNoPopup("BLACK_REMOVE", "Take %s off the guild Blacklist?\nThis takes them off everyone's.", function(data)
	if data and data.key then ns.RemoveBlackWithMessage(data.key) end
end)

function ns.AskReason(info)
	if ns.RefuseAlly(info) then return end
	local shown = NameColor(info.class, ns.FullName(info.name, info.realm))
	StaticPopup_Show(ns.POPUP_PREFIX .. "REASON", shown, nil, { info = info })
end

function ns.AskEditReason(key)
	local e = ns.Get(key)
	if not e then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "REASON", ns.ColorName(e), nil, { key = key, edit = true })
end

function ns.AskRemove(key)
	local e = ns.Get(key)
	if not e then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "REMOVE", ns.ColorName(e), nil, { key = key })
end

function ns.AskBlackEdit(key)
	local e = ns.GetBlack(key)
	if not e then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "BLACK_REASON", ns.ColorName(e), nil, { key = key, edit = true })
end

function ns.AskBlackReason(info)
	local key = ns.Key(info.name, info.realm)
	if ns.GetBlack(key) then return ns.AskBlackEdit(key) end
	if ns.RefuseBlack(info) then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "BLACK_REASON", NameColor(info.class, ns.FullName(info.name, info.realm)), nil, { info = info })
end

function ns.AskBlackLeaver(info, reason)
	StaticPopup_Show(ns.POPUP_PREFIX .. "BLACK_LEAVER", NameColor(info.class, ns.FullName(info.name, info.realm)), nil, { info = info, reason = reason })
end

function ns.AskBlackRemove(key)
	local e = ns.GetBlack(key)
	if not e then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "BLACK_REMOVE", ns.ColorName(e), nil, { key = key })
end

function ns.AskBlackName()
	StaticPopup_Show(ns.POPUP_PREFIX .. "BLACK_NAME")
end

local function GuildText(name)
	return "the whole guild |cffffd200<" .. name .. ">|r"
end

function ns.AskGuildReason(name)
	name = ns.CleanGuildName(name)
	if not name or ns.RefuseAllyGuild(name) then return end
	local g = ns.GetGuild(name)
	StaticPopup_Show(ns.POPUP_PREFIX .. "REASON", GuildText(g and g.n or name), nil, { guild = name, edit = g ~= nil })
end

function ns.AskRemoveGuild(name)
	local g = ns.GetGuild(name)
	if not g then return end
	StaticPopup_Show(ns.POPUP_PREFIX .. "REMOVE", GuildText(g.n), nil, { guild = g.n })
end

function ns.AskAddGuild()
	StaticPopup_Show(ns.POPUP_PREFIX .. "ADD_GUILD")
end

function ns.AskAddName()
	StaticPopup_Show(ns.POPUP_PREFIX .. "ADD_NAME")
end

local banner = CreateFrame("Frame", ns.FRAME_PREFIX .. "Banner", UIParent, BACKDROP_TEMPLATE)
banner:SetSize(420, 74)
banner:SetFrameStrata("HIGH")
banner:Hide()
Backdrop(banner, 0.8)
banner:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
banner.title = Text(banner, "GameFontNormalLarge", "CENTER")
banner.title:SetPoint("TOP", 0, -8)
banner.title:SetTextColor(1, 0.15, 0.15)
banner.title:SetText("KILL ON SIGHT")
banner.name = Text(banner, "GameFontHighlightLarge", "CENTER")
banner.name:SetPoint("TOP", banner.title, "BOTTOM", 0, -4)
banner.why = Text(banner, "GameFontHighlightSmall", "CENTER")
banner.why:SetPoint("TOP", banner.name, "BOTTOM", 0, -4)
banner.why:SetWidth(400)
banner:SetMovable(true)
banner:SetClampedToScreen(true)
banner:RegisterForDrag("LeftButton")
banner:SetScript("OnDragStart", function(self) if self.unlocked then self:StartMoving() end end)
banner:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self, "banner") end)

local BANNER_TIME = 6
banner:SetScript("OnUpdate", function(self, elapsed)
	if self.unlocked then self:SetAlpha(1) return end
	self.left = (self.left or 0) - elapsed
	if self.left <= 0 then self:Hide() return end
	self:SetAlpha(math.min(1, self.left / 1.0))
end)

function ns.ShowBanner(e, level, title, how)
	local levelText = (level and level > 0) and ("  |cffcccccc" .. level .. "|r") or ""
	local guild = e.g and ("  |cff999999<" .. e.g .. ">|r") or ""
	banner.title:SetText(title or "KILL ON SIGHT")
	if title then banner.title:SetTextColor(1, 0.6, 0.1) else banner.title:SetTextColor(1, 0.15, 0.15) end
	banner.name:SetText(ns.ColorName(e) .. (how and ("  |cffcccccc" .. how .. "|r") or "") .. levelText .. guild)
	local why = e.w or "No reason given"
	banner.why:SetText(why .. "  |cff999999- added by " .. ns.SenderName(e.b) .. "|r")
	banner.left = BANNER_TIME
	banner:SetAlpha(1)
	banner:Show()
end

function ns.ToggleBannerMove()
	banner.unlocked = not banner.unlocked
	banner:EnableMouse(banner.unlocked)
	if banner.unlocked then
		banner.title:SetText("KILL ON SIGHT")
		banner.title:SetTextColor(1, 0.15, 0.15)
		banner.name:SetText("Drag me where you want the warning")
		banner.why:SetText("Type /kos move again when you're done")
		banner:Show()
	else
		banner:Hide()
	end
	return banner.unlocked
end

local NEARBY_ROWS = 10
local ROW_H = 16
local NEARBY_W = 250

local nearby = CreateFrame("Frame", ns.FRAME_PREFIX .. "Nearby", UIParent, BACKDROP_TEMPLATE)
nearby:SetSize(NEARBY_W, 22)
nearby:SetFrameStrata("MEDIUM")
nearby:SetClampedToScreen(true)
nearby:SetMovable(true)
nearby:EnableMouse(true)
nearby:RegisterForDrag("LeftButton")
nearby:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
nearby:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self, "nearby", true) end)
Backdrop(nearby, 0.75)
nearby:Hide()

nearby.title = Text(nearby, "GameFontNormalSmall")
nearby.title:SetPoint("TOPLEFT", 6, -5)
nearby.title:SetText("Horde Scum Nearby")

nearby:SetScript("OnEnter", function(self)
	if not ns.db then return end
	local w, l, n = ns.Totals()
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Horde Scum Nearby")
	GameTooltip:AddLine("Your record: " .. ns.Score({ w = w, l = l }), 1, 1, 1)
	GameTooltip:AddLine(n .. " enemy player" .. (n == 1 and "" or "s") .. " seen so far", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Hover a name for your record against them. /kos to see everyone you've met.", 0.5, 0.8, 1, true)
	GameTooltip:Show()
end)
nearby:SetScript("OnLeave", function() GameTooltip:Hide() end)
nearby.footer = Text(nearby, "GameFontDisableSmall")
nearby.footer:SetPoint("BOTTOMLEFT", 6, 4)

local rows = {}

local function RowMenu(row)
	local key, info = row.key, row.info
	if not key then return end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(row, function(_, root)
			root:CreateTitle(info and ns.FullName(info.name, info.realm) or "?")
			if ns.Get(key) then
				root:CreateButton("Edit reason", function() ns.AskEditReason(key) end)
				root:CreateButton("|cffe03c3cRemove from kill list|r", function() ns.AskRemove(key) end)
			else
				root:CreateButton("|cffe03c3cAdd to kill list|r", function() ns.AskReason(info) end)
			end
			local guild = info and info.guild
			if guild and ns.GetGuild(guild) then
				root:CreateButton("|cffe03c3cRemove guild <" .. guild .. "> from kill list|r", function() ns.AskRemoveGuild(guild) end)
			elseif guild then
				root:CreateButton("|cffe03c3cAdd the whole guild <" .. guild .. ">|r", function() ns.AskGuildReason(guild) end)
			end
		end)
	elseif ns.Get(key) then
		ns.AskRemove(key)
	elseif info then
		ns.AskReason(info)
	end
end

local function MakeRow(i)
	local row = CreateFrame("Button", ns.FRAME_PREFIX .. "NearbyRow" .. i, nearby, "SecureActionButtonTemplate")
	row:SetSize(NEARBY_W - 8, ROW_H)
	row:SetPoint("TOPLEFT", nearby, "TOPLEFT", 4, -20 - (i - 1) * ROW_H)

	row:RegisterForClicks("AnyDown", "AnyUp")
	row:SetAttribute("type1", "macro")
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
	row.name = Text(row, "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 3, 0)
	row.name:SetWidth(NEARBY_W - 60)
	row.info = nil
	row.right = Text(row, "GameFontDisableSmall", "RIGHT")
	row.right:SetPoint("RIGHT", -3, 0)
	row:SetScript("PostClick", function(self, button, down)
		if ns.clickDebug then
			local get = (C_CVar and C_CVar.GetCVar) or GetCVar
			local ok, keyDown = pcall(get, "ActionButtonUseKeyDown")
			ns.Print(string.format("click: %s %s | cast on key down: %s | type1 %s | macro %s | in combat: %s",
				tostring(button), down and "press" or "release", ok and tostring(keyDown) or "?",
				tostring(self:GetAttribute("type1")), tostring(self:GetAttribute("macrotext")),
				InCombatLockdown() and "yes" or "no"))
			C_Timer.After(0.3, function()
				ns.Print("target now: " .. tostring(ns.PlainText(UnitName("target")) or "none"))
			end)
		end
		if button == "RightButton" and not down then RowMenu(self) end
	end)
	row:SetScript("OnEnter", function(self)
		if not self.key then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		local n = ns.nearby[self.key]
		local e = ns.Get(self.key)
		GameTooltip:AddLine(e and ns.ColorName(e) or (n and NameColor(n.class, ns.FullName(n.name, n.realm))) or "?")
		if n then
			local bits = {}
			if n.level and n.level > 0 then bits[#bits + 1] = "Level " .. n.level end
			if n.race then bits[#bits + 1] = n.race end
			if #bits > 0 then GameTooltip:AddLine(table.concat(bits, " "), 1, 1, 1) end
			if n.guild then GameTooltip:AddLine("<" .. n.guild .. ">", 0.7, 0.7, 0.7) end
		end
		local g = not e and n and ns.GetGuild(n.guild)
		if e then
			GameTooltip:AddLine("Kill on sight" .. (e.w and (": " .. e.w) or ""), 1, 0.2, 0.2, true)
			GameTooltip:AddLine("Added by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a), 0.6, 0.6, 0.6)
		elseif g then
			GameTooltip:AddLine("Kill on sight: the whole guild" .. (g.w and (": " .. g.w) or ""), 1, 0.2, 0.2, true)
			GameTooltip:AddLine("Guild added by " .. ns.SenderName(g.b) .. ", " .. ns.Ago(g.a), 0.6, 0.6, 0.6)
		end
		ns.AddStatsLines(GameTooltip, self.key)
		GameTooltip:AddLine("Left-click: target   Right-click: kill list", 0.5, 0.8, 1)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:Hide()
	rows[i] = row
end

local function EnsureRows()
	if #rows == NEARBY_ROWS then return true end
	if InCombatLockdown() then return false end
	for i = #rows + 1, NEARBY_ROWS do MakeRow(i) end
	return true
end

local function FillRowText(row, item)
	local n, e = item.n, item.e
	local listed = e or item.g
	local level = (n.level and n.level > 0) and (" |cffaaaaaa" .. n.level .. "|r") or ""
	row.name:SetText(NameColor(n.class, ns.FullName(n.name, n.realm)) .. level)
	local age = math.floor(GetTime() - n.seen)
	local rec = ns.Enemy(item.key)
	local score = (rec and ((rec.w or 0) + (rec.l or 0)) > 0) and ("|cff40ff40" .. rec.w .. "|r-|cffff4040" .. rec.l .. "|r ") or ""
	row.right:SetText(score .. (listed and "|cffff3030KOS|r" or (age < 5 and "now" or (age .. "s"))))
	row.bg:SetShown(listed ~= nil)
end

local HIDE_IN = { party = true, raid = true, scenario = true }
function ns.InDungeon()
	if not IsInInstance then return false end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and ns.Plain(inside) and HIDE_IN[ns.Plain(kind)] == true or false
end

local function NearbyWanted()
	return ns.Setting("nearby") and not (ns.Setting("hideInDungeons") and ns.InDungeon())
end

local layoutPending = false

local function LayoutNearby()
	local list = ns.NearbyList()
	if InCombatLockdown() or not EnsureRows() then

		layoutPending = true
		local byKey, extra = {}, 0
		for _, item in ipairs(list) do byKey[item.key] = item end
		local shownKeys = {}
		for _, row in ipairs(rows) do
			if row.key then
				shownKeys[row.key] = true
				local item = byKey[row.key]
				if item then FillRowText(row, item) else row.right:SetText("gone") end
			end
		end
		for _, item in ipairs(list) do
			if not shownKeys[item.key] then extra = extra + 1 end
		end
		nearby.footer:SetText(extra > 0 and ("+" .. extra .. " more after combat") or "")
		return
	end
	layoutPending = false
	local count = math.min(#list, NEARBY_ROWS)
	for i, row in ipairs(rows) do
		local item = list[i]
		if item and i <= count then
			row.key = item.key
			row.info = { name = item.n.name, realm = item.n.realm, class = item.n.class, guild = item.n.guild, level = item.n.level }
			row:SetAttribute("macrotext", "/targetexact " .. ns.TargetName({ n = item.n.name, r = item.n.realm }))
			FillRowText(row, item)
			row:Show()
		else
			row.key, row.info = nil, nil
			row:SetAttribute("macrotext", nil)
			row:Hide()
		end
	end
	local more = #list - count
	nearby.footer:SetText(more > 0 and ("+" .. more .. " more") or (#list == 0 and "No enemies nearby" or ""))
	nearby:SetHeight(20 + count * ROW_H + 16)
	nearby.title:SetText("Horde Scum Nearby" .. (#list > 0 and (" (" .. #list .. ")") or ""))
	local want = NearbyWanted()
	if want and not nearby:IsShown() then nearby:Show() elseif not want and nearby:IsShown() then nearby:Hide() end
end

ns.Listen("TICK", LayoutNearby)
ns.Listen("LIST_CHANGED", function() if nearby:IsShown() then LayoutNearby() end end)
ns.Listen("SETTINGS_CHANGED", function() LayoutNearby() end)
ns.On("PLAYER_REGEN_ENABLED", function() if layoutPending then LayoutNearby() end end)

ns.On("PLAYER_ENTERING_WORLD", function() LayoutNearby() end)

function ns.ToggleNearby()
	if InCombatLockdown() then
		ns.Print("the nearby window can't be shown or hidden in combat.")
		return
	end
	ns.SetSetting("nearby", not ns.Setting("nearby"))
	ns.Print("nearby window " .. (ns.Setting("nearby") and "on." or "off.")
		.. ((ns.Setting("nearby") and not NearbyWanted()) and " It comes back when you leave this dungeon (or turn off \"Hide the nearby window in dungeons and raids\" in /kos options)." or ""))
end

local LIST_ROWS = 10
local LROW_H = 36
local WIN_W, WIN_H = 640, 20 + 34 + LIST_ROWS * LROW_H + 40

local win = CreateFrame("Frame", ns.FRAME_PREFIX .. "Window", UIParent, BACKDROP_TEMPLATE)
win:SetSize(WIN_W, WIN_H)
win:SetFrameStrata("DIALOG")
win:SetClampedToScreen(true)
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self, "window") end)
Backdrop(win, 0.94)
win:Hide()
tinsert(UISpecialFrames, ns.FRAME_PREFIX .. "Window")

win.title = Text(win, "GameFontNormal")
win.title:SetPoint("TOPLEFT", 10, -8)

local mode = "kos"

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local search = CreateFrame("EditBox", ns.FRAME_PREFIX .. "Search", win, "InputBoxTemplate")
search:SetSize(118, 20)
search:SetPoint("TOPLEFT", 16, -30)
search:SetAutoFocus(false)
search.hint = Text(search, "GameFontDisableSmall")
search.hint:SetPoint("LEFT", 2, 0)
search.hint:SetText("Search")

local function Button(label, width, onClick)
	local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local addTarget = Button("Add target", 90, function()
	local info = ns.TargetInfo()
	if mode == "black" then
		if not info then ns.Print("target a player first.") return end
		ns.AskBlackReason(info)
		return
	end
	if not info then ns.Print("target an enemy player first.") return end
	if ns.GetByName(info.name, info.realm) then ns.AskEditReason(ns.Key(info.name, info.realm)) return end
	ns.AskReason(info)
end)
addTarget:SetPoint("LEFT", search, "RIGHT", 10, 0)
local addName = Button("Add by name", 96, function()
	if mode == "black" then ns.AskBlackName() else ns.AskAddName() end
end)
addName:SetPoint("LEFT", addTarget, "RIGHT", 4, 0)
local addGuild = Button("Add guild", 84, function() ns.AskAddGuild() end)
addGuild:SetPoint("LEFT", addName, "RIGHT", 4, 0)
addGuild:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Add a whole guild")
	GameTooltip:AddLine("Every member of the guild you come across counts as kill on sight. Target one of them first and their guild is filled in for you.", 1, 1, 1, true)
	GameTooltip:Show()
end)
addGuild:SetScript("OnLeave", function() GameTooltip:Hide() end)
local optionsBtn = Button("Options", 76, function() ns.ToggleOptions() end)
optionsBtn:SetPoint("LEFT", addGuild, "RIGHT", 4, 0)

local RefreshList
local tabSeen = Button("Recently Seen", 110, function() ns.ShowPage("seen") end)
tabSeen:SetPoint("TOPRIGHT", -28, -5)
local tabBlack = Button("Blacklist", 80, function() ns.ShowPage("black") end)
tabBlack:SetPoint("RIGHT", tabSeen, "LEFT", -4, 0)
tabBlack:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("Guild Blacklist")
	GameTooltip:AddLine("Players on our side to keep out of your groups, shared with the guild. You're warned when one is in your group, invites you or talks in chat.", 1, 1, 1, true)
	GameTooltip:Show()
end)
tabBlack:SetScript("OnLeave", function() GameTooltip:Hide() end)
local tabKos = Button("Kill List", 80, function() ns.ShowPage("kos") end)
tabKos:SetPoint("RIGHT", tabBlack, "LEFT", -4, 0)

local listArea = CreateFrame("Frame", nil, win)
listArea:SetPoint("TOPLEFT", 6, -56)
listArea:SetPoint("BOTTOMRIGHT", -6, 34)

local status = Text(win, "GameFontDisableSmall")
status:SetPoint("BOTTOMLEFT", 10, 12)
status:SetWidth(WIN_W - 120)

local syncBtn = Button("Sync now", 90, function()
	if ns.SyncNow() then
		ns.Print("asked the guild to compare lists. Anything missing on either side is sent over in the next few seconds.")
	else
		ns.Print("you need to be in a guild to sync.")
	end
end)
syncBtn:SetPoint("BOTTOMRIGHT", -8, 8)

local offset = 0
local filtered = {}
local lrows = {}

local function Matches(fields, q)
	if q == "" then return true end
	for _, f in ipairs(fields) do
		if type(f) == "string" and f:lower():find(q, 1, true) then return true end
	end
	return false
end

for i = 1, LIST_ROWS do
	local row = CreateFrame("Button", nil, listArea)
	row:SetHeight(LROW_H)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * LROW_H)
	row:SetPoint("TOPRIGHT", 0, -(i - 1) * LROW_H)
	local stripe = row:CreateTexture(nil, "BACKGROUND")
	stripe:SetAllPoints()
	stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	row.name = Text(row, "GameFontHighlight")
	row.name:SetPoint("TOPLEFT", 6, -4)
	row.name:SetWidth(250)
	row.why = Text(row, "GameFontHighlightSmall")
	row.why:SetPoint("TOPLEFT", 6, -20)
	row.why:SetWidth(250)
	row.why:SetTextColor(1, 0.75, 0.75)
	row.by = Text(row, "GameFontDisableSmall", "RIGHT")
	row.by:SetPoint("TOPRIGHT", -112, -5)
	row.by:SetWidth(140)
	row.seen = Text(row, "GameFontDisableSmall", "RIGHT")
	row.seen:SetPoint("TOPRIGHT", -112, -21)
	row.seen:SetWidth(140)
	row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.edit:SetSize(50, 20)
	row.edit:SetPoint("RIGHT", -56, 0)
	row.edit:SetText("Edit")
	row.edit:SetScript("OnClick", function()
		if row.guild then ns.AskGuildReason(row.guild) return end
		if not row.key then return end
		if row.black then ns.AskBlackEdit(row.key) return end
		if ns.Get(row.key) then ns.AskEditReason(row.key) return end
		local rec = ns.Enemy(row.key)
		if rec then ns.AskReason({ name = rec.n, realm = rec.r, class = rec.c, guild = rec.g, level = rec.lv }) end
	end)
	row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.remove:SetSize(52, 20)
	row.remove:SetPoint("RIGHT", -2, 0)
	row.remove:SetText("Remove")
	row.remove:SetScript("OnClick", function()
		if row.guild then
			ns.AskRemoveGuild(row.guild)
		elseif row.black then
			ns.AskBlackRemove(row.key)
		elseif row.key then
			ns.AskRemove(row.key)
		end
	end)
	row:SetScript("OnEnter", function(self)
		if self.guild then
			local g = ns.GetGuild(self.guild)
			if not g then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine("|cffffd200<" .. g.n .. ">|r  whole guild")
			GameTooltip:AddLine(g.w or "No reason given", 1, 0.75, 0.75, true)
			GameTooltip:AddLine("Added by " .. ns.SenderName(g.b) .. ", " .. ns.Ago(g.a), 0.6, 0.6, 0.6)
			GameTooltip:AddLine("Every member you come across counts as kill on sight. The game doesn't tell addons who is in a guild, so a member is only recognised once you see them.", 1, 1, 1, true)
			GameTooltip:Show()
			return
		end
		if not self.key then return end
		if self.black then
			local b = ns.GetBlack(self.key)
			if not b then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(ns.ColorName(b) .. "  |cffff9900guild Blacklist|r")
			if b.g then GameTooltip:AddLine("<" .. b.g .. ">", 0.7, 0.7, 0.7) end
			GameTooltip:AddLine(b.w or "No reason given", 1, 0.8, 0.5, true)
			GameTooltip:AddLine("Added by " .. ns.SenderName(b.b) .. ", " .. ns.Ago(b.a), 0.6, 0.6, 0.6)
			if b.gs then GameTooltip:AddLine("Last in your group " .. ns.Ago(b.gs), 0.6, 0.6, 0.6) end
			GameTooltip:AddLine("You're warned when they're in your group, invite you or talk in chat.", 1, 1, 1, true)
			GameTooltip:Show()
			return
		end
		local e = ns.Get(self.key)
		if mode == "seen" then
			local rec = ns.Enemy(self.key)
			if not rec then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(ns.ColorName({ n = rec.n, r = rec.r, c = rec.c }))
			if rec.g then GameTooltip:AddLine("<" .. rec.g .. ">", 0.7, 0.7, 0.7) end
			if rec.lv or rec.race then GameTooltip:AddLine(((rec.lv and rec.lv > 0 and ("Level " .. rec.lv .. " ")) or "") .. (rec.race or ""), 1, 1, 1) end
			ns.AddStatsLines(GameTooltip, self.key)
			GameTooltip:AddLine("Last seen " .. ns.Ago(rec.last) .. (rec.zone and rec.zone ~= "" and (" in " .. rec.zone) or ""), 0.6, 0.6, 0.6, true)
			if rec.lastWin then GameTooltip:AddLine("Last killed them " .. ns.Ago(rec.lastWin), 0.4, 1, 0.4) end
			if rec.lastLoss then GameTooltip:AddLine("Last killed by them " .. ns.Ago(rec.lastLoss), 1, 0.4, 0.4) end
			if e then GameTooltip:AddLine("On the kill list" .. (e.w and (": " .. e.w) or ""), 1, 0.2, 0.2, true) end
			GameTooltip:Show()
			return
		end
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.ColorName(e))
		if e.g then GameTooltip:AddLine("<" .. e.g .. ">", 0.7, 0.7, 0.7) end
		if e.lv or e.race then GameTooltip:AddLine(((e.lv and ("Level " .. e.lv .. " ")) or "") .. (e.race or ""), 1, 1, 1) end
		GameTooltip:AddLine(e.w or "No reason given", 1, 0.75, 0.75, true)
		GameTooltip:AddLine("Added by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a), 0.6, 0.6, 0.6)
		if e.seen then
			GameTooltip:AddLine("Last seen " .. ns.Ago(e.seen) .. (e.sz and e.sz ~= "" and (" in " .. e.sz) or "") .. (e.sb and (" by " .. e.sb) or ""), 0.6, 0.6, 0.6, true)
		end
		ns.AddStatsLines(GameTooltip, self.key)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	lrows[i] = row
end

listArea:EnableMouseWheel(true)
listArea:SetScript("OnMouseWheel", function(_, delta)
	local maxOffset = math.max(0, #filtered - LIST_ROWS)
	offset = math.max(0, math.min(maxOffset, offset - delta * 3))
	RefreshList()
end)

local emptyText = Text(listArea, "GameFontDisable", "CENTER")
emptyText:SetPoint("CENTER")
emptyText:SetWidth(400)
emptyText:SetWordWrap(true)

local function MembersSeen(g)
	local key, n = g.n:lower(), 0
	for _, rec in pairs(ns.Enemies()) do
		if rec.g and rec.g:lower() == key then n = n + 1 end
	end
	return n
end

local function FillGuildRow(row, g)
	row.key, row.guild, row.black = nil, g.n, nil
	row.name:SetText("|cffffd200<" .. g.n .. ">|r  |cffaaaaaawhole guild|r")
	row.why:SetText(g.w or "|cff777777No reason given|r")
	row.why:SetTextColor(1, 0.75, 0.75)
	row.by:SetText("by " .. ns.SenderName(g.b) .. ", " .. ns.Ago(g.a))
	local seen = MembersSeen(g)
	row.seen:SetText(seen > 0 and (seen .. " member" .. (seen == 1 and "" or "s") .. " seen") or "no members seen yet")
	row.edit:SetText("Edit")
	row.edit:Show()
	row.remove:Show()
end

local function FillKosRow(row, e)
	if e.isGuildRow then FillGuildRow(row, e.g) return end
	row.guild, row.black = nil, nil
	row.key = ns.Key(e.n, e.r)
	local level = e.lv and e.lv > 0 and ("  |cffaaaaaa" .. e.lv .. "|r") or ""
	local guild = e.g and ("  |cff888888<" .. e.g .. ">|r") or ""
	row.name:SetText(ns.ColorName(e) .. level .. guild)
	row.why:SetText(e.w or "|cff777777No reason given|r")
	row.why:SetTextColor(1, 0.75, 0.75)
	local rec = ns.Enemy(row.key)
	local score = (rec and ((rec.w or 0) + (rec.l or 0)) > 0) and (ns.Score(rec) .. "  ") or ""
	row.by:SetText(score .. "by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a))
	row.seen:SetText(e.seen and ("seen " .. ns.Ago(e.seen)) or "not seen yet")
	row.edit:SetText("Edit")
	row.edit:Show()
	row.remove:Show()
end

local function FillSeenRow(row, item)
	local rec = item.rec
	row.key, row.guild, row.black = item.key, nil, nil
	local level = rec.lv and rec.lv > 0 and ("  |cffaaaaaa" .. rec.lv .. "|r") or ""
	local guild = rec.g and ("  |cff888888<" .. rec.g .. ">|r") or ""
	row.name:SetText(ns.ColorName({ n = rec.n, r = rec.r, c = rec.c }) .. level .. guild)
	local times = rec.times or 1
	row.why:SetText((rec.zone and rec.zone ~= "" and rec.zone or "Somewhere") .. "  |cff888888(seen " .. times .. " time" .. (times == 1 and "" or "s") .. ")|r")
	row.why:SetTextColor(0.85, 0.85, 0.85)
	row.by:SetText(ns.Score(rec))
	row.seen:SetText("seen " .. ns.Ago(rec.last))
	local listed = ns.Get(item.key) ~= nil
	row.edit:SetText(listed and "Edit" or "KoS")
	row.edit:Show()
	row.remove:SetShown(listed)
end

local function FillBlackRow(row, e)
	row.key, row.guild, row.black = ns.Key(e.n, e.r), nil, true
	local guild = e.g and ("  |cff888888<" .. e.g .. ">|r") or ""
	row.name:SetText(ns.ColorName(e) .. guild)
	row.why:SetText(e.w or "|cff777777No reason given|r")
	row.why:SetTextColor(1, 0.8, 0.5)
	row.by:SetText("by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a))
	row.seen:SetText(e.gs and ("in your group " .. ns.Ago(e.gs)) or "")
	row.edit:SetText("Edit")
	row.edit:Show()
	row.remove:Show()
end

local function VersionTag()
	local v = ns.VERSION
	if type(v) ~= "string" or v == "" or v == "?" then return "" end
	return "  |cff666666v" .. v .. "|r"
end

RefreshList = function()
	if not win:IsShown() or not ns.db then return end
	local q = (search:GetText() or ""):lower()
	search.hint:SetShown(q == "" and not search:HasFocus())
	filtered = {}
	if mode == "seen" then
		for _, item in ipairs(ns.EnemyList()) do
			local r = item.rec
			if Matches({ ns.DisplayName(r), r.g, r.c, r.race, r.zone }, q) then filtered[#filtered + 1] = item end
		end
	elseif mode == "black" then
		for _, e in ipairs(ns.BlackList()) do
			if Matches({ ns.DisplayName(e), e.g, e.w, e.b, e.c }, q) then filtered[#filtered + 1] = e end
		end
	else
		for _, g in ipairs(ns.GuildList()) do
			if Matches({ g.n, g.w, g.b }, q) then filtered[#filtered + 1] = { isGuildRow = true, g = g } end
		end
		for _, e in ipairs(ns.List()) do
			if Matches({ ns.DisplayName(e), e.g, e.w, e.b, e.c }, q) then filtered[#filtered + 1] = e end
		end
	end
	offset = math.max(0, math.min(offset, math.max(0, #filtered - LIST_ROWS)))
	for i, row in ipairs(lrows) do
		local item = filtered[offset + i]
		if item then
			if mode == "seen" then
				FillSeenRow(row, item)
			elseif mode == "black" then
				FillBlackRow(row, item)
			else
				FillKosRow(row, item)
			end
			row:Show()
		else
			row.key, row.guild, row.black = nil, nil, nil
			row:Hide()
		end
	end
	tabKos:SetEnabled(mode ~= "kos")
	tabSeen:SetEnabled(mode ~= "seen")
	tabBlack:SetEnabled(mode ~= "black")
	addGuild:SetShown(mode ~= "black")
	local total
	if mode == "black" then
		total = ns.BlackCount()
		win.title:SetText("|cffff9900Guild Blacklist|r  |cffaaaaaa" .. total .. " player" .. (total == 1 and "" or "s") .. "|r" .. VersionTag())
	elseif mode == "seen" then
		local w, l, n = ns.Totals()
		total = n
		win.title:SetText("|cffe03c3cRecently Seen|r  |cffaaaaaa" .. n .. " enemies|r  " .. ns.Score({ w = w, l = l }) .. VersionTag())
	else
		local guilds = ns.GuildCount()
		total = ns.Count() + guilds
		win.title:SetText("|cffe03c3cBH&G Kill List|r  |cffaaaaaa" .. ns.Count() .. " player" .. (ns.Count() == 1 and "" or "s")
			.. (guilds > 0 and (", " .. guilds .. " guild" .. (guilds == 1 and "" or "s")) or "") .. "|r" .. VersionTag())
	end
	if total == 0 then
		emptyText:SetText(mode == "seen" and "No enemy players seen yet. Everyone you come across is kept here, with your wins and losses against them."
			or mode == "black" and "Nobody on the guild Blacklist yet.\nIt's for players on our side to keep out of groups. Right-click a player or their name in chat, or target them and click Add target. When someone leaves your dungeon group you're asked too."
			or "Nobody on the list yet.\nTarget an enemy and click Add target, or right-click a player's name.\nAdd guild puts a whole guild on the list.")
	elseif #filtered == 0 then
		emptyText:SetText("No one matches \"" .. q .. "\".")
	else
		emptyText:SetText("")
	end
	local first, last = math.min(#filtered, offset + 1), math.min(#filtered, offset + LIST_ROWS)
	local range = (#filtered > LIST_ROWS) and (first .. "-" .. last .. " of " .. #filtered .. ", scroll for more.  ") or ""
	if mode == "seen" then
		status:SetText(range .. "Kept on this PC. Wins and losses are worked out from what the game shows addons.")
		return
	end
	if mode == "black" then
		status:SetText(range .. (IsInGuild() and "Shared with the guild. You're warned when one of them is in your group, invites you or talks in chat." or "Not in a guild: nothing is shared"))
		return
	end
	local peers = 0
	for _, t in pairs(ns.sync.peers) do if GetTime() - t < 3600 then peers = peers + 1 end end
	status:SetText(range .. (IsInGuild() and ("Shared with the guild" .. (peers > 0 and (" (" .. peers .. " heard from)") or "")) or "Not in a guild: nothing is shared"))
end

function ns.ShowPage(page)
	mode = page
	offset = 0
	if ns.CloseOptions then ns.CloseOptions() end
	if not win:IsShown() then win:Show() else RefreshList() end
end

search:SetScript("OnTextChanged", function() offset = 0 RefreshList() end)
search:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
search:SetScript("OnEditFocusLost", function() RefreshList() end)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
win:SetScript("OnShow", function() RefreshList() end)

ns.Listen("LIST_CHANGED", function() RefreshList() end)
ns.Listen("SEEN", function() RefreshList() end)
ns.Listen("STATS_CHANGED", function() RefreshList() end)
local lastSeenRefresh = 0
ns.Listen("TICK", function()

	if mode == "seen" and GetTime() - lastSeenRefresh > 2 then
		lastSeenRefresh = GetTime()
		RefreshList()
	end
end)

local opts = CreateFrame("Frame", nil, win)
opts:SetPoint("TOPLEFT", listArea, "TOPLEFT")
opts:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT")
opts:Hide()

local OPTIONS = {
	{ "banner", "Show a big warning when a listed player shows up" },
	{ "sound", "Play the warning sounds (kill list, adding and removing)" },
	{ "nearbySound", "Play a sound for every new enemy player nearby" },
	{ "chat", "Write the warning in chat" },
	{ "shareSightings", "Tell the guild when I spot a listed player" },
	{ "guildSightings", "Show the guild's sightings in my chat" },
	{ "nearby", "Show the nearby enemies window" },
	{ "hideInDungeons", "Hide the nearby window in dungeons and raids" },
	{ "nearbyAll", "List every enemy player nearby, not only listed ones" },
	{ "farPlates", "Show nameplates as far away as the game allows (spots enemies sooner)" },
	{ "blackWarn", "Warn me when someone on the guild Blacklist is in my group or invites me" },
	{ "blackChat", "Point out guild Blacklist players who whisper me or talk in chat channels" },
	{ "leavePrompt", "Offer to blacklist someone who leaves my dungeon group" },
}
local OPTION_H = 22

local checks = {}
for i, o in ipairs(OPTIONS) do
	local cb = CreateFrame("CheckButton", nil, opts)
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", 14, -8 - (i - 1) * OPTION_H)
	cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	cb.label = Text(opts, "GameFontHighlight")
	cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb.label:SetText(o[2])
	cb:SetScript("OnClick", function(self)
		if o[1] == "nearby" and InCombatLockdown() then
			self:SetChecked(ns.Setting("nearby"))
			ns.Print("the nearby window can't be shown or hidden in combat.")
			return
		end
		ns.SetSetting(o[1], self:GetChecked() and true or false)
	end)
	cb.key = o[1]
	checks[#checks + 1] = cb
end

local testBtn = CreateFrame("Button", nil, opts, "UIPanelButtonTemplate")
testBtn:SetSize(120, 22)
testBtn:SetPoint("TOPLEFT", 16, -8 - #OPTIONS * OPTION_H - 8)
testBtn:SetText("Test warning")
testBtn:SetScript("OnClick", function() ns.TestAlert() end)

local moveBtn = CreateFrame("Button", nil, opts, "UIPanelButtonTemplate")
moveBtn:SetSize(120, 22)
moveBtn:SetPoint("LEFT", testBtn, "RIGHT", 6, 0)
moveBtn:SetText("Move warning")
moveBtn:SetScript("OnClick", function() ns.ToggleBannerMove() end)

local platesBtn = CreateFrame("Button", nil, opts, "UIPanelButtonTemplate")
platesBtn:SetSize(170, 22)
platesBtn:SetPoint("LEFT", moveBtn, "RIGHT", 6, 0)
platesBtn:SetText("Turn on enemy nameplates")
platesBtn:SetScript("OnClick", function() ns.TurnOnEnemyPlates() end)
platesBtn:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Enemy nameplates")
	GameTooltip:AddLine("With enemy nameplates on, enemies are spotted the moment they come into range. With them off, only when you target or mouse over them.", 1, 1, 1, true)
	GameTooltip:Show()
end)
platesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local optsNote = Text(opts, "GameFontDisableSmall")
optsNote:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -10)
optsNote:SetWidth(WIN_W - 60)
optsNote:SetWordWrap(true)
optsNote:SetText("Drag the nearby window by its edge to move it. The kill list and the Blacklist are shared with every guild member who has the addon; anyone offline catches up when they log in.")

function ns.ToggleOptions()
	local show = not opts:IsShown()
	opts:SetShown(show)
	listArea:SetShown(not show)
	optionsBtn:SetText(show and "List" or "Options")
	for _, cb in ipairs(checks) do cb:SetChecked(ns.Setting(cb.key)) end
	platesBtn:SetEnabled(ns.EnemyPlatesOn() ~= true)
	if not win:IsShown() then win:Show() end
end

function ns.CloseOptions()
	if opts:IsShown() then ns.ToggleOptions() end
end

function ns.ToggleWindow(showOptions)
	if win:IsShown() and not showOptions then
		win:Hide()
		return
	end
	win:Show()
	if showOptions and not opts:IsShown() then ns.ToggleOptions() end
end

function ns.TestAlert()
	ns.Alert({ n = "Testplayer", r = ns.MyRealm(), c = "ROGUE", w = "This is what a warning looks like", b = ns.MyFullName(), g = "Some Horde Guild", lv = 60 }, { level = 60 }, true)
end

ns.Listen("DB_READY", function()
	RestorePos(banner, "banner", "TOP", UIParent, "TOP", 0, -140)
	RestorePos(nearby, "nearby", "TOPLEFT", UIParent, "LEFT", 20, 230)
	RestorePos(win, "window", "CENTER", UIParent, "CENTER", 0, 40)
	if not InCombatLockdown() then LayoutNearby() end
end)
end

do

local HELP = {
	"/kos - open the kill list",
	"/kos add - add your target (asks for a reason)",
	"/kos add <name> [reason] - add someone by name (Name, or Name-Realm for someone from elsewhere)",
	"/kos remove <name> - take someone off the list (for everyone)",
	"/kos reason <name> <reason> - change someone's reason",
	"/kos check <name> - is this player (or guild) on the list?",
	"/kos guild - put your target's whole guild on the list (asks for a reason)",
	"/kos guild add <guild>[: reason] - put a whole guild on the list by name",
	"/kos guild remove <guild> - take a guild off the list (for everyone)",
	"/kos guild reason <guild>: <reason> - change a guild's reason",
	"/kos guilds - list the guilds on the kill list",
	"/kos black - put your target on the guild Blacklist (players on our side to keep out of groups)",
	"/kos black <name> [reason] - put someone on the guild Blacklist by name",
	"/kos black remove <name> - take someone off the guild Blacklist (for everyone)",
	"/kos black reason <name> <reason> - change someone's Blacklist reason",
	"/kos blacklist - open the guild Blacklist (/kos black list writes it in chat)",
	"/kos seen - everyone you've come across, with your wins and losses",
	"/kos nearby - show or hide the nearby enemies window",
	"/kos plates - turn on enemy nameplates (spots enemies as soon as they're in range)",
	"/kos options - open the options",
	"/kos sync - compare lists with the guild now",
	"/kos test - show a test warning",
	"/kos move - move the warning",
	"/kos status - what the addon can see (for bug reports)",
	"/kos clicks - write clicks on the nearby window to chat (for bug reports)",
	"/kos on | off - turn K-UI's kill list on or off (K-UI only)",
}

local function SwitchKUI(on)
	local kui = _G.KainUIForeverKoS
	if kui and kui.SetEnabled then
		kui.SetEnabled(on)
	else
		ns.Print("/kos on and /kos off switch K-UI's kill list; K-UI isn't loaded.")
	end
end

local function Status()
	local say = ns.Print
	say((ns.embedded and "K-UI's kill list" or "standalone addon") .. " version " .. ns.VERSION
		.. (_G.BHGKillListStandalone and ns.embedded and " (the standalone addon is installed and asleep)" or "") .. ", " .. ns.Count() .. " players and " .. ns.GuildCount() .. " whole guilds on the list (" .. (function()
		local n = 0
		for _, e in pairs(ns.db.entries) do if e.x then n = n + 1 end end
		return n
	end)() .. " removed ones remembered so removals spread), " .. ns.BlackCount() .. " on the guild Blacklist.")
	say("saved data present at login: " .. (ns.loadedWithData and "yes" or "no (first run, or the client didn't load it; the guild sync fills it back in)"))
	local s = ns.sync
	local peers = 0
	for _, t in pairs(s.peers) do if GetTime() - t < 3600 then peers = peers + 1 end end
	say(string.format("sync: %s | guild %s | sent %d, failed %d, received %d, merged %d | %d queued | %d guildmates heard from in the last hour | last hello %s",
		ns.CommRestricted() and "the game is holding messages right now" or "ok",
		IsInGuild() and "yes" or "NO", s.sent, s.failed or 0, s.received, s.merged, ns.QueueLength(), peers,
		s.lastHello and (math.floor(GetTime() - s.lastHello) .. "s ago") or "not yet"))
	say("last send: " .. (s.lastResult or "none yet") .. " | client checks: " .. ns.CommChecks())
	local digests = {}
	for i, h in ipairs(ns.BucketHashes()) do digests[i] = ns.ToB36(h) end
	local black = {}
	for i, h in ipairs(ns.BlackHashes()) do black[i] = ns.ToB36(h) end
	say("list fingerprint: " .. ns.ToB36(ns.Hash(table.concat(digests, ","))) .. ", guilds " .. ns.ToB36(ns.GuildDigest())
		.. ", Blacklist " .. ns.ToB36(ns.Hash(table.concat(black, ","))) .. " (the same on every guild member's PC once they're in sync)")
	local w, l, seenCount = ns.Totals()
	say("seen " .. seenCount .. " enemy players, record " .. ns.Score({ w = w, l = l }) .. ".")
	local plates = ns.EnemyPlatesOn()
	local range = ns.PlateRange()
	say(string.format("detection: nameplates %s (enemy nameplates %s, range %s), tooltips %s, menus %s, combat log %s",
		(C_NamePlate and C_NamePlate.GetNamePlates) and "yes" or "no",
		plates == true and "on" or (plates == false and "OFF: /kos plates" or "?"),
		range and (range .. " yards") or "?",
		(TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) and "yes" or "old style",
		(Menu and Menu.ModifyMenu) and "yes" or "no",
		CombatLogGetCurrentEventInfo and "yes" or "no (restricted on Forever)"))
	say("nearby window: " .. (not ns.Setting("nearby") and "off" or ((ns.Setting("hideInDungeons") and ns.InDungeon()) and "hidden in this dungeon" or "on")) .. ".")
	local any = false
	for label, n in pairs(ns.errorCounts) do
		any = true
		say("  caught errors in '" .. label .. "': " .. n)
	end
	if not any then say("no errors caught so far.") end
end

local function ListGuilds()
	local list = ns.GuildList()
	if #list == 0 then
		ns.Print("no guilds on the list. /kos guild adds your target's guild.")
		return
	end
	ns.Print(#list .. " guild" .. (#list == 1 and "" or "s") .. " on the list:")
	for _, g in ipairs(list) do
		print("  |cffffd200<" .. g.n .. ">|r" .. (g.w and (" - " .. g.w) or "") .. " |cff999999(added by " .. ns.SenderName(g.b) .. ", " .. ns.Ago(g.a) .. ")|r")
	end
end

local function GuildCommand(rest)
	local sub, arg = rest:match("^(%S*)%s*(.-)$")
	sub = sub:lower()
	local name, reason = arg:match("^([^:]*):%s*(.-)%s*$")
	if not name then name = arg end
	if reason == "" then reason = nil end
	if sub == "" or (sub == "add" and name == "") then
		local guild, why = ns.TargetGuild()
		if not guild then ns.Print(why .. " Or type /kos guild add <guild name>.") return end
		ns.AskGuildReason(guild)
	elseif sub == "add" then
		ns.AddGuildWithMessage(name, reason)
	elseif sub == "remove" or sub == "rem" or sub == "del" then
		if not ns.GetGuild(name) then ns.Print("no guild called \"" .. name .. "\" is on the list.") return end
		ns.RemoveGuildWithMessage(name)
	elseif sub == "reason" then
		if not ns.GetGuild(name) then ns.Print("usage: /kos guild reason <guild>: <reason>") return end
		ns.SetGuildReason(name, reason)
		ns.Print("reason updated.")
	elseif sub == "list" then
		ListGuilds()
	else
		for _, line in ipairs(HELP) do
			if line:find("guild") then print("  " .. line) end
		end
	end
end

local function Find(arg, get)
	get = get or ns.Get
	local name, realm = ns.SplitName(arg)
	if not name then return nil end
	local key = ns.Key(name, realm)
	if get(key) then return key, name, realm end

	local found
	for k, e in pairs(get == ns.Get and ns.db.entries or ns.db.black) do
		if not e.x and e.n:lower() == name:lower() then
			if found then return nil, name, realm end
			found = k
		end
	end
	return found, name, realm
end

local function ListBlack()
	local list = ns.BlackList()
	if #list == 0 then
		ns.Print("nobody on the guild Blacklist. /kos black adds your target.")
		return
	end
	ns.Print(#list .. " player" .. (#list == 1 and "" or "s") .. " on the guild Blacklist:")
	for _, e in ipairs(list) do
		print("  " .. ns.ColorName(e) .. (e.w and (" - " .. e.w) or "") .. " |cff999999(added by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a) .. ")|r")
	end
end

local function BlackCommand(rest)
	local sub, arg = rest:match("^(%S*)%s*(.-)$")
	local lower = sub:lower()
	if sub == "" then
		local info = ns.TargetInfo()
		if not info then ns.Print("target a player first, or type /kos black <name> [reason].") return end
		ns.AskBlackReason(info)
	elseif lower == "remove" or lower == "rem" or lower == "del" then
		local key = Find(arg, ns.GetBlack)
		if not key then ns.Print("no one called \"" .. arg .. "\" is on the guild Blacklist.") return end
		ns.RemoveBlackWithMessage(key)
	elseif lower == "reason" then
		local who, reason = arg:match("^(%S+)%s*(.-)$")
		local key = who and Find(who, ns.GetBlack)
		if not key then ns.Print("usage: /kos black reason <name> <reason>") return end
		ns.SetBlackReason(key, reason)
		ns.Print("reason updated.")
	elseif lower == "list" then
		ListBlack()
	else
		local name, realm = ns.SplitName(sub)
		if not name then ns.Print("that isn't a player name.") return end
		ns.AddBlackWithMessage({ name = name, realm = realm }, arg ~= "" and arg or nil)
	end
end

local function Handler(msg)
	if not ns.db then return end
	msg = (msg or ""):match("^%s*(.-)%s*$")
	local cmd, rest = msg:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or ""

	if cmd == "on" or cmd == "off" then
		SwitchKUI(cmd == "on")
	elseif cmd == "" then
		ns.ToggleWindow()
	elseif cmd == "add" then
		if rest == "" then
			local info = ns.TargetInfo()
			if not info then ns.Print("target a player first, or type /kos add <name>.") return end
			ns.AskReason(info)
			return
		end
		local who, reason = rest:match("^(%S+)%s*(.-)$")
		local name, realm = ns.SplitName(who)
		if not name then ns.Print("that isn't a player name.") return end
		ns.AddWithMessage({ name = name, realm = realm }, reason ~= "" and reason or nil)
	elseif cmd == "remove" or cmd == "rem" or cmd == "del" then
		local key = Find(rest)
		if not key then ns.Print("no one called \"" .. rest .. "\" is on the list.") return end
		ns.RemoveWithMessage(key)
	elseif cmd == "reason" then
		local who, reason = rest:match("^(%S+)%s*(.-)$")
		local key = who and Find(who)
		if not key then ns.Print("usage: /kos reason <name> <reason>") return end
		ns.SetReason(key, reason)
		ns.Print("reason updated.")
	elseif cmd == "check" then
		local key, name = Find(rest)
		local e = key and ns.Get(key)
		local g = not e and ns.GetGuild(rest)
		local blackKey = Find(rest, ns.GetBlack)
		local b = blackKey and ns.GetBlack(blackKey)
		if e then
			ns.Print(ns.ColorName(e) .. " is on the list" .. (e.w and (": " .. e.w) or "") .. " (added by " .. ns.SenderName(e.b) .. ", " .. ns.Ago(e.a) .. ").")
		elseif g then
			ns.Print("the whole guild <" .. g.n .. "> is on the list" .. (g.w and (": " .. g.w) or "") .. " (added by " .. ns.SenderName(g.b) .. ", " .. ns.Ago(g.a) .. ").")
		end
		if b then
			ns.Print(ns.ColorName(b) .. " is on the guild Blacklist" .. (b.w and (": " .. b.w) or "") .. " (added by " .. ns.SenderName(b.b) .. ", " .. ns.Ago(b.a) .. ").")
		end
		if not e and not g and not b then
			ns.Print((name or rest) .. " isn't on the kill list or the Blacklist.")
		end
	elseif cmd == "guild" then
		GuildCommand(rest)
	elseif cmd == "guilds" then
		ListGuilds()
	elseif cmd == "black" or cmd == "bl" then
		BlackCommand(rest)
	elseif cmd == "blacklist" then
		if rest == "" then ns.ShowPage("black") else BlackCommand(rest) end
	elseif cmd == "seen" or cmd == "stats" then
		ns.ShowPage("seen")
	elseif cmd == "plates" then
		ns.TurnOnEnemyPlates()
	elseif cmd == "nearby" then
		ns.ToggleNearby()
	elseif cmd == "options" or cmd == "config" then
		ns.ToggleWindow(true)
	elseif cmd == "sync" then
		if ns.SyncNow() then
			ns.Print("asked the guild to compare lists.")
		else
			ns.Print("you need to be in a guild to sync.")
		end
	elseif cmd == "test" then
		ns.TestAlert()
	elseif cmd == "move" then
		ns.Print(ns.ToggleBannerMove() and "drag the warning where you want it, then type /kos move again." or "warning position saved.")
	elseif cmd == "status" or cmd == "probe" then
		Status()
	elseif cmd == "clicks" then
		ns.clickDebug = not ns.clickDebug
		ns.Print(ns.clickDebug and "clicks on the nearby window are now written to chat. Type /kos clicks again to stop." or "click details off.")
	else
		for _, line in ipairs(HELP) do print("  " .. line) end
	end
end

local function Register(fn)
	_G.SLASH_BHGKILLLIST1 = "/kos"
	_G.SLASH_BHGKILLLIST2 = "/bhgkos"
	SlashCmdList["BHGKILLLIST"] = fn
	if _G.hash_SlashCmdList then
		_G.hash_SlashCmdList["/KOS"] = nil
		_G.hash_SlashCmdList["/BHGKOS"] = nil
	end
end

ns.Listen("DB_READY", function() Register(Handler) end)

if ns.embedded then
	local probe = CreateFrame("Frame")
	probe:RegisterEvent("PLAYER_LOGIN")
	probe:SetScript("OnEvent", function()
		C_Timer.After(0, function()
			if not ns.disabled then return end
			local standalone = _G.BHGKillListStandalone
			if standalone and standalone.active then return end
			Register(function(msg)
				local cmd = (msg or ""):match("^%s*(%S*)"):lower()
				if cmd == "on" then
					ns.SetEnabled(true)
				else
					ns.Print("K-UI's kill list is off. Type /kos on and /reload to turn it on.")
				end
			end)
		end)
	end)
end
end
