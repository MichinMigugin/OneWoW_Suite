-- ============================================================================
-- OneWoW_AltTracker/UI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- This file only maps library calls into the local ns.UI namespace.
-- If you need a new UI function, add it to OneWoW_GUI/OneWoW_GUI.lua first,
-- then add a thin wrapper here.
-- ============================================================================
local addonName, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function ns.UI.CreateSearchBox(parent, options)
    return OneWoW_GUI:CreateEditBox(parent, options)
end

function ns.UI.ClearFrame(frame)
    return OneWoW_GUI:ClearFrame(frame)
end

function ns.UI.CreateDialog(config)
    return OneWoW_GUI:CreateDialog(config)
end

function ns.UI.CreateConfirmDialog(config)
    return OneWoW_GUI:CreateConfirmDialog(config)
end

function ns.UI.CreateFilterBar(parent, config)
    return OneWoW_GUI:CreateFilterBar(parent, config)
end

-- Weak-keyed registry of all visible mail icon cells, keyed by the cell frame
-- itself. Values are the charKey the cell belongs to. Weak keys let orphaned
-- cells (from rebuilt tabs) be garbage collected automatically.
ns.UI.mailIconCells = ns.UI.mailIconCells or setmetatable({}, { __mode = "k" })

-- Returns the live mail summary for a character or nil if no data exists.
-- Drops already-expired entries on the fly, so the count never includes mail
-- the server has deleted.
function ns.UI.GetMailSummaryForChar(charKey)
    if not charKey then return nil end
    local api = StorageAPI
    if api and api.GetMailSummary then
        return api.GetMailSummary(charKey)
    end
    return nil
end

-- True if the character has any non-expired mail in storage. Falls back to the
-- legacy hasNewMail flag for characters whose data hasn't been re-scanned
-- since the fix landed.
function ns.UI.GetHasMailForChar(charKey)
    if not charKey then return false end

    local summary = ns.UI.GetMailSummaryForChar(charKey)
    if summary then
        return summary.hasAnyMail == true or summary.count > 0
    end

    local storageDB = OneWoW_AltTracker_Storage_DB
    if storageDB and storageDB.characters then
        local sc = storageDB.characters[charKey]
        if sc and sc.mail then
            return sc.mail.hasAnyMail == true or sc.mail.hasNewMail == true
        end
    end
    return false
end

local function ApplyMailCellState(cell, hasMail)
    if not cell or not cell.icon then return end
    if hasMail then
        cell.icon:SetVertexColor(1, 1, 0, 1)
    else
        cell.icon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    end
end

-- Formats seconds remaining as a compact "Xd Yh" / "Xh Ym" / "<1m" string
-- using the existing FMT_* locale tokens.
local function FormatRemaining(seconds)
    if not seconds or seconds <= 0 then return ns.L["FMT_LESS_THAN_MINUTE"] end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return string.format("%d%s %d%s", days, ns.L["FMT_DAY_SHORT"], hours, ns.L["FMT_HOUR_SHORT"])
    elseif hours > 0 then
        return string.format("%d%s %d%s", hours, ns.L["FMT_HOUR_SHORT"], minutes, ns.L["FMT_MINUTE_SHORT"])
    elseif minutes > 0 then
        return string.format("%d%s", minutes, ns.L["FMT_MINUTE_SHORT"])
    end
    return ns.L["FMT_LESS_THAN_MINUTE"]
end

local function FormatAgo(epoch)
    if not epoch or epoch <= 0 then return ns.L["FMT_NEVER"] end
    local diff = time() - epoch
    if diff < 60 then return ns.L["FMT_NOW"] end
    return FormatRemaining(diff)
end

-- Shared tooltip renderer for mail icons. Public so the detail popup helper
-- (UI/MailDetail.lua) can reuse the exact same formatting.
function ns.UI.ShowMailTooltip(anchor, charKey)
    if not anchor or not charKey then return end
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

    local charData = OneWoW_AltTracker_Character_DB
        and OneWoW_AltTracker_Character_DB.characters
        and OneWoW_AltTracker_Character_DB.characters[charKey]
    local title = (charData and charData.name) or charKey
    local classColor = charData and charData.class and RAID_CLASS_COLORS[charData.class]
    if classColor then
        GameTooltip:SetText(title, classColor.r, classColor.g, classColor.b)
    else
        GameTooltip:SetText(title, 1, 1, 1)
    end

    local summary = ns.UI.GetMailSummaryForChar(charKey)
    if not summary or summary.count == 0 then
        GameTooltip:AddLine(ns.L["TT_MAIL_NONE"], 0.7, 0.7, 0.7)
        if summary and summary.lastScan and summary.lastScan > 0 then
            GameTooltip:AddLine(string.format(ns.L["TT_MAIL_LAST_SCAN"], FormatAgo(summary.lastScan)), 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine(ns.L["TT_MAIL_NEVER_SCANNED"], 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
        return
    end

    GameTooltip:AddLine(string.format(ns.L["TT_MAIL_COUNT"], summary.count), 1, 1, 1)

    if summary.oldestExpirySeconds then
        local color = { 0.5, 1, 0.5 }
        local days = summary.oldestExpirySeconds / 86400
        if days < 1 then color = { 1, 0.4, 0.4 }
        elseif days < 5 then color = { 1, 0.8, 0.2 }
        end
        GameTooltip:AddLine(
            string.format(ns.L["TT_MAIL_OLDEST"], FormatRemaining(summary.oldestExpirySeconds)),
            color[1], color[2], color[3]
        )
    end

    if summary.hasCOD then
        GameTooltip:AddLine(ns.L["TT_MAIL_HAS_COD"], 1, 0.6, 0.2)
    end
    if summary.hasReturned then
        GameTooltip:AddLine(ns.L["TT_MAIL_HAS_RETURNED"], 0.9, 0.7, 0.4)
    end

    if summary.lastScan and summary.lastScan > 0 then
        GameTooltip:AddLine(string.format(ns.L["TT_MAIL_LAST_SCAN"], FormatAgo(summary.lastScan)), 0.5, 0.5, 0.5)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(ns.L["TT_MAIL_CLICK_HINT"], 0.7, 0.85, 1)
    GameTooltip:Show()
end

function ns.UI.RegisterMailIconCell(cell, charKey)
    if not cell or not charKey then return end
    ns.UI.mailIconCells[cell] = charKey

    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(self)
        ns.UI.ShowMailTooltip(self, charKey)
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    cell:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and ns.UI.ShowMailDetail then
            ns.UI.ShowMailDetail(charKey)
        end
    end)
end

-- Cheap in-place refresh: walks the registered mail icon cells and re-skins
-- each one from current storage. Does NOT rebuild rows, so it's safe to call
-- any time (e.g. from UPDATE_PENDING_MAIL) without flashing the UI.
function ns.UI.RefreshMailIcons()
    if not ns.UI.mailIconCells then return end
    for cell, charKey in pairs(ns.UI.mailIconCells) do
        ApplyMailCellState(cell, ns.UI.GetHasMailForChar(charKey))
    end
end

-- Expose the refresh to other addons (Storage calls this from DataManager).
OneWoW_AltTracker = OneWoW_AltTracker or {}
OneWoW_AltTracker.UI = OneWoW_AltTracker.UI or {}
OneWoW_AltTracker.UI.RefreshMailIcons = ns.UI.RefreshMailIcons

function ns.UI.GetSortedCharacters(getSortValue, sortColumn, sortAscending)
    if not OneWoW_AltTracker_Character_DB or not OneWoW_AltTracker_Character_DB.characters then return {} end
    local allChars = {}
    for charKey, charData in pairs(OneWoW_AltTracker_Character_DB.characters) do
        allChars[#allChars + 1] = { key = charKey, data = charData }
    end
    if #allChars == 0 then return allChars end
    local currentCharKey = OneWoW_GUI:GetCharacterKey()
    table.sort(allChars, function(a, b)
        local aFav = ns.IsFavoriteChar(a.key)
        local bFav = ns.IsFavoriteChar(b.key)
        if aFav and not bFav then return true end
        if bFav and not aFav then return false end
        local aIsCurrent = (a.key == currentCharKey)
        local bIsCurrent = (b.key == currentCharKey)
        if aIsCurrent and not bIsCurrent then return true end
        if bIsCurrent and not aIsCurrent then return false end
        if sortColumn and getSortValue then
            local aVal = getSortValue(a.key, a.data, sortColumn)
            local bVal = getSortValue(b.key, b.data, sortColumn)
            if aVal ~= nil and bVal ~= nil then
                if sortAscending then return aVal < bVal else return aVal > bVal end
            end
        end
        return (a.data.name or "") < (b.data.name or "")
    end)
    return allChars
end

function ns.UI.AddCommonCells(charRow, charKey, charData)
    if ns.UI.CreateFavoriteStarButton then
        table.insert(charRow.cells, 2, ns.UI.CreateFavoriteStarButton(charRow, charKey))
    end
    local factionCell = OneWoW_GUI:CreateFactionIcon(charRow, { faction = charData.faction })
    table.insert(charRow.cells, factionCell)
    local hasMail = ns.UI.GetHasMailForChar(charKey)
    local mailCell = OneWoW_GUI:CreateMailIcon(charRow, { hasMail = hasMail })
    table.insert(charRow.cells, mailCell)
    charRow.mailCell = mailCell
    ns.UI.RegisterMailIconCell(mailCell, charKey)
    local nameText = OneWoW_GUI:CreateFS(charRow, 12)
    nameText:SetText(charData.name or charKey)
    local classColor = RAID_CLASS_COLORS[charData.class]
    if classColor then
        nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    nameText:SetJustifyH("LEFT")
    table.insert(charRow.cells, nameText)
    return nameText
end

function ns.UI.AddLevelCell(charRow, charData)
    local levelText = OneWoW_GUI:CreateFS(charRow, 12)
    levelText:SetText(tostring(charData.level or 0))
    levelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    table.insert(charRow.cells, levelText)
    return levelText
end

function ns.IsFavoriteChar(charKey)
    local db = OneWoW_AltTracker and OneWoW_AltTracker.db and OneWoW_AltTracker.db.global
    return db and db.favorites and db.favorites[charKey] == true
end

function ns.SetFavoriteChar(charKey, value)
    local addon = OneWoW_AltTracker
    if not addon or not addon.db then return end
    if not addon.db.global.favorites then
        addon.db.global.favorites = {}
    end
    addon.db.global.favorites[charKey] = value and true or nil
end

function ns.IsFavoriteBarSet(setName)
    if not setName then return false end
    local db = OneWoW_AltTracker and OneWoW_AltTracker.db and OneWoW_AltTracker.db.global
    return db and db.favoriteBarSets and db.favoriteBarSets[setName] == true
end

function ns.SetFavoriteBarSet(setName, value)
    local addon = OneWoW_AltTracker
    if not addon or not addon.db or not setName then return end
    if not addon.db.global.favoriteBarSets then
        addon.db.global.favoriteBarSets = {}
    end
    addon.db.global.favoriteBarSets[setName] = value and true or nil
end

function ns.IsFavoriteItem(itemID)
    if not itemID then return false end
    local db = OneWoW_AltTracker and OneWoW_AltTracker.db and OneWoW_AltTracker.db.global
    return db and db.favoriteItems and db.favoriteItems[tostring(itemID)] == true
end

function ns.SetFavoriteItem(itemID, value)
    local addon = OneWoW_AltTracker
    if not addon or not addon.db or not itemID then return end
    if not addon.db.global.favoriteItems then
        addon.db.global.favoriteItems = {}
    end
    local k = tostring(itemID)
    addon.db.global.favoriteItems[k] = value and true or nil
end
