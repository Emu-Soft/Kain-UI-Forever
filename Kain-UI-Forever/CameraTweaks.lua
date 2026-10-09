local _, KUI = ...

local CVAR = "cameraDistanceMaxZoomFactor"
local BASE_YARDS = 15
local HARD_CAP_YARDS = 50

KUI.CAMERA_ZOOM_MIN = 1.0
KUI.CAMERA_ZOOM_MAX = 3.4
KUI.CAMERA_ZOOM_STEP = 0.1

local function ReadCVar()
	local raw = (C_CVar and C_CVar.GetCVar) and C_CVar.GetCVar(CVAR) or GetCVar(CVAR)
	return tonumber(raw)
end

local function ReadCVarDefault()
	local raw
	if C_CVar and C_CVar.GetCVarDefault then
		raw = C_CVar.GetCVarDefault(CVAR)
	elseif GetCVarDefault then
		raw = GetCVarDefault(CVAR)
	end
	return tonumber(raw) or KUI.CAMERA_ZOOM_MIN
end

local function Snap(factor)
	local step = KUI.CAMERA_ZOOM_STEP
	factor = math.floor(factor / step + 0.5) * step
	if factor < KUI.CAMERA_ZOOM_MIN then factor = KUI.CAMERA_ZOOM_MIN end
	if factor > KUI.CAMERA_ZOOM_MAX then factor = KUI.CAMERA_ZOOM_MAX end
	return factor
end

local function WriteCVar(factor)
	SetCVar(CVAR, format("%.1f", factor))
	return ReadCVar() or factor
end

function KUI:CameraZoomToYards(factor)
	return math.min(factor * BASE_YARDS, HARD_CAP_YARDS)
end

function KUI:GetCameraMaxZoom()
	return ReadCVar() or ReadCVarDefault()
end

function KUI:SetCameraMaxZoom(factor)
	local actual = WriteCVar(Snap(factor))
	self.db.cameraMaxZoomFactor = actual
	return actual
end

function KUI:ResetCameraMaxZoom()
	self.db.cameraMaxZoomFactor = nil
	return WriteCVar(ReadCVarDefault())
end

function KUI:ZoomCameraToMax()
	if CameraZoomOut then pcall(CameraZoomOut, 50) end
end

function KUI:ApplyCameraTweaks()
	local saved = self.db.cameraMaxZoomFactor
	if saved then WriteCVar(Snap(saved)) end
end
