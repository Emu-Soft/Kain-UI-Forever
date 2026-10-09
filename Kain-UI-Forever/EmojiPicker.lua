local _, KUI = ...

local focusLostAt = setmetatable({}, { __mode = "k" })
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", function(_, editBox)
		if editBox then focusLostAt[editBox] = GetTime() end
	end, "KainUIForeverEmojiPicker")
	EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, editBox)
		if editBox then focusLostAt[editBox] = nil end
	end, "KainUIForeverEmojiPicker")
end

local BUTTON_SIZE = 16
local BUTTON_HOVER_SIZE = 19
local BUTTON_REST_ALPHA = 0.8
local DEFAULT_FACE = "\240\159\153\130"

local COLS, ROWS = 9, 7
local CELL = 30
local ICON = 22
local PAD = 10

local COLOR_INPUT = { 0.12, 0.13, 0.14, 1 }
local COLOR_HOVER = { 1, 1, 1, 0.10 }
local COLOR_DIVIDER = { 0.11, 0.11, 0.13, 1 }

local COLOR_PANEL_BG = { 0, 0, 0, 0.85 }
local COLOR_PANEL_BORDER = { 1, 1, 1, 0.5 }

local function FirstCodepoint(s)
	local b1, b2, b3, b4 = s:byte(1, 4)
	if not b1 then return 0 end
	if b1 < 0x80 then return b1 end
	if b1 < 0xE0 then return (b1 % 0x20) * 0x40 + (b2 % 0x40) end
	if b1 < 0xF0 then return (b1 % 0x10) * 0x1000 + (b2 % 0x40) * 0x40 + (b3 % 0x40) end
	return (b1 % 0x08) * 0x40000 + (b2 % 0x40) * 0x1000 + (b3 % 0x40) * 0x40 + (b4 % 0x40)
end

local FACE_RANGES = {
	{ 0x1F600, 0x1F637 }, { 0x1F641, 0x1F644 }, { 0x1F910, 0x1F915 },
	{ 0x1F917, 0x1F917 }, { 0x1F920, 0x1F925 }, { 0x1F927, 0x1F92F },
	{ 0x1F970, 0x1F976 }, { 0x1F978, 0x1F97A }, { 0x1F9D0, 0x1F9D0 },
	{ 0x1FAE0, 0x1FAE5 }, { 0x1FAE8, 0x1FAE9 }, { 0x2639, 0x2639 },
	{ 0x263A, 0x263A },
}
local function IsFace(cp)
	for _, r in ipairs(FACE_RANGES) do
		if cp >= r[1] and cp <= r[2] then return true end
	end
	return false
end

local allEmoji, faces

local function BuildLists()
	if allEmoji then return end
	allEmoji, faces = {}, {}
	local registry = KUI.EMOJI_REGISTRY or {}
	local aliases = {}
	for code, char in pairs(KUI.EMOJI_SHORTCODES or {}) do
		aliases[char] = aliases[char] or {}
		table.insert(aliases[char], code)
	end
	for char, entry in pairs(registry) do
		local names = aliases[char] or { entry.name }
		table.sort(names)
		local cp = FirstCodepoint(char)
		local e = {
			char = char, file = entry.file, name = entry.name,
			search = table.concat(names, " "):lower(),
			cp = cp, face = IsFace(cp),
		}
		table.insert(allEmoji, e)
		if e.face then table.insert(faces, e) end
	end
	local function order(a, b)
		if a.face ~= b.face then return a.face end
		if a.cp ~= b.cp then return a.cp < b.cp end
		if #a.char ~= #b.char then return #a.char < #b.char end
		return a.char < b.char
	end
	table.sort(allEmoji, order)
	table.sort(faces, order)
end

local function IconFor(e)
	return (KUI.EMOJI_ICON_PATH or "") .. e.file
end

local function Enabled()
	return not KUI.db or KUI.db.emojiChat ~= false
end

local function EditBoxFor(chatFrame)
	local name = chatFrame.GetName and chatFrame:GetName()
	return (name and _G[name .. "EditBox"]) or chatFrame.editBox
end

local function InsertEmoji(chatFrame, char)
	local editBox = EditBoxFor(chatFrame)
	if not editBox then return end

	if KUI.IsChatLockedDown and KUI:IsChatLockedDown() then
		print("|cffff6060Kain-UI Forever:|r emoji can't be added during a boss encounter -- type the :shortcode: instead (e.g. :fire:).")
		return
	end
	if not editBox:IsShown() then

		if ChatFrame_OpenChat then
			ChatFrame_OpenChat("", chatFrame)
		elseif ChatEdit_ActivateChat then
			ChatEdit_ActivateChat(editBox)
		end
	elseif not editBox:HasFocus() then

		editBox:SetFocus()
	end
	editBox:Insert(char)
end

local picker
local targetChatFrame
local results = {}
local offset = 0
local AllChatFrames

local function PositionCatcherStrips(strips)
	local uiLeft, uiRight = UIParent:GetLeft(), UIParent:GetRight()
	local uiTop, uiBottom = UIParent:GetTop(), UIParent:GetBottom()

	local leftV, rightV, topV, bottomV
	for _, frame in ipairs(AllChatFrames()) do
		if frame:IsShown() then
			local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
			if l and (not leftV or l < leftV) then leftV = l end
			if r and (not rightV or r > rightV) then rightV = r end
			if t and (not topV or t > topV) then topV = t end
			if b and (not bottomV or b < bottomV) then bottomV = b end
		end
	end

	leftV, rightV = leftV or uiLeft, rightV or uiLeft
	topV, bottomV = topV or uiTop, bottomV or uiTop

	strips.top:ClearAllPoints()
	strips.top:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
	strips.top:SetSize(math.max(0, uiRight - uiLeft), math.max(0, uiTop - topV))

	strips.bottom:ClearAllPoints()
	strips.bottom:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT")
	strips.bottom:SetSize(math.max(0, uiRight - uiLeft), math.max(0, bottomV - uiBottom))

	strips.left:ClearAllPoints()
	strips.left:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -(uiTop - topV))
	strips.left:SetSize(math.max(0, leftV - uiLeft), math.max(0, topV - bottomV))

	strips.right:ClearAllPoints()
	strips.right:SetPoint("TOPLEFT", UIParent, "TOPLEFT", rightV - uiLeft, -(uiTop - topV))
	strips.right:SetSize(math.max(0, uiRight - rightV), math.max(0, topV - bottomV))
end

local function FlatBackdrop(frame, bg, border)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function MaxOffset()
	return math.max(0, math.ceil(#results / COLS) - ROWS)
end

local function ShowFooter(e)
	if e then
		picker.footerIcon:SetTexture(IconFor(e))
		picker.footerIcon:Show()
		picker.footerText:SetText(":" .. e.name .. ":")
	else
		picker.footerIcon:Hide()
		picker.footerText:SetText(#results > 0 and "|cff949ba4Shift-click to pick more than one|r" or "")
	end
end

local function RefreshGrid()
	for i, cell in ipairs(picker.cells) do
		local e = results[offset * COLS + i]
		cell.entry = e
		if e then
			cell.icon:SetTexture(IconFor(e))
			cell:Show()
		else
			cell:Hide()
		end
	end
	picker.empty:SetShown(#results == 0)
	local maxOffset = MaxOffset()
	picker.scroll:SetMinMaxValues(0, maxOffset)
	picker.scroll:SetShown(maxOffset > 0)
	picker.scroll.syncing = true
	picker.scroll:SetValue(offset)
	picker.scroll.syncing = false
end

local function ApplySearch()
	BuildLists()
	local query = (picker.search:GetText() or ""):lower():gsub(":", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then
		results = allEmoji
	else
		results = {}
		for _, e in ipairs(allEmoji) do
			if e.search:find(query, 1, true) then table.insert(results, e) end
		end
	end
	offset = 0
	picker.searchHint:SetShown(query == "")
	RefreshGrid()
	ShowFooter(nil)
end

local function Scroll(delta)
	local new = math.max(0, math.min(MaxOffset(), offset - delta))
	if new ~= offset then
		offset = new
		RefreshGrid()
	end
end

local function Pick(e)
	if not e or not targetChatFrame then return end
	InsertEmoji(targetChatFrame, e.char)
	if not IsShiftKeyDown() then picker:Hide() end
end

local function BuildPicker()
	local width = PAD * 2 + COLS * CELL + 10
	local height = PAD + 28 + 6 + ROWS * CELL + 6 + 34 + PAD

	picker = CreateFrame("Frame", "KainUIForeverEmojiPicker", UIParent, "BackdropTemplate")
	picker:SetSize(width, height)
	picker:SetFrameStrata("DIALOG")
	picker:SetClampedToScreen(true)
	picker:EnableMouse(true)
	picker:Hide()
	FlatBackdrop(picker, COLOR_PANEL_BG, COLOR_PANEL_BORDER)

	if KUI.ApplyDiamondBorder then KUI:ApplyDiamondBorder(picker) end
	tinsert(UISpecialFrames, "KainUIForeverEmojiPicker")

	local search = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
	search:SetPoint("TOPLEFT", PAD, -PAD)
	search:SetPoint("TOPRIGHT", -PAD, -PAD)
	search:SetHeight(28)
	search:SetAutoFocus(false)
	search:SetFontObject(ChatFontNormal)
	search:SetTextInsets(8, 8, 0, 0)
	FlatBackdrop(search, COLOR_INPUT, COLOR_INPUT)
	search:SetScript("OnTextChanged", ApplySearch)
	search:SetScript("OnEscapePressed", function() picker:Hide() end)
	search:SetScript("OnEnterPressed", function()
		if search:GetText() == "" then

			if KUI.IsChatLockedDown and KUI:IsChatLockedDown() then
				picker:Hide()
				return
			end
			if ChatFrame_OpenChat and targetChatFrame then
				ChatFrame_OpenChat("", targetChatFrame)
			end
			return
		end
		Pick(results[1])
	end)
	picker.search = search

	local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText("Find the perfect emoji")
	picker.searchHint = hint

	local grid = CreateFrame("Frame", nil, picker)
	grid:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -6)
	grid:SetSize(COLS * CELL, ROWS * CELL)
	grid:EnableMouseWheel(true)
	grid:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
	grid:SetScript("OnLeave", function() ShowFooter(nil) end)

	picker.cells = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local cell = CreateFrame("Button", nil, grid)
			cell:SetSize(CELL, CELL)
			cell:SetPoint("TOPLEFT", col * CELL, -row * CELL)
			local hl = cell:CreateTexture(nil, "BACKGROUND")
			hl:SetAllPoints()
			hl:SetColorTexture(COLOR_HOVER[1], COLOR_HOVER[2], COLOR_HOVER[3], COLOR_HOVER[4])
			hl:Hide()
			cell.hl = hl
			local icon = cell:CreateTexture(nil, "ARTWORK")
			icon:SetSize(ICON, ICON)
			icon:SetPoint("CENTER")
			cell.icon = icon
			cell:EnableMouseWheel(true)
			cell:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
			cell:SetScript("OnEnter", function(self) self.hl:Show() ShowFooter(self.entry) end)
			cell:SetScript("OnLeave", function(self) self.hl:Hide() end)
			cell:SetScript("OnClick", function(self) Pick(self.entry) end)
			table.insert(picker.cells, cell)
		end
	end

	local empty = grid:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("CENTER")
	empty:SetText("No emoji match that search.")
	picker.empty = empty

	local scroll = CreateFrame("Slider", nil, picker)
	scroll:SetOrientation("VERTICAL")
	scroll:SetPoint("TOPLEFT", grid, "TOPRIGHT", 3, 0)
	scroll:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 3, 0)
	scroll:SetWidth(6)
	scroll:SetValueStep(1)
	if scroll.SetObeyStepOnDrag then scroll:SetObeyStepOnDrag(true) end
	local track = scroll:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0.15, 0.16, 0.17, 1)
	local thumb = scroll:CreateTexture(nil, "ARTWORK")
	thumb:SetColorTexture(0.10, 0.10, 0.11, 1)
	thumb:SetSize(6, 36)
	scroll:SetThumbTexture(thumb)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
	scroll:SetScript("OnValueChanged", function(self, value)
		if self.syncing then return end
		local new = math.floor(value + 0.5)
		if new ~= offset then
			offset = new
			RefreshGrid()
		end
	end)
	picker.scroll = scroll

	local footerIcon = picker:CreateTexture(nil, "ARTWORK")
	footerIcon:SetSize(24, 24)
	footerIcon:SetPoint("BOTTOMLEFT", PAD + 2, PAD + 5)
	picker.footerIcon = footerIcon
	local footerText = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	footerText:SetPoint("LEFT", footerIcon, "RIGHT", 8, 0)
	footerText:SetPoint("RIGHT", picker, "RIGHT", -PAD, 0)
	footerText:SetJustifyH("LEFT")
	footerText:SetWordWrap(false)
	picker.footerText = footerText
	local divider = picker:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(COLOR_DIVIDER[1], COLOR_DIVIDER[2], COLOR_DIVIDER[3], 1)
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT", PAD, PAD + 34)
	divider:SetPoint("BOTTOMRIGHT", -PAD, PAD + 34)

	picker:SetScript("OnHide", function()
		search:ClearFocus()
		targetChatFrame = nil
		if picker.catcherStrips then
			for _, strip in pairs(picker.catcherStrips) do strip:Hide() end
		end
	end)

	local function HandleCatcherClick(self, button)
		self:SetPropagateMouseClicks(button == "RightButton")
		if button == "LeftButton" then picker:Hide() end
	end
	local function BuildStrip()
		local strip = CreateFrame("Frame", nil, UIParent)
		strip:SetFrameStrata("HIGH")
		strip:EnableMouse(true)
		strip:Hide()
		strip:SetScript("OnMouseDown", HandleCatcherClick)
		strip:SetScript("OnMouseUp", HandleCatcherClick)
		return strip
	end
	picker.catcherStrips = {
		top = BuildStrip(), bottom = BuildStrip(),
		left = BuildStrip(), right = BuildStrip(),
	}
end

local function TogglePicker(holder, chatFrame)
	if not picker then BuildPicker() end
	if picker:IsShown() and targetChatFrame == chatFrame then
		picker:Hide()
		return
	end
	targetChatFrame = chatFrame
	picker:ClearAllPoints()
	picker:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 6, 8)
	picker:Show()
	if picker.catcherStrips then
		PositionCatcherStrips(picker.catcherStrips)
		for _, strip in pairs(picker.catcherStrips) do

			strip:SetPropagateMouseClicks(true)
			strip:Show()
		end
	end
	picker.search:SetText("")
	ApplySearch()
	picker.search:SetFocus()

	local editBox = EditBoxFor(chatFrame)

	if editBox and not editBox:IsShown() and focusLostAt[editBox]
		and (GetTime() - focusLostAt[editBox]) < 0.5
		and not (KUI.IsChatLockedDown and KUI:IsChatLockedDown()) then
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if not editBox:IsShown() then editBox:Show() end
			end)
		else
			editBox:Show()
		end
	end
end

local buttons = setmetatable({}, { __mode = "k" })

local DEFAULT_OFFSET = { x = -12, y = 12 }

if KUI.defaults then
	KUI.defaults.emojiButtonUnlocked = false
	KUI.defaults.emojiButtonOffset = { x = DEFAULT_OFFSET.x, y = DEFAULT_OFFSET.y }
end

local function CurrentOffset()
	local o = KUI.db and KUI.db.emojiButtonOffset
	if o and type(o.x) == "number" and type(o.y) == "number" then return o end
	return DEFAULT_OFFSET
end

local function Unlocked()
	return KUI.db and KUI.db.emojiButtonUnlocked and true or false
end

local function PlaceHolder(holder)
	local o = CurrentOffset()
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", holder.chatFrame, "BOTTOMRIGHT", o.x, o.y)
end

local function PlaceAll()
	for _, button in pairs(buttons) do PlaceHolder(button.holder) end
end

local function ApplyUnlockedLook(button)
	local unlocked = Unlocked()
	button.holder.unlockTint:SetShown(unlocked)
	if unlocked then button:RegisterForDrag("LeftButton") else button:RegisterForDrag() end
end

local function SetButtonFace(button, e)
	button.face = e
	button.icon:SetTexture(IconFor(e))
end

local function SetButtonHover(button, hovered)
	local size = hovered and BUTTON_HOVER_SIZE or BUTTON_SIZE
	button:SetSize(size, size)
	button.icon:SetDesaturated(not hovered)
	button.icon:SetAlpha(hovered and 1 or BUTTON_REST_ALPHA)
end

local function RandomFace(except)
	BuildLists()
	if #faces == 0 then return nil end
	if #faces == 1 then return faces[1] end
	local e
	repeat e = faces[math.random(#faces)] until e ~= except
	return e
end

local function DefaultFace()
	BuildLists()
	for _, e in ipairs(faces) do
		if e.char == DEFAULT_FACE then return e end
	end
	return faces[1]
end

local function AddButton(chatFrame)
	if buttons[chatFrame] then return end

	if chatFrame == _G.COMBATLOG then return end
	local start = DefaultFace()
	if not start then return end

	local holder = CreateFrame("Frame", nil, chatFrame)
	holder:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	holder:SetFrameLevel(chatFrame:GetFrameLevel() + 10)
	holder:SetMovable(true)
	holder:SetClampedToScreen(true)
	holder.chatFrame = chatFrame
	PlaceHolder(holder)

	local tint = holder:CreateTexture(nil, "BACKGROUND")
	tint:SetPoint("CENTER")
	tint:SetSize(BUTTON_HOVER_SIZE + 6, BUTTON_HOVER_SIZE + 6)
	tint:SetColorTexture(0.2, 0.85, 0.3, 0.35)
	holder.unlockTint = tint

	local button = CreateFrame("Button", nil, holder)

	button:SetPoint("CENTER", holder, "CENTER")
	button.holder = holder
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	SetButtonFace(button, start)
	SetButtonHover(button, false)

	button:SetScript("OnEnter", function(self)
		local e = RandomFace(self.face)
		if e then SetButtonFace(self, e) end
		SetButtonHover(self, true)
	end)
	button:SetScript("OnLeave", function(self) SetButtonHover(self, false) end)
	button:SetScript("OnClick", function(self) TogglePicker(self.holder, chatFrame) end)

	button:SetScript("OnDragStart", function(self)
		if Unlocked() then
			self.holder:StartMoving()
			if KUI.BeginAlignDrag then KUI:BeginAlignDrag(self.holder) end
		end
	end)
	button:SetScript("OnDragStop", function(self)
		local h = self.holder
		h:StopMovingOrSizing()
		if KUI.EndAlignDrag then KUI:EndAlignDrag(h) end
		if h.SetUserPlaced then h:SetUserPlaced(false) end

		local cx, cy = h:GetCenter()
		local right, bottom = chatFrame:GetRight(), chatFrame:GetBottom()
		if cx and right and KUI.db then
			KUI.db.emojiButtonOffset = {
				x = math.floor(cx - right + 0.5),
				y = math.floor(cy - bottom + 0.5),
			}
		end
		PlaceAll()
	end)

	buttons[chatFrame] = button
	ApplyUnlockedLook(button)
	holder:SetShown(Enabled())
end

function KUI:SetEmojiButtonUnlocked(unlocked)
	if not KUI.db then return end
	KUI.db.emojiButtonUnlocked = unlocked and true or false
	for _, button in pairs(buttons) do ApplyUnlockedLook(button) end
	if unlocked and picker then picker:Hide() end
end

function KUI:ResetEmojiButtonPosition()
	if not KUI.db then return end
	KUI.db.emojiButtonOffset = { x = DEFAULT_OFFSET.x, y = DEFAULT_OFFSET.y }
	PlaceAll()
end

function AllChatFrames()
	local frames = {}
	if type(_G.CHAT_FRAMES) == "table" then
		for _, name in ipairs(_G.CHAT_FRAMES) do
			if _G[name] then table.insert(frames, _G[name]) end
		end
	end
	if #frames == 0 then
		for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
			if _G["ChatFrame" .. i] then table.insert(frames, _G["ChatFrame" .. i]) end
		end
	end
	return frames
end

function KUI:EnsureEmojiPickerButtons()
	if not KUI.EMOJI_REGISTRY then return end
	for _, frame in ipairs(AllChatFrames()) do AddButton(frame) end
	local shown = Enabled()
	for _, button in pairs(buttons) do button.holder:SetShown(shown) end
	if not shown and picker then picker:Hide() end
end

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "UPDATE_CHAT_WINDOWS", "CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }) do
	KUI:SafeRegisterEvent(watcher, event)
end
watcher:SetScript("OnEvent", function()
	KUI:EnsureEmojiPickerButtons()

	if C_Timer and C_Timer.After then
		C_Timer.After(0.2, function() KUI:EnsureEmojiPickerButtons() end)
	end
end)
if type(FCF_OpenTemporaryWindow) == "function" then
	hooksecurefunc("FCF_OpenTemporaryWindow", function() KUI:EnsureEmojiPickerButtons() end)
end

if type(KUI.SetEmojiChatEnabled) == "function" then
	hooksecurefunc(KUI, "SetEmojiChatEnabled", function() KUI:EnsureEmojiPickerButtons() end)
end

function KUI:SetEmojiButtonOffset(x, y)
	if not KUI.db or type(x) ~= "number" or type(y) ~= "number" then return end
	KUI.db.emojiButtonOffset = { x = x, y = y }
	PlaceAll()
end
