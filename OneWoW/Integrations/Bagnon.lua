local _, ns = ...

local function IsEnabled()
    return ns.SettingsFeatureRegistry:IsIntegrationEnabled("bagnon")
end

local function ProcessBagnonButton(button)
    if not IsEnabled() then
        ns.OverlayEngine:CleanButton(button)
        return
    end
    if button.info and button.info.cached then
        ns.OverlayEngine:CleanButton(button)
        return
    end
    local bag  = button.bag
    local slot = button:GetID()
    local loc  = ItemLocation:CreateFromBagAndSlot(bag, slot)
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

    ns.OverlayEngine:RegisterIntegration(RefreshBagnon)
end

ns:RegisterCoreLoginHandler("Bagnon", function()
    if C_AddOns.IsAddOnLoaded("Bagnon") then
        SetupHooks()
    end
end)
