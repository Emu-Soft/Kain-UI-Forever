local _, KUI = ...
local M = KUI.Market
local P = {}
M.Prices = P

local FIELD = { min = 1, market = 2, avg7d = 3, qty = 4 }
P.SOURCES = { "market", "min", "avg7d" }
local SOURCE_LABEL = { market = "Market", min = "Min buyout", avg7d = "7-day average" }
P.SOURCE_LABEL = SOURCE_LABEL

local cache = { house = nil, t = nil, items = {} }

function P.Faction()
	local faction = UnitFactionGroup and M.Plain(UnitFactionGroup("player"))
	return type(faction) == "string" and faction ~= "" and faction or nil
end

function P:AppHouse()
	local data = _G.KUI_PRICE_DATA
	if type(data) ~= "table" or data.v ~= 1 or type(data.houses) ~= "table" then return nil end
	local faction = self.Faction()
	if not faction then return nil end
	for id, h in pairs(data.houses) do
		if type(h) == "table" and h.faction == faction and type(h.d) == "string" and type(h.t) == "number" then return id, h end
	end
	return nil
end

function P:PeerHouse()
	local db = M.DB and M:DB()
	local faction = self.Faction()
	local p = type(db) == "table" and type(db.peerPrices) == "table" and faction and db.peerPrices[faction]
	if type(p) ~= "table" or type(p.d) ~= "string" or type(p.t) ~= "number" or p.house == nil then return nil end
	if not p.faction then p.faction = faction end
	return p.house, p
end

function P:House()
	local id, h = self:AppHouse()
	local pid, ph = self:PeerHouse()
	if ph and (not h or ph.t > h.t) then return pid, ph, "guild" end
	if h then return id, h, "app" end
	return nil
end

function P:Get(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	local id, h = self:House()
	if not h then return nil end
	if cache.house ~= id or cache.t ~= h.t then
		cache.house, cache.t, cache.items = id, h.t, {}
	end
	local r = cache.items[itemID]
	if r == nil then
		r = false
		local d, key = h.d, itemID .. ","
		local pos
		if d:sub(1, #key) == key then
			pos = 1
		else
			local f = d:find(";" .. key, 1, true)
			pos = f and f + 1
		end
		if pos then
			local mn, mk, av, q = d:match("^%d+,(%d+),(%d+),(%d+),(%d+)", pos)
			if mn then r = { tonumber(mn), tonumber(mk), tonumber(av), tonumber(q) } end
		end
		cache.items[itemID] = r
	end
	return r or nil
end

function P:Value(itemID, source)
	local r = self:Get(itemID)
	local i = r and FIELD[source]
	return i and r[i] or nil
end

function M:MarketPrice(itemID)
	local v = P:Value(itemID, "market")
	if not v or v <= 0 then return nil end
	local age = P:Age()
	return v, age and ("market, " .. age .. " old") or "market"
end

function P.ParseInput(text)
	if type(text) ~= "string" then return nil end
	local s = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local pct, src = s:match("^(%d+%.?%d*)%s*%%%s*o?f?%s*(%a[%w]*)$")
	if not src then src = s:match("^(%a[%w]*)$") end
	if src then
		src = src:gsub("^km", "")
		if not FIELD[src] or src == "qty" then return nil end
		pct = tonumber(pct) or 100
		if pct <= 0 or pct > 1000 then return nil end
		if pct == 100 then return src end
		return string.format("%s%% %s", (pct == math.floor(pct)) and string.format("%d", pct) or tostring(pct), src)
	end
	return M.ParseMoney(text)
end

function P:Resolve(value, itemID)
	if type(value) == "number" then return value, nil end
	if type(value) ~= "string" then return nil end
	local pct, src = value:match("^(%d+%.?%d*)%% (%a[%w]*)$")
	if not src then src = value end
	local base = FIELD[src] and self:Value(itemID, src)
	if not base then return nil, src end
	pct = tonumber(pct) or 100
	return math.floor(base * pct / 100 + 0.5), src
end

function P.Show(value)
	if type(value) == "string" then return value end
	if type(value) == "number" and value > 0 then return M.FormatMoney(value) end
	return "0"
end

local function AgeText(s)
	s = math.max(0, s)
	if s < 3600 then return math.floor(s / 60) .. " min" end
	if s < 172800 then return math.floor(s / 3600) .. " h" end
	return math.floor(s / 86400) .. " days"
end

function P:Age()
	local _, h = self:House()
	if not h or type(h.t) ~= "number" then return nil end
	return AgeText(time() - h.t)
end

function P:Newest(itemID)
	local best, age
	local _, h = self:House()
	local v = self:Value(itemID, "market")
	if v and v > 0 and h and type(h.t) == "number" then best, age = v, math.max(0, time() - h.t) end
	if M.NotedPrice then
		local noted, nage = M:NotedPrice(tonumber(itemID))
		if noted and noted > 0 and nage and (not age or nage < age) then best, age = noted, math.max(0, nage) end
	end
	return best, age
end

local GREEN, YELLOW, RED = { 0.1, 1, 0.1 }, { 1, 0.85, 0 }, { 1, 0.2, 0.2 }
local function Mix(a, b, f) return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f end
function P.AgeColor(age)
	local h = math.max(0, age) / 3600
	if h <= 1 then return GREEN[1], GREEN[2], GREEN[3] end
	if h <= 6 then return Mix(GREEN, YELLOW, (h - 1) / 5) end
	if h < 24 then return Mix(YELLOW, RED, (h - 6) / 18) end
	return RED[1], RED[2], RED[3]
end

local COIN_ICON = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
local function Coins(copper)
	copper = math.floor(copper + 0.5)
	local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. COIN_ICON:format("Gold") end
	if sv > 0 then parts[#parts + 1] = sv .. COIN_ICON:format("Silver") end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COIN_ICON:format("Copper") end
	return table.concat(parts, " ")
end
P.Coins = Coins

function P.UpdatedText(age)
	if age < 60 then return "Updated just now" end
	return "Updated " .. AgeText(age) .. " ago"
end

function P:Status()
	local data = _G.KUI_PRICE_DATA
	local id, h, from = self:House()
	local share = self.Share and self.Share.StatusText and self.Share:StatusText()
	share = share and (" " .. share) or ""
	if not h then
		if type(data) ~= "table" then
			return "No price data. Install the K-Market Prices app (github.com/Emu-Soft/K-Market-Prices), then /reload,"
				.. " or wait for a guildmate who has it." .. share
		end
		if data.v ~= 1 then return "The price data is a newer format than this K-UI. Update K-UI." .. share end
		return "Price data has no auction house for your faction." .. share
	end
	local where = from == "guild" and ("shared by " .. tostring(h.from or "a guildmate")) or "from the app"
	return string.format("Prices for house %s (%s), %s: %d items, %s old.%s",
		tostring(id), tostring(h.faction), where, P.Count(h.d), self:Age() or "?", share)
end

function P.Count(d)
	if type(d) ~= "string" or d == "" then return 0 end
	local n = 1
	for _ in d:gmatch(";") do n = n + 1 end
	return n
end

local function TooltipOn()
	local db = M.DB and M:DB()
	return not (type(db) == "table" and db.priceTooltip == false)
end

local function AddLines(tooltip, itemID)
	if not TooltipOn() or not tooltip or not tooltip.AddDoubleLine then return end
	local value, age = P:Newest(itemID)
	if not value then return end
	tooltip:AddDoubleLine("K-Market Value", P.Coins(value), 0.88, 0.73, 0, 1, 1, 1)
	if tooltip.AddLine then tooltip:AddLine(P.UpdatedText(age), P.AgeColor(age)) end
	if tooltip.Show then tooltip:Show() end
end
P.AddTooltipLines = AddLines

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
	and Enum.TooltipDataType.Item then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		local id = type(data) == "table" and data.id
		if type(id) == "number" then pcall(AddLines, tooltip, id) end
	end)
end

function P.Command(msg)
	local rest = msg:match("^%s*prices%s*(.*)$")
	if not rest then return false end
	local onoff = rest:match("^tooltip%s+(%a+)")
	local shareOnOff = rest:match("^share%s+(%a+)")
	if onoff == "on" or onoff == "off" then
		local db = M:DB()
		if db then db.priceTooltip = (onoff == "on") end
		print("|cffe0bb00K-Market:|r price lines in tooltips " .. onoff .. ".")
	elseif shareOnOff == "on" or shareOnOff == "off" then
		local db = M:DB()
		if db then db.priceShare = (shareOnOff == "on") end
		if P.Share and P.Share.SettingChanged then P.Share:SettingChanged() end
		print("|cffe0bb00K-Market:|r sharing prices with your guild " .. shareOnOff .. ".")
	else
		print("|cffe0bb00K-Market:|r " .. P:Status())
	end
	return true
end
