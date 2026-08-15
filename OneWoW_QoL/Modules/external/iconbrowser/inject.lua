-- ============================================================================
-- Icon Browser injection
-- ============================================================================
-- Replaces Blizzard IconSelector on any IconSelectorPopupFrameTemplate
-- popup, including OneWoW Bags' cloned bank-tab menu. Stands down when
-- the IconBrowser addon is loaded so the two UIs never stack. Show/SetShown
-- hooks persist; the active flag restores the stock selector on disable.
-- ============================================================================

local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

local C_AddOns = C_AddOns
local hooksecurefunc = hooksecurefunc

local Inject = {
    active = false,
    watchersArmed = false,
    records = {},
}
M.Inject = Inject

local function HasForeignBrowser()
    if LRPMediaIconBrowserAPI then
        return true
    end
    return C_AddOns.IsAddOnLoaded("IconBrowser")
end

local function SuppressStock(frame)
    if not frame or frame._onewowIBHooked then
        return
    end
    frame._onewowIBHooked = true
    hooksecurefunc(frame, "Show", function(self)
        if not Inject.active then
            return
        end
        self:SetAlpha(0)
        self:Hide()
    end)
    hooksecurefunc(frame, "SetShown", function(self, shown)
        if not Inject.active then
            return
        end
        if shown then
            self:SetAlpha(0)
            self:Hide()
        end
    end)
end

local function ForEachStockChrome(popup, fn)
    fn(popup.IconSelector)
    local box = popup.BorderBox
    if not box then
        return
    end
    fn(box.IconTypeDropdown)
    fn(box.IconSelectionText)
end

local function ApplyStockVisibility(popup, showStock)
    ForEachStockChrome(popup, function(region)
        if not region then
            return
        end
        if showStock then
            region:SetAlpha(1)
            region:Show()
        else
            region:SetAlpha(0)
            region:Hide()
        end
    end)
end

-- Search+filter sit in the stock "Choose an Icon" / type-dropdown row;
-- the grid fills the IconSelector hole Blizzard already reserved.
local TOOLBAR_HEIGHT = 32

local function AnchorBrowser(browser, popup)
    local selector = popup.IconSelector
    if selector then
        browser:ClearAllPoints()
        browser:SetPoint("TOPLEFT", selector, "TOPLEFT", 0, TOOLBAR_HEIGHT)
        browser:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", 0, 0)
        return
    end

    local box = popup.BorderBox
    if not box then
        browser:SetAllPoints(popup)
        return
    end
    browser:ClearAllPoints()
    browser:SetPoint("TOPLEFT", box, "TOPLEFT", 21, -68)
    browser:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -14, 38)
end

function Inject.TryAttach(popup)
    if not popup or popup._onewowIconBrowser then
        return
    end
    if not popup.BorderBox then
        return
    end

    ForEachStockChrome(popup, SuppressStock)

    local browser = M.Browser.Create(popup.BorderBox, { popup = popup })
    browser:SetFrameLevel(popup.BorderBox:GetFrameLevel() + 10)
    AnchorBrowser(browser, popup)
    browser:Hide()
    popup._onewowIconBrowser = browser

    popup:HookScript("OnShow", function(myself)
        if not Inject.active then
            return
        end
        ApplyStockVisibility(myself, false)
        local attached = myself._onewowIconBrowser
        if attached then
            AnchorBrowser(attached, myself)
            attached:Show()
        end
    end)

    popup:HookScript("OnHide", function(myself)
        local attached = myself._onewowIconBrowser
        if attached then
            attached:Hide()
        end
    end)

    tinsert(Inject.records, { popup = popup, browser = browser })

    if Inject.active and popup:IsShown() then
        ApplyStockVisibility(popup, false)
        browser:Show()
    end
end

local function AttachKnownPopups()
    if MacroPopupFrame then
        Inject.TryAttach(MacroPopupFrame)
    end
    if GuildBankPopupFrame then
        Inject.TryAttach(GuildBankPopupFrame)
    end
    if GearManagerPopupFrame then
        Inject.TryAttach(GearManagerPopupFrame)
    end
    if BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.TabSettingsMenu then
        Inject.TryAttach(BankFrame.BankPanel.TabSettingsMenu)
    end
    if OneWoW_BankTabSettingsMenu then
        Inject.TryAttach(OneWoW_BankTabSettingsMenu)
    end
    local transmog = (TransmogFrame and TransmogFrame.OutfitPopup) or WardrobeOutfitEditFrame
    if transmog then
        Inject.TryAttach(transmog)
    end
end

function Inject.ArmWatchers()
    if Inject.watchersArmed then
        return
    end
    Inject.watchersArmed = true

    hooksecurefunc(IconSelectorPopupFrameTemplateMixin, "OnShow", function(popup)
        if not Inject.active then
            return
        end
        Inject.TryAttach(popup)
    end)

    OneWoW:RegisterAddonLoadedWatcher("Blizzard_MacroUI", AttachKnownPopups)
    OneWoW:RegisterAddonLoadedWatcher("Blizzard_GuildBankUI", AttachKnownPopups)
    OneWoW:RegisterAddonLoadedWatcher("Blizzard_Transmog", AttachKnownPopups)
    OneWoW:RegisterAddonLoadedWatcher("Blizzard_UIPanels_Game", AttachKnownPopups)
    OneWoW:RegisterAddonLoadedWatcher("OneWoW_Bags", AttachKnownPopups)
end

function Inject.Arm()
    if HasForeignBrowser() then
        return
    end
    Inject.active = true
    Inject.ArmWatchers()
    AttachKnownPopups()
    for i = 1, #Inject.records do
        local rec = Inject.records[i]
        ApplyStockVisibility(rec.popup, false)
        if rec.popup:IsShown() then
            rec.browser:Show()
        end
    end
end

function Inject.Disarm()
    Inject.active = false
    for i = 1, #Inject.records do
        local rec = Inject.records[i]
        rec.browser:Hide()
        ApplyStockVisibility(rec.popup, true)
    end
end
