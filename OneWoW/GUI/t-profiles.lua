local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function T(key) return OneWoW_GUI:GetThemeColor(key) end
local function S(key) return OneWoW_GUI:GetSpacing(key) end

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = DeepCopy(v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function DeepMerge(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

local function SyncSettingToChildAddons(settingType, value)
    local integratedAddons = {
        "OneWoW_AltTracker",
        "OneWoW_Notes",
        "OneWoW_QoL",
        "OneWoW_Catalog",
        "OneWoW_DirectDeposit",
        "OneWoW_ShoppingList",
        "OneWoW_UtilityDevTool",
        "OneWoW_UtilityExtractor",
    }

    for _, globalName in ipairs(integratedAddons) do
        local addon = _G[globalName]
        if addon then
            if settingType == "theme" and addon.ApplyTheme then
                addon:ApplyTheme()
            elseif settingType == "language" and addon.ApplyLanguage then
                if addon.db and addon.db.global then
                    addon.db.global.language = value
                end
                addon:ApplyLanguage()
            end
        end
    end
end

local function CreateDropdownMenu(parent, options, onSelect)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menu:SetBackdropColor(T("BG_PRIMARY"))
    menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local yOff = -4
    local maxWidth = 180
    for _, opt in ipairs(options) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, yOff)
        btn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, yOff)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        btn:SetBackdropColor(0, 0, 0, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 8, 0)
        btn.text:SetText(opt.label)
        btn.text:SetTextColor(T("TEXT_PRIMARY"))

        local textW = btn.text:GetStringWidth() + 20
        if textW > maxWidth then maxWidth = textW end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        btn:SetScript("OnClick", function()
            menu:Hide()
            onSelect(opt.value, opt.label)
        end)

        yOff = yOff - 24
    end

    menu:SetSize(maxWidth + 16, math.abs(yOff) + 8)
    menu:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)

    menu:SetScript("OnShow", function(self)
        local timeOutside = 0
        self:SetScript("OnUpdate", function(self, elapsed)
            if not MouseIsOver(menu) and not MouseIsOver(parent) then
                timeOutside = timeOutside + elapsed
                if timeOutside > 0.5 then
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                end
            else
                timeOutside = 0
            end
        end)
    end)

    return menu
end

OneWoW.Profiles = {}

function OneWoW.Profiles.CaptureSettings()
    local snapshot = {}

    if OneWoW.db and OneWoW.db.global then
        local g = OneWoW.db.global
        snapshot.core = {
            language = g.language,
            theme = g.theme,
            minimap = DeepCopy(g.minimap),
            settings = DeepCopy(g.settings),
            toasts = DeepCopy(g.toasts),
            portalHub = DeepCopy(g.portalHub),
        }
    end

    local qol = _G.OneWoW_QoL
    if qol and qol.db and qol.db.global then
        local q = qol.db.global
        snapshot.qol = {
            language = q.language,
            theme = q.theme,
            minimap = DeepCopy(q.minimap),
            modules = {},
        }
        if q.modules then
            for id, modData in pairs(q.modules) do
                snapshot.qol.modules[id] = DeepCopy(modData)
            end
        end
    end

    snapshot.cvars = {}
    if qol and qol.GetCVarList then
        for _, entry in ipairs(qol.GetCVarList()) do
            local val = C_CVar.GetCVar(entry.cvar)
            if val then
                snapshot.cvars[entry.cvar] = val
            end
        end
    end

    return snapshot
end

function OneWoW.Profiles.ApplySettings(snapshot)
    if not snapshot then return end

    if snapshot.core and OneWoW.db and OneWoW.db.global then
        local g = OneWoW.db.global
        if snapshot.core.language then
            g.language = snapshot.core.language
        end
        if snapshot.core.theme then
            g.theme = snapshot.core.theme
        end
        if snapshot.core.minimap then
            if snapshot.core.minimap.hide ~= nil then
                g.minimap.hide = snapshot.core.minimap.hide
            end
            if snapshot.core.minimap.theme then
                g.minimap.theme = snapshot.core.minimap.theme
            end
        end
        if snapshot.core.settings then
            DeepMerge(g.settings, snapshot.core.settings)
        end
        if snapshot.core.toasts then
            DeepMerge(g.toasts, snapshot.core.toasts)
        end
        if snapshot.core.portalHub then
            DeepMerge(g.portalHub, snapshot.core.portalHub)
        end
    end

    local qol = _G.OneWoW_QoL
    if snapshot.qol and qol and qol.db and qol.db.global then
        local q = qol.db.global
        if snapshot.qol.language then q.language = snapshot.qol.language end
        if snapshot.qol.theme then q.theme = snapshot.qol.theme end
        if snapshot.qol.minimap then
            DeepMerge(q.minimap, snapshot.qol.minimap)
        end
        if snapshot.qol.modules then
            for id, modData in pairs(snapshot.qol.modules) do
                if q.modules and q.modules[id] then
                    DeepMerge(q.modules[id], modData)
                end
            end
        end
    end

    if snapshot.cvars then
        for cvarName, value in pairs(snapshot.cvars) do
            C_CVar.SetCVar(cvarName, value)
        end
    end

    if snapshot.core and snapshot.core.theme then
        SyncSettingToChildAddons("theme", snapshot.core.theme)
    end
    if snapshot.core and snapshot.core.language then
        SyncSettingToChildAddons("language", snapshot.core.language)
    end

    GUI:FullReset()
    C_Timer.After(0.1, function()
        GUI:Show()
        GUI:SelectSubTab("settings", "profiles")
    end)
end

function GUI:CreateProfilesTab(parent)

    -- ── internal mini tab bar ─────────────────────────────────────
    local tabBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    tabBar:SetHeight(38)
    tabBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    tabBar:SetBackdropColor(T("BG_SECONDARY"))
    tabBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local panelA = CreateFrame("Frame", nil, parent)
    panelA:SetPoint("TOPLEFT",  tabBar,  "BOTTOMLEFT",  0,  0)
    panelA:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local panelB = CreateFrame("Frame", nil, parent)
    panelB:SetPoint("TOPLEFT",  tabBar,  "BOTTOMLEFT",  0,  0)
    panelB:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    panelB:Hide()

    local tabButtons = {}
    local activeTab  = "settings"

    local function MakeTabBtn(label, key, xAnchor, prevBtn)
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        btn:SetHeight(34)
        btn:SetWidth(160)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        if prevBtn then
            btn:SetPoint("TOPLEFT", prevBtn, "TOPRIGHT", 2, 0)
        else
            btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 4, -2)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("CENTER")
        lbl:SetText(label)
        lbl:SetTextColor(T("TEXT_PRIMARY"))
        btn.lbl = lbl
        btn.key = key

        btn:SetScript("OnEnter", function(self)
            if activeTab ~= key then
                self:SetBackdropColor(T("BG_HOVER"))
                lbl:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if activeTab ~= key then
                self:SetBackdropColor(T("BG_TERTIARY"))
                lbl:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnClick", function(self)
            activeTab = key
            panelA:SetShown(key == "settings")
            panelB:SetShown(key == "charprofiles")
            for _, b in ipairs(tabButtons) do
                if b.key == activeTab then
                    b:SetBackdropColor(T("BG_ACTIVE"))
                    b:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    b.lbl:SetTextColor(T("TEXT_ACCENT"))
                else
                    b:SetBackdropColor(T("BG_TERTIARY"))
                    b:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                    b.lbl:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
        end)

        btn:SetBackdropColor(T("BG_TERTIARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        table.insert(tabButtons, btn)
        return btn
    end

    local btnSettings    = MakeTabBtn("Settings Profiles",   "settings",     4,   nil)
    local btnCharprofiles = MakeTabBtn("Character Profiles", "charprofiles", 166,  btnSettings)

    -- activate Settings tab by default
    btnSettings:SetBackdropColor(T("BG_ACTIVE"))
    btnSettings:SetBackdropBorderColor(T("BORDER_ACCENT"))
    btnSettings.lbl:SetTextColor(T("TEXT_ACCENT"))

    -- ── Panel B: Character Profiles ───────────────────────────────
    if GUI.CreateCharProfilesPanel then
        GUI:CreateCharProfilesPanel(panelB)
    end

    -- ── Panel A: Settings Profiles ────────────────────────────────
    local scrollFrame, content = GUI:CreateScrollFrame("OneWoW_ProfilesScroll", panelA)
    content:SetHeight(1000)

    local yOffset = -10

    -- Default / Global Profile box
    local defaultContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    defaultContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    defaultContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    defaultContainer:SetHeight(90)
    defaultContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    defaultContainer:SetBackdropColor(T("BG_SECONDARY"))
    defaultContainer:SetBackdropBorderColor(T("BORDER_ACCENT"))

    local defaultTitle = defaultContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    defaultTitle:SetPoint("TOPLEFT", defaultContainer, "TOPLEFT", 15, -12)
    defaultTitle:SetText("Global / Default Profile")
    defaultTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local defaultNameLabel = defaultContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    defaultNameLabel:SetPoint("TOPLEFT", defaultContainer, "TOPLEFT", 15, -42)
    defaultNameLabel:SetText("Default: " .. (OneWoW.db.global.defaultProfile or "|cFF888888None set|r"))
    defaultNameLabel:SetTextColor(T("TEXT_PRIMARY"))

    local applyDefaultBtn = GUI:CreateButton(nil, defaultContainer, "Apply Default Profile", 180, 32)
    applyDefaultBtn:SetPoint("TOPRIGHT", defaultContainer, "TOPRIGHT", -15, -45)
    applyDefaultBtn:SetScript("OnClick", function()
        local def = OneWoW.db.global.defaultProfile
        if not def or not OneWoW.db.global.profiles[def] then
            print("|cFFFFD100OneWoW:|r No default profile set. Select a profile and use 'Set as Default'.")
            return
        end
        OneWoW.Profiles.ApplySettings(OneWoW.db.global.profiles[def])
        OneWoW.db.global.activeProfile = def
    end)

    yOffset = yOffset - 110

    local infoContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    infoContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    infoContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    infoContainer:SetHeight(80)
    infoContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    infoContainer:SetBackdropColor(T("BG_SECONDARY"))
    infoContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local infoText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", infoContainer, "TOPLEFT", 15, -12)
    infoText:SetPoint("TOPRIGHT", infoContainer, "TOPRIGHT", -15, -12)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetSpacing(2)
    infoText:SetText("Saves: language, theme, minimap icon, all overlay / toast / tooltip settings, portal settings, and all QoL feature toggles.")
    infoText:SetTextColor(T("TEXT_SECONDARY"))

    local addonsText = infoContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonsText:SetPoint("TOPLEFT", infoContainer, "TOPLEFT", 15, -56)
    addonsText:SetText("Covers: OneWoW (core), OneWoW_QoL (all modules + CVars)")
    addonsText:SetTextColor(T("ACCENT_SECONDARY"))

    yOffset = yOffset - 100

    local activeProfileContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    activeProfileContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    activeProfileContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    activeProfileContainer:SetHeight(80)
    activeProfileContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    activeProfileContainer:SetBackdropColor(T("BG_SECONDARY"))
    activeProfileContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local activeTitle = activeProfileContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeTitle:SetPoint("TOPLEFT", activeProfileContainer, "TOPLEFT", 15, -12)
    activeTitle:SetText("Active Profile")
    activeTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local activeLabel = activeProfileContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", activeProfileContainer, "TOPLEFT", 15, -45)
    activeLabel:SetText(OneWoW.db.global.activeProfile or "None")
    activeLabel:SetTextColor(T("TEXT_PRIMARY"))

    yOffset = yOffset - 100

    local saveContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    saveContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    saveContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    saveContainer:SetHeight(140)
    saveContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    saveContainer:SetBackdropColor(T("BG_SECONDARY"))
    saveContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local saveTitle = saveContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    saveTitle:SetPoint("TOPLEFT", saveContainer, "TOPLEFT", 15, -12)
    saveTitle:SetText("Save Profile")
    saveTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local saveLabel = saveContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveLabel:SetPoint("TOPLEFT", saveContainer, "TOPLEFT", 15, -42)
    saveLabel:SetText("Profile Name:")
    saveLabel:SetTextColor(T("TEXT_SECONDARY"))

    local nameInput = GUI:CreateEditBox("OneWoW_ProfileNameInput", saveContainer, 250, 24)
    nameInput:SetPoint("TOPLEFT", saveContainer, "TOPLEFT", 15, -65)
    nameInput:SetAutoFocus(false)
    nameInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    nameInput:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    local saveBtn = GUI:CreateButton(nil, saveContainer, "Save Profile", 130, 28)
    saveBtn:SetPoint("TOPLEFT", saveContainer, "TOPLEFT", 275, -62)
    saveBtn:SetScript("OnClick", function()
        local name = nameInput:GetText():trim()
        if name == "" then
            print("Profile name cannot be empty")
            return
        end
        local snap = OneWoW.Profiles.CaptureSettings()
        OneWoW.db.global.profiles[name] = snap
        OneWoW.db.global.activeProfile = name
        activeLabel:SetText(name)
        nameInput:SetText("")
        print(string.format("Profile '%s' saved", name))
    end)

    local noteText = saveContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteText:SetPoint("TOPLEFT", saveContainer, "TOPLEFT", 15, -100)
    noteText:SetText("Note: Overwrites if name already exists")
    noteText:SetTextColor(T("TEXT_SECONDARY"))

    yOffset = yOffset - 160

    local manageContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    manageContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    manageContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    manageContainer:SetHeight(160)
    manageContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    manageContainer:SetBackdropColor(T("BG_SECONDARY"))
    manageContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local manageTitle = manageContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    manageTitle:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 15, -12)
    manageTitle:SetText("Load & Manage")
    manageTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local selectLabel = manageContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectLabel:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 15, -42)
    selectLabel:SetText("Select Profile:")
    selectLabel:SetTextColor(T("TEXT_SECONDARY"))

    local selectedProfileName = nil
    local dropdownText = manageContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdownText:SetPoint("LEFT", 270, 0)
    dropdownText:SetText("")
    dropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local profileDropdown = CreateFrame("Button", nil, manageContainer, "BackdropTemplate")
    profileDropdown:SetSize(250, 30)
    profileDropdown:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 15, -65)
    profileDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    profileDropdown:SetBackdropColor(T("BG_TERTIARY"))
    profileDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local dropdownArrow = profileDropdown:CreateTexture(nil, "OVERLAY")
    dropdownArrow:SetSize(16, 16)
    dropdownArrow:SetPoint("RIGHT", profileDropdown, "RIGHT", -5, 0)
    dropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local loadBtn = GUI:CreateButton(nil, manageContainer, "Load Profile", 130, 28)
    loadBtn:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 15, -110)
    loadBtn:SetScript("OnClick", function()
        if not selectedProfileName then
            print("No profile selected")
            return
        end
        local profile = OneWoW.db.global.profiles[selectedProfileName]
        if profile then
            OneWoW.Profiles.ApplySettings(profile)
            OneWoW.db.global.activeProfile = selectedProfileName
            activeLabel:SetText(selectedProfileName)
            print(string.format("Profile '%s' loaded", selectedProfileName))
        end
    end)

    local updateBtn = GUI:CreateButton(nil, manageContainer, "Update Profile", 130, 28)
    updateBtn:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 160, -110)
    updateBtn:SetScript("OnClick", function()
        if not OneWoW.db.global.activeProfile then
            print("No active profile to update")
            return
        end
        local snap = OneWoW.Profiles.CaptureSettings()
        OneWoW.db.global.profiles[OneWoW.db.global.activeProfile] = snap
        print(string.format("Profile '%s' updated", OneWoW.db.global.activeProfile))
    end)

    local setDefaultBtn = GUI:CreateButton(nil, manageContainer, "Set as Default", 130, 28)
    setDefaultBtn:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 305, -110)
    setDefaultBtn:SetScript("OnClick", function()
        if not selectedProfileName then
            print("No profile selected")
            return
        end
        OneWoW.db.global.defaultProfile = selectedProfileName
        defaultNameLabel:SetText("Default: " .. selectedProfileName)
        print(string.format("Default profile set to '%s'", selectedProfileName))
    end)

    local deleteBtn = GUI:CreateButton(nil, manageContainer, "Delete Profile", 130, 28)
    deleteBtn:SetPoint("TOPLEFT", manageContainer, "TOPLEFT", 450, -110)
    deleteBtn:SetScript("OnClick", function()
        if not selectedProfileName then
            print("No profile selected")
            return
        end
        OneWoW.db.global.profiles[selectedProfileName] = nil
        if OneWoW.db.global.activeProfile == selectedProfileName then
            OneWoW.db.global.activeProfile = nil
            activeLabel:SetText("None")
        end
        if OneWoW.db.global.defaultProfile == selectedProfileName then
            OneWoW.db.global.defaultProfile = nil
            defaultNameLabel:SetText("Default: |cFF888888None set|r")
        end
        BuildProfileDropdown()
        print(string.format("Profile '%s' deleted", selectedProfileName))
        selectedProfileName = nil
        dropdownText:SetText("")
        contentsContainer:Hide()
    end)

    yOffset = yOffset - 190

    local contentsContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    contentsContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    contentsContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    contentsContainer:SetHeight(250)
    contentsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contentsContainer:SetBackdropColor(T("BG_SECONDARY"))
    contentsContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    contentsContainer:Hide()

    local contentsTitle = contentsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    contentsTitle:SetPoint("TOPLEFT", contentsContainer, "TOPLEFT", 15, -12)
    contentsTitle:SetText("Profile Contents")
    contentsTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local contentsText = contentsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contentsText:SetPoint("TOPLEFT", contentsContainer, "TOPLEFT", 15, -40)
    contentsText:SetPoint("TOPRIGHT", contentsContainer, "TOPRIGHT", -15, -40)
    contentsText:SetJustifyH("LEFT")
    contentsText:SetWordWrap(true)
    contentsText:SetSpacing(2)
    contentsText:SetText("")
    contentsText:SetTextColor(T("TEXT_PRIMARY"))

    local function ShowProfileContents(profileName)
        if not profileName or not OneWoW.db.global.profiles[profileName] then
            contentsContainer:Hide()
            return
        end

        local profile = OneWoW.db.global.profiles[profileName]
        local lines = {}

        table.insert(lines, "Data included in this profile:")
        table.insert(lines, "")

        if profile.core then
            table.insert(lines, "OneWoW Core:")
            if profile.core.language then table.insert(lines, "  - Language") end
            if profile.core.theme then table.insert(lines, "  - Theme") end
            if profile.core.minimap then table.insert(lines, "  - Minimap settings") end
            if profile.core.settings then table.insert(lines, "  - All overlay/toast/tooltip settings") end
            if profile.core.portalHub then table.insert(lines, "  - Portal Hub settings") end
            table.insert(lines, "")
        end

        if profile.qol then
            table.insert(lines, "OneWoW_QoL:")
            if profile.qol.language then table.insert(lines, "  - Language") end
            if profile.qol.theme then table.insert(lines, "  - Theme") end
            if profile.qol.minimap then table.insert(lines, "  - Minimap settings") end
            if profile.qol.modules then
                local moduleCount = 0
                for _ in pairs(profile.qol.modules) do moduleCount = moduleCount + 1 end
                if moduleCount > 0 then
                    table.insert(lines, string.format("  - ALL %d QoL modules (toggles, positions, configs)", moduleCount))
                end
            end
            table.insert(lines, "")
        end

        if profile.cvars then
            local cvarCount = 0
            for _ in pairs(profile.cvars) do cvarCount = cvarCount + 1 end
            if cvarCount > 0 then
                table.insert(lines, string.format("Game CVars: %d settings", cvarCount))
                table.insert(lines, "")
            end
        end

        table.insert(lines, "Note: Only installed addons will be restored.")

        contentsText:SetText(table.concat(lines, "\n"))
        contentsContainer:Show()
    end

    function BuildProfileDropdown()
        selectedProfileName = nil
        dropdownText:SetText("")
        contentsContainer:Hide()
        profileDropdown:SetScript("OnClick", function(self)
            local options = {}
            for name in pairs(OneWoW.db.global.profiles) do
                table.insert(options, { label = name, value = name })
            end
            if #options == 0 then
                print("No profiles saved yet")
                return
            end
            table.sort(options, function(a, b) return a.label < b.label end)
            local menu = CreateDropdownMenu(self, options, function(value, label)
                selectedProfileName = value
                dropdownText:SetText(label)
                ShowProfileContents(value)
            end)
            menu:Show()
        end)
    end

    BuildProfileDropdown()

    content:SetHeight(math.abs(yOffset) + 300)
end
