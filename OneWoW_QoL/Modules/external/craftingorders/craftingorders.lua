local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI
local C_AddOns = C_AddOns

local OWNER = "QoL_craftingorders"

local INCOMPATIBLE_ADDONS = {
    "PatronOffers",
    "PublicOrdersReagentsColumn",
}

local function ModuleOn()
    return ns.ModuleRegistry:IsEnabled("craftingorders")
end

local function AddonIsEnabled(name)
    if not C_AddOns.DoesAddOnExist(name) then
        return false
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    return C_AddOns.GetAddOnEnableState(name) > Enum.AddOnEnableState.None
end

local function CollectIncompatibleTitles()
    local titles = {}
    for i = 1, #INCOMPATIBLE_ADDONS do
        local name = INCOMPATIBLE_ADDONS[i]
        if AddonIsEnabled(name) then
            local _, title = C_AddOns.GetAddOnInfo(name)
            if not title or title == "" then
                title = name
            end
            tinsert(titles, title)
        end
    end
    return titles
end

local function HasIncompatibleAddons()
    return #CollectIncompatibleTitles() > 0
end

function M:ShowIncompatibleDialog()
    local titles = CollectIncompatibleTitles()
    if #titles == 0 then
        return
    end
    if M._incompatDialog and M._incompatDialog:IsShown() then
        M._incompatDialog:Raise()
        return
    end
    local result = OneWoW_GUI:CreateConfirmDialog({
        name = "OneWoWQoLCraftOrdersIncompatible",
        addonTitle = L["CRAFTORDERS_TITLE"],
        title = L["CRAFTORDERS_INCOMPATIBLE_TITLE"],
        message = L["CRAFTORDERS_INCOMPATIBLE_BODY"]:format(table.concat(titles, ", ")),
        width = 480,
        showBrand = true,
        buttons = {
            {
                text = CLOSE,
                onClick = function(dialog)
                    dialog:Hide()
                end,
            },
        },
        onClose = function()
            M._incompatDialog = nil
        end,
    })
    result.frame:HookScript("OnHide", function()
        M._incompatDialog = nil
    end)
    M._incompatDialog = result.frame
    result.frame:Show()
    result.frame:Raise()
end

function M:CanEnable()
    if HasIncompatibleAddons() then
        M:ShowIncompatibleDialog()
        ns.ModuleRegistry:GetModuleBucket("craftingorders").userChoseOn = true
    end
    return true
end

function M:CreateCustomDetail(parent, yOffset)
    local titles = CollectIncompatibleTitles()
    if #titles == 0 then
        return yOffset
    end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    local width = parent:GetWidth() or 0
    if width >= 1 then
        fs:SetWidth(width)
    end
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    fs:SetText(L["CRAFTORDERS_INCOMPATIBLE_BODY"]:format(table.concat(titles, ", ")))
    return yOffset - fs:GetStringHeight() - 8
end

function M:WireProfessions()
    if not ModuleOn() then return end
    local page = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if not page then return end

    if not M._pageHooks then
        M._pageHooks = true
        -- XML mixin="" copies methods onto OrdersPage at load. Hooking the
        -- mixin table after Blizzard_Professions loads never wraps those copies.
        hooksecurefunc(page, "SetCraftingOrderType", function(myself)
            M:OnOrderTypeChanged(myself)
        end)
        hooksecurefunc(page, "ShowGeneric", function(myself, orders)
            M:OnOrdersShown(myself, orders)
        end)
        hooksecurefunc(page, "SendOrderRequest", function(myself, request)
            M:OnOrdersRequestSent(myself, request)
        end)

        page:HookScript("OnShow", function()
            if ModuleOn() then
                M:ShowOverlay()
            end
        end)
        page:HookScript("OnHide", function()
            if ModuleOn() then
                M:HideOverlay()
            end
        end)
        local browse = page.BrowseFrame
        if browse then
            browse:HookScript("OnShow", function()
                if ModuleOn() then
                    M:ShowOverlay()
                end
            end)
        end
        local list = browse and browse.OrderList
        if list then
            list:HookScript("OnShow", function(myself)
                if ModuleOn() and M:WantsOverlay() and M._overlay and M._overlay:IsShown() then
                    myself:Hide()
                end
            end)
        end

        local view = page.OrderView
        if view then
            hooksecurefunc(view, "SetOrder", function(myself)
                M:OnOrderViewUpdated(myself)
            end)
            hooksecurefunc(view, "SetOrderState", function(myself)
                M:OnOrderViewUpdated(myself)
            end)
            hooksecurefunc(view, "UpdateCreateButton", function(myself)
                M:OnOrderViewUpdated(myself)
            end)
            hooksecurefunc(view, "UpdateStartOrderButton", function(myself)
                M:OnOrderViewUpdated(myself)
            end)
        end
    end

    M:InstallCastBarNoop()
    M:EnsureOverlay()
    M:EnsureModeButton()
    M:EnsureMagicButton()
end

function M:OnProfessionShown()
    if not ModuleOn() then return end
    M:WireProfessions()
    local page = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if page and page:IsShown() then
        M:ShowOverlay()
    end
end

function M:OnProfessionClosed()
    M:HideOverlay()
    M:HideMagicButton()
end

function M:EnsureEventFrame()
    if M._eventFrame then return M._eventFrame end
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function(_, event)
        if not ModuleOn() then return end
        if event == "CRAFTINGORDERS_CAN_REQUEST" then
            M._holdPull = false
            M._loading = false
        end
        M:RefreshOverlay()
        M:ValidateMagicButton()
    end)
    M._eventFrame = f
    return f
end

function M:OnEnable()
    if HasIncompatibleAddons() and not ns.ModuleRegistry:GetModuleBucket("craftingorders").userChoseOn then
        ns.ModuleRegistry:SetEnabled("craftingorders", false)
        return
    end

    OneWoW:RegisterAddonLoadedWatcher("Blizzard_Professions", function()
        if ModuleOn() then
            M:WireProfessions()
        end
    end)
    OneWoW.ProfessionRecipe.RegisterShowCallback(OWNER, function()
        M:OnProfessionShown()
    end)
    OneWoW.ProfessionRecipe.RegisterClosedCallback(OWNER, function()
        M:OnProfessionClosed()
    end)
    OneWoW:RegisterDataReadyWatcher("OneWoW_ShoppingList", function()
        if ModuleOn() then
            M:RefreshOverlay()
        end
    end)
    OneWoW:RegisterAddonLoadedWatcher("OneWoW_ShoppingList", function()
        if ModuleOn() then
            M:RefreshOverlay()
        end
    end)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Storage", function()
        M:OnStorageReady()
        if ModuleOn() then
            M:RefreshOverlay()
        end
    end)

    OneWoW.Inventory.RegisterDelayedCallback(OWNER, function()
        if not ModuleOn() then return end
        M:RefreshOverlay()
    end)
    OneWoW.Inventory.RegisterBankSlotsCallback(OWNER, function()
        if not ModuleOn() then return end
        M:RefreshOverlay()
    end)

    local f = M:EnsureEventFrame()
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    f:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT")
    f:RegisterEvent("CRAFTINGORDERS_CAN_REQUEST")
    f:RegisterEvent("CRAFTINGORDERS_UPDATE_CUSTOMER_NAME")
    f:RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS")
    f:RegisterEvent("PLAYER_GUILD_UPDATE")

    OneWoW.Restriction.RegisterStateCallback(OWNER, function()
        M:ValidateMagicButton()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", M, function()
        if not ModuleOn() then return end
        M:ApplyOverlayTheme()
        M:ValidateMagicButton()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", M, function()
        if not ModuleOn() then return end
        M:RefreshOverlay()
        M:ValidateMagicButton()
    end)

    if OneWoW.ProfessionRecipe.IsTradeskillOpen() then
        M:OnProfessionShown()
    end
end

function M:OnDisable()
    ns.ModuleRegistry:GetModuleBucket("craftingorders").userChoseOn = nil
    OneWoW.ProfessionRecipe.UnregisterCallback(OWNER)
    OneWoW.Inventory.UnregisterCallback(OWNER)
    OneWoW.Restriction.UnregisterStateCallback(OWNER)
    OneWoW.Restriction.CancelWhenUnrestricted("QoL_craftingorders_magic")
    if M._eventFrame then
        M._eventFrame:UnregisterAllEvents()
    end
    M:RestoreCastBar()
    M:HideMagicButton()
    M:HideOverlay()
    if M._modeBtn then
        M._modeBtn:Hide()
    end
    if M._settingsBtn then
        M._settingsBtn:Hide()
    end
end

function M:OnToggle(toggleId)
    if toggleId == "hideUnlearned" then
        if M:WantsOverlay() then
            M:RefreshOverlay()
        end
        return
    end
    if toggleId ~= "useBlizzardList" then return end
    M:UpdateModeButton()
    if M:WantsOverlay() then
        M:ShowOverlay()
    else
        M:HideOverlay()
    end
end
