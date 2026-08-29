local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.NotesHyperlinks = {}
local NotesHyperlinks = ns.NotesHyperlinks

-- Custom hyperlink type for collectible references. Unlike item/spell/etc. tokens
-- (which convert to native Blizzard links), a collectible link has no native
-- counterpart: clicking `|Honewowcollectible:<key>|h` is dispatched by
-- LinkUtil.ProcessLink (via SetItemRef) to the handler registered below, opening
-- the Collectibles tab. The key keeps its own colons (mount:1234,
-- appearance:source:5678) — LinkUtil.SplitLinkData only peels the leading type off,
-- so `linkData.options` is the whole key.
local COLLECTIBLE_LINK_TYPE = "onewowcollectible"
-- OneWoW brand gold (matches the chat print prefix) so a collectible ref reads as
-- an addon link, not a Blizzard item/spell link.
local COLLECTIBLE_LINK_COLOR = "|cFFFFD100"

--- Builds a clickable collectible hyperlink for a key, or nil if the key is
--- invalid. Display text is the live collectible name, falling back to the generic
--- label while the name is unresolved (e.g. an uncached appearance).
---@param key string
---@return string|nil link
function NotesHyperlinks:BuildCollectibleLink(key)
    local canonical = OneWoW.Collectibles.CanonicalizeKey(key)
    if not canonical then return nil end
    local display = OneWoW.Collectibles.ResolveDisplay(canonical)
    local name = (display and display.name) or ns.L["TAB_COLLECTIBLES"]
    return COLLECTIBLE_LINK_COLOR .. "|H" .. COLLECTIBLE_LINK_TYPE .. ":" .. canonical .. "|h[" .. name .. "]|h|r"
end

-- Route clicks on collectible links to the Collectibles tab. Registered once;
-- returning nil marks the link handled, so SetItemRef never falls through to the
-- default item-ref tooltip for our custom type.
if LinkUtil and not LinkUtil.IsLinkHandlerRegistered(COLLECTIBLE_LINK_TYPE) then
    LinkUtil.RegisterLinkHandler(COLLECTIBLE_LINK_TYPE, function(_, _, linkData)
        local key = linkData and linkData.options
        if key and key ~= "" and OneWoW_Notes_API and OneWoW_Notes_API.OpenCollectible then
            OneWoW_Notes_API.OpenCollectible(key)
        end
    end)
end

function NotesHyperlinks:ConvertManualLinks(text)
    if not text then return text end

    local function convertItemID(itemID)
        local id = tonumber(itemID)
        if id then
            local _, itemLink = C_Item.GetItemInfo(id)
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
            local spellLink = C_Spell.GetSpellLink(id)
            if spellLink then return spellLink end
        end
        return "(spell=" .. spellID .. ")"
    end

    local function convertQuestID(questID)
        local id = tonumber(questID)
        if id then
            local questLink = GetQuestLink(id)
            if questLink then return questLink end
        end
        return "(quest=" .. questID .. ")"
    end

    local function convertAchievementID(achievementID)
        local id = tonumber(achievementID)
        if id then
            local achievementLink = GetAchievementLink(id)
            if achievementLink then return achievementLink end
        end
        return "(achievement=" .. achievementID .. ")"
    end

    local function convertCurrencyID(currencyID)
        local id = tonumber(currencyID)
        if id then
            local currencyLink = C_CurrencyInfo.GetCurrencyLink(id)
            if currencyLink then return currencyLink end
        end
        return "(currency=" .. currencyID .. ")"
    end

    local function convertToyID(toyID)
        local id = tonumber(toyID)
        if id then
            local toyLink = C_ToyBox.GetToyLink(id)
            if toyLink then return toyLink end
        end
        return "(toy=" .. toyID .. ")"
    end

    local function convertBattlePetID(petID)
        local id = tonumber(petID)
        if id then
            local petLink = nil
            local speciesName = C_PetJournal.GetPetInfoBySpeciesID(id)
            if speciesName and type(speciesName) == "string" and speciesName ~= "" then
                petLink = "|cffffd000|Hbattlepet:species:" .. id .. "|h[" .. speciesName .. "]|h|r"
            end

            if petLink then return petLink end
        end
        return "(battlepet=" .. petID .. ")"
    end

    local function convertMountID(mountID)
        local id = tonumber(mountID)
        if id then
            local mountLink = nil
            local name, spellID = C_MountJournal.GetMountInfoByID(id)
            if name and spellID then
                local spellLink = C_Spell.GetSpellLink(spellID)
                if spellLink then
                    mountLink = spellLink
                else
                    mountLink = "|cff71d5ff|Hspell:" .. spellID .. "|h[" .. name .. "]|h|r"
                end
            end
            if mountLink then return mountLink end
        end
        return "(mount=" .. mountID .. ")"
    end

    local function convertCollectible(key)
        local link = NotesHyperlinks:BuildCollectibleLink(key)
        if link then return link end
        return "(collectible=" .. key .. ")"
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
    text = text:gsub("%(collectible=([%w:]+)%)", convertCollectible)
    text = text:gsub("%(coll=([%w:]+)%)", convertCollectible)

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

    editBox:SetScript("OnChar", function(myself, char)
        if char == ")" then
            local fullText = myself:GetText()
            local cursorPos = myself:GetCursorPosition()

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
                myself:SetText(newText)
                local lineDiff = string.len(convertedLine) - string.len(currentLine)
                myself:SetCursorPosition(cursorPos + lineDiff)
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
        local mf = OneWoWMainWindow
        if mf and mf:IsShown() then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", mf, "TOPRIGHT", 5, 0)
        end
        if not self._visibilityTicker then
            self._visibilityTicker = C_Timer.NewTicker(0.5, function()
                local mainFrame = OneWoWMainWindow
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

    local _, tabsBottomY = OneWoW_GUI:CreateFitFrameButtons(helpPanel, {
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
        { name = L["ITEM"],     syntax = L["UI_HELP_LINK_ITEM_SYNTAX"],     example = L["UI_HELP_LINK_ITEM_EXAMPLE"],     icon = "Interface\\Icons\\INV_Misc_Note_01" },
        { name = L["CTX_LINK_TYPE_SPELL"],    syntax = L["UI_HELP_LINK_SPELL_SYNTAX"],    example = L["UI_HELP_LINK_SPELL_EXAMPLE"],    icon = "Interface\\Icons\\INV_Misc_Book_09" },
        { name = L["UI_HELP_LINK_QUEST_NAME"],    syntax = L["UI_HELP_LINK_QUEST_SYNTAX"],    example = L["UI_HELP_LINK_QUEST_EXAMPLE"],    icon = "Interface\\Icons\\INV_Misc_Note_02" },
        { name = L["ACHIEVEMENT"],     syntax = L["UI_HELP_LINK_ACHV_SYNTAX"],     example = L["UI_HELP_LINK_ACHV_EXAMPLE"],     icon = "Interface\\Icons\\Achievement_General" },
        { name = CURRENCY, syntax = L["UI_HELP_LINK_CURRENCY_SYNTAX"], example = L["UI_HELP_LINK_CURRENCY_EXAMPLE"], icon = "Interface\\Icons\\INV_Misc_Coin_01" },
        { name = TOY,      syntax = L["UI_HELP_LINK_TOY_SYNTAX"],      example = L["UI_HELP_LINK_TOY_EXAMPLE"],      icon = "Interface\\Icons\\INV_Misc_Toy_10" },
        { name = L["BATTLE_PET"],      syntax = L["UI_HELP_LINK_PET_SYNTAX"],      example = L["UI_HELP_LINK_PET_EXAMPLE"],      icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
        { name = MOUNT,    syntax = L["UI_HELP_LINK_MOUNT_SYNTAX"],    example = L["UI_HELP_LINK_MOUNT_EXAMPLE"],    icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
        { name = L["TAB_COLLECTIBLES"], syntax = L["UI_HELP_LINK_COLLECTIBLE_SYNTAX"], example = L["UI_HELP_LINK_COLLECTIBLE_EXAMPLE"], icon = "Interface\\Icons\\INV_Misc_Gift_02" },
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

    -- Pure relative-anchor stacking: each row (and its expanded detail) is pinned
    -- below the previous element's BOTTOM, so the widget system computes the gaps
    -- itself. Detail frames auto-size to their wrapped contents (see below), so a
    -- larger font grows the layout instead of overlapping it.
    local function UpdateLinksScrollHeight()
        local top    = linksScrollContent:GetTop()
        local bottom = fromGameDesc:GetBottom()
        if top and bottom and top > bottom then
            linksScrollContent:SetHeight((top - bottom) + 20)
        end
        linksScrollObj.UpdateThumb()
    end

    local function UpdateRowPositions()
        local prev = nil
        for i, row in ipairs(allRows) do
            row:ClearAllPoints()
            if prev then
                row:SetPoint("TOPLEFT",  prev, "BOTTOMLEFT",  0, -2)
                row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -2)
            else
                row:SetPoint("TOPLEFT",  linksScrollContent, "TOPLEFT",  0, 0)
                row:SetPoint("TOPRIGHT", linksScrollContent, "TOPRIGHT", 0, 0)
            end
            prev = row

            -- The detail frame stays anchored to its row (set at creation), so
            -- it follows automatically; when expanded it becomes the anchor the
            -- next row stacks beneath.
            if expandedRows[i] and allDetailFrames[i] then
                prev = allDetailFrames[i]
            end
        end

        fromGameLabel:ClearAllPoints()
        fromGameLabel:SetPoint("TOPLEFT",  prev or linksScrollContent, prev and "BOTTOMLEFT"  or "TOPLEFT",  0, -8)
        fromGameLabel:SetPoint("TOPRIGHT", prev or linksScrollContent, prev and "BOTTOMRIGHT" or "TOPRIGHT", 0, -8)

        fromGameDesc:ClearAllPoints()
        fromGameDesc:SetPoint("TOP",   fromGameLabel, "BOTTOM", 0, -4)
        fromGameDesc:SetPoint("LEFT",  linksScrollContent, "LEFT",  0, 0)
        fromGameDesc:SetPoint("RIGHT", linksScrollContent, "RIGHT", 0, 0)

        UpdateLinksScrollHeight()
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

        -- The detail's contents anchor to the ROW (not to the detail frame) and
        -- chain vertically among themselves, so nothing anchors back to the
        -- detail frame. That lets the detail frame safely wrap them by pinning
        -- its BOTTOM to the Paste button without creating an anchor cycle. The
        -- whole stack therefore grows with the font and never overlaps.
        local detailFrame = CreateFrame("Frame", nil, linksScrollContent, "BackdropTemplate")
        detailFrame:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  0, -2)
        detailFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
        detailFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        detailFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        detailFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        detailFrame:Hide()

        local instrText = OneWoW_GUI:CreateFS(detailFrame, 10)
        instrText:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  8, -8)
        instrText:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", -8, -8)
        instrText:SetJustifyH("LEFT")
        instrText:SetWordWrap(true)
        instrText:SetText(L["UI_HELP_DETAIL_INSTRUCTION"])
        instrText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local exampleText = OneWoW_GUI:CreateFS(detailFrame, 10)
        exampleText:SetPoint("TOP",   instrText, "BOTTOM", 0, -3)
        exampleText:SetPoint("LEFT",  row, "LEFT",  8, 0)
        exampleText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        exampleText:SetJustifyH("LEFT")
        exampleText:SetWordWrap(true)
        exampleText:SetText(string.format(L["UI_HELP_DETAIL_EXAMPLE"], linkType.example))
        exampleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local pasteBtn = OneWoW_GUI:CreateButton(detailFrame, { text = L["UI_HELP_PASTE_BUTTON"], width = 60, height = 20 })
        pasteBtn:SetPoint("TOPLEFT", exampleText, "BOTTOMLEFT", 0, -6)
        detailFrame:SetPoint("BOTTOM", pasteBtn, "BOTTOM", 0, -6)
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
            C_Timer.After(0, UpdateLinksScrollHeight)
        end)

        row:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY")) end)
    end

    UpdateRowPositions()
    linksScrollContent:HookScript("OnSizeChanged", UpdateLinksScrollHeight)
    linksContent:HookScript("OnShow", function() C_Timer.After(0, UpdateLinksScrollHeight) end)

    -- =============================================
    -- PINS TAB
    -- =============================================
    local pinsScrollObj = ns.UI.CreateCustomScroll(pinsContent)
    pinsScrollObj.container:SetPoint("TOPLEFT",     pinsContent, "TOPLEFT",     0, 0)
    pinsScrollObj.container:SetPoint("BOTTOMRIGHT", pinsContent, "BOTTOMRIGHT", 0, 0)

    local pinsScrollContent = pinsScrollObj.scrollChild

    -- Each card's title/lines anchor to the SCROLL CHILD (external) for width and
    -- chain vertically (TOP -> previous element's BOTTOM); nothing anchors back to
    -- the card. The card frame then wraps that content (TOPLEFT from its title,
    -- BOTTOM from its last line) without forming an anchor cycle. Result: pure
    -- widget-driven layout that adapts to any font and never overlaps, with no
    -- GetStringHeight measurement.
    local pinCards = {}
    local prevCard = nil

    local function CreatePinCard(title, lines)
        local card = CreateFrame("Frame", nil, pinsScrollContent, "BackdropTemplate")
        card:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local cardTitle = OneWoW_GUI:CreateFS(card, 12)
        if prevCard then
            cardTitle:SetPoint("TOPLEFT",  prevCard, "BOTTOMLEFT",  8, -16)
            cardTitle:SetPoint("TOPRIGHT", prevCard, "BOTTOMRIGHT", -8, -16)
        else
            cardTitle:SetPoint("TOPLEFT",  pinsScrollContent, "TOPLEFT",  8, -8)
            cardTitle:SetPoint("TOPRIGHT", pinsScrollContent, "TOPRIGHT", -8, -8)
        end
        cardTitle:SetJustifyH("LEFT")
        cardTitle:SetWordWrap(true)
        cardTitle:SetText(title)
        cardTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local prev = cardTitle
        for _, line in ipairs(lines) do
            local lineText = OneWoW_GUI:CreateFS(card, 10)
            lineText:SetPoint("TOP",   prev, "BOTTOM", 0, -6)
            lineText:SetPoint("LEFT",  pinsScrollContent, "LEFT",  10, 0)
            lineText:SetPoint("RIGHT", pinsScrollContent, "RIGHT", -10, 0)
            lineText:SetJustifyH("LEFT")
            lineText:SetWordWrap(true)
            lineText:SetText(line)
            lineText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            prev = lineText
        end

        card:SetPoint("TOPLEFT",  cardTitle, "TOPLEFT",  -8, 8)
        card:SetPoint("RIGHT",    pinsScrollContent, "RIGHT", 0, 0)
        card:SetPoint("BOTTOM",   prev, "BOTTOM", 0, -10)

        pinCards[#pinCards + 1] = card
        prevCard = card
    end

    local function UpdatePinsScrollHeight()
        local top    = pinsScrollContent:GetTop()
        local bottom = prevCard and prevCard:GetBottom()
        if top and bottom and top > bottom then
            pinsScrollContent:SetHeight((top - bottom) + 20)
        end
        pinsScrollObj.UpdateThumb()
    end

    CreatePinCard(L["UI_HELP_PIN_REGULAR_TITLE"], {
        L["UI_HELP_PIN_REGULAR_LINE1"],
        L["UI_HELP_PIN_REGULAR_LINE2"],
        L["UI_HELP_PIN_REGULAR_LINE3"],
    })
    CreatePinCard(L["UI_HELP_PIN_DAILY_TITLE"], {
        L["UI_HELP_PIN_DAILY_LINE1"],
        L["UI_HELP_PIN_DAILY_LINE2"],
        L["UI_HELP_PIN_DAILY_LINE3"],
    })
    CreatePinCard(L["UI_HELP_PIN_ZONE_TITLE"], {
        L["UI_HELP_PIN_ZONE_LINE1"],
        L["UI_HELP_PIN_ZONE_LINE2"],
        L["UI_HELP_PIN_ZONE_LINE3"],
        L["UI_HELP_PIN_ZONE_LINE4"],
    })

    pinsScrollContent:HookScript("OnSizeChanged", UpdatePinsScrollHeight)
    pinsContent:HookScript("OnShow", function() C_Timer.After(0, UpdatePinsScrollHeight) end)
    UpdatePinsScrollHeight()

    return helpPanel
end
