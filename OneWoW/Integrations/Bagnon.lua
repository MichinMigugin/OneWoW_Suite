local ADDON_NAME, OneWoW = ...

local function IsEnabled()
    local ov = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    if not ov or not ov.integrations or not ov.integrations.bagnon then return true end
    return ov.integrations.bagnon.enabled ~= false
end

local function ProcessBagnonButton(button)
    if not IsEnabled() then
        OneWoW.OverlayEngine:CleanButton(button)
        return
    end
    if button.info and button.info.cached then
        OneWoW.OverlayEngine:CleanButton(button)
        return
    end
    local bag  = button.bag
    local slot = button:GetID()
    local loc  = ItemLocation:CreateFromBagAndSlot(bag, slot)
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

local function SetupHooks()
    if not BagBrother then return end

    hooksecurefunc("SetItemButtonTexture", function(button)
        if button.bag ~= nil then
            ProcessBagnonButton(button)
        end
    end)

    local function RefreshBagnon()
        if not BagBrother or not BagBrother.Frames then return end
        BagBrother.Frames:Update()
    end

    OneWoW.OverlayEngine:RegisterIntegration(RefreshBagnon)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if C_AddOns.IsAddOnLoaded("Bagnon") then
        SetupHooks()
    end
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)
