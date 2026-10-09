local _, KUI = ...

local MACRO_NAME = "Weapon Swap"
local MACRO_ICON = "INV_Misc_EngGizmos_SwissArmy"

local SLOTS = {
	{
		key = "oneHand", label = "MH", tip = "Main hand: a one-handed weapon",
		accepts = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true },
		emptyIcon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
	},

	{

		key = "shield", label = "OH", tip = "Off hand: a shield, off-hand item or off-hand weapon",
		accepts = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true },
		emptyIcon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
	},
	{
		key = "twoHand", label = "2H", tip = "Two-handed weapon",
		accepts = { INVTYPE_2HWEAPON = true },
		emptyIcon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
	},
}

local function Say(msg)
	print("|cff33ff99Kain-UI Forever|r " .. msg)
end

local function Warn(msg)
	print("|cffff6060Kain-UI Forever:|r " .. msg)
end

local function BagAPI()
	local c = _G.C_Container
	return (c and c.GetContainerNumSlots) or _G.GetContainerNumSlots,
		(c and c.GetContainerItemLink) or _G.GetContainerItemLink,
		(c and c.UseContainerItem) or _G.UseContainerItem
end

function _G.WE(n)
	if not n or n == "" then return end
	local numSlots, getLink, useItem = BagAPI()
	if not (numSlots and getLink and useItem) then return end
	for b = 0, 4 do
		for s = 1, (numSlots(b) or 0) do
			local l = getLink(b, s)
			if l and strfind(l, n, 1, true) then
				useItem(b, s)
				return
			end
		end
	end
end

function _G.WH(n, i)
	if not n or n == "" then return false end
	local l = GetInventoryItemLink("player", i)
	return l and strfind(l, n, 1, true) or false
end

local function Store()
	if not KUI.db then return nil end
	KUI.db.weaponSwap = KUI.db.weaponSwap or {}
	return KUI.db.weaponSwap
end

local function GetInstant(itemID)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not fn then return nil end

	local _, _, subType, equipLoc, icon = fn(itemID)
	return equipLoc, icon, subType
end

local function NameFromLink(link)
	return link and link:match("%[(.-)%]") or nil
end

local function SlotByKey(key)
	for _, s in ipairs(SLOTS) do
		if s.key == key then return s end
	end
end

local function GetNames()
	local st = Store()
	if not st then return nil end
	local a, b, c = st.oneHand, st.twoHand, st.shield
	if a and a.name and b and b.name and c and c.name then
		return a.name, b.name, c.name
	end
end

function KUI:BuildWeaponSwapMacroBody()
	local st = Store()
	local one, two, off = st and st.oneHand, st and st.twoHand, st and st.shield
	if not (one and one.id and two and two.id and off and off.id) then return nil end
	local _, _, twoType = GetInstant(two.id)
	if not twoType or twoType == "" then return nil end
	local offLoc, _, offType = GetInstant(off.id)

	if offLoc == "INVTYPE_SHIELD" and offType and offType ~= "" then
		local body = "/equipslot [equipped:" .. twoType .. "] 16 item:" .. one.id .. "\n"
			.. "/equipslot [noequipped:" .. offType .. "] 17 item:" .. off.id .. "\n"
			.. "/equip [equipped:" .. offType .. "] item:" .. two.id
		return body, false
	end

	local cond = "[equipped:" .. twoType .. "]"
	local body = "/equipslot " .. cond .. " 16 item:" .. one.id .. "\n"
		.. "/equipslot " .. cond .. " 17 item:" .. off.id .. "\n"
		.. "/equip [noequipped:" .. twoType .. "] item:" .. two.id
	return body, false
end

function _G.KainUIWeaponSwap()
	local one, two, shield = GetNames()
	if not one then
		Warn("fill all three Weapon Swap slots first (/kainui).")
		return
	end
	if WH(two, 16) or not WH(one, 16) or not WH(shield, 17) then
		WE(shield)
		C_Timer.After(.5, function() WE(one) end)
	else
		WE(two)
	end
end

local pendingSync

local function DoSync(create, quiet, setIcon)
	local body, isShort = KUI:BuildWeaponSwapMacroBody()
	if not body then
		if create and not quiet then Warn("fill all three Weapon Swap slots first, then the macro is made for you.") end
		return
	end

	local getIndex = _G.GetMacroIndexByName or (C_Macro and C_Macro.GetMacroIndexByName)
	local getInfo = _G.GetMacroInfo or (C_Macro and C_Macro.GetMacroInfo)
	local editMacro = _G.EditMacro or (C_Macro and C_Macro.EditMacro)
	local createMacro = _G.CreateMacro or (C_Macro and C_Macro.CreateMacro)
	if not (createMacro and editMacro and getIndex) then
		if not quiet then Warn("couldn't find the macro API on this client -- Weapon Swap macro not written.") end
		return
	end

	local idx
	local okIdx, found = pcall(getIndex, MACRO_NAME)
	if okIdx and found and found > 0 then idx = found end

	if idx then

		if getInfo and not setIcon then
			local okInfo, _, _, current = pcall(getInfo, idx)
			if okInfo and current == body then return end
		end

		local ok, err = pcall(editMacro, idx, nil, setIcon and MACRO_ICON or nil, body)
		if ok then
			if not quiet then Say("Weapon Swap macro updated" .. (isShort and " (short form: item names too long for a full macro)." or ".")) end
		elseif not quiet then
			Warn("couldn't update the Weapon Swap macro (" .. tostring(err) .. ").")
		end
	elseif create then

		local ok, result = pcall(createMacro, MACRO_NAME, MACRO_ICON, body, true)
		if not (ok and result) then

			ok, result = pcall(createMacro, MACRO_NAME, "INV_Misc_QuestionMark", body, true)
		end
		if ok and result then
			Say("Weapon Swap macro created in your character macros" .. (isShort and " (short form: item names too long for a full macro)." or "."))
		else
			Warn("couldn't create the Weapon Swap macro (" .. tostring(ok and "no free character macro slot?" or result) .. ").")
		end
	end
end

function KUI:SyncWeaponSwapMacro(create, quiet, setIcon)
	if InCombatLockdown() then
		pendingSync = { create = create, setIcon = setIcon }
		if not self.weaponSwapRegenFrame then
			local f = CreateFrame("Frame")
			self:SafeRegisterEvent(f, "PLAYER_REGEN_ENABLED")
			f:SetScript("OnEvent", function()
				if pendingSync then
					local p = pendingSync
					pendingSync = nil
					DoSync(p.create, false, p.setIcon)
				end
			end)
			self.weaponSwapRegenFrame = f
		end
		if not quiet then Say("in combat -- the Weapon Swap macro will be written when combat ends.") end
		return
	end
	DoSync(create, quiet, setIcon)
end

function KUI:SetWeaponSwapItem(key, itemID, link)
	local slot = SlotByKey(key)
	local st = Store()
	if not slot or not st or not itemID then return false end

	local equipLoc = GetInstant(itemID)

	if equipLoc and equipLoc ~= "" and not slot.accepts[equipLoc] then
		Warn("that isn't a valid item for the " .. slot.label .. " slot (" .. slot.tip .. ").")
		return false
	end

	if not link then
		local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
		local _, l = getInfo(itemID)
		link = l
	end
	local name = NameFromLink(link)
	if not name then
		Warn("couldn't read that item's name yet -- try dropping it again.")
		return false
	end

	st[key] = { id = itemID, link = link, name = name }
	self:SyncWeaponSwapMacro(true)
	return true
end

function KUI:ClearWeaponSwapItem(key)
	local st = Store()
	if st then st[key] = nil end
end

local SLOT_SIZE, SLOT_GAP = 37, 8
local TITLE_DROP = 2

local function SlotBackground(tex)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-item-slot64") then
		tex:SetAtlas("bags-item-slot64")
	else
		tex:SetTexture("Interface\\Buttons\\UI-EmptySlot")
		tex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
	end
end

local function QualityColor(itemID)
	local quality
	if C_Item and C_Item.GetItemQualityByID then
		quality = C_Item.GetItemQualityByID(itemID)
	else
		local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
		quality = select(3, getInfo(itemID))
	end
	if quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then return r, g, b end
	end
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local c = ITEM_QUALITY_COLORS[quality]
		return c.r, c.g, c.b
	end
	return 0.62, 0.62, 0.62
end

function KUI:BuildWeaponSwapWidgets(parent, x, y)
	y = y - TITLE_DROP
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", x, y)
	title:SetText("Weapon Swap Macro Helper")

	local buttons = {}

	local function Refresh()
		local st = Store() or {}
		for _, b in ipairs(buttons) do
			local saved = st[b.slotKey]
			if saved and saved.id then
				local _, icon = GetInstant(saved.id)
				b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				b.icon:SetTexCoord(0, 1, 0, 1)
				b.icon:SetAlpha(1)
				b.IconBorder:SetVertexColor(QualityColor(saved.id))
				b.IconBorder:Show()
			else

				b.icon:SetTexture(b.def.emptyIcon)
				b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				b.icon:SetAlpha(0.35)
				b.IconBorder:Hide()
			end
		end
	end

	local function TryDrop(b)
		local kind, itemID, link = GetCursorInfo()
		if kind ~= "item" or not itemID then return false end
		local ok = KUI:SetWeaponSwapItem(b.slotKey, itemID, link)

		ClearCursor()
		Refresh()
		return ok
	end

	for i, def in ipairs(SLOTS) do
		local b = CreateFrame("Button", nil, parent)
		b:SetSize(SLOT_SIZE, SLOT_SIZE)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (SLOT_SIZE + SLOT_GAP), y - 26)
		b.slotKey, b.def = def.key, def

		b.slotBg = b:CreateTexture(nil, "BACKGROUND")
		b.slotBg:SetAllPoints()
		SlotBackground(b.slotBg)

		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()

		b.IconBorder = b:CreateTexture(nil, "OVERLAY")
		b.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
		b.IconBorder:SetAllPoints()
		b.IconBorder:Hide()

		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnReceiveDrag", function(btn) TryDrop(btn) end)
		b:SetScript("OnClick", function(btn, button)
			if TryDrop(btn) then return end
			if button == "RightButton" then
				KUI:ClearWeaponSwapItem(btn.slotKey)
				Refresh()
			end
		end)
		b:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			local st = Store()
			local saved = st and st[btn.slotKey]
			if saved and saved.link then
				GameTooltip:SetHyperlink(saved.link)
				GameTooltip:AddLine("Right-click to clear.", 0.6, 0.6, 0.6)
			else
				GameTooltip:AddLine(btn.def.label .. ": " .. btn.def.tip, 1, 0.82, 0)
				GameTooltip:AddLine("Drag an item here.", 0.8, 0.8, 0.8)
			end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)

		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOP", b, "BOTTOM", 0, -2)
		label:SetText(def.label)

		buttons[#buttons + 1] = b
	end

	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", x + 4, y - 26 - SLOT_SIZE - 20)
	hint:SetWidth(300)
	hint:SetJustifyH("LEFT")
	hint:SetText("Drag gear in from your bags or character sheet. Right-click a slot to clear it.")

	Refresh()
	return Refresh
end

function KUI:WeaponSwapRebuild()
	if not GetNames() then
		Warn("fill all three Weapon Swap slots first (/kainui).")
		return
	end
	self:SyncWeaponSwapMacro(true, false, true)
end
