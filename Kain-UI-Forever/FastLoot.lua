local _, KUI = ...

local function GetLootSlotFunc()
	return (C_Loot and C_Loot.LootSlot) or _G.LootSlot
end
local function GetNumLootItemsFunc()
	return (C_Loot and C_Loot.GetNumLootItems) or _G.GetNumLootItems
end
local function GetLootSlotInfoFunc()
	return (C_Loot and C_Loot.GetLootSlotInfo) or _G.GetLootSlotInfo
end
local function GetLootSlotLinkFunc()
	return (C_Loot and C_Loot.GetLootSlotLink) or _G.GetLootSlotLink
end
local function GetContainerFreeFunc()
	return (C_Container and C_Container.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots
end

local function GetBandFunc()
	return _G.bit and _G.bit.band
end

local function GetSlotLockedAndQuantity(getLootSlotInfoFunc, slot)
	local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9 = pcall(getLootSlotInfoFunc, slot)
	if not ok then return nil, nil, r1 end
	local quantity = r3

	if type(r1) == "boolean" then return r1, quantity end
	if type(r2) == "boolean" then return r2, quantity end
	if type(r3) == "boolean" then return r3, quantity end
	if type(r4) == "boolean" then return r4, quantity end
	if type(r5) == "boolean" then return r5, quantity end
	if type(r6) == "boolean" then return r6, quantity end
	if type(r7) == "boolean" then return r7, quantity end
	if type(r8) == "boolean" then return r8, quantity end
	if type(r9) == "boolean" then return r9, quantity end
	return nil, quantity
end

local generalFree = 0
local numSpecialBags = 0
local specialFree = {}
local specialFamily = {}
local canCheckBagSpace = false

local function SnapshotBags()
	generalFree, numSpecialBags, canCheckBagSpace = 0, 0, false

	local containerFreeFunc = GetContainerFreeFunc()
	if not containerFreeFunc then return nil, "GetContainerNumFreeSlots (or C_Container.GetContainerNumFreeSlots) not found" end

	local backpack = _G.BACKPACK_CONTAINER or 0
	local numBags = _G.NUM_BAG_SLOTS or 4
	for bag = backpack, numBags do
		local ok, freeSlots, bagFamily = pcall(containerFreeFunc, bag)
		if not ok then return nil, string.format("bag %d: %s", bag, tostring(freeSlots)) end
		freeSlots = freeSlots or 0
		if not bagFamily or bagFamily == 0 then
			generalFree = generalFree + freeSlots
		else
			numSpecialBags = numSpecialBags + 1
			specialFree[numSpecialBags] = freeSlots
			specialFamily[numSpecialBags] = bagFamily
		end
	end

	canCheckBagSpace = true
	return true
end

local function CanLootItem(itemLink, quantity)
	if not canCheckBagSpace or not itemLink then return nil end
	if generalFree > 0 then return true end

	if numSpecialBags > 0 then
		local band = GetBandFunc()
		if band then
			local ok, itemFamily = pcall(GetItemFamily, itemLink)
			if ok and itemFamily then
				for i = 1, numSpecialBags do
					if specialFree[i] > 0 and band(itemFamily, specialFamily[i]) > 0 then
						return true
					end
				end
			end
		end
	end

	local ownedOk, ownedCount = pcall(GetItemCount, itemLink)
	ownedCount = (ownedOk and ownedCount) or 0
	if ownedCount == 0 then return false end

	local infoOk, stackSize = pcall(function() return select(8, GetItemInfo(itemLink)) end)
	stackSize = (infoOk and stackSize) or 0
	if stackSize <= 1 then return false end

	local remainder = ownedCount % stackSize
	local availableSpaceInStack = (remainder == 0) and 0 or (stackSize - remainder)
	return availableSpaceInStack >= (quantity or 1)
end

local scanLines = { "no loot window has opened yet this session -- open one, then run this again." }
local function ResetScan() scanLines = {} end
local function Note(fmt, ...) table.insert(scanLines, string.format(fmt, ...)) end

function KUI:FastLootScanReport()
	print("|cff33ff99Kain-UI Forever|r fast loot scan:")
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
end

local function AttemptFastLoot(triggerEvent)
	if not (KUI.db and KUI.db.fastLoot) then return end
	if KUI.SKIP and KUI.SKIP.loot then return end
	ResetScan()

	local lootSlotFunc = GetLootSlotFunc()
	local numLootItemsFunc = GetNumLootItemsFunc()
	if not lootSlotFunc then
		Note("couldn't find LootSlot (or C_Loot.LootSlot) on this client -- fast loot can't run.")
		return
	end
	if not numLootItemsFunc then
		Note("couldn't find GetNumLootItems (or C_Loot.GetNumLootItems) on this client -- fast loot can't run.")
		return
	end

	local ok, total = pcall(numLootItemsFunc)
	if not ok or not total then
		Note("GetNumLootItems failed: %s", tostring(total))
		return
	end

	Note("triggered by %s, %d slot(s) reported.", triggerEvent, total)

	local getLootSlotInfoFunc = GetLootSlotInfoFunc()
	local getLootSlotLinkFunc = GetLootSlotLinkFunc()
	if not getLootSlotInfoFunc then
		Note("GetLootSlotInfo not found -- locked-slot and bag-space checks skipped, looting blind as before.")
	end

	local spaceOk, spaceErr
	if getLootSlotInfoFunc and getLootSlotLinkFunc then
		spaceOk, spaceErr = SnapshotBags()
		if not spaceOk then
			Note("bag-space check unavailable (%s) -- skipping items that won't fit is disabled this pass.", tostring(spaceErr))
		end
	end

	local attempted, failed, skippedLocked, skippedNoSpace = 0, 0, 0, 0
	for i = total, 1, -1 do
		local locked, quantity
		if getLootSlotInfoFunc then
			local infoErr
			locked, quantity, infoErr = GetSlotLockedAndQuantity(getLootSlotInfoFunc, i)
			if infoErr then
				Note("slot %d: GetLootSlotInfo failed: %s", i, tostring(infoErr))
			end
		end

		if locked then
			skippedLocked = skippedLocked + 1
			Note("slot %d: skipped -- locked (pending roll).", i)
		else
			local fits = true
			if canCheckBagSpace and getLootSlotLinkFunc then
				local linkOk, itemLink = pcall(getLootSlotLinkFunc, i)
				if linkOk and itemLink then
					local canFit = CanLootItem(itemLink, quantity)
					if canFit == false then fits = false end
				end
			end

			if not fits then
				skippedNoSpace = skippedNoSpace + 1
				Note("slot %d: skipped -- no bag space, left for the loot window.", i)
			else
				local lootOk, err = pcall(lootSlotFunc, i)
				attempted = attempted + 1
				if not lootOk then
					failed = failed + 1
					Note("slot %d: LootSlot call failed: %s", i, tostring(err))
				end
			end
		end
	end
	Note("attempted %d slot(s), %d call(s) failed outright, %d skipped (locked), %d skipped (no space).",
		attempted, failed, skippedLocked, skippedNoSpace)
end

local LOOT_REVEAL_TIMEOUT = 0.25
local LOOT_UNKNOWN_WAIT = 0.04
local hiddenByUs = false
local hiddenAt = 0
local hiddenThisLoot = false

local function LootWindow()
	local f = _G.LootFrame
	if f and f.SetAlpha then return f end
end

local function LootWindowFilled(f)
	local sb = f.ScrollBox
	if type(sb) ~= "table" or type(sb.GetFrames) ~= "function" then return nil end
	local ok, frames = pcall(sb.GetFrames, sb)
	if not ok or type(frames) ~= "table" then return nil end
	for _, row in pairs(frames) do
		if type(row) == "table" and row.IsShown and row:IsShown() then return true end
	end
	return false
end

local revealWatcher = CreateFrame("Frame")
revealWatcher:Hide()

local function RevealLootWindow()
	revealWatcher:Hide()
	if not hiddenByUs then return end
	hiddenByUs = false
	local f = LootWindow()
	if f then f:SetAlpha(1) end
end

local function HideLootWindowUntilFilled()
	local f = LootWindow()
	if not f then return end
	if not hiddenByUs then
		hiddenByUs = true
		hiddenAt = GetTime()
		f:SetAlpha(0)
	end
	revealWatcher:Show()
end

revealWatcher:SetScript("OnUpdate", function(self)
	local f = LootWindow()
	if not f or not hiddenByUs then self:Hide(); return end
	local waited = GetTime() - hiddenAt
	local filled = LootWindowFilled(f)
	if filled == true
		or (filled == nil and waited >= LOOT_UNKNOWN_WAIT)
		or waited >= LOOT_REVEAL_TIMEOUT then
		RevealLootWindow()
	end
end)

local lootFrame = CreateFrame("Frame")
KUI:SafeRegisterEvent(lootFrame, "LOOT_READY")
KUI:SafeRegisterEvent(lootFrame, "LOOT_OPENED")
KUI:SafeRegisterEvent(lootFrame, "LOOT_SLOT_CLEARED")
KUI:SafeRegisterEvent(lootFrame, "LOOT_CLOSED")
lootFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "LOOT_CLOSED" then
		RevealLootWindow()
		hiddenThisLoot = false
		return
	end
	if event == "LOOT_READY" or event == "LOOT_OPENED" then

		if not hiddenThisLoot then
			hiddenThisLoot = true
			HideLootWindowUntilFilled()
		end
		if event == "LOOT_READY" then return end
	end
	AttemptFastLoot(event)
end)

function KUI:SetFastLoot(enabled)
	if not KUI.db then return end
	KUI.db.fastLoot = enabled
end
