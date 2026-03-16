--[[
OneWoW Bags Integration for TransmogLootHelper
================================================

This file allows TransmogLootHelper to add transmog loot markers/overlays to items
displayed in OneWoW Bags.

Place this file in: TransmogLootHelper/integrations/OneWoWBags.lua
Then add it to TransmogLootHelper.toc as:
Integrations\OneWoWBags.lua
]]

local appName, app = ...                                                                                                   
   
  if _G.OneWoW_Bags then                                                                                                     
                                                                  
        local function UpdateItemButton(button, bagID, slotID)
                if not button then return end

                if not button.TLHOverlay then
                        button.TLHOverlay = CreateFrame("Frame", nil, button)
                        button.TLHOverlay:SetAllPoints(button)
                        button.TLHOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
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
