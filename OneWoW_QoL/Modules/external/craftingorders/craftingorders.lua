local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI

local OWNER = "QoL_craftingorders"

local function ModuleOn()
    return ns.ModuleRegistry:IsEnabled("craftingorders")
end

function M:WireProfessions()
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
            M:HideOverlay()
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
    OneWoW:RegisterAddonLoadedWatcher("Blizzard_Professions", function()
        M:WireProfessions()
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
        M:ApplyOverlayTheme()
        M:ValidateMagicButton()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", M, function()
        M:RefreshOverlay()
        M:ValidateMagicButton()
    end)

    if OneWoW.ProfessionRecipe.IsTradeskillOpen() then
        M:OnProfessionShown()
    end
end

function M:OnDisable()
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
