local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

OneWoW_Bags.TSMIntegration = {}
local TSM = OneWoW_Bags.TSMIntegration

local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local tinsert = table.insert
local time, random = time, math.random

function TSM:IsAvailable()
    return TSM_API ~= nil or (TSMAPI_FOUR and TSMAPI_FOUR.Groups) ~= nil
end

-- Collect TSM group paths and item sets in a best-effort manner. Returns
-- { [path] = { [itemID]=true } } or nil, errmsg.
function TSM:CollectGroups()
    if not self:IsAvailable() then return nil, "TSM not loaded" end

    local ok, groups = pcall(function()
        if TSM_API and TSM_API.GetGroupPaths then
            return TSM_API.GetGroupPaths()
        end
        return nil
    end)

    if not ok or not groups then
        ok, groups = pcall(function()
            if TSMAPI_FOUR and TSMAPI_FOUR.Groups then
                local paths = {}
                for path in TSMAPI_FOUR.Groups:GroupIterator() do
                    tinsert(paths, path)
                end
                return paths
            end
            return nil
        end)
    end

    if not ok or not groups then return nil, "Could not enumerate TSM groups" end

    local groupItems = {}
    for _, path in ipairs(groups) do
        local items = {}
        local gotItems = false

        pcall(function()
            if TSM_API and TSM_API.GetGroupItems then
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
    return groupItems
end

-- BuildPlan populates plan.categories with TSM-derived entries. This is the
-- pure planner: it does not mutate the addon database.
function TSM:BuildPlan(plan, db, options)
    options = options or {}
    local usePrefix = options.tsmPrefix ~= false

    local groupItems, err = self:CollectGroups()
    if not groupItems then
        tinsert(plan.warnings, { severity = "error", text = err or "TSM fetch failed" })
        return plan
    end

    for path, items in pairs(groupItems) do
        local displayPath = path:gsub("`", " > ")
        local name = usePrefix and ("TSM: " .. displayPath) or displayPath

        local planCid = "tsm_cat_" .. path
        plan.categories[planCid] = {
            name       = name,
            items      = items,
            enabled    = true,
            isTSM      = true,
            filterMode = "items",
            originalId = planCid,
        }
    end
    return plan
end

-- Thin legacy wrapper: build a plan then run it through the Applier with all
-- conflicts auto-renamed (the historic direct-import behavior).
function TSM:Import()
    if not self:IsAvailable() then return 0 end

    local Planner = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Planner
    local Applier = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Applier
    if not Planner or not Applier then return 0 end

    local db = OneWoW_Bags:GetDB()
    DB:Ensure(db, "global", "customCategoriesV2")

    local plan = Planner:FromTsmDirect(db, { tsmPrefix = true })

    -- Default resolution for headless import: rename on conflict (matches
    -- the historical behavior of leaving existing data alone).
    for _, cat in pairs(plan.categories) do
        if cat.resolution == "rename" then
            cat.renamePrefix = ""
            cat.renameSuffix = " (TSM)"
        end
    end

    local controller = OneWoW_Bags.CategoryController
    local result = Applier:Apply(plan, controller, db)
    return result and result.categoriesNew + result.categoriesRenamed or 0
end
