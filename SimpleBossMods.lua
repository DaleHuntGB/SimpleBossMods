-- SimpleBossMods.lua (Core)
-- Shared constants, defaults, and utility helpers.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then
	M = {}
	_G[ADDON_NAME] = M
end

M.Const = M.Const or {}
local C = M.Const

-- Font
C.FONT_PATH = "Interface\\AddOns\\SimpleBossMods\\media\\fonts\\Expressway.ttf"
C.FONT_FLAGS = "OUTLINE" -- or "THICKOUTLINE"

-- Bar texture (flat)
C.BAR_TEX_DEFAULT = "Interface\\TARGETINGFRAME\\UI-StatusBar"

-- Defaults
C.THRESHOLD_TO_BAR = 5.0
C.ICON_ZOOM = 0.10
C.ICONS_PER_ROW = 5
C.BAR_GAP = 6
C.TICK_INTERVAL = 0.20

-- Move everything slightly up (requested)
C.GLOBAL_Y_NUDGE = 0.1

-- Indicators
C.INDICATOR_MAX = 6
C.INDICATOR_MASK = 1023 -- all bits

-- Bars: indicator icons outside to the right
C.BAR_END_INDICATOR_GAP_X = 6

-- Default bar color: #FF9800
C.BAR_FG_R, C.BAR_FG_G, C.BAR_FG_B, C.BAR_FG_A = (255/255), (152/255), (0/255), 1.0
C.BAR_BG_R, C.BAR_BG_G, C.BAR_BG_B, C.BAR_BG_A = 0.0, 0.0, 0.0, 0.80

M.Defaults = M.Defaults or {
	pos = { x = 500, y = 50 },
	cfg = {
		general = { gap = 8 },
		icons = { size = 64, fontSize = 32, borderThickness = 2 },
		bars = {
			width = 352,
			height = 36,
			fontSize = 16,
			borderThickness = 2,
			color = {
				r = C.BAR_FG_R,
				g = C.BAR_FG_G,
				b = C.BAR_FG_B,
				a = C.BAR_FG_A,
			},
		},
		indicators = { iconSize = 10, barSize = 20 },
	},
}

function M:EnsureDefaults()
	SimpleBossModsDB = SimpleBossModsDB or {}
	SimpleBossModsDB.pos = SimpleBossModsDB.pos or { x = M.Defaults.pos.x, y = M.Defaults.pos.y }
	SimpleBossModsDB.cfg = SimpleBossModsDB.cfg or {}

	local cfg = SimpleBossModsDB.cfg
	cfg.general = cfg.general or { gap = M.Defaults.cfg.general.gap }
	cfg.icons = cfg.icons or {
		size = M.Defaults.cfg.icons.size,
		fontSize = M.Defaults.cfg.icons.fontSize,
		borderThickness = M.Defaults.cfg.icons.borderThickness,
	}
	cfg.bars = cfg.bars or {
		width = M.Defaults.cfg.bars.width,
		height = M.Defaults.cfg.bars.height,
		fontSize = M.Defaults.cfg.bars.fontSize,
		borderThickness = M.Defaults.cfg.bars.borderThickness,
	}
	cfg.bars.color = cfg.bars.color or {
		r = M.Defaults.cfg.bars.color.r,
		g = M.Defaults.cfg.bars.color.g,
		b = M.Defaults.cfg.bars.color.b,
		a = M.Defaults.cfg.bars.color.a,
	}
	cfg.indicators = cfg.indicators or {
		iconSize = M.Defaults.cfg.indicators.iconSize,
		barSize = M.Defaults.cfg.indicators.barSize,
	}
end

M.Live = M.Live or {}
local L = M.Live

M.Util = M.Util or {}
local U = M.Util

function U.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function U.round(v)
	v = tonumber(v) or 0
	if v >= 0 then return math.floor(v + 0.5) end
	return math.ceil(v - 0.5)
end

function M.SyncLiveConfig()
	local gc = SimpleBossModsDB.cfg.general
	local ic = SimpleBossModsDB.cfg.icons
	local bc = SimpleBossModsDB.cfg.bars
	local inc = SimpleBossModsDB.cfg.indicators

	L.GAP = tonumber(gc.gap) or 6

	L.ICON_SIZE = ic.size
	L.ICON_FONT_SIZE = ic.fontSize
	L.ICON_BORDER_THICKNESS = ic.borderThickness

	L.BAR_WIDTH = bc.width
	L.BAR_HEIGHT = bc.height
	L.BAR_FONT_SIZE = bc.fontSize
	L.BAR_BORDER_THICKNESS = bc.borderThickness
	local barColor = bc.color or {}
	L.BAR_FG_R = U.clamp(tonumber(barColor.r) or C.BAR_FG_R, 0, 1)
	L.BAR_FG_G = U.clamp(tonumber(barColor.g) or C.BAR_FG_G, 0, 1)
	L.BAR_FG_B = U.clamp(tonumber(barColor.b) or C.BAR_FG_B, 0, 1)
	L.BAR_FG_A = U.clamp(tonumber(barColor.a) or C.BAR_FG_A, 0, 1)

	L.ICON_INDICATOR_SIZE = tonumber(inc.iconSize) or 0
	L.BAR_INDICATOR_SIZE = tonumber(inc.barSize) or 0
end

function U.formatTimeIcon(rem)
	if rem <= 0 then return "" end
	return tostring(math.max(0, math.floor(rem + 0.5))) -- no decimals
end

function U.formatTimeBar(rem)
	if rem >= 10 then
		return tostring(math.floor(rem + 0.5))
	end
	return string.format("%.1f", rem)
end

function U.safeGetIconFileID(eventInfo)
	if type(eventInfo) ~= "table" then return nil end
	local icon = eventInfo.iconFileID or eventInfo.icon
	if icon then return icon end
	if type(eventInfo.spellID) == "number" then
		local ok, iconFileID = pcall(function()
			if C_Spell and C_Spell.GetSpellInfo then
				local info = C_Spell.GetSpellInfo(eventInfo.spellID)
				return info and info.iconID or nil
			end
			if GetSpellInfo then
				local _, _, iconTex = GetSpellInfo(eventInfo.spellID)
				return iconTex
			end
			return nil
		end)
		if ok then return iconFileID end
	end
	return nil
end

function U.safeGetLabel(eventInfo)
	if type(eventInfo) ~= "table" then return "" end
	local label = eventInfo.name or eventInfo.text or eventInfo.title or eventInfo.label
		or eventInfo.spellName or eventInfo.overrideName or ""

	if type(issecretvalue) == "function" and issecretvalue(label) then
		return label
	end

	if label == "" and type(eventInfo.spellID) == "number" then
		local ok, spellName = pcall(function()
			if C_Spell and C_Spell.GetSpellName then
				return C_Spell.GetSpellName(eventInfo.spellID)
			end
			if GetSpellInfo then
				return GetSpellInfo(eventInfo.spellID)
			end
			return nil
		end)
		if ok and type(spellName) == "string" then
			label = spellName
		end
	end

	return label
end

function M:CanUseTimelineScriptEvents()
	return C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function"
end

function M:SafeAddScriptEvent(payload)
	if not (C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function") then
		return nil
	end
	local ok, id = pcall(C_EncounterTimeline.AddScriptEvent, payload)
	if ok then return id end
	ok, id = pcall(C_EncounterTimeline.AddScriptEvent, C_EncounterTimeline, payload)
	if ok then return id end
	return nil
end

function U.barIndicatorSize()
	if L.BAR_INDICATOR_SIZE and L.BAR_INDICATOR_SIZE > 0 then
		return U.clamp(U.round(L.BAR_INDICATOR_SIZE), 8, 32)
	end
	return U.clamp(math.floor(L.BAR_HEIGHT * 0.55 + 0.5), 10, 22)
end

function U.iconIndicatorSize()
	-- inside icon, bottom-right; tiny bit smaller
	if L.ICON_INDICATOR_SIZE and L.ICON_INDICATOR_SIZE > 0 then
		return U.clamp(U.round(L.ICON_INDICATOR_SIZE), 8, 24)
	end
	return U.clamp(math.floor(L.ICON_SIZE * 0.22 + 0.5), 10, 18)
end

M:EnsureDefaults()
M.SyncLiveConfig()

-- =========================
-- State
-- =========================
M.enabled = true
M.events = M.events or {}
M._settingsCategoryName = "SimpleBossMods"
M._settingsCategoryID = nil
M._testTicker = nil
M._testTimelineEventIDs = nil
M._testTimelineEventIDSet = nil
