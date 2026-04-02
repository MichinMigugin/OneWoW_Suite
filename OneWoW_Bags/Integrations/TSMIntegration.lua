local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

OneWoW_Bags.TSMIntegration = {}
local TSM = OneWoW_Bags.TSMIntegration

function TSM:IsAvailable()
    return _G.TSM_API ~= nil
end

function TSM:Import()
    if not self:IsAvailable() then return 0 end

    local db = OneWoW_Bags.db
    DB:Ensure(db, "global", "customCategoriesV2")

    local imported = 0

    local ok, groups = pcall(function()
        if TSM_API.GetGroupPaths then
            return TSM_API.GetGroupPaths()
        end
        return nil
    end)

    if not ok or not groups then
        ok, groups = pcall(function()
            if _G.TSMAPI_FOUR and _G.TSMAPI_FOUR.Groups then
                local paths = {}
                for path in _G.TSMAPI_FOUR.Groups:GroupIterator() do
                    tinsert(paths, path)
                end
                return paths
            end
            return nil
        end)
    end

    if not ok or not groups then return 0 end

    local groupItems = {}
    for _, path in ipairs(groups) do
        local items = {}
        local gotItems = false

        pcall(function()
            if TSM_API.GetGroupItems then
                local groupItemList = TSM_API.GetGroupItems(path)
                if groupItemList then
                    for _, itemStr in ipairs(groupItemList) do
                        local itemID = tonumber(itemStr:match("i:(%d+)"))
                        if itemID then
                            items[tostring(itemID)] = true
                            gotItems = true
                        end
                    end
                end
            end
        end)

        if gotItems then
            groupItems[path] = items
        end
    end

    for path, items in pairs(groupItems) do
        local name = "TSM: " .. path:gsub("`", " > ")

        local exists = false
        for _, cat in pairs(db.global.customCategoriesV2) do
            if cat.name == name then exists = true; break end
        end

        if not exists then
            local id = "tsm_" .. time() .. "_" .. math.random(1000, 9999)
            local order = 1
            for _, c in pairs(db.global.customCategoriesV2) do
                if c.sortOrder and c.sortOrder >= order then order = c.sortOrder + 1 end
            end
            db.global.customCategoriesV2[id] = {
                name = name,
                items = items,
                enabled = true,
                sortOrder = order,
                isTSM = true,
            }
            imported = imported + 1
        end
    end

    if OneWoW_Bags.Categories then
        OneWoW_Bags.Categories:SetCustomCategories(db.global.customCategoriesV2)
        OneWoW_Bags.Categories:InvalidateCache()
    end

    return imported
end
