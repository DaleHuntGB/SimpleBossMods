-- SimpleBossMods test mode helpers.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const

-- =========================
-- Test mode (looping "rotation" stack)
-- =========================
local TEST_ICONS = {
	-- iconFileID (common textures), duration
	{ icon = 134400, dur = 18.0, label = "Test A" }, -- fire
	{ icon = 136243, dur = 14.0, label = "Test B" }, -- frost
	{ icon = 135807, dur = 10.0, label = "Test C" }, -- nature
	{ icon = 135860, dur = 7.5,  label = "Test D" }, -- bleed-ish
	{ icon = 136116, dur = 6.0,  label = "Test E" }, -- poison-ish
	{ icon = 136007, dur = 5.5,  label = "Test F" }, -- magic-ish
	{ icon = 132104, dur = 4.8,  label = "Test G" }, -- tank-ish
	{ icon = 135740, dur = 3.8,  label = "Test H" }, -- healer-ish
}

-- Fake indicator icons for test (not secure/API-driven)
local TEST_INDICATOR_ICONS = {
	135860, -- bleed
	136116, -- poison
	136007, -- magic
	132104, -- tank
	135740, -- healer
	135834, -- enrage-ish
}

local function applyFakeIndicators(frame, isIcon)
	local target = isIcon and frame.indicatorsFrame or frame.endIndicatorsFrame
	if not target then return end
	local textures = M.ensureIndicatorTextures(target, C.INDICATOR_MAX)

	for i = 1, C.INDICATOR_MAX do
		local tex = textures[i]
		tex:Show()
		tex:SetTexture(TEST_INDICATOR_ICONS[i] or nil)
		tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	if isIcon then
		M.layoutIconIndicators(frame, textures)
	else
		M.layoutBarIndicators(frame, textures)
	end
end

function M:StopTest()
	if self._testTicker then
		self._testTicker:Cancel()
		self._testTicker = nil
	end
	self:clearAll()
end

function M:StartTest()
	self:StopTest()

	local base = (math.floor(GetTime() * 1000) % 1000000) + 9100000
	local pool = {}

	for i, t in ipairs(TEST_ICONS) do
		pool[i] = {
			id = base + i,
			icon = t.icon,
			dur = t.dur,
			label = t.label,
			remaining = t.dur,
		}
	end

	local start = GetTime()

	-- Seed events
	for _, t in ipairs(pool) do
		local info = { name = t.label, iconFileID = t.icon }
		self:updateRecord(t.id, info, t.remaining)
	end
	self:LayoutAll()

	self._testTicker = C_Timer.NewTicker(0.05, function()
		local now = GetTime()
		local elapsed = now - start

		for _, t in ipairs(pool) do
			-- loop forever: when it expires, restart with slight jitter
			local rem = t.dur - ((elapsed + (t.id % 7) * 0.2) % t.dur)
			t.remaining = rem

			local rec = M.events[t.id]
			if not rec then
				M.events[t.id] = { id = t.id }
				rec = M.events[t.id]
			end
			rec.eventInfo = { name = t.label, iconFileID = t.icon }
			rec.remaining = rem
			M._updateRecTiming(rec, rem)

			if rem <= C.THRESHOLD_TO_BAR then
				M:ensureBar(rec)
			else
				M:ensureIcon(rec)
			end

			-- Fake indicators in test (so you can see more types)
			if rec.iconFrame then
				applyFakeIndicators(rec.iconFrame, true)
			end
			if rec.barFrame then
				applyFakeIndicators(rec.barFrame, false)
			end
		end

		M:LayoutAll()
	end)
end
