-- SimpleBossMods settings panel and live config apply.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

local C = M.Const
local L = M.Live
local U = M.Util

-- =========================
-- Apply config live
-- =========================
function M:ApplyGeneralConfig(x, y, gap)
	SimpleBossModsDB.pos.x = tonumber(x) or (SimpleBossModsDB.pos.x or 0)
	SimpleBossModsDB.pos.y = tonumber(y) or (SimpleBossModsDB.pos.y or 0)
	SimpleBossModsDB.cfg.general.gap = tonumber(gap) or (SimpleBossModsDB.cfg.general.gap or 6)

	M.SyncLiveConfig()
	M:SetPosition(SimpleBossModsDB.pos.x, SimpleBossModsDB.pos.y)
	M:LayoutAll()
end

function M:ApplyIconConfig(size, fontSize, borderThickness)
	local ic = SimpleBossModsDB.cfg.icons
	ic.size = U.clamp(U.round(size), 16, 128)
	ic.fontSize = U.clamp(U.round(fontSize), 10, 48)
	ic.borderThickness = U.clamp(U.round(borderThickness), 0, 6)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.iconFrame then
			rec.iconFrame:SetSize(L.ICON_SIZE, L.ICON_SIZE)
			M.ensureFullBorder(rec.iconFrame.main, L.ICON_BORDER_THICKNESS)
			M.applyIconFont(rec.iconFrame.timeText)
		end
	end
	for _, f in ipairs(M.pools.icon) do
		f:SetSize(L.ICON_SIZE, L.ICON_SIZE)
		M.ensureFullBorder(f.main, L.ICON_BORDER_THICKNESS)
		M.applyIconFont(f.timeText)
	end

	self:LayoutAll()
end

function M:ApplyBarConfig(width, height, fontSize, borderThickness)
	local bc = SimpleBossModsDB.cfg.bars
	bc.width = U.clamp(U.round(width), 120, 800)
	bc.height = U.clamp(U.round(height), 12, 80)
	bc.fontSize = U.clamp(U.round(fontSize), 8, 32)
	bc.borderThickness = U.clamp(U.round(borderThickness), 1, 6)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.barFrame then
			rec.barFrame:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
			M.ensureFullBorder(rec.barFrame, L.BAR_BORDER_THICKNESS)

			rec.barFrame.leftFrame:SetWidth(L.BAR_HEIGHT)
			rec.barFrame.iconFrame:SetSize(L.BAR_HEIGHT, L.BAR_HEIGHT)
			M.ensureRightDivider(rec.barFrame.leftFrame, L.BAR_BORDER_THICKNESS)

			M.applyBarFont(rec.barFrame.txt)
			M.applyBarFont(rec.barFrame.rt)
			M.setBarFillFlat(rec.barFrame, C.BAR_FG_R, C.BAR_FG_G, C.BAR_FG_B, C.BAR_FG_A)
		end
	end
	for _, f in ipairs(M.pools.bar) do
		f:SetSize(L.BAR_WIDTH, L.BAR_HEIGHT)
		M.ensureFullBorder(f, L.BAR_BORDER_THICKNESS)
		if f.leftFrame then
			f.leftFrame:SetWidth(L.BAR_HEIGHT)
			M.ensureRightDivider(f.leftFrame, L.BAR_BORDER_THICKNESS)
		end
		if f.iconFrame then
			f.iconFrame:SetSize(L.BAR_HEIGHT, L.BAR_HEIGHT)
		end
		if f.endIndicatorsFrame then
			f.endIndicatorsFrame:SetWidth(1)
		end
		if f.txt then M.applyBarFont(f.txt) end
		if f.rt then M.applyBarFont(f.rt) end
		M.setBarFillFlat(f, C.BAR_FG_R, C.BAR_FG_G, C.BAR_FG_B, C.BAR_FG_A)
	end

	self:LayoutAll()
end

function M:ApplyIndicatorConfig(iconSize, barSize)
	local ic = SimpleBossModsDB.cfg.indicators
	ic.iconSize = U.clamp(U.round(iconSize), 0, 32)
	ic.barSize = U.clamp(U.round(barSize), 0, 32)

	M.SyncLiveConfig()

	for _, rec in pairs(self.events) do
		if rec.iconFrame then
			M.applyIndicatorsToIconFrame(rec.iconFrame, rec.id)
		end
		if rec.barFrame then
			M.applyIndicatorsToBarEnd(rec.barFrame, rec.id)
		end
	end

	self:LayoutAll()
end

-- =========================
-- Settings Panel (Midnight-safe OpenToCategory)
-- =========================
function M:OpenSettings()
	if Settings and Settings.OpenToCategory and type(self._settingsCategoryID) == "number" then
		Settings.OpenToCategory(self._settingsCategoryID)
	end
end

function M:CreateSettingsPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

	local panel = CreateFrame("Frame")
	panel.name = "SimpleBossMods"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("SimpleBossMods")

	local curY = -52
	local function Heading(text)
		local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		h:SetPoint("TOPLEFT", 16, curY)
		h:SetText(text)
		curY = curY - 22
		return h
	end

	local LABEL_X = 16
	local INPUT_X = 220
	local ROW_H = 26
	local inputs = {}

	local function AddNumberRow(label, get, set, tooltip, allowDecimal)
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		fs:SetPoint("TOPLEFT", LABEL_X, curY)
		fs:SetText(label)

		local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
		eb:SetSize(110, 22)
		eb:SetAutoFocus(false)
		eb:SetPoint("LEFT", panel, "TOPLEFT", INPUT_X, curY - 2)

		-- allow decimals: do NOT SetNumeric(true) (it blocks '.' in many clients)
		if not allowDecimal then
			eb:SetNumeric(true)
		end

		local function refresh()
			local v = get()
			eb:SetText(tostring(v))
		end

		local function apply()
			local v = tonumber(eb:GetText())
			if v == nil then
				refresh()
				return
			end
			set(v)
			refresh()
		end

		eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); apply() end)
		eb:SetScript("OnEditFocusLost", function() apply() end)
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)

		if tooltip then
			fs:SetScript("OnEnter", function()
				GameTooltip:SetOwner(fs, "ANCHOR_RIGHT")
				GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			fs:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		table.insert(inputs, refresh)
		curY = curY - ROW_H
		return eb
	end

	-- GENERAL
	Heading("General")

	AddNumberRow("X Offset",
		function() return SimpleBossModsDB.pos.x or 0 end,
		function(v) M:ApplyGeneralConfig(v, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6) end,
		nil, true
	)

	AddNumberRow("Y Offset",
		function() return SimpleBossModsDB.pos.y or 0 end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, v, SimpleBossModsDB.cfg.general.gap or 6) end,
		nil, true
	)

	AddNumberRow("Gap",
		function() return SimpleBossModsDB.cfg.general.gap or 6 end,
		function(v) M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, U.clamp(U.round(v), 0, 30)) end,
		"Used for icon gap and bars-to-icons gap.", false
	)

	curY = curY - 10

	-- ICONS
	Heading("Icons")
	AddNumberRow("Icon Size",
		function() return SimpleBossModsDB.cfg.icons.size end,
		function(v) M:ApplyIconConfig(v, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow("Icon Font Size",
		function() return SimpleBossModsDB.cfg.icons.fontSize end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, v, SimpleBossModsDB.cfg.icons.borderThickness) end
	)
	AddNumberRow("Icon Border Thickness",
		function() return SimpleBossModsDB.cfg.icons.borderThickness end,
		function(v) M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, v) end,
		"0 disables icon border."
	)

	curY = curY - 10

	-- BARS
	Heading("Bars")
	AddNumberRow("Bar Width",
		function() return SimpleBossModsDB.cfg.bars.width end,
		function(v) M:ApplyBarConfig(v, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow("Bar Height",
		function() return SimpleBossModsDB.cfg.bars.height end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, v, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow("Bar Font Size",
		function() return SimpleBossModsDB.cfg.bars.fontSize end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, v, SimpleBossModsDB.cfg.bars.borderThickness) end
	)
	AddNumberRow("Bar Border Thickness",
		function() return SimpleBossModsDB.cfg.bars.borderThickness end,
		function(v) M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, v) end
	)

	curY = curY - 12

	-- INDICATORS
	Heading("Indicators")
	AddNumberRow("Icon Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.iconSize or 0 end,
		function(v) M:ApplyIndicatorConfig(v, SimpleBossModsDB.cfg.indicators.barSize or 0) end,
		"0 uses auto size."
	)
	AddNumberRow("Bar Indicator Size",
		function() return SimpleBossModsDB.cfg.indicators.barSize or 0 end,
		function(v) M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, v) end,
		"0 uses auto size."
	)

	curY = curY - 12

	local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testBtn:SetSize(160, 22)
	testBtn:SetPoint("TOPLEFT", 16, curY)
	testBtn:SetText("Test (Loop)")
	testBtn:SetScript("OnClick", function() M:StartTest() end)

	local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	clearBtn:SetSize(160, 22)
	clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
	clearBtn:SetText("Clear")
	clearBtn:SetScript("OnClick", function() M:StopTest() end)

	panel:SetScript("OnShow", function()
		for _, r in ipairs(inputs) do r() end
		M:LayoutAll()
	end)

	panel:SetScript("OnHide", function()
		M:LayoutAll()
	end)

	local category = Settings.RegisterCanvasLayoutCategory(panel, M._settingsCategoryName)
	Settings.RegisterAddOnCategory(category)

	if category and type(category.GetID) == "function" then
		M._settingsCategoryID = category:GetID()
	elseif category and type(category.ID) == "number" then
		M._settingsCategoryID = category.ID
	end
end
