local _, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.onewow_bags then return true end
    return ov.integrations.onewow_bags.enabled ~= false
end

local function ProcessButton(button, bagID, slotID)
    if not IsEnabled() then
        OneWoW.OverlayEngine:CleanButton(button)
        return
    end
    if not button.owb_hasItem or not bagID or not slotID then
        OneWoW.OverlayEngine:CleanButton(button)
        return
    end
    local loc    = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    local exists = C_Item.DoesItemExist(loc)
    if exists then
        local link = C_Item.GetItemLink(loc)
        if link then
            OneWoW.OverlayEngine:ProcessButton(button, link, loc)
        else
            OneWoW.OverlayEngine:CleanButton(button)
        end
    else
        OneWoW.OverlayEngine:CleanButton(button)
    end
end

local wired = false
local function SetupCallbacks()
    if wired then return end
    local Bags = OneWoW_Bags
    if not Bags or not Bags.RegisterItemButtonCallback then return end
    wired = true

    Bags:RegisterItemButtonCallback("OneWoW_Overlays", function(button, bagID, slotID)
        ProcessButton(button, bagID, slotID)
    end)

    local function RefreshOneWoWBags()
        Bags:FireCallbacksOnAllButtons()
    end

    OneWoW.OverlayEngine:RegisterIntegration(RefreshOneWoWBags)
end

-- Wire on every load path (cold-start force-load via RunPostLoadInit, mid-session
-- enable, or already-loaded at registration). SetupCallbacks only registers the
-- item-button callback + overlay-engine integration; it never paints. The first
-- paint comes from OneWoW_Bags:InstallIntegrationHooks at login (and the overlay
-- toggle path repaints via OverlayEngine:Refresh).
OneWoW:RegisterAddonLoadedWatcher("OneWoW_Bags", SetupCallbacks)
