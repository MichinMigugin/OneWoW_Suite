local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

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
    transmog       = true,
}

local POSITIONS = {
    "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
    "Outer-Top-Left", "Outer-Top-Middle", "Outer-Top-Right",
    "Outer-Bottom-Left", "Outer-Bottom-Middle", "Outer-Bottom-Right",
}

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

local OuterPositionData = {
    ["Outer-Top-Left"]      = { "TOPLEFT",     4, -4 },
    ["Outer-Top-Middle"]    = { "TOP",         0, -4 },
    ["Outer-Top-Right"]     = { "TOPRIGHT",   -4, -4 },
    ["Outer-Bottom-Left"]   = { "BOTTOMLEFT",  4,  4 },
    ["Outer-Bottom-Middle"] = { "BOTTOM",      0,  4 },
    ["Outer-Bottom-Right"]  = { "BOTTOMRIGHT",-4,  4 },
}

local ICON_EFFECT_OPTIONS = { "None", "Spinning", "Zooming", "Both" }
local ICON_EFFECT_VALUE_MAP  = { ["None"] = "none", ["Spinning"] = "spinning", ["Zooming"] = "zooming", ["Both"] = "both" }
local ICON_EFFECT_DISPLAY_MAP = { ["none"] = "None", ["spinning"] = "Spinning", ["zooming"] = "Zooming", ["both"] = "Both" }

local BG_STYLE_OPTIONS = { "Solid-Circle", "Solid-Square", "Spinning Orbs", "Glow Pulse", "Portal Spiral" }

local PREVIEW_SLOT_SIZE = 74
-- Item link used only for overlay settings preview when "rarity-colored background" is enabled (matches engine: C_Item.GetItemQualityColor).
local PREVIEW_BG_RARITY_ITEM_LINK = "|cff0070dd|Hitem:19019::::::::60:::::::::|h[]|h|r"

local ICON_CATEGORIES = {
    {
        nameKey = "OVR_ICON_CAT_CUSTOM",
        icons   = {
            "BLANK",
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
    {
        nameKey = "OVR_ICON_CAT_MISC",
        icons   = {
            "Battlenet-ClientIcon-WoW", "BfAMission-Icon-HUB",
            "BfAMission-Icon-Normal", "midnight-beta-access",
            "checkmark-minimal-disabled",
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
    container:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(container, {})
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0,    0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)

    local catExpanded = {}
    local headers     = {}
    local allItemRows = {}

    for catIdx, cat in ipairs(ICON_CATEGORIES) do
        catExpanded[catIdx] = (catIdx == 1)

        local hdr = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        hdr:SetHeight(PICKER_HDR_HEIGHT)
        hdr:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        hdr:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        hdr:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        hdr:Hide()

        local hdrArrow = hdr:CreateTexture(nil, "OVERLAY")
        hdrArrow:SetSize(12, 12)
        hdrArrow:SetPoint("LEFT", hdr, "LEFT", 5, 0)
        if catIdx == 1 then
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
        else
            hdrArrow:SetAtlas("UI-HUD-ActionBar-PageNextButton-Up", false)
        end

        local hdrLabel = OneWoW_GUI:CreateFS(hdr, 10)
        hdrLabel:SetPoint("LEFT", hdr, "LEFT", 20, 0)
        hdrLabel:SetText(L[cat.nameKey] or cat.nameKey)
        hdrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        local catRows = {}
        for _, iconName in ipairs(cat.icons) do
            local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(PICKER_ROW_HEIGHT)
            row:SetBackdrop(BACKDROP_SIMPLE)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:Hide()

            local icoFrame = CreateFrame("Frame", nil, row)
            icoFrame:SetSize(PICKER_ICON_SIZE, PICKER_ICON_SIZE)
            icoFrame:SetPoint("LEFT", row, "LEFT", 22, 0)
            local icoTex = icoFrame:CreateTexture(nil, "ARTWORK")
            icoTex:SetAllPoints(icoFrame)
            OneWoW.OverlayIcons:ApplyToTexture(icoTex, iconName)

            local lbl = OneWoW_GUI:CreateFS(row, 10)
            lbl:SetPoint("LEFT", icoFrame, "RIGHT", 5, 0)
            lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetText(OneWoW.OverlayIcons:GetDisplayName(iconName))
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

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
                        rowData.frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                        rowData.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    else
                        rowData.frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                        rowData.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:SetMinMaxValues(0, maxScroll)
            if scrollFrame:GetVerticalScroll() > maxScroll then
                scrollFrame.ScrollBar:SetValue(maxScroll)
            end
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
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                capturedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        capturedFrame:SetScript("OnLeave", function(self)
            if capturedName ~= currentSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                capturedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

local function CreateSlotPreview(parent, featureId, reg)
    local SLOT_SIZE = PREVIEW_SLOT_SIZE

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(SLOT_SIZE + 6, SLOT_SIZE + 6)
    container:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local slotFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    slotFrame:SetSize(SLOT_SIZE, SLOT_SIZE)
    slotFrame:SetPoint("CENTER", container, "CENTER", 0, 0)
    slotFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    slotFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    slotFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local itemTex = slotFrame:CreateTexture(nil, "ARTWORK")
    itemTex:SetPoint("TOPLEFT",     slotFrame, "TOPLEFT",     1, -1)
    itemTex:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -1,  1)
    itemTex:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")

    local overlayFrame = CreateFrame("Frame", nil, slotFrame)
    overlayFrame:SetFrameLevel(slotFrame:GetFrameLevel() + 3)
    overlayFrame:EnableMouse(false)

    local overlayTex = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    overlayTex:SetAllPoints(overlayFrame)

    local iconAnim = overlayFrame:CreateAnimationGroup()
    local iSpin1 = iconAnim:CreateAnimation("Rotation")
    iSpin1:SetDuration(1.5); iSpin1:SetDegrees(-360); iSpin1:SetOrder(1)
    local iScaleUp = iconAnim:CreateAnimation("Scale")
    iScaleUp:SetDuration(0.75); iScaleUp:SetScale(1.5, 1.5); iScaleUp:SetOrder(1)
    local iSpin2 = iconAnim:CreateAnimation("Rotation")
    iSpin2:SetDuration(1.5); iSpin2:SetDegrees(-360); iSpin2:SetOrder(2)
    local iScaleDown = iconAnim:CreateAnimation("Scale")
    iScaleDown:SetDuration(0.75); iScaleDown:SetScale(1/1.5, 1/1.5); iScaleDown:SetOrder(2)
    iconAnim:SetLooping("REPEAT")

    local bgFrame = CreateFrame("Frame", nil, overlayFrame)
    bgFrame:SetPoint("CENTER", overlayFrame, "CENTER", 0, 0)
    bgFrame:SetFrameLevel(overlayFrame:GetFrameLevel() - 1)
    bgFrame:EnableMouse(false)
    local bgTex = bgFrame:CreateTexture(nil, "ARTWORK")

    local bgAnim = bgTex:CreateAnimationGroup()
    local bSpin1 = bgAnim:CreateAnimation("Rotation")
    bSpin1:SetDuration(1.5); bSpin1:SetDegrees(-360); bSpin1:SetOrder(1)
    local bScaleUp = bgAnim:CreateAnimation("Scale")
    bScaleUp:SetDuration(0.75); bScaleUp:SetScale(1.8, 1.8); bScaleUp:SetOrder(1)
    local bSpin2 = bgAnim:CreateAnimation("Rotation")
    bSpin2:SetDuration(1.5); bSpin2:SetDegrees(-360); bSpin2:SetOrder(2)
    local bScaleDown = bgAnim:CreateAnimation("Scale")
    bScaleDown:SetDuration(0.75); bScaleDown:SetScale(1/1.8, 1/1.8); bScaleDown:SetOrder(2)
    bgAnim:SetLooping("REPEAT")

    local bgPulseAnim = bgTex:CreateAnimationGroup()
    local bgFadeOut = bgPulseAnim:CreateAnimation("Alpha")
    bgFadeOut:SetFromAlpha(1.0)
    bgFadeOut:SetToAlpha(0.3)
    bgFadeOut:SetDuration(0.75)
    bgFadeOut:SetOrder(1)
    local bgFadeIn = bgPulseAnim:CreateAnimation("Alpha")
    bgFadeIn:SetFromAlpha(0.3)
    bgFadeIn:SetToAlpha(1.0)
    bgFadeIn:SetDuration(0.75)
    bgFadeIn:SetOrder(2)
    bgPulseAnim:SetLooping("REPEAT")

    bgFrame:Hide()

    local bgMask = bgFrame:CreateMaskTexture()
    bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bgMask:SetAllPoints(bgFrame)
    bgMask:Hide()
    local previewMaskActive = false

    local function Refresh()
        local icon     = reg:GetOverlaySetting(featureId, "icon")     or "VignetteEvent-SuperTracked"
        local position = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local scale    = reg:GetOverlaySetting(featureId, "scale")    or 1.0
        local alpha    = reg:GetOverlaySetting(featureId, "alpha")    or 1.0
        local baseSize = SLOT_SIZE * 0.54
        local finalSize = baseSize * scale

        overlayFrame:ClearAllPoints()
        local outerData = OuterPositionData[position]
        if outerData then
            overlayFrame:SetPoint("CENTER", slotFrame, outerData[1], outerData[2], outerData[3])
        else
            local offsets = PositionOffsets[position] or {0, 0}
            overlayFrame:SetPoint(position, slotFrame, position, offsets[1], offsets[2])
        end
        overlayFrame:SetSize(finalSize, finalSize)
        if icon == "BLANK" then
            overlayTex:SetTexture(nil)
            overlayTex:SetAtlas("")
            overlayTex:SetAlpha(0)
        else
            OneWoW.OverlayIcons:ApplyToTexture(overlayTex, icon)
            overlayTex:SetAlpha(alpha)
        end
        overlayFrame:Show()

        local effect = reg:GetOverlaySetting(featureId, "effect") or "none"
        iconAnim:Stop()
        if effect ~= "none" then
            local hasSpin = (effect == "spinning" or effect == "both")
            local hasZoom = (effect == "zooming" or effect == "both")
            iSpin1:SetDegrees(hasSpin and -360 or 0)
            iSpin2:SetDegrees(hasSpin and -360 or 0)
            iScaleUp:SetScale(hasZoom and 1.5 or 1, hasZoom and 1.5 or 1)
            iScaleDown:SetScale(hasZoom and (1/1.5) or 1, hasZoom and (1/1.5) or 1)
            iconAnim:Play()
        end

        local bgEnabled = reg:GetOverlaySetting(featureId, "bgEnabled")
        if bgEnabled then
            bgFrame:SetFrameLevel(overlayFrame:GetFrameLevel() - 1)

            local bgStyle = reg:GetOverlaySetting(featureId, "bgStyle") or "Solid-Circle"
            local bgScale = reg:GetOverlaySetting(featureId, "bgScale") or 1.0
            local bgColor = reg:GetOverlaySetting(featureId, "bgColor") or {1, 1, 1}
            if reg:GetOverlaySetting(featureId, "bgUseRarityColor") and PREVIEW_BG_RARITY_ITEM_LINK and C_Item and C_Item.GetItemInfo then
                local quality = select(3, C_Item.GetItemInfo(PREVIEW_BG_RARITY_ITEM_LINK))
                if quality then
                    local r, g, b = C_Item.GetItemQualityColor(quality)
                    bgColor = {r, g, b}
                end
            end

            local baseBgSize = finalSize * 1.6
            local finalBgSize = baseBgSize * bgScale
            bgFrame:SetSize(finalBgSize, finalBgSize)
            bgTex:ClearAllPoints()
            bgTex:SetAllPoints(bgFrame)
            bgTex:SetVertexColor(bgColor[1], bgColor[2], bgColor[3])

            local function applyCircleMask()
                if not previewMaskActive then
                    bgTex:AddMaskTexture(bgMask)
                    previewMaskActive = true
                end
                bgMask:Show()
            end

            local function removeCircleMask()
                if previewMaskActive then
                    bgTex:RemoveMaskTexture(bgMask)
                    previewMaskActive = false
                end
                bgMask:Hide()
            end

            if bgStyle == "Spinning Orbs" then
                removeCircleMask()
                bgTex:SetTexture(nil)
                bgTex:SetAtlas("ArtifactsFX-SpinningGlowys-Purple", false)
                bgPulseAnim:Stop()
                bgAnim:Play()
            elseif bgStyle == "Portal Spiral" then
                removeCircleMask()
                bgTex:SetTexture(nil)
                bgTex:SetAtlas("UI-Frame-jailerstower-Portrait-QualityEpic", false)
                bgPulseAnim:Stop()
                bgAnim:Play()
            elseif bgStyle == "Glow Pulse" then
                bgAnim:Stop()
                bgTex:SetAtlas("")
                bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
                applyCircleMask()
                bgPulseAnim:Play()
            else
                bgAnim:Stop()
                bgPulseAnim:Stop()
                bgTex:SetAtlas("")
                bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
                if bgStyle == "Solid-Circle" then
                    applyCircleMask()
                else
                    removeCircleMask()
                end
            end
            bgFrame:Show()
        else
            bgAnim:Stop()
            bgPulseAnim:Stop()
            bgFrame:Hide()
        end
    end

    Refresh()

    return container, Refresh
end

local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L["OVR_GENERAL_TITLE"])
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L["OVR_GENERAL_DESC"])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general") end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 20

    local noteLabel = OneWoW_GUI:CreateFS(dsc, 12)
    noteLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(3)
    noteLabel:SetText(L["OVR_GENERAL_NOTE"])
    noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 20

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 14

    local intHeader = OneWoW_GUI:CreateFS(dsc, 16)
    intHeader:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intHeader:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intHeader:SetJustifyH("LEFT")
    intHeader:SetText(L["OVR_INTEGRATIONS_HEADER"])
    intHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - intHeader:GetStringHeight() - 6

    local intDesc = OneWoW_GUI:CreateFS(dsc, 12)
    intDesc:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    intDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    intDesc:SetJustifyH("LEFT")
    intDesc:SetWordWrap(true)
    intDesc:SetSpacing(3)
    intDesc:SetText(L["OVR_INTEGRATIONS_DESC"])
    intDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - intDesc:GetStringHeight() - 10

    local integrationDefs = {
        { addonName = "ArkInventory",  displayName = "ArkInventory", dbKey = "arkinventory" },
        { addonName = "Baganator",     displayName = "Baganator",    dbKey = "baganator" },
        { addonName = "Bagnon",        displayName = "Bagnon",       notCompatible = true },
        { addonName = "BetterBags",    displayName = "BetterBags",   dbKey = "betterbags" },
        { addonName = "OneWoW_Bags",   displayName = "OneWoW Bags",  dbKey = "onewow_bags" },
        { addonName = "ElvUI",         displayName = "ElvUI",        dbKey = "elvui" },
    }

    for _, def in ipairs(integrationDefs) do
        local opts = {
            addonName         = def.addonName,
            displayName       = def.displayName,
            statusLabel       = L["FEATURE_STATUS_LABEL"],
            detectedText      = L["OVR_INT_DETECTED"],
            notDetectedText   = L["OVR_INT_NOT_DETECTED"],
            enabledText       = L["FEATURE_ENABLED"],
            disabledText      = L["FEATURE_DISABLED"],
            enableBtnText     = L["FEATURE_ENABLE_BTN"],
            disableBtnText    = L["FEATURE_DISABLE_BTN"],
            notCompatible     = def.notCompatible,
            notCompatibleText = L["OVR_INT_NOT_COMPATIBLE"],
        }

        if def.dbKey then
            opts.isEnabled = function()
                local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
                return not (db and db.integrations and db.integrations[def.dbKey] and db.integrations[def.dbKey].enabled == false)
            end
            opts.onToggle = function(newState)
                local db = OneWoW.db.global.settings.overlays
                db.integrations = db.integrations or {}
                db.integrations[def.dbKey] = db.integrations[def.dbKey] or {}
                db.integrations[def.dbKey].enabled = newState
                OneWoW.OverlayEngine:Refresh()
            end
        end

        local row = OneWoW_GUI:CreateIntegrationRow(dsc, opts)
        row:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
        row:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        yOffset = yOffset - 34
    end

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 14

    local resetAllBtn = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["OVR_RESET_ALL_DEFAULTS_BTN"], height = 26 })
    resetAllBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    resetAllBtn:SetScript("OnClick", function()
        local db = OneWoW.db.global.settings.overlays
        local generalEnabled = db.general and db.general.enabled
        local integrations = db.integrations
        wipe(db)
        db.integrations = integrations
        OneWoW:InitializeDatabase()
        if generalEnabled ~= nil then
            db.general.enabled = generalEnabled
        end
        OneWoW_GUI:ClearFrame(dsc)
        ShowGeneralDetail(split, dsc, selectedRow)
    end)
    yOffset = yOffset - 30 - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowOverlayDetail(split, feature, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local featureId = feature.id
    local reg       = OneWoW.SettingsFeatureRegistry

    if featureId == "general" then
        ShowGeneralDetail(split, dsc, selectedRow)
        return
    end

    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return reg:IsEnabled("overlays", featureId) end,
        onToggle = function(newState)
            reg:SetEnabled("overlays", featureId, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 20

    if featureId == "junk" or featureId == "protected" then
        local noteKey = (featureId == "junk") and "OVR_JUNK_NOTE" or "OVR_PROTECTED_NOTE"
        local markNote = OneWoW_GUI:CreateFS(dsc, 12)
        markNote:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
        markNote:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        markNote:SetJustifyH("LEFT")
        markNote:SetWordWrap(true)
        markNote:SetSpacing(3)
        markNote:SetText(L[noteKey])
        markNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - markNote:GetStringHeight() - 16
    end

    if featureId == "upgrade" then
        OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
        yOffset = yOffset - 14

        local modeHdr = OneWoW_GUI:CreateFS(dsc, 12)
        modeHdr:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        modeHdr:SetText(L["OVR_UPGRADE_MODE_LABEL"])
        modeHdr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        yOffset = yOffset - modeHdr:GetStringHeight() - 10

        local hasPawn = _G.PawnShouldItemLinkHaveUpgradeArrow ~= nil

        local pawnStatus = OneWoW_GUI:CreateFS(dsc, 12)
        pawnStatus:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        if hasPawn then
            pawnStatus:SetText(L["OVR_UPGRADE_PAWN_STATUS"] .. ": " .. L["OVR_UPGRADE_PAWN_DETECTED"])
            pawnStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            pawnStatus:SetText(L["OVR_UPGRADE_PAWN_STATUS"] .. ": " .. L["OVR_UPGRADE_PAWN_NOT_DETECTED"])
            pawnStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        yOffset = yOffset - pawnStatus:GetStringHeight() - 10

        local currentMode = reg:GetOverlaySetting(featureId, "mode") or "ILVL"
        if not hasPawn and (currentMode == "PAWN" or currentMode == "PAWN>ILVL") then
            currentMode = "ILVL"
            reg:SetOverlaySetting(featureId, "mode", "ILVL")
        end

        local MODES = {
            { value = "ILVL",     label = L["OVR_UPGRADE_MODE_ILVL"],      desc = L["OVR_UPGRADE_MODE_ILVL_DESC"] },
            { value = "PAWN",     label = L["OVR_UPGRADE_MODE_PAWN"],       desc = L["OVR_UPGRADE_MODE_PAWN_DESC"], needsPawn = true },
            { value = "PAWN>ILVL", label = L["OVR_UPGRADE_MODE_PAWN_ILVL"], desc = L["OVR_UPGRADE_MODE_PAWN_ILVL_DESC"], needsPawn = true },
        }

        local radioButtons = {}
        local refreshEnforcePawnState

        for _, modeInfo in ipairs(MODES) do
            local radio = CreateFrame("CheckButton", nil, dsc, "UIRadioButtonTemplate")
            radio:SetPoint("TOPLEFT", dsc, "TOPLEFT", 15, yOffset)
            radio:SetChecked(currentMode == modeInfo.value)

            local radioLabel = OneWoW_GUI:CreateFS(dsc, 12)
            radioLabel:SetPoint("LEFT", radio, "RIGHT", 5, 0)
            radioLabel:SetText(modeInfo.label)
            radioLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 20

            local radioDesc = OneWoW_GUI:CreateFS(dsc, 10)
            radioDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 40, yOffset)
            radioDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
            radioDesc:SetJustifyH("LEFT")
            radioDesc:SetWordWrap(true)
            radioDesc:SetText(modeInfo.desc)
            radioDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            yOffset = yOffset - radioDesc:GetStringHeight() - 10

            if modeInfo.needsPawn and not hasPawn then
                radio:Disable()
                radioLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                radioDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            radio:SetScript("OnClick", function()
                reg:SetOverlaySetting(featureId, "mode", modeInfo.value)
                for _, rb in ipairs(radioButtons) do
                    rb:SetChecked(false)
                end
                radio:SetChecked(true)
                if refreshEnforcePawnState then
                    refreshEnforcePawnState(modeInfo.value)
                end
                OneWoW.OverlayEngine:Refresh()
            end)

            radioButtons[#radioButtons + 1] = radio
        end

        if not hasPawn then
            local pawnNote = OneWoW_GUI:CreateFS(dsc, 10)
            pawnNote:SetPoint("TOPLEFT", dsc, "TOPLEFT", 15, yOffset)
            pawnNote:SetText(L["OVR_UPGRADE_PAWN_NOT_INSTALLED"])
            pawnNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            yOffset = yOffset - pawnNote:GetStringHeight() - 10
        end

        if hasPawn then
            local enforceCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_PAWN_ENFORCE_REQ_LEVEL"] })
            enforceCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
            enforceCb:SetChecked(reg:GetOverlaySetting(featureId, "pawnEnforceReqLevel") ~= false)
            enforceCb:SetScript("OnClick", function(self)
                reg:SetOverlaySetting(featureId, "pawnEnforceReqLevel", self:GetChecked())
                OneWoW.OverlayEngine:Refresh()
            end)
            enforceCb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["OVR_UPGRADE_PAWN_ENFORCE_REQ_LEVEL"], 1, 1, 1)
                GameTooltip:AddLine(L["OVR_UPGRADE_PAWN_ENFORCE_REQ_LEVEL_TOOLTIP"], nil, nil, nil, true)
                GameTooltip:Show()
            end)
            enforceCb:SetScript("OnLeave", function() GameTooltip:Hide() end)

            refreshEnforcePawnState = function(mode)
                local usesPawn = (mode == "PAWN") or (mode == "PAWN>ILVL")
                if usesPawn then
                    enforceCb:Enable()
                    enforceCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                else
                    enforceCb:Disable()
                    enforceCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
            end
            refreshEnforcePawnState(currentMode)
            yOffset = yOffset - 28
        end

        yOffset = yOffset - 6

        local DETAIL_LEVELS = {
            { value = "FULL",    text = L["OVR_TOOLTIP_DETAIL_FULL"] },
            { value = "SIMPLE",  text = L["OVR_TOOLTIP_DETAIL_SIMPLE"] },
            { value = "MINIMUM", text = L["OVR_TOOLTIP_DETAIL_MINIMUM"] },
        }
        local function GetDetailLabel(val)
            for _, d in ipairs(DETAIL_LEVELS) do
                if d.value == val then return d.text end
            end
            return val
        end

        -- Row 1: [Show in Tooltips checkbox]   [Detail dropdown]
        local tooltipCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_TOOLTIP_LABEL"] })
        tooltipCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        tooltipCb:SetChecked(reg:GetOverlaySetting(featureId, "showInTooltip") or false)

        local currentDetail = reg:GetOverlaySetting(featureId, "tooltipDetail") or "FULL"
        local detailDD, detailDDText = OneWoW_GUI:CreateDropdown(dsc, {
            width = 110,
            text = GetDetailLabel(currentDetail),
        })
        detailDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        OneWoW_GUI:AttachFilterMenu(detailDD, {
            searchable = false,
            buildItems = function() return DETAIL_LEVELS end,
            onSelect = function(value, text)
                detailDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "tooltipDetail", value)
            end,
            getActiveValue = function()
                return reg:GetOverlaySetting(featureId, "tooltipDetail") or "FULL"
            end,
        })
        yOffset = yOffset - 30

        -- Row 2: [Only show if upgrade] (indented sub-option)
        local onlyUpgradeCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_TOOLTIP_ONLY_UPGRADE"] })
        onlyUpgradeCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 30, yOffset)
        onlyUpgradeCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipOnlyUpgrade") or false)
        onlyUpgradeCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "tooltipOnlyUpgrade", self:GetChecked())
        end)
        yOffset = yOffset - 28

        -- Row 3: [Show skipped reason] (indented sub-option)
        local showSkipCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_TOOLTIP_SHOW_SKIP"] })
        showSkipCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 30, yOffset)
        showSkipCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipShowSkipReason") or false)
        showSkipCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "tooltipShowSkipReason", self:GetChecked())
        end)
        yOffset = yOffset - 28

        -- Row 4: [Show alt upgrades] (indented sub-option)
        local showAltsCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS"] })
        showAltsCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 30, yOffset)
        showAltsCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipShowAlts") ~= false)
        showAltsCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        showAltsCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        yOffset = yOffset - 28

        -- Row 5: [Match alts' current spec only] (double-indented under Show alt upgrades)
        local altSpecCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_UPGRADE_ALT_SPEC_MATCH"] })
        altSpecCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 48, yOffset)
        altSpecCb:SetChecked(reg:GetOverlaySetting(featureId, "altSpecMatch") or false)
        altSpecCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "altSpecMatch", self:GetChecked())
        end)
        altSpecCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_ALT_SPEC_MATCH"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_ALT_SPEC_MATCH_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        altSpecCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        yOffset = yOffset - 30 - 10

        local function setAltSpecEnabled(enabled)
            if enabled then
                altSpecCb:Enable()
                altSpecCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            else
                altSpecCb:Disable()
                altSpecCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end

        local function refreshTooltipSubs(enabled)
            if enabled then
                detailDD:Enable()
                detailDD._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                detailDD:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                onlyUpgradeCb:Enable()
                onlyUpgradeCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                showSkipCb:Enable()
                showSkipCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                showAltsCb:Enable()
                showAltsCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                setAltSpecEnabled(showAltsCb:GetChecked())
            else
                detailDD:Disable()
                detailDD._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                detailDD:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                onlyUpgradeCb:Disable()
                onlyUpgradeCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                showSkipCb:Disable()
                showSkipCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                showAltsCb:Disable()
                showAltsCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                setAltSpecEnabled(false)
            end
        end
        refreshTooltipSubs(reg:GetOverlaySetting(featureId, "showInTooltip") or false)

        showAltsCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "tooltipShowAlts", self:GetChecked())
            setAltSpecEnabled(self:GetChecked())
        end)

        tooltipCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showInTooltip", self:GetChecked())
            refreshTooltipSubs(self:GetChecked())
        end)
    end

    if not OVERLAY_SETTINGS_IDS[featureId] then
        dsc:SetHeight(math.abs(yOffset) + 20)
        split.UpdateDetailThumb()
        return
    end

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 14

    if featureId == "quest" then
        local questNote = OneWoW_GUI:CreateFS(dsc, 12)
        questNote:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
        questNote:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        questNote:SetJustifyH("LEFT")
        questNote:SetWordWrap(true)
        questNote:SetSpacing(3)
        questNote:SetText(L["OVR_QUEST_NOTE"])
        questNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - questNote:GetStringHeight() - 16

        local vendorCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_VENDOR_LABEL"] })
        vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") or false)
        vendorCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_AH_LABEL"] })
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

    local settingsHdr = OneWoW_GUI:CreateFS(dsc, 12)
    settingsHdr:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    settingsHdr:SetText(L["OVR_SETTINGS_HEADER"])
    settingsHdr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - settingsHdr:GetStringHeight() - 10

    if featureId == "itemlevel" then
        local rightY = yOffset

        local posLabel = OneWoW_GUI:CreateFS(dsc, 12)
        posLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        posLabel:SetText(L["OVR_POSITION_LABEL"])
        posLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - posLabel:GetStringHeight() - 6

        local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
        local posDD, posDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 160, text = currentPos })
        OneWoW_GUI:AttachFilterMenu(posDD, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(POSITIONS) do
                    table.insert(items, { text = opt, value = opt })
                end
                return items
            end,
            onSelect = function(value, text)
                posDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "position", value)
            end,
            getActiveValue = function() return reg:GetOverlaySetting(featureId, "position") end,
        })
        posDD:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 26 - 16

        local qualCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_QUALITY_COLORS_LABEL"] })
        qualCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        qualCb:SetChecked(reg:GetOverlaySetting(featureId, "useQualityColors") or false)
        qualCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "useQualityColors", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local vendorCb2 = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_VENDOR_LABEL"] })
        vendorCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        vendorCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToVendorItems") ~= false)
        vendorCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local ahCb2 = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_AH_LABEL"] })
        ahCb2:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        ahCb2:SetChecked(reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false)
        ahCb2:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local petLvlCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_ILVL_PET_LEVEL"] })
        petLvlCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        petLvlCb:SetChecked(reg:GetOverlaySetting(featureId, "showPetLevel") ~= false)
        petLvlCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showPetLevel", self:GetChecked())
        end)
        yOffset = yOffset - 30

        local containerSlotsCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_ILVL_CONTAINER_SLOTS"] })
        containerSlotsCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        containerSlotsCb:SetChecked(reg:GetOverlaySetting(featureId, "showContainerSlots") ~= false)
        containerSlotsCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showContainerSlots", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 16

        local fsLabel = OneWoW_GUI:CreateFS(dsc, 12)
        fsLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        fsLabel:SetText(L["OVR_FONTSIZE_LABEL"])
        fsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - fsLabel:GetStringHeight() - 6

        local currentFS = reg:GetOverlaySetting(featureId, "fontSize") or 10
        local fsSlider = OneWoW_GUI:CreateSlider(dsc, {
            minVal = 7, maxVal = 20, step = 1, currentVal = currentFS,
            onChange = function(val) reg:SetOverlaySetting(featureId, "fontSize", val) end,
            width = 240, fmt = "%d",
        })
        fsSlider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 36 - 10

        local LSM = LibStub("LibSharedMedia-3.0", true)
        local fontList = {}
        if LSM then
            fontList = LSM:List("font") or {}
        end
        table.sort(fontList)

        local fontLabel = OneWoW_GUI:CreateFS(dsc, 12)
        fontLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        fontLabel:SetText(L["OVR_FONT_LABEL"] or "Font")
        fontLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        rightY = rightY - fontLabel:GetStringHeight() - 6

        local currentFont = reg:GetOverlaySetting(featureId, "fontFamily") or "Friz Quadrata TF"
        local fontDD, fontDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 240, text = currentFont })
        OneWoW_GUI:AttachFilterMenu(fontDD, {
            searchable = true,
            buildItems = function()
                local items = {}
                for _, name in ipairs(fontList) do
                    table.insert(items, { text = name, value = name })
                end
                return items
            end,
            onSelect = function(value, text)
                fontDD._text:SetText(text)
                reg:SetOverlaySetting(featureId, "fontFamily", value)
                OneWoW.OverlayEngine:Refresh()
            end,
            getActiveValue = function() return reg:GetOverlaySetting(featureId, "fontFamily") end,
        })
        fontDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
        fontDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
        rightY = rightY - 26 - 16

        local outlineLabel = OneWoW_GUI:CreateFS(dsc, 12)
        outlineLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
        outlineLabel:SetText("Font Outline")
        outlineLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        rightY = rightY - outlineLabel:GetStringHeight() - 6

        local outlineOptions = {"None", "Outline", "Thick Outline"}
        local currentOutline = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
        local outlineDisplayMap = {[""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline"}
        local outlineValueMap = {["None"] = "", ["Outline"] = "OUTLINE", ["Thick Outline"] = "THICKOUTLINE"}
        local outlineDD, outlineDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 240, text = outlineDisplayMap[currentOutline] })
        OneWoW_GUI:AttachFilterMenu(outlineDD, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(outlineOptions) do
                    table.insert(items, { text = opt, value = opt })
                end
                return items
            end,
            onSelect = function(value, text)
                outlineDD._text:SetText(text)
                reg:SetOverlaySetting(featureId, "fontOutline", outlineValueMap[value])
                OneWoW.OverlayEngine:Refresh()
            end,
            getActiveValue = function()
                local cur = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
                return outlineDisplayMap[cur]
            end,
        })
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

    local previewName = OneWoW_GUI:CreateFS(dsc, 10)
    previewName:SetPoint("LEFT", previewFrame, "RIGHT", 6, 0)
    previewName:SetText(OneWoW.OverlayIcons:GetDisplayName(currentIcon))
    previewName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightY = rightY - 24 - 6

    previewContainer:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    rightY = rightY - previewContainer:GetHeight() - 10

    local posLabel = OneWoW_GUI:CreateFS(dsc, 12)
    posLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    posLabel:SetText(L["OVR_POSITION_LABEL"])
    posLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - posLabel:GetStringHeight() - 6

    local currentPos = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT"
    local posDropdown, posDropdownText = OneWoW_GUI:CreateDropdown(dsc, { width = 160, text = currentPos })
    OneWoW_GUI:AttachFilterMenu(posDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(POSITIONS) do
                table.insert(items, { text = opt, value = opt })
            end
            return items
        end,
        onSelect = function(value, text)
            posDropdownText:SetText(text)
            reg:SetOverlaySetting(featureId, "position", value)
            RefreshPreview()
        end,
        getActiveValue = function() return reg:GetOverlaySetting(featureId, "position") end,
    })
    posDropdown:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    posDropdown:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 26 - 10

    local scaleLabel = OneWoW_GUI:CreateFS(dsc, 12)
    scaleLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    scaleLabel:SetText(L["OVR_SCALE_LABEL"])
    scaleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - scaleLabel:GetStringHeight() - 6

    local currentScale = reg:GetOverlaySetting(featureId, "scale") or 1.0
    local scaleSlider  = OneWoW_GUI:CreateSlider(dsc, {
        minVal = 0.5, maxVal = 2.0, step = 0.1, currentVal = currentScale,
        onChange = function(val)
            reg:SetOverlaySetting(featureId, "scale", val)
            RefreshPreview()
        end,
        width = 160,
    })
    scaleSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    scaleSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 10

    local alphaLabel = OneWoW_GUI:CreateFS(dsc, 12)
    alphaLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    alphaLabel:SetText(L["OVR_ALPHA_LABEL"])
    alphaLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - alphaLabel:GetStringHeight() - 6

    local currentAlpha = reg:GetOverlaySetting(featureId, "alpha") or 1.0
    local alphaSlider  = OneWoW_GUI:CreateSlider(dsc, {
        minVal = 0.1, maxVal = 1.0, step = 0.1, currentVal = currentAlpha,
        onChange = function(val)
            reg:SetOverlaySetting(featureId, "alpha", val)
            RefreshPreview()
        end,
        width = 160,
    })
    alphaSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    alphaSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 10

    local effectLabel = OneWoW_GUI:CreateFS(dsc, 12)
    effectLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    effectLabel:SetText(L["OVR_EFFECT_LABEL"])
    effectLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - effectLabel:GetStringHeight() - 6

    local currentEffect = reg:GetOverlaySetting(featureId, "effect") or "none"
    local effectDD, effectDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 160, text = ICON_EFFECT_DISPLAY_MAP[currentEffect] or "None" })
    OneWoW_GUI:AttachFilterMenu(effectDD, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(ICON_EFFECT_OPTIONS) do
                table.insert(items, { text = opt, value = opt })
            end
            return items
        end,
        onSelect = function(value, text)
            effectDDText:SetText(text)
            reg:SetOverlaySetting(featureId, "effect", ICON_EFFECT_VALUE_MAP[value])
            RefreshPreview()
        end,
        getActiveValue = function()
            local cur = reg:GetOverlaySetting(featureId, "effect") or "none"
            return ICON_EFFECT_DISPLAY_MAP[cur] or "None"
        end,
    })
    effectDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    effectDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 26 - 16

    local bgDiv = dsc:CreateTexture(nil, "ARTWORK")
    bgDiv:SetHeight(1)
    bgDiv:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    bgDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    bgDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    rightY = rightY - 10

    local bgCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_BG_ENABLE_LABEL"] })
    bgCb:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    bgCb:SetChecked(reg:GetOverlaySetting(featureId, "bgEnabled") or false)
    bgCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "bgEnabled", self:GetChecked())
        RefreshPreview()
    end)
    rightY = rightY - 30

    local bgStyleLabel = OneWoW_GUI:CreateFS(dsc, 12)
    bgStyleLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    bgStyleLabel:SetText(L["OVR_BG_STYLE_LABEL"])
    bgStyleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - bgStyleLabel:GetStringHeight() - 6

    local currentBgStyle = reg:GetOverlaySetting(featureId, "bgStyle") or "Solid-Circle"
    local bgStyleDD, bgStyleDDText = OneWoW_GUI:CreateDropdown(dsc, { width = 180, text = currentBgStyle })
    OneWoW_GUI:AttachFilterMenu(bgStyleDD, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(BG_STYLE_OPTIONS) do
                table.insert(items, { text = opt, value = opt })
            end
            return items
        end,
        onSelect = function(value, text)
            bgStyleDDText:SetText(text)
            reg:SetOverlaySetting(featureId, "bgStyle", value)
            RefreshPreview()
        end,
        getActiveValue = function() return reg:GetOverlaySetting(featureId, "bgStyle") or "Solid-Circle" end,
    })
    bgStyleDD:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    bgStyleDD:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 26 - 10

    local bgScaleLabel = OneWoW_GUI:CreateFS(dsc, 12)
    bgScaleLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    bgScaleLabel:SetText(L["OVR_BG_SCALE_LABEL"])
    bgScaleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    rightY = rightY - bgScaleLabel:GetStringHeight() - 6

    local currentBgScale = reg:GetOverlaySetting(featureId, "bgScale") or 1.0
    local bgScaleSlider = OneWoW_GUI:CreateSlider(dsc, {
        minVal = 0.1, maxVal = 3.0, step = 0.1, currentVal = currentBgScale,
        onChange = function(val)
            reg:SetOverlaySetting(featureId, "bgScale", val)
            RefreshPreview()
        end,
        width = 160,
    })
    bgScaleSlider:SetPoint("TOPLEFT",  dsc, "TOP",      20,  rightY)
    bgScaleSlider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, rightY)
    rightY = rightY - 36 - 10

    local bgColorLabel = OneWoW_GUI:CreateFS(dsc, 12)
    bgColorLabel:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    bgColorLabel:SetText(L["OVR_BG_COLOR_LABEL"])
    bgColorLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bgSwatch = OneWoW_GUI:CreateColorSwatch(dsc, {
        getColor = function()
            local sc = reg:GetOverlaySetting(featureId, "bgColor") or {1, 1, 1}
            return sc[1], sc[2], sc[3]
        end,
        onColorChanged = function(r, g, b)
            reg:SetOverlaySetting(featureId, "bgColor", {r, g, b})
            RefreshPreview()
        end,
    })
    bgSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 8, 0)
    rightY = rightY - 28 - 10

    local bgRarityCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_BG_RARITY_LABEL"] })
    bgRarityCb:SetPoint("TOPLEFT", dsc, "TOP", 20, rightY)
    bgRarityCb:SetChecked(reg:GetOverlaySetting(featureId, "bgUseRarityColor") or false)
    bgRarityCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "bgUseRarityColor", self:GetChecked())
        RefreshPreview()
    end)
    rightY = rightY - 30 - 16

    local iconLabel = OneWoW_GUI:CreateFS(dsc, 12)
    iconLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    iconLabel:SetText(L["OVR_ICON_LABEL"])
    iconLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    local vendorCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_VENDOR_LABEL"] })
    vendorCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local vendorEnabled = reg:GetOverlaySetting(featureId, "applyToVendorItems") or false
    vendorCb:SetChecked(vendorEnabled)
    vendorCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToVendorItems", self:GetChecked())
    end)

    local vendorApplyAll = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["OVR_APPLY_TO_ALL_BTN"], height = 20 })
    vendorApplyAll:SetPoint("LEFT", vendorCb, "RIGHT", 160, 0)
    vendorApplyAll:SetScript("OnClick", function()
        local val = vendorCb:GetChecked()
        local db = OneWoW.db.global.settings.overlays
        for id in pairs(OVERLAY_SETTINGS_IDS) do
            if db[id] then
                db[id].applyToVendorItems = val
            end
        end
    end)
    yOffset = yOffset - 30

    local ahCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_AH_LABEL"] })
    ahCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    local ahEnabled = reg:GetOverlaySetting(featureId, "applyToAuctionHouse") or false
    ahCb:SetChecked(ahEnabled)
    ahCb:SetScript("OnClick", function(self)
        reg:SetOverlaySetting(featureId, "applyToAuctionHouse", self:GetChecked())
    end)

    local ahApplyAll = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["OVR_APPLY_TO_ALL_BTN"], height = 20 })
    ahApplyAll:SetPoint("LEFT", ahCb, "RIGHT", 160, 0)
    ahApplyAll:SetScript("OnClick", function()
        local val = ahCb:GetChecked()
        local db = OneWoW.db.global.settings.overlays
        for id in pairs(OVERLAY_SETTINGS_IDS) do
            if db[id] then
                db[id].applyToAuctionHouse = val
            end
        end
    end)
    yOffset = yOffset - 30 - 10

    yOffset = math.min(yOffset, rightY)

    if featureId == "junk" or featureId == "protected" then
        local tooltipCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_TOOLTIP_LABEL"] })
        tooltipCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        tooltipCb:SetChecked(reg:GetOverlaySetting(featureId, "showInTooltip") ~= false)
        tooltipCb:SetScript("OnClick", function(self)
            reg:SetOverlaySetting(featureId, "showInTooltip", self:GetChecked())
        end)
        yOffset = yOffset - 30 - 10

        if featureId == "junk" then
            local greyCb = OneWoW_GUI:CreateCheckbox(dsc, { label = L["OVR_JUNK_GREY_LABEL"] })
            greyCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
            greyCb:SetChecked(reg:GetOverlaySetting(featureId, "includeGreyItems") or false)
            greyCb:SetScript("OnClick", function(self)
                reg:SetOverlaySetting(featureId, "includeGreyItems", self:GetChecked())
            end)
            yOffset = yOffset - 30 - 10
        end
    end

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 14

    local resetBtn = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["OVR_RESET_DEFAULTS_BTN"], height = 26 })
    resetBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    resetBtn:SetScript("OnClick", function()
        local db = OneWoW.db.global.settings.overlays
        if db[featureId] then
            local wasEnabled = db[featureId].enabled
            db[featureId] = nil
            OneWoW:InitializeDatabase()
            db[featureId].enabled = wasEnabled
            ShowOverlayDetail(split, feature, selectedRow)
        end
    end)
    yOffset = yOffset - 30 - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local allRows = {}

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        allRows = {}
        local yOffset = -5
        local filter = (filterText or ""):lower()

        for _, feature in ipairs(features) do
            local displayName = L[feature.title] or feature.title
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local capturedFeature = feature
                local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)

                local row = OneWoW_GUI:CreateListRowBasic(lsc, {
                    height = 30,
                    label = displayName,
                    showDot = true,
                    dotEnabled = isEnabled,
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedRow = self
                        self:SetActive(true)
                        ShowOverlayDetail(split, capturedFeature, self)
                        if split.rightStatusText then
                            local fe = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", capturedFeature.id)
                            split.rightStatusText:SetText(displayName .. (fe and " (Enabled)" or " (Disabled)"))
                        end
                    end,
                })
                row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
                table.insert(allRows, row)
                yOffset = yOffset - 34
            end
        end

        lsc:SetHeight(math.abs(yOffset) + 10)
        if #allRows > 0 and not selectedRow then
            allRows[1]:Click()
        end
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetSearchText()
            RenderRows(text)
        end)
    end

    local enabledCount = 0
    for _, f in ipairs(features) do
        if OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", f.id) then
            enabledCount = enabledCount + 1
        end
    end
    split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
end

function GUI:CreateOverlaysTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true, searchPlaceholder = L["SEARCH_PLACEHOLDER"] or "Search..." })
    split.listTitle:SetText(L["OVERLAYS_LIST_TITLE"])
    split.detailTitle:SetText(L["OVERLAYS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "overlays")
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)
end
