-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-quests.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local selectedQuest    = nil
local questListButtons = {}
local detailElements   = {}
local searchText       = ""
local expansionFilter  = -1
local zoneFilter       = ""
local typeFilter       = "all"
local questTypeFilter  = "all"
local completionFilter = "all"

local dataAddon            = nil
local PopulateZoneDropdown = nil
local RefreshQuestList

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

local function CreateSeparatorLine(parent, yOffset)
    return OneWoW_GUI:CreateDivider(parent, { yOffset = yOffset })
end

local function CreateLabel(parent, text, fontSize, yOffset, xLeft, textColor)
    local fs = OneWoW_GUI:CreateFS(parent, fontSize or 10)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xLeft or 10, yOffset)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    if textColor then
        fs:SetTextColor(unpack(textColor))
    else
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    local contentWidth = parent:GetWidth()
    if contentWidth < 50 then
        C_Timer.After(0.05, function()
            if selectedQuest == questData then
                ShowQuestDetail(panels, questData)
            end
        end)
        return
    end

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

    local function addWrappedText(text, fontSize, color)
        local fs = track(OneWoW_GUI:CreateFS(parent, fontSize or 12))
        fs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, yOffset)
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        fs:SetWidth(W)
        if color then fs:SetTextColor(unpack(color)) else fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
        yOffset = yOffset - fs:GetStringHeight() - 8
        return fs
    end

    addWrappedText(
        questData.name or string.format(L["QUESTS_UNNAMED"], questData.id or 0),
        16,
        { OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT") }
    )

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
    addWrappedText(metaStr, 10, { OneWoW_GUI:GetThemeColor("TEXT_SECONDARY") })

    addSep()

    if questData.description and questData.description ~= "" then
        addWrappedText(questData.description, 12)

        if questData.objectivesText and questData.objectivesText ~= "" then
            local objLabel = track(OneWoW_GUI:CreateFS(parent, 10))
            objLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
            objLabel:SetText(L["QUESTS_OBJECTIVES"])
            objLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            yOffset = yOffset - 16

            local objFs = track(OneWoW_GUI:CreateFS(parent, 12))
            objFs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD + 8, yOffset)
            objFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
            objFs:SetJustifyH("LEFT")
            objFs:SetWordWrap(true)
            objFs:SetText(questData.objectivesText)
            objFs:SetWidth(W - 8)
            objFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            yOffset = yOffset - objFs:GetStringHeight() - 8
        end
    else
        local noDescFs = track(OneWoW_GUI:CreateFS(parent, 12))
        noDescFs:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, yOffset)
        noDescFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
        noDescFs:SetJustifyH("LEFT")
        noDescFs:SetWordWrap(true)
        noDescFs:SetText(L["QUESTS_NO_DESCRIPTION"])
        noDescFs:SetWidth(W)
        noDescFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yOffset = yOffset - noDescFs:GetStringHeight() - 8
    end

    local hasRewards = (questData.rewardGold and questData.rewardGold > 0)
        or (questData.rewardXP and questData.rewardXP > 0)
        or (questData.rewardItems and #questData.rewardItems > 0)

    if hasRewards then
        addSep()

        local rwdLabel = track(OneWoW_GUI:CreateFS(parent, 10))
        rwdLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        rwdLabel:SetText(L["QUESTS_REWARDS"])
        rwdLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - 18

        if questData.rewardGold and questData.rewardGold > 0 then
            local goldText = track(OneWoW_GUI:CreateFS(parent, 12))
            goldText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            goldText:SetText(L["QUESTS_GOLD"] .. ": " .. addon.QuestData:FormatGold(questData.rewardGold))
            goldText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardXP and questData.rewardXP > 0 then
            local xpText = track(OneWoW_GUI:CreateFS(parent, 12))
            xpText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            xpText:SetText(L["QUESTS_XP"] .. ": " .. addon.QuestData:FormatNumber(questData.rewardXP))
            xpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardItems and #questData.rewardItems > 0 then
            local itemHdr = track(OneWoW_GUI:CreateFS(parent, 10))
            itemHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            itemHdr:SetText(L["QUESTS_ITEMS"] .. ":")
            itemHdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            yOffset = yOffset - 18

            for _, item in ipairs(questData.rewardItems) do
                local itemName = item.name or string.format(L["QUESTS_ITEM_UNNAMED"], item.itemID or 0)
                local countStr = (item.count and item.count > 1) and (" x" .. item.count) or ""
                local itemLine = track(OneWoW_GUI:CreateFS(parent, 12))
                itemLine:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 16, yOffset)
                itemLine:SetText(itemName .. countStr)
                itemLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                yOffset = yOffset - 18
            end
        end

        addVSpace(4)
    end

    addSep()

    local compLabel = track(OneWoW_GUI:CreateFS(parent, 10))
    compLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
    compLabel:SetText(L["QUESTS_COMPLETION"])
    compLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - 18

    local completedChars = tracker and tracker:GetCompletedCharacters(questData.id) or {}

    if #completedChars == 0 then
        local noCharText = track(OneWoW_GUI:CreateFS(parent, 12))
        noCharText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
        noCharText:SetText(L["QUESTS_NOT_COMPLETED"])
        noCharText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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
            checkTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

            local charText = OneWoW_GUI:CreateFS(rowFrame, 12)
            charText:SetPoint("LEFT", checkTex, "RIGHT", 4, 0)
            charText:SetText(charInfo.name)
            charText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

            yOffset = yOffset - 20
        end
    end

    addVSpace(4)
    panels.detailScrollChild:SetHeight(math.abs(yOffset) + 20)
end

local function CreateQuestListEntry(parent, quest, yOffset, panels, onClick)
    local addon   = GetDataAddon()
    local tracker = addon and addon.CompletionTracker

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(44)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  4, yOffset)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    btn.quest = quest

    local nameText = OneWoW_GUI:CreateFS(btn, 12)
    nameText:SetPoint("TOPLEFT",  btn, "TOPLEFT",  8, -6)
    nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -44, -6)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(quest.name or string.format(L["QUESTS_UNNAMED"], quest.id or 0))
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    btn.nameText = nameText

    local expShort = ""
    if quest.expansion ~= nil and addon then
        expShort = addon.QuestData:GetExpansionShortName(quest.expansion) or ""
    end

    local subText = OneWoW_GUI:CreateFS(btn, 10)
    subText:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  8, 6)
    subText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -44, 6)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    subText:SetText(expShort)
    subText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local isCompleted = tracker and tracker:IsCompletedByCurrentChar(quest.id)
    if isCompleted then
        local checkTex = btn:CreateTexture(nil, "ARTWORK")
        checkTex:SetSize(14, 14)
        checkTex:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
        checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    end

    if ns.Favorites then
        local favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
            size     = 18,
            favorite = ns.Favorites:IsFavorite("quests", quest.id),
            tooltipTitle = L["CATALOG_FAVORITE"],
            tooltipText  = L["CATALOG_FAVORITE_TT"],
            onClick = function(_, on)
                ns.Favorites:SetFavorite("quests", quest.id, on)
                RefreshQuestList(panels)
            end,
        })
        favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -6)
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        if selectedQuest and selectedQuest.id == quest.id then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)
    btn:SetScript("OnClick", function(self)
        if onClick then onClick(quest, self) end
    end)

    return btn
end

function RefreshQuestList(panels)
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

    if completionFilter ~= "all" then
        local filtered = {}
        for _, quest in ipairs(quests) do
            if completionFilter == "completed" then
                if C_QuestLog.IsQuestFlaggedCompleted(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "not_completed" then
                if not C_QuestLog.IsQuestFlaggedCompleted(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "active" then
                if C_QuestLog.IsOnQuest(quest.id) then table.insert(filtered, quest) end
            elseif completionFilter == "warband" then
                if C_QuestLog.IsQuestFlaggedCompletedOnAccount(quest.id) then table.insert(filtered, quest) end
            end
        end
        quests = filtered
    end

    if ns.Favorites and #quests > 0 then
        local origOrder = {}
        for i, q in ipairs(quests) do
            origOrder[q.id] = i
        end
        table.sort(quests, function(a, b)
            local fa = ns.Favorites:IsFavorite("quests", a.id)
            local fb = ns.Favorites:IsFavorite("quests", b.id)
            if fa ~= fb then return fa end
            return (origOrder[a.id] or 0) < (origOrder[b.id] or 0)
        end)
    end

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
        local btn = CreateQuestListEntry(panels.listScrollChild, quest, yOffset, panels, function(q, clickedBtn)
            for _, b in ipairs(questListButtons) do
                b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                if b.nameText then b.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
            end
            clickedBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
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

    OneWoW_GUI:AttachFilterMenu(panels.expDropdown, {
        searchable = false,
        getActiveValue = function() return expansionFilter end,
        buildItems = function()
            local items = { { value = -1, text = L["QUESTS_EXPANSION_ALL"] } }
            local expansions = addon.QuestData:GetAvailableExpansions()
            for _, exp in ipairs(expansions) do
                table.insert(items, {
                    value   = exp.id,
                    text    = exp.name,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            expansionFilter = value
            panels.expText:SetText(value == -1 and L["QUESTS_EXPANSION_ALL"] or text)
            zoneFilter = ""
            panels.zoneText:SetText(L["QUESTS_ZONE_ALL"])
            PopulateZoneDropdown(panels)
            RefreshQuestList(panels)
        end,
    })
end

PopulateZoneDropdown = function(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then return end

    OneWoW_GUI:AttachFilterMenu(panels.zoneDropdown, {
        searchable = true,
        getActiveValue = function() return zoneFilter end,
        buildItems = function()
            local zones = addon.QuestData:GetAvailableZones(expansionFilter ~= -1 and expansionFilter or nil)
            local items = { { value = "", text = L["QUESTS_ZONE_ALL"] } }
            for _, zoneName in ipairs(zones) do
                table.insert(items, {
                    value   = zoneName,
                    text    = zoneName,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            zoneFilter = value
            panels.zoneText:SetText(value == "" and L["QUESTS_ZONE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupTypeDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.typeDropdown, {
        searchable = false,
        getActiveValue = function() return typeFilter end,
        buildItems = function()
            return {
                { value = "all",   text = L["QUESTS_TYPE_ALL"]   },
                { value = "solo",  text = L["QUESTS_TYPE_SOLO"]  },
                { value = "group", text = L["QUESTS_TYPE_GROUP"] },
                { value = "raid",  text = L["QUESTS_TYPE_RAID"]  },
            }
        end,
        onSelect = function(value, text)
            typeFilter = value
            panels.typeText:SetText(value == "all" and L["QUESTS_TYPE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupQuestTypeDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.qTypeDropdown, {
        searchable = false,
        getActiveValue = function() return questTypeFilter end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_QTYPE_ALL"]       },
                { value = "normal",     text = L["QUESTS_TYPE_NORMAL"]     },
                { value = "daily",      text = L["QUESTS_TYPE_DAILY"]      },
                { value = "weekly",     text = L["QUESTS_TYPE_WEEKLY"]     },
                { value = "campaign",   text = L["QUESTS_TYPE_CAMPAIGN"]   },
                { value = "worldquest", text = L["QUESTS_TYPE_WORLDQUEST"] },
            }
        end,
        onSelect = function(value, text)
            questTypeFilter = value
            panels.qTypeText:SetText(value == "all" and L["QUESTS_QTYPE_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local function SetupProgressDropdown(panels)
    OneWoW_GUI:AttachFilterMenu(panels.progDropdown, {
        searchable = false,
        getActiveValue = function() return completionFilter end,
        buildItems = function()
            return {
                { value = "all",           text = L["QUESTS_PROGRESS_ALL"]           },
                { value = "completed",     text = L["QUESTS_PROGRESS_COMPLETED"]     },
                { value = "not_completed", text = L["QUESTS_PROGRESS_NOT_COMPLETED"] },
                { value = "active",        text = L["QUESTS_PROGRESS_ACTIVE"]        },
                { value = "warband",       text = L["QUESTS_PROGRESS_WARBAND"]       },
            }
        end,
        onSelect = function(value, text)
            completionFilter = value
            panels.progText:SetText(value == "all" and L["QUESTS_PROGRESS_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })
end

local panels_ref = nil

function ns.UI.CreateQuestsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP
    local HDR_H  = 42

    local leftHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    leftHeader:ClearAllPoints()
    leftHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    leftHeader:SetWidth(LEFT_W)

    local rightHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HDR_H, offset = 0 })
    rightHeader:ClearAllPoints()
    rightHeader:SetPoint("TOPLEFT", leftHeader, "TOPRIGHT", GAP, 0)
    rightHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT",     leftHeader, "BOTTOMLEFT",  0, -GAP)
    contentArea:SetPoint("BOTTOMRIGHT", parent,     "BOTTOMRIGHT", 0, 0)

    local panels = OneWoW_GUI:CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["QUESTS_LIST_TITLE"])
    panels.detailTitle:SetText(L["QUESTS_DETAIL_TITLE"])

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local searchBox = OneWoW_GUI:CreateEditBox(leftHeader, {
        height = 26,
        placeholderText = L["QUESTS_SEARCH"],
        onTextChanged = function(text)
            searchText = text
            if panels._searchTimer then panels._searchTimer:Cancel() end
            panels._searchTimer = C_Timer.NewTimer(0.3, function()
                RefreshQuestList(panels)
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", leftHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local DD_GAP = 4
    local DD_PAD = 8

    local expDropdown, expText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_EXPANSION_ALL"] })
    local zoneDropdown, zoneText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_ZONE_ALL"] })
    local typeDropdown, typeText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_TYPE_ALL"] })
    local qTypeDropdown, qTypeText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_QTYPE_ALL"] })
    local progDropdown, progText = OneWoW_GUI:CreateDropdown(rightHeader, { width = 10, text = L["QUESTS_PROGRESS_ALL"] })

    local function LayoutFilterDropdowns(w)
        local ddW = math.floor((w - (DD_PAD * 2) - (DD_GAP * 4)) / 5)
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

        progDropdown:ClearAllPoints()
        progDropdown:SetSize(ddW, 26)
        progDropdown:SetPoint("TOPLEFT", rightHeader, "TOPLEFT", DD_PAD + (ddW + DD_GAP) * 4, -8)
    end

    rightHeader:SetScript("OnSizeChanged", function(self, w)
        LayoutFilterDropdowns(w)
    end)

    C_Timer.After(0, function()
        local w = rightHeader:GetWidth()
        if w and w > 0 then LayoutFilterDropdowns(w) end
    end)

    local emptyList = OneWoW_GUI:CreateFS(panels.listScrollChild, 12)
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyList = emptyList

    local emptyDetail = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyDetail:SetPoint("CENTER", panels.detailPanel, "CENTER", 0, 0)
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.emptyDetail = emptyDetail

    panels.expDropdown   = expDropdown
    panels.expText       = expText
    panels.zoneDropdown  = zoneDropdown
    panels.zoneText      = zoneText
    panels.typeDropdown  = typeDropdown
    panels.typeText      = typeText
    panels.qTypeDropdown = qTypeDropdown
    panels.qTypeText     = qTypeText
    panels.progDropdown  = progDropdown
    panels.progText      = progText
    panels.searchBox     = searchBox

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
        completionFilter = "all"
        searchBox:SetText("")
        searchBox:ClearFocus()
        expText:SetText(L["QUESTS_EXPANSION_ALL"])
        zoneText:SetText(L["QUESTS_ZONE_ALL"])
        typeText:SetText(L["QUESTS_TYPE_ALL"])
        qTypeText:SetText(L["QUESTS_QTYPE_ALL"])
        progText:SetText(L["QUESTS_PROGRESS_ALL"])
        RefreshQuestList(panels)
    end)

    C_Timer.After(0.5, function()
        PopulateExpansionDropdown(panels)
        PopulateZoneDropdown(panels)
        SetupTypeDropdown(panels)
        SetupQuestTypeDropdown(panels)
        SetupProgressDropdown(panels)
        RefreshQuestList(panels)
    end)

    ns.UI.RefreshQuestsList = function()
        RefreshQuestList(panels)
    end
end
