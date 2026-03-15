local addonName, ns = ...

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
local pendingUpdate = false
local previewMode   = false

local function GetSettings()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods["questitembar"] then mods["questitembar"] = {} end
    local s = mods["questitembar"]
    if s.locked        == nil then s.locked        = false end
    if s.hideWhenEmpty == nil then s.hideWhenEmpty = true  end
    if s.buttonSize    == nil then s.buttonSize    = 36    end
    if s.columns       == nil then s.columns       = 12    end
    if s.sortMode      == nil then s.sortMode      = 2     end
    return s
end

QuestItemBarModule.GetSettings = GetSettings

local function GetItemSortName(itemLink)
    if not itemLink then return "" end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if itemID then
        local name = C_Item.GetItemNameByID(itemID)
        if name and name ~= "" then return name end
    end
    return itemLink
end

local function BuildQuestItemList()
    local items = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    for questLogIndex = 1, numEntries do
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and not info.isHeader then
            local itemLink, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
            if texture and texture ~= 0 then
                local itemID = itemLink and C_Item.GetItemInfoInstant(itemLink)
                if itemID then
                    table.insert(items, {
                        link          = itemLink,
                        itemID        = itemID,
                        tex           = texture,
                        charges       = charges,
                        questTitle    = info.title or "",
                        questLogIndex = questLogIndex,
                    })
                end
            end
        end
    end

    local s = GetSettings()
    if s.sortMode == 2 then
        table.sort(items, function(a, b)
            if a.questTitle ~= b.questTitle then
                return a.questTitle < b.questTitle
            end
            return (a.link or "") < (b.link or "")
        end)
    elseif s.sortMode == 3 then
        table.sort(items, function(a, b)
            local an = GetItemSortName(a.link)
            local bn = GetItemSortName(b.link)
            if an ~= bn then return an < bn end
            return (a.questTitle or "") < (b.questTitle or "")
        end)
    end

    return items
end

local function EnsureButton(i)
    if buttons[i] then return buttons[i] end

    local b = CreateFrame("Button", "OneWoW_QoL_QuestItemBarBtn" .. i, barFrame, "SecureActionButtonTemplate")
    b:SetSize(36, 36)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(34, 34)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.normalTex = b:CreateTexture(nil, "BACKGROUND")
    b.normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b.normalTex:SetSize(36, 36)
    b.normalTex:SetPoint("CENTER")

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    b.cooldown = CreateFrame("Cooldown", "OneWoW_QoL_QuestItemBarBtn" .. i .. "CD", b, "CooldownFrameTemplate")
    b.cooldown:SetSize(34, 34)
    b.cooldown:SetPoint("CENTER")
    b.cooldown:SetDrawEdge(false)
    b.cooldown:SetHideCountdownNumbers(false)

    b:RegisterForClicks("AnyDown", "AnyUp")

    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local ht = b:GetHighlightTexture()
    if ht then
        ht:SetAlpha(0.4)
        ht:SetSize(36, 36)
        ht:SetPoint("CENTER")
    end

    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pt = b:GetPushedTexture()
    if pt then
        pt:SetSize(36, 36)
        pt:SetPoint("CENTER")
    end

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
            if self.questTitle and self.questTitle ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(ns.L["QUESTITEMBAR_QUEST_LABEL"] .. " " .. self.questTitle, 1, 0.82, 0)
            end
            GameTooltip:AddLine(ns.L["QUESTITEMBAR_LEFT_CLICK_USE"], 1, 1, 1)
        end
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
    local s       = GetSettings()
    local btnSize = s.buttonSize or 36
    local padding = 5
    local cols    = s.columns or 12
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
        barFrame.dragHandle:SetSize(20, math.max(height, 36))
        if previewMode or not s.locked then
            barFrame.dragHandle:Show()
        else
            barFrame.dragHandle:Hide()
        end
    end
end

function QuestItemBarModule:SecureUpdate()
    if InCombatLockdown() then
        pendingUpdate = true
        return
    end
    pendingUpdate = false

    if not barFrame then return end

    if not previewMode and not ns.ModuleRegistry:IsEnabled("questitembar") then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
        return
    end

    local list = BuildQuestItemList()

    local s = GetSettings()
    if not previewMode and s.hideWhenEmpty and #list == 0 then
        barFrame:Hide()
        if barFrame.dragHandle then barFrame.dragHandle:Hide() end
        return
    end

    local displayCount = #list
    if previewMode and displayCount == 0 then
        displayCount = math.min(3, s.columns or 12)
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

function QuestItemBarModule:FullUpdate()
    self:SecureUpdate()
    self:NonSecureUpdate()
end

function QuestItemBarModule:ScheduleUpdate()
    if updateTimer then
        updateTimer:Cancel()
    end
    updateTimer = C_Timer.NewTimer(0.2, function()
        QuestItemBarModule:FullUpdate()
        updateTimer = nil
    end)
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
    barFrame:SetSize(40, 40)
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
    dragHandle:SetSize(20, 36)
    dragHandle:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)
    dragHandle:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        tile     = false,
        edgeSize = 0,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    dragHandle:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
    dragHandle:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")

    local dragLine = dragHandle:CreateTexture(nil, "ARTWORK")
    dragLine:SetSize(3, 20)
    dragLine:SetPoint("CENTER")
    dragLine:SetColorTexture(0.6, 0.6, 0.6, 1)

    dragHandle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.L["QUESTITEMBAR_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["QUESTITEMBAR_DRAG_TOOLTIP"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    dragHandle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
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
    if eventFrame then return end

    eventFrame = CreateFrame("Frame", "OneWoW_QoL_QuestItemBarEvents")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event)
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
            return
        end

        if event == "QUEST_LOG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            QuestItemBarModule:ScheduleUpdate()
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
    if eventFrame then
        eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
        eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    self:FullUpdate()
end

function QuestItemBarModule:OnDisable()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
    if barFrame then
        barFrame:Hide()
        if barFrame.dragHandle then
            barFrame.dragHandle:Hide()
        end
    end
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
