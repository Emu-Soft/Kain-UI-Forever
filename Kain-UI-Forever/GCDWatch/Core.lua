local _, KUI = ...

local ns = {}
KUI.GCDWatch = ns

local MOTHER = "ForeverGCD"
local PREFIX = "|cff33ff99GCDWatch:|r "
ns.TITLE = "GCDWatch"
ns.BASED_ON = "Forever GCD 0.3.0 by Tarolg"

local function IsSecret(value) return issecretvalue ~= nil and issecretvalue(value) end
function ns.Public(value) return not IsSecret(value) end
function ns.Yes(value) return not IsSecret(value) and value == true end
function ns.Number(value) return not IsSecret(value) and type(value) == "number" end
function ns.Text(value) return not IsSecret(value) and type(value) == "string" end

ns.POSITIONS = { "left", "right", "above" }
ns.POSITION_LABELS = { above = "Above", left = "Left", right = "Right" }

local defaults = {

    casts = true, buffs = true, debuffs = true,

    playersOnly = true,

    plates = true, position = "left", size = 45, offset = 4,

    name = true, nameSize = 10, tenths = 15,

    bar = false, barLocked = true, barSize = 45, barX = -20, barY = -120 }

local limits = { size = { 16, 64 }, offset = { -20, 60 }, nameSize = { 8, 20 }, tenths = { 5, 40 },
    barSize = { 16, 64 }, barX = { -4000, 4000 }, barY = { -4000, 4000 } }
local choices = { position = ns.POSITIONS }
ns.Limits, ns.Choices = limits, choices
ns.Version = ns.BASED_ON
local db

local function Valid(key, value)
    if type(value) ~= type(defaults[key]) then return false end
    if choices[key] then
        for _, option in ipairs(choices[key]) do
            if option == value then return true end
        end
        return false
    end
    if type(value) ~= "number" then return true end
    if value ~= value or value == math.huge or value == -math.huge or value ~= math.floor(value) then return false end
    if limits[key] then return value >= limits[key][1] and value <= limits[key][2] end
    return true
end

local MAX_OPEN_GROUPS = 200
local function ValidOpenGroups(groups)
    if type(groups) ~= "table" then return false end
    local count = 0
    for key, open in pairs(groups) do
        count = count + 1
        if type(key) ~= "string" or type(open) ~= "boolean" or count > MAX_OPEN_GROUPS then return false end
    end
    return true
end

local function Load()
    if not KUI.db then return false end
    local saved = KUI.db.gcdWatchSettings
    if db and db == saved then return true end
    if type(saved) ~= "table" then
        saved = {}
        KUI.db.gcdWatchSettings = saved
    end
    for key, value in pairs(defaults) do
        if not Valid(key, saved[key]) then saved[key] = value end
    end
    if not ValidOpenGroups(saved.openGroups) then saved.openGroups = {} end
    db = saved
    return true
end
ns.Load = Load

function ns.Get(key)
    if db then return db[key] end
    return defaults[key]
end

function ns.Set(key, value)
    if not Load() or defaults[key] == nil or not Valid(key, value) then return end
    if db[key] == value then return end
    db[key] = value
    ns.ApplyMany({ key })
end
function ns.Default(key) return defaults[key] end
function ns.Seconds() return (ns.Get("tenths") or defaults.tenths) / 10 end

function ns.SetMany(values)
    if not Load() then return end
    local changed = {}
    for key, value in pairs(values) do
        if defaults[key] ~= nil and Valid(key, value) and db[key] ~= value then
            db[key] = value
            changed[#changed + 1] = key
        end
    end
    if #changed > 0 then ns.ApplyMany(changed) end
end
function ns.ResetBarPosition() ns.SetMany({ barX = defaults.barX, barY = defaults.barY }) end

function ns.ApplyMany(keys)
    if ns.FlashApply then ns.FlashApply(keys) end
    if ns.PlatesApply then ns.PlatesApply(keys) end
    if ns.BarApply then ns.BarApply(keys) end
    if ns.RefreshSettings then ns.RefreshSettings() end
end

function ns.GroupOpen(title)
    local groups = db and db.openGroups
    if type(groups) ~= "table" then return nil end
    return groups[title]
end
function ns.SetGroupOpen(title, open)
    local groups = db and db.openGroups
    if type(groups) ~= "table" or type(title) ~= "string" then return end
    if groups[title] == nil then
        local count = 0
        for _ in pairs(groups) do count = count + 1 end
        if count >= MAX_OPEN_GROUPS then return end
    end
    groups[title] = open == true
end

function ns.Yielded()
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then return false end
    local ok, loading, loaded = pcall(C_AddOns.IsAddOnLoaded, MOTHER)
    if not ok then return false end
    return ns.Yes(loading) or ns.Yes(loaded)
end

function ns.Active()
    return KUI.db ~= nil and KUI.db.gcdWatch == true and Load() and not ns.Yielded()
end

function ns.StatusText()
    if ns.Yielded() then return "Forever GCD is installed, so it does this job and GCDWatch stays off" end
    if not ns.Active() then return "off: turn it on in Kain-UI's settings under Nameplates, or with /kui gcdw on" end
    if not ns.FlashAvailable() then
        return "this build has no Blizzard aura container, so only casts can flash, not buffs or debuffs"
    end
    local count = ns.PlateCount and ns.PlateCount() or 0
    local words = count .. (count == 1 and " enemy plate" or " enemy plates") .. " watched"
    if ns.Get("plates") ~= true then words = "plates off" end
    if ns.OpponentShown and ns.OpponentShown() then words = words .. " · duel opponent found" end
    return words
end

ns.COMMAND = "/kui gcdw"
ns.COMMANDS = {
    { "", "open settings and list these commands" },
    { "on", "turn GCDWatch on" },
    { "off", "turn GCDWatch off" },
    { "status", "say how many enemy plates are watched" },
    { "unlock", "turn the target bar on and unlock it to move" },
    { "lock", "lock the target bar" },
    { "preview", "play sample flashes on nameplates and the target bar for 20 seconds" },
    { "options", "open settings" },
    { "help", "list these commands" },
}

function ns.PlaySamples(seconds)
    if not ns.Active() then return "GCDWatch is off, so there is nothing to show. " .. ns.COMMAND .. " on turns it on." end
    local count = ns.PlayPlates(seconds)
    ns.PlayBar(seconds)
    local where = count == 0 and "the target bar (no nameplates on screen)"
        or (count .. (count == 1 and " nameplate" or " nameplates") .. " and the target bar")
    return "sample flashes on " .. where .. " for " .. seconds .. " seconds."
end

local function PrintHelp()
    print(PREFIX .. "commands")
    for _, command in ipairs(ns.COMMANDS) do
        print(ns.COMMAND .. (command[1] ~= "" and (" " .. command[1]) or "") .. " - " .. command[2])
    end
end

local function OpenMother()
    local open = type(SlashCmdList) == "table" and SlashCmdList.FOREVERGCD
    if type(open) == "function" then
        open("options")
    else
        print(PREFIX .. "Forever GCD is installed, so it does this job: type /fgcd for its settings.")
    end
end

local warnedAura, warnedYield = false, false
function KUI:ApplyGCDWatch()
    if not Load() then return end
    local yielded = ns.Yielded()
    local active = ns.Active()
    if yielded and self.db.gcdWatch == true and not warnedYield then
        warnedYield = true
        print(PREFIX .. "Forever GCD is installed, so it does this job and GCDWatch stays off.")
    end
    if active and not warnedAura and not ns.FlashAvailable() then
        warnedAura = true
        print(PREFIX .. "this build has no Blizzard aura container (Blizzard_AuraContainer), so only casts can flash, not buffs or debuffs.")
    end
    if ns.PlatesSetActive then ns.PlatesSetActive(active) end
    if ns.BarSetActive then ns.BarSetActive(active) end
    if ns.RefreshSettings then ns.RefreshSettings() end
end

function KUI:SetGCDWatch(on)
    if not self.db then return end
    self.db.gcdWatch = on == true
    self:ApplyGCDWatch()
end

function KUI:IsGCDWatchYielded() return ns.Yielded() end

function KUI:OpenGCDWatchSettings()
    if ns.Yielded() then return OpenMother() end
    if ns.OpenSettings then ns.OpenSettings() end
end

function KUI:GCDWatchCommand(message)
    local command = (type(message) == "string" and message or ""):lower():match("^%s*(%a*)") or ""
    if ns.Yielded() then
        if command == "" or command == "options" then OpenMother() end
        print(PREFIX .. "Forever GCD is installed, so it does this job and GCDWatch stays off. Use /fgcd for its commands.")
        return
    end
    if command == "" then
        self:OpenGCDWatchSettings()
        PrintHelp()
    elseif command == "options" then
        self:OpenGCDWatchSettings()
    elseif command == "on" or command == "off" then
        self:SetGCDWatch(command == "on")
        print(PREFIX .. (command == "on" and "on." or "off."))
    elseif command == "status" then
        print(PREFIX .. ns.StatusText())
    elseif command == "unlock" then

        if not ns.Active() then self:SetGCDWatch(true) end
        ns.Set("bar", true)
        ns.Set("barLocked", false)
        print(PREFIX .. "target bar unlocked. Drag it to move it, drag its corner to resize, right-click it to lock.")
    elseif command == "lock" then
        ns.Set("barLocked", true)
        print(PREFIX .. "target bar locked.")
    elseif command == "preview" then
        print(PREFIX .. ns.PlaySamples(20))
    else
        PrintHelp()
    end
end
