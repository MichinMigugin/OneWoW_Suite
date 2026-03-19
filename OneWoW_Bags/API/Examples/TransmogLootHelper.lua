--[[
OneWoW Bags Integration - TransmogLootHelper Example

This is a real-world example showing how TransmogLootHelper integrates with OneWoW Bags.

TransmogLootHelper provides transmog loot marking overlays on items. This integration
adds those same overlays to items displayed in OneWoW Bags.

Instructions for TransmogLootHelper devs:
1. Copy to: TransmogLootHelper/Integrations/OneWoWBags.lua
2. Add to .toc: Integrations\OneWoWBags.lua
3. Done! The integration will automatically activate.
]]

local appName, app = ...                                                                                                   
   
  if _G.OneWoW_Bags then                                                                                                     
                                                                  
        local debugCount = 0

        local function UpdateItemButton(button, bagID, slotID)
                if not button then return end

                if not button.TLHOverlay then
                        button.TLHOverlay = CreateFrame("Frame", nil, button)
                        button.TLHOverlay:SetAllPoints(button)
                        button.TLHOverlay:SetFrameLevel(button:GetFrameLevel() + 1)

                        debugCount = debugCount + 1
                end

                local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

                if C_Item.DoesItemExist(itemLocation) then
                        local itemLink = C_Item.GetItemLink(itemLocation)
                        local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                        if itemLink and containerInfo then
                                app:ApplyItemOverlay(button.TLHOverlay, itemLink, itemLocation, containerInfo)
                        end
                else
                        button.TLHOverlay:Hide()
                end
        end

        _G.OneWoW_Bags:RegisterItemButtonCallback("TransmogLootHelper", UpdateItemButton)

  end
