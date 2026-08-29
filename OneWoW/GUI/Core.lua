-- Shared UI toolkit, published as a plain global (absorbed into the OneWoW
-- load unit — see Docs/ARCHITECTURE.md §8.1). Not a LibStub library.
OneWoW_GUI = OneWoW_GUI or {}
local OneWoW_GUI = OneWoW_GUI

OneWoW_GUI.noop = function() end

-- WoW has this function but it was deprecated in 10.2.6.
-- Accounts for color overrides in game accessibility settings
function OneWoW_GUI:GetItemQualityColor(quality)
    local t = ColorManager.GetColorDataForItemQuality(quality or 1)
    local colorMixin = t.color
    -- Returns r, g, b, a floats
    return colorMixin:GetRGBA()
end

-- Save frame position (and size if resizable) into storage table.
-- Call from frame's OnHide script. Storage shape: { point, relativePoint, x, y, width?, height? }
function OneWoW_GUI:SaveWindowPosition(frame, storage)
    if not frame or not storage then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    storage.point = point
    storage.relativePoint = relativePoint
    storage.x = x
    storage.y = y
    if frame.GetWidth and frame.GetHeight then
        storage.width = frame:GetWidth()
        storage.height = frame:GetHeight()
    end
end

-- Restore frame position/size from storage. Returns true if restored.
-- Call after creating frame, before first Show. Caller should SetPoint("CENTER") if false.
-- Clamps restored size to the screen. On first show, nudges partial overflow back
-- on-screen; centers only when the frame is fully off-screen (lost-window salvage).
-- Corrected size/point are written back to storage so a reload keeps the fix.
function OneWoW_GUI:RestoreWindowPosition(frame, storage)
    if not frame or not storage or not storage.point then return false end
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    frame:ClearAllPoints()
    frame:SetPoint(storage.point, UIParent, storage.relativePoint, storage.x, storage.y)
    if storage.width and storage.height and frame.SetSize then
        frame:SetSize(math.min(storage.width, sw), math.min(storage.height, sh))
    end
    frame._owgPositionStorage = storage
    frame._owgNeedsBoundsCheck = true
    if not frame._owgBoundsHooked then
        frame._owgBoundsHooked = true
        frame:HookScript("OnShow", function(myself)
            if not myself._owgNeedsBoundsCheck then return end
            myself._owgNeedsBoundsCheck = false
            C_Timer.After(0, function()
                if not myself:IsShown() then return end
                local l, b, r, t = myself:GetLeft(), myself:GetBottom(), myself:GetRight(), myself:GetTop()
                if not l or not b or not r or not t then return end
                local screenW, screenH = GetScreenWidth(), GetScreenHeight()
                local changed = false
                local w, h = r - l, t - b
                if w > screenW or h > screenH then
                    w = math.min(w, screenW)
                    h = math.min(h, screenH)
                    myself:SetSize(w, h)
                    l, b, r, t = myself:GetLeft(), myself:GetBottom(), myself:GetRight(), myself:GetTop()
                    if not l or not b or not r or not t then return end
                    changed = true
                end
                if r < 0 or l > screenW or t < 0 or b > screenH then
                    myself:ClearAllPoints()
                    myself:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    changed = true
                else
                    local dx, dy = 0, 0
                    if l < 0 then
                        dx = -l
                    elseif r > screenW then
                        dx = screenW - r
                    end
                    if b < 0 then
                        dy = -b
                    elseif t > screenH then
                        dy = screenH - t
                    end
                    if dx ~= 0 or dy ~= 0 then
                        myself:ClearAllPoints()
                        myself:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dx, b + dy)
                        changed = true
                    end
                end
                if changed and myself._owgPositionStorage then
                    OneWoW_GUI:SaveWindowPosition(myself, myself._owgPositionStorage)
                end
            end)
        end)
    end
    return true
end

function OneWoW_GUI:ClearFrame(frame)
    if not frame then return end
    frame._onewowZebraSeq = nil
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end
