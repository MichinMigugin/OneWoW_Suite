--[[
OneWoW Bags Integration - Basic Template

Use this as a starting point for your addon's OneWoW Bags integration.

Instructions:
1. Copy this file to your addon folder: YourAddon/Integrations/OneWoWBags.lua
2. Replace YourAddon_* function names with your addon's name
3. Implement YourAddon_ApplyOverlay() with your custom logic
4. Add "Integrations\OneWoWBags.lua" to your addon's .toc file
]]

local ADDON_NAME = ...

if _G.OneWoW_Bags then

    function YourAddon_ApplyOverlay(overlayFrame, itemLink, containerInfo)
        if not overlayFrame or not itemLink then
            overlayFrame:Hide()
            return
        end

        overlayFrame:Show()

        -- Your custom logic here
        -- Examples:
        --   - Draw colored texture
        --   - Add text badge
        --   - Create animated effect
        --   - Apply custom coloring
    end

    function YourAddon_UpdateItemButton(button, bagID, slotID)
        if not button then return end

        if not button.YourAddonOverlay then
            button.YourAddonOverlay = CreateFrame("Frame", nil, button)
            button.YourAddonOverlay:SetAllPoints(button)
            button.YourAddonOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
        end

        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

        if C_Item.DoesItemExist(itemLocation) then
            local itemLink = C_Item.GetItemLink(itemLocation)
            local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemLink and containerInfo then
                YourAddon_ApplyOverlay(button.YourAddonOverlay, itemLink, containerInfo)
            end
        else
            button.YourAddonOverlay:Hide()
        end
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, YourAddon_UpdateItemButton)

end
