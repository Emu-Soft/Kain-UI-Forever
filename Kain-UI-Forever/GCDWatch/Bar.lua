local _, KUI = ...

local ns = KUI.GCDWatch
local Public = ns.Public

local BAR_TITLE = "GCDWatch"
local STRIP_H, STRIP_GAP, GEAR_SIZE = 14, 2, 12
local STRIP_LINE, STRIP_FILL = { 0.8, 0.62, 0.25 }, { 0.075, 0.08, 0.09, 0.75 }
local GOLD, GREY = { 0.95, 0.76, 0.35 }, { 0.55, 0.55, 0.58 }
local GEAR_ART = "Interface\\WorldMap\\GEAR_64GREY"
local GRIP_DOTS = { { 0, 0 }, { 4, 0 }, { 8, 0 }, { 0, 4 }, { 4, 4 }, { 0, 8 } }
local GRIP_HINT = "Drag to resize. Double-click to reset to the default size."
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
local EDGE = { edgeFile = WHITE, edgeSize = 1 }
local SAMPLE_GAP = 0.4
local TICK = 0.1

local bar
local previewUntil = 0

local function PaintGrip(grip, color)
    for _, dot in ipairs(grip.dots) do dot:SetVertexColor(color[1], color[2], color[3], 1) end
end

function ns.BarFace(parent)
    local face = {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(1, 1)
    face.frame = frame
    local strip = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    strip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, STRIP_GAP)
    strip:SetSize(1, STRIP_H)
    strip:SetBackdrop(BACKDROP)
    strip:SetBackdropColor(STRIP_FILL[1], STRIP_FILL[2], STRIP_FILL[3], STRIP_FILL[4])
    strip:SetBackdropBorderColor(STRIP_LINE[1], STRIP_LINE[2], STRIP_LINE[3], 1)
    strip.title = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    strip.title:SetPoint("LEFT", strip, "LEFT", 4, 0)
    strip.title:SetText(BAR_TITLE)
    strip.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    face.strip = strip

    local gear = CreateFrame("Button", nil, strip, "BackdropTemplate")
    gear:SetSize(GEAR_SIZE, GEAR_SIZE)
    gear:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -1, -1)
    gear:SetBackdrop(BACKDROP)
    gear:SetBackdropColor(0.14, 0.145, 0.16, 1)
    gear:SetBackdropBorderColor(0, 0, 0, 1)
    gear.line = CreateFrame("Frame", nil, gear, "BackdropTemplate")
    gear.line:SetPoint("TOPLEFT", gear, "TOPLEFT", 1, -1)
    gear.line:SetPoint("BOTTOMRIGHT", gear, "BOTTOMRIGHT", -1, 1)
    gear.line:SetBackdrop(EDGE)
    gear.line:SetBackdropBorderColor(STRIP_LINE[1], STRIP_LINE[2], STRIP_LINE[3], 1)
    gear.line:Hide()
    gear.art = gear:CreateTexture(nil, "ARTWORK")
    gear.art:SetTexture(GEAR_ART)
    gear.art:SetSize(GEAR_SIZE - 2, GEAR_SIZE - 2)
    gear.art:SetPoint("CENTER", gear, "CENTER", 0, 0)
    face.gear = gear

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(12, 12)
    grip:SetPoint("CENTER", frame, "BOTTOMRIGHT", 3, -3)
    grip.dots = {}
    for _, at in ipairs(GRIP_DOTS) do
        local dot = grip:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(WHITE)
        dot:SetSize(2, 2)
        dot:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -1 - at[1], 1 + at[2])
        grip.dots[#grip.dots + 1] = dot
    end
    PaintGrip(grip, GREY)
    face.grip = grip
    local level = frame:GetFrameLevel()
    if Public(level) and type(level) == "number" then
        strip:SetFrameLevel(level + 5)
        gear:SetFrameLevel(level + 7)
        grip:SetFrameLevel(level + 10)
    end

    face.spot = ns.NewSpot(frame, 30)
    face.spot.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    function face.Lay(size, unlocked)
        face.spot:Style(size)
        local titleWidth = strip.title:GetStringWidth()
        if not (Public(titleWidth) and type(titleWidth) == "number" and titleWidth > 0 and titleWidth < 2000) then
            titleWidth = 60
        end
        local spotWidth = math.max(size, ns.Get("name") == true and math.max(60, size * 3) or size)
        local width = unlocked and math.max(spotWidth, math.ceil(titleWidth) + 4 + 4 + GEAR_SIZE + 1) or spotWidth
        frame:SetSize(width, ns.SpotHeight(size))
        face.spot.frame:ClearAllPoints()
        face.spot.frame:SetPoint("TOP", frame, "TOP", 0, 0)
        strip:SetWidth(width)
        strip:SetShown(unlocked)
        grip:SetShown(unlocked)
        if not unlocked then return width, 0 end
        return width + 9, STRIP_H + STRIP_GAP
    end
    return face
end

local function PlaceBar()
    if not bar or bar.moving then return end
    bar.frame:ClearAllPoints()
    bar.frame:SetPoint("TOPLEFT", UIParent, "CENTER", ns.Get("barX"), ns.Get("barY"))
end
local function StopMove()
    if not bar or not bar.moving then return end
    bar.moving = false
    bar.frame:StopMovingOrSizing()
    local left, top = bar.frame:GetLeft(), bar.frame:GetTop()
    local cx, cy = UIParent:GetCenter()
    if ns.Number(left) and ns.Number(top) and ns.Number(cx) and ns.Number(cy) then
        local limits = ns.Limits.barX
        ns.SetMany({ barX = math.max(limits[1], math.min(limits[2], math.floor(left - cx + 0.5))),
            barY = math.max(limits[1], math.min(limits[2], math.floor(top - cy + 0.5))) })
    end
    PlaceBar()
end
local function StartMove()
    if not bar or ns.Get("barLocked") == true or InCombatLockdown() then return end
    GameTooltip:Hide()
    bar.moving = true
    bar.frame:StartMoving()
end

local function BarTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(BAR_TITLE)
    if not InCombatLockdown() then GameTooltip:AddLine("Drag: move", 0.85, 0.85, 0.85) end
    GameTooltip:AddLine("Drag the corner: resize", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Right-click: lock", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Gear: settings", 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function ns.BarMenu(root)
    local function Check(label, key, tip)
        root:CreateCheckbox(label, function() return ns.Get(key) == true end,
            function() ns.Set(key, ns.Get(key) ~= true) end):SetTooltip(tip)
    end
    root:CreateTitle("What flashes")
    Check("Their casts", "casts", "An enemy's finished casts and instants, when the game tells addons about them: the spell is hidden from the addon, but its name and icon still show. Gold bar.")
    Check("Their new buffs", "buffs", "A buff new to the enemy, such as a shield, Ghost Wolf or Blood Fury, drawn by the game's own aura code. Green bar.")
    Check("Your new debuffs, in duels", "debuffs", "A debuff new to you, shown on your duel opponent's plate and on this bar while your opponent is your target. In a duel only they can have put it there. Red bar.")
    root:CreateTitle("Where")
    Check("Nameplates", "plates", "Flashes over every enemy nameplate.")
    Check("Spell name", "name", "The spell's name under the icon.")
    root:CreateSlider("Bar icon size", function() return ns.Get("barSize") end,
        function(value) ns.Set("barSize", value) end, 16, 64, 1, function(value) return value .. " px" end,
        ns.Default("barSize")):SetTooltip("How large the icon on this bar is (16 to 64 px). The grip in the unlocked bar's corner sets it too.")
    root:CreateSlider("Shown for", function() return ns.Get("tenths") end,
        function(value) ns.Set("tenths", value) end, 5, 40, 1, function(value) return string.format("%.1f s", value / 10) end,
        ns.Default("tenths")):SetTooltip("How long each flash stays while its bar runs down (0.5 to 4 s). 1.5 s is a global cooldown.")
    root:CreateDivider()
    root:CreateButton("All options...", function() if ns.OpenSettings then ns.OpenSettings() end end)
        :SetTooltip("Opens every GCDWatch setting in its settings window.")
end

local function OpenGear(gear)
    GameTooltip:Hide()
    if ns.FlatMenu then
        ns.FlatMenu.Open(gear, function(_, root) ns.BarMenu(root) end)
    elseif ns.OpenSettings then
        ns.OpenSettings()
    end
end

local function StopGrip(grip)
    grip.drag = nil
    grip:SetScript("OnUpdate", nil)
end
local function ReleaseGrip(grip)
    StopGrip(grip)
    local over = grip:IsMouseOver()
    if not (Public(over) and over == true) then PaintGrip(grip, GREY) end
end
local function WireGrip(grip)
    grip:RegisterForClicks("LeftButtonUp")
    grip:SetScript("OnEnter", function(self)
        PaintGrip(self, GOLD)
        if self.drag then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(GRIP_HINT)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        if not self.drag then PaintGrip(self, GREY) end
        GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or ns.Get("barLocked") == true then return end
        StopGrip(self)
        local scale = bar.frame:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        if not (ns.Number(scale) and scale > 0 and ns.Number(cx) and ns.Number(cy)) then return end
        GameTooltip:Hide()
        self.drag = { cx = cx, cy = cy, scale = scale, size = ns.Get("barSize") }
        self:SetScript("OnUpdate", function()
            local drag = self.drag
            if not drag or ns.Get("barLocked") == true then StopGrip(self); return end
            if not IsMouseButtonDown("LeftButton") then ReleaseGrip(self); return end
            local x, y = GetCursorPosition()
            if not (ns.Number(x) and ns.Number(y)) then return end

            local across = drag.size + (x - drag.cx) / drag.scale
            local down = drag.size + (drag.cy - y) / drag.scale
            local wanted = math.abs(across - drag.size) >= math.abs(down - drag.size) and across or down
            local limits = ns.Limits.barSize
            local snapped = math.max(limits[1], math.min(limits[2], math.floor(wanted + 0.5)))
            if snapped ~= ns.Get("barSize") then ns.Set("barSize", snapped) end
        end)
    end)
    grip:SetScript("OnMouseUp", ReleaseGrip)
    grip:SetScript("OnHide", function(self)
        StopGrip(self)
        PaintGrip(self, GREY)
    end)
    grip:SetScript("OnDoubleClick", function()
        if ns.Get("barLocked") == true then return end
        ns.Set("barSize", ns.Default("barSize"))
    end)
end

local function NextSample(now)
    bar.sampleIndex = (bar.sampleIndex or 0) % #ns.SAMPLES + 1
    bar.face.spot:Sample(ns.SampleEntry(ns.SAMPLES[bar.sampleIndex]))
    bar.nextSampleAt = now + ns.FlashLength() + SAMPLE_GAP
end

local UpdateBar
local function OnBarUpdate(_, elapsed)
    bar.elapsed = (bar.elapsed or 0) + (elapsed or 0)
    if bar.elapsed < TICK then return end
    bar.elapsed = 0
    local now = GetTime()
    if not bar.unlocked and now >= previewUntil then
        UpdateBar()
        return
    end
    if now >= (bar.nextSampleAt or 0) then NextSample(now) end
end

local function MakeBar()
    local face = ns.BarFace(UIParent)
    local frame = face.frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    face.strip:EnableMouse(true)
    face.strip:RegisterForDrag("LeftButton")
    for _, region in ipairs({ frame, face.strip }) do
        region:SetScript("OnDragStart", StartMove)
        region:SetScript("OnDragStop", StopMove)
        region:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" and ns.Get("barLocked") ~= true then ns.Set("barLocked", true) end
        end)
        region:SetScript("OnEnter", BarTooltip)
        region:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    end
    frame:SetScript("OnHide", StopMove)
    local gear = face.gear
    gear:EnableMouse(true)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnEnter", function(self)
        self.line:Show()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(self)
        self.line:Hide()
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    gear:SetScript("OnClick", OpenGear)
    WireGrip(face.grip)
    bar = { face = face, frame = frame }
    PlaceBar()
end

local function TargetIsOpponent()
    return ns.Opponent("target")
end

function UpdateBar(fresh)

    local active = ns.Active()
    local on = active and ns.Get("bar") == true
    local previewing = active and GetTime() < previewUntil
    if not on and not previewing then
        if bar then
            bar.frame:SetScript("OnUpdate", nil)
            bar.face.spot:Stop()
            bar.frame:Hide()
        end
        return
    end
    if not bar then MakeBar() end
    local unlocked = on and ns.Get("barLocked") ~= true
    local sampling = unlocked or previewing
    bar.unlocked = unlocked
    bar.frame:EnableMouse(unlocked)
    PlaceBar()
    bar.face.Lay(ns.Get("barSize"), unlocked)
    if sampling then
        bar.face.spot:Stop()
        if not bar.sampling then bar.nextSampleAt = 0 end
        bar.frame:SetScript("OnUpdate", OnBarUpdate)
    else
        bar.frame:SetScript("OnUpdate", nil)
        bar.face.spot:Follow("target", TargetIsOpponent(), fresh == true or bar.sampling == true)
    end
    bar.sampling = sampling
    bar.frame:Show()
end

function ns.PlayBar(seconds)
    previewUntil = GetTime() + (seconds or 20)
    UpdateBar()
end

function ns.Bar() return bar end

local BAR_KEYS = { playersOnly = true, bar = true, barLocked = true, barSize = true, barX = true, barY = true, name = true, nameSize = true, tenths = true,
    casts = true, buffs = true, debuffs = true }
function ns.BarApply(keys)
    for _, key in ipairs(keys) do
        if BAR_KEYS[key] then
            UpdateBar()
            return
        end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateBar(true)
    elseif event == "UNIT_FACTION" then

        if not Public(unit) or unit == "target" or unit == "player" then UpdateBar() end
    elseif event == "DUEL_FINISHED" then
        UpdateBar()
    elseif event == "PLAYER_LEAVING_WORLD" then

        StopMove()
        if bar then StopGrip(bar.face.grip) end
    end
end)

local BAR_EVENTS = { "PLAYER_TARGET_CHANGED", "UNIT_FACTION", "DUEL_FINISHED", "PLAYER_LEAVING_WORLD" }
function ns.BarSetActive(active)
    if active then
        for _, event in ipairs(BAR_EVENTS) do
            if not events:IsEventRegistered(event) then events:RegisterEvent(event) end
        end
    else
        events:UnregisterAllEvents()
        previewUntil = 0
        StopMove()
        if bar then StopGrip(bar.face.grip) end
    end
    UpdateBar(true)
end
