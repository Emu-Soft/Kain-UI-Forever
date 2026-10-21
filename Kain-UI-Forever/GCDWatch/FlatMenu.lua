local _, KUI = ...

local ns = KUI.GCDWatch

local Menu = {}
ns.FlatMenu = Menu

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
local EDGE = { edgeFile = WHITE, edgeSize = 1 }
local PANEL = { 0.075, 0.08, 0.09, 0.98 }
local ROW_BG, HOVER = { 0.14, 0.145, 0.16 }, { 0.24, 0.20, 0.12 }
local LINE = { 0.8, 0.62, 0.25 }
local GOLD, TEXT = { 0.95, 0.76, 0.35 }, { 0.92, 0.92, 0.92 }
local GREY, OFF = { 0.55, 0.55, 0.58 }, { 0.45, 0.45, 0.47 }
local EMPTY, FIELD = { 0.05, 0.05, 0.06 }, { 0.1, 0.105, 0.12 }
local HEIGHTS = { title = 18, divider = 7, button = 20, radio = 20, check = 20, slider = 24, input = 24 }
local POOLS = { title = "title", divider = "divider", button = "row", radio = "row", check = "row", slider = "slider", input = "input" }
local PAD, MIN_WIDTH, MAX_WIDTH, BAR = 3, 120, 360, 8
local SLIDER_WIDTH, INPUT_WIDTH = 200, 200
local CLOSE_DELAY = 0.15

local state = { open = false, serial = 0, closeToken = 0, hovered = 0 }
local panels = {}
local watcher
local Close, Refresh, Draw, OpenSub, CloseFrom, Activate, Remember, PaintSteps

local function Number(value)
    if type(value) ~= "number" then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function Flag(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function Over(frame)
    if type(frame) ~= "table" or type(frame.IsMouseOver) ~= "function" then return false end
    return Flag(frame:IsMouseOver()) == true
end

local function Response(name)

    local responses = MenuResponse
    return type(responses) == "table" and responses[name] or nil
end

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local Description = {}
Description.__index = Description

local function Add(parent, entry)
    entry.parent = parent
    entry.children = {}
    parent.children[#parent.children + 1] = entry
    return setmetatable(entry, Description)
end

function Description:CreateTitle(text) return Add(self, { kind = "title", text = text }) end
function Description:CreateDivider() return Add(self, { kind = "divider" }) end
function Description:CreateButton(text, callback, data)
    return Add(self, { kind = "button", text = text, callback = callback, data = data })
end
function Description:CreateRadio(text, isSelected, setSelected, data)
    return Add(self, { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data })
end
function Description:CreateCheckbox(text, isSelected, setSelected, data)
    return Add(self, { kind = "check", text = text, isSelected = isSelected, setSelected = setSelected, data = data })
end

function Description:CreateSlider(text, get, set, low, high, step, format, default)
    return Add(self, { kind = "slider", text = text, get = get, set = set, low = low, high = high,
        step = step, format = format, default = Number(default) })
end

function Description:CreateInput(text, get, set, options)
    return Add(self, { kind = "input", text = text, get = get, set = set, options = options or {} })
end
function Description:SetScrollMode(height) self.scrollHeight = Number(height) end
function Description:SetEnabled(enabled) self.enabled = enabled end
function Description:SetTooltip(tooltip) self.tooltip = tooltip end
function Description:SetFont(file, size, flags) self.font = { file, size, flags or "" } end
function Description:SetOnEnter(onEnter) self.onEnter = onEnter end
function Description:SetOnLeave(onLeave) self.onLeave = onLeave end
function Description:GetData() return self.data end
function Description:AddMenuReleasedCallback(callback)
    local root = self
    while root.parent do root = root.parent end
    root.released[#root.released + 1] = callback
end
function Description:IsEnabled()
    local enabled = self.enabled
    if type(enabled) == "function" then enabled = enabled(self) end
    return Flag(enabled) ~= false
end
function Description:IsSelected()
    if type(self.isSelected) ~= "function" then return false end
    return Flag(self.isSelected(self.data)) and true or false
end
function Description:HasSubmenu() return self.kind ~= "root" and #self.children > 0 end

local function Build(owner, generator)
    local root = setmetatable({ kind = "root", children = {}, released = {} }, Description)
    generator(owner, root)
    return root
end

local function IndexOf(list, item)
    for index, value in ipairs(list) do
        if value == item then return index end
    end
end

local function Paint(frame, color)
    frame:SetBackdropColor(color[1], color[2], color[3], 1)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function Skin(row, lit)
    Paint(row, lit and HOVER or ROW_BG)
    row.line:SetShown(lit and true or false)
end

local function GoldLine(frame)
    local line = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("BOTTOMRIGHT", -1, 1)
    line:SetBackdrop(EDGE)
    line:SetBackdropBorderColor(LINE[1], LINE[2], LINE[3], 1)
    line:Hide()
    return line
end

local function Label(frame, font)
    local label = frame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    return label
end

local function IsOpenParent(row)
    local next = panels[row.menuLevel + 1]
    return next ~= nil and next:IsShown() and next.menuEntry ~= nil and next.menuEntry == row.menuEntry
end

local function HideTip()
    if state.tipRow then
        state.tipRow = nil
        GameTooltip:Hide()
    end
end

local function ShowTip(row)
    local entry = row.menuEntry
    local tip = entry.tooltip
    if type(tip) ~= "function" and type(tip) ~= "string" then return end
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if entry:HasSubmenu() then
        GameTooltip:SetPoint("TOPRIGHT", row.menuPanel, "TOPLEFT", -2, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", row.menuPanel, "TOPRIGHT", 2, 0)
    end
    if type(tip) == "string" then

        GameTooltip:SetText(entry.text or "", 1, 1, 1)
        GameTooltip:AddLine(tip, TEXT[1] * 0.92, TEXT[2] * 0.92, TEXT[3] * 0.92, true)
    else
        tip(GameTooltip, entry)
    end
    GameTooltip:Show()
    state.tipRow = row
end

local function ScheduleClose(level)
    local panel = panels[level]
    if not (panel and panel:IsShown()) then return end
    state.closeToken = state.closeToken + 1
    local token = state.closeToken
    local function Run()
        if state.closeToken ~= token or not state.open then return end
        if state.hovered < level then CloseFrom(level) end
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(CLOSE_DELAY, Run)
    else
        Run()
    end
end

local function RowEnter(row)
    state.hovered = row.menuLevel
    local entry = row.menuEntry
    if not entry then return end
    local enabled = entry:IsEnabled()
    if enabled then Skin(row, true) end
    if enabled and entry:HasSubmenu() then
        OpenSub(row.menuLevel + 1, entry, row)
    else
        ScheduleClose(row.menuLevel + 1)
    end
    ShowTip(row)
    if enabled and type(entry.onEnter) == "function" then
        row.entered = entry
        entry.onEnter(row, entry)
    end
end

local function RowLeave(row)
    if state.tipRow == row then HideTip() end
    if row.menuEntry then Skin(row, IsOpenParent(row)) end
    local entered = row.entered
    row.entered = nil
    if entered and type(entered.onLeave) == "function" then entered.onLeave(row, entered) end
end

local function RowClick(row, mouse)
    if row.menuEntry then Activate(row.menuEntry, row.menuLevel, mouse) end
end

local function NewRow(panel)
    local row = CreateFrame("Button", nil, panel, "BackdropTemplate")
    row:SetBackdrop(BACKDROP)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.line = GoldLine(row)

    row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.box:SetSize(10, 10)
    row.box:SetPoint("LEFT", 6, 0)
    row.box:SetBackdrop(BACKDROP)
    row.label = Label(row)

    row.arrow = {}
    for index, height in ipairs({ 7, 5, 3 }) do
        local bar = row:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(GREY[1], GREY[2], GREY[3], 1)
        bar:SetSize(1, height)
        bar:SetPoint("RIGHT", row, "RIGHT", -11 + index, 0)
        row.arrow[index] = bar
    end
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    Skin(row, false)
    return row
end

local function NewTitle(panel)
    local row = CreateFrame("Frame", nil, panel)
    row.label = Label(row, "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetPoint("RIGHT", -6, 0)
    row.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    return row
end

local function NewDivider(panel)
    local row = CreateFrame("Frame", nil, panel)
    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", 2, 0)
    line:SetPoint("RIGHT", -2, 0)
    line:SetHeight(1)
    line:SetColorTexture(0, 0, 0, 1)
    return row
end

local RESET_ATLAS, RESET_FILE = "common-icon-undo", "Interface\\Buttons\\UI-RefreshButton"
function Menu.ResetArt(texture, changed)
    if not texture.resetArt then
        local atlas = type(C_Texture) == "table" and type(C_Texture.GetAtlasInfo) == "function"
            and C_Texture.GetAtlasInfo(RESET_ATLAS)
        if atlas then texture:SetAtlas(RESET_ATLAS) else texture:SetTexture(RESET_FILE) end
        texture.resetArt = true
    end
    texture:SetDesaturated(not changed)
    if changed then
        texture:SetVertexColor(1, 1, 1, 1)
    else
        texture:SetVertexColor(0.5, 0.5, 0.52, 1)
    end
end

local function SliderText(entry, value)
    if entry.format then return entry.format(value) end
    return tostring(math.floor(value * 100 + 0.5) / 100)
end

function Menu.Differs(value, default, step)
    value, default = Number(value), Number(default)
    if not (value and default) then return false end
    local slack = (Number(step) or 0) / 2
    if slack < 1e-6 then slack = 1e-6 end
    return math.abs(value - default) >= slack
end

local function PaintReset(row)
    local entry = row.menuEntry
    if not (entry and entry.default) then return end
    row.resetChanged = Menu.Differs(entry.get and entry.get(), entry.default, entry.step)
    Menu.ResetArt(row.reset.art, row.resetChanged)
end

local function Stepped(row, direction)
    local entry = row.menuEntry
    if not (entry and entry:IsEnabled()) then return nil end
    local current = Number(entry.get and entry.get())
    local low, high, step = Number(entry.low), Number(entry.high), Number(entry.step) or 1
    if not (current and low and high) or step <= 0 then return nil end
    local value = math.floor((current + direction * step) / step + 0.5) * step
    value = Clamp(value, low, high)
    if not Menu.Differs(value, current, step) then return nil end
    return value
end

function PaintSteps(row)
    for _, arrow in ipairs({ row.down, row.up }) do
        local lit = Stepped(row, arrow.direction) ~= nil
        local color = (lit and arrow.hovered) and GOLD or lit and GREY or { 0.25, 0.25, 0.27 }
        arrow.label:SetTextColor(color[1], color[2], color[3])
    end
end

local function NewStep(row, direction)
    local arrow = CreateFrame("Button", nil, row)
    arrow:SetSize(10, 16)
    arrow.direction = direction
    arrow.label = Label(arrow)
    arrow.label:SetPoint("CENTER")
    arrow.label:SetText(direction < 0 and "<" or ">")
    local function Enter(self)
        state.hovered = row.menuLevel
        self.hovered = true
        PaintSteps(row)
        local entry = row.menuEntry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", row.menuPanel, "TOPRIGHT", 2, 0)
        GameTooltip:SetText(direction < 0 and "One step down" or "One step up")
        local value = Stepped(row, direction)
        if value then
            GameTooltip:AddLine("Sets " .. SliderText(entry, value) .. ".", TEXT[1] * 0.92, TEXT[2] * 0.92, TEXT[3] * 0.92, true)
        elseif entry:IsEnabled() then
            GameTooltip:AddLine(direction < 0 and "Already at the lowest value." or "Already at the highest value.",
                TEXT[1] * 0.92, TEXT[2] * 0.92, TEXT[3] * 0.92, true)
        end
        GameTooltip:Show()
        state.tipRow = self
    end
    arrow:SetScript("OnEnter", Enter)
    arrow:SetScript("OnLeave", function(self)
        self.hovered = false
        PaintSteps(row)
        if state.tipRow == self then HideTip() end
    end)
    arrow:SetScript("OnClick", function(self)
        local entry = row.menuEntry
        local value = Stepped(row, direction)
        if not (entry and value and entry.set) then return end
        entry.set(value)
        row.filling = true
        row.control:SetValue(value)
        row.valueText:SetText(SliderText(entry, value))
        row.filling = false
        PaintReset(row)
        PaintSteps(row)
        if state.tipRow == self then Enter(self) end
    end)
    return arrow
end

local function NewSlider(panel)
    local row = CreateFrame("Frame", nil, panel)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        state.hovered = self.menuLevel
        ScheduleClose(self.menuLevel + 1)
        if self.menuEntry then ShowTip(self) end
    end)
    row:SetScript("OnLeave", function(self) if state.tipRow == self then HideTip() end end)
    row.label = Label(row)
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetWidth(60)
    local reset = CreateFrame("Button", nil, row)
    reset:SetSize(14, 14)
    reset:SetPoint("RIGHT", -4, 0)
    reset.art = reset:CreateTexture(nil, "ARTWORK")
    reset.art:SetAllPoints()
    reset:SetScript("OnEnter", function(self)
        state.hovered = row.menuLevel
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", row.menuPanel, "TOPRIGHT", 2, 0)
        GameTooltip:SetText("Reset to default")
        GameTooltip:Show()
        state.tipRow = self
    end)
    reset:SetScript("OnLeave", function(self) if state.tipRow == self then HideTip() end end)
    reset:SetScript("OnClick", function()
        local entry = row.menuEntry
        if not (entry and entry.default and row.resetChanged and entry:IsEnabled()) then return end
        if entry.set then entry.set(entry.default) end
        row.filling = true
        row.control:SetValue(Clamp(entry.default, entry.low, entry.high))
        row.filling = false
        PaintReset(row)
        PaintSteps(row)
    end)
    row.reset = reset
    row.valueText = Label(row)
    row.valueText:SetWidth(36)
    row.valueText:SetJustifyH("RIGHT")

    local down, up = NewStep(row, -1), NewStep(row, 1)
    down:SetPoint("LEFT", row.label, "RIGHT", 2, 0)
    up:SetPoint("RIGHT", row.valueText, "LEFT", -2, 0)
    row.down, row.up = down, up
    local control = CreateFrame("Slider", nil, row)
    control:SetPoint("LEFT", down, "RIGHT", 1, 0)
    control:SetPoint("RIGHT", up, "LEFT", -1, 0)
    control:SetHeight(16)
    control:SetOrientation("HORIZONTAL")
    control:SetObeyStepOnDrag(true)
    control:SetThumbTexture(WHITE)
    local thumb = control:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, 14)
        thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    end
    row.thumb = thumb
    local track = control:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(0.22, 0.24, 0.27, 1)
    control:SetScript("OnValueChanged", function(_, raw)
        local entry = row.menuEntry
        if not entry then return end
        local value = Number(raw) or entry.low
        if entry.step and entry.step > 0 then value = math.floor(value / entry.step + 0.5) * entry.step end
        value = Clamp(value, entry.low, entry.high)
        row.valueText:SetText(SliderText(entry, value))
        if row.filling or not entry.set then return end
        entry.set(value)
        PaintReset(row)
        PaintSteps(row)
    end)
    row.control = control
    return row
end

local function Commit(entry, text)
    entry.pending = nil
    if type(entry.set) == "function" then entry.set(text) end
end

local function CommitInputs(entry)
    if not entry then return end
    for _, child in ipairs(entry.children) do
        if child.kind == "input" and child.pending ~= nil then Commit(child, child.pending) end
        CommitInputs(child)
    end
end

local function InputDone(row, close)
    local entry = row.menuEntry
    if not entry then return end
    local serial = state.serial
    Commit(entry, row.box:GetText() or "")
    if state.serial ~= serial or not state.open then return end
    if close then Close() else row.box:ClearFocus(); Refresh() end
end

local function NewInput(panel)
    local row = CreateFrame("Frame", nil, panel)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) state.hovered = self.menuLevel; ScheduleClose(self.menuLevel + 1) end)
    row.label = Label(row)
    row.label:SetPoint("LEFT", 6, 0)
    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetBackdrop(BACKDROP)
    Paint(box, FIELD)
    box.line = GoldLine(box)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(5, 5, 0, 0)
    box:SetAutoFocus(false)
    box:SetHeight(20)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function()
        InputDone(row, not (row.menuEntry and row.menuEntry.options.stayOpen))
    end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and row.menuEntry then row.menuEntry.pending = self:GetText() or "" end
    end)

    box:SetScript("OnEditFocusGained", function(self)
        self.line:Show()
        self:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self.line:Hide()
        self:HighlightText(0, 0)
    end)
    box:SetScript("OnHide", function(self) self:ClearFocus() end)

    box:SetScript("OnTabPressed", function()
        local inputs = {}
        for _, other in ipairs(panel.pools.input) do
            if other:IsShown() and other.menuEntry then inputs[#inputs + 1] = other end
        end
        for index, other in ipairs(inputs) do
            if other == row and #inputs > 1 then
                local step = (type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) and -1 or 1
                inputs[(index - 1 + step) % #inputs + 1].box:SetFocus()
                return
            end
        end
    end)
    row.box = box
    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetBackdrop(BACKDROP)
    button.line = GoldLine(button)
    button.label = Label(button)
    button.label:SetPoint("CENTER")
    button.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    button:SetSize(44, 20)
    button:SetPoint("RIGHT", -2, 0)
    button:SetScript("OnEnter", function(self) Skin(self, true) end)
    button:SetScript("OnLeave", function(self) Skin(self, false) end)
    button:SetScript("OnClick", function() InputDone(row, true) end)
    Skin(button, false)
    row.button = button
    return row
end

local MAKERS = { row = NewRow, title = NewTitle, divider = NewDivider, slider = NewSlider, input = NewInput }

local function Fill(row, entry)
    row.menuEntry = entry
    local kind = entry.kind
    if kind == "divider" then return end
    if kind == "title" then
        row.label:SetText(entry.text or "")
        return
    end
    if kind == "slider" then
        row.label:SetText(entry.text or "")
        local panel = row.menuPanel
        row.label:SetWidth(panel and panel.sliderLabel or 60)
        row.valueText:SetWidth(panel and panel.sliderValue or 36)
        local resettable = entry.default ~= nil
        row.reset:SetShown(resettable)
        row.valueText:ClearAllPoints()
        if resettable then
            row.valueText:SetPoint("RIGHT", row.reset, "LEFT", -3, 0)
        else
            row.valueText:SetPoint("RIGHT", -6, 0)
        end
        row.filling = true
        row.control:SetMinMaxValues(entry.low, entry.high)
        row.control:SetValueStep(entry.step or 1)
        local current = Number(entry.get and entry.get()) or entry.low
        row.control:SetValue(Clamp(current, entry.low, entry.high))
        row.valueText:SetText(SliderText(entry, current))
        row.filling = false
        PaintReset(row)
        local enabled = entry:IsEnabled()
        row.control:SetEnabled(enabled)
        local color = enabled and TEXT or OFF
        row.label:SetTextColor(color[1], color[2], color[3])
        row.valueText:SetTextColor(color[1], color[2], color[3])
        local thumbColor = enabled and GOLD or OFF
        if row.thumb then row.thumb:SetColorTexture(thumbColor[1], thumbColor[2], thumbColor[3], 1) end
        if not enabled then Menu.ResetArt(row.reset.art, false) end
        PaintSteps(row)
        return
    end
    if kind == "input" then
        local options = entry.options
        local named = entry.text ~= nil and entry.text ~= ""
        row.label:SetText(named and entry.text or "")
        row.label:SetShown(named)
        local box = row.box
        box:ClearAllPoints()
        if named then
            box:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        else
            box:SetPoint("LEFT", 2, 0)
        end
        row.button:SetShown(options.button ~= nil)
        if options.button then
            row.button.label:SetText(options.button)
            box:SetPoint("RIGHT", row.button, "LEFT", -2, 0)
        else
            box:SetPoint("RIGHT", -2, 0)
        end
        box:SetNumeric(options.numeric and true or false)
        box:SetMaxLetters(options.maxLetters or 0)
        local text = entry.pending
        if text == nil and entry.get then text = entry.get() end
        box:SetText(type(text) == "string" and text or (text ~= nil and tostring(text) or ""))
        return
    end
    local enabled = entry:IsEnabled()
    local choice = kind == "radio" or kind == "check"
    local on = choice and entry:IsSelected()
    local submenu = entry:HasSubmenu()
    row.box:SetShown(choice)
    if on then
        local dim = enabled and 1 or 0.55
        row.box:SetBackdropColor(GOLD[1] * dim, GOLD[2] * dim, GOLD[3] * dim, 1)
    else
        row.box:SetBackdropColor(EMPTY[1], EMPTY[2], EMPTY[3], 1)
    end
    row.box:SetBackdropBorderColor(0, 0, 0, 1)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", choice and 22 or 8, 0)
    row.label:SetPoint("RIGHT", submenu and -18 or -8, 0)
    if entry.font then
        row.customFont = row.label:SetFont(entry.font[1], entry.font[2], entry.font[3]) ~= false
    elseif row.customFont then
        row.label:SetFontObject("GameFontHighlightSmall")
        row.customFont = nil
    end
    row.label:SetText(entry.text or "")

    local color = TEXT
    if not enabled then
        color = OFF
    elseif on then
        color = GOLD
    end
    row.label:SetTextColor(color[1], color[2], color[3])
    for _, bar in ipairs(row.arrow) do bar:SetShown(submenu) end
    Skin(row, IsOpenParent(row))
end

local function Wanted(panel, entry)
    local kind = entry.kind
    if kind == "divider" then return 0 end
    if kind == "slider" then
        return SLIDER_WIDTH + (panel.sliderLabel - 60) + (panel.sliderValue - 36) + (entry.default and 18 or 0)
    end
    if kind == "input" then return entry.options.width or INPUT_WIDTH end
    if entry.font then panel.measure:SetFont(entry.font[1], entry.font[2], entry.font[3]) end
    panel.measure:SetText(entry.text or "")
    local text = Number(panel.measure:GetStringWidth()) or 0
    if entry.font then panel.measure:SetFontObject("GameFontHighlightSmall") end
    if kind == "title" then return text + 12 end
    local left = (kind == "radio" or kind == "check") and 22 or 8
    return left + text + (entry:HasSubmenu() and 20 or 10)
end

local function ScrollTo(panel, first)
    first = Clamp(first, 1, panel.last or 1)
    if first == panel.first then return end
    panel.first = first
    Draw(panel)
end

local function NewPanel(level)
    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(10 + level * 30)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(PANEL[1], PANEL[2], PANEL[3], PANEL[4])
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    panel.menuLevel = level
    panel.first = 1
    panel.pools = { row = {}, title = {}, divider = {}, slider = {}, input = {} }
    panel.drawn = {}

    panel.measure = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.measure:SetPoint("TOPLEFT")
    panel.measure:SetWordWrap(false)
    panel.measure:SetAlpha(0)
    panel:SetScript("OnMouseWheel", function(self, delta)
        ScrollTo(self, self.first + ((Number(delta) or 0) > 0 and -2 or 2))
    end)

    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(5)
    bar:SetPoint("TOPRIGHT", -PAD, -PAD)
    bar:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    bar:SetObeyStepOnDrag(true)
    bar:SetValueStep(1)
    bar:SetThumbTexture(WHITE)
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetSize(5, 24)
        thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    end
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(ROW_BG[1], ROW_BG[2], ROW_BG[3], 1)
    bar:SetScript("OnValueChanged", function(_, value)
        if panel.filling then return end
        ScrollTo(panel, math.floor((Number(value) or 1) + 0.5))
    end)
    bar:Hide()
    panel.bar = bar
    if level == 1 then
        panel:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                Close()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end
    return panel
end

local function Panel(level)
    if not panels[level] then panels[level] = NewPanel(level) end
    return panels[level]
end

function Draw(panel)
    local entries = panel.menuEntry and panel.menuEntry.children or {}
    for _, pool in pairs(panel.pools) do
        for _, row in ipairs(pool) do
            row:Hide()
            row.menuEntry = nil
        end
    end
    panel.drawn = {}

    local labelWidth, valueWidth = 60, 36
    for _, entry in ipairs(entries) do
        if entry.kind == "slider" then
            panel.measure:SetText(entry.text or "")
            labelWidth = math.max(labelWidth, (Number(panel.measure:GetStringWidth()) or 0) + 4)
            for _, value in ipairs({ entry.low, entry.high, entry.default or entry.low, Number(entry.get and entry.get()) or entry.low }) do
                panel.measure:SetText(SliderText(entry, value))
                valueWidth = math.max(valueWidth, (Number(panel.measure:GetStringWidth()) or 0) + 4)
            end
        end
    end
    panel.sliderLabel, panel.sliderValue = math.min(labelWidth, 150), math.min(valueWidth, 90)
    local total, width = 0, math.max(MIN_WIDTH, panel.minWidth or 0)
    for _, entry in ipairs(entries) do
        total = total + (HEIGHTS[entry.kind] or HEIGHTS.button)
        width = math.max(width, Wanted(panel, entry) + 2 * PAD)
    end
    width = math.min(width, math.max(MAX_WIDTH, panel.minWidth or 0))
    local scale = Number(panel:GetScale()) or 1
    if scale <= 0 then scale = 1 end
    local screen = Number(UIParent:GetHeight()) or 768
    local limit = (panel.menuEntry and panel.menuEntry.scrollHeight) or math.floor(screen * 0.8 / scale)
    local scrolling = total + 2 * PAD > limit
    panel.last = 1
    if scrolling then

        local height, last = 0, #entries
        for index = #entries, 1, -1 do
            height = height + (HEIGHTS[entries[index].kind] or HEIGHTS.button)
            if height > limit - 2 * PAD then break end
            last = index
        end
        panel.last = last
        width = width + BAR
    end
    panel.first = Clamp(panel.first or 1, 1, panel.last)
    local inner = width - 2 * PAD - (scrolling and BAR or 0)
    local used, y = {}, PAD
    for index = scrolling and panel.first or 1, #entries do
        local entry = entries[index]
        local height = HEIGHTS[entry.kind] or HEIGHTS.button
        if scrolling and y + height > limit - PAD then break end
        local pool = POOLS[entry.kind] or "row"
        used[pool] = (used[pool] or 0) + 1
        local row = panel.pools[pool][used[pool]]
        if not row then
            row = MAKERS[pool](panel)
            row.menuPanel = panel
            panel.pools[pool][used[pool]] = row
        end
        row.menuLevel = panel.menuLevel
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
        row:SetSize(inner, height)
        row:SetFrameLevel(panel:GetFrameLevel() + 2)
        Fill(row, entry)
        row:Show()
        panel.drawn[entry] = row
        y = y + height
    end
    panel:SetSize(width, (scrolling and limit or y + PAD))
    panel.bar:SetShown(scrolling)
    if scrolling then
        panel.filling = true
        panel.bar:SetMinMaxValues(1, panel.last)
        panel.bar:SetValue(panel.first)
        panel.filling = false
    end
end

function CloseFrom(level)
    for index = level, #panels do
        local panel = panels[index]
        if panel:IsShown() then panel:Hide() end
        panel.menuEntry, panel.parentRow = nil, nil
    end
    local parent = panels[level - 1]
    if parent and parent:IsShown() then
        for entry, row in pairs(parent.drawn) do
            if entry:HasSubmenu() and not Over(row) then Skin(row, false) end
        end
    end
end

local function OffRight(panel)
    local right, scale = Number(panel:GetRight()), Number(panel:GetEffectiveScale())
    local screen, screenScale = Number(UIParent:GetRight()), Number(UIParent:GetEffectiveScale())
    if not (right and scale and screen and screenScale) then return false end
    return right * scale > screen * screenScale + 0.5
end

function OpenSub(level, entry, row)
    state.closeToken = state.closeToken + 1
    local panel = Panel(level)
    if panel:IsShown() and panel.menuEntry == entry then return end
    CloseFrom(level)
    panel.menuEntry, panel.parentRow, panel.first, panel.minWidth = entry, row, 1, 0
    panel:SetScale(panels[1]:GetScale() or 1)
    Draw(panel)
    panel:ClearAllPoints()
    if row then
        panel:SetPoint("TOPLEFT", row, "TOPRIGHT", PAD + 1, PAD + 1)
        if OffRight(panel) then
            panel:ClearAllPoints()
            panel:SetPoint("TOPRIGHT", row, "TOPLEFT", -(PAD + 1), PAD + 1)
        end
        Skin(row, true)
    else
        panel:SetPoint("TOPLEFT", panels[level - 1], "TOPRIGHT", 1, 0)
    end
    panel:Show()
end

function Activate(entry, level, mouse)
    if not (state.open and entry) or not entry:IsEnabled() then return end
    local kind = entry.kind
    if kind ~= "button" and kind ~= "radio" and kind ~= "check" then return end
    if entry:HasSubmenu() and not entry.callback then
        local panel = panels[level]
        OpenSub(level + 1, entry, panel and panel.drawn[entry])
        return
    end
    local input = { buttonName = mouse or "LeftButton" }
    local serial = state.serial
    local response, keep
    if kind == "button" then
        if entry.callback then response = entry.callback(entry.data, input, Menu) end
        keep = false
    else
        if entry.setSelected then response = entry.setSelected(entry.data, input, Menu) end
        keep = kind == "check" or (state.options and state.options.keepOpen) or false
    end

    if state.serial ~= serial or not state.open then return end
    if response ~= nil and (response == Response("Close") or response == Response("CloseAll")) then
        keep = false
    elseif response ~= nil and (response == Response("Refresh") or response == Response("Open")) then
        keep = true
    end
    if keep then Refresh() else Close() end
end

function Refresh()
    if not state.open then return end
    CommitInputs(state.root)
    local path = {}
    for level = 2, #panels do
        local panel = panels[level]
        if not (panel:IsShown() and panel.menuEntry and panel.menuEntry.parent) then break end
        path[level - 1] = IndexOf(panel.menuEntry.parent.children, panel.menuEntry)
    end
    state.root = Build(state.owner, state.generator)
    local entry = state.root
    panels[1].menuEntry = entry
    Draw(panels[1])
    for level = 2, #panels do
        local index = path[level - 1]
        local child = index and entry.children[index]
        if not (child and child:HasSubmenu() and panels[level]:IsShown()) then
            CloseFrom(level)
            break
        end
        panels[level].menuEntry = child
        Draw(panels[level])
        entry = child
    end
end

local function Keys(on)
    local panel = panels[1]
    if not panel then return end
    if on then
        if InCombatLockdown() then return end
        panel:EnableKeyboard(true)
        panel:SetPropagateKeyboardInput(true)
    else
        panel:EnableKeyboard(false)
    end
end

local function Edge(frame, method)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return nil end
    return Number(frame[method](frame))
end

local function OwnerSpot(owner)
    return Edge(owner, "GetLeft"), Edge(owner, "GetTop"), Edge(owner, "GetEffectiveScale")
end

function Remember(panel, owner)
    state.held = nil
    local left, top = Edge(panel, "GetLeft"), Edge(panel, "GetTop")
    local ownerLeft, ownerTop, ownerScale = OwnerSpot(owner)
    if not (left and top and ownerLeft and ownerTop and ownerScale) then return end
    state.held = { left = left, top = top, ownerLeft = ownerLeft, ownerTop = ownerTop, ownerScale = ownerScale }
end

local function Hold()
    local held, panel = state.held, panels[1]
    if not (held and panel) then return end
    local left, top, scale = OwnerSpot(state.owner)
    if not (left and top and scale) then return end
    if math.abs(left - held.ownerLeft) < 0.5 and math.abs(top - held.ownerTop) < 0.5
        and math.abs(scale - held.ownerScale) < 0.001 then
        return
    end
    state.held = nil
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", held.left, held.top)
end

local function Visible(frame)
    if type(frame) ~= "table" or type(frame.IsVisible) ~= "function" then return true end
    local visible = Flag(frame:IsVisible())
    return visible ~= false
end

local function Watch(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function(_, event, button)
            if not state.open then return end
            if event == "PLAYER_REGEN_ENABLED" then
                Keys(true)
                return
            end
            if button ~= "LeftButton" and button ~= "RightButton" then return end

            if state.openedAt and GetTime() == state.openedAt then return end
            for _, panel in ipairs(panels) do
                if panel:IsShown() and Over(panel) then return end
            end

            if state.owner and not state.atCursor and Over(state.owner) then return end
            Close()
        end)
    end
    if on then
        watcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnUpdate", function()
            if state.open and state.owner and not Visible(state.owner) then Close() return end
            if state.open then Hold() end
        end)
    else
        watcher:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnUpdate", nil)
    end
end

function Close()
    if not state.open then return end
    local root, options = state.root, state.options
    state.open = false
    state.serial = state.serial + 1
    state.closeToken = state.closeToken + 1
    HideTip()
    Keys(false)
    Watch(false)
    for _, panel in ipairs(panels) do
        panel:Hide()
        panel.menuEntry, panel.parentRow = nil, nil
    end
    state.owner, state.generator, state.root, state.options, state.held = nil, nil, nil, nil, nil

    CommitInputs(root)
    for _, released in ipairs(root and root.released or {}) do released() end
    if options and options.onClose then options.onClose() end
end

local function Place(panel, owner, options, atCursor)
    panel:ClearAllPoints()
    if atCursor or not owner then
        local x, y = GetCursorPosition()
        local scale = Number(panel:GetEffectiveScale()) or 1
        if scale <= 0 then scale = 1 end
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (Number(x) or 0) / scale, (Number(y) or 0) / scale)
        return
    end
    local point = options.point
    if point then
        panel:SetPoint(point[1], owner, point[2], point[3] or 0, point[4] or 0)
        return
    end
    panel:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)

    local bottom = Number(panel:GetBottom())
    if bottom and bottom < 0 then
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    end
end

local function OpenMenu(owner, generator, options, atCursor)
    options = options or {}
    if not atCursor and state.open and owner ~= nil and state.owner == owner then
        Close()
        return false
    end
    Close()
    local root = Build(owner, generator)
    if #root.children == 0 then return false end
    GameTooltip:Hide()
    state.open, state.owner, state.generator, state.options, state.root = true, owner, generator, options, root
    state.atCursor = atCursor and true or false
    state.serial = state.serial + 1
    state.hovered = 0
    state.openedAt = GetTime()
    local panel = Panel(1)
    local scale = 1
    if type(owner) == "table" and type(owner.GetEffectiveScale) == "function" then
        local own, base = Number(owner:GetEffectiveScale()), Number(UIParent:GetEffectiveScale())
        if own and base and own > 0 and base > 0 then scale = own / base end
    end
    panel:SetScale(scale)
    local minWidth = options.minWidth
    if not minWidth and not atCursor and type(owner) == "table" and type(owner.GetWidth) == "function" then
        minWidth = Number(owner:GetWidth())
    end
    panel.menuEntry, panel.first, panel.minWidth = root, 1, minWidth or 0
    Draw(panel)
    Place(panel, owner, options, atCursor)
    panel:Show()
    if not atCursor then Remember(panel, owner) end
    Keys(true)
    Watch(true)
    return true
end

function Menu.Open(owner, generator, options) return OpenMenu(owner, generator, options, false) end
function Menu.OpenAtCursor(owner, generator, options) return OpenMenu(owner, generator, options, true) end
Menu.Close = function() Close() end
Menu.Refresh = function() Refresh() end
function Menu.IsOpen(owner) return state.open and (owner == nil or state.owner == owner) end
function Menu.Owner() return state.open and state.owner or nil end

function Menu.DownArrow(button)
    local bars = {}
    for index, width in ipairs({ 7, 5, 3 }) do
        local bar = button:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(GREY[1], GREY[2], GREY[3], 1)
        bar:SetSize(width, 1)
        bar:SetPoint("RIGHT", button, "RIGHT", -8 - (7 - width) / 2, 2 - index)
        bars[index] = bar
    end
    return bars
end

function Menu.Entries(level)
    local panel = panels[level or 1]
    if not (state.open and panel and panel:IsShown() and panel.menuEntry) then return nil end
    return panel.menuEntry.children
end
function Menu.Find(text, level)
    for _, entry in ipairs(Menu.Entries(level) or {}) do
        if entry.text == text then return entry end
    end
end
function Menu.Click(target, level, mouse)
    local entry = type(target) == "table" and target or Menu.Find(target, level)
    if not entry then return false end
    Activate(entry, level or 1, mouse)
    return true
end
function Menu.Hover(target, level)
    level = level or 1
    local entry = type(target) == "table" and target or Menu.Find(target, level)
    if not (entry and entry:HasSubmenu() and entry:IsEnabled()) then return false end
    local panel = panels[level]
    OpenSub(level + 1, entry, panel and panel.drawn[entry])
    return true
end
function Menu.Row(target, level)
    local panel = panels[level or 1]
    local entry = type(target) == "table" and target or Menu.Find(target, level)
    return panel and entry and panel.drawn[entry] or nil
end
function Menu.Panel(level) return panels[level or 1] end
function Menu.Build(owner, generator) return Build(owner, generator) end

function Menu.Untipped(owner, generator)
    local missing = {}
    local function Walk(entry)
        for _, child in ipairs(entry.children or {}) do
            if child.kind ~= "title" and child.kind ~= "divider"
                and type(child.tooltip) ~= "function" and type(child.tooltip) ~= "string" then
                missing[#missing + 1] = child.text or child.kind
            end
            Walk(child)
        end
    end
    Walk(Build(owner, generator))
    return missing
end
