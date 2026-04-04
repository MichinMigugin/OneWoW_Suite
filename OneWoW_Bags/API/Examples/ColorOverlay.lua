--[[
OneWoW Bags Integration - Color Overlay Example

Shows how to add a colored texture overlay to items based on custom criteria.
This example highlights items by rarity color.

Instructions:
1. Copy to: YourAddon/Integrations/OneWoWBags.lua
2. Add to .toc: Integrations\OneWoWBags.lua
3. Modify the RARITY_COLORS table to suit your needs
]]

local ADDON_NAME = ...

if _G.OneWoW_Bags then

    local RARITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },  -- Poor (gray)
        [1] = { r = 1.00, g = 1.00, b = 1.00 },  -- Common (white)
        [2] = { r = 0.12, g = 1.00, b = 0.00 },  -- Uncommon (green)
        [3] = { r = 0.00, g = 0.44, b = 0.87 },  -- Rare (blue)
        [4] = { r = 0.64, g = 0.21, b = 0.93 },  -- Epic (purple)
        [5] = { r = 1.00, g = 0.50, b = 0.00 },  -- Legendary (orange)
    }

    function YourAddon_ApplyColorOverlay(overlayFrame, itemLink, containerInfo)
        if not overlayFrame or not containerInfo then
            overlayFrame:Hide()
            return
        end

        local quality = containerInfo.quality or 1
        local color = RARITY_COLORS[quality]

        if not color then
            overlayFrame:Hide()
            return
        end

        -- Create or update texture
        if not overlayFrame.colorTexture then
            overlayFrame.colorTexture = overlayFrame:CreateTexture(nil, "BORDER")
            overlayFrame.colorTexture:SetAllPoints(overlayFrame)
            overlayFrame.colorTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        end

        overlayFrame.colorTexture:SetVertexColor(color.r, color.g, color.b, 0.3)
        overlayFrame:Show()
    end

    function YourAddon_UpdateItemButton(button, bagID, slotID)
        if not button then return end

        if not button.YourAddonColorOverlay then
            button.YourAddonColorOverlay = CreateFrame("Frame", nil, button)
            button.YourAddonColorOverlay:SetAllPoints(button)
            button.YourAddonColorOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
        end

        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

        if C_Item.DoesItemExist(itemLocation) then
            local itemLink = C_Item.GetItemLink(itemLocation)
            local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemLink and containerInfo then
                YourAddon_ApplyColorOverlay(button.YourAddonColorOverlay, itemLink, containerInfo)
            end
        else
            button.YourAddonColorOverlay:Hide()
        end
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, YourAddon_UpdateItemButton)

end
