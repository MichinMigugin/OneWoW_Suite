local _, ns = ...
local L = ns.L

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
    "Shopping List"
}

function NotesCategories:GetCategories()
    local allCategories = {}

    for _, category in ipairs(BUILT_IN_CATEGORIES) do
        table.insert(allCategories, category)
    end

    for _, customCategory in ipairs(OneWoW_Notes.db.global.notesCustomCategories) do
        table.insert(allCategories, customCategory)
    end

    return allCategories
end

function NotesCategories:GetCustomCategories()
    return OneWoW_Notes.db.global.notesCustomCategories
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

    tinsert(OneWoW_Notes.db.global.notesCustomCategories, categoryName)
    return true
end

function NotesCategories:RemoveCustomCategory(categoryName)
    if not categoryName or categoryName == "" then
        return false, L["NOTES_CATEGORY_EMPTY"]
    end

    if self:IsBuiltInCategory(categoryName) then
        return false, L["NOTES_CATEGORY_BUILTIN"]
    end

    local addon = OneWoW_Notes
    for i = #addon.db.global.notesCustomCategories, 1, -1 do
        if addon.db.global.notesCustomCategories[i] == categoryName then
            table.remove(addon.db.global.notesCustomCategories, i)
            return true
        end
    end

    return false, L["NOTES_CATEGORY_NOT_IN_CUSTOM"]
end
