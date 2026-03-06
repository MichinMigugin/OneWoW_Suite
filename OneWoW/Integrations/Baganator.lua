local ADDON_NAME, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.baganator then return true end
    return ov.integrations.baganator.enabled ~= false
end

local function SetupHooks()
    if not Baganator or not Baganator.API then return end

    Baganator.API.RegisterCornerWidget(
        "OneWoW Overlays",
        "onewow_overlays",
        function(icon, itemDetails)
            local itemButton = icon.onewow_button
            if not itemButton then return false end

            if not IsEnabled() or not itemDetails or not itemDetails.itemLink then
                OneWoW.OverlayEngine:CleanButton(itemButton)
                return false
            end

            local loc
            if itemDetails.itemLocation then
                loc = ItemLocation:CreateFromBagAndSlot(
                    itemDetails.itemLocation.bagID,
                    itemDetails.itemLocation.slotIndex
                )
            end

            OneWoW.OverlayEngine:ProcessButton(itemButton, itemDetails.itemLink, loc)
            return true
        end,
        function(itemButton)
            local icon = CreateFrame("Frame", nil, itemButton)
            icon:SetSize(1, 1)
            icon:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", 0, 0)
            icon.onewow_button = itemButton
            local c = CreateFrame("Frame", nil, icon)
            c:SetAllPoints(itemButton)
            c:EnableMouse(false)
            c:Hide()
            itemButton.onewow_overlayContainer = c
            return icon
        end,
        { corner = "top_right", priority = 1 }
    )

    local function RefreshBaganator()
        if not Baganator or not Baganator.API then return end
        Baganator.API.RequestItemButtonsRefresh({ Baganator.Constants.RefreshReason.ItemWidgets })
    end

    OneWoW.OverlayEngine:RegisterIntegration(RefreshBaganator)
    C_Timer.After(0.5, RefreshBaganator)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if C_AddOns.IsAddOnLoaded("Baganator") then
        SetupHooks()
    end
    eventFrame:UnregisterEvent("PLAYER_LOGIN")
end)
