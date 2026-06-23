local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local format = string.format
local floor, abs = math.floor, math.abs

-- ============================================================================
-- Format
-- ============================================================================
-- Suite-wide number and money formatting. Money display preferences
-- (moneyDisplay.*) live in OneWoW_DB and are read through
-- OneWoW_GUI:GetSetting at call time so toggles apply immediately.
-- ============================================================================

local Format = {}
ns.Format = Format

--- Format a number with digit grouping. Uses BreakUpLargeNumbers (client
--- locale) when the regional-numbers setting is on; otherwise US-style
--- comma grouping.
---@param n number|string|nil coerced via tonumber; nil/invalid treated as 0
---@return string
function Format.FormatNumber(n)
    n = floor(tonumber(n) or 0)
    if n < 0 then
        n = abs(n)
    end
    if OneWoW_GUI:GetSetting("moneyDisplay.useRegionalNumbers") then
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

--- Format a copper amount as gold/silver/copper text. Respects the
--- moneyDisplay settings: coin textures vs colored g/s/c letters, and
--- white vs classic-tinted digits in letter mode.
---@param copper number|nil copper amount; nil/non-number treated as 0
---@return string
function Format.FormatGold(copper)
    if copper == nil or type(copper) ~= "number" then
        copper = 0
    else
        copper = floor(tonumber(copper) or 0)
    end

    local useLetters = OneWoW_GUI:GetSetting("moneyDisplay.useLetters")
    local isNegative = copper < 0
    local absCopper = abs(copper)

    if not useLetters then
        return (isNegative and "-" or "") .. C_CurrencyInfo.GetCoinTextureString(absCopper)
    end

    local gold = floor(absCopper / 10000)
    local silver = floor((absCopper % 10000) / 100)
    local cop = absCopper % 100
    local prefix = isNegative and "-" or ""

    if OneWoW_GUI:GetSetting("moneyDisplay.useWhiteValues") then
        local W = "|cFFFFFFFF"
        if gold > 0 then
            return prefix .. format(
                "%s%s|r|cFFFFD100g|r %s%s|r|cFFC0C0C0s|r %s%s|r|cFFAD6A24c|r",
                W, Format.FormatNumber(gold), W, silver, W, cop
            )
        elseif silver > 0 then
            return prefix .. format(
                "%s%s|r|cFFC0C0C0s|r %s%s|r|cFFAD6A24c|r",
                W, silver, W, cop
            )
        else
            return prefix .. format("%s%s|r|cFFAD6A24c|r", W, cop)
        end
    end

    if gold > 0 then
        return prefix .. format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", Format.FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return prefix .. format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return prefix .. format("|cFFAD6A24%dc|r", cop)
    end
end
