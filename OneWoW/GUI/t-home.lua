local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local function T(key)
    if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
        return unpack(OneWoW.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW.Constants and OneWoW.Constants.SPACING then
        return OneWoW.Constants.SPACING[key] or 8
    end
    return 8
end

local STATUS_TEX_OK   = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STATUS_TEX_WARN = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local STATUS_TEX_BAD  = "Interface\\RaidFrame\\ReadyCheck-NotReady"

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

local function GetAddonVersion(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then return nil end
    return C_AddOns.GetAddOnMetadata(addonName, "Version")
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

    if not StaticPopupDialogs["ONEWOW_CONFIRM_DISABLE_ADDON"] then
        StaticPopupDialogs["ONEWOW_CONFIRM_DISABLE_ADDON"] = {
            text         = "%s",
            button1      = L["FEATURE_DISABLE_BTN"],
            button2      = L["CANCEL"],
            OnAccept     = function(self, data)
                if data and data.addonName then
                    C_AddOns.DisableAddOn(data.addonName)
                    if data.cascade then
                        for _, name in ipairs(data.cascade) do
                            C_AddOns.DisableAddOn(name)
                        end
                    end
                    C_AddOns.SaveAddOns()
                    C_UI.Reload()
                end
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    if not StaticPopupDialogs["ONEWOW_CONFIRM_ENABLE_ADDON"] then
        StaticPopupDialogs["ONEWOW_CONFIRM_ENABLE_ADDON"] = {
            text         = "%s",
            button1      = L["FEATURE_ENABLE_BTN"],
            button2      = L["CANCEL"],
            OnAccept     = function(self, data)
                if data and data.addonName then
                    C_AddOns.EnableAddOn(data.addonName)
                    if data.cascade then
                        for _, name in ipairs(data.cascade) do
                            C_AddOns.EnableAddOn(name)
                        end
                    end
                    C_AddOns.SaveAddOns()
                    C_UI.Reload()
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
        local version        = GetAddonVersion(addonName)

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

        local nameText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", light, "RIGHT", 8, 0)
        nameText:SetWidth(120)
        nameText:SetText(localizedName)
        nameText:SetJustifyH("LEFT")
        if status == "not_found" then
            nameText:SetTextColor(T("TEXT_MUTED"))
        else
            nameText:SetTextColor(T("TEXT_PRIMARY"))
        end

        if version then
            local verText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            verText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
            verText:SetText(version)
            verText:SetTextColor(T("TEXT_MUTED"))
        end

        if not noButton then
            local isActive   = (status == "enabled" or status == "warning")
            local btnLabel   = isActive and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"]
            local dialogKey  = isActive and "ONEWOW_CONFIRM_DISABLE_ADDON" or "ONEWOW_CONFIRM_ENABLE_ADDON"
            local confirmKey = isActive and "HOME_ADDON_DISABLE_CONFIRM" or "HOME_ADDON_ENABLE_CONFIRM"

            local toggleBtn = GUI:CreateButton(nil, panel, btnLabel, 90, 20)
            toggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, rowY - 2)

            if status == "not_found" then
                toggleBtn:Disable()
            else
                toggleBtn:SetScript("OnClick", function()
                    local msg = string.format(L[confirmKey], localizedName)
                    StaticPopup_Show(dialogKey, msg, nil, { addonName = addonName, cascade = cascadeAddons })
                end)
            end
        end
    end

    local scrollFrame, content = GUI:CreateScrollFrame("OneWoW_HomeScroll", parent)
    content:SetHeight(1200)

    local yOffset = -30

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(128, 128)
    logo:SetPoint("TOP", content, "TOP", 0, yOffset)
    logo:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")
    yOffset = yOffset - 150

    local versionLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    versionLabel:SetPoint("TOP", content, "TOP", 0, yOffset)
    versionLabel:SetText("OneWoW " .. (L["HOME_VERSION"] or "Version") .. " " .. (GetAddonVersion("OneWoW") or ""))
    versionLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - 35

    local divider1 = content:CreateTexture(nil, "ARTWORK")
    divider1:SetHeight(1)
    divider1:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    divider1:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)
    divider1:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 20

    local discordRow = CreateFrame("Frame", nil, content)
    discordRow:SetHeight(28)
    discordRow:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    discordRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)

    local discordLabel = discordRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    discordLabel:SetPoint("LEFT", discordRow, "LEFT", 0, 0)
    discordLabel:SetText((L["HOME_DISCORD"] or "Discord") .. ":")
    discordLabel:SetTextColor(T("TEXT_SECONDARY"))

    local discordBox = GUI:CreateEditBox("OneWoW_DiscordLink", discordRow, 350, 24)
    discordBox:SetPoint("LEFT", discordLabel, "RIGHT", S("SM"), 0)
    discordBox:SetText(L["HOME_DISCORD_LINK"] or "https://discord.gg/6vnabDVnDu")
    discordBox:SetAutoFocus(false)
    discordBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    discordBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    local supportLabel = discordRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    supportLabel:SetPoint("RIGHT", discordRow, "RIGHT", -358, 0)
    supportLabel:SetText((L["HOME_SUPPORT"] or "Support OneWoW") .. ":")
    supportLabel:SetTextColor(T("TEXT_SECONDARY"))

    local supportBox = GUI:CreateEditBox("OneWoW_SupportLink", discordRow, 350, 24)
    supportBox:SetPoint("LEFT", supportLabel, "RIGHT", S("SM"), 0)
    supportBox:SetText(L["HOME_SUPPORT_LINK"] or "https://buymeacoffee.com/migugin")
    supportBox:SetAutoFocus(false)
    supportBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    supportBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    yOffset = yOffset - 38

    local thanksBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    thanksBar:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, yOffset)
    thanksBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    thanksBar:SetHeight(30)
    thanksBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    thanksBar:SetBackdropColor(T("BG_SECONDARY"))
    thanksBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local thanksTitle = thanksBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thanksTitle:SetPoint("LEFT", thanksBar, "LEFT", 15, 0)
    thanksTitle:SetText(L["HOME_SPECIAL_THANKS"] or "Special Thanks")
    thanksTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local thanksNames = thanksBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thanksNames:SetPoint("LEFT", thanksTitle, "RIGHT", 12, 0)
    thanksNames:SetText(L["HOME_THANKS_NAMES"] or "Name 1, Name 2, Name 3")
    thanksNames:SetTextColor(T("TEXT_SECONDARY"))

    yOffset = yOffset - 42

    local splitContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    splitContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    splitContainer:SetBackdropColor(T("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local modHDiv = splitContainer:CreateTexture(nil, "ARTWORK")
    modHDiv:SetHeight(1)
    modHDiv:SetPoint("TOPLEFT",  splitContainer, "TOPLEFT",  8, -36)
    modHDiv:SetPoint("TOPRIGHT", splitContainer, "TOPRIGHT", -8, -36)
    modHDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local modVDiv = splitContainer:CreateTexture(nil, "ARTWORK")
    modVDiv:SetWidth(1)
    modVDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local leftPanel  = CreateFrame("Frame", nil, splitContainer)
    local rightPanel = CreateFrame("Frame", nil, splitContainer)

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
        modVDiv:SetPoint("BOTTOMLEFT", splitContainer, "BOTTOMLEFT", col,   8)
    end

    splitContainer:HookScript("OnSizeChanged", LayoutColumns)
    C_Timer.After(0, LayoutColumns)

    -- === LEFT: Detected Modules ===
    local detectedTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectedTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    detectedTitle:SetText(L["HOME_DETECTED_MODULES"])
    detectedTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local modY = -38
    CreateModuleRow(leftPanel, "MODULE_ONEWOW", "OneWoW", "OneWoW", modY, nil, true)
    modY = modY - 28

    local moduleChecks = {
        { key = "MODULE_ALTTRACKER",    displayName = "AltTracker",      addonName = "OneWoW_AltTracker",    cascade = { "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Auctions", "OneWoW_AltTracker_Character", "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame", "OneWoW_AltTracker_Professions", "OneWoW_AltTracker_Storage" } },
        { key = "MODULE_CATALOG",       displayName = "Catalog",         addonName = "OneWoW_Catalog",       cascade = { "OneWoW_CatalogData_Journal", "OneWoW_CatalogData_Tradeskills", "OneWoW_CatalogData_Vendors" } },
        { key = "MODULE_DIRECTDEPOSIT", displayName = "Direct Deposit",  addonName = "OneWoW_DirectDeposit" },
        { key = "MODULE_NOTES",         displayName = "Notes",           addonName = "OneWoW_Notes" },
        { key = "MODULE_QOL",           displayName = "Quality of Life", addonName = "OneWoW_QoL" },
        { key = "MODULE_SHOPPINGLIST",  displayName = "Shopping List",   addonName = "OneWoW_ShoppingList" },
    }

    for _, mod in ipairs(moduleChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.displayName, mod.addonName, modY, mod.cascade)
        modY = modY - 28
    end

    local leftSectDivY = modY - 4
    local leftSectDiv = leftPanel:CreateTexture(nil, "ARTWORK")
    leftSectDiv:SetHeight(1)
    leftSectDiv:SetPoint("TOPLEFT",  leftPanel, "TOPLEFT",  8, leftSectDivY)
    leftSectDiv:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -8, leftSectDivY)
    leftSectDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local utilTitleY = leftSectDivY - 18
    local utilTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    utilTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, utilTitleY)
    utilTitle:SetText(L["HOME_UTILITIES"])
    utilTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local utilitiesChecks = {
        { key = "MODULE_DEVTOOLS",  displayName = "DevTools",  addonName = "OneWoW_Utility_DevTool" },
        { key = "MODULE_EXTRACTOR", displayName = "Extractor", addonName = "OneWoW_Utility_Extractor" },
        { key = "MODULE_ITEMS",     displayName = "Items",     addonName = "OneWoW_Utility_Items" },
    }

    local utilY = utilTitleY - 24
    for _, mod in ipairs(utilitiesChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.displayName, mod.addonName, utilY)
        utilY = utilY - 28
    end

    -- === RIGHT: Detected Data Modules ===
    local dataTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dataTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    dataTitle:SetText(L["HOME_DETECTED_DATA_MODULES"])
    dataTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local rightY = -38

    local atSubHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    atSubHeader:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, rightY)
    atSubHeader:SetText(L["HOME_ALTTRACKER_MODULES"])
    atSubHeader:SetTextColor(T("TEXT_SECONDARY"))
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
    rightSectDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local catSubHeaderY = rightSectDivY - 18
    local catSubHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catSubHeader:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, catSubHeaderY)
    catSubHeader:SetText(L["HOME_CATALOG_DATA_MODULES"])
    catSubHeader:SetTextColor(T("TEXT_SECONDARY"))
    rightY = catSubHeaderY - 22

    local catalogDataChecks = {
        { key = "CAT_MOD_JOURNAL",     displayName = "Journal",     addonName = "OneWoW_CatalogData_Journal" },
        { key = "CAT_MOD_TRADESKILLS", displayName = "Tradeskills", addonName = "OneWoW_CatalogData_Tradeskills" },
        { key = "CAT_MOD_VENDORS",     displayName = "Vendors",     addonName = "OneWoW_CatalogData_Vendors" },
    }

    for _, mod in ipairs(catalogDataChecks) do
        CreateModuleRow(rightPanel, mod.key, mod.displayName, mod.addonName, rightY)
        rightY = rightY - 28
    end

    local leftDepth  = math.abs(utilY) + 4
    local rightDepth = math.abs(rightY) + 4
    local containerH = 40 + math.max(leftDepth, rightDepth) + 20
    splitContainer:SetHeight(containerH)

    yOffset = yOffset - containerH - 20

    local cmdContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    cmdContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    cmdContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    cmdContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cmdContainer:SetBackdropColor(T("BG_SECONDARY"))
    cmdContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local cmdTitle = cmdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cmdTitle:SetPoint("TOPLEFT", cmdContainer, "TOPLEFT", 15, -12)
    cmdTitle:SetText(L["HOME_COMMANDS"] or "Available Commands")
    cmdTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local cmdHDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdHDiv:SetHeight(1)
    cmdHDiv:SetPoint("TOPLEFT",  cmdContainer, "TOPLEFT",  8, -36)
    cmdHDiv:SetPoint("TOPRIGHT", cmdContainer, "TOPRIGHT", -8, -36)
    cmdHDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local cmdVDiv = cmdContainer:CreateTexture(nil, "ARTWORK")
    cmdVDiv:SetWidth(1)
    cmdVDiv:SetPoint("TOP",    cmdContainer, "TOP",    0, -40)
    cmdVDiv:SetPoint("BOTTOM", cmdContainer, "BOTTOM", 0, 8)
    cmdVDiv:SetColorTexture(T("BORDER_SUBTLE"))

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
                local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, pY)
                hdr:SetText(set.header)
                hdr:SetTextColor(T("TEXT_MUTED"))
                local soon = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                soon:SetPoint("LEFT", hdr, "RIGHT", 6, 0)
                soon:SetText("(" .. (L["HOME_MINIMAP_PLACEHOLDER"] or "Coming Soon") .. ")")
                soon:SetTextColor(T("TEXT_MUTED"))
                pY = pY - 26
            else
                local show = set.always or (_G[set.global] ~= nil)
                if show then
                    local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, pY)
                    hdr:SetText(set.header)
                    hdr:SetTextColor(T("ACCENT_PRIMARY"))
                    pY = pY - 18
                    for _, cmdInfo in ipairs(set.commands) do
                        local cmdText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        cmdText:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, pY)
                        cmdText:SetText("|cFFFFFFFF" .. cmdInfo.cmd .. "|r")
                        cmdText:SetTextColor(T("TEXT_PRIMARY"))
                        local descText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        descText:SetPoint("TOPLEFT", panel, "TOPLEFT", 210, pY)
                        descText:SetText("- " .. cmdInfo.desc)
                        descText:SetTextColor(T("TEXT_SECONDARY"))
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
