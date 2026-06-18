local ADDON_NAME, OneWoW = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

local DEFAULTS = {
    language = GetLocale(),
    theme = "green",
    font = "default",
    fontSizeOffset = 0,
    minimap = {
        hide = false,
        minimapPos = 220,
        theme = "horde",
    },
    minimapLaunchers = {},
    moneyDisplay = {
        useLetters = false,
        useRegionalNumbers = true,
        useWhiteValues = true,
    },
    mainFrameSize = {
        width = 1400,
        height = 900,
    },
    lastModuleTab = "home",
    lastSubTabs = {},
    debugTrace = false,
    portalHub = {
        escEnabled = true,
        randomHearthstone = true,
        showAll = true,
        showAllOnEsc = false,
        showSeasonal = true,
        showDalaranHearth = true,
        showGarrisonHearth = true,
        showFlightWhistle = true,
        showHousingPortal = true,
        escShowZoneNotes = true,
        escHideZoneNotesWhenEmpty = false,
        escShowAlerts = true,
        escPortalsEnabled = true,
        escShowCharacterInfo = true,
        escPanelsSide = "left",
        escPortalsSide = "right",
        allFavorites = {},
        escFavorites = {},
        customItems = {},
        iconSize = 36,
        escIconSize = 32,
        gridColumns = 8,
    },
    instanceStatsEsc = { enabled = false },
    instanceStatsPosition = {},
    settings = {
        overlays = {
            general = { enabled = true },
            consumables = {
                enabled          = false,
                icon             = "VignetteEvent-SuperTracked",
                position         = "TOPRIGHT",
                scale            = 1.0,
                alpha            = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            itemlevel = {
                enabled = false,
                position = "TOPRIGHT",
                useQualityColors = false,
                applyToVendorItems = true,
                applyToAuctionHouse = false,
                fontSize = 10,
                showPetLevel = true,
                showContainerSlots = true,
            },
            knownitems = {
                enabled = false,
                icon = "warband-completed-icon",
                position = "TOPRIGHT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            unknownitems = {
                enabled = false,
                icon = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            housingdecor = {
                enabled = false,
                icon = "shop-icon-housing-beds-selected",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            mounts = {
                enabled = false,
                icon = "icon-mount",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            pets = {
                enabled = false,
                icon = "icon-pet",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            quest = {
                enabled = false,
                icon = "Quest-Campaign-Available",
                position = "CENTER",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            reagents = {
                enabled = false,
                icon = "Bonus-Objective-Star",
                position = "TOPRIGHT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            recipe = {
                enabled = false,
                icon = "icon-recipe",
                position = "BOTTOMRIGHT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            soulbound = {
                enabled = false,
                icon = "VignetteKill",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            toys = {
                enabled = false,
                icon = "icon-toy",
                position = "BOTTOMRIGHT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            warbound = {
                enabled = false,
                icon = "warbands-icon",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
                includeWUE = true,
            },
            wue = {
                enabled = false,
                icon = "warband-completed-icon",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            boe = {
                enabled = false,
                icon = "icon-flag",
                position = "TOPRIGHT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            junk = {
                enabled = false,
                icon = "bags-junkcoin",
                position = "CENTER",
                scale = 1.5,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
                showInTooltip = true,
                includeGreyItems = false,
            },
            protected = {
                enabled = false,
                icon = "soulbinds_tree_conduit_icon_protect",
                position = "CENTER",
                scale = 1.5,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
                showInTooltip = true,
            },
            upgrade = {
                enabled = false,
                icon = "Professions-Icon-Quality-Tier3-Small",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
                mode = "ILVL",
                pawnEnforceReqLevel = true,
                showInTooltip = false,
                tooltipDetail = "FULL",
                tooltipOnlyUpgrade = false,
                tooltipShowSkipReason = false,
                tooltipShowAlts = true,
                tooltipIgnoreSoulbound = false,
                tooltipAltLimit = 10,
                tooltipAltWhitelistEnabled = false,
                tooltipAltWhitelist = {},
                showPawnPrompt = true,
                altSpecMatch = false,
                selfSpecMatch = false,
            },
            transmog = {
                enabled = false,
                icon = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",
                position = "TOPLEFT",
                scale = 1.0,
                alpha = 1.0,
                applyToVendorItems = false,
                applyToAuctionHouse = false,
            },
            integrations = {
                arkinventory = { enabled = true },
                baganator    = { enabled = true },
                bagnon       = { enabled = true },
                betterbags   = { enabled = true },
                elvui        = { enabled = true },
                onewow_bags  = { enabled = true },
            },
        },
        -- Toast runtime config (relocated from the legacy db.global.toasts
        -- root in migration v5). "anchor" is a storage-only id — not in the
        -- SettingsFeatureRegistry catalog; its x/y are dynamic keys written
        -- on drag.
        toastalerts = {
            general        = { enabled = false },
            detectiontypes = {
                enabled = false,
                mounts  = false,
                pets    = false,
                toys    = false,
                recipes = false,
                recipesOnlyMyProfessions = false,
                tmogs   = false,
                suppressBlizzardAlerts = false,
                sound   = SOUNDKIT.READY_CHECK,
            },
            instances      = { enabled = false, sound = 0 },
            notealerts     = {
                enabled = false,
                npcs    = false,
                players = false,
                zones   = false,
                items   = false,
                sound   = SOUNDKIT.ACHIEVEMENT_MENU_OPEN,
            },
            upgrades       = { enabled = false },
            anchor         = { visible = true, locked = false },
        },
        tooltips = {
            general = { enabled = true },
            technicalids = {
                enabled = false,
                showItemID = true,
                showSpellID = true,
                showNpcID = true,
                showAchievementID = true,
                showQuestID = true,
                showCurrencyID = true,
                showMountID = true,
                showPetID = true,
                showEnchantID = true,
                showIconID = true,
                showExpansionID = true,
                showSetID = true,
                showDecorEntryID = true,
                showRecipeID = true,
                showEquipmentSetID = true,
                showEssenceID = true,
                showConduitID = true,
                showOutfitID = true,
                showMacroID = true,
                showObjectID = true,
                showAbilityID = true,
                showAreaPoiID = true,
                showArtifactPowerID = true,
                showBonusID = true,
                showCompanionID = true,
                showCriteriaID = true,
                showGemID = true,
                showSourceID = true,
                showTalentID = true,
                showTraitDefinitionID = false,
                showTraitEntryID = false,
                showTraitNodeID = false,
                showVignetteID = true,
                showVisualID = true,
            },
            itemtracker = {
                enabled = true,
                colorByClass = true,
                characterLimit = 10,
                showAlts        = true,
                showBags        = true,
                showBank        = true,
                showEquipped    = true,
                showAuctions    = true,
                showWarbandBank = true,
                showGuildBanks  = true,
                showVendors     = true,
                showInstances   = true,
            },
            recipeknowledge = { enabled = true },
            customnotes = { enabled = true },
            enhancements = {
                removeBlizzardVendorValue = true,
            },
            talentmods = {},
            value = {
                enabled = true,
                showVendorPrice = true,
                showAHValue = true,
                ahPriceSource = "onewow",
                showTSMValue = false,
                tsmPriceString = "dbmarket",
            },
            pets = {
                enabled = true,
                showCollectionStatus = true,
                showPetInfo = true,
                showSource = true,
                showDescription = true,
                showValue = true,
                showAHValue = true,
                showItemStatus = true,
                showTechnicalIDs = true,
            },
        },
    },
    itemStatus = {},
    -- Runtime state of Integrations/ExternalTooltipSync.lua (Auctionator option
    -- backups, one-time notice flags). Machine state, not user settings — kept
    -- outside the settings funnel.
    externalTooltipSync = {
        auctionatorBackup = {},
        auctionatorPopupShown = false,
        tsmNoticeShown = false,
    },
    profiles = {},
    charProfiles = {},
    defaultProfile = "Default",
}

--- Fresh copy of the shipped defaults subtree for one settings tab
--- ("overlays", "tooltips", "toastalerts"). Used by
--- SettingsFeatureRegistry:ResetTab. Errors on unknown tab names.
---@param tabName string
---@return table
function OneWoW:GetSettingsDefaults(tabName)
    return CopyTable(DEFAULTS.settings[tabName])
end

local MIGRATIONS = {
    {
        version = 1,
        name = "external_tooltip_sync_state_relocation",
        -- ExternalTooltipSync historically stored its runtime state inside
        -- settings.tooltips.value as underscore-prefixed keys. Relocate it to
        -- its own root so the settings tree holds only user settings.
        run = function(d)
            local value = DB:Read(d.global, "settings", "tooltips", "value")
            if not value then return end
            local state = DB:Ensure(d.global, "externalTooltipSync")
            if type(value._auctionatorTooltipBackup) == "table" then
                state.auctionatorBackup = value._auctionatorTooltipBackup
            end
            if value._auctionatorSourcePopupShown then
                state.auctionatorPopupShown = true
            end
            if value._tsmTooltipNoticeShown then
                state.tsmNoticeShown = true
            end
            value._auctionatorTooltipBackup = nil
            value._auctionatorSourcePopupShown = nil
            value._tsmTooltipNoticeShown = nil
        end,
    },
    {
        version = 2,
        name = "overlay_settings_normalization",
        -- Three historical overlay-config normalizations that used to run
        -- unconditionally in InitializeDatabase (all idempotent): outer
        -- position renames, raw LSM font names -> unified font keys, and the
        -- legacy effect* fields -> bg* background model.
        run = function(d)
            local ov = DB:Read(d.global, "settings", "overlays")
            if not ov then return end
            local outerRename = {
                TOPLEFT_OUTER     = "Outer-Top-Left",
                TOPRIGHT_OUTER    = "Outer-Top-Right",
                BOTTOMLEFT_OUTER  = "Outer-Bottom-Left",
                BOTTOMRIGHT_OUTER = "Outer-Bottom-Right",
            }
            for _, cfg in pairs(ov) do
                if type(cfg) == "table" then
                    if cfg.position and outerRename[cfg.position] then
                        cfg.position = outerRename[cfg.position]
                    end
                    -- Overlays historically stored fontFamily as a raw LSM name
                    -- (e.g. "Hack"). Other addons store the OneWoW_GUI key
                    -- ("hack"). Migrate so the whole suite uses the same
                    -- canonical key. LSM-only fonts with no hardcoded
                    -- equivalent (e.g. "Poppins SemiBold") stay as their LSM
                    -- name, which is also their unified key.
                    if cfg.fontFamily then
                        local migrated = OneWoW_GUI:MigrateLSMFontName(cfg.fontFamily)
                        if migrated then cfg.fontFamily = migrated end
                    end
                    if cfg.effectColor and cfg.effectColor ~= "none" and not cfg.bgEnabled then
                        cfg.bgEnabled = true
                        cfg.bgStyle = cfg.effectAtlas or "Solid-Circle"
                        if cfg.bgStyle ~= "Solid-Circle" and cfg.bgStyle ~= "Solid-Square" and cfg.bgStyle ~= "Spinning Orbs" then
                            cfg.bgStyle = "Spinning Orbs"
                        end
                        cfg.bgScale = cfg.effectScale or 1.0
                        cfg.bgColor = cfg.effectSolidColor or {1, 1, 1}
                        if not cfg.effect then
                            cfg.effect = "both"
                        end
                    end
                    cfg.effectColor = nil
                    cfg.effectAtlas = nil
                    cfg.effectScale = nil
                    cfg.effectSolidColor = nil
                end
            end
        end,
    },
    {
        version = 3,
        name = "toast_reset_to_defaults",
        -- One-time toast opt-in reset. Predates versioned migrations, so the
        -- legacy resetToDefaultsV1 boolean stays as the inner gate: users who
        -- already ran it (and re-enabled toasts since) must not be reset again.
        -- Nil-guarded: since v5 relocated toasts into settings.toastalerts,
        -- fresh DBs run this step without a toasts root.
        run = function(d)
            local ts = d.global.toasts
            if not ts or ts.resetToDefaultsV1 then return end
            ts.resetToDefaultsV1 = true
            ts.enabled = false
            ts.loot.enabled = false
            ts.loot.mounts  = false
            ts.loot.pets    = false
            ts.loot.toys    = false
            ts.loot.recipes = false
            ts.loot.tmogs   = false
            ts.notes.enabled = false
            ts.notes.npcs    = false
            ts.notes.players = false
            ts.notes.zones   = false
            ts.notes.items   = false
            ts.instance.enabled = false
            local ta = d.global.settings.toastalerts
            ta.general.enabled        = false
            ta.detectiontypes.enabled = false
            ta.instances.enabled      = false
            ta.notealerts.enabled     = false
            ts.anchor.visible = true
            ts.anchor.locked  = false
        end,
    },
    {
        version = 4,
        name = "fold_gui_db",
        -- Folds the legacy OneWoW_GUI_DB SavedVariables (still loaded by the
        -- transitional OneWoW_GUI stub addon) into the unified OneWoW_DB.
        -- One-way — never writes back to OneWoW_GUI_DB. GUI value wins on key
        -- collision: it is what ApplyTheme read before the fold. Tolerates a
        -- missing OneWoW_GUI_DB (fresh installs, stub retired).
        run = function(d)
            local sv = OneWoW_GUI_DB
            if type(sv) ~= "table" then return end

            -- Very old installs stored GUI settings flat at the SV root.
            local src = sv.global
            if type(src) ~= "table" and next(sv) ~= nil then
                src = sv
            end
            if type(src) ~= "table" then return end

            local g = d.global

            for _, key in ipairs({ "language", "theme", "font", "fontSizeOffset" }) do
                if src[key] ~= nil then g[key] = src[key] end
            end
            for _, key in ipairs({ "minimapLaunchers", "moneyDisplay" }) do
                if type(src[key]) == "table" then g[key] = CopyTable(src[key]) end
            end
            -- Per-leaf for minimap: hide/theme were GUI-owned, but minimapPos
            -- always lived in OneWoW_DB and must survive.
            if type(src.minimap) == "table" then
                if src.minimap.hide ~= nil then g.minimap.hide = src.minimap.hide end
                if src.minimap.theme ~= nil then g.minimap.theme = src.minimap.theme end
            end

            -- _migrated gates OneWoW_GUI:MigrateSettings (legacy per-addon
            -- theme/language copies). Carry it as set: without it the first
            -- feature unit to call MigrateSettings would overwrite the folded
            -- values with its own stale local copy.
            g._migrated = true

            -- Scope roots live at the SV root in single mode; fill-only merge
            -- so anything already written to the unified DB wins.
            local root = d.root
            for _, key in ipairs({ "chars", "realms", "factions", "classes", "specs" }) do
                if type(sv[key]) == "table" then
                    if not root[key] then root[key] = {} end
                    DB:MergeMissing(root[key], sv[key])
                end
            end
            if type(sv.presets) == "table" then
                DB:MergeMissing(root.presets, sv.presets)
            end
            if sv._activePreset ~= nil then
                root._activePreset = sv._activePreset
                d._activePreset = sv._activePreset
            end
        end,
    },
    {
        version = 5,
        name = "toasts_settings_relocation",
        -- The toast runtime config historically lived at its own global root
        -- (db.global.toasts), with only the enable flags mirrored into
        -- settings.toastalerts. Relocate the whole tree under
        -- settings.toastalerts so SettingsFeatureRegistry is the single
        -- access path: enabled -> general.enabled, loot -> detectiontypes,
        -- notes -> notealerts, instance -> instances, anchor -> anchor.
        -- Stored profile snapshots (t-profiles core.toasts, t-charprofiles
        -- addonSettings) are rewritten too, so old snapshots restore into the
        -- new layout. The legacy resetToDefaultsV1 gate is dropped — once
        -- versioned past v3 it never re-runs.
        run = function(d)
            local SECTION_MAP = { loot = "detectiontypes", notes = "notealerts", instance = "instances" }

            -- Old-root values win over whatever is already in the settings
            -- tree: the root was what the toast code actually read.
            local function Relocate(ts, settings)
                if type(ts) ~= "table" or type(settings) ~= "table" then return end
                local ta = settings.toastalerts
                if type(ta) ~= "table" then
                    ta = {}
                    settings.toastalerts = ta
                end
                if ts.enabled ~= nil then
                    if type(ta.general) ~= "table" then ta.general = {} end
                    ta.general.enabled = ts.enabled
                end
                for old, new in pairs(SECTION_MAP) do
                    if type(ts[old]) == "table" then
                        if type(ta[new]) ~= "table" then ta[new] = {} end
                        for k, v in pairs(ts[old]) do
                            ta[new][k] = v
                        end
                    end
                end
                if type(ts.anchor) == "table" then
                    ta.anchor = ts.anchor
                end
            end

            local g = d.global
            Relocate(g.toasts, g.settings)
            g.toasts = nil

            if type(g.profiles) == "table" then
                for _, snap in pairs(g.profiles) do
                    local core = type(snap) == "table" and snap.core or nil
                    if type(core) == "table" and core.toasts ~= nil then
                        if type(core.settings) ~= "table" then core.settings = {} end
                        Relocate(core.toasts, core.settings)
                        core.toasts = nil
                    end
                end
            end

            if type(g.charProfiles) == "table" then
                for _, profile in pairs(g.charProfiles) do
                    local addons = type(profile) == "table"
                        and type(profile.addonSettings) == "table"
                        and profile.addonSettings.addons or nil
                    local entry = type(addons) == "table" and addons.OneWoW_DB or nil
                    local s = type(entry) == "table" and entry.settings or nil
                    if type(s) == "table" and s.toasts ~= nil then
                        if type(s.settings) ~= "table" then s.settings = {} end
                        Relocate(s.toasts, s.settings)
                        s.toasts = nil
                    end
                end
            end
        end,
    },
}

function OneWoW:InitializeDatabase()
    -- OneWoW_DB was historically a flat root — the root WAS the global table
    -- (`self.db = { global = OneWoW_DB }`). DB:Init single mode expects
    -- root.global plus scope roots, so wrap a legacy flat SV once before
    -- Init. Shape-detected rather than versioned: _migrationVersion itself
    -- rides along into the wrapped global table.
    local sv = OneWoW_DB
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do
            oldData[k] = v
        end
        wipe(sv)
        sv.global = oldData
    end

    self.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_DB",
        defaults = { global = DEFAULTS },
    })

    DB:RunMigrations(self.db, MIGRATIONS)
end
