-- Bootstraps LoadOnDemand data stores: exposes OnAddonLoaded / OnPlayerLogin /
-- OnPlayerEnteringWorld hooks for OneWoW's lifecycle dispatcher. No WoW event
-- registration — core drives all lifecycle phases.
local _, OneWoW = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB
local ipairs = ipairs

---@param ns table store namespace (becomes _G[addonName])
---@param config table savedVar, defaults, initDB, onLogin, onEnteringWorld, withScanCallbacks, sortField
function OneWoW:BootStore(ns, config)
    local savedVar = config.savedVar
    local onLogin = config.onLogin
    local onEnteringWorld = config.onEnteringWorld
    local defaults = config.defaults
    local initDB = config.initDB

    -- STOP-GAP (suite-wide cleanup pending; see OneWoW/Docs/MIGRATION.md):
    -- the core lifecycle dispatcher (Lifecycle.RunUnitHook) resolves a load unit
    -- by reading _G[addonName] and calling the OnAddonLoaded / OnPlayerLogin /
    -- OnPlayerEnteringWorld hooks attached to ns below. Publishing the whole
    -- namespace as a global is exactly the practice the suite is retiring, but
    -- centralizing it here (instead of a hand-written "_G[addon] = ns" in every
    -- store's main file) means all stores wire identically and the eventual
    -- removal is a single edit. Stores must NOT hand-publish "= ns" anymore.
    if config.addonName then
        _G[config.addonName] = ns
    end

    ns.AddonInitialized = false

    if OneWoW.Lifecycle then
        OneWoW.Lifecycle:CreateHandlerRegistry(ns)
    end

    if config.withScanCallbacks then
        local scanCallbacks = {}
        ns.RegisterScanCallback = function(_, idOrFn, maybeFn)
            local id, fn
            if type(idOrFn) == "function" then
                fn = idOrFn
                id = nil
            else
                id = idOrFn
                fn = maybeFn
            end
            scanCallbacks[#scanCallbacks + 1] = { id = id, fn = fn }
        end
        ns.FireScanCallbacks = function(_, data)
            local storeLabel = savedVar or "store"
            for i, entry in ipairs(scanCallbacks) do
                local label = entry.id or (storeLabel .. "#" .. i)
                OneWoW.Lifecycle.SafeCall(label, entry.fn, data)
            end
        end
    end

    ns.GetCharacterKey = function()
        return OneWoW_GUI:GetCharacterKey()
    end
    ns.GetCharacterData = function(_, charKey)
        return DB:GetCharData(savedVar, charKey)
    end
    -- Returns the live charKey -> charData map (the store's `.characters`
    -- table), matching the `_API.GetAllCharacters()` contract. Callers that
    -- want a sorted list build one themselves or use DB:GetAllChars directly.
    ns.GetAllCharacters = function()
        local sv = _G[savedVar]
        return (sv and sv.characters) or {}
    end
    ns.DeleteCharacter = function(_, charKey)
        return DB:DeleteChar(savedVar, charKey)
    end

    -- Core DispatchUnitOnAddonLoaded guarantees single dispatch; didInit removable later.
    local didInit = false
    function ns.OnAddonLoaded()
        if didInit then return end
        didInit = true
        if savedVar then
            -- Ensure the live SavedVariable exists and carries its default shape.
            -- This runs after C_AddOns.LoadAddOn (so _G[savedVar] is the real
            -- disk table); stores read/write _G[savedVar] directly by name.
            if not _G[savedVar] then _G[savedVar] = {} end
            if defaults then
                DB:MergeMissing(_G[savedVar], defaults)
            end
        end
        if initDB then
            initDB()
        elseif ns.InitializeDatabase then
            ns:InitializeDatabase()
        end
    end

    local didLogin = false
    function ns.OnPlayerLogin()
        if didLogin then return end
        didLogin = true
        ns.AddonInitialized = true
        if onLogin then onLogin() end
        if ns.FireLoginHandlers then
            ns:FireLoginHandlers()
        end
    end

    function ns.OnPlayerEnteringWorld(isLogin, isReload, isZoning)
        if onEnteringWorld then
            onEnteringWorld(isLogin, isReload, isZoning)
        end
        if ns.FireEnteringWorldHandlers then
            ns:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
        end
    end
end
