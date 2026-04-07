local ADDON_NAME, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local DEFAULTS = {
    language = GetLocale(),
    theme = "green",
    minimap = {
        hide = false,
        minimapPos = 220,
        theme = "horde",
    },
    mainFrameSize = {
        width = 1400,
        height = 900,
    },
    lastModuleTab = "home",
    lastSubTabs = {},
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
        escShowTasks = true,
        escShowZoneNotes = true,
        escHideZoneNotesWhenEmpty = false,
        escShowAlerts = true,
        escShowEscNotes = true,
        escPortalsEnabled = true,
        escShowCharacterInfo = true,
        allFavorites = {},
        escFavorites = {},
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
                showInTooltip = false,
                showPawnPrompt = true,
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
                betterbags   = { enabled = true },
                onewow_bags  = { enabled = true },
            },
        },
        toastalerts = {
            general        = { enabled = false },
            detectiontypes = { enabled = false },
            instances      = { enabled = false },
            notealerts     = { enabled = false },
            upgrades       = { enabled = false },
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
            enhancements = {},
            talentmods = {},
            value = { enabled = true },
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
    toasts = {
        enabled = false,
        anchor = { x = nil, y = nil, visible = true, locked = false },
        loot = {
            enabled = false,
            mounts  = false,
            pets    = false,
            toys    = false,
            recipes = false,
            tmogs   = false,
            sound   = SOUNDKIT.READY_CHECK,
        },
        notes = {
            enabled = false,
            npcs    = false,
            players = false,
            zones   = false,
            sound   = SOUNDKIT.ACHIEVEMENT_MENU_OPEN,
        },
        instance = {
            enabled = false,
            sound   = 0,
        },
    },
    profiles = {},
    charProfiles = {},
    defaultProfile = "Default",
}

local defaults = {
    global = {
        language = GetLocale(),
        theme = "green",
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },
        mainFrameSize = {
            width = 1400,
            height = 900,
        },
        mainFramePosition = nil,
        lastModuleTab = "home",
        lastSubTabs = {},
    },
}

function OneWoW:InitializeDatabase()
    if not OneWoW_DB then
        OneWoW_DB = CopyTable(defaults.global)
    end

    self.db = {
        global = OneWoW_DB,
    }

    if OneWoW_GUI then
        OneWoW_GUI.DB:MergeMissing(self.db.global, DEFAULTS)
    end

    local ov = self.db.global.settings and self.db.global.settings.overlays or {}
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

    local ts = self.db.global.toasts
    local ta = self.db.global.settings.toastalerts
    if not ts.resetToDefaultsV1 then
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
        ts.instance.enabled = false
        if ta.general        then ta.general.enabled        = false end
        if ta.detectiontypes then ta.detectiontypes.enabled = false end
        if ta.instances      then ta.instances.enabled      = false end
        if ta.notealerts     then ta.notealerts.enabled     = false end
        ts.anchor.visible = true
        ts.anchor.locked  = false
    end

end
