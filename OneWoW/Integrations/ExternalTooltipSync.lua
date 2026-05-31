local ADDON_NAME, OneWoW = ...
local wipe = table.wipe

OneWoW.ExternalTooltipSync = OneWoW.ExternalTooltipSync or {}
local Sync = OneWoW.ExternalTooltipSync

local AUCTIONATOR_OPTION_KEYS = {
    "AUCTION_TOOLTIPS",
    "AUCTION_AGE_TOOLTIPS",
    "AUCTION_MEAN_TOOLTIPS",
    "VENDOR_TOOLTIPS",
    "PET_TOOLTIPS",
}

local function ValueCfg()
    local s = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    return s and s.tooltips and s.tooltips.value
end

local function EnsureBackupTable(cfg)
    if not cfg._auctionatorTooltipBackup or type(cfg._auctionatorTooltipBackup) ~= "table" then
        cfg._auctionatorTooltipBackup = {}
    end
    return cfg._auctionatorTooltipBackup
end

function Sync:EnsurePopups()
    if self._popups then return end
    self._popups = true
    local L = OneWoW.L
    StaticPopupDialogs["ONEWOW_AUCTIONATOR_AH_SOURCE"] = {
        text = L["VALUE_AUCTIONATOR_POPUP_TEXT"] or "Auctionator is now the source for Auction House prices in OneWoW tooltips. Use Auctionator to scan the AH. The OneWoW AH scanner is hidden where this setting applies.",
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopupDialogs["ONEWOW_TSM_TOOLTIP_NOTICE"] = {
        text = L["VALUE_TSM_POPUP_TEXT"] or "OneWoW can show a TSM price line in tooltips. To avoid duplicate lines, open TSM Settings > Tooltip Settings and disable \"Enable TSM tooltips\", or clear all TSM tooltip line options you also show in OneWoW.",
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function Sync:BackupAuctionatorIfNeeded(cfg)
    if not (Auctionator and Auctionator.Config and Auctionator.Config.Get and Auctionator.Config.Options) then return end
    local Opt = Auctionator.Config.Options
    local b = EnsureBackupTable(cfg)
    if b._captured then return end
    for _, k in ipairs(AUCTIONATOR_OPTION_KEYS) do
        local opt = Opt[k]
        if opt then
            b[opt] = Auctionator.Config.Get(opt)
        end
    end
    b._captured = true
end

function Sync:RestoreAuctionator(cfg)
    local b = cfg._auctionatorTooltipBackup
    if not b or not b._captured then return end
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
    self:BackupAuctionatorIfNeeded(cfg)

    Auctionator.Config.Set(Opt.AUCTION_TOOLTIPS, false)
    Auctionator.Config.Set(Opt.AUCTION_AGE_TOOLTIPS, false)
    Auctionator.Config.Set(Opt.AUCTION_MEAN_TOOLTIPS, false)

    if cfg.showVendorPrice ~= false then
        Auctionator.Config.Set(Opt.VENDOR_TOOLTIPS, false)
    end

    Auctionator.Config.Set(Opt.PET_TOOLTIPS, false)
end

function Sync:MaybeShowAuctionatorNotice(cfg)
    if cfg._auctionatorSourcePopupShown then return end
    cfg._auctionatorSourcePopupShown = true
    self:EnsurePopups()
    StaticPopup_Show("ONEWOW_AUCTIONATOR_AH_SOURCE")
end

function Sync:MaybeShowTSMNotice(cfg)
    if cfg.showTSMValue ~= true then return end
    if cfg._tsmTooltipNoticeShown then return end
    cfg._tsmTooltipNoticeShown = true
    self:EnsurePopups()
    StaticPopup_Show("ONEWOW_TSM_TOOLTIP_NOTICE")
end

function Sync:SyncAll()
    local cfg = ValueCfg()
    if not cfg then return end
    self:EnsurePopups()

    if C_AddOns.IsAddOnLoaded("Auctionator") and Auctionator and Auctionator.Config and Auctionator.Config.Options then
        if cfg.ahPriceSource == "auctionator" then
            self:ApplyAuctionatorSuppression(cfg)
            self:MaybeShowAuctionatorNotice(cfg)
        else
            self:RestoreAuctionator(cfg)
        end
    end

    if cfg.showTSMValue == true and C_AddOns.IsAddOnLoaded("TradeSkillMaster") then
        self:MaybeShowTSMNotice(cfg)
    end
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("ADDON_LOADED")
syncFrame:SetScript("OnEvent", function(_, _, name)
    if name == "Auctionator" or name == "TradeSkillMaster" then
        Sync:SyncAll()
    end
end)

function OneWoW.ExternalTooltipSync_OnLogin()
    Sync:SyncAll()
end
