-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesHyperlinks.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.NotesHyperlinks = {}
local NotesHyperlinks = ns.NotesHyperlinks

function NotesHyperlinks:ConvertManualLinks(text)
    if not text then return text end

    local function convertItemID(itemID)
        local id = tonumber(itemID)
        if id then
            local itemName, itemLink = GetItemInfo(id)
            if itemLink then
                return itemLink
            else
                return "(item=" .. id .. ")"
            end
        end
        return "(item=" .. itemID .. ")"
    end

    local function convertSpellID(spellID)
        local id = tonumber(spellID)
        if id then
            local spellLink = nil
            if C_Spell and C_Spell.GetSpellLink then
                spellLink = C_Spell.GetSpellLink(id)
            elseif GetSpellLink then
                spellLink = GetSpellLink(id)
            elseif C_SpellBook and C_SpellBook.GetSpellLinkFromSpellID then
                spellLink = C_SpellBook.GetSpellLinkFromSpellID(id)
            end
            if spellLink then return spellLink end
        end
        return "(spell=" .. spellID .. ")"
    end

    local function convertQuestID(questID)
        local id = tonumber(questID)
        if id then
            local questLink = nil
            if GetQuestLink then
                questLink = GetQuestLink(id)
            elseif C_QuestLog and C_QuestLog.GetQuestLink then
                questLink = C_QuestLog.GetQuestLink(id)
            end
            if questLink then return questLink end
        end
        return "(quest=" .. questID .. ")"
    end

    local function convertAchievementID(achievementID)
        local id = tonumber(achievementID)
        if id then
            local achievementLink = nil
            if GetAchievementLink then
                achievementLink = GetAchievementLink(id)
            end
            if achievementLink then return achievementLink end
        end
        return "(achievement=" .. achievementID .. ")"
    end

    local function convertCurrencyID(currencyID)
        local id = tonumber(currencyID)
        if id then
            local currencyLink = nil
            if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
                currencyLink = C_CurrencyInfo.GetCurrencyLink(id)
            end
            if currencyLink then return currencyLink end
        end
        return "(currency=" .. currencyID .. ")"
    end

    local function convertToyID(toyID)
        local id = tonumber(toyID)
        if id then
            local toyLink = nil
            if C_ToyBox and C_ToyBox.GetToyLink then
                toyLink = C_ToyBox.GetToyLink(id)
            end
            if toyLink then return toyLink end
        end
        return "(toy=" .. toyID .. ")"
    end

    local function convertBattlePetID(petID)
        local id = tonumber(petID)
        if id then
            local petLink = nil
            if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
                local speciesName = C_PetJournal.GetPetInfoBySpeciesID(id)
                if speciesName and type(speciesName) == "string" and speciesName ~= "" then
                    petLink = "|cffffd000|Hbattlepet:species:" .. id .. "|h[" .. speciesName .. "]|h|r"
                end
            end
            if petLink then return petLink end
        end
        return "(battlepet=" .. petID .. ")"
    end

    local function convertMountID(mountID)
        local id = tonumber(mountID)
        if id then
            local mountLink = nil
            if C_MountJournal and C_MountJournal.GetMountInfoByID then
                local name, spellID = C_MountJournal.GetMountInfoByID(id)
                if name and spellID then
                    local spellLink = nil
                    if C_Spell and C_Spell.GetSpellLink then
                        spellLink = C_Spell.GetSpellLink(spellID)
                    elseif GetSpellLink then
                        spellLink = GetSpellLink(spellID)
                    end
                    if spellLink then
                        mountLink = spellLink
                    else
                        mountLink = "|cff71d5ff|Hspell:" .. spellID .. "|h[" .. name .. "]|h|r"
                    end
                end
            end
            if mountLink then return mountLink end
        end
        return "(mount=" .. mountID .. ")"
    end

    local function createWaypointLink(mapID, x, y, label)
        local mID = tonumber(mapID)
        local px = tonumber(x)
        local py = tonumber(y)
        if mID and px and py then
            if mID == 0 then
                mID = C_Map.GetBestMapForUnit("player")
                if not mID then
                    return "(map=0 " .. px .. " " .. py .. (label or "") .. ")"
                end
            end
            local displayLabel = label and label:trim() or "Waypoint"
            if displayLabel == "" then displayLabel = "Waypoint" end
            return string.format(
                "|cffffff00|Hworldmap:%s:%s:%s|h[|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a %s]|h|r",
                mID, math.floor(px * 100), math.floor(py * 100), displayLabel
            )
        end
        return nil
    end

    text = text:gsub("%(item=(%d+)%)", convertItemID)
    text = text:gsub("%(itm=(%d+)%)", convertItemID)
    text = text:gsub("%(spell=(%d+)%)", convertSpellID)
    text = text:gsub("%(spe=(%d+)%)", convertSpellID)
    text = text:gsub("%(quest=(%d+)%)", convertQuestID)
    text = text:gsub("%(que=(%d+)%)", convertQuestID)
    text = text:gsub("%(achievement=(%d+)%)", convertAchievementID)
    text = text:gsub("%(ach=(%d+)%)", convertAchievementID)
    text = text:gsub("%(currency=(%d+)%)", convertCurrencyID)
    text = text:gsub("%(cur=(%d+)%)", convertCurrencyID)
    text = text:gsub("%([$]=(%d+)%)", convertCurrencyID)
    text = text:gsub("%(toy=(%d+)%)", convertToyID)
    text = text:gsub("%(battlepet=(%d+)%)", convertBattlePetID)
    text = text:gsub("%(mount=(%d+)%)", convertMountID)

    text = text:gsub("%(/?way ([%d%.]+) ([%d%.]+)([^%)\n]*)", function(x, y, label)
        local currentMapID = C_Map.GetBestMapForUnit("player")
        if currentMapID then
            local link = createWaypointLink(currentMapID, x, y, label)
            if link then return link end
        end
        return "(/way " .. x .. " " .. y .. (label or "") .. ")"
    end)

    text = text:gsub("%(map=(%d+) ([%d%.]+) ([%d%.]+)([^%)\n]*)", function(mapID, x, y, label)
        local link = createWaypointLink(mapID, x, y, label)
        if link then return link end
        return "(map=" .. mapID .. " " .. x .. " " .. y .. (label or "") .. ")"
    end)

    text = text:gsub("%(worldmap=(%d+):([%d%.]+):([%d%.]+):([^%)\n]+)%)", function(mapID, x, y, label)
        local link = createWaypointLink(mapID, x, y, label)
        if link then return link end
        return "(worldmap=" .. mapID .. ":" .. x .. ":" .. y .. ":" .. label .. ")"
    end)

    return text
end

function NotesHyperlinks:EnhanceEditBox(editBox)
    if not editBox then return end

    editBox:SetScript("OnChar", function(self, char)
        if char == ")" then
            local fullText = self:GetText()
            local cursorPos = self:GetCursorPosition()

            local lineStart = 1
            local searchPos = cursorPos
            while searchPos > 1 do
                local byte = string.byte(fullText, searchPos - 1)
                if byte == 10 then break end
                searchPos = searchPos - 1
            end
            lineStart = searchPos

            local lineEnd = cursorPos
            local textLen = string.len(fullText)
            while lineEnd < textLen do
                lineEnd = lineEnd + 1
                local byte = string.byte(fullText, lineEnd)
                if byte == 10 then
                    lineEnd = lineEnd - 1
                    break
                end
            end

            local beforeLine = string.sub(fullText, 1, lineStart - 1)
            local currentLine = string.sub(fullText, lineStart, lineEnd)
            local afterLine = string.sub(fullText, lineEnd + 1)

            local convertedLine = NotesHyperlinks:ConvertManualLinks(currentLine)
            if convertedLine ~= currentLine then
                local newText = beforeLine .. convertedLine .. afterLine
                self:SetText(newText)
                local lineDiff = string.len(convertedLine) - string.len(currentLine)
                self:SetCursorPosition(cursorPos + lineDiff)
            end
        end
    end)

    return editBox
end

ns.UI = ns.UI or {}

function ns.UI.CreateNotesHelpPanel()
    local L      = ns.L

    local EDGE     = OneWoW_GUI:GetSpacing("XS")
    local TITLE_H  = 20
    local PANEL_W  = 320
    local PANEL_H  = 600

    local helpPanel = CreateFrame("Frame", "OneWoW_Notes_HelpPanel", UIParent, "BackdropTemplate")
    helpPanel:SetSize(PANEL_W, PANEL_H)
    helpPanel:SetFrameStrata("MEDIUM")
    helpPanel:SetToplevel(true)
    helpPanel:SetClampedToScreen(true)
    helpPanel:EnableMouse(true)
    helpPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    helpPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    helpPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    helpPanel:Hide()

    helpPanel._visibilityTicker = nil
    helpPanel:SetScript("OnShow", function(self)
        local mf = _G.OneWoW_NotesMainFrame or _G.OneWoWMainWindow
        if mf and mf:IsShown() then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", mf, "TOPRIGHT", 5, 0)
        end
        if not self._visibilityTicker then
            self._visibilityTicker = C_Timer.NewTicker(0.5, function()
                local mainFrame = _G.OneWoW_NotesMainFrame or _G.OneWoWMainWindow
                if not mainFrame or not mainFrame:IsShown() then
                    self:Hide()
                end
            end)
        end
    end)

    helpPanel:SetScript("OnHide", function(self)
        if self._visibilityTicker then
            self._visibilityTicker:Cancel()
            self._visibilityTicker = nil
        end
    end)

    -- =============================================
    -- TITLE BAR
    -- =============================================
    local titleBar = CreateFrame("Frame", nil, helpPanel, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  helpPanel, "TOPLEFT",  EDGE, -EDGE)
    titleBar:SetPoint("TOPRIGHT", helpPanel, "TOPRIGHT", -EDGE, -EDGE)
    titleBar:SetHeight(TITLE_H)
    titleBar:SetBackdrop(BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:SetFrameLevel(helpPanel:GetFrameLevel() + 1)

    local titleText = OneWoW_GUI:CreateFS(titleBar, 12)
    titleText:SetPoint("LEFT", titleBar, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    titleText:SetText(L["UI_HELP_PANEL_TITLE"])
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -EDGE / 2, 0)
    closeBtn:SetScript("OnClick", function() helpPanel:Hide() end)

    -- =============================================
    -- CONTENT AREA + TAB BUTTONS
    -- =============================================
    local tabAreaTop = -(EDGE + TITLE_H + OneWoW_GUI:GetSpacing("XS"))

    local linksContent = CreateFrame("Frame", nil, helpPanel)
    local pinsContent  = CreateFrame("Frame", nil, helpPanel)
    pinsContent:Hide()

    local tabBtns, tabsBottomY = OneWoW_GUI:CreateFitFrameButtons(helpPanel, {
        yOffset  = tabAreaTop,
        items    = {
            { text = L["UI_HELP_TAB_LINKS"], value = "links", isActive = true },
            { text = L["UI_HELP_TAB_PINS"],  value = "pins"                   },
        },
        height   = 28,
        gap      = 4,
        marginX  = EDGE,
        onSelect = function(value)
            linksContent:SetShown(value == "links")
            pinsContent:SetShown(value == "pins")
        end,
    })

    local contentTop = tabsBottomY - OneWoW_GUI:GetSpacing("XS")

    linksContent:SetPoint("TOPLEFT",     helpPanel, "TOPLEFT",     EDGE, contentTop)
    linksContent:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -EDGE, EDGE)

    pinsContent:SetPoint("TOPLEFT",     helpPanel, "TOPLEFT",     EDGE, contentTop)
    pinsContent:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -EDGE, EDGE)

    -- =============================================
    -- LINKS TAB
    -- =============================================
    local hintText = OneWoW_GUI:CreateFS(linksContent, 10)
    hintText:SetPoint("TOPLEFT",  linksContent, "TOPLEFT",  0, -2)
    hintText:SetPoint("TOPRIGHT", linksContent, "TOPRIGHT", 0, -2)
    hintText:SetJustifyH("LEFT")
    hintText:SetText(L["UI_HELP_LINKS_HINT"])
    hintText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local linksScrollObj = ns.UI.CreateCustomScroll(linksContent)
    linksScrollObj.container:SetPoint("TOPLEFT",     linksContent, "TOPLEFT",     0, -20)
    linksScrollObj.container:SetPoint("BOTTOMRIGHT", linksContent, "BOTTOMRIGHT", 0,   0)

    local linksScrollContent = linksScrollObj.scrollChild

    local linkTypes = {
        { name = L["UI_HELP_LINK_ITEM_NAME"],     syntax = L["UI_HELP_LINK_ITEM_SYNTAX"],     example = L["UI_HELP_LINK_ITEM_EXAMPLE"],     icon = "Interface\\Icons\\INV_Misc_Note_01" },
        { name = L["UI_HELP_LINK_SPELL_NAME"],    syntax = L["UI_HELP_LINK_SPELL_SYNTAX"],    example = L["UI_HELP_LINK_SPELL_EXAMPLE"],    icon = "Interface\\Icons\\INV_Misc_Book_09" },
        { name = L["UI_HELP_LINK_QUEST_NAME"],    syntax = L["UI_HELP_LINK_QUEST_SYNTAX"],    example = L["UI_HELP_LINK_QUEST_EXAMPLE"],    icon = "Interface\\Icons\\INV_Misc_Note_02" },
        { name = L["UI_HELP_LINK_ACHV_NAME"],     syntax = L["UI_HELP_LINK_ACHV_SYNTAX"],     example = L["UI_HELP_LINK_ACHV_EXAMPLE"],     icon = "Interface\\Icons\\Achievement_General" },
        { name = L["UI_HELP_LINK_CURRENCY_NAME"], syntax = L["UI_HELP_LINK_CURRENCY_SYNTAX"], example = L["UI_HELP_LINK_CURRENCY_EXAMPLE"], icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { name = L["UI_HELP_LINK_TOY_NAME"],      syntax = L["UI_HELP_LINK_TOY_SYNTAX"],      example = L["UI_HELP_LINK_TOY_EXAMPLE"],      icon = "Interface\\Icons\\INV_Misc_Toy_10" },
        { name = L["UI_HELP_LINK_PET_NAME"],      syntax = L["UI_HELP_LINK_PET_SYNTAX"],      example = L["UI_HELP_LINK_PET_EXAMPLE"],      icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
        { name = L["UI_HELP_LINK_MOUNT_NAME"],    syntax = L["UI_HELP_LINK_MOUNT_SYNTAX"],    example = L["UI_HELP_LINK_MOUNT_EXAMPLE"],    icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
        { name = L["UI_HELP_LINK_WAYPOINT_NAME"], syntax = L["UI_HELP_LINK_WAYPOINT_SYNTAX"], example = L["UI_HELP_LINK_WAYPOINT_EXAMPLE"], icon = "Interface\\Icons\\Taxi_Flight_Path_Unfriendly" },
    }

    local expandedRows   = {}
    local allRows        = {}
    local allDetailFrames = {}

    local fromGameLabel = OneWoW_GUI:CreateFS(linksScrollContent, 12)
    fromGameLabel:SetJustifyH("LEFT")
    fromGameLabel:SetText(L["UI_HELP_FROM_GAME"])
    fromGameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local fromGameDesc = OneWoW_GUI:CreateFS(linksScrollContent, 10)
    fromGameDesc:SetJustifyH("LEFT")
    fromGameDesc:SetWordWrap(true)
    fromGameDesc:SetText(L["UI_HELP_FROM_GAME_DESC"])
    fromGameDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local function UpdateRowPositions()
        local yPos = 0
        for i, row in ipairs(allRows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  linksScrollContent, "TOPLEFT",  0, yPos)
            row:SetPoint("TOPRIGHT", linksScrollContent, "TOPRIGHT", 0, yPos)
            yPos = yPos - 24

            if expandedRows[i] and allDetailFrames[i] then
                allDetailFrames[i]:ClearAllPoints()
                allDetailFrames[i]:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  0, -2)
                allDetailFrames[i]:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                yPos = yPos - 66
            end
        end

        local fromGameY = yPos - 8
        fromGameLabel:ClearAllPoints()
        fromGameLabel:SetPoint("TOPLEFT",  linksScrollContent, "TOPLEFT",  0, fromGameY)
        fromGameLabel:SetPoint("TOPRIGHT", linksScrollContent, "TOPRIGHT", 0, fromGameY)

        fromGameDesc:ClearAllPoints()
        fromGameDesc:SetPoint("TOPLEFT",  linksScrollContent, "TOPLEFT",  0, fromGameY - 20)
        fromGameDesc:SetPoint("TOPRIGHT", linksScrollContent, "TOPRIGHT", 0, fromGameY - 20)

        linksScrollContent:SetHeight(math.abs(fromGameY) + 80)
        linksScrollObj.UpdateThumb()
    end

    for i, linkType in ipairs(linkTypes) do
        local row = CreateFrame("Button", nil, linksScrollContent, "BackdropTemplate")
        row:SetHeight(22)
        row:SetPoint("TOPLEFT",  linksScrollContent, "TOPLEFT",  0, 0)
        row:SetPoint("TOPRIGHT", linksScrollContent, "TOPRIGHT", 0, 0)
        row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        icon:SetTexture(linkType.icon)

        local rowText = OneWoW_GUI:CreateFS(row, 10)
        rowText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        rowText:SetText(linkType.name .. "  " .. linkType.syntax)
        rowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local expandIcon = row:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(12, 12)
        expandIcon:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        expandIcon:SetAtlas("common-button-collapseExpand-down")

        local detailFrame = CreateFrame("Frame", nil, linksScrollContent, "BackdropTemplate")
        detailFrame:SetHeight(64)
        detailFrame:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  0, -2)
        detailFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
        detailFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        detailFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        detailFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        detailFrame:Hide()

        local instrText = OneWoW_GUI:CreateFS(detailFrame, 10)
        instrText:SetPoint("TOPLEFT",  detailFrame, "TOPLEFT",  8, -6)
        instrText:SetPoint("TOPRIGHT", detailFrame, "TOPRIGHT", -8, -6)
        instrText:SetJustifyH("LEFT")
        instrText:SetWordWrap(true)
        instrText:SetText(L["UI_HELP_DETAIL_INSTRUCTION"])
        instrText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local exampleText = OneWoW_GUI:CreateFS(detailFrame, 10)
        exampleText:SetPoint("TOPLEFT",  instrText, "BOTTOMLEFT",  0, -3)
        exampleText:SetPoint("TOPRIGHT", instrText, "BOTTOMRIGHT", 0, -3)
        exampleText:SetJustifyH("LEFT")
        exampleText:SetText(string.format(L["UI_HELP_DETAIL_EXAMPLE"], linkType.example))
        exampleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local pasteBtn = OneWoW_GUI:CreateButton(detailFrame, { text = L["UI_HELP_PASTE_BUTTON"], width = 60, height = 20 })
        pasteBtn:SetPoint("BOTTOMLEFT", detailFrame, "BOTTOMLEFT", 8, 6)
        pasteBtn:SetScript("OnClick", function()
            local editBox = ns.UI.activeContentEditBox
            if editBox then
                local template = linkType.syntax:match("^%(.-=") or linkType.syntax:match("^%(/way ")
                if template then
                    editBox:SetFocus()
                    editBox:Insert(template)
                end
            end
        end)

        table.insert(allRows, row)
        table.insert(allDetailFrames, detailFrame)

        row:SetScript("OnClick", function()
            if detailFrame:IsShown() then
                detailFrame:Hide()
                expandIcon:SetAtlas("common-button-collapseExpand-down")
                expandedRows[i] = false
            else
                detailFrame:Show()
                expandIcon:SetAtlas("common-button-collapseExpand-up")
                expandedRows[i] = true
            end
            UpdateRowPositions()
        end)

        row:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY")) end)
    end

    UpdateRowPositions()

    -- =============================================
    -- PINS TAB
    -- =============================================
    local pinsScrollObj = ns.UI.CreateCustomScroll(pinsContent)
    pinsScrollObj.container:SetPoint("TOPLEFT",     pinsContent, "TOPLEFT",     0, 0)
    pinsScrollObj.container:SetPoint("BOTTOMRIGHT", pinsContent, "BOTTOMRIGHT", 0, 0)

    local pinsScrollContent = pinsScrollObj.scrollChild

    local function CreatePinCard(title, lines, yOffset)
        local card = CreateFrame("Frame", nil, pinsScrollContent, "BackdropTemplate")
        card:SetPoint("TOPLEFT",  pinsScrollContent, "TOPLEFT",  0, yOffset)
        card:SetPoint("TOPRIGHT", pinsScrollContent, "TOPRIGHT", 0, yOffset)
        card:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local cardTitle = OneWoW_GUI:CreateFS(card, 12)
        cardTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
        cardTitle:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
        cardTitle:SetJustifyH("LEFT")
        cardTitle:SetText(title)
        cardTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local currentY = -26
        for _, line in ipairs(lines) do
            local lineText = OneWoW_GUI:CreateFS(card, 10)
            lineText:SetPoint("TOPLEFT",  card, "TOPLEFT",  10, currentY)
            lineText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, currentY)
            lineText:SetJustifyH("LEFT")
            lineText:SetWordWrap(true)
            lineText:SetText(line)
            lineText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            currentY = currentY - lineText:GetStringHeight() - 6
        end

        local cardHeight = math.abs(currentY) + 10
        card:SetHeight(cardHeight)
        return cardHeight
    end

    local cardY = 0
    local h1 = CreatePinCard(L["UI_HELP_PIN_REGULAR_TITLE"], {
        L["UI_HELP_PIN_REGULAR_LINE1"],
        L["UI_HELP_PIN_REGULAR_LINE2"],
        L["UI_HELP_PIN_REGULAR_LINE3"],
    }, cardY)
    cardY = cardY - h1 - 8

    local h2 = CreatePinCard(L["UI_HELP_PIN_DAILY_TITLE"], {
        L["UI_HELP_PIN_DAILY_LINE1"],
        L["UI_HELP_PIN_DAILY_LINE2"],
        L["UI_HELP_PIN_DAILY_LINE3"],
    }, cardY)
    cardY = cardY - h2 - 8

    local h3 = CreatePinCard(L["UI_HELP_PIN_ZONE_TITLE"], {
        L["UI_HELP_PIN_ZONE_LINE1"],
        L["UI_HELP_PIN_ZONE_LINE2"],
        L["UI_HELP_PIN_ZONE_LINE3"],
    }, cardY)
    cardY = cardY - h3

    pinsScrollContent:SetHeight(math.abs(cardY) + 20)
    pinsScrollObj.UpdateThumb()

    return helpPanel
end
