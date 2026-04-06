local ADDON_NAME, Addon = ...

local ColorTools = {}
Addon.ColorTools = ColorTools

--- Cached class color rows for the Color Tools tab (WoW API data).
function ColorTools:GetClassColorRows()
    if self._classRows then
        return self._classRows
    end
    local keys = {}
    for key, _ in pairs(RAID_CLASS_COLORS) do
        if key ~= "ADVENTURER" and key ~= "TRAVELER" then
            tinsert(keys, key)
        end
    end
    sort(keys)
    local rows = {}
    for _, className in ipairs(keys) do
        tinsert(rows, {
            colorMixin = RAID_CLASS_COLORS[className],
            className = LOCALIZED_CLASS_NAMES_MALE[className],
        })
    end
    self._classRows = rows
    return rows
end

--- Parse "RRGGBB" into 0–1 RGB components (alpha = 1).
function ColorTools:HexToRGB(hex)
    if not hex or #hex < 6 then
        return 1, 1, 1
    end
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end
