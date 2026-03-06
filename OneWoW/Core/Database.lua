local ADDON_NAME, OneWoW = ...

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

    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end
    if not self.db.global.theme then
        self.db.global.theme = "green"
    end
    if not self.db.global.minimap then
        self.db.global.minimap = {}
    end
    if self.db.global.minimap.hide == nil then
        self.db.global.minimap.hide = false
    end
    if self.db.global.minimap.minimapPos == nil then
        self.db.global.minimap.minimapPos = 220
    end
    if not self.db.global.minimap.theme then
        self.db.global.minimap.theme = "horde"
    end
    if not self.db.global.mainFrameSize then
        self.db.global.mainFrameSize = { width = 1400, height = 900 }
    end
    if not self.db.global.lastModuleTab then
        self.db.global.lastModuleTab = "home"
    end
    if not self.db.global.lastSubTabs then
        self.db.global.lastSubTabs = {}
    end
    if not self.db.global.portalHub then
        self.db.global.portalHub = {}
    end
    local ph = self.db.global.portalHub
    if ph.escEnabled == nil then ph.escEnabled = true end
    if ph.randomHearthstone == nil then ph.randomHearthstone = true end
    if ph.showAll == nil then ph.showAll = true end
    if ph.showAllOnEsc == nil then ph.showAllOnEsc = false end
    if ph.showSeasonal == nil then ph.showSeasonal = true end
    if ph.escShowTasks == nil then ph.escShowTasks = true end
    if ph.escShowZoneNotes == nil then ph.escShowZoneNotes = true end
    if ph.escHideZoneNotesWhenEmpty == nil then ph.escHideZoneNotesWhenEmpty = false end
    if ph.escShowAlerts == nil then ph.escShowAlerts = true end
    if ph.escShowEscNotes == nil then ph.escShowEscNotes = true end

    if not self.db.global.settings then
        self.db.global.settings = {}
    end
    if not self.db.global.settings.overlays then
        self.db.global.settings.overlays = {}
    end
    local ov = self.db.global.settings.overlays
    if not ov.general then
        ov.general = { enabled = true }
    end
    if ov.general.enabled == nil then
        ov.general.enabled = true
    end
    if not ov.consumables then
        ov.consumables = {
            enabled          = false,
            icon             = "VignetteEvent-SuperTracked",
            position         = "TOPRIGHT",
            scale            = 1.0,
            alpha            = 1.0,
            applyToVendorItems = false,
            applyToAuctionHouse = false,
        }
    end
    if ov.consumables.applyToVendorItems == nil then
        ov.consumables.applyToVendorItems = false
    end
    if ov.consumables.applyToAuctionHouse == nil then
        ov.consumables.applyToAuctionHouse = false
    end
    if not ov.itemlevel then
        ov.itemlevel = { enabled = false, position = "TOPRIGHT", useQualityColors = false, applyToVendorItems = true, applyToAuctionHouse = false, fontSize = 10 }
    end
    if ov.itemlevel.fontSize == nil then
        ov.itemlevel.fontSize = 10
    end
    if ov.itemlevel.applyToAuctionHouse == nil then
        ov.itemlevel.applyToAuctionHouse = false
    end
    if not ov.knownitems then
        ov.knownitems   = { enabled = false, icon = "warband-completed-icon",                          position = "TOPRIGHT", scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.knownitems.applyToAuctionHouse == nil then
        ov.knownitems.applyToAuctionHouse = false
    end
    if not ov.unknownitems then
        ov.unknownitems = { enabled = false, icon = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",   position = "TOPLEFT",  scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.unknownitems.applyToAuctionHouse == nil then
        ov.unknownitems.applyToAuctionHouse = false
    end
    if not ov.housingdecor then
        ov.housingdecor = { enabled = false, icon = "shop-icon-housing-beds-selected", position = "TOPLEFT",     scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.housingdecor.applyToAuctionHouse == nil then
        ov.housingdecor.applyToAuctionHouse = false
    end
    if not ov.mounts then
        ov.mounts       = { enabled = false, icon = "icon-mount",                      position = "TOPLEFT",     scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.mounts.applyToAuctionHouse == nil then
        ov.mounts.applyToAuctionHouse = false
    end
    if not ov.pets then
        ov.pets         = { enabled = false, icon = "icon-pet",                        position = "TOPLEFT",     scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.pets.applyToAuctionHouse == nil then
        ov.pets.applyToAuctionHouse = false
    end
    if not ov.quest then
        ov.quest        = { enabled = false, icon = "Quest-Campaign-Available",        position = "CENTER",      scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.quest.applyToAuctionHouse == nil then
        ov.quest.applyToAuctionHouse = false
    end
    if not ov.reagents then
        ov.reagents     = { enabled = false, icon = "Bonus-Objective-Star",            position = "TOPRIGHT",    scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.reagents.applyToAuctionHouse == nil then
        ov.reagents.applyToAuctionHouse = false
    end
    if not ov.recipe then
        ov.recipe       = { enabled = false, icon = "icon-recipe",                     position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.recipe.applyToAuctionHouse == nil then
        ov.recipe.applyToAuctionHouse = false
    end
    if not ov.soulbound then
        ov.soulbound    = { enabled = false, icon = "VignetteKill",                    position = "TOPLEFT",     scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.soulbound.applyToAuctionHouse == nil then
        ov.soulbound.applyToAuctionHouse = false
    end
    if not ov.toys then
        ov.toys         = { enabled = false, icon = "icon-toy",                        position = "BOTTOMRIGHT", scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.toys.applyToAuctionHouse == nil then
        ov.toys.applyToAuctionHouse = false
    end
    if not ov.warbound then
        ov.warbound     = { enabled = false, icon = "warbands-icon",                   position = "TOPLEFT",     scale = 1.0, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false }
    end
    if ov.warbound.applyToAuctionHouse == nil then
        ov.warbound.applyToAuctionHouse = false
    end
    if not ov.junk then
        ov.junk         = { enabled = false, icon = "bags-junkcoin",                   position = "CENTER",      scale = 1.5, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false, showInTooltip = true }
    end
    if ov.junk.applyToAuctionHouse == nil then
        ov.junk.applyToAuctionHouse = false
    end
    if not ov.protected then
        ov.protected    = { enabled = false, icon = "soulbinds_tree_conduit_icon_protect", position = "CENTER",  scale = 1.5, alpha = 1.0, applyToVendorItems = false, applyToAuctionHouse = false, showInTooltip = true }
    end
    if ov.protected.applyToAuctionHouse == nil then
        ov.protected.applyToAuctionHouse = false
    end
    if not ov.integrations then
        ov.integrations = {}
    end
    if not ov.integrations.arkinventory then
        ov.integrations.arkinventory = { enabled = true }
    end
    if ov.integrations.arkinventory.enabled == nil then
        ov.integrations.arkinventory.enabled = true
    end
    if not ov.integrations.baganator then
        ov.integrations.baganator = { enabled = true }
    end
    if ov.integrations.baganator.enabled == nil then
        ov.integrations.baganator.enabled = true
    end
    if not ov.integrations.betterbags then
        ov.integrations.betterbags = { enabled = true }
    end
    if ov.integrations.betterbags.enabled == nil then
        ov.integrations.betterbags.enabled = true
    end
    if not ov.integrations.onewow_bags then
        ov.integrations.onewow_bags = { enabled = true }
    end
    if ov.integrations.onewow_bags.enabled == nil then
        ov.integrations.onewow_bags.enabled = true
    end
    if not self.db.global.settings.toastalerts then
        self.db.global.settings.toastalerts = {}
    end
    local ta = self.db.global.settings.toastalerts
    if not ta.general        then ta.general        = { enabled = false } end
    if not ta.detectiontypes then ta.detectiontypes = { enabled = false } end
    if not ta.instances      then ta.instances      = { enabled = false } end
    if not ta.notealerts     then ta.notealerts     = { enabled = false } end
    if not ta.upgrades       then ta.upgrades       = { enabled = false } end
    if not self.db.global.settings.tooltips then
        self.db.global.settings.tooltips = {}
    end
    local tt = self.db.global.settings.tooltips
    if not tt.general then
        tt.general = { enabled = true }
    end
    if tt.general.enabled == nil then
        tt.general.enabled = true
    end
    if not tt.technicalids then
        tt.technicalids = { enabled = false }
    end
    local tid = tt.technicalids
    if tid.showItemID == nil then tid.showItemID = true end
    if tid.showSpellID == nil then tid.showSpellID = true end
    if tid.showNpcID == nil then tid.showNpcID = true end
    if tid.showAchievementID == nil then tid.showAchievementID = true end
    if tid.showQuestID == nil then tid.showQuestID = true end
    if tid.showCurrencyID == nil then tid.showCurrencyID = true end
    if tid.showMountID == nil then tid.showMountID = true end
    if tid.showPetID == nil then tid.showPetID = true end
    if tid.showEnchantID == nil then tid.showEnchantID = true end
    if tid.showIconID == nil then tid.showIconID = true end
    if tid.showExpansionID == nil then tid.showExpansionID = true end
    if tid.showSetID == nil then tid.showSetID = true end
    if tid.showDecorEntryID == nil then tid.showDecorEntryID = true end
    if tid.showRecipeID == nil then tid.showRecipeID = true end
    if tid.showEquipmentSetID == nil then tid.showEquipmentSetID = true end
    if tid.showEssenceID == nil then tid.showEssenceID = true end
    if tid.showConduitID == nil then tid.showConduitID = true end
    if tid.showOutfitID == nil then tid.showOutfitID = true end
    if tid.showMacroID == nil then tid.showMacroID = true end
    if tid.showObjectID == nil then tid.showObjectID = true end
    if tid.showAbilityID == nil then tid.showAbilityID = true end
    if tid.showAreaPoiID == nil then tid.showAreaPoiID = true end
    if tid.showArtifactPowerID == nil then tid.showArtifactPowerID = true end
    if tid.showBonusID == nil then tid.showBonusID = true end
    if tid.showCompanionID == nil then tid.showCompanionID = true end
    if tid.showCriteriaID == nil then tid.showCriteriaID = true end
    if tid.showGemID == nil then tid.showGemID = true end
    if tid.showSourceID == nil then tid.showSourceID = true end
    if tid.showTalentID == nil then tid.showTalentID = true end
    if tid.showTraitDefinitionID == nil then tid.showTraitDefinitionID = false end
    if tid.showTraitEntryID == nil then tid.showTraitEntryID = false end
    if tid.showTraitNodeID == nil then tid.showTraitNodeID = false end
    if tid.showVignetteID == nil then tid.showVignetteID = true end
    if tid.showVisualID == nil then tid.showVisualID = true end

    if not tt.itemtracker then
        tt.itemtracker = { enabled = true }
    end
    if not tt.recipeknowledge then
        tt.recipeknowledge = { enabled = true }
    end
    if tt.itemtracker.enabled == nil then
        tt.itemtracker.enabled = true
    end
    if tt.itemtracker.colorByClass == nil then
        tt.itemtracker.colorByClass = true
    end
    if tt.itemtracker.characterLimit == nil then
        tt.itemtracker.characterLimit = 10
    end
    if tt.itemtracker.showAlts        == nil then tt.itemtracker.showAlts        = true end
    if tt.itemtracker.showBags        == nil then tt.itemtracker.showBags        = true end
    if tt.itemtracker.showBank        == nil then tt.itemtracker.showBank        = true end
    if tt.itemtracker.showEquipped    == nil then tt.itemtracker.showEquipped    = true end
    if tt.itemtracker.showAuctions    == nil then tt.itemtracker.showAuctions    = true end
    if tt.itemtracker.showWarbandBank == nil then tt.itemtracker.showWarbandBank = true end
    if tt.itemtracker.showGuildBanks  == nil then tt.itemtracker.showGuildBanks  = true end
    if tt.itemtracker.showVendors     == nil then tt.itemtracker.showVendors     = true end
    if tt.itemtracker.showInstances   == nil then tt.itemtracker.showInstances   = true end

    if not self.db.global.itemStatus then
        self.db.global.itemStatus = {}
    end

    if not self.db.global.toasts then
        self.db.global.toasts = {}
    end
    local ts = self.db.global.toasts
    if ts.enabled == nil then ts.enabled = false end
    if not ts.anchor then ts.anchor = { x = nil, y = nil } end
    if ts.anchor.visible == nil then ts.anchor.visible = true end
    if ts.anchor.locked  == nil then ts.anchor.locked  = false end

    if not ts.loot then ts.loot = {} end
    local tl = ts.loot
    if tl.enabled == nil then tl.enabled = false end
    if tl.mounts  == nil then tl.mounts  = false end
    if tl.pets    == nil then tl.pets    = false end
    if tl.toys    == nil then tl.toys    = false end
    if tl.recipes == nil then tl.recipes = false end
    if tl.tmogs   == nil then tl.tmogs   = false end
    if tl.sound   == nil then tl.sound   = SOUNDKIT.READY_CHECK end

    if not ts.notes then ts.notes = {} end
    local tn = ts.notes
    if tn.enabled == nil then tn.enabled = false end
    if tn.npcs    == nil then tn.npcs    = false end
    if tn.players == nil then tn.players = false end
    if tn.zones   == nil then tn.zones   = false end
    if tn.sound   == nil then tn.sound   = SOUNDKIT.ACHIEVEMENT_MENU_OPEN end

    if not ts.instance then ts.instance = {} end
    local ti = ts.instance
    if ti.enabled == nil then ti.enabled = false end
    if ti.sound   == nil then ti.sound   = 0 end

    if not ts.resetToDefaultsV1 then
        ts.resetToDefaultsV1 = true
        ts.enabled = false
        tl.enabled = false
        tl.mounts  = false
        tl.pets    = false
        tl.toys    = false
        tl.recipes = false
        tl.tmogs   = false
        tn.enabled = false
        tn.npcs    = false
        tn.players = false
        tn.zones   = false
        ti.enabled = false
        if ta.general        then ta.general.enabled        = false end
        if ta.detectiontypes then ta.detectiontypes.enabled = false end
        if ta.instances      then ta.instances.enabled      = false end
        if ta.notealerts     then ta.notealerts.enabled     = false end
        ts.anchor.visible = true
        ts.anchor.locked  = false
    end

    if not self.db.global.profiles then
        self.db.global.profiles = {}
    end
    if self.db.global.activeProfile == nil then
        self.db.global.activeProfile = nil
    end
    if not self.db.global.charProfiles then
        self.db.global.charProfiles = {}
    end
    if self.db.global.defaultProfile == nil then
        self.db.global.defaultProfile = nil
    end
end
