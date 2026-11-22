local _, KUI = ...

local autoText
local writing

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

local function Enabled()
	return KUI.db and KUI.db.mailAutoSubject ~= false
end

function KUI:FormatMailMoney(copper)
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper / 100) % 100
	local coins = copper % 100
	local parts = {}
	if gold > 0 then parts[#parts + 1] = gold .. "g" end
	if silver > 0 then parts[#parts + 1] = silver .. "s" end
	if coins > 0 then parts[#parts + 1] = coins .. "c" end
	return table.concat(parts, " ")
end

function KUI:GetMailAutoSubject()
	local count, title = 0, nil
	for i = 1, ATTACHMENTS_MAX_SEND or 12 do
		if HasSendMailItem(i) then
			count = count + 1
			if count == 1 then
				local name, _, _, stack = GetSendMailItem(i)
				name, stack = Plain(name), Plain(stack)
				if type(name) == "string" and name ~= "" then
					title = (type(stack) == "number" and stack > 1) and (name .. " (" .. stack .. ")") or name
				end
			end
		end
	end
	if count > 1 then return "Multiple items (" .. count .. ")" end
	if count == 1 then return title end
	local sendMoney = SendMailSendMoneyButton and SendMailSendMoneyButton:GetChecked()
	if sendMoney and SendMailMoney and MoneyInputFrame_GetCopper then
		local copper = Plain(MoneyInputFrame_GetCopper(SendMailMoney))
		if type(copper) == "number" and copper > 0 then return KUI:FormatMailMoney(copper) end
	end
end

local function Refresh()
	local box = SendMailSubjectEditBox
	if writing or not Enabled() or not box then return end
	local current = Plain(box:GetText())
	if type(current) ~= "string" then return end
	local blizzard = SendMailFrame and Plain(SendMailFrame.previousItem)
	local ours = current == "" or current == autoText or (type(blizzard) == "string" and blizzard ~= "" and current == blizzard)
	if not ours then return end
	local want = KUI:GetMailAutoSubject() or ""
	if want ~= current then
		writing = true
		box:SetText(want)
		writing = false
	end
	autoText = want ~= "" and want or nil
end

local function OnSubjectChanged(box, userInput)
	if writing or not userInput then return end

	if Plain(box:GetText()) ~= autoText then autoText = nil end
end

function KUI:SetMailAutoSubject(enabled)
	if not KUI.db then return end
	KUI.db.mailAutoSubject = enabled and true or false

	if enabled then Refresh() else autoText = nil end
end

local hooked
local function HookMail()
	if hooked or type(SendMailFrame_Update) ~= "function" or not SendMailSubjectEditBox then return end
	hooked = true
	hooksecurefunc("SendMailFrame_Update", Refresh)
	if type(SendMailRadioButton_OnClick) == "function" then
		hooksecurefunc("SendMailRadioButton_OnClick", Refresh)
	end
	SendMailSubjectEditBox:HookScript("OnTextChanged", OnSubjectChanged)
	for _, name in ipairs({ "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
		local money = _G[name]
		if money and money.HookScript then money:HookScript("OnTextChanged", Refresh) end
	end
end

HookMail()
if not hooked then
	if EventUtil and EventUtil.ContinueOnAddOnLoaded then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", HookMail)
	else
		local watcher = CreateFrame("Frame")
		watcher:RegisterEvent("ADDON_LOADED")
		watcher:SetScript("OnEvent", function(self, _, name)
			if name == "Blizzard_MailFrame" then
				HookMail()
				self:UnregisterEvent("ADDON_LOADED")
			end
		end)
	end
end
