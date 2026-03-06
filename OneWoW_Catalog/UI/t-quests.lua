-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-quests.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedQuest    = nil
local questListButtons = {}
local detailElements   = {}
local searchText       = ""
local expansionFilter  = -1
local zoneFilter       = ""
local typeFilter       = "all"
local questTypeFilter  = "all"

local dataAddon            = nil
local PopulateZoneDropdown = nil

local function GetDataAddon()
    if dataAddon then return dataAddon end
    if ns.Catalog and ns.Catalog.GetDataAddon then
        dataAddon = ns.Catalog:GetDataAddon("quests")
    end
    return dataAddon
end

local function ClearDetailElements()
    for _, element in ipairs(detailElements) do
        if element.Hide then element:Hide() end
        if element.SetParent then element:SetParent(nil) end
    end
    wipe(detailElements)
end

local function ClearQuestList()
    for _, btn in ipairs(questListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(questListButtons)
end

local activeMenus = {}

local function HideAllMenus()
    for _, menu in ipairs(activeMenus) do
        if menu and menu:IsShown() then menu:Hide() end
    end
    wipe(activeMenus)
end

local function CreateThemedDropdown(parent, width, defaultText)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, 26)
    dropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(T("BG_TERTIARY"))
    dropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    dropdown.label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.label:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    dropdown.label:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
    dropdown.label:SetJustifyH("LEFT")
    dropdown.label:SetWordWrap(false)
    dropdown.label:SetText(defaultText)
    dropdown.label:SetTextColor(T("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    return dropdown
end

local function ShowDropdownMenu(dropdown, items, onSelect)
    HideAllMenus()

    local itemHeight = 24
    local padding    = 6
    local menuHeight = (#items * itemHeight) + (padding * 2)
    local menuWidth  = dropdown:GetWidth()
    if menuWidth < 160 then menuWidth = 160 end

    local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetSize(menuWidth, menuHeight)
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    menu:EnableMouse(true)

    table.insert(activeMenus, menu)

    local yPos = -padding
    for _, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetSize(menuWidth - 4, itemHeight)
        btn:SetPoint("TOP", menu, "TOP", 0, yPos)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        btn:SetBackdropColor(0, 0, 0, 0)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        text:SetText(item.text)

        if item.checked then
            text:SetTextColor(T("ACCENT_HIGHLIGHT"))
        else
            text:SetTextColor(T("TEXT_PRIMARY"))
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            text:SetTextColor(T("TEXT_ACCENT"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
            if item.checked then
                text:SetTextColor(T("ACCENT_HIGHLIGHT"))
            else
                text:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnClick", function()
            menu:Hide()
            if onSelect then onSelect(item.value, item.text) end
        end)

        yPos = yPos - itemHeight
    end

    local timeOutside = 0
    menu:SetScript("OnUpdate", function(self, elapsed)
        if not MouseIsOver(menu) and not MouseIsOver(dropdown) then
            timeOutside = timeOutside + elapsed
            if timeOutside > 0.5 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        else
            timeOutside = 0
        end
    end)
end

local function GetQuestTypeLabel(quest)
    if not quest then return L["QUESTS_TYPE_NORMAL"] end
    if quest.isDaily   then return L["QUESTS_TYPE_DAILY"]   end
    if quest.isWeekly  then return L["QUESTS_TYPE_WEEKLY"]  end
    if quest.isCampaign then return L["QUESTS_TYPE_CAMPAIGN"] end
    if quest.isWorldQuest then return L["QUESTS_TYPE_WORLDQUEST"] end
    local cls = quest.classification
    if cls == 1 then return L["QUESTS_TYPE_LEGENDARY"] end
    if cls == 5 then return L["QUESTS_TYPE_REPEATABLE"] end
    return L["QUESTS_TYPE_NORMAL"]
end

local function GetGroupTypeLabel(quest)
    if not quest then return L["QUESTS_TYPE_SOLO"] end
    local sg = quest.suggestedGroup or 0
    if sg >= 10 then return L["QUESTS_TYPE_RAID"]  end
    if sg >= 2  then return L["QUESTS_TYPE_GROUP"] end
    return L["QUESTS_TYPE_SOLO"]
end

local function CreateSeparatorLine(parent, yOffset, padLeft, padRight)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  padLeft or 8,   yOffset)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(padRight or 8), yOffset)
    sep:SetColorTexture(T("BORDER_SUBTLE"))
    return sep
end

local function CreateLabel(parent, text, font, yOffset, xLeft, textColor)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xLeft or 10, yOffset)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    if textColor then
        fs:SetTextColor(unpack(textColor))
    else
        fs:SetTextColor(T("TEXT_PRIMARY"))
    end
    return fs
end

local function ShowQuestDetail(panels, questData)
    selectedQuest = questData
    ClearDetailElements()

    if not questData then
        if panels.emptyDetail then
            panels.emptyDetail:SetText(L["QUESTS_SELECT"])
            panels.emptyDetail:Show()
        end
        panels.detailScrollChild:SetHeight(100)
        return
    end

    if panels.emptyDetail then panels.emptyDetail:Hide() end

    local parent  = panels.detailScrollChild
    local addon   = GetDataAddon()
    local tracker = addon and addon.CompletionTracker

    -- Defer if parent not yet laid out
    local contentWidth = parent:GetWidth()
    if contentWidth < 50 then
        C_Timer.After(0.05, function()
            if selectedQuest == questData then
                ShowQuestDetail(panels, questData)
            end
        end)
        return
    end

    -- Enrich sparse quest data with live API calls
    if addon and addon.QuestData then
        if not questData.mapID then
            local liveMapID = GetQuestUiMapID(questData.id)
            if liveMapID and liveMapID ~= 0 then
                local mapInfo = C_Map.GetMapInfo(liveMapID)
                questData.mapID    = liveMapID
                questData.zoneName = mapInfo and mapInfo.name or questData.zoneName
                addon.QuestData:StoreQuestInfo(questData.id, { mapID = liveMapID, zoneName = questData.zoneName })
            end
        end
        if not questData.classification and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
            local cls = C_QuestInfoSystem.GetQuestClassification(questData.id)
            if cls then
                questData.classification = cls
                addon.QuestData:StoreQuestInfo(questData.id, { classification = cls })
            end
        end
        if not questData.tagName then
            local tagInfo = C_QuestLog.GetQuestTagInfo(questData.id)
            if tagInfo and tagInfo.tagName then
                questData.tagName = tagInfo.tagName
                questData.isElite = tagInfo.isElite
                addon.QuestData:StoreQuestInfo(questData.id, { tagName = tagInfo.tagName, isElite = tagInfo.isElite })
            end
        end
    end

    local yOffset = -12
    local PAD     = 10
    local W       = contentWidth - PAD * 2

    local function track(elem)
        table.insert(detailElements, elem)
        return elem
    end

    local function addSep()
        local sep = CreateSeparatorLine(parent, yOffset - 6)
        track(sep)
        yOffset = yOffset - 20
    end

    local function addVSpace(h)
        yOffset = yOffset - (h or 8)
    end

    local function addWrappedText(text, font, color)
        local fs = track(parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal"))
        fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, yOffset)
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        fs:SetWidth(W)
        if color then fs:SetTextColor(unpack(color)) else fs:SetTextColor(T("TEXT_PRIMARY")) end
        yOffset = yOffset - fs:GetStringHeight() - 8
        return fs
    end

    -- Quest Name
    addWrappedText(
        questData.name or string.format(L["QUESTS_UNNAMED"], questData.id or 0),
        "GameFontNormalLarge",
        { T("ACCENT_HIGHLIGHT") }
    )

    -- Meta row
    local expName  = (questData.expansion ~= nil) and addon.QuestData:GetExpansionName(questData.expansion) or L["QUESTS_UNKNOWN"]
    local zoneName = questData.zoneName or L["QUESTS_UNKNOWN"]
    local typeName = GetQuestTypeLabel(questData)
    local grpName  = GetGroupTypeLabel(questData)
    local mapID    = questData.mapID or 0
    local questID  = questData.id or 0

    local metaStr = string.format(
        "%s: %s  |  %s: %s  |  %s: %s  |  %s: %s  |  %s: %d  |  %s: %d",
        L["QUESTS_EXPANSION"], expName,
        L["QUESTS_ZONE"], zoneName,
        L["QUESTS_TYPE_LABEL"], typeName,
        L["QUESTS_GROUP_TYPE"], grpName,
        L["QUESTS_QUESTID"], questID,
        L["QUESTS_MAPID"], mapID
    )
    yOffset = yOffset + 8
    addWrappedText(metaStr, "GameFontNormalSmall", { T("TEXT_SECONDARY") })

    addSep()

    -- Description
    if questData.description and questData.description ~= "" then
        addWrappedText(questData.description, "GameFontNormal")

        if questData.objectivesText and questData.objectivesText ~= "" then
            local objLabel = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
            objLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
            objLabel:SetText(L["QUESTS_OBJECTIVES"])
            objLabel:SetTextColor(T("TEXT_SECONDARY"))
            yOffset = yOffset - 16

            local objFs = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            objFs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD + 8, yOffset)
            objFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
            objFs:SetJustifyH("LEFT")
            objFs:SetWordWrap(true)
            objFs:SetText(questData.objectivesText)
            objFs:SetWidth(W - 8)
            objFs:SetTextColor(T("TEXT_MUTED"))
            yOffset = yOffset - objFs:GetStringHeight() - 8
        end
    else
        local noDescFs = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        noDescFs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, yOffset)
        noDescFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
        noDescFs:SetJustifyH("LEFT")
        noDescFs:SetWordWrap(true)
        noDescFs:SetText(L["QUESTS_NO_DESCRIPTION"])
        noDescFs:SetWidth(W)
        noDescFs:SetTextColor(T("TEXT_MUTED"))
        yOffset = yOffset - noDescFs:GetStringHeight() - 8
    end

    -- Rewards section
    local hasRewards = (questData.rewardGold and questData.rewardGold > 0)
        or (questData.rewardXP and questData.rewardXP > 0)
        or (questData.rewardItems and #questData.rewardItems > 0)

    if hasRewards then
        addSep()

        local rwdLabel = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        rwdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        rwdLabel:SetText(L["QUESTS_REWARDS"])
        rwdLabel:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - 18

        if questData.rewardGold and questData.rewardGold > 0 then
            local goldText = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            goldText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            goldText:SetText(L["QUESTS_GOLD"] .. ": " .. addon.QuestData:FormatGold(questData.rewardGold))
            goldText:SetTextColor(1, 0.82, 0, 1)
            yOffset = yOffset - 18
        end

        if questData.rewardXP and questData.rewardXP > 0 then
            local xpText = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            xpText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            xpText:SetText(L["QUESTS_XP"] .. ": " .. addon.QuestData:FormatNumber(questData.rewardXP))
            xpText:SetTextColor(T("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardItems and #questData.rewardItems > 0 then
            local itemHdr = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
            itemHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            itemHdr:SetText(L["QUESTS_ITEMS"] .. ":")
            itemHdr:SetTextColor(T("TEXT_SECONDARY"))
            yOffset = yOffset - 18

            for _, item in ipairs(questData.rewardItems) do
                local itemName = item.name or string.format(L["QUESTS_ITEM_UNNAMED"], item.itemID or 0)
                local countStr = (item.count and item.count > 1) and (" x" .. item.count) or ""
                local itemLine = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
                itemLine:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                itemLine:SetText(itemName .. countStr)
                itemLine:SetTextColor(T("TEXT_PRIMARY"))
                yOffset = yOffset - 18
            end
        end

        addVSpace(4)
    end

    -- Completion section
    addSep()

    local compLabel = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
    compLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    compLabel:SetText(L["QUESTS_COMPLETION"])
    compLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - 18

    local completedChars = tracker and tracker:GetCompletedCharacters(questData.id) or {}

    if #completedChars == 0 then
        local noCharText = track(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        noCharText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
        noCharText:SetText(L["QUESTS_NOT_COMPLETED"])
        noCharText:SetTextColor(T("TEXT_MUTED"))
        yOffset = yOffset - 18
    else
        for _, charInfo in ipairs(completedChars) do
            local rowFrame = track(CreateFrame("Frame", nil, parent))
            rowFrame:SetHeight(18)
            rowFrame:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD + 8, yOffset)
            rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)

            local checkTex = rowFrame:CreateTexture(nil, "ARTWORK")
            checkTex:SetSize(14, 14)
            checkTex:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
            checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            checkTex:SetVertexColor(0.2, 1, 0.2, 1)

            local charText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            charText:SetPoint("LEFT", checkTex, "RIGHT", 4, 0)
            charText:SetText(charInfo.name)
            charText:SetTextColor(0.2, 1, 0.2, 1)

            yOffset = yOffset - 20
        end
    end

    addVSpace(4)
    panels.detailScrollChild:SetHeight(math.abs(yOffset) + 20)
end

local function CreateQuestListEntry(parent, quest, yOffset, onClick)
    local addon   = GetDataAddon()
    local tracker = addon and addon.CompletionTracker

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(44)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  4, yOffset)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(T("BG_SECONDARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    btn.quest = quest

    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT",  btn, "TOPLEFT",  8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -26, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(quest.name or string.format(L["QUESTS_UNNAMED"], quest.id or 0))
    nameText:SetTextColor(T("TEXT_PRIMARY"))
    btn.nameText = nameText

    local expShort = ""
    if quest.expansion ~= nil and addon then
        expShort = addon.QuestData:GetExpansionShortName(quest.expansion) or ""
    end

    local subText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subText:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  8, 6)
    subText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -26, 6)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    subText:SetText(expShort)
    subText:SetTextColor(T("TEXT_MUTED"))

    local isCompleted = tracker and tracker:IsCompletedByCurrentChar(quest.id)
    if isCompleted then
        local checkTex = btn:CreateTexture(nil, "ARTWORK")
        checkTex:SetSize(14, 14)
        checkTex:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkTex:SetVertexColor(0.2, 1, 0.2, 1)
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        nameText:SetTextColor(T("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        if selectedQuest and selectedQuest.id == quest.id then
            self:SetBackdropColor(T("BG_ACTIVE"))
            nameText:SetTextColor(T("TEXT_ACCENT"))
        else
            self:SetBackdropColor(T("BG_SECONDARY"))
            nameText:SetTextColor(T("TEXT_PRIMARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        if onClick then onClick(quest, self) end
    end)

    return btn
end

local function RefreshQuestList(panels)
    ClearQuestList()

    local addon = GetDataAddon()
    if not addon or not addon.QuestData then
        if panels.emptyList then
            panels.emptyList:SetText(L["QUESTS_NO_DATA"])
            panels.emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        return
    end

    local quests = addon.QuestData:GetSortedQuests(
        expansionFilter,
        zoneFilter,
        typeFilter,
        questTypeFilter,
        searchText
    )

    if #quests == 0 then
        if panels.emptyList then
            panels.emptyList:SetText(
                (addon.QuestData:GetCapturedQuestCount() == 0)
                and L["QUESTS_NONE_YET"]
                or  L["QUESTS_EMPTY"]
            )
            panels.emptyList:Show()
        end
        panels.listScrollChild:SetHeight(100)
        if panels.leftStatusText then
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], 0))
        end
        return
    end

    if panels.emptyList then panels.emptyList:Hide() end

    local yOffset = -4
    for _, quest in ipairs(quests) do
        local btn = CreateQuestListEntry(panels.listScrollChild, quest, yOffset, function(q, clickedBtn)
            for _, b in ipairs(questListButtons) do
                b:SetBackdropColor(T("BG_SECONDARY"))
                if b.nameText then b.nameText:SetTextColor(T("TEXT_PRIMARY")) end
            end
            clickedBtn:SetBackdropColor(T("BG_ACTIVE"))
            ShowQuestDetail(panels, q)
        end)
        table.insert(questListButtons, btn)
        yOffset = yOffset - 48
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)

    if panels.leftStatusText then
        panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], #quests))
    end

    if selectedQuest then
        ShowQuestDetail(panels, addon.QuestData:GetQuest(selectedQuest.id))
    end
end

local function PopulateExpansionDropdown(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return end

    local items = { { value = -1, text = L["QUESTS_EXPANSION_ALL"], checked = (expansionFilter == -1) } }
    local expansions = addon.QuestData:GetAvailableExpansions()
    for _, exp in ipairs(expansions) do
        table.insert(items, {
            value   = exp.id,
            text    = exp.name,
            checked = (expansionFilter == exp.id),
        })
    end

    panels.expDropdown:SetScript("OnClick", function(self)
        ShowDropdownMenu(self, items, function(value, text)
            expansionFilter = value
            self.label:SetText(value == -1 and L["QUESTS_EXPANSION_ALL"] or text)
            zoneFilter = ""
            panels.zoneDropdown.label:SetText(L["QUESTS_ZONE_ALL"])
            PopulateZoneDropdown(panels)
            RefreshQuestList(panels)
        end)
    end)
end

PopulateZoneDropdown = function(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return end

    local zones = addon.QuestData:GetAvailableZones(expansionFilter ~= -1 and expansionFilter or nil)
    local items = { { value = "", text = L["QUESTS_ZONE_ALL"], checked = (zoneFilter == "") } }
    for _, zoneName in ipairs(zones) do
        table.insert(items, {
            value   = zoneName,
            text    = zoneName,
            checked = (zoneFilter == zoneName),
        })
    end

    panels.zoneDropdown:SetScript("OnClick", function(self)
        ShowDropdownMenu(self, items, function(value, text)
            zoneFilter = value
            self.label:SetText(value == "" and L["QUESTS_ZONE_ALL"] or text)
            RefreshQuestList(panels)
        end)
    end)
end

local function SetupTypeDropdown(panels)
    local items = {
        { value = "all",   text = L["QUESTS_TYPE_ALL"],  checked = (typeFilter == "all")   },
        { value = "solo",  text = L["QUESTS_TYPE_SOLO"], checked = (typeFilter == "solo")  },
        { value = "group", text = L["QUESTS_TYPE_GROUP"],checked = (typeFilter == "group") },
        { value = "raid",  text = L["QUESTS_TYPE_RAID"], checked = (typeFilter == "raid")  },
    }
    panels.typeDropdown:SetScript("OnClick", function(self)
        ShowDropdownMenu(self, items, function(value, text)
            typeFilter = value
            self.label:SetText(value == "all" and L["QUESTS_TYPE_ALL"] or text)
            for _, item in ipairs(items) do item.checked = (item.value == value) end
            RefreshQuestList(panels)
        end)
    end)
end

local function SetupQuestTypeDropdown(panels)
    local items = {
        { value = "all",        text = L["QUESTS_QTYPE_ALL"],           checked = (questTypeFilter == "all")        },
        { value = "normal",     text = L["QUESTS_TYPE_NORMAL"],         checked = (questTypeFilter == "normal")     },
        { value = "daily",      text = L["QUESTS_TYPE_DAILY"],          checked = (questTypeFilter == "daily")      },
        { value = "weekly",     text = L["QUESTS_TYPE_WEEKLY"],         checked = (questTypeFilter == "weekly")     },
        { value = "campaign",   text = L["QUESTS_TYPE_CAMPAIGN"],       checked = (questTypeFilter == "campaign")   },
        { value = "worldquest", text = L["QUESTS_TYPE_WORLDQUEST"],     checked = (questTypeFilter == "worldquest") },
    }
    panels.qTypeDropdown:SetScript("OnClick", function(self)
        ShowDropdownMenu(self, items, function(value, text)
            questTypeFilter = value
            self.label:SetText(value == "all" and L["QUESTS_QTYPE_ALL"] or text)
            for _, item in ipairs(items) do item.checked = (item.value == value) end
            RefreshQuestList(panels)
        end)
    end)
end

local panels_ref = nil

function ns.UI.CreateQuestsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42

    local leftHeader = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftHeader:SetHeight(HDR_H)
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)
    leftHeader:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    leftHeader:SetBackdropColor(T("BG_TERTIARY"))
    leftHeader:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local rightHeader = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightHeader:SetHeight(HDR_H)
    rightHeader:SetPoint("TOPLEFT",  leftHeader,  "TOPRIGHT",  GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent,      "TOPRIGHT",  0, 0)
    rightHeader:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rightHeader:SetBackdropColor(T("BG_TERTIARY"))
    rightHeader:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT",     leftHeader, "BOTTOMLEFT",  0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent,     "BOTTOMRIGHT", 0, 0)

    local panels = ns.UI.CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["QUESTS_LIST_TITLE"])
    panels.detailTitle:SetText(L["QUESTS_DETAIL_TITLE"])

    -- LEFT HEADER: Search + Clear
    local searchBox = CreateFrame("EditBox", nil, leftHeader, "BackdropTemplate")
    searchBox:SetHeight(26)
    searchBox:SetPoint("TOPLEFT",  leftHeader, "TOPLEFT",  8, -8)
    searchBox:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -42, -8)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(T("BG_SECONDARY"))
    searchBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    searchBox:SetFontObject(GameFontNormal)
    searchBox:SetTextColor(T("TEXT_PRIMARY"))
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    placeholder:SetText(L["QUESTS_SEARCH"])
    placeholder:SetTextColor(T("TEXT_MUTED"))

    local clearBtn = CreateFrame("Button", nil, leftHeader, "BackdropTemplate")
    clearBtn:SetSize(34, 26)
    clearBtn:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 4, 0)
    clearBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    clearBtn:SetBackdropColor(T("BG_SECONDARY"))
    clearBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    local clearBtnText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearBtnText:SetPoint("CENTER")
    clearBtnText:SetText(L["QUESTS_CLEAR"])
    clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    clearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
        clearBtnText:SetTextColor(T("TEXT_ACCENT"))
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        clearBtnText:SetTextColor(T("TEXT_PRIMARY"))
    end)

    -- RIGHT HEADER: 4 dropdowns
    local DD_GAP = 4
    local DD_PAD = 8

    local expDropdown   = CreateThemedDropdown(rightHeader, 10, L["QUESTS_EXPANSION_ALL"])
    local zoneDropdown  = CreateThemedDropdown(rightHeader, 10, L["QUESTS_ZONE_ALL"])
    local typeDropdown  = CreateThemedDropdown(rightHeader, 10, L["QUESTS_TYPE_ALL"])
    local qTypeDropdown = CreateThemedDropdown(rightHeader, 10, L["QUESTS_QTYPE_ALL"])

    local function LayoutFilterDropdowns(w)
        local ddW = math.floor((w - (DD_PAD * 2) - (DD_GAP * 3)) / 4)
        expDropdown:ClearAllPoints()
        expDropdown:SetSize(ddW, 26)
        expDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD, -8)

        zoneDropdown:ClearAllPoints()
        zoneDropdown:SetSize(ddW, 26)
        zoneDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP), -8)

        typeDropdown:ClearAllPoints()
        typeDropdown:SetSize(ddW, 26)
        typeDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP) * 2, -8)

        qTypeDropdown:ClearAllPoints()
        qTypeDropdown:SetSize(ddW, 26)
        qTypeDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP) * 3, -8)
    end

    rightHeader:SetScript("OnSizeChanged", function(self, w)
        LayoutFilterDropdowns(w)
    end)

    C_Timer.After(0, function()
        local w = rightHeader:GetWidth()
        if w and w > 0 then LayoutFilterDropdowns(w) end
    end)

    -- Empty state labels
    local emptyList = panels.listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(T("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = panels.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(T("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    panels.expDropdown   = expDropdown
    panels.zoneDropdown  = zoneDropdown
    panels.typeDropdown  = typeDropdown
    panels.qTypeDropdown = qTypeDropdown
    panels.searchBox     = searchBox
    panels.placeholder   = placeholder

    ns.UI.questsPanels = panels
    panels_ref = panels

    emptyList:SetText(L["QUESTS_EMPTY"])
    emptyDetail:SetText(L["QUESTS_SELECT"])
    panels.listScrollChild:SetHeight(100)
    panels.detailScrollChild:SetHeight(100)

    clearBtn:SetScript("OnClick", function()
        searchText      = ""
        expansionFilter = -1
        zoneFilter      = ""
        typeFilter      = "all"
        questTypeFilter = "all"
        searchBox:SetText("")
        placeholder:Show()
        expDropdown.label:SetText(L["QUESTS_EXPANSION_ALL"])
        zoneDropdown.label:SetText(L["QUESTS_ZONE_ALL"])
        typeDropdown.label:SetText(L["QUESTS_TYPE_ALL"])
        qTypeDropdown.label:SetText(L["QUESTS_QTYPE_ALL"])
        RefreshQuestList(panels)
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            placeholder:Hide()
        else
            placeholder:Show()
        end
        searchText = text or ""
        if panels._searchTimer then
            panels._searchTimer:Cancel()
        end
        panels._searchTimer = C_Timer.NewTimer(0.3, function()
            RefreshQuestList(panels)
        end)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    C_Timer.After(0.5, function()
        PopulateExpansionDropdown(panels)
        PopulateZoneDropdown(panels)
        SetupTypeDropdown(panels)
        SetupQuestTypeDropdown(panels)
        RefreshQuestList(panels)
    end)
end
