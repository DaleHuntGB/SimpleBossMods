-- SimpleBossMods layout and record management.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live
local U = M.Util
local frames = M.frames

-- =========================
-- Layout
-- =========================
local function sortByRemaining(a, b)
	return (a.remaining or 999999) < (b.remaining or 999999)
end

function M:layoutIcons()
	local list = {}
	for _, rec in pairs(self.events) do
		if rec.iconFrame then list[#list + 1] = rec end
	end
	table.sort(list, sortByRemaining)

	local count = #list
	local cols = C.ICONS_PER_ROW
	local rows = (count > 0) and math.ceil(count / cols) or 0

	for i, rec in ipairs(list) do
		local idx = i - 1
		local row = math.floor(idx / cols)
		local col = idx % cols

		local x = col * (L.ICON_SIZE + L.GAP)
		local y = -row * (L.ICON_SIZE + L.GAP)

		local f = rec.iconFrame
		f:SetSize(L.ICON_SIZE, L.ICON_SIZE)
		M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS)

		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", frames.iconsParent, "TOPLEFT", x, y)
	end

	local w = (cols > 0) and (cols * L.ICON_SIZE + (cols - 1) * L.GAP) or 1
	local h = (rows > 0) and (rows * L.ICON_SIZE + (rows - 1) * L.GAP) or 1

	frames.iconsParent:SetSize(w, h)
end

function M:layoutBars()
	local list = {}
	for _, rec in pairs(self.events) do
		if rec.barFrame then list[#list + 1] = rec end
	end
	table.sort(list, sortByRemaining)

	local y = 0
	local maxEndW = 0

	for _, rec in ipairs(list) do
		local f = rec.barFrame
		f:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
		M.ensureFullBorder(f, L.BAR_BORDER_THICKNESS)

		f.leftFrame:SetWidth(L.BAR_HEIGHT)
		f.iconFrame:SetSize(L.BAR_HEIGHT, L.BAR_HEIGHT)
		M.ensureRightDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)

		M.applyBarFont(f.txt)
		M.applyBarFont(f.rt)

		M.applyIndicatorsToBarEnd(f, rec.id)
		if f.endIndicatorsFrame then
			maxEndW = math.max(maxEndW, f.endIndicatorsFrame:GetWidth() or 0)
		end

		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", frames.barsParent, "BOTTOMLEFT", 0, y)
		y = y + L.BAR_HEIGHT + L.GAP
	end

	local h = (#list > 0) and (y - L.GAP) or 1
	local totalW = L.BAR_WIDTH + (maxEndW > 0 and (C.BAR_END_INDICATOR_GAP_X + maxEndW) or 0)
	frames.barsParent:SetSize(totalW, h)
end

function M:LayoutAll()
	-- bars anchored above icon TOP, using shared GAP
	frames.barsParent:ClearAllPoints()
	frames.barsParent:SetPoint("BOTTOMLEFT", frames.iconsParent, "TOPLEFT", 0, L.GAP)

	self:layoutIcons()
	self:layoutBars()
end

-- =========================
-- Core
-- =========================
function M:removeEvent(eventID)
	local rec = self.events[eventID]
	if not rec then return end
	M.releaseIcon(rec.iconFrame)
	M.releaseBar(rec.barFrame)
	self.events[eventID] = nil
end

function M:clearAll()
	for id in pairs(self.events) do
		self:removeEvent(id)
	end
	self:LayoutAll()
end

local function updateRecTiming(rec, remaining)
	local now = GetTime()
	if type(remaining) ~= "number" then return end

	if not rec.duration then
		rec.duration = remaining
		rec.startTime = now
	else
		if remaining > rec.duration then
			rec.duration = remaining
			rec.startTime = now
		else
			rec.startTime = now - (rec.duration - remaining)
		end
	end
end

M._updateRecTiming = updateRecTiming

local function refreshIconTexture(rec)
	local f = rec.iconFrame
	if not f then return end
	local iconFileID = U.safeGetIconFileID(rec.eventInfo)
	if iconFileID then
		f.tex:SetTexture(iconFileID)
		local z = C.ICON_ZOOM
		f.tex:SetTexCoord(z, 1 - z, z, 1 - z)
	end
end

local function refreshBarLabelAndIcon(rec)
	local bar = rec.barFrame
	if not bar then return end

	local label = U.safeGetLabel(rec.eventInfo)
	if type(issecretvalue) == "function" and issecretvalue(label) then
		bar.txt:SetText(label)
	elseif label ~= "" then
		bar.txt:SetText(label)
	end

	local iconFileID = U.safeGetIconFileID(rec.eventInfo)
	if iconFileID then
		bar.icon:SetTexture(iconFileID)
		local z = C.ICON_ZOOM
		bar.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	end
end

function M:ensureIcon(rec)
	if rec.iconFrame then return end
	if rec.barFrame then
		M.releaseBar(rec.barFrame)
		rec.barFrame = nil
	end
	local icon = M.acquireIcon()
	icon.__id = rec.id
	rec.iconFrame = icon

	icon.tex:SetTexture(nil)
	icon.tex:SetTexCoord(0, 1, 0, 1)
	refreshIconTexture(rec)

	M.applyIndicatorsToIconFrame(icon, rec.id)
end

function M:ensureBar(rec)
	if rec.barFrame then return end
	if rec.iconFrame then
		M.releaseIcon(rec.iconFrame)
		rec.iconFrame = nil
	end

	local bar = M.acquireBar()
	bar.__id = rec.id
	rec.barFrame = bar

	bar.txt:SetText("Ability")
	bar.icon:SetTexture(nil)
	bar.icon:SetTexCoord(0, 1, 0, 1)
	refreshBarLabelAndIcon(rec)

	M.applyIndicatorsToBarEnd(bar, rec.id)
	M.setBarFillFlat(bar, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)

	bar:SetScript("OnUpdate", function(self)
		local rrec = M.events[self.__id]
		if not rrec then return end

		local rem = rrec.remaining
		if C_EncounterTimeline and C_EncounterTimeline.GetEventTimeRemaining then
			local ok, v = pcall(C_EncounterTimeline.GetEventTimeRemaining, rrec.id)
			if ok and type(v) == "number" then
				rem = v
				rrec.remaining = v
			end
		end

		if type(rem) ~= "number" then rem = 999 end
		if rem <= 0 then
			M:removeEvent(rrec.id)
			M:LayoutAll()
			return
		end

		local shown = U.clamp(rem, 0, C.THRESHOLD_TO_BAR)
		self.sb:SetValue(shown)
		self.rt:SetText(U.formatTimeBar(shown))
	end)
end

function M:updateRecord(eventID, eventInfo, remaining)
	if not self.enabled then return end
	if type(eventID) ~= "number" then return end

	local rec = self.events[eventID]
	if not rec then
		rec = { id = eventID }
		self.events[eventID] = rec
	end

	rec.eventInfo = eventInfo or rec.eventInfo
	rec.remaining = remaining or rec.remaining

	if type(rec.remaining) == "number" then
		updateRecTiming(rec, rec.remaining)
	end

	if type(rec.remaining) == "number" and rec.remaining <= C.THRESHOLD_TO_BAR then
		self:ensureBar(rec)
	else
		self:ensureIcon(rec)
	end

	if rec.iconFrame then
		local f = rec.iconFrame
		refreshIconTexture(rec)
		local rem = rec.remaining
		if type(rem) == "number" and rem > 0 then
			f.timeText:SetText(U.formatTimeIcon(rem))
			if rec.startTime and rec.duration and rec.duration > 0 then
				f.cd:SetCooldown(rec.startTime, rec.duration)
			end
		else
			f.timeText:SetText("")
			f.cd:Clear()
		end

		if rec.isTest and M.ApplyTestIndicators then
			M:ApplyTestIndicators(f, true)
		else
			M.applyIndicatorsToIconFrame(f, rec.id)
		end
	end

	if rec.barFrame then
		refreshBarLabelAndIcon(rec)
		if rec.isTest and M.ApplyTestIndicators then
			M:ApplyTestIndicators(rec.barFrame, false)
		else
			M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
		end
		M.setBarFillFlat(rec.barFrame, L.BAR_FG_R, L.BAR_FG_G, L.BAR_FG_B, L.BAR_FG_A)
	end
end

-- =========================
-- Timeline refresh
-- =========================
function M:Tick()
	if not self.enabled then return end
	if self._testTicker then return end
	local hasTimeline = C_EncounterTimeline
		and C_EncounterTimeline.HasActiveEvents
		and C_EncounterTimeline.GetEventList
	if not hasTimeline then return end

	if not C_EncounterTimeline.HasActiveEvents() then
		if next(self.events) ~= nil then self:clearAll() end
		return
	end

	local list = C_EncounterTimeline.GetEventList()
	if type(list) ~= "table" then return end

	local seen = {}
	for _, eventID in ipairs(list) do
		seen[eventID] = true
		local rec = self.events[eventID]
		if not rec then
			rec = { id = eventID }
			self.events[eventID] = rec
		end
		rec.isTest = self._testTimelineEventIDSet and self._testTimelineEventIDSet[eventID] or false

		local info = C_EncounterTimeline.GetEventInfo and C_EncounterTimeline.GetEventInfo(eventID) or nil
		local rem = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID) or nil
		self:updateRecord(eventID, info, rem)
	end

	for id in pairs(self.events) do
		if not seen[id] then self:removeEvent(id) end
	end

	-- Keep icon numbers updating smoothly
	for _, rec in pairs(self.events) do
		if rec.iconFrame and C_EncounterTimeline and C_EncounterTimeline.GetEventTimeRemaining then
			local ok, v = pcall(C_EncounterTimeline.GetEventTimeRemaining, rec.id)
			if ok and type(v) == "number" then
				rec.remaining = v
				updateRecTiming(rec, v)
				self:updateRecord(rec.id, rec.eventInfo, v)
			end
		end
	end

	self:LayoutAll()
end

C_Timer.NewTicker(C.TICK_INTERVAL, function() M:Tick() end)
