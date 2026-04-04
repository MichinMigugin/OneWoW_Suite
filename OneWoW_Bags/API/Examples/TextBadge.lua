--[[
OneWoW Bags Integration - Text Badge Example

Shows how to add a text badge to items. This example displays item prices,
but you can modify it to show any text-based information.

Instructions:
1. Copy to: YourAddon/Integrations/OneWoWBags.lua
2. Add to .toc: Integrations\OneWoWBags.lua
3. Modify YourAddon_GetItemValue() to return your custom data
]]

local ADDON_NAME = ...

if _G.OneWoW_Bags then

    function YourAddon_GetItemValue(itemLink)
        -- This function should return the value you want to display
        -- Example: look up in a pricing database

        if not itemLink then return nil end

        -- Parse item ID from link
        local itemID = tonumber(itemLink:match("item:(%d+)"))
        if not itemID then return nil end

        -- Example: lookup in your price database
        -- return MyPriceDatabase[itemID]

        -- For now, just return a placeholder
        return itemID % 1000
    end

    function YourAddon_ApplyTextBadge(overlayFrame, itemLink, containerInfo)
        if not overlayFrame or not itemLink then
            overlayFrame:Hide()
            return
        end

        local value = YourAddon_GetItemValue(itemLink)
        if not value then
            overlayFrame:Hide()
            return
        end

        -- Create or update badge frame
        if not overlayFrame.badgeFrame then
            overlayFrame.badgeFrame = CreateFrame("Frame", nil, overlayFrame)
            overlayFrame.badgeFrame:SetSize(16, 16)
            overlayFrame.badgeFrame:SetPoint("BOTTOMRIGHT", overlayFrame, "BOTTOMRIGHT", -2, 2)

            -- Badge background
            overlayFrame.badgeFrame.bg = overlayFrame.badgeFrame:CreateTexture(nil, "BACKGROUND")
            overlayFrame.badgeFrame.bg:SetAllPoints()
            overlayFrame.badgeFrame.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            overlayFrame.badgeFrame.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

            -- Badge text
            overlayFrame.badgeFrame.text = overlayFrame.badgeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            overlayFrame.badgeFrame.text:SetAllPoints()
            overlayFrame.badgeFrame.text:SetJustifyH("CENTER")
            overlayFrame.badgeFrame.text:SetJustifyV("MIDDLE")
        end

        -- Update badge text
        overlayFrame.badgeFrame.text:SetText(tostring(value))
        overlayFrame:Show()
    end

    function YourAddon_UpdateItemButton(button, bagID, slotID)
        if not button then return end

        if not button.YourAddonTextBadge then
            button.YourAddonTextBadge = CreateFrame("Frame", nil, button)
            button.YourAddonTextBadge:SetAllPoints(button)
            button.YourAddonTextBadge:SetFrameLevel(button:GetFrameLevel() + 1)
        end

        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

        if C_Item.DoesItemExist(itemLocation) then
            local itemLink = C_Item.GetItemLink(itemLocation)
            local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemLink and containerInfo then
                YourAddon_ApplyTextBadge(button.YourAddonTextBadge, itemLink, containerInfo)
            end
        else
            button.YourAddonTextBadge:Hide()
        end
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, YourAddon_UpdateItemButton)

end
