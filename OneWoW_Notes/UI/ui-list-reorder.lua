local _, ns = ...
local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local tinsert, tremove = tinsert, tremove

--- Migrate legacy Manual prefs key to Custom.
function ns.UI.NormalizeSortBy(by)
    if by == "manual" then
        return "custom"
    end
    return by
end

function ns.UI.FormatSectionCount(n)
    return "(" .. tostring(n or 0) .. ")"
end

--- Flip the tab into Custom sort mode (visual + prefs). No-op if already Custom.
function ns.UI.EnsureCustomSort(sortHandle, currentSort, prefsKey)
    if not currentSort or currentSort.by == "custom" then
        return
    end
    currentSort.by = "custom"
    currentSort.ascending = true
    if sortHandle and sortHandle.SetSort then
        sortHandle:SetSort("custom", true)
    end
    if prefsKey and ns.db and ns.db.global and ns.db.global.tabSortPrefs then
        ns.db.global.tabSortPrefs[prefsKey] = { by = "custom", ascending = true }
    end
end

--- Bags-style insert math against a section's data array. Rewrites sortOrder 1..n.
--- @return boolean changed
function ns.UI.ApplySectionReorder(sectionArray, fromIdx, toIdx, insertBefore)
    if not sectionArray or not fromIdx or not toIdx then
        return false
    end
    local destIdx = insertBefore and toIdx or (toIdx + 1)
    if destIdx > fromIdx then
        destIdx = destIdx - 1
    end
    if destIdx == fromIdx then
        return false
    end
    local entry = tremove(sectionArray, fromIdx)
    if not entry then
        return false
    end
    tinsert(sectionArray, destIdx, entry)
    for i, item in ipairs(sectionArray) do
        if item.data then
            item.data.sortOrder = i
        end
    end
    return true
end

--- CreateReorderDrag wired for Notes list sections (insert line + auto-scroll).
--- opts: getItems, getScrollFrame, onReorder(fromIdx, toIdx, insertBefore)
function ns.UI.CreateNotesListReorderDrag(opts)
    opts = opts or {}
    local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    return OneWoW_GUI:CreateReorderDrag({
        getItems = opts.getItems,
        dropIndicator = {
            thickness         = 2,
            horizontalPadding = 4,
            color             = { r, g, b, 1 },
        },
        autoScroll = {
            getFrame = opts.getScrollFrame,
            edgeZone = 40,
            maxSpeed = 14,
            minSpeed = 2,
        },
        onReorder = opts.onReorder,
        onPickup = function(row)
            if row and row.SetBackdropBorderColor then
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end
        end,
        onRestore = function(row)
            if not row or not row.SetBackdropBorderColor then
                return
            end
            if row._notesListSelected then
                row:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end,
        onHover = function(row)
            if row and row.SetBackdropBorderColor then
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
        end,
        onUnhover = function(row)
            if not row or not row.SetBackdropBorderColor then
                return
            end
            if row._notesListSelected then
                row:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end,
    })
end
