local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L

local function T(key)
    if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
        return unpack(OneWoW.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function ClearPanel(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end

local OVERLAY_SETTINGS_IDS = {
    consumables  = true,
    housingdecor = true,
    itemlevel    = true,
    junk         = true,
    knownitems   = true,
    mounts       = true,
    pets         = true,
    protected    = true,
    quest        = true,
    reagents     = true,
    recipe       = true,
    soulbound    = true,
    toys         = true,
    unknownitems = true,
    upgrade      = true,
    warbound     = true,
}

local POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local PositionOffsets = {
    TOPLEFT     = { 1, -1},
    TOPRIGHT    = {-1, -1},
    BOTTOMLEFT  = { 1,  1},
    BOTTOMRIGHT = {-1,  1},
    BOTTOM      = { 0,  1},
    TOP         = { 0, -1},
    LEFT        = { 1,  0},
    RIGHT       = {-1,  0},
    CENTER      = { 0,  0},
}

local PREVIEW_SLOT_SIZE = 74

local ICON_CATEGORIES = {
    {
        nameKey = "OVR_ICON_CAT_CUSTOM",
        icons   = {
            "icon-add", "icon-alert", "icon-alliance", "icon-compass", "icon-fav",
            "icon-flag", "icon-gears", "icon-horde", "icon-minus", "icon-mount",
            "icon-pet", "icon-pin", "icon-recipe", "icon-toy", "icon-trash",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_MAP",
        icons   = {
            "VignetteKill", "VignetteEvent-SuperTracked",
            "map-icon-ignored-blueexclaimation", "map-icon-ignored-bluequestion",
            "UI-QuestPoiImportant-OuterGlow",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_QUEST",
        icons   = {
            "Quest-Campaign-Available", "Quest-DailyCampaign-Available",
            "QuestArtifactTurnin", "QuestLegendary",
            "questlog-questtypeicon-lock", "questlog-questtypeicon-questfailed",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_WAYPOINTS",
        icons   = {
            "poi-door-arrow-up", "poi-traveldirections-arrow", "talents-arrow-line-red",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_BAGS",
        icons   = {
            "bags-junkcoin", "bags-newitem",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_STATUS",
        icons   = {
            "groupfinder-icon-role-large-tank", "soulbinds_tree_conduit_icon_protect",
            "Bonus-Objective-Star", "collections-icon-favorites",
            "worldquest-icon-petbattle", "mechagon-projects", "ui-achievement-shield-2",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_WARBAND",
        icons   = {
            "greatvault-dragonflight-32x32", "warband-completed-icon", "warbands-icon",
            "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",
            "Warfronts-BaseMapIcons-Alliance-Workshop-Minimap",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_HOUSING",
        icons   = {
            "shop-icon-housing-beds-selected", "shop-icon-housing-mounts-up",
            "shop-icon-housing-pets-selected", "Perks-ShoppingCart",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_GLOWS",
        icons   = {
            "bags-glow-white", "bags-glow-purple", "bags-glow-blue",
            "bags-glow-green", "bags-glow-orange", "bags-glow-artifact",
            "bags-glow-heirloom",
        },
    },
}

local PICKER_MAX_HEIGHT = 220
local PICKER_ROW_HEIGHT = 24
local PICKER_HDR_HEIGHT = 22
local PICKER_ICON_SIZE  = 16

local function CreateIconPicker(parent, initialIcon, onChange)
    local currentSelected = initialIcon or "VignetteEvent-SuperTracked"

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    container:SetBackdropColor(T("BG_TERTIARY"))
    container:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local sbw = 10

    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0,    0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -sbw, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollBar = CreateFrame("Slider", nil, container, "BackdropTemplate")
    scrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    0, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
    scrollBar:SetWidth(sbw)
    scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollBar:SetBackdropColor(T("BG_SECONDARY"))
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 20)
    thumb:SetColorTexture(T("ACCENT_PRIMARY"))
    scrollBar:SetThumbTexture(thumb)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, direction)
        local cur = scrollFrame:GetVerticalScroll()
        local max = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        local new = math.max(0, math.min(max, cur - direction * 28))
        scrollFrame:SetVerticalScroll(new)
        scrollBar:SetValue(new)
    end)

    local catExpanded = {}
    local headers     = {}
    local allItemRows = {}

    for catIdx, cat in ipairs(ICON_CATEGORIES) do
        catExpanded[catIdx] = (catIdx == 1)

        local hdr = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        hdr:SetHeight(PICKER_HDR_HEIGHT)
        hdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        hdr:SetBackdropColor(T("BG_SECONDARY"))
        hdr:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        hdr:Hide()

        local hdrArrow = hdr:CreateTexture(nil, "OVERLAY")
        hdrArrow:SetSize(12, 12)
        hdrArrow:SetPoint("LEFT", hdr, "LEFT", 5, 0)
        if catIdx == 1 then
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
        else
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageNextButton-Up", false)
        end

        local hdrLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdrLabel:SetPoint("LEFT", hdr, "LEFT", 20, 0)
        hdrLabel:SetText(L[cat.nameKey] or cat.nameKey)
        hdrLabel:SetTextColor(T("ACCENT_PRIMARY"))

        local catRows = {}
        for _, iconName in ipairs(cat.icons) do
            local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(PICKER_ROW_HEIGHT)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            row:SetBackdropColor(T("BG_TERTIARY"))
            row:Hide()

            local icoFrame = CreateFrame("Frame", nil, row)
            icoFrame:SetSize(PICKER_ICON_SIZE, PICKER_ICON_SIZE)
            icoFrame:SetPoint("LEFT", row, "LEFT", 22, 0)
            local icoTex = icoFrame:CreateTexture(nil, "ARTWORK")
            icoTex:SetAllPoints(icoFrame)
            OneWoW.OverlayIcons:ApplyToTexture(icoTex, iconName)

            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", icoFrame, "RIGHT", 5, 0)
            lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetText(OneWoW.OverlayIcons:GetDisplayName(iconName))
            lbl:SetTextColor(T("TEXT_PRIMARY"))

            table.insert(catRows,    { iconName = iconName, frame = row, label = lbl })
            table.insert(allItemRows, { iconName = iconName, frame = row, label = lbl })
        end

        headers[catIdx] = { frame = hdr, arrow = hdrArrow, items = catRows }
    end

    local function LayoutPicker()
        local yPos = -2

        for catIdx, cat in ipairs(ICON_CATEGORIES) do
            local hdrData = headers[catIdx]
            local hdr     = hdrData.frame

            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  2, yPos)
            hdr:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
            hdr:Show()
            yPos = yPos - (PICKER_HDR_HEIGHT + 2)

            if catExpanded[catIdx] then
                hdrData.arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
            else
                hdrData.arrow:SetAtlas("UI-HUD-ActionBar-PageNextButton-Up", false)
            end

            for _, rowData in ipairs(hdrData.items) do
                if catExpanded[catIdx] then
                    rowData.frame:ClearAllPoints()
                    rowData.frame:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  2, yPos)
                    rowData.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                    rowData.frame:Show()
                    yPos = yPos - (PICKER_ROW_HEIGHT + 2)

                    if rowData.iconName == currentSelected then
                        rowData.frame:SetBackdropColor(T("BG_ACTIVE"))
                        rowData.label:SetTextColor(T("TEXT_ACCENT"))
                    else
                        rowData.frame:SetBackdropColor(T("BG_TERTIARY"))
                        rowData.label:SetTextColor(T("TEXT_PRIMARY"))
                    end
                else
                    rowData.frame:Hide()
                end
            end
        end

        local totalH = math.abs(yPos) + 4
        scrollChild:SetHeight(totalH)

        local frameH = math.min(PICKER_MAX_HEIGHT, math.max(PICKER_HDR_HEIGHT + 4, totalH))
        container:SetHeight(frameH)

        local maxScroll = math.max(0, totalH - frameH)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollFrame:GetVerticalScroll() > maxScroll then
            scrollFrame:SetVerticalScroll(maxScroll)
            scrollBar:SetValue(maxScroll)
        end
    end

    for catIdx in ipairs(ICON_CATEGORIES) do
        local capturedIdx = catIdx
        headers[catIdx].frame:SetScript("OnClick", function()
            catExpanded[capturedIdx] = not catExpanded[capturedIdx]
            LayoutPicker()
        end)
    end

    for _, rowData in ipairs(allItemRows) do
        local capturedName  = rowData.iconName
        local capturedFrame = rowData.frame
        local capturedLabel = rowData.label

        capturedFrame:SetScript("OnEnter", function(self)
            if capturedName ~= currentSelected then
                self:SetBackdropColor(T("BG_HOVER"))
                capturedLabel:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        capturedFrame:SetScript("OnLeave", function(self)
            if capturedName ~= currentSelected then
                self:SetBackdropColor(T("BG_TERTIARY"))
                capturedLabel:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        capturedFrame:SetScript("OnClick", function()
            currentSelected = capturedName
            LayoutPicker()
            onChange(capturedName)
        end)
    end

    LayoutPicker()
    return container
end

local function CreateDropdown(parent, options, currentValue, onChange, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 160, 26)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    btn:SetBackdropColor(T("BG_TERTIARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT",  btn, "LEFT",  8,   0)
    label:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
    label:SetJustifyH("LEFT")
    label:SetText(currentValue or options[1] or "")
    label:SetTextColor(T("TEXT_PRIMARY"))
    btn.label = label

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
    arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)

    local menu = nil
    btn:SetScript("OnClick", function(self)
        if menu and menu:IsShown() then menu:Hide() return end
        if not menu then
            menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            menu:SetBackdropColor(T("BG_PRIMARY"))
            menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))

            local optH = 24
            menu:SetWidth(self:GetWidth())
            menu:SetHeight(#options * optH + 4)
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

            for i, opt in ipairs(options) do
                local row = CreateFrame("Button", nil, menu)
                row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * optH)
                row:SetSize(self:GetWidth() - 4, optH)
                local rowTx = row:CreateTexture(nil, "BACKGROUND")
                rowTx:SetAllPoints(row)
                rowTx:SetColorTexture(T("BG_SECONDARY"))
                rowTx:Hide()
                local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                rowLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
                rowLabel:SetText(opt)
                rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                row:SetScript("OnEnter", function() rowTx:Show() end)
                row:SetScript("OnLeave", function() rowTx:Hide() end)
                row:SetScript("OnClick", function()
                    label:SetText(opt)
                    menu:Hide()
                    onChange(opt)
                end)
            end

            menu:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(self) and not MouseIsOver(btn) then
                    self.elapsed = (self.elapsed or 0) + elapsed
                    if self.elapsed > 0.5 then self:Hide() self.elapsed = 0 end
                else
                    self.elapsed = 0
                end
            end)
        end
        menu:Show()
    end)

    return btn
end

local function CreateFontDropdown(parent, fontList, currentValue, onChange, width)
    width = width or 160

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 26)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    btn:SetBackdropColor(T("BG_TERTIARY"))
    btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT",  btn, "LEFT",  8,   0)
    label:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
    label:SetJustifyH("LEFT")
    label:SetText(currentValue or "")
    label:SetTextColor(T("TEXT_PRIMARY"))
    btn.label = label

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
    arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)

    local menu = nil
    local currentSelection = currentValue

    local function UpdateButtonFont()
        if currentSelection then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local fontPath = LSM:Fetch("font", currentSelection)
                if fontPath then
                    label:SetFont(fontPath, 11, "")
                    return
                end
            end
        end
        label:SetFontObject("GameFontNormal")
    end

    UpdateButtonFont()

    btn:SetScript("OnClick", function(self)
        if menu and menu:IsShown() then menu:Hide() return end
        if not menu then
            menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            menu:SetBackdropColor(T("BG_PRIMARY"))
            menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            menu:SetWidth(self:GetWidth())

            local sbw = 10
            local MAX_HEIGHT = 300
            local ROW_H = 24
            local PAD = 2

            local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
            scrollFrame:SetPoint("TOPLEFT",     menu, "TOPLEFT",     0,    0)
            scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -sbw, 0)
            scrollFrame:EnableMouseWheel(true)

            local scrollBar = CreateFrame("Slider", nil, menu, "BackdropTemplate")
            scrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",    0, 0)
            scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
            scrollBar:SetWidth(sbw)
            scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            scrollBar:SetBackdropColor(T("BG_SECONDARY"))
            scrollBar:SetMinMaxValues(0, 1)
            scrollBar:SetValue(0)
            scrollBar:SetScript("OnValueChanged", function(_, value)
                scrollFrame:SetVerticalScroll(value)
            end)

            local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
            thumb:SetSize(8, 20)
            thumb:SetColorTexture(T("ACCENT_PRIMARY"))
            scrollBar:SetThumbTexture(thumb)

            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollChild:SetHeight(1)
            scrollFrame:SetScrollChild(scrollChild)

            scrollFrame:HookScript("OnSizeChanged", function(self, w)
                scrollChild:SetWidth(w)
            end)

            scrollFrame:SetScript("OnMouseWheel", function(self, direction)
                local cur = scrollFrame:GetVerticalScroll()
                local max = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
                local new = math.max(0, math.min(max, cur - direction * 28))
                scrollFrame:SetVerticalScroll(new)
                scrollBar:SetValue(new)
            end)

            for i, fontName in ipairs(fontList) do
                local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(ROW_H)
                row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  PAD, -PAD - (i - 1) * ROW_H)
                row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -PAD, -PAD - (i - 1) * ROW_H)
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

                if fontName == currentSelection then
                    row:SetBackdropColor(T("BG_ACTIVE"))
                else
                    row:SetBackdropColor(T("BG_SECONDARY"))
                end

                local rowFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                rowFS:SetPoint("LEFT", row, "LEFT", 8, 0)
                rowFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                rowFS:SetJustifyH("LEFT")
                rowFS:SetText(fontName)

                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local fontPath = LSM:Fetch("font", fontName)
                    if fontPath then
                        rowFS:SetFont(fontPath, 11, "")
                    end
                end

                if fontName == currentSelection then
                    rowFS:SetTextColor(T("ACCENT_PRIMARY"))
                else
                    rowFS:SetTextColor(T("TEXT_PRIMARY"))
                end

                row:SetScript("OnEnter", function(self)
                    if fontName ~= currentSelection then
                        self:SetBackdropColor(T("BG_HOVER"))
                    end
                    rowFS:SetTextColor(T("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(self)
                    if fontName == currentSelection then
                        self:SetBackdropColor(T("BG_ACTIVE"))
                        rowFS:SetTextColor(T("ACCENT_PRIMARY"))
                    else
                        self:SetBackdropColor(T("BG_SECONDARY"))
                        rowFS:SetTextColor(T("TEXT_PRIMARY"))
                    end
                end)
                row:SetScript("OnClick", function()
                    currentSelection = fontName
                    label:SetText(fontName)
                    UpdateButtonFont()
                    menu:Hide()
                    onChange(fontName)
                end)
            end

            local totalH = PAD * 2 + #fontList * ROW_H
            scrollChild:SetHeight(totalH)
            local frameH = math.min(MAX_HEIGHT, math.max(ROW_H + 4, totalH))
            menu:SetHeight(frameH)

            local maxScroll = math.max(0, totalH - frameH)
            scrollBar:SetMinMaxValues(0, maxScroll)

            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

            menu:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(self) and not MouseIsOver(btn) then
                    self.elapsed = (self.elapsed or 0) + elapsed
                    if self.elapsed > 0.5 then self:Hide() self.elapsed = 0 end
                else
                    self.elapsed = 0
                end
            end)
        end
        menu:Show()
    end)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    return btn
end

local function CreateSlider(parent, minVal, maxVal, step, currentVal, onChange, width, fmt)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 200, 36)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",  container, "TOPLEFT",  0,   0)
    slider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -40, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(currentVal)
    slider:SetObeyStepOnDrag(true)

    local valLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valLabel:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    valLabel:SetText(string.format(fmt or "%.1f", currentVal))
    valLabel:SetTextColor(T("TEXT_PRIMARY"))

    if slider.Low  then slider.Low:SetText(tostring(minVal)) end
    if slider.High then slider.High:SetText(tostring(maxVal)) end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(self, val)
        local rounded = math.floor(val / step + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valLabel:SetText(string.format(fmt or "%.1f", rounded))
        onChange(rounded)
    end)

    return container
end

local function CreateSlotPreview(parent, featureId, reg)
    local SLOT_SIZE = PREVIEW_SLOT_SIZE

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(SLOT_SIZE + 6, SLOT_SIZE + 6)
    container:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(T("BG_SECONDARY"))
    container:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local slotFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    slotFrame:SetSize(SLOT_SIZE, SLOT_SIZE)
    slotFrame:SetPoint("CENTER", container, "CENTER", 0, 0)
    slotFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slotFrame:SetBackdropColor(0.07, 0.07, 0.07, 1)
    slotFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    local itemTex = slotFrame:CreateTexture(nil, "ARTWORK")
    itemTex:SetPoint("TOPLEFT",     slotFrame, "TOPLEFT",     1, -1)
    itemTex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1,  1)
    itemTex:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")

    local overlayFrame = CreateFrame("Frame", nil, slotFrame)
    overlayFrame:SetFrameLevel(slotFrame:GetFrameLevel() + 3)
    overlayFrame:EnableMouse(false)

    local overlayTex = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    overlayTex:SetAllPoints(overlayFrame)

    local function Refresh()
        local icon     = reg:GetOverlaySetting(featureId, "icon")     or "VignetteEvent-SuperTracked"
        local position = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local scale    = reg:GetOverlaySetting(featureId, "scale")    or 1.0
        local alpha    = reg:GetOverlaySetting(featureId, "alpha")    or 1.0
        local offsets  = PositionOffsets[position] or {0, 0}
        local baseSize = SLOT_SIZE * 0.54
        local finalSize = baseSize * scale

        overlayFrame:ClearAllPoints()
        overlayFrame:SetPoint(position, slotFrame, position, offsets[1], offsets[2])
        overlayFrame:SetSize(finalSize, finalSize)
        OneWoW.OverlayIcons:ApplyToTexture(overlayTex, icon)
        overlayTex:SetAlpha(alpha)
        overlayFrame:Show()
    end

    Refresh()

    return container, Refresh
end

local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L["OVR_GENERAL_TITLE"])
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L["OVR_GENERAL_DESC"])
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")

    local statusPrefix = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusPrefix:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    statusPrefix:SetText(L["FEATURE_STATUS_LABEL"])
    statusPrefix:SetTextColor(T("TEXT_PRIMARY"))

    local statusValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)
    if isEnabled then
        statusValue:SetText(L["FEATURE_ENABLED"])
        statusValue:SetTextColor(0.2, 1.0, 0.2)
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(1.0, 0.2, 0.2)
    end

    local toggleBtn = GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
        OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(1.0, 0.2, 0.2)
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.enabledDot then
            if nowEnabled then
                selectedRow.enabledDot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
            else
                selectedRow.enabledDot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
            end
        end
    end)

    yOffset = yOffset - 30 - 20

    local noteLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(3)
    noteLabel:SetText(L["OVR_GENERAL_NOTE"])
    noteLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 20

    local intDiv = dsc:CreateTexture(nil, "ARTWORK")
    intDiv:SetHeight(1)
    intDiv:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 14

    local intHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    intHeader:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intHeader:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intHeader:SetJustifyH("LEFT")
    intHeader:SetText(L["OVR_INTEGRATIONS_HEADER"])
    intHeader:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - intHeader:GetStringHeight() - 6

    local intDesc = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intDesc:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intDesc:SetJustifyH("LEFT")
    intDesc:SetWordWrap(true)
    intDesc:SetSpacing(3)
    intDesc:SetText(L["OVR_INTEGRATIONS_DESC"])
    intDesc:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - intDesc:GetStringHeight() - 10

    local arkDetected  = C_AddOns.IsAddOnLoaded("ArkInventory")
    local ovDB         = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
    local arkEnabled   = not (ovDB and ovDB.integrations and ovDB.integrations.arkinventory and ovDB.integrations.arkinventory.enabled == false)

    local arkRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    arkRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    arkRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    arkRow:SetHeight(30)
    arkRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    arkRow:SetBackdropColor(T("BG_TERTIARY"))
    arkRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local arkName = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkName:SetPoint("LEFT", arkRow, "LEFT", 10, 0)
    arkName:SetText("ArkInventory")
    arkName:SetTextColor(T("TEXT_PRIMARY"))

    local arkStatusLabel = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkStatusLabel:SetPoint("LEFT", arkName, "RIGHT", 16, 0)
    arkStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    arkStatusLabel:SetTextColor(T("TEXT_SECONDARY"))

    local arkStatusValue = arkRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arkStatusValue:SetPoint("LEFT", arkStatusLabel, "RIGHT", 4, 0)

    if not arkDetected then
        arkStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        arkStatusValue:SetTextColor(0.5, 0.5, 0.5)
    else
        if arkEnabled then
            arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            arkStatusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            arkStatusValue:SetTextColor(1.0, 0.4, 0.4)
        end

        local arkToggleBtn = GUI:CreateButton(nil, arkRow, arkEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        arkToggleBtn:SetPoint("RIGHT", arkRow, "RIGHT", -6, 0)
        arkToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.arkinventory = db.integrations.arkinventory or {}
            local nowEnabled = db.integrations.arkinventory.enabled ~= false
            db.integrations.arkinventory.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                arkStatusValue:SetTextColor(0.2, 1.0, 0.2)
            else
                arkStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                arkStatusValue:SetTextColor(1.0, 0.4, 0.4)
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local bagDetected  = C_AddOns.IsAddOnLoaded("Baganator")
    local bagEnabled   = not (ovDB and ovDB.integrations and ovDB.integrations.baganator and ovDB.integrations.baganator.enabled == false)

    local bagRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bagRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bagRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bagRow:SetHeight(30)
    bagRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bagRow:SetBackdropColor(T("BG_TERTIARY"))
    bagRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bagName = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagName:SetPoint("LEFT", bagRow, "LEFT", 10, 0)
    bagName:SetText("Baganator")
    bagName:SetTextColor(T("TEXT_PRIMARY"))

    local bagStatusLabel = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagStatusLabel:SetPoint("LEFT", bagName, "RIGHT", 16, 0)
    bagStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bagStatusLabel:SetTextColor(T("TEXT_SECONDARY"))

    local bagStatusValue = bagRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagStatusValue:SetPoint("LEFT", bagStatusLabel, "RIGHT", 4, 0)

    if not bagDetected then
        bagStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bagStatusValue:SetTextColor(0.5, 0.5, 0.5)
    else
        if bagEnabled then
            bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            bagStatusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            bagStatusValue:SetTextColor(1.0, 0.4, 0.4)
        end

        local bagToggleBtn = GUI:CreateButton(nil, bagRow, bagEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        bagToggleBtn:SetPoint("RIGHT", bagRow, "RIGHT", -6, 0)
        bagToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.baganator = db.integrations.baganator or {}
            local nowEnabled = db.integrations.baganator.enabled ~= false
            db.integrations.baganator.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                bagStatusValue:SetTextColor(0.2, 1.0, 0.2)
            else
                bagStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                bagStatusValue:SetTextColor(1.0, 0.4, 0.4)
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local bgnDetected = C_AddOns.IsAddOnLoaded("Bagnon")

    local bgnRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bgnRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bgnRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bgnRow:SetHeight(30)
    bgnRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bgnRow:SetBackdropColor(T("BG_TERTIARY"))
    bgnRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bgnName = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnName:SetPoint("LEFT", bgnRow, "LEFT", 10, 0)
    bgnName:SetText("Bagnon")
    bgnName:SetTextColor(T("TEXT_PRIMARY"))

    local bgnStatusLabel = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnStatusLabel:SetPoint("LEFT", bgnName, "RIGHT", 16, 0)
    bgnStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bgnStatusLabel:SetTextColor(T("TEXT_SECONDARY"))

    local bgnStatusValue = bgnRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgnStatusValue:SetPoint("LEFT", bgnStatusLabel, "RIGHT", 4, 0)

    if not bgnDetected then
        bgnStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bgnStatusValue:SetTextColor(0.5, 0.5, 0.5)
    else
        bgnStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["OVR_INT_NOT_COMPATIBLE"] .. ")")
        bgnStatusValue:SetTextColor(1.0, 0.65, 0.0)
    end

    yOffset = yOffset - 34

    local bbDetected = C_AddOns.IsAddOnLoaded("BetterBags")
    local bbEnabled  = not (ovDB and ovDB.integrations and ovDB.integrations.betterbags and ovDB.integrations.betterbags.enabled == false)

    local bbRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    bbRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    bbRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    bbRow:SetHeight(30)
    bbRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bbRow:SetBackdropColor(T("BG_TERTIARY"))
    bbRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bbName = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbName:SetPoint("LEFT", bbRow, "LEFT", 10, 0)
    bbName:SetText("BetterBags")
    bbName:SetTextColor(T("TEXT_PRIMARY"))

    local bbStatusLabel = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbStatusLabel:SetPoint("LEFT", bbName, "RIGHT", 16, 0)
    bbStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    bbStatusLabel:SetTextColor(T("TEXT_SECONDARY"))

    local bbStatusValue = bbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bbStatusValue:SetPoint("LEFT", bbStatusLabel, "RIGHT", 4, 0)

    if not bbDetected then
        bbStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        bbStatusValue:SetTextColor(0.5, 0.5, 0.5)
    else
        if bbEnabled then
            bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            bbStatusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            bbStatusValue:SetTextColor(1.0, 0.4, 0.4)
        end

        local bbToggleBtn = GUI:CreateButton(nil, bbRow, bbEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        bbToggleBtn:SetPoint("RIGHT", bbRow, "RIGHT", -6, 0)
        bbToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.betterbags = db.integrations.betterbags or {}
            local nowEnabled = db.integrations.betterbags.enabled ~= false
            db.integrations.betterbags.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                bbStatusValue:SetTextColor(0.2, 1.0, 0.2)
            else
                bbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                bbStatusValue:SetTextColor(1.0, 0.4, 0.4)
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    local owbDetected = C_AddOns.IsAddOnLoaded("OneWoW_Bags")
    local owbEnabled  = not (ovDB and ovDB.integrations and ovDB.integrations.onewow_bags and ovDB.integrations.onewow_bags.enabled == false)

    local owbRow = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    owbRow:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    owbRow:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    owbRow:SetHeight(30)
    owbRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    owbRow:SetBackdropColor(T("BG_TERTIARY"))
    owbRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local owbName = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbName:SetPoint("LEFT", owbRow, "LEFT", 10, 0)
    owbName:SetText("OneWoW Bags")
    owbName:SetTextColor(T("TEXT_PRIMARY"))

    local owbStatusLabel = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbStatusLabel:SetPoint("LEFT", owbName, "RIGHT", 16, 0)
    owbStatusLabel:SetText(L["FEATURE_STATUS_LABEL"])
    owbStatusLabel:SetTextColor(T("TEXT_SECONDARY"))

    local owbStatusValue = owbRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    owbStatusValue:SetPoint("LEFT", owbStatusLabel, "RIGHT", 4, 0)

    if not owbDetected then
        owbStatusValue:SetText(L["OVR_INT_NOT_DETECTED"])
        owbStatusValue:SetTextColor(0.5, 0.5, 0.5)
    else
        if owbEnabled then
            owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
            owbStatusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
            owbStatusValue:SetTextColor(1.0, 0.4, 0.4)
        end

        local owbToggleBtn = GUI:CreateButton(nil, owbRow, owbEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 22)
        owbToggleBtn:SetPoint("RIGHT", owbRow, "RIGHT", -6, 0)
        owbToggleBtn:SetScript("OnClick", function(self)
            local db = OneWoW.db.global.settings.overlays
            db.integrations = db.integrations or {}
            db.integrations.onewow_bags = db.integrations.onewow_bags or {}
            local nowEnabled = db.integrations.onewow_bags.enabled ~= false
            db.integrations.onewow_bags.enabled = not nowEnabled
            nowEnabled = not nowEnabled
            if nowEnabled then
                owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_ENABLED"] .. ")")
                owbStatusValue:SetTextColor(0.2, 1.0, 0.2)
            else
                owbStatusValue:SetText(L["OVR_INT_DETECTED"] .. " (" .. L["FEATURE_DISABLED"] .. ")")
                owbStatusValue:SetTextColor(1.0, 0.4, 0.4)
            end
            self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
            OneWoW.OverlayEngine:Refresh()
        end)
    end

    yOffset = yOffset - 34

    dsc:SetHeight(math.abs(yOffset) + 20)
    split.UpdateDetailThumb()
end

local function ShowOverlayDetail(split, feature, selectedRow)
    local dsc = split.detailScrollChild
    ClearPanel(dsc)

    local featureId = feature.id
    local reg       = OneWoW.SettingsFeatureRegistry

    if featureId == "general" then
        ShowGeneralDetail(split, dsc, selectedRow)
        return
    end

    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = reg:IsEnabled("overlays", featureId)

    local statusPrefix = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusPrefix:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    statusPrefix:SetText(L["FEATURE_STATUS_LABEL"])
    statusPrefix:SetTextColor(T("TEXT_PRIMARY"))

    local statusValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)
    if isEnabled then
        statusValue:SetText(L["FEATURE_ENABLED"])
        statusValue:SetTextColor(0.2, 1.0, 0.2)
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(1.0, 0.2, 0.2)
    end

    local toggleBtn = GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = reg:IsEnabled("overlays", featureId)
        reg:SetEnabled("overlays", featureId, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(1.0, 0.2, 0.2)
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.enabledDot then
            if nowEnabled then
                selectedRow.enabledDot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
            else
                selectedRow.enabledDot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
            end
        end
    end)

    yOffset = yOffset - 30 - 20

    if not OVERLAY_SETTINGS_IDS[featureId] then
        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local secDiv = dsc:CreateTexture(nil, "ARTWORK")
    secDiv:SetHeight(1)
    secDiv:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    secDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    secDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 14

    if featureId == "quest" then
        local questNote = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        questNote:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
        questNote:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        questNote:SetJustifyH("LEFT")
        questNote:SetWordWrap(true)
        questNote:SetSpacing(3)
        questNote:SetText(L["OVR_QUEST_NOTE"])
        questNote:SetTextColor(T("TEXT_SECONDARY"))
        yOffset = yOffset - questNote:GetStringHeight() - 16

        local vendorCb = GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
        vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") or false)
        vendorCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb = GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
        ahCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        ahCb:SetChecked(reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false)
        ahCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 10

        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local settingsHdr = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsHdr:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    settingsHdr:SetText(L["OVR_SETTINGS_HEADER"])
    settingsHdr:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - settingsHdr:GetStringHeight() - 10

    if featureId == "itemlevel" then
        local rightY = yOffset

        local posLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        posLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        posLabel:SetText(L["OVR_POSITION_LABEL"])
        posLabel:SetTextColor(T("TEXT_PRIMARY"))
        yOffset = yOffset - posLabel:GetStringHeight() - 6

        local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local posDD = CreateDropdown(dsc, POSITIONS, currentPos, function(val)
            reg:SetOverlaySetting(featureId, "position", val)
        end, 160)
        posDD:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 26 - 16

        local qualCb = GUI:CreateCheckbox(nil, dsc, L["OVR_QUALITY_COLORS_LABEL"])
        qualCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        qualCb:SetChecked(reg:GetOverlaySetting(featureId, "useQualityColors") or false)
        qualCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "useQualityColors", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local vendorCb2 = GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
        vendorCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") ~= false)
        vendorCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb2 = GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
        ahCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        ahCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false)
        ahCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local fsLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fsLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        fsLabel:SetText(L["OVR_FONTSIZE_LABEL"])
        fsLabel:SetTextColor(T("TEXT_PRIMARY"))
        yOffset = yOffset - fsLabel:GetStringHeight() - 6

        local currentFS = reg:GetOverlaySetting(featureId, "fontSize") or 10
        local fsSlider = CreateSlider(dsc, 7, 20, 1, currentFS, function(val)
            reg:SetOverlaySetting(featureId, "fontSize", val)
        end, 240, "%d")
        fsSlider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 36 - 10

        local LSM = LibStub("LibSharedMedia-3.0", true)
        local fontList = {}
        if LSM then
            fontList = LSM:List("font") or {}
        end
        table.sort(fontList)

        local fontLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        fontLabel:SetText(L["OVR_FONT_LABEL"] or "Font")
        fontLabel:SetTextColor(T("TEXT_PRIMARY"))
        rightY = rightY - fontLabel:GetStringHeight() - 6

        local currentFont = reg:GetOverlaySetting(featureId, "fontFamily") or "Friz Quadrata TF"
        local fontDD = CreateFontDropdown(dsc, fontList, currentFont, function(val)
            reg:SetOverlaySetting(featureId, "fontFamily", val)
            OneWoW.OverlayEngine:Refresh()
        end, 240)
        fontDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
        fontDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
        rightY = rightY - 26 - 16

        local outlineLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        outlineLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        outlineLabel:SetText("Font Outline")
        outlineLabel:SetTextColor(T("TEXT_PRIMARY"))
        rightY = rightY - outlineLabel:GetStringHeight() - 6

        local outlineOptions = {"None", "Outline", "Thick Outline"}
        local currentOutline = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
        local outlineDisplayMap = {[""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline"}
        local outlineValueMap = {["None"] = "", ["Outline"] = "OUTLINE", ["Thick Outline"] = "THICKOUTLINE"}
        local outlineDD = CreateDropdown(dsc, outlineOptions, outlineDisplayMap[currentOutline], function(val)
            reg:SetOverlaySetting(featureId, "fontOutline", outlineValueMap[val])
            OneWoW.OverlayEngine:Refresh()
        end, 240)
        outlineDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
        outlineDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
        rightY = rightY - 26 - 10

        yOffset = math.min(yOffset, rightY)
        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    local currentIcon = reg:GetOverlaySetting(featureId, "icon") or "VignetteEvent-SuperTracked"

    local previewContainer, RefreshPreview = CreateSlotPreview(dsc, featureId, reg)
    local rightY = yOffset

    local previewFrame = CreateFrame("Frame", nil, dsc)
    previewFrame:SetSize(20, 20)
    previewFrame:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    local previewTex = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTex:SetAllPoints(previewFrame)
    OneWoW.OverlayIcons:ApplyToTexture(previewTex, currentIcon)

    local previewName = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewName:SetPoint("LEFT", previewFrame, "RIGHT", 6, 0)
    previewName:SetText(OneWoW.OverlayIcons:GetDisplayName(currentIcon))
    previewName:SetTextColor(T("TEXT_SECONDARY"))
    rightY = rightY - 24 - 6

    previewContainer:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    rightY = rightY - previewContainer:GetHeight() - 10

    local posLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    posLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    posLabel:SetText(L["OVR_POSITION_LABEL"])
    posLabel:SetTextColor(T("TEXT_PRIMARY"))
    rightY = rightY - posLabel:GetStringHeight() - 6

    local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
    local posDropdown = CreateDropdown(dsc, POSITIONS, currentPos, function(val)
        reg:SetOverlaySetting(featureId, "position", val)
        RefreshPreview()
    end, 160)
    posDropdown:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    posDropdown:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 26 - 10

    local scaleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    scaleLabel:SetText(L["OVR_SCALE_LABEL"])
    scaleLabel:SetTextColor(T("TEXT_PRIMARY"))
    rightY = rightY - scaleLabel:GetStringHeight() - 6

    local currentScale = reg:GetOverlaySetting(featureId, "scale") or 1.0
    local scaleSlider  = CreateSlider(dsc, 0.5, 2.0, 0.1, currentScale, function(val)
        reg:SetOverlaySetting(featureId, "scale", val)
        RefreshPreview()
    end, 160)
    scaleSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    scaleSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 10

    local alphaLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    alphaLabel:SetText(L["OVR_ALPHA_LABEL"])
    alphaLabel:SetTextColor(T("TEXT_PRIMARY"))
    rightY = rightY - alphaLabel:GetStringHeight() - 6

    local currentAlpha = reg:GetOverlaySetting(featureId, "alpha") or 1.0
    local alphaSlider  = CreateSlider(dsc, 0.1, 1.0, 0.1, currentAlpha, function(val)
        reg:SetOverlaySetting(featureId, "alpha", val)
        RefreshPreview()
    end, 160)
    alphaSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    alphaSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 16

    local iconLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    iconLabel:SetText(L["OVR_ICON_LABEL"])
    iconLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - 18 - 4

    local picker = CreateIconPicker(dsc, currentIcon, function(iconName)
        reg:SetOverlaySetting(featureId, "icon", iconName)
        OneWoW.OverlayIcons:ApplyToTexture(previewTex, iconName)
        previewName:SetText(OneWoW.OverlayIcons:GetDisplayName(iconName))
        RefreshPreview()
    end)
    picker:SetPoint("TOPLEFT",  dsc, "TOPLEFT", 12,  yOffset)
    picker:SetPoint("TOPRIGHT", dsc, "TOP",     -20, yOffset)
    yOffset = yOffset - picker:GetHeight() - 16

    yOffset = math.min(yOffset, rightY)

    local vendorCb = GUI:CreateCheckbox(nil, dsc, L["OVR_VENDOR_LABEL"])
    vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local vendorEnabled = reg:GetOverlaySetting(featureId, "applyToVendorItems") or false
    vendorCb:SetChecked(vendorEnabled)
    vendorCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
    end)
    yOffset = yOffset - 30

    local ahCb = GUI:CreateCheckbox(nil, dsc, L["OVR_AH_LABEL"])
    ahCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local ahEnabled = reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false
    ahCb:SetChecked(ahEnabled)
    ahCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
    end)
    yOffset = yOffset - 30 - 10

    if featureId == "junk" or featureId == "protected" then
        local tooltipCb = GUI:CreateCheckbox(nil, dsc, L["OVR_TOOLTIP_LABEL"])
        tooltipCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        tooltipCb:SetChecked(reg:GetOverlaySetting(featureId, "showInTooltip") ~= false)
        tooltipCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showInTooltip", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 10
    end

    dsc:SetHeight(math.abs(yOffset) + 20)
    split.UpdateDetailThumb()
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    ClearPanel(lsc)

    local features    = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local yOffset     = -5

    for _, feature in ipairs(features) do
        local capturedFeature = feature
        local row = CreateFrame("Button", nil, lsc, "BackdropTemplate")
        row:SetPoint("TOPLEFT",  lsc, "TOPLEFT",  4, yOffset)
        row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
        row:SetHeight(32)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row:SetBackdropColor(T("BG_SECONDARY"))
        row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowLabel:SetPoint("LEFT",  row, "LEFT",  10, 0)
        rowLabel:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        rowLabel:SetJustifyH("LEFT")
        rowLabel:SetText(L[feature.title] or feature.title)
        rowLabel:SetTextColor(T("TEXT_PRIMARY"))
        row.rowLabel = rowLabel

        local dot = row:CreateTexture(nil, "OVERLAY")
        dot:SetSize(8, 8)
        dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        if OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id) then
            dot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
        else
            dot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
        end
        row.enabledDot = dot

        row:SetScript("OnClick", function(self)
            if selectedRow and selectedRow ~= self then
                selectedRow:SetBackdropColor(T("BG_SECONDARY"))
                selectedRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                if selectedRow.rowLabel then
                    selectedRow.rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
            selectedRow = self
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            rowLabel:SetTextColor(T("TEXT_ACCENT"))
            ShowOverlayDetail(split, capturedFeature, self)
            if split.rightStatusText then
                local featureName = L[capturedFeature.title] or capturedFeature.title
                local featureEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", capturedFeature.id)
                split.rightStatusText:SetText(featureName .. (featureEnabled and " (Enabled)" or " (Disabled)"))
            end
        end)
        row:SetScript("OnEnter", function(self)
            if selectedRow ~= self then
                self:SetBackdropColor(T("BG_HOVER"))
                rowLabel:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        row:SetScript("OnLeave", function(self)
            if selectedRow ~= self then
                self:SetBackdropColor(T("BG_SECONDARY"))
                rowLabel:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)

        yOffset = yOffset - 36
    end

    lsc:SetHeight(math.abs(yOffset) + 10)
    split.UpdateListThumb()

    if #features > 0 then
        local firstRow = lsc:GetChildren()
        if firstRow then firstRow:Click() end
    end
end

function GUI:CreateOverlaysTab(parent)
    local split = GUI:CreateSplitPanel(parent)
    split.listTitle:SetText(L["OVERLAYS_LIST_TITLE"])
    split.detailTitle:SetText(L["OVERLAYS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "overlays")
        local features = OneWoW.SettingsFeatureRegistry:GetByTab("overlays")
        local enabledCount = 0
        for _, f in ipairs(features) do
            if OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", f.id) then
                enabledCount = enabledCount + 1
            end
        end
        split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
    end)
end
