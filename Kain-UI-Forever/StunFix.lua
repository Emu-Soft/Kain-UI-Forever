local _, KUI = ...

local AURAS_FRAME_LEVEL = 100

local CC_CHILD_KEYS = { "LossOfControlFrame", "CrowdControlListFrame" }

local hooked = setmetatable({}, { __mode = "k" })
local conforming = setmetatable({}, { __mode = "k" })

local function SafeSize(frame)
	if not (frame and frame.GetSize) then return end
	local ok, w, h = pcall(frame.GetSize, frame)
	if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
		return w, h
	end
end

local function FillParent(parent, depth)
	if depth > 3 then return end
	if parent.GetRegions then
		for _, region in ipairs({ parent:GetRegions() }) do
			if region.IsObjectType and not region:IsObjectType("FontString")
				and region.SetAllPoints then
				region:SetAllPoints(parent)
			end
		end
	end
	if parent.GetChildren then
		for _, child in ipairs({ parent:GetChildren() }) do
			if child.SetAllPoints then
				child:SetAllPoints(parent)
				FillParent(child, depth + 1)
			end
		end
	end
end

local function ConformCC(cc, badge)
	if conforming[cc] then return end
	local w, h = SafeSize(badge)
	if not w then return end
	conforming[cc] = true
	cc:SetSize(w, h)
	if cc.SetClipsChildren then cc:SetClipsChildren(true) end
	cc:ClearAllPoints()
	cc:SetPoint("CENTER", badge, "CENTER", 0, 0)
	FillParent(cc, 1)
	conforming[cc] = nil
end

local function FixAuras(plate)
	local unitFrame = plate and plate.UnitFrame
	local auras = unitFrame and unitFrame.AurasFrame
	local badge = unitFrame and unitFrame.PlayerLevelDiffFrame
	if not (auras and auras.SetFrameLevel and badge) then return end

	auras:SetFrameLevel(AURAS_FRAME_LEVEL)

	local ccFrames = {}
	for _, key in ipairs(CC_CHILD_KEYS) do
		local cc = auras[key]
		if type(cc) == "table" and cc.SetSize then
			ccFrames[#ccFrames + 1] = cc
			ConformCC(cc, badge)
		end
	end

	if not hooked[auras] then
		hooked[auras] = true

		auras:HookScript("OnShow", function(self)
			self:SetFrameLevel(AURAS_FRAME_LEVEL)
			for _, cc in ipairs(ccFrames) do ConformCC(cc, badge) end
		end)
		for _, cc in ipairs(ccFrames) do
			if cc.HookScript then
				cc:HookScript("OnSizeChanged", function(self) ConformCC(self, badge) end)
				cc:HookScript("OnShow", function(self) ConformCC(self, badge) end)
			end
		end
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:SetScript("OnEvent", function(_, _, unit)
	FixAuras(unit and C_NamePlate.GetNamePlateForUnit(unit))
end)

for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
	FixAuras(plate)
end

SLASH_STUNFIX1 = "/stunfix"
SlashCmdList["STUNFIX"] = function(msg)
	if msg ~= "dump" then
		print("|cff66ccffStunFix:|r /stunfix dump")
		return
	end
	local plate = C_NamePlate.GetNamePlateForUnit("target")
	local auras = plate and plate.UnitFrame and plate.UnitFrame.AurasFrame
	if not auras then
		print("|cff66ccffStunFix:|r target an enemy with a nameplate first")
		return
	end
	for k, v in pairs(auras) do
		if type(v) == "table" and v.GetObjectType then
			local ok, t = pcall(v.GetObjectType, v)
			print("|cff66ccffStunFix:|r AurasFrame." .. tostring(k), ok and t or "?")
		end
	end
end
