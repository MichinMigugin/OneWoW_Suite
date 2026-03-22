local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

local format = format
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local tinsert = tinsert

local BR = Addon.TextureAtlasBrowser

-- Forward declaration: refreshSheetOverlays (above) calls this from overlay OnClick.
local selectAtlasFromOverlay

local function getDU()
    return Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
end

local BOOKMARK_ICON_PATH = format("Interface\\AddOns\\%s\\Media\\icon-fav.png", ADDON_NAME)

--- Solo atlas preview: fit atlas pixel aspect ratio inside a max square of (base * zoom).
local function layoutAtlasSoloFrame(tab, atlasName, textureKey)
    if not tab or not tab.atlasSoloFrame then return end
    atlasName = atlasName or tab.selectedAtlasName
    textureKey = textureKey or tab.selectedTextureKey
    local DU = getDU()
    local base = DU.TEXTURE_PREVIEW_BASE_SIZE or 256
    local zmin = DU.TEXTURE_ZOOM_MIN or 0.03
    local zmax = DU.TEXTURE_ZOOM_MAX or 4
    local z = max(zmin, min(zmax, tab.zoomLevel or 1))
    tab.zoomLevel = z
    local maxDim = base * z
    local iw, ih = base, base
    if atlasName then
        local info = BR:ResolveAtlasInfo(atlasName, textureKey)
        tab._cachedAtlasInfo = info
        tab._cachedAtlasName = atlasName
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            iw, ih = info.width, info.height
        end
    end
    local longest = max(iw, ih)
    if longest < 1 then longest = 1 end
    local scale = maxDim / longest
    tab.atlasSoloFrame:SetSize(max(1, floor(iw * scale + 0.5)), max(1, floor(ih * scale + 0.5)))
end

local function scheduleFilterRefresh(tab)
    if tab._filterTicker then
        tab._filterTicker:Cancel()
        tab._filterTicker = nil
    end
    tab._filterTicker = C_Timer.After(0.12, function()
        tab._filterTicker = nil
        if not tab.searchBox then return end
        BR:SetFilterText(tab.searchBox:GetSearchText())
        Addon.UI.TextureTab_RefreshList(tab)
    end)
end

function Addon.UI.TextureTab_RefreshList(tab)
    if not tab or not tab.listScroll then return end
    local DU = getDU()
    local rowH = tab.listRowH or DU.TEXTURE_LIST_ROW_HEIGHT or 22
    local n = BR:GetFilteredCount()
    local content = tab.listScroll:GetScrollChild()
    content:SetHeight(max(n * rowH, 1))
    local scrollMax = max(content:GetHeight() - tab.listScroll:GetHeight(), 0)
    local vs = tab.listScroll:GetVerticalScroll()
    if vs > scrollMax then
        tab.listScroll:SetVerticalScroll(scrollMax)
    end
    Addon.UI.TextureTab_UpdateListRows(tab)
end

local function ensureListRowBookmarkIcon(btn, rowH)
    if btn.bookmarkIcon then return end
    local DU = getDU()
    local sz = DU.TEXTURE_BROWSER_BOOKMARK_ICON_SIZE or 14
    local pad = DU.TEXTURE_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    rowH = rowH or 22
    local topInset = -floor((rowH - sz) / 2 + 0.5)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(sz, sz)
    tex:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -pad, topInset)
    tex:SetTexCoord(0, 1, 0, 1)
    btn.bookmarkIcon = tex
end

local function styleListButtonText(btn)
    local fs = btn:GetFontString()
    if not fs then return end
    local DU = getDU()
    local gap = DU.TEXTURE_BROWSER_BOOKMARK_ICON_TEXT_GAP or 4
    local rightPad = DU.TEXTURE_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    if btn.bookmarkIcon and btn.bookmarkIcon:IsShown() then
        fs:SetPoint("RIGHT", btn.bookmarkIcon, "LEFT", -gap, 0)
    else
        fs:SetPoint("RIGHT", btn, "RIGHT", -rightPad, 0)
    end
end

function Addon.UI.TextureTab_UpdateListRows(tab)
    if not tab or not tab.listButtons then return end
    local rowH = tab.listRowH
    local scroll = tab.listScroll:GetVerticalScroll()
    local startIdx = floor(scroll / rowH) + 1
    local listContent = tab.listScroll:GetScrollChild()

    for i, btn in ipairs(tab.listButtons) do
        local idx = startIdx + i - 1
        local entry = BR:GetFilteredEntry(idx)
        if entry then
            -- Pool of row frames must sit at each entry's Y on the scroll child, not fixed at 0..NUM_ROWS,
            -- or scrolling leaves the buttons above the viewport and shows empty space.
            btn:ClearAllPoints()
            btn:SetHeight(rowH)
            btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(idx - 1) * rowH)
            btn:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)

            local label = entry.displayName or entry.atlasName or "?"
            if entry.kind == "atlas" and entry.textureKey then
                label = entry.atlasName
            end
            ensureListRowBookmarkIcon(btn, rowH)
            local bookmarks = Addon.db and Addon.db.textureBookmarks
            local showBm = false
            if bookmarks then
                if entry.kind == "atlas" and entry.atlasName and bookmarks[entry.atlasName] then
                    showBm = true
                elseif entry.kind == "texture" and entry.textureKey and BR:TextureHasBookmarkedAtlas(entry.textureKey, bookmarks) then
                    showBm = true
                end
            end
            if showBm then
                btn.bookmarkIcon:SetTexture(BOOKMARK_ICON_PATH)
                btn.bookmarkIcon:Show()
            else
                btn.bookmarkIcon:Hide()
            end
            btn:SetText(label)
            btn.entryIndex = idx
            local sel = (tab.selectedListIndex == idx)
            if sel then
                btn:SetNormalFontObject(GameFontHighlightSmall)
            else
                btn:SetNormalFontObject(GameFontNormalSmall)
            end
            btn._tooltipFullText = label
            styleListButtonText(btn)
            btn:Show()
        else
            if btn.bookmarkIcon then
                btn.bookmarkIcon:Hide()
            end
            btn:Hide()
            btn.entryIndex = nil
            btn._tooltipFullText = nil
        end
    end
end

local function releaseOverlays(tab)
    if tab.overlayPool then
        tab.overlayPool:ReleaseAll()
    end
end

local function beginSheetPanDrag(tab, button)
    if button ~= "LeftButton" then return end
    if BR:GetViewMode() ~= BR.VIEW_TEXTURE then return end
    if not tab.selectedTextureKey then return end
    local x, y = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    tab._sheetPanActive = true
    tab._sheetPanDragged = false
    tab._sheetPanStartCX = x / sc
    tab._sheetPanStartCY = y / sc
    tab._sheetPanLastCX = tab._sheetPanStartCX
    tab._sheetPanLastCY = tab._sheetPanStartCY
end

local function ensureSheetOverlayBookmarkIcon(overlay)
    if overlay._sheetBookmarkTex then
        return overlay._sheetBookmarkTex
    end
    local tex = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    overlay._sheetBookmarkTex = tex
    return tex
end

--- Apply selection/bookmark visual state to a single overlay without rebuilding geometry.
local function styleSheetOverlay(tab, overlay, DU)
    local highlightVisible = not tab.sheetSelectionHighlightSuppressed
    local isSel = highlightVisible and tab.selectedAtlasName == overlay.atlasName

    local edgeNormal = DU.TEXTURE_SHEET_OVERLAY_EDGE_NORMAL or 1
    local edgeSelected = DU.TEXTURE_SHEET_OVERLAY_EDGE_SELECTED or 3
    local fillAlpha = DU.TEXTURE_SHEET_OVERLAY_SELECTED_FILL_ALPHA or 0.26
    local borderMutedA = DU.TEXTURE_SHEET_OVERLAY_UNSELECTED_BORDER_ALPHA or 0.55
    local levelBoostSel = DU.TEXTURE_SHEET_OVERLAY_SELECTED_LEVEL_OFFSET or 10
    local levelBoostNorm = DU.TEXTURE_SHEET_OVERLAY_NORMAL_LEVEL_OFFSET or 1

    local baseLevel = tab.sheetFrame:GetFrameLevel() or 0
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = isSel and edgeSelected or edgeNormal,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetFrameLevel(baseLevel + (isSel and levelBoostSel or levelBoostNorm))
    if isSel then
        local fr, fg, fb = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        overlay:SetBackdropColor(fr, fg, fb, fillAlpha)
        overlay:SetBackdropBorderColor(fr, fg, fb, 0.98)
    else
        overlay:SetBackdropColor(0, 0, 0, 0)
        local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        overlay:SetBackdropBorderColor(r, g, b, borderMutedA)
    end

    local bookmarks = Addon.db and Addon.db.textureBookmarks
    local bmTex = ensureSheetOverlayBookmarkIcon(overlay)
    if bookmarks and bookmarks[overlay.atlasName] then
        bmTex:SetTexture(BOOKMARK_ICON_PATH)
        bmTex:Show()
    else
        bmTex:Hide()
    end
end

--- Light-weight restyle: update selection highlight and bookmark icons on existing overlays.
local function updateSheetOverlayStyles(tab)
    if not tab.sheetFrame or not tab.overlayPool then return end
    local DU = getDU()
    for overlay in tab.overlayPool:EnumerateActive() do
        styleSheetOverlay(tab, overlay, DU)
    end
end

--- Full rebuild: releases all overlays and re-creates them from atlas data.
--- Call only when the texture key or sheet geometry changes.
local function refreshSheetOverlays(tab)
    releaseOverlays(tab)
    if not tab.sheetFrame or not tab.selectedTextureKey then return end
    if BR:GetViewMode() ~= BR.VIEW_TEXTURE then return end

    local DU = getDU()
    local bmSize = DU.TEXTURE_SHEET_PREVIEW_BOOKMARK_ICON_SIZE or 12
    local bmInset = DU.TEXTURE_SHEET_PREVIEW_BOOKMARK_ICON_INSET or 2

    local w, h = tab.sheetFrame:GetWidth(), tab.sheetFrame:GetHeight()
    if not w or not h or w <= 0 or h <= 0 then return end

    local atlases = BR:GetAtlasesForTexture(tab.selectedTextureKey)
    for _, row in ipairs(atlases) do
        local info = row.info
        if info then
            local du = (info.rightTexCoord or 0) - (info.leftTexCoord or 0)
            local dv = (info.bottomTexCoord or 0) - (info.topTexCoord or 0)
            if du > 0 and dv > 0 then
                local overlay = tab.overlayPool:Acquire()
                overlay:ClearAllPoints()
                overlay.atlasName = row.atlasName
                overlay:SetPoint("TOPLEFT", tab.sheetFrame, (info.leftTexCoord or 0) * w, -(info.topTexCoord or 0) * h)
                overlay:SetPoint("BOTTOMRIGHT", tab.sheetFrame, -(1 - (info.rightTexCoord or 1)) * w, (1 - (info.bottomTexCoord or 1)) * h)

                styleSheetOverlay(tab, overlay, DU)

                local bmTex = overlay._sheetBookmarkTex
                if bmTex then
                    bmTex:ClearAllPoints()
                    bmTex:SetSize(bmSize, bmSize)
                    bmTex:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -bmInset, -bmInset)
                    bmTex:SetTexCoord(0, 1, 0, 1)
                end

                overlay:SetScript("OnMouseDown", function(_, btn)
                    beginSheetPanDrag(tab, btn)
                end)
                overlay:SetScript("OnClick", function(self)
                    if tab._sheetPanDragged then
                        tab._sheetPanDragged = false
                        return
                    end
                    selectAtlasFromOverlay(tab, self.atlasName)
                end)
                overlay:Show()
            end
        end
    end
end

local function computeFitZoom(tab)
    local DU = getDU()
    local bw, bh = tab.baseSheetW, tab.baseSheetH
    if not bw or not bh or bw <= 0 or bh <= 0 then
        return nil
    end
    if not tab.previewClip then
        return nil
    end
    local cw, ch = tab.previewClip:GetWidth(), tab.previewClip:GetHeight()
    if not cw or cw < 8 or not ch or ch < 8 then
        return nil
    end
    local z = min(cw / bw, ch / bh)
    local zmin = DU.TEXTURE_ZOOM_MIN or 0.03
    local zmax = DU.TEXTURE_ZOOM_MAX or 4
    return max(zmin, min(z, zmax))
end

local function applyDefaultSheetZoom(tab)
    local z = computeFitZoom(tab)
    if not z then return end
    local DU = getDU()
    local mult = DU.TEXTURE_SHEET_INITIAL_ZOOM_MULTIPLIER or 0.8
    local zmin = DU.TEXTURE_ZOOM_MIN or 0.03
    local zmax = DU.TEXTURE_ZOOM_MAX or 4
    tab.zoomLevel = max(zmin, min(z * mult, zmax))
end

local function refreshZoomPercentDisplay(tab)
    if not tab or not tab.zoomPctLabel then return end
    if BR:GetViewMode() == BR.VIEW_TEXTURE and tab.selectedTextureKey then
        local z = tab.zoomLevel or 1
        local zFit = computeFitZoom(tab)
        local pct
        if zFit and zFit > 0 then
            pct = floor((z / zFit) * 100 + 0.5)
        else
            pct = floor(z * 100 + 0.5)
        end
        tab.zoomPctLabel:SetText(format(L["TEXTURE_ZOOM_PERCENT"] or "%d%%", pct))
        tab.zoomPctLabel:Show()
    elseif BR:GetViewMode() == BR.VIEW_ATLAS then
        local z = tab.zoomLevel or 1
        tab.zoomPctLabel:SetText(format(L["TEXTURE_ZOOM_PERCENT"] or "%d%%", floor(z * 100 + 0.5)))
        tab.zoomPctLabel:Show()
    else
        tab.zoomPctLabel:Hide()
    end
end

local function applySheetFrameLayout(tab)
    local DU = getDU()
    local z = tab.zoomLevel or 1
    local zmin = DU.TEXTURE_ZOOM_MIN or 0.03
    local zmax = DU.TEXTURE_ZOOM_MAX or 4
    z = max(zmin, min(zmax, z))
    tab.zoomLevel = z
    if tab.baseSheetW and tab.baseSheetH and tab.sheetFrame and tab.previewSheetHost then
        local sw = tab.baseSheetW * z
        local sh = tab.baseSheetH * z
        tab.sheetFrame:SetSize(sw, sh)
        tab.sheetFrame:ClearAllPoints()
        tab.sheetFrame:SetPoint("CENTER", tab.previewSheetHost, "CENTER", tab.sheetPanX or 0, tab.sheetPanY or 0)
    end
end

local function layoutSheetPreview(tab)
    applySheetFrameLayout(tab)
    if tab.baseSheetW and tab.baseSheetH and tab.sheetFrame and tab.selectedTextureKey then
        refreshSheetOverlays(tab)
    end
    refreshZoomPercentDisplay(tab)
    tab._lastFitZoom = computeFitZoom(tab)
end

local function showTextureSheet(tab, textureKey)
    tab.previewAtlasHost:Hide()
    tab.previewSheetHost:Show()

    tab.sheetSelectionHighlightSuppressed = false
    tab.textureUserZoomed = false
    tab.sheetPanX, tab.sheetPanY = 0, 0
    tab._sheetPanActive = false
    tab._sheetPanDragged = false
    tab.selectedTextureKey = textureKey
    tab.baseSheetW, tab.baseSheetH = BR:ComputeSheetPixelSize(textureKey)
    local apiKey = BR:TextureKeyForAPI(textureKey)

    tab.sheetTexture:SetTexture(apiKey)
    tab.sheetTexture:SetTexCoord(0, 1, 0, 1)
    tab.sheetTexture:SetVertexColor(1, 1, 1, 1)
    tab.sheetTexture:Show()

    local function fitLayoutAndOverlays()
        if not tab.textureUserZoomed then
            applyDefaultSheetZoom(tab)
        end
        layoutSheetPreview(tab)
    end
    -- Deferred: frames may not have valid sizes until the next layout pass.
    C_Timer.After(0, fitLayoutAndOverlays)

    tab.nameText:SetText(tostring(textureKey))
end

local function showAtlasSolo(tab, atlasName, textureKey)
    tab.previewSheetHost:Hide()
    tab.previewAtlasHost:Show()
    releaseOverlays(tab)

    tab.selectedAtlasName = atlasName
    tab.selectedTextureKey = textureKey
    tab.sheetSelectionHighlightSuppressed = false
    tab.atlasSoloTexture:SetAtlas(atlasName)
    tab.atlasSoloTexture:Show()
    tab.nameText:SetText(atlasName)

    layoutAtlasSoloFrame(tab, atlasName, textureKey)
    refreshZoomPercentDisplay(tab)
end

local function updateDetailPanel(tab)
    if not tab.infoText then return end

    local lines = {}
    local atlasName = tab.selectedAtlasName
    local texKey = tab.selectedTextureKey

    if BR:GetViewMode() == BR.VIEW_TEXTURE and texKey and not atlasName then
        tinsert(lines, L["TEXTURE_MSG_CLICK_REGION"] or "Click a highlighted region on the sheet to inspect that atlas entry. Drag to pan when zoomed.")
        tinsert(lines, "")
        tinsert(lines, (L["LABEL_FILE"] or "File:") .. " " .. tostring(texKey))
        local w, h = BR:ComputeSheetPixelSize(texKey)
        tinsert(lines, (L["TEXTURE_LABEL_SHEET_SIZE"] or "Sheet (est. px):") .. " " .. format("%.0f x %.0f", w, h))
    elseif atlasName then
        local info = tab._cachedAtlasInfo
        if not info or tab._cachedAtlasName ~= atlasName then
            info = BR:ResolveAtlasInfo(atlasName, texKey)
            tab._cachedAtlasInfo = info
            tab._cachedAtlasName = atlasName
        end
        for _, line in ipairs(BR:FormatDetailLines(atlasName, info, texKey, L)) do
            tinsert(lines, line)
        end

        local bm = Addon.db.textureBookmarks and Addon.db.textureBookmarks[atlasName]
        if bm then
            tinsert(lines, "")
            tinsert(lines, "|cff00ff00[" .. (L["LABEL_BOOKMARKED"] or "Bookmarked") .. "]|r")
        end
    else
        tinsert(lines, L["TEXTURE_MSG_SELECT_ITEM"] or "Select a texture or atlas from the list.")
    end

    tab.infoText:SetText(table.concat(lines, "\n"))
    local h = tab.infoText:GetStringHeight()
    tab.infoScroll:GetScrollChild():SetHeight(max(h + 16, tab.infoScroll:GetHeight()))
end

local function applyListSelection(tab, entryIndex)
    local entry = BR:GetFilteredEntry(entryIndex)
    if not entry then return end

    tab.selectedListIndex = entryIndex

    if entry.kind == "texture" then
        tab.selectedAtlasName = nil
        showTextureSheet(tab, entry.textureKey)
        -- Favorites + By sheet lists whole textures; pick first bookmarked atlas so detail + overlay match that slice.
        if BR.favoritesOnly and Addon.db.textureBookmarks then
            for _, row in ipairs(BR:GetAtlasesForTexture(entry.textureKey)) do
                if Addon.db.textureBookmarks[row.atlasName] then
                    selectAtlasFromOverlay(tab, row.atlasName)
                    break
                end
            end
        end
    else
        tab.zoomLevel = 1
        showAtlasSolo(tab, entry.atlasName, entry.textureKey)
    end

    updateDetailPanel(tab)
    Addon.UI.TextureTab_UpdateListRows(tab)
    Addon.UI.TextureTab_RefreshToolbarButtons(tab)
end

--- After toggling textureBookmarks; favorites view must rebuild the filtered list.
local function textureTabAfterBookmarkToggle(tab)
    if BR.favoritesOnly then
        BR:RebuildFiltered()
        Addon.UI.TextureTab_RefreshList(tab)
        local n = BR:GetFilteredCount()
        if n == 0 then
            tab.selectedListIndex = nil
            tab.selectedAtlasName = nil
            tab.selectedTextureKey = nil
            tab.sheetSelectionHighlightSuppressed = false
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            releaseOverlays(tab)
            if tab.nameText then tab.nameText:SetText("") end
            updateDetailPanel(tab)
            Addon.UI.TextureTab_UpdateListRows(tab)
            Addon.UI.TextureTab_RefreshToolbarButtons(tab)
        else
            local pick = nil
            for i = 1, n do
                local e = BR:GetFilteredEntry(i)
                if e.kind == "atlas" and tab.selectedAtlasName and e.atlasName == tab.selectedAtlasName then
                    pick = i
                    break
                end
                if e.kind == "texture" and tab.selectedTextureKey and e.textureKey == tab.selectedTextureKey then
                    pick = i
                    break
                end
            end
            -- applyListSelection already calls UpdateListRows + RefreshToolbarButtons.
            applyListSelection(tab, pick or 1)
        end
    else
        updateDetailPanel(tab)
        Addon.UI.TextureTab_UpdateListRows(tab)
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end
    if BR:GetViewMode() == BR.VIEW_TEXTURE and tab.selectedTextureKey and tab.previewSheetHost and tab.previewSheetHost:IsShown() then
        updateSheetOverlayStyles(tab)
    end
end

selectAtlasFromOverlay = function(tab, atlasName)
    if not atlasName or not tab.selectedTextureKey then return end
    if tab.selectedAtlasName == atlasName then
        tab.sheetSelectionHighlightSuppressed = not tab.sheetSelectionHighlightSuppressed
    else
        tab.selectedAtlasName = atlasName
        tab.sheetSelectionHighlightSuppressed = false
    end
    updateSheetOverlayStyles(tab)
    updateDetailPanel(tab)
    Addon.UI.TextureTab_RefreshToolbarButtons(tab)
end

local function paintTextureBarButton(btn)
    if not btn or not btn.text then return end
    local active = btn._textureBarActive
    local over = btn:IsMouseOver()
    if active then
        if over then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
    else
        if over then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

local function bindTextureBarButtonMouse(btn)
    btn:SetScript("OnEnter", function(self)
        paintTextureBarButton(self)
    end)
    btn:SetScript("OnLeave", function(self)
        paintTextureBarButton(self)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(self)
        paintTextureBarButton(self)
    end)
end

local function setCopyButtonEnabled(btn, enabled)
    if not btn then return end
    btn:EnableMouse(enabled)
    if enabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end
end

function Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    if not tab or not tab.btnByTexture then return end
    tab.btnByTexture._textureBarActive = (BR:GetViewMode() == BR.VIEW_TEXTURE)
    tab.btnByAtlas._textureBarActive = (BR:GetViewMode() == BR.VIEW_ATLAS)
    tab.favsBtn._textureBarActive = BR.favoritesOnly
    local bookmarked = tab.selectedAtlasName and Addon.db.textureBookmarks and Addon.db.textureBookmarks[tab.selectedAtlasName]
    tab.bookmarkBtn._textureBarActive = bookmarked and true or false
    tab.manualToggle._textureBarActive = tab.manualPanel and tab.manualPanel:IsShown() or false
    paintTextureBarButton(tab.btnByTexture)
    paintTextureBarButton(tab.btnByAtlas)
    paintTextureBarButton(tab.favsBtn)
    if tab.bookmarkBtn.SetFitText then
        if tab.selectedAtlasName then
            if bookmarked then
                tab.bookmarkBtn:SetFitText(L["BTN_REMOVE_BOOKMARK"] or "Remove bookmark")
            else
                tab.bookmarkBtn:SetFitText(L["BTN_BOOKMARK"] or "Bookmark")
            end
        else
            tab.bookmarkBtn:SetFitText(L["BTN_BOOKMARK"] or "Bookmark")
        end
    end
    paintTextureBarButton(tab.bookmarkBtn)
    paintTextureBarButton(tab.manualToggle)

    local hasSelection = tab.selectedAtlasName or tab.selectedTextureKey
    local hasAtlas = tab.selectedAtlasName ~= nil
    setCopyButtonEnabled(tab.copyNameBtn, hasSelection)
    setCopyButtonEnabled(tab.copySnippetBtn, hasAtlas)
    setCopyButtonEnabled(tab.copyCoordBtn, hasAtlas)
end

function Addon.UI:CreateTextureTab(parent)
    local DU = getDU()
    local TEX_ROW_H = DU.TEXTURE_BROWSER_LIST_ROW_HEIGHT or DU.TEXTURE_LIST_BUTTON_HEIGHT or 22
    local NUM_ROWS = DU.TEXTURE_BROWSER_LIST_VISIBLE_ROWS or 40
    local ZOOM_IN = DU.TEXTURE_ZOOM_IN_FACTOR or 1.2
    local ZOOM_OUT = DU.TEXTURE_ZOOM_OUT_FACTOR or 0.8

    BR:ResetFilterState()
    BR:RebuildFiltered()

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    tab.listRowH = TEX_ROW_H
    tab.zoomLevel = 1

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 160,
        height = 22,
        placeholderText = L["LABEL_FILTER"] or "Filter...",
        onTextChanged = function()
            scheduleFilterRefresh(tab)
        end,
    })
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    if not BR:IsDataAvailable() then
        local warn = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warn:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -16)
        warn:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -16, -16)
        warn:SetJustifyH("LEFT")
        warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        warn:SetText(L["TEXTURE_MSG_NO_DATA"] or "Atlas data is not loaded for this client build. Update Data/AtlasInfo-*.lua to match GetBuildInfo().")
        Addon.TextureBrowserTab = tab
        return tab
    end

    local btnByTexture = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_VIEW_BY_SHEET"] or "By sheet",
        height = 22,
        minWidth = 72,
    })
    btnByTexture:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    bindTextureBarButtonMouse(btnByTexture)
    btnByTexture:SetScript("OnClick", function()
        BR:SetViewMode(BR.VIEW_TEXTURE)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            applyListSelection(tab, 1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            tab.nameText:SetText("")
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local btnByAtlas = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_VIEW_BY_ATLAS"] or "By atlas",
        height = 22,
        minWidth = 72,
    })
    btnByAtlas:SetPoint("LEFT", btnByTexture, "RIGHT", 4, 0)
    bindTextureBarButtonMouse(btnByAtlas)
    btnByAtlas:SetScript("OnClick", function()
        BR:SetViewMode(BR.VIEW_ATLAS)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            applyListSelection(tab, 1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            tab.nameText:SetText("")
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local favsBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_FAVORITES"] or "Favorites",
        height = 22,
        minWidth = 72,
    })
    favsBtn:SetPoint("LEFT", btnByAtlas, "RIGHT", 6, 0)
    bindTextureBarButtonMouse(favsBtn)
    favsBtn:SetScript("OnClick", function()
        BR:SetFavoritesOnly(not BR.favoritesOnly)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            applyListSelection(tab, 1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local bookmarkBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_BOOKMARK"] or "Bookmark",
        height = 22,
        minWidth = 72,
    })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 4, 0)
    bindTextureBarButtonMouse(bookmarkBtn)
    bookmarkBtn:SetScript("OnClick", function()
        if not tab.selectedAtlasName then
            Addon:Print(L["MSG_SELECT_ATLAS"] or "Select an atlas first")
            Addon.UI.TextureTab_RefreshToolbarButtons(tab)
            return
        end
        if not Addon.db.textureBookmarks then
            Addon.db.textureBookmarks = {}
        end
        local name = tab.selectedAtlasName
        if Addon.db.textureBookmarks[name] then
            Addon.db.textureBookmarks[name] = nil
            Addon:Print((L["MSG_REMOVED_BOOKMARK"] or "Removed: {name}"):gsub("{name}", name))
        else
            Addon.db.textureBookmarks[name] = true
            Addon:Print((L["MSG_BOOKMARKED"] or "Bookmarked: {name}"):gsub("{name}", name))
        end
        textureTabAfterBookmarkToggle(tab)
    end)

    local manualToggle = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_BTN_MANUAL"] or "Manual",
        height = 22,
        minWidth = 56,
    })
    manualToggle:SetPoint("LEFT", bookmarkBtn, "RIGHT", 6, 0)
    bindTextureBarButtonMouse(manualToggle)

    tab.btnByTexture = btnByTexture
    tab.btnByAtlas = btnByAtlas
    tab.favsBtn = favsBtn
    tab.bookmarkBtn = bookmarkBtn
    tab.manualToggle = manualToggle

    local LEFT_DEFAULT = DU.TEXTURE_BROWSER_LEFT_PANE_DEFAULT_WIDTH or 300
    local LEFT_MIN = DU.TEXTURE_BROWSER_LEFT_PANE_MIN_WIDTH or 200
    local RIGHT_MIN = DU.TEXTURE_BROWSER_RIGHT_PANE_MIN_WIDTH or 260
    local DIV_W = DU.FRAME_INSPECTOR_DIVIDER_WIDTH or 6
    local SPLIT_PAD = DU.TEXTURE_BROWSER_SPLIT_PADDING
    if SPLIT_PAD == nil then
        SPLIT_PAD = DIV_W + 10
    end

    local savedListW = Addon.db and Addon.db.textureBrowserLeftPaneWidth
    local initListW = LEFT_DEFAULT
    if type(savedListW) == "number" and savedListW >= LEFT_MIN then
        initListW = savedListW
    end

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 320, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(initListW)
    self:StyleContentPanel(leftPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "TextureTabListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
        Addon.UI.TextureTab_RefreshList(tab)
    end)
    listScroll:SetScript("OnVerticalScroll", function()
        Addon.UI.TextureTab_UpdateListRows(tab)
    end)

    tab.listScroll = listScroll
    tab.searchBox = searchBox

    tab.listButtons = {}
    for i = 1, NUM_ROWS do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(TEX_ROW_H)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i - 1) * TEX_ROW_H)
        btn:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetScript("OnClick", function(b)
            if b.entryIndex then
                applyListSelection(tab, b.entryIndex)
            end
        end)
        btn:SetScript("OnEnter", function(b)
            local t = b._tooltipFullText
            if t and t ~= "" then
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                local tr, tg, tb = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                GameTooltip:SetText(t, tr, tg, tb, nil, true)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
        styleListButtonText(btn)
        tab.listButtons[i] = btn
    end

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = DIV_W,
        leftMinWidth = LEFT_MIN,
        rightMinWidth = RIGHT_MIN,
        splitPadding = SPLIT_PAD,
        bottomOuterInset = 5,
        rightOuterInset = 5,
        resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95,
        mainFrame = Addon.UI and Addon.UI.mainFrame,
        onWidthChanged = function(w)
            if Addon.db then
                Addon.db.textureBrowserLeftPaneWidth = w
            end
        end,
    })

    local zoomInBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_ZOOM_IN"] or "+", height = 22, minWidth = 36 })
    zoomInBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -6, -4)
    zoomInBtn:SetScript("OnClick", function()
        if BR:GetViewMode() == BR.VIEW_TEXTURE then
            tab.textureUserZoomed = true
        end
        tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_IN
        if BR:GetViewMode() == BR.VIEW_TEXTURE then
            layoutSheetPreview(tab)
        else
            layoutAtlasSoloFrame(tab)
            refreshZoomPercentDisplay(tab)
        end
    end)

    local zoomOutBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_ZOOM_OUT"] or "-", height = 22, minWidth = 36 })
    zoomOutBtn:SetPoint("RIGHT", zoomInBtn, "LEFT", -4, 0)
    zoomOutBtn:SetScript("OnClick", function()
        if BR:GetViewMode() == BR.VIEW_TEXTURE then
            tab.textureUserZoomed = true
        end
        tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_OUT
        local zmin = DU.TEXTURE_ZOOM_MIN or 0.03
        tab.zoomLevel = max(zmin, tab.zoomLevel)
        if BR:GetViewMode() == BR.VIEW_TEXTURE then
            layoutSheetPreview(tab)
        else
            layoutAtlasSoloFrame(tab)
            refreshZoomPercentDisplay(tab)
        end
    end)

    local resetBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_RESET_ZOOM"] or "Reset", height = 22, minWidth = 56 })
    resetBtn:SetPoint("RIGHT", zoomOutBtn, "LEFT", -4, 0)
    resetBtn:SetScript("OnClick", function()
        if BR:GetViewMode() == BR.VIEW_TEXTURE then
            tab.textureUserZoomed = false
            tab.sheetPanX, tab.sheetPanY = 0, 0
            tab._sheetPanActive = false
            tab._sheetPanDragged = false
            local z = computeFitZoom(tab)
            if z then
                tab.zoomLevel = z
            else
                tab.zoomLevel = 1
            end
            layoutSheetPreview(tab)
        else
            tab.zoomLevel = 1
            layoutAtlasSoloFrame(tab)
            refreshZoomPercentDisplay(tab)
        end
    end)

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -6)
    tab.nameText:SetPoint("TOPRIGHT", resetBtn, "TOPLEFT", -8, 0)
    tab.nameText:SetJustifyH("LEFT")
    tab.nameText:SetWordWrap(true)
    if tab.nameText.SetMaxLines then
        tab.nameText:SetMaxLines(2)
    end
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local previewBg = rightPanel:CreateTexture(nil, "BACKGROUND")
    local bottomReserve = DU.TEXTURE_PREVIEW_BOTTOM_RESERVE or 188
    previewBg:SetPoint("TOP", tab.nameText, "BOTTOM", 0, -8)
    previewBg:SetPoint("LEFT", rightPanel, "LEFT", 8, 0)
    previewBg:SetPoint("RIGHT", rightPanel, "RIGHT", -8, 0)
    previewBg:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, bottomReserve)
    previewBg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    -- Plain Frame (not BackdropTemplate): avoid an extra backdrop layer over the preview.
    local previewClip = CreateFrame("Frame", nil, rightPanel)
    previewClip:SetPoint("TOPLEFT", previewBg, "TOPLEFT", 2, -2)
    previewClip:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", -2, 2)
    previewClip:SetClipsChildren(true)
    previewClip:SetFrameLevel((rightPanel:GetFrameLevel() or 0) + 5)
    tab.previewClip = previewClip
    previewClip:HookScript("OnSizeChanged", function()
        if BR:GetViewMode() ~= BR.VIEW_TEXTURE then return end
        if not tab.selectedTextureKey then return end
        local oldFit = tab._lastFitZoom
        local newFit = computeFitZoom(tab)
        if oldFit and newFit and oldFit > 0 and tab.zoomLevel then
            tab.zoomLevel = tab.zoomLevel * (newFit / oldFit)
        elseif newFit then
            local mult = DU.TEXTURE_SHEET_INITIAL_ZOOM_MULTIPLIER or 0.8
            tab.zoomLevel = newFit * mult
        end
        tab._lastFitZoom = newFit
        layoutSheetPreview(tab)
    end)

    tab.previewSheetHost = CreateFrame("Frame", nil, previewClip)
    tab.previewSheetHost:SetAllPoints(previewClip)
    tab.previewSheetHost:EnableMouse(true)
    tab.previewSheetHost:SetScript("OnMouseDown", function(_, btn)
        beginSheetPanDrag(tab, btn)
    end)

    tab.sheetFrame = CreateFrame("Frame", nil, tab.previewSheetHost)
    tab.sheetFrame:SetPoint("CENTER", tab.previewSheetHost, "CENTER", 0, 0)
    tab.sheetFrame:EnableMouse(true)
    tab.sheetFrame:SetScript("OnMouseDown", function(_, btn)
        beginSheetPanDrag(tab, btn)
    end)

    tab.sheetTexture = tab.sheetFrame:CreateTexture(nil, "ARTWORK")
    tab.sheetTexture:SetAllPoints()

    tab.overlayPool = CreateFramePool("BUTTON", tab.sheetFrame, "BackdropTemplate")

    tab.previewSheetHost:EnableMouseWheel(true)
    tab.previewSheetHost:SetScript("OnMouseWheel", function(_, delta)
        tab.textureUserZoomed = true
        if delta > 0 then
            tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_IN
        else
            tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_OUT
            tab.zoomLevel = max(DU.TEXTURE_ZOOM_MIN or 0.03, tab.zoomLevel)
        end
        layoutSheetPreview(tab)
    end)

    tab.previewAtlasHost = CreateFrame("Frame", nil, previewClip)
    -- Match sheet host geometry so the solo preview has a non-zero layout rect (CENTER-only parent can size to 0).
    tab.previewAtlasHost:SetAllPoints(previewClip)
    tab.previewAtlasHost:Hide()
    tab.atlasSoloFrame = CreateFrame("Frame", nil, tab.previewAtlasHost)
    tab.atlasSoloFrame:SetSize(DU.TEXTURE_PREVIEW_BASE_SIZE or 256, DU.TEXTURE_PREVIEW_BASE_SIZE or 256)
    tab.atlasSoloFrame:SetPoint("CENTER", tab.previewAtlasHost, "CENTER", 0, 0)
    tab.atlasSoloTexture = tab.atlasSoloFrame:CreateTexture(nil, "ARTWORK")
    tab.atlasSoloTexture:SetAllPoints()

    tab.previewAtlasHost:EnableMouseWheel(true)
    tab.previewAtlasHost:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_IN
        else
            tab.zoomLevel = (tab.zoomLevel or 1) * ZOOM_OUT
            tab.zoomLevel = max(DU.TEXTURE_ZOOM_MIN or 0.03, tab.zoomLevel)
        end
        layoutAtlasSoloFrame(tab)
        refreshZoomPercentDisplay(tab)
    end)

    -- Font strings must be parented to a Frame; previewBg is a Texture.
    local uvLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    uvLabel:SetPoint("BOTTOMLEFT", previewBg, "BOTTOMLEFT", 6, 4)
    uvLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tab.uvCursorLabel = uvLabel

    tab.zoomPctLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.zoomPctLabel:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", -6, 4)
    tab.zoomPctLabel:SetJustifyH("RIGHT")
    tab.zoomPctLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tab.zoomPctLabel:SetText("")

    previewClip:SetScript("OnUpdate", function(self)
        if not tab:IsShown() then return end
        local panThresh = DU.TEXTURE_SHEET_PAN_CLICK_THRESHOLD or 4

        if tab._sheetPanActive then
            if IsMouseButtonDown("LeftButton") then
                local x, y = GetCursorPosition()
                local sc = UIParent:GetEffectiveScale()
                local cx, cy = x / sc, y / sc
                if abs(cx - tab._sheetPanStartCX) + abs(cy - tab._sheetPanStartCY) > panThresh then
                    tab._sheetPanDragged = true
                end
                local dx = cx - tab._sheetPanLastCX
                local dy = cy - tab._sheetPanLastCY
                tab._sheetPanLastCX = cx
                tab._sheetPanLastCY = cy
                if dx ~= 0 or dy ~= 0 then
                    tab.sheetPanX = (tab.sheetPanX or 0) + dx
                    tab.sheetPanY = (tab.sheetPanY or 0) + dy
                    applySheetFrameLayout(tab)
                end
            else
                tab._sheetPanActive = false
            end
        end

        if not self:IsMouseOver() then
            uvLabel:SetText("")
            return
        end
        local x, y = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        x = x / sc
        y = y / sc
        local l, t = previewClip:GetLeft(), previewClip:GetTop()
        local w, h = previewClip:GetWidth(), previewClip:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then return end
        local nx = (x - l) / w
        local ny = (t - y) / h
        nx = max(0, min(1, nx))
        ny = max(0, min(1, ny))
        uvLabel:SetText(format(L["TEXTURE_UV_CURSOR"] or "UV X: %.4f  Y: %.4f", nx, ny))
    end)

    -- Decorative outline only: a filled backdrop here is created after previewClip and would
    -- paint on top of the texture (looked like the image was "under" the window).
    local border = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", previewBg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", 1, -1)
    border:SetFrameLevel((rightPanel:GetFrameLevel() or 0) + 2)
    border:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    tab.manualPanel = CreateFrame("Frame", nil, rightPanel)
    tab.manualPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -6)
    tab.manualPanel:SetPoint("TOPRIGHT", previewBg, "BOTTOMRIGHT", 0, -6)
    tab.manualPanel:SetHeight(52)
    tab.manualPanel:Hide()

    local manualEdit = OneWoW_GUI:CreateEditBox(tab.manualPanel, {
        width = 200,
        height = 22,
        placeholderText = L["TEXTURE_MANUAL_PLACEHOLDER"] or "Atlas name or texture path...",
    })
    manualEdit:SetPoint("TOPLEFT", tab.manualPanel, "TOPLEFT", 0, 0)
    manualEdit:SetPoint("RIGHT", tab.manualPanel, "RIGHT", -90, 0)

    local manualApply = OneWoW_GUI:CreateFitTextButton(tab.manualPanel, {
        text = L["TEXTURE_MANUAL_APPLY"] or "Apply",
        height = 22,
        minWidth = 72,
    })
    manualApply:SetPoint("LEFT", manualEdit, "RIGHT", 6, 0)
    manualApply:SetScript("OnClick", function()
        local path = strtrim(manualEdit:GetSearchText() or "")
        if path == "" then return end

        BR:EnsureIndices()
        tab.atlasSoloTexture:ClearAllPoints()
        tab.atlasSoloTexture:SetAllPoints(tab.atlasSoloFrame)

        if tab.atlasSoloTexture:SetAtlas(path, true) then
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Show()
            releaseOverlays(tab)
            tab.nameText:SetText(path)
            tab.selectedAtlasName = path
            tab.sheetSelectionHighlightSuppressed = false
            tab.selectedTextureKey = BR.atlasPrimaryTexture and BR.atlasPrimaryTexture[path] or nil
            tab.selectedListIndex = nil
            tab.zoomLevel = tab.zoomLevel or 1
            layoutAtlasSoloFrame(tab)
            Addon.UI.TextureTab_UpdateListRows(tab)
            updateDetailPanel(tab)
            return
        end

        -- Texture path / file id string: use the same sheet preview as "By sheet" (solo quad was easy to miss or parent-sized to 0).
        tab.previewAtlasHost:Hide()
        tab.previewSheetHost:Show()
        tab.selectedAtlasName = nil
        tab.selectedListIndex = nil
        local texKey = path:gsub("\\", "/")
        showTextureSheet(tab, texKey)
        Addon.UI.TextureTab_UpdateListRows(tab)
        updateDetailPanel(tab)
    end)

    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    tab.infoPanel = infoPanel
    infoPanel:ClearAllPoints()
    infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -8)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 42)
    self:StyleContentPanel(infoPanel)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, { name = "TextureTabInfoScroll" })
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    infoScroll:HookScript("OnSizeChanged", function(_, w)
        infoContent:SetWidth(w)
    end)

    tab.infoScroll = infoScroll
    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    manualToggle:SetScript("OnClick", function()
        if tab.manualPanel:IsShown() then
            tab.manualPanel:Hide()
        else
            tab.manualPanel:Show()
        end
        if tab.manualPanel:IsShown() then
            tab.infoPanel:ClearAllPoints()
            tab.infoPanel:SetPoint("TOPLEFT", tab.manualPanel, "BOTTOMLEFT", 0, -8)
            tab.infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 42)
        else
            tab.infoPanel:ClearAllPoints()
            tab.infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -8)
            tab.infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 42)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    -- Copy row: LibCopyPaste-style label + short buttons (matches Fonts tab)
    local copyRowLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    copyRowLabel:SetText(L["FONT_COPY_ROW_LABEL"] or "Copy:")
    copyRowLabel:SetTextColor(1, 0.82, 0)
    copyRowLabel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, 8)

    local copyNameBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_NAME"] or "Name",
        height = 22,
        minWidth = 44,
    })
    copyNameBtn:SetPoint("LEFT", copyRowLabel, "RIGHT", 6, -5)
    copyNameBtn:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 6)
    copyNameBtn:SetScript("OnClick", function()
        local s = tab.selectedAtlasName or tab.selectedTextureKey
        if s then
            Addon:CopyToClipboard(tostring(s))
        end
    end)

    local copySnippetBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["TEXTURE_BTN_COPY_SNIPPET"] or "Snippet",
        height = 22,
        minWidth = 52,
    })
    copySnippetBtn:SetPoint("LEFT", copyNameBtn, "RIGHT", 4, 0)
    copySnippetBtn:SetScript("OnClick", function()
        if tab.selectedAtlasName then
            Addon:CopyToClipboard(BR:GetSetAtlasSnippet(tab.selectedAtlasName))
        end
    end)

    local copyCoordBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["TEXTURE_BTN_COPY_COORDS"] or "UVs",
        height = 22,
        minWidth = 44,
    })
    copyCoordBtn:SetPoint("LEFT", copySnippetBtn, "RIGHT", 4, 0)
    copyCoordBtn:SetScript("OnClick", function()
        if not tab.selectedAtlasName then return end
        local info = BR:ResolveAtlasInfo(tab.selectedAtlasName, tab.selectedTextureKey)
        if info then
            Addon:CopyToClipboard(BR:GetCoordsCopyLine(info))
        end
    end)

    tab.copyNameBtn = copyNameBtn
    tab.copySnippetBtn = copySnippetBtn
    tab.copyCoordBtn = copyCoordBtn

    Addon.TextureBrowserTab = tab

    Addon.UI.TextureTab_RefreshList(tab)
    if BR:GetFilteredCount() > 0 then
        applyListSelection(tab, 1)
    else
        updateDetailPanel(tab)
    end
    Addon.UI.TextureTab_RefreshToolbarButtons(tab)

    return tab
end
