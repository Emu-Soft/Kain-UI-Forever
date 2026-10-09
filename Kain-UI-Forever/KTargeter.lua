local ADDON_NAME = ...

local PREFIX = "|cff33ff99K-Targeter:|r "

local function IsSecretAny(v)
    if issecretvalue and issecretvalue(v) then return true end
    if type(v) == "table" and issecrettable and issecrettable(v) then return true end
    return false
end

local function Plain(v)
    if IsSecretAny(v) then return nil end
    return v
end

local function SafeUnitName(unit)
    local ok, name = pcall(UnitName, unit)
    if not ok then return nil end
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

local errorCounts = {}
local function Guarded(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local n = (errorCounts[label] or 0) + 1
            errorCounts[label] = n
            if n == 1 then
                print(PREFIX .. "'" .. label .. "' hit an error (further ones are counted, not printed): " .. tostring(err))
            end
        end
    end
end

local IDLE_BODY = "/stopmacro"

local MACRO_NAME = "K-Targeter"

local MACRO_ICON = 1380366

local MACRO_MAX_CHARS = 255

local dbAtLoad = type(KTargeterDB) == "table" and next(KTargeterDB) ~= nil
KTargeterDB = KTargeterDB or {}

local function DB_Init()
    KTargeterDB.turnins = KTargeterDB.turnins or {}
    KTargeterDB.objectiveMobs = KTargeterDB.objectiveMobs or {}
    KTargeterDB.worldObjects = KTargeterDB.worldObjects or {}
end

local function DB_ReportLoadState()
end

local function DB_GetTurnin(questTitle)
    return KTargeterDB.turnins and KTargeterDB.turnins[questTitle]
end
local function DB_SetTurnin(questTitle, npcName, confirmed)
    KTargeterDB.turnins = KTargeterDB.turnins or {}
    KTargeterDB.turnins[questTitle] = { name = npcName, confirmed = confirmed }
end
local function DB_EachTurnin()
    return pairs(KTargeterDB.turnins or {})
end

local function DB_GetObjectiveMobs(objName)
    return KTargeterDB.objectiveMobs and KTargeterDB.objectiveMobs[objName]
end

local function DB_AddObjectiveMob(objName, mobName)
    KTargeterDB.objectiveMobs = KTargeterDB.objectiveMobs or {}
    KTargeterDB.objectiveMobs[objName] = KTargeterDB.objectiveMobs[objName] or {}
    if KTargeterDB.objectiveMobs[objName][mobName] then
        return false
    end
    KTargeterDB.objectiveMobs[objName][mobName] = true
    return true
end
local function DB_EachObjectiveMobs()
    return pairs(KTargeterDB.objectiveMobs or {})
end

local function DB_IsWorldObject(objName)
    return KTargeterDB.worldObjects and KTargeterDB.worldObjects[objName]
end
local function DB_SetWorldObject(objName, value)
    KTargeterDB.worldObjects = KTargeterDB.worldObjects or {}
    KTargeterDB.worldObjects[objName] = value
end

local function DB_IsSharingEnabled()
    return KTargeterDB.shareData ~= false
end
local function DB_SetSharing(enabled)
    KTargeterDB.shareData = enabled
end

local macrosSeen, macrosTimedOut = false, false

local function MacrosReady()
    if macrosSeen or macrosTimedOut then return true end
    local numAccount, numChar = GetNumMacros()
    if (numAccount or 0) + (numChar or 0) > 0 then
        macrosSeen = true
        return true
    end
    return false
end

local function GetOurMacroIndex()
    local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
    if ok and index and index > 0 then
        return index
    end
    return nil
end

local function CanCreateMacro()

    local numAccount = GetNumMacros()
    return (numAccount or 0) < 119
end

local createFailureShown = false
local function EnsureMacroExists()
    if not MacrosReady() then return end
    if GetOurMacroIndex() then return end
    if InCombatLockdown() then return end
    if not CanCreateMacro() then
        if not createFailureShown then
            createFailureShown = true
            print(PREFIX .. "couldn't create the macro -- your macro book is full. Delete a macro you don't need and reload.")
        end
        return
    end

    local ok, made = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, IDLE_BODY)
    if (not ok or not made) and not createFailureShown then
        createFailureShown = true
        print(PREFIX .. "couldn't create the macro: " .. tostring(ok and "the client refused" or made))
    end
end

local lastBody = nil
local writeFailureShown = false

local function WriteMacroBody(body)
    if #body > MACRO_MAX_CHARS then body = body:sub(1, MACRO_MAX_CHARS) end
    if body == lastBody then return end
    if InCombatLockdown() then return end
    if not MacrosReady() then return end
    EnsureMacroExists()
    local index = GetOurMacroIndex()
    if not index then return end

    local ok, err = pcall(EditMacro, index, nil, nil, body)
    if ok then
        lastBody = body
    elseif not writeFailureShown then
        writeFailureShown = true
        print(PREFIX .. "couldn't update the macro: " .. tostring(err))
    end
end

local QL = C_QuestLog

local function GetLogQuests()
    local list = {}
    local numEntries = QL.GetNumQuestLogEntries() or 0
    local header = nil
    for i = 1, numEntries do
        local info = QL.GetInfo(i)
        if type(info) == "table" then
            if info.isHeader then
                header = info.title
            elseif info.questID and not info.isHidden then
                list[#list + 1] = { questID = info.questID, title = info.title, header = header, onMap = info.isOnMap }
            end
        end
    end
    return list
end

local function GetAllQuestIDs()
    local ids = {}
    for _, q in ipairs(GetLogQuests()) do ids[#ids + 1] = q.questID end
    return ids
end

local function GetObjectivesFor(questID)
    local objs = QL.GetQuestObjectives(questID)
    if type(objs) ~= "table" then return {} end
    return objs
end

local function GetTurninTexts(questID)
    local texts = {}
    for _, obj in ipairs(GetObjectivesFor(questID)) do
        if type(obj.text) == "string" and obj.text ~= "" then texts[#texts + 1] = obj.text end
    end
    if GetQuestLogCompletionText and QL.GetLogIndexForQuestID then
        local okI, index = pcall(QL.GetLogIndexForQuestID, questID)
        if okI and type(index) == "number" and index > 0 then
            local okT, text = pcall(GetQuestLogCompletionText, index)
            text = okT and Plain(text) or nil
            if type(text) == "string" and text ~= "" then texts[#texts + 1] = text end
        end
    end
    return texts
end

local function QuestIsComplete(questID)
    local fn = QL.IsComplete or QL.ReadyForTurnIn
    return fn and fn(questID) and true or false
end

local function QuestTitleFor(questID)
    local title = QL.GetTitleForQuestID(questID)
    if type(title) == "string" and title ~= "" then return title end
    return nil
end

local KILL_SUFFIXES  = { "slain", "killed", "defeated" }
local OTHER_SUFFIXES = { "looted", "collected", "activated", "used", "returned", "shown", "captured", "destroyed",
                        "rescued", "freed", "found", "discovered", "delivered", "escorted", "gathered", "burned" }

local function ExtractObjectiveName(desc)
    if type(desc) ~= "string" then return nil end

    desc = desc:gsub("%s*%(Optional%)%s*$", "")
    for _, suf in ipairs(KILL_SUFFIXES) do
        local name = desc:match("^(.-)%s+" .. suf .. ":%s*%d+%s*/%s*%d+%s*$")
        if name then return name, true end
    end
    for _, suf in ipairs(OTHER_SUFFIXES) do
        local name = desc:match("^(.-)%s+" .. suf .. ":%s*%d+%s*/%s*%d+%s*$")
        if name then return name, false end
    end

    local name = desc:match("^(.-):%s*%d+%s*/%s*%d+%s*$")
    if name then return name, false end

    local name2 = desc:match("^%d+%s*/%s*%d+%s+(.+)$")
    if name2 then
        for _, suf in ipairs(KILL_SUFFIXES) do
            local bare = name2:match("^(.-)%s+" .. suf .. "$")
            if bare and bare ~= "" then return bare, true end
        end
        for _, suf in ipairs(OTHER_SUFFIXES) do
            local bare = name2:match("^(.-)%s+" .. suf .. "$")
            if bare and bare ~= "" then return bare, false end
        end
        return name2, false
    end
    return nil
end

local TURNIN_VERBS = { "report back to ", "report to ", "return to ", "go back to ", "speak with ", "speak to ",
                       "talk with ", "talk to ", "meet with ", "seek out ", "visit " }

local NAME_STOPS = { " in ", " near ", " at ", " inside ", " outside ", " within ", " on ", " by ", " beside ",
                     " behind ", " to ", " who ", " and " }

local function ExtractTurninNPC(text)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("^%s*%-%s*", "")
    s = s:gsub("^%s+", "")
    local lower = s:lower()
    for _, verb in ipairs(TURNIN_VERBS) do
        if lower:sub(1, #verb) == verb then
            local rest, restLower = s:sub(#verb + 1), lower:sub(#verb + 1)
            local cut = #rest + 1
            for _, stop in ipairs(NAME_STOPS) do
                local at = restLower:find(stop, 1, true)
                if at and at < cut then cut = at end
            end
            local punct = rest:find("[,;:%(]")
            if punct and punct < cut then cut = punct end
            local name = rest:sub(1, cut - 1):gsub("%s+$", "")
            name = name:gsub("%.$", "")
            if name ~= "" and not name:sub(1, 1):match("%l") then return name end
            return nil
        end
    end
    return nil
end

local function FindTurninNPCFromText(questID)
    for _, text in ipairs(GetTurninTexts(questID)) do
        local name = ExtractTurninNPC(text)
        if name then return name end
    end
    return nil
end

local function GetCurrentZoneName()
    local zone = GetZoneText()

    if issecretvalue and issecretvalue(zone) then return nil end
    if type(zone) == "string" and zone ~= "" then return zone end
    local real = GetRealZoneText()
    if issecretvalue and issecretvalue(real) then return nil end
    return real
end

local lastFallbackTime = -math.huge
local function FindAndTrackFallbackQuest()

    if (GetTime() - lastFallbackTime) < 2 then return nil end
    lastFallbackTime = GetTime()

    if _G.KGuide and _G.KGuide.IsGuiding and _G.KGuide.IsGuiding() then
        return nil
    end

    local quests = GetLogQuests()
    if #quests == 0 then return nil end

    local function tryTrack(matches)
        for _, q in ipairs(quests) do
            if matches(q) and QL.AddQuestWatch(q.questID) ~= false then
                return q
            end
        end
        return nil
    end

    local currentZone = GetCurrentZoneName()
    local picked = nil
    if currentZone and currentZone ~= "" then
        picked = tryTrack(function(q) return q.header == currentZone end)
    end
    if not picked then
        picked = tryTrack(function(q) return q.onMap end)
    end
    if not picked then
        picked = tryTrack(function() return true end)

    end
    return picked and picked.questID or nil
end

local function GetTrackedQuestIDs()
    local list = {}
    local numWatches = QL.GetNumQuestWatches() or 0
    for i = 1, numWatches do
        local questID = QL.GetQuestIDForQuestWatchIndex(i)
        if questID then table.insert(list, questID) end
    end
    if #list == 0 then
        local fallback = FindAndTrackFallbackQuest()
        if fallback then table.insert(list, fallback) end
    end
    return list
end

local function GetUnfinishedObjectiveNames(questID)
    local names = {}
    local seen = {}
    for _, obj in ipairs(GetObjectivesFor(questID)) do
        if obj.text and not obj.finished then
            local name = ExtractObjectiveName(obj.text)
            if name and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    return names
end

local function BuildTargetCandidates(objectiveNames)
    local candidates = {}
    local seen = {}
    for _, objName in ipairs(objectiveNames) do

        if not DB_IsWorldObject(objName) then
            local sources = DB_GetObjectiveMobs(objName)
            local foundSource = false
            if sources then
                for mobName in pairs(sources) do
                    foundSource = true
                    if not seen[mobName] then
                        seen[mobName] = true
                        table.insert(candidates, mobName)
                    end
                end
            end

            if not foundSource and not seen[objName] then
                seen[objName] = true
                table.insert(candidates, objName)
            end
        end
    end
    return candidates
end

local function GetMarkedWorldObjectNames(objectiveNames)
    local marked = {}
    for _, objName in ipairs(objectiveNames) do
        if DB_IsWorldObject(objName) then
            table.insert(marked, objName)
        end
    end
    return marked
end

local SAFETY_LINE = "/targetlasttarget [dead]"

local MACRO_CHAR_BUDGET = MACRO_MAX_CHARS - 1 - #SAFETY_LINE
local function ComposeTargetLines(names)
    local body = ""
    for _, name in ipairs(names) do
        local line = "/targetexact " .. name
        local candidate = (body == "") and line or (body .. "\n" .. line)
        if #candidate > MACRO_CHAR_BUDGET then break end
        body = candidate
    end
    if body ~= "" then
        body = body .. "\n" .. SAFETY_LINE
    end
    return body
end

local function ComputeMacroBody()
    local questIDs = GetTrackedQuestIDs()

    local candidates, seenCandidate = {}, {}
    local reminders, seenReminder = {}, {}

    local function addCandidate(name)
        if not seenCandidate[name] then
            seenCandidate[name] = true
            table.insert(candidates, name)
        end
    end
    local function addReminder(text)
        if not seenReminder[text] then
            seenReminder[text] = true
            table.insert(reminders, text)
        end
    end

    local guideTarget = nil
    local guideDriving = _G.KGuide and _G.KGuide.IsGuiding and _G.KGuide.IsGuiding()
    if _G.KGuide and _G.KGuide.GetCurrentStepTarget then
        guideTarget = _G.KGuide.GetCurrentStepTarget()
        if guideTarget then
            addCandidate(guideTarget)
        end
    end

    if #questIDs == 0 and #candidates == 0 then
        return IDLE_BODY, "idle", {}, {}
    end

    for _, questID in ipairs(questIDs) do
        local title = QuestTitleFor(questID)
        if title then
            if QuestIsComplete(questID) then

                if not (guideDriving and guideTarget) then

                    local entry = DB_GetTurnin(title)
                    local npc
                    if entry and entry.confirmed then
                        npc = entry.name
                    else
                        npc = FindTurninNPCFromText(questID) or (entry and entry.name)
                    end
                    if npc then
                        addCandidate(npc)
                    else
                        addReminder("turn in \"" .. title .. "\" (unknown NPC)")
                    end
                end
            else
                local names = GetUnfinishedObjectiveNames(questID)
                if #names > 0 then
                    for _, c in ipairs(BuildTargetCandidates(names)) do
                        addCandidate(c)
                    end
                    for _, marked in ipairs(GetMarkedWorldObjectNames(names)) do
                        addReminder(marked)
                    end
                end
            end
        end
    end

    local body = ComposeTargetLines(candidates)

    if body == "" then
        return IDLE_BODY, "idle", {}, reminders
    end

    return body, "objectives", candidates, reminders
end

local RefreshMacro = Guarded("macro-refresh", function()
    local body = ComputeMacroBody()
    WriteMacroBody(body)
end)

local _refreshQueued = false
local function RefreshMacroSoon()
    if not (C_Timer and C_Timer.After) then
        RefreshMacro()
        return
    end
    if _refreshQueued then return end
    _refreshQueued = true
    C_Timer.After(0, function()
        _refreshQueued = false
        RefreshMacro()
    end)
end

local macroTimeoutScheduled = false
local function ScheduleMacroTimeout()
    if macroTimeoutScheduled or macrosSeen then return end
    macroTimeoutScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(15, function()
            macrosTimedOut = true
            RefreshMacroSoon()
        end)
    end
end

local COMM_PREFIX = "KTargeter1"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX)
end

local SEND_INTERVAL = 0.25
local SEND_QUEUE_MAX = 1000
local sendQueue, sendTicker = {}, nil

local function CommRestricted()
    local ci = C_ChatInfo
    if not ci then return true end
    for _, name in ipairs({ "InChatMessagingLockdown", "AreOutgoingAddonChatMessagesRestricted" }) do
        if ci[name] then
            local ok, restricted = pcall(ci[name])
            if ok and Plain(restricted) == true then return true end
        end
    end
    return false
end

local function CommChannels()
    local list = {}
    local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
    if instanceCategory and IsInGroup(instanceCategory) then
        list[#list + 1] = "INSTANCE_CHAT"
    elseif IsInRaid() then
        list[#list + 1] = "RAID"
    elseif IsInGroup() then
        list[#list + 1] = "PARTY"
    end
    if IsInGuild() then
        list[#list + 1] = "GUILD"
    end
    return list
end

local function PumpSendQueue()
    if #sendQueue == 0 then
        if sendTicker then sendTicker:Cancel() sendTicker = nil end
        return
    end
    if CommRestricted() then return end
    local item = sendQueue[1]
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, item.text, item.channel)
    local results = Enum and Enum.SendAddonMessageResult
    if ok and results and result ~= nil
        and (result == results.AddonMessageThrottle or result == results.ChannelThrottle) then
        return
    end
    table.remove(sendQueue, 1)
end

local function SendKTMessage(text)
    if not DB_IsSharingEnabled() then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage and C_Timer and C_Timer.NewTicker) then return end
    for _, channel in ipairs(CommChannels()) do
        if #sendQueue < SEND_QUEUE_MAX then
            sendQueue[#sendQueue + 1] = { channel = channel, text = text }
        end
    end
    if #sendQueue > 0 and not sendTicker then
        sendTicker = C_Timer.NewTicker(SEND_INTERVAL, PumpSendQueue)
    end
end

local function BroadcastFullDatabase()
    local count = 0
    for objName, sources in DB_EachObjectiveMobs() do
        for mobName in pairs(sources) do
            SendKTMessage("KTM::" .. objName .. "::" .. mobName)
            count = count + 1
        end
    end
    for questTitle, entry in DB_EachTurnin() do
        if entry.confirmed then
            SendKTMessage("KTT::" .. questTitle .. "::" .. entry.name)
            count = count + 1
        end
    end
    return count
end

local function GuessTurninFromQuestGiver()
    local title = GetTitleText()
    local npcName = SafeUnitName("npc")
    if not title or title == "" or not npcName then return end

    local existing = DB_GetTurnin(title)
    if not existing then
        DB_SetTurnin(title, npcName, false)

    end
end

local function RememberTurnin(fromNetwork)
    local title = GetTitleText()
    local npc = SafeUnitName("npc")
    if not title or title == "" or not npc then return end

    local existing = DB_GetTurnin(title)
    if not existing or not existing.confirmed or existing.name ~= npc then
        DB_SetTurnin(title, npc, true)

        if not fromNetwork then
            SendKTMessage("KTT::" .. title .. "::" .. npc)
        end
    end
end

local pendingSyncCount = 0
local syncSummaryPending = false

local function FlushSyncSummary()
    syncSummaryPending = false

    pendingSyncCount = 0
end

local function QueueSyncSummary(sender)
    pendingSyncCount = pendingSyncCount + 1
    if not syncSummaryPending then
        syncSummaryPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, FlushSyncSummary)
        else
            FlushSyncSummary()
        end
    end
end

local function RecordObjectiveSource(objName, mobName, fromNetwork)

    if mobName == SafeUnitName("player") then return false end

    if DB_AddObjectiveMob(objName, mobName) then
        if not fromNetwork then

            SendKTMessage("KTM::" .. objName .. "::" .. mobName)
        end

        RefreshMacroSoon()
        return true
    end
    return false
end

local lastPartyKillName, lastPartyKillTime = nil, 0

local OnCombatLogEvent = Guarded("combat-log", function()
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    subevent, destGUID, destName = Plain(subevent), Plain(destGUID), Plain(destName)

    if subevent == "PARTY_KILL" and type(destName) == "string" and type(destGUID) == "string"
        and not destGUID:match("^Player%-") then
        lastPartyKillName = destName
        lastPartyKillTime = GetTime()
    end
end)

local OnChatMsgLoot = Guarded("loot-message", function(msg)
    msg = Plain(msg)
    if type(msg) ~= "string" then return end
    if not lastPartyKillName then return end
    if (GetTime() - lastPartyKillTime) > 10 then return end
    local itemName = msg:match("%[(.-)%]")
    if not itemName then return end

    for _, questID in ipairs(GetAllQuestIDs()) do
        for _, obj in ipairs(GetObjectivesFor(questID)) do
            if obj.text and not obj.finished then
                local objName = ExtractObjectiveName(obj.text)
                if objName == itemName then
                    RecordObjectiveSource(objName, lastPartyKillName)
                end
            end
        end
    end
end)

local scanTip
local function GetScanTip()
    if scanTip == nil then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "KTargeterScanTooltip", nil, "GameTooltipTemplate")
        if ok and tip then
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            scanTip = tip
        else
            scanTip = false
        end
    end
    return scanTip or nil
end

local function AddTipLine(tipLines, tipNames, text)
    text = Plain(text)
    if type(text) ~= "string" or text == "" then return end
    tipLines[text] = true
    local stripped = text:match("^%-%s*(.+)$")
    if stripped then tipLines[stripped] = true end
    local name = ExtractObjectiveName(stripped or text)
    if name then tipNames[name] = true end
end

local function GetUnitTooltipLines(unit)
    local tipLines, tipNames = {}, {}
    local got = false

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        data = ok and Plain(data) or nil
        local lines = type(data) == "table" and Plain(data.lines) or nil
        if type(lines) == "table" then
            got = true
            for _, line in ipairs(lines) do
                if type(line) == "table" and not IsSecretAny(line) then
                    local text = line.leftText
                    if text == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
                        pcall(TooltipUtil.SurfaceArgs, line)
                        text = line.leftText
                    end
                    AddTipLine(tipLines, tipNames, text)
                end
            end
        end
    end

    if not got then
        local tip = GetScanTip()
        if tip then
            tip:ClearLines()
            tip:SetUnit(unit)
            for i = 1, tip:NumLines() do
                local fontString = _G["KTargeterScanTooltipTextLeft" .. i]
                AddTipLine(tipLines, tipNames, fontString and fontString:GetText())
            end

            tip:Hide()
        end
    end
    return tipLines, tipNames
end

local LearnObjectiveSources = Guarded("hover-learn", function()
    if not Plain(UnitExists("mouseover")) then return end

    if Plain(UnitIsUnit("mouseover", "player")) ~= false then return end

    local questIDs = GetAllQuestIDs()
    if #questIDs == 0 then return end

    local mobName = SafeUnitName("mouseover")
    if not mobName then return end

    local tipLines, tipNames = GetUnitTooltipLines("mouseover")

    for _, questID in ipairs(questIDs) do
        for _, obj in ipairs(GetObjectivesFor(questID)) do
            local desc = obj.text
            if desc and not obj.finished then
                local objName = ExtractObjectiveName(desc)
                if objName and (tipLines[desc] or tipNames[objName]) then
                    RecordObjectiveSource(objName, mobName)
                end
            end
        end
    end
end)

local function ClassifyLootSource(slot)
    if not GetLootSourceInfo then return nil end
    local ok, guid = pcall(GetLootSourceInfo, slot)
    guid = ok and Plain(guid) or nil
    if type(guid) ~= "string" then return nil end

    local kind = guid:match("^(%a+)%-")
    if kind == "GameObject" then
        return "object"
    elseif kind == "Creature" or kind == "Vehicle" then
        local name
        local okT, targetGUID = pcall(UnitGUID, "target")
        if okT and Plain(targetGUID) == guid then name = SafeUnitName("target") end
        if not name and UnitNameFromGUID then
            local okN, n = pcall(UnitNameFromGUID, guid)
            n = okN and Plain(n) or nil
            if type(n) == "string" and n ~= "" and n ~= UNKNOWNOBJECT then name = n end
        end
        return "creature", name
    end
    return nil
end

local LearnFromLootWindow = Guarded("loot-learn", function()
    local questIDs = GetAllQuestIDs()
    if #questIDs == 0 then return end

    local numLoot = GetNumLootItems() or 0
    if numLoot == 0 then return end

    local lootSlots = {}
    for slot = 1, numLoot do
        local _, itemName = GetLootSlotInfo(slot)
        itemName = Plain(itemName)
        if type(itemName) == "string" and not lootSlots[itemName] then lootSlots[itemName] = slot end
    end

    local targetCorpseName = nil
    if Plain(UnitExists("target")) and Plain(UnitIsDead("target"))
        and Plain(UnitIsUnit("target", "player")) == false then
        targetCorpseName = SafeUnitName("target")
    end

    for _, questID in ipairs(questIDs) do
        for _, obj in ipairs(GetObjectivesFor(questID)) do
            if obj.text and not obj.finished then
                local objName = ExtractObjectiveName(obj.text)
                local slot = objName and lootSlots[objName]
                if slot then
                    local kind, sourceName = ClassifyLootSource(slot)
                    if kind == "object" then
                        if not DB_IsWorldObject(objName) then
                            DB_SetWorldObject(objName, true)

                        end
                    else
                        sourceName = sourceName or targetCorpseName
                        if sourceName then
                            RecordObjectiveSource(objName, sourceName)
                        end
                    end
                end
            end
        end
    end
end)

local frame = CreateFrame("Frame")
local hasAnnouncedFusion = false

local function SafeRegister(f, event)
    return pcall(f.RegisterEvent, f, event)
end

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_MACROS",
    "PLAYER_REGEN_ENABLED",
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "QUEST_WATCH_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_DETAIL",
    "QUEST_COMPLETE",
    "QUEST_PROGRESS",
    "UPDATE_MOUSEOVER_UNIT",
    "LOOT_OPENED",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_ADDON",
}
for _, e in ipairs(EVENTS) do SafeRegister(frame, e) end

local combatLogAvailable = CombatLogGetCurrentEventInfo ~= nil and SafeRegister(frame, "COMBAT_LOG_EVENT_UNFILTERED") or false

local lastFullBroadcast = -math.huge
local OnAddonMessage = Guarded("comm-receive", function(prefix, text, sender)
    prefix, text, sender = Plain(prefix), Plain(text), Plain(sender)
    if prefix ~= COMM_PREFIX or type(text) ~= "string" then return end
    if text == "KTREQ" then
        local me = SafeUnitName("player")
        local isSelf = type(sender) == "string" and me ~= nil and Ambiguate(sender, "short") == me
        if not isSelf and (GetTime() - lastFullBroadcast) > 60 then
            lastFullBroadcast = GetTime()
            BroadcastFullDatabase()
        end
        return
    end
    local msgType, a, b = text:match("^(%a+)::(.-)::(.-)$")
    if msgType == "KTM" and a ~= "" and b ~= "" then
        if RecordObjectiveSource(a, b, true) then
            QueueSyncSummary(sender)

        end
    elseif msgType == "KTT" and a ~= "" and b ~= "" then
        local existing = DB_GetTurnin(a)
        if not existing or existing.name ~= b then
            DB_SetTurnin(a, b, true)
            QueueSyncSummary(sender)
            RefreshMacroSoon()
        end
    end
end)

frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)

    if event == "UPDATE_MACROS" then
        macrosSeen = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScheduleMacroTimeout()
    end

    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        DB_Init()
        DB_ReportLoadState()
        EnsureMacroExists()
        RefreshMacro()
    elseif event == "PLAYER_ENTERING_WORLD" then

        if not hasAnnouncedFusion and _G.KGuide and _G.KGuide.GetCurrentStepTarget then
            hasAnnouncedFusion = true
            print("|cffFFD700[K-Targeter]|r K-Guide Detected - Performing Fusion Dance.")
        end

        RefreshMacroSoon()
    elseif event == "UPDATE_MACROS" then

        RefreshMacroSoon()
    elseif event == "QUEST_DETAIL" then
        GuessTurninFromQuestGiver()
        RefreshMacroSoon()
    elseif event == "QUEST_COMPLETE" or event == "QUEST_PROGRESS" then
        RememberTurnin()
        RefreshMacroSoon()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        LearnObjectiveSources()
        RefreshMacroSoon()
    elseif event == "LOOT_OPENED" then
        LearnFromLootWindow()
        RefreshMacroSoon()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "CHAT_MSG_LOOT" then
        OnChatMsgLoot(arg1)
        RefreshMacroSoon()
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(arg1, arg2, arg4)
    else
        RefreshMacroSoon()
    end
end)

local mouseoverPollElapsed = 0
local MOUSEOVER_POLL_INTERVAL = 1.0
frame:SetScript("OnUpdate", function(self, elapsed)
    mouseoverPollElapsed = mouseoverPollElapsed + elapsed
    if mouseoverPollElapsed < MOUSEOVER_POLL_INTERVAL then return end
    mouseoverPollElapsed = 0
    if Plain(UnitExists("mouseover")) then
        LearnObjectiveSources()
        RefreshMacroSoon()
    end
end)

local guiFrame
local objField, mobField, suggestButtons, suggestionBG
local MAX_SUGGESTIONS = 6

local BACKDROP_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

local function GetAllTeachableObjectiveNames()
    local names, seen = {}, {}
    for _, questID in ipairs(GetAllQuestIDs()) do
        for _, obj in ipairs(GetObjectivesFor(questID)) do
            local name = obj.text and ExtractObjectiveName(obj.text)
            if name and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    return names
end

local function GetPlausibleTargetSourceName()
    if not Plain(UnitExists("target")) then return nil end
    if Plain(UnitIsPlayer("target")) ~= false then return nil end
    local name = SafeUnitName("target")
    if not name or name == UNKNOWNOBJECT then return nil end
    return name
end

local function HideSuggestions()
    if not suggestButtons then return end
    for _, btn in ipairs(suggestButtons) do
        btn:Hide()
    end
    if suggestionBG then suggestionBG:Hide() end
end

local function RefreshSuggestions()
    if not suggestButtons then return end
    local typed = objField:GetText() or ""
    HideSuggestions()
    if typed == "" then return end
    local typedLower = typed:lower()
    local shown = 0
    for _, name in ipairs(GetAllTeachableObjectiveNames()) do
        if shown >= MAX_SUGGESTIONS then break end
        if name:lower():find(typedLower, 1, true) then
            shown = shown + 1
            local btn = suggestButtons[shown]
            btn:SetText(name)
            btn:Show()
        end
    end
    if shown > 0 and suggestionBG then
        suggestionBG:SetHeight(shown * 14 + 8)
        suggestionBG:Show()
    end
end

local function BuildGUI()
    local f = CreateFrame("Frame", "KTargeterGUIFrame", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(320, 310)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    else

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
    end
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText("K-Targeter")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local regenBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    regenBtn:SetSize(150, 22)
    regenBtn:SetPoint("TOP", 0, -40)
    regenBtn:SetText("Regenerate Macro")
    regenBtn:SetScript("OnClick", function()
        lastBody = nil
        RefreshMacro()
        print(PREFIX .. "macro regenerated.")
    end)

    suggestionBG = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    suggestionBG:SetPoint("TOPLEFT", 20, -106)
    suggestionBG:SetSize(268, 14)
    if suggestionBG.SetBackdrop then
        suggestionBG:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        suggestionBG:SetBackdropColor(0, 0, 0, 0.9)
    else
        local bg = suggestionBG:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    suggestionBG:Hide()

    suggestButtons = {}
    for i = 1, MAX_SUGGESTIONS do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(260, 14)
        btn:SetPoint("TOPLEFT", 24, -110 - (i - 1) * 14)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("LEFT")
        btn.text = fs
        function btn:SetText(t) self.text:SetText(t) end
        btn:SetScript("OnClick", function(self)
            objField:SetText(self.text:GetText() or "")
            HideSuggestions()
            objField:ClearFocus()
        end)
        btn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 0) end)
        btn:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1) end)
        btn:Hide()
        suggestButtons[i] = btn
    end

    local objLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    objLabel:SetPoint("TOPLEFT", 20, -74)
    objLabel:SetText("Item / objective name:")

    objField = CreateFrame("EditBox", "KTargeterGUIObjField", f, "InputBoxTemplate")
    objField:SetSize(260, 20)
    objField:SetPoint("TOPLEFT", 24, -90)
    objField:SetAutoFocus(false)
    objField:SetScript("OnTextChanged", RefreshSuggestions)
    objField:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    objField:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local mobLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mobLabel:SetPoint("TOPLEFT", 20, -206)
    mobLabel:SetText("Source creature:")

    local mobHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mobHint:SetPoint("TOPLEFT", 20, -220)
    mobHint:SetTextColor(0.6, 0.6, 0.6)
    mobHint:SetText("Hint: Target an NPC to auto-fill this field")

    mobField = CreateFrame("EditBox", "KTargeterGUIMobField", f, "InputBoxTemplate")
    mobField:SetSize(260, 20)
    mobField:SetPoint("TOPLEFT", 24, -236)
    mobField:SetAutoFocus(false)
    mobField:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mobField:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    mobField.userEdited = false
    mobField:SetScript("OnTextChanged", function(self, isUserInput)
        if isUserInput then
            self.userEdited = (self:GetText() ~= "")
        end
    end)

    local learnBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    learnBtn:SetSize(150, 22)
    learnBtn:SetPoint("TOP", 0, -276)
    learnBtn:SetText("Learn Source")
    learnBtn:SetScript("OnClick", function()
        local objName = (objField:GetText() or ""):match("^%s*(.-)%s*$")
        local mobName = (mobField:GetText() or ""):match("^%s*(.-)%s*$")
        if objName == "" or mobName == "" then
            print(PREFIX .. "fill in both fields first.")
            return
        end
        RecordObjectiveSource(objName, mobName)
        lastBody = nil
        RefreshMacro()
        HideSuggestions()
        mobField.userEdited = false
    end)

    SafeRegister(f, "PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_TARGET_CHANGED" and self:IsShown() and not mobField.userEdited then
            local name = GetPlausibleTargetSourceName()
            if name then mobField:SetText(name) end
        end
    end)
    f:SetScript("OnShow", function(self)
        RefreshSuggestions()
        if not mobField.userEdited then
            local name = GetPlausibleTargetSourceName()
            if name then mobField:SetText(name) end
        end
    end)
    f:SetScript("OnHide", function() HideSuggestions() end)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "KTargeterGUIFrame")
    end

    return f
end

local function ToggleGUI()
    if not guiFrame then
        guiFrame = BuildGUI()
    end
    if guiFrame:IsShown() then
        guiFrame:Hide()
    else
        guiFrame:Show()
    end
end

local RunProbe = Guarded("probe", function()
    local function say(fmt, ...) print(PREFIX .. string.format(fmt, ...)) end
    local function has(v) return v ~= nil and "yes" or "NO" end

    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
    local _, build, _, toc = GetBuildInfo()
    say("probe: addon %s | client build %s | interface %s", tostring(version), tostring(build), tostring(toc))

    say("quest log: GetInfo=%s GetQuestObjectives=%s AddQuestWatch=%s GetQuestIDForQuestWatchIndex=%s IsComplete=%s",
        has(QL and QL.GetInfo), has(QL and QL.GetQuestObjectives), has(QL and QL.AddQuestWatch),
        has(QL and QL.GetQuestIDForQuestWatchIndex), has(QL and QL.IsComplete))

    local okQ, logQuests = pcall(function() return #GetLogQuests() end)
    local okW, watched = pcall(function() return QL.GetNumQuestWatches() or 0 end)
    say("  quests visible in log: %s | tracked: %s (quests under a collapsed header are not listed)",
        okQ and tostring(logQuests) or ("ERROR " .. tostring(logQuests)),
        okW and tostring(watched) or ("ERROR " .. tostring(watched)))

    say("learning: C_TooltipInfo.GetUnit=%s GetLootSourceInfo=%s UnitNameFromGUID=%s",
        has(C_TooltipInfo and C_TooltipInfo.GetUnit), has(GetLootSourceInfo), has(UnitNameFromGUID))
    say("  combat log kill attribution: %s (expected: off on Forever)", combatLogAvailable and "ON" or "off")

    local numAccount, numChar = GetNumMacros()
    local index = GetOurMacroIndex()
    local bodyLen = "n/a"
    if index and GetMacroBody then
        local okB, body = pcall(GetMacroBody, index)
        if okB and type(body) == "string" then bodyLen = tostring(#body) end
    end
    say("macros: ready=%s (UPDATE_MACROS seen=%s, timed out=%s) | general=%s character=%s",
        tostring(MacrosReady()), tostring(macrosSeen), tostring(macrosTimedOut), tostring(numAccount), tostring(numChar))
    say("  K-Targeter macro: %s | body length %s of %d allowed", index and ("index " .. index) or "not found", bodyLen, MACRO_MAX_CHARS)

    local nT, nM, nW = 0, 0, 0
    for _ in pairs(KTargeterDB.turnins or {}) do nT = nT + 1 end
    for _ in pairs(KTargeterDB.objectiveMobs or {}) do nM = nM + 1 end
    for _ in pairs(KTargeterDB.worldObjects or {}) do nW = nW + 1 end
    say("data: %d turn-ins, %d objectives with sources, %d world objects | saved data present at load: %s",
        nT, nM, nW, dbAtLoad and "yes" or "NO (beta SavedVariables bug, or first run)")

    local commState = "ok"
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then commState = "no SendAddonMessage"
    elseif CommRestricted() then commState = "RESTRICTED right now" end
    say("sharing: %s | comms %s | %d message(s) queued", DB_IsSharingEnabled() and "on" or "off", commState, #sendQueue)

    local anyErr = false
    for label, n in pairs(errorCounts) do
        anyErr = true
        say("  caught errors in '%s': %d", label, n)
    end
    if not anyErr then say("no errors caught so far.") end
end)

SLASH_KTARGETER1 = "/kt"
SLASH_KTARGETER2 = "/ktargeter"
SlashCmdList["KTARGETER"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")

    if msg == "" or msg:lower() == "gui" then
        ToggleGUI()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower()

    if cmd == "regen" then
        lastBody = nil
        RefreshMacro()
        local _, status, extra, reminders = ComputeMacroBody()
        if status == "objectives" and #extra > 0 then
            print(PREFIX .. "targeting -> " .. table.concat(extra, ", "))
        else
            print(PREFIX .. "nothing to target right now.")
        end
        if reminders and #reminders > 0 then
            print(PREFIX .. "also need (not targetable): " .. table.concat(reminders, "; "))
        end
        return
    elseif cmd == "probe" then
        RunProbe()
        return
    elseif cmd == "object" and rest ~= "" then
        DB_SetWorldObject(rest, true)
        print(PREFIX .. "marked \"" .. rest .. "\" as a world object -- will no longer try to target it, just remind you.")
        lastBody = nil
        RefreshMacro()
        return
    elseif cmd == "unobject" and rest ~= "" then
        DB_SetWorldObject(rest, nil)
        print(PREFIX .. "unmarked \"" .. rest .. "\".")
        lastBody = nil
        RefreshMacro()
        return
    elseif cmd == "source" and rest:find("%->") then
        local objName, mobName = rest:match("^(.-)%s*%->%s*(.-)$")
        if objName and mobName and objName ~= "" and mobName ~= "" then
            RecordObjectiveSource(objName, mobName)
            lastBody = nil
            RefreshMacro()
        else
            print(PREFIX .. "usage: /kt source <objective name> -> <creature name>")
        end
        return
    elseif cmd == "turnin" and rest:find("%->") then
        local questTitle, npcName = rest:match("^(.-)%s*%->%s*(.-)$")
        if questTitle and npcName and questTitle ~= "" and npcName ~= "" then
            DB_SetTurnin(questTitle, npcName, true)
            print(PREFIX .. "set turn-in for \"" .. questTitle .. "\" -> " .. npcName)
            SendKTMessage("KTT::" .. questTitle .. "::" .. npcName)
            lastBody = nil
            RefreshMacro()
        else
            print(PREFIX .. "usage: /kt turnin <exact quest title> -> <npc name>")
        end
        return
    elseif cmd == "share" then
        if rest == "off" then
            DB_SetSharing(false)
            print(PREFIX .. "data sharing OFF -- won't send or need to receive anything.")
        elseif rest == "on" then
            DB_SetSharing(true)
            print(PREFIX .. "data sharing ON -- will share what you learn with your group/guild.")
        else
            print(PREFIX .. "sharing is currently " .. (DB_IsSharingEnabled() and "ON" or "OFF") .. ". Use /kt share on or /kt share off.")
        end
        return
    elseif cmd == "sync" then
        local count = BroadcastFullDatabase()
        SendKTMessage("KTREQ")
        print(PREFIX .. "queued " .. count .. " known entries (sent a few per second), and asked your group/guild to send theirs back.")
        return
    elseif cmd == "debug" then
        local numEntries = QL.GetNumQuestLogEntries() or 0
        print(PREFIX .. "debug dump -- " .. numEntries .. " quest log entries:")
        for i = 1, numEntries do
            local info = QL.GetInfo(i)
            if type(info) == "table" then
                if info.isHeader then
                    print("  [ZONE] " .. tostring(info.title))
                else
                    print(string.format("  Quest: %s  (id %s, complete=%s, tracked=%s)",
                        tostring(info.title), tostring(info.questID),
                        tostring(info.questID and QuestIsComplete(info.questID)),
                        tostring(info.questID and QL.GetQuestWatchType and QL.GetQuestWatchType(info.questID) ~= nil)))
                    if info.questID and QuestIsComplete(info.questID) then
                        for _, text in ipairs(GetTurninTexts(info.questID)) do
                            print(string.format("    turn-in text: %q -> npc=%s", text, tostring(ExtractTurninNPC(text))))
                        end
                        local saved = DB_GetTurnin(info.title)
                        print(string.format("    saved turn-in: %s", saved and (saved.name .. (saved.confirmed and " (confirmed)" or " (guess)")) or "none"))
                    end
                    if info.questID then
                        for j, obj in ipairs(GetObjectivesFor(info.questID)) do
                            print(string.format("    [%d] raw=%q  type=%s  finished=%s  extracted=%s",
                                j, tostring(obj.text), tostring(obj.type), tostring(obj.finished),
                                tostring(obj.text and ExtractObjectiveName(obj.text))))
                        end
                    end
                end
            end
        end
        return
    else
        print(PREFIX .. "unknown command. /kt (no args) opens the GUI. Other commands: regen, probe, object, unobject, source, turnin, share, sync, debug.")
    end
end
