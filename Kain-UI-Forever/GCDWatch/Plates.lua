local _, KUI = ...

local ns = KUI.GCDWatch
local Public, Yes = ns.Public, ns.Yes

local records, pool = {}, {}
local present = {}
local opponent
local events = CreateFrame("Frame")
local enabled = false

local previewUntil = 0
local SAMPLE_GAP = 0.4
local ticker = CreateFrame("Frame")
local function Previewing() return GetTime() < previewUntil end

local function MatchLayer(frame, plate)
    local strata, level = plate:GetFrameStrata(), plate:GetFrameLevel()
    if Public(strata) and type(strata) == "string" then frame:SetFrameStrata(strata) end
    if Public(level) and type(level) == "number" then frame:SetFrameLevel(level + 5) end
end

local function Region(object)
    if type(object) == "table" and type(object.GetObjectType) == "function" then return object end
end
local function Anchors(plate)
    local unitFrame = Region(plate.UnitFrame)
    local container = unitFrame and Region(unitFrame.HealthBarsContainer)
    local health = container and (Region(container.healthBar) or container)
    local level = unitFrame and Region(unitFrame.PlayerLevelDiffFrame)
    return health or plate, level or health or plate
end

local function Place(frame, plate)
    local gap, position, size = ns.Get("offset"), ns.Get("position"), ns.Get("size")
    local health, right = Anchors(plate)
    frame:ClearAllPoints()
    if position == "left" then
        frame:SetPoint("TOPRIGHT", health, "LEFT", -gap, size / 2)
    elseif position == "right" then
        frame:SetPoint("TOPLEFT", right, "RIGHT", gap, size / 2)
    else
        frame:SetPoint("BOTTOM", health, "TOP", 0, gap)
    end
end
ns.PlaceSpot = Place

local function Detach(unit)
    local record = records[unit]
    if not record then return end
    records[unit] = nil
    record.spot:Stop()
    record.spot.frame:Hide()
    record.spot.frame:ClearAllPoints()
    record.spot.frame:SetParent(UIParent)
    record.plate = nil
    pool[#pool + 1] = record
end

local function Attach(unit)
    if records[unit] then Detach(unit) end
    if ns.Get("plates") ~= true or not (ns.Hostile(unit) or Previewing()) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local record = table.remove(pool)
    if not record then record = { spot = ns.NewSpot(UIParent, ns.Get("size")) } end
    record.plate, record.unit = plate, unit
    local frame = record.spot.frame
    frame:SetParent(plate)
    MatchLayer(frame, plate)
    record.spot:Style(ns.Get("size"))
    Place(frame, plate)
    frame:Show()
    records[unit] = record
    record.spot:Follow(unit, unit == opponent, true)
end

local function FindOpponent()
    local found, count = nil, 0
    for unit in pairs(present) do
        if ns.Opponent(unit) then
            count = count + 1
            found = found or unit
            local targeted = UnitIsUnit(unit, "target")
            if Public(targeted) and targeted == true then
                found, count = unit, 1
                break
            end
        end
    end
    if count ~= 1 then found = nil end
    if found == opponent then return end
    opponent = found
    for unit, record in pairs(records) do record.spot:Follow(unit, unit == opponent, false) end
end

local function Recheck(unit)
    if not present[unit] then return end
    local wanted = ns.Get("plates") == true and (ns.Hostile(unit) or Previewing())
    if wanted and not records[unit] then
        Attach(unit)
    elseif not wanted and records[unit] then
        Detach(unit)
    elseif records[unit] then
        records[unit].spot:Follow(unit, unit == opponent, false)
    end
end
local function RecheckAll()
    for unit in pairs(present) do Recheck(unit) end
    FindOpponent()
end
ns.PlatesRecheck = RecheckAll

events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_FACTION" then

        if Public(unit) and type(unit) == "string" and present[unit] then
            Recheck(unit)
            FindOpponent()
        elseif not Public(unit) or unit == "player" then
            RecheckAll()
        end
        return
    elseif event == "DUEL_FINISHED" or event == "PLAYER_TARGET_CHANGED" then
        RecheckAll()
        return
    end
    if not Public(unit) or type(unit) ~= "string" then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        present[unit] = true
        Attach(unit)
        FindOpponent()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        present[unit] = nil
        Detach(unit)
        FindOpponent()
    end
end)

local function Enable(on)
    if on and not enabled then
        for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FACTION", "DUEL_FINISHED",
            "PLAYER_TARGET_CHANGED" }) do
            events:RegisterEvent(event)
        end
        enabled = true

        for index = 1, 40 do
            local token = "nameplate" .. index
            if Yes(UnitExists(token)) then present[token] = true end
        end
        RecheckAll()
    elseif not on and enabled then
        events:UnregisterAllEvents()
        enabled = false
        ticker:SetScript("OnUpdate", nil)
        previewUntil = 0
        for unit in pairs(records) do Detach(unit) end
        for unit in pairs(present) do present[unit] = nil end
        opponent = nil
    end
end

local sampleIndex, nextSampleAt = 0, 0
local function StopSamples()
    ticker:SetScript("OnUpdate", nil)
    previewUntil = 0
    for _, record in pairs(records) do
        record.spot.cast.flash:Stop()
        record.spot.cast.button:SetAlpha(0)
    end
    if enabled then RecheckAll() end
end
local function SampleTick()
    local now = GetTime()
    if now >= previewUntil then return StopSamples() end
    if now < nextSampleAt then return end
    sampleIndex = sampleIndex % #ns.SAMPLES + 1
    local sample = ns.SampleEntry(ns.SAMPLES[sampleIndex])
    for _, record in pairs(records) do record.spot:Sample(sample) end
    nextSampleAt = now + ns.FlashLength() + SAMPLE_GAP
end
function ns.PlayPlates(seconds)
    if not enabled then return 0 end
    previewUntil = GetTime() + (seconds or 20)
    nextSampleAt, sampleIndex = 0, 0
    RecheckAll()
    ticker:SetScript("OnUpdate", SampleTick)
    SampleTick()
    return ns.PlateCount()
end

function ns.PlateCount()
    local count = 0
    for _ in pairs(records) do count = count + 1 end
    return count
end
function ns.OpponentShown() return opponent ~= nil end

function ns.PlateRecord(unit) return records[unit] end

local FOLLOW_KEYS = { casts = true, buffs = true, debuffs = true }
local PLACE_KEYS = { position = true, offset = true, size = true, name = true, nameSize = true, tenths = true }
function ns.PlatesApply(keys)
    for _, key in ipairs(keys) do
        if key == "plates" then
            Enable(ns.Active() and ns.Get("plates") == true)
        elseif FOLLOW_KEYS[key] then
            for unit, record in pairs(records) do record.spot:Follow(unit, unit == opponent, false) end
        elseif PLACE_KEYS[key] then
            for _, record in pairs(records) do
                record.spot:Style(ns.Get("size"))
                Place(record.spot.frame, record.plate)
            end
        end
    end
end

function ns.PlatesSetActive(active)
    Enable(active == true and ns.Get("plates") == true)
end
