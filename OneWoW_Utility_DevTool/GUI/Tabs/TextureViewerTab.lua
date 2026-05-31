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
local applySheetFrameLayout

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
    tab._filterTicker = C_Timer.NewTimer(0.12, function()
        tab._filterTicker = nil
        if not tab.searchBox then return end
        BR:SetFilterText(tab.searchBox:GetSearchText())
        Addon.UI.TextureTab_RefreshList(tab)
    end)
end

function Addon.UI.TextureTab_RefreshList(tab)
    if not tab or not tab.virtualizedList then return end
    tab.virtualizedList.Refresh()
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

local function releaseOverlays(tab)
    if tab.overlayPool then
        tab.overlayPool:ReleaseAll()
    end
end

local function stopPreviewInteraction(tab)
    if not tab or not tab.previewClip then
        return
    end
    tab._sheetPanActive = false
    tab.previewClip:SetScript("OnUpdate", nil)
    if tab.uvCursorLabel then
        tab.uvCursorLabel:SetText("")
    end
end

local function syncPreviewInteraction(tab)
    if not tab or not tab.previewClip then
        return
    end
    if not tab:IsShown() or not tab.selectedTextureKey or not tab.previewSheetHost or not tab.previewSheetHost:IsShown() then
        stopPreviewInteraction(tab)
        return
    end
    if tab.previewAtlasHost and tab.previewAtlasHost:IsShown() then
        stopPreviewInteraction(tab)
        return
    end
    if tab.previewClip:GetScript("OnUpdate") then
        return
    end

    local uvLabel = tab.uvCursorLabel
    tab.previewClip:SetScript("OnUpdate", function(self)
        local DU = getDU()
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
        local l, t = self:GetLeft(), self:GetTop()
        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then return end
        local nx = (x - l) / w
        local ny = (t - y) / h
        nx = max(0, min(1, nx))
        ny = max(0, min(1, ny))
        uvLabel:SetText(format(L["TEXTURE_UV_CURSOR"], nx, ny))
    end)
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

    local bookmarks = Addon.db.global.textureBookmarks
    local bmTex = ensureSheetOverlayBookmarkIcon(overlay)
    if bookmarks[overlay.atlasName] then
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
        tab.zoomPctLabel:SetText(format(L["TEXTURE_ZOOM_PERCENT"], pct))
        tab.zoomPctLabel:Show()
    elseif BR:GetViewMode() == BR.VIEW_ATLAS then
        local z = tab.zoomLevel or 1
        tab.zoomPctLabel:SetText(format(L["TEXTURE_ZOOM_PERCENT"], floor(z * 100 + 0.5)))
        tab.zoomPctLabel:Show()
    else
        tab.zoomPctLabel:Hide()
    end
end

applySheetFrameLayout = function(tab)
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
    syncPreviewInteraction(tab)
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
    syncPreviewInteraction(tab)
end

local function updateDetailPanel(tab)
    if not tab.infoText then return end

    local lines = {}
    local atlasName = tab.selectedAtlasName
    local texKey = tab.selectedTextureKey

    if BR:GetViewMode() == BR.VIEW_TEXTURE and texKey and not atlasName then
        tinsert(lines, L["TEXTURE_MSG_CLICK_REGION"])
        tinsert(lines, "")
        tinsert(lines, (L["LABEL_FILE"]) .. " " .. tostring(texKey))
        local w, h = BR:ComputeSheetPixelSize(texKey)
        tinsert(lines, (L["TEXTURE_LABEL_SHEET_SIZE"]) .. " " .. format("%.0f x %.0f", w, h))
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

        local bm = Addon.db.global and Addon.db.global.textureBookmarks and Addon.db.global.textureBookmarks[atlasName]
        if bm then
            tinsert(lines, "")
            tinsert(lines, "|cff00ff00[" .. (L["LABEL_BOOKMARKED"]) .. "]|r")
        end
    else
        tinsert(lines, L["TEXTURE_MSG_SELECT_ITEM"])
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
        if BR.favoritesOnly and Addon.db.global and Addon.db.global.textureBookmarks then
            for _, row in ipairs(BR:GetAtlasesForTexture(entry.textureKey)) do
                if Addon.db.global.textureBookmarks[row.atlasName] then
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
            syncPreviewInteraction(tab)
            releaseOverlays(tab)
            if tab.nameText then tab.nameText:SetText("") end
            updateDetailPanel(tab)
            if tab.virtualizedList then tab.virtualizedList.SetSelectedIndex(nil) end
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
            if tab.virtualizedList then tab.virtualizedList.SetSelectedIndex(pick or 1) end
        end
    else
        updateDetailPanel(tab)
        if tab.virtualizedList then tab.virtualizedList.Refresh() end
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

local TEXTURE_BAR_ACTIVE_KEY = "_textureBarActive"

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
    local bookmarked = tab.selectedAtlasName and Addon.db.global and Addon.db.global.textureBookmarks and Addon.db.global.textureBookmarks[tab.selectedAtlasName]
    tab.bookmarkBtn._textureBarActive = bookmarked and true or false
    tab.manualToggle._textureBarActive = tab.manualPanel and tab.manualPanel:IsShown() or false
    Addon.UI:PaintToolbarBarButton(tab.btnByTexture, TEXTURE_BAR_ACTIVE_KEY)
    Addon.UI:PaintToolbarBarButton(tab.btnByAtlas, TEXTURE_BAR_ACTIVE_KEY)
    Addon.UI:PaintToolbarBarButton(tab.favsBtn, TEXTURE_BAR_ACTIVE_KEY)
    if tab.bookmarkBtn.SetFitText then
        if tab.selectedAtlasName then
            if bookmarked then
                tab.bookmarkBtn:SetFitText(L["BTN_REMOVE_BOOKMARK"])
            else
                tab.bookmarkBtn:SetFitText(L["BTN_BOOKMARK"])
            end
        else
            tab.bookmarkBtn:SetFitText(L["BTN_BOOKMARK"])
        end
    end
    Addon.UI:PaintToolbarBarButton(tab.bookmarkBtn, TEXTURE_BAR_ACTIVE_KEY)
    Addon.UI:PaintToolbarBarButton(tab.manualToggle, TEXTURE_BAR_ACTIVE_KEY)

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
        placeholderText = L["LABEL_FILTER"],
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
        local unloadOn = Addon.UI and Addon.UI.GetUnloadOnDisable and Addon.UI:GetUnloadOnDisable("textures")
        local msg
        if unloadOn then
            msg = L["TEXTURE_MSG_UNLOADED"]
        elseif Addon._DevToolTextureAssetsPurgedSession then
            msg = L["TEXTURE_MSG_RELOAD_RESTORE"]
        else
            msg = L["TEXTURE_MSG_NO_DATA"]
        end
        warn:SetText(msg)
        Addon.TextureBrowserTab = tab
        return tab
    end

    local btnByTexture = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_VIEW_BY_SHEET"],
        height = 22,
        minWidth = 72,
    })
    btnByTexture:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    Addon.UI:BindToolbarBarButtonMouse(btnByTexture, TEXTURE_BAR_ACTIVE_KEY)
    btnByTexture:SetScript("OnClick", function()
        BR:SetViewMode(BR.VIEW_TEXTURE)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            tab.virtualizedList.SetSelectedIndex(1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            syncPreviewInteraction(tab)
            tab.nameText:SetText("")
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local btnByAtlas = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_VIEW_BY_ATLAS"],
        height = 22,
        minWidth = 72,
    })
    btnByAtlas:SetPoint("LEFT", btnByTexture, "RIGHT", 4, 0)
    Addon.UI:BindToolbarBarButtonMouse(btnByAtlas, TEXTURE_BAR_ACTIVE_KEY)
    btnByAtlas:SetScript("OnClick", function()
        BR:SetViewMode(BR.VIEW_ATLAS)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            tab.virtualizedList.SetSelectedIndex(1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            syncPreviewInteraction(tab)
            tab.nameText:SetText("")
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local favsBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_FAVORITES"],
        height = 22,
        minWidth = 72,
    })
    favsBtn:SetPoint("LEFT", btnByAtlas, "RIGHT", 6, 0)
    Addon.UI:BindToolbarBarButtonMouse(favsBtn, TEXTURE_BAR_ACTIVE_KEY)
    favsBtn:SetScript("OnClick", function()
        BR:SetFavoritesOnly(not BR.favoritesOnly)
        BR:SetFilterText(searchBox:GetSearchText())
        tab.selectedListIndex = nil
        tab.selectedTextureKey = nil
        tab.selectedAtlasName = nil
        tab.sheetSelectionHighlightSuppressed = false
        Addon.UI.TextureTab_RefreshList(tab)
        if BR:GetFilteredCount() > 0 then
            tab.virtualizedList.SetSelectedIndex(1)
        else
            tab.previewSheetHost:Hide()
            tab.previewAtlasHost:Hide()
            syncPreviewInteraction(tab)
            updateDetailPanel(tab)
        end
        Addon.UI.TextureTab_RefreshToolbarButtons(tab)
    end)

    local bookmarkBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_BOOKMARK"],
        height = 22,
        minWidth = 72,
    })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 4, 0)
    Addon.UI:BindToolbarBarButtonMouse(bookmarkBtn, TEXTURE_BAR_ACTIVE_KEY)
    bookmarkBtn:SetScript("OnClick", function()
        if not tab.selectedAtlasName then
            Addon:Print(L["MSG_SELECT_ATLAS"])
            Addon.UI.TextureTab_RefreshToolbarButtons(tab)
            return
        end
        if not Addon.db.global.textureBookmarks then
            Addon.db.global.textureBookmarks = {}
        end
        local name = tab.selectedAtlasName
        if Addon.db.global.textureBookmarks[name] then
            Addon.db.global.textureBookmarks[name] = nil
            Addon:Print((L["MSG_REMOVED_BOOKMARK"]):gsub("{name}", name))
        else
            Addon.db.global.textureBookmarks[name] = true
            Addon:Print((L["MSG_BOOKMARKED"]):gsub("{name}", name))
        end
        textureTabAfterBookmarkToggle(tab)
    end)

    local manualToggle = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["TEXTURE_BTN_MANUAL"],
        height = 22,
        minWidth = 56,
    })
    manualToggle:SetPoint("LEFT", bookmarkBtn, "RIGHT", 6, 0)
    Addon.UI:BindToolbarBarButtonMouse(manualToggle, TEXTURE_BAR_ACTIVE_KEY)

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

    local savedListW = Addon.db.global.textureBrowserLeftPaneWidth
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

    local listAPI = OneWoW_GUI:CreateVirtualizedList(leftPanel, {
        name = "TextureTabListScroll",
        rowHeight = TEX_ROW_H,
        numVisibleRows = NUM_ROWS,
        getCount = function() return BR:GetFilteredCount() end,
        getEntry = function(idx) return BR:GetFilteredEntry(idx) end,
        onSelect = function(idx) applyListSelection(tab, idx) end,
        renderRow = function(btn, idx, entry, isSelected)
            local label = entry.displayName or entry.atlasName or "?"
            if entry.kind == "atlas" and entry.textureKey then
                label = entry.atlasName
            end
            ensureListRowBookmarkIcon(btn, TEX_ROW_H)
            local bookmarks = Addon.db.global.textureBookmarks
            local showBm = false
            if entry.kind == "atlas" and entry.atlasName and bookmarks[entry.atlasName] then
                showBm = true
            elseif entry.kind == "texture" and entry.textureKey and BR:TextureHasBookmarkedAtlas(entry.textureKey, bookmarks) then
                showBm = true
            end
            if showBm then
                btn.bookmarkIcon:SetTexture(BOOKMARK_ICON_PATH)
                btn.bookmarkIcon:Show()
            else
                btn.bookmarkIcon:Hide()
            end
            btn:SetText(label)
            btn._tooltipFullText = label
            styleListButtonText(btn)
        end,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    tab.virtualizedList = listAPI
    tab.listScroll = listAPI.listScroll
    tab.searchBox = searchBox

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
            Addon.db.global.textureBrowserLeftPaneWidth = w
        end,
    })

    local zoomInBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_ZOOM_IN"], height = 22, minWidth = 36 })
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

    local zoomOutBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_ZOOM_OUT"], height = 22, minWidth = 36 })
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

    local resetBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = L["BTN_RESET_ZOOM"], height = 22, minWidth = 56 })
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
        placeholderText = L["TEXTURE_MANUAL_PLACEHOLDER"],
    })
    manualEdit:SetPoint("TOPLEFT", tab.manualPanel, "TOPLEFT", 0, 0)
    manualEdit:SetPoint("RIGHT", tab.manualPanel, "RIGHT", -90, 0)

    local manualApply = OneWoW_GUI:CreateFitTextButton(tab.manualPanel, {
        text = L["TEXTURE_MANUAL_APPLY"],
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
            syncPreviewInteraction(tab)
            releaseOverlays(tab)
            tab.nameText:SetText(path)
            tab.selectedAtlasName = path
            tab.sheetSelectionHighlightSuppressed = false
            tab.selectedTextureKey = BR.atlasPrimaryTexture and BR.atlasPrimaryTexture[path] or nil
            tab.selectedListIndex = nil
            tab.zoomLevel = tab.zoomLevel or 1
            layoutAtlasSoloFrame(tab)
            if tab.virtualizedList then tab.virtualizedList.SetSelectedIndex(nil) end
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
        if tab.virtualizedList then tab.virtualizedList.SetSelectedIndex(nil) end
        updateDetailPanel(tab)
    end)

    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    tab.infoPanel = infoPanel
    infoPanel:ClearAllPoints()
    infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -8)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 42)
    self:StyleContentPanel(infoPanel)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, {})
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
    copyRowLabel:SetText(L["FONT_COPY_ROW_LABEL"])
    copyRowLabel:SetTextColor(1, 0.82, 0)
    copyRowLabel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, 8)

    local copyNameBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_NAME"],
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
        text = L["TEXTURE_BTN_COPY_SNIPPET"],
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
        text = L["TEXTURE_BTN_COPY_COORDS"],
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

    tab:SetScript("OnShow", function()
        syncPreviewInteraction(tab)
    end)

    tab:SetScript("OnHide", function()
        stopPreviewInteraction(tab)
        if tab._filterTicker then
            tab._filterTicker:Cancel()
            tab._filterTicker = nil
        end
    end)

    function tab:Teardown()
        stopPreviewInteraction(self)
        if self._filterTicker then
            self._filterTicker:Cancel()
            self._filterTicker = nil
        end
        if Addon.TextureBrowserTab == self then
            Addon.TextureBrowserTab = nil
        end
    end

    Addon.TextureBrowserTab = tab

    Addon.UI.TextureTab_RefreshList(tab)
    if BR:GetFilteredCount() > 0 then
        tab.virtualizedList.SetSelectedIndex(1)
    else
        updateDetailPanel(tab)
    end
    syncPreviewInteraction(tab)
    Addon.UI.TextureTab_RefreshToolbarButtons(tab)

    return tab
end
