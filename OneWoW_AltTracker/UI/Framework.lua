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

local StorageAPI = _G.OneWoW_AltTracker_StorageAPI

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
    local hasMail = false
    if StorageAPI then
        local mailData = StorageAPI.GetMail(charKey)
        hasMail = mailData and mailData.hasNewMail
    elseif _G.OneWoW_AltTracker_Storage_DB and _G.OneWoW_AltTracker_Storage_DB.characters then
        local sc = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        hasMail = sc and sc.mail and sc.mail.hasNewMail
    end
    local mailCell = OneWoW_GUI:CreateMailIcon(charRow, { hasMail = hasMail })
    table.insert(charRow.cells, mailCell)
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
