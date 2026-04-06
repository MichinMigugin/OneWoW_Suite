local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local QuestItemBarModule = {
    id          = "questitembar",
    title       = "QUESTITEMBAR_TITLE",
    category    = "INTERFACE",
    description = "QUESTITEMBAR_DESC",
    version     = "1.0",
    author      = "Clew",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
}

local barFrame      = nil
local buttons       = {}
local eventFrame    = nil
local updateTimer   = nil
local proximityTicker = nil
local scheduledFromProximityTrigger = false
local pendingUpdate = false
local previewMode   = false

local defaultColumns = 12
local defaultButtonSize = 36
local defaultSortMode = 2

local MIN_BUTTON_SIZE = 24
local MAX_BUTTON_SIZE = 48
local MIN_COLUMNS = 1
local MAX_COLUMNS = 12
local BUTTON_PADDING = 5

local SORT_MODES = {
    { value = 1, labelKey = "QUESTITEMBAR_SORT_NONE" },
    { value = 2, labelKey = "QUESTITEMBAR_SORT_QUEST" },
    { value = 3, labelKey = "QUESTITEMBAR_SORT_ITEM" },
    { value = 4, labelKey = "QUESTITEMBAR_SORT_PROXIMITY" },
    { value = 5, labelKey = "QUESTITEMBAR_SORT_DYNAMIC" },
}

local DYNAMIC_TIER_KEYS = { "supertracked", "proximity", "zone", "tracked" }

local function SyncKeybindings()
    if InCombatLockdown() then return end
    if not barFrame then return end
    ClearOverrideBindings(barFrame)
    for i = 1, 4 do
        local key = GetBindingKey("QUESTITEM_" .. i)
        if key then
            SetOverrideBindingClick(barFrame, false, key, "OneWoW_QoL_QuestItemBarBtn" .. i)
        end
    end
end

local function HideBar()
    if barFrame then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
    end
end

local function GetSettings()
    local addon = _G.OneWoW_QoL
    -- Defensive: return empty table if addon not initialized; writes will not persist.
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods["questitembar"] then mods["questitembar"] = {} end
    local s = mods["questitembar"]
    if s.locked               == nil then s.locked               = false end
    if s.hideWhenEmpty        == nil then s.hideWhenEmpty        = true  end
    if s.showOnlySupertracked == nil then s.showOnlySupertracked = false end
    if s.showOnlyCurrentZone  == nil then s.showOnlyCurrentZone  = false end
    if s.showOnlyTracked      == nil then s.showOnlyTracked      = false end
    if s.buttonSize       == nil then s.buttonSize       = defaultButtonSize    end
    if s.columns          == nil then s.columns         = defaultColumns    end
    if s.sortMode         == nil then s.sortMode        = defaultSortMode     end
    if s.dynamicOrder     == nil or #s.dynamicOrder == 0 then
        s.dynamicOrder = { "supertracked", "proximity", "zone", "tracked" }
    end
    return s
end

QuestItemBarModule.GetSettings = GetSettings
QuestItemBarModule.SORT_MODES = SORT_MODES
QuestItemBarModule.defaultSortMode = defaultSortMode
QuestItemBarModule.defaultButtonSize = defaultButtonSize
QuestItemBarModule.defaultColumns = defaultColumns
QuestItemBarModule.MIN_BUTTON_SIZE = MIN_BUTTON_SIZE
QuestItemBarModule.MAX_BUTTON_SIZE = MAX_BUTTON_SIZE
QuestItemBarModule.MIN_COLUMNS = MIN_COLUMNS
QuestItemBarModule.MAX_COLUMNS = MAX_COLUMNS
QuestItemBarModule.DYNAMIC_TIER_KEYS = DYNAMIC_TIER_KEYS

function QuestItemBarModule:GetDynamicOrder()
    local s = GetSettings()
    if not s.dynamicOrder or #s.dynamicOrder == 0 then
        return { "supertracked", "proximity", "zone", "tracked" }
    end
    return s.dynamicOrder
end

function QuestItemBarModule:SwapDynamicOrder(index, direction)
    local s = GetSettings()
    local order = s.dynamicOrder
    if not order or #order == 0 then
        order = { "supertracked", "proximity", "zone", "tracked" }
        s.dynamicOrder = order
    end
    local other = index + direction
    if other < 1 or other > #order then return order end
    order[index], order[other] = order[other], order[index]
    QuestItemBarModule:ScheduleUpdate()
    return order
end

function QuestItemBarModule:GetSortLabel(mode)
    mode = mode or GetSettings().sortMode or defaultSortMode
    for _, m in ipairs(SORT_MODES) do
        if m.value == mode then
            return (ns.L and ns.L[m.labelKey]) or m.labelKey
        end
    end
    return (ns.L and ns.L[SORT_MODES[1].labelKey]) or SORT_MODES[1].labelKey
end

local function GetItemSortName(itemLink)
    if not itemLink then return "" end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if itemID then
        local name = C_Item.GetItemNameByID(itemID)
        if name and name ~= "" then return name end
    end
    return itemLink
end

local function addItemFromQuestLog(items, questLogIndex, info)
    local itemLink, texture, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
    local readyForTurnIn = C_QuestLog.ReadyForTurnIn(info.questID)
    local shouldShow = texture and texture ~= 0 and itemLink
        and (not readyForTurnIn or showItemWhenComplete)
    if shouldShow then
        local itemID = C_Item.GetItemIDForItemInfo(itemLink)
        if itemID then
            tinsert(items, {
                link          = itemLink,
                itemID        = itemID,
                tex           = texture,
                charges       = charges,
                questTitle    = info.title or "",
                questLogIndex = questLogIndex,
                questID       = info.questID,
            })
        end
    end
end

local function BuildQuestItemList(shouldSortProximity)
    local items = {}
    local s = GetSettings()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    -- 1. Supertracked overrides all
    if s.showOnlySupertracked then
        local superID = C_SuperTrack.GetSuperTrackedQuestID()
        if not superID then
            return {}
        end
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(superID)
        if questLogIndex then
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info and not info.isHeader then
                addItemFromQuestLog(items, questLogIndex, info)
            end
        end
        -- Skip sort when supertracked (only one quest's items)
        return items
    end

    -- 2. Build zone quest set when Current Zone filter is on or Dynamic sort (for tier classification)
    local zoneQuestSet = {}
    if s.showOnlyCurrentZone or s.sortMode == 5 then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local questsOnMap = C_QuestLog.GetQuestsOnMap(mapID)
            if questsOnMap then
                for _, q in ipairs(questsOnMap) do
                    if q.questID then
                        zoneQuestSet[q.questID] = true
                    end
                end
            end
        end
    end

    -- 3. Helper: should include quest given filters (Tracked and/or Current Zone)
    local function passesFilters(info)
        if s.showOnlyTracked and not C_QuestLog.GetQuestWatchType(info.questID) then
            return false
        end
        if s.showOnlyCurrentZone and not zoneQuestSet[info.questID] then
            return false
        end
        return true
    end

    local anyFilter = s.showOnlyTracked or s.showOnlyCurrentZone

    if s.sortMode == 4 and not s.showOnlySupertracked then
        -- By Proximity: use watched quest order
        if shouldSortProximity then
            C_QuestLog.SortQuestWatches()
            C_Timer.After(0, function()
                QuestItemBarModule:ScheduleUpdate()
            end)
        end
        local watchedSet = {}
        for i = 1, C_QuestLog.GetNumQuestWatches() do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if questID then
                watchedSet[questID] = true
                local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                if questLogIndex then
                    local info = C_QuestLog.GetInfo(questLogIndex)
                    if info and not info.isHeader and (not anyFilter or passesFilters(info)) then
                        addItemFromQuestLog(items, questLogIndex, info)
                    end
                end
            end
        end
        if not s.showOnlyTracked then
            for questLogIndex = 1, numEntries do
                local info = C_QuestLog.GetInfo(questLogIndex)
                if info and not info.isHeader and not watchedSet[info.questID] then
                    if not anyFilter or passesFilters(info) then
                        addItemFromQuestLog(items, questLogIndex, info)
                    end
                end
            end
        end
    else
        for questLogIndex = 1, numEntries do
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info and not info.isHeader then
                if not anyFilter or passesFilters(info) then
                    addItemFromQuestLog(items, questLogIndex, info)
                end
            end
        end

        if s.sortMode == 5 then
            -- Dynamic: tier-based ordering
            if shouldSortProximity then
                C_QuestLog.SortQuestWatches()
                C_Timer.After(0, function()
                    QuestItemBarModule:ScheduleUpdate()
                end)
            end
            local watchedProximityOrder = {}
            for i = 1, C_QuestLog.GetNumQuestWatches() do
                local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                if questID then
                    watchedProximityOrder[questID] = i
                end
            end
            local superID = C_SuperTrack.GetSuperTrackedQuestID()
            local order = s.dynamicOrder
            if not order or #order == 0 then
                order = DYNAMIC_TIER_KEYS
            end
            local tierBuckets = {}
            for _, key in ipairs(order) do
                tierBuckets[key] = {}
            end
            for _, it in ipairs(items) do
                local questID = it.questID
                local isSuper = (questID == superID)
                local isProximity = watchedProximityOrder[questID]
                local isZone = zoneQuestSet[questID]
                local isTracked = C_QuestLog.GetQuestWatchType(questID)
                local assigned = false
                for _, key in ipairs(order) do
                    if key == "supertracked" and isSuper then
                        tinsert(tierBuckets[key], it)
                        assigned = true
                        break
                    elseif key == "proximity" and isProximity then
                        tinsert(tierBuckets[key], it)
                        assigned = true
                        break
                    elseif key == "zone" and isZone then
                        tinsert(tierBuckets[key], it)
                        assigned = true
                        break
                    elseif key == "tracked" and isTracked then
                        tinsert(tierBuckets[key], it)
                        assigned = true
                        break
                    end
                end
                if not assigned then
                    local lastKey = order[#order]
                    tinsert(tierBuckets[lastKey], it)
                end
            end
            local function sortProximity(a, b)
                local pa = watchedProximityOrder[a.questID] or 9999
                local pb = watchedProximityOrder[b.questID] or 9999
                if pa ~= pb then return pa < pb end
                if a.questTitle ~= b.questTitle then return a.questTitle < b.questTitle end
                return (a.link or "") < (b.link or "")
            end
            local function sortQuestItem(a, b)
                if a.questTitle ~= b.questTitle then return a.questTitle < b.questTitle end
                return (a.link or "") < (b.link or "")
            end
            wipe(items)
            for _, key in ipairs(order) do
                local bucket = tierBuckets[key]
                if key == "proximity" then
                    sort(bucket, sortProximity)
                else
                    sort(bucket, sortQuestItem)
                end
                for _, it in ipairs(bucket) do
                    tinsert(items, it)
                end
            end
        elseif s.sortMode == defaultSortMode then
            sort(items, function(a, b)
                if a.questTitle ~= b.questTitle then
                    return a.questTitle < b.questTitle
                end
                return (a.link or "") < (b.link or "")
            end)
        elseif s.sortMode == 3 then
            sort(items, function(a, b)
                local an = GetItemSortName(a.link)
                local bn = GetItemSortName(b.link)
                if an ~= bn then return an < bn end
                return (a.questTitle or "") < (b.questTitle or "")
            end)
        end
    end

    return items
end

local STATUS_KEYS = {
    INCLUDED            = "QUESTITEMBAR_DEBUG_INCLUDED",
    NOT_TRACKED         = "QUESTITEMBAR_DEBUG_NOT_TRACKED",
    NO_USABLE_ITEMS     = "QUESTITEMBAR_DEBUG_NO_USABLE_ITEMS",
    NO_SPECIAL          = "QUESTITEMBAR_DEBUG_NO_SPECIAL",
    READY_TURNIN        = "QUESTITEMBAR_DEBUG_READY_TURNIN",
    INVALID             = "QUESTITEMBAR_DEBUG_INVALID",
    NO_SUPERTRACKED     = "QUESTITEMBAR_DEBUG_NO_SUPERTRACKED",
}

local function BuildQuestItemDebugList()
    local entries = {}
    local s = GetSettings()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    local includedSet = {}
    do
        local barList = BuildQuestItemList(false) -- skip SortQuestWatches to avoid event loop
        for _, it in ipairs(barList) do
            includedSet[it.questLogIndex] = true
        end
    end

    -- Synthetic row when Supertracked filter is on but no quest is super-tracked
    if s.showOnlySupertracked and not C_SuperTrack.GetSuperTrackedQuestID() then
        local msg = (ns.L and ns.L[STATUS_KEYS.NO_SUPERTRACKED]) or STATUS_KEYS.NO_SUPERTRACKED
        tinsert(entries, {
            link         = nil,
            itemID       = nil,
            tex          = nil,
            questTitle   = msg,
            questID      = nil,
            questLogIndex = nil,
            name         = "",
            quality      = 1,
            status       = STATUS_KEYS.NO_SUPERTRACKED,
            included     = false,
        })
    end

    for questLogIndex = 1, numEntries do
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and not info.isHeader then
            local itemLink, texture, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
            local readyForTurnIn = C_QuestLog.ReadyForTurnIn(info.questID)
            local questTitle = info.title or ""

            local statusKey, included, itemID, name, quality, tex

            if not texture or texture == 0 or not itemLink then
                statusKey = STATUS_KEYS.NO_USABLE_ITEMS
                included = false
                name = questTitle
                quality = 1
            else
                itemID = C_Item.GetItemIDForItemInfo(itemLink)
                tex = texture
                if not itemID then
                    statusKey = STATUS_KEYS.INVALID
                    included = false
                    name = questTitle
                    quality = 1
                elseif readyForTurnIn and not showItemWhenComplete then
                    statusKey = STATUS_KEYS.READY_TURNIN
                    included = false
                    local itemName, _, itemQuality = C_Item.GetItemInfo(itemID)
                    name = itemName or C_Item.GetItemNameByID(itemID) or questTitle
                    quality = itemQuality or 1
                else
                    included = includedSet[questLogIndex] == true
                    if included then
                        statusKey = STATUS_KEYS.INCLUDED
                    elseif not C_QuestLog.GetQuestWatchType(info.questID) then
                        statusKey = STATUS_KEYS.NOT_TRACKED
                    else
                        statusKey = STATUS_KEYS.NO_SPECIAL
                    end
                    local itemName, _, itemQuality = C_Item.GetItemInfo(itemID)
                    name = itemName or C_Item.GetItemNameByID(itemID) or questTitle
                    quality = itemQuality or 1
                end
            end

            tinsert(entries, {
                link          = itemLink,
                itemID        = itemID,
                tex           = tex,
                questTitle    = questTitle,
                questID       = info.questID,
                questLogIndex = questLogIndex,
                name          = name or questTitle,
                quality       = quality or 1,
                status        = statusKey,
                included      = included,
            })
        end
    end

    -- Sort: No supertracked (synthetic) first, Included next, No usable items last; within groups by name
    local statusOrder = {
        [STATUS_KEYS.NO_SUPERTRACKED] = 0,
        [STATUS_KEYS.INCLUDED]        = 1,
        [STATUS_KEYS.READY_TURNIN]    = 2,
        [STATUS_KEYS.INVALID]         = 3,
        [STATUS_KEYS.NOT_TRACKED]     = 4,
        [STATUS_KEYS.NO_SPECIAL]      = 5,
        [STATUS_KEYS.NO_USABLE_ITEMS] = 6,
    }
    sort(entries, function(a, b)
        local orderA = statusOrder[a.status] or 99
        local orderB = statusOrder[b.status] or 99
        if orderA ~= orderB then
            return orderA < orderB
        end
        return (a.name or "") < (b.name or "")
    end)

    return entries
end

QuestItemBarModule.BuildQuestItemDebugList = BuildQuestItemDebugList

local function EnsureButton(i)
    if buttons[i] then return buttons[i] end

    local b = CreateFrame("Button", "OneWoW_QoL_QuestItemBarBtn" .. i, barFrame, "SecureActionButtonTemplate")
    b:SetSize(defaultButtonSize, defaultButtonSize)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(defaultButtonSize - 2, defaultButtonSize - 2)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.normalTex = b:CreateTexture(nil, "BACKGROUND")
    b.normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b.normalTex:SetSize(defaultButtonSize, defaultButtonSize)
    b.normalTex:SetPoint("CENTER")

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    b.cooldown = CreateFrame("Cooldown", "OneWoW_QoL_QuestItemBarBtn" .. i .. "CD", b, "CooldownFrameTemplate")
    b.cooldown:SetSize(defaultButtonSize - 2, defaultButtonSize - 2)
    b.cooldown:SetPoint("CENTER")
    b.cooldown:SetDrawEdge(false)
    b.cooldown:SetHideCountdownNumbers(false)

    b:RegisterForClicks("AnyDown", "AnyUp")

    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local ht = b:GetHighlightTexture()
    if ht then
        ht:SetAlpha(0.4)
        ht:SetSize(defaultButtonSize, defaultButtonSize)
        ht:SetPoint("CENTER")
    end

    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pt = b:GetPushedTexture()
    if pt then
        pt:SetSize(defaultButtonSize, defaultButtonSize)
        pt:SetPoint("CENTER")
    end

    b:SetScript("OnEnter", function(self)
        if not self.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        if self.questTitle and self.questTitle ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.L["QUESTITEMBAR_QUEST_LABEL"] .. " " .. self.questTitle, 1, 0.82, 0)
        end
        GameTooltip:AddLine(ns.L["QUESTITEMBAR_LEFT_CLICK_USE"], 1, 1, 1)
        GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    buttons[i] = b
    return b
end

local function ClearButton(b)
    b.itemLink = nil
    b.itemID = nil
    b.questTitle = nil
    b.questLogIndex = nil
    b.icon:SetTexture(nil)
    b.count:SetText("")
    b.cooldown:Hide()
    b:SetAttribute("type*", nil)
    b:SetAttribute("item*", nil)
end

local function SetButtonEntry(b, entry)
    b.itemLink = entry.link
    b.itemID = entry.itemID
    b.questTitle = entry.questTitle
    b.questLogIndex = entry.questLogIndex

    b.icon:SetTexture(entry.tex)
    b.count:SetText((entry.charges and entry.charges > 1) and entry.charges or "")

    b:SetAttribute("type*", "item")
    b:SetAttribute("item*", "item:" .. entry.itemID)
end

local function UpdateCooldown(b)
    if not b.itemID then
        b.cooldown:Hide()
        return
    end

    local start, duration, enabled = C_Item.GetItemCooldown(b.itemID)
    if start then
        CooldownFrame_Set(b.cooldown, start, duration, enabled)
    else
        b.cooldown:Hide()
    end
end

function QuestItemBarModule:LayoutButtons(count)
    if not barFrame then return end
    local s       = GetSettings()
    local btnSize = s.buttonSize or defaultButtonSize
    local padding = BUTTON_PADDING
    local cols    = s.columns or defaultColumns
    local actualCols = math.min(count, cols)
    local rows    = math.max(1, math.ceil(count / cols))

    for i = 1, count do
        local b = EnsureButton(i)
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        b:ClearAllPoints()
        b:SetSize(btnSize, btnSize)
        b:SetPoint("TOPLEFT", barFrame, "TOPLEFT",
            col * (btnSize + padding),
            -(row * (btnSize + padding)))

        local iconSize = btnSize - 2
        b.icon:SetSize(iconSize, iconSize)
        b.normalTex:SetSize(btnSize, btnSize)
        b.cooldown:SetSize(iconSize, iconSize)

        local ht = b:GetHighlightTexture()
        if ht then ht:SetSize(btnSize, btnSize) end
        local pt = b:GetPushedTexture()
        if pt then pt:SetSize(btnSize, btnSize) end

        b:Show()
    end

    for i = count + 1, #buttons do
        buttons[i]:Hide()
    end

    if actualCols > 0 then
        local width  = (actualCols * btnSize) + ((actualCols - 1) * padding)
        local height = (rows * btnSize) + ((rows - 1) * padding)
        barFrame:SetSize(width, height)
    else
        barFrame:SetSize(btnSize, btnSize)
    end

    if barFrame.dragHandle then
        local height = barFrame:GetHeight()
        barFrame.dragHandle:SetSize(20, math.max(height, defaultButtonSize))
        if previewMode or not s.locked then
            barFrame.dragHandle:Show()
        else
            barFrame.dragHandle:Hide()
        end
    end
end

function QuestItemBarModule:SecureUpdate(fromProximityTrigger)
    if InCombatLockdown() then
        pendingUpdate = true
        return
    end
    pendingUpdate = false

    if not barFrame then return end

    if not previewMode and not ns.ModuleRegistry:IsEnabled("questitembar") then
        HideBar()
        return
    end

    local list = BuildQuestItemList(fromProximityTrigger)

    local s = GetSettings()
    if not previewMode and s.hideWhenEmpty and #list == 0 then
        HideBar()
        return
    end

    local displayCount = #list
    if previewMode and displayCount == 0 then
        displayCount = math.min(3, s.columns or defaultColumns)
    end

    self:LayoutButtons(displayCount)

    for i = 1, #list do
        local b = EnsureButton(i)
        SetButtonEntry(b, list[i])
        UpdateCooldown(b)
    end

    for i = #list + 1, displayCount do
        local b = EnsureButton(i)
        ClearButton(b)
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        b:Show()
    end

    for i = displayCount + 1, #buttons do
        ClearButton(buttons[i])
    end

    barFrame:Show()
end

function QuestItemBarModule:NonSecureUpdate()
    for i = 1, #buttons do
        local b = buttons[i]
        if b:IsShown() and b.itemLink then
            UpdateCooldown(b)
        end
    end
end

function QuestItemBarModule:FullUpdate(fromProximityTrigger)
    self:SecureUpdate(fromProximityTrigger)
    self:NonSecureUpdate()
end

local function UpdateProximityTickerState()
    local s = GetSettings()
    local inProximityMode = (s.sortMode == 4 or s.sortMode == 5) and ns.ModuleRegistry:IsEnabled("questitembar") and not s.showOnlySupertracked
    if inProximityMode then
        if not proximityTicker then
            proximityTicker = C_Timer.NewTicker(5, function()
                QuestItemBarModule:ScheduleUpdate(true)
            end)
        end
    else
        if proximityTicker then
            proximityTicker:Cancel()
            proximityTicker = nil
        end
    end
end

function QuestItemBarModule:ScheduleUpdate(fromProximityTrigger)
    scheduledFromProximityTrigger = fromProximityTrigger == true
    if updateTimer then
        updateTimer:Cancel()
    end
    updateTimer = C_Timer.NewTimer(0.2, function()
        local flag = scheduledFromProximityTrigger
        scheduledFromProximityTrigger = false
        QuestItemBarModule:FullUpdate(flag)
        updateTimer = nil
    end)
    UpdateProximityTickerState()
end

function QuestItemBarModule:SavePosition()
    if not barFrame then return end
    local left   = barFrame:GetLeft()
    local top    = barFrame:GetTop()
    local bottom = barFrame:GetBottom()
    if not left or not top or not bottom then return end

    local centerY      = (top + bottom) / 2
    local screenHeight = UIParent:GetHeight()
    local anchorPoint, yOffset

    if centerY > (screenHeight * 0.66) then
        anchorPoint = "TOPLEFT"
        yOffset     = top - screenHeight
    elseif centerY < (screenHeight * 0.33) then
        anchorPoint = "BOTTOMLEFT"
        yOffset     = bottom
    else
        anchorPoint = "LEFT"
        yOffset     = centerY - (screenHeight / 2)
    end

    barFrame:Execute(string.format([[
        self:ClearAllPoints()
        self:SetPoint("%s", self:GetParent(), "%s", %.2f, %.2f)
    ]], anchorPoint, anchorPoint, left, yOffset))

    local s = GetSettings()
    s.position = { point = anchorPoint, relativePoint = anchorPoint, x = left, y = yOffset }
end

function QuestItemBarModule:CreateBar()
    if barFrame then return end
    barFrame = CreateFrame("Frame", "OneWoW_QoL_QuestItemBar", UIParent, "SecureHandlerBaseTemplate")
    barFrame:SetSize(defaultButtonSize + 4, defaultButtonSize + 4)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetClampedToScreen(true)
    barFrame:Hide()

    local s = GetSettings()
    if s.position then
        barFrame:SetPoint(s.position.point, UIParent, s.position.relativePoint, s.position.x, s.position.y)
    else
        barFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end

    barFrame:EnableMouse(false)

    local dragOffsetX, dragOffsetY = 0, 0

    local dragHandle = CreateFrame("Frame", "OneWoW_QoL_QuestItemBarDrag", barFrame, "BackdropTemplate")
    dragHandle:SetSize(20, defaultButtonSize)
    dragHandle:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)
    dragHandle:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        tile     = false,
        edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    dragHandle:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    dragHandle:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")

    local dragLine = dragHandle:CreateTexture(nil, "ARTWORK")
    dragLine:SetSize(3, 20)
    dragLine:SetPoint("CENTER")
    dragLine:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    dragHandle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.L["QUESTITEMBAR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["QUESTITEMBAR_DRAG_TOOLTIP"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        GameTooltip:Hide()
    end)
    dragHandle:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        if previewMode or not GetSettings().locked then
            local scale = barFrame:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            dragOffsetX = barFrame:GetLeft() - (cx / scale)
            dragOffsetY = barFrame:GetTop() - (cy / scale)
            dragHandle:SetScript("OnUpdate", function()
                local cx2, cy2 = GetCursorPosition()
                local s2 = barFrame:GetEffectiveScale()
                local newX = (cx2 / s2) + dragOffsetX
                local newY = (cy2 / s2) + dragOffsetY
                barFrame:Execute(string.format([[
                    self:ClearAllPoints()
                    self:SetPoint("TOPLEFT", self:GetParent(), "BOTTOMLEFT", %.2f, %.2f)
                ]], newX, newY))
            end)
        end
    end)
    dragHandle:SetScript("OnDragStop", function()
        dragHandle:SetScript("OnUpdate", nil)
        QuestItemBarModule:SavePosition()
    end)

    barFrame.dragHandle = dragHandle
    self.frame = barFrame
end

function QuestItemBarModule:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "OneWoW_QoL_QuestItemBarEvents")
    end
    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            SyncKeybindings()
            return
        end

        if not ns.ModuleRegistry:IsEnabled("questitembar") then return end

        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                QuestItemBarModule:FullUpdate()
            end)
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if pendingUpdate then
                QuestItemBarModule:FullUpdate()
            end
            SyncKeybindings()
            return
        end

        if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_LIST_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "SUPER_TRACKING_CHANGED" then
            -- Refresh settings list when user is viewing it (throttled to avoid event storm)
            if QuestItemBarModule._detailScrollChild and QuestItemBarModule._refreshCustomDetail then
                local container = QuestItemBarModule._detailScrollChild._qibContainer
                if container and container:GetParent() == QuestItemBarModule._detailScrollChild then
                    local now = GetTime()
                    if not QuestItemBarModule._lastDetailRefresh or (now - QuestItemBarModule._lastDetailRefresh) >= 0.5 then
                        QuestItemBarModule._lastDetailRefresh = now
                        QuestItemBarModule._refreshCustomDetail()
                    end
                end
            end
            QuestItemBarModule:ScheduleUpdate()
            return
        end

        if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
            local s = GetSettings()
            if s.sortMode == 4 or s.sortMode == 5 then
                QuestItemBarModule:ScheduleUpdate(true)
            end
            if s.showOnlyCurrentZone and s.sortMode ~= 4 and s.sortMode ~= 5 then
                if QuestItemBarModule._detailScrollChild and QuestItemBarModule._refreshCustomDetail then
                    local container = QuestItemBarModule._detailScrollChild._qibContainer
                    if container and container:GetParent() == QuestItemBarModule._detailScrollChild then
                        local now = GetTime()
                        if not QuestItemBarModule._lastDetailRefresh or (now - QuestItemBarModule._lastDetailRefresh) >= 0.5 then
                            QuestItemBarModule._lastDetailRefresh = now
                            QuestItemBarModule._refreshCustomDetail()
                        end
                    end
                end
                QuestItemBarModule:ScheduleUpdate()
            end
            return
        end

        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
            QuestItemBarModule:NonSecureUpdate()
            return
        end
    end)
end

function QuestItemBarModule:OnEnable()
    if not barFrame then
        self:CreateBar()
    end
    self:RegisterEvents()
    self:FullUpdate()
    SyncKeybindings()
end

function QuestItemBarModule:OnDisable()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
    if proximityTicker then
        proximityTicker:Cancel()
        proximityTicker = nil
    end
    if barFrame then
        ClearOverrideBindings(barFrame)
    end
    HideBar()
end

function QuestItemBarModule:OnToggle(toggleId, value)
end

function QuestItemBarModule:ShowPreview()
    previewMode = true
    if not barFrame then
        self:CreateBar()
        self:RegisterEvents()
    end
    self:FullUpdate()
end

function QuestItemBarModule:HidePreview()
    previewMode = false
    if barFrame then
        self:FullUpdate()
    end
end

function QuestItemBarModule:IsPreviewActive()
    return previewMode
end

function QuestItemBarModule:SetLocked(locked)
    local s = GetSettings()
    s.locked = locked
    if barFrame and barFrame.dragHandle then
        if locked then
            barFrame.dragHandle:Hide()
        else
            barFrame.dragHandle:Show()
        end
    end
end

ns.QuestItemBarModule = QuestItemBarModule
