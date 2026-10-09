local _, KUI = ...

local function EnsureEditModeLoaded()
	if EditModeManagerFrame and EditModeManagerFrame.Border then return true end
	local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
	if loader then
		pcall(loader, "Blizzard_EditMode")
	end
	return EditModeManagerFrame ~= nil and EditModeManagerFrame.Border ~= nil
end

local function CloneBorderPieces(sourceFrame, bgDest, overlayDest)
	local mapping = { [sourceFrame] = overlayDest }
	local regions = { sourceFrame:GetRegions() }
	local textures = {}
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			textures[#textures + 1] = region
		end
	end

	local clonedCount, bgClonedCount = 0, 0
	local remaining = textures
	local guard = 0
	while #remaining > 0 and guard < 10 do
		guard = guard + 1
		local nextRemaining = {}
		for _, region in ipairs(remaining) do
			local numPoints = region:GetNumPoints()
			local points, resolved = {}, true
			for i = 1, numPoints do
				local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
				local destRelativeTo = mapping[relativeTo]
				if not destRelativeTo and relativeTo == nil then destRelativeTo = overlayDest end
				if destRelativeTo then
					points[i] = { point, destRelativeTo, relativePoint, x, y }
				else
					resolved = false
					break
				end
			end
			if resolved then
				local atlas = region:GetAtlas()
				if atlas then
					local layer, sublevel = region:GetDrawLayer()
					local isBg = (layer == "BACKGROUND")
					local dest = isBg and bgDest or overlayDest
					local tex = dest:CreateTexture(nil, layer or "BORDER", nil, sublevel)

					tex:SetAtlas(atlas, true)
					local w, h = region:GetSize()
					if w and w > 0 and h and h > 0 then tex:SetSize(w, h) end
					for _, p in ipairs(points) do
						tex:SetPoint(p[1], p[2], p[3], p[4], p[5])
					end
					local r, g, b, a = region:GetVertexColor()
					if r then tex:SetVertexColor(r, g, b, a) end
					mapping[region] = tex
					clonedCount = clonedCount + 1
					if isBg then bgClonedCount = bgClonedCount + 1 end
				end
			else
				nextRemaining[#nextRemaining + 1] = region
			end
		end
		if #nextRemaining == #remaining then break end
		remaining = nextRemaining
	end
	return clonedCount, #textures, bgClonedCount
end

function KUI:ApplyDiamondBorder(frame)
	if not frame then return false end
	if frame.kainUIDiamondBorder then return true end
	if KUI.SKIP and KUI.SKIP.border then return false end
	if not EnsureEditModeLoaded() then return false end

	local ok, border = pcall(function() return EditModeManagerFrame.Border end)
	if not ok or not border then return false end

	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetPoint("TOPLEFT", 0, 0)
	overlay:SetPoint("BOTTOMRIGHT", 0, 0)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 5)

	local cloneOk, clonedCount, _, bgClonedCount = pcall(CloneBorderPieces, border, frame, overlay)
	if not cloneOk or not clonedCount or clonedCount == 0 then
		overlay:Hide()
		return false
	end

	if frame.SetBackdrop then
		pcall(frame.SetBackdrop, frame, nil)
	end

	if bgClonedCount == 0 then
		local inset = 8
		for _, tex in ipairs({ overlay:GetRegions() }) do
			if tex.GetObjectType and tex:GetObjectType() == "Texture" then
				local w, h = tex:GetSize()
				local smaller = math.min(w or inset, h or inset)
				if smaller > 0 and smaller < inset then inset = smaller end
			end
		end
		local fallbackBg = frame:CreateTexture(nil, "BACKGROUND")
		fallbackBg:SetTexture("Interface\\Buttons\\WHITE8x8")
		fallbackBg:SetVertexColor(0, 0, 0, 0.85)
		fallbackBg:SetPoint("TOPLEFT", inset, -inset)
		fallbackBg:SetPoint("BOTTOMRIGHT", -inset, inset)
	end

	frame.kainUIDiamondBorder = overlay
	return true
end

function KUI:BorderScanReport()
	print("|cff33ff99Kain-UI Forever|r diamond border scan:")
	local loaded = EnsureEditModeLoaded()
	print("  EditModeManagerFrame.Border found: " .. tostring(loaded))
	if not loaded then
		print("  Can't clone the border on this client build -- affected windows keep their plain border instead.")
		return
	end
	local scratch = CreateFrame("Frame", nil, UIParent)
	scratch:Hide()
	local overlay = CreateFrame("Frame", nil, scratch)
	local ok, clonedCount, totalCount, bgClonedCount = pcall(CloneBorderPieces, EditModeManagerFrame.Border, scratch, overlay)
	if not ok then
		print("  Clone attempt errored: " .. tostring(clonedCount))
		return
	end
	print(("  cloned %d of %d texture piece(s) (%d of them a real background layer)."):format(
		clonedCount or 0, totalCount or 0, bgClonedCount or 0))
	print("  affected windows: /kainui options panel, chat copy-paste popup, weblink copy popup.")
	print("  /kainui and reopen any of those windows to see it (or /reload if one's already open).")
end
