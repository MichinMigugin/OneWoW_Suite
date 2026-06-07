local _, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.arkinventory then return true end
    return ov.integrations.arkinventory.enabled ~= false
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
            OneWoW.OverlayEngine:CleanButton(itemButton)
            return
        end

        local data = ArkInventory.API.ItemFrameItemTableGet(itemButton)
        if not data then
            OneWoW.OverlayEngine:CleanButton(itemButton)
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
            OneWoW.OverlayEngine:ProcessButton(itemButton, data.h, itemLocation)
        else
            OneWoW.OverlayEngine:CleanButton(itemButton)
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

    OneWoW.OverlayEngine:RegisterIntegration(RefreshArkInventory)
end

OneWoW:RegisterAddonLoadedWatcher("ArkInventory", SetupHooks)
