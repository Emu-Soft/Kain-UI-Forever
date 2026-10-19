local _, KUI = ...

local ns = KUI.GCDWatch

local Kit = {}
ns.PreviewKit = Kit

local function Measure(value)
    if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end
function Kit.PlaceTooltip(tip, owner)
    tip:ClearAllPoints()
    if not UIParent then
        tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT")
        return
    end
    local window = owner
    while window and window.GetParent and window:GetParent() and window:GetParent() ~= UIParent do
        window = window:GetParent()
    end
    local tipScale, ownerScale = Measure(tip:GetEffectiveScale()), Measure(owner:GetEffectiveScale())
    local width, height = Measure(tip:GetWidth()), Measure(tip:GetHeight())
    local ownerTop, ownerBottom = Measure(owner:GetTop()), Measure(owner:GetBottom())
    local left, right, top = Measure(window:GetLeft()), Measure(window:GetRight()), Measure(window:GetTop())
    local windowScale, screen = Measure(window:GetEffectiveScale()), Measure(UIParent:GetRight())
    local parentScale = Measure(UIParent:GetEffectiveScale())
    if not (tipScale and ownerScale and width and ownerTop and left and right and top and windowScale and screen and parentScale) then
        tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT")
        return
    end
    local gap = 4
    width, screen = width * tipScale, screen * parentScale

    local drop = (ownerTop * ownerScale - top * windowScale) / tipScale
    if right * windowScale + gap + width <= screen then
        tip:SetPoint("TOPLEFT", window, "TOPRIGHT", gap / tipScale, drop)
    elseif left * windowScale - gap - width >= 0 then
        tip:SetPoint("TOPRIGHT", window, "TOPLEFT", -gap / tipScale, drop)
    elseif ownerBottom and ownerBottom * ownerScale - (height or 0) * tipScale >= 0 then
        tip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -gap / tipScale)
    else
        tip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, gap / tipScale)
    end
end
Kit.VERSION = 5

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD = { 0.95, 0.76, 0.35 }
local GREY = { 0.55, 0.55, 0.58 }
local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local EDGE = { edgeFile = WHITE, edgeSize = 1 }
Kit.GREY, Kit.AMBER = "|cff8c8c94", "|cffff9f1a"

local LABEL_TOP, SAMPLE_TOP, SAMPLE_LEFT = 4, 24, 6
local SCREEN_W, SCREEN_H = 104, 16
local LOOP_GAP = 0.6

local FIND_HINT = "|cffd9c08aclick a part to find its setting|r"
local FIND_NOTE = "Click any part to find its setting"
local PULSE_BEAT, PULSE_BEATS = 0.7, 3
local GHOST_ALPHA = 0.35

local SKY, HORIZON, GROUND = { 0.2, 0.25, 0.3 }, { 0.25, 0.28, 0.22 }, { 0.16, 0.15, 0.12 }

local function Gradient(texture, top, bottom)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
end

local function FlatButton(parent, text, width, height, tip)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop(BACKDROP)
    button:SetBackdropColor(0.14, 0.145, 0.16, 1)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    local gold = CreateFrame("Frame", nil, button, "BackdropTemplate")
    gold:SetPoint("TOPLEFT", 1, -1)
    gold:SetPoint("BOTTOMRIGHT", -1, 1)
    gold:SetBackdrop(EDGE)
    gold:SetBackdropBorderColor(0.8, 0.62, 0.25, 1)
    gold:Hide()
    button.gold = gold
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    button.label = label
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.24, 0.20, 0.12, 1)
        gold:Show()
        if tip then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetText(text)
            GameTooltip:AddLine(tip, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
            Kit.PlaceTooltip(GameTooltip, self)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.14, 0.145, 0.16, 1)
        gold:Hide()
        if tip then GameTooltip:Hide() end
    end)
    return button
end

local TEXT_ABOVE, OUTLINE_ABOVE, LIFT_LIMIT = 20, 30, 2000

local function Level(frame)
    if type(frame) ~= "table" or type(frame.GetFrameLevel) ~= "function" then return nil end
    local level = frame:GetFrameLevel()
    if issecretvalue and issecretvalue(level) then return nil end
    if type(level) ~= "number" then return nil end
    return level
end

local function Highest(frame, own, top, count)
    if type(frame.GetChildren) ~= "function" then return top, count end
    for _, child in ipairs({ frame:GetChildren() }) do
        if count >= LIFT_LIMIT then break end
        if type(child) == "table" and not own[child] then
            count = count + 1
            local level = Level(child)
            if level and level > top then top = level end
            top, count = Highest(child, own, top, count)
        end
    end
    return top, count
end

local function SetLevel(frame, level)
    if Level(frame) ~= level then frame:SetFrameLevel(level) end
end

local function Outline(holder, level, thick)
    local box = CreateFrame("Frame", nil, holder)
    box:SetFrameLevel(level or (holder:GetFrameLevel() + OUTLINE_ABOVE))
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local line = box:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] then line:SetHeight(thick and 2 or 1) else line:SetWidth(thick and 2 or 1) end
    end
    box:Hide()
    return box
end

local function Over(frame)
    if not frame or type(frame.IsMouseOver) ~= "function" then return false end
    local over = frame:IsMouseOver()
    if issecretvalue and issecretvalue(over) then return false end
    return over == true
end

local function Magnifier(on)
    if on then
        if SetCursor then SetCursor("INSPECT_CURSOR") end
    elseif ResetCursor then
        ResetCursor()
    end
end

local function Area(region)
    local width = type(region.GetWidth) == "function" and region:GetWidth() or 0
    local height = type(region.GetHeight) == "function" and region:GetHeight() or 0
    if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return 0 end
    if type(width) ~= "number" or type(height) ~= "number" then return 0 end
    return width * height
end

function Kit.New(frame, options)
    options = options or {}
    local x, width = options.x or 14, options.width or 508
    local preview = { frame = frame, parts = {}, loops = {}, outlines = {}, markBoxes = {}, top = SAMPLE_TOP, left = x + SAMPLE_LEFT, width = width,
        labelDrop = 0, extra = 0 }

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x + 2, -LABEL_TOP)
    label:SetWidth(options.onScreen and (width - SCREEN_W - 8) or width)
    label:SetJustifyH("LEFT")
    label:SetTextColor(GREY[1], GREY[2], GREY[3])
    preview.label = label
    if options.onScreen then
        local button = FlatButton(frame, "Show on screen", SCREEN_W, SCREEN_H, options.screenTip)
        button:SetPoint("TOPLEFT", x + width - SCREEN_W, -1)
        button:SetScript("OnClick", function() options.onScreen() end)
        preview.screen = button
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder.settingsPreview = true
    preview.holder = holder
    local stage = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    stage:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -(SAMPLE_TOP - 6))
    stage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", x + width, 4)
    stage:SetFrameLevel(holder:GetFrameLevel())
    stage:SetBackdrop(EDGE)
    stage:SetBackdropBorderColor(0, 0, 0, 1)
    preview.stage = stage
    if options.plain then
        local fill = stage:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(options.plain[1], options.plain[2], options.plain[3], 1)
        preview.fill = fill
    else
        local sky = stage:CreateTexture(nil, "BACKGROUND")
        sky:SetPoint("TOPLEFT", 1, -1)
        sky:SetPoint("BOTTOMRIGHT", stage, "RIGHT", -1, 0)
        Gradient(sky, SKY, HORIZON)
        local ground = stage:CreateTexture(nil, "BACKGROUND")
        ground:SetPoint("TOPLEFT", stage, "LEFT", 1, 0)
        ground:SetPoint("BOTTOMRIGHT", -1, 1)
        Gradient(ground, HORIZON, GROUND)
        preview.sky, preview.ground = sky, ground
    end
    local text = CreateFrame("Frame", nil, holder)
    text:SetAllPoints(holder)
    text:SetFrameLevel(holder:GetFrameLevel() + TEXT_ABOVE)
    preview.text = text

    local own = { [stage] = true, [text] = true }

    function preview.Caption(width)
        local caption = text:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        caption:SetJustifyH("LEFT")
        if type(width) == "number" and width > 0 then
            caption:SetWidth(width)
            caption:SetWordWrap(true)
        else
            caption:SetWordWrap(false)
        end
        return caption
    end

    local extra = 0
    function preview.SetLabel(value)
        value = value or ""
        if options.find then value = (value ~= "" and (value .. " · ") or "") .. FIND_HINT end
        label:SetText(value)
        local height = label:GetStringHeight()
        extra = 0
        if type(height) == "number" then extra = math.max(0, math.ceil(LABEL_TOP + height + 2 - (SAMPLE_TOP - 6))) end
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -extra)
        holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

        preview.labelDrop, preview.extra = extra, extra
        return extra
    end
    function preview.Fit(bottom)
        preview.Lift()
        local height = math.ceil(extra + bottom + 6)
        preview.height = height
        if options.resize then options.resize(height) end
        return height
    end

    local function Run()
        local now = GetTime()
        for _, loop in ipairs(preview.loops) do
            if loop.active then
                if loop.step then loop.step(now) end
                if loop.done() then loop.active, loop.next = false, now + LOOP_GAP end
            elseif loop.next and now >= loop.next then
                loop.active, loop.next = true, nil
                loop.play(now, false)
            end
        end
    end
    function preview.Restart()
        local now = GetTime()
        holder:SetScript("OnUpdate", (not preview.holding and #preview.loops > 0) and Run or nil)
        for _, loop in ipairs(preview.loops) do
            loop.stop()
            loop.active, loop.next = false, nil
            if preview.holding then
                loop.still()
            else
                loop.active = true
                loop.play(now, true)
            end
        end
    end
    function preview.Hold(on)
        on = on == true
        if preview.holding == on then return end
        preview.holding = on
        preview.Restart()
    end
    holder:SetScript("OnHide", function()
        holder:SetScript("OnUpdate", nil)
        for _, loop in ipairs(preview.loops) do
            loop.stop()
            loop.active, loop.next = false, nil
        end
    end)

    local tag = CreateFrame("Frame", nil, holder)
    tag:SetFrameLevel(holder:GetFrameLevel() + OUTLINE_ABOVE + 1)
    own[tag] = true
    tag:SetHeight(14)
    local tagFill = tag:CreateTexture(nil, "BACKGROUND")
    tagFill:SetAllPoints()
    tagFill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    local tagText = tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagText:SetPoint("CENTER", 0, 0)
    tagText:SetTextColor(0, 0, 0, 1)
    tag:Hide()
    preview.tag, preview.tagText = tag, tagText

    local outlineLevel = holder:GetFrameLevel() + OUTLINE_ABOVE
    preview.hotspots = {}
    local shownSpots = 0
    function preview.Lift()
        local base = Level(holder)
        if not base then return end
        local top = Highest(holder, own, base, 0)
        local textLevel = math.max(base + TEXT_ABOVE, top + 1)

        outlineLevel = math.max(base + OUTLINE_ABOVE, textLevel + 1 + shownSpots)
        SetLevel(text, textLevel)
        for index = 1, shownSpots do
            local spot = preview.hotspots[index]
            SetLevel(spot, textLevel + index)
            SetLevel(spot.ghost, textLevel + index)
        end
        for _, box in ipairs(preview.outlines) do SetLevel(box, outlineLevel) end
        for _, box in ipairs(preview.markBoxes) do SetLevel(box, outlineLevel) end
        if preview.markTag then SetLevel(preview.markTag, outlineLevel + 1) end
        SetLevel(tag, outlineLevel + 1)
        if preview.note then SetLevel(preview.note, outlineLevel + 1) end
        local screen = preview.screen
        if screen then
            local frameLevel = Level(frame)
            local wanted = math.max(frameLevel and frameLevel + 1 or 0, top + 1)
            SetLevel(screen, wanted)
            SetLevel(screen.gold, wanted + 1)
        end
        return textLevel
    end

    function preview.Point(part, name)
        for _, box in ipairs(preview.outlines) do box:Hide() end
        tag:Hide()
        local find = part and preview.parts[part]
        preview.pointed, preview.pointedName = find and part or nil, find and name or nil
        preview.Hold(find ~= nil)
        if not find then return end
        local regions, whole = find()
        local shown = {}
        for _, region in ipairs(regions or {}) do
            if region and region:IsShown() ~= false then shown[#shown + 1] = region end
        end
        local off = #shown == 0
        if off then shown[1] = whole end
        if not shown[1] then return end
        preview.Lift()
        for index, region in ipairs(shown) do
            local box = preview.outlines[index]
            if not box then
                box = Outline(holder, outlineLevel)
                own[box] = true
                preview.outlines[index] = box
            end
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", region, "TOPLEFT", -2, 2)
            box:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 2, -2)
            box:Show()
        end
        tagText:SetText(off and ((name or "") .. ": not shown") or (name or ""))
        tag:SetWidth((tagText:GetStringWidth() or 60) + 8)
        tag:ClearAllPoints()
        local right, edge = preview.outlines[1]:GetRight(), stage:GetRight()
        if type(right) == "number" and type(edge) == "number" and right + 4 + tag:GetWidth() > edge then
            tag:SetPoint("BOTTOMRIGHT", preview.outlines[1], "TOPRIGHT", 0, 1)
        else
            tag:SetPoint("LEFT", preview.outlines[1], "RIGHT", 4, 0)
        end
        tag:Show()
    end

    local markTag, markText
    function preview.Mark(part, value)
        for _, box in ipairs(preview.markBoxes) do box:Hide() end
        if markTag then markTag:Hide() end
        preview.marked, preview.markedText = part, value
        local find = part and preview.parts[part]
        if not find then return end
        local shown = {}
        for _, region in ipairs((find()) or {}) do
            if region and region:IsShown() ~= false then shown[#shown + 1] = region end
        end
        if not shown[1] then return end
        preview.Lift()
        for index, region in ipairs(shown) do
            local box = preview.markBoxes[index]
            if not box then
                box = Outline(holder, outlineLevel, true)
                own[box] = true
                preview.markBoxes[index] = box
            end
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", region, "TOPLEFT", -3, 3)
            box:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 3, -3)
            box:Show()
        end
        if not markTag then
            markTag = CreateFrame("Frame", nil, holder)
            own[markTag] = true
            markTag:SetHeight(14)
            local fill = markTag:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            markText = markTag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            markText:SetPoint("CENTER", 0, 0)
            markText:SetTextColor(0, 0, 0, 1)
            preview.markTag, preview.markText = markTag, markText
        end
        SetLevel(markTag, outlineLevel + 1)
        markText:SetText(value or "Editing")
        markTag:SetWidth((markText:GetStringWidth() or 40) + 8)
        markTag:ClearAllPoints()
        markTag:SetPoint("BOTTOMLEFT", preview.markBoxes[1], "TOPLEFT", 0, -1)
        markTag:Show()
    end

    local ghosts, hovered = false, nil
    local function ShowGhosts(on)
        ghosts = on
        for index = 1, shownSpots do preview.hotspots[index].ghost:SetShown(on) end
    end
    local function CheckGhosts()
        if Over(stage) or hovered then return end
        ShowGhosts(false)
    end
    local function Later(fn)
        if C_Timer and C_Timer.After then C_Timer.After(0, fn) else fn() end
    end
    local function Spot(index)
        local spot = preview.hotspots[index]
        if spot then return spot end
        spot = CreateFrame("Button", nil, holder)
        spot:RegisterForClicks("LeftButtonUp")
        local ghost = Outline(holder)
        ghost:SetAlpha(GHOST_ALPHA)
        spot.ghost = ghost
        own[spot], own[ghost] = true, true
        spot:SetScript("OnEnter", function(self)
            hovered = self
            ShowGhosts(true)
            Magnifier(true)
            preview.Point(self.parts[1], options.names and options.names(self.parts) or nil)
        end)
        spot:SetScript("OnLeave", function(self)
            if hovered == self then hovered = nil end
            Magnifier(false)
            preview.Point(nil)
            Later(CheckGhosts)
        end)
        spot:SetScript("OnClick", function(self)
            if options.find then options.find(self.parts) end
        end)
        preview.hotspots[index] = spot
        return spot
    end
    function preview.Hotspots()
        if not options.find then return end
        local names = {}
        for part in pairs(preview.parts) do names[#names + 1] = part end
        table.sort(names)
        local byRegion, regions = {}, {}
        for _, part in ipairs(names) do
            local list = preview.parts[part]()
            for _, region in ipairs(list or {}) do
                if region and region:IsShown() ~= false then
                    if not byRegion[region] then
                        byRegion[region] = {}
                        regions[#regions + 1] = region
                    end
                    table.insert(byRegion[region], part)
                end
            end
        end

        if options.names then
            local kept = {}
            for _, region in ipairs(regions) do
                local label = options.names(byRegion[region])
                if type(label) == "string" and label ~= "" then kept[#kept + 1] = region end
            end
            regions = kept
        end
        table.sort(regions, function(a, b) return Area(a) > Area(b) end)
        for index, region in ipairs(regions) do
            local spot = Spot(index)
            spot.region, spot.parts = region, byRegion[region]
            spot:ClearAllPoints()
            spot:SetPoint("TOPLEFT", region, "TOPLEFT", -1, 1)
            spot:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 1, -1)
            spot.ghost:ClearAllPoints()
            spot.ghost:SetPoint("TOPLEFT", region, "TOPLEFT", -1, 1)
            spot.ghost:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 1, -1)
            spot.ghost:SetShown(ghosts or preview.pulsing == true)
            spot:Show()
        end
        for index = #regions + 1, #preview.hotspots do
            preview.hotspots[index]:Hide()
            preview.hotspots[index].ghost:Hide()
        end
        shownSpots = #regions
    end
    if options.find then
        stage:EnableMouse(true)
        stage:SetScript("OnEnter", function() ShowGhosts(true) end)
        stage:SetScript("OnLeave", function() Later(CheckGhosts) end)

        local note = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        note:SetBackdrop(BACKDROP)
        note:SetBackdropColor(0.075, 0.08, 0.09, 0.92)
        note:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        note:SetPoint("TOPLEFT", stage, "TOPLEFT", 4, -4)
        note:SetHeight(16)
        local noteText = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noteText:SetPoint("LEFT", 6, 0)
        noteText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        noteText:SetText(FIND_NOTE)
        note:SetWidth((noteText:GetStringWidth() or 180) + 12)
        note:Hide()
        own[note] = true
        preview.note, preview.noteText = note, noteText
        local pulser = CreateFrame("Frame", nil, holder)
        own[pulser] = true
        preview.pulser = pulser
        local pulseStart = 0
        local function PulseStep()
            local t = GetTime() - pulseStart
            if t >= PULSE_BEAT * PULSE_BEATS then
                pulser:SetScript("OnUpdate", nil)
                preview.pulsing = false
                note:Hide()
                for index = 1, shownSpots do preview.hotspots[index].ghost:SetAlpha(GHOST_ALPHA) end
                ShowGhosts(Over(stage) or hovered ~= nil)
                return
            end
            local beat = (t % PULSE_BEAT) / PULSE_BEAT
            local alpha = 0.15 + 0.85 * math.sin(beat * math.pi)
            for index = 1, shownSpots do
                local ghost = preview.hotspots[index].ghost
                ghost:Show()
                ghost:SetAlpha(alpha)
            end
        end

        function preview.Pulse()
            pulseStart = GetTime()
            preview.pulsing = true
            note:Show()
            pulser:SetScript("OnUpdate", PulseStep)
            PulseStep()
        end
        holder:SetScript("OnShow", function() preview.Pulse() end)
        holder:HookScript("OnHide", function()
            pulser:SetScript("OnUpdate", nil)
            preview.pulsing = false
            note:Hide()
            hovered = nil
            ShowGhosts(false)
            Magnifier(false)
        end)
    end

    function preview.Settle()
        preview.Restart()
        preview.Hotspots()
        preview.Lift()
        if preview.pointed then preview.Point(preview.pointed, preview.pointedName) end
        if preview.marked then preview.Mark(preview.marked, preview.markedText) end
    end
    return preview
end

local GLOW_BEAT, GLOW_BEATS, GLOW_HOLD, GLOW_FADE = 0.6, 3, 2.6, 1.0
local POINTER_H, POINTER_LIFE, POINTER_CHECK, GLIDE = 22, 10, 0.1, 0.3
local GLOW_EDGE = { edgeFile = WHITE, edgeSize = 2 }

local function Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "number" then return nil end
    return value
end

local function Arrow(parent, layer, way, colour)
    local bars = {}
    colour = colour or GOLD
    for index, size in ipairs({ 7, 5, 3 }) do
        local bar = parent:CreateTexture(nil, layer or "OVERLAY")
        bar:SetColorTexture(colour[1], colour[2], colour[3], 1)
        if way == "right" then bar:SetSize(1, size) else bar:SetSize(size, 1) end
        bars[index] = bar
    end
    function bars.Place(point, relative, x, y)
        for index, bar in ipairs(bars) do
            bar:ClearAllPoints()
            if way == "right" then
                bar:SetPoint(point, relative, point, x + index - 1, y)
            else
                bar:SetPoint(point, relative, point, x + (7 - bar:GetWidth()) / 2, y + (way == "up" and (index - 2) or (2 - index)))
            end
        end
    end
    function bars.SetShown(on) for index = 1, 3 do bars[index]:SetShown(on) end end
    function bars.SetAlpha(alpha) for index = 1, 3 do bars[index]:SetAlpha(alpha) end end
    function bars.SetColour(c) for index = 1, 3 do bars[index]:SetColorTexture(c[1], c[2], c[3], 1) end end
    return bars
end
Kit.Arrow = Arrow

local glows, glowRunner = {}, nil
local function GlowStep()
    local now = GetTime()
    local live = false
    for strip, glow in pairs(glows) do
        local t = now - glow.start
        local pulse = GLOW_BEAT * GLOW_BEATS
        local fill, edge
        if t < pulse then
            local k = math.sin(((t % GLOW_BEAT) / GLOW_BEAT) * math.pi)
            fill, edge = 0.12 + 0.33 * k, 0.55 + 0.45 * k
        elseif t < pulse + GLOW_HOLD then
            fill, edge = 0.14, 1
        elseif t < pulse + GLOW_HOLD + GLOW_FADE then
            local k = 1 - (t - pulse - GLOW_HOLD) / GLOW_FADE
            fill, edge = 0.14 * k, k
        end
        if fill then
            live = true
            glow.fill:SetAlpha(fill)
            glow:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], edge)
            glow.arrow.SetAlpha(edge)
        else
            glow:Hide()
            glows[strip] = nil
        end
    end
    if not live and glowRunner then glowRunner:SetScript("OnUpdate", nil) end
end
local function Glow(strip)
    local glow = strip.kitGlow
    if not glow then
        glow = CreateFrame("Frame", nil, strip, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", -1, 1)
        glow:SetPoint("BOTTOMRIGHT", 1, -1)
        glow:SetBackdrop(GLOW_EDGE)
        local fill = glow:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", -2, 2)
        fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        glow.fill = fill
        glow.arrow = Arrow(glow, "OVERLAY", "right")
        glow.arrow.Place("LEFT", glow, -9, 0)
        strip.kitGlow = glow
    end
    local level = Level(strip)
    if level then SetLevel(glow, level + 2) end
    glow.start = GetTime()
    glow:Show()
    glows[strip] = glow
    if not glowRunner then glowRunner = CreateFrame("Frame") end
    glowRunner:SetScript("OnUpdate", GlowStep)
    GlowStep()
end
Kit.Glow = Glow

local function Span(region)
    if type(region.GetTop) ~= "function" then return nil end
    local top, bottom = Number(region:GetTop()), Number(region:GetBottom())
    local scale = Number(type(region.GetEffectiveScale) == "function" and region:GetEffectiveScale() or 1)
    if not top or not bottom or not scale then return nil end
    return top * scale, bottom * scale
end

local function OutOfSight(scroll, strips, names, margin)
    local top, bottom = Span(scroll)
    if not top then return nil end
    local below, above = {}, {}
    for index, strip in ipairs(strips) do
        local stripTop, stripBottom = Span(strip)
        if stripTop and strip:IsVisible() ~= false then
            local middle = (stripTop + stripBottom) / 2
            local entry = { name = names and names[index], top = stripTop, bottom = stripBottom }
            if middle < bottom + margin then
                below[#below + 1] = entry
            elseif middle > top - margin then
                above[#above + 1] = entry
            end
        end
    end
    table.sort(below, function(a, b) return a.top > b.top end)
    table.sort(above, function(a, b) return a.top < b.top end)
    return below, above, top, bottom
end

local function Glide(scroll, delta)
    local scale = Number(scroll:GetEffectiveScale()) or 1
    local from = Number(scroll:GetVerticalScroll()) or 0
    local range = Number(scroll:GetVerticalScrollRange()) or 0
    local to = math.max(0, math.min(range, from + delta / scale))
    local start = GetTime()
    local glider = scroll.kitGlider
    if not glider then
        glider = CreateFrame("Frame", nil, scroll)
        scroll.kitGlider = glider
    end
    glider:SetScript("OnUpdate", function(self)
        local t = math.min(1, (GetTime() - start) / GLIDE)
        local eased = 1 - (1 - t) * (1 - t)
        scroll:SetVerticalScroll(from + (to - from) * eased)
        if t >= 1 then self:SetScript("OnUpdate", nil) end
    end)
    glider:GetScript("OnUpdate")(glider)
end

local function Pointer(scroll)
    local pointer = scroll.kitPointer
    if pointer then return pointer end
    pointer = CreateFrame("Button", nil, scroll:GetParent() or scroll, "BackdropTemplate")
    pointer:SetHeight(POINTER_H)
    pointer:SetBackdrop(BACKDROP)
    pointer:SetBackdropColor(0.24, 0.20, 0.12, 0.97)
    pointer:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    pointer:RegisterForClicks("LeftButtonUp")
    local text = pointer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 24, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(1, 0.9, 0.6)
    pointer.text = text
    pointer.down = Arrow(pointer, "OVERLAY", "down")
    pointer.down.Place("LEFT", pointer, 9, 0)
    pointer.up = Arrow(pointer, "OVERLAY", "up")
    pointer.up.Place("LEFT", pointer, 9, 0)
    pointer:SetScript("OnEnter", function(self) self:SetBackdropColor(0.34, 0.27, 0.12, 0.97) end)
    pointer:SetScript("OnLeave", function(self) self:SetBackdropColor(0.24, 0.20, 0.12, 0.97) end)
    pointer:Hide()
    scroll.kitPointer = pointer
    return pointer
end

local function Plural(count, one, many) return count == 1 and one or many end

local function Aim(scroll, pointer)
    local below, above, top, bottom = OutOfSight(scroll, pointer.strips, pointer.names, POINTER_H + 4)
    if not below or (#below == 0 and #above == 0) or GetTime() - pointer.start > POINTER_LIFE then
        pointer:SetScript("OnUpdate", nil)
        pointer:Hide()
        return
    end
    local list, down = below, true
    if #below == 0 then list, down = above, false end
    local names = {}
    for _, entry in ipairs(list) do
        if entry.name and entry.name ~= "" then names[#names + 1] = entry.name end
    end
    local what = #list .. " " .. Plural(#list, "setting", "settings") .. (down and " further down" or " further up")
    if #names > 0 then what = what .. ": " .. table.concat(names, ", ") end
    pointer.text:SetText(what .. " · |cffffffffclick to show " .. Plural(#list, "it", "them") .. "|r")
    pointer.down.SetShown(down)
    pointer.up.SetShown(not down)
    pointer:ClearAllPoints()
    if down then
        pointer:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT", 4, 4)
        pointer:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -4, 4)
    else
        pointer:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -4)
        pointer:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -4, -4)
    end

    local edge = POINTER_H + 12
    if down then
        local first = (bottom + edge) - list[1].bottom
        local need = (bottom + edge) - list[#list].bottom
        local room = (top - 12) - list[1].top
        pointer.delta = math.max(first, math.min(need, room))
    else
        local first = (top - edge) - list[1].top
        local need = (top - edge) - list[#list].top
        local room = (bottom + 12) - list[1].bottom
        pointer.delta = math.min(first, math.max(need, room))
    end
    local level = Level(scroll)
    if level then SetLevel(pointer, level + 40) end
    pointer:Show()
end

function Kit.Found(scroll, strips, names)
    strips = strips or {}
    for _, strip in ipairs(strips) do Glow(strip) end
    if not scroll or #strips == 0 then return end
    local pointer = Pointer(scroll)
    pointer.strips, pointer.names, pointer.start = strips, names, GetTime()
    pointer:SetScript("OnClick", function(self)
        if self.delta then Glide(scroll, self.delta) end
        for _, strip in ipairs(self.strips) do Glow(strip) end
    end)
    local waited = 0
    pointer:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + (Number(elapsed) or 0)
        if waited < POINTER_CHECK then return end
        waited = 0
        Aim(scroll, self)
    end)

    local function First() Aim(scroll, pointer) end
    if C_Timer and C_Timer.After then C_Timer.After(0, First) else First() end
end

local CHIP_H, CHIP_GAP, CHIP_PAD, CHIP_MIN = 24, 6, 12, 64
local PICKER_TOP, PICKER_TITLE, PICKER_FOOT, PICKER_PAD = 4, 30, 22, 8
local RAIL_X, RAIL_W = 9, 3
local PANEL_FILL = { 0.15, 0.125, 0.07 }
local CHIP_FILL, CHIP_LIT = { 0.14, 0.145, 0.16 }, { 0.24, 0.20, 0.12 }
local PICKED_TEXT = { 0.08, 0.06, 0.02 }

function Kit.Picker(frame, options)
    options = options or {}
    local x, width = options.x or 14, options.width or 508
    local picker = { frame = frame, chips = {}, height = 0 }

    local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", x, -PICKER_TOP)
    panel:SetWidth(width)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(PANEL_FILL[1], PANEL_FILL[2], PANEL_FILL[3], 1)
    panel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    picker.panel = panel

    local shine = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    shine:SetBackdrop(EDGE)
    shine:SetBackdropBorderColor(1, 0.9, 0.55, 1)
    shine:SetAlpha(0)
    picker.shine = shine

    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    bar:SetWidth(RAIL_W)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", -RAIL_X, 0)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x - RAIL_X, 0)
    picker.bar = bar

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText(options.title or "Choose what to edit")
    picker.title = title
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 10, 1)
    hint:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    hint:SetTextColor(GREY[1], GREY[2], GREY[3])
    hint:SetText(options.hint or "")
    picker.hint = hint

    local foot = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    foot:SetJustifyH("LEFT")
    foot:SetWordWrap(false)
    picker.foot = foot
    local footArrow = Arrow(panel, "OVERLAY", "down")
    picker.footArrow = footArrow

    local function Picked() return options.get and options.get() end
    local function Chip(index)
        local chip = picker.chips[index]
        if chip then return chip end
        chip = CreateFrame("Button", nil, panel, "BackdropTemplate")
        chip:SetHeight(CHIP_H)
        chip:SetBackdrop(BACKDROP)
        chip:SetBackdropBorderColor(0, 0, 0, 1)
        chip:RegisterForClicks("LeftButtonUp")
        local gold = CreateFrame("Frame", nil, chip, "BackdropTemplate")
        gold:SetPoint("TOPLEFT", 1, -1)
        gold:SetPoint("BOTTOMRIGHT", -1, 1)
        gold:SetBackdrop(EDGE)
        gold:SetBackdropBorderColor(0.8, 0.62, 0.25, 1)
        gold:Hide()
        chip.gold = gold
        local label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER", 0, 0)
        label:SetWordWrap(false)
        chip.label = label
        function chip.Paint()
            local on = chip.choice and chip.choice.key == Picked()
            if on then
                chip:SetBackdropColor(GOLD[1], GOLD[2], GOLD[3], 1)
                label:SetTextColor(PICKED_TEXT[1], PICKED_TEXT[2], PICKED_TEXT[3])
                gold:Hide()
            else
                local fill = chip.hover and CHIP_LIT or CHIP_FILL
                chip:SetBackdropColor(fill[1], fill[2], fill[3], 1)
                label:SetTextColor(0.92, 0.92, 0.92)
                gold:SetShown(chip.hover == true)
            end
        end
        chip:SetScript("OnClick", function(self)
            if self.choice and options.set then options.set(self.choice.key) end
            picker.Refresh()
        end)
        chip:SetScript("OnEnter", function(self)
            self.hover = true
            self.Paint()
            if not self.choice then return end
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetText(self.choice.label)
            local tip = options.tip and options.tip(self.choice)
            GameTooltip:AddLine(tip or "Click to change it in the rows below.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
            Kit.PlaceTooltip(GameTooltip, self)
        end)
        chip:SetScript("OnLeave", function(self)
            self.hover = false
            self.Paint()
            GameTooltip:Hide()
        end)
        picker.chips[index] = chip
        return chip
    end

    function picker.Refresh()
        local choices = (options.choices and options.choices()) or {}
        local sizes = {}
        for index, choice in ipairs(choices) do
            local chip = Chip(index)
            chip.choice = choice

            chip.label:SetWidth(0)
            chip.label:SetText(choice.label or "")
            local textWidth = Number(chip.label:GetStringWidth()) or (#(choice.label or "") * 7)
            local chipWidth = math.min(width - 20, math.max(CHIP_MIN, math.ceil(textWidth) + 2 * CHIP_PAD))
            chip:SetWidth(chipWidth)
            chip.label:SetWidth(chipWidth - 2 * CHIP_PAD + 4)
            sizes[index] = { chipWidth, CHIP_H }
        end
        local places, height = Kit.Flow(sizes, width - 20, CHIP_GAP, CHIP_GAP)
        local pickedLabel
        for index, chip in ipairs(picker.chips) do
            local place = places[index]
            if place then
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + place.x, -(PICKER_TITLE + place.y))
                chip:Show()
                chip.Paint()
                if chip.choice.key == Picked() then pickedLabel = chip.choice.label end
            else
                chip:Hide()
                chip.choice = nil
            end
        end
        local footY = PICKER_TITLE + height + 8
        footArrow.Place("TOPLEFT", panel, 12, -(footY + 5))
        foot:ClearAllPoints()
        foot:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -footY)
        foot:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
        foot:SetTextColor(0.92, 0.92, 0.92)
        foot:SetText((options.noun and ("The rows below change " .. options.noun .. ": ") or "The rows below change: ")
            .. "|cffffd27a" .. (pickedLabel or "?") .. "|r")
        local panelHeight = footY + PICKER_FOOT - 4 + PICKER_PAD
        panel:SetHeight(panelHeight)
        local total = PICKER_TOP + panelHeight + 6
        if total ~= picker.height then
            picker.height = total
            if options.resize then options.resize(total) else frame:SetHeight(total) end
        end
        return total
    end

    local rail = frame:GetParent() and frame:GetParent():CreateTexture(nil, "ARTWORK") or nil
    local railFoot = rail and frame:GetParent():CreateTexture(nil, "ARTWORK") or nil
    if rail then
        rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
        rail:SetWidth(RAIL_W)
        railFoot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
        railFoot:SetSize(7, RAIL_W)
        rail:Hide()
        railFoot:Hide()
    end
    picker.rail, picker.railFoot = rail, railFoot
    function picker.Rail(frames)
        if frames then picker.railFrames = frames end
        if not rail then return end
        local last
        for _, row in ipairs(picker.railFrames or {}) do
            if row:IsShown() then last = row end
        end
        if not last or not frame:IsShown() then
            rail:Hide()
            railFoot:Hide()
            return
        end
        rail:ClearAllPoints()
        rail:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x - RAIL_X, 0)
        rail:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", x - RAIL_X, 2)
        railFoot:ClearAllPoints()
        railFoot:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 0, 0)
        rail:Show()
        railFoot:Show()
    end

    local pulseStart
    local function PulseStep(self)
        local t = GetTime() - pulseStart
        if t >= PULSE_BEAT * PULSE_BEATS then
            self:SetScript("OnUpdate", nil)
            shine:SetAlpha(0)
            return
        end
        shine:SetAlpha(math.sin(((t % PULSE_BEAT) / PULSE_BEAT) * math.pi))
    end
    function picker.Pulse()
        pulseStart = GetTime()
        shine:SetScript("OnUpdate", PulseStep)
        PulseStep(shine)
    end
    panel:SetScript("OnShow", function() picker.Pulse() end)
    panel:SetScript("OnHide", function()
        shine:SetScript("OnUpdate", nil)
        shine:SetAlpha(0)
    end)

    picker.Refresh()
    return picker
end

local MOVE_TOP, MOVE_TITLE, MOVE_BUTTON_H, MOVE_PAD = 4, 30, 24, 8
local UNLOCK_W, SCREEN_BUTTON_W = 128, 112
local MOVE_SCREEN_TIP = "Play samples on the real boxes for a few seconds, where they are now."

local function BigButton(parent, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, MOVE_BUTTON_H)
    button:SetBackdrop(BACKDROP)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button:RegisterForClicks("LeftButtonUp")
    local gold = CreateFrame("Frame", nil, button, "BackdropTemplate")
    gold:SetPoint("TOPLEFT", 1, -1)
    gold:SetPoint("BOTTOMRIGHT", -1, 1)
    gold:SetBackdrop(EDGE)
    gold:SetBackdropBorderColor(0.8, 0.62, 0.25, 1)
    gold:Hide()
    button.gold = gold
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER", 0, 0)
    label:SetWordWrap(false)
    button.label = label
    function button.Paint()
        if button.solid then
            local fill = button.hover and { 1, 0.86, 0.5 } or GOLD
            button:SetBackdropColor(fill[1], fill[2], fill[3], 1)
            label:SetTextColor(PICKED_TEXT[1], PICKED_TEXT[2], PICKED_TEXT[3])
            gold:Hide()
        else
            local fill = button.hover and CHIP_LIT or CHIP_FILL
            button:SetBackdropColor(fill[1], fill[2], fill[3], 1)
            label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            gold:SetShown(button.hover == true)
        end
    end
    button:SetScript("OnEnter", function(self)
        self.hover = true
        self.Paint()
        if not self.tipTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetText(self.tipTitle)
        GameTooltip:AddLine(self.tip, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
        Kit.PlaceTooltip(GameTooltip, self)
    end)
    button:SetScript("OnLeave", function(self)
        self.hover = false
        self.Paint()
        GameTooltip:Hide()
    end)
    return button
end

function Kit.Move(frame, options)
    options = options or {}
    local x, width = options.x or 14, options.width or 508
    local move = { frame = frame, chips = {}, height = 0 }
    local function Locked() return not options.locked or options.locked() == true end

    local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", x, -MOVE_TOP)
    panel:SetWidth(width)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(PANEL_FILL[1], PANEL_FILL[2], PANEL_FILL[3], 1)
    panel:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    move.panel = panel
    local shine = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    shine:SetBackdrop(EDGE)
    shine:SetBackdropBorderColor(1, 0.9, 0.55, 1)
    shine:SetAlpha(0)
    move.shine = shine

    local bar = panel:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    bar:SetWidth(RAIL_W + 1)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    move.bar = bar

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -8)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText(options.title or "Move the bars")
    move.title = title
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetWidth(width - 24)
    hint:SetTextColor(GREY[1], GREY[2], GREY[3])
    hint:SetText(options.hint or "")
    move.hint = hint

    local unlock = BigButton(panel, UNLOCK_W)
    move.unlock = unlock
    unlock:SetScript("OnClick", function()
        if Locked() then
            if options.setLocked then options.setLocked(false) end
        elseif options.setLocked then
            options.setLocked(true)
        end
        move.Refresh()
    end)
    local screen = BigButton(panel, SCREEN_BUTTON_W)
    screen.label:SetText("Show on screen")
    screen.tipTitle, screen.tip = "Show on screen", options.screenTip or MOVE_SCREEN_TIP
    screen:SetScript("OnClick", function()
        if options.onScreen then options.onScreen() end
    end)
    move.screen = screen
    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    move.status = status
    local how = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    how:SetJustifyH("LEFT")
    how:SetWordWrap(true)
    how:SetWidth(width - 24)
    how:SetTextColor(1, 0.72, 0.3)
    move.how = how

    local function Chip(index)
        local chip = move.chips[index]
        if chip then return chip end
        chip = CreateFrame("Button", nil, panel, "BackdropTemplate")
        chip:SetHeight(CHIP_H - 4)
        chip:SetBackdrop(BACKDROP)
        chip:SetBackdropBorderColor(0, 0, 0, 1)
        chip:RegisterForClicks("LeftButtonUp")
        local gold = CreateFrame("Frame", nil, chip, "BackdropTemplate")
        gold:SetPoint("TOPLEFT", 1, -1)
        gold:SetPoint("BOTTOMRIGHT", -1, 1)
        gold:SetBackdrop(EDGE)
        gold:SetBackdropBorderColor(0.8, 0.62, 0.25, 1)
        gold:Hide()
        chip.gold = gold
        local box = chip:CreateTexture(nil, "OVERLAY")
        box:SetSize(8, 8)
        box:SetPoint("LEFT", 8, 0)
        chip.box = box
        local label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", box, "RIGHT", 6, 0)
        label:SetWordWrap(false)
        chip.label = label
        function chip.Paint()
            local open = chip.part and chip.part.locked and chip.part.locked() == false
            local fill = chip.hover and CHIP_LIT or CHIP_FILL
            chip:SetBackdropColor(fill[1], fill[2], fill[3], 1)
            gold:SetShown(chip.hover == true)
            if open then
                box:SetColorTexture(1, 0.62, 0.1, 1)
                label:SetTextColor(1, 0.72, 0.3)
            else
                box:SetColorTexture(GREY[1], GREY[2], GREY[3], 1)
                label:SetTextColor(0.92, 0.92, 0.92)
            end
        end
        chip:SetScript("OnClick", function(self)
            local part = self.part
            if not part or not part.set then return end
            if part.locked and part.locked() == false then
                part.set(true)
            else
                part.set(false)
            end
            move.Refresh()
        end)
        chip:SetScript("OnEnter", function(self)
            self.hover = true
            self.Paint()
            if not self.part then return end
            local open = self.part.locked and self.part.locked() == false
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetText(self.part.label)
            GameTooltip:AddLine(open and "Unlocked. Click to lock it in place."
                or "Locked. Click to unlock just this one, so you can drag it.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
            Kit.PlaceTooltip(GameTooltip, self)
        end)
        chip:SetScript("OnLeave", function(self)
            self.hover = false
            self.Paint()
            GameTooltip:Hide()
        end)
        move.chips[index] = chip
        return chip
    end

    function move.Refresh()
        local locked = Locked()
        unlock.solid = locked
        unlock.label:SetText(locked and "Unlock to move" or "Lock in place")
        unlock.tipTitle = locked and "Unlock to move" or "Lock in place"
        unlock.tip = locked and (options.unlockTip or "Unlock the boxes: they show with samples so you can drag them.")
            or (options.lockTip or "Lock every box where it is.")
        unlock.Paint()
        screen.Paint()
        status:SetText(locked and (Kit.GREY .. "Locked|r") or (Kit.AMBER .. "Unlocked|r"))

        local y = MOVE_TITLE
        local hintText = options.hint or ""
        hint:ClearAllPoints()
        if hintText ~= "" then
            hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -y)
            y = y + (Number(hint:GetStringHeight()) or 12) + 6
        end
        unlock:ClearAllPoints()
        unlock:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -y)
        screen:ClearAllPoints()
        screen:SetPoint("LEFT", unlock, "RIGHT", 6, 0)
        status:ClearAllPoints()
        status:SetPoint("LEFT", screen, "RIGHT", 10, 0)
        y = y + MOVE_BUTTON_H + 6

        local parts = (options.parts and options.parts()) or {}
        local sizes = {}
        for index, part in ipairs(parts) do
            local chip = Chip(index)
            chip.part = part
            chip.label:SetWidth(0)
            chip.label:SetText(part.label or "")
            local textWidth = Number(chip.label:GetStringWidth()) or (#(part.label or "") * 6)
            local chipWidth = math.min(width - 28, math.max(CHIP_MIN, math.ceil(textWidth) + 30))
            chip:SetWidth(chipWidth)
            chip.label:SetWidth(chipWidth - 26)
            sizes[index] = { chipWidth, CHIP_H - 4 }
        end
        local places, chipsHeight = Kit.Flow(sizes, width - 28, CHIP_GAP, CHIP_GAP)
        for index, chip in ipairs(move.chips) do
            local place = places[index]
            if place then
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", panel, "TOPLEFT", 14 + place.x, -(y + place.y))
                chip:Show()
                chip.Paint()
            else
                chip:Hide()
                chip.part = nil
            end
        end
        if #parts > 0 then y = y + chipsHeight + 6 end

        local howText = options.how and (type(options.how) == "function" and options.how() or options.how) or nil
        how:ClearAllPoints()
        if not locked and howText and howText ~= "" then
            how:SetText(howText)
            how:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -y)
            how:Show()
            y = y + (Number(how:GetStringHeight()) or 12) + 4
        else
            how:SetText("")
            how:Hide()
        end

        local panelHeight = y + MOVE_PAD - 4
        panel:SetHeight(panelHeight)
        local total = MOVE_TOP + panelHeight + 6
        if total ~= move.height then
            move.height = total
            if options.resize then options.resize(total) else frame:SetHeight(total) end
        end
        return total
    end

    local pulseStart
    local function PulseStep(self)
        local t = GetTime() - pulseStart
        if t >= PULSE_BEAT * PULSE_BEATS then
            self:SetScript("OnUpdate", nil)
            shine:SetAlpha(0)
            return
        end
        shine:SetAlpha(math.sin(((t % PULSE_BEAT) / PULSE_BEAT) * math.pi))
    end
    function move.Pulse()
        pulseStart = GetTime()
        shine:SetScript("OnUpdate", PulseStep)
        PulseStep(shine)
    end
    panel:SetScript("OnShow", function() move.Refresh(); move.Pulse() end)
    panel:SetScript("OnHide", function()
        shine:SetScript("OnUpdate", nil)
        shine:SetAlpha(0)
    end)

    move.Refresh()
    return move
end

function Kit.MatchStrata(sample, holder)
    local strata = holder:GetFrameStrata()
    if issecretvalue and issecretvalue(strata) then return end
    if type(strata) ~= "string" then return end
    sample:SetFrameStrata(strata)
end

function Kit.Scale(width, scale, notes, room, height, roomHeight)
    room = room or 496
    scale = scale or 1
    local fit
    if width * scale > room then fit = room / width end
    if type(height) == "number" and type(roomHeight) == "number" and height > 0 and height * scale > roomHeight then
        local down = roomHeight / height
        if not fit or down < fit then fit = down end
    end
    if fit then
        if notes then notes[#notes + 1] = "shrunk to fit" end
        return fit
    elseif scale ~= 1 and notes then
        notes[#notes + 1] = math.floor(scale * 100 + 0.5) .. "%"
    end
    return scale
end

function Kit.Flow(sizes, room, gap, lineGap)
    room, gap, lineGap = room or 496, gap or 12, lineGap or 6
    local places, x, y, line, widest = {}, 0, 0, 0, 0
    for index, size in ipairs(sizes or {}) do
        local w, h = size[1] or size.width or 0, size[2] or size.height or 0
        if x > 0 and x + w > room then x, y, line = 0, y + line + lineGap, 0 end
        places[index] = { x = x, y = y }
        widest = math.max(widest, x + w)
        x = x + w + gap
        line = math.max(line, h)
    end
    return places, y + line, widest
end

function Kit.Copy(settings)
    local copy = {}
    for key, value in pairs(settings or {}) do copy[key] = value end
    return copy
end
