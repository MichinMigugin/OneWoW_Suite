local ADDON_NAME, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.elvui then return true end
    return ov.integrations.elvui.enabled ~= false
end

local elvuiBags = nil

local function GetSlotButton(bagID, slotID)
    if not elvuiBags then return nil end
    if elvuiBags.BagFrame and elvuiBags.BagFrame.Bags then
        local b = elvuiBags.BagFrame.Bags[bagID]
        if b and b[slotID] then return b[slotID] end
    end
    return nil
end

local function ProcessSlot(bagID, slotID)
    if not IsEnabled() then return end
    local button = GetSlotButton(bagID, slotID)
    if not button then return end

    if not button.onewow_overlayContainer then
        local bagFrame = elvuiBags.BagFrame
        if bagFrame then
            local c = CreateFrame("Frame", nil, bagFrame)
            c:SetAllPoints(button)
            c:EnableMouse(false)
            c:SetFrameStrata("TOOLTIP")
            c:Hide()
            button.onewow_overlayContainer = c
        end
    end

    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if C_Item.DoesItemExist(loc) then
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

local function SetupHooks()
    local E = ElvUI and ElvUI[1]
    if not E then return end
    local B = E:GetModule("Bags")
    if not B then return end

    elvuiBags = B

    hooksecurefunc(B, "UpdateSlot", function(self, bagID, slotID)
        ProcessSlot(bagID, slotID)
    end)

    local function RefreshElvUI()
        if not elvuiBags or not elvuiBags.BagFrame then return end
        if not elvuiBags.BagFrame:IsVisible() then return end
        for bagID = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                ProcessSlot(bagID, slotID)
            end
        end
    end

    OneWoW.OverlayEngine:RegisterIntegration(RefreshElvUI)
    C_Timer.After(0.5, RefreshElvUI)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if C_AddOns.IsAddOnLoaded("ElvUI") then
        SetupHooks()
    end
    eventFrame:UnregisterEvent("PLAYER_LOGIN")
end)
