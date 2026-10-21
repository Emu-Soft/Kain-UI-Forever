local addonName, KUI = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH = 430
local ROW = 28
local FADE_X, SCALE_X, SCALE_W = 140, 190, 170

local panel
local refreshers = {}

local function Refresh()
	for _, fn in ipairs(refreshers) do pcall(fn) end
end

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

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
	check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	refreshers[#refreshers + 1] = function() check:SetChecked(get() and true or false) end
	return check
end

local function Slider(parent, x, y, lo, hi, step, get, set)
	local slider = KUI.CreateOptionsSlider(parent, x, y, SCALE_W, lo, hi, step)
	local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	local syncing = false
	slider:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		value:SetText(Percent(v))
		if not syncing then set(v) end
	end)
	refreshers[#refreshers + 1] = function()
		syncing = true
		slider:SetValue(get())
		value:SetText(Percent(get()))
		syncing = false
	end
	return slider
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
					root:CreateRadio(c.label, function() return get() == c.key end, function() Pick(c.key) end)
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
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
		f:SetBackdropColor(0, 0, 0, 0.85)
		f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	end
	f:Hide()
	table.insert(UISpecialFrames, "KainUIForeverKainedOptionsFrame")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

	Label(f, 16, -14, "Kained Unit Frames", "GameFontNormalLarge")
	local status = Label(f, 16, -38, "")
	status:SetWidth(WIDTH - 32)
	status:SetJustifyH("LEFT")
	refreshers[#refreshers + 1] = function()
		if KUI:KainedFramesActive() then
			status:SetText("|cff999999Drag the frames with Unlock below, or |cffffff00/kuf unlock|r|cff999999.|r")
		else
			status:SetText("|cffff8060Not in use: pick Kained Unit Frames under Style in /kui (Unit Frames). Changes here are kept for when you do.|r")
		end
	end

	local y = -66
	Label(f, 16, y, "Frame", "GameFontNormalSmall")
	local fadeHeader = Label(f, FADE_X, y, "Fade", "GameFontNormalSmall")
	Info(f, fadeHeader, "Combat fader",
		"Ticked frames fade out when you're out of combat, at full health and power, not casting and with no target, and come back as soon as any of that changes.")
	Label(f, SCALE_X, y, "Scale", "GameFontNormalSmall")
	y = y - 18

	for _, item in ipairs(KUI.KAINED_FRAMES) do
		local key = item.key
		Label(f, 16, y - 5, item.label)
		Checkbox(f, FADE_X - 4, y,
			nil,
			function() return KUI:GetKainedFade(key) end,
			function(on) KUI:SetKainedFade(key, on) end)
		Slider(f, SCALE_X, y - 3, KUI.KAINED_SCALE_MIN, KUI.KAINED_SCALE_MAX, 0.05,
			function() return KUI:GetKainedScale(key) end,
			function(v) KUI:SetKainedScale(key, v) end)
		y = y - ROW
	end

	y = y - 6
	local alphaLabel = Label(f, 16, y - 2, "Faded opacity")
	Info(f, alphaLabel, "Faded opacity", "How much of a faded frame still shows. 0% hides it completely.")
	Slider(f, SCALE_X, y, 0, 1, 0.05,
		function() return KUI:GetKainedFadeAlpha() end,
		function(v) KUI:SetKainedFadeAlpha(v) end)
	y = y - 32

	local sideways = Checkbox(f, 12, y, "Stack party frames side by side",
		function() return KUI:GetKainedPartyHorizontal() end,
		function(on) KUI:SetKainedPartyHorizontal(on) end)
	Info(f, sideways.label, "Stack party frames side by side",
		"Lines your party up in a row instead of a column. The top-left corner stays where it is; /kuf unlock to move the row.")
	y = y - 34

	Label(f, 16, y, "Text", "GameFontNormalSmall")
	y = y - 20
	local function FontPart(i) return select(i, KUI:GetKainedFont()) end
	Label(f, 16, y - 5, "Font")
	Dropdown(f, FADE_X, y, 200,
		function() return KUI.KAINED_FONTS end,
		function() return FontPart(1) end,
		function(key) KUI:SetKainedFont(key) end)
	y = y - ROW
	Label(f, 16, y - 5, "Style")
	Dropdown(f, FADE_X, y, 200,
		function()
			local list, current = {}, FontPart(1)
			for _, family in ipairs(KUI.KAINED_FONTS) do
				if family.key == current then
					for _, style in ipairs(KUI.KAINED_FONT_STYLES) do
						if family.styles[style.key] then list[#list + 1] = style end
					end
				end
			end
			return list
		end,
		function() return FontPart(2) end,
		function(key) KUI:SetKainedFont(nil, key) end)
	y = y - ROW
	Label(f, 16, y - 5, "Outline")
	Dropdown(f, FADE_X, y, 200,
		function() return KUI.KAINED_FONT_OUTLINES end,
		function() return FontPart(3) end,
		function(key) KUI:SetKainedFont(nil, nil, key) end)
	y = y - 40

	local lockButton = Button(f, 16, y, 120, "Unlock", function()
		SlashCmdList["KAINUIKUF"](KUI:IsKainedUnlocked() and "lock" or "unlock")
	end)
	refreshers[#refreshers + 1] = function() lockButton:SetText(KUI:IsKainedUnlocked() and "Lock" or "Unlock") end
	Button(f, 146, y, 130, "Reset positions", function() SlashCmdList["KAINUIKUF"]("reset") end)
	Button(f, 286, y, 120, "Reset scales", function() KUI:ResetKainedScales() end)

	f:SetSize(WIDTH, -y + 38)
	f:SetScript("OnShow", Refresh)
	panel = f
	return f
end

function KUI:ToggleKainedOptions()
	local f = panel or Build()
	f:SetShown(not f:IsShown())
end
