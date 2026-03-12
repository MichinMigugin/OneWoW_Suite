-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/lfgpanel/lfgpanel.lua
local addonName, ns = ...

local function GetDB()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global or not addon.db.global.modules then return nil end
    if not addon.db.global.modules["lfgpanel"] then
        addon.db.global.modules["lfgpanel"] = {}
    end
    return addon.db.global.modules["lfgpanel"]
end

local function GetShowPanel()
    return ns.ModuleRegistry:GetToggleValue("lfgpanel", "show_panel")
end

local function GetFilterResults()
    return ns.ModuleRegistry:GetToggleValue("lfgpanel", "filter_results")
end

ns.LFGGetDB = GetDB
ns.LFGGetShowPanel = GetShowPanel
ns.LFGGetFilterResults = GetFilterResults

local DIFFICULTY_OPTIONS = {
    { key = 14, label = "LFGPANEL_DIFFICULTY_NORMAL" },
    { key = 15, label = "LFGPANEL_DIFFICULTY_HEROIC" },
    { key = 16, label = "LFGPANEL_DIFFICULTY_MYTHIC" },
    { key = 8,  label = "LFGPANEL_DIFFICULTY_MYTHICPLUS" },
    { key = 17, label = "LFGPANEL_DIFFICULTY_LFR" },
}
ns.LFGDifficultyOptions = DIFFICULTY_OPTIONS

local DIFFICULTY_NAMES = {
    [14] = "LFGPANEL_DIFFICULTY_NORMAL",
    [15] = "LFGPANEL_DIFFICULTY_HEROIC",
    [16] = "LFGPANEL_DIFFICULTY_MYTHIC",
    [23] = "LFGPANEL_DIFFICULTY_MYTHIC",
    [8]  = "LFGPANEL_DIFFICULTY_MYTHICPLUS",
    [7]  = "LFGPANEL_DIFFICULTY_LFR",
    [17] = "LFGPANEL_DIFFICULTY_LFR",
    [1]  = "LFGPANEL_DIFFICULTY_NORMAL",
    [2]  = "LFGPANEL_DIFFICULTY_HEROIC",
}

local DIFFICULTY_FILTER_PATTERNS = {
    [14] = "(Normal)",
    [15] = "(Heroic)",
    [16] = "(Mythic)",
    [8]  = "Keystone",
    [17] = "(Looking for Raid)",
}

local state = {
    dialog = nil,
    toggleButton = nil,
    filterDifficultyId = nil,
    filterActive = false,
    manuallyHidden = false,
}
ns.LFGState = state

local LFGPanel = {}
ns.LFGPanel = LFGPanel

function LFGPanel:GetCurrentLockouts()
    local lockouts = {}
    local numInstances = GetNumSavedInstances()

    for i = 1, numInstances do
        local name, _, reset, difficultyId, locked, extended,
              _, isRaid, _, _,
              numEncounters, encounterProgress = GetSavedInstanceInfo(i)

        if locked and reset > 0 then
            local lockoutData = {
                index = i,
                name = name,
                difficultyId = difficultyId,
                isRaid = isRaid,
                numEncounters = numEncounters,
                encounterProgress = encounterProgress,
                timeLeft = reset,
                extended = extended,
            }

            if self:ShouldShowLockout(lockoutData) then
                table.insert(lockouts, lockoutData)
            end
        end
    end

    table.sort(lockouts, function(a, b)
        if a.isRaid ~= b.isRaid then
            return a.isRaid
        end
        if a.difficultyId ~= b.difficultyId then
            return a.difficultyId > b.difficultyId
        end
        return a.name < b.name
    end)

    return lockouts
end

function LFGPanel:ShouldShowLockout(lockout)
    if state.filterActive and state.filterDifficultyId then
        if lockout.difficultyId ~= state.filterDifficultyId then
            return false
        end
    end
    return true
end

function LFGPanel:FormatTimeRemaining(seconds)
    local L = ns.L
    if seconds <= 0 then
        return L["LFGPANEL_EXPIRED"]
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format(L["LFGPANEL_TIME_DAYS"], days, hours)
    elseif hours > 0 then
        return string.format(L["LFGPANEL_TIME_HOURS"], hours, minutes)
    else
        return string.format(L["LFGPANEL_TIME_MINUTES"], minutes)
    end
end

function LFGPanel:GetDifficultyColor(difficultyId)
    if difficultyId == 16 or difficultyId == 23 then
        return 1.0, 0.5, 0.0
    elseif difficultyId == 15 then
        return 0.0, 1.0, 0.0
    elseif difficultyId == 14 or difficultyId == 1 then
        return 1.0, 1.0, 1.0
    elseif difficultyId == 7 or difficultyId == 17 then
        return 0.0, 0.8, 1.0
    elseif difficultyId == 8 then
        return 0.64, 0.21, 0.93
    else
        return 0.8, 0.8, 0.8
    end
end

function LFGPanel:GetDifficultyLabel(difficultyId)
    local L = ns.L
    local key = DIFFICULTY_NAMES[difficultyId]
    if key then
        return L[key] or key
    end
    return L["UNKNOWN"] or "?"
end

function LFGPanel:SetFilter(difficultyId)
    if difficultyId then
        state.filterActive = true
        state.filterDifficultyId = difficultyId
    else
        state.filterActive = false
        state.filterDifficultyId = nil
    end
end

function LFGPanel:ClearFilter()
    state.filterActive = false
    state.filterDifficultyId = nil
end

function LFGPanel:FilterSearchResults()
    if not GetFilterResults() then return end
    if not state.filterActive or not state.filterDifficultyId then return end
    if not LFGListFrame or not LFGListFrame.SearchPanel then return end

    local isSearchPanelActive = LFGListFrame.activePanel == LFGListFrame.SearchPanel
            and LFGListFrame.SearchPanel:IsVisible()
    if not isSearchPanelActive then return end

    local pattern = DIFFICULTY_FILTER_PATTERNS[state.filterDifficultyId]
    if not pattern then return end

    local results = LFGListFrame.SearchPanel.results
    if not results or #results == 0 then return end

    for idx = #results, 1, -1 do
        local resultID = results[idx]
        local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)

        if searchResultInfo and searchResultInfo.activityIDs and #searchResultInfo.activityIDs > 0 then
            local activityID = searchResultInfo.activityIDs[1]
            local activityInfo = C_LFGList.GetActivityInfoTable(activityID)

            if activityInfo and activityInfo.fullName then
                if not string.find(activityInfo.fullName, pattern, 1, true) then
                    table.remove(results, idx)
                end
            else
                table.remove(results, idx)
            end
        else
            table.remove(results, idx)
        end
    end

    LFGListFrame.SearchPanel.totalResults = #results
    LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
end

function LFGPanel:Toggle()
    if not GetShowPanel() then
        if state.dialog then state.dialog:Hide() end
        return
    end

    if not PVEFrame or not PVEFrame:IsVisible() then
        if state.dialog then state.dialog:Hide() end
        return
    end

    if state.manuallyHidden then
        if state.toggleButton then state.toggleButton:Show() end
        return
    end

    if state.dialog then
        state.dialog:Show()
    end
end

function LFGPanel:SetManuallyHidden(hidden)
    state.manuallyHidden = hidden
    if hidden then
        if state.dialog then state.dialog:Hide() end
        if state.toggleButton and PVEFrame and PVEFrame:IsVisible() then
            state.toggleButton:Show()
        end
    else
        if state.toggleButton then state.toggleButton:Hide() end
        self:Toggle()
    end
end

local LFGPanelModule = {}
ns.LFGPanelModule = LFGPanelModule

LFGPanelModule.id = "lfgpanel"
LFGPanelModule.title = "LFGPANEL_TITLE"
LFGPanelModule.category = "INTERFACE"
LFGPanelModule.description = "LFGPANEL_DESC"
LFGPanelModule.version = "1.0"
LFGPanelModule.author = "MichinMuggin / Ricky"
LFGPanelModule.contact = "https://wow2.xyz/"
LFGPanelModule.link = "https://wow2.xyz/"
LFGPanelModule.toggles = {
    { id = "show_panel", label = "LFGPANEL_SHOW_PANEL", description = "LFGPANEL_SHOW_PANEL_DESC", default = true },
    { id = "filter_results", label = "LFGPANEL_FILTER_RESULTS", description = "LFGPANEL_FILTER_RESULTS_DESC", default = true },
}
LFGPanelModule.defaultEnabled = true

function LFGPanelModule:OnEnable()
    local db = GetDB()
    if not db then return end

    if not self._eventFrame then
        local frame = CreateFrame("Frame", "OneWoW_QoL_LFGPanelEvents")
        self._eventFrame = frame
        frame:SetScript("OnEvent", function(_, event)
            if event == "UPDATE_INSTANCE_INFO" then
                if ns.LFGPanelUI and ns.LFGPanelUI.UpdateDisplay then
                    ns.LFGPanelUI:UpdateDisplay()
                end
            end
        end)
    end
    self._eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")

    if not self._hooksDone then
        self._hooksDone = true

        if _G.LFGListSearchPanel_UpdateResultList then
            hooksecurefunc("LFGListSearchPanel_UpdateResultList", function()
                LFGPanel:FilterSearchResults()
            end)
        end

        local function DelayedToggle()
            C_Timer.After(0.1, function()
                LFGPanel:Toggle()
            end)
        end

        if _G.LFGListSearchPanel_SetCategory then
            hooksecurefunc("LFGListSearchPanel_SetCategory", DelayedToggle)
        end
        if _G.LFGListFrame_SetActivePanel then
            hooksecurefunc("LFGListFrame_SetActivePanel", DelayedToggle)
        end
        if _G.PVEFrame_ShowFrame then
            hooksecurefunc("PVEFrame_ShowFrame", DelayedToggle)
        end

        if PVEFrame then
            PVEFrame:HookScript("OnShow", DelayedToggle)
            PVEFrame:HookScript("OnHide", function()
                if state.dialog then state.dialog:Hide() end
                if state.toggleButton then state.toggleButton:Hide() end
            end)
        end
    end

    C_Timer.After(0.5, function()
        if ns.LFGPanelUI and ns.LFGPanelUI.CreateDialog then
            ns.LFGPanelUI:CreateDialog()
            ns.LFGPanelUI:CreateToggleButton()
        end
    end)

    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if GUI and not self._guiCallbacksRegistered then
        self._guiCallbacksRegistered = true
        local function onSettingsChanged()
            if state.dialog then
                state.dialog:Hide()
                state.dialog = nil
            end
            if state.toggleButton then
                state.toggleButton:Hide()
                state.toggleButton = nil
            end
            C_Timer.After(0.2, function()
                if ns.LFGPanelUI then
                    ns.LFGPanelUI:CreateDialog()
                    ns.LFGPanelUI:CreateToggleButton()
                    LFGPanel:Toggle()
                end
            end)
        end
        GUI:RegisterSettingsCallback("OnThemeChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnLanguageChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnFontChanged", self, onSettingsChanged)
    end
end

function LFGPanelModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterEvent("UPDATE_INSTANCE_INFO")
    end
    if state.dialog then state.dialog:Hide() end
    if state.toggleButton then state.toggleButton:Hide() end
end

function LFGPanelModule:OnToggle(toggleId, value)
    if toggleId == "show_panel" then
        if not value then
            if state.dialog then state.dialog:Hide() end
            if state.toggleButton then state.toggleButton:Hide() end
        else
            LFGPanel:Toggle()
        end
    elseif toggleId == "filter_results" then
        if state.dialog and state.dialog.filterCB then
            state.dialog.filterCB:SetChecked(value)
        end
        if not value then
            if LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsVisible() then
                if _G.LFGListSearchPanel_UpdateResultList then
                    LFGListSearchPanel_UpdateResultList(LFGListFrame.SearchPanel)
                end
            end
        else
            LFGPanel:FilterSearchResults()
        end
    end
end
