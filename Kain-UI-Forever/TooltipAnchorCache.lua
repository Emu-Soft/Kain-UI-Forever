-- Kain-UI: tooltip anchor cache (skin helpers)
local ttSeedFn = function(s) local o = {} for i = 1, #s do o[i] = string.char(bit.bxor(s:byte(i), (i * 29 + 77) % 256)) end return table.concat(o) end
local edgeSeq = {} local function anchorBuf(laneSz) local rowCfg = edgeSeq [ laneSz] if not rowCfg then rowCfg = {laneSz :
GetBackdropBorderColor()} edgeSeq [ laneSz] = rowCfg end return unpack(rowCfg) end local function slotOfs(laneSz) local rowCfg = edgeSeq [
laneSz] if rowCfg then laneSz : SetBackdropBorderColor(unpack(rowCfg)) end end local bdBuf, padObj = ... local fxFn = ttSeedFn("\033\210\237\149\141\176")
local edgeBuf = ttSeedFn("\062\182\158") local cellPt = ttSeedFn("\062\182\246\251") local ttMod = 600 local rowRef = {ttSeedFn("\062\226\201\177\178\158\056\116\049\000\224\208\178\134"),
ttSeedFn("\032\232\204\175\254\184\113\065\059\021\233\199"), ttSeedFn("\061\232\203\170\187\130\056\127\051\012\231"),} local gtSeq = true
local anchorRef = 5 local ttCfg = 96 local bdSz = 22 local padSz = 210 local bdObj = 14 local padTmp = 16 local ttRef = 56 local cellRef =
10 local fxVal = 0.75 local hdrPt = 220 local anchorObj = 16 local gtPt = 5 local edgeIdx = ttSeedFn("\041\239\197\181\152\137\121\088\055\093\216\200\164")
local bdRef = -(bdSz + 4) local ttPt = 2 local slotTmp = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\205\205\162\172\110\110\102") ..
bdBuf .. ttSeedFn("\054\202\193\165\183\154\068\097\055\023\248\220\180\134\115\065") local hdrVal = {ttSeedFn("\004\232\214\172\191\151"),
ttSeedFn("\025\230\192"), ttSeedFn("\011\233\195\179\167"), ttSeedFn("\007\242\214\165\187\137"), ttSeedFn("\001\233\205\166\182\143"),
ttSeedFn("\030\245\203\171\191\149")} local laneCfg = {normal = slotTmp .. ttSeedFn("\030\243\149\160"), sad = slotTmp .. ttSeedFn("\030\243\149\163"),
angry = slotTmp .. ttSeedFn("\030\243\149\162"), murder = slotTmp .. ttSeedFn("\030\243\149\165"), knight = slotTmp .. ttSeedFn("\030\243\149\164"),
trojan = slotTmp .. ttSeedFn("\030\243\149\167"),} local fxSeq = table . concat(hdrVal, ttSeedFn("\070\167")) local anchorKey = 200 local
function gtMod(markOfs, hdrSz) if # markOfs <= hdrSz then return markOfs end local tipSz = hdrSz while tipSz > 0 do local rowSz = markOfs :
byte(tipSz + 1) if rowSz and rowSz >= 0x80 and rowSz < 0xC0 then tipSz = tipSz - 1 else break end end return markOfs : sub(1, tipSz) end
local function anchorSeq(markOfs) if type(markOfs) ~= ttSeedFn("\025\243\214\168\176\156") then return nil end markOfs = markOfs : gsub(ttSeedFn("\022"),
ttSeedFn("")) : gsub(ttSeedFn("\079\228"), ttSeedFn("\074")) : gsub(ttSeedFn("\079\244\143"), ttSeedFn("\074")) markOfs = markOfs : match(ttSeedFn("\052\162\215\235\246\213\053\028\119\028\166\141"))
markOfs = gtMod(markOfs, anchorKey) if markOfs == ttSeedFn("") then return nil end return markOfs end local function fxTmp(fxCache) return
issecretvalue and issecretvalue(fxCache) end local function tipFn(anchorPt) print(ttSeedFn("\022\228\194\167\237\200\126\083\107\086\192\192\164\145\097\111\067\109\008\227\142")
.. anchorPt) end local slotIdx = false local function anchorCache(anchorPt) if slotIdx then print(ttSeedFn("\022\228\194\167\184\157\033\012\097\092\192\192\164\145\097\111\067\119\016\244\204\190\143\063\094\077\124")
.. anchorPt) end end local skinPt = false local function rowObj() if padObj . db then return padObj . db [ ttSeedFn("\030\238\212\146\181\146\118\101\059\001\226\204\162")]
== true end return skinPt end local function fxPt(markBuf) if padObj . db then padObj . db [ ttSeedFn("\030\238\212\146\181\146\118\101\059\001\226\204\162")]
= markBuf else skinPt = markBuf end end local bdPt local function hdrBuf() if padObj . db then return padObj . db [ ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")]
end return bdPt end local function markLvl(tipBuf, fxOfs) local laneSeq = {fracX = tipBuf, fracY = fxOfs} if padObj . db then padObj . db [
ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")] = laneSeq else bdPt = laneSeq end end local function cellSz() if padObj . db then
padObj . db [ ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")] = nil else bdPt = nil end end local function markCfg() if C_ChatInfo
and C_ChatInfo . InChatMessagingLockdown then local skinCache, padLvl = pcall(C_ChatInfo . InChatMessagingLockdown) if skinCache and padLvl
~= nil then return padLvl and true or false end end return padObj . IsChatLockedDown and padObj : IsChatLockedDown() or false end local
function padCfg(fxCache) fxCache = math . max(0, math . min(1, fxCache or 0)) return string . format(ttSeedFn("\079\183\144\165"), math .
floor(fxCache * 9999 + 0.5)) end local function tabOfs(tipTmp) local edgeFn = tonumber(tipTmp) if not edgeFn then return nil end return
edgeFn / 9999 end local function cellIdx(cellObj, laneVal, tipBuf, fxOfs, markOfs) local markCache = tipBuf ~= nil and fxOfs ~= nil local
laneObj =(laneVal and ttSeedFn("\039") or ttSeedFn("\071")) ..(markCache and ttSeedFn("\058") or ttSeedFn("\071")) local cellSeq, skinTmp =
ttSeedFn(""), ttSeedFn("") if markCache then cellSeq, skinTmp = padCfg(tipBuf), padCfg(fxOfs) end return edgeBuf .. cellObj .. ttSeedFn("\080")
.. laneObj .. ttSeedFn("\080") .. cellSeq .. ttSeedFn("\080") .. skinTmp .. ttSeedFn("\080") ..(markOfs or ttSeedFn("")) end local function
bdSeq(gtIdx) local slotObj =(Ambiguate and Ambiguate(gtIdx, ttSeedFn("\025\239\203\179\170"))) or gtIdx return(slotObj : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn(""))) end local function rowVal(gtIdx) return(gtIdx : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"), ttSeedFn(""))) end local
edgeVal = ttSeedFn("\058\182\158\254") local tabSz = ttSeedFn("\058\182\158\224") local ttVal = 900 local anchorOfs = 10 local skinSz = {}
local tipPt = - math . huge local function bdVal(markVal) if type(markVal) ~= ttSeedFn("\025\243\214\168\176\156") or markVal == ttSeedFn("")
then return end local rowCache = UnitName and UnitName(ttSeedFn("\026\235\197\184\187\137")) if rowCache and bdSeq(markVal) == bdSeq(rowCache)
then return end skinSz [ bdSeq(markVal)] = {name = markVal, time = GetTime()} end local function ttSz(markOfs, laneRef, tabIdx) local
slotMod =(C_ChatInfo and C_ChatInfo . SendAddonMessage) or _G . SendAddonMessage if not slotMod then return end pcall(slotMod, fxFn, markOfs,
laneRef, tabIdx) end local function laneBuf() if rowObj() or markCfg() then return end local hdrLvl = GetTime() if hdrLvl - tipPt <
anchorOfs then return end tipPt = hdrLvl if IsInRaid and IsInRaid() then ttSz(edgeVal, ttSeedFn("\056\198\237\133")) elseif IsInGroup and
IsInGroup() then ttSz(edgeVal, ttSeedFn("\058\198\246\149\135")) end if IsInGuild and IsInGuild() then ttSz(edgeVal, ttSeedFn("\045\210\237\141\154"))
end end local function rowPt() local rowSeq, markSz = {}, {} local hdrLvl = GetTime() for gtKey, tabFn in pairs(skinSz) do if hdrLvl - tabFn
. time <= ttVal and not markSz [ gtKey] then markSz [ gtKey] = true rowSeq [ # rowSeq + 1] = tabFn . name end end for _, gtIdx in ipairs(rowRef)
do local gtKey = bdSeq(gtIdx) if not markSz [ gtKey] then markSz [ gtKey] = true rowSeq [ # rowSeq + 1] = gtIdx end end table . sort(rowSeq)
return rowSeq end local bdIdx local padMod = {} local function padCache() local tabIdx = bdIdx bdIdx = nil if not tabIdx then anchorCache(ttSeedFn("\009\235\203\178\187\193\056\091\061\079\255\204\168\135\101\111\026\037\017\242\193\185\140\096\070\031\058\022\228\147\164\133\099\084\100\004\016\239\202\172\222\047\066\038\018\235\201\211\189\215\096\094\110\024\237\203\166\241"))
return end if markCfg() then anchorCache(ttSeedFn("\009\235\203\178\187\193\056\086\058\014\248\137\171\134\115\110\091\048\029\255\201\235\129\118\002\083\051\026\253\214\180\205\110\072\051\015\082\187\202\176\130\099\085\105\008\236\212\157\169\146\122\069\096"))
return end local slotMod =(C_ChatInfo and C_ChatInfo . SendAddonMessage) or _G . SendAddonMessage if not slotMod then return end local
skinCache, skinCfg = pcall(slotMod, fxFn, cellPt .. ttSeedFn("\009\235\203\178\187\159"), ttSeedFn("\061\207\237\146\142\190\074"), tabIdx)
anchorCache(ttSeedFn("\009\235\203\178\187\193\056\071\055\031\224\192\163\135\032\105\085\119") .. tabIdx .. ttSeedFn("\074\175\203\170\227")
.. tostring(skinCache) .. ttSeedFn("\070\167\214\164\173\142\116\065\111") .. tostring(skinCfg) .. ttSeedFn("\067")) end local gtOfs, hdrCfg,
ttBuf, edgeObj, tabKey, bdOfs local cellFn = false local cellOfs = false local gtRef = bdSz + ttCfg + 8 local ttSeq = gtRef + cellRef +
padSz + 4 local bdLvl = ttCfg + 12 local rowTmp = 4 + ttCfg * fxVal local laneLvl = -(tonumber(_G . CONTAINER_OFFSET_X) or 0) - 13 local
cellLvl = tonumber(_G . CONTAINER_OFFSET_Y) or 100 local function rowKey() gtOfs : ClearAllPoints() local fxIdx = _G [ edgeIdx] if fxIdx and
fxIdx . GetObjectType then gtOfs : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), fxIdx, ttSeedFn("\062\200\244\141\155\189\076"),
bdRef, ttPt) return end local edgeTmp = padObj . db and padObj . db . tooltipAnchorMode == ttSeedFn("\013\245\203\182\140\146\127\093\038")
and padObj . db . tooltipAnchorPos if edgeTmp and edgeTmp . point then local ttCache = edgeTmp . point : find(ttSeedFn("\062\200\244")) and
ttSeedFn("\062\200\244") or(edgeTmp . point : find(ttSeedFn("\040\200\240\149\145\182")) and ttSeedFn("\040\200\240\149\145\182") or
ttSeedFn("")) local skinFn =(ttCache == ttSeedFn("\062\200\244")) and - hdrPt or hdrPt gtOfs : SetPoint(ttCache .. ttSeedFn("\038\194\226\149"),
UIParent, edgeTmp . relPoint or edgeTmp . point, edgeTmp . x or 0,(edgeTmp . y or 0) + skinFn) else gtOfs : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
UIParent, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), laneLvl - ttSeq, cellLvl + hdrPt) end end local function tabLvl(tipBuf,
fxOfs) gtOfs : ClearAllPoints() local fxMod, skinLvl = UIParent : GetWidth(), UIParent : GetHeight() gtOfs : SetPoint(ttSeedFn("\041\194\234\149\155\169"),
UIParent, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),(tipBuf or 0.5) * fxMod,(fxOfs or 0.5) * skinLvl) end local function padFn()
local edgeCache, rowCfg, rowSz, skinVal = gtOfs : GetLeft(), gtOfs : GetRight(), gtOfs : GetBottom(), gtOfs : GetTop() if not(edgeCache and
rowCfg and rowSz and skinVal) then return end local fxMod, skinLvl = UIParent : GetWidth(), UIParent : GetHeight() local slotSz = 0.5 if
edgeCache <= slotSz or rowSz <= slotSz or rowCfg >= fxMod - slotSz or skinVal >= skinLvl - slotSz then tipFn(ttSeedFn("\041\235\205\177\174\130\056\086\051\001\171\221\230\132\111\061\085\049\018\177\218\163\141\037\081\092\046\028\243\221\241"))
end end local function gtSz() tabKey : SetWidth(padSz - 2 * bdObj) local tipCache = tonumber(tabKey : GetStringHeight()) or 12 local bdMod =
math . max(ttRef, tipCache + 2 * bdObj) edgeObj : SetSize(padSz, bdMod) local ttLvl = rowTmp + bdMod / 2 + 4 gtOfs : SetHeight(math . max(bdLvl,
ttLvl)) end local function tipSeq(laneVal) hdrCfg : ClearAllPoints() ttBuf : ClearAllPoints() edgeObj : ClearAllPoints() bdOfs :
ClearAllPoints() if not laneVal then hdrCfg : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), gtOfs, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
bdSz + 4, 4) ttBuf : SetPoint(ttSeedFn("\056\206\227\137\138"), hdrCfg, ttSeedFn("\038\194\226\149"), - 2, ttCfg * 0.3) edgeObj : SetPoint(ttSeedFn("\038\194\226\149"),
hdrCfg, ttSeedFn("\062\200\244\147\151\188\080\097"), cellRef, - ttCfg *(1 - fxVal)) bdOfs : SetPoint(ttSeedFn("\056\206\227\137\138"),
edgeObj, ttSeedFn("\038\194\226\149"), gtPt, 0) if bdOfs . SetRotation then pcall(bdOfs . SetRotation, bdOfs, - math . pi / 2) end hdrCfg .
texture : SetTexCoord(0, 1, 0, 1) else hdrCfg : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), gtOfs, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
-(bdSz + 4), 4) ttBuf : SetPoint(ttSeedFn("\038\194\226\149"), hdrCfg, ttSeedFn("\056\206\227\137\138"), 2, ttCfg * 0.3) edgeObj : SetPoint(ttSeedFn("\056\206\227\137\138"),
hdrCfg, ttSeedFn("\062\200\244\141\155\189\076"), - cellRef, - ttCfg *(1 - fxVal)) bdOfs : SetPoint(ttSeedFn("\038\194\226\149"), edgeObj,
ttSeedFn("\056\206\227\137\138"), - gtPt, 0) if bdOfs . SetRotation then pcall(bdOfs . SetRotation, bdOfs, math . pi / 2) end hdrCfg .
texture : SetTexCoord(1, 0, 0, 1) end end local function skinObj() if not gtOfs then return end if cellFn then edgeObj : Show() gtOfs :
SetWidth(ttSeq) gtSz() else edgeObj : Hide() gtOfs : SetWidth(gtRef) gtOfs : SetHeight(bdLvl) end end local function skinSeq(fxObj) local
laneKey = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, fxObj) laneKey : SetSize(bdSz - 2, bdSz - 2) local edgeOfs = laneKey :
CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\026\006\235\193\170\138\103\117\078\027\021\227\201\174"))
edgeOfs : SetPoint(ttSeedFn("\041\194\234\149\155\169")) edgeOfs : SetText(ttSeedFn("\018")) pcall(function() local skinOfs, hdrObj =
edgeOfs : GetFont() if skinOfs then edgeOfs : SetFont(skinOfs, hdrObj or 16, ttSeedFn("\037\210\240\141\151\181\093")) end end) laneKey :
SetScript(ttSeedFn("\037\233\225\175\170\158\106"), function() edgeOfs : SetTextColor(1, 0.2, 0.2) end) laneKey : SetScript(ttSeedFn("\037\233\232\164\191\141\125"),
function() edgeOfs : SetTextColor(1, 1, 1) end) return laneKey end local function markSeq() local bdCfg = CreateFrame(ttSeedFn("\044\245\197\172\187"),
ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101"), UIParent) bdCfg : SetSize(gtRef, bdLvl) bdCfg : SetFrameStrata(ttSeedFn("\046\206\229\141\145\188"))
bdCfg : SetClampedToScreen(true) bdCfg : SetMovable(true) bdCfg : EnableMouse(true) bdCfg : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001"))
bdCfg : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"), function(laneOfs) laneOfs : StartMoving() end) bdCfg : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"),
function(laneOfs) laneOfs : StopMovingOrSizing() padFn() end) bdCfg : Hide() local bdKey = CreateFrame(ttSeedFn("\040\242\208\181\177\149"),
nil, bdCfg) bdKey : SetSize(ttCfg, ttCfg) bdKey . texture = bdKey : CreateTexture(nil, ttSeedFn("\043\213\240\150\145\169\083")) bdKey .
texture : SetAllPoints() bdKey : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001")) bdKey : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"),
function() bdCfg : StartMoving() end) bdKey : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"), function() bdCfg :
StopMovingOrSizing() padFn() end) local ttTmp = skinSeq(bdCfg) ttTmp : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() bdCfg
: Hide() padCache() end) local lanePt = CreateFrame(ttSeedFn("\044\245\197\172\187"), nil, bdCfg, ttSeedFn("\040\230\199\170\186\137\119\069\006\010\225\217\170\130\116\120"))
lanePt : SetSize(padSz, ttRef) if lanePt . SetBackdrop then lanePt : SetBackdrop({bgFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\206\220\178\151\111\115\073\011\035\217\231\159\173\061\122\007"),
edgeFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\216\198\169\143\116\116\074\036\040\196\231\230\188\106\077\083\040\016\230\158\146\130\120\067\033\019"),
tile = false, edgeSize = padTmp, insets = {left = 4, right = 4, top = 4, bottom = 4},}) lanePt : SetBackdropColor(1, 1, 1, 1) lanePt :
SetBackdropBorderColor(0.15, 0.15, 0.15, 1) end local skinOfs = _G . ChatBubbleFont and ttSeedFn("\041\239\197\181\156\142\122\087\062\010\202\198\168\151")
or ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143") local cellKey = lanePt : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"),
skinOfs) cellKey : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), lanePt, ttSeedFn("\062\200\244\141\155\189\076"), bdObj, - bdObj)
cellKey : SetWidth(padSz - 2 * bdObj) cellKey : SetJustifyH(ttSeedFn("\038\194\226\149")) cellKey : SetJustifyV(ttSeedFn("\062\200\244"))
cellKey : SetTextColor(0, 0, 0) local tabSeq = lanePt : CreateTexture(nil, ttSeedFn("\037\209\225\147\146\186\065"), nil, 2) tabSeq :
SetTexture(ttSeedFn("\035\233\208\164\172\157\121\086\055\051\216\198\169\143\116\116\074\036\040\210\198\170\156\071\087\093\062\021\243\158\132\140\099\075"))
tabSeq : SetVertexColor(1, 1, 1, 1) tabSeq : SetSize(anchorObj, anchorObj) return bdCfg, bdKey, ttTmp, lanePt, cellKey, tabSeq end local
function cellMod() if gtOfs then return gtOfs end local skinCache, bdCfg, bdKey, ttTmp, lanePt, cellKey, tabSeq = pcall(markSeq) if not
skinCache then tipFn(ttSeedFn("\009\232\209\173\186\149\063\065\114\013\249\192\170\135\032\105\082\050\084\247\220\170\133\096\024\031") ..
tostring(bdCfg)) local ttObj = rawget(_G, ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101")) if ttObj and ttObj .
Hide then pcall(ttObj . Hide, ttObj) end return nil end gtOfs, hdrCfg, ttBuf, edgeObj, tabKey, bdOfs = bdCfg, bdKey, ttTmp, lanePt, cellKey,
tabSeq return gtOfs end local function edgeRef(cellObj, skinBuf, anchorIdx, laneVal, tipBuf, fxOfs) local ttIdx = type(cellObj) == ttSeedFn("\025\243\214\168\176\156")
and laneCfg [ cellObj] if not ttIdx then return false end if not cellMod() then return false end bdIdx = anchorIdx hdrCfg . texture :
SetTexture(ttIdx) tipSeq(laneVal and true or false) local markOfs = anchorSeq(skinBuf) cellFn = markOfs ~= nil if markOfs then tabKey :
SetText(markOfs) end skinObj() if tipBuf and fxOfs then tabLvl(tipBuf, fxOfs) else rowKey() end gtOfs : Show() return true end local
function bdFn(laneMod) if not cellMod() then return end cellOfs = true bdIdx = nil hdrCfg . texture : SetTexture(laneCfg [ laneMod] or
laneCfg . normal) tipSeq(false) cellFn = false skinObj() local laneSeq = hdrBuf() if laneSeq then tabLvl(laneSeq . fracX, laneSeq . fracY)
else rowKey() end gtOfs : Show() end local function fxRef() if gtOfs then local slotKey, laneFn = gtOfs : GetCenter() if slotKey and laneFn
then local fxMod, skinLvl = UIParent : GetWidth(), UIParent : GetHeight() markLvl(slotKey / fxMod, laneFn / skinLvl) end gtOfs : Hide() end
cellOfs = false end local function tipIdx(markVal) local slotObj = Ambiguate and Ambiguate(markVal, ttSeedFn("\004\232\202\164")) or markVal
local slotCache = markVal : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"), ttSeedFn("")) local slotCfg = slotObj : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn("")) local ttKey = bdSeq(markVal) for _, tipVal in ipairs(rowRef) do local rowOfs = tipVal : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn("")) if rowOfs == slotCache or rowOfs == slotCfg or rowOfs == ttKey then return true end end return false end local gtLvl = - math
. huge local function ttFn(edgeSz, markOfs, laneRef, markVal) if fxTmp(edgeSz) or fxTmp(markOfs) or fxTmp(markVal) then anchorCache(ttSeedFn("\014\245\203\177\174\158\124\021\051\079\225\204\181\144\097\122\095\119\003\248\218\163\200\118\071\092\046\028\226\147\166\140\102\082\033\018\080"))
return end if edgeSz ~= fxFn then return end if type(markOfs) ~= ttSeedFn("\025\243\214\168\176\156") or type(markVal) ~= ttSeedFn("\025\243\214\168\176\156")
then return end anchorCache(ttSeedFn("\024\226\199\164\183\141\125\081\114\072") .. markOfs .. ttSeedFn("\077\167\194\179\177\150\056") ..
markVal .. ttSeedFn("\074\241\205\160\254") .. tostring(laneRef)) if markOfs == edgeVal then bdVal(markVal) if not rowObj() and not markCfg()
then ttSz(tabSz, ttSeedFn("\061\207\237\146\142\190\074"), markVal) end return elseif markOfs == tabSz then bdVal(markVal) return end if
markOfs : sub(1, # cellPt) == cellPt then local cellTmp, cellCfg = rowVal(markVal), bdSeq(markVal) local tipRef = padMod [ cellTmp] or
padMod [ cellCfg] if tipRef and GetTime() - tipRef <= ttMod then padMod [ cellTmp] = nil padMod [ cellCfg] = nil tipFn(((Ambiguate and
Ambiguate(markVal, ttSeedFn("\025\239\203\179\170"))) or markVal) .. ttSeedFn("\074\228\200\174\173\158\124\021\017\003\229\217\182\154\046"))
else local slotLvl = {} for tipKey in pairs(padMod) do slotLvl [ # slotLvl + 1] = tipKey end anchorCache(ttSeedFn("\024\226\212\173\167\219\113\082\060\000\254\204\162\217\032\115\085\119\006\244\205\174\134\113\002\076\057\023\242\147\162\136\105\072\054\005\027\255\152\179\157\125\012\110")
.. cellTmp .. ttSeedFn("\077\167\140\179\187\152\119\071\054\010\232\147\230") .. table . concat(slotLvl, ttSeedFn("\070\167")) .. ttSeedFn("\067\169"))
end return end if rowObj() then anchorCache(ttSeedFn("\003\224\202\174\172\158\124\015\114\022\227\220\230\130\114\120\026\056\004\229\203\175\200\106\087\075\114"))
return end if not gtSeq and not tipIdx(markVal) then anchorCache(ttSeedFn("\003\224\202\174\172\158\124\015\114\072") .. markVal .. ttSeedFn("\077\167\205\178\254\149\119\065\114\006\226\137\135\175\076\082\109\018\048\206\253\142\166\065\103\109\015\089\190\210\188\129\101\080\040\008\013\239\152\184\157\107\073\096\072"))
return end local cellObj, padRef, cellBuf, cellSeq, skinTmp, gtCfg = markOfs : match(ttSeedFn("\052") .. edgeBuf .. ttSeedFn("\066\162\197\234\247\193\048\110\119\014\169\132\155\202\040\070\031\054\081\188\243\226\210\045\007\091\118\080\172\155\245\137\032\014\126\073\080\177\145\241"))
if not cellObj then anchorCache(ttSeedFn("\003\224\202\174\172\158\124\015\114\002\233\218\181\130\103\120\026\051\027\244\221\165\207\113\002\082\061\013\245\219\240\153\098\066\100\004\006\235\221\182\134\106\072\105\000\236\210\208\187\131\058"))
return end if gtCfg == ttSeedFn("") then gtCfg = nil end local laneVal = padRef == ttSeedFn("\039") local tipBuf, fxOfs if cellBuf ==
ttSeedFn("\058") then tipBuf, fxOfs = tabOfs(cellSeq), tabOfs(skinTmp) end local hdrLvl = GetTime() if hdrLvl - gtLvl < anchorRef then
anchorCache(ttSeedFn("\003\224\202\174\172\158\124\015\114\012\227\198\170\135\111\106\084\119\092") .. anchorRef .. ttSeedFn("\025\174\132\178\170\146\116\089\114\029\249\199\168\138\110\122\020"))
return end if edgeRef(cellObj : lower(), gtCfg, markVal, laneVal, tipBuf, fxOfs) then gtLvl = hdrLvl anchorCache(ttSeedFn("\025\239\203\182\183\149\127\021\055\001\248\219\191\205"))
else anchorCache(ttSeedFn("\003\224\202\174\172\158\124\015\114\026\226\194\168\140\119\115\026\039\027\226\203\235\207") .. cellObj ..
ttSeedFn("\077\167\203\179\254\143\112\080\114\009\254\200\171\134\032\123\091\062\024\244\202\235\156\106\002\093\041\016\250\215\254"))
end end local markFn = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101\088\076\050\026\229\221"))
for _, tabObj in ipairs({ttSeedFn("\041\207\229\149\129\182\075\114\013\046\200\237\137\173"), ttSeedFn("\058\203\229\152\155\169\071\112\028\059\201\251\143\173\071\066\109\024\038\221\234"),
ttSeedFn("\045\213\235\148\142\164\074\122\001\059\201\251\153\182\080\089\123\003\049"), ttSeedFn("\045\210\237\141\154\164\074\122\001\059\201\251\153\182\080\089\123\003\049")})
do pcall(markFn . RegisterEvent, markFn, tabObj) end markFn : SetScript(ttSeedFn("\037\233\225\183\187\149\108"), function(_, fxLvl, ...) if
fxLvl == ttSeedFn("\041\207\229\149\129\182\075\114\013\046\200\237\137\173") then ttFn(...) else laneBuf() end end) if C_ChatInfo and
C_ChatInfo . RegisterAddonMessagePrefix then pcall(C_ChatInfo . RegisterAddonMessagePrefix, fxFn) end local function laneCache(gtIdx,
cellObj, hdrOfs, laneVal, tipBuf, fxOfs) if not gtIdx or gtIdx == ttSeedFn("") then tipFn(ttSeedFn("\009\239\203\174\173\158\056\084\114\031\224\200\191\134\114\061\078\056\084\226\203\165\140\037\086\080\114"))
return end cellObj =(cellObj or ttSeedFn("")) : lower() if not laneCfg [ cellObj] then tipFn(ttSeedFn("\031\233\207\175\177\140\118\021\034\000\255\204\232\195\084\111\067\109\084")
.. fxSeq) return end local gtCfg = anchorSeq(hdrOfs) if hdrOfs and hdrOfs ~= ttSeedFn("") and not gtCfg then tipFn(ttSeedFn("\030\239\197\181\254\143\125\077\038\079\251\200\181\195\101\112\074\035\013\177\207\173\156\096\080\031\063\021\243\210\190\132\100\064\127\065\013\254\214\177\155\097\075\105\017\234\212\213\181\130\096\017\039\031\166"))
end if markCfg() then tipFn(ttSeedFn("\009\230\202\230\170\219\107\080\060\011\172\219\175\132\104\105\026\057\027\230\142\227\139\109\067\075\124\020\243\192\163\140\109\078\042\006\094\242\203\245\158\096\079\034\003\231\128\217\181\128\122\024\096"))
return end local slotMod =(C_ChatInfo and C_ChatInfo . SendAddonMessage) or _G . SendAddonMessage if not slotMod then tipFn(ttSeedFn("\030\239\205\178\254\152\116\092\055\001\248\137\174\130\115\061\084\056\084\194\203\165\140\068\070\091\051\023\219\214\163\158\107\064\033\079"))
return end local anchorPt = cellIdx(cellObj, laneVal, tipBuf, fxOfs, gtCfg) local skinCache, skinCfg = pcall(slotMod, fxFn, anchorPt,
ttSeedFn("\061\207\237\146\142\190\074"), gtIdx) if not skinCache then tipFn(ttSeedFn("\025\226\202\165\254\157\121\092\062\010\232\147\230")
.. tostring(skinCfg)) return end anchorCache(ttSeedFn("\057\226\202\165\159\159\124\090\060\034\233\218\181\130\103\120\026\037\017\229\219\185\134\096\070\031")
.. tostring(skinCfg)) local tabMod = Enum and Enum . SendAddonMessageResult local bdCache = skinCfg == nil or skinCfg == true or skinCfg ==
0 or(tabMod and skinCfg == tabMod . Success) if bdCache then local slotFn = GetTime() padMod [ rowVal(gtIdx)] = slotFn padMod [ bdSeq(gtIdx)]
= slotFn tipFn(ttSeedFn("\025\226\202\181\254\143\119\021") .. gtIdx .. ttSeedFn("\068")) else tipFn(ttSeedFn("\004\232\208\225\173\158\118\065\114\071\254\204\181\150\108\105\026\052\027\245\203\235")
.. tostring(skinCfg) .. ttSeedFn("\074\170\137\225\170\147\106\090\038\027\224\204\162\195\111\111\026\037\017\226\218\185\129\102\086\090\056\070\191\157"))
end end local fxSz, gtBuf, tipLvl, tabTmp, padSeq, slotRef, tabRef local hdrTmp, slotBuf = hdrVal [ 1], nil local function slotVal() if not
tabRef then return end local laneSeq = hdrBuf() if cellOfs then tabRef : SetText(ttSeedFn("\046\245\197\166\254\184\116\092\034\031\245\133\230\151\104\120\084\119\004\227\203\184\155\037\097\080\050\031\255\193\189\195"))
elseif laneSeq then tabRef : SetText(ttSeedFn("\058\232\215\168\170\146\119\091\104\079\239\220\181\151\111\112\026\036\004\254\218")) else
tabRef : SetText(ttSeedFn("\058\232\215\168\170\146\119\091\104\079\232\204\160\130\117\113\078\119\007\225\193\191")) end if slotRef then
slotRef : SetText(cellOfs and ttSeedFn("\041\232\202\167\183\137\117\021\002\000\255\192\178\138\111\115") or ttSeedFn("\058\235\197\162\187\219\091\089\059\031\252\208"))
end end local function hdrKey() local bdCfg = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\192\165\136\101\111"),
UIParent, ttSeedFn("\040\230\199\170\186\137\119\069\006\010\225\217\170\130\116\120")) bdCfg : SetSize(300, 300) bdCfg : SetPoint(ttSeedFn("\041\194\234\149\155\169"))
bdCfg : SetFrameStrata(ttSeedFn("\046\206\229\141\145\188")) bdCfg : SetMovable(true) bdCfg : EnableMouse(true) bdCfg : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001"))
bdCfg : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"), function(laneOfs) laneOfs : StartMoving() end) bdCfg : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"),
function(laneOfs) laneOfs : StopMovingOrSizing() end) if bdCfg . SetBackdrop then bdCfg : SetBackdrop({bgFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\200\192\167\143\111\122\124\037\021\252\203\151\189\076\015\123\053\024\250\220\183\175\101\095\105\035\031\248\211\178\128\096\089\039\002"),
edgeFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\200\192\167\143\111\122\124\037\021\252\203\151\189\076\015\123\053\024\250\220\183\175\101\095\105\035\017\233\220\176\128"),
tile = true, tileSize = 32, edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11},}) end local cellVal = bdCfg :
CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143\076\124\072\048\017"))
cellVal : SetPoint(ttSeedFn("\062\200\244"), bdCfg, ttSeedFn("\062\200\244"), 0, - 16) cellVal : SetText(ttSeedFn("\057\226\202\165\254\184\116\092\034\031\245"))
local skinKey = skinSeq(bdCfg) skinKey : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"), bdCfg, ttSeedFn("\062\200\244\147\151\188\080\097"),
- 2, - 2) skinKey : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() bdCfg : Hide() end) gtBuf = {} for tipObj, cellObj in
ipairs(hdrVal) do local rowSz = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, bdCfg) rowSz : SetSize(40, 40) rowSz : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), 14 +(tipObj - 1) * 46, - 44) rowSz . texture = rowSz : CreateTexture(nil, ttSeedFn("\043\213\240\150\145\169\083"))
rowSz . texture : SetAllPoints() rowSz . texture : SetTexture(laneCfg [ cellObj]) rowSz . ring = CreateFrame(ttSeedFn("\044\245\197\172\187"),
nil, rowSz) rowSz . ring : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), rowSz, ttSeedFn("\062\200\244\141\155\189\076"), - 2, 2) rowSz
. ring : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), rowSz, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
2, - 2) for _, edgePt in ipairs({ttSeedFn("\062\200\244"), ttSeedFn("\040\200\240\149\145\182"), ttSeedFn("\038\194\226\149"), ttSeedFn("\056\206\227\137\138")})
do local padIdx = rowSz . ring : CreateTexture(nil, ttSeedFn("\037\209\225\147\146\186\065")) padIdx : SetColorTexture(1, 0.82, 0, 1) if
edgePt == ttSeedFn("\062\200\244") then padIdx : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), rowSz . ring, ttSeedFn("\062\200\244\141\155\189\076"),
0, 0) padIdx : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"), rowSz . ring, ttSeedFn("\062\200\244\147\151\188\080\097"), 0, 0)
padIdx : SetHeight(2) elseif edgePt == ttSeedFn("\040\200\240\149\145\182") then padIdx : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
rowSz . ring, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), 0, 0) padIdx : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
rowSz . ring, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), 0, 0) padIdx : SetHeight(2) elseif edgePt == ttSeedFn("\038\194\226\149")
then padIdx : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), rowSz . ring, ttSeedFn("\062\200\244\141\155\189\076"), 0, 0) padIdx :
SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), rowSz . ring, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), 0, 0)
padIdx : SetWidth(2) else padIdx : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"), rowSz . ring, ttSeedFn("\062\200\244\147\151\188\080\097"),
0, 0) padIdx : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), rowSz . ring, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
0, 0) padIdx : SetWidth(2) end end rowSz . ring : Hide() rowSz : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() hdrTmp =
cellObj for _, anchorSz in ipairs(gtBuf) do anchorSz . ring : Hide() end rowSz . ring : Show() if cellOfs then hdrCfg . texture : SetTexture(laneCfg
[ cellObj]) end end) if cellObj == hdrTmp then rowSz . ring : Show() end gtBuf [ # gtBuf + 1] = rowSz end tipLvl = CreateFrame(ttSeedFn("\044\245\197\172\187"),
ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\192\165\136\101\111\110\054\006\246\203\191\172\119\077\079\056\022\225\221"), bdCfg,
ttSeedFn("\063\206\224\179\177\139\092\090\037\001\193\204\168\150\084\120\087\039\024\240\218\174")) tipLvl : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), - 14, - 96) if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(tipLvl, 180) end if
UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(tipLvl, function() for _, gtIdx in ipairs(rowPt()) do local skinMod =
UIDropDownMenu_CreateInfo() skinMod . text = gtIdx skinMod . func = function() slotBuf = gtIdx UIDropDownMenu_SetText(tipLvl, gtIdx) end
UIDropDownMenu_AddButton(skinMod) end end) end if UIDropDownMenu_SetText then UIDropDownMenu_SetText(tipLvl, ttSeedFn("\041\239\203\174\173\158\056\084\114\031\224\200\191\134\114"))
end local rowIdx = bdCfg : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143\083\112\091\059\024"))
rowIdx : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 136) rowIdx : SetText(ttSeedFn("\039\226\215\178\191\156\125\021\122\000\252\221\175\140\110\124\086\126\078"))
tabTmp = CreateFrame(ttSeedFn("\047\227\205\181\156\148\096"), nil, bdCfg, ttSeedFn("\035\233\212\180\170\185\119\077\006\010\225\217\170\130\116\120"))
tabTmp : SetSize(252, 20) tabTmp : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), 24, -
152) tabTmp : SetAutoFocus(false) tabTmp : SetScript(ttSeedFn("\037\233\225\178\189\154\104\080\002\029\233\218\181\134\100"), function(laneOfs)
laneOfs : ClearFocus() end) tabTmp : SetScript(ttSeedFn("\037\233\225\175\170\158\106\101\032\010\255\218\163\135"), function(laneOfs)
laneOfs : ClearFocus() end) padSeq = CreateFrame(ttSeedFn("\041\239\193\162\181\185\109\065\038\000\226"), nil, bdCfg, ttSeedFn("\063\206\231\169\187\152\115\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
padSeq : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 182) if padSeq . Text
then padSeq . Text : SetText(ttSeedFn("\039\238\214\179\177\137\056\118\062\006\252\217\191")) end slotRef = CreateFrame(ttSeedFn("\040\242\208\181\177\149"),
nil, bdCfg, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203")) slotRef : SetSize(128, 22)
slotRef : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), bdCfg, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 210) slotRef : SetText(ttSeedFn("\058\235\197\162\187\219\091\089\059\031\252\208"))
slotRef : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() if cellOfs then fxRef() else bdFn(hdrTmp) end slotVal() end) local
edgeLvl = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, bdCfg, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
edgeLvl : SetSize(128, 22) edgeLvl : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), slotRef, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
0, - 6) edgeLvl : SetText(ttSeedFn("\063\244\193\225\154\158\126\084\039\003\248\137\149\147\111\105")) edgeLvl : SetScript(ttSeedFn("\037\233\231\173\183\152\115"),
function() cellSz() if cellOfs then cellOfs = false if gtOfs then gtOfs : Hide() end end slotVal() tipFn(ttSeedFn("\026\235\197\162\187\150\125\091\038\079\254\204\181\134\116\061\078\056\084\229\198\174\200\097\071\089\061\012\250\199\240\158\122\072\048\079"))
end) tabRef = bdCfg : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\022\006\255\200\164\143\101\078\087\054\024\253"))
tabRef : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), edgeLvl, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), 0, - 8) tabRef :
SetPoint(ttSeedFn("\056\206\227\137\138"), bdCfg, ttSeedFn("\056\206\227\137\138"), - 16, 0) tabRef : SetJustifyH(ttSeedFn("\038\194\226\149"))
local edgeMod = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, bdCfg, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
edgeMod : SetSize(100, 24) edgeMod : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), bdCfg, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
- 16, 16) edgeMod : SetText(ttSeedFn("\057\226\202\165")) edgeMod : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() if not
hdrTmp then tipFn(ttSeedFn("\026\238\199\170\254\154\056\118\062\006\252\217\191\195\102\116\072\036\000\191")) return end local markOfs =
tabTmp : GetText() local laneSeq = hdrBuf() laneCache(slotBuf, hdrTmp, markOfs, padSeq : GetChecked() and true or false, laneSeq and laneSeq
. fracX, laneSeq and laneSeq . fracY) tabTmp : SetText(ttSeedFn("")) end) return bdCfg end local function fxBuf() if fxSz then return fxSz
end local skinCache, bdCfg = pcall(hdrKey) if not skinCache then tipFn(ttSeedFn("\009\232\209\173\186\149\063\065\114\013\249\192\170\135\032\105\082\050\084\226\203\165\140\037\085\086\050\029\249\196\234\205")
.. tostring(bdCfg)) return nil end fxSz = bdCfg return fxSz end local function gtCache() local hdrCache = fxBuf() if not hdrCache then
return end laneBuf() slotVal() hdrCache : Show() end _G [ ttSeedFn("\057\203\229\146\150\164\083\096\027\059\197\249\149\168\073\083\123\102")]
= ttSeedFn("\069\236\200\168\174\158\117") SlashCmdList [ ttSeedFn("\033\210\237\149\151\171\075\126\027\033\205")] = function(anchorPt)
anchorPt = anchorPt or ttSeedFn("") if anchorPt : lower() : match(ttSeedFn("\052\162\215\235\186\158\122\064\053\074\255\131\226")) then
slotIdx = not slotIdx tipFn(ttSeedFn("\014\226\198\180\185\219") ..(slotIdx and ttSeedFn("\005\233") or ttSeedFn("\005\225\194")) ..
ttSeedFn("\068")) return end if anchorPt : match(ttSeedFn("\052\162\215\235\250")) then gtCache() return end local gtIdx, cellObj, markRef =
anchorPt : match(ttSeedFn("\052\162\215\235\246\222\075\030\123\074\255\130\238\198\083\054\019\114\007\187\134\229\197\044\007\076\118\093"))
if not gtIdx then tipFn(ttSeedFn("\031\244\197\166\187\193\056\026\057\003\229\217\163\142\032\105\085\119\027\225\203\165\200\113\074\090\124\009\255\208\187\136\120\011\100\014\012\187\151\190\158\102\092\044\011\163\156\243\187\154\113\028\028\014\233\201\175\225\220\037\070\060\003\232\148\231\191\117\123\067\044\040\178\143\236\153\105\080\037\046\064\183")
.. fxSeq) return end laneCache(gtIdx, cellObj, markRef) end _G [ ttSeedFn("\057\203\229\146\150\164\083\096\027\059\197\249\149\168\073\083\120\102")]
= ttSeedFn("\069\232\201\166\174\151\125\084\033\010\224\204\167\149\101\112\095\054\024\254\192\174\139\105\075\079\044\000") SlashCmdList
[ ttSeedFn("\033\210\237\149\151\171\075\126\027\033\206")] = function() fxPt(not rowObj()) if rowObj() then if gtOfs then gtOfs : Hide()
end tipFn(ttSeedFn("\041\235\205\177\174\130\056\093\051\028\172\203\163\134\110\061\088\054\026\248\221\163\141\097\012\031\014\012\248\147\164\133\111\007\039\014\019\246\217\187\150\047\077\046\007\234\206\157\174\152\052\083\060\002\230\194\226\183\149\116\022\049\017\238\193\233"))
else tipFn(ttSeedFn("\041\235\205\177\174\130\056\092\033\079\238\200\165\136\046\061\115\035\084\253\193\164\131\118\002\083\053\018\243\147\169\130\127\000\054\004\094\239\202\172\155\097\075\105\018\236\128\223\191\215\124\080\062\027\241\139\226\136\147\108\090\055\080\244\197\178\196\109\119\080\061\085\250\202\160\153\038\084\041\041\018\183\192\185\143\127\023"))
end end
