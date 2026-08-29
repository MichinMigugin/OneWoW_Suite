local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local L = ns.L

ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    local coreL = OneWoW.Locale:GetTable("OneWoW")
    local sharedL = OneWoW.Locale:GetTable("shared")

    local rolesSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = coreL["ROLES_ALTS_SUBTAB"], yOffset = yOffset })
    yOffset = rolesSection.bottomY - 8

    -- Width may still be 0 on first create; fall back so wrap height is usable.
    local wrapWidth = (scrollContent:GetWidth() or 0) - 30
    if wrapWidth < 200 then wrapWidth = 740 end

    -- Pointer copy is "... Settings / %s." — prefix/suffix stay body text; %s is the nav link.
    local pointerFmt = coreL["SETTINGS_ROLES_ALTS_POINTER"]
    local linkLabel = coreL["ROLES_ALTS_SUBTAB"]
    local beforeText, afterText = pointerFmt:match("^(.-)%%s(.*)$")
    if not beforeText then
        beforeText = pointerFmt
        afterText = ""
    end

    local rolesBefore = OneWoW_GUI:CreateFS(scrollContent, 12)
    rolesBefore:SetPoint("TOPLEFT", 15, yOffset)
    rolesBefore:SetPoint("TOPRIGHT", -15, yOffset)
    rolesBefore:SetJustifyH("LEFT")
    rolesBefore:SetWordWrap(true)
    rolesBefore:SetSpacing(3)
    rolesBefore:SetText(beforeText)
    rolesBefore:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rolesBefore:SetWidth(wrapWidth)
    local rolesBeforeHeight = math.max(rolesBefore:GetStringHeight() or 12, 12)

    local rolesLink = OneWoW_GUI:CreateTextLink(scrollContent, {
        text = linkLabel,
        fontSize = 12,
        nav = true,
        onClick = function()
            OneWoW.UI:Show("settings")
            OneWoW.UI:SelectSubTab("settings", "rolesandalts")
        end,
    })
    rolesLink:SetPoint("TOPLEFT", 15, yOffset - rolesBeforeHeight - 2)

    if afterText ~= "" then
        local rolesAfter = OneWoW_GUI:CreateFS(scrollContent, 12)
        rolesAfter:SetPoint("LEFT", rolesLink, "RIGHT", 0, 0)
        rolesAfter:SetJustifyH("LEFT")
        rolesAfter:SetText(afterText)
        rolesAfter:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    yOffset = yOffset - rolesBeforeHeight - 2 - (rolesLink:GetHeight() or 12) - 20

    local dbSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = sharedL["DATABASE_MANAGER_TITLE"], yOffset = yOffset })
    yOffset = dbSection.bottomY - 8

    local dbDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText(sharedL["DATABASE_MANAGER_DESC"])
    dbDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)
    dbDesc:SetWidth(wrapWidth)
    local dbDescHeight = math.max(dbDesc:GetStringHeight() or 12, 12)
    yOffset = yOffset - dbDescHeight - 16

    local databases = {
        { key = "OneWoW_AltTracker", name = "AltTracker Core", desc = "Main addon settings and UI state" },
        { key = "OneWoW_AltTracker_Character", name = "Character Data", desc = "Character info, stats, equipment, and progression" },
        { key = "OneWoW_AltTracker_Storage", name = "Storage & Mail", desc = "Bags, banks, guild banks, and mail data" },
        { key = "OneWoW_AltTracker_Professions", name = "Professions", desc = "Profession data for all characters" },
        { key = "OneWoW_AltTracker_Endgame", name = "Endgame Content", desc = "Mythic+, raids, currencies, and gear" },
        { key = "OneWoW_AltTracker_Accounting", name = "Accounting", desc = "Gold tracking and transactions" },
        { key = "OneWoW_AltTracker_Auctions", name = "Auctions", desc = "Auction house history" },
        { key = "OneWoW_AltTracker_Collections", name = "Collections", desc = "Mounts, pets, and transmog" },
    }

    local function GetEntryCount(dbKey)
        local db = _G[dbKey .. "_DB"]
        if not db then return nil end
        if db.characters then
            local size = 0
            for _ in pairs(db.characters) do size = size + 1 end
            return size
        end
        local size = 0
        for _ in pairs(db) do size = size + 1 end
        return math.max(0, size - 5)
    end

    for _, dbData in ipairs(databases) do
        local key = dbData.key
        yOffset = yOffset - OneWoW_GUI:CreateDatabaseManagerRow(scrollContent, {
            name = dbData.name,
            description = dbData.desc,
            addonKey = key,
            yOffset = yOffset,
            getEntryCount = function()
                return GetEntryCount(key)
            end,
        })
    end

    yOffset = yOffset - 10

    local overrideSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["STATUS_TITLE"], yOffset = yOffset })
    yOffset = overrideSection.bottomY - 8

    local overrideDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    overrideDesc:SetPoint("TOPLEFT", 15, yOffset)
    overrideDesc:SetPoint("TOPRIGHT", -15, yOffset)
    overrideDesc:SetJustifyH("LEFT")
    overrideDesc:SetWordWrap(true)
    overrideDesc:SetText(L["OVERRIDE_SYSTEM_DESC"])
    overrideDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    overrideDesc:SetSpacing(3)
    overrideDesc:SetWidth(wrapWidth)
    local overrideDescHeight = math.max(overrideDesc:GetStringHeight() or 12, 12)
    yOffset = yOffset - overrideDescHeight - 16

    local overrideBtn = OneWoW_GUI:CreateFitTextButton(scrollContent, { text = OPTIONS, height = 35 })
    overrideBtn:SetPoint("TOPLEFT", 25, yOffset)
    overrideBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    if overrideBtn.text then overrideBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")) end
    overrideBtn:SetScript("OnClick", function()
        ns.UI.ShowProgressTrackingDialog()
    end)

    yOffset = yOffset - 50

    local checklistSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["SEASON_CHECKLIST_BTN"], yOffset = yOffset })
    yOffset = checklistSection.bottomY - 8

    local checklistDescText = OneWoW_GUI:CreateFS(scrollContent, 12)
    checklistDescText:SetPoint("TOPLEFT", 15, yOffset)
    checklistDescText:SetPoint("TOPRIGHT", -15, yOffset)
    checklistDescText:SetJustifyH("LEFT")
    checklistDescText:SetWordWrap(true)
    checklistDescText:SetText(L["SEASON_CHECKLIST_DESC"])
    checklistDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    checklistDescText:SetSpacing(3)
    yOffset = yOffset - 50

    local checklistBtn = OneWoW_GUI:CreateFitTextButton(scrollContent, { text = L["SEASON_CHECKLIST_BTN"], height = 35 })
    checklistBtn:ClearAllPoints()
    checklistBtn:SetPoint("TOPLEFT", 25, yOffset)
    checklistBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local checklistDialog = nil

    local function GetCurrencyIDsDisplay()
        local ids = ns:GetProgressList("trackedCurrencyIDs")
        local parts = {}
        for _, id in ipairs(ids) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            table.insert(parts, (info and info.name or "ID " .. id) .. " (" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local function GetBossQuestIDsDisplay()
        local BOSS_NAMES = {}
        local ids = ns:GetProgressList("worldBossQuestIDs")
        local parts = {}
        for _, id in ipairs(ids) do
            table.insert(parts, (BOSS_NAMES[id] or C_QuestLog.GetTitleForQuestID(id) or "Unknown") .. " (Q:" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local CHECKLIST_ITEMS = {
        {section = "Progress Tab"},
        {key = "p_raids_cols", label = "Update d-season.lua raid columns for the current season", auto = false, value = function()
            local sd = ns.SeasonData
            local parts = {}
            for _, raid in ipairs(sd.raids) do
                table.insert(parts, raid.label)
            end
            return #parts > 0 and table.concat(parts, ", ") or "None"
        end, file = "OneWoW_AltTracker/Data/d-season.lua"},
        {key = "p_dungeons_cols", label = "Update d-season.lua M+ dungeon columns and challenge mapIDs", auto = false, value = function()
            local sd = ns.SeasonData
            local parts = {}
            for _, dung in ipairs(sd.dungeons) do
                table.insert(parts, dung.name)
            end
            return #parts > 0 and table.concat(parts, ", ") or "None"
        end, file = "OneWoW_AltTracker/Data/d-season.lua (mapIDs also resolve via C_ChallengeMode.GetMapTable)"},
        {key = "p_currencies", label = "Verify season currency IDs in OverrideDefaults (Progress columns follow Settings overrides)", auto = false, value = GetCurrencyIDsDisplay, file = "OneWoW_AltTracker/Data/d-overrides.lua"},
        {key = "p_bosses",    label = "Verify world boss / lair quest IDs",                auto = false, value = GetBossQuestIDsDisplay, file = "OneWoW_AltTracker/Data/d-overrides.lua"},
        {key = "p_boss_names",label = "Update KNOWN_BOSS_NAMES in both files",       auto = false, value = function() return "WorldBoss.lua and t-progress.lua must stay in sync" end, file = "OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua, OneWoW_AltTracker/UI/t-progress.lua"},
        {key = "p_weeklies",  label = "Verify weekly activity quest IDs", auto = false, value = function()
            local list = ns:GetProgressList("weeklyActivityQuests")
            local parts = {}
            for _, entry in ipairs(list) do
                table.insert(parts, entry.key or "?")
            end
            return #parts > 0 and table.concat(parts, ", ") or "None"
        end, file = "OneWoW_AltTracker/Data/d-overrides.lua (no in-game override editor)"},
        {key = "p_lockouts",  label = "Raid lockout collection",                      auto = true,  value = function() return "GetSavedInstanceInfo()" end, file = "OneWoW_AltTracker_Endgame/Modules/Raids.lua"},
        {key = "p_vault",     label = "Great Vault activity types",                 auto = true,  value = function() return "C_WeeklyRewards.GetActivities()" end, file = "OneWoW_AltTracker_Endgame/Modules/GreatVault.lua"},

        {section = "Portals"},
        {key = "po_s1", label = "Keep S.1 seasonal portal spell list valid", auto = false, value = function() return "Midnight S1 Path-of spells on the ESC S.1 row" end, file = "OneWoW_QoL/Portals/portalhub-detection.lua SEASON_PORTAL_SPELLS[1]"},
        {key = "po_s2", label = "Update S.2 seasonal portal spell list and ShortNames", auto = false, value = function() return "Midnight S2 Path-of spells on the ESC S.2 row" end, file = "OneWoW_QoL/Portals/portalhub-detection.lua SEASON_PORTAL_SPELLS[2] + Data/ShortNames.lua"},
        {key = "po_mid", label = "Add new Midnight dungeon/raid portals to the MID expansion flyout", auto = false, value = function() return "dungeonsByExpansion.mid and raidsByExpansion.mid" end, file = "OneWoW_QoL/Portals/portalhub-detection.lua"},
        {key = "po_toggles", label = "ESC settings: showSeason1 and showSeason2 toggles", auto = false, value = function() return "Portals settings card" end, file = "OneWoW/Core/Database.lua + OneWoW_QoL/UI/t-portals.lua"},

        {section = "Bags / Search"},
        {key = "ba_bonus", label = "Update CURRENT_SEASON_BONUS_IDS for crafted/voidforged gear", auto = false, value = function() return "Dump bonus IDs from an S2 crafted or voidforged item via /1wpetooltip" end, file = "OneWoW/Services/PredicateEngine.lua"},
        {key = "ba_label", label = "Season tooltip label (Midnight Season N)", auto = true, value = function() return "C_MythicPlus + EXPANSION_SEASON_NAME" end, file = "OneWoW/Services/PredicateEngine.lua"},

        {section = "Trackers"},
        {key = "tr_preset", label = "Bump bundled Midnight weekly tracker version and IDs", auto = false, value = function() return "Crests, delves, prey, weeklies" end, file = "OneWoW_Trackers/Core/TrackerPresets.lua bundled_midnight_routine"},

        {section = "Bank / Storage Tab"},
        {key = "b_bags",      label = "Bag container IDs: 0=Backpack, 1-4=Bags, 5=Reagent", auto = true, value = function() return "C_Container.GetContainerNumSlots(0-5)" end, file = "OneWoW_AltTracker_Storage/Modules/Bags.lua"},
        {key = "b_pbank",     label = "Personal Bank bag IDs (6-10)",               auto = true,  value = function() return "bankBagID = 5 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/PersonalBank.lua"},
        {key = "b_warband",   label = "Warband Bank bag IDs (12+)",                 auto = true,  value = function() return "warbandBagID = 11 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/WarbandBank.lua"},
        {key = "b_maxslots",  label = "Verify max bag/bank slot counts still valid", auto = false, value = function() return "Only if Blizzard adds new bank tab types" end, file = "OneWoW_AltTracker_Storage/Modules/"},

        {section = "Equipment Tab"},
        {key = "e_slots",     label = "Verify equipment slot IDs 1-19 still valid", auto = false, value = function() return "Head=1 through Tabard=19" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},
        {key = "e_tier",      label = "Tier set count uses item.setID from the API", auto = true, value = function() return "No hardcoded tier item IDs" end, file = "OneWoW_AltTracker/UI/t-equipment.lua"},
        {key = "e_ilvl",      label = "GetAverageItemLevel()", auto = true, value = function() return "API call" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},

        {section = "General"},
        {key = "s_maxlevel",  label = "Max player level",                   auto = true,  value = function() return "Level " .. GetMaxPlayerLevel() end, file = "GetMaxPlayerLevel()"},
        {key = "g_interface",  label = "Update ## Interface in TOC files when the build changes", auto = false, value = function() local _, _, _, intVersion = GetBuildInfo(); return "Current: " .. (intVersion or "?") end, file = "All .toc files - ## Interface line"},
        {key = "g_journal",   label = "Regenerate Journal DB2 if season instances moved", auto = false, value = function() return "python bin/journal_db2_tools.py generate" end, file = "OneWoW_CatalogData_Journal/Data/Generated/"},
    }

    local function OpenChecklistDialog()
        if checklistDialog and checklistDialog:IsShown() then
            checklistDialog:Raise()
            return
        end
        if checklistDialog then
            OneWoW_GUI:ApplyFontToFrame(checklistDialog)
            checklistDialog:Show()
            checklistDialog:Raise()
            return
        end

        local clResult = OneWoW_GUI:CreateDialog({
            name = "OneWoWSeasonChecklist",
            showBrand = true,
            title = L["SEASON_CHECKLIST_TITLE"],
            width = 780,
            height = 700,
            titleHeight = 26,
            showScrollFrame = true,
        })
        checklistDialog = clResult.frame
        local sc2 = clResult.scrollContent

        local cdy = -8
        local ROW_H = 54
        local checkedBoxes = {}

        for _, item in ipairs(CHECKLIST_ITEMS) do
            if item.section then
                local sh = OneWoW_GUI:CreateSectionHeader(sc2, { title = item.section, yOffset = cdy })
                cdy = sh.bottomY - 6
            else
                local row = OneWoW_GUI:CreateFrame(sc2, { height = ROW_H })
                row:SetPoint("TOPLEFT", 8, cdy)
                row:SetPoint("TOPRIGHT", -8, cdy)

                local isChecked = ns.db.global.seasonChecklist[item.key] == true
                local isAuto = item.auto == true

                if isChecked then
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                elseif isAuto then
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    local br, bg, bb = OneWoW_GUI:GetThemeColor("BTN_BORDER")
                    row:SetBackdropBorderColor(br, bg, bb, 0.5)
                else
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end

                local checkBtn = OneWoW_GUI:CreateButton(row, { width = 22, height = 22 })
                checkBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
                if isChecked then
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                    checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                elseif isAuto then
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                    local br, bg, bb = OneWoW_GUI:GetThemeColor("BTN_BORDER")
                    checkBtn:SetBackdropBorderColor(br, bg, bb, 0.5)
                else
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                end
                local checkMark = OneWoW_GUI:CreateFS(checkBtn, 12)
                checkMark:SetPoint("CENTER")
                checkMark:SetText(isChecked and "X" or (isAuto and "A" or " "))
                if isChecked then
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                elseif isAuto then
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                else
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end

                local labelText = OneWoW_GUI:CreateFS(row, 12)
                labelText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -6)
                labelText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
                labelText:SetJustifyH("LEFT")
                labelText:SetText(item.label)
                if isChecked then
                    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local valStr = item.value and item.value() or ""
                local valueText = OneWoW_GUI:CreateFS(row, 10)
                valueText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -22)
                valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -22)
                valueText:SetJustifyH("LEFT")
                valueText:SetWordWrap(true)
                valueText:SetText(L["SEASON_CURRENT"] .. " " .. valStr)
                if isAuto then
                    valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                else
                    valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end

                local fileText = OneWoW_GUI:CreateFS(row, 10)
                fileText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -37)
                fileText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -37)
                fileText:SetJustifyH("LEFT")
                fileText:SetText(L["FILE"] .. " " .. item.file)
                fileText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                if not isAuto then
                    checkBtn:EnableMouse(true)
                    checkBtn:SetScript("OnClick", function()
                        local nowChecked = not (ns.db.global.seasonChecklist[item.key] == true)
                        ns.db.global.seasonChecklist[item.key] = nowChecked
                        if nowChecked then
                            checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                            checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                            checkMark:SetText("X")
                            checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                            labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        else
                            checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                            checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                            checkMark:SetText(" ")
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                            labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        end
                    end)
                    checkBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
                    checkBtn:SetScript("OnLeave", function(self)
                        local c = ns.db.global.seasonChecklist[item.key]
                        if c then
                            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                        else
                            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        end
                    end)
                end

                table.insert(checkedBoxes, {key = item.key, btn = checkBtn, mark = checkMark, rowFrame = row, label = labelText, isAuto = isAuto})
                cdy = cdy - (ROW_H + 4)
            end
        end

        sc2:SetHeight(math.abs(cdy) + 20)

        local clearBtn = OneWoW_GUI:CreateFitTextButton(checklistDialog, { text = CLEAR_ALL, height = 30 })
        clearBtn:ClearAllPoints()
        clearBtn:SetPoint("BOTTOMLEFT", checklistDialog, "BOTTOMLEFT", 10, 10)
        clearBtn:SetScript("OnClick", function()
            ns.db.global.seasonChecklist = {}
            for _, entry in ipairs(checkedBoxes) do
                if not entry.isAuto then
                    entry.btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    entry.btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                    entry.mark:SetText(" ")
                    entry.rowFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    entry.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
            end
        end)

        local closeBtnCL = OneWoW_GUI:CreateFitTextButton(checklistDialog, { text = CLOSE, height = 30 })
        closeBtnCL:ClearAllPoints()
        closeBtnCL:SetPoint("BOTTOMRIGHT", checklistDialog, "BOTTOMRIGHT", -10, 10)
        closeBtnCL:SetScript("OnClick", function() checklistDialog:Hide() end)

        local legendText = OneWoW_GUI:CreateFS(checklistDialog, 10)
        legendText:SetPoint("BOTTOM", checklistDialog, "BOTTOM", 0, 14)
        legendText:SetText("[X] = Verified this season    [A] = Auto-detected, no action needed    [ ] = Needs manual verification")
        legendText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        OneWoW_GUI:ApplyFontToFrame(checklistDialog)
        checklistDialog:Show()
        checklistDialog:Raise()
    end

    checklistBtn:SetScript("OnClick", OpenChecklistDialog)

    yOffset = yOffset - 50

    scrollContent:SetHeight(math.abs(yOffset) + 20)

    OneWoW_GUI:ApplyFontToFrame(parent)
    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
end
