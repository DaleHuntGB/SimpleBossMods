-- SimpleBossMods events and slash commands.

local ADDON_NAME = ...
local M = _G[ADDON_NAME]
if not M then return end

-- =========================
-- Events
-- =========================
local ef = CreateFrame("Frame")
ef:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		M:EnsureDefaults()
		M.SyncLiveConfig()

		M:SetPosition(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0)
		M:ApplyGeneralConfig(SimpleBossModsDB.pos.x or 0, SimpleBossModsDB.pos.y or 0, SimpleBossModsDB.cfg.general.gap or 6)
		M:ApplyIconConfig(SimpleBossModsDB.cfg.icons.size, SimpleBossModsDB.cfg.icons.fontSize, SimpleBossModsDB.cfg.icons.borderThickness)
		M:ApplyBarConfig(SimpleBossModsDB.cfg.bars.width, SimpleBossModsDB.cfg.bars.height, SimpleBossModsDB.cfg.bars.fontSize, SimpleBossModsDB.cfg.bars.borderThickness)
		M:ApplyIndicatorConfig(SimpleBossModsDB.cfg.indicators.iconSize or 0, SimpleBossModsDB.cfg.indicators.barSize or 0)

		M:CreateSettingsPanel()
		M:Tick()
		M:LayoutAll()
	elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED"
		or event == "ENCOUNTER_TIMELINE_EVENT_REMOVED"
		or event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
		C_Timer.After(0, function() M:Tick() end)
	end
end)

ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
ef:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")

-- =========================
-- Slash
-- =========================
SLASH_SIMPLEBOSSMODS1 = "/sbm"
SLASH_SIMPLEBOSSMODS2 = "/simplebossmods"
SlashCmdList["SIMPLEBOSSMODS"] = function(msg)
	msg = (msg or ""):lower()

	if msg == "" or msg == "settings" or msg == "config" or msg == "options" then
		M:OpenSettings()
		return
	end

	if msg == "test" then
		M:StartTest()
		return
	end

	if msg == "clear" then
		M:StopTest()
		return
	end

	print(ADDON_NAME .. " commands: /sbm | /sbm settings|config|options | /sbm test | /sbm clear")
end
