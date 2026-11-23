local _, KUI = ...
local M = {}
KUI.Market = M

local HOUR, DAY = 3600, 86400
local MERGE_SECONDS = 60
local LEDGER_MAX = 5000
local SEP = "`"
M.SEP = SEP

local KINDS = { "mail", "crafter", "post" }
M.KINDS = KINDS
local KIND_LABEL = { mail = "Mailing", crafter = "Crafter", post = "Auctioning" }
M.KIND_LABEL = KIND_LABEL

M.PROFESSIONS = { "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First Aid", "Fishing",
	"Herbalism", "Inscription", "Jewelcrafting", "Leatherworking", "Mining", "Skinning", "Tailoring" }
local IS_PROFESSION = {}
for _, p in ipairs(M.PROFESSIONS) do IS_PROFESSION[p] = true end

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
M.Plain = Plain

function M.Say(msg)
	print("|cff33ff99K-Market:|r " .. msg)
end

function M.Now() return M.clock and M.clock() or time() end
local Now = M.Now

local OP_DEFAULTS = {
	mail = { to = "", keep = 0, maxQty = 0, restock = false },
	crafter = { profession = "", to = "", keep = 0, maxQty = 0, restock = false },

	post = { keep = 0, postCap = 5, duration = 2, undercut = 100, minPrice = 0, normalPrice = 0, maxPrice = 0,
		belowMin = "none", aboveMax = "maxPrice", cancelUndercut = true },
}
M.OP_DEFAULTS = OP_DEFAULTS
local BELOW_MIN = { none = true, minPrice = true, normalPrice = true, maxPrice = true }
local ABOVE_MAX = { none = true, minPrice = true, normalPrice = true, maxPrice = true }

local function Migrate(m)

	for name, g in pairs(m.groups) do
		if type(g) == "table" and type(g.items) == "table" then
			for id in pairs(g.items) do
				if type(id) == "number" and not m.items[id] then m.items[id] = name end
			end
			g.items = nil
		end
	end
	for _, op in pairs(m.ops) do
		if type(op) == "table" and OP_DEFAULTS[op.kind] then
			for k, v in pairs(OP_DEFAULTS[op.kind]) do
				if type(op[k]) ~= type(v) then op[k] = v end
			end
			if op.kind == "post" then
				if not BELOW_MIN[op.belowMin] then op.belowMin = "none" end
				if not ABOVE_MAX[op.aboveMax] then op.aboveMax = "maxPrice" end
			end
		end
	end
	m.version = 2
end

local function Sanitize(m)
	for _, k in ipairs({ "gold", "groups", "ops", "chars", "items", "inv", "ledger" }) do
		if type(m[k]) ~= "table" then m[k] = {} end
	end
	for key, c in pairs(m.gold) do
		if type(key) ~= "string" or type(c) ~= "table" or type(c.points) ~= "table" then
			m.gold[key] = nil
		else
			local good = {}
			for _, p in ipairs(c.points) do
				if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then good[#good + 1] = p end
			end
			c.points = good
		end
	end
	for path, g in pairs(m.groups) do
		if type(path) ~= "string" or path == "" or type(g) ~= "table" then
			m.groups[path] = nil
		elseif type(g.ops) ~= "table" then
			g.ops = {}
		end
	end
	for name, op in pairs(m.ops) do
		if type(name) ~= "string" or type(op) ~= "table" or not KIND_LABEL[op.kind] then m.ops[name] = nil end
	end
	Migrate(m)

	for path in pairs(m.groups) do
		local parent = path:match("^(.*)" .. SEP .. "[^" .. SEP .. "]*$")
		while parent do
			if not m.groups[parent] then m.groups[parent] = { ops = {} } end
			parent = parent:match("^(.*)" .. SEP .. "[^" .. SEP .. "]*$")
		end
	end
	for id, path in pairs(m.items) do
		if type(id) ~= "number" or type(path) ~= "string" or not m.groups[path] then m.items[id] = nil end
	end
	for key, c in pairs(m.chars) do
		if type(key) ~= "string" or type(c) ~= "table" then
			m.chars[key] = nil
		elseif type(c.professions) ~= "table" then
			c.professions = {}
		end
	end
	for key, inv in pairs(m.inv) do
		if type(key) ~= "string" or type(inv) ~= "table" then m.inv[key] = nil end
	end
	local good = {}
	for _, e in ipairs(m.ledger) do
		if type(e) == "table" and type(e.t) == "number" and (e.kind == "sale" or e.kind == "buy") and type(e.copper) == "number" then
			good[#good + 1] = e
		end
	end
	m.ledger = good
	m.checked = nil
end

local sanitized

function M:DB()
	local acct = _G.KainUIForeverAccountDB
	if type(acct) ~= "table" then acct = {}; _G.KainUIForeverAccountDB = acct end
	local m = acct.market
	if type(m) ~= "table" then m = {}; acct.market = m end
	if m ~= sanitized or type(m.inv) ~= "table" then Sanitize(m); sanitized = m end
	return m
end

function M:Me()
	local name, realm = Plain(UnitName("player")), Plain(GetRealmName())
	if type(name) ~= "string" or name == "" or type(realm) ~= "string" then return nil end
	return name .. "-" .. realm, name, realm
end

function M:Thin(points, now)
	local out = {}
	for i, p in ipairs(points) do
		local age = now - p[1]
		local bucket = (age > 60 * DAY and DAY) or (age > 7 * DAY and HOUR) or nil
		local nxt = points[i + 1]
		if not (bucket and nxt and math.floor(nxt[1] / bucket) == math.floor(p[1] / bucket)) then
			out[#out + 1] = p
		end
	end
	return out
end

function M:RecordMoney()
	local key = self:Me()
	if not key then return end
	local copper = Plain(GetMoney())
	if type(copper) ~= "number" then return end
	local now = Now()
	local db = self:DB()
	local c = db.gold[key]
	if not c then c = { points = {} }; db.gold[key] = c end
	local _, class = UnitClass("player")
	c.class = Plain(class) or c.class
	local pts = c.points
	local last = pts[#pts]
	if last and last[2] == copper then return end
	if last and now - last[1] < MERGE_SECONDS then
		last[1], last[2] = now, copper
		local before = pts[#pts - 1]
		if before and before[2] == copper then pts[#pts] = nil end
	else
		pts[#pts + 1] = { now, copper }
	end
	if self.RefreshWindow then self:RefreshWindow() end
end

function M:GoldCharacters()
	local list = {}
	for key in pairs(self:DB().gold) do list[#list + 1] = key end
	table.sort(list)
	return list
end

local function ValueAt(points, t)
	local lo, hi = 1, #points
	if hi == 0 or points[1][1] > t then return nil end
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if points[mid][1] <= t then lo = mid else hi = mid - 1 end
	end
	return points[lo][2]
end

function M:GoldAt(keys, t)
	local db = self:DB()
	local sum
	for _, key in ipairs(keys or self:GoldCharacters()) do
		local c = db.gold[key]
		local v = c and ValueAt(c.points, t)
		if v then sum = (sum or 0) + v end
	end
	return sum
end

function M:Series(keys, from, to, columns)
	local values, low, high = {}, nil, nil
	for i = 1, columns do
		local t = from + (to - from) * (i - 1) / math.max(columns - 1, 1)
		local sum = self:GoldAt(keys, t)
		values[i] = sum
		if sum then
			low = math.min(low or sum, sum)
			high = math.max(high or sum, sum)
		end
	end
	return values, low, high
end

function M:FirstGoldTime(keys)
	local db, first = self:DB(), nil
	for _, key in ipairs(keys or self:GoldCharacters()) do
		local c = db.gold[key]
		local p = c and c.points[1]
		if p and (not first or p[1] < first) then first = p[1] end
	end
	return first
end

function M.FormatMoney(copper, short)
	local neg = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local gold = (BreakUpLargeNumbers and BreakUpLargeNumbers(g)) or tostring(g)
	local text
	if short then
		text = gold .. "g"
	elseif g > 0 then
		text = string.format("%sg %ds %dc", gold, s, c)
	elseif s > 0 then
		text = string.format("%ds %dc", s, c)
	else
		text = c .. "c"
	end
	return (neg and "-" or "") .. text
end

function M.FormatAxisGold(copper)
	local g = copper / 10000
	if g < 1000 then return math.floor(g) .. "g" end
	if g < 10000 then return string.format("%.2fkg", g / 1000) end
	if g < 1000000 then return math.floor(g / 1000) .. "kg" end
	if g < 10000000 then return string.format("%.2fMg", g / 1000000) end
	return math.floor(g / 1000000) .. "Mg"
end

function M.ParseMoney(text)
	if type(text) ~= "string" then return nil end
	text = text:lower():gsub(",", "")
	if text:match("^%s*$") then return 0 end
	local plain = text:match("^%s*(%d+%.?%d*)%s*$")
	if plain then return math.floor(tonumber(plain) * 10000 + 0.5) end
	local total, any = 0, false
	for num, unit in text:gmatch("(%d+%.?%d*)%s*([gsc])") do
		total = total + tonumber(num) * ({ g = 10000, s = 100, c = 1 })[unit]
		any = true
	end
	local rest = text:gsub("%d+%.?%d*%s*[gsc]", ""):gsub("%s", "")
	if not any or rest ~= "" then return nil end
	return math.floor(total + 0.5)
end

function M:RecordLedger(kind, name, count, copper)
	if (kind ~= "sale" and kind ~= "buy") or type(copper) ~= "number" or copper <= 0 then return end
	local ledger = self:DB().ledger
	ledger[#ledger + 1] = { t = Now(), kind = kind, name = type(name) == "string" and name or "?", count = tonumber(count) or 1, copper = copper }
	while #ledger > LEDGER_MAX do table.remove(ledger, 1) end
end

function M:LedgerSummary(from, to)
	local sum = { sales = 0, buys = 0, soldCount = 0, boughtCount = 0, topSaleUnit = 0, topBuyUnit = 0 }
	local bySale, byBuy = {}, {}
	for _, e in ipairs(self:DB().ledger) do
		if (not from or e.t >= from) and (not to or e.t <= to) then
			local count = math.max(1, tonumber(e.count) or 1)
			local unit = e.copper / count
			if e.kind == "sale" then
				sum.sales = sum.sales + e.copper
				sum.soldCount = sum.soldCount + count
				sum.topSaleUnit = math.max(sum.topSaleUnit, unit)
				bySale[e.name] = (bySale[e.name] or 0) + e.copper
			else
				sum.buys = sum.buys + e.copper
				sum.boughtCount = sum.boughtCount + count
				sum.topBuyUnit = math.max(sum.topBuyUnit, unit)
				byBuy[e.name] = (byBuy[e.name] or 0) + e.copper
			end
		end
	end
	local function Top(t)
		local best, amount
		for name, v in pairs(t) do
			if not amount or v > amount or (v == amount and name < best) then best, amount = name, v end
		end
		return best, amount
	end
	sum.topSale, sum.topSaleAmount = Top(bySale)
	sum.topBuy, sum.topBuyAmount = Top(byBuy)
	sum.profit = sum.sales - sum.buys
	return sum
end

function M:LedgerDays(maxDays)
	local days, byDay = {}, {}
	local ledger = self:DB().ledger
	for i = #ledger, 1, -1 do
		local e = ledger[i]
		local t = date("*t", e.t)
		local day = time({ year = t.year, month = t.month, day = t.day, hour = 0 })
		local d = byDay[day]
		if not d then
			if #days >= (maxDays or 30) then break end
			d = { day = day, sold = 0, soldCount = 0, bought = 0, boughtCount = 0, lines = {} }
			byDay[day] = d
			days[#days + 1] = d
		end
		local count = math.max(1, tonumber(e.count) or 1)
		if e.kind == "sale" then
			d.sold, d.soldCount = d.sold + e.copper, d.soldCount + count
		else
			d.bought, d.boughtCount = d.bought + e.copper, d.boughtCount + count
		end
		if #d.lines < 6 then d.lines[#d.lines + 1] = { kind = e.kind, name = e.name, count = count, copper = e.copper } end
	end
	table.sort(days, function(a, b) return a.day > b.day end)
	return days
end

local function CleanName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub(SEP, ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 40 then return nil end
	return name
end

function M.ParentPath(path)
	return path:match("^(.*)" .. SEP .. "[^" .. SEP .. "]*$")
end
local ParentPath = M.ParentPath

function M.GroupName(path)
	return path:match("([^" .. SEP .. "]*)$")
end

function M.FormatPath(path)
	return (path:gsub(SEP, " > "))
end

function M.Depth(path)
	local _, n = path:gsub(SEP, "")
	return n
end

local function IsUnder(path, base)
	return path == base or path:sub(1, #base + 1) == base .. SEP
end
M.IsUnder = IsUnder

function M:GroupPaths()
	local list = {}
	for path in pairs(self:DB().groups) do list[#list + 1] = path end
	table.sort(list, function(a, b) return a:lower():gsub(SEP, "\1") < b:lower():gsub(SEP, "\1") end)
	return list
end
M.GroupNames = M.GroupPaths

function M:NewGroup(name, parent)
	name = CleanName(name)
	local groups = self:DB().groups
	if not name or (parent and not groups[parent]) then return false end
	local path = parent and (parent .. SEP .. name) or name
	if groups[path] then return false end
	groups[path] = { ops = {} }
	return true, path
end

function M:RenameGroup(path, newName)
	newName = CleanName(newName)
	local db = self:DB()
	if not newName or not db.groups[path] then return false end
	local parent = ParentPath(path)
	local newPath = parent and (parent .. SEP .. newName) or newName
	if db.groups[newPath] then return false end
	local moved = {}
	for p, g in pairs(db.groups) do
		if IsUnder(p, path) then moved[newPath .. p:sub(#path + 1)] = g; db.groups[p] = nil end
	end
	for p, g in pairs(moved) do db.groups[p] = g end
	for id, p in pairs(db.items) do
		if IsUnder(p, path) then db.items[id] = newPath .. p:sub(#path + 1) end
	end
	return true, newPath
end

function M:DeleteGroup(path)
	local db = self:DB()
	if not db.groups[path] then return false end
	local parent = ParentPath(path)
	for p in pairs(db.groups) do if IsUnder(p, path) then db.groups[p] = nil end end
	for id, p in pairs(db.items) do
		if IsUnder(p, path) then db.items[id] = parent end
	end
	return true
end

function M:AddItem(path, itemID)
	local db = self:DB()
	itemID = tonumber(itemID)
	if not db.groups[path] or not itemID or itemID <= 0 or itemID ~= math.floor(itemID) then return false end
	if db.items[itemID] == path then return false end
	db.items[itemID] = path
	return true
end

function M:RemoveItem(path, itemID)
	local db = self:DB()
	if db.items[itemID] ~= path then return false end
	db.items[itemID] = nil
	return true
end

function M:ItemGroup(itemID) return self:DB().items[itemID] end

function M:GroupItems(path, deep)
	local list = {}
	for id, p in pairs(self:DB().items) do
		if p == path or (deep and IsUnder(p, path)) then list[#list + 1] = id end
	end
	table.sort(list)
	return list
end

function M.ParseItemList(text)
	local ids, seen = {}, {}
	local function Add(id)
		id = tonumber(id)
		if id and id > 0 and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
	end
	if type(text) ~= "string" then return ids end
	local found = false
	for id in text:gmatch("item:(%d+)") do Add(id); found = true end
	for id in text:gsub("item:%d+", ""):gmatch("i:(%d+)") do Add(id); found = true end
	if not found and text:match("^[%d%s,;]+$") then
		for id in text:gmatch("%d+") do Add(id) end
	end
	return ids
end

function M:ImportGroups(base, text)
	if type(text) ~= "string" then return nil, "nothing to import" end
	if text:find("^%s*[%w%+/=]+%s*$") and not text:find("[ig]:") and not text:find("^[%d%s,;]+$") then
		return nil, "that looks like TSM's newer packed export, which K-Market can't read; in TSM use the old list format (\"group:\" and \"i:\" entries)"
	end
	local db = self:DB()
	local target, added, made = base, 0, 0
	if not text:find("group:", 1, true) then
		if not base then return nil, "pick a group first" end
		for _, id in ipairs(M.ParseItemList(text)) do if self:AddItem(base, id) then added = added + 1 end end
		return added, 0
	end
	for part in (text .. ","):gmatch("([^,]*),") do
		part = part:gsub("^%s+", ""):gsub("%s+$", "")
		local gp = part:match("^group:(.+)$")
		if gp then
			gp = gp:gsub("``", ",")
			local parent = base
			for piece in (gp .. SEP):gmatch("([^" .. SEP .. "]*)" .. SEP) do
				local name = CleanName(piece)
				if name then
					local path = parent and (parent .. SEP .. name) or name
					if not db.groups[path] then db.groups[path] = { ops = {} }; made = made + 1 end
					parent = path
				end
			end
			target = parent
		else
			local id = part:match("^i:(%d+)") or part:match("item:(%d+)") or part:match("^(%d+)$")
			if id and target and self:AddItem(target, id) then added = added + 1 end
		end
	end
	return added, made
end

function M:ExportGroups(path)
	local parts = {}
	for _, id in ipairs(self:GroupItems(path)) do parts[#parts + 1] = "i:" .. id end
	for _, p in ipairs(self:GroupPaths()) do
		if p ~= path and IsUnder(p, path) then
			local items = self:GroupItems(p)
			if #items > 0 then
				parts[#parts + 1] = "group:" .. p:sub(#path + 2):gsub(",", "``")
				for _, id in ipairs(items) do parts[#parts + 1] = "i:" .. id end
			end
		end
	end
	return table.concat(parts, ",")
end

function M:ImportItems(path, text)
	local n = self:ImportGroups(path, text)
	return n or 0
end
function M:ExportItems(path) return self:ExportGroups(path) end

function M:OpNames(kind)
	local list = {}
	for name, op in pairs(self:DB().ops) do
		if not kind or op.kind == kind then list[#list + 1] = name end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function M:NewOp(name, kind)
	name = CleanName(name)
	local ops = self:DB().ops
	if not name or ops[name] or not OP_DEFAULTS[kind] then return false end
	local op = { kind = kind }
	for k, v in pairs(OP_DEFAULTS[kind]) do op[k] = v end
	ops[name] = op
	return true, name
end

function M:DeleteOp(name)
	local db = self:DB()
	if not db.ops[name] then return false end
	db.ops[name] = nil
	for _, g in pairs(db.groups) do
		for kind, opName in pairs(g.ops) do if opName == name then g.ops[kind] = nil end end
	end
	return true
end

function M:RenameOp(old, new)
	new = CleanName(new)
	local db = self:DB()
	if not new or not db.ops[old] or db.ops[new] then return false end
	db.ops[new], db.ops[old] = db.ops[old], nil
	for _, g in pairs(db.groups) do
		for kind, opName in pairs(g.ops) do if opName == old then g.ops[kind] = new end end
	end
	return true, new
end

function M:AssignOp(path, kind, opName)
	local db = self:DB()
	local g = db.groups[path]
	if not g or not KIND_LABEL[kind] then return false end
	if opName then
		local op = db.ops[opName]
		if not op or op.kind ~= kind then return false end
	end
	g.ops[kind] = opName
	return true
end

function M:EffectiveOp(path, kind)
	local db = self:DB()
	local p = path
	while p do
		local g = db.groups[p]
		local name = g and g.ops[kind]
		if name == false then return nil end
		if name ~= nil then
			local op = db.ops[name]
			if op and op.kind == kind then return op, name, p end
			return nil
		end
		p = ParentPath(p)
	end
end

function M:GroupOp(g, kind)
	if type(g) == "string" then return (self:EffectiveOp(g, kind)) end
	for path, t in pairs(self:DB().groups) do
		if t == g then return (self:EffectiveOp(path, kind)) end
	end
end

function M:ItemOp(itemID, kind)
	local path = self:DB().items[itemID]
	if path then return self:EffectiveOp(path, kind) end
end

function M:RecordProfessions()
	local key, name, realm = self:Me()
	if not key then return end
	local found = {}
	if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
		for _, index in ipairs({ GetProfessions() }) do
			local prof = Plain((GetProfessionInfo(index)))
			if IS_PROFESSION[prof] then found[prof] = true end
		end
	end
	if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
		for i = 1, (Plain(GetNumSkillLines()) or 0) do
			local skill = Plain((GetSkillLineInfo(i)))
			if IS_PROFESSION[skill] then found[skill] = true end
		end
	end
	local db = self:DB()
	local c = db.chars[key] or {}
	c.name, c.realm, c.professions = name, realm, found
	db.chars[key] = c
end

local function RecipientFor(c, myRealm)
	if c.realm == myRealm then return c.name end
	return c.name .. "-" .. tostring(c.realm):gsub("%s", "")
end

function M:Recipient(op)
	if type(op.to) == "string" and op.to:match("%S") then return (op.to:gsub("%s", "")) end
	if op.kind ~= "crafter" or not IS_PROFESSION[op.profession] then return nil end
	local me, _, myRealm = self:Me()
	local best, bestKey
	for key, c in pairs(self:DB().chars) do
		if key ~= me and c.professions[op.profession] and type(c.name) == "string" then
			local better = not best or (c.realm == myRealm and best.realm ~= myRealm)
				or ((c.realm == myRealm) == (best.realm == myRealm) and key < bestKey)
			if better then best, bestKey = c, key end
		end
	end
	return best and RecipientFor(best, myRealm)
end

function M:CharKeyFor(recipient)
	if type(recipient) ~= "string" then return nil end
	local _, _, myRealm = self:Me()
	local want = recipient:lower()
	for key, c in pairs(self:DB().chars) do
		if type(c.name) == "string" then
			local full = (c.name .. "-" .. tostring(c.realm):gsub("%s", "")):lower()
			if full == want or (c.realm == myRealm and c.name:lower() == want) then return key end
		end
	end
end

function M:CharCount(key, itemID)
	local inv = key and self:DB().inv[key]
	if not inv then return 0 end
	local n = 0
	for _, where in ipairs({ "bags", "bank", "mail" }) do
		local t = inv[where]
		if type(t) == "table" and type(t[itemID]) == "number" then n = n + t[itemID] end
	end
	return n
end

function M:AddInTransit(recipient, itemID, count)
	local key = self:CharKeyFor(recipient)
	if not key then return end
	local inv = self:DB().inv
	inv[key] = inv[key] or {}
	inv[key].mail = inv[key].mail or {}
	inv[key].mail[itemID] = (inv[key].mail[itemID] or 0) + count
end

local function BagList()
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	local list = {}
	for bag = 0, last do list[#list + 1] = bag end
	return list
end

local function BankList()
	local list = {}
	local idx = Enum and Enum.BagIndex
	if idx and idx.CharacterBankTab_1 then
		for i = 1, 6 do
			local b = idx["CharacterBankTab_" .. i]
			if b then list[#list + 1] = b end
		end
	else
		list[1] = BANK_CONTAINER or -1
		local first = (NUM_BAG_SLOTS or 4) + 1
		for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = bag end
	end
	return list
end

local function SlotInfo(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then return nil end
	local id, count = Plain(info.itemID), Plain(info.stackCount)
	if type(id) ~= "number" or type(count) ~= "number" then return nil end
	return id, count, Plain(info.isBound) and true or false, Plain(info.isLocked) and true or false
end
M.SlotInfo = SlotInfo

function M:ScanBags()
	local out = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
	for _, bag in ipairs(BagList()) do
		for slot = 1, (Plain(C_Container.GetContainerNumSlots(bag)) or 0) do
			local id, count, bound, locked = SlotInfo(bag, slot)
			if id and not bound and not locked then
				local e = out[id]
				if not e then e = { count = 0, slots = {} }; out[id] = e end
				e.count = e.count + count
				e.slots[#e.slots + 1] = { bag = bag, slot = slot, count = count }
			end
		end
	end
	return out
end

function M:EmptySlots()
	local list = {}
	for _, bag in ipairs(BagList()) do
		local family = 0
		if C_Container.GetContainerNumFreeSlots then
			local _, f = C_Container.GetContainerNumFreeSlots(bag)
			family = Plain(f) or 0
		end
		if family == 0 and bag <= (NUM_BAG_SLOTS or 4) then
			for slot = 1, (Plain(C_Container.GetContainerNumSlots(bag)) or 0) do
				if not C_Container.GetContainerItemInfo(bag, slot) then list[#list + 1] = { bag = bag, slot = slot } end
			end
		end
	end
	return list
end

local function CountContainers(bags)
	local t = {}
	for _, bag in ipairs(bags) do
		for slot = 1, (Plain(C_Container.GetContainerNumSlots(bag)) or 0) do
			local id, count = SlotInfo(bag, slot)
			if id then t[id] = (t[id] or 0) + count end
		end
	end
	return t
end

function M:RecordInventory(withBank)
	local key = self:Me()
	if not key or not C_Container or not C_Container.GetContainerNumSlots then return end
	local inv = self:DB().inv
	inv[key] = inv[key] or {}
	inv[key].bags = CountContainers(BagList())
	if withBank then inv[key].bank = CountContainers(BankList()) end
	inv[key].t = Now()
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LOGOUT", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED",
	"BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_INBOX_UPDATE" }) do
	KUI:SafeRegisterEvent(events, e)
end
local bankOpen, invPending = false, false
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		local db = M:DB()
		local now = Now()
		for _, c in pairs(db.gold) do c.points = M:Thin(c.points, now) end
		local key = M:Me()

		if key and db.inv[key] then db.inv[key].mail = nil end
		M:RecordProfessions()
		C_Timer.After(2, function() M:RecordMoney(); M:RecordInventory(false) end)
	elseif event == "PLAYER_MONEY" or event == "PLAYER_LOGOUT" then
		M:RecordMoney()
		if event == "PLAYER_LOGOUT" then M:RecordInventory(bankOpen) end
	elseif event == "SKILL_LINES_CHANGED" then
		M:RecordProfessions()
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		M:RecordInventory(true)
	elseif event == "BANKFRAME_CLOSED" then
		M:RecordInventory(true)
		bankOpen = false
	elseif event == "BAG_UPDATE_DELAYED" and not invPending then
		invPending = true
		C_Timer.After(1, function() invPending = false; M:RecordInventory(bankOpen) end)
	elseif event == "MAIL_INBOX_UPDATE" and M.OnInboxUpdate then
		M:OnInboxUpdate()
	end
end)

SLASH_KAINUIMARKET1 = "/kmarket"
SlashCmdList["KAINUIMARKET"] = function() if M.ToggleWindow then M:ToggleWindow() end end
