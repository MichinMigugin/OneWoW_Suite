local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

function Addon.UI:CreateTextureTab(parent)
    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local TEX_ROW_H = DU.TEXTURE_LIST_BUTTON_HEIGHT or 18
    local TEX_BASE = DU.TEXTURE_PREVIEW_BASE_SIZE or 256
    local ZOOM_IN = DU.TEXTURE_ZOOM_IN_FACTOR or 1.2
    local ZOOM_OUT = DU.TEXTURE_ZOOM_OUT_FACTOR or 0.8
    local ZMIN = DU.TEXTURE_ZOOM_MIN or 0.25
    local ZMAX = DU.TEXTURE_ZOOM_MAX or 4.0

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    tab.atlasList = Addon:LoadBuiltInAtlases()
    tab.filteredList = {}
    for _, name in ipairs(tab.atlasList) do
        tinsert(tab.filteredList, name)
    end

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 200,
        height = 22,
        placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
        onTextChanged = function(text)
            Addon.UI:FilterAtlases(text)
        end,
    })
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local favsBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_FAVORITES"] or "Favorites", width = 100, height = 22 })
    favsBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    favsBtn:SetScript("OnClick", function()
        Addon.UI:ShowFavorites()
    end)

    local bookmarkBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_BOOKMARK"] or "Bookmark", width = 100, height = 22 })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 5, 0)
    bookmarkBtn:SetScript("OnClick", function()
        Addon.UI:ToggleBookmark()
    end)

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 320, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(320)
    self:StyleContentPanel(leftPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "TextureTabListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.listButtons = {}
    for i = 1, 30 do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(TEX_ROW_H)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * TEX_ROW_H)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)

        btn:SetScript("OnClick", function(btnSelf)
            if btnSelf.atlasName then
                Addon.UI:SelectAtlas(btnSelf.atlasName)
            end
        end)

        tab.listButtons[i] = btn
    end

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    rightPanel:ClearAllPoints()
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    self:StyleContentPanel(rightPanel)

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOP", 0, -5)
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local zoomInBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_IN"] or "+", width = 40, height = 22 })
    zoomInBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -5, -5)
    zoomInBtn:SetScript("OnClick", function()
        Addon.UI:ZoomTexture(ZOOM_IN)
    end)

    local zoomOutBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_OUT"] or "-", width = 40, height = 22 })
    zoomOutBtn:SetPoint("RIGHT", zoomInBtn, "LEFT", -2, 0)
    zoomOutBtn:SetScript("OnClick", function()
        Addon.UI:ZoomTexture(ZOOM_OUT)
    end)

    local resetBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_RESET_ZOOM"] or "Reset", width = 60, height = 22 })
    resetBtn:SetPoint("RIGHT", zoomOutBtn, "LEFT", -2, 0)
    resetBtn:SetScript("OnClick", function()
        Addon.UI:ResetTextureZoom()
    end)

    local previewBg = rightPanel:CreateTexture(nil, "BACKGROUND")
    previewBg:SetPoint("TOP", tab.nameText, "BOTTOM", 0, -10)
    previewBg:SetSize(400, 400)
    previewBg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    tab.previewFrame = CreateFrame("Frame", nil, rightPanel)
    tab.previewFrame:SetPoint("CENTER", previewBg, "CENTER")
    tab.previewFrame:SetSize(TEX_BASE, TEX_BASE)

    tab.preview = tab.previewFrame:CreateTexture(nil, "ARTWORK")
    tab.preview:SetAllPoints(tab.previewFrame)

    local border = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", previewBg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    border:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    infoPanel:ClearAllPoints()
    infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -10)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -5, 35)
    self:StyleContentPanel(infoPanel)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, { name = "TextureTabInfoScroll" })
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)

    infoScroll:HookScript("OnSizeChanged", function(self, w)
        infoContent:SetWidth(w)
    end)

    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.infoScroll = infoScroll

    local copyBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_NAME"] or "Copy Name", width = 100, height = 22 })
    copyBtn:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if tab.currentAtlas then
            Addon:CopyToClipboard(tab.currentAtlas)
        end
    end)

    tab.listScroll = listScroll
    tab.zoomLevel = 1.0
    tab.selectedIndex = 1

    tab:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then
            Addon.UI:NavigateAtlasList(-1)
        elseif key == "DOWN" then
            Addon.UI:NavigateAtlasList(1)
        end
    end)

    tab:EnableKeyboard(true)
    tab:SetPropagateKeyboardInput(false)

    self:UpdateAtlasList()

    if #tab.atlasList > 0 then
        self:SelectAtlas(tab.atlasList[1])
    end

    Addon.TextureBrowserTab = tab
    return tab
end

function Addon.UI:NavigateAtlasList(direction)
    local tab = Addon.TextureBrowserTab
    if not tab or #tab.filteredList == 0 then return end

    tab.selectedIndex = tab.selectedIndex + direction

    if tab.selectedIndex < 1 then
        tab.selectedIndex = 1
    elseif tab.selectedIndex > #tab.filteredList then
        tab.selectedIndex = #tab.filteredList
    end

    local atlasName = tab.filteredList[tab.selectedIndex]
    if atlasName then
        self:SelectAtlas(atlasName)
        self:UpdateAtlasList()
    end
end

function Addon.UI:ZoomTexture(factor)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local TEX_BASE = DU.TEXTURE_PREVIEW_BASE_SIZE or 256
    local ZMIN = DU.TEXTURE_ZOOM_MIN or 0.25
    local ZMAX = DU.TEXTURE_ZOOM_MAX or 4.0

    tab.zoomLevel = tab.zoomLevel * factor
    tab.zoomLevel = math.max(ZMIN, math.min(ZMAX, tab.zoomLevel))

    local newSize = TEX_BASE * tab.zoomLevel
    tab.previewFrame:SetSize(newSize, newSize)
end

function Addon.UI:ResetTextureZoom()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local TEX_BASE = DU.TEXTURE_PREVIEW_BASE_SIZE or 256

    tab.zoomLevel = 1.0
    tab.previewFrame:SetSize(TEX_BASE, TEX_BASE)
end

function Addon.UI:FilterAtlases(filter)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    filter = (filter or ""):lower()
    tab.filteredList = {}

    if filter == "" then
        for _, name in ipairs(tab.atlasList) do
            tinsert(tab.filteredList, name)
        end
    else
        for _, name in ipairs(tab.atlasList) do
            if name:lower():find(filter, 1, true) then
                tinsert(tab.filteredList, name)
            end
        end
    end

    self:UpdateAtlasList()
end

function Addon.UI:UpdateAtlasList()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local TEX_ROW_H = DU.TEXTURE_LIST_BUTTON_HEIGHT or 18

    for i, btn in ipairs(tab.listButtons) do
        local name = tab.filteredList[i]
        if name then
            btn:SetText(name)
            btn.atlasName = name

            if name == tab.currentAtlas then
                btn:SetNormalFontObject(GameFontHighlight)
                btn:LockHighlight()
            else
                btn:SetNormalFontObject(GameFontNormalSmall)
                btn:UnlockHighlight()
            end

            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#tab.filteredList * TEX_ROW_H + 5, tab.listScroll:GetHeight())
    tab.listScroll:GetScrollChild():SetHeight(height)
end

function Addon.UI:SelectAtlas(atlasName)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    for i, name in ipairs(tab.filteredList) do
        if name == atlasName then
            tab.selectedIndex = i
            break
        end
    end

    local info = C_Texture.GetAtlasInfo(atlasName)

    if info then
        tab.currentAtlas = atlasName
        tab.preview:SetAtlas(atlasName)
        tab.preview:Show()
        tab.nameText:SetText(atlasName)

        self:UpdateAtlasList()

        local isBookmarked = Addon.db.textureBookmarks and Addon.db.textureBookmarks[atlasName]

        local details = {}
        tinsert(details, (L["LABEL_WIDTH"] or "Width:") .. " " .. (info.width or 0))
        tinsert(details, (L["LABEL_HEIGHT"] or "Height:") .. " " .. (info.height or 0))
        tinsert(details, "")
        tinsert(details, (L["LABEL_FILE"] or "File:") .. " " .. (info.file or info.filename or L["LABEL_UNKNOWN"] or "Unknown"))

        if info.leftTexCoord then
            tinsert(details, "")
            tinsert(details, L["LABEL_TEX_COORDS"] or "Texture Coordinates:")
            tinsert(details, string.format((L["LABEL_LEFT"] or "  Left:") .. " %.4f", info.leftTexCoord))
            tinsert(details, string.format((L["LABEL_RIGHT"] or "  Right:") .. " %.4f", info.rightTexCoord))
            tinsert(details, string.format((L["LABEL_TOP"] or "  Top:") .. " %.4f", info.topTexCoord))
            tinsert(details, string.format((L["LABEL_BOTTOM"] or "  Bottom:") .. " %.4f", info.bottomTexCoord))
        end

        if info.tilesHorizontally or info.tilesVertically then
            tinsert(details, "")
            tinsert(details, string.format((L["LABEL_TILES"] or "Tiles:") .. " %s x %s",
                tostring(info.tilesHorizontally or false),
                tostring(info.tilesVertically or false)))
        end

        if isBookmarked then
            tinsert(details, "")
            tinsert(details, "|cff00ff00[" .. (L["LABEL_BOOKMARKED"] or "Bookmarked") .. "]|r")
        end

        tab.infoText:SetText(table.concat(details, "\n"))

        local height = tab.infoText:GetStringHeight()
        tab.infoScroll:GetScrollChild():SetHeight(math.max(height + 10, tab.infoScroll:GetHeight()))
    end
end

function Addon.UI:ToggleBookmark()
    local tab = Addon.TextureBrowserTab
    if not tab or not tab.currentAtlas then
        Addon:Print(Addon.L and Addon.L["MSG_SELECT_ATLAS"] or "Select an atlas first")
        return
    end

    if not Addon.db.textureBookmarks then
        Addon.db.textureBookmarks = {}
    end

    local name = tab.currentAtlas

    if Addon.db.textureBookmarks[name] then
        Addon.db.textureBookmarks[name] = nil
        Addon:Print((Addon.L and Addon.L["MSG_REMOVED_BOOKMARK"] or "Removed: ") .. name)
    else
        Addon.db.textureBookmarks[name] = true
        Addon:Print((Addon.L and Addon.L["MSG_BOOKMARKED"] or "Bookmarked: ") .. name)
    end

    self:SelectAtlas(name)
end

function Addon.UI:ShowFavorites()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    if not Addon.db.textureBookmarks then
        Addon:Print(Addon.L and Addon.L["MSG_NO_BOOKMARKS"] or "No bookmarks yet")
        return
    end

    tab.filteredList = {}
    for name, _ in pairs(Addon.db.textureBookmarks) do
        tinsert(tab.filteredList, name)
    end

    sort(tab.filteredList)
    self:UpdateAtlasList()
end
