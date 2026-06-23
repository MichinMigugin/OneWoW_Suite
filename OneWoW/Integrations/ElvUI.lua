local _, ns = ...

local function IsEnabled()
    return ns.SettingsFeatureRegistry:IsIntegrationEnabled("elvui")
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
            ns.OverlayEngine:ProcessButton(button, link, loc)
        else
            ns.OverlayEngine:CleanButton(button)
        end
    else
        ns.OverlayEngine:CleanButton(button)
    end
end

local wired = false
local function SetupHooks()
    if wired then return end
    local E = ElvUI and ElvUI[1]
    if not E then return end
    local B = E:GetModule("Bags")
    if not B then return end
    wired = true

    elvuiBags = B

    hooksecurefunc(B, "UpdateSlot", function(_, bagID, slotID)
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

    ns.OverlayEngine:RegisterIntegration(RefreshElvUI)
    C_Timer.After(0.5, RefreshElvUI)
end

ns:RegisterAddonLoadedWatcher("ElvUI", SetupHooks)
