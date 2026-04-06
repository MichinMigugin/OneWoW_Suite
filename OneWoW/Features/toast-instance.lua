local ADDON_NAME, OneWoW = ...

local Toasts = OneWoW.Toasts

local GRID_LABELS = {
    tmogs   = "TMogs",
    mounts  = "Mounts",
    pets    = "Pets",
    recipes = "Recipes",
    toys    = "Toys",
    quests  = "Quests",
    housing = "Housing",
}

local TOTAL_ONLY = {
    quests  = true,
    housing = true,
}

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.toasts
end

local function InstanceEnabled()
    local db = GetDB()
    return db and db.instance and db.instance.enabled ~= false
end

local function GetInstanceIcon(instanceName)
    if not EJ_GetInstanceInfo then return nil end
    local count = EJ_GetNumInstances and EJ_GetNumInstances() or 0
    for i = 1, count do
        local id = EJ_GetInstanceByIndex(i, false)
        if id then
            local name, _, _, buttonImage1 = EJ_GetInstanceInfo(id)
            if name == instanceName and buttonImage1 and buttonImage1 ~= 0 then
                return buttonImage1
            end
        end
    end
    return nil
end

local function GetCatalogData(mapID)
    local journalNS = _G.OneWoW_CatalogData_Journal
    if not journalNS or not journalNS.JournalData then return nil end

    local JournalData = journalNS.JournalData
    JournalData:BuildJournalCache()
    if not JournalData.journalCache then return nil end

    local instData
    for _, data in pairs(JournalData.journalCache) do
        if data.mapID == mapID then
            instData = data
            break
        end
    end
    if not instData then return nil end

    local keyMap = {
        TMog    = "tmogs",
        Mount   = "mounts",
        Pet     = "pets",
        Toy     = "toys",
        Recipe  = "recipes",
        Quest   = "quests",
        Housing = "housing",
    }
    local counts = {
        tmogs   = { current = 0, total = 0 },
        mounts  = { current = 0, total = 0 },
        pets    = { current = 0, total = 0 },
        recipes = { current = 0, total = 0 },
        toys    = { current = 0, total = 0 },
        quests  = { current = 0, total = 0 },
        housing = { current = 0, total = 0 },
    }

    for _, enc in ipairs(instData.encounters) do
        for _, item in ipairs(enc.items) do
            local key = keyMap[item.special]
            if key then
                counts[key].total = counts[key].total + 1
                local collected = JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
                if collected then
                    counts[key].current = counts[key].current + 1
                end
            end
        end
    end

    return counts
end

local function BuildGrid(catalogData)
    if not catalogData then return nil end
    local grid = {}
    local order = {"tmogs", "mounts", "pets", "recipes", "toys", "housing", "quests"}
    for _, key in ipairs(order) do
        local entry = catalogData[key] or { current = 0, total = 0 }
        table.insert(grid, {
            label     = GRID_LABELS[key] or key,
            current   = entry.current or 0,
            total     = entry.total   or 0,
            totalOnly = TOTAL_ONLY[key] or false,
        })
    end
    return grid
end

local instanceFrame = CreateFrame("Frame")
instanceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

instanceFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUI)
    if not InstanceEnabled() then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then return end
    if instanceType == "pvp" or instanceType == "arena" then return end

    C_Timer.After(3, function()
        if not InstanceEnabled() then return end
        local stillIn, stillType = IsInInstance()
        if not stillIn then return end
        if stillType == "pvp" or stillType == "arena" then return end

        local name, _, diffID, diffName, _, _, _, instanceID = GetInstanceInfo()
        if not name or name == "" then return end

        local icon = GetInstanceIcon(name)

        local catalogData = GetCatalogData(instanceID)
        local grid        = BuildGrid(catalogData)

        Toasts.FireToast({
            toastType     = "instance",
            title         = name,
            subtitle      = diffName or "",
            icon          = icon,
            grid          = grid,
            instanceMapID = instanceID,
        })
    end)
end)
