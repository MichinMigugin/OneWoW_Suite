-- Bootstraps LoadOnDemand data stores: exposes OnAddonLoaded / OnPlayerLogin /
-- OnPlayerEnteringWorld hooks for OneWoW's lifecycle dispatcher. No WoW event
-- registration — core drives all lifecycle phases.
local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local ipairs = ipairs

---@param storeNs table store namespace (registered privately for lifecycle dispatch)
---@param config table savedVar, defaults, initDB, onLogin, onEnteringWorld, withScanCallbacks, sortField
function ns:BootStore(storeNs, config)
    local savedVar = config.savedVar
    local onLogin = config.onLogin
    local onEnteringWorld = config.onEnteringWorld
    local defaults = config.defaults
    local initDB = config.initDB

    if config.addonName and ns.Lifecycle then
        ns.Lifecycle.RegisterUnit(config.addonName, storeNs)
    end

    storeNs.AddonInitialized = false

    if ns.Lifecycle then
        ns.Lifecycle:CreateHandlerRegistry(storeNs)
    end

    if config.withScanCallbacks then
        local scanCallbacks = {}
        storeNs.RegisterScanCallback = function(_, idOrFn, maybeFn)
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
        storeNs.FireScanCallbacks = function(_, data)
            local storeLabel = savedVar or "store"
            for i, entry in ipairs(scanCallbacks) do
                local label = entry.id or (storeLabel .. "#" .. i)
                ns.Lifecycle.SafeCall(label, entry.fn, data)
            end
        end
    end

    storeNs.GetCharacterKey = function()
        return OneWoW_GUI:GetCharacterKey()
    end
    storeNs.GetCharacterData = function(_, charKey)
        return DB:GetCharData(savedVar, charKey)
    end
    -- Returns the live charKey -> charData map (the store's `.characters`
    -- table), matching the `_API.GetAllCharacters()` contract. Callers that
    -- want a sorted list build one themselves or use DB:GetAllChars directly.
    storeNs.GetAllCharacters = function()
        local sv = _G[savedVar]
        return (sv and sv.characters) or {}
    end
    storeNs.DeleteCharacter = function(_, charKey)
        return DB:DeleteChar(savedVar, charKey)
    end

    function storeNs.OnAddonLoaded()
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
        elseif storeNs.InitializeDatabase then
            storeNs:InitializeDatabase()
        end
    end

    local didLogin = false
    function storeNs.OnPlayerLogin()
        if didLogin then return end
        didLogin = true
        storeNs.AddonInitialized = true
        if onLogin then onLogin() end
        if storeNs.FireLoginHandlers then
            storeNs:FireLoginHandlers()
        end
        -- Login init complete = this store's data is queryable. Emit the
        -- suite-wide data-ready signal (data boundary) so consumers populate
        -- without ad-hoc retries. Keyed on addon name, uniform with the
        -- load-boundary signals; no-op for stores nobody watches.
        OneWoW:SignalDataReady(config.addonName)
    end

    function storeNs.OnPlayerEnteringWorld(isLogin, isReload, isZoning)
        if onEnteringWorld then
            onEnteringWorld(isLogin, isReload, isZoning)
        end
        if storeNs.FireEnteringWorldHandlers then
            storeNs:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
        end
    end
end
