-- Kain-UI: tooltip anchor cache (skin helpers)
local ttSeedFn = function(s) local o = {} for i = 1, #s do o[i] = string.char(bit.bxor(s:byte(i), (i * 29 + 77) % 256)) end return table.concat(o) end
local slotObj = {} local function slotCfg(skinPt) local skinCache = slotObj [ skinPt] if not skinCache then skinCache = {skinPt :
GetBackdropBorderColor()} slotObj [ skinPt] = skinCache end return unpack(skinCache) end local function cellCfg(skinPt) local skinCache =
slotObj [ skinPt] if skinCache then skinPt : SetBackdropBorderColor(unpack(skinCache)) end end local fxPt, tipIdx = ... local bdRef =
ttSeedFn("\033\210\237\149\141\176") local rowPt = ttSeedFn("\062\182\158") local anchorOfs = ttSeedFn("\062\182\246\251") local ttVal = 600
local gtSeq = {ttSeedFn("\062\226\201\177\178\158\056\116\049\000\224\208\178\134"), ttSeedFn("\032\232\204\175\254\184\113\065\059\021\233\199"),}
local tabSz = 5 local bdSz = 96 local bdFn = 22 local ttRef = 210 local cellRef = 14 local bdLvl = 16 local padTmp = 56 local fxVal = 10
local skinObj = 0.75 local ttMod = 220 local cellPt = 16 local anchorRef = 5 local cellIdx = ttSeedFn("\041\239\197\181\152\137\121\088\055\093\216\200\164")
local gtRef = -(bdFn + 4) local edgeIdx = 2 local padObj = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\205\205\162\172\110\110\102")
.. fxPt .. ttSeedFn("\054\202\193\165\183\154\068\097\055\023\248\220\180\134\115\065") local rowObj = {ttSeedFn("\004\232\214\172\191\151"),
ttSeedFn("\025\230\192"), ttSeedFn("\011\233\195\179\167"), ttSeedFn("\007\242\214\165\187\137"), ttSeedFn("\001\233\205\166\182\143"),
ttSeedFn("\030\245\203\171\191\149")} local ttFn = {normal = padObj .. ttSeedFn("\030\243\149\160"), sad = padObj .. ttSeedFn("\030\243\149\163"),
angry = padObj .. ttSeedFn("\030\243\149\162"), murder = padObj .. ttSeedFn("\030\243\149\165"), knight = padObj .. ttSeedFn("\030\243\149\164"),
trojan = padObj .. ttSeedFn("\030\243\149\167"),} local gtCache = table . concat(rowObj, ttSeedFn("\070\167")) local fxTmp = 200 local
function bdVal(edgeMod, hdrCfg) if # edgeMod <= hdrCfg then return edgeMod end local ttTmp = hdrCfg while ttTmp > 0 do local edgeRef =
edgeMod : byte(ttTmp + 1) if edgeRef and edgeRef >= 0x80 and edgeRef < 0xC0 then ttTmp = ttTmp - 1 else break end end return edgeMod : sub(1,
ttTmp) end local function markCfg(edgeMod) if type(edgeMod) ~= ttSeedFn("\025\243\214\168\176\156") then return nil end edgeMod = edgeMod :
gsub(ttSeedFn("\022"), ttSeedFn("")) : gsub(ttSeedFn("\079\228"), ttSeedFn("\074")) : gsub(ttSeedFn("\079\244\143"), ttSeedFn("\074"))
edgeMod = edgeMod : match(ttSeedFn("\052\162\215\235\246\213\053\028\119\028\166\141")) edgeMod = bdVal(edgeMod, fxTmp) if edgeMod ==
ttSeedFn("") then return nil end return edgeMod end local function ttCfg(edgePt) return issecretvalue and issecretvalue(edgePt) end local
function tabLvl(slotLvl) print(ttSeedFn("\022\228\194\167\237\200\126\083\107\086\192\192\164\145\097\111\067\109\008\227\142") .. slotLvl)
end local ttBuf = false local function laneLvl(slotLvl) if ttBuf then print(ttSeedFn("\022\228\194\167\184\157\033\012\097\092\192\192\164\145\097\111\067\119\016\244\204\190\143\063\094\077\124")
.. slotLvl) end end local edgeTmp = false local function padCache() if tipIdx . db then return tipIdx . db [ ttSeedFn("\030\238\212\146\181\146\118\101\059\001\226\204\162")]
== true end return edgeTmp end local function rowKey(hdrObj) if tipIdx . db then tipIdx . db [ ttSeedFn("\030\238\212\146\181\146\118\101\059\001\226\204\162")]
= hdrObj else edgeTmp = hdrObj end end local cellObj local function gtSz() if tipIdx . db then return tipIdx . db [ ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")]
end return cellObj end local function rowVal(tabTmp, slotSz) local hdrSz = {fracX = tabTmp, fracY = slotSz} if tipIdx . db then tipIdx . db
[ ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")] = hdrSz else cellObj = hdrSz end end local function padFn() if tipIdx . db then
tipIdx . db [ ttSeedFn("\030\238\212\146\181\146\118\102\034\000\248")] = nil else cellObj = nil end end local function ttPt() if C_ChatInfo
and C_ChatInfo . InChatMessagingLockdown then local padIdx, tipObj = pcall(C_ChatInfo . InChatMessagingLockdown) if padIdx and tipObj ~= nil
then return tipObj and true or false end end return tipIdx . IsChatLockedDown and tipIdx : IsChatLockedDown() or false end local function
laneCache(edgePt) edgePt = math . max(0, math . min(1, edgePt or 0)) return string . format(ttSeedFn("\079\183\144\165"), math . floor(edgePt
* 9999 + 0.5)) end local function cellLvl(anchorSz) local edgeCache = tonumber(anchorSz) if not edgeCache then return nil end return
edgeCache / 9999 end local function markSeq(gtIdx, tipKey, tabTmp, slotSz, edgeMod) local tipBuf = tabTmp ~= nil and slotSz ~= nil local
slotIdx =(tipKey and ttSeedFn("\039") or ttSeedFn("\071")) ..(tipBuf and ttSeedFn("\058") or ttSeedFn("\071")) local fxIdx, tabSeq =
ttSeedFn(""), ttSeedFn("") if tipBuf then fxIdx, tabSeq = laneCache(tabTmp), laneCache(slotSz) end return rowPt .. gtIdx .. ttSeedFn("\080")
.. slotIdx .. ttSeedFn("\080") .. fxIdx .. ttSeedFn("\080") .. tabSeq .. ttSeedFn("\080") ..(edgeMod or ttSeedFn("")) end local function
slotTmp(tipPt) local gtBuf =(Ambiguate and Ambiguate(tipPt, ttSeedFn("\025\239\203\179\170"))) or tipPt return(gtBuf : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn(""))) end local function hdrVal(tipPt) return(tipPt : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"), ttSeedFn(""))) end local
bdMod local cellTmp = {} local function edgeBuf() local slotMod = bdMod bdMod = nil if not slotMod then laneLvl(ttSeedFn("\009\235\203\178\187\193\056\091\061\079\255\204\168\135\101\111\026\037\017\242\193\185\140\096\070\031\058\022\228\147\164\133\099\084\100\004\016\239\202\172\222\047\066\038\018\235\201\211\189\215\096\094\110\024\237\203\166\241"))
return end if ttPt() then laneLvl(ttSeedFn("\009\235\203\178\187\193\056\086\058\014\248\137\171\134\115\110\091\048\029\255\201\235\129\118\002\083\051\026\253\214\180\205\110\072\051\015\082\187\202\176\130\099\085\105\008\236\212\157\169\146\122\069\096"))
return end local fxObj =(C_ChatInfo and C_ChatInfo . SendAddonMessage) or _G . SendAddonMessage if not fxObj then return end local padIdx,
ttObj = pcall(fxObj, bdRef, anchorOfs .. ttSeedFn("\009\235\203\178\187\159"), ttSeedFn("\061\207\237\146\142\190\074"), slotMod) laneLvl(ttSeedFn("\009\235\203\178\187\193\056\071\055\031\224\192\163\135\032\105\085\119")
.. slotMod .. ttSeedFn("\074\175\203\170\227") .. tostring(padIdx) .. ttSeedFn("\070\167\214\164\173\142\116\065\111") .. tostring(ttObj) ..
ttSeedFn("\067")) end local tabObj, anchorIdx, cellKey, gtMod, bdBuf, rowOfs local skinOfs = false local anchorPt = false local hdrKey =
bdFn + bdSz + 8 local tabOfs = hdrKey + fxVal + ttRef + 4 local laneBuf = bdSz + 12 local rowRef = 4 + bdSz * skinObj local cellSz = -(tonumber(_G
. CONTAINER_OFFSET_X) or 0) - 13 local fxRef = tonumber(_G . CONTAINER_OFFSET_Y) or 100 local function fxSeq() tabObj : ClearAllPoints()
local slotBuf = _G [ cellIdx] if slotBuf and slotBuf . GetObjectType then tabObj : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
slotBuf, ttSeedFn("\062\200\244\141\155\189\076"), gtRef, edgeIdx) return end local edgeFn = tipIdx . db and tipIdx . db . tooltipAnchorMode
== ttSeedFn("\013\245\203\182\140\146\127\093\038") and tipIdx . db . tooltipAnchorPos if edgeFn and edgeFn . point then local slotFn =
edgeFn . point : find(ttSeedFn("\062\200\244")) and ttSeedFn("\062\200\244") or(edgeFn . point : find(ttSeedFn("\040\200\240\149\145\182"))
and ttSeedFn("\040\200\240\149\145\182") or ttSeedFn("")) local cellFn =(slotFn == ttSeedFn("\062\200\244")) and - ttMod or ttMod tabObj :
SetPoint(slotFn .. ttSeedFn("\038\194\226\149"), UIParent, edgeFn . relPoint or edgeFn . point, edgeFn . x or 0,(edgeFn . y or 0) + cellFn)
else tabObj : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), UIParent, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
cellSz - tabOfs, fxRef + ttMod) end end local function laneCfg(tabTmp, slotSz) tabObj : ClearAllPoints() local bdCache, laneObj = UIParent :
GetWidth(), UIParent : GetHeight() tabObj : SetPoint(ttSeedFn("\041\194\234\149\155\169"), UIParent, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),(tabTmp
or 0.5) * bdCache,(slotSz or 0.5) * laneObj) end local function fxFn() local fxSz, skinCache, edgeRef, hdrTmp = tabObj : GetLeft(), tabObj :
GetRight(), tabObj : GetBottom(), tabObj : GetTop() if not(fxSz and skinCache and edgeRef and hdrTmp) then return end local bdCache, laneObj
= UIParent : GetWidth(), UIParent : GetHeight() local bdIdx = 0.5 if fxSz <= bdIdx or edgeRef <= bdIdx or skinCache >= bdCache - bdIdx or
hdrTmp >= laneObj - bdIdx then tabLvl(ttSeedFn("\041\235\205\177\174\130\056\086\051\001\171\221\230\132\111\061\085\049\018\177\218\163\141\037\081\092\046\028\243\221\241"))
end end local function fxBuf() bdBuf : SetWidth(ttRef - 2 * cellRef) local markVal = tonumber(bdBuf : GetStringHeight()) or 12 local slotVal
= math . max(padTmp, markVal + 2 * cellRef) gtMod : SetSize(ttRef, slotVal) local gtLvl = rowRef + slotVal / 2 + 4 tabObj : SetHeight(math .
max(laneBuf, gtLvl)) end local function edgeVal(tipKey) anchorIdx : ClearAllPoints() cellKey : ClearAllPoints() gtMod : ClearAllPoints()
rowOfs : ClearAllPoints() if not tipKey then anchorIdx : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), tabObj, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
bdFn + 4, 4) cellKey : SetPoint(ttSeedFn("\056\206\227\137\138"), anchorIdx, ttSeedFn("\038\194\226\149"), - 2, bdSz * 0.3) gtMod : SetPoint(ttSeedFn("\038\194\226\149"),
anchorIdx, ttSeedFn("\062\200\244\147\151\188\080\097"), fxVal, - bdSz *(1 - skinObj)) rowOfs : SetPoint(ttSeedFn("\056\206\227\137\138"),
gtMod, ttSeedFn("\038\194\226\149"), anchorRef, 0) if rowOfs . SetRotation then pcall(rowOfs . SetRotation, rowOfs, - math . pi / 2) end
anchorIdx . texture : SetTexCoord(0, 1, 0, 1) else anchorIdx : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), tabObj,
ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), -(bdFn + 4), 4) cellKey : SetPoint(ttSeedFn("\038\194\226\149"), anchorIdx,
ttSeedFn("\056\206\227\137\138"), 2, bdSz * 0.3) gtMod : SetPoint(ttSeedFn("\056\206\227\137\138"), anchorIdx, ttSeedFn("\062\200\244\141\155\189\076"),
- fxVal, - bdSz *(1 - skinObj)) rowOfs : SetPoint(ttSeedFn("\038\194\226\149"), gtMod, ttSeedFn("\056\206\227\137\138"), - anchorRef, 0) if
rowOfs . SetRotation then pcall(rowOfs . SetRotation, rowOfs, math . pi / 2) end anchorIdx . texture : SetTexCoord(1, 0, 0, 1) end end local
function rowTmp() if not tabObj then return end if skinOfs then gtMod : Show() tabObj : SetWidth(tabOfs) fxBuf() else gtMod : Hide() tabObj
: SetWidth(hdrKey) tabObj : SetHeight(laneBuf) end end local function anchorKey(padSeq) local hdrPt = CreateFrame(ttSeedFn("\040\242\208\181\177\149"),
nil, padSeq) hdrPt : SetSize(bdFn - 2, bdFn - 2) local markFn = hdrPt : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"),
ttSeedFn("\045\230\201\164\152\148\118\065\026\006\235\193\170\138\103\117\078\027\021\227\201\174")) markFn : SetPoint(ttSeedFn("\041\194\234\149\155\169"))
markFn : SetText(ttSeedFn("\018")) pcall(function() local tipLvl, tabFn = markFn : GetFont() if tipLvl then markFn : SetFont(tipLvl, tabFn
or 16, ttSeedFn("\037\210\240\141\151\181\093")) end end) hdrPt : SetScript(ttSeedFn("\037\233\225\175\170\158\106"), function() markFn :
SetTextColor(1, 0.2, 0.2) end) hdrPt : SetScript(ttSeedFn("\037\233\232\164\191\141\125"), function() markFn : SetTextColor(1, 1, 1) end)
return hdrPt end local function bdObj() local laneFn = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101"),
UIParent) laneFn : SetSize(hdrKey, laneBuf) laneFn : SetFrameStrata(ttSeedFn("\046\206\229\141\145\188")) laneFn : SetClampedToScreen(true)
laneFn : SetMovable(true) laneFn : EnableMouse(true) laneFn : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001")) laneFn :
SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"), function(cellBuf) cellBuf : StartMoving() end) laneFn : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"),
function(cellBuf) cellBuf : StopMovingOrSizing() fxFn() end) laneFn : Hide() local gtOfs = CreateFrame(ttSeedFn("\040\242\208\181\177\149"),
nil, laneFn) gtOfs : SetSize(bdSz, bdSz) gtOfs . texture = gtOfs : CreateTexture(nil, ttSeedFn("\043\213\240\150\145\169\083")) gtOfs .
texture : SetAllPoints() gtOfs : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001")) gtOfs : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"),
function() laneFn : StartMoving() end) gtOfs : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"), function() laneFn :
StopMovingOrSizing() fxFn() end) local tipVal = anchorKey(laneFn) tipVal : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function()
laneFn : Hide() edgeBuf() end) local gtPt = CreateFrame(ttSeedFn("\044\245\197\172\187"), nil, laneFn, ttSeedFn("\040\230\199\170\186\137\119\069\006\010\225\217\170\130\116\120"))
gtPt : SetSize(ttRef, padTmp) if gtPt . SetBackdrop then gtPt : SetBackdrop({bgFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\206\220\178\151\111\115\073\011\035\217\231\159\173\061\122\007"),
edgeFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\216\198\169\143\116\116\074\036\040\196\231\230\188\106\077\083\040\016\230\158\146\130\120\067\033\019"),
tile = false, edgeSize = bdLvl, insets = {left = 4, right = 4, top = 4, bottom = 4},}) gtPt : SetBackdropColor(1, 1, 1, 1) gtPt :
SetBackdropBorderColor(0.15, 0.15, 0.15, 1) end local tipLvl = _G . ChatBubbleFont and ttSeedFn("\041\239\197\181\156\142\122\087\062\010\202\198\168\151")
or ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143") local anchorObj = gtPt : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"),
tipLvl) anchorObj : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), gtPt, ttSeedFn("\062\200\244\141\155\189\076"), cellRef, - cellRef)
anchorObj : SetWidth(ttRef - 2 * cellRef) anchorObj : SetJustifyH(ttSeedFn("\038\194\226\149")) anchorObj : SetJustifyV(ttSeedFn("\062\200\244"))
anchorObj : SetTextColor(0, 0, 0) local laneOfs = gtPt : CreateTexture(nil, ttSeedFn("\037\209\225\147\146\186\065"), nil, 2) laneOfs :
SetTexture(ttSeedFn("\035\233\208\164\172\157\121\086\055\051\216\198\169\143\116\116\074\036\040\210\198\170\156\071\087\093\062\021\243\158\132\140\099\075"))
laneOfs : SetVertexColor(1, 1, 1, 1) laneOfs : SetSize(cellPt, cellPt) return laneFn, gtOfs, tipVal, gtPt, anchorObj, laneOfs end local
function ttSeq() if tabObj then return tabObj end local padIdx, laneFn, gtOfs, tipVal, gtPt, anchorObj, laneOfs = pcall(bdObj) if not padIdx
then tabLvl(ttSeedFn("\009\232\209\173\186\149\063\065\114\013\249\192\170\135\032\105\082\050\084\247\220\170\133\096\024\031") .. tostring(laneFn))
local padLvl = rawget(_G, ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101")) if padLvl and padLvl . Hide then pcall(padLvl
. Hide, padLvl) end return nil end tabObj, anchorIdx, cellKey, gtMod, bdBuf, rowOfs = laneFn, gtOfs, tipVal, gtPt, anchorObj, laneOfs return
tabObj end local function tipSeq(gtIdx, tabKey, fxLvl, tipKey, tabTmp, slotSz) local padMod = type(gtIdx) == ttSeedFn("\025\243\214\168\176\156")
and ttFn [ gtIdx] if not padMod then return false end if not ttSeq() then return false end bdMod = fxLvl anchorIdx . texture : SetTexture(padMod)
edgeVal(tipKey and true or false) local edgeMod = markCfg(tabKey) skinOfs = edgeMod ~= nil if edgeMod then bdBuf : SetText(edgeMod) end
rowTmp() if tabTmp and slotSz then laneCfg(tabTmp, slotSz) else fxSeq() end tabObj : Show() return true end local function cellMod(hdrLvl)
if not ttSeq() then return end anchorPt = true bdMod = nil anchorIdx . texture : SetTexture(ttFn [ hdrLvl] or ttFn . normal) edgeVal(false)
skinOfs = false rowTmp() local hdrSz = gtSz() if hdrSz then laneCfg(hdrSz . fracX, hdrSz . fracY) else fxSeq() end tabObj : Show() end local
function anchorSeq() if tabObj then local laneRef, edgeLvl = tabObj : GetCenter() if laneRef and edgeLvl then local bdCache, laneObj =
UIParent : GetWidth(), UIParent : GetHeight() rowVal(laneRef / bdCache, edgeLvl / laneObj) end tabObj : Hide() end anchorPt = false end
local function hdrBuf(cellOfs) local gtBuf = Ambiguate and Ambiguate(cellOfs, ttSeedFn("\004\232\202\164")) or cellOfs local markRef =
cellOfs : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"), ttSeedFn("")) local laneMod = gtBuf : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn("")) local tabRef = slotTmp(cellOfs) for _, markLvl in ipairs(gtSeq) do local ttSz = markLvl : lower() : gsub(ttSeedFn("\049\162\215\228\243\166"),
ttSeedFn("")) if ttSz == markRef or ttSz == laneMod or ttSz == tabRef then return true end end return false end local skinLvl = - math .
huge local function skinSeq(gtKey, edgeMod, rowSz, cellOfs) if ttCfg(gtKey) or ttCfg(edgeMod) or ttCfg(cellOfs) then laneLvl(ttSeedFn("\014\245\203\177\174\158\124\021\051\079\225\204\181\144\097\122\095\119\003\248\218\163\200\118\071\092\046\028\226\147\166\140\102\082\033\018\080"))
return end if gtKey ~= bdRef then return end if type(edgeMod) ~= ttSeedFn("\025\243\214\168\176\156") or type(cellOfs) ~= ttSeedFn("\025\243\214\168\176\156")
then return end laneLvl(ttSeedFn("\024\226\199\164\183\141\125\081\114\072") .. edgeMod .. ttSeedFn("\077\167\194\179\177\150\056") ..
cellOfs .. ttSeedFn("\074\241\205\160\254") .. tostring(rowSz)) if edgeMod : sub(1, # anchorOfs) == anchorOfs then local rowIdx, edgeSz =
hdrVal(cellOfs), slotTmp(cellOfs) local skinVal = cellTmp [ rowIdx] or cellTmp [ edgeSz] if skinVal and GetTime() - skinVal <= ttVal then
cellTmp [ rowIdx] = nil cellTmp [ edgeSz] = nil tabLvl(((Ambiguate and Ambiguate(cellOfs, ttSeedFn("\025\239\203\179\170"))) or cellOfs) ..
ttSeedFn("\074\228\200\174\173\158\124\021\017\003\229\217\182\154\046")) else local hdrCache = {} for slotCache in pairs(cellTmp) do
hdrCache [ # hdrCache + 1] = slotCache end laneLvl(ttSeedFn("\024\226\212\173\167\219\113\082\060\000\254\204\162\217\032\115\085\119\006\244\205\174\134\113\002\076\057\023\242\147\162\136\105\072\054\005\027\255\152\179\157\125\012\110")
.. rowIdx .. ttSeedFn("\077\167\140\179\187\152\119\071\054\010\232\147\230") .. table . concat(hdrCache, ttSeedFn("\070\167")) .. ttSeedFn("\067\169"))
end return end if padCache() then laneLvl(ttSeedFn("\003\224\202\174\172\158\124\015\114\022\227\220\230\130\114\120\026\056\004\229\203\175\200\106\087\075\114"))
return end if not hdrBuf(cellOfs) then laneLvl(ttSeedFn("\003\224\202\174\172\158\124\015\114\072") .. cellOfs .. ttSeedFn("\077\167\205\178\254\149\119\065\114\006\226\137\135\175\076\082\109\018\048\206\253\142\166\065\103\109\015\087"))
return end local gtIdx, bdKey, rowCache, fxIdx, tabSeq, bdOfs = edgeMod : match(ttSeedFn("\052") .. rowPt .. ttSeedFn("\066\162\197\234\247\193\048\110\119\014\169\132\155\202\040\070\031\054\081\188\243\226\210\045\007\091\118\080\172\155\245\137\032\014\126\073\080\177\145\241"))
if not gtIdx then laneLvl(ttSeedFn("\003\224\202\174\172\158\124\015\114\002\233\218\181\130\103\120\026\051\027\244\221\165\207\113\002\082\061\013\245\219\240\153\098\066\100\004\006\235\221\182\134\106\072\105\000\236\210\208\187\131\058"))
return end if bdOfs == ttSeedFn("") then bdOfs = nil end local tipKey = bdKey == ttSeedFn("\039") local tabTmp, slotSz if rowCache ==
ttSeedFn("\058") then tabTmp, slotSz = cellLvl(fxIdx), cellLvl(tabSeq) end local skinFn = GetTime() if skinFn - skinLvl < tabSz then laneLvl(ttSeedFn("\003\224\202\174\172\158\124\015\114\012\227\198\170\135\111\106\084\119\092")
.. tabSz .. ttSeedFn("\025\174\132\178\170\146\116\089\114\029\249\199\168\138\110\122\020")) return end if tipSeq(gtIdx : lower(), bdOfs,
cellOfs, tipKey, tabTmp, slotSz) then skinLvl = skinFn laneLvl(ttSeedFn("\025\239\203\182\183\149\127\021\055\001\248\219\191\205")) else
laneLvl(ttSeedFn("\003\224\202\174\172\158\124\015\114\026\226\194\168\140\119\115\026\039\027\226\203\235\207") .. gtIdx .. ttSeedFn("\077\167\203\179\254\143\112\080\114\009\254\200\171\134\032\123\091\062\024\244\202\235\156\106\002\093\041\016\250\215\254"))
end end local skinBuf = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\219\169\129\101\088\076\050\026\229\221"))
pcall(skinBuf . RegisterEvent, skinBuf, ttSeedFn("\041\207\229\149\129\182\075\114\013\046\200\237\137\173")) skinBuf : SetScript(ttSeedFn("\037\233\225\183\187\149\108"),
function(_, gtCfg, ...) if gtCfg == ttSeedFn("\041\207\229\149\129\182\075\114\013\046\200\237\137\173") then skinSeq(...) end end) if
C_ChatInfo and C_ChatInfo . RegisterAddonMessagePrefix then pcall(C_ChatInfo . RegisterAddonMessagePrefix, bdRef) end local function
anchorCache(tipPt, gtIdx, slotKey, tipKey, tabTmp, slotSz) if not tipPt or tipPt == ttSeedFn("") then tabLvl(ttSeedFn("\009\239\203\174\173\158\056\084\114\031\224\200\191\134\114\061\078\056\084\226\203\165\140\037\086\080\114"))
return end gtIdx =(gtIdx or ttSeedFn("")) : lower() if not ttFn [ gtIdx] then tabLvl(ttSeedFn("\031\233\207\175\177\140\118\021\034\000\255\204\232\195\084\111\067\109\084")
.. gtCache) return end local bdOfs = markCfg(slotKey) if slotKey and slotKey ~= ttSeedFn("") and not bdOfs then tabLvl(ttSeedFn("\030\239\197\181\254\143\125\077\038\079\251\200\181\195\101\112\074\035\013\177\207\173\156\096\080\031\063\021\243\210\190\132\100\064\127\065\013\254\214\177\155\097\075\105\017\234\212\213\181\130\096\017\039\031\166"))
end if ttPt() then tabLvl(ttSeedFn("\009\230\202\230\170\219\107\080\060\011\172\219\175\132\104\105\026\057\027\230\142\227\139\109\067\075\124\020\243\192\163\140\109\078\042\006\094\242\203\245\158\096\079\034\003\231\128\217\181\128\122\024\096"))
return end local fxObj =(C_ChatInfo and C_ChatInfo . SendAddonMessage) or _G . SendAddonMessage if not fxObj then tabLvl(ttSeedFn("\030\239\205\178\254\152\116\092\055\001\248\137\174\130\115\061\084\056\084\194\203\165\140\068\070\091\051\023\219\214\163\158\107\064\033\079"))
return end local slotLvl = markSeq(gtIdx, tipKey, tabTmp, slotSz, bdOfs) local padIdx, ttObj = pcall(fxObj, bdRef, slotLvl, ttSeedFn("\061\207\237\146\142\190\074"),
tipPt) if not padIdx then tabLvl(ttSeedFn("\025\226\202\165\254\157\121\092\062\010\232\147\230") .. tostring(ttObj)) return end laneLvl(ttSeedFn("\057\226\202\165\159\159\124\090\060\034\233\218\181\130\103\120\026\037\017\229\219\185\134\096\070\031")
.. tostring(ttObj)) local edgeObj = Enum and Enum . SendAddonMessageResult local markSz = ttObj == nil or ttObj == true or ttObj == 0 or(edgeObj
and ttObj == edgeObj . Success) if markSz then local skinCfg = GetTime() cellTmp [ hdrVal(tipPt)] = skinCfg cellTmp [ slotTmp(tipPt)] =
skinCfg tabLvl(ttSeedFn("\025\226\202\181\254\143\119\021") .. tipPt .. ttSeedFn("\068")) else tabLvl(ttSeedFn("\004\232\208\225\173\158\118\065\114\071\254\204\181\150\108\105\026\052\027\245\203\235")
.. tostring(ttObj) .. ttSeedFn("\074\170\137\225\170\147\106\090\038\027\224\204\162\195\111\111\026\037\017\226\218\185\129\102\086\090\056\070\191\157"))
end end local bdCfg, ttLvl, skinKey, tabMod, skinMod, laneVal, tipTmp local rowSeq, laneSeq = rowObj [ 1], nil local function tipFn() if not
tipTmp then return end local hdrSz = gtSz() if anchorPt then tipTmp : SetText(ttSeedFn("\046\245\197\166\254\184\116\092\034\031\245\133\230\151\104\120\084\119\004\227\203\184\155\037\097\080\050\031\255\193\189\195"))
elseif hdrSz then tipTmp : SetText(ttSeedFn("\058\232\215\168\170\146\119\091\104\079\239\220\181\151\111\112\026\036\004\254\218")) else
tipTmp : SetText(ttSeedFn("\058\232\215\168\170\146\119\091\104\079\232\204\160\130\117\113\078\119\007\225\193\191")) end if laneVal then
laneVal : SetText(anchorPt and ttSeedFn("\041\232\202\167\183\137\117\021\002\000\255\192\178\138\111\115") or ttSeedFn("\058\235\197\162\187\219\091\089\059\031\252\208"))
end end local function padSz() local laneFn = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\192\165\136\101\111"),
UIParent, ttSeedFn("\040\230\199\170\186\137\119\069\006\010\225\217\170\130\116\120")) laneFn : SetSize(300, 300) laneFn : SetPoint(ttSeedFn("\041\194\234\149\155\169"))
laneFn : SetFrameStrata(ttSeedFn("\046\206\229\141\145\188")) laneFn : SetMovable(true) laneFn : EnableMouse(true) laneFn : RegisterForDrag(ttSeedFn("\038\226\194\181\156\142\108\065\061\001"))
laneFn : SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\051\029\248"), function(cellBuf) cellBuf : StartMoving() end) laneFn :
SetScript(ttSeedFn("\037\233\224\179\191\156\075\065\061\031"), function(cellBuf) cellBuf : StopMovingOrSizing() end) if laneFn .
SetBackdrop then laneFn : SetBackdrop({bgFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\200\192\167\143\111\122\124\037\021\252\203\151\189\076\015\123\053\024\250\220\183\175\101\095\105\035\031\248\211\178\128\096\089\039\002"),
edgeFile = ttSeedFn("\035\233\208\164\172\157\121\086\055\051\200\192\167\143\111\122\124\037\021\252\203\151\189\076\015\123\053\024\250\220\183\175\101\095\105\035\017\233\220\176\128"),
tile = true, tileSize = 32, edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11},}) end local bdPt = laneFn :
CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143\076\124\072\048\017"))
bdPt : SetPoint(ttSeedFn("\062\200\244"), laneFn, ttSeedFn("\062\200\244"), 0, - 16) bdPt : SetText(ttSeedFn("\057\226\202\165\254\184\116\092\034\031\245"))
local laneKey = anchorKey(laneFn) laneKey : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"), laneFn, ttSeedFn("\062\200\244\147\151\188\080\097"),
- 2, - 2) laneKey : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() laneFn : Hide() end) ttLvl = {} for fxOfs, gtIdx in
ipairs(rowObj) do local edgeRef = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, laneFn) edgeRef : SetSize(40, 40) edgeRef :
SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneFn, ttSeedFn("\062\200\244\141\155\189\076"), 14 +(fxOfs - 1) * 46, - 44) edgeRef .
texture = edgeRef : CreateTexture(nil, ttSeedFn("\043\213\240\150\145\169\083")) edgeRef . texture : SetAllPoints() edgeRef . texture :
SetTexture(ttFn [ gtIdx]) edgeRef . ring = CreateFrame(ttSeedFn("\044\245\197\172\187"), nil, edgeRef) edgeRef . ring : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
edgeRef, ttSeedFn("\062\200\244\141\155\189\076"), - 2, 2) edgeRef . ring : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
edgeRef, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), 2, - 2) for _, rowCfg in ipairs({ttSeedFn("\062\200\244"), ttSeedFn("\040\200\240\149\145\182"),
ttSeedFn("\038\194\226\149"), ttSeedFn("\056\206\227\137\138")}) do local markCache = edgeRef . ring : CreateTexture(nil, ttSeedFn("\037\209\225\147\146\186\065"))
markCache : SetColorTexture(1, 0.82, 0, 1) if rowCfg == ttSeedFn("\062\200\244") then markCache : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
edgeRef . ring, ttSeedFn("\062\200\244\141\155\189\076"), 0, 0) markCache : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"), edgeRef .
ring, ttSeedFn("\062\200\244\147\151\188\080\097"), 0, 0) markCache : SetHeight(2) elseif rowCfg == ttSeedFn("\040\200\240\149\145\182")
then markCache : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), edgeRef . ring, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
0, 0) markCache : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), edgeRef . ring, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
0, 0) markCache : SetHeight(2) elseif rowCfg == ttSeedFn("\038\194\226\149") then markCache : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
edgeRef . ring, ttSeedFn("\062\200\244\141\155\189\076"), 0, 0) markCache : SetPoint(ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
edgeRef . ring, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), 0, 0) markCache : SetWidth(2) else markCache : SetPoint(ttSeedFn("\062\200\244\147\151\188\080\097"),
edgeRef . ring, ttSeedFn("\062\200\244\147\151\188\080\097"), 0, 0) markCache : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
edgeRef . ring, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), 0, 0) markCache : SetWidth(2) end end edgeRef . ring : Hide()
edgeRef : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() rowSeq = gtIdx for _, padRef in ipairs(ttLvl) do padRef . ring :
Hide() end edgeRef . ring : Show() if anchorPt then anchorIdx . texture : SetTexture(ttFn [ gtIdx]) end end) if gtIdx == rowSeq then edgeRef
. ring : Show() end ttLvl [ # ttLvl + 1] = edgeRef end skinKey = CreateFrame(ttSeedFn("\044\245\197\172\187"), ttSeedFn("\033\210\237\149\183\139\075\094\059\001\220\192\165\136\101\111\110\054\006\246\203\191\172\119\077\079\056\022\225\221"),
laneFn, ttSeedFn("\063\206\224\179\177\139\092\090\037\001\193\204\168\150\084\120\087\039\024\240\218\174")) skinKey : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"),
laneFn, ttSeedFn("\062\200\244\141\155\189\076"), - 14, - 96) if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(skinKey, 180) end if
UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(skinKey, function() for _, tipPt in ipairs(gtSeq) do local edgeOfs =
UIDropDownMenu_CreateInfo() edgeOfs . text = tipPt edgeOfs . func = function() laneSeq = tipPt UIDropDownMenu_SetText(skinKey, tipPt) end
UIDropDownMenu_AddButton(edgeOfs) end end) end if UIDropDownMenu_SetText then UIDropDownMenu_SetText(skinKey, ttSeedFn("\041\239\203\174\173\158\056\084\114\031\224\200\191\134\114"))
end local skinSz = laneFn : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\028\000\254\196\167\143\083\112\091\059\024"))
skinSz : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneFn, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 136) skinSz : SetText(ttSeedFn("\039\226\215\178\191\156\125\021\122\000\252\221\175\140\110\124\086\126\078"))
tabMod = CreateFrame(ttSeedFn("\047\227\205\181\156\148\096"), nil, laneFn, ttSeedFn("\035\233\212\180\170\185\119\077\006\010\225\217\170\130\116\120"))
tabMod : SetSize(252, 20) tabMod : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneFn, ttSeedFn("\062\200\244\141\155\189\076"), 24,
- 152) tabMod : SetAutoFocus(false) tabMod : SetScript(ttSeedFn("\037\233\225\178\189\154\104\080\002\029\233\218\181\134\100"), function(cellBuf)
cellBuf : ClearFocus() end) tabMod : SetScript(ttSeedFn("\037\233\225\175\170\158\106\101\032\010\255\218\163\135"), function(cellBuf)
cellBuf : ClearFocus() end) skinMod = CreateFrame(ttSeedFn("\041\239\193\162\181\185\109\065\038\000\226"), nil, laneFn, ttSeedFn("\063\206\231\169\187\152\115\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
skinMod : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneFn, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 182) if skinMod . Text
then skinMod . Text : SetText(ttSeedFn("\039\238\214\179\177\137\056\118\062\006\252\217\191")) end laneVal = CreateFrame(ttSeedFn("\040\242\208\181\177\149"),
nil, laneFn, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203")) laneVal : SetSize(128, 22)
laneVal : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneFn, ttSeedFn("\062\200\244\141\155\189\076"), 20, - 210) laneVal : SetText(ttSeedFn("\058\235\197\162\187\219\091\089\059\031\252\208"))
laneVal : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() if anchorPt then anchorSeq() else cellMod(rowSeq) end tipFn() end)
local lanePt = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, laneFn, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
lanePt : SetSize(128, 22) lanePt : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), laneVal, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"),
0, - 6) lanePt : SetText(ttSeedFn("\063\244\193\225\154\158\126\084\039\003\248\137\149\147\111\105")) lanePt : SetScript(ttSeedFn("\037\233\231\173\183\152\115"),
function() padFn() if anchorPt then anchorPt = false if tabObj then tabObj : Hide() end end tipFn() tabLvl(ttSeedFn("\026\235\197\162\187\150\125\091\038\079\254\204\181\134\116\061\078\056\084\229\198\174\200\097\071\089\061\012\250\199\240\158\122\072\048\079"))
end) tipTmp = laneFn : CreateFontString(nil, ttSeedFn("\037\209\225\147\146\186\065"), ttSeedFn("\045\230\201\164\152\148\118\065\022\006\255\200\164\143\101\078\087\054\024\253"))
tipTmp : SetPoint(ttSeedFn("\062\200\244\141\155\189\076"), lanePt, ttSeedFn("\040\200\240\149\145\182\084\112\020\059"), 0, - 8) tipTmp :
SetPoint(ttSeedFn("\056\206\227\137\138"), laneFn, ttSeedFn("\056\206\227\137\138"), - 16, 0) tipTmp : SetJustifyH(ttSeedFn("\038\194\226\149"))
local slotRef = CreateFrame(ttSeedFn("\040\242\208\181\177\149"), nil, laneFn, ttSeedFn("\063\206\244\160\176\158\116\119\039\027\248\198\168\183\101\112\074\059\021\229\203"))
slotRef : SetSize(100, 24) slotRef : SetPoint(ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"), laneFn, ttSeedFn("\040\200\240\149\145\182\074\124\021\039\216"),
- 16, 16) slotRef : SetText(ttSeedFn("\057\226\202\165")) slotRef : SetScript(ttSeedFn("\037\233\231\173\183\152\115"), function() if not
rowSeq then tabLvl(ttSeedFn("\026\238\199\170\254\154\056\118\062\006\252\217\191\195\102\116\072\036\000\191")) return end local edgeMod =
tabMod : GetText() local hdrSz = gtSz() anchorCache(laneSeq, rowSeq, edgeMod, skinMod : GetChecked() and true or false, hdrSz and hdrSz .
fracX, hdrSz and hdrSz . fracY) tabMod : SetText(ttSeedFn("")) end) return laneFn end local function padCfg() if bdCfg then return bdCfg end
local padIdx, laneFn = pcall(padSz) if not padIdx then tabLvl(ttSeedFn("\009\232\209\173\186\149\063\065\114\013\249\192\170\135\032\105\082\050\084\226\203\165\140\037\085\086\050\029\249\196\234\205")
.. tostring(laneFn)) return nil end bdCfg = laneFn return bdCfg end local function bdSeq() local hdrOfs = padCfg() if not hdrOfs then return
end tipFn() hdrOfs : Show() end _G [ ttSeedFn("\057\203\229\146\150\164\083\096\027\059\197\249\149\168\073\083\123\102")] = ttSeedFn("\069\236\200\168\174\158\117")
SlashCmdList [ ttSeedFn("\033\210\237\149\151\171\075\126\027\033\205")] = function(slotLvl) slotLvl = slotLvl or ttSeedFn("") if slotLvl :
lower() : match(ttSeedFn("\052\162\215\235\186\158\122\064\053\074\255\131\226")) then ttBuf = not ttBuf tabLvl(ttSeedFn("\014\226\198\180\185\219")
..(ttBuf and ttSeedFn("\005\233") or ttSeedFn("\005\225\194")) .. ttSeedFn("\068")) return end if slotLvl : match(ttSeedFn("\052\162\215\235\250"))
then bdSeq() return end local tipPt, gtIdx, tipSz = slotLvl : match(ttSeedFn("\052\162\215\235\246\222\075\030\123\074\255\130\238\198\083\054\019\114\007\187\134\229\197\044\007\076\118\093"))
if not tipPt then tabLvl(ttSeedFn("\031\244\197\166\187\193\056\026\057\003\229\217\163\142\032\105\085\119\027\225\203\165\200\113\074\090\124\009\255\208\187\136\120\011\100\014\012\187\151\190\158\102\092\044\011\163\156\243\187\154\113\028\028\014\233\201\175\225\220\037\070\060\003\232\148\231\191\117\123\067\044\040\178\143\236\153\105\080\037\046\064\183")
.. gtCache) return end anchorCache(tipPt, gtIdx, tipSz) end _G [ ttSeedFn("\057\203\229\146\150\164\083\096\027\059\197\249\149\168\073\083\120\102")]
= ttSeedFn("\069\232\201\166\174\151\125\084\033\010\224\204\167\149\101\112\095\054\024\254\192\174\139\105\075\079\044\000") SlashCmdList
[ ttSeedFn("\033\210\237\149\151\171\075\126\027\033\206")] = function() rowKey(not padCache()) if padCache() then if tabObj then tabObj :
Hide() end tabLvl(ttSeedFn("\041\235\205\177\174\130\056\093\051\028\172\203\163\134\110\061\088\054\026\248\221\163\141\097\012\031\014\012\248\147\164\133\111\007\039\014\019\246\217\187\150\047\077\046\007\234\206\157\174\152\052\083\060\002\230\194\226\183\149\116\022\049\017\238\193\233"))
else tabLvl(ttSeedFn("\041\235\205\177\174\130\056\092\033\079\238\200\165\136\046\061\115\035\084\253\193\164\131\118\002\083\053\018\243\147\169\130\127\000\054\004\094\239\202\172\155\097\075\105\018\236\128\223\191\215\124\080\062\027\241\139\226\136\147\108\090\055\080\244\197\178\196\109\119\080\061\085\250\202\160\153\038\084\041\041\018\183\192\185\143\127\023"))
end end
