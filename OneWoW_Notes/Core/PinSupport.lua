local _, ns = ...

local PinSupport = {}
ns.PinSupport = PinSupport

local pinTooltip = CreateFrame("GameTooltip", "OneWoW_NotesPinTooltip", UIParent, "GameTooltipTemplate")

local deferredPins = {}
local deferredGeometrySaves = {}
local worldMapHooked = false

function PinSupport.IsLayoutBlocked()
    return OneWoW.Restriction.IsProtectedActionBlocked()
end

function PinSupport.ShowTooltip(owner, anchor, title, body)
    pinTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    pinTooltip:ClearLines()
    pinTooltip:SetText(title, 1, 1, 1)
    if body then
        pinTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
    end
    pinTooltip:Show()
end

function PinSupport.HideTooltip()
    pinTooltip:Hide()
end

function PinSupport.CachePinSize(pin)
    if PinSupport.IsLayoutBlocked() then return end
    pin._cachedWidth = pin:GetWidth()
    pin._cachedHeight = pin:GetHeight()
end

function PinSupport.GetPinWidth(pin, fallback)
    if PinSupport.IsLayoutBlocked() then
        return pin._cachedWidth or fallback or 300
    end
    local w = pin:GetWidth()
    pin._cachedWidth = w
    return w
end

function PinSupport.GetPinHeight(pin, fallback)
    if PinSupport.IsLayoutBlocked() then
        return pin._cachedHeight or fallback or 400
    end
    local h = pin:GetHeight()
    pin._cachedHeight = h
    return h
end

function PinSupport.GetFrameHeight(frame, fallback)
    if PinSupport.IsLayoutBlocked() then
        return fallback or 20
    end
    return frame:GetHeight()
end

function PinSupport.GetScrollWidth(scrollFrame, fallback, cacheKey)
    if PinSupport.IsLayoutBlocked() then
        return scrollFrame[cacheKey] or fallback or 280
    end
    local w = scrollFrame:GetWidth() or fallback or 280
    scrollFrame[cacheKey] = w
    return w
end

function PinSupport.RegisterDeferredPin(pin)
    deferredPins[pin] = true
    PinSupport.EnsureWorldMapHook()
    -- Recover when the restriction lifts, not only on WorldMapFrame:OnHide.
    OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_Notes.PinSupport", PinSupport.FlushDeferred)
end

function PinSupport.DeferGeometrySave(pin, fn)
    deferredGeometrySaves[pin] = fn
    PinSupport.EnsureWorldMapHook()
    -- Recover when the restriction lifts, not only on WorldMapFrame:OnHide.
    OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_Notes.PinSupport", PinSupport.FlushDeferred)
end

function PinSupport.FlushDeferred()
    PinSupport.HideTooltip()

    for pin, fn in pairs(deferredGeometrySaves) do
        if pin and fn then
            fn()
        end
    end
    wipe(deferredGeometrySaves)

    for pin in pairs(deferredPins) do
        if pin and pin:IsShown() and pin.RefreshLayout then
            pin:RefreshLayout()
        end
    end
    wipe(deferredPins)
end

function PinSupport.EnsureWorldMapHook()
    if worldMapHooked then return end
    worldMapHooked = true

    local function HookWorldMap()
        if not WorldMapFrame then return end
        WorldMapFrame:HookScript("OnShow", PinSupport.HideTooltip)
        WorldMapFrame:HookScript("OnHide", PinSupport.FlushDeferred)
    end

    if WorldMapFrame then
        HookWorldMap()
    else
        C_Timer.After(0, HookWorldMap)
    end
end
