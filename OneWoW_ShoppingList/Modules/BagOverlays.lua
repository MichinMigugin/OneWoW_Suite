local ADDON_NAME, ns = ...

ns.BagOverlays = {}
local BagOverlays = ns.BagOverlays

local overlayPool = {}
local activeOverlays = {}
local refreshPending = false

local function GetOverlaySettings()
    local db = OneWoW_ShoppingList_DB
    if not db or not db.global or not db.global.settings then
        return { enabled = true, position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0 }
    end
    return db.global.settings.overlay or { enabled = true, position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0 }
end

local function GetOrCreateOverlay(button)
    if button._owsl_overlay then
        return button._owsl_overlay
    end

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 3)

    local tex = overlay:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("Perks-ShoppingCart")
    overlay.tex = tex

    button._owsl_overlay = overlay
    table.insert(overlayPool, overlay)

    return overlay
end

local function PositionTexture(tex, overlay, settings)
    local pos      = settings.position or "BOTTOMRIGHT"
    local size     = 28 * (settings.scale or 1.0)
    local alpha    = settings.alpha or 1.0
    local offsets  = {
        TOPLEFT     = {  1, -1 },
        TOPRIGHT    = { -1, -1 },
        BOTTOMLEFT  = {  1,  1 },
        BOTTOMRIGHT = { -1,  1 },
        TOP         = {  0, -1 },
        BOTTOM      = {  0,  1 },
        LEFT        = {  1,  0 },
        RIGHT       = { -1,  0 },
        CENTER      = {  0,  0 },
    }
    local outerData = {
        ["Outer-Top-Left"]      = { "TOPLEFT",     4, -4 },
        ["Outer-Top-Middle"]    = { "TOP",         0, -4 },
        ["Outer-Top-Right"]     = { "TOPRIGHT",   -4, -4 },
        ["Outer-Bottom-Left"]   = { "BOTTOMLEFT",  4,  4 },
        ["Outer-Bottom-Middle"] = { "BOTTOM",      0,  4 },
        ["Outer-Bottom-Right"]  = { "BOTTOMRIGHT",-4,  4 },
    }

    tex:ClearAllPoints()
    tex:SetSize(size, size)
    local outer = outerData[pos]
    if outer then
        tex:SetPoint("CENTER", overlay, outer[1], outer[2], outer[3])
    else
        local off = offsets[pos] or offsets["BOTTOMRIGHT"]
        tex:SetPoint(pos, overlay, pos, off[1], off[2])
    end
    tex:SetAlpha(alpha)
end

local function UpdateButtonOverlay(button, bag, slot)
    if not button then return end

    local settings = GetOverlaySettings()

    if not settings.enabled then
        if button._owsl_overlay then
            button._owsl_overlay:Hide()
        end
        activeOverlays[button] = nil
        return
    end

    bag  = bag  or (button.Parent and button.Parent.ContainerId)
    slot = slot or button.SlotIndex

    if not bag or not slot then
        if button._owsl_overlay then button._owsl_overlay:Hide() end
        activeOverlays[button] = nil
        return
    end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then
        if button._owsl_overlay then button._owsl_overlay:Hide() end
        activeOverlays[button] = nil
        return
    end

    local isOnList = ns.ShoppingList:IsOnAnyList(info.itemID)

    if isOnList then
        local overlay = GetOrCreateOverlay(button)
        PositionTexture(overlay.tex, overlay, settings)
        overlay:Show()
        activeOverlays[button] = true
    else
        if button._owsl_overlay then button._owsl_overlay:Hide() end
        activeOverlays[button] = nil
    end
end

function BagOverlays:RefreshAll()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.1, function()
        refreshPending = false
        self:DoRefresh()
    end)
end

function BagOverlays:DoRefresh()
    local settings = GetOverlaySettings()
    if not settings.enabled then
        for button in pairs(activeOverlays) do
            if button._owsl_overlay then button._owsl_overlay:Hide() end
        end
        wipe(activeOverlays)
        return
    end

    if _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsVisible() then
        if _G.ContainerFrameCombinedBags.EnumerateValidItems then
            for _, button in _G.ContainerFrameCombinedBags:EnumerateValidItems() do
                if button and button.GetBagID and button.GetID then
                    UpdateButtonOverlay(button, button:GetBagID(), button:GetID())
                end
            end
        end
    else
        for bagID = 0, 4 do
            local frame = _G["ContainerFrame" .. (bagID + 1)]
            if frame and frame:IsVisible() then
                local numSlots = C_Container.GetContainerNumSlots(bagID)
                for slot = 1, (numSlots or 0) do
                    local btn = _G["ContainerFrame" .. (bagID + 1) .. "Item" .. slot]
                    if btn then
                        UpdateButtonOverlay(btn, bagID, slot)
                    end
                end
            end
        end
    end
end

function BagOverlays:UpdateAllSettings()
    local settings = GetOverlaySettings()
    for button in pairs(activeOverlays) do
        if button._owsl_overlay and button._owsl_overlay.tex then
            PositionTexture(button._owsl_overlay.tex, button._owsl_overlay, settings)
        end
    end
end

function BagOverlays:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("BAG_OPEN")
    frame:SetScript("OnEvent", function()
        C_Timer.After(0.3, function()
            BagOverlays:DoRefresh()
        end)
    end)
end
