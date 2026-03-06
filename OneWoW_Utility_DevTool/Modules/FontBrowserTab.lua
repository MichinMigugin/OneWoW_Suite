local AddonName, Addon = ...

local FontBrowserTab = {}
Addon.FontBrowserTab = FontBrowserTab

FontBrowserTab.fonts = {
    {name = "GameFontNormal", object = GameFontNormal},
    {name = "GameFontNormalLarge", object = GameFontNormalLarge},
    {name = "GameFontNormalSmall", object = GameFontNormalSmall},
    {name = "GameFontHighlight", object = GameFontHighlight},
    {name = "GameFontHighlightLarge", object = GameFontHighlightLarge},
    {name = "GameFontHighlightSmall", object = GameFontHighlightSmall},
    {name = "GameFontDisable", object = GameFontDisable},
    {name = "GameFontGreen", object = GameFontGreen},
    {name = "GameFontRed", object = GameFontRed},
    {name = "GameFontWhite", object = GameFontWhite},
    {name = "QuestFont", object = QuestFont},
    {name = "QuestFontNormalSmall", object = QuestFontNormalSmall},
    {name = "NumberFontNormal", object = NumberFontNormal},
    {name = "NumberFontNormalLarge", object = NumberFontNormalLarge},
    {name = "NumberFontNormalSmall", object = NumberFontNormalSmall},
    {name = "SystemFont_Large", object = SystemFont_Large},
    {name = "SystemFont_Med1", object = SystemFont_Med1},
    {name = "SystemFont_Med2", object = SystemFont_Med2},
    {name = "SystemFont_Small", object = SystemFont_Small},
    {name = "Tooltip_Med", object = Tooltip_Med},
    {name = "Tooltip_Small", object = Tooltip_Small},
}

function FontBrowserTab:Initialize(parent)
    self.parent = parent

    local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    searchBox:SetSize(300, 25)
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    searchBox:SetAutoFocus(false)

    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchBox.placeholder:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    searchBox.placeholder:SetText("Search fonts...")

    searchBox:SetScript("OnEditFocusGained", function(self)
        self.placeholder:Hide()
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        FontBrowserTab:FilterFonts(self:GetText())
        if self:GetText() ~= "" then
            self.placeholder:Hide()
        elseif not self:HasFocus() then
            self.placeholder:Show()
        end
    end)

    local bookmarkButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    bookmarkButton:SetSize(120, 25)
    bookmarkButton:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    bookmarkButton:SetText("Bookmark")
    bookmarkButton:SetScript("OnClick", function()
        FontBrowserTab:ToggleBookmark()
    end)

    local listScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -45)
    listScroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    listScroll:SetWidth(350)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listScroll:SetScrollChild(listContent)
    listContent:SetSize(1, 1)

    listContent.bg = listContent:CreateTexture(nil, "BACKGROUND")
    listContent.bg:SetAllPoints()
    listContent.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    self.listButtons = {}
    for i = 1, 25 do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetSize(330, 25)
        btn:SetPoint("TOPLEFT", 5, -(i-1) * 25 - 5)
        btn:SetNormalFontObject(GameFontNormalSmall)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        btn.bg:Hide()

        btn:SetScript("OnEnter", function(self)
            self.bg:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            if not self.selected then
                self.bg:Hide()
            end
        end)

        btn:SetScript("OnClick", function(self)
            FontBrowserTab:SelectFont(self.fontData)
        end)

        self.listButtons[i] = btn
    end

    local previewPanel = CreateFrame("Frame", nil, parent)
    previewPanel:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 10, 0)
    previewPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

    previewPanel.bg = previewPanel:CreateTexture(nil, "BACKGROUND")
    previewPanel.bg:SetAllPoints()
    previewPanel.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    previewPanel.title = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewPanel.title:SetPoint("TOP", 0, -10)
    previewPanel.title:SetText("Select a font to preview")

    self.previewSmall = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.previewSmall:SetPoint("TOP", previewPanel.title, "BOTTOM", 0, -30)
    self.previewSmall:SetWidth(previewPanel:GetWidth() - 40)
    self.previewSmall:SetText("The quick brown fox jumps over the lazy dog\n0123456789")

    self.previewMedium = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.previewMedium:SetPoint("TOP", self.previewSmall, "BOTTOM", 0, -30)
    self.previewMedium:SetWidth(previewPanel:GetWidth() - 40)
    self.previewMedium:SetText("The quick brown fox jumps over the lazy dog\n0123456789")

    self.previewLarge = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.previewLarge:SetPoint("TOP", self.previewMedium, "BOTTOM", 0, -30)
    self.previewLarge:SetWidth(previewPanel:GetWidth() - 40)
    self.previewLarge:SetText("The quick brown fox jumps over the lazy dog\n0123456789")

    self.infoText = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.infoText:SetPoint("TOP", self.previewLarge, "BOTTOM", 0, -30)
    self.infoText:SetWidth(previewPanel:GetWidth() - 40)
    self.infoText:SetJustifyH("LEFT")
    self.infoText:SetText("")

    local copyButton = CreateFrame("Button", nil, previewPanel, "UIPanelButtonTemplate")
    copyButton:SetSize(150, 25)
    copyButton:SetPoint("TOP", self.infoText, "BOTTOM", 0, -20)
    copyButton:SetText("Copy Font Name")
    copyButton:SetScript("OnClick", function()
        FontBrowserTab:CopyFontName()
    end)

    self.searchBox = searchBox
    self.listScroll = listScroll
    self.listContent = listContent
    self.previewPanel = previewPanel

    self:FilterFonts("")
end

function FontBrowserTab:FilterFonts(filter)
    self.filteredFonts = {}
    filter = filter:upper()

    for _, fontData in ipairs(self.fonts) do
        if filter == "" or string.find(fontData.name:upper(), filter, 1, true) then
            table.insert(self.filteredFonts, fontData)
        end
    end

    self:UpdateList()
end

function FontBrowserTab:UpdateList()
    for i, btn in ipairs(self.listButtons) do
        local fontData = self.filteredFonts[i]

        if fontData then
            btn:SetText(fontData.name)
            btn.fontData = fontData
            btn:Show()

            if fontData == self.currentFont then
                btn.selected = true
                btn.bg:Show()
            else
                btn.selected = false
                btn.bg:Hide()
            end
        else
            btn:Hide()
        end
    end

    self.listContent:SetHeight(math.max(#self.filteredFonts * 25 + 10, self.listScroll:GetHeight()))
end

function FontBrowserTab:SelectFont(fontData)
    if not fontData then return end

    self.currentFont = fontData

    self.previewSmall:SetFontObject(fontData.object)
    self.previewMedium:SetFontObject(fontData.object)
    self.previewLarge:SetFontObject(fontData.object)

    local font, size, flags = fontData.object:GetFont()

    local infoLines = {
        "Font: " .. fontData.name,
        "File: " .. (font or "Unknown"),
        "Size: " .. (size or "Unknown"),
        "Flags: " .. (flags or "None"),
    }

    if self:IsBookmarked(fontData.name) then
        table.insert(infoLines, "|cff00ff00[Bookmarked]|r")
    end

    self.infoText:SetText(table.concat(infoLines, "\n"))
    self.previewPanel.title:SetText("Preview: " .. fontData.name)

    self:UpdateList()
end

function FontBrowserTab:ToggleBookmark()
    if not self.currentFont then
        Addon:Print("Select a font first")
        return
    end

    if not Addon.db.fontBookmarks then
        Addon.db.fontBookmarks = {}
    end

    local name = self.currentFont.name

    if self:IsBookmarked(name) then
        Addon.db.fontBookmarks[name] = nil
        Addon:Print("Removed font bookmark: " .. name)
    else
        Addon.db.fontBookmarks[name] = true
        Addon:Print("Bookmarked font: " .. name)
    end

    self:SelectFont(self.currentFont)
end

function FontBrowserTab:IsBookmarked(fontName)
    return Addon.db.fontBookmarks and Addon.db.fontBookmarks[fontName]
end

function FontBrowserTab:CopyFontName()
    if not self.currentFont then
        Addon:Print("Select a font first")
        return
    end

    Addon:CopyToClipboard(self.currentFont.name)
end

function FontBrowserTab:OnShow()
end

function FontBrowserTab:OnHide()
end
