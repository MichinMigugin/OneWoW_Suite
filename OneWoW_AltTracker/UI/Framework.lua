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

function ns.UI.GetHasMailForChar(charKey)
    if not charKey then return false end

    local api = _G.StorageAPI
    if api and api.GetMail then
        local mailData = api.GetMail(charKey)
        return mailData and mailData.hasNewMail and true or false
    end

    local storageDB = _G.OneWoW_AltTracker_Storage_DB
    if storageDB and storageDB.characters then
        local sc = storageDB.characters[charKey]
        return sc and sc.mail and sc.mail.hasNewMail and true or false
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

function ns.UI.RegisterMailIconCell(cell, charKey)
    if not cell or not charKey then return end
    ns.UI.mailIconCells[cell] = charKey
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
_G.OneWoW_AltTracker = _G.OneWoW_AltTracker or {}
_G.OneWoW_AltTracker.UI = _G.OneWoW_AltTracker.UI or {}
_G.OneWoW_AltTracker.UI.RefreshMailIcons = ns.UI.RefreshMailIcons

function ns.UI.GetSortedCharacters(getSortValue, sortColumn, sortAscending)
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return {} end
    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
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
    local db = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global
    return db and db.favorites and db.favorites[charKey] == true
end

function ns.SetFavoriteChar(charKey, value)
    local addon = _G.OneWoW_AltTracker
    if not addon or not addon.db then return end
    if not addon.db.global.favorites then
        addon.db.global.favorites = {}
    end
    addon.db.global.favorites[charKey] = value and true or nil
end

function ns.IsFavoriteBarSet(setName)
    if not setName then return false end
    local db = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global
    return db and db.favoriteBarSets and db.favoriteBarSets[setName] == true
end

function ns.SetFavoriteBarSet(setName, value)
    local addon = _G.OneWoW_AltTracker
    if not addon or not addon.db or not setName then return end
    if not addon.db.global.favoriteBarSets then
        addon.db.global.favoriteBarSets = {}
    end
    addon.db.global.favoriteBarSets[setName] = value and true or nil
end

function ns.IsFavoriteItem(itemID)
    if not itemID then return false end
    local db = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global
    return db and db.favoriteItems and db.favoriteItems[tostring(itemID)] == true
end

function ns.SetFavoriteItem(itemID, value)
    local addon = _G.OneWoW_AltTracker
    if not addon or not addon.db or not itemID then return end
    if not addon.db.global.favoriteItems then
        addon.db.global.favoriteItems = {}
    end
    local k = tostring(itemID)
    addon.db.global.favoriteItems[k] = value and true or nil
end
