local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker

ns.Core = {}
local Core = ns.Core

function Core:Initialize()
    self.initialized = true

    self:CheckForWoWNotesDataMigration()

    if ns.MigrationFix then
        ns.MigrationFix:FixImportedData()
        ns.MigrationFix:CleanupWrongPlacedData()
    end

    if ns.AlttrackerModule and ns.AlttrackerModule.Initialize then
        ns.AlttrackerModule:Initialize()
    end
end

function Core:CheckForWoWNotesDataMigration()
    local OneWoWAltTracker = _G.OneWoW_AltTracker
    if not OneWoWAltTracker or not _G.OneWoW_AltTracker.db or not _G.OneWoW_AltTracker.db.global then
        return
    end

    local migrationStatus = _G.OneWoW_AltTracker.db.global.migrationStatus

    if not migrationStatus.cleanupPerformed then
        self:CleanupOldMigrationData()
    end

    if migrationStatus.migrationComplete then
        return
    end

    if not _G.WoWNotes or not _G.WoWNotes.db or not _G.WoWNotes.db.global then
        migrationStatus.checkedForWoWNotesData = true
        migrationStatus.lastMigrationCheck = time()
        return
    end

    local wownotes = _G.WoWNotes.db.global
    if not wownotes.altTracker or not wownotes.altTracker.characters then
        migrationStatus.checkedForWoWNotesData = true
        migrationStatus.lastMigrationCheck = time()
        return
    end

    local charCount = 0
    for _ in pairs(wownotes.altTracker.characters) do
        charCount = charCount + 1
    end

    if charCount == 0 then
        migrationStatus.checkedForWoWNotesData = true
        migrationStatus.lastMigrationCheck = time()
        return
    end

    C_Timer.After(2, function()
        self:ShowMigrationDialog(charCount)
    end)
end

function Core:CleanupOldMigrationData()
    local targetDB = _G.OneWoW_AltTracker.db.global
    if not targetDB then return end

    targetDB.altTracker = nil
    targetDB.warbandBankData = nil
    targetDB.guildBanks = nil
    targetDB.actionBars = nil

    if targetDB.migrationStatus then
        targetDB.migrationStatus.cleanupPerformed = true
    end
end

function Core:CheckSubAddons()
    local subAddons = {
        Character = _G.OneWoW_AltTracker_Character_DB,
        Professions = _G.OneWoW_AltTracker_Professions_DB,
        Endgame = _G.OneWoW_AltTracker_Endgame_DB
    }

    local available = {}
    local missing = {}

    for name, db in pairs(subAddons) do
        if db then
            available[name] = true
        else
            table.insert(missing, name)
        end
    end

    return available, missing
end

function Core:ShowMigrationDialog(charCount)
    local L = ns.L
    local T = ns.T
    local available, missing = self:CheckSubAddons()

    if _G.OneWoWMigrationDialog then
        _G.OneWoWMigrationDialog.bodyText:SetText(string.format(L["MIGRATION_DIALOG_TEXT"], charCount))
        _G.OneWoWMigrationDialog:Show()
        _G.OneWoWMigrationDialog:Raise()
        return
    end

    local dialog = CreateFrame("Frame", "OneWoWMigrationDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 390)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    tinsert(UISpecialFrames, "OneWoWMigrationDialog")

    local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("BG_SECONDARY"))

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(16, 16)
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    titleText:SetText(L["IMPORT_FROM_WOWNOTES"] or "Import WoWNotes Data")
    titleText:SetTextColor(T("ACCENT_PRIMARY"))

    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -29)
    divider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -29)
    divider:SetColorTexture(T("BORDER_SUBTLE"))

    local bodyText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -46)
    bodyText:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -18, -46)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(4)
    bodyText:SetText(string.format(L["MIGRATION_DIALOG_TEXT"], charCount))
    bodyText:SetTextColor(T("TEXT_PRIMARY"))
    dialog.bodyText = bodyText

    if #missing > 0 then
        local warnText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        warnText:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", 0, -10)
        warnText:SetPoint("TOPRIGHT", bodyText, "BOTTOMRIGHT", 0, -10)
        warnText:SetJustifyH("LEFT")
        warnText:SetWordWrap(true)
        warnText:SetText(string.format(L["MIGRATION_ERROR_MISSING_SUBADDONS"], table.concat(missing, ", ")))
        warnText:SetTextColor(1, 0.7, 0.3)
    end

    local btnDivider = dialog:CreateTexture(nil, "ARTWORK")
    btnDivider:SetHeight(1)
    btnDivider:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 1, 56)
    btnDivider:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 56)
    btnDivider:SetColorTexture(T("BORDER_SUBTLE"))

    local yesBtn = ns.UI.CreateButton(nil, dialog, L["MIGRATION_YES"], 180, 32)
    yesBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 14)
    yesBtn:SetScript("OnClick", function()
        dialog:Hide()
        Core:PerformDataMigration()
    end)

    local noBtn = ns.UI.CreateButton(nil, dialog, L["MIGRATION_NO"], 180, 32)
    noBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 14)
    noBtn:SetScript("OnClick", function()
        dialog:Hide()
        _G.OneWoW_AltTracker.db.global.migrationStatus.checkedForWoWNotesData = true
        _G.OneWoW_AltTracker.db.global.migrationStatus.lastMigrationCheck = time()
    end)

    dialog:Show()
end

function Core:SimplifyProfessions(professionsData)
    if not professionsData then return {} end

    local simplified = {}
    for profName, profData in pairs(professionsData) do
        if profData and profData.name then
            simplified[profName] = {
                name = profData.name,
                skillLevel = profData.skillLevel or 0,
                maxSkillLevel = profData.maxSkillLevel or 0
            }
        end
    end
    return simplified
end

function Core:PerformDataMigration()
    local L = ns.L

    if not _G.WoWNotes or not _G.WoWNotes.db or not _G.WoWNotes.db.global then
        print("|cFFFFD100OneWoW - AltTracker:|r " .. L["MIGRATION_ERROR_NO_DATA"])
        return
    end

    local sourceDB = _G.WoWNotes.db.global
    local available, missing = self:CheckSubAddons()

    local counts = {
        character = 0,
        professions = 0,
        endgame = 0,
        total = 0
    }

    if sourceDB.altTracker and sourceDB.altTracker.characters then
        for charKey, charData in pairs(sourceDB.altTracker.characters) do
            counts.total = counts.total + 1

            if available.Character and _G.OneWoW_AltTracker_Character_DB then
                if not _G.OneWoW_AltTracker_Character_DB.characters then
                    _G.OneWoW_AltTracker_Character_DB.characters = {}
                end

                local normalizedClass = charData.class
                local classDisplayName = charData.className

                if normalizedClass then
                    normalizedClass = string.upper(normalizedClass)
                    normalizedClass = string.gsub(normalizedClass, " ", "")
                    normalizedClass = string.gsub(normalizedClass, "-", "")

                    if not classDisplayName then
                        local classNames = {
                            WARRIOR = "Warrior",
                            PALADIN = "Paladin",
                            HUNTER = "Hunter",
                            ROGUE = "Rogue",
                            PRIEST = "Priest",
                            DEATHKNIGHT = "Death Knight",
                            SHAMAN = "Shaman",
                            MAGE = "Mage",
                            WARLOCK = "Warlock",
                            MONK = "Monk",
                            DRUID = "Druid",
                            DEMONHUNTER = "Demon Hunter",
                            EVOKER = "Evoker",
                        }
                        classDisplayName = classNames[normalizedClass] or charData.className or normalizedClass
                    end
                end

                local charDBEntry = {
                    key = charKey,
                    name = charData.name,
                    level = charData.level,
                    class = normalizedClass or string.upper(charData.class or ""),
                    className = classDisplayName or charData.className,
                    race = charData.race,
                    raceFile = charData.raceFile,
                    raceName = charData.raceName,
                    sex = charData.sex,
                    faction = charData.faction,
                    factionLocalized = charData.factionLocalized,
                    realm = charData.realm,
                    money = charData.money,
                    guid = charData.guid,
                    guild = charData.guild and {
                        name = charData.guild,
                        rank = charData.guildRank,
                        rankIndex = charData.guildRankIndex,
                    } or nil,
                    title = charData.title,
                    lastLogin = charData.lastLogin,
                    itemLevel = charData.itemLevel or 0,
                    itemLevelColor = charData.itemLevelColor,
                }

                if charData.restedXP or charData.currentXP or charData.maxXP or charData.restState then
                    charDBEntry.xp = {
                        restedXP = charData.restedXP or 0,
                        currentXP = charData.currentXP or 0,
                        maxXP = charData.maxXP or 0,
                        restState = charData.restState or 0,
                        isXPDisabled = charData.isXPDisabled or false,
                        isResting = charData.isResting or false,
                    }
                end

                if charData.hearthLocation then
                    charDBEntry.location = {
                        bindLocation = charData.hearthLocation,
                    }
                end

                if charData.specialization or charData.activeSpec then
                    local specName = charData.specialization or charData.activeSpec
                    if type(specName) == "table" and specName.name then
                        specName = specName.name
                    end
                    specName = tostring(specName or "")
                    charDBEntry.stats = {
                        specName = specName,
                    }
                end

                _G.OneWoW_AltTracker_Character_DB.characters[charKey] = charDBEntry

                if sourceDB.actionBars and sourceDB.actionBars[charKey] then
                    _G.OneWoW_AltTracker_Character_DB.characters[charKey].actionBars = CopyTable(sourceDB.actionBars[charKey])
                end

                counts.character = counts.character + 1
            end

            if available.Professions and _G.OneWoW_AltTracker_Professions_DB then
                if not _G.OneWoW_AltTracker_Professions_DB.characters then
                    _G.OneWoW_AltTracker_Professions_DB.characters = {}
                end

                _G.OneWoW_AltTracker_Professions_DB.characters[charKey] = {
                    professions = self:SimplifyProfessions(charData.professions)
                }

                counts.professions = counts.professions + 1
            end

            if available.Endgame and _G.OneWoW_AltTracker_Endgame_DB then
                if not _G.OneWoW_AltTracker_Endgame_DB.characters then
                    _G.OneWoW_AltTracker_Endgame_DB.characters = {}
                end

                _G.OneWoW_AltTracker_Endgame_DB.characters[charKey] = {
                    mythicPlusRating = charData.mythicPlusRating,
                    mythicPlus = charData.mythicPlus,
                    covenant = charData.covenant,
                    renownLevel = charData.renownLevel,
                    raidProgressLFR = charData.raidProgressLFR,
                    raidProgressNormal = charData.raidProgressNormal,
                    raidProgressHeroic = charData.raidProgressHeroic,
                    raidProgressMythic = charData.raidProgressMythic,
                    raidProgress = charData.raidProgress,
                    weeklyProgress = charData.weeklyProgress,
                    currencyData = charData.currencyData,
                    equipment = charData.equipment
                }

                counts.endgame = counts.endgame + 1
            end
        end
    end

    local targetDB = _G.OneWoW_AltTracker.db.global
    targetDB.migrationStatus.checkedForWoWNotesData = true
    targetDB.migrationStatus.lastMigrationCheck = time()
    targetDB.migrationStatus.migratedCharacterCount = counts.total
    targetDB.migrationStatus.migrationComplete = true
    targetDB.migrationStatus.migratedToDistributed = true
    targetDB.migrationStatus.subAddonsAvailable = available

    print("|cFFFFD100OneWoW - AltTracker:|r " .. string.format(L["MIGRATION_SUCCESS"],
        counts.total, counts.character, counts.professions, counts.endgame))

    C_Timer.After(1, function()
        self:ShowCleanupReminderDialog()
    end)
end

function Core:ShowCleanupReminderDialog()
    local L = ns.L
    local T = ns.T

    if _G.OneWoWCleanupDialog then
        _G.OneWoWCleanupDialog:Show()
        _G.OneWoWCleanupDialog:Raise()
        return
    end

    local dialog = CreateFrame("Frame", "OneWoWCleanupDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(460, 210)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    tinsert(UISpecialFrames, "OneWoWCleanupDialog")

    local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("BG_SECONDARY"))

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(16, 16)
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    titleText:SetText(L["IMPORT_FROM_WOWNOTES"] or "Import WoWNotes Data")
    titleText:SetTextColor(T("ACCENT_PRIMARY"))

    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -29)
    divider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -29)
    divider:SetColorTexture(T("BORDER_SUBTLE"))

    local bodyText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -46)
    bodyText:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -18, -46)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(4)
    bodyText:SetText(L["MIGRATION_CLEANUP_REMINDER"])
    bodyText:SetTextColor(T("TEXT_PRIMARY"))

    local btnDivider = dialog:CreateTexture(nil, "ARTWORK")
    btnDivider:SetHeight(1)
    btnDivider:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 1, 56)
    btnDivider:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 56)
    btnDivider:SetColorTexture(T("BORDER_SUBTLE"))

    local okBtn = ns.UI.CreateButton(nil, dialog, L["MIGRATION_CLEANUP_OK"], 180, 32)
    okBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 14)
    okBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end
