local _, ns = ...
local L = ns.L

local tinsert, sort = tinsert, sort

local NotesCategories = {}
ns.NotesCategories = NotesCategories

local BUILT_IN_CATEGORIES = {
    "General",
    "Personal",
    "Guild",
    "Raid",
    "Dungeon",
    "Quest",
    "Achievement",
    "Profession",
    "Gold Making",
    "PvP",
    "Shopping List",
    "Farming"
}

function NotesCategories:GetCategories()
    local allCategories = {}

    for _, category in ipairs(BUILT_IN_CATEGORIES) do
        tinsert(allCategories, category)
    end

    for _, customCategory in ipairs(ns.db.global.notesCustomCategories) do
        tinsert(allCategories, customCategory)
    end

    sort(allCategories)
    return allCategories
end

function NotesCategories:GetCustomCategories()
    return ns.db.global.notesCustomCategories
end

function NotesCategories:IsBuiltInCategory(categoryName)
    for _, builtin in ipairs(BUILT_IN_CATEGORIES) do
        if builtin == categoryName then
            return true
        end
    end
    return false
end

function NotesCategories:AddCustomCategory(categoryName)
    if not categoryName or categoryName == "" then
        return false, L["NOTES_CATEGORY_EMPTY"]
    end

    local allCategories = self:GetCategories()
    for _, existing in ipairs(allCategories) do
        if existing:lower() == categoryName:lower() then
            return false, L["NOTES_CATEGORY_EXISTS"]
        end
    end

    tinsert(ns.db.global.notesCustomCategories, categoryName)
    return true
end

function NotesCategories:RemoveCustomCategory(categoryName)
    if not categoryName or categoryName == "" then
        return false, L["NOTES_CATEGORY_EMPTY"]
    end

    if self:IsBuiltInCategory(categoryName) then
        return false, L["NOTES_CATEGORY_BUILTIN"]
    end

    local addon = ns
    for i = #addon.db.global.notesCustomCategories, 1, -1 do
        if addon.db.global.notesCustomCategories[i] == categoryName then
            table.remove(addon.db.global.notesCustomCategories, i)
            return true
        end
    end

    return false, L["NOTES_CATEGORY_NOT_IN_CUSTOM"]
end
