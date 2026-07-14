local _, ns = ...

local function IsEnabled()
    return ns.SettingsFeatureRegistry:IsIntegrationEnabled("onewow_bags")
end

--- Paint overlays for a OneWoW_Bags item button.
--- Guild bank slots use tab/slot ids with GetGuildBankItemLink (no ItemLocation).
local function ProcessButton(button, bagID, slotID)
    if not IsEnabled() then
        ns.OverlayEngine:CleanButton(button)
        return
    end
    if not button.owb_hasItem or not bagID or not slotID then
        ns.OverlayEngine:CleanButton(button)
        return
    end

    if button.owb_isGuildBank then
        local link = GetGuildBankItemLink(bagID, slotID)
        if link then
            ns.OverlayEngine:ProcessButton(button, link, nil)
        else
            ns.OverlayEngine:CleanButton(button)
        end
        return
    end

    local loc    = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    local exists = C_Item.DoesItemExist(loc)
    if exists then
        local link = C_Item.GetItemLink(loc)
        if link then
            ns.OverlayEngine:ProcessButton(button, link, loc)
        else
            ns.OverlayEngine:CleanButton(button)
        end
    else
        ns.OverlayEngine:CleanButton(button)
    end
end

local wired = false
local function SetupCallbacks()
    if wired then return end
    if not OneWoW_Bags_API or not OneWoW_Bags_API.RegisterItemButtonCallback then return end
    wired = true

    OneWoW_Bags_API.RegisterItemButtonCallback("OneWoW_Overlays", function(button, bagID, slotID)
        ProcessButton(button, bagID, slotID)
    end)

    local function RefreshOneWoWBags()
        OneWoW_Bags_API.FireCallbacksOnAllButtons()
        OneWoW_Bags_API.FireCallbacksOnBankButtons()
        OneWoW_Bags_API.FireCallbacksOnGuildBankButtons()
    end

    ns.OverlayEngine:RegisterIntegration(RefreshOneWoWBags)
end

-- Wire on every load path (cold-start force-load via RunPostLoadInit, mid-session
-- enable, or already-loaded at registration). SetupCallbacks only registers the
-- item-button callback + overlay-engine integration; it never paints. The first
-- paint comes from OneWoW_Bags:InstallIntegrationHooks at login (and the overlay
-- toggle path repaints via OverlayEngine:Refresh).
ns:RegisterAddonLoadedWatcher("OneWoW_Bags", SetupCallbacks)
