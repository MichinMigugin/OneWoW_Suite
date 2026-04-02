local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local STATUS_TEX_OK   = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STATUS_TEX_WARN = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local STATUS_TEX_BAD  = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local originalStates = {}
local pendingStates = {}
local rowElements = {}
local saveReloadBtn = nil
local pendingCountText = nil
local pendingBar = nil

local function IsAddonPendingEnabled(addonName)
    if pendingStates[addonName] ~= nil then
        return pendingStates[addonName]
    end
    return originalStates[addonName] or false
end

local function GetPendingCount()
    local count = 0
    for addonName, newState in pairs(pendingStates) do
        if originalStates[addonName] ~= nil and originalStates[addonName] ~= newState then
            count = count + 1
        end
    end
    return count
end

local function UpdateSaveButton()
    if not pendingBar then return end
    local L = OneWoW.L
    local count = GetPendingCount()
    if count > 0 then
        pendingBar:Show()
        if pendingCountText then
            pendingCountText:SetText(string.format(L["HOME_PENDING_CHANGES"], count))
        end
    else
        pendingBar:Hide()
    end
end

local function UpdateRowVisual(addonName)
    local row = rowElements[addonName]
    if not row then return end
    local L = OneWoW.L
    local isPending = (pendingStates[addonName] ~= nil and pendingStates[addonName] ~= originalStates[addonName])

    if isPending then
        local willBeEnabled = pendingStates[addonName]
        if willBeEnabled then
            row.light:SetTexture(STATUS_TEX_OK)
        else
            row.light:SetTexture(STATUS_TEX_BAD)
        end
        row.light:SetVertexColor(1, 1, 1, 1)
        if row.btn then
            row.btn.text:SetText(willBeEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        end
    else
        if row.originalStatus == "enabled" then
            row.light:SetTexture(STATUS_TEX_OK)
            row.light:SetVertexColor(1, 1, 1, 1)
        elseif row.originalStatus == "warning" then
            row.light:SetTexture(STATUS_TEX_WARN)
            row.light:SetVertexColor(1, 1, 1, 1)
        elseif row.originalStatus == "disabled" then
            row.light:SetTexture(STATUS_TEX_BAD)
            row.light:SetVertexColor(1, 1, 1, 1)
        end
        if row.btn then
            local isActive = (row.originalStatus == "enabled" or row.originalStatus == "warning")
            row.btn.text:SetText(isActive and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        end
    end
end

local function ToggleAddon(addonName, cascadeAddons)
    local currentlyEnabled = IsAddonPendingEnabled(addonName)
    local newState = not currentlyEnabled

    if newState then
        C_AddOns.EnableAddOn(addonName)
    else
        C_AddOns.DisableAddOn(addonName)
    end
    pendingStates[addonName] = newState
    UpdateRowVisual(addonName)

    if cascadeAddons then
        for _, name in ipairs(cascadeAddons) do
            if C_AddOns.DoesAddOnExist(name) then
                if newState then
                    C_AddOns.EnableAddOn(name)
                else
                    C_AddOns.DisableAddOn(name)
                end
                pendingStates[name] = newState
                UpdateRowVisual(name)
            end
        end
    end

    UpdateSaveButton()
end

function GUI:HasPendingHomeChanges()
    return GetPendingCount() > 0
end

function GUI:SaveAndReloadHome()
    C_AddOns.SaveAddOns()
    C_UI.Reload()
end

function GUI:DiscardHomeChanges()
    for addonName, _ in pairs(pendingStates) do
        local orig = originalStates[addonName]
        if orig ~= nil then
            if orig then
                C_AddOns.EnableAddOn(addonName)
            else
                C_AddOns.DisableAddOn(addonName)
            end
        end
    end
    pendingStates = {}
    for addonName, _ in pairs(rowElements) do
        UpdateRowVisual(addonName)
    end
    UpdateSaveButton()
end

local function GetAddonStatus(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then
        return "not_found", nil
    end
    local enableState = C_AddOns.GetAddOnEnableState(addonName)
    if enableState == 0 then
        return "disabled", nil
    end
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(addonName)
    if not loadable and reason and reason ~= "DISABLED" then
        return "warning", reason
    end
    return "enabled", nil
end

local function GetReasonText(reason)
    local L = OneWoW.L
    local map = {
        ["DEP_NOT_LOADED"]        = L["HOME_REASON_DEP_NOT_LOADED"],
        ["DEP_NOT_DEMAND_LOADED"] = L["HOME_REASON_DEP_DEMAND"],
        ["INTERFACE_VERSION"]     = L["HOME_REASON_INTERFACE_VERSION"],
        ["CORRUPT"]               = L["HOME_REASON_CORRUPT"],
        ["MISSING"]               = L["HOME_REASON_MISSING"],
    }
    return map[reason] or L["HOME_REASON_UNKNOWN"]
end

function GUI:CreateHomeTab(parent)
    local L = OneWoW.L
    local Constants = OneWoW.Constants

    originalStates = {}
    pendingStates = {}
    rowElements = {}

    if not StaticPopupDialogs["ONEWOW_UNSAVED_CHANGES"] then
        StaticPopupDialogs["ONEWOW_UNSAVED_CHANGES"] = {
            text         = L["HOME_UNSAVED_CONFIRM"],
            button1      = L["HOME_SAVE_RELOAD"],
            button2      = L["CANCEL"],
            button3      = L["HOME_DISCARD"],
            OnAccept     = function()
                GUI:SaveAndReloadHome()
            end,
            OnCancel     = function()
                GUI._pendingAction = nil
            end,
            OnAlt        = function()
                GUI:DiscardHomeChanges()
                if GUI._pendingAction then
                    GUI._pendingAction()
                    GUI._pendingAction = nil
                end
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local function CreateModuleRow(panel, localeKey, displayName, addonName, rowY, cascadeAddons, noButton)
        local status, reason = GetAddonStatus(addonName)
        local localizedName  = L[localeKey] or displayName
        local version        = OneWoW_GUI:GetAddonVersion(addonName)

        if status ~= "not_found" then
            local enableState = C_AddOns.GetAddOnEnableState(addonName)
            originalStates[addonName] = (enableState ~= 0)
        end

        local light = panel:CreateTexture(nil, "ARTWORK")
        light:SetSize(14, 14)
        light:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, rowY - 1)

        if status == "enabled" then
            light:SetTexture(STATUS_TEX_OK)
        elseif status == "warning" then
            light:SetTexture(STATUS_TEX_WARN)
        elseif status == "disabled" then
            light:SetTexture(STATUS_TEX_BAD)
        else
            light:SetTexture(STATUS_TEX_BAD)
            light:SetVertexColor(0.35, 0.35, 0.35, 0.6)
        end

        local lightHit = CreateFrame("Frame", nil, panel)
        lightHit:SetSize(16, 16)
        lightHit:SetPoint("CENTER", light, "CENTER")
        lightHit:EnableMouse(true)
        lightHit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if status == "enabled" then
                GameTooltip:SetText(L["HOME_STATUS_ENABLED"], 0.2, 0.8, 0.2)
            elseif status == "warning" then
                GameTooltip:SetText(L["HOME_STATUS_WARNING"], 1, 0.82, 0)
                GameTooltip:AddLine(GetReasonText(reason), 1, 1, 1, true)
            elseif status == "disabled" then
                GameTooltip:SetText(L["HOME_STATUS_DISABLED"], 0.8, 0.2, 0.2)
            else
                GameTooltip:SetText(L["HOME_STATUS_NOT_FOUND"], 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        lightHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local nameText = OneWoW_GUI:CreateFS(panel, 12)
        nameText:SetPoint("LEFT", light, "RIGHT", 8, 0)
        nameText:SetWidth(120)
        nameText:SetText(localizedName)
        nameText:SetJustifyH("LEFT")
        if status == "not_found" then
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        if version then
            local verText = OneWoW_GUI:CreateFS(panel, 10)
            verText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
            verText:SetText(version)
            verText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local toggleBtn = nil
        if not noButton then
            local isActive   = (status == "enabled" or status == "warning")
            local btnLabel   = isActive and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"]

            toggleBtn = OneWoW_GUI:CreateFitTextButton(panel, { text = btnLabel, height = 20 })
            toggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, rowY - 2)

            if status == "not_found" then
                toggleBtn:Disable()
            else
                toggleBtn:SetScript("OnClick", function()
                    ToggleAddon(addonName, cascadeAddons)
                end)
            end
        end

        if status ~= "not_found" then
            rowElements[addonName] = {
                light = light,
                btn = toggleBtn,
                originalStatus = status,
            }
        end
    end

    local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_HomeScroll" })
    content:SetHeight(1200)

    pendingBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pendingBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    pendingBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    pendingBar:SetHeight(34)
    pendingBar:SetFrameLevel(parent:GetFrameLevel() + 10)
    pendingBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    pendingBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    pendingBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    pendingBar:Hide()

    pendingCountText = OneWoW_GUI:CreateFS(pendingBar, 12)
    pendingCountText:SetPoint("LEFT", pendingBar, "LEFT", 15, 0)
    pendingCountText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    saveReloadBtn = OneWoW_GUI:CreateFitTextButton(pendingBar, { text = L["HOME_SAVE_RELOAD"], height = 22 })
    saveReloadBtn:SetPoint("RIGHT", pendingBar, "RIGHT", -10, 0)
    saveReloadBtn:SetScript("OnClick", function()
        GUI:SaveAndReloadHome()
    end)

    local yOffset = -30

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(128, 128)
    logo:SetPoint("TOP", content, "TOP", 0, yOffset)
    logo:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")
    yOffset = yOffset - 150

    local versionLabel = OneWoW_GUI:CreateFS(content, 16)
    versionLabel:SetPoint("TOP", content, "TOP", 0, yOffset)
    versionLabel:SetText("OneWoW " .. (L["HOME_VERSION"] or "Version") .. " " .. (OneWoW_GUI:GetAddonVersion("OneWoW") or ""))
    versionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 35

    local divider1 = content:CreateTexture(nil, "ARTWORK")
    divider1:SetHeight(1)
    divider1:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    divider1:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)
    divider1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 20

    local discordRow = CreateFrame("Frame", nil, content)
    discordRow:SetHeight(28)
    discordRow:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    discordRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)

    local discordLabel = OneWoW_GUI:CreateFS(discordRow, 12)
    discordLabel:SetPoint("LEFT", discordRow, "LEFT", 0, 0)
    discordLabel:SetText((L["HOME_DISCORD"] or "Discord") .. ":")
    discordLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local discordBox = OneWoW_GUI:CreateEditBox(discordRow, { name = "OneWoW_DiscordLink", width = 350, height = 24 })
    discordBox:SetPoint("LEFT", discordLabel, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    discordBox:SetText(L["HOME_DISCORD_LINK"] or "https://discord.gg/6vnabDVnDu")
    discordBox:SetAutoFocus(false)
    discordBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    discordBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local supportLabel = OneWoW_GUI:CreateFS(discordRow, 12)
    supportLabel:SetPoint("RIGHT", discordRow, "RIGHT", -358, 0)
    supportLabel:SetText((L["HOME_SUPPORT"] or "Support OneWoW") .. ":")
    supportLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local supportBox = OneWoW_GUI:CreateEditBox(discordRow, { name = "OneWoW_SupportLink", width = 350, height = 24 })
    supportBox:SetPoint("LEFT", supportLabel, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    supportBox:SetText(L["HOME_SUPPORT_LINK"] or "https://buymeacoffee.com/migugin")
    supportBox:SetAutoFocus(false)
    supportBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    supportBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    yOffset = yOffset - 38

    local thanksBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    thanksBar:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, yOffset)
    thanksBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    thanksBar:SetHeight(30)
    thanksBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    thanksBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    thanksBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local thanksTitle = OneWoW_GUI:CreateFS(thanksBar, 12)
    thanksTitle:SetPoint("LEFT", thanksBar, "LEFT", 15, 0)
    thanksTitle:SetText(L["HOME_SPECIAL_THANKS"] or "Special Thanks")
    thanksTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local thanksNames = OneWoW_GUI:CreateFS(thanksBar, 12)
    thanksNames:SetPoint("LEFT", thanksTitle, "RIGHT", 12, 0)
    thanksNames:SetText(L["HOME_THANKS_NAMES"] or "Name 1, Name 2, Name 3")
    thanksNames:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 42

    local splitContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    splitContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    splitContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local modHDiv = splitContainer:CreateTexture(nil, "ARTWORK")
    modHDiv:SetHeight(1)
    modHDiv:SetPoint("TOPLEFT",  splitContainer, "TOPLEFT",  8, -36)
    modHDiv:SetPoint("TOPRIGHT", splitContainer, "TOPRIGHT", -8, -36)
    modHDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local modVDiv = splitContainer:CreateTexture(nil, "ARTWORK")
    modVDiv:SetWidth(1)
    modVDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local leftPanel  = CreateFrame("Frame", nil, splitContainer)
    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    local modVDivBottomY = nil

    local function LayoutColumns()
        local w = splitContainer:GetWidth()
        if not w or w <= 0 then return end
        local col = math.floor(w / 2)

        leftPanel:ClearAllPoints()
        leftPanel:SetPoint("TOPLEFT",    splitContainer, "TOPLEFT",    0, -40)
        leftPanel:SetPoint("BOTTOMLEFT", splitContainer, "BOTTOMLEFT", 0,   0)
        leftPanel:SetWidth(col)

        rightPanel:ClearAllPoints()
        rightPanel:SetPoint("TOPLEFT",     splitContainer, "TOPLEFT",     col, -40)
        rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT",   0,   0)

        modVDiv:ClearAllPoints()
        modVDiv:SetPoint("TOPLEFT",    splitContainer, "TOPLEFT",    col, -40)
        if modVDivBottomY then
            modVDiv:SetPoint("BOTTOMLEFT", splitContainer, "TOPLEFT", col, modVDivBottomY + 4)
        else
            modVDiv:SetPoint("BOTTOMLEFT", splitContainer, "BOTTOMLEFT", col, 8)
        end
    end

    splitContainer:HookScript("OnSizeChanged", LayoutColumns)
    C_Timer.After(0, LayoutColumns)

    -- === LEFT: Required Addons ===
    local requiredTitle = OneWoW_GUI:CreateFS(leftPanel, 16)
    requiredTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    requiredTitle:SetText(L["HOME_REQUIRED_ADDONS"])
    requiredTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local modY = -38
    CreateModuleRow(leftPanel, "MODULE_ONEWOW", "OneWoW", "OneWoW", modY, nil, true)
    modY = modY - 28
    CreateModuleRow(leftPanel, "MODULE_GUI", "OneWoW GUI", "OneWoW_GUI", modY, nil, true)
    modY = modY - 28

    local leftDiv1Y = modY - 4
    local leftDiv1 = leftPanel:CreateTexture(nil, "ARTWORK")
    leftDiv1:SetHeight(1)
    leftDiv1:SetPoint("TOPLEFT",  leftPanel, "TOPLEFT",  8, leftDiv1Y)
    leftDiv1:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -8, leftDiv1Y)
    leftDiv1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local detectedTitleY = leftDiv1Y - 18
    local detectedTitle = OneWoW_GUI:CreateFS(leftPanel, 16)
    detectedTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, detectedTitleY)
    detectedTitle:SetText(L["HOME_DETECTED_MODULES"])
    detectedTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    modY = detectedTitleY - 24
    local moduleChecks = {
        { key = "MODULE_ALTTRACKER",    displayName = "AltTracker",      addonName = "OneWoW_AltTracker",    cascade = { "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Auctions", "OneWoW_AltTracker_Character", "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame", "OneWoW_AltTracker_Professions", "OneWoW_AltTracker_Storage" } },
        { key = "MODULE_CATALOG",       displayName = "Catalog",         addonName = "OneWoW_Catalog",       cascade = { "OneWoW_CatalogData_Journal", "OneWoW_CatalogData_Quests", "OneWoW_CatalogData_Tradeskills", "OneWoW_CatalogData_Vendors" } },
        { key = "MODULE_NOTES",         displayName = "Notes",           addonName = "OneWoW_Notes" },
        { key = "MODULE_QOL",           displayName = "Quality of Life", addonName = "OneWoW_QoL" },
    }

    for _, mod in ipairs(moduleChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.displayName, mod.addonName, modY, mod.cascade)
        modY = modY - 28
    end

    local leftDiv2Y = modY - 4
    local leftDiv2 = leftPanel:CreateTexture(nil, "ARTWORK")
    leftDiv2:SetHeight(1)
    leftDiv2:SetPoint("TOPLEFT",  leftPanel, "TOPLEFT",  8, leftDiv2Y)
    leftDiv2:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -8, leftDiv2Y)
    leftDiv2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local standaloneTitleY = leftDiv2Y - 18
    local standaloneTitle = OneWoW_GUI:CreateFS(leftPanel, 16)
    standaloneTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, standaloneTitleY)
    standaloneTitle:SetText(L["HOME_STANDALONE_ADDONS"])
    standaloneTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    modY = standaloneTitleY - 24
    local standaloneChecks = {
        { key = "MODULE_BAGS",         displayName = "Bags",           addonName = "OneWoW_Bags" },
        { key = "MODULE_DIRECTDEPOSIT", displayName = "Direct Deposit", addonName = "OneWoW_DirectDeposit" },
        { key = "MODULE_SHOPPINGLIST",  displayName = "Shopping List",  addonName = "OneWoW_ShoppingList" },
    }

    for _, mod in ipairs(standaloneChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.displayName, mod.addonName, modY, mod.cascade)
        modY = modY - 28
    end

    local leftEndModY = modY

    -- === RIGHT: Detected Data Modules ===
    local dataTitle = OneWoW_GUI:CreateFS(rightPanel, 16)
    dataTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    dataTitle:SetText(L["HOME_DETECTED_DATA_MODULES"])
    dataTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local rightY = -38

    local atSubHeader = OneWoW_GUI:CreateFS(rightPanel, 12)
    atSubHeader:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, rightY)
    atSubHeader:SetText(L["HOME_ALTTRACKER_MODULES"])
    atSubHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightY = rightY - 22

    local dataModuleChecks = {
        { key = "DATA_MOD_ACCOUNTING",  displayName = "Accounting",  addonName = "OneWoW_AltTracker_Accounting" },
        { key = "DATA_MOD_AUCTIONS",    displayName = "Auctions",    addonName = "OneWoW_AltTracker_Auctions" },
        { key = "DATA_MOD_CHARACTER",   displayName = "Character",   addonName = "OneWoW_AltTracker_Character" },
        { key = "DATA_MOD_COLLECTIONS", displayName = "Collections", addonName = "OneWoW_AltTracker_Collections" },
        { key = "DATA_MOD_ENDGAME",     displayName = "EndGame",     addonName = "OneWoW_AltTracker_Endgame" },
        { key = "DATA_MOD_PROFESSIONS", displayName = "Professions", addonName = "OneWoW_AltTracker_Professions" },
        { key = "DATA_MOD_STORAGE",     displayName = "Storage",     addonName = "OneWoW_AltTracker_Storage" },
    }

    for _, mod in ipairs(dataModuleChecks) do
        CreateModuleRow(rightPanel, mod.key, mod.displayName, mod.addonName, rightY)
        rightY = rightY - 28
    end

    local rightSectDivY = rightY - 4
    local rightSectDiv = rightPanel:CreateTexture(nil, "ARTWORK")
    rightSectDiv:SetHeight(1)
    rightSectDiv:SetPoint("TOPLEFT",  rightPanel, "TOPLEFT",  8, rightSectDivY)
    rightSectDiv:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, rightSectDivY)
    rightSectDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local catSubHeaderY = rightSectDivY - 18
    local catSubHeader = OneWoW_GUI:CreateFS(rightPanel, 12)
    catSubHeader:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, catSubHeaderY)
    catSubHeader:SetText(L["HOME_CATALOG_DATA_MODULES"])
    catSubHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightY = catSubHeaderY - 22

    local catalogDataChecks = {
        { key = "CAT_MOD_JOURNAL",     displayName = "Journal",     addonName = "OneWoW_CatalogData_Journal" },
        { key = "CAT_MOD_QUESTS",      displayName = "Quests",      addonName = "OneWoW_CatalogData_Quests" },
        { key = "CAT_MOD_TRADESKILLS", displayName = "Tradeskills", addonName = "OneWoW_CatalogData_Tradeskills" },
        { key = "CAT_MOD_VENDORS",     displayName = "Vendors",     addonName = "OneWoW_CatalogData_Vendors" },
    }

    for _, mod in ipairs(catalogDataChecks) do
        CreateModuleRow(rightPanel, mod.key, mod.displayName, mod.addonName, rightY)
        rightY = rightY - 28
    end

    local leftDepth  = math.abs(leftEndModY) + 4
    local rightDepth = math.abs(rightY) + 4
    local columnsDepth = 40 + math.max(leftDepth, rightDepth)

    local utilFullDivY = -(columnsDepth + 4)
    modVDivBottomY = utilFullDivY
    local utilFullDiv = splitContainer:CreateTexture(nil, "ARTWORK")
    utilFullDiv:SetHeight(1)
    utilFullDiv:SetPoint("TOPLEFT",  splitContainer, "TOPLEFT",  8, utilFullDivY)
    utilFullDiv:SetPoint("TOPRIGHT", splitContainer, "TOPRIGHT", -8, utilFullDivY)
    utilFullDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local utilTitleY = utilFullDivY - 18
    local utilTitle = OneWoW_GUI:CreateFS(splitContainer, 16)
    utilTitle:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 15, utilTitleY)
    utilTitle:SetText(L["HOME_UTILITIES"])
    utilTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local utilLeftPanel = CreateFrame("Frame", nil, splitContainer)
    local utilRightPanel = CreateFrame("Frame", nil, splitContainer)

    local function LayoutUtilColumns()
        local w = splitContainer:GetWidth()
        if not w or w <= 0 then return end
        local col = math.floor(w / 2)
        local utilRowY = utilTitleY - 24

        utilLeftPanel:ClearAllPoints()
        utilLeftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, utilRowY)
        utilLeftPanel:SetWidth(col)
        utilLeftPanel:SetHeight(32)

        utilRightPanel:ClearAllPoints()
        utilRightPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", col, utilRowY)
        utilRightPanel:SetWidth(col)
        utilRightPanel:SetHeight(32)
    end

    splitContainer:HookScript("OnSizeChanged", LayoutUtilColumns)
    C_Timer.After(0, LayoutUtilColumns)

    CreateModuleRow(utilLeftPanel,  "MODULE_DEVTOOLS",  "DevTools",  "OneWoW_Utility_DevTool",  -4)
    CreateModuleRow(utilRightPanel, "MODULE_EXTRACTOR", "Extractor", "OneWoW_Utility_Extractor", -4)

    local containerH = columnsDepth + 8 + 18 + 24 + 32 + 20
    splitContainer:SetHeight(containerH)

    yOffset = yOffset - containerH - 20

    local cmdContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    cmdContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    cmdContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    cmdContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    cmdContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    cmdContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdTitle = OneWoW_GUI:CreateFS(cmdContainer, 16)
    cmdTitle:SetPoint("TOPLEFT", cmdContainer, "TOPLEFT", 15, -12)
    cmdTitle:SetText(L["HOME_COMMANDS"] or "Available Commands")
    cmdTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cmdHDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdHDiv:SetHeight(1)
    cmdHDiv:SetPoint("TOPLEFT",  cmdContainer, "TOPLEFT",  8, -36)
    cmdHDiv:SetPoint("TOPRIGHT", cmdContainer, "TOPRIGHT", -8, -36)
    cmdHDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdVDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdVDiv:SetWidth(1)
    cmdVDiv:SetPoint("TOP",    cmdContainer, "TOP",    0, -40)
    cmdVDiv:SetPoint("BOTTOM", cmdContainer, "BOTTOM", 0, 8)
    cmdVDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local cmdLeft = CreateFrame("Frame", nil, cmdContainer)
    cmdLeft:SetPoint("TOPLEFT",    cmdContainer, "TOPLEFT", 0, -40)
    cmdLeft:SetPoint("BOTTOMRIGHT", cmdContainer, "BOTTOM",  0, 0)

    local cmdRight = CreateFrame("Frame", nil, cmdContainer)
    cmdRight:SetPoint("TOPLEFT",    cmdContainer, "TOP",         0, -40)
    cmdRight:SetPoint("BOTTOMRIGHT", cmdContainer, "BOTTOMRIGHT", 0, 0)

    local function RenderSets(panel, sets)
        local pY = -8
        for _, set in ipairs(sets) do
            if set.comingSoon then
                local hdr = OneWoW_GUI:CreateFS(panel, 10)
                hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, pY)
                hdr:SetText(set.header)
                hdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                local soon = OneWoW_GUI:CreateFS(panel, 10)
                soon:SetPoint("LEFT", hdr, "RIGHT", 6, 0)
                soon:SetText("(" .. (L["HOME_MINIMAP_PLACEHOLDER"] or "Coming Soon") .. ")")
                soon:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                pY = pY - 26
            else
                local show = set.always or (_G[set.global] ~= nil)
                if show then
                    local hdr = OneWoW_GUI:CreateFS(panel, 10)
                    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, pY)
                    hdr:SetText(set.header)
                    hdr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    pY = pY - 18
                    for _, cmdInfo in ipairs(set.commands) do
                        local cmdText = OneWoW_GUI:CreateFS(panel, 12)
                        cmdText:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, pY)
                        cmdText:SetText("|cFFFFFFFF" .. cmdInfo.cmd .. "|r")
                        cmdText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        local descText = OneWoW_GUI:CreateFS(panel, 12)
                        descText:SetPoint("TOPLEFT", panel, "TOPLEFT", 210, pY)
                        descText:SetText("- " .. cmdInfo.desc)
                        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        pY = pY - 20
                    end
                    pY = pY - 8
                end
            end
        end
        return pY
    end

    local leftSets = {
        {
            always = true,
            header = "OneWoW",
            commands = {
                { cmd = "/1w, /ow, /one, /onewow", desc = L["CMD_TOGGLE_ONEWOW"] or "Toggle OneWoW" },
            },
        },
        {
            global = "OneWoW_Notes",
            header = "Notes",
            commands = {
                { cmd = "/1wn, /own, /onewownotes", desc = L["CMD_OPEN_NOTES"] or "Open Notes" },
            },
        },
        {
            global = "OneWoW_AltTracker",
            header = "AltTracker",
            commands = {
                { cmd = "/1wat, /owat, /onewowat", desc = L["CMD_OPEN_ALTTRACKER"] or "Open AltTracker" },
            },
        },
        {
            comingSoon = true,
            header = "Catalog",
        },
        {
            global = "OneWoW_QoL",
            header = "QoL",
            commands = {
                { cmd = "/1wqol, /owqol, /onewowqol", desc = L["CMD_OPEN_QOL"] or "Toggle QoL" },
            },
        },
    }

    local rightSets = {
        {
            global = "OneWoW_DirectDeposit",
            header = "Direct Deposit",
            commands = {
                { cmd = "/1wdd, /dd, /directdeposit, /directdep", desc = L["CMD_OPEN_DD"]       or "Open Direct Deposit" },
                { cmd = "  /ddeposit",                             desc = L["CMD_MANUAL_DEPOSIT"] or "Manual deposit" },
                { cmd = "  /ddeposit pause|stop",                  desc = L["CMD_DEPOSIT_PAUSE"]  or "Pause deposit" },
                { cmd = "  /ddeposit clean",                       desc = L["CMD_DEPOSIT_CLEAN"]  or "Clean item list" },
            },
        },
        {
            global = "OneWoW_ShoppingList",
            header = "Shopping List",
            commands = {
                { cmd = "/1wsl, /owsl, /shoppinglist", desc = L["CMD_OPEN_SL"] or "Open Shopping List" },
                { cmd = "  /owsl add <id>",            desc = L["CMD_SL_ADD"]  or "Add item to active list" },
            },
        },
        {
            global = "OneWoW_UtilityDevTool",
            header = "DevTools",
            commands = {
                { cmd = "/1wdt, /dt, /devtool, /devtools", desc = L["CMD_OPEN_DEVTOOLS"] or "Open DevTools" },
            },
        },
    }

    local leftEndY  = RenderSets(cmdLeft,  leftSets)
    local rightEndY = RenderSets(cmdRight, rightSets)

    local cmdHeight = 40 + math.max(math.abs(leftEndY), math.abs(rightEndY)) + 15
    cmdContainer:SetHeight(cmdHeight)

    yOffset = yOffset - cmdHeight - 20

    content:SetHeight(math.abs(yOffset) + 50)
end
