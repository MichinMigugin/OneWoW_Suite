local _, ns = ...

local function IsEnabled()
    return ns.SettingsFeatureRegistry:IsIntegrationEnabled("arkinventory")
end

local wired = false
local function SetupHooks()
    if wired then return end
    if not ArkInventory or not ArkInventory.API then return end
    wired = true

    local function InitButton(itemButton)
        if not itemButton.onewow_overlayContainer then
            local c = CreateFrame("Frame", nil, itemButton)
            c:SetAllPoints(itemButton)
            c:EnableMouse(false)
            c:Hide()
            itemButton.onewow_overlayContainer = c
        end
    end

    local function UpdateButton(itemButton)
        if not IsEnabled() then
            ns.OverlayEngine:CleanButton(itemButton)
            return
        end

        local data = ArkInventory.API.ItemFrameItemTableGet(itemButton)
        if not data then
            ns.OverlayEngine:CleanButton(itemButton)
            return
        end

        local itemLocation

        if not ArkInventory.API.LocationIsOffline(data.loc_id) then
            local blizzardBagID = itemButton.ARK_Data and itemButton.ARK_Data.blizzard_id
            local blizzardSlot  = itemButton.ARK_Data and itemButton.ARK_Data.slot_id
            if blizzardBagID and blizzardSlot then
                itemLocation = ItemLocation:CreateFromBagAndSlot(blizzardBagID, blizzardSlot)
                if not C_Item.DoesItemExist(itemLocation) then
                    itemLocation = nil
                end
            end
        end

        if data.h then
            ns.OverlayEngine:ProcessButton(itemButton, data.h, itemLocation)
        else
            ns.OverlayEngine:CleanButton(itemButton)
        end
    end

    for _, itemButton in ArkInventory.API.ItemFrameLoadedIterate() do
        InitButton(itemButton)
    end

    hooksecurefunc(ArkInventory.API, "ItemFrameLoaded", function(itemButton)
        InitButton(itemButton)
    end)

    hooksecurefunc(ArkInventory.API, "ItemFrameUpdated", function(itemButton)
        UpdateButton(itemButton)
    end)

    local function RefreshArkInventory()
        if not ArkInventory or not ArkInventory.API then return end
        for _, itemButton in ArkInventory.API.ItemFrameLoadedIterate() do
            UpdateButton(itemButton)
        end
    end

    ns.OverlayEngine:RegisterIntegration(RefreshArkInventory)
end

ns:RegisterAddonLoadedWatcher("ArkInventory", SetupHooks)
