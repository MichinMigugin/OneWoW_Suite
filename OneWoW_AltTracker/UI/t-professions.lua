local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}

-- Placeholder for numeric fields that require the LoD catalog data unit (not a
-- translatable string; an em dash for "unavailable").
local DASH = "\226\128\148"

local columnsConfig = {
    {key = "expand", label = "", width = 25, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_EXPAND"], ttDesc = L["TT_COL_EXPAND_DESC"]},
    {key = "star", label = "", width = 30, fixed = true, align = "icon", sortable = false, ttTitle = L["TT_COL_STAR"], ttDesc = L["TT_COL_STAR_DESC"]},
    {key = "faction", label = L["COL_FACTION"], width = 25, fixed = true, align = "icon", sortable = false, ttTitle = FACTION, ttDesc = L["PROF_TT_FACTION_DESC"]},
    {key = "mail", label = L["COL_MAIL"], width = 35, fixed = true, align = "icon", sortable = false, ttTitle = L["MAIL"], ttDesc = L["PROF_TT_MAIL_DESC"]},
    {key = "name", label = CHARACTER, width = 135, fixed = false, align = "left", ttTitle = CHARACTER, ttDesc = L["PROF_TT_CHAR_NAME_DESC"]},
    {key = "level", label = L["COL_LEVEL"], width = 40, fixed = true, align = "center", ttTitle = LEVEL, ttDesc = L["PROF_TT_CHAR_LEVEL_DESC"]},
    {key = "primary1", label = L["PROF_COL_PRIMARY_1"], width = 90, fixed = false, align = "left", ttTitle = L["PROF_COL_PRIMARY_1"], ttDesc = L["PROF_TT_PRIMARY_1_DESC"]},
    {key = "conc1", label = L["PROF_COL_CONC"], width = 40, fixed = true, align = "center", ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
    {key = "primary2", label = L["PROF_COL_PRIMARY_2"], width = 90, fixed = false, align = "left", ttTitle = L["PROF_COL_PRIMARY_2"], ttDesc = L["PROF_TT_PRIMARY_2_DESC"]},
    {key = "conc2", label = L["PROF_COL_CONC"], width = 40, fixed = true, align = "center", ttTitle = L["PROF_COL_CONC"], ttDesc = L["PROF_TT_CONC_DESC"]},
    {key = "cooking", label = L["PROF_COL_COOKING"], width = 60, fixed = false, align = "center", ttTitle = L["PROF_COL_COOKING"], ttDesc = L["PROF_TT_COOKING_DESC"]},
    {key = "fishing", label = L["PROF_COL_FISHING"], width = 60, fixed = false, align = "center", ttTitle = L["PROF_COL_FISHING"], ttDesc = L["PROF_TT_FISHING_DESC"]},
    {key = "archeology", label = L["PROF_COL_ARCHEOLOGY"], width = 80, fixed = false, align = "center", ttTitle = L["PROF_COL_ARCHEOLOGY"], ttDesc = L["PROF_TT_ARCHAEOLOGY_DESC"]},
    {key = "gear", label = L["PROF_COL_GEAR"], width = 50, fixed = false, align = "left", ttTitle = L["PROF_COL_GEAR"], ttDesc = L["PROF_TT_GEAR_DESC"]}
}

local onHeaderCreate = function(btn, col, _)
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
        OneWoW_GUI:SetFavoriteAtlasTexture(icon)
        btn.icon = icon
        if btn.text then btn.text:SetText("") end
    end
end

function ns.UI.CreateProfessionsTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        height = 110,
        columns = 5,
        stats = {
            { label = L["ATTENTION"], value = "0", ttTitle = L["ATTENTION"], ttDesc = L["TT_PROF_ATTENTION_DESC"] },
            { label = L["CHARACTERS"], value = "0", ttTitle = L["CHARACTERS"], ttDesc = L["TT_PROF_CHARACTERS_DESC"] },
            { label = L["PROF_PRIMARY_PROFS"], value = "0/11", ttTitle = L["PRIMARY_PROFESSIONS"], ttDesc = L["TT_PROF_PRIMARY_PROFS_DESC"] },
            { label = L["PROF_SECONDARY_PROFS"], value = "0/3", ttTitle = L["TT_PROF_SECONDARY_PROFS"], ttDesc = L["TT_PROF_SECONDARY_PROFS_DESC"] },
            { label = L["PROF_MAX_LEVEL"], value = "0", ttTitle = L["PROF_MAX_LEVEL"], ttDesc = L["TT_PROF_MAX_LEVEL_DESC"] },
            { label = L["PROF_NO_PROFESSIONS"], value = "0", ttTitle = L["PROF_NO_PROFESSIONS"], ttDesc = L["TT_PROF_NO_PROFESSIONS_DESC"] },
            { label = L["PROF_INCOMPLETE_SECONDARY"], value = "0", ttTitle = L["PROF_INCOMPLETE_SECONDARY"], ttDesc = L["TT_PROF_INCOMPLETE_SECONDARY_DESC"] },
            { label = L["PROF_MISSING_EQUIPMENT"], value = "0", ttTitle = L["PROF_MISSING_EQUIPMENT"], ttDesc = L["TT_PROF_MISSING_EQUIPMENT_DESC"] },
            { label = L["PROF_RECIPES"], value = "0/0", ttTitle = L["TT_PROF_RECIPES"], ttDesc = L["TT_PROF_RECIPES_DESC"] },
            { label = L["PROF_TOOLS_MISSING"], value = "0", ttTitle = L["PROF_TOOLS_MISSING"], ttDesc = L["TT_PROF_TOOLS_MISSING_DESC"] },
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

    OneWoW_GUI:ApplyFontToFrame(parent)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("professions", parent)
    end

    -- Live refresh: when the core funnel delivers a scan (the player opened or
    -- updated a profession), rebuild the tab so Known counts update without a
    -- /reload. Only when the tab is actually visible to avoid wasted work.
    OneWoW.ProfessionRecipe.RegisterScanCallback("AltTracker_ProfessionsTab", function()
        if parent:IsShown() and ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)

    -- Recipe totals/Missing need the LoD catalog data unit. If it loads after this
    -- tab was rendered in degraded (em-dash) mode, refresh once its data is
    -- queryable so the dashes become real numbers. Catch-up fires immediately if
    -- it is already loaded, which is a harmless no-op re-render.
    OneWoW:RegisterDataReadyWatcher(OneWoW:ResolveCatalogPack("tradeskills"), function()
        if ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)
    -- Roster keys come from Character; skill/recipe rows need the Professions store.
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Character", function()
        if ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Professions", function()
        if ns.UI.RefreshProfessionsTab then
            ns.UI.RefreshProfessionsTab(parent)
        end
    end)
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

local function AddConcentrationTooltip(frame, concData, profName)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(profName or L["PROF_COL_CONC"], 1, 1, 1)
        if concData and concData.value then
            local current, max = GetEstimatedConcentration(concData)
            local r, g, b = GetSkillColor(current, max)
            GameTooltip:AddDoubleLine(L["SEASON_CURRENT"], string.format("%d / %d", current, max), 1, 1, 1, r, g, b)
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
    frame:SetScript("OnLeave", function()
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
                    expansion.name or UNKNOWN,
                    string.format("%d / %d", curSkill, maxSkill),
                    1, 1, 1,
                    expR, expG, expB
                )
            end
        end

        if profRecipes and type(profRecipes) == "table" then
            local totalRecipes = 0
            local totalLearned = 0
            for _, expData in pairs(profRecipes) do
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
    frame:SetScript("OnLeave", function()
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

local function BuildExpandedPanels(ef, data, row)
    local grid = OneWoW_GUI:CreateExpandedPanelGrid(ef)

    local shiftHeld = IsShiftKeyDown()
    ef._renderedShift = shiftHeld

    -- Re-render this row's detail in place when SHIFT is pressed/released so the
    -- per-expansion skill breakdown can be toggled without collapsing the row.
    if row and not ef._shiftWatcherHooked then
        ef._shiftWatcherHooked = true
        ef:RegisterEvent("MODIFIER_STATE_CHANGED")
        ef:SetScript("OnEvent", function(self, event, key)
            if event ~= "MODIFIER_STATE_CHANGED" then return end
            if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
            if not self:IsShown() then return end
            if IsShiftKeyDown() ~= self._renderedShift then
                row:RefreshDetails()
            end
        end)
    end

    local professions = data.professions
    local professionEquipment = data.professionEquipment
    local recipeProgress = data.recipeProgress or {}

    local hasProfessions = false
    if professions then
        for _, profData in pairs(professions) do
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

    local isCurrentPlayer = (data.charKey == OneWoW_GUI:GetCharacterKey())

    -- Overlay a click target on a profession name line that opens that
    -- profession's window. Only the current character's own professions can be
    -- opened, so other alts' rows stay non-interactive.
    local function MakeProfClickable(fs, panel, profData)
        if not fs or not isCurrentPlayer or not profData or not profData.skillLine then return end
        local btn = CreateFrame("Button", nil, panel)
        btn:SetAllPoints(fs)
        btn:RegisterForClicks("AnyUp")
        btn:SetScript("OnClick", function()
            if OneWoW.Restriction.IsProtectedActionBlocked() then return end
            C_TradeSkillUI.OpenTradeSkill(profData.skillLine)
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(profData.name, 1, 1, 1)
            GameTooltip:AddLine(L["PROF_CLICK_TO_OPEN"], 0.4, 0.8, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function AddSkillLines(profData)
        if not profData or not profData.name then return end
        local iconMarkup = ns.ProfessionData:GetProfIconMarkup(profData, 16, 16)
        local nameFS = grid:AddLine(pSkills, iconMarkup .. " " .. profData.name)
        MakeProfClickable(nameFS, pSkills, profData)
        local totalCurrent, totalMax = GetTotalSkill(profData)
        local r, g, b = GetSkillColor(totalCurrent, totalMax)
        grid:AddLine(pSkills, "  " .. L["PROF_LABEL_SKILL"] .. " " .. string.format("%d / %d", totalCurrent, totalMax), {r, g, b})
        local hasExpansions = profData.expansions and #profData.expansions > 0
        if hasExpansions and shiftHeld then
            for _, expansion in ipairs(profData.expansions) do
                local curSkill = expansion.currentSkill or 0
                local maxSkill = expansion.maxSkill or 0
                local er, eg, eb = GetSkillColor(curSkill, maxSkill)
                grid:AddLine(pSkills, "    " .. (expansion.name or UNKNOWN) .. ": " .. string.format("%d / %d", curSkill, maxSkill), {er, eg, eb})
            end
        elseif hasExpansions then
            grid:AddLine(pSkills, "  " .. L["PROF_SHIFT_FOR_EXPANSION"], {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
        end
        grid:AddLine(pSkills, " ")
    end

    local function AddEquipLink(panel, label, itemData)
        local display = itemData.itemLink or itemData.itemName or UNKNOWN
        local fs = grid:AddLine(panel, "  " .. label .. " " .. display)
        if itemData.itemLink then
            local btn = CreateFrame("Button", nil, panel)
            btn:SetAllPoints(fs)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(itemData.itemLink)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    local function AddEquipmentLines(profData)
        if not profData or not profData.name then return end
        local iconMarkup = ns.ProfessionData:GetProfIconMarkup(profData, 16, 16)
        local nameFS = grid:AddLine(pEquip, iconMarkup .. " " .. profData.name)
        MakeProfClickable(nameFS, pEquip, profData)

        local profEquipData = professionEquipment and professionEquipment[profData.name]

        if profData.name ~= "Fishing" and profData.name ~= "Archaeology" then
            local accLabelText = (profData.name == "Cooking") and L["PROF_LABEL_ACC"] or L["PROF_LABEL_ACC_1"]
            if profEquipData and profEquipData.accessory1 then
                AddEquipLink(pEquip, accLabelText, profEquipData.accessory1)
            else
                grid:AddLine(pEquip, "  " .. accLabelText .. " " .. NONE, {1, 0.34, 0.13})
            end

            if profData.name ~= "Cooking" then
                if profEquipData and profEquipData.accessory2 then
                    AddEquipLink(pEquip, L["PROF_LABEL_ACC_2"], profEquipData.accessory2)
                else
                    grid:AddLine(pEquip, "  " .. L["PROF_LABEL_ACC_2"] .. " " .. NONE, {1, 0.34, 0.13})
                end
            end
        end

        if profEquipData and profEquipData.tool then
            AddEquipLink(pEquip, L["PROF_LABEL_TOOL"], profEquipData.tool)
        else
            grid:AddLine(pEquip, "  " .. L["PROF_LABEL_TOOL"] .. " " .. NONE, {1, 0.34, 0.13})
        end
        grid:AddLine(pEquip, " ")
    end

    local function AddRecipeLines(profData)
        if not profData or not profData.name then return end
        local iconMarkup = ns.ProfessionData:GetProfIconMarkup(profData, 16, 16)
        local nameFS = grid:AddLine(pRecipes, iconMarkup .. " " .. profData.name)
        MakeProfClickable(nameFS, pRecipes, profData)

        local progress = recipeProgress[profData.name]

        -- Degraded contract: without the catalog data unit loaded there is no
        -- authoritative total, so show only the stored Known count and dash out
        -- Total/Missing rather than rendering a misleading "Total 0 / Known 0".
        if not progress or not progress.catalogLoaded then
            local stored = (progress and progress.stored) or 0
            grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_TOTAL"] .. " " .. DASH)
            grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_KNOWN"] .. " " .. tostring(stored),
                {OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")})
            grid:AddLine(pRecipes, "  " .. L["PROF_LABEL_MISSING"] .. " " .. DASH,
                {OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")})
            grid:AddLine(pRecipes, " ")
            return
        end

        local totalRecipes = progress.total or 0
        local totalLearned = progress.known or 0

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

    if not OneWoW_AltTracker_Character_API then return end

    local ProfModule = GetProfessionsModule()
    if not ProfModule then return end

    local allChars = ns.UI.GetSortedCharacters(function(charKey, charData, col)
        if col == "name" then
            return charData.name or ""
        elseif col == "level" then
            return charData.level or 0
        elseif col == "primary1" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local prof = profData.professions and profData.professions.Primary1
            return (prof and prof.currentSkill) or 0
        elseif col == "primary2" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local prof = profData.professions and profData.professions.Primary2
            return (prof and prof.currentSkill) or 0
        elseif col == "cooking" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local prof = profData.professions and profData.professions.Cooking
            return (prof and prof.currentSkill) or 0
        elseif col == "fishing" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local prof = profData.professions and profData.professions.Fishing
            return (prof and prof.currentSkill) or 0
        elseif col == "archeology" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local prof = profData.professions and profData.professions.Archaeology
            return (prof and prof.currentSkill) or 0
        elseif col == "conc1" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local conc = profData.concentration and profData.concentration.Primary1
            return (conc and conc.value) or 0
        elseif col == "conc2" then
            local profData = ProfModule:GetCharacterProfessions(charKey)
            local conc = profData.concentration and profData.concentration.Primary2
            return (conc and conc.value) or 0
        elseif col == "gear" then
            return 0
        else
            return charData.name or ""
        end
    end, currentSortColumn, currentSortAscending)
    if #allChars == 0 then return end

    local scrollContent = professionsTab.scrollContent
    local dt = professionsTab.dataTable
    if not scrollContent then return end

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(characterRows)
    if dt then dt:ClearRows() end

    for _, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local professionData = ProfModule:GetCharacterProfessions(charKey)
        local professions = professionData.professions or {}
        local professionEquipment = professionData.professionEquipment or {}
        local recipesByExpansion = professionData.recipesByExpansion or {}
        local recipeProgress = professionData.recipeProgress or {}
        local concentration = professionData.concentration or {}

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            data = {
                charKey = charKey,
                charData = charData,
                professions = professions,
                professionEquipment = professionEquipment,
                recipesByExpansion = recipesByExpansion,
                recipeProgress = recipeProgress,
            },
            exclusiveExpand = true,
            createDetails = function(ef, d, expandedRow)
                BuildExpandedPanels(ef, d, expandedRow)
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })
        charRow.charKey = charKey
        charRow.professionData = professionData

        ns.UI.AddCommonCells(charRow, charKey, charData)
        ns.UI.AddLevelCell(charRow, charData)

        local prof1 = professions.Primary1
        local primary1Frame = CreateFrame("Frame", nil, charRow)
        primary1Frame:SetSize(90, 32)
        local primary1Text = OneWoW_GUI:CreateFS(primary1Frame, 12)
        primary1Text:SetPoint("LEFT", primary1Frame, "LEFT", 0, 0)
        primary1Text:SetJustifyH("LEFT")
        if prof1 and prof1.name then
            local totalCurrent, totalMax = GetTotalSkill(prof1)
            local iconMarkup = ns.ProfessionData:GetProfIconMarkup(prof1, 14, 14)
            primary1Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary1Frame, prof1, recipesByExpansion[prof1.name])
        else
            primary1Text:SetText("--")
        end
        primary1Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary1Frame)

        local conc1Frame = CreateFrame("Frame", nil, charRow)
        conc1Frame:SetSize(40, 32)
        local conc1Text = OneWoW_GUI:CreateFS(conc1Frame, 12)
        conc1Text:SetPoint("CENTER", conc1Frame, "CENTER", 0, 0)
        conc1Text:SetJustifyH("CENTER")
        local conc1Data = concentration.Primary1
        if prof1 and prof1.name and conc1Data and conc1Data.value then
            local current = GetEstimatedConcentration(conc1Data)
            conc1Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc1Data.max or 0)
            conc1Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc1Frame, conc1Data, prof1.name)
        else
            conc1Text:SetText("--")
            conc1Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc1Frame)

        local prof2 = professions.Primary2
        local primary2Frame = CreateFrame("Frame", nil, charRow)
        primary2Frame:SetSize(90, 32)
        local primary2Text = OneWoW_GUI:CreateFS(primary2Frame, 12)
        primary2Text:SetPoint("LEFT", primary2Frame, "LEFT", 0, 0)
        primary2Text:SetJustifyH("LEFT")
        if prof2 and prof2.name then
            local totalCurrent, totalMax = GetTotalSkill(prof2)
            local iconMarkup = ns.ProfessionData:GetProfIconMarkup(prof2, 14, 14)
            primary2Text:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(primary2Frame, prof2, recipesByExpansion[prof2.name])
        else
            primary2Text:SetText("--")
        end
        primary2Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, primary2Frame)

        local conc2Frame = CreateFrame("Frame", nil, charRow)
        conc2Frame:SetSize(40, 32)
        local conc2Text = OneWoW_GUI:CreateFS(conc2Frame, 12)
        conc2Text:SetPoint("CENTER", conc2Frame, "CENTER", 0, 0)
        conc2Text:SetJustifyH("CENTER")
        local conc2Data = concentration.Primary2
        if prof2 and prof2.name and conc2Data and conc2Data.value then
            local current = GetEstimatedConcentration(conc2Data)
            conc2Text:SetText(tostring(current))
            local r, g, b = GetSkillColor(current, conc2Data.max or 0)
            conc2Text:SetTextColor(r, g, b)
            AddConcentrationTooltip(conc2Frame, conc2Data, prof2.name)
        else
            conc2Text:SetText("--")
            conc2Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
        table.insert(charRow.cells, conc2Frame)

        local cookingFrame = CreateFrame("Frame", nil, charRow)
        cookingFrame:SetSize(60, 32)
        local cookingText = OneWoW_GUI:CreateFS(cookingFrame, 12)
        cookingText:SetPoint("CENTER", cookingFrame, "CENTER", 0, 0)
        cookingText:SetJustifyH("CENTER")
        local cooking = professions.Cooking
        if cooking and cooking.name then
            local totalCurrent, totalMax = GetTotalSkill(cooking)
            local iconMarkup = ns.ProfessionData:GetProfIconMarkup(cooking, 14, 14)
            cookingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(cookingFrame, cooking, recipesByExpansion["Cooking"])
        else
            cookingText:SetText("--")
        end
        cookingText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, cookingFrame)

        local fishingFrame = CreateFrame("Frame", nil, charRow)
        fishingFrame:SetSize(60, 32)
        local fishingText = OneWoW_GUI:CreateFS(fishingFrame, 12)
        fishingText:SetPoint("CENTER", fishingFrame, "CENTER", 0, 0)
        fishingText:SetJustifyH("CENTER")
        local fishing = professions.Fishing
        if fishing and fishing.name then
            local totalCurrent, totalMax = GetTotalSkill(fishing)
            local iconMarkup = ns.ProfessionData:GetProfIconMarkup(fishing, 14, 14)
            fishingText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(fishingFrame, fishing, recipesByExpansion["Fishing"])
        else
            fishingText:SetText("--")
        end
        fishingText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, fishingFrame)

        local archeologyFrame = CreateFrame("Frame", nil, charRow)
        archeologyFrame:SetSize(80, 32)
        local archeologyText = OneWoW_GUI:CreateFS(archeologyFrame, 12)
        archeologyText:SetPoint("CENTER", archeologyFrame, "CENTER", 0, 0)
        archeologyText:SetJustifyH("CENTER")
        local archaeology = professions.Archaeology
        if archaeology and archaeology.name then
            local totalCurrent, totalMax = GetTotalSkill(archaeology)
            local iconMarkup = ns.ProfessionData:GetProfIconMarkup(archaeology, 14, 14)
            archeologyText:SetText(iconMarkup .. " " .. string.format("%d/%d", totalCurrent, totalMax))
            AddProfessionTooltip(archeologyFrame, archaeology, recipesByExpansion["Archaeology"])
        else
            archeologyText:SetText("--")
        end
        archeologyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, archeologyFrame)

        local gearText = OneWoW_GUI:CreateFS(charRow, 12)
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

    -- First-open hint: auto-expand row 1 the first time this tab renders rows
    -- in the current session so users discover the per-character expand panel.
    -- Per-session only (flag lives on the tab frame, resets on /reload).
    if not professionsTab._didInitialExpand and characterRows[1] then
        characterRows[1]:Expand()
        professionsTab._didInitialExpand = true
    end

    if professionsTab.statusText then
        professionsTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshProfessionsStats(professionsTab)

    OneWoW_GUI:ApplyFontToFrame(professionsTab)

    C_Timer.After(0.1, function()
        if professionsTab.headerRow then
            professionsTab.headerRow:GetScript("OnSizeChanged")(professionsTab.headerRow)
        end
    end)
end

function ns.UI.RefreshProfessionsStats(professionsTab)
    if not professionsTab or not professionsTab.statBoxes then return end

    if not OneWoW_AltTracker_Character_API then return end

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
    for charKey, charData in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
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
        local charRecipeProgress = professionData.recipeProgress or {}

        -- Catalog totals only count when the catalog data unit is loaded; without
        -- it, contribute the stored Known count and leave the total untouched.
        local function AccumulateRecipes(profName)
            local progress = charRecipeProgress[profName]
            if not progress then return end
            if progress.catalogLoaded then
                stats.recipesKnown = stats.recipesKnown + (progress.known or 0)
                stats.recipesTotal = stats.recipesTotal + (progress.total or 0)
            else
                stats.recipesKnown = stats.recipesKnown + (progress.stored or 0)
            end
        end

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

            AccumulateRecipes(professions.Primary1.name)
        end

        if professions.Primary2 and professions.Primary2.name then
            hasPrimary2 = true
            uniquePrimaryProfs[professions.Primary2.name] = true

            local totalCurrent, totalMax = GetTotalSkill(professions.Primary2)
            if totalCurrent >= totalMax and totalMax > 0 then
                stats.maxLevelProfs = stats.maxLevelProfs + 1
            end

            AccumulateRecipes(professions.Primary2.name)
        end

        if professions.Cooking and professions.Cooking.name then
            hasCooking = true
            uniqueSecondaryProfs["Cooking"] = true

            AccumulateRecipes("Cooking")
        end

        if professions.Fishing and professions.Fishing.name then
            hasFishing = true
            uniqueSecondaryProfs["Fishing"] = true

            AccumulateRecipes("Fishing")
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
