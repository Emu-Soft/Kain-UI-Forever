local _, KUI = ...

local BRIGHTNESS_CVARS = { "Brightness" }
local CONTRAST_CVARS = { "Contrast" }

local CONTRAST_VALUE = "100"
local BRIGHTNESS_VALUE = "60"

local scanLines = { "Contrast hasn't been turned on yet this session -- check the box, then run this again." }
local function ResetScan() scanLines = {} end
local function Note(fmt, ...) table.insert(scanLines, string.format(fmt, ...)) end

function KUI:ContrastScanReport()
	print("|cff33ff99Kain-UI Forever|r contrast scan:")
	for _, line in ipairs(scanLines) do
		print("  " .. line)
	end
end

local function FindExistingCVar(candidates)
	for _, name in ipairs(candidates) do
		local ok, value = pcall(GetCVar, name)
		if ok and value ~= nil then
			return name
		end
	end
	return nil
end

function KUI:IsContrastAtRecommendedValues()
	local brightnessCVar = FindExistingCVar(BRIGHTNESS_CVARS)
	local contrastCVar = FindExistingCVar(CONTRAST_CVARS)
	if not brightnessCVar or not contrastCVar then return false end

	local okB, brightness = pcall(GetCVar, brightnessCVar)
	local okC, contrast = pcall(GetCVar, contrastCVar)
	if not okB or not okC then return false end

	return tostring(brightness) == BRIGHTNESS_VALUE and tostring(contrast) == CONTRAST_VALUE
end

local function CaptureOriginalValues()
	local saved = {}
	local brightnessCVar = FindExistingCVar(BRIGHTNESS_CVARS)
	if brightnessCVar then
		local ok, value = pcall(GetCVar, brightnessCVar)
		if ok then
			saved.brightnessCVar = brightnessCVar
			saved.brightnessValue = value
		end
	end
	local contrastCVar = FindExistingCVar(CONTRAST_CVARS)
	if contrastCVar then
		local ok, value = pcall(GetCVar, contrastCVar)
		if ok then
			saved.contrastCVar = contrastCVar
			saved.contrastValue = value
		end
	end
	return saved
end

function KUI:RestoreContrast()
	if not KUI.db then return end
	ResetScan()
	local saved = KUI.db.contrastSavedValues
	if not saved then
		Note("nothing to restore -- Contrast hasn't been turned on this session, so no original values were ever captured.")
		return
	end

	if saved.brightnessCVar and saved.brightnessValue ~= nil then
		local ok, err = pcall(SetCVar, saved.brightnessCVar, saved.brightnessValue)
		Note("brightness (%s): %s", saved.brightnessCVar, ok and ("restored to " .. tostring(saved.brightnessValue)) or ("failed: " .. tostring(err)))
	end
	if saved.contrastCVar and saved.contrastValue ~= nil then
		local ok, err = pcall(SetCVar, saved.contrastCVar, saved.contrastValue)
		Note("contrast (%s): %s", saved.contrastCVar, ok and ("restored to " .. tostring(saved.contrastValue)) or ("failed: " .. tostring(err)))
	end

	KUI.db.contrastSavedValues = nil
	KUI.db.contrastEnabled = false
end

function KUI:SetContrastEnabled(enabled)
	if not KUI.db then return end
	ResetScan()

	if not enabled then
		KUI:RestoreContrast()
		return
	end

	if not KUI.db.contrastSavedValues then
		KUI.db.contrastSavedValues = CaptureOriginalValues()
	end

	local saved = KUI.db.contrastSavedValues
	if saved.brightnessCVar then
		local ok, err = pcall(SetCVar, saved.brightnessCVar, BRIGHTNESS_VALUE)
		Note("brightness (%s): %s", saved.brightnessCVar, ok and "set to 60%" or ("failed: " .. tostring(err)))
	else
		Note("no brightness CVar found on this client (tried: %s).", table.concat(BRIGHTNESS_CVARS, ", "))
	end
	if saved.contrastCVar then
		local ok, err = pcall(SetCVar, saved.contrastCVar, CONTRAST_VALUE)
		Note("contrast (%s): %s", saved.contrastCVar, ok and "set to 100%" or ("failed: " .. tostring(err)))
	else
		Note("no contrast CVar found on this client (tried: %s) -- brightness alone still applied above, if found.", table.concat(CONTRAST_CVARS, ", "))
	end

	KUI.db.contrastEnabled = true
end

function KUI:ApplyContrast()
	if not KUI.db then return end
	if KUI.db.contrastEnabled then

		KUI:SetContrastEnabled(true)
	end
end
