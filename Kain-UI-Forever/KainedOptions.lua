local addonName, KUI = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH = 750
local ROW = 28
local FADE_X, SLIDER_W = 128, 90
local ALPHA_X, SCALE_X, WIDTH_X, HEIGHT_X = 158, 296, 434, 572
local RIGHT_X = 410
local PARTY_X = 40
local PREVIEW_SIZE = 14

local panel
local refreshers = {}

local function Refresh()
	for _, fn in ipairs(refreshers) do pcall(fn) end
end

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function Whole(v) return tostring(math.floor(v + 0.5)) end

local function Checkbox(parent, x, y, label, get, set)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	check:SetSize(22, 22)
	if label then
		local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", check, "RIGHT", 2, 0)
		text:SetText(label)
		check.label = text
	end
	check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Refresh() end)
	refreshers[#refreshers + 1] = function() check:SetChecked(get() and true or false) end
	return check
end

local function Slider(parent, x, y, lo, hi, step, get, set, format)
	format = format or Percent
	local slider = KUI.CreateOptionsSlider(parent, x, y, SLIDER_W, lo, hi, step)
	local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	local syncing = false
	slider:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		value:SetText(format(v))
		if not syncing then set(v) end
	end)
	refreshers[#refreshers + 1] = function()
		syncing = true
		slider:SetValue(get())
		value:SetText(format(get()))
		syncing = false
	end
	return slider, value
end

local function Label(parent, x, y, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	return fs
end

local function Info(parent, anchor, title, text)
	if KUI.AddOptionsInfoButton then KUI.AddOptionsInfoButton(parent, anchor, title, text) end
end

local function Button(parent, x, y, width, text, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPLEFT", x, y)
	button:SetText(text)
	button:SetScript("OnClick", function(self) onClick(self); Refresh() end)
	return button
end

local function Dropdown(parent, x, y, width, choices, get, set)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPLEFT", x, y)
	local function Sync()
		local current = get()
		for _, c in ipairs(choices()) do
			if c.key == current then button:SetText(c.label) end
		end
	end
	local function Pick(key) set(key); Refresh() end
	local flat = KUI.GCDWatch and KUI.GCDWatch.FlatMenu
	if flat and flat.DownArrow then flat.DownArrow(button) end
	button:SetScript("OnClick", function(self)
		if flat and flat.Open then
			flat.Open(self, function(_, root)
				for _, c in ipairs(choices()) do
					local radio = root:CreateRadio(c.label, function() return get() == c.key end, function() Pick(c.key) end)
					if c.font and radio.SetFont then radio:SetFont(c.font, PREVIEW_SIZE, c.flags) end
				end
			end)
			return
		end
		local list, index = choices(), 1
		for i, c in ipairs(list) do
			if c.key == get() then index = i % #list + 1 end
		end
		Pick(list[index].key)
	end)
	refreshers[#refreshers + 1] = Sync
	return button
end

local function Build()
	local f = CreateFrame("Frame", "KainUIForeverKainedOptionsFrame", UIParent, "BackdropTemplate")
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	table.insert(UISpecialFrames, "KainUIForeverKainedOptionsFrame")

	if KUI.DressOptionsPanel then
		KUI.DressOptionsPanel(f, "KainUIForeverKainedOptionsCloseGem")
	else
		if f.SetBackdrop then
			f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
			f:SetBackdropColor(0, 0, 0, 0.85)
			f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
		end
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
	end

	Label(f, 24, -18, "Kained Unit Frames", "GameFontNormalLarge")
	local status = Label(f, 24, -42, "")
	status:SetWidth(WIDTH - 260)
	status:SetJustifyH("LEFT")
	refreshers[#refreshers + 1] = function()
		if KUI:KainedFramesActive() then
			status:SetText(KUI:IsKainedUnlocked()
				and "|cffffff00Unlocked:|r |cff999999frames stay fully shown while you move them. Lock to see them fade.|r"
				or "|cff999999Drag the frames with Unlock below, or |cffffff00/kuf unlock|r|cff999999.|r")
		else
			status:SetText("|cffff8060Not in use: pick Kained Unit Frames under Style in /kui (Unit Frames). Changes here are kept for when you do.|r")
		end
	end

	local y = -70
	Label(f, 16, y, "Frame", "GameFontNormalSmall")
	local fadeHeader = Label(f, FADE_X, y, "Fade", "GameFontNormalSmall")
	Info(f, fadeHeader, "Combat fader",
		"Works like Shadowed Unit Frames' combat fader. A ticked frame fades out when you're out of combat and not casting, and its own unit is at full health and mana, energy or focus. It comes back as soon as any of that changes. Your own frame also stays while you have a target. Faded alpha is how much still shows when faded: 0% hides it.")
	Label(f, ALPHA_X + 26, y, "Faded alpha", "GameFontNormalSmall")
	Label(f, SCALE_X, y, "Scale", "GameFontNormalSmall")
	Label(f, WIDTH_X, y, "Width", "GameFontNormalSmall")
	local heightHeader = Label(f, HEIGHT_X, y, "Height", "GameFontNormalSmall")
	Info(f, heightHeader, "Width and height",
		"The frame's own size in pixels, before Scale. Bars, portrait and text fit themselves to it. Party sets all four members at once. Changes wait until you're out of combat.")
	y = y - 18

	local function W(key) return (KUI:GetKainedSize(key)) end
	local function H(key) return select(2, KUI:GetKainedSize(key)) end
	for _, item in ipairs(KUI.KAINED_FRAMES) do
		local key = item.key
		Label(f, 16, y - 5, item.label)
		Checkbox(f, FADE_X - 4, y,
			nil,
			function() return KUI:GetKainedFade(key) end,
			function(on) KUI:SetKainedFade(key, on) end)
		local alpha, alphaValue = Slider(f, ALPHA_X, y - 3, 0, 1, 0.05,
			function() return KUI:GetKainedFadeAlpha(key) end,
			function(v) KUI:SetKainedFadeAlpha(key, v) end)
		refreshers[#refreshers + 1] = function()
			local on = KUI:GetKainedFade(key)
			alpha:SetShown(on)
			alphaValue:SetShown(on)
		end
		Slider(f, SCALE_X, y - 3, KUI.KAINED_SCALE_MIN, KUI.KAINED_SCALE_MAX, 0.05,
			function() return KUI:GetKainedScale(key) end,
			function(v) KUI:SetKainedScale(key, v) end)
		Slider(f, WIDTH_X, y - 3, KUI.KAINED_WIDTH_MIN, KUI.KAINED_WIDTH_MAX, 1,
			function() return W(key) end,
			function(v) KUI:SetKainedSize(key, v, nil) end, Whole)
		Slider(f, HEIGHT_X, y - 3, KUI.KAINED_HEIGHT_MIN, KUI.KAINED_HEIGHT_MAX, 1,
			function() return H(key) end,
			function(v) KUI:SetKainedSize(key, nil, v) end, Whole)
		y = y - ROW
	end

	y = y - 10
	local top = y

	Label(f, PARTY_X, y, "Party", "GameFontNormalSmall")
	y = y - 18
	local sideways = Checkbox(f, PARTY_X - 4, y, "Stack party frames side by side",
		function() return KUI:GetKainedPartyHorizontal() end,
		function(on) KUI:SetKainedPartyHorizontal(on) end)
	Info(f, sideways.label, "Stack party frames side by side",
		"Lines your party up in a row instead of a column. The top-left corner stays where it is; /kuf unlock to move the row.")
	y = y - ROW
	local rangeLook = Checkbox(f, PARTY_X - 4, y, "Grey out party members out of range",
		function() return KUI:GetKainedPartyLook("range") end,
		function(on) KUI:SetKainedPartyLook("range", on) end)
	Info(f, rangeLook.label, "Out of range",
		"A party member your heals can't reach fades with a grey wash over their bars; names and numbers stay readable on top. The red in-combat edge still shows at full strength. Untick for just a light fade instead. Offline members always show fully grey at full strength.")
	y = y - ROW
	local combatLook = Checkbox(f, PARTY_X - 4, y, "Red edge on party members in combat",
		function() return KUI:GetKainedPartyLook("combat") end,
		function(on) KUI:SetKainedPartyLook("combat", on) end)
	Info(f, combatLook.label, "In combat",
		"A party member who is fighting gets a red edge and crossed swords in the corner. Members out of combat keep a plain frame, so you can tell at a glance who has pulled and who hasn't.")
	local bottom = y - ROW

	y = top
	local DROP_X, DROP_W = RIGHT_X + 60, 200
	Label(f, RIGHT_X, y, "Text", "GameFontNormalSmall")
	y = y - 18
	local function FontPart(i) return select(i, KUI:GetKainedFont()) end
	local function FamilyOf(key)
		for _, family in ipairs(KUI.KAINED_FONTS) do
			if family.key == key then return family end
		end
	end
	Label(f, RIGHT_X, y - 5, "Font")
	Dropdown(f, DROP_X, y, DROP_W,
		function()
			local list, style = {}, FontPart(2)
			for _, family in ipairs(KUI.KAINED_FONTS) do
				list[#list + 1] = { key = family.key, label = family.label, font = family.styles[style] or family.styles.regular or select(2, next(family.styles)) }
			end
			return list
		end,
		function() return FontPart(1) end,
		function(key) KUI:SetKainedFont(key) end)
	y = y - ROW
	Label(f, RIGHT_X, y - 5, "Style")
	Dropdown(f, DROP_X, y, DROP_W,
		function()
			local list, family = {}, FamilyOf(FontPart(1))
			for _, style in ipairs(KUI.KAINED_FONT_STYLES) do
				if family and family.styles[style.key] then
					list[#list + 1] = { key = style.key, label = style.label, font = family.styles[style.key] }
				end
			end
			return list
		end,
		function() return FontPart(2) end,
		function(key) KUI:SetKainedFont(nil, key) end)
	y = y - ROW
	Label(f, RIGHT_X, y - 5, "Outline")
	Dropdown(f, DROP_X, y, DROP_W,
		function()
			local list, family = {}, FamilyOf(FontPart(1))
			local file = family and family.styles[FontPart(2)]
			for _, outline in ipairs(KUI.KAINED_FONT_OUTLINES) do
				list[#list + 1] = { key = outline.key, label = outline.label, font = file, flags = outline.key }
			end
			return list
		end,
		function() return FontPart(3) end,
		function(key) KUI:SetKainedFont(nil, nil, key) end)

	y = math.min(bottom, y - ROW) - 20

	local buttonsX = math.floor((WIDTH - 420) / 2)
	local lockButton = Button(f, buttonsX, y, 120, "Unlock", function()
		SlashCmdList["KAINUIKUF"](KUI:IsKainedUnlocked() and "lock" or "unlock")
	end)
	refreshers[#refreshers + 1] = function() lockButton:SetText(KUI:IsKainedUnlocked() and "Lock" or "Unlock") end
	Button(f, buttonsX + 130, y, 130, "Reset positions", function() SlashCmdList["KAINUIKUF"]("reset") end)
	Button(f, buttonsX + 270, y, 150, "Reset sizes and scales", function() KUI:ResetKainedScales() end)

	f:SetSize(WIDTH, -y + 72)
	f:SetScript("OnShow", Refresh)
	panel = f
	return f
end

function KUI:ToggleKainedOptions()
	local f = panel or Build()
	f:SetShown(not f:IsShown())
end
