local ADDON_NAME, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.betterbags then return true end
    return ov.integrations.betterbags.enabled ~= false
end

local bb_events
local bb_context
local bb_addon

local function ProcessButton(item, decoration)
    if not item or not decoration then return end
    if not IsEnabled() then
        OneWoW.OverlayEngine:CleanButton(decoration)
        return
    end
    if item.isFreeSlot or not item.kind then
        OneWoW.OverlayEngine:CleanButton(decoration)
        return
    end
    local bagid = decoration.bagID
    local slotid = decoration:GetID()
    if bagid == nil or not slotid then
        OneWoW.OverlayEngine:CleanButton(decoration)
        return
    end

    if not decoration.onewow_overlayContainer then
        local bagFrame
        if bagid <= 5 then
            bagFrame = bb_addon and bb_addon.Bags and bb_addon.Bags.Backpack and bb_addon.Bags.Backpack.frame
        else
            bagFrame = bb_addon and bb_addon.Bags and bb_addon.Bags.Bank and bb_addon.Bags.Bank.frame
        end
        if bagFrame then
            local c = CreateFrame("Frame", nil, bagFrame)
            c:SetAllPoints(decoration)
            c:EnableMouse(false)
            c:SetFrameStrata("TOOLTIP")
            c:Hide()
            decoration.onewow_overlayContainer = c
        end
    end

    local loc    = ItemLocation:CreateFromBagAndSlot(bagid, slotid)
    local exists = C_Item.DoesItemExist(loc)
    if exists then
        local link = C_Item.GetItemLink(loc)
        if link then
            OneWoW.OverlayEngine:ProcessButton(decoration, link, loc)
        else
            OneWoW.OverlayEngine:CleanButton(decoration)
        end
    else
        OneWoW.OverlayEngine:CleanButton(decoration)
    end
end

local function SetupHooks()
    if not LibStub then return end
    local AceAddon = LibStub("AceAddon-3.0", true)
    if not AceAddon then return end
    local ok, addon = pcall(function() return AceAddon:GetAddon("BetterBags") end)
    if not ok or not addon then return end

    bb_addon    = addon
    bb_events   = addon:GetModule("Events")
    bb_context  = addon:GetModule("Context")
    if not bb_events or not bb_context then return end

    bb_events:RegisterMessage("item/NewButton", function(_, item, decoration)
        ProcessButton(item, decoration)
    end)

    bb_events:RegisterMessage("item/Updated", function(_, item, decoration)
        ProcessButton(item, decoration)
    end)

    bb_events:RegisterMessage("item/Clearing", function(_, item, decoration)
        if decoration then
            OneWoW.OverlayEngine:CleanButton(decoration)
        end
    end)

    local function RefreshBetterBags()
        if not bb_events or not bb_context then return end
        local ctx = bb_context:New("OneWoW")
        bb_events:SendMessage(ctx, "bags/FullRefreshAll")
    end

    OneWoW.OverlayEngine:RegisterIntegration(RefreshBetterBags)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if C_AddOns.IsAddOnLoaded("BetterBags") then
        SetupHooks()
    end
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)
