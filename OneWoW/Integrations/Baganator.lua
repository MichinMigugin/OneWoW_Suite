local _, ns = ...

local function IsEnabled()
    return ns.SettingsFeatureRegistry:IsIntegrationEnabled("baganator")
end

local wired = false
local function SetupHooks()
    if wired then return end
    if not Baganator or not Baganator.API then return end
    wired = true

    Baganator.API.RegisterCornerWidget(
        "OneWoW Overlays",
        "onewow_overlays",
        function(icon, itemDetails)
            local itemButton = icon.onewow_button
            if not itemButton then return false end

            if not IsEnabled() or not itemDetails or not itemDetails.itemLink then
                ns.OverlayEngine:CleanButton(itemButton)
                return false
            end

            local loc
            if itemDetails.itemLocation then
                loc = ItemLocation:CreateFromBagAndSlot(
                    itemDetails.itemLocation.bagID,
                    itemDetails.itemLocation.slotIndex
                )
            end

            ns.OverlayEngine:ProcessButton(itemButton, itemDetails.itemLink, loc)
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

    ns.OverlayEngine:RegisterIntegration(RefreshBaganator)
    C_Timer.After(0.5, RefreshBaganator)
end

ns:RegisterAddonLoadedWatcher("Baganator", SetupHooks)
