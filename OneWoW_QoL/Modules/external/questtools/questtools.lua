-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/questtools/questtools.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local QuestToolsModule = {
    id          = "questtools",
    title       = "QUESTTOOLS_TITLE",
    category    = "AUTOMATION",
    description = "QUESTTOOLS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "auto_accept",  label = "QUESTTOOLS_TOGGLE_ACCEPT",  description = "QUESTTOOLS_TOGGLE_ACCEPT_DESC",  default = true  },
        { id = "auto_turnin",  label = "QUESTTOOLS_TOGGLE_TURNIN",  description = "QUESTTOOLS_TOGGLE_TURNIN_DESC",  default = true  },
        { id = "reward_picker",label = "QUESTTOOLS_TOGGLE_REWARDS", description = "QUESTTOOLS_TOGGLE_REWARDS_DESC", default = true  },
        { id = "auto_select_quest_gossip", label = "QUESTTOOLS_TOGGLE_GOSSIP", description = "QUESTTOOLS_TOGGLE_GOSSIP_DESC", default = true },
    },
    _acceptFrame  = nil,
    _turninFrame  = nil,
    _goldIcon     = nil,
    _gossipFrame  = nil,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("questtools", id)
end

function QuestToolsModule:InitAccept()
    if self._acceptFrame then return end
    self._acceptFrame = CreateFrame("Frame", "OneWoW_QoL_QuestAccept")
    self._acceptFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "QUEST_DETAIL" then
            if not GetToggle("auto_accept") then return end
            if IsShiftKeyDown() then return end
            if QuestGetAutoAccept() then return end
            AcceptQuest()
        elseif event == "QUEST_GREETING" then
            if not GetToggle("auto_accept") then return end
            if IsShiftKeyDown() then return end
            local numActive = GetNumActiveQuests()
            for i = 1, numActive do SelectActiveQuest(i) end
            local numAvail = GetNumAvailableQuests()
            for i = 1, numAvail do SelectAvailableQuest(i) end
        end
    end)
end

function QuestToolsModule:InitTurnin()
    if self._turninFrame then return end
    self._turninFrame = CreateFrame("Frame", "OneWoW_QoL_QuestTurnin")
    self._turninFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "QUEST_PROGRESS" then
            if not GetToggle("auto_turnin") then return end
            if IsQuestCompletable() then CompleteQuest() end
        elseif event == "QUEST_COMPLETE" then
            if not GetToggle("auto_turnin") then return end
            local numChoices = GetNumQuestChoices()
            if numChoices <= 1 then GetQuestReward(1) end
        end
    end)
end

function QuestToolsModule:InitRewardPicker()
    if self._goldIcon then return end

    self._goldIcon = CreateFrame("Frame", "OneWoW_QoL_QuestRewardPicker", QuestInfoRewardsFrame)
    self._goldIcon:SetSize(20, 20)
    self._goldIcon:SetFrameStrata("DIALOG")
    self._goldIcon:SetFrameLevel(501)
    self._goldIcon:Hide()

    local texture = self._goldIcon:CreateTexture(nil, "OVERLAY")
    texture:SetSize(20, 20)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    texture:SetDrawLayer("OVERLAY", 7)
    self._goldIcon.texture = texture

    hooksecurefunc(QuestInfoRewardsFrame, "Show", function()
        C_Timer.After(0.1, function() self:EvaluateRewards() end)
    end)

    if MapQuestInfoRewardsFrame then
        hooksecurefunc(MapQuestInfoRewardsFrame, "Show", function()
            C_Timer.After(0.1, function() self:EvaluateRewards() end)
        end)
    end
end

function QuestToolsModule:InitGossip()
    if self._gossipFrame then return end
    self._gossipFrame = CreateFrame("Frame", "OneWoW_QoL_QuestGossip")
    self._gossipFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "GOSSIP_SHOW" then
            if not GetToggle("auto_select_quest_gossip") then return end
            if IsShiftKeyDown() then return end
            local options = C_GossipInfo.GetOptions()
            for _, option in ipairs(options) do
                if string.find(option.name, "Quest") then
                    C_GossipInfo.SelectOption(option.optionID)
                end
            end
        end
    end)
end

function QuestToolsModule:EvaluateRewards()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("reward_picker") then
        if self._goldIcon then self._goldIcon:Hide() end
        return
    end

    if self._goldIcon then self._goldIcon:Hide() end

    local choices = {}
    local count = 0

    if QuestFrame and QuestFrame:IsShown() and QuestInfoRewardsFrame:IsShown() then
        local questItemName = "QuestInfoRewardsFrameQuestInfoItem"
        for i = 1, 50 do
            local button = _G[questItemName .. i]
            if button and button:IsShown() and button.type == "choice" then
                local itemLink = GetQuestItemLink("choice", button:GetID())
                if itemLink then
                    count = count + 1
                    choices[count] = {link = itemLink, button = button}
                end
            end
        end
    end

    if WorldMapFrame and WorldMapFrame:IsShown() and QuestMapFrame and QuestMapFrame:IsShown() and MapQuestInfoRewardsFrame and MapQuestInfoRewardsFrame:IsShown() then
        local questItemName = "MapQuestInfoRewardsFrameQuestInfoItem"
        for i = 1, 50 do
            local button = _G[questItemName .. i]
            if button and button:IsShown() and button.type == "choice" then
                local itemLink = GetQuestLogItemLink("choice", button:GetID())
                if itemLink then
                    count = count + 1
                    choices[count] = {link = itemLink, button = button}
                end
            end
        end
    end

    if count <= 1 then return end

    local allCached = true
    for i = 1, count do
        if choices[i] and choices[i].link then
            if not GetItemInfo(choices[i].link) then
                allCached = false
                local itemID = GetItemInfoFromHyperlink(choices[i].link)
                if itemID then C_Item.RequestLoadItemDataByID(itemID) end
            end
        end
    end

    if not allCached then
        C_Timer.After(0.3, function() self:EvaluateRewards() end)
        return
    end

    local highestValue = 0
    local highestChoice = nil
    for i = 1, count do
        local choice = choices[i]
        if choice and choice.link then
            local vendorPrice = select(11, GetItemInfo(choice.link))
            if vendorPrice and vendorPrice > highestValue then
                highestValue = vendorPrice
                highestChoice = choice
            end
        end
    end

    if highestChoice and highestValue > 0 and highestChoice.button and self._goldIcon then
        self._goldIcon:SetParent(highestChoice.button)
        self._goldIcon:ClearAllPoints()
        self._goldIcon:SetPoint("TOPLEFT", highestChoice.button, "TOPLEFT", -1, 1)
        self._goldIcon:Show()
    end
end

function QuestToolsModule:OnEnable()
    self:InitAccept()
    self:InitTurnin()
    self:InitRewardPicker()
    self:InitGossip()

    self._acceptFrame:RegisterEvent("QUEST_DETAIL")
    self._acceptFrame:RegisterEvent("QUEST_GREETING")
    self._turninFrame:RegisterEvent("QUEST_PROGRESS")
    self._turninFrame:RegisterEvent("QUEST_COMPLETE")
    self._gossipFrame:RegisterEvent("GOSSIP_SHOW")
end

function QuestToolsModule:OnDisable()
    if self._acceptFrame then self._acceptFrame:UnregisterAllEvents() end
    if self._turninFrame then self._turninFrame:UnregisterAllEvents() end
    if self._gossipFrame then self._gossipFrame:UnregisterAllEvents() end
    if self._goldIcon then self._goldIcon:Hide() end
end

function QuestToolsModule:OnToggle(toggleId, value)
    if toggleId == "auto_accept" then
        if self._acceptFrame then
            if value then
                self._acceptFrame:RegisterEvent("QUEST_DETAIL")
                self._acceptFrame:RegisterEvent("QUEST_GREETING")
            else
                self._acceptFrame:UnregisterAllEvents()
            end
        end
    elseif toggleId == "auto_turnin" then
        if self._turninFrame then
            if value then
                self._turninFrame:RegisterEvent("QUEST_PROGRESS")
                self._turninFrame:RegisterEvent("QUEST_COMPLETE")
            else
                self._turninFrame:UnregisterAllEvents()
            end
        end
    elseif toggleId == "reward_picker" then
        if not value and self._goldIcon then
            self._goldIcon:Hide()
        end
    elseif toggleId == "auto_select_quest_gossip" then
        if self._gossipFrame then
            if value then
                self._gossipFrame:RegisterEvent("GOSSIP_SHOW")
            else
                self._gossipFrame:UnregisterEvent("GOSSIP_SHOW")
            end
        end
    end
end

ns.QuestToolsModule = QuestToolsModule
