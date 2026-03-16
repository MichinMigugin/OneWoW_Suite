local AddonName, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local FontBrowserTab = {}
Addon.FontBrowserTab = FontBrowserTab

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

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

    local searchBox = OneWoW_GUI:CreateEditBox(parent, {
        width = 300,
        height = 25,
        placeholderText = "Search fonts...",
        onTextChanged = function(text)
            FontBrowserTab:FilterFonts(text)
        end,
    })
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)

    local bookmarkButton = OneWoW_GUI:CreateFitTextButton(parent, { text = "Bookmark", height = 25 })
    bookmarkButton:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    bookmarkButton:SetScript("OnClick", function()
        FontBrowserTab:ToggleBookmark()
    end)

    local listPanel = OneWoW_GUI:CreateFrame(parent, { backdrop = BACKDROP_INNER_NO_INSETS, width = 350, height = 200 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -45)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    listPanel:SetWidth(350)
    listPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, { name = "FontBrowserListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    self.listButtons = {}
    for i = 1, 25 do
        local btn = OneWoW_GUI:CreateListRowBasic(listContent, {
            height = 25,
            label = "",
            onClick = function(self)
                FontBrowserTab:SelectFont(self.fontData)
            end,
        })
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 5, -(i-1) * 25 - 5)
        btn:SetPoint("RIGHT", listContent, "RIGHT", -5, 0)
        btn.label:SetFontObject(GameFontNormalSmall)

        self.listButtons[i] = btn
    end

    local previewPanel = OneWoW_GUI:CreateFrame(parent, { backdrop = BACKDROP_INNER_NO_INSETS, width = 200, height = 200 })
    previewPanel:ClearAllPoints()
    previewPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
    previewPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    previewPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    previewPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    previewPanel.title = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewPanel.title:SetPoint("TOP", 0, -10)
    previewPanel.title:SetText("Select a font to preview")
    previewPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

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
    self.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyButton = OneWoW_GUI:CreateFitTextButton(previewPanel, { text = "Copy Font Name", height = 25 })
    copyButton:SetPoint("TOP", self.infoText, "BOTTOM", 0, -20)
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
            tinsert(self.filteredFonts, fontData)
        end
    end

    self:UpdateList()
end

function FontBrowserTab:UpdateList()
    for i, btn in ipairs(self.listButtons) do
        local fontData = self.filteredFonts[i]

        if fontData then
            btn.label:SetText(fontData.name)
            btn.fontData = fontData
            btn:SetActive(fontData == self.currentFont)
            btn:Show()
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
        tinsert(infoLines, "|cff00ff00[Bookmarked]|r")
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
