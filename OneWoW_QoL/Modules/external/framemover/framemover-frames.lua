local addonName, ns = ...

local R = {}
ns.FrameMoverFrames = R

-- ============================================================
-- Category definitions (display order)
-- ============================================================

R.CATEGORIES = {
    { id = "CORE",        label = "FRAMEMOVER_CAT_CORE" },
    { id = "COLLECTIONS", label = "FRAMEMOVER_CAT_COLLECTIONS" },
    { id = "CHARACTER",   label = "FRAMEMOVER_CAT_CHARACTER" },
    { id = "PROFESSIONS", label = "FRAMEMOVER_CAT_PROFESSIONS" },
    { id = "GROUP",       label = "FRAMEMOVER_CAT_GROUP" },
    { id = "SOCIAL",      label = "FRAMEMOVER_CAT_SOCIAL" },
    { id = "HOUSING",     label = "FRAMEMOVER_CAT_HOUSING" },
    { id = "MISC",        label = "FRAMEMOVER_CAT_MISC" },
}

-- ============================================================
-- Friendly display-name overrides (auto-generated otherwise)
-- ============================================================

R.DISPLAY_NAMES = {
    ["ContainerFrameCombinedBags"]  = "Combined Bags",
    ["ContainerFrame1"]             = "Bag 1",
    ["PVEFrame"]                    = "Group Finder (PVE)",
    ["PVPMatchResults"]             = "PvP Match Results",
    ["PVPMatchScoreboard"]          = "PvP Scoreboard",
    ["QuestLogPopupDetailFrame"]    = "Quest Detail Popup",
    ["HelpFrame"]                   = "Support / Help",
    ["DressUpFrame"]                = "Dressing Room",
    ["SettingsPanel"]               = "Game Settings",
    ["AddonList"]                   = "AddOn List",
    ["ChatConfigFrame"]             = "Chat Settings",
    ["GameMenuFrame"]               = "Game Menu (Esc)",
    ["GossipFrame"]                 = "NPC Gossip",
    ["QuestFrame"]                  = "Quest Dialog",
    ["TaxiFrame"]                   = "Flight Map (Taxi)",
    ["MerchantFrame"]               = "Vendor",
    ["MailFrame"]                    = "Mailbox",
    ["LootFrame"]                   = "Loot Window",
    ["BankFrame"]                   = "Bank",
    ["TradeFrame"]                  = "Trade",
    ["ItemTextFrame"]               = "Item / Book Text",
    ["ReadyCheckFrame"]             = "Ready Check",
    ["ModelPreviewFrame"]           = "Model Preview",
    ["SplashFrame"]                 = "Expansion Splash",
    ["TalkingHeadFrame"]            = "Talking Head",
    ["AchievementFrame"]            = "Achievements",
    ["CollectionsJournal"]          = "Collections",
    ["EncounterJournal"]            = "Adventure Guide",
    ["ProfessionsFrame"]            = "Professions",
    ["AuctionHouseFrame"]           = "Auction House",
    ["BlackMarketFrame"]            = "Black Market AH",
    ["GuildBankFrame"]              = "Guild Bank",
    ["InspectFrame"]                = "Inspect",
    ["CalendarFrame"]               = "Calendar",
    ["CommunitiesFrame"]            = "Communities / Guild",
    ["TimeManagerFrame"]            = "Clock / Stopwatch",
    ["ChallengesKeystoneFrame"]     = "Keystone Slot",
    ["WeeklyRewardsFrame"]          = "Great Vault",
    ["ClassTalentFrame"]            = "Talents (DF)",
    ["PlayerSpellsFrame"]           = "Talents & Spellbook",
    ["GenericTraitFrame"]           = "Trait Tree",
    ["ItemUpgradeFrame"]            = "Item Upgrade",
    ["ItemInteractionFrame"]        = "Item Interaction",
    ["CovenantMissionFrame"]        = "Covenant Missions",
    ["ExpansionLandingPage"]        = "Expansion Landing",
    ["GarrisonLandingPage"]         = "Garrison Report",
    ["AlliedRacesFrame"]            = "Allied Races",
    ["ChromieTimeFrame"]            = "Chromie Time",
    ["ChannelFrame"]                = "Chat Channels",
    ["MacroFrame"]                  = "Macros",
    ["KeyBindingFrame"]             = "Key Bindings",
    ["BarberShopFrame"]             = "Barber Shop",
    ["FlightMapFrame"]              = "Flight Map (World)",
    ["VoidStorageFrame"]            = "Void Storage",
    ["ScrappingMachineFrame"]       = "Scrapper",
    ["ItemSocketingFrame"]          = "Gem Socketing",
    ["ArchaeologyFrame"]            = "Archaeology",
    ["ClickBindingFrame"]           = "Click Bindings",
    ["AccountStoreFrame"]           = "Trading Post",
    ["ProfessionsBookFrame"]        = "Professions Book",
    ["ProfessionsCustomerOrdersFrame"] = "Crafting Orders",
    ["InspectRecipeFrame"]          = "Inspect Recipe",
    ["StableFrame"]                 = "Pet Stable",
    ["DeathRecapFrame"]             = "Death Recap",
    ["HeroTalentsSelectionDialog"]  = "Hero Talent Choice",
    ["DelvesDifficultyPickerFrame"] = "Delves Difficulty",
    ["DelvesCompanionConfigurationFrame"] = "Delves Companion",
    ["DelvesCompanionAbilityListFrame"]   = "Delves Abilities",
    ["CooldownViewerSettings"]      = "Cooldown Viewer",
    ["HousingDashboardFrame"]       = "Housing Dashboard",
    ["HouseFinderFrame"]            = "House Finder",
    ["HousingBulletinBoardFrame"]   = "Housing Bulletin",
    ["HousingCornerstoneFrame"]     = "Housing Cornerstone",
    ["HousingHouseSettingsFrame"]   = "House Settings",
    ["HousingModelPreviewFrame"]    = "Housing Preview",
    ["HouseListFrame"]              = "House List",
    ["TransmogFrame"]               = "Transmog",
    ["WardrobeFrame"]               = "Wardrobe",
    ["RemixArtifactFrame"]          = "Remix Artifact",
    ["GuildRenameFrame"]            = "Guild Rename",
}

-- ============================================================
-- Utility: auto-generate a display name from a frame path
-- ============================================================

function R:PrettyName(frameName)
    if self.DISPLAY_NAMES[frameName] then
        return self.DISPLAY_NAMES[frameName]
    end
    local short = frameName:match("%.([^%.]+)$") or frameName
    short = short:gsub("Frame$", ""):gsub("UI$", ""):gsub("Panel$", "")
    short = short:gsub("(%l)(%u)", "%1 %2")
    short = short:gsub("(%u%u)(%u%l)", "%1 %2")
    short = short:match("^%s*(.-)%s*$") or short
    if short == "" then short = frameName end
    return short
end

-- ============================================================
-- Helpers to query the registry
-- ============================================================

function R:GetAllFrames()
    local all = {}
    for _, e in ipairs(self.GLOBAL) do all[#all + 1] = e end
    for _, list in pairs(self.ADDONS) do
        for _, e in ipairs(list) do all[#all + 1] = e end
    end
    return all
end

function R:GetFramesByCategory(catId)
    local out = {}
    for _, e in ipairs(self.GLOBAL) do
        if e.category == catId then out[#out + 1] = e end
    end
    for _, list in pairs(self.ADDONS) do
        for _, e in ipairs(list) do
            if e.category == catId then out[#out + 1] = e end
        end
    end
    table.sort(out, function(a, b) return self:PrettyName(a.name) < self:PrettyName(b.name) end)
    return out
end

-- ============================================================
-- GLOBAL frames  (always available in FrameXML)
-- ============================================================

R.GLOBAL = {
    -- Core UI
    { name = "CharacterFrame",          category = "CORE" },
    { name = "FriendsFrame",            category = "CORE" },
    { name = "WorldMapFrame",           category = "CORE" },
    { name = "QuestFrame",              category = "CORE" },
    { name = "GossipFrame",             category = "CORE" },
    { name = "MerchantFrame",           category = "CORE" },
    { name = "MailFrame",               category = "CORE" },
    { name = "BankFrame",               category = "CORE" },
    { name = "TradeFrame",              category = "CORE" },
    { name = "LootFrame",              category = "CORE" },
    { name = "DressUpFrame",            category = "CORE" },
    { name = "GameMenuFrame",           category = "CORE" },
    { name = "SettingsPanel",           category = "CORE" },
    { name = "AddonList",               category = "CORE" },
    { name = "HelpFrame",               category = "CORE" },
    { name = "ChatConfigFrame",         category = "CORE" },
    { name = "ItemTextFrame",           category = "CORE" },
    { name = "ReadyCheckFrame",         category = "CORE" },
    { name = "ModelPreviewFrame",       category = "CORE" },
    { name = "TaxiFrame",              category = "CORE" },
    { name = "SplashFrame",             category = "CORE" },
    { name = "TalkingHeadFrame",        category = "CORE" },
    { name = "GuildInviteFrame",        category = "CORE" },
    { name = "PVEFrame",                category = "GROUP" },
    { name = "QuestLogPopupDetailFrame",category = "CORE" },
    { name = "QuickKeybindFrame",       category = "CORE" },
    { name = "PingSystemTutorial",      category = "MISC" },
    { name = "ContainerFrame1",         category = "CORE" },
    { name = "ContainerFrameCombinedBags", category = "CORE" },
    { name = "DestinyFrame",            category = "MISC" },
}

-- ============================================================
-- ADDON frames  (load-on-demand Blizzard addons)
-- ============================================================

R.ADDONS = {

    -- Collections & Journals --------------------------------
    ["Blizzard_AchievementUI"] = {
        { name = "AchievementFrame", category = "COLLECTIONS" },
    },
    ["Blizzard_Collections"] = {
        { name = "CollectionsJournal", category = "COLLECTIONS" },
    },
    ["Blizzard_EncounterJournal"] = {
        { name = "EncounterJournal", category = "COLLECTIONS" },
    },

    -- Character & Talents -----------------------------------
    ["Blizzard_ClassTalentUI"] = {
        { name = "ClassTalentFrame", category = "CHARACTER" },
    },
    ["Blizzard_PlayerSpells"] = {
        { name = "PlayerSpellsFrame",          category = "CHARACTER" },
        { name = "HeroTalentsSelectionDialog", category = "CHARACTER" },
    },
    ["Blizzard_GenericTraitUI"] = {
        { name = "GenericTraitFrame", category = "CHARACTER" },
    },
    ["Blizzard_TalentUI"] = {
        { name = "PlayerTalentFrame", category = "CHARACTER" },
    },
    ["Blizzard_InspectUI"] = {
        { name = "InspectFrame", category = "SOCIAL" },
    },
    ["Blizzard_AlliedRacesUI"] = {
        { name = "AlliedRacesFrame", category = "CHARACTER" },
    },

    -- Professions & Economy ---------------------------------
    ["Blizzard_Professions"] = {
        { name = "ProfessionsFrame",  category = "PROFESSIONS" },
        { name = "InspectRecipeFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ProfessionsBook"] = {
        { name = "ProfessionsBookFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ProfessionsCustomerOrders"] = {
        { name = "ProfessionsCustomerOrdersFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_AuctionHouseUI"] = {
        { name = "AuctionHouseFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_BlackMarketUI"] = {
        { name = "BlackMarketFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_GuildBankUI"] = {
        { name = "GuildBankFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_VoidStorageUI"] = {
        { name = "VoidStorageFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ItemUpgradeUI"] = {
        { name = "ItemUpgradeFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ItemInteractionUI"] = {
        { name = "ItemInteractionFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ItemSocketingUI"] = {
        { name = "ItemSocketingFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_AccountStore"] = {
        { name = "AccountStoreFrame", category = "PROFESSIONS" },
    },
    ["Blizzard_ScrappingMachineUI"] = {
        { name = "ScrappingMachineFrame", category = "PROFESSIONS" },
    },

    -- Group Content -----------------------------------------
    ["Blizzard_ChallengesUI"] = {
        { name = "ChallengesKeystoneFrame", category = "GROUP" },
    },
    ["Blizzard_WeeklyRewards"] = {
        { name = "WeeklyRewardsFrame", category = "GROUP" },
    },
    ["Blizzard_PVPMatch"] = {
        { name = "PVPMatchResults", category = "GROUP" },
    },
    ["Blizzard_PVPUI"] = {
        { name = "PVPMatchScoreboard", category = "GROUP" },
    },
    ["Blizzard_DelvesCompanionConfiguration"] = {
        { name = "DelvesCompanionConfigurationFrame", category = "GROUP" },
        { name = "DelvesCompanionAbilityListFrame",   category = "GROUP" },
    },
    ["Blizzard_DelvesDifficultyPicker"] = {
        { name = "DelvesDifficultyPickerFrame", category = "GROUP" },
    },
    ["Blizzard_IslandsQueueUI"] = {
        { name = "IslandsQueueFrame", category = "GROUP" },
    },

    -- Social & Guilds ---------------------------------------
    ["Blizzard_Calendar"] = {
        { name = "CalendarFrame", category = "SOCIAL" },
    },
    ["Blizzard_Communities"] = {
        { name = "CommunitiesFrame", category = "SOCIAL" },
    },
    ["Blizzard_Channels"] = {
        { name = "ChannelFrame", category = "SOCIAL" },
    },
    ["Blizzard_GuildUI"] = {
        { name = "GuildFrame", category = "SOCIAL" },
    },
    ["Blizzard_GuildControlUI"] = {
        { name = "GuildControlUI", category = "SOCIAL" },
    },
    ["Blizzard_GuildRename"] = {
        { name = "GuildRenameFrame", category = "SOCIAL" },
    },

    -- Housing -----------------------------------------------
    ["Blizzard_HousingDashboard"] = {
        { name = "HousingDashboardFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingHouseFinder"] = {
        { name = "HouseFinderFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingBulletinBoard"] = {
        { name = "HousingBulletinBoardFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingCornerstone"] = {
        { name = "HousingCornerstoneFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingHouseSettings"] = {
        { name = "HousingHouseSettingsFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingModelPreview"] = {
        { name = "HousingModelPreviewFrame", category = "HOUSING" },
    },
    ["Blizzard_HouseList"] = {
        { name = "HouseListFrame", category = "HOUSING" },
    },
    ["Blizzard_HousingCreateNeighborhood"] = {
        { name = "HousingCreateNeighborhoodCharterFrame", category = "HOUSING" },
    },

    -- Miscellaneous -----------------------------------------
    ["Blizzard_MacroUI"] = {
        { name = "MacroFrame", category = "MISC" },
    },
    ["Blizzard_BindingUI"] = {
        { name = "KeyBindingFrame", category = "MISC" },
    },
    ["Blizzard_TimeManager"] = {
        { name = "TimeManagerFrame", category = "MISC" },
    },
    ["Blizzard_ArchaeologyUI"] = {
        { name = "ArchaeologyFrame", category = "MISC" },
    },
    ["Blizzard_DeathRecap"] = {
        { name = "DeathRecapFrame", category = "MISC" },
    },
    ["Blizzard_ClickBindingUI"] = {
        { name = "ClickBindingFrame", category = "MISC" },
    },
    ["Blizzard_ChromieTimeUI"] = {
        { name = "ChromieTimeFrame", category = "MISC" },
    },
    ["Blizzard_FlightMap"] = {
        { name = "FlightMapFrame", category = "MISC" },
    },
    ["Blizzard_ExpansionLandingPage"] = {
        { name = "ExpansionLandingPage", category = "MISC" },
    },
    ["Blizzard_StableUI"] = {
        { name = "StableFrame", category = "MISC" },
    },
    ["Blizzard_BehavioralMessaging"] = {
        { name = "BehavioralMessagingDetails", category = "MISC" },
    },
    ["Blizzard_CooldownViewer"] = {
        { name = "CooldownViewerSettings", category = "MISC" },
    },
    ["Blizzard_TokenUI"] = {
        { name = "CurrencyTransferMenu", category = "MISC" },
    },
    ["Blizzard_Transmog"] = {
        { name = "TransmogFrame", category = "COLLECTIONS" },
    },
    ["Blizzard_RemixArtifactUI"] = {
        { name = "RemixArtifactFrame", category = "CHARACTER" },
    },
    ["Blizzard_GarrisonUI"] = {
        { name = "CovenantMissionFrame",  category = "MISC" },
        { name = "GarrisonLandingPage",   category = "MISC" },
    },
    ["Blizzard_OrderHallUI"] = {
        { name = "OrderHallTalentFrame", category = "MISC" },
    },
    ["Blizzard_Soulbinds"] = {
        { name = "SoulbindViewer", category = "MISC" },
    },
    ["Blizzard_RuneforgeUI"] = {
        { name = "RuneforgeFrame", category = "MISC" },
    },
    ["Blizzard_PlayerChoice"] = {
        { name = "PlayerChoiceFrame", category = "MISC" },
    },
    ["Blizzard_SubscriptionInterstitialUI"] = {
        { name = "SubscriptionInterstitialFrame", category = "MISC" },
    },
    ["Blizzard_MajorFactions"] = {
        { name = "MajorFactionRenownFrame", category = "MISC" },
    },
    ["Blizzard_Contribution"] = {
        { name = "ContributionCollectionFrame", category = "MISC" },
    },
    ["Blizzard_CovenantPreviewUI"] = {
        { name = "CovenantPreviewFrame", category = "MISC" },
    },
    ["Blizzard_CovenantRenown"] = {
        { name = "CovenantRenownFrame", category = "MISC" },
    },
    ["Blizzard_CovenantSanctum"] = {
        { name = "CovenantSanctumFrame", category = "MISC" },
    },
    ["Blizzard_AnimaDiversionUI"] = {
        { name = "AnimaDiversionFrame", category = "MISC" },
    },
    ["Blizzard_TrainerUI"] = {
        { name = "ClassTrainerFrame", category = "MISC" },
    },
}
