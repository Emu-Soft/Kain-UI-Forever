local _, KUI = ...

local ns = KUI.GCDWatch
local Public, Yes = ns.Public, ns.Yes

local MAX_BUTTONS = 40
local FADE_IN, FADE_OUT = 0.1, 0.3
local WHITE = "Interface\\Buttons\\WHITE8X8"
ns.COLORS = {
    cast = { 0.95, 0.76, 0.35 },
    buff = { 0.3, 0.85, 0.35 },
    debuff = { 0.9, 0.25, 0.2 },
}

local available, broken
local feeds = {}
local pending = false

local function Available()
    if available == nil then
        available = type(AuraContainerSortMethod) == "table" and type(AuraContainerSortMethod.AuraInstanceIDOnly) == "number"
            and type(AuraContainerSortDirection) == "table" and type(AuraContainerSortDirection.Reverse) == "number"
            and type(AnchorUtil) == "table" and type(AnchorUtil.FlowLayoutAxis) == "table"
            and type(AnchorUtil.FlowDirection) == "table"
    end
    return available and not broken
end
function ns.FlashAvailable() return Available() == true end

local function CanTouch()
    if type(C_Secrets) ~= "table" or type(C_Secrets.ShouldAurasBeSecret) ~= "function" then return true end
    local secret = C_Secrets.ShouldAurasBeSecret()
    return Public(secret) and secret == false
end

function ns.Hostile(unit)
    if not unit or not Yes(UnitExists(unit)) then return false end
    local me = UnitIsUnit(unit, "player")
    if Public(me) and me then return false end
    local hostile = UnitCanAttack("player", unit)
    return not Public(hostile) or hostile == true
end

function ns.Watched(unit)
    if not ns.Hostile(unit) then return false end
    if ns.Get("playersOnly") ~= true then return true end
    local isPlayer = UnitIsPlayer(unit)
    if Public(isPlayer) then return isPlayer == true end
    local _, kind = IsInInstance()
    return Public(kind) and (kind == "pvp" or kind == "arena")
end

function ns.Opponent(unit)
    if not unit or not Yes(UnitExists(unit)) or not Yes(UnitIsPlayer(unit)) then return false end
    if not Yes(UnitCanAttack("player", unit)) then return false end
    local inside = IsInInstance()
    if not Public(inside) or inside == true then return false end
    local mine, theirs = UnitFactionGroup("player"), UnitFactionGroup(unit)
    return ns.Text(mine) and ns.Text(theirs) and mine ~= "" and mine == theirs
end

local function NameFont(label, size)
    local file, _, flags = GameFontHighlightSmall:GetFont()
    if file then label:SetFont(file, size, flags ~= "" and flags or "OUTLINE") end
end

local SWEEP_DARK = 0.64
local function Clip(frame)
    local clip = CreateFrame("Frame", nil, frame)
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    local inner = CreateFrame("Frame", nil, clip)
    inner:SetAllPoints(clip)
    inner:EnableMouse(false)
    return clip, inner
end
local function Turn(group, target, origin)
    local turn = group:CreateAnimation("Rotation")
    turn:SetTarget(target)
    turn:SetOrigin(origin, 0, 0)
    turn:SetSmoothing("NONE")
    turn:SetOrder(2)
    return turn
end

function ns.BuildParts(frame)
    local p = { button = frame }
    p.edge = frame:CreateTexture(nil, "BACKGROUND")
    p.edge:SetColorTexture(0, 0, 0, 1)
    p.line = frame:CreateTexture(nil, "BORDER")
    p.line:SetTexture(WHITE)
    p.icon = frame:CreateTexture(nil, "ARTWORK")
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local inner
    p.rightClip, inner = Clip(frame)
    p.rightDark = inner:CreateTexture(nil, "ARTWORK")
    p.rightDark:SetColorTexture(0, 0, 0, SWEEP_DARK)
    p.leftClip, inner = Clip(frame)
    p.leftDark = inner:CreateTexture(nil, "ARTWORK")
    p.leftDark:SetColorTexture(0, 0, 0, SWEEP_DARK)
    p.handClip, inner = Clip(frame)
    p.hand = inner:CreateTexture(nil, "OVERLAY")
    p.hand:SetTexture(WHITE)
    p.hand:SetVertexColor(1, 0.9, 0.55, 0.9)
    p.hand:SetBlendMode("ADD")
    p.name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.name:SetJustifyH("CENTER")
    p.name:SetWordWrap(false)

    local flash = frame:CreateAnimationGroup()
    flash:SetToFinalAlpha(true)
    local into = flash:CreateAnimation("Alpha")
    into:SetFromAlpha(0)
    into:SetToAlpha(1)
    into:SetDuration(FADE_IN)
    into:SetOrder(1)
    local hold = flash:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetOrder(2)
    p.rightTurn = Turn(flash, p.rightDark, "LEFT")
    p.rightTurn:SetDegrees(-180)
    p.leftTurn = Turn(flash, p.leftDark, "RIGHT")
    p.leftTurn:SetDegrees(-180)
    p.handTurn = Turn(flash, p.hand, "BOTTOM")
    p.handTurn:SetDegrees(-360)
    local out = flash:CreateAnimation("Alpha")
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(FADE_OUT)
    out:SetOrder(3)
    p.flash, p.hold = flash, hold
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    return p
end

function ns.FlashHeight(size) return size end

function ns.SpotHeight(size)
    return ns.FlashHeight(size) + (ns.Get("name") == true and ((ns.Get("nameSize") or 10) + 3) or 0)
end

function ns.FlashLength() return FADE_IN + ns.Seconds() + FADE_OUT end

function ns.StyleParts(p, look)
    local frame, size = p.button, look.size
    frame:SetSize(size, ns.FlashHeight(size))
    p.edge:ClearAllPoints()
    p.edge:SetPoint("TOPLEFT", 0, 0)
    p.edge:SetSize(size, size)
    p.line:ClearAllPoints()
    p.line:SetPoint("TOPLEFT", 1, -1)
    p.line:SetSize(size - 2, size - 2)
    p.icon:ClearAllPoints()
    p.icon:SetPoint("TOPLEFT", 2, -2)
    p.icon:SetSize(size - 4, size - 4)
    if look.color then p.line:SetVertexColor(look.color[1], look.color[2], look.color[3], 1) end
    p.name:ClearAllPoints()
    p.name:SetPoint("TOP", frame, "TOP", 0, -(ns.FlashHeight(size) + 1))
    p.name:SetWidth(math.max(60, size * 3))
    NameFont(p.name, look.nameSize)
    p.name:SetShown(look.name)

    local inner, seconds = size - 4, look.seconds
    p.rightClip:ClearAllPoints()
    p.rightClip:SetPoint("TOPLEFT", p.icon, "TOP")
    p.rightClip:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT")
    p.rightDark:ClearAllPoints()
    p.rightDark:SetPoint("LEFT", p.rightClip, "LEFT")
    p.rightDark:SetSize(inner, inner * 2)
    p.leftClip:ClearAllPoints()
    p.leftClip:SetPoint("TOPLEFT", p.icon, "TOPLEFT")
    p.leftClip:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOM")
    p.leftDark:ClearAllPoints()
    p.leftDark:SetPoint("RIGHT", p.leftClip, "RIGHT")
    p.leftDark:SetSize(inner, inner * 2)
    p.handClip:ClearAllPoints()
    p.handClip:SetAllPoints(p.icon)
    p.hand:ClearAllPoints()
    p.hand:SetPoint("BOTTOM", p.handClip, "CENTER")
    p.hand:SetSize(2, inner * 0.75)
    p.hold:SetDuration(seconds)
    p.rightTurn:SetDuration(seconds / 2)
    p.leftTurn:SetStartDelay(seconds / 2)
    p.leftTurn:SetDuration(seconds / 2)
    p.handTurn:SetDuration(seconds)
end

function ns.Look(size, color)
    return { size = size, name = ns.Get("name") == true, nameSize = ns.Get("nameSize") or 10,
        seconds = ns.Seconds(), color = color }
end

function ns.PlayParts(p, name, icon, color)
    if color then p.line:SetVertexColor(color[1], color[2], color[3], 1) end
    p.icon:SetTexture(icon)
    p.name:SetText(name)
    p.flash:Stop()
    p.flash:Play()
end

local Feed = {}
Feed.__index = Feed

local function NewFeed(spot, kind)
    local self = setmetatable({ spot = spot, kind = kind, filter = kind == "buff" and "HELPFUL" or "HARMFUL",
        unit = "none", parts = {}, settleUntil = 0, token = 0 }, Feed)
    feeds[#feeds + 1] = self
    return self
end

function Feed:InitButton(button)
    local p = ns.BuildParts(button)
    ns.StyleParts(p, ns.Look(self.spot.size, ns.COLORS[self.kind]))
    button:SetIcon(p.icon)
    button:SetSpellName(p.name)
    button:AddAuraAssignedAnimation(p.flash)
    self.parts[#self.parts + 1] = p
end

function Feed:Build()
    if self.container then return true end
    if not Available() then return false end
    local holder = CreateFrame("Frame", nil, self.spot.frame)
    holder:SetSize(1, 1)
    holder:EnableMouse(false)
    holder:SetAlpha(0)
    holder:SetPoint("TOPLEFT", self.spot.frame, "TOPLEFT", 0, 0)
    local level = self.spot.frame:GetFrameLevel()
    if Public(level) and type(level) == "number" then holder:SetFrameLevel(level + (self.kind == "buff" and 2 or 1)) end
    broken = true
    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetEditModePreviewEnabled(false)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:AddAuraGroup(self.kind, self.filter, {
        maxFrameCount = MAX_BUTTONS,
        sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        layout = { lineSpacing = 1 },
        initializeFrame = function(button) self:InitButton(button) end,
    })
    broken = false
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    self.holder, self.container = holder, container
    return true
end

function Feed:UpdateShown()
    if not self.holder then return end
    self.holder:SetAlpha((self.unit ~= "none" and GetTime() >= self.settleUntil) and 1 or 0)
end

function Feed:SetUnit(unit, fresh)
    if unit == self.unit and not fresh then return end
    if unit == "none" and self.unit == "none" then return end
    if unit ~= "none" and not self:Build() then return end
    if not self.container then return end
    self.container:SetUnit("none")
    if unit ~= "none" then self.container:SetUnit(unit) end
    self.unit = unit
    self.settleUntil = GetTime() + ns.FlashLength() + 0.1
    self:UpdateShown()
    if unit ~= "none" and C_Timer and C_Timer.After then
        self.token = self.token + 1
        local token = self.token
        C_Timer.After(ns.FlashLength() + 0.1, function()
            if self.token == token then self:UpdateShown() end
        end)
    end
end

local function RestyleAll()
    if not CanTouch() then
        pending = true
        return false
    end
    pending = false
    for _, feed in ipairs(feeds) do
        for _, p in ipairs(feed.parts) do ns.StyleParts(p, ns.Look(feed.spot.size, ns.COLORS[feed.kind])) end
    end
    return true
end
ns.RestyleAll = RestyleAll
function ns.RestylePending() return pending end

local Spot = {}
Spot.__index = Spot

function ns.NewSpot(parent, size)
    local self = setmetatable({ size = size, unit = nil }, Spot)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    self.frame = frame

    local castFrame = CreateFrame("Frame", nil, frame)
    castFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local level = frame:GetFrameLevel()
    if Public(level) and type(level) == "number" then castFrame:SetFrameLevel(level + 3) end
    self.cast = ns.BuildParts(castFrame)
    self.buffs, self.debuffs = NewFeed(self, "buff"), NewFeed(self, "debuff")
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
    self:Style(size)
    return self
end

function Spot:Style(size)
    self.size = size
    self.frame:SetSize(math.max(size, 1), ns.SpotHeight(size))
    ns.StyleParts(self.cast, ns.Look(size, ns.COLORS.cast))
end

function Spot:Follow(unit, opponent, fresh)
    local enemy = unit ~= nil and ns.Watched(unit)
    local castUnit = (enemy and ns.Get("casts") == true) and unit or nil
    if castUnit ~= self.castUnit then
        self.events:UnregisterAllEvents()
        if castUnit then self.events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", castUnit) end
        self.castUnit = castUnit
    end
    if fresh or unit ~= self.unit then
        self.cast.flash:Stop()
        self.cast.button:SetAlpha(0)
    end
    self.unit = unit
    self.buffs:SetUnit((enemy and ns.Get("buffs") == true) and unit or "none", fresh)

    self.debuffs:SetUnit((opponent and ns.Get("debuffs") == true) and "player" or "none", false)
    self.opponent = opponent == true
end

function Spot:Stop()
    self:Follow(nil, false, false)
end

function Spot:OnEvent(event, unit, _, spellID)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end

    if Public(unit) and unit ~= self.castUnit then return end
    if Public(spellID) and spellID == nil then return end
    local name = C_Spell.GetSpellName(spellID)
    local icon = C_Spell.GetSpellTexture(spellID)
    ns.PlayParts(self.cast, name, icon, ns.COLORS.cast)
end

function Spot:Sample(sample)
    ns.PlayParts(self.cast, sample.name, sample.icon, ns.COLORS[sample.kind])
end

local LOOK_KEYS = { name = true, nameSize = true, tenths = true, size = true, barSize = true }
function ns.FlashApply(keys)
    for _, key in ipairs(keys) do
        if LOOK_KEYS[key] then
            RestyleAll()
            return
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending and RestyleAll() and ns.RefreshSettings then ns.RefreshSettings() end
end)

local QUESTION_MARK = 134400
ns.SAMPLES = {
    { kind = "cast", spell = 2136, name = "Fire Blast", caption = "their cast" },
    { kind = "buff", spell = 17, name = "Power Word: Shield", caption = "their new buff" },
    { kind = "debuff", spell = 5116, name = "Concussive Shot", caption = "your new debuff, in a duel" },
}
function ns.SampleEntry(sample)
    local name, icon = C_Spell.GetSpellName(sample.spell), C_Spell.GetSpellTexture(sample.spell)
    return { kind = sample.kind, caption = sample.caption,
        name = ns.Text(name) and name or sample.name, icon = ns.Number(icon) and icon or QUESTION_MARK }
end
