local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local selectedQuest    = nil
local questResults     = {}
local questListAPI     = nil
local activePanels     = nil
local detailElements   = {}
local searchText       = ""
local expansionFilter  = -1
local zoneFilter       = ""
local typeFilter       = "all"
local questTypeFilter  = "all"
local completionFilter = "all"
local advCategory      = "all"
local advFlag          = "all"
local advFaction       = "all"
local advStory         = "all"
local advRuntime       = "all"
local advClass         = "all"
local advRace          = "all"
local advProfession    = "all"
local dataAddon        = nil
local ROW_HEIGHT       = 44
local npcNameCache     = {}
local detailNameRetryPending = false
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

local function IsGenericNPCName(name)
    return not name or name == "" or name:find("^NPC %d") ~= nil
end

-- Resolves a real creature name for an NPC ID. Priority: live-captured name,
-- then a saved Notes name, then a client tooltip lookup (the same unit-hyperlink
-- scan the Vendors data loader uses). Returns nil if still unknown; sets
-- detailNameRetryPending so the detail view can re-resolve shortly after the
-- client caches the name.
local function ResolveNPCName(npcID, knownName)
    if not IsGenericNPCName(knownName) then
        return knownName
    end

    if OneWoW_Notes then
        local note = OneWoW_Notes.NPCs:GetNPC(npcID)
        if note and not IsGenericNPCName(note.name) then
            return note.name
        end
    end

    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end

    local data = C_TooltipInfo.GetHyperlink(
        string.format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
    )
    if data and data.lines and data.lines[1] then
        local name = data.lines[1].leftText
        if name and name ~= "" and not name:find("Retrieving") then
            npcNameCache[npcID] = name
            return name
        end
    end

    -- The lookup above primes the client cache; ask the detail to re-resolve.
    detailNameRetryPending = true
    return nil
end

local function ShowQuestDetail(panels, questData)
    selectedQuest = questData
    ClearDetailElements()
    detailNameRetryPending = false

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
    if not addon then return end
    local tracker = addon.CompletionTracker

    local contentWidth = parent:GetWidth()
    if contentWidth < 50 then
        C_Timer.After(0.05, function()
            if selectedQuest == questData then
                ShowQuestDetail(panels, questData)
            end
        end)
        return
    end

    if addon.QuestData then
        if not questData.mapID then
            local liveMapID = GetQuestUiMapID(questData.id)
            if liveMapID and liveMapID ~= 0 then
                local mapInfo = C_Map.GetMapInfo(liveMapID)
                questData.mapID    = liveMapID
                questData.zoneName = mapInfo and mapInfo.name or questData.zoneName
                addon.QuestData:StoreQuestInfoQuiet(questData.id, { mapID = liveMapID, zoneName = questData.zoneName })
            end
        end
        if not questData.classification and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
            local cls = C_QuestInfoSystem.GetQuestClassification(questData.id)
            if cls then
                questData.classification = cls
                addon.QuestData:StoreQuestInfoQuiet(questData.id, { classification = cls })
            end
        end
        if not questData.tagName then
            local tagInfo = C_QuestLog.GetQuestTagInfo(questData.id)
            if tagInfo and tagInfo.tagName then
                questData.tagName = tagInfo.tagName
                questData.isElite = tagInfo.isElite
                addon.QuestData:StoreQuestInfoQuiet(questData.id, { tagName = tagInfo.tagName, isElite = tagInfo.isElite })
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

    local pinMapID = (questData.coords and questData.coords.mapID) or questData.mapID
    if pinMapID and pinMapID ~= 0 then
        local cx = questData.coords and questData.coords.x
        local cy = questData.coords and questData.coords.y
        local mapBtn = track(OneWoW_GUI:CreateFitTextButton(parent, { text = L["QUESTS_SHOW_ON_MAP"], height = 22 }))
        mapBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        mapBtn:SetScript("OnClick", function()
            ns.Navigation:OpenMapPin(pinMapID, cx, cy)
        end)
        yOffset = yOffset - 28
    end

    -- Quest giver / turn-in NPC. When Notes is installed these open (and add)
    -- the NPC in OneWoW_Notes; otherwise they show as plain text.
    local function AddNPCLink(labelText, npcID, npcName, npcMapID, npcCoords, npcZone)
        if type(npcID) ~= "number" then return end
        local resolved = ResolveNPCName(npcID, npcName)
        local displayName = resolved or string.format(L["QUESTS_NPC_UNNAMED"], npcID)

        if OneWoW_Notes then
            local hasNote = OneWoW_Notes.NPCs:GetNPC(npcID) ~= nil
            local suffix = hasNote and L["QUESTS_SEE_NOTE"] or L["QUESTS_MAKE_NOTE"]
            local btn = track(OneWoW_GUI:CreateFitTextButton(parent, {
                text = labelText .. ": " .. displayName .. " - " .. suffix,
                height = 20,
            }))
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
            btn:SetScript("OnClick", function()
                ns.Navigation:OpenNPC(npcID, { name = resolved or npcName, mapID = npcMapID, coords = npcCoords, zone = npcZone })
            end)
            yOffset = yOffset - 24
        else
            local fs = track(OneWoW_GUI:CreateFS(parent, 11))
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
            fs:SetText(labelText .. ": " .. displayName)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            yOffset = yOffset - 20
        end
    end

    local starts1 = questData.starts and questData.starts[1]
    local ends1   = questData.ends and questData.ends[1]

    local giverID     = questData.questGiverID or (starts1 and starts1.npcID)
    local giverName   = questData.questGiverName or (starts1 and (starts1.npcName or starts1.name))
    local giverCoords = (starts1 and starts1.x) and { x = starts1.x, y = starts1.y } or nil
    AddNPCLink(L["QUESTS_QUEST_GIVER"], giverID, giverName,
        (starts1 and starts1.mapID) or questData.mapID, giverCoords,
        (starts1 and starts1.zoneName) or questData.zoneName)

    local turnInID     = questData.questTurnInID or (ends1 and ends1.npcID)
    local turnInName   = questData.questTurnInName or (ends1 and (ends1.npcName or ends1.name))
    local turnInCoords = (ends1 and ends1.x) and { x = ends1.x, y = ends1.y } or nil
    AddNPCLink(L["QUESTS_TURN_IN"], turnInID, turnInName,
        (ends1 and ends1.mapID) or questData.mapID, turnInCoords,
        (ends1 and ends1.zoneName) or questData.zoneName)

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
            goldText:SetText(L["QUESTS_GOLD"] .. ": " .. OneWoW.Format.FormatGold(questData.rewardGold))
            goldText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardXP and questData.rewardXP > 0 then
            local xpText = track(OneWoW_GUI:CreateFS(parent, 12))
            xpText:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            xpText:SetText(L["QUESTS_XP"] .. ": " .. OneWoW.Format.FormatNumber(questData.rewardXP))
            xpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end

        if questData.rewardItems and #questData.rewardItems > 0 then
            local itemHdr = track(OneWoW_GUI:CreateFS(parent, 10))
            itemHdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            itemHdr:SetText(L["QUESTS_ITEMS"] .. ":")
            itemHdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            yOffset = yOffset - 20

            -- Reward items render as a wrapping grid of skinned icons. Hover for
            -- the tooltip; Ctrl-click previews equippable items in the dressing room.
            local ICON, ICON_GAP = 36, 4
            local startX = PAD + 16
            local perRow = math.max(1, math.floor((W - 16) / (ICON + ICON_GAP)))
            local col = 0

            for _, item in ipairs(questData.rewardItems) do
                -- Reward entries may be numeric item IDs (static DB) or tables.
                local itemID = (type(item) == "table") and (item.itemID or item.id) or item
                if itemID then
                    local iconObj = OneWoW_GUI:CreateItemIcon(parent, { size = ICON, itemID = itemID, showIlvl = false })
                    local iconFrame = track(iconObj.frame)
                    iconFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", startX + col * (ICON + ICON_GAP), yOffset)
                    iconFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(itemID)
                        if OneWoW_Notes then
                            local hasNote = OneWoW_Notes.Items:GetItem(itemID) ~= nil
                            local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
                            GameTooltip:AddLine(hasNote and L["QUESTS_TT_SEE_NOTE"] or L["QUESTS_TT_MAKE_NOTE"], r, g, b)
                        end
                        GameTooltip:Show()
                    end)
                    iconFrame:SetScript("OnLeave", GameTooltip_Hide)
                    iconFrame:SetScript("OnClick", function()
                        if IsControlKeyDown() then
                            ns.Navigation:OpenItemNote(itemID, { category = "Quest" })
                        end
                    end)

                    col = col + 1
                    if col >= perRow then
                        col = 0
                        yOffset = yOffset - (ICON + ICON_GAP)
                    end
                end
            end

            if col > 0 then
                yOffset = yOffset - (ICON + ICON_GAP)
            end
        end

        addVSpace(4)
    end

    -- Quest chain (storyline / series) as clickable links to related quests.
    local chainIDs, chainSeen = {}, {}
    local function collectChain(list)
        if not list then return end
        for _, qid in ipairs(list) do
            qid = tonumber(qid)
            if qid and qid ~= questData.id and not chainSeen[qid] then
                chainSeen[qid] = true
                chainIDs[#chainIDs + 1] = qid
            end
        end
    end
    collectChain(questData.storyline)
    collectChain(questData.series)

    if #chainIDs > 0 then
        addSep()

        local chainLabel = track(OneWoW_GUI:CreateFS(parent, 10))
        chainLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOffset)
        chainLabel:SetText(L["QUESTS_CHAIN"])
        chainLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - 18

        for _, qid in ipairs(chainIDs) do
            local linked = addon.QuestData:GetQuest(qid)
            local lname = (linked and linked.name) or string.format(L["QUESTS_UNNAMED"], qid)
            local linkBtn = track(OneWoW_GUI:CreateFitTextButton(parent, { text = lname, height = 20 }))
            linkBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, yOffset)
            linkBtn:SetScript("OnClick", function()
                ShowQuestDetail(panels, addon.QuestData:GetQuest(qid) or { id = qid, name = lname })
            end)
            yOffset = yOffset - 24
        end
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

    -- A creature name lookup primed the client cache but wasn't ready yet;
    -- re-resolve once shortly after so the real name replaces "NPC <id>".
    if detailNameRetryPending and not questData._nameRetried then
        questData._nameRetried = true
        C_Timer.After(0.5, function()
            if selectedQuest == questData then
                ShowQuestDetail(panels, questData)
            end
        end)
    end
end

-- Applies selected/normal background + text colors to a pooled list row.
local function ApplyRowColors(btn, selected)
    btn._selected = selected
    if selected then
        btn.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        if btn.nameText then btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
    else
        btn.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        if btn.nameText then btn.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    end
end

-- renderRow callback for CreateVirtualizedList. Rows are pooled: child widgets
-- are built once (guarded by _questBuilt) and updated on each render. The pooled
-- buttons are plain frames without BackdropTemplate, so row coloring uses a
-- background texture rather than SetBackdrop.
local function RenderQuestRow(btn, _, quest, selected)
    local addon = GetDataAddon()
    local tracker = addon and addon.CompletionTracker

    if not btn._questBuilt then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -1)
        btn.bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)

        btn.nameText = OneWoW_GUI:CreateFS(btn, 12)
        btn.nameText:SetPoint("TOPLEFT",  btn, "TOPLEFT",  8, -6)
        btn.nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -44, -6)
        btn.nameText:SetJustifyH("LEFT")
        btn.nameText:SetWordWrap(false)

        btn.subText = OneWoW_GUI:CreateFS(btn, 10)
        btn.subText:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  8, 6)
        btn.subText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -44, 6)
        btn.subText:SetJustifyH("LEFT")
        btn.subText:SetWordWrap(false)
        btn.subText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        btn.checkTex = btn:CreateTexture(nil, "ARTWORK")
        btn.checkTex:SetSize(14, 14)
        btn.checkTex:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
        btn.checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        btn.checkTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

        if ns.Favorites then
            btn.favBtn = OneWoW_GUI:CreateFavoriteToggleButton(btn, {
                size         = 18,
                tooltipTitle = L["CATALOG_FAVORITE"],
                tooltipText  = L["CATALOG_FAVORITE_TT"],
                onClick = function(_, on)
                    if btn._quest then
                        ns.Favorites:SetFavorite("quests", btn._quest.id, on)
                        if activePanels then RefreshQuestList(activePanels) end
                    end
                end,
            })
            btn.favBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -6)
        end

        btn:HookScript("OnEnter", function(self)
            if not self._selected then
                self.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                if self.nameText then self.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
            end
        end)
        btn:HookScript("OnLeave", function(self)
            ApplyRowColors(self, self._selected)
        end)

        btn._questBuilt = true
    end

    btn._quest = quest
    btn.nameText:SetText(quest.name or string.format(L["QUESTS_UNNAMED"], quest.id or 0))

    local expShort = ""
    if quest.expansion ~= nil and addon then
        expShort = addon.QuestData:GetExpansionShortName(quest.expansion) or ""
    end
    btn.subText:SetText(expShort)

    if tracker and tracker:IsCompletedByCurrentChar(quest.id) then
        btn.checkTex:Show()
    else
        btn.checkTex:Hide()
    end

    if btn.favBtn then
        btn.favBtn:SetFavorite(ns.Favorites:IsFavorite("quests", quest.id))
    end

    ApplyRowColors(btn, selected)
end

-- True when no search text and all filters are at their defaults.
local function IsDefaultView()
    return searchText == ""
        and expansionFilter == -1
        and zoneFilter == ""
        and typeFilter == "all"
        and questTypeFilter == "all"
        and completionFilter == "all"
        and advCategory == "all"
        and advFlag == "all"
        and advFaction == "all"
        and advStory == "all"
        and advRuntime == "all"
        and advClass == "all"
        and advRace == "all"
        and advProfession == "all"
end

-- Initial-view cap: how many quests to show before the user searches/filters.
local INITIAL_VIEW_LIMIT = 100

function RefreshQuestList(panels)
    local addon = GetDataAddon()
    if not addon or not addon.QuestData then
        wipe(questResults)
        if questListAPI then questListAPI.Refresh() end
        if panels.emptyList then
            panels.emptyList:SetText(L["QUESTS_NO_DATA"])
            panels.emptyList:Show()
        end
        if panels.leftStatusText then
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], 0))
        end
        return
    end

    local defaultView = IsDefaultView()
    local quests, defaultTotal

    if defaultView then
        -- Unfiltered view: all expansions, sorted, capped to INITIAL_VIEW_LIMIT.
        quests, defaultTotal = addon.QuestData:GetInitialQuests(INITIAL_VIEW_LIMIT)
    else
        quests = addon.QuestData:GetSortedQuests(
            expansionFilter,
            zoneFilter,
            typeFilter,
            questTypeFilter,
            searchText,
            {
                category   = advCategory,
                flag       = advFlag,
                faction    = advFaction,
                story      = advStory,
                runtime    = advRuntime,
                class      = advClass,
                race       = advRace,
                profession = advProfession,
            }
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
    end

    questResults = quests

    if panels.emptyList then
        if #quests == 0 then
            panels.emptyList:SetText(defaultView and L["QUESTS_NONE_YET"] or L["QUESTS_EMPTY"])
            panels.emptyList:Show()
        else
            panels.emptyList:Hide()
        end
    end

    if questListAPI then questListAPI.Refresh() end

    if panels.leftStatusText then
        if defaultView and defaultTotal and defaultTotal > #quests then
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_CAPPED"], #quests, defaultTotal))
        else
            panels.leftStatusText:SetText(string.format(L["QUESTS_STATUS_COUNT"], #quests))
        end
    end

    if selectedQuest then
        ShowQuestDetail(panels, addon.QuestData:GetQuest(selectedQuest.id))
    end
end

local PopulateZoneDropdown = function(panels)
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

-- Title-cases a lowercase data token for display (e.g. "world_quest" -> "World Quest").
local function TitleCase(token)
    token = tostring(token):gsub("_", " ")
    return (token:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b:lower() end))
end

local function SetupAdvancedDropdowns(panels)
    OneWoW_GUI:AttachFilterMenu(panels.factionDropdown, {
        searchable = false,
        getActiveValue = function() return advFaction end,
        buildItems = function()
            return {
                { value = "all",      text = L["QUESTS_FILTER_FACTION_ALL"] },
                { value = "neutral",  text = L["QUESTS_FACTION_NEUTRAL"]    },
                { value = "alliance", text = L["QUESTS_FACTION_ALLIANCE"]   },
                { value = "horde",    text = L["QUESTS_FACTION_HORDE"]      },
            }
        end,
        onSelect = function(value, text)
            advFaction = value
            panels.factionText:SetText(value == "all" and L["QUESTS_FILTER_FACTION_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.storyDropdown, {
        searchable = false,
        getActiveValue = function() return advStory end,
        buildItems = function()
            return {
                { value = "all",        text = L["QUESTS_FILTER_STORY_ALL"] },
                { value = "storyline",  text = L["QUESTS_STORY_STORYLINE"]  },
                { value = "chain",      text = L["QUESTS_STORY_CHAIN"]      },
                { value = "standalone", text = L["QUESTS_STORY_STANDALONE"] },
            }
        end,
        onSelect = function(value, text)
            advStory = value
            panels.storyText:SetText(value == "all" and L["QUESTS_FILTER_STORY_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })

    OneWoW_GUI:AttachFilterMenu(panels.dataDropdown, {
        searchable = false,
        getActiveValue = function() return advRuntime end,
        buildItems = function()
            return {
                { value = "all",              text = L["QUESTS_FILTER_DATA_ALL"]      },
                { value = "has_location",     text = L["QUESTS_DATA_HAS_LOCATION"]    },
                { value = "missing_location", text = L["QUESTS_DATA_MISSING_LOCATION"] },
                { value = "has_quest_giver",  text = L["QUESTS_DATA_HAS_GIVER"]       },
                { value = "has_turnin",       text = L["QUESTS_DATA_HAS_TURNIN"]      },
                { value = "has_rewards",      text = L["QUESTS_DATA_HAS_REWARDS"]     },
            }
        end,
        onSelect = function(value, text)
            advRuntime = value
            panels.dataText:SetText(value == "all" and L["QUESTS_FILTER_DATA_ALL"] or text)
            RefreshQuestList(panels)
        end,
    })

    -- Data-driven dropdowns: options come from the values actually present in
    -- the quest set (QuestData:GetFilterValues). Class/race IDs resolve to
    -- localized names; profession/category/flag tokens are title-cased.
    local function SetupDataDriven(dropdown, textRegion, getVar, setVar, allKey, listKey, labelFn)
        OneWoW_GUI:AttachFilterMenu(dropdown, {
            searchable = true,
            getActiveValue = getVar,
            buildItems = function()
                local items = { { value = "all", text = L[allKey] } }
                local addon = GetDataAddon()
                local fv = addon and addon.QuestData and addon.QuestData:GetFilterValues()
                if fv then
                    for _, v in ipairs(fv[listKey]) do
                        local label = labelFn(v)
                        if label and label ~= "" then
                            table.insert(items, { value = tostring(v), text = label })
                        end
                    end
                end
                return items
            end,
            onSelect = function(value, text)
                setVar(value)
                textRegion:SetText(value == "all" and L[allKey] or text)
                RefreshQuestList(panels)
            end,
        })
    end

    SetupDataDriven(panels.classDropdown, panels.classText,
        function() return advClass end, function(v) advClass = v end,
        "QUESTS_FILTER_CLASS_ALL", "classes", function(id) return (GetClassInfo(id)) end)

    SetupDataDriven(panels.raceDropdown, panels.raceText,
        function() return advRace end, function(v) advRace = v end,
        "QUESTS_FILTER_RACE_ALL", "races", function(id)
            local info = C_CreatureInfo.GetRaceInfo(id)
            return info and info.raceName
        end)

    SetupDataDriven(panels.professionDropdown, panels.professionText,
        function() return advProfession end, function(v) advProfession = v end,
        "QUESTS_FILTER_PROFESSION_ALL", "professions", TitleCase)

    SetupDataDriven(panels.categoryDropdown, panels.categoryText,
        function() return advCategory end, function(v) advCategory = v end,
        "QUESTS_FILTER_CATEGORY_ALL", "categories", TitleCase)

    SetupDataDriven(panels.flagDropdown, panels.flagText,
        function() return advFlag end, function(v) advFlag = v end,
        "QUESTS_FILTER_FLAG_ALL", "flags", TitleCase)
end

-- Navigates the Catalog to the quests tab and opens the given quest's detail.
-- Used by Item Search's quest-reward cross-references.
function ns.UI.OpenToQuest(questID)
    questID = tonumber(questID)
    if not questID then return end

    if ns.oneWoWHubActive then
        OneWoW.UI:Show("catalog")
        OneWoW.UI:SelectSubTab("catalog", "quests")
    else
        ns.UI:Show("quests")
    end

    C_Timer.After(0.15, function()
        local panels = activePanels or ns.UI.questsPanels
        if not panels then return end
        local addon = GetDataAddon()
        if not addon or not addon.QuestData then return end
        local quest = addon.QuestData:GetQuest(questID)
        if quest then
            ShowQuestDetail(panels, quest)
        end
    end)
end

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

    -- The split panel's plain list scroll would need one frame per quest, which
    -- is unusable with the ~33k-quest static DB. Replace it with a pooled
    -- virtualized list hosted in the same area.
    panels.listScrollFrame:Hide()

    local listHost = CreateFrame("Frame", nil, panels.listPanel)
    listHost:SetPoint("TOPLEFT", panels.listPanel, "TOPLEFT", 8, -32)
    listHost:SetPoint("BOTTOMRIGHT", panels.listPanel, "BOTTOMRIGHT", -8, 8)

    questListAPI = OneWoW_GUI:CreateVirtualizedList(listHost, {
        name = "OneWoWCatalogQuestList",
        rowHeight = ROW_HEIGHT,
        getCount = function() return #questResults end,
        getEntry = function(i) return questResults[i] end,
        onSelect = function(_, quest) ShowQuestDetail(panels, quest) end,
        renderRow = RenderQuestRow,
    })

    activePanels = panels

    local advBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_ADVANCED"], height = 26, minWidth = 34 })
    advBtn:SetPoint("TOPRIGHT", leftHeader, "TOPRIGHT", -8, -8)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(leftHeader, { text = L["QUESTS_CLEAR"], height = 26, minWidth = 34 })
    clearBtn:SetPoint("TOPRIGHT", advBtn, "TOPLEFT", -4, 0)

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

    -- Advanced filter drawer (hidden until toggled). Two rows of four filters,
    -- full width below the search/filter headers; opening it pushes content down.
    local ADV_H = 74
    local advHeader = OneWoW_GUI:CreateFilterBar(parent, { height = ADV_H, offset = 0 })
    advHeader:ClearAllPoints()
    advHeader:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
    advHeader:SetPoint("TOPRIGHT", rightHeader, "BOTTOMRIGHT", 0, -GAP)
    advHeader:SetHeight(ADV_H)
    advHeader:Hide()

    local function UpdateContentAnchor()
        contentArea:ClearAllPoints()
        if advHeader:IsShown() then
            contentArea:SetPoint("TOPLEFT", advHeader, "BOTTOMLEFT", 0, -GAP)
        else
            contentArea:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -GAP)
        end
        contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end

    advBtn:SetScript("OnClick", function()
        if advHeader:IsShown() then advHeader:Hide() else advHeader:Show() end
        UpdateContentAnchor()
    end)

    local advDropdowns = {}
    local function MakeAdvDropdown(key, allKey)
        local dd, txt = OneWoW_GUI:CreateDropdown(advHeader, { width = 10, text = L[allKey] })
        panels[key .. "Dropdown"] = dd
        panels[key .. "Text"] = txt
        advDropdowns[#advDropdowns + 1] = dd
    end

    MakeAdvDropdown("faction",    "QUESTS_FILTER_FACTION_ALL")
    MakeAdvDropdown("story",      "QUESTS_FILTER_STORY_ALL")
    MakeAdvDropdown("data",       "QUESTS_FILTER_DATA_ALL")
    MakeAdvDropdown("class",      "QUESTS_FILTER_CLASS_ALL")
    MakeAdvDropdown("race",       "QUESTS_FILTER_RACE_ALL")
    MakeAdvDropdown("profession", "QUESTS_FILTER_PROFESSION_ALL")
    MakeAdvDropdown("category",   "QUESTS_FILTER_CATEGORY_ALL")
    MakeAdvDropdown("flag",       "QUESTS_FILTER_FLAG_ALL")

    local function LayoutAdvDropdowns(w)
        local cols, pad, gap = 4, 8, 4
        local ddW = math.floor((w - (pad * 2) - (gap * (cols - 1))) / cols)
        for i, dd in ipairs(advDropdowns) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            dd:ClearAllPoints()
            dd:SetSize(ddW, 26)
            dd:SetPoint("TOPLEFT", advHeader, "TOPLEFT", pad + col * (ddW + gap), -8 - row * 32)
        end
    end

    advHeader:SetScript("OnSizeChanged", function(_, w)
        LayoutAdvDropdowns(w)
    end)

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

    rightHeader:SetScript("OnSizeChanged", function(_, w)
        LayoutFilterDropdowns(w)
    end)

    C_Timer.After(0, function()
        local w = rightHeader:GetWidth()
        if w and w > 0 then LayoutFilterDropdowns(w) end
    end)

    local emptyList = OneWoW_GUI:CreateFS(listHost, 12)
    emptyList:SetPoint("CENTER", listHost, "CENTER", 0, 0)
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
        advFaction      = "all"
        advStory        = "all"
        advRuntime      = "all"
        advClass        = "all"
        advRace         = "all"
        advProfession   = "all"
        searchBox:SetText("")
        searchBox:ClearFocus()
        expText:SetText(L["QUESTS_EXPANSION_ALL"])
        zoneText:SetText(L["QUESTS_ZONE_ALL"])
        typeText:SetText(L["QUESTS_TYPE_ALL"])
        qTypeText:SetText(L["QUESTS_QTYPE_ALL"])
        progText:SetText(L["QUESTS_PROGRESS_ALL"])
        panels.factionText:SetText(L["QUESTS_FILTER_FACTION_ALL"])
        panels.storyText:SetText(L["QUESTS_FILTER_STORY_ALL"])
        panels.dataText:SetText(L["QUESTS_FILTER_DATA_ALL"])
        panels.classText:SetText(L["QUESTS_FILTER_CLASS_ALL"])
        panels.raceText:SetText(L["QUESTS_FILTER_RACE_ALL"])
        panels.professionText:SetText(L["QUESTS_FILTER_PROFESSION_ALL"])
        panels.categoryText:SetText(L["QUESTS_FILTER_CATEGORY_ALL"])
        panels.flagText:SetText(L["QUESTS_FILTER_FLAG_ALL"])
        RefreshQuestList(panels)
    end)

    C_Timer.After(0.5, function()
        PopulateExpansionDropdown(panels)
        PopulateZoneDropdown(panels)
        SetupTypeDropdown(panels)
        SetupQuestTypeDropdown(panels)
        SetupProgressDropdown(panels)
        SetupAdvancedDropdowns(panels)
        RefreshQuestList(panels)
    end)

    ns.UI.RefreshQuestsList = function()
        RefreshQuestList(panels)
    end
end
