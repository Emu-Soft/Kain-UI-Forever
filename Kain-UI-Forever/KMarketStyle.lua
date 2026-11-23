local addonName, KUI = ...
local M = KUI.Market
local UI = {}
M.UI = UI

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
UI.MEDIA = MEDIA .. "KMarket\\"
UI.LINE = UI.MEDIA .. "Line.tga"
UI.DOT = UI.MEDIA .. "Dot.tga"
UI.CIRCLE = UI.MEDIA .. "Circle.tga"
UI.ROUND = UI.MEDIA .. "Round.tga"
UI.WHITE = "Interface\\Buttons\\WHITE8x8"

local function Hex(h)
	return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255 }
end
UI.C = {
	surface = Hex("#0e1313"), lowest = Hex("#090e0e"), low = Hex("#161c1c"), medium = Hex("#1d2323"),
	high = Hex("#292f2f"), outline = Hex("#434949"), outlineMain = Hex("#99a0a0"),
	text = Hex("#ecf4f3"), textLow = Hex("#b8bfbf"),
	accent = Hex("#e0bb00"), accentDark = Hex("#564600"), onAccent = Hex("#473900"),
	error = Hex("#fd392e"), positive = Hex("#08d36b"),
}
local C = UI.C

function UI.Hex(key)
	local c = C[key]
	return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
function UI.Colorize(text, key) return "|cff" .. UI.Hex(key) .. text .. "|r" end

local FONT_FILES = {
	body = { regular = "Montserrat-Medium.ttf", medium = "Montserrat-SemiBold.ttf", bold = "Montserrat-Bold.ttf" },
	numeric = { regular = "Roboto-Medium.ttf", medium = "Roboto-Medium.ttf", bold = "Roboto-Medium.ttf" },
}
local SIZES = { h5 = 23, h6 = 19, p = 16, small = 13, ["x-small"] = 11 }
local fontObjects = {}

function UI.FontObject(style)
	local obj = fontObjects[style]
	if obj then return obj end
	local family, weight, size = style:match("^(%a+)/(%a+)/([%a%-%d]+)$")
	local files = FONT_FILES[family] or FONT_FILES.body
	local px = SIZES[size] or 13
	obj = CreateFont("KainUIForeverMarketFont_" .. style:gsub("[/%-]", "_"))
	local ok = obj:SetFont(MEDIA .. "Fonts\\" .. (files[weight] or files.regular), px, "")
	if ok == false then obj:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", px, "") end
	obj:SetShadowOffset(0, 0)
	fontObjects[style] = obj
	return obj
end

function UI.Font(fs, style) fs:SetFontObject(UI.FontObject(style)) end

function UI.TextColor(fs, key, alpha)
	local c = C[key] or C.text
	fs:SetTextColor(c[1], c[2], c[3], alpha or 1)
end

function UI.Text(parent, style, colorKey, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	UI.Font(fs, style or "body/regular/small")
	UI.TextColor(fs, colorKey or "text")
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

function UI.Fill(tex, key, alpha)
	local c = C[key] or C.surface
	tex:SetColorTexture(c[1], c[2], c[3], alpha or 1)
end

function UI.Tint(tex, key, alpha)
	local c = C[key] or C.text
	tex:SetVertexColor(c[1], c[2], c[3], alpha or 1)
end

local CUT = 16 / 64
function UI.Rounded(frame, key, radius, layer)
	radius = radius or 4
	local pieces = {}
	local function Piece(l, r, t, b)
		local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
		tex:SetTexture(UI.ROUND)
		tex:SetTexCoord(l, r, t, b)
		pieces[#pieces + 1] = tex
		return tex
	end
	local tl, tr = Piece(0, CUT, 0, CUT), Piece(1 - CUT, 1, 0, CUT)
	local bl, br = Piece(0, CUT, 1 - CUT, 1), Piece(1 - CUT, 1, 1 - CUT, 1)
	for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(radius, radius) end
	tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
	local top = Piece(CUT, 1 - CUT, 0, CUT)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	local bottom = Piece(CUT, 1 - CUT, 1 - CUT, 1)
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	local mid = Piece(0, 1, CUT, 1 - CUT)
	mid:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); mid:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	pieces.SetColor = function(_, k, a) for _, p in ipairs(pieces) do UI.Tint(p, k, a) end end
	pieces:SetColor(key, 1)
	frame.kmBackground = pieces
	return pieces
end

function UI.Panel(parent, key, radius)
	local f = CreateFrame("Frame", nil, parent)
	UI.Rounded(f, key or "low", radius or 4)
	return f
end

function UI.Rule(parent, key, vertical)
	local t = parent:CreateTexture(nil, "ARTWORK")
	UI.Fill(t, key or "outline")
	if vertical then t:SetWidth(1) else t:SetHeight(1) end
	return t
end

local BUTTON_COLORS = {
	primary = { bg = "accent", hover = "accent", text = "onAccent", alpha = 1, hoverAlpha = 0.85 },
	secondary = { bg = "high", hover = "outline", text = "text", alpha = 1, hoverAlpha = 1 },
	tertiary = { bg = "high", hover = "high", text = "textLow", alpha = 0, hoverAlpha = 1 },
}

function UI.Button(parent, text, width, height, kind, name)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(width or 100, height or 24)
	local style = BUTTON_COLORS[kind or "secondary"]
	b.kmBg = UI.Rounded(b, style.bg, 4)
	b.kmBg:SetColor(style.bg, style.alpha)
	local fs = UI.Text(b, "body/medium/small", style.text, "CENTER")
	fs:SetPoint("LEFT", 6, 0); fs:SetPoint("RIGHT", -6, 0)
	b.kmText = fs
	b.kmStyle = style
	fs:SetText(text or "")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnEnter", function(self)
		if self:IsEnabled() then self.kmBg:SetColor(style.hover, style.hoverAlpha) end
		if self.kmTip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.kmTip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.kmBg:SetColor(style.bg, style.alpha)
		if self.kmTip then GameTooltip:Hide() end
	end)
	b.SetKMEnabled = function(self, on)
		self:SetEnabled(on)
		UI.TextColor(self.kmText, on and style.text or "outlineMain")
		self:SetAlpha(on and 1 or 0.6)
	end
	return b
end

local function ButtonText(b, text) if b.kmText then b.kmText:SetText(text) end end
UI.ButtonText = ButtonText

function UI.Input(parent, width, height, numeric)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 120, height or 24)
	e:SetAutoFocus(false)
	UI.Rounded(e, "lowest", 4)
	e:SetFontObject(UI.FontObject(numeric and "numeric/regular/small" or "body/regular/small"))
	e:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
	e:SetTextInsets(8, 8, 0, 0)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return e
end

function UI.Toggle(parent, label, onChange)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(200, 20)
	local box = CreateFrame("Frame", nil, b)
	box:SetSize(14, 14)
	box:SetPoint("LEFT")
	UI.Rounded(box, "lowest", 3)
	local tick = box:CreateTexture(nil, "OVERLAY")
	tick:SetTexture(UI.ROUND)
	tick:SetPoint("TOPLEFT", 3, -3); tick:SetPoint("BOTTOMRIGHT", -3, 3)
	UI.Tint(tick, "accent")
	local fs = UI.Text(b, "body/regular/small", "text")
	fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
	fs:SetText(label)
	b.kmText = fs
	b.SetKMChecked = function(self, on) self.kmChecked = on and true or false; tick:SetShown(self.kmChecked) end
	b:SetScript("OnClick", function(self)
		self:SetKMChecked(not self.kmChecked)
		if onChange then onChange(self.kmChecked) end
	end)
	b:SetKMChecked(false)
	return b
end

function UI.Choice(parent, width, choices, onChange)
	local b = UI.Button(parent, "", width or 140, 24, "secondary")
	b.kmChoices = choices
	b.SetKMValue = function(self, value)
		self.kmValue = value
		for _, c in ipairs(self.kmChoices) do
			if c[1] == value then ButtonText(self, c[2] .. "  |cff99a0a0v|r"); return end
		end
		ButtonText(self, tostring(value))
	end
	b:SetScript("OnClick", function(self, button)
		local list, at = self.kmChoices, 1
		for i, c in ipairs(list) do if c[1] == self.kmValue then at = i end end
		at = button == "RightButton" and (at - 2) % #list + 1 or at % #list + 1
		self:SetKMValue(list[at][1])
		if onChange then onChange(list[at][1]) end
	end)
	return b
end

function UI.Tabs(parent, names, onSelect, style)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(28)
	bar.tabs = {}
	local x = 0
	for i, name in ipairs(names) do
		local t = CreateFrame("Button", nil, bar)
		local fs = UI.Text(t, style or "body/bold/small", "textLow", "CENTER")
		fs:SetPoint("CENTER")
		fs:SetText(name)
		local w = math.max(60, (fs:GetStringWidth() or 60) + 24)
		t:SetSize(w, 28)
		t:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + w + 4
		local line = t:CreateTexture(nil, "OVERLAY")
		line:SetHeight(2)
		line:SetPoint("BOTTOMLEFT", 6, 0); line:SetPoint("BOTTOMRIGHT", -6, 0)
		UI.Fill(line, "accent")
		t.kmText, t.kmLine, t.kmIndex = fs, line, i
		t:SetScript("OnClick", function() bar:Select(i) end)
		t:SetScript("OnEnter", function(self) if bar.selected ~= self.kmIndex then UI.TextColor(fs, "text") end end)
		t:SetScript("OnLeave", function(self) if bar.selected ~= self.kmIndex then UI.TextColor(fs, "textLow") end end)
		bar.tabs[i] = t
	end
	bar:SetWidth(x)
	function bar:Select(i)
		self.selected = i
		for j, t in ipairs(self.tabs) do
			t.kmLine:SetShown(j == i)
			UI.TextColor(t.kmText, j == i and "accent" or "textLow")
		end
		if onSelect then onSelect(i) end
	end
	return bar
end

function UI.List(parent, rowHeight, visible, build, fill)
	local f = CreateFrame("Frame", nil, parent)
	f:EnableMouseWheel(true)
	f.rows, f.items, f.offset = {}, {}, 0
	f.rowHeight, f.visible = rowHeight, visible
	for i = 1, visible do
		local row = CreateFrame("Button", nil, f)
		row:SetHeight(rowHeight)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
		row:SetPoint("TOPRIGHT", 0, -(i - 1) * rowHeight)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local hl = row:CreateTexture(nil, "BACKGROUND")
		hl:SetAllPoints()
		UI.Fill(hl, "high")
		hl:Hide()
		row.kmHighlight = hl
		row:SetScript("OnEnter", function(self) if not self.kmSelected then hl:Show() end end)
		row:SetScript("OnLeave", function(self) if not self.kmSelected then hl:Hide() end end)
		row.SetKMSelected = function(self, on)
			self.kmSelected = on
			hl:SetShown(on and true or false)
			UI.Fill(hl, on and "accentDark" or "high")
		end
		build(row)
		f.rows[i] = row
	end
	function f:SetItems(items)
		self.items = items
		self.offset = math.max(0, math.min(self.offset, #items - self.visible))
		self:Redraw()
	end
	function f:Redraw()
		for i, row in ipairs(self.rows) do
			local index = self.offset + i
			local item = self.items[index]
			row:SetShown(item ~= nil)
			if item ~= nil then
				row.kmItem, row.kmIndex = item, index
				fill(row, item, index)
			end
		end
	end
	f:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, #self.items - self.visible)
		self.offset = math.max(0, math.min(max, self.offset - delta * 3))
		self:Redraw()
	end)
	return f
end
