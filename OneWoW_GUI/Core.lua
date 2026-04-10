local MAJOR, MINOR = "OneWoW_GUI-1.0", 9
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
    frame._owgNeedsBoundsCheck = true
    if not frame._owgBoundsHooked then
        frame._owgBoundsHooked = true
        frame:HookScript("OnShow", function(self)
            if not self._owgNeedsBoundsCheck then return end
            self._owgNeedsBoundsCheck = false
            C_Timer.After(0, function()
                if not self:IsShown() then return end
                local l, b, r, t = self:GetLeft(), self:GetBottom(), self:GetRight(), self:GetTop()
                if not l or not b or not r or not t then return end
                local sw, sh = GetScreenWidth(), GetScreenHeight()
                if l < 0 or b < 0 or r > sw or t > sh then
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end)
        end)
    end
    return true
end

--- Use BreakUpLargeNumbers (client locale) when enabled; otherwise US-style comma grouping.
function OneWoW_GUI:UseRegionalMoneyNumbers()
    local db = self._settingsDB
    if not db or not db.moneyDisplay then
        return true
    end
    return db.moneyDisplay.useRegionalNumbers ~= false
end

--- When true, show colored g/s/c text. When false, use Blizzard coin textures.
function OneWoW_GUI:UseMoneyLetters()
    local db = self._settingsDB
    if not db or not db.moneyDisplay then
        return false
    end
    return db.moneyDisplay.useLetters == true
end

--- When true (letter mode), show amounts in white; when false, classic gold/silver/copper tint on digits too.
function OneWoW_GUI:UseMoneyWhiteValues()
    local db = self._settingsDB
    if not db or not db.moneyDisplay then
        return true
    end
    return db.moneyDisplay.useWhiteValues ~= false
end

function OneWoW_GUI:FormatNumber(n)
    n = math.floor(tonumber(n) or 0)
    if n < 0 then
        n = math.abs(n)
    end
    if self:UseRegionalMoneyNumbers() and type(BreakUpLargeNumbers) == "function" then
        local formatted = BreakUpLargeNumbers(n)
        if formatted and formatted ~= "" then
            return formatted
        end
    end
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
    if copper == nil or type(copper) ~= "number" then
        copper = 0
    else
        copper = math.floor(tonumber(copper) or 0)
    end

    local useLetters = self:UseMoneyLetters()
    local isNegative = copper < 0
    local absCopper = math.abs(copper)

    if not useLetters then
        local texFn = _G.GetCoinTextureString
            or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
        if texFn then
            local ok, result = pcall(texFn, absCopper)
            if ok and result and result ~= "" then
                return (isNegative and "-" or "") .. result
            end
        end
        useLetters = true
    end

    local gold = math.floor(absCopper / 10000)
    local silver = math.floor((absCopper % 10000) / 100)
    local cop = absCopper % 100
    local prefix = isNegative and "-" or ""

    if self:UseMoneyWhiteValues() then
        local W = "|cFFFFFFFF"
        if gold > 0 then
            return prefix .. string.format(
                "%s%s|r|cFFFFD100g|r %s%s|r|cFFC0C0C0s|r %s%s|r|cFFAD6A24c|r",
                W, self:FormatNumber(gold), W, silver, W, cop
            )
        elseif silver > 0 then
            return prefix .. string.format(
                "%s%s|r|cFFC0C0C0s|r %s%s|r|cFFAD6A24c|r",
                W, silver, W, cop
            )
        else
            return prefix .. string.format("%s%s|r|cFFAD6A24c|r", W, cop)
        end
    end

    if gold > 0 then
        return prefix .. string.format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", self:FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return prefix .. string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return prefix .. string.format("|cFFAD6A24%dc|r", cop)
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