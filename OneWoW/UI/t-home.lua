local _, ns = ...

local UI = ns.UI

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local STATUS_TEX_OK  = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STATUS_TEX_BAD = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- The Home tab is read-only: it mirrors effective feature state (Blizzard enable
-- flags + OneWoW soft opt-out via ns:GetFeatureUnitState). Enabling/disabling
-- lives in Settings > Manage Features (storage addons have dependencies users
-- shouldn't toggle blind).
--   all            -> green check  (wanted for every known character, loaded here)
--   some           -> grey check   (wanted for some characters only, loaded here)
--   notloaded      -> amber check + "(not loaded)" tag (Blizzard-enabled but not
--                     wanted or not loaded on this character — soft opt-out or
--                     orchestrator skip)
--   pendingdisable -> amber check + "(off next reload)" tag (loaded and working
--                     this session, but soft-disabled — will not load next reload)
--   none           -> red X        (Blizzard-disabled for this character)
--   missing        -> muted grey X (addon not installed)
local STATE_ALL, STATE_SOME, STATE_NOTLOADED, STATE_PENDING_DISABLE, STATE_NONE, STATE_MISSING =
    "all", "some", "notloaded", "pendingdisable", "none", "missing"

local function MapFeatureUnitState(unitState)
    if unitState == "all" then return STATE_ALL
    elseif unitState == "some" then return STATE_SOME
    elseif unitState == "not_loaded" then return STATE_NOTLOADED
    elseif unitState == "pending_disable" then return STATE_PENDING_DISABLE
    elseif unitState == "disabled" then return STATE_NONE
    else return STATE_MISSING end
end

function UI:CreateHomeTab(parent)
    local L = ns.L
    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_HomeScroll" })

    -- Each status row registers its ApplyState() here so RefreshAll() (OnShow +
    -- ns.FeatureStateChanged) can re-query live state without rebuilding rows.
    local rowRefreshers = {}

    -- The suite ships as one bundle: every addon's TOC Version bumps together, so
    -- core's version is the canonical one. A per-addon mismatch means the user has
    -- a stale/partial install (e.g. an installer only replaced some folders) and
    -- should redownload the whole suite. Dev-only utilities are excluded — they
    -- ship on a separate cadence from a private repo and legitimately differ.
    local coreVersion = ns:GetAddonVersion("OneWoW")

    --- True when an installed suite addon's TOC version differs from core's.
    --- Missing addons (nil version) and core itself never count as a mismatch.
    ---@param addonName string
    ---@return boolean
    local function IsVersionMismatch(addonName)
        if addonName == "OneWoW" or not coreVersion then return false end
        local ver = ns:GetAddonVersion(addonName)
        return ver ~= nil and ver ~= coreVersion
    end

    -- Addon groups shown on the left/right columns. Hoisted so the version-parity
    -- pre-scan (below) and the layout loops share one source of truth.
    local moduleChecks = {
        { key = "MODULE_ALTTRACKER", addonName = "OneWoW_AltTracker" },
        { key = "MODULE_CATALOG",    addonName = "OneWoW_Catalog" },
        { key = "MODULE_NOTES",      addonName = "OneWoW_Notes" },
        { key = "MODULE_QOL",        addonName = "OneWoW_QoL" },
    }
    local standaloneChecks = {
        { key = "MODULE_BAGS",          addonName = "OneWoW_Bags" },
        { key = "MODULE_DIRECTDEPOSIT", addonName = "OneWoW_DirectDeposit" },
        { key = "MAIL",                 addonName = "OneWoW_Mail" },
        { key = "MODULE_SHOPPINGLIST",  addonName = "OneWoW_ShoppingList" },
        { key = "MODULE_TRACKERS",      addonName = "OneWoW_Trackers" },
    }
    local dataModuleChecks = {
        { key = "DATA_MOD_ACCOUNTING",  addonName = "OneWoW_AltTracker_Accounting" },
        { key = "DATA_MOD_AUCTIONS",    addonName = "OneWoW_AltTracker_Auctions" },
        { key = "DATA_MOD_CHARACTER",   addonName = "OneWoW_AltTracker_Character" },
        { key = "DATA_MOD_COLLECTIONS", addonName = "OneWoW_AltTracker_Collections" },
        { key = "DATA_MOD_ENDGAME",     addonName = "OneWoW_AltTracker_Endgame" },
        { key = "DATA_MOD_PROFESSIONS", addonName = "OneWoW_AltTracker_Professions" },
        { key = "DATA_MOD_STORAGE",     addonName = "OneWoW_AltTracker_Storage" },
    }
    local catalogDataChecks = {
        { key = "CAT_MOD_JOURNAL",     addonName = "OneWoW_CatalogData_Journal" },
        { key = "CAT_MOD_QUESTS",      addonName = "OneWoW_CatalogData_Quests" },
        { key = "CAT_MOD_TRADESKILLS", addonName = "OneWoW_CatalogData_Tradeskills" },
        { key = "CAT_MOD_VENDORS",     addonName = "OneWoW_CatalogData_Vendors" },
    }

    --- Scan every parity-checked addon group once to decide whether to surface the
    --- redownload notice (and reserve layout space for it). Static per session.
    ---@return boolean
    local function HasAnyVersionMismatch()
        for _, group in ipairs({ moduleChecks, standaloneChecks, dataModuleChecks, catalogDataChecks }) do
            for _, mod in ipairs(group) do
                if IsVersionMismatch(mod.addonName) then return true end
            end
        end
        return false
    end

    -- Read-only status row: a tri-state checkmark + name + version. No toggle.
    -- Widgets are built once; ApplyState() re-reads GetFeatureUnitState and restyles
    -- so the row stays accurate when addons load/unload or opt-out changes.
    local function CreateModuleRow(panel, localeKey, addonName, rowY, skipParity)
        local localizedName = L[localeKey]
        local state  -- live, updated by ApplyState(); read by the tooltip handler

        local light = panel:CreateTexture(nil, "ARTWORK")
        light:SetSize(14, 14)
        light:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, rowY - 1)

        local lightHit = CreateFrame("Frame", nil, panel)
        lightHit:SetSize(16, 16)
        lightHit:SetPoint("CENTER", light, "CENTER")
        lightHit:EnableMouse(true)
        lightHit:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if state == STATE_ALL then
                GameTooltip:SetText(L["HOME_STATUS_ALL"], 0.2, 0.8, 0.2)
            elseif state == STATE_SOME then
                GameTooltip:SetText(L["HOME_STATUS_SOME"], 0.7, 0.7, 0.7)
            elseif state == STATE_NOTLOADED then
                GameTooltip:SetText(L["HOME_STATUS_NOTLOADED"], 1, 0.82, 0, 1, true)
            elseif state == STATE_PENDING_DISABLE then
                GameTooltip:SetText(L["HOME_STATUS_PENDING_DISABLE"], 1, 0.82, 0, 1, true)
            elseif state == STATE_NONE then
                GameTooltip:SetText(L["HOME_STATUS_NONE"], 1, 0.4, 0.4)
            else
                GameTooltip:SetText(L["HOME_STATUS_NOT_FOUND"], 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        lightHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local nameText = OneWoW_GUI:CreateFS(panel, 12)
        nameText:SetPoint("LEFT", light, "RIGHT", 8, 0)
        nameText:SetWidth(120)
        nameText:SetText(localizedName)
        nameText:SetJustifyH("LEFT")

        local verText = OneWoW_GUI:CreateFS(panel, 10)
        verText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        verText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local tag = OneWoW_GUI:CreateFS(panel, 10)
        tag:SetPoint("LEFT", verText, "RIGHT", 4, 0)
        tag:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

        local function ApplyState()
            state = MapFeatureUnitState(ns:GetFeatureUnitState(addonName))

            if state == STATE_ALL then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif state == STATE_SOME then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(0.5, 0.5, 0.5, 1)
            elseif state == STATE_NOTLOADED or state == STATE_PENDING_DISABLE then
                light:SetTexture(STATUS_TEX_OK)
                light:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))  -- amber: enabled, not loaded / disabling on reload
            elseif state == STATE_NONE then
                light:SetTexture(STATUS_TEX_BAD)
                light:SetVertexColor(1, 1, 1, 1)
            else
                light:SetTexture(STATUS_TEX_BAD)
                light:SetVertexColor(0.45, 0.45, 0.45, 0.8)  -- missing: muted X
            end

            if state == STATE_MISSING then
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            verText:SetText(ns:GetAddonVersion(addonName) or "")
            if not skipParity and IsVersionMismatch(addonName) then
                verText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))  -- red: stale/partial install
            else
                verText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            if state == STATE_NOTLOADED then
                tag:SetText(L["HOME_NOTLOADED_TAG"])
                tag:Show()
            elseif state == STATE_PENDING_DISABLE then
                tag:SetText(L["HOME_PENDING_DISABLE_TAG"])
                tag:Show()
            else
                tag:Hide()
            end
        end

        ApplyState()
        rowRefreshers[#rowRefreshers + 1] = ApplyState
    end

    content:SetHeight(1200)
    local yOffset = -30

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(128, 128)
    logo:SetPoint("TOP", content, "TOP", 0, yOffset)
    logo:SetTexture("Interface\\AddOns\\OneWoW\\Media\\neutral-large.png")
    yOffset = yOffset - 150

    local versionLabel = OneWoW_GUI:CreateFS(content, 16)
    versionLabel:SetPoint("TOP", content, "TOP", 0, yOffset)
    versionLabel:SetText("OneWoW " .. (L["HOME_VERSION"]) .. " " .. (coreVersion or ""))
    versionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 35

    -- Surfaced only when a suite addon's version drifts from core (stale/partial
    -- install). Reserves flow space only when shown so the normal case has no gap.
    if HasAnyVersionMismatch() then
        local mismatchNotice = OneWoW_GUI:CreateFS(content, 12)
        mismatchNotice:SetPoint("TOPLEFT",  content, "TOPLEFT",  40, yOffset)
        mismatchNotice:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)
        mismatchNotice:SetJustifyH("CENTER")
        mismatchNotice:SetText(string.format(L["HOME_VERSION_MISMATCH_NOTICE"], coreVersion or ""))
        mismatchNotice:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        -- Fixed reserve: the notice wraps to 2-3 lines and content width isn't
        -- resolved yet at build time, so GetStringHeight would under-report.
        yOffset = yOffset - 52
    end

    local divider1 = content:CreateTexture(nil, "ARTWORK")
    divider1:SetHeight(1)
    divider1:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    divider1:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)
    divider1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 20

    local linksRow = CreateFrame("Frame", nil, content)
    linksRow:SetHeight(24)
    linksRow:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    linksRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -40, yOffset)

    -- Builds a clickable label that opens ShowCopyURLDialog. Used for the
    -- compact link row on the home tab.
    local function CreateLinkButton(parentFrame, title, url)
        local btn = CreateFrame("Button", nil, parentFrame)
        btn:SetSize(140, 24)
        btn:EnableMouse(true)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(title)
        label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        btn:SetScript("OnEnter", function()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            SetCursor("Interface\\CURSOR\\Point")
        end)
        btn:SetScript("OnLeave", function()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            ResetCursor()
        end)
        btn:SetScript("OnClick", function()
            OneWoW_GUI:ShowCopyURLDialog(title, url)
        end)

        return btn
    end

    local discordBtn = CreateLinkButton(linksRow,
        L["DISCORD"],
        L["HOME_DISCORD_LINK"])
    discordBtn:SetPoint("LEFT", linksRow, "CENTER", -160, 0)

    local supportBtn = CreateLinkButton(linksRow,
        L["HOME_SUPPORT"],
        L["HOME_SUPPORT_LINK"])
    supportBtn:SetPoint("LEFT", linksRow, "CENTER", 20, 0)

    yOffset = yOffset - 34

    local thanksBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    thanksBar:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, yOffset)
    thanksBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    thanksBar:SetHeight(30)
    thanksBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    thanksBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    thanksBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local thanksTitle = OneWoW_GUI:CreateFS(thanksBar, 12)
    thanksTitle:SetPoint("LEFT", thanksBar, "LEFT", 15, 0)
    thanksTitle:SetText(L["HOME_SPECIAL_THANKS"])
    thanksTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local thanksNames = OneWoW_GUI:CreateFS(thanksBar, 12)
    thanksNames:SetPoint("LEFT", thanksTitle, "RIGHT", 12, 0)
    thanksNames:SetText(L["HOME_THANKS_NAMES"])
    thanksNames:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 42

    -- Home is read-only for enable/disable; point users to Manage Features.
    local manageRow = CreateFrame("Frame", nil, content)
    manageRow:SetHeight(20)
    manageRow:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset)
    manageRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, yOffset)

    UI:CreateManageFeaturesLinkRow(manageRow, { pointerKey = "HOME_MANAGE_POINTER", center = true })

    yOffset = yOffset - 28

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
    CreateModuleRow(leftPanel, "MODULE_ONEWOW", "OneWoW", modY)
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
    for _, mod in ipairs(moduleChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.addonName, modY)
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
    for _, mod in ipairs(standaloneChecks) do
        CreateModuleRow(leftPanel, mod.key, mod.addonName, modY)
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

    for _, mod in ipairs(dataModuleChecks) do
        CreateModuleRow(rightPanel, mod.key, mod.addonName, rightY)
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

    for _, mod in ipairs(catalogDataChecks) do
        CreateModuleRow(rightPanel, mod.key, mod.addonName, rightY)
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

    CreateModuleRow(utilLeftPanel,  "MODULE_DEVTOOLS",  "OneWoW_Utility_DevTool",  -4, true)
    CreateModuleRow(utilRightPanel, "MODULE_EXTRACTOR", "OneWoW_Utility_Extractor", -4, true)

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
    cmdTitle:SetText(L["HOME_COMMANDS"])
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
                soon:SetText("(" .. (L["HOME_MINIMAP_PLACEHOLDER"]) .. ")")
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
                { cmd = "/1w, /ow, /one, /onewow", desc = L["CMD_TOGGLE_ONEWOW"] },
                { cmd = "/1wkeys, /owkeys", desc = L["CMD_KEYWORD_HELP"] },
            },
        },
        {
            global = "OneWoW_Notes",
            header = "Notes",
            commands = {
                { cmd = "/1wn, /own, /onewownotes", desc = L["CMD_OPEN_NOTES"] },
            },
        },
        {
            global = "OneWoW_AltTracker",
            header = "AltTracker",
            commands = {
                { cmd = "/1wat, /owat, /onewowat", desc = L["CMD_OPEN_ALTTRACKER"] },
            },
        },
        {
            global = "OneWoW_Catalog",
            header = "Catalog",
            commands = {
                { cmd = "/1wcat, /owcat, /onewowcatalog", desc = L["CMD_OPEN_CATALOG"] },
            },
        },
        {
            global = "OneWoW_Trackers",
            header = "Trackers",
            commands = {
                { cmd = "/1wt, /owt, /tracker", desc = L["CMD_OPEN_TRACKERS"] },
            },
        },
        {
            global = "OneWoW_QoL",
            header = "QoL",
            commands = {
                { cmd = "/1wqol, /owqol, /onewowqol", desc = L["CMD_OPEN_QOL"] },
            },
        },
    }

    local rightSets = {
        {
            global = "OneWoW_DirectDeposit",
            header = "Direct Deposit",
            commands = {
                { cmd = "/1wdd, /dd, /directdeposit, /directdep", desc = L["CMD_OPEN_DD"] },
                { cmd = "  /ddeposit",                             desc = L["CMD_MANUAL_DEPOSIT"] },
                { cmd = "  /ddeposit pause|stop",                  desc = L["CMD_DEPOSIT_PAUSE"] },
            },
        },
        {
            global = "OneWoW_ShoppingList",
            header = "Shopping List",
            commands = {
                { cmd = "/1wsl, /owsl, /shoppinglist", desc = L["CMD_OPEN_SL"] },
                { cmd = "  /owsl add <id>",            desc = L["CMD_SL_ADD"] },
            },
        },
        {
            global = "OneWoW_Bags",
            header = "Bags",
            commands = {
                { cmd = "/1wb, /onewowbags, /1wbags", desc = L["CMD_OPEN_BAGS"] },
                { cmd = "  /owbags-export",           desc = L["CMD_BAGS_EXPORT"] },
            },
        },
        {
            global = "OneWoW_Mail",
            header = "Mail",
            commands = {
                { cmd = "/1wmail, /owmail", desc = L["CMD_OPEN_MAIL"] },
            },
        },
        {
            global = "OneWoW_Utility_DevTool",
            header = "DevTools",
            commands = {
                { cmd = "/1wdt, /dt, /devtool, /devtools", desc = L["CMD_OPEN_DEVTOOLS"] },
            },
        },
    }

    local leftEndY  = RenderSets(cmdLeft,  leftSets)
    local rightEndY = RenderSets(cmdRight, rightSets)

    local cmdHeight = 40 + math.max(math.abs(leftEndY), math.abs(rightEndY)) + 15
    cmdContainer:SetHeight(cmdHeight)

    yOffset = yOffset - cmdHeight - 20

    content:SetHeight(math.abs(yOffset) + 50)

    -- Re-query every row's live state. Driven on panel show (navigate back to Home)
    -- and by ns.FeatureStateChanged (load/opt-out change while Home is visible).
    local function RefreshAll()
        for _, fn in ipairs(rowRefreshers) do fn() end
    end
    parent.RefreshStatus = RefreshAll
    parent:HookScript("OnShow", RefreshAll)
end
