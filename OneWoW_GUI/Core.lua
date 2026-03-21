local MAJOR, MINOR = "OneWoW_GUI-1.0", 3
local OneWoW_GUI, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)

if not OneWoW_GUI then return end

OneWoW_GUI.noop = function() end

local issecretvalue_fn = issecretvalue or function() return false end
local issecrettable_fn = issecrettable or function() return false end

--- True if value must not be used in addon logic or persisted (Midnight secret system).
function OneWoW_GUI:IsSecret(value)
    if issecretvalue_fn(value) then
        return true
    end
    if type(value) == "table" and issecrettable_fn(value) then
        return true
    end
    return false
end

function OneWoW_GUI:GetAddonVersion(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then return nil end
    return C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
end

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
function OneWoW_GUI:RestoreWindowPosition(frame, storage)
    if not frame or not storage or not storage.point then return false end
    frame:ClearAllPoints()
    frame:SetPoint(storage.point, UIParent, storage.relativePoint, storage.x, storage.y)
    if storage.width and storage.height and frame.SetSize then
        frame:SetSize(storage.width, storage.height)
    end
    return true
end

function OneWoW_GUI:FormatNumber(n)
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local parts = { s:sub(1, pos) }
    for i = pos + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return table.concat(parts, ",")
end

function OneWoW_GUI:FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", self:FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
end

function OneWoW_GUI:ClearFrame(frame)
    if not frame then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end