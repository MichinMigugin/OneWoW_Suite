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
        { id = "auto_gossip",  label = "QUESTTOOLS_TOGGLE_GOSSIP",  description = "QUESTTOOLS_TOGGLE_GOSSIP_DESC",  default = false },
    },
    preview       = true,
    _acceptFrame  = nil,
    _turninFrame  = nil,
    _gossipFrame  = nil,
    _gossipHooked = false,
    _gossipRetryToken = 0,
    _goldIcon     = nil,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("questtools", id)
end

local function GetDisplayedTextFromGossipButton(btn)
    if not btn then return nil end
    if btn.GetText then
        local t = btn:GetText()
        if type(t) == "string" and t ~= "" then return t end
    end
    local regions = { btn:GetRegions() }
    for _, rr in ipairs(regions) do
        if rr.GetText and rr:GetObjectType() == "FontString" then
            local t = rr:GetText()
            if type(t) == "string" and t ~= "" then return t end
        end
    end
    return nil
end

function QuestToolsModule:GetGossipDisplayedButtonTexts()
    local out = {}
    local gf = _G.GossipFrame
    if not gf or not gf:IsShown() then return out end
    local scrollTarget = gf.GreetingPanel and gf.GreetingPanel.ScrollBox and gf.GreetingPanel.ScrollBox.ScrollTarget
    if not scrollTarget then return out end
    local children = { scrollTarget:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "Button" then
            local t = GetDisplayedTextFromGossipButton(child)
            if t then
                out[#out + 1] = t
            end
        end
    end
    return out
end

function QuestToolsModule:DebugPrintGossipApiVsUi()
    print("|cff00ff00[OneWoW_QoL QuestTools]|r Gossip: API name vs. UI button text")
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local opts = C_GossipInfo.GetOptions()
        if opts then
            for _, o in pairs(opts) do
                print("  API", "order", tostring(o.orderIndex), "name", tostring(o.name), "icon", tostring(o.icon))
            end
        else
            print("  API: (nil)")
        end
    else
        print("  API: C_GossipInfo not available")
    end
    print("  UI (GossipFrame scroll buttons):")
    local lines = self:GetGossipDisplayedButtonTexts()
    if #lines == 0 then
        print("    (none — is GossipFrame open?)")
    else
        for i, line in ipairs(lines) do
            print("   ", i, line)
        end
    end
end

local function NormalizeGossipTextForMatch(text)
    if not text then return "" end
    local s = text
    s = s:gsub("|H[^|]+|h([^|]*)|h", "%1")
    for _ = 1, 12 do
        local before = s
        s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if s == before then break end
    end
    s = s:gsub("|T[^|]+|t", "")
    s = s:gsub("^%s+", "")
    return s
end

local function HasQuestGossipMarker(name)
    if not name or name == "" then return false end
    local plain = "(quest)"
    if string.find(name:lower(), plain, 1, true) then return true end
    local s = NormalizeGossipTextForMatch(name)
    return string.find(s:lower(), plain, 1, true) ~= nil
end

function QuestToolsModule:IsGossipOptionChoosable(opt)
    if not opt then return false end
    if Enum and Enum.GossipOptionStatus and opt.status ~= nil then
        local S = Enum.GossipOptionStatus
        if S then
            if opt.status == S.Locked or opt.status == S.Unavailable then
                return false
            end
        end
    end
    return true
end

local function HasQuestLabelPrependFlag(opt)
    if not opt or opt.flags == nil then return false end
    if FlagsUtil and FlagsUtil.IsSet and Enum and Enum.GossipOptionRecFlags and Enum.GossipOptionRecFlags.QuestLabelPrepend then
        return FlagsUtil.IsSet(opt.flags, Enum.GossipOptionRecFlags.QuestLabelPrepend)
    end
    return false
end

local function ResolveIndexedGossipHits(hits, texts, byOrder)
    if #hits == 0 then return nil end
    if #hits == 1 then return hits[1].opt end
    local withDisplayQuest = {}
    for _, hit in ipairs(hits) do
        local t = texts[hit.index]
        if t and HasQuestGossipMarker(t) then
            withDisplayQuest[#withDisplayQuest + 1] = hit.opt
        end
    end
    if #withDisplayQuest == 1 then return withDisplayQuest[1] end
    if #withDisplayQuest > 1 then
        table.sort(withDisplayQuest, byOrder)
        return withDisplayQuest[1]
    end
    table.sort(hits, function(a, b)
        return (a.opt.orderIndex or math.huge) < (b.opt.orderIndex or math.huge)
    end)
    return hits[1].opt
end

function QuestToolsModule:PickQuestGossipOption()
    local options = C_GossipInfo.GetOptions()
    if not options then return nil end
    local list = {}
    for _, o in pairs(options) do
        list[#list + 1] = o
    end
    table.sort(list, function(a, b)
        return (a.orderIndex or math.huge) < (b.orderIndex or math.huge)
    end)
    local texts = self:GetGossipDisplayedButtonTexts()
    local byOrder = function(a, b)
        return (a.orderIndex or math.huge) < (b.orderIndex or math.huge)
    end
    local flagHits = {}
    for i, opt in ipairs(list) do
        if self:IsGossipOptionChoosable(opt) and HasQuestLabelPrependFlag(opt) then
            flagHits[#flagHits + 1] = { index = i, opt = opt }
        end
    end
    if #flagHits == 0 then return nil end
    return ResolveIndexedGossipHits(flagHits, texts, byOrder)
end

function QuestToolsModule:TryAutoGossip()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return false end
    if IsShiftKeyDown() then return false end
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return false end
    local gf = _G.GossipFrame
    if gf and not gf:IsShown() then return false end

    local opt = self:PickQuestGossipOption()
    if not opt then return false end
    local name = opt.name or opt.title
    if opt.gossipOptionID ~= nil then
        local id = opt.gossipOptionID
        local ok = pcall(C_GossipInfo.SelectOption, id, name)
        if not ok then
            ok = pcall(C_GossipInfo.SelectOption, id)
        end
        return ok
    elseif opt.orderIndex ~= nil and C_GossipInfo.SelectOptionByIndex then
        local idx = opt.orderIndex
        local ok = pcall(C_GossipInfo.SelectOptionByIndex, idx, name)
        if not ok then
            ok = pcall(C_GossipInfo.SelectOptionByIndex, idx)
        end
        return ok
    end
    return false
end

function QuestToolsModule:ScheduleGossipRetries()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return end
    if IsShiftKeyDown() then return end
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return end

    self._gossipRetryToken = (self._gossipRetryToken or 0) + 1
    local token = self._gossipRetryToken
    local attempt = 0
    local maxAttempts = 24

    local function step()
        if token ~= self._gossipRetryToken then return end
        if not GetToggle("auto_gossip") then return end
        if IsShiftKeyDown() then return end
        local gf = _G.GossipFrame
        if gf and not gf:IsShown() then return end
        attempt = attempt + 1
        if self:TryAutoGossip() then return end
        if attempt < maxAttempts then
            C_Timer.After(0.05, step)
        end
    end

    C_Timer.After(0, step)
end

function QuestToolsModule:OnGossipOpen()
    if not ns.ModuleRegistry:IsEnabled("questtools") or not GetToggle("auto_gossip") then return end
    if IsShiftKeyDown() then return end
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return end
    self:HookGossipFrameShow()
    self:ScheduleGossipRetries()
end

function QuestToolsModule:HookGossipFrameShow()
    if self._gossipHooked then return end
    local gf = _G.GossipFrame
    if not gf or not gf.HookScript then return end
    self._gossipHooked = true
    gf:HookScript("OnShow", function()
        QuestToolsModule:OnGossipOpen()
    end)
end

function QuestToolsModule:InitGossip()
    if self._gossipFrame then return end
    self._gossipFrame = CreateFrame("Frame", "OneWoW_QoL_QuestGossip")
    self._gossipFrame:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_SHOW" then
            self:OnGossipOpen()
        end
    end)
    self:HookGossipFrameShow()
end

function QuestToolsModule:RegisterGossipEvents()
    if not self._gossipFrame then return end
    self._gossipFrame:RegisterEvent("GOSSIP_SHOW")
end

function QuestToolsModule:UnregisterGossipEvents()
    if not self._gossipFrame then return end
    self._gossipFrame:UnregisterEvent("GOSSIP_SHOW")
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
    self:InitGossip()
    self:InitRewardPicker()

    C_Timer.After(0, function()
        QuestToolsModule:HookGossipFrameShow()
    end)

    self._acceptFrame:RegisterEvent("QUEST_DETAIL")
    self._acceptFrame:RegisterEvent("QUEST_GREETING")
    self._turninFrame:RegisterEvent("QUEST_PROGRESS")
    self._turninFrame:RegisterEvent("QUEST_COMPLETE")
    if GetToggle("auto_gossip") then
        self:RegisterGossipEvents()
    end
end

function QuestToolsModule:OnDisable()
    if self._acceptFrame then self._acceptFrame:UnregisterAllEvents() end
    if self._turninFrame then self._turninFrame:UnregisterAllEvents() end
    self:UnregisterGossipEvents()
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
    elseif toggleId == "auto_gossip" then
        if value then
            self:RegisterGossipEvents()
        else
            self:UnregisterGossipEvents()
        end
    end
end

ns.QuestToolsModule = QuestToolsModule

_G.OneWoW_QoL_DebugGossipDisplayed = function()
    QuestToolsModule:DebugPrintGossipApiVsUi()
end
