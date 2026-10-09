local _, KUI = ...

local BUTTON_SIZE = 32
local PADDING = 6
local SPACING = 4
local MAX_COLUMNS = 10

local BLIZZARD_KEEP = {
	MiniMapTracking = true, MinimapZoomIn = true, MinimapZoomOut = true, MiniMapMailFrame = true,
	QueueStatusButton = true, QueueStatusMinimapButton = true, GameTimeFrame = true, TimeManagerClockButton = true,
	MiniMapWorldMapButton = true, MiniMapLFGFrame = true, LFGMinimapFrame = true, MinimapBackdrop = true,
	MiniMapBattlefieldFrame = true, GarrisonLandingPageMinimapButton = true, ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame = true,
}

local enabled = false
local bin
local collected = {}
local info = setmetatable({}, { __mode = "k" })
local placing = false
local originalMouseUp
local clickReplaced = false
local dbIconHooked = false

local function DBIcon()
	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	return type(lib) == "table" and lib or nil
end

local function SafeName(f)
	local ok, n = pcall(function() return f:GetName() end)
	return ok and type(n) == "string" and n or nil
end

local function IsForbidden(f)
	local ok, forbidden = pcall(function() return f:IsForbidden() end)
	return not ok or forbidden
end

local function EnsureBin()
	if bin then return bin end
	bin = CreateFrame("Frame", "KainUIForeverMinimapButtonBin", UIParent, "BackdropTemplate")
	bin:SetFrameStrata("DIALOG")
	bin:SetClampedToScreen(true)
	bin:EnableMouse(true)
	if bin.SetBackdrop then
		bin:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		bin:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
		bin:SetBackdropBorderColor(0.55, 0.42, 0.18, 1)
	end
	bin:Hide()

	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "KainUIForeverMinimapButtonBin") end

	bin:SetScript("OnEvent", function(self, event)
		if event ~= "GLOBAL_MOUSE_DOWN" or not self:IsShown() then return end
		if self:IsMouseOver() or (Minimap and Minimap:IsMouseOver()) then return end
		self:Hide()
	end)
	bin:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
	bin:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
	local empty = bin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	empty:SetPoint("CENTER")
	empty:SetText("No addon minimap icons")
	bin.empty = empty
	return bin
end

local function SetLayer(b, strata, level, lockStrata, lockLevel)
	pcall(function()
		if b.SetFixedFrameStrata then b:SetFixedFrameStrata(false) end
		if b.SetFixedFrameLevel then b:SetFixedFrameLevel(false) end
		b:SetFrameStrata(strata)
		b:SetFrameLevel(level)
		if b.SetFixedFrameStrata then b:SetFixedFrameStrata(lockStrata) end
		if b.SetFixedFrameLevel then b:SetFixedFrameLevel(lockLevel) end
	end)
end

local function RaiseIntoBin(b)
	SetLayer(b, bin:GetFrameStrata(), bin:GetFrameLevel() + 5, true, true)
	pcall(function()
		if b.fadeOut and b.fadeOut.Stop then b.fadeOut:Stop() end
		b:SetAlpha(1)
	end)
end

local function Layout()
	if not bin then return end
	local shown = {}
	for _, b in ipairs(collected) do
		local i = info[b]
		local hiddenByAddon = i and i.hiddenByAddon and i.hiddenByAddon()
		if not hiddenByAddon then shown[#shown + 1] = b end
	end
	local n = #shown
	local cols = math.max(1, math.min(MAX_COLUMNS, math.ceil(math.sqrt(n))))
	local rows = math.max(1, math.ceil(n / cols))
	local w = PADDING * 2 + cols * BUTTON_SIZE + (cols - 1) * SPACING
	local h = PADDING * 2 + rows * BUTTON_SIZE + (rows - 1) * SPACING
	if n == 0 then w, h = 160, 36 end
	bin:SetSize(w, h)
	bin.empty:SetShown(n == 0)
	placing = true
	for index, b in ipairs(shown) do
		local col = (index - 1) % cols
		local row = math.floor((index - 1) / cols)
		RaiseIntoBin(b)
		pcall(function()
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", bin, "TOPLEFT", PADDING + col * (BUTTON_SIZE + SPACING), -(PADDING + row * (BUTTON_SIZE + SPACING)))
			b:Show()
		end)
	end

	for _, b in ipairs(collected) do
		local i = info[b]
		if i and i.hiddenByAddon and i.hiddenByAddon() then pcall(b.Hide, b) end
	end
	placing = false
end

local function Collect(b, name, hiddenByAddon)
	if info[b] or IsForbidden(b) then return end
	local points = {}
	for p = 1, b:GetNumPoints() do points[p] = { b:GetPoint(p) } end
	info[b] = { name = name, parent = b:GetParent(), points = points, hiddenByAddon = hiddenByAddon,
		wasShown = b:IsShown(), strata = b:GetFrameStrata(), level = b:GetFrameLevel(),
		fixedStrata = b.IsFrameStrataFixed and b:IsFrameStrataFixed() or false,
		fixedLevel = b.IsFrameLevelFixed and b:IsFrameLevelFixed() or false,
		alpha = b:GetAlpha() }
	collected[#collected + 1] = b
	b:SetParent(EnsureBin())

	pcall(b.RegisterForDrag, b)

	if not info[b].hooked then
		info[b].hooked = true
		hooksecurefunc(b, "SetPoint", function(self)
			if placing or not enabled or not info[self] then return end
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function() if enabled and info[self] then Layout() end end)
			end
		end)
	end
end

local function CollectAll()
	if not enabled then return end
	local before = #collected

	local lib = DBIcon()
	if lib and type(lib.GetButtonList) == "function" then
		local okList, names = pcall(lib.GetButtonList, lib)
		if okList and type(names) == "table" then
			for _, name in ipairs(names) do
				local okB, b = pcall(lib.GetMinimapButton, lib, name)
				if okB and b then
					Collect(b, name, function()
						return type(b.db) == "table" and b.db.hide == true
					end)
				end
			end
		end
	end

	for _, holder in ipairs({ Minimap, _G.MinimapBackdrop }) do
		if holder then
			for _, child in ipairs({ holder:GetChildren() }) do
				local name = SafeName(child)
				if name and not BLIZZARD_KEEP[name] and not name:find("^KainUIForever")
					and (name:find("^LibDBIcon10_") or name:find("MinimapButton")) and child.GetObjectType
					and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
					Collect(child, name, nil)
				end
			end
		end
	end
	if #collected ~= before then Layout() end
end

local function ReleaseAll()
	placing = true
	for _, b in ipairs(collected) do
		local i = info[b]
		if i then
			pcall(function()
				b:SetParent(i.parent or Minimap)
				if i.strata and i.level then SetLayer(b, i.strata, i.level, i.fixedStrata, i.fixedLevel) end
				if i.alpha then b:SetAlpha(i.alpha) end
				b:ClearAllPoints()
				for _, p in ipairs(i.points) do b:SetPoint(unpack(p)) end
				b:RegisterForDrag("LeftButton")
				if i.wasShown then b:Show() end
			end)
			info[b] = nil
		end
	end
	placing = false
	collected = {}

	local lib = DBIcon()
	if lib and type(lib.GetButtonList) == "function" and type(lib.Refresh) == "function" then
		local okList, names = pcall(lib.GetButtonList, lib)
		if okList and type(names) == "table" then
			for _, name in ipairs(names) do pcall(lib.Refresh, lib, name) end
		end
	end
end

local function Toggle()
	EnsureBin()
	if bin:IsShown() then bin:Hide(); return end
	CollectAll()
	Layout()

	local corner = KUI.SquareMinimapBorder
	if not (corner and corner.IsShown and corner:IsShown()) then corner = Minimap end
	bin:ClearAllPoints()
	if corner then
		bin:SetPoint("TOPRIGHT", corner, "BOTTOMLEFT", 0, 0)
	else
		local cx, cy = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		bin:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
	end
	bin:Show()
end

local function OnMinimapMouseUp(self, button, ...)
	if enabled and button == "RightButton" then
		Toggle()
		return
	end
	if originalMouseUp then return originalMouseUp(self, button, ...) end
end

local function ReplaceClick()
	if clickReplaced or not Minimap then return end
	originalMouseUp = Minimap:GetScript("OnMouseUp")
	Minimap:SetScript("OnMouseUp", OnMinimapMouseUp)
	clickReplaced = true
end

local function RestoreClick()
	if not clickReplaced or not Minimap then return end
	Minimap:SetScript("OnMouseUp", originalMouseUp)
	originalMouseUp = nil
	clickReplaced = false
end

local function Apply(on)
	on = on and true or false
	if on == enabled then
		if on then CollectAll() end
		return
	end
	enabled = on
	if on then
		ReplaceClick()
		CollectAll()

		local lib = DBIcon()
		if lib and not dbIconHooked and type(lib.Register) == "function" then
			dbIconHooked = true
			hooksecurefunc(lib, "Register", function()
				if enabled and C_Timer and C_Timer.After then C_Timer.After(0, CollectAll) end
			end)
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(2, CollectAll)
			C_Timer.After(6, CollectAll)
		end
	else
		if bin then bin:Hide() end
		RestoreClick()
		ReleaseAll()
	end
end

function KUI:ApplyMinimapButtonBin()
	local db = KUI.db
	Apply(type(db) == "table" and db.squareMinimap == true)
end

function KUI:MinimapButtonBinScanReport()
	print("|cff33ff99Kain-UI Forever|r minimap button box: " .. (enabled and "ON" or "off")
		.. ", right-click " .. (clickReplaced and "opens the box" or "not taken over")
		.. ", LibDBIcon " .. (DBIcon() and "found" or "not loaded"))
	if #collected == 0 then
		print("  no icons collected" .. (enabled and " (none found yet -- they're re-checked when the box opens)" or ""))
		return
	end
	local names = {}
	for _, b in ipairs(collected) do
		local i = info[b]
		local hidden = i and i.hiddenByAddon and i.hiddenByAddon()
		names[#names + 1] = (i and i.name or "?") .. (hidden and " (hidden by its addon)" or "")
	end
	print("  " .. #collected .. " icon(s): " .. table.concat(names, ", "))
end
