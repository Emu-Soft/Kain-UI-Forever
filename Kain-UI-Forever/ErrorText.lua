local _, KUI = ...

local EVENT = "UI_ERROR_MESSAGE"
local unregisteredByUs = false

function KUI:ApplyHideErrorText()
	local f = _G.UIErrorsFrame
	if not (f and f.RegisterEvent and f.UnregisterEvent and f.IsEventRegistered) then return end
	local hide = KUI.db and KUI.db.hideErrorText == true
	if hide then
		if not unregisteredByUs and f:IsEventRegistered(EVENT) then
			f:UnregisterEvent(EVENT)
			unregisteredByUs = true
		end
	elseif unregisteredByUs then
		f:RegisterEvent(EVENT)
		unregisteredByUs = false
	end
end

function KUI:SetHideErrorText(enabled)
	if not KUI.db then return end
	KUI.db.hideErrorText = enabled and true or false
	self:ApplyHideErrorText()
end
