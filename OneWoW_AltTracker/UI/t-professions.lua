local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}

local columnsConfig = {
    {key = "expand", label = "", width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "star", label = "", width = 30, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_STAR"], ttDesc = L["TT_COL_STAR_DESC"]},
    {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_FACTION"], ttDesc = L["PROF_TT_FACTION_DESC"]},
    {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_MAIL"], ttDesc = L["PROF_TT_MAIL_DESC"]},
    {key = "name", label = L["COL_CHARACTER"], width = 135, fixed = false, align = "left", ttTitle = L["TT_COL_CHARACTER"], ttDesc = L["PROF_TT_CHAR_NAME_DESC"]},
    {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, align = "center", ttTitle = L["TT_COL_LEVEL"], ttDesc = L["PROF_TT_CHAR_LEVEL_DESC"]},
    {key = "primary1", label = L["PROF_COL_PRIMARY_1"], width = 90, fixed = false, align = "left", ttTitle = L["PROF_COL_PRIMARY_1"], ttDesc = L["PROF_TT_PRIMARY_1_DESC"]},
    {key = "conc1", label = L["PROF_COL_CONC"], width = 40, fixed = true, align = "center", ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
    {key = "primary2", label = L["PROF_COL_PRIMARY_2"], width = 90, fixed = false, align = "left", ttTitle = L["PROF_COL_PRIMARY_2"], ttDesc = L["PROF_TT_PRIMARY_2_DESC"]},
    {key = "conc2", label = L["PROF_COL_CONC"], width = 40, fixed = true, align = "center", ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
    {key = "cooking", label = L["PROF_COL_COOKING"], width = 60, fixed = false, align = "center", ttTitle = L["PROF_COL_COOKING"], ttDesc = L["PROF_TT_COOKING_DESC"]},
    {key = "fishing", label = L["PROF_COL_FISHING"], width = 60, fixed = false, align = "center", ttTitle = L["PROF_COL_FISHING"], ttDesc = L["PROF_TT_FISHING_DESC"]},
    {key = "archeology", label = L["PROF_COL_ARCHEOLOGY"], width = 80, fixed = false, align = "center", ttTitle = L["PROF_COL_ARCHEOLOGY"], ttDesc = L["PROF_TT_ARCHAEOLOGY_DESC"]},
    {key = "gear", label = L["PROF_COL_GEAR"], width = 50, fixed = false, align = "left", ttTitle = L["PROF_COL_GEAR"], ttDesc = L["PROF_TT_GEAR_DESC"]}
}

local onHeaderCreate = function(btn, col, index)
    if col.key == "expand" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("CENTER")
        icon:SetAtlas("Gamepad_Rev_Plus_64")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "faction" then
        if btn.text then btn.text:SetText("") end
    elseif col.key == "mail" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    elseif col.key == "star" then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface/Common/FavoritesIcon")
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

function ns.UI.CreateProfessionsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["PROFESSIONS_OVERVIEW"],
        height = 110,
        columns = 5,
        stats = {
            { label = L["PROF_ATTENTION"], value = "0", ttTitle = L["TT_PROF_ATTENTION"], ttDesc = L["TT_PROF_ATTENTION_DESC"] },
            { label = L["PROF_CHARACTERS"], value = "0", ttTitle = L["TT_PROF_CHARACTERS"], ttDesc = L["TT_PROF_CHARACTERS_DESC"] },
            { label = L["PROF_PRIMARY_PROFS"], value = "0/11", ttTitle = L["TT_PROF_PRIMARY_PROFS"], ttDesc = L["TT_PROF_PRIMARY_PROFS_DESC"] },
            { label = L["PROF_SECONDARY_PROFS"], value = "0/3", ttTitle = L["TT_PROF_SECONDARY_PROFS"], ttDesc = L["TT_PROF_SECONDARY_PROFS_DESC"] },
            { label = L["PROF_MAX_LEVEL"], value = "0", ttTitle = L["TT_PROF_MAX_LEVEL"], ttDesc = L["TT_PROF_MAX_LEVEL_DESC"] },
            { label = L["PROF_NO_PROFESSIONS"], value = "0", ttTitle = L["TT_PROF_NO_PROFESSIONS"], ttDesc = L["TT_PROF_NO_PROFESSIONS_DESC"] },
            { label = L["PROF_INCOMPLETE_SECONDARY"], value = "0", ttTitle = L["TT_PROF_INCOMPLETE_SECONDARY"], ttDesc = L["TT_PROF_INCOMPLETE_SECONDARY_DESC"] },
            { label = L["PROF_MISSING_EQUIPMENT"], value = "0", ttTitle = L["TT_PROF_MISSING_EQUIPMENT"], ttDesc = L["TT_PROF_MISSING_EQUIPMENT_DESC"] },
            { label = L["PROF_RECIPES"], value = "0/0", ttTitle = L["TT_PROF_RECIPES"], ttDesc = L["TT_PROF_RECIPES_DESC"] },
            { label = L["PROF_TOOLS_MISSING"], value = "0", ttTitle = L["TT_PROF_TOOLS_MISSING"], ttDesc = L["TT_PROF_TOOLS_MISSING_DESC"] },
        },
    })

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, overview.panel)

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshProfessionsTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    local statusBar = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["CHARACTERS_TRACKED"], 0, ""),
    })

    parent.dataTable = dt
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.rosterPanel = rosterPanel
    parent.statBoxes = overview.statBoxes
    parent.statusText = statusBar.text
    parent.statusBar = statusBar.bar

    ns.UI.ApplyFontToFrame(parent)

    C_Timer.After(0.5, function()
        if ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("professions", parent)
    end
end

local ProfessionsModule = nil

local function GetProfessionsModule()
    if not ProfessionsModule then
        ProfessionsModule = ns.ProfessionsModule
    end
    return ProfessionsModule
end

local function GetSkillColor(current, max)
    local percent = max > 0 and (current / max * 100) or 0
    if percent >= 100 then
        return 0.30, 0.69, 0.31
    elseif percent >= 75 then
        return 0, 0.74, 0.83
    elseif percent >= 50 then
        return 1, 0.84, 0
    else
        return 1, 0.34, 0.13
    end
end

local CONCENTRATION_RATE = 1 / 360

local function GetEstimatedConcentration(concData)
    if not concData or not concData.value then return nil end
    local timeSince = time() - (concData.ts or time())
    local estimated = math.min(concData.max or 0, math.floor(concData.value + (timeSince * CONCENTRATION_RATE)))
    return estimated, concData.max or 0, concData.value, concData.ts or time()
end

local function AddConcentrationTooltip(frame, concData, profName, L)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(profName or L["PROF_COL_CONC"], 1, 1, 1)
        if concData and concData.value then
            local current, max, stored, ts = GetEstimatedConcentration(concData)
            local r, g, b = GetSkillColor(current, max)
            GameTooltip:AddDoubleLine(L["PROF_TT_CONC_CURRENT"], string.format("%d / %d", current, max), 1, 1, 1, r, g, b)
            if current < max then
                local remaining = (max - current) / CONCENTRATION_RATE
                GameTooltip:AddDoubleLine(L["PROF_TT_CONC_TIME_TO_FULL"], SecondsToTime(remaining), 1, 1, 1, 0.8, 0.8, 0.8)
            else
                GameTooltip:AddDoubleLine(L["PROF_TT_CONC_TIME_TO_FULL"], L["PROF_TT_CONC_FULL"], 1, 1, 1, 0.30, 0.69, 0.31)
            end
        else
            GameTooltip:AddLine(L["PROF_TT_CONC_NO_DATA"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local function AddProfessionTooltip(frame, profData, profRecipes)
    if not profData or not profData.name then return end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(profData.name, 1, 1, 1)

        local totalCurrent = profData.currentSkill or 0
        local totalMax = profData.maxSkill or 0
        local expansionData = profData.expansions or {}

        if #expansionData > 0 then
            totalCurrent = 0
            totalMax = 0
            for _, expansion in ipairs(expansionData) do
                totalCurrent = totalCurrent + (expansion.currentSkill or 0)
                totalMax = totalMax + (expansion.maxSkill or 0)
            end
        end

        local r, g, b = GetSkillColor(totalCurrent, totalMax)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["PROF_LABEL_TOTAL_SKILL"], string.format("%d / %d", totalCurrent, totalMax), 1, 1, 1, r, g, b)

        if #expansionData > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["PROF_LABEL_BY_EXPANSION"], 1, 0.82, 0)

            for _, expansion in ipairs(expansionData) do
                local curSkill = expansion.currentSkill or 0
                local maxSkill = expansion.maxSkill or 0
                local expR, expG, expB = GetSkillColor(curSkill, maxSkill)
                GameTooltip:AddDoubleLine(
                    expansion.name or L["PROF_VALUE_UNKNOWN"],
                    string.format("%d / %d", curSkill, maxSkill),
                    1, 1, 1,
                    expR, expG, expB
                )
            end
        end

        if profRecipes and type(profRecipes) == "table" then
            local totalRecipes = 0
            local totalLearned = 0
            for expansionID, expData in pairs(profRecipes) do
                if type(expData) == "table" then
                    totalRecipes = totalRecipes + (expData.totalRecipes or 0)
                    totalLearned = totalLearned + (expData.learnedRecipes or 0)
                end
            end

            if totalRecipes > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format(L["PROF_RECIPES_FORMAT"], totalLearned, totalRecipes), 0.8, 0.8, 0.8)
            end
        end

        if #expansionData == 0 and (not profRecipes or not next(profRecipes)) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["PROF_NO_EXPANSION_DATA"], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L["PROF_OPEN_TO_SCAN"], 0.6, 0.6, 0.6)
        end

        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local function GetTotalSkill(profData)
    if not profData or not profData.name then return 0, 0 end
    local totalCurrent = profData.currentSkill or 0
    local totalMax = profData.maxSkill or 0
    if profData.expansions and #profData.expansions > 0 then
        totalCurrent = 0
        totalMax = 0
        for _, exp in ipairs(profData.expansions) do
            totalCurrent = totalCurrent + (exp.currentSkill or 0)
            totalMax = totalMax + (exp.maxSkill or 0)
        end
    end
    return totalCurrent, totalMax
end

local function BuildExpandedPanels(ef, data)
    local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)

    local professions = data.professions
    local professionEquipment = data.professionEquipment
    local recipesByExpansion = data.recipesByExpansion

    local hasProfessions = false
    if professions then
        for slotName, profData in pairs(professions) do
            if profData and profData.name and profData.name ~= "" then
                hasProfessions = true
                break
            end
        end
    end

    if not hasProfessions then
        local p1 = grid:AddPanel(L["PROF_EXPANDED_PROFESSIONS"])
        grid:AddLine(p1, L["PROF_NO_PROFESSIONS_LEARNED"], {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
        grid:Finish()
        return
    end

    local pSkills = grid:AddPanel(L["PROF_EXPANDED_PROFESSIONS"])
    local pEquip = grid:AddPanel(L["PROF_EXPANDED_EQUIPMENT"])
    local pRecipes = grid:AddPanel(L["PROF_EXPANDED_RECIPE_DATA"])

    local function AddSkillLines(profData)
        if not profData or not profData.name then return end
        local iconPath = ns.ProfessionData:GetIcon(profData.name)
        local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)
        grid:AddLine(pSkills, iconMarkup .. " " .. profData.name)
        local totalCurrent, totalMax = GetTotalSkill(profData)
        local r, g, b = GetSkillColor(totalCurrent, totalMax)
        grid:AddLine(pSkills, "  " .. L["PROF_LABEL_SKILL"] .. " " .. string.format("%d / %d", totalCurrent, totalMax), {r, g, b})
        grid:AddLine(pSkills, " ")
    end

    local function AddEquipLink(panel, label, itemData)
        local display = itemData.itemLink or itemData.itemName or L["PROF_VALUE_UNKNOWN"]
        local fs = grid:AddLine(panel, "  " .. label .. " " .. display)
        if itemData.itemLink then
            local btn = CreateFrame("Button", nil, panel)
            btn:SetAllPoints(fs)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    local function AddEquipmentLines(profData)
        if not profData or not profData.name then return end
        local iconPath = ns.ProfessionData:GetIcon(profData.name)
        local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)
        grid:AddLine(pEquip, iconMarkup .. " " .. profData.name)

        local profEquipData = professionEquipment and professionEquipment[profData.name]

        if profEquipData and profEquipData.tool then
            AddEquipLink(pEquip, L["PROF_LABEL_TOOL"], profEquipData.tool)
        else
            grid:AddLine(pEquip, "  " .. L["PROF_LABEL_TOOL"] .. " " .. L["PROF_VALUE_NONE"], {1, 0.34, 0.13})
        end

        if profData.name ~= "Fishing" and profData.name ~= "Archaeology" then
            local accLabelText = (profData.name == "Cooking") and L["PROF_LABEL_ACC"] or L["PROF_LABEL_ACC_1"]
            if profEquipData and profEquipData.accessory1 then
                AddEquipLink(pEquip, accLabelText, profEquipData.accessory1)
            else
                grid:AddLine(pEquip, "  " .. accLabelText .. " " .. L["PROF_VALUE_NONE"], {1, 0.34, 0.13})
            end

            if profData.name ~= "Cooking" then
                if profEquipData and profEquipData.accessory2 then
                    AddEquipLink(pEquip, L["PROF_LABEL_ACC_2"], profEquipData.accessory2)
                else
                    grid:AddLine(pEquip, "  " .. L["PROF_LABEL_ACC_2"] .. " " .. L["PROF_VALUE_NONE"], {1, 0.34, 0.13})
                end
            end
        end
        grid:AddLine(pEquip, " ")
    end

    local function AddRecipeLines(profData)
        if not profData or not profData.name then return end
        local iconPath = ns.ProfessionData:GetIcon(profData.name)
        local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 16, 16, 0, 1, 0, 1)
        grid:AddLine(pRecipes, iconMarkup .. " " .. profData.name)

        local totalRecipes = 0
        local totalLearned = 0
        local profRecipeData = recipesByExpansion and recipesByExpansion[profData.name]
        if profRecipeData and type(profRecipeData) == "table" then
            for expansionID, expData in pairs(profRecipeData) do
                if type(expData) == "table" then
                    totalRecipes = totalRecipes + (expData.totalRecipes or 0)
                    totalLearned = totalLearned + (expData.learnedRecipes or 0)
                end
            end
        end

        grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_TOTAL"] .. " " .. tostring(totalRecipes))

        local r, g, b = GetSkillColor(totalLearned, totalRecipes)
        grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_KNOWN"] .. " " .. tostring(totalLearned), {r, g, b})

        local missing = totalRecipes - totalLearned
        if missing > 0 then
            grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_MISSING"] .. " " .. tostring(missing), {1, 0.34, 0.13})
        else
            grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_MISSING"] .. " " .. tostring(missing), {0.30, 0.69, 0.31})
        end
        grid:AddLine(pRecipes, " ")
    end

    if professions.Primary1 and professions.Primary1.name then
        AddSkillLines(professions.Primary1)
        AddEquipmentLines(professions.Primary1)
        AddRecipeLines(professions.Primary1)
    end

    if professions.Primary2 and professions.Primary2.name then
        AddSkillLines(professions.Primary2)
        AddEquipmentLines(professions.Primary2)
        AddRecipeLines(professions.Primary2)
    end

    if professions.Cooking and professions.Cooking.name then
        AddSkillLines(professions.Cooking)
        AddEquipmentLines(professions.Cooking)
        AddRecipeLines(professions.Cooking)
    end

    if professions.Fishing and professions.Fishing.name then
        AddSkillLines(professions.Fishing)
        AddEquipmentLines(professions.Fishing)
        AddRecipeLines(professions.Fishing)
    end

    if professions.Archaeology and professions.Archaeology.name then
        AddSkillLines(professions.Archaeology)
    end

    grid:Finish()
end

function ns.UI.RefreshProfessionsTab(professionsTab)
    if not professionsTab then return end

    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local ProfModule = GetProfessionsModule()
    if not ProfModule then return end

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end

    if #allChars == 0 then return end

    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    local currentCharKey = currentChar .. "-" .. currentRealm
    table.sort(allChars, function(a, b)
        local aFav = ns.IsFavoriteChar(a.key)
        local bFav = ns.IsFavoriteChar(b.key)
        if aFav and not bFav then return true end
        if bFav and not aFav then return false end

        local aIsCurrent = (a.key == currentCharKey)
        local bIsCurrent = (b.key == currentCharKey)
        if aIsCurrent and not bIsCurrent then return true end
        if bIsCurrent and not aIsCurrent then return false end

        if currentSortColumn then
            local aVal, bVal

            if currentSortColumn == "name" then
                aVal = a.data.name or ""
                bVal = b.data.name or ""
            elseif currentSortColumn == "level" then
                aVal = a.data.level or 0
                bVal = b.data.level or 0
            elseif currentSortColumn == "primary1" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Primary1
                local bProf = bProfData.professions and bProfData.professions.Primary1
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "primary2" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Primary2
                local bProf = bProfData.professions and bProfData.professions.Primary2
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "cooking" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Cooking
                local bProf = bProfData.professions and bProfData.professions.Cooking
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "fishing" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Fishing
                local bProf = bProfData.professions and bProfData.professions.Fishing
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "archeology" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aProf = aProfData.professions and aProfData.professions.Archaeology
                local bProf = bProfData.professions and bProfData.professions.Archaeology
                aVal = (aProf and aProf.currentSkill) or 0
                bVal = (bProf and bProf.currentSkill) or 0
            elseif currentSortColumn == "conc1" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aConc = aProfData.concentration and aProfData.concentration.Primary1
                local bConc = bProfData.concentration and bProfData.concentration.Primary1
                aVal = (aConc and aConc.value) or 0
                bVal = (bConc and bConc.value) or 0
            elseif currentSortColumn == "conc2" then
                local aProfData = ProfModule:GetCharacterProfessions(a.key)
                local bProfData = ProfModule:GetCharacterProfessions(b.key)
                local aConc = aProfData.concentration and aProfData.concentration.Primary2
                local bConc = bProfData.concentration and bProfData.concentration.Primary2
                aVal = (aConc and aConc.value) or 0
                bVal = (bConc and bConc.value) or 0
            elseif currentSortColumn == "gear" then
                aVal = 0
                bVal = 0
            else
                aVal = a.data.name or ""
                bVal = b.data.name or ""
            end

            if type(aVal) == "number" then
                if currentSortAscending then
                    return aVal < bVal
                else
                    return aVal > bVal
                end
            else
                if currentSortAscending then
                    return aVal < bVal
                else
                    return aVal > bVal
                end
            end
        end

        return (a.data.name or "") < (b.data.name or "")
    end)

    local scrollContent = professionsTab.scrollContent
    local dt = professionsTab.dataTable
    if not scrollContent then return end

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(characterRows)
    if dt then dt:ClearRows() end

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local professionData = ProfModule:GetCharacterProfessions(charKey)
        local professions = professionData.professions or {}
        local professionEquipment = professionData.professionEquipment or {}
        local recipesByExpansion = professionData.recipesByExpansion or {}
        local concentration = professionData.concentration or {}

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            data = {
                charKey = charKey,
                charData = charData,
                professions = professions,
                professionEquipment = professionEquipment,
                recipesByExpansion = recipesByExpansion,
            },
            createDetails = function(ef, d)
                BuildExpandedPanels(ef, d)
                ns.UI.ApplyFontToFrame(ef)
            end,
        })
        charRow.charKey = charKey
        charRow.professionData = professionData

        if ns.UI.CreateFavoriteStarButton then
            table.insert(charRow.cells, 2, ns.UI.CreateFavoriteStarButton(charRow, charKey))
        end

        local factionCell = OneWoW_GUI:CreateFactionIcon(charRow, { faction = charData.faction })
        table.insert(charRow.cells, factionCell)

        local hasMail = charData.hasNewMail or false
        local mailCell = OneWoW_GUI:CreateMailIcon(charRow, { hasMail = hasMail })
        table.insert(charRow.cells, mailCell)

        local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        nameText:SetJustifyH("LEFT")
        table.insert(charRow.cells, nameText)

        local levelText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelText:SetText(tostring(charData.level or 0))
        levelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, levelText)

        local prof1 = professions.Primary1
        local primary1Frame = CreateFrame("Frame", nil, charRow)
        primary1Frame:SetSize(90, 32)
        local primary1Text = primary1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        primary1Text:SetPoint("LEFT", primary1Frame, "LEFT", 0, 0)
        primary1Text:SetJustifyH("LEFT")
        if prof1 and prof1.name then
            local totalCurrent, totalMax = GetTotalSkill(prof1)
            local iconPath = ns.ProfessionData:GetIcon(prof1.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            primary1Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary1Frame, prof1, recipesByExpansion[prof1.name])
        else
            primary1Text:SetText("--")
        end
        primary1Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary1Frame)

        local conc1Frame = CreateFrame("Frame", nil, charRow)
        conc1Frame:SetSize(40, 32)
        local conc1Text = conc1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        conc1Text:SetPoint("CENTER", conc1Frame, "CENTER", 0, 0)
        conc1Text:SetJustifyH("CENTER")
        local conc1Data = concentration.Primary1
        if prof1 and prof1.name and conc1Data and conc1Data.value then
            local current = GetEstimatedConcentration(conc1Data)
            conc1Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc1Data.max or 0)
            conc1Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc1Frame, conc1Data, prof1.name, L)
        else
            conc1Text:SetText("--")
            conc1Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc1Frame)

        local prof2 = professions.Primary2
        local primary2Frame = CreateFrame("Frame", nil, charRow)
        primary2Frame:SetSize(90, 32)
        local primary2Text = primary2Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        primary2Text:SetPoint("LEFT", primary2Frame, "LEFT", 0, 0)
        primary2Text:SetJustifyH("LEFT")
        if prof2 and prof2.name then
            local totalCurrent, totalMax = GetTotalSkill(prof2)
            local iconPath = ns.ProfessionData:GetIcon(prof2.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            primary2Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary2Frame, prof2, recipesByExpansion[prof2.name])
        else
            primary2Text:SetText("--")
        end
        primary2Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary2Frame)

        local conc2Frame = CreateFrame("Frame", nil, charRow)
        conc2Frame:SetSize(40, 32)
        local conc2Text = conc2Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        conc2Text:SetPoint("CENTER", conc2Frame, "CENTER", 0, 0)
        conc2Text:SetJustifyH("CENTER")
        local conc2Data = concentration.Primary2
        if prof2 and prof2.name and conc2Data and conc2Data.value then
            local current = GetEstimatedConcentration(conc2Data)
            conc2Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc2Data.max or 0)
            conc2Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc2Frame, conc2Data, prof2.name, L)
        else
            conc2Text:SetText("--")
            conc2Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc2Frame)

        local cookingFrame = CreateFrame("Frame", nil, charRow)
        cookingFrame:SetSize(60, 32)
        local cookingText = cookingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cookingText:SetPoint("CENTER", cookingFrame, "CENTER", 0, 0)
        cookingText:SetJustifyH("CENTER")
        local cooking = professions.Cooking
        if cooking and cooking.name then
            local totalCurrent, totalMax = GetTotalSkill(cooking)
            local iconPath = ns.ProfessionData:GetIcon(cooking.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            cookingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(cookingFrame, cooking, recipesByExpansion["Cooking"])
        else
            cookingText:SetText("--")
        end
        cookingText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, cookingFrame)

        local fishingFrame = CreateFrame("Frame", nil, charRow)
        fishingFrame:SetSize(60, 32)
        local fishingText = fishingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fishingText:SetPoint("CENTER", fishingFrame, "CENTER", 0, 0)
        fishingText:SetJustifyH("CENTER")
        local fishing = professions.Fishing
        if fishing and fishing.name then
            local totalCurrent, totalMax = GetTotalSkill(fishing)
            local iconPath = ns.ProfessionData:GetIcon(fishing.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            fishingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(fishingFrame, fishing, recipesByExpansion["Fishing"])
        else
            fishingText:SetText("--")
        end
        fishingText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, fishingFrame)

        local archeologyFrame = CreateFrame("Frame", nil, charRow)
        archeologyFrame:SetSize(80, 32)
        local archeologyText = archeologyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        archeologyText:SetPoint("CENTER", archeologyFrame, "CENTER", 0, 0)
        archeologyText:SetJustifyH("CENTER")
        local archaeology = professions.Archaeology
        if archaeology and archaeology.name then
            local totalCurrent, totalMax = GetTotalSkill(archaeology)
            local iconPath = ns.ProfessionData:GetIcon(archaeology.name)
            local iconMarkup = CreateTextureMarkup(iconPath, 64, 64, 14, 14, 0, 1, 0, 1)
            archeologyText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(archeologyFrame, archaeology, recipesByExpansion["Archaeology"])
        else
            archeologyText:SetText("--")
        end
        archeologyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, archeologyFrame)

        local gearText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local gearEquipped = 0
        local gearTotal = 0

        local gearProfessions = {"Primary1", "Primary2", "Cooking", "Fishing"}
        for _, slotName in ipairs(gearProfessions) do
            if professions[slotName] and professions[slotName].name then
                local profName = professions[slotName].name
                gearTotal = gearTotal + 1
                if professionEquipment[profName] and professionEquipment[profName].tool then
                    gearEquipped = gearEquipped + 1
                end
                if slotName == "Primary1" or slotName == "Primary2" then
                    gearTotal = gearTotal + 2
                    if professionEquipment[profName] then
                        if professionEquipment[profName].accessory1 then gearEquipped = gearEquipped + 1 end
                        if professionEquipment[profName].accessory2 then gearEquipped = gearEquipped + 1 end
                    end
                elseif slotName == "Cooking" then
                    gearTotal = gearTotal + 1
                    if professionEquipment[profName] and professionEquipment[profName].accessory1 then
                        gearEquipped = gearEquipped + 1
                    end
                end
            end
        end

        if gearTotal > 0 then
            gearText:SetText(string.format("%d/%d", gearEquipped, gearTotal))
            if gearEquipped == gearTotal then
                gearText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                gearText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
        else
            gearText:SetText("--")
            gearText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        gearText:SetJustifyH("LEFT")
        table.insert(charRow.cells, gearText)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(charRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, 32)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(characterRows, charRow)
        if dt then dt:RegisterRow(charRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent)

    if professionsTab.statusText then
        professionsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshProfessionsStats(professionsTab)

    ns.UI.ApplyFontToFrame(professionsTab)

    C_Timer.After(0.1, function()
        if professionsTab.headerRow then
            professionsTab.headerRow:GetScript("OnSizeChanged")(professionsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshProfessionsStats(professionsTab)
    if not professionsTab or not professionsTab.statBoxes then return end

    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local ProfModule = GetProfessionsModule()
    if not ProfModule then return end

    local stats = {
        attention = 0,
        characters = 0,
        primaryProfs = 0,
        secondaryProfs = 0,
        maxLevelProfs = 0,
        noProfessions = 0,
        incompleteSecondary = 0,
        missingEquipment = 0,
        recipesKnown = 0,
        recipesTotal = 0,
        toolsMissing = 0
    }

    local allChars = {}
    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        table.insert(allChars, {
            key = charKey,
            data = charData
        })
    end
    stats.characters = #allChars

    local uniquePrimaryProfs = {}
    local uniqueSecondaryProfs = {}

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local professionData = ProfModule:GetCharacterProfessions(charKey)
        local professions = professionData.professions or {}
        local professionEquipment = professionData.professionEquipment or {}
        local charRecipesByExpansion = professionData.recipesByExpansion or {}

        local hasPrimary1 = false
        local hasPrimary2 = false
        local hasCooking = false
        local hasFishing = false

        if professions.Primary1 and professions.Primary1.name then
            hasPrimary1 = true
            uniquePrimaryProfs[professions.Primary1.name] = true

            local totalCurrent, totalMax = GetTotalSkill(professions.Primary1)
            if totalCurrent >= totalMax and totalMax > 0 then
                stats.maxLevelProfs = stats.maxLevelProfs + 1
            end

            local prof1Recipes = charRecipesByExpansion[professions.Primary1.name]
            if prof1Recipes and type(prof1Recipes) == "table" then
                for expansionID, expData in pairs(prof1Recipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Primary2 and professions.Primary2.name then
            hasPrimary2 = true
            uniquePrimaryProfs[professions.Primary2.name] = true

            local totalCurrent, totalMax = GetTotalSkill(professions.Primary2)
            if totalCurrent >= totalMax and totalMax > 0 then
                stats.maxLevelProfs = stats.maxLevelProfs + 1
            end

            local prof2Recipes = charRecipesByExpansion[professions.Primary2.name]
            if prof2Recipes and type(prof2Recipes) == "table" then
                for expansionID, expData in pairs(prof2Recipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Cooking and professions.Cooking.name then
            hasCooking = true
            uniqueSecondaryProfs["Cooking"] = true

            local cookingRecipes = charRecipesByExpansion["Cooking"]
            if cookingRecipes and type(cookingRecipes) == "table" then
                for expansionID, expData in pairs(cookingRecipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Fishing and professions.Fishing.name then
            hasFishing = true
            uniqueSecondaryProfs["Fishing"] = true

            local fishingRecipes = charRecipesByExpansion["Fishing"]
            if fishingRecipes and type(fishingRecipes) == "table" then
                for expansionID, expData in pairs(fishingRecipes) do
                    if type(expData) == "table" then
                        stats.recipesKnown = stats.recipesKnown + (expData.learnedRecipes or 0)
                        stats.recipesTotal = stats.recipesTotal + (expData.totalRecipes or 0)
                    end
                end
            end
        end

        if professions.Archaeology and professions.Archaeology.name then
            uniqueSecondaryProfs["Archaeology"] = true
        end

        if not hasPrimary1 or not hasPrimary2 then
            stats.noProfessions = stats.noProfessions + 1
            stats.attention = stats.attention + 1
        end

        if not hasCooking or not hasFishing then
            stats.incompleteSecondary = stats.incompleteSecondary + 1
        end

        local gatheringProfs = {
            ["Herbalism"] = true,
            ["Mining"] = true,
            ["Skinning"] = true
        }

        if professions.Primary1 and professions.Primary1.name and gatheringProfs[professions.Primary1.name] then
            if not (professionEquipment[professions.Primary1.name] and professionEquipment[professions.Primary1.name].tool) then
                stats.toolsMissing = stats.toolsMissing + 1
            end
        end

        if professions.Primary2 and professions.Primary2.name and gatheringProfs[professions.Primary2.name] then
            if not (professionEquipment[professions.Primary2.name] and professionEquipment[professions.Primary2.name].tool) then
                stats.toolsMissing = stats.toolsMissing + 1
            end
        end
    end

    local primaryCount = 0
    for _ in pairs(uniquePrimaryProfs) do
        primaryCount = primaryCount + 1
    end
    stats.primaryProfs = primaryCount

    local secondaryCount = 0
    for _ in pairs(uniqueSecondaryProfs) do
        secondaryCount = secondaryCount + 1
    end
    stats.secondaryProfs = secondaryCount

    local statBoxes = professionsTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then statBoxes[3].value:SetText(stats.primaryProfs .. "/11") end
        if statBoxes[4] then statBoxes[4].value:SetText(stats.secondaryProfs .. "/3") end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.maxLevelProfs)) end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.noProfessions)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.incompleteSecondary)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.missingEquipment)) end
        if statBoxes[9] then statBoxes[9].value:SetText(stats.recipesKnown .. "/" .. stats.recipesTotal) end
        if statBoxes[10] then statBoxes[10].value:SetText(tostring(stats.toolsMissing)) end
    end
end
