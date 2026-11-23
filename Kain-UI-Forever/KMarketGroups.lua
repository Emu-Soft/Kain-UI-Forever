local _, KUI = ...
local M = KUI.Market
local SEP = M.SEP
local Plain = M.Plain

local CLASS_CONSUMABLE, CLASS_WEAPON, CLASS_ARMOR, CLASS_TRADEGOODS = 0, 2, 4, 7
local SUB_CLOTH = 5
local BIND_ON_EQUIP = 2

local SUBCLASS_PROFESSION = {
	[1] = "Engineering", [6] = "Leatherworking", [7] = "Blacksmithing", [8] = "Cooking",
	[9] = "Alchemy", [12] = "Enchanting",
}

local CONSUMABLE_KEY = { [1] = "potion", [2] = "elixir", [3] = "flask", [5] = "food", [7] = "bandage" }

local REAGENTS = {

	["Alchemy"] = {
		730, 765, 785, 1288, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3371, 3372, 3818, 3819,
		3820, 3821, 3858, 4625, 6358, 6359, 6370, 7972, 8831, 8836, 8838, 8839, 8845, 8846, 8925, 9262, 10620,
		12363, 13422, 13423, 13463, 13464, 13465, 13466, 13467, 13468, 18256, 19943, 213371, 248821, 248822,
		248823, 249274, 249399, 249424,
	},
	["Blacksmithing"] = {
		774, 818, 1206, 1210, 1529, 1705, 2835, 2836, 2838, 2840, 2841, 2842, 2880, 3466, 3470, 3478, 3486, 3575,
		3577, 3859, 3860, 3864, 5498, 5635, 5637, 6037, 7075, 7076, 7077, 7081, 7909, 7910, 7912, 7966, 7971, 8146,
		11139, 11371, 11382, 12359, 12360, 12361, 12364, 12365, 12644, 12655, 12662, 12799, 12800, 12804, 17010,
		17011, 17203, 18567, 19774, 20520, 22202, 22203, 213373, 213376, 234004, 234006, 249410, 249432, 249726,
		251290, 251291,
	},
	["Cooking"] = {
		723, 729, 731, 769, 1015, 1080, 1081, 1468, 1475, 2251, 2672, 2673, 2674, 2675, 2677, 2678, 2692, 2886,
		2924, 3172, 3173, 3174, 3404, 3667, 3685, 3712, 3713, 3730, 3731, 4402, 4603, 4655, 5465, 5466, 5467, 5468,
		5469, 5470, 5471, 5503, 5504, 6289, 6291, 6303, 6308, 6317, 6361, 6362, 6889, 7974, 8150, 8365, 8959,
		10284, 12037, 12184, 12202, 12203, 12204, 12205, 12206, 12207, 12208, 12223, 13754, 13756, 13758, 13759,
		13760, 13888, 13889, 20424, 21024, 21071, 21153, 239016, 239017, 251524, 272941,
	},
	["Enchanting"] = {
		2775, 4470, 6217, 6338, 10938, 10939, 10940, 10978, 10998, 11083, 11084, 11128, 11134, 11135, 11137, 11138,
		11144, 11174, 11175, 11176, 11177, 11178, 11291, 12808, 14343, 14344, 16202, 16203, 16204, 16206, 20725,
		234003, 234010, 234011, 234012, 247786, 248819, 248820, 249425,
	},
	["Engineering"] = {
		814, 4357, 4359, 4361, 4363, 4364, 4371, 4375, 4377, 4382, 4387, 4389, 4399, 4400, 4404, 4611, 7068, 7191,
		9060, 9061, 10505, 10558, 10559, 10560, 10561, 10647, 10648, 15992, 15994, 16000, 16006, 18631, 213381,
		213383, 215430, 234005, 238737, 249426, 255007, 260784, 260794, 260796, 260799, 260801, 260804, 260808,
		260813, 260815,
	},
	["First Aid"] = {
		19441, 23567, 255645,
	},
	["Leatherworking"] = {
		783, 2318, 2319, 2325, 2934, 4231, 4232, 4233, 4234, 4235, 4236, 4289, 4304, 4340, 4461, 5082, 5116, 5500,
		5784, 5785, 6261, 6470, 6471, 7067, 7069, 7070, 7078, 7080, 7082, 7286, 7287, 7392, 7428, 8151, 8152, 8153,
		8154, 8165, 8167, 8168, 8169, 8170, 8171, 8172, 8368, 12607, 12803, 12809, 12810, 12811, 15407, 15408,
		15409, 15410, 15412, 15414, 15415, 15416, 15417, 15419, 15420, 15422, 15423, 17012, 18240, 18512, 19726,
		19767, 19768, 20381, 20498, 20500, 20501, 22682, 213369, 213370, 213372, 221021, 234007, 248824, 248825,
		249427, 249428, 249429, 274030,
	},
	["Mining"] = {
		2770, 2771, 2772, 2776, 3576, 3857, 7911, 11370, 18562, 248815,
	},
	["Tailoring"] = {
		2324, 2604, 2605, 4341, 4342, 4589, 6260, 6371, 7071, 7072, 7079, 9210, 10286, 10290, 11082, 13926, 236656,
		249391, 249409, 249430, 249431,
	},

}

local REAGENT_PROFESSION = {}
for prof, ids in pairs(REAGENTS) do
	for _, id in ipairs(ids) do REAGENT_PROFESSION[id] = prof end
end
M.REAGENT_PROFESSION = REAGENT_PROFESSION

local DEFAULTS = {
	{ "Crafting Reagents", "reagent" },
}
do
	local profs = {}
	for prof in pairs(REAGENTS) do profs[prof] = true end
	for _, prof in pairs(SUBCLASS_PROFESSION) do profs[prof] = true end
	local list = {}
	for prof in pairs(profs) do list[#list + 1] = prof end
	table.sort(list)
	for _, prof in ipairs(list) do DEFAULTS[#DEFAULTS + 1] = { "Crafting Reagents" .. SEP .. prof, "reagent:" .. prof } end
	local rest = {
		{ "Cloth", "cloth" },
		{ "BoE Gear", "boe" },
		{ "BoE Gear" .. SEP .. "Uncommon", "boe:2" },
		{ "BoE Gear" .. SEP .. "Rare", "boe:3" },
		{ "BoE Gear" .. SEP .. "Epic", "boe:4" },
		{ "Consumables", "consumable" },
		{ "Consumables" .. SEP .. "Potions", "potion" },
		{ "Consumables" .. SEP .. "Elixirs", "elixir" },
		{ "Consumables" .. SEP .. "Flasks", "flask" },
		{ "Consumables" .. SEP .. "Food & Drink", "food" },
		{ "Consumables" .. SEP .. "Bandages", "bandage" },
	}
	for _, d in ipairs(rest) do DEFAULTS[#DEFAULTS + 1] = d end
end
M.DEFAULT_GROUPS = DEFAULTS

local QUALITY_NAME = { ["2"] = "green (uncommon)", ["3"] = "blue (rare)", ["4"] = "purple (epic)" }

function M.RuleText(rule)
	if type(rule) ~= "string" then return nil end
	local kind, arg = rule:match("^([^:]+):?(.*)$")
	if kind == "reagent" then return arg ~= "" and (arg .. " reagents") or "crafting reagents" end
	if kind == "boe" then return (QUALITY_NAME[arg] and (QUALITY_NAME[arg] .. " ") or "") .. "bind-on-equip gear" end
	return ({ cloth = "cloth", consumable = "consumables", potion = "potions", elixir = "elixirs", flask = "flasks",
		food = "food and drink", bandage = "bandages" })[kind]
end

function M:ItemRules(itemID)
	if not (C_Item and C_Item.GetItemInfoInstant) then return false end
	local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
	classID, subID = Plain(classID), Plain(subID)
	if type(classID) ~= "number" then return nil end
	if classID == CLASS_TRADEGOODS then
		if subID == SUB_CLOTH then return { "cloth" } end
		local prof = REAGENT_PROFESSION[itemID] or SUBCLASS_PROFESSION[subID]
		if prof then return { "reagent:" .. prof, "reagent" } end
		return { "reagent" }
	elseif classID == CLASS_CONSUMABLE then
		local key = CONSUMABLE_KEY[subID]
		if key then return { key, "consumable" } end
		return { "consumable" }
	elseif classID == CLASS_WEAPON or classID == CLASS_ARMOR then
		local info = { C_Item.GetItemInfo(itemID) }
		local quality, bind = Plain(info[3]), Plain(info[14])
		if type(quality) ~= "number" or type(bind) ~= "number" then return nil end
		if bind ~= BIND_ON_EQUIP or quality < 2 then return false end
		if quality <= 4 then return { "boe:" .. quality, "boe" } end
		return { "boe" }
	end
	return false
end

function M:MakeDefaultGroups()
	local groups = self:DB().groups
	local made = 0
	for _, d in ipairs(DEFAULTS) do
		if not groups[d[1]] then
			groups[d[1]] = { ops = {}, auto = d[2] }
			made = made + 1
		end
	end
	return made
end

local function RuleIndex(groups)
	local index = {}
	for _, path in ipairs(M:GroupPaths()) do
		local g = groups[path]
		if type(g.auto) == "string" and not g.autoOff and not index[g.auto] then index[g.auto] = path end
	end
	return index
end

function M:AutoGroupFor(itemID, index)
	local rules = self:ItemRules(itemID)
	if rules == nil then return nil, true end
	if not rules then return nil end
	index = index or RuleIndex(self:DB().groups)
	for _, rule in ipairs(rules) do
		if index[rule] then return index[rule] end
	end
end

function M:AutoFill(withBank)
	local db = self:DB()
	if type(db.autoSkip) ~= "table" then db.autoSkip = {} end
	local index = RuleIndex(db.groups)
	if not next(index) then return 0 end
	local seen = {}
	for id in pairs(self:ScanBags()) do seen[id] = true end
	if withBank and self.ScanBank then
		for id in pairs(self:ScanBank()) do seen[id] = true end
	end
	local added = 0
	for id in pairs(seen) do
		if not db.items[id] and not db.autoSkip[id] then
			local path = self:AutoGroupFor(id, index)
			if path and self:AddItem(path, id) then added = added + 1 end
		end
	end
	if added > 0 and self.RefreshWindow then self:RefreshWindow() end
	return added
end

function M:ScanBank()
	local out = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
	local list = {}
	local idx = Enum and Enum.BagIndex
	if idx and idx.CharacterBankTab_1 then
		for i = 1, 6 do if idx["CharacterBankTab_" .. i] then list[#list + 1] = idx["CharacterBankTab_" .. i] end end
	else
		list[1] = BANK_CONTAINER or -1
		local first = (NUM_BAG_SLOTS or 4) + 1
		for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = bag end
	end
	for _, bag in ipairs(list) do
		for slot = 1, (Plain(C_Container.GetContainerNumSlots(bag)) or 0) do
			local id, count, bound = M.SlotInfo(bag, slot)
			if id and not bound then out[id] = (out[id] or 0) + count end
		end
	end
	return out
end

function M:SetGroupAuto(path, on)
	local g = self:DB().groups[path]
	if not g or type(g.auto) ~= "string" then return false end
	g.autoOff = (not on) or nil
	if on then self:AutoFill(false) end
	return true
end

local RemoveItem = M.RemoveItem
function M:RemoveItem(path, itemID)
	local ok = RemoveItem(self, path, itemID)
	if ok then
		local db = self:DB()
		if type(db.autoSkip) ~= "table" then db.autoSkip = {} end
		db.autoSkip[itemID] = true
	end
	return ok
end

function M:BuildGroupAuto(page, left, right)
	local UI = self.UI
	local defaults = UI.Button(left, "Default Groups", 110, 20, "tertiary")
	defaults:SetPoint("TOPRIGHT", -8, -8)
	defaults.kmTip = "Makes any of K-Market's default groups that are missing (crafting reagents by profession, cloth, bind-on-equip gear, consumables). They fill themselves from your bags."
	defaults:SetScript("OnClick", function()
		local made = M:MakeDefaultGroups()
		local added = M:AutoFill(false)
		M.Say(string.format("%d default group(s) made, %d item(s) sorted into groups.", made, added))
		page:Refresh()
	end)
	page.defaultsButton = defaults
	page.autoToggle = UI.Toggle(right, "", function(on)
		if page.autoPath then M:SetGroupAuto(page.autoPath, on); page:Refresh() end
	end)
	page.autoToggle:SetPoint("TOPRIGHT", 0, -2)
	page.autoToggle:SetSize(300, 16)
	page.autoToggle.kmText:SetPoint("RIGHT", 0, 0)
	page.autoToggle.kmText:SetJustifyH("LEFT")
end

function M:RefreshGroupAuto(page, path)
	local t = page.autoToggle
	if not t then return end
	local g = path and self:DB().groups[path]
	local rule = g and self.RuleText(g.auto)
	page.autoPath = rule and path or nil
	t:SetShown(rule ~= nil)
	if rule then
		t.kmText:SetText("Fills itself with " .. rule)
		t:SetKMChecked(not g.autoOff)
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "GET_ITEM_INFO_RECEIVED" }) do
	KUI:SafeRegisterEvent(events, e)
end
local pending, bankOpen = false, false
local function Soon()
	if pending then return end
	pending = true
	C_Timer.After(1.5, function() pending = false; M:AutoFill(bankOpen) end)
end
events:SetScript("OnEvent", function(_, event) M:OnGroupEvent(event) end)
function M:OnGroupEvent(event)
	if event == "PLAYER_LOGIN" then
		local db = self:DB()
		if db.defaultGroups ~= 1 then
			self:MakeDefaultGroups()
			db.defaultGroups = 1
		end
		C_Timer.After(3, function() M:AutoFill(false) end)
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		Soon()
	elseif event == "BANKFRAME_CLOSED" then
		bankOpen = false
	else
		Soon()
	end
end
