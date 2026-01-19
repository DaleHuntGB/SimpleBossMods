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
		bars = { width = 352, height = 36, fontSize = 16, borderThickness = 2 },
		indicators = { iconSize = 10, barSize = 20 },
	},
	note = "",
}

function M:EnsureDefaults()
	SimpleBossModsDB = SimpleBossModsDB or {}
	SimpleBossModsDB.pos = SimpleBossModsDB.pos or { x = M.Defaults.pos.x, y = M.Defaults.pos.y }
	SimpleBossModsDB.cfg = SimpleBossModsDB.cfg or {}
	SimpleBossModsDB.note = SimpleBossModsDB.note or M.Defaults.note

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
	return type(eventInfo) == "table" and (eventInfo.iconFileID or eventInfo.icon) or nil
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

function U.parseNoteTime(token)
	if type(token) ~= "string" then return nil end
	token = token:gsub("^%s+", ""):gsub("%s+$", "")
	token = token:gsub("^%[", ""):gsub("%]$", "")
	local m, s = token:match("^(%d+):(%d+%.?%d*)$")
	if m and s then
		return (tonumber(m) * 60) + tonumber(s)
	end
	local sec = token:match("^(%d+%.?%d*)[sS]$")
	if sec then return tonumber(sec) end
	local mins = token:match("^(%d+%.?%d*)[mM]$")
	if mins then return tonumber(mins) * 60 end
	local plain = token:match("^(%d+%.?%d*)$")
	if plain then return tonumber(plain) end
	return nil
end

function U.parseNoteLine(line)
	if type(line) ~= "string" then return nil end
	line = line:gsub("^%s+", ""):gsub("%s+$", "")
	if line == "" then return nil end
	if line:match("^#") or line:match("^//") then return nil end

	local t
	local timeTag = line:match("{%s*[Tt][Ii][Mm][Ee]%s*:%s*([^}]+)}")
	if timeTag then
		timeTag = timeTag:gsub("^%s+", ""):gsub("%s+$", "")
		t = U.parseNoteTime(timeTag)
		line = line:gsub("{%s*[Tt][Ii][Mm][Ee]%s*:%s*[^}]+}", " ")
	end

	if not t then
		local token, rest = line:match("^([^%s]+)%s*(.*)$")
		t = U.parseNoteTime(token)
		if not t then return nil end
		line = rest or ""
	end

	line = line:gsub("^[-:]+%s*", "")
	local spellId = line:match("{%s*[Ss][Pp][Ee][Ll][Ll]%s*:%s*(%d+)%s*}")
		or line:match("{%s*[Ii][Dd]%s*:%s*(%d+)%s*}")
		or line:match("[Ss][Pp][Ee][Ll][Ll][Ii]?[Dd]?%s*:%s*(%d+)")
		or line:match("[Ii][Dd]%s*:%s*(%d+)")
	if spellId then
		spellId = tonumber(spellId)
		line = line:gsub("{%s*[Ss][Pp][Ee][Ll][Ll]%s*:%s*%d+%s*}", " ")
		line = line:gsub("{%s*[Ii][Dd]%s*:%s*%d+%s*}", " ")
		line = line:gsub("[Ss][Pp][Ee][Ll][Ll][Ii]?[Dd]?%s*:%s*%d+", " ")
		line = line:gsub("[Ii][Dd]%s*:%s*%d+", " ")
	end

	local rest = line:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

	local spellName, icon
	if spellId then
		if C_Spell and C_Spell.GetSpellInfo then
			local info = C_Spell.GetSpellInfo(spellId)
			if info then
				spellName = info.name
				icon = info.iconID
			end
		elseif GetSpellInfo then
			local name, _, iconTex = GetSpellInfo(spellId)
			spellName = name
			icon = iconTex
		end
	end

	if rest == "" and spellName then
		rest = spellName
	elseif rest == "" and spellId then
		rest = "Spell " .. tostring(spellId)
	end

	return {
		time = t,
		text = rest,
		spellId = spellId,
		icon = icon,
	}
end

function U.parseNote(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for line in text:gmatch("[^\r\n]+") do
		local entry = U.parseNoteLine(line)
		if entry then
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a, b) return a.time < b.time end)
	return out
end

function M:ParseNote()
	local note = (SimpleBossModsDB and SimpleBossModsDB.note) or ""
	if self.ClearNoteEvents then self:ClearNoteEvents() end
	self.noteEntries = U.parseNote(note)
	for i, entry in ipairs(self.noteEntries) do
		entry.id = -(1000000 + i)
	end
	self.noteTimelinePushed = false
	self.noteTimelineEventIDs = nil
end

function M:CanUseTimelineNotes()
	return C_EncounterTimeline and type(C_EncounterTimeline.AddScriptEvent) == "function"
end

function M:ClearTimelineNoteEvents()
	if not (C_EncounterTimeline and type(C_EncounterTimeline.RemoveScriptEvent) == "function") then
		self.noteTimelineEventIDs = nil
		self.noteTimelinePushed = false
		return
	end
	if not self.noteTimelineEventIDs then return end
	for _, id in pairs(self.noteTimelineEventIDs) do
		if id then
			pcall(C_EncounterTimeline.RemoveScriptEvent, id)
		end
	end
	self.noteTimelineEventIDs = nil
	self.noteTimelinePushed = false
end

function M:PushNoteTimelineEvents()
	if not self:CanUseTimelineNotes() then return false end
	if self.noteTimelinePushed then return false end
	if not self.noteEntries or #self.noteEntries == 0 then return false end

	local elapsed = 0
	if self.noteCombatStart then
		elapsed = GetTime() - self.noteCombatStart
		if elapsed < 0 then elapsed = 0 end
	end

	self.noteTimelineEventIDs = {}
	for i, entry in ipairs(self.noteEntries) do
		local remaining = entry.time - elapsed
		if remaining > 0 then
			local payload = {
				duration = remaining,
				spellID = entry.spellId or 12345,
				overrideName = entry.text ~= "" and entry.text or nil,
				iconFileID = entry.icon,
				maxQueueDuration = 0,
			}
			local id = C_EncounterTimeline.AddScriptEvent(payload)
			self.noteTimelineEventIDs[i] = id
		end
	end

	self.noteTimelinePushed = true
	return true
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
M.noteEntries = M.noteEntries or {}
M.noteCombatStart = nil
M.noteEncounterActive = false
M.noteTimelinePushed = false
M.noteTimelineEventIDs = nil
M._settingsCategoryName = "SimpleBossMods"
M._settingsCategoryID = nil
M._settingsNoteCategoryID = nil
M._testTicker = nil
M._testTimelineEventIDs = nil
