local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedCharacterKey = nil
local currentBankType = "personal"
local currentTab = 1
local selectedGuildName = nil

function ns.UI.CreateBankTab(parent)
    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    selectedCharacterKey = currentChar .. "-" .. currentRealm

    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    controlPanel:SetHeight(85)
    controlPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    controlPanel:SetBackdropColor(T("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlTitle:SetPoint("TOP", controlPanel, "TOP", 0, -8)
    controlTitle:SetText(currentChar .. " - " .. L["BANK_PERSONAL"])
    controlTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local charDropdown = CreateFrame("Button", nil, controlPanel, "BackdropTemplate")
    charDropdown:SetSize(170, 28)
    charDropdown:SetPoint("BOTTOMLEFT", controlPanel, "BOTTOMLEFT", 10, 6)
    charDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    charDropdown:SetBackdropColor(T("BG_TERTIARY"))
    charDropdown:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local charDropdownText = charDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charDropdownText:SetPoint("LEFT", charDropdown, "LEFT", 8, 0)
    charDropdownText:SetPoint("RIGHT", charDropdown, "RIGHT", -20, 0)
    charDropdownText:SetJustifyH("LEFT")
    charDropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local charDropdownArrow = charDropdown:CreateTexture(nil, "OVERLAY")
    charDropdownArrow:SetSize(14, 14)
    charDropdownArrow:SetPoint("RIGHT", charDropdown, "RIGHT", -4, 0)
    charDropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    charDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    charDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    end)

    local guildDropdown = CreateFrame("Button", nil, controlPanel, "BackdropTemplate")
    guildDropdown:SetSize(170, 28)
    guildDropdown:SetPoint("LEFT", charDropdown, "RIGHT", 6, 0)
    guildDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    guildDropdown:SetBackdropColor(T("BG_TERTIARY"))
    guildDropdown:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    guildDropdown:Hide()

    local guildDropdownText = guildDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildDropdownText:SetPoint("LEFT", guildDropdown, "LEFT", 8, 0)
    guildDropdownText:SetPoint("RIGHT", guildDropdown, "RIGHT", -20, 0)
    guildDropdownText:SetJustifyH("LEFT")
    guildDropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local guildDropdownArrow = guildDropdown:CreateTexture(nil, "OVERLAY")
    guildDropdownArrow:SetSize(14, 14)
    guildDropdownArrow:SetPoint("RIGHT", guildDropdown, "RIGHT", -4, 0)
    guildDropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    guildDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    guildDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    end)

    local buttonContainer = CreateFrame("Frame", nil, controlPanel)
    buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
    buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
    buttonContainer:SetHeight(30)

    local function CreateBankTypeButton(btnText, bankTypeKey, index)
        local btn = CreateFrame("Button", nil, buttonContainer, "BackdropTemplate")
        btn:SetHeight(28)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_TERTIARY"))
        btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnLabel:SetPoint("CENTER")
        btnLabel:SetText(btnText)
        btnLabel:SetTextColor(T("TEXT_SECONDARY"))

        btn.label = btnLabel
        btn.bankType = bankTypeKey
        btn.index = index

        btn:SetScript("OnEnter", function(self)
            if currentBankType ~= self.bankType then
                self:SetBackdropColor(T("BG_HOVER"))
                self.label:SetTextColor(T("TEXT_ACCENT"))
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if currentBankType ~= self.bankType then
                self:SetBackdropColor(T("BG_TERTIARY"))
                self.label:SetTextColor(T("TEXT_SECONDARY"))
            end
        end)

        btn:SetScript("OnClick", function(self)
            currentBankType = self.bankType
            currentTab = 1

            for _, button in ipairs(parent.bankTypeButtons) do
                if button.bankType == currentBankType then
                    button:SetBackdropColor(T("ACCENT_PRIMARY"))
                    button:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                    button.label:SetTextColor(1, 1, 1)
                else
                    button:SetBackdropColor(T("BG_TERTIARY"))
                    button:SetBackdropBorderColor(T("BORDER_DEFAULT"))
                    button.label:SetTextColor(T("TEXT_SECONDARY"))
                end
            end

            if currentBankType == "guild" then
                guildDropdown:Show()
                buttonContainer:ClearAllPoints()
                buttonContainer:SetPoint("LEFT", guildDropdown, "RIGHT", 8, 0)
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
            else
                guildDropdown:Hide()
                buttonContainer:ClearAllPoints()
                buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
            end

            if ns.UI.RefreshBankDisplay then
                ns.UI.RefreshBankDisplay(parent)
            end
        end)

        return btn
    end

    local personalBtn = CreateBankTypeButton(L["BANK_PERSONAL"], "personal", 1)
    local warbandBtn = CreateBankTypeButton(L["BANK_WARBAND"], "warband", 2)
    local guildBtn = CreateBankTypeButton(L["BANK_GUILD"], "guild", 3)
    local bagsBtn = CreateBankTypeButton(L["BANK_BAGS"], "bags", 4)

    parent.bankTypeButtons = { personalBtn, warbandBtn, guildBtn, bagsBtn }

    local function LayoutBankButtons()
        local containerWidth = buttonContainer:GetWidth()
        local numButtons = #parent.bankTypeButtons
        local totalGap = 8 * (numButtons - 1)
        local buttonWidth = (containerWidth - totalGap) / numButtons

        for i, btn in ipairs(parent.bankTypeButtons) do
            btn:SetWidth(buttonWidth)
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", parent.bankTypeButtons[i-1], "RIGHT", 8, 0)
            end
        end
    end

    buttonContainer:SetScript("OnSizeChanged", LayoutBankButtons)
    C_Timer.After(0.1, LayoutBankButtons)

    personalBtn:SetBackdropColor(T("ACCENT_PRIMARY"))
    personalBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
    personalBtn.label:SetTextColor(1, 1, 1)

    local updateButton = CreateFrame("Button", nil, controlPanel, "BackdropTemplate")
    updateButton:SetSize(120, 28)
    updateButton:SetPoint("BOTTOMRIGHT", controlPanel, "BOTTOMRIGHT", -10, 6)
    updateButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    updateButton:SetBackdropColor(T("BG_TERTIARY"))
    updateButton:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local updateText = updateButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    updateText:SetPoint("CENTER")
    updateText:SetText(L["BANK_UPDATE_BANKS"])
    updateText:SetTextColor(T("TEXT_PRIMARY"))

    updateButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        updateText:SetTextColor(T("TEXT_ACCENT"))
    end)
    updateButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        updateText:SetTextColor(T("TEXT_PRIMARY"))
    end)
    updateButton:SetScript("OnClick", function()
        print("|cFFFFD100OneWoW|r AltTracker: " .. L["BANK_UPDATE_BANKS"])
    end)

    local bankViewPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bankViewPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -8)
    bankViewPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    bankViewPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bankViewPanel:SetBackdropColor(T("BG_PRIMARY"))
    bankViewPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local gridContainer = CreateFrame("Frame", nil, bankViewPanel)
    gridContainer:SetPoint("TOPLEFT", bankViewPanel, "TOPLEFT", 10, -10)
    gridContainer:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -75, 10)

    local tabContainer = CreateFrame("Frame", nil, bankViewPanel)
    tabContainer:SetPoint("TOPRIGHT", bankViewPanel, "TOPRIGHT", -5, -10)
    tabContainer:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -5, 10)
    tabContainer:SetWidth(65)

    local bagScrollFrame = CreateFrame("ScrollFrame", nil, bankViewPanel)
    bagScrollFrame:SetPoint("TOPLEFT", bankViewPanel, "TOPLEFT", 10, -10)
    bagScrollFrame:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -17, 10)
    bagScrollFrame:Hide()

    local bagScrollContent = CreateFrame("Frame", nil, bagScrollFrame)
    bagScrollContent:SetWidth(1)
    bagScrollContent:SetHeight(1)
    bagScrollFrame:SetScrollChild(bagScrollContent)

    local bagScrollBar = CreateFrame("Slider", nil, bankViewPanel, "BackdropTemplate")
    bagScrollBar:SetPoint("TOPLEFT", bagScrollFrame, "TOPRIGHT", 2, 0)
    bagScrollBar:SetPoint("BOTTOMLEFT", bagScrollFrame, "BOTTOMRIGHT", 2, 0)
    bagScrollBar:SetWidth(10)
    bagScrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    bagScrollBar:SetBackdropColor(T("BG_TERTIARY"))
    bagScrollBar:SetMinMaxValues(0, 0)
    bagScrollBar:SetValue(0)
    bagScrollBar:Hide()
    bagScrollBar:SetScript("OnValueChanged", function(s, value)
        bagScrollFrame:SetVerticalScroll(value)
    end)

    local bagScrollThumb = bagScrollBar:CreateTexture(nil, "OVERLAY")
    bagScrollThumb:SetSize(8, 30)
    bagScrollThumb:SetColorTexture(T("ACCENT_PRIMARY"))
    bagScrollBar:SetThumbTexture(bagScrollThumb)

    bagScrollFrame:EnableMouseWheel(true)
    bagScrollFrame:SetScript("OnMouseWheel", function(sf, direction)
        local current = bagScrollFrame:GetVerticalScroll()
        local maxScroll = math.max(0, bagScrollContent:GetHeight() - bagScrollFrame:GetHeight())
        local new = math.max(0, math.min(maxScroll, current - (direction * 42)))
        bagScrollFrame:SetVerticalScroll(new)
        bagScrollBar:SetValue(new)
    end)

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    statusBar:SetPoint("TOPLEFT", bankViewPanel, "BOTTOMLEFT", 0, -5)
    statusBar:SetPoint("TOPRIGHT", bankViewPanel, "BOTTOMRIGHT", 0, -5)
    statusBar:SetHeight(25)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetTextColor(T("TEXT_SECONDARY"))
    statusText:SetText(L["BANK_VIEWING"] .. ": " .. currentChar .. " - " .. L["BANK_PERSONAL"])

    parent.controlPanel = controlPanel
    parent.controlTitle = controlTitle
    parent.bankViewPanel = bankViewPanel
    parent.gridContainer = gridContainer
    parent.tabContainer = tabContainer
    parent.statusBar = statusBar
    parent.statusText = statusText
    parent.charDropdown = charDropdown
    parent.guildDropdown = guildDropdown
    parent.buttonContainer = buttonContainer
    parent.updateButton = updateButton
    parent.itemFramePool = {}
    parent.tabButtons = {}
    parent.bagScrollFrame = bagScrollFrame
    parent.bagScrollContent = bagScrollContent
    parent.bagScrollBar = bagScrollBar
    parent.bagItemFramePool = {}

    local function InitializeCharacterDropdown()
        if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
            charDropdownText:SetText(L["BANK_NO_CHARACTERS"] or "No Characters")
            return
        end

        local characterList = {}
        for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
            table.insert(characterList, {
                text = charData.name or charKey,
                key = charKey,
                name = charData.name or charKey
            })
        end

        table.sort(characterList, function(a, b)
            return a.name < b.name
        end)

        for _, charInfo in ipairs(characterList) do
            if charInfo.key == selectedCharacterKey then
                charDropdownText:SetText(charInfo.text)
                break
            end
        end

        charDropdown:SetScript("OnClick", function(self)
            if self._menu and self._menu:IsShown() then
                self._menu:Hide()
                return
            end

            local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
            self._menu = menu
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetSize(self:GetWidth() + 20, 314)
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            menu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            menu:SetBackdropColor(T("BG_SECONDARY"))
            menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            menu:EnableMouse(true)

            local searchBox = ns.UI.CreateEditBox(nil, menu, menu:GetWidth() - 15, 28)
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            searchBox:SetMaxLetters(50)

            local separator = menu:CreateTexture(nil, "ARTWORK")
            separator:SetSize(menu:GetWidth() - 4, 1)
            separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
            separator:SetColorTexture(T("BORDER_DEFAULT"))

            local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
            scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -36)
            scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -13, 2)

            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollChild:SetWidth(scrollFrame:GetWidth())
            scrollFrame:SetScrollChild(scrollChild)

            local scrollBar = CreateFrame("Slider", nil, menu, "BackdropTemplate")
            scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, 0)
            scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
            scrollBar:SetWidth(10)
            scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            scrollBar:SetBackdropColor(T("BG_TERTIARY"))
            scrollBar:SetMinMaxValues(0, 1)
            scrollBar:SetValue(0)
            scrollBar:SetScript("OnValueChanged", function(s, value)
                scrollFrame:SetVerticalScroll(value)
            end)

            local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(8, 30)
            thumb:SetColorTexture(T("ACCENT_PRIMARY"))
            scrollBar:SetThumbTexture(thumb)

            scrollFrame:EnableMouseWheel(true)
            scrollFrame:SetScript("OnMouseWheel", function(sf, direction)
                local current = scrollFrame:GetVerticalScroll()
                local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
                local new = math.max(0, math.min(maxScroll, current - (direction * 28)))
                scrollFrame:SetVerticalScroll(new)
                scrollBar:SetValue(new)
            end)

            local buttons = {}
            for _, charInfo in ipairs(characterList) do
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollFrame:GetWidth() - 4, 26)
                btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                if charInfo.key == selectedCharacterKey then
                    btn:SetBackdropColor(T("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(T("BG_TERTIARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
                txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                txt:SetJustifyH("LEFT")
                txt:SetText(charInfo.text)
                txt:SetTextColor(T("TEXT_PRIMARY"))

                btn:SetScript("OnEnter", function(b)
                    if charInfo.key ~= selectedCharacterKey then
                        b:SetBackdropColor(T("BG_HOVER"))
                        txt:SetTextColor(T("TEXT_ACCENT"))
                    end
                end)
                btn:SetScript("OnLeave", function(b)
                    if charInfo.key ~= selectedCharacterKey then
                        b:SetBackdropColor(T("BG_TERTIARY"))
                        txt:SetTextColor(T("TEXT_PRIMARY"))
                    end
                end)
                btn:SetScript("OnClick", function()
                    selectedCharacterKey = charInfo.key
                    charDropdownText:SetText(charInfo.text)
                    currentTab = 1
                    menu:Hide()
                    if ns.UI.RefreshBankDisplay then
                        ns.UI.RefreshBankDisplay(parent)
                    end
                end)

                btn.filterKey = charInfo.name:lower()
                btn:Hide()
                table.insert(buttons, btn)
            end

            local function renderList(filter)
                local yPos = -2
                for _, btn in ipairs(buttons) do
                    if filter == "" or string.find(btn.filterKey, filter, 1, true) then
                        btn:ClearAllPoints()
                        btn:SetPoint("TOP", scrollChild, "TOP", 0, yPos)
                        btn:Show()
                        yPos = yPos - 28
                    else
                        btn:Hide()
                    end
                end
                local totalH = math.max(28, math.abs(yPos) + 2)
                scrollChild:SetHeight(totalH)
                local maxScroll = math.max(0, totalH - scrollFrame:GetHeight())
                scrollBar:SetMinMaxValues(0, maxScroll)
                scrollFrame:SetVerticalScroll(0)
                scrollBar:SetValue(0)
            end

            renderList("")

            searchBox:SetScript("OnTextChanged", function(s)
                renderList(s:GetText():lower())
            end)
            searchBox:SetScript("OnEscapePressed", function(s)
                if s:GetText() ~= "" then
                    s:SetText("")
                    renderList("")
                else
                    menu:Hide()
                end
            end)

            menu:SetScript("OnShow", function(m)
                local timeOutside = 0
                m:SetScript("OnUpdate", function(m2, elapsed)
                    if not MouseIsOver(menu) and not MouseIsOver(self) and not searchBox:HasFocus() then
                        timeOutside = timeOutside + elapsed
                        if timeOutside > 0.5 then
                            m2:Hide()
                            m2:SetScript("OnUpdate", nil)
                        end
                    else
                        timeOutside = 0
                    end
                end)
            end)

            menu:Show()
            searchBox:SetFocus()
        end)
    end

    local function InitializeGuildDropdown()
        if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.guildBanks then
            guildDropdownText:SetText(L["BANK_NO_GUILDS"])
            return
        end

        local guildList = {}
        for guildName, guildData in pairs(_G.OneWoW_AltTracker_Storage_DB.guildBanks) do
            if guildData and guildData.tabs and next(guildData.tabs) then
                table.insert(guildList, {
                    name = guildName,
                    lastUpdate = guildData.lastScan or 0
                })
            end
        end

        table.sort(guildList, function(a, b)
            return a.name < b.name
        end)

        if #guildList > 0 then
            if not selectedGuildName or selectedGuildName == "" then
                local currentPlayerGuild = IsInGuild() and GetGuildInfo("player")
                selectedGuildName = currentPlayerGuild or guildList[1].name
            end

            local foundGuild = false
            for _, guildInfo in ipairs(guildList) do
                if guildInfo.name == selectedGuildName then
                    guildDropdownText:SetText(guildInfo.name)
                    foundGuild = true
                    break
                end
            end

            if not foundGuild then
                selectedGuildName = guildList[1].name
                guildDropdownText:SetText(guildList[1].name)
            end

            guildDropdown:SetScript("OnClick", function(self)
                if self._menu and self._menu:IsShown() then
                    self._menu:Hide()
                    return
                end

                local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
                self._menu = menu
                menu:SetFrameStrata("FULLSCREEN_DIALOG")
                menu:SetSize(self:GetWidth() + 20, 314)
                menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                menu:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                menu:SetBackdropColor(T("BG_SECONDARY"))
                menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
                menu:EnableMouse(true)

                local searchBox = ns.UI.CreateEditBox(nil, menu, menu:GetWidth() - 15, 28)
                searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
                searchBox:SetMaxLetters(50)

                local separator = menu:CreateTexture(nil, "ARTWORK")
                separator:SetSize(menu:GetWidth() - 4, 1)
                separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
                separator:SetColorTexture(T("BORDER_DEFAULT"))

                local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
                scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -36)
                scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -13, 2)

                local scrollChild = CreateFrame("Frame", nil, scrollFrame)
                scrollChild:SetWidth(scrollFrame:GetWidth())
                scrollFrame:SetScrollChild(scrollChild)

                local scrollBar = CreateFrame("Slider", nil, menu, "BackdropTemplate")
                scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, 0)
                scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
                scrollBar:SetWidth(10)
                scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                scrollBar:SetBackdropColor(T("BG_TERTIARY"))
                scrollBar:SetMinMaxValues(0, 1)
                scrollBar:SetValue(0)
                scrollBar:SetScript("OnValueChanged", function(s, value)
                    scrollFrame:SetVerticalScroll(value)
                end)

                local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
                thumb:SetSize(8, 30)
                thumb:SetColorTexture(T("ACCENT_PRIMARY"))
                scrollBar:SetThumbTexture(thumb)

                scrollFrame:EnableMouseWheel(true)
                scrollFrame:SetScript("OnMouseWheel", function(sf, direction)
                    local current = scrollFrame:GetVerticalScroll()
                    local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
                    local new = math.max(0, math.min(maxScroll, current - (direction * 28)))
                    scrollFrame:SetVerticalScroll(new)
                    scrollBar:SetValue(new)
                end)

                local buttons = {}
                for _, guildInfo in ipairs(guildList) do
                    local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                    btn:SetSize(scrollFrame:GetWidth() - 4, 26)
                    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    if guildInfo.name == selectedGuildName then
                        btn:SetBackdropColor(T("ACCENT_PRIMARY"))
                    else
                        btn:SetBackdropColor(T("BG_TERTIARY"))
                    end

                    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
                    txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                    txt:SetJustifyH("LEFT")
                    txt:SetText(guildInfo.name)
                    txt:SetTextColor(T("TEXT_PRIMARY"))

                    btn:SetScript("OnEnter", function(b)
                        if guildInfo.name ~= selectedGuildName then
                            b:SetBackdropColor(T("BG_HOVER"))
                            txt:SetTextColor(T("TEXT_ACCENT"))
                        end
                    end)
                    btn:SetScript("OnLeave", function(b)
                        if guildInfo.name ~= selectedGuildName then
                            b:SetBackdropColor(T("BG_TERTIARY"))
                            txt:SetTextColor(T("TEXT_PRIMARY"))
                        end
                    end)
                    btn:SetScript("OnClick", function()
                        selectedGuildName = guildInfo.name
                        guildDropdownText:SetText(guildInfo.name)
                        currentTab = 1
                        menu:Hide()
                        if ns.UI.RefreshBankDisplay then
                            ns.UI.RefreshBankDisplay(parent)
                        end
                    end)

                    btn.filterKey = guildInfo.name:lower()
                    btn:Hide()
                    table.insert(buttons, btn)
                end

                local function renderList(filter)
                    local yPos = -2
                    for _, btn in ipairs(buttons) do
                        if filter == "" or string.find(btn.filterKey, filter, 1, true) then
                            btn:ClearAllPoints()
                            btn:SetPoint("TOP", scrollChild, "TOP", 0, yPos)
                            btn:Show()
                            yPos = yPos - 28
                        else
                            btn:Hide()
                        end
                    end
                    local totalH = math.max(28, math.abs(yPos) + 2)
                    scrollChild:SetHeight(totalH)
                    local maxScroll = math.max(0, totalH - scrollFrame:GetHeight())
                    scrollBar:SetMinMaxValues(0, maxScroll)
                    scrollFrame:SetVerticalScroll(0)
                    scrollBar:SetValue(0)
                end

                renderList("")

                searchBox:SetScript("OnTextChanged", function(s)
                    renderList(s:GetText():lower())
                end)
                searchBox:SetScript("OnEscapePressed", function(s)
                    if s:GetText() ~= "" then
                        s:SetText("")
                        renderList("")
                    else
                        menu:Hide()
                    end
                end)

                menu:SetScript("OnShow", function(m)
                    local timeOutside = 0
                    m:SetScript("OnUpdate", function(m2, elapsed)
                        if not MouseIsOver(menu) and not MouseIsOver(self) and not searchBox:HasFocus() then
                            timeOutside = timeOutside + elapsed
                            if timeOutside > 0.5 then
                                m2:Hide()
                                m2:SetScript("OnUpdate", nil)
                            end
                        else
                            timeOutside = 0
                        end
                    end)
                end)

                menu:Show()
                searchBox:SetFocus()
            end)
        else
            selectedGuildName = nil
            guildDropdownText:SetText(L["BANK_NO_GUILDS"])
        end
    end

    InitializeCharacterDropdown()
    InitializeGuildDropdown()

    parent.lastGuildBankUpdate = 0

    local guildBankEventFrame = CreateFrame("Frame")
    guildBankEventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    guildBankEventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")
    guildBankEventFrame:SetScript("OnEvent", function(self, event)
        local now = GetTime()
        if (now - parent.lastGuildBankUpdate) > 2 then
            parent.lastGuildBankUpdate = now
            C_Timer.After(1.5, function()
                if ns.UI.RefreshBankDisplay and parent:IsVisible() then
                    ns.UI.RefreshBankDisplay(parent)
                end
            end)
        end
    end)
    parent.guildBankEventFrame = guildBankEventFrame

    parent:SetScript("OnSizeChanged", function(self)
        if not (self.bagScrollFrame and self.bagScrollFrame:IsShown()) then return end
        if self._bagResizeTimer then
            self._bagResizeTimer:Cancel()
            self._bagResizeTimer = nil
        end
        self._bagResizeTimer = C_Timer.NewTimer(1, function()
            self._bagResizeTimer = nil
            if ns.UI.RefreshBankDisplay and self.bagScrollFrame and self.bagScrollFrame:IsShown() then
                ns.UI.RefreshBankDisplay(self)
            end
        end)
    end)

    parent.RefreshData = function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end

    parent.Activate = function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end

    parent:SetScript("OnShow", function(self)
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(self)
        end
    end)

    if not ns.UI.BankTabReference then
        ns.UI.BankTabReference = {}
    end
    ns.UI.BankTabReference.parent = parent

    _G.OneWoW_AltTracker = _G.OneWoW_AltTracker or {}
    _G.OneWoW_AltTracker.UI = _G.OneWoW_AltTracker.UI or {}
    _G.OneWoW_AltTracker.UI.RefreshBankDisplay = ns.UI.RefreshBankDisplay
    _G.OneWoW_AltTracker.UI.BankTab = parent

    C_Timer.After(0.3, function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end)
end

function ns.UI.RefreshBankDisplay(parent)
    if not parent or not parent.bankViewPanel then return end

    local charName = selectedCharacterKey:match("([^-]+)") or selectedCharacterKey
    local bankTypeName = L["BANK_" .. currentBankType:upper()] or currentBankType

    if currentBankType == "bags" then
        parent.gridContainer:Hide()
        parent.tabContainer:Hide()
        if parent.bagScrollFrame then parent.bagScrollFrame:Show() end
        if parent.bagScrollBar then parent.bagScrollBar:Show() end

        ns.UI.CleanupBankFrames(parent, true)

        local bankData = ns.UI.GetBankData(selectedCharacterKey, currentBankType, selectedGuildName)
        local sortedItems = {}

        if bankData and bankData.bags then
            for bagID = 0, 5 do
                local bagData = bankData.bags[bagID]
                if bagData and bagData.slots then
                    for _, itemData in pairs(bagData.slots) do
                        if itemData then
                            table.insert(sortedItems, itemData)
                        end
                    end
                end
            end
        end

        table.sort(sortedItems, function(a, b)
            local nameA = a.itemName
            local nameB = b.itemName
            if nameA and nameB then
                return nameA < nameB
            elseif nameA then
                return true
            elseif nameB then
                return false
            else
                return (a.itemID or 0) < (b.itemID or 0)
            end
        end)

        ns.UI.DisplayOneBagGrid(parent, sortedItems)

        if parent.controlTitle then
            parent.controlTitle:SetText(charName .. " - " .. bankTypeName)
        end

        if parent.statusText then
            parent.statusText:SetText(L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. #sortedItems .. " " .. L["BANK_ITEMS"])
        end
    else
        if parent.bagScrollFrame then parent.bagScrollFrame:Hide() end
        if parent.bagScrollBar then parent.bagScrollBar:Hide() end
        parent.gridContainer:Show()
        parent.tabContainer:Show()

        ns.UI.CleanupBankFrames(parent, true)
        ns.UI.CreateBankTabs(parent)

        local bankData = ns.UI.GetBankData(selectedCharacterKey, currentBankType, selectedGuildName)
        local items = {}

        if bankData then
            if currentBankType == "personal" then
                if bankData.personalBank and bankData.personalBank.tabs then
                    if bankData.personalBank.tabs[currentTab] and bankData.personalBank.tabs[currentTab].items then
                        for slotID, itemData in pairs(bankData.personalBank.tabs[currentTab].items) do
                            items[slotID] = itemData
                        end
                    end
                end
            elseif currentBankType == "warband" then
                if bankData.warbandBank and bankData.warbandBank.tabs and bankData.warbandBank.tabs[currentTab] then
                    if bankData.warbandBank.tabs[currentTab].items then
                        for slotID, itemData in pairs(bankData.warbandBank.tabs[currentTab].items) do
                            items[slotID] = itemData
                        end
                    end
                end
            elseif currentBankType == "guild" then
                if bankData.guildBank and bankData.guildBank.tabs and bankData.guildBank.tabs[currentTab] and bankData.guildBank.tabs[currentTab].slots then
                    for slotID, itemData in pairs(bankData.guildBank.tabs[currentTab].slots) do
                        items[slotID] = itemData
                    end
                end
            end
        end

        ns.UI.DisplayBankGrid(parent, items)

        local statusMessage = L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. string.format(L["AB_LABEL_BAR"], currentTab)

        if parent.controlTitle then
            if currentBankType == "guild" and selectedGuildName then
                parent.controlTitle:SetText(selectedGuildName .. " - " .. L["BANK_GUILD"])
            else
                parent.controlTitle:SetText(charName .. " - " .. bankTypeName)
            end
        end

        if parent.statusText then
            parent.statusText:SetText(statusMessage)
        end
    end
end

function ns.UI.GetBankData(characterKey, bankType, guildName)
    if not _G.OneWoW_AltTracker_Storage_DB then return nil end
    if not characterKey then return nil end

    local charData = _G.OneWoW_AltTracker_Storage_DB.characters and _G.OneWoW_AltTracker_Storage_DB.characters[characterKey]
    if not charData then return nil end

    return {
        bags = charData.bags,
        personalBank = charData.personalBank,
        warbandBank = _G.OneWoW_AltTracker_Storage_DB.warbandBank,
        guildBank = guildName and _G.OneWoW_AltTracker_Storage_DB.guildBanks and _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName] or nil,
    }
end

function ns.UI.CreateBankTabs(parent)
    ns.UI.CleanupBankTabs(parent)
    if currentBankType == "bags" then return end

    if not parent.tabButtons then
        parent.tabButtons = {}
    end

    local maxTabs = 6
    if currentBankType == "bags" then
        maxTabs = 6
    elseif currentBankType == "personal" then
        if bankData and bankData.personalBank and bankData.personalBank.tabs then
            maxTabs = 0
            for tabID, _ in pairs(bankData.personalBank.tabs) do
                if tabID > maxTabs then
                    maxTabs = tabID
                end
            end
        else
            maxTabs = 6
        end
    elseif currentBankType == "warband" then
        maxTabs = 5
    elseif currentBankType == "guild" then
        maxTabs = 8
    end

    local bagNames = {
        L["BANK_BACKPACK"], L["BANK_BAG_1"], L["BANK_BAG_2"],
        L["BANK_BAG_3"], L["BANK_BAG_4"], L["BANK_REAGENTS"]
    }

    for i = 1, maxTabs do
        local tabBtn = CreateFrame("Button", nil, parent.tabContainer, "BackdropTemplate")
        tabBtn:SetSize(58, 50)
        tabBtn:SetPoint("TOP", parent.tabContainer, "TOP", 0, -((i - 1) * 55))
        tabBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tabBtn:SetBackdropColor(T("BG_TERTIARY"))
        tabBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local icon = tabBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("CENTER", tabBtn, "CENTER", 0, 4)

        if currentBankType == "bags" and bankData and bankData.bags then
            local bagSlot = i - 1
            local bagItemID = nil

            if bagSlot == 0 then
                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            elseif bagSlot == 5 then
                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_CenarionHerbBag")
            else
                local containerInfo = C_Container.GetContainerNumSlots(bagSlot)
                if containerInfo and containerInfo > 0 then
                    local invSlot = ContainerIDToInventoryID(bagSlot)
                    if invSlot then
                        bagItemID = GetInventoryItemID("player", invSlot)
                        if bagItemID then
                            local bagIcon = C_Item.GetItemIconByID(bagItemID)
                            if bagIcon then
                                icon:SetTexture(bagIcon)
                            else
                                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                            end
                        else
                            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                        end
                    else
                        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                    end
                else
                    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                end
            end
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
        end

        tabBtn.icon = icon

        local tabText = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabText:SetPoint("BOTTOM", tabBtn, "BOTTOM", 0, 4)
        tabText:SetTextColor(T("TEXT_SECONDARY"))

        if currentBankType == "bags" then
            local shortName = bagNames[i]:gsub("Bag ", ""):gsub("Backpack", "BP"):gsub("Reagents", "R")
            tabText:SetText(shortName)
        else
            tabText:SetText(tostring(i))
        end

        tabBtn.text = tabText

        tabBtn:SetScript("OnEnter", function(self)
            if currentTab ~= i then
                self:SetBackdropColor(T("BG_HOVER"))
                self.text:SetTextColor(T("TEXT_ACCENT"))
            end
        end)

        tabBtn:SetScript("OnLeave", function(self)
            if currentTab ~= i then
                self:SetBackdropColor(T("BG_TERTIARY"))
                self.text:SetTextColor(T("TEXT_SECONDARY"))
            end
        end)

        tabBtn:SetScript("OnClick", function()
            currentTab = i

            for tabIndex, btn in ipairs(parent.tabButtons) do
                if tabIndex == i then
                    btn:SetBackdropColor(T("ACCENT_PRIMARY"))
                    btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                    btn.text:SetTextColor(1, 1, 1)
                else
                    btn:SetBackdropColor(T("BG_TERTIARY"))
                    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                    btn.text:SetTextColor(T("TEXT_SECONDARY"))
                end
            end

            if ns.UI.RefreshBankDisplay then
                ns.UI.RefreshBankDisplay(parent)
            end
        end)

        if i == currentTab then
            tabBtn:SetBackdropColor(T("ACCENT_PRIMARY"))
            tabBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            tabBtn.text:SetTextColor(1, 1, 1)
        end

        table.insert(parent.tabButtons, tabBtn)
    end
end

function ns.UI.DisplayBankGrid(parent, items)
    local itemSize = 40
    local itemSpacing = 2
    local slotsPerRow = 14
    local maxRows = 7

    for col = 0, slotsPerRow - 1 do
        for row = 0, maxRows - 1 do
            local slotIndex = col * maxRows + row + 1
            local itemInfo = items[slotIndex]

            local x = col * (itemSize + itemSpacing)
            local y = -row * (itemSize + itemSpacing)

            local itemFrame = ns.UI.GetItemFrame(parent)
            itemFrame:SetSize(itemSize, itemSize)
            itemFrame:SetPoint("TOPLEFT", parent.gridContainer, "TOPLEFT", x, y)
            itemFrame:Show()

            if not itemFrame.bg then
                itemFrame.bg = itemFrame:CreateTexture(nil, "BACKGROUND")
                itemFrame.bg:SetAllPoints()
                itemFrame.bg:SetColorTexture(T("BG_SECONDARY"))
            end

            if not itemFrame.border then
                itemFrame.border = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
                itemFrame.border:SetAllPoints()
                itemFrame.border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                itemFrame.border:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            end

            if not itemFrame.texture then
                itemFrame.texture = itemFrame:CreateTexture(nil, "ARTWORK")
                itemFrame.texture:SetSize(itemSize - 6, itemSize - 6)
                itemFrame.texture:SetPoint("CENTER")
            end

            if not itemFrame.qualityBorder then
                itemFrame.qualityBorder = itemFrame:CreateTexture(nil, "BORDER")
                itemFrame.qualityBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
                itemFrame.qualityBorder:SetSize(itemSize - 4, itemSize - 4)
                itemFrame.qualityBorder:SetPoint("CENTER")
                itemFrame.qualityBorder:Hide()
            end

            if not itemFrame.count then
                itemFrame.count = itemFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                itemFrame.count:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", -2, 2)
                itemFrame.count:SetJustifyH("RIGHT")
            end

            if itemInfo and itemInfo.itemID then
                local itemTexture = C_Item.GetItemIconByID(itemInfo.itemID)
                if itemTexture then
                    itemFrame.texture:SetTexture(itemTexture)
                else
                    itemFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end

                local quality = itemInfo.quality
                if quality and quality > 1 then
                    local r, g, b = C_Item.GetItemQualityColor(quality)
                    itemFrame.qualityBorder:SetColorTexture(r, g, b, 1.0)
                    itemFrame.qualityBorder:Show()
                else
                    itemFrame.qualityBorder:Hide()
                end

                if itemInfo.stackCount and itemInfo.stackCount > 1 then
                    itemFrame.count:SetText(itemInfo.stackCount)
                    itemFrame.count:Show()
                else
                    itemFrame.count:Hide()
                end

                itemFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if itemInfo.itemLink then
                        GameTooltip:SetHyperlink(itemInfo.itemLink)
                    else
                        GameTooltip:SetItemByID(itemInfo.itemID)
                    end
                    GameTooltip:Show()
                end)

                itemFrame:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            else
                itemFrame.texture:SetTexture(nil)
                itemFrame.qualityBorder:Hide()
                itemFrame.count:Hide()

                itemFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L["BANK_EMPTY_SLOT"], 1, 1, 1)
                    GameTooltip:AddLine(L["BANK_SLOT"] .. " " .. slotIndex, 0.7, 0.7, 0.7, true)
                    GameTooltip:Show()
                end)

                itemFrame:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            end
        end
    end
end

function ns.UI.DisplayOneBagGrid(parent, sortedItems)
    if not parent.bagScrollFrame or not parent.bagScrollContent then return end

    if parent.bagItemFramePool then
        for _, f in ipairs(parent.bagItemFramePool) do
            if f then
                f:Hide()
                f:ClearAllPoints()
            end
        end
    else
        parent.bagItemFramePool = {}
    end

    local itemSize = 40
    local itemSpacing = 2
    local step = itemSize + itemSpacing
    local panelWidth = parent.bagScrollFrame:GetWidth()
    if panelWidth <= 0 then panelWidth = 840 end
    local xPad = step
    local columns = math.max(1, math.floor((panelWidth - xPad * 2) / step))

    parent.bagScrollContent:SetWidth(panelWidth)

    for i, itemData in ipairs(sortedItems) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = xPad + col * step
        local y = -row * step

        local itemFrame = ns.UI.GetBagItemFrame(parent)
        itemFrame:SetSize(itemSize, itemSize)
        itemFrame:SetPoint("TOPLEFT", parent.bagScrollContent, "TOPLEFT", x, y)
        itemFrame:Show()

        if not itemFrame.bg then
            itemFrame.bg = itemFrame:CreateTexture(nil, "BACKGROUND")
            itemFrame.bg:SetAllPoints()
            itemFrame.bg:SetColorTexture(T("BG_SECONDARY"))
        end

        if not itemFrame.border then
            itemFrame.border = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
            itemFrame.border:SetAllPoints()
            itemFrame.border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            itemFrame.border:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end

        if not itemFrame.texture then
            itemFrame.texture = itemFrame:CreateTexture(nil, "ARTWORK")
            itemFrame.texture:SetSize(itemSize - 6, itemSize - 6)
            itemFrame.texture:SetPoint("CENTER")
        end

        if not itemFrame.qualityBorder then
            itemFrame.qualityBorder = itemFrame:CreateTexture(nil, "BORDER")
            itemFrame.qualityBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
            itemFrame.qualityBorder:SetSize(itemSize - 4, itemSize - 4)
            itemFrame.qualityBorder:SetPoint("CENTER")
            itemFrame.qualityBorder:Hide()
        end

        if not itemFrame.count then
            itemFrame.count = itemFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            itemFrame.count:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", -2, 2)
            itemFrame.count:SetJustifyH("RIGHT")
        end

        local itemTexture = C_Item.GetItemIconByID(itemData.itemID)
        if itemTexture then
            itemFrame.texture:SetTexture(itemTexture)
        else
            itemFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local quality = itemData.quality
        if quality and quality > 1 then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            itemFrame.qualityBorder:SetColorTexture(r, g, b, 1.0)
            itemFrame.qualityBorder:Show()
        else
            itemFrame.qualityBorder:Hide()
        end

        if itemData.stackCount and itemData.stackCount > 1 then
            itemFrame.count:SetText(itemData.stackCount)
            itemFrame.count:Show()
        else
            itemFrame.count:Hide()
        end

        itemFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemData.itemLink then
                GameTooltip:SetHyperlink(itemData.itemLink)
            else
                GameTooltip:SetItemByID(itemData.itemID)
            end
            GameTooltip:Show()
        end)

        itemFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    local numRows = math.ceil(math.max(1, #sortedItems) / columns)
    local contentHeight = numRows * step + itemSpacing
    parent.bagScrollContent:SetHeight(contentHeight)

    if parent.bagScrollBar then
        local frameHeight = parent.bagScrollFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - frameHeight)
        parent.bagScrollBar:SetMinMaxValues(0, maxScroll)
        parent.bagScrollBar:SetValue(0)
        parent.bagScrollFrame:SetVerticalScroll(0)
    end
end

function ns.UI.GetBagItemFrame(parent)
    for _, pooledFrame in ipairs(parent.bagItemFramePool) do
        if pooledFrame and not pooledFrame:IsShown() then
            return pooledFrame
        end
    end

    local newFrame = CreateFrame("Button", nil, parent.bagScrollContent)
    newFrame:EnableMouse(true)
    table.insert(parent.bagItemFramePool, newFrame)

    return newFrame
end

function ns.UI.GetItemFrame(parent)
    for _, pooledFrame in ipairs(parent.itemFramePool) do
        if pooledFrame and not pooledFrame:IsShown() then
            return pooledFrame
        end
    end

    local newFrame = CreateFrame("Button", nil, parent.gridContainer)
    newFrame:EnableMouse(true)
    table.insert(parent.itemFramePool, newFrame)

    return newFrame
end

function ns.UI.CleanupBankFrames(parent, gridOnly)
    if not parent then return end

    if parent.itemFramePool then
        for _, itemFrame in ipairs(parent.itemFramePool) do
            if itemFrame then
                itemFrame:Hide()
                itemFrame:ClearAllPoints()
            end
        end
    end

    if parent.bagItemFramePool then
        for _, itemFrame in ipairs(parent.bagItemFramePool) do
            if itemFrame then
                itemFrame:Hide()
                itemFrame:ClearAllPoints()
            end
        end
    end

    if not gridOnly then
        ns.UI.CleanupBankTabs(parent)
    end
end

function ns.UI.CleanupBankTabs(parent)
    if not parent or not parent.tabButtons then return end

    for _, tabBtn in ipairs(parent.tabButtons) do
        if tabBtn then
            tabBtn:Hide()
            tabBtn:SetParent(nil)
            tabBtn:ClearAllPoints()
        end
    end

    wipe(parent.tabButtons)
end
