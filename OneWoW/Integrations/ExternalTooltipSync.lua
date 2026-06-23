-- ============================================================================
-- ExternalTooltipSync
-- ============================================================================
-- Keeps external tooltip addons (Auctionator, TSM) consistent with OneWoW's
-- tooltip value settings: suppresses Auctionator's own tooltip lines while it
-- is the AH price source (backing up the user's Auctionator options for
-- restore), and shows one-time notices.
--
-- Settings are READ via SettingsFeatureRegistry; runtime state (option
-- backups, notice flags) lives at db.global.externalTooltipSync — machine
-- state, not user settings.
-- ============================================================================

local _, ns = ...

local wipe = wipe

ns.ExternalTooltipSync = ns.ExternalTooltipSync or {}
local Sync = ns.ExternalTooltipSync

local AUCTIONATOR_OPTION_KEYS = {
    "AUCTION_TOOLTIPS",
    "AUCTION_AGE_TOOLTIPS",
    "AUCTION_MEAN_TOOLTIPS",
    "VENDOR_TOOLTIPS",
    "PET_TOOLTIPS",
}

local function State()
    return ns.db.global.externalTooltipSync
end

local function ValueCfg()
    return ns.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "value")
end

function Sync:EnsurePopups()
    if self._popups then return end
    self._popups = true
    local L = ns.L
    StaticPopupDialogs["ONEWOW_AUCTIONATOR_AH_SOURCE"] = {
        text = L["VALUE_AUCTIONATOR_POPUP_TEXT"],
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopupDialogs["ONEWOW_TSM_TOOLTIP_NOTICE"] = {
        text = L["VALUE_TSM_POPUP_TEXT"],
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function Sync:BackupAuctionatorIfNeeded()
    if not (Auctionator and Auctionator.Config and Auctionator.Config.Get and Auctionator.Config.Options) then return end
    local Opt = Auctionator.Config.Options
    local b = State().auctionatorBackup
    if b._captured then return end
    for _, k in ipairs(AUCTIONATOR_OPTION_KEYS) do
        local opt = Opt[k]
        if opt then
            b[opt] = Auctionator.Config.Get(opt)
        end
    end
    b._captured = true
end

function Sync:RestoreAuctionator()
    local b = State().auctionatorBackup
    if not b._captured then return end
    if not (Auctionator and Auctionator.Config and Auctionator.Config.Set and Auctionator.Config.Options) then
        wipe(b)
        b._captured = false
        return
    end
    local Opt = Auctionator.Config.Options
    for _, k in ipairs(AUCTIONATOR_OPTION_KEYS) do
        local opt = Opt[k]
        if opt and b[opt] ~= nil then
            Auctionator.Config.Set(opt, b[opt])
        end
    end
    wipe(b)
    b._captured = false
end

function Sync:ApplyAuctionatorSuppression(cfg)
    if not (Auctionator and Auctionator.Config and Auctionator.Config.Set and Auctionator.Config.Options) then return end
    local Opt = Auctionator.Config.Options
    self:BackupAuctionatorIfNeeded()

    Auctionator.Config.Set(Opt.AUCTION_TOOLTIPS, false)
    Auctionator.Config.Set(Opt.AUCTION_AGE_TOOLTIPS, false)
    Auctionator.Config.Set(Opt.AUCTION_MEAN_TOOLTIPS, false)

    if cfg.showVendorPrice ~= false then
        Auctionator.Config.Set(Opt.VENDOR_TOOLTIPS, false)
    end

    Auctionator.Config.Set(Opt.PET_TOOLTIPS, false)
end

function Sync:MaybeShowAuctionatorNotice()
    local state = State()
    if state.auctionatorPopupShown then return end
    state.auctionatorPopupShown = true
    self:EnsurePopups()
    StaticPopup_Show("ONEWOW_AUCTIONATOR_AH_SOURCE")
end

function Sync:MaybeShowTSMNotice(cfg)
    if cfg.showTSMValue ~= true then return end
    local state = State()
    if state.tsmNoticeShown then return end
    state.tsmNoticeShown = true
    self:EnsurePopups()
    StaticPopup_Show("ONEWOW_TSM_TOOLTIP_NOTICE")
end

function Sync:SyncAll()
    -- Addon-loaded watcher catch-up can invoke this at file-parse time (e.g.
    -- Auctionator sorts before OneWoW), before InitializeDatabase has run. The
    -- login handler below re-syncs once the DB exists.
    if not ns.db then return end
    local cfg = ValueCfg()
    self:EnsurePopups()

    if C_AddOns.IsAddOnLoaded("Auctionator") and Auctionator and Auctionator.Config and Auctionator.Config.Options then
        if cfg.ahPriceSource == "auctionator" then
            self:ApplyAuctionatorSuppression(cfg)
            self:MaybeShowAuctionatorNotice()
        else
            self:RestoreAuctionator()
        end
    end

    if cfg.showTSMValue == true and C_AddOns.IsAddOnLoaded("TradeSkillMaster") then
        self:MaybeShowTSMNotice(cfg)
    end
end

ns:RegisterAddonLoadedWatcher("Auctionator", function()
    Sync:SyncAll()
end)
ns:RegisterAddonLoadedWatcher("TradeSkillMaster", function()
    Sync:SyncAll()
end)

-- Re-sync whenever a tooltip value setting changes, regardless of which UI
-- mutated it (settings tab, Trackers farm panel, ...). Bulk resets pass a nil
-- storageId and are included.
ns.SettingsFeatureRegistry:RegisterListener("ExternalTooltipSync", function(storageTab, storageId)
    if storageTab == "tooltips" and (storageId == nil or storageId == "value") then
        Sync:SyncAll()
    end
end)

function ns.ExternalTooltipSync_OnLogin()
    Sync:SyncAll()
end

ns:RegisterCoreLoginHandler("ExternalTooltipSync", function()
    ns.ExternalTooltipSync_OnLogin()
end, "early")
