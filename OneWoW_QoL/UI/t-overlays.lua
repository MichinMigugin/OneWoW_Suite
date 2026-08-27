local _, ns = ...

-- ============================================================================
-- QoL > Overlays — Overlay System 2.0 settings UI (card layout)
-- ============================================================================
-- Left list: General + built-ins (Item Level, Quality Border, Gear Upgrade)
-- + user overlays in priority order, each row with its icon thumbnail,
-- a drag handle for reordering, and enable dot, plus a pinned
-- "+ Add Overlay" row.
--
-- Detail pane: a hero block (live preview slots + name + enable toggle)
-- followed by collapsible full-width cards (Rule / Icon / Placement /
-- Background / Where It Shows / Manage). All painting in the preview goes
-- through the real 2.0 renderer so what you see is what you get.
-- ============================================================================

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local L = ns.L

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local BG_STYLE_OPTIONS = {
    "Solid-Circle", "Solid-Square", "Spinning Orbs", "Glow Pulse", "Portal Spiral",
    "PowerSwirlAnimation-YellowRing", "PowerSwirlAnimation-BlueRing",
    "PowerSwirlAnimation-StarBurst", "PowerSwirlAnimation-WhiteStarBurst",
    "PowerSwirlAnimation-SpinningGlowys",
    "ArtifactsFX-SpinningGlowys", "ArtifactsFX-StarBurst", "ArtifactsFX-YellowRing",
    "Artifacts-PerkRing-GoldMedal", "Artifacts-PerkRing-MainProc", "Artifacts-PerkRing-Small",
    "auctionhouse-itemicon-border-blue", "auctionhouse-itemicon-border-green",
    "auctionhouse-itemicon-border-purple", "auctionhouse-itemicon-border-gray",
    "auctionhouse-itemicon-border-orange", "auctionhouse-itemicon-border-white",
    "auctionhouse-itemicon-border-account", "auctionhouse-itemicon-border-artifact",
}

-- Item link used only for the preview's rarity-colored background (matches
-- engine: C_Item.GetItemQualityColor).
local PREVIEW_BG_RARITY_ITEM_LINK = "|cff0070dd|Hitem:19019::::::::60:::::::::|h[]|h|r"

local PREVIEW_SLOT_SIZE = 44
local PREVIEW_ICONS = {
    "Interface\\Icons\\INV_Chest_Plate06",
    "Interface\\Icons\\INV_Misc_Food_11",
}
local PREVIEW_QUALITIES = { Enum.ItemQuality.Epic, Enum.ItemQuality.Poor }

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
        nameKey = "OVR_ICON_CAT_SHAPES",
        icons   = {
            "WhiteCircle-RaidBlips", "Gamepad_Shp_Circle_64", "Gamepad_Shp_Square_64",
            "Gamepad_Shp_Triangle_64", "Gamepad_Shp_Cross_64", "Rare-Elite-Star",
            "UI-Achievement-Shield-2-Desaturated",
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
            "bags-icon-consumables", "bags-icon-equipment", "bags-icon-reagents",
            "bags-icon-tradegoods", "bags-icon-profession-goods", "bags-icon-scrappable",
            "lootroll-icon-transmog",
            "transmog-icon-tick", "transmog-icon-warning", "transmog-icon-disabled",
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
            "auctionhouse-itemicon-border-color", "auctionhouse-itemicon-border-blue",
            "auctionhouse-itemicon-border-green", "auctionhouse-itemicon-border-purple",
            "auctionhouse-itemicon-border-gray", "auctionhouse-itemicon-border-orange",
            "auctionhouse-itemicon-border-white", "auctionhouse-itemicon-border-account",
            "auctionhouse-itemicon-border-artifact",
            "Artifacts-ItemIconBorder", "Artifacts-PerkRing-GoldMedal",
            "Artifacts-PerkRing-MainProc", "Artifacts-PerkRing-Small",
            "Artifacts-PerkRing-Highlight", "ArtifactsFX-SpinningGlowys",
            "ArtifactsFX-StarBurst", "ArtifactsFX-YellowRing",
            "PowerSwirlAnimation-YellowRing", "PowerSwirlAnimation-BlueRing",
            "PowerSwirlAnimation-StarBurst", "PowerSwirlAnimation-WhiteStarBurst",
            "PowerSwirlAnimation-SpinningGlowys",
        },
    },
    {
        nameKey = "OVR_ICON_CAT_MISC",
        icons   = {
            "Battlenet-ClientIcon-WoW", "BfAMission-Icon-HUB",
            "BfAMission-Icon-Normal", "midnight-beta-access",
            "checkmark-minimal-disabled",
            "AnimCreate_Icon_Template", "AnimCreate_Icon_Texture",
            "AnimCreate_Icon_Add", "AnimCreate_Icon_Mask",
        },
    },
}

-- Card collapsed state, remembered per card key for the session.
local collapsedCards = {}

-- ----------------------------------------------------------------------------
-- Storage helpers
-- ----------------------------------------------------------------------------

local function Reg()
    return OneWoW.SettingsFeatureRegistry
end

local function GetUserOverlays()
    return Reg():GetFeatureSettings("overlays", "userOverlays")
end

--- Persist one userOverlays entry through the settings funnel (fires
--- listeners so the engine rebuilds + repaints).
local function SaveEntry(id, entry)
    Reg():SetSetting("overlays", "userOverlays", id, entry)
end

local function SetEntryField(id, entry, key, value)
    entry[key] = value
    SaveEntry(id, entry)
end

--- Ordered array of { id, entry } for the list panel.
local function GetOrderedEntries()
    local ordered = {}
    for id, entry in pairs(GetUserOverlays()) do
        if type(entry) == "table" then
            table.insert(ordered, { id = id, entry = entry })
        end
    end
    table.sort(ordered, function(a, b)
        local oa, ob = a.entry.order or 0, b.entry.order or 0
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)
    return ordered
end

local function EntryDisplayName(entry)
    local preset = entry.preset and OneWoW.Overlays2Defs:GetPreset(entry.preset)
    if preset then return L[preset.title] end
    if entry.name and entry.name ~= "" then return entry.name end
    return L["OVR_CUSTOM_DEFAULT_NAME"]
end

--- Move a user overlay to an arbitrary position: pull it out of the ordered
--- list and re-insert it before/after the target, then renumber and persist.
--- fromId/toId are userOverlays ids; insertBefore true = above target.
local function ReorderEntry(fromId, toId, insertBefore)
    if fromId == toId then return false end
    local ordered = GetOrderedEntries()

    local srcIdx
    for i, item in ipairs(ordered) do
        if item.id == fromId then srcIdx = i break end
    end
    if not srcIdx then return false end
    local src = table.remove(ordered, srcIdx)

    local tgtIdx
    for i, item in ipairs(ordered) do
        if item.id == toId then tgtIdx = i break end
    end
    if not tgtIdx then
        table.insert(ordered, srcIdx, src)
        return false
    end

    table.insert(ordered, insertBefore and tgtIdx or (tgtIdx + 1), src)

    for i, item in ipairs(ordered) do
        item.entry.order = i
        SaveEntry(item.id, item.entry)
    end
    return true
end

-- Forward declaration: list rebuild (assigned in BuildOverlayList).
local RefreshListRef

local function RefreshList(selectId)
    if RefreshListRef then RefreshListRef(selectId) end
end

-- ----------------------------------------------------------------------------
-- Card stack
-- ----------------------------------------------------------------------------

local function NewCardStack(split, dsc)
    local stack = OneWoW_GUI:CreateCardStack(dsc, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    stack.dsc = dsc
    stack.split = split
    stack.OnRelayout = function()
        split.UpdateDetailThumb()
    end
    return stack
end

-- ----------------------------------------------------------------------------
-- Hero block: preview slots + name + enable toggle
-- ----------------------------------------------------------------------------

local function CreatePreviewSlot(parent, iconPath, size)
    local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slot:SetSize(size or PREVIEW_SLOT_SIZE, size or PREVIEW_SLOT_SIZE)
    slot:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    slot:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    slot:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    local tex = slot:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    tex:SetTexture(iconPath)
    slot._iconTex = tex
    slot._defaultIcon = iconPath
    return slot
end

--- Hero block at the top of every detail: the selection title, an optional
--- description, and the enable toggle. Painting goes to the split's docked
--- side preview panel when present (the Overlays tab); otherwise two inline
--- preview slots render in the hero itself (the Tooltips > Gear Upgrades
--- mirror has no side panel).
--- opts: title, desc?, isEnabled fn?, onToggle fn(newState)?, selectedRow?,
---       paintSlot fn(slotFrame, quality)? (nil = bare slots)
--- Returns RefreshPreview.
local function AddHeroBlock(stack, opts)
    local dsc = stack.dsc
    local hero = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    hero:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    hero:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    hero:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    stack:AddFrame(hero)

    local Renderer = OneWoW.Overlays2Renderer
    local sidePreview = stack.split._overlayPreview

    local slots = {}
    local textLeft = 10
    if not sidePreview then
        for i = 1, 2 do
            local slot = CreatePreviewSlot(hero, PREVIEW_ICONS[i])
            slot:SetPoint("TOPLEFT", hero, "TOPLEFT", 10 + (i - 1) * (PREVIEW_SLOT_SIZE + 6), -10)
            slots[i] = slot
        end
        textLeft = 10 + 2 * (PREVIEW_SLOT_SIZE + 6) + 6
    end

    local title = OneWoW_GUI:CreateFS(hero, 15)
    title:SetPoint("TOPLEFT", hero, "TOPLEFT", textLeft, -12)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(opts.title or "")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local toggleBtn
    if opts.isEnabled then
        toggleBtn = OneWoW_GUI:CreateFeatureHeaderToggle(hero, {
            isEnabled = opts.isEnabled,
            onToggle = opts.onToggle,
            selectedRow = opts.selectedRow,
        })
        toggleBtn:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -10, -10)
        title:SetPoint("TOPRIGHT", toggleBtn, "TOPLEFT", -8, 0)
    else
        title:SetWidth(math.max(120, stack.contentWidth - textLeft - 20))
    end

    -- Header clearance (title/toggle), matching Toast/Tooltips spacing.
    -- Inline preview slots (no side panel) still set the floor when taller.
    local headerBottom = -12 - title:GetStringHeight()
    if toggleBtn then
        headerBottom = math.min(headerBottom, -10 - toggleBtn:GetHeight())
    end
    local bottomY = sidePreview and headerBottom or math.min(headerBottom, -(10 + PREVIEW_SLOT_SIZE))

    local desc
    if opts.desc then
        desc = OneWoW_GUI:CreateFS(hero, 11)
        desc:SetPoint("TOPLEFT", hero, "TOPLEFT", 10, bottomY - 8)
        desc:SetWidth(stack.contentWidth - 8)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetSpacing(2)
        desc:SetText(opts.desc)
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        bottomY = bottomY - 8 - desc:GetStringHeight()
    end

    hero:SetHeight(math.abs(bottomY) + 10)

    local function RefreshPreview()
        if sidePreview then
            sidePreview:SetPainter(opts.paintSlot)
            if sidePreview.SetTintAccessor then
                sidePreview:SetTintAccessor(opts.tintAccessor)
            end
            return
        end
        for i = 1, 2 do
            Renderer:CleanButton(slots[i])
            if opts.paintSlot then
                opts.paintSlot(slots[i], PREVIEW_QUALITIES[i])
                Renderer:ShowContainer(slots[i])
            end
        end
    end
    RefreshPreview()

    return RefreshPreview
end

-- ----------------------------------------------------------------------------
-- Docked side preview panel (always visible; does not scroll away)
-- ----------------------------------------------------------------------------

local SIDE_PREVIEW_WIDTH = 132

local function CreateSidePreviewPanel(split)
    local panel = CreateFrame("Frame", nil, split.detailPanel, "BackdropTemplate")
    panel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    panel:SetWidth(SIDE_PREVIEW_WIDTH)
    panel:SetPoint("TOPRIGHT", split.detailPanel, "TOPRIGHT", -8, -32)
    panel:SetPoint("BOTTOMRIGHT", split.detailPanel, "BOTTOMRIGHT", -8, 8)

    -- Make room: end the detail scroll area at the panel's left edge.
    local sf = split.detailScrollFrame
    local container = sf:GetParent()
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    sf:SetPoint("RIGHT", panel, "LEFT", -18, 0)

    -- The scrollbar was styled against the container's right edge (where the
    -- preview panel now sits); move it into the gap right of the scroll area.
    local sb = sf.ScrollBar
    if sb then
        sb:ClearAllPoints()
        sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
        sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
    end

    local heading = OneWoW_GUI:CreateFS(panel, 12)
    heading:SetPoint("TOP", panel, "TOP", 0, -10)
    heading:SetText(PREVIEW)
    heading:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    -- Large sample on top, normal bag-button size pair below (epic + poor).
    local big = CreatePreviewSlot(panel, PREVIEW_ICONS[1], 76)
    big:SetPoint("TOP", panel, "TOP", 0, -30)

    local smallLeft = CreatePreviewSlot(panel, PREVIEW_ICONS[1], 37)
    smallLeft:SetPoint("TOP", panel, "TOP", -21, -30 - 76 - 12)

    local smallRight = CreatePreviewSlot(panel, PREVIEW_ICONS[2], 37)
    smallRight:SetPoint("TOP", panel, "TOP", 21, -30 - 76 - 12)

    panel._slots = {
        { slot = big,        quality = PREVIEW_QUALITIES[1], role = "big" },
        { slot = smallLeft,  quality = PREVIEW_QUALITIES[1], role = "left" },
        { slot = smallRight, quality = PREVIEW_QUALITIES[2], role = "right" },
    }

    local Renderer = OneWoW.Overlays2Renderer

    local tintLabel = OneWoW_GUI:CreateFS(panel, 11)
    tintLabel:SetPoint("TOP", smallLeft, "BOTTOM", 21, -16)
    tintLabel:SetText(L["OVR_ICON_COLOR_LABEL"])
    tintLabel:SetJustifyH("CENTER")
    tintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local tintSwatch = OneWoW_GUI:CreateColorSwatch(panel, {
        getColor = function()
            local acc = panel._tintAccessor
            local tint = acc and acc.getTint and acc.getTint() or { 1, 1, 1 }
            return tint[1], tint[2], tint[3]
        end,
        onColorChanged = function(r, g, b)
            local acc = panel._tintAccessor
            if acc and acc.setTint then
                acc.setTint({ r, g, b })
            end
        end,
    })
    tintSwatch:SetPoint("TOP", tintLabel, "BOTTOM", 0, -6)

    local tintReset = OneWoW_GUI:CreateFitTextButton(panel, { text = RESET, height = 20 })
    tintReset:SetPoint("TOP", tintSwatch, "BOTTOM", 0, -6)
    tintReset:SetScript("OnClick", function()
        local acc = panel._tintAccessor
        if acc and acc.setTint then
            acc.setTint(nil)
        end
    end)

    -- Background color + rarity color live here too, shown only while the
    -- overlay has Add Background enabled (see SyncAppearance).
    local bgColorLabel = OneWoW_GUI:CreateFS(panel, 11)
    bgColorLabel:SetPoint("TOP", tintReset, "BOTTOM", 0, -14)
    bgColorLabel:SetText(L["OVR_BG_COLOR_LABEL"])
    bgColorLabel:SetJustifyH("CENTER")
    bgColorLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bgSwatch = OneWoW_GUI:CreateColorSwatch(panel, {
        getColor = function()
            local acc = panel._tintAccessor
            local c = acc and acc.bgGet and acc.bgGet("color") or { 1, 1, 1 }
            return c[1], c[2], c[3]
        end,
        onColorChanged = function(r, g, b)
            local acc = panel._tintAccessor
            if acc and acc.bgSet then
                acc.bgSet("color", { r, g, b })
            end
        end,
    })
    bgSwatch:SetPoint("TOP", bgColorLabel, "BOTTOM", 0, -6)

    -- Reset clears the color (nil) so no color is applied over the texture.
    local bgReset = OneWoW_GUI:CreateFitTextButton(panel, { text = RESET, height = 20 })
    bgReset:SetPoint("TOP", bgSwatch, "BOTTOM", 0, -6)
    bgReset:SetScript("OnClick", function()
        local acc = panel._tintAccessor
        if acc and acc.bgSet then
            acc.bgSet("color", nil)
        end
    end)

    -- Vendor / Auction House visibility status lights at the bottom. The panel
    -- is narrow, so labels are short, width-capped and wrap — this stays inside
    -- the box at any font size. Each status is its own bottom-anchored row.
    local STATUS_LABEL_W = SIDE_PREVIEW_WIDTH - 12 - 8 - 5 - 8

    local vendorDot = OneWoW_GUI:CreateStatusDot(panel, { enabled = false })
    vendorDot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10)
    local vendorLbl = OneWoW_GUI:CreateFS(panel, 10)
    vendorLbl:SetPoint("BOTTOMLEFT", vendorDot, "BOTTOMRIGHT", 5, -1)
    vendorLbl:SetWidth(STATUS_LABEL_W)
    vendorLbl:SetJustifyH("LEFT")
    vendorLbl:SetWordWrap(true)
    vendorLbl:SetText(L["OVR_PREVIEW_VENDORS"])
    vendorLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local ahDot = OneWoW_GUI:CreateStatusDot(panel, { enabled = false })
    ahDot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10 + 22)
    local ahLbl = OneWoW_GUI:CreateFS(panel, 10)
    ahLbl:SetPoint("BOTTOMLEFT", ahDot, "BOTTOMRIGHT", 5, -1)
    ahLbl:SetWidth(STATUS_LABEL_W)
    ahLbl:SetJustifyH("LEFT")
    ahLbl:SetWordWrap(true)
    ahLbl:SetText(L["OVR_PREVIEW_AH"])
    ahLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    function panel:Refresh()
        for _, entry in ipairs(self._slots) do
            Renderer:CleanButton(entry.slot)
            -- Restore the slot's default icon; role-aware painters (item level)
            -- may override it per refresh.
            if entry.slot._iconTex and entry.slot._defaultIcon then
                entry.slot._iconTex:SetTexture(entry.slot._defaultIcon)
            end
            if self._paint then
                self._paint(entry.slot, entry.quality, entry.role)
                Renderer:ShowContainer(entry.slot)
            end
        end
    end

    --- fn(slotFrame, quality) or nil for bare slots.
    function panel:SetPainter(fn)
        self._paint = fn
        self:Refresh()
    end

    --- Show/hide the background color controls based on the current overlay's
    --- Add Background state, and update vendor/AH status lights. Called on
    --- selection and on every preview refresh.
    function panel:SyncAppearance()
        local acc = self._tintAccessor
        -- Background color only applies to a plain color fill, not when
        -- rarity color overrides it.
        local bgOn = acc ~= nil and acc.bgGet ~= nil and acc.bgGet("enabled") == true
        local showColor = bgOn and acc.bgGet("useRarityColor") ~= true
        bgColorLabel:SetShown(showColor)
        bgSwatch:SetShown(showColor)
        bgReset:SetShown(showColor)

        local hasSurface = acc ~= nil and acc.get ~= nil
        vendorDot:SetShown(hasSurface)
        vendorLbl:SetShown(hasSurface)
        ahDot:SetShown(hasSurface)
        ahLbl:SetShown(hasSurface)
        if hasSurface then
            vendorDot:SetStatus(acc.get("applyToVendorItems") == true)
            ahDot:SetStatus(acc.get("applyToAuctionHouse") == true)
        end
    end

    function panel:SetTintAccessor(acc)
        self._tintAccessor = acc
        local shown = acc ~= nil and acc.getTint ~= nil
        tintLabel:SetShown(shown)
        tintSwatch:SetShown(shown)
        tintReset:SetShown(shown)
        self:SyncAppearance()
    end
    panel:SetTintAccessor(nil)

    split._overlayPreview = panel
    return panel
end

-- ----------------------------------------------------------------------------
-- Shared control helpers (inside card content)
-- ----------------------------------------------------------------------------

-- GetThemeColor returns r,g,b,a; capturing it into a single local collapses it
-- to r, which then breaks SetTextColor. Always apply it in one call.
local function ApplyThemeText(fs, key)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(key))
end

local function AddLabel(content, y, text, x)
    local lbl = OneWoW_GUI:CreateFS(content, 12)
    lbl:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    return lbl, y - lbl:GetStringHeight() - 5
end

-- width is REQUIRED (stack.contentWidth): wrapped text must be measured
-- against an explicit width because fresh parents have unresolved rects.
local function AddNote(content, y, text, width)
    local note = OneWoW_GUI:CreateFS(content, 11)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(text)
    note:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return y - note:GetStringHeight() - 10
end

local function AddCheckbox(content, y, label, checked, onClick, x)
    local cb = OneWoW_GUI:CreateCheckbox(content, { label = label })
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, y)
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(myself) onClick(myself:GetChecked()) end)
    return cb, y - 28
end

-- ----------------------------------------------------------------------------
-- Appearance accessors
-- ----------------------------------------------------------------------------
-- One card codebase drives both storage shapes:
--   * user overlays — 2.0 entry (icon spec table, bg table)
--   * gear upgrade  — flat 1.0-shape keys under overlays/upgrade

local function UserAccessor(id, entry, refreshPreview)
    local function IconSpec()
        if type(entry.icon) ~= "table" then
            entry.icon = { kind = "list", value = "VignetteEvent-SuperTracked" }
        end
        return entry.icon
    end
    local function BG()
        if type(entry.bg) ~= "table" then
            entry.bg = { enabled = false }
        end
        return entry.bg
    end
    return {
        supportsSources = true,
        get = function(key) return entry[key] end,
        set = function(key, value)
            entry[key] = value
            SaveEntry(id, entry)
            refreshPreview()
        end,
        getIconSpec = IconSpec,
        setIcon = function(kind, value)
            local spec = IconSpec()
            spec.kind = kind
            spec.value = value
            SaveEntry(id, entry)
            refreshPreview()
        end,
        getTint = function() return IconSpec().tint end,
        setTint = function(tint)
            IconSpec().tint = tint
            SaveEntry(id, entry)
            refreshPreview()
        end,
        bgGet = function(key)
            local bg = entry.bg
            return bg and bg[key]
        end,
        bgSet = function(key, value)
            BG()[key] = value
            SaveEntry(id, entry)
            refreshPreview()
        end,
        refreshPreview = refreshPreview,
    }
end

local UPGRADE_BG_KEYS = {
    enabled = "bgEnabled",
    style = "bgStyle",
    scale = "bgScale",
    color = "bgColor",
    useRarityColor = "bgUseRarityColor",
    effect = "bgEffect",
}

local function UpgradeAccessor(refreshPreview)
    local featureId = "upgrade"
    local reg = Reg()
    return {
        supportsSources = false,
        get = function(key) return reg:GetOverlaySetting(featureId, key) end,
        set = function(key, value)
            reg:SetOverlaySetting(featureId, key, value)
            refreshPreview()
        end,
        getIconSpec = function()
            return {
                kind = "list",
                value = reg:GetOverlaySetting(featureId, "icon") or "Professions-Icon-Quality-Tier3-Small",
                tint = reg:GetOverlaySetting(featureId, "iconColor"),
            }
        end,
        setIcon = function(_, value)
            reg:SetOverlaySetting(featureId, "icon", value)
            refreshPreview()
        end,
        getTint = function() return reg:GetOverlaySetting(featureId, "iconColor") end,
        setTint = function(tint)
            reg:SetOverlaySetting(featureId, "iconColor", tint)
            refreshPreview()
        end,
        bgGet = function(key) return reg:GetOverlaySetting(featureId, UPGRADE_BG_KEYS[key]) end,
        bgSet = function(key, value)
            reg:SetOverlaySetting(featureId, UPGRADE_BG_KEYS[key], value)
            refreshPreview()
        end,
        refreshPreview = refreshPreview,
    }
end

--- Renderer paint config from an accessor (drives the hero preview).
local function AccessorPaint(acc)
    return {
        iconSpec = acc.getIconSpec(),
        position = acc.get("position"),
        scale = acc.get("scale"),
        alpha = acc.get("alpha"),
        effect = acc.get("effect"),
        bg = acc.bgGet("enabled") and {
            enabled = true,
            style = acc.bgGet("style"),
            scale = acc.bgGet("scale"),
            color = acc.bgGet("color"),
            useRarityColor = acc.bgGet("useRarityColor"),
            effect = acc.bgGet("effect"),
        } or nil,
    }
end

-- ----------------------------------------------------------------------------
-- Card builders
-- ----------------------------------------------------------------------------

local function BuildIconCategoriesForGrid()
    local cats = {}
    for _, cat in ipairs(ICON_CATEGORIES) do
        table.insert(cats, { name = L[cat.nameKey], icons = cat.icons })
    end
    return cats
end

local function BuildIconTypeCard(content, acc, w, rebuild)
    local y = 0
    local spec = acc.getIconSpec()
    local currentKind = spec.kind or "list"

    local radioButtons = {}
    local TYPES = {
        { kind = "list",  label = L["OVR_ICON_TYPE_SYSTEM"] },
        { kind = "atlas", label = L["OVR_ICON_ATLAS_LABEL"] },
        { kind = "file",  label = L["OVR_ICON_FILE_LABEL"] },
    }

    for _, info in ipairs(TYPES) do
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        radio:SetChecked(currentKind == info.kind)

        local label = OneWoW_GUI:CreateFS(content, 12)
        label:SetPoint("LEFT", radio, "RIGHT", 5, 0)
        label:SetText(info.label)
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        radio:SetScript("OnClick", function()
            for _, rb in ipairs(radioButtons) do rb:SetChecked(false) end
            radio:SetChecked(true)
            local current = acc.getIconSpec()
            if current.kind == info.kind then return end
            local newValue
            if info.kind == "list" then
                newValue = (current.kind == "list" and current.value) or "VignetteEvent-SuperTracked"
            else
                -- Keep an existing atlas/file string only when staying the
                -- same kind; a system icon name is meaningless as an atlas/file.
                newValue = (current.kind == info.kind) and current.value or ""
            end
            acc.setIcon(info.kind, newValue)
            -- Rebuild so the matching source input (atlas / file) appears and
            -- the gallery enables only for the System type.
            if rebuild then rebuild() end
        end)

        radioButtons[#radioButtons + 1] = radio
        y = y - 24
    end

    local kind = acc.getIconSpec().kind or "list"
    if kind == "atlas" then
        y = y - 6
        y = select(2, AddLabel(content, y, L["OVR_ICON_ATLAS_LABEL"]))

        local err = OneWoW_GUI:CreateFS(content, 11)
        local box = OneWoW_GUI:CreateEditBox(content, {
            placeholderText = L["OVR_ICON_ATLAS_PLACEHOLDER"],
            height = 22,
        })
        box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        box:SetPoint("TOPRIGHT", content, "TOPRIGHT", -60, y)
        box:SetText(acc.getIconSpec().value or "")
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local function ApplyAtlas()
            local name = box:GetSearchText()
            if name == "" then return end
            if OneWoW.OverlayIcons:IsValidAtlas(name) then
                acc.setIcon("atlas", name)
                err:SetText("")
            else
                err:SetText(L["OVR_ICON_ATLAS_INVALID"])
                err:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
        end

        local useBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_ICON_USE_BTN"], height = 22 })
        useBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        useBtn:SetScript("OnClick", ApplyAtlas)
        box:SetScript("OnEnterPressed", function(myself)
            myself:ClearFocus()
            ApplyAtlas()
        end)
        y = y - 26

        err:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        err:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        err:SetJustifyH("LEFT")
        err:SetText("")
        y = y - 13
        y = AddNote(content, y, L["OVR_ICON_ATLAS_NOTE"], w)
    elseif kind == "file" then
        y = y - 6
        y = select(2, AddLabel(content, y, L["OVR_ICON_FILE_LABEL"]))

        local err = OneWoW_GUI:CreateFS(content, 11)
        local box = OneWoW_GUI:CreateEditBox(content, {
            placeholderText = L["OVR_ICON_FILE_PLACEHOLDER"],
            height = 22,
        })
        box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        box:SetPoint("TOPRIGHT", content, "TOPRIGHT", -60, y)
        box:SetText(acc.getIconSpec().value or "")
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local probeTex = content:CreateTexture(nil, "BACKGROUND")
        probeTex:SetSize(1, 1)
        probeTex:SetPoint("TOPLEFT", content, "TOPLEFT", -100, 0)
        probeTex:Hide()

        local function ApplyFile()
            local name = box:GetSearchText()
            if name == "" then return end
            if probeTex:SetTexture(OneWoW.OverlayIcons:GetCustomFilePath(name)) then
                acc.setIcon("file", name)
                err:SetText("")
            else
                err:SetText(L["OVR_ICON_FILE_INVALID"])
                err:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
            probeTex:SetTexture(nil)
        end

        local useBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_ICON_USE_BTN"], height = 22 })
        useBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        useBtn:SetScript("OnClick", ApplyFile)
        box:SetScript("OnEnterPressed", function(myself)
            myself:ClearFocus()
            ApplyFile()
        end)
        y = y - 26

        err:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        err:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        err:SetJustifyH("LEFT")
        err:SetText("")
        y = y - 13
        y = AddNote(content, y, L["OVR_ICON_FILE_NOTE"], w)
    end

    return math.abs(y)
end

local function BuildIconCard(content, acc, w)
    local y = 0
    local spec = acc.getIconSpec()

    local grid = OneWoW_GUI:CreateIconGrid(content, {
        categories = BuildIconCategoriesForGrid(),
        width = w,
        selected = spec.kind == "list" and spec.value or nil,
        applyIcon = function(tex, iconName)
            OneWoW.OverlayIcons:ApplyToTexture(tex, iconName)
        end,
        getDisplayName = function(iconName)
            return OneWoW.OverlayIcons:GetDisplayName(iconName)
        end,
        searchPlaceholder = L["SEARCH_HINT"],
        onSelect = function(iconName)
            acc.setIcon("list", iconName)
        end,
    })
    grid:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - grid:GetHeight() - 10

    return math.abs(y)
end

local function BuildPlacementCard(content, acc)
    local posGrid = OneWoW_GUI:CreatePositionGrid(content, {
        value = acc.get("position") or "TOPRIGHT",
        onChange = function(pos)
            acc.set("position", pos)
        end,
    })
    posGrid:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -14)

    local posLbl = OneWoW_GUI:CreateFS(content, 12)
    posLbl:SetPoint("BOTTOMLEFT", posGrid, "TOPLEFT", 0, 3)
    posLbl:SetText(L["OVR_POSITION_LABEL"])
    posLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local rightX = posGrid:GetWidth() + 24
    local y = 0

    local scaleLbl = OneWoW_GUI:CreateFS(content, 12)
    scaleLbl:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, y)
    scaleLbl:SetText(L["OVR_SCALE_LABEL"])
    scaleLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - scaleLbl:GetStringHeight() - 4

    local scaleSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 0.5, maxVal = 2.0, step = 0.1,
        currentVal = acc.get("scale") or 1.0,
        onChange = function(val) acc.set("scale", val) end,
        width = 160,
    })
    scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, y)
    scaleSlider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
    y = y - 34

    local alphaLbl = OneWoW_GUI:CreateFS(content, 12)
    alphaLbl:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, y)
    alphaLbl:SetText(L["OVR_ALPHA_LABEL"])
    alphaLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - alphaLbl:GetStringHeight() - 4

    local alphaSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 0.1, maxVal = 1.0, step = 0.1,
        currentVal = acc.get("alpha") or 1.0,
        onChange = function(val) acc.set("alpha", val) end,
        width = 160,
    })
    alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, y)
    alphaSlider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
    y = y - 34

    return math.max(math.abs(y), 14 + posGrid:GetHeight() + 4)
end

-- Effect picker as radio rows (no dropdown) — its own card between Placement
-- and Background. Icon effect uses entry.effect; background effect uses
-- entry.bg.effect (or overlays/upgrade.bgEffect). Values stay stable
-- (none/spinning/zooming/both); only the labels are localized.
local EFFECT_CHOICES = {
    { value = "none",     labelKey = "OVR_EFFECT_NONE" },
    { value = "spinning", labelKey = "OVR_EFFECT_SPINNING" },
    { value = "zooming",  labelKey = "OVR_EFFECT_ZOOMING" },
    { value = "both",     labelKey = "OVR_EFFECT_BOTH" },
}

local function AddEffectRadioColumn(content, x, yStart, current, radios, onSelect)
    local y = yStart
    for _, choice in ipairs(EFFECT_CHOICES) do
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        radio:SetChecked(current == choice.value)

        local label = OneWoW_GUI:CreateFS(content, 12)
        label:SetPoint("LEFT", radio, "RIGHT", 5, 0)
        label:SetText(L[choice.labelKey])
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        radio:SetScript("OnClick", function()
            for _, rb in ipairs(radios) do rb:SetChecked(false) end
            radio:SetChecked(true)
            onSelect(choice.value)
        end)

        radios[#radios + 1] = radio
        y = y - 24
    end
    return y
end

local function BuildEffectCard(content, acc, w)
    local colGap = math.floor((w or 280) / 2)
    local y = 0

    local iconHdr = OneWoW_GUI:CreateFS(content, 12)
    iconHdr:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
    iconHdr:SetText(L["OVR_ICON_LABEL"])
    iconHdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bgHdr = OneWoW_GUI:CreateFS(content, 12)
    bgHdr:SetPoint("TOPLEFT", content, "TOPLEFT", colGap, y)
    bgHdr:SetText(L["OVR_CARD_BACKGROUND"])
    bgHdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    y = y - 20

    local iconRadios = {}
    local bgRadios = {}
    local iconEnd = AddEffectRadioColumn(content, 2, y, acc.get("effect") or "none", iconRadios, function(value)
        acc.set("effect", value)
    end)
    local bgEnd = AddEffectRadioColumn(content, colGap, y, acc.bgGet("effect") or "none", bgRadios, function(value)
        acc.bgSet("effect", value)
    end)

    return math.max(math.abs(iconEnd), math.abs(bgEnd))
end

-- Paint one background-style preview swatch. Named styles (solid shapes,
-- glow pulse) draw a representative white texture; atlas styles draw the atlas.
local function ApplyBackgroundPreview(tex, style)
    tex:SetVertexColor(1, 1, 1)
    if C_Texture.GetAtlasInfo(style) then
        tex:SetTexture(nil)
        tex:SetAtlas(style, false)
    else
        tex:SetAtlas("")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        if style == "Solid-Circle" or style == "Glow Pulse" then
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function BuildBackgroundCard(content, acc, w)
    local y = 0

    local _, cbY = AddCheckbox(content, y, L["OVR_BG_ENABLE_LABEL"], acc.bgGet("enabled") == true, function(checked)
        acc.bgSet("enabled", checked)
    end)
    y = cbY - 4

    -- Same gallery presentation as the icon picker so styles are visible
    -- rather than hidden behind an opaque dropdown. Color and rarity color
    -- live on the side preview panel (shown when Add Background is on).
    y = select(2, AddLabel(content, y, L["OVR_BG_STYLE_LABEL"]))
    local grid = OneWoW_GUI:CreateIconGrid(content, {
        categories = { { name = L["OVR_BG_STYLE_LABEL"], icons = BG_STYLE_OPTIONS } },
        width = w,
        selected = acc.bgGet("style") or "Solid-Circle",
        applyIcon = ApplyBackgroundPreview,
        getDisplayName = function(style)
            return OneWoW.OverlayIcons:GetDisplayName(style)
        end,
        searchPlaceholder = L["SEARCH_HINT"],
        onSelect = function(style)
            acc.bgSet("style", style)
        end,
    })
    grid:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - grid:GetHeight() - 10

    y = select(2, AddLabel(content, y, L["OVR_BG_SCALE_LABEL"]))
    local bgScaleSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 0.1, maxVal = 3.0, step = 0.1,
        currentVal = acc.bgGet("scale") or 1.0,
        onChange = function(val) acc.bgSet("scale", val) end,
        width = 200,
    })
    bgScaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 36

    -- Rarity color overrides the picked background color; when on, the color
    -- swatch on the preview panel is hidden.
    local _, rarityY = AddCheckbox(content, y, L["OVR_BG_RARITY_LABEL"], acc.bgGet("useRarityColor") == true, function(checked)
        acc.bgSet("useRarityColor", checked)
    end)
    y = rarityY

    y = AddNote(content, y, L["OVR_BG_COLOR_SIDE_NOTE"], w)

    return math.abs(y)
end

--- Vendor + Auction House visibility toggles. getFn/setFn take (key) /
--- (key, value) with keys applyToVendorItems / applyToAuctionHouse.
local function BuildSurfacesCard(content, getFn, setFn)
    local y = 0
    local _, y1 = AddCheckbox(content, y, L["OVR_VENDOR_LABEL"], getFn("applyToVendorItems") == true, function(checked)
        setFn("applyToVendorItems", checked)
    end)
    local _, y2 = AddCheckbox(content, y1, L["OVR_AH_LABEL"], getFn("applyToAuctionHouse") == true, function(checked)
        setFn("applyToAuctionHouse", checked)
    end)
    return math.abs(y2)
end

-- ----------------------------------------------------------------------------
-- General detail
-- ----------------------------------------------------------------------------

local function ShowGeneralDetail(split, dsc, selectedRow)
    local stack = NewCardStack(split, dsc)

    AddHeroBlock(stack, {
        title = L["OVR_GENERAL_TITLE"],
        desc = L["OVR_GENERAL_DESC"] .. " " .. L["OVR_GENERAL_NOTE"],
        isEnabled = function() return Reg():IsEnabled("overlays", "general") end,
        onToggle = function(newState) Reg():SetEnabled("overlays", "general", newState) end,
        selectedRow = selectedRow,
    })

    stack:AddCard("general-overlays", L["OVERLAYS_LIST_TITLE"], function(content, w)
        local y = 0
        local addBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_ADD_OVERLAY_BTN"], height = 26 })
        addBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        addBtn:SetScript("OnClick", function()
            ns.UI.ShowAddOverlayDialog()
        end)
        y = y - 32
        y = AddNote(content, y, L["OVR_MAX_OVERLAYS_NOTE"], w)
        return math.abs(y)
    end)

    local integrationDefs = {
        { addonName = "ArkInventory",  displayName = "ArkInventory", dbKey = "arkinventory" },
        { addonName = "Baganator",     displayName = "Baganator",    dbKey = "baganator" },
        { addonName = "Bagnon",        displayName = "Bagnon",       notCompatible = true },
        { addonName = "BetterBags",    displayName = "BetterBags",   dbKey = "betterbags" },
        { addonName = "OneWoW_Bags",   displayName = "OneWoW Bags",  dbKey = "onewow_bags" },
        { addonName = "ElvUI",         displayName = "ElvUI",        dbKey = "elvui" },
    }

    stack:AddCard("general-integrations", L["OVR_INTEGRATIONS_HEADER"], function(content, w)
        local y = AddNote(content, 0, L["OVR_INTEGRATIONS_DESC"], w)
        for _, def in ipairs(integrationDefs) do
            local opts = {
                addonName         = def.addonName,
                displayName       = def.displayName,
                detectedText      = L["OVR_INT_DETECTED"],
                notDetectedText   = L["OVR_INT_NOT_DETECTED"],
                enabledText       = L["FEATURE_ENABLED"],
                disabledText      = L["FEATURE_DISABLED"],
                notCompatible     = def.notCompatible,
                notCompatibleText = L["OVR_INT_NOT_COMPATIBLE"],
            }
            if def.dbKey then
                opts.isEnabled = function()
                    return Reg():IsIntegrationEnabled(def.dbKey)
                end
                opts.onToggle = function(newState)
                    Reg():SetIntegrationEnabled(def.dbKey, newState)
                end
            end
            local row = OneWoW_GUI:CreateIntegrationRow(content, opts)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            y = y - 34
        end
        return math.abs(y)
    end)

    stack:AddCard("general-manage", L["OVR_CARD_MANAGE"], function(content)
        local resetAllBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_RESET_ALL_DEFAULTS_BTN"], height = 26 })
        resetAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        resetAllBtn:SetScript("OnClick", function()
            local dialog = OneWoW_GUI:CreateConfirmDialog({
                name    = "OneWoW_OverlayResetAllConfirm",
                title   = L["OVR_RESET_ALL_DEFAULTS_BTN"],
                message = L["OVR_RESET_ALL_CONFIRM_MSG"],
                buttons = {
                    { text = L["OVR_RESET_ALL_DEFAULTS_BTN"], color = { 0.6, 0.2, 0.2 }, onClick = function(d)
                        d:Hide()
                        local reg = Reg()
                        -- Preserve the master switch and integration states.
                        local generalEnabled = reg:IsEnabled("overlays", "general")
                        local integrationStates = {}
                        for _, def in ipairs(integrationDefs) do
                            if def.dbKey then
                                integrationStates[def.dbKey] = reg:IsIntegrationEnabled(def.dbKey)
                            end
                        end
                        reg:ResetTab("overlays")
                        reg:SetEnabled("overlays", "general", generalEnabled)
                        for key, value in pairs(integrationStates) do
                            reg:SetIntegrationEnabled(key, value)
                        end
                        RefreshList("general")
                    end },
                    { text = CANCEL, onClick = function(d) d:Hide() end },
                },
            })
            dialog.frame:Show()
        end)
        return 28
    end)

    stack:Finish()
end

-- ----------------------------------------------------------------------------
-- Item Level detail
-- ----------------------------------------------------------------------------

local function ShowItemLevelDetail(split, dsc, selectedRow)
    local featureId = "itemlevel"
    local reg = Reg()
    local stack = NewCardStack(split, dsc)
    local Renderer = OneWoW.Overlays2Renderer

    local RefreshPreview = AddHeroBlock(stack, {
        title = L["OVR_ITEMLEVEL_TITLE"],
        desc = L["OVR_ITEMLEVEL_DESC"],
        isEnabled = function() return reg:IsEnabled("overlays", featureId) end,
        onToggle = function(newState) reg:SetEnabled("overlays", featureId, newState) end,
        selectedRow = selectedRow,
        paintSlot = function(slot, _, role)
            local cfg = reg:GetFeatureSettings("overlays", featureId)
            -- big = equipment ilvl; left = pet level (if enabled);
            -- right = bag container size (if enabled). Lets the user see each
            -- number type on its own sample icon.
            if role == "left" then
                if cfg.showPetLevel == false then return end
                if slot._iconTex then slot._iconTex:SetTexture("Interface\\Icons\\INV_Box_PetCarrier_01") end
                Renderer:ApplyItemLevel(slot, cfg, "25", Enum.ItemQuality.Rare)
            elseif role == "right" then
                if cfg.showContainerSlots == false then return end
                if slot._iconTex then slot._iconTex:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue") end
                Renderer:ApplyItemLevel(slot, cfg, "32", Enum.ItemQuality.Uncommon)
            else
                Renderer:ApplyItemLevel(slot, cfg, "528", Enum.ItemQuality.Epic)
            end
        end,
    })

    stack:AddCard("ilvl-text", L["OVR_CARD_TEXTSTYLE"], function(content)
        local y = 0
        y = select(2, AddLabel(content, y, L["OVR_ILVL_COLOR_LABEL"]))

        local COLOR_MODES = {
            { value = "custom",  label = L["OVR_ILVL_COLOR_CUSTOM"] },
            { value = "quality", label = L["OVR_ILVL_COLOR_QUALITY"] },
            { value = "theme",   label = L["OVR_ILVL_COLOR_THEME"] },
        }
        local currentMode = reg:GetOverlaySetting(featureId, "colorMode") or "custom"
        local radios = {}

        for _, modeInfo in ipairs(COLOR_MODES) do
            local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
            radio:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            radio:SetChecked(currentMode == modeInfo.value)

            local radioLabel = OneWoW_GUI:CreateFS(content, 12)
            radioLabel:SetPoint("LEFT", radio, "RIGHT", 5, 0)
            radioLabel:SetText(modeInfo.label)
            radioLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            if modeInfo.value == "custom" then
                local swatch = OneWoW_GUI:CreateColorSwatch(content, {
                    getColor = function()
                        local c = reg:GetOverlaySetting(featureId, "customColor") or { 1, 1, 1 }
                        return c[1], c[2], c[3]
                    end,
                    onColorChanged = function(r, g, b)
                        reg:SetOverlaySetting(featureId, "customColor", { r, g, b })
                        RefreshPreview()
                    end,
                })
                swatch:SetPoint("LEFT", radioLabel, "RIGHT", 10, 0)
            end

            radio:SetScript("OnClick", function()
                reg:SetOverlaySetting(featureId, "colorMode", modeInfo.value)
                for _, rb in ipairs(radios) do rb:SetChecked(false) end
                radio:SetChecked(true)
                RefreshPreview()
            end)
            radios[#radios + 1] = radio
            y = y - 24
        end
        y = y - 8

        y = select(2, AddLabel(content, y, L["OVR_FONTSIZE_LABEL"]))
        local fsSlider = OneWoW_GUI:CreateSlider(content, {
            minVal = 7, maxVal = 20, step = 1,
            currentVal = reg:GetOverlaySetting(featureId, "fontSize") or 10,
            onChange = function(val)
                reg:SetOverlaySetting(featureId, "fontSize", val)
                RefreshPreview()
            end,
            width = 220, fmt = "%d",
        })
        fsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 38

        y = select(2, AddLabel(content, y, L["OVR_FONT_LABEL"]))
        local fontList = OneWoW_GUI:GetFontList()
        local function ResolveOverlayFontKey()
            local raw = reg:GetOverlaySetting(featureId, "fontFamily")
            return OneWoW_GUI:MigrateLSMFontName(raw) or raw or "default"
        end
        local currentInfo = OneWoW_GUI:GetFontInfoByKey(ResolveOverlayFontKey())
        local fontDD = OneWoW_GUI:CreateDropdown(content, {
            width = 240,
            text = currentInfo and currentInfo.label or "WoW Default",
        })
        OneWoW_GUI:AttachFilterMenu(fontDD, {
            searchable = true,
            buildItems = function()
                local items = {}
                for _, entry in ipairs(fontList) do
                    table.insert(items, {
                        text = entry.label,
                        value = entry.key,
                        fontPath = entry.file,
                        fontSize = 13,
                    })
                end
                return items
            end,
            onSelect = function(value, text)
                fontDD._text:SetText(text)
                reg:SetOverlaySetting(featureId, "fontFamily", value)
                RefreshPreview()
            end,
            getActiveValue = ResolveOverlayFontKey,
        })
        fontDD:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 30

        y = select(2, AddLabel(content, y, L["OVR_FONT_OUTLINE_LABEL"]))
        local outlineOptions = { "None", "Outline", "Thick Outline" }
        local outlineDisplayMap = { [""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" }
        local outlineValueMap = { ["None"] = "", ["Outline"] = "OUTLINE", ["Thick Outline"] = "THICKOUTLINE" }
        local currentOutline = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
        local outlineDD = OneWoW_GUI:CreateDropdown(content, { width = 240, text = outlineDisplayMap[currentOutline] })
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
                RefreshPreview()
            end,
            getActiveValue = function()
                local cur = reg:GetOverlaySetting(featureId, "fontOutline") or "OUTLINE"
                return outlineDisplayMap[cur]
            end,
        })
        outlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 26

        return math.abs(y)
    end)

    stack:AddCard("ilvl-placement", L["OVR_CARD_PLACEMENT"], function(content)
        local posGrid = OneWoW_GUI:CreatePositionGrid(content, {
            value = reg:GetOverlaySetting(featureId, "position") or "TOPRIGHT",
            onChange = function(pos)
                reg:SetOverlaySetting(featureId, "position", pos)
                RefreshPreview()
            end,
        })
        posGrid:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        return posGrid:GetHeight()
    end)

    stack:AddCard("ilvl-surfaces", L["OVR_CARD_SURFACES"], function(content)
        local y = 0
        local _
        _, y = AddCheckbox(content, y, L["OVR_VENDOR_LABEL"],
            reg:GetOverlaySetting(featureId, "applyToVendorItems") ~= false, function(checked)
                reg:SetOverlaySetting(featureId, "applyToVendorItems", checked)
            end)
        _, y = AddCheckbox(content, y, L["OVR_AH_LABEL"],
            reg:GetOverlaySetting(featureId, "applyToAuctionHouse") == true, function(checked)
                reg:SetOverlaySetting(featureId, "applyToAuctionHouse", checked)
            end)
        _, y = AddCheckbox(content, y, L["OVR_ILVL_PET_LEVEL"],
            reg:GetOverlaySetting(featureId, "showPetLevel") ~= false, function(checked)
                reg:SetOverlaySetting(featureId, "showPetLevel", checked)
                RefreshPreview()
            end)
        _, y = AddCheckbox(content, y, L["OVR_ILVL_CONTAINER_SLOTS"],
            reg:GetOverlaySetting(featureId, "showContainerSlots") ~= false, function(checked)
                reg:SetOverlaySetting(featureId, "showContainerSlots", checked)
                RefreshPreview()
            end)
        return math.abs(y)
    end)

    stack:Finish()
end

-- ----------------------------------------------------------------------------
-- Quality Border detail
-- ----------------------------------------------------------------------------

local function ShowQualityBorderDetail(split, dsc, selectedRow)
    local featureId = "qualityborder"
    local reg = Reg()
    local stack = NewCardStack(split, dsc)
    local Renderer = OneWoW.Overlays2Renderer

    local RefreshPreview = AddHeroBlock(stack, {
        title = L["OVR_QUALITYBORDER_TITLE"],
        desc = L["OVR_QUALITYBORDER_DESC"],
        isEnabled = function() return reg:IsEnabled("overlays", featureId) end,
        onToggle = function(newState) reg:SetEnabled("overlays", featureId, newState) end,
        selectedRow = selectedRow,
        paintSlot = function(slot, quality)
            local cfg = reg:GetFeatureSettings("overlays", featureId)
            Renderer:ApplyQualityBorder(slot, cfg, quality)
        end,
    })

    stack:AddCard("qb-style", L["OVR_CARD_STYLE"], function(content)
        local y = 0
        -- OneWoW clean border only (no style choice). Scale controls border
        -- thickness; alpha controls opacity.
        y = select(2, AddLabel(content, y, L["OVR_SCALE_LABEL"]))
        local scaleSlider = OneWoW_GUI:CreateSlider(content, {
            minVal = 1, maxVal = 6, step = 1,
            currentVal = reg:GetOverlaySetting(featureId, "scale") or 2,
            onChange = function(val)
                reg:SetOverlaySetting(featureId, "scale", val)
                RefreshPreview()
            end,
            width = 220, fmt = "%d",
        })
        scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 38

        y = select(2, AddLabel(content, y, L["OVR_ALPHA_LABEL"]))
        local alphaSlider = OneWoW_GUI:CreateSlider(content, {
            minVal = 0.1, maxVal = 1.0, step = 0.1,
            currentVal = reg:GetOverlaySetting(featureId, "alpha") or 1.0,
            onChange = function(val)
                reg:SetOverlaySetting(featureId, "alpha", val)
                RefreshPreview()
            end,
            width = 220,
        })
        alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - 38
        return math.abs(y)
    end)

    stack:AddCard("qb-surfaces", L["OVR_CARD_SURFACES"], function(content, w)
        local y = AddNote(content, 0, L["OVR_QUALITYBORDER_BAGS_NOTE"], w)
        local _, y1 = AddCheckbox(content, y, L["OVR_VENDOR_LABEL"],
            reg:GetOverlaySetting(featureId, "applyToVendorItems") == true, function(checked)
                reg:SetOverlaySetting(featureId, "applyToVendorItems", checked)
            end)
        local _, y2 = AddCheckbox(content, y1, L["OVR_AH_LABEL"],
            reg:GetOverlaySetting(featureId, "applyToAuctionHouse") == true, function(checked)
                reg:SetOverlaySetting(featureId, "applyToAuctionHouse", checked)
            end)
        return math.abs(y2)
    end)

    stack:Finish()
end

-- ----------------------------------------------------------------------------
-- Gear Upgrade detail (detector-backed built-in; flat 1.0-shape storage)
-- ----------------------------------------------------------------------------

local function ShowUpgradeDetail(split, feature, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local featureId = "upgrade"
    local reg = Reg()
    local stack = NewCardStack(split, dsc)
    local Renderer = OneWoW.Overlays2Renderer

    local refreshPreviewRef
    local acc = UpgradeAccessor(function()
        if refreshPreviewRef then refreshPreviewRef() end
    end)

    refreshPreviewRef = AddHeroBlock(stack, {
        title = L[feature.title],
        desc = L[feature.description],
        isEnabled = function() return reg:IsEnabled("overlays", featureId) end,
        onToggle = function(newState) reg:SetEnabled("overlays", featureId, newState) end,
        selectedRow = selectedRow,
        tintAccessor = acc,
        paintSlot = function(slot)
            Renderer:ApplyOverlay(slot, AccessorPaint(acc), 1, PREVIEW_BG_RARITY_ITEM_LINK)
        end,
    })

    stack:AddCard("upgrade-detection", L["OVR_UPGRADE_MODE_LABEL"], function(content)
        local y = 0
        local hasPawn = rawget(_G, "PawnShouldItemLinkHaveUpgradeArrow") ~= nil

        local pawnStatus = OneWoW_GUI:CreateFS(content, 12)
        pawnStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        if hasPawn then
            pawnStatus:SetText(L["OVR_UPGRADE_PAWN_STATUS"] .. ": " .. L["OVR_UPGRADE_PAWN_DETECTED"])
            pawnStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            pawnStatus:SetText(L["OVR_UPGRADE_PAWN_STATUS"] .. ": " .. L["OVR_UPGRADE_PAWN_NOT_DETECTED"])
            pawnStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        y = y - pawnStatus:GetStringHeight() - 10

        local currentMode = reg:GetOverlaySetting(featureId, "mode") or "ILVL"
        if not hasPawn and (currentMode == "PAWN" or currentMode == "PAWN>ILVL") then
            currentMode = "ILVL"
            reg:SetOverlaySetting(featureId, "mode", "ILVL")
        end

        local MODES = {
            { value = "ILVL",      label = L["OVR_UPGRADE_MODE_ILVL"],      desc = L["OVR_UPGRADE_MODE_ILVL_DESC"] },
            { value = "PAWN",      label = L["OVR_UPGRADE_MODE_PAWN"],      desc = L["OVR_UPGRADE_MODE_PAWN_DESC"], needsPawn = true },
            { value = "PAWN>ILVL", label = L["OVR_UPGRADE_MODE_PAWN_ILVL"], desc = L["OVR_UPGRADE_MODE_PAWN_ILVL_DESC"], needsPawn = true },
        }

        local radioButtons = {}
        local refreshEnforcePawnState

        for _, modeInfo in ipairs(MODES) do
            local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
            radio:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            radio:SetChecked(currentMode == modeInfo.value)

            local radioLabel = OneWoW_GUI:CreateFS(content, 12)
            radioLabel:SetPoint("LEFT", radio, "RIGHT", 5, 0)
            radioLabel:SetText(modeInfo.label)
            radioLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            y = y - 20

            local radioDesc = OneWoW_GUI:CreateFS(content, 10)
            radioDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 26, y)
            radioDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            radioDesc:SetJustifyH("LEFT")
            radioDesc:SetWordWrap(true)
            radioDesc:SetText(modeInfo.desc)
            radioDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            y = y - radioDesc:GetStringHeight() - 10

            if modeInfo.needsPawn and not hasPawn then
                radio:Disable()
                radioLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            radio:SetScript("OnClick", function()
                reg:SetOverlaySetting(featureId, "mode", modeInfo.value)
                for _, rb in ipairs(radioButtons) do rb:SetChecked(false) end
                radio:SetChecked(true)
                if refreshEnforcePawnState then
                    refreshEnforcePawnState(modeInfo.value)
                end
            end)
            radioButtons[#radioButtons + 1] = radio
        end

        if not hasPawn then
            local pawnNote = OneWoW_GUI:CreateFS(content, 10)
            pawnNote:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            pawnNote:SetText(L["OVR_UPGRADE_PAWN_NOT_INSTALLED"])
            pawnNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            y = y - pawnNote:GetStringHeight() - 10
        end

        if hasPawn then
            local enforceCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_PAWN_ENFORCE_REQ_LEVEL"] })
            enforceCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            enforceCb:SetChecked(reg:GetOverlaySetting(featureId, "pawnEnforceReqLevel") ~= false)
            enforceCb:SetScript("OnClick", function(myself)
                reg:SetOverlaySetting(featureId, "pawnEnforceReqLevel", myself:GetChecked())
            end)
            enforceCb:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
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
            y = y - 28
        end

        local selfSpecCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_SELF_SPEC_MATCH"] })
        selfSpecCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        selfSpecCb:SetChecked(reg:GetOverlaySetting(featureId, "selfSpecMatch") or false)
        selfSpecCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "selfSpecMatch", myself:GetChecked())
        end)
        selfSpecCb:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_SELF_SPEC_MATCH"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_SELF_SPEC_MATCH_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        selfSpecCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 28

        return math.abs(y)
    end)

    stack:AddCard("upgrade-tooltip", L["OVR_CARD_TOOLTIP"], function(content, w)
        local y = 0

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

        local tooltipCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_TOOLTIP_LABEL"] })
        tooltipCb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        tooltipCb:SetChecked(reg:GetOverlaySetting(featureId, "showInTooltip") or false)

        local currentDetail = reg:GetOverlaySetting(featureId, "tooltipDetail") or "FULL"
        local detailDD, detailDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 110,
            text = GetDetailLabel(currentDetail),
        })
        detailDD:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
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
        y = y - 30

        local onlyUpgradeCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_TOOLTIP_ONLY_UPGRADE"] })
        onlyUpgradeCb:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
        onlyUpgradeCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipOnlyUpgrade") or false)
        onlyUpgradeCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "tooltipOnlyUpgrade", myself:GetChecked())
        end)
        y = y - 28

        local showSkipCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_TOOLTIP_SHOW_SKIP"] })
        showSkipCb:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
        showSkipCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipShowSkipReason") or false)
        showSkipCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "tooltipShowSkipReason", myself:GetChecked())
        end)
        y = y - 28

        local showAltsCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS"] })
        showAltsCb:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
        showAltsCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipShowAlts") ~= false)
        showAltsCb:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_TOOLTIP_SHOW_ALTS_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        showAltsCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 28

        local altSpecCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_ALT_SPEC_MATCH"] })
        altSpecCb:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        altSpecCb:SetChecked(reg:GetOverlaySetting(featureId, "altSpecMatch") or false)
        altSpecCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "altSpecMatch", myself:GetChecked())
        end)
        altSpecCb:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_ALT_SPEC_MATCH"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_ALT_SPEC_MATCH_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        altSpecCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 28

        local ignoreSBCb = OneWoW_GUI:CreateCheckbox(content, { label = L["OVR_UPGRADE_TOOLTIP_IGNORE_SOULBOUND"] })
        ignoreSBCb:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        ignoreSBCb:SetChecked(reg:GetOverlaySetting(featureId, "tooltipIgnoreSoulbound") or false)
        ignoreSBCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "tooltipIgnoreSoulbound", myself:GetChecked())
        end)
        ignoreSBCb:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_TOOLTIP_IGNORE_SOULBOUND"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_TOOLTIP_IGNORE_SOULBOUND_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        ignoreSBCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 28

        local ALT_LIMIT_VALUES = { 1, 2, 3, 4, 6, 8, 10, 15, 20, 25, 0 }
        local function altLimitValueToPos(val)
            for i, v in ipairs(ALT_LIMIT_VALUES) do
                if v == val then return i end
            end
            return 7
        end
        local function altLimitLabel(pos)
            local v = ALT_LIMIT_VALUES[pos]
            if v == 0 then return L["OVR_UPGRADE_TOOLTIP_ALT_LIMIT_ALL"] end
            return tostring(v)
        end

        local altLimitLbl = OneWoW_GUI:CreateFS(content, 12)
        altLimitLbl:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        altLimitLbl:SetText(L["OVR_UPGRADE_TOOLTIP_ALT_LIMIT"])
        altLimitLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        altLimitLbl:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_TOOLTIP_ALT_LIMIT"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_TOOLTIP_ALT_LIMIT_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        altLimitLbl:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 18

        local controlWidth = math.max(140, (w or 200) - 36)
        local currentLimit = reg:GetOverlaySetting(featureId, "tooltipAltLimit") or 10
        local altLimitSliderWrap = OneWoW_GUI:CreateSlider(content, {
            width = controlWidth,
            minVal = 1,
            maxVal = #ALT_LIMIT_VALUES,
            step = 1,
            currentVal = altLimitValueToPos(currentLimit),
            getLabel = altLimitLabel,
            getValue = function(pos) return ALT_LIMIT_VALUES[pos] end,
            onChange = function(value)
                reg:SetOverlaySetting(featureId, "tooltipAltLimit", value)
            end,
        })
        altLimitSliderWrap:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        y = y - 40

        local ALT_SORT_OPTIONS = {
            { value = "UPGRADE_DESC", text = L["OVR_UPGRADE_ALT_SORT_UPGRADE_DESC"] },
            { value = "UPGRADE_ASC",  text = L["OVR_UPGRADE_ALT_SORT_UPGRADE_ASC"] },
            { value = "NAME_ASC",     text = L["OVR_UPGRADE_ALT_SORT_NAME"] },
            { value = "ILVL_DESC",    text = L["OVR_UPGRADE_ALT_SORT_ILVL"] },
            { value = "LOGIN_DESC",   text = L["OVR_UPGRADE_ALT_SORT_LOGIN"] },
        }
        local function GetAltSortLabel(val)
            for _, o in ipairs(ALT_SORT_OPTIONS) do
                if o.value == val then return o.text end
            end
            return L["OVR_UPGRADE_ALT_SORT_UPGRADE_DESC"]
        end

        local altSortLbl = OneWoW_GUI:CreateFS(content, 12)
        altSortLbl:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        altSortLbl:SetText(L["OVR_UPGRADE_TOOLTIP_ALT_SORT"])
        altSortLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        altSortLbl:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_UPGRADE_TOOLTIP_ALT_SORT"], 1, 1, 1)
            GameTooltip:AddLine(L["OVR_UPGRADE_TOOLTIP_ALT_SORT_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        altSortLbl:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 18

        local currentSort = reg:GetOverlaySetting(featureId, "tooltipAltSort") or "UPGRADE_DESC"
        local altSortDD, altSortDDText = OneWoW_GUI:CreateDropdown(content, {
            width = controlWidth,
            text = GetAltSortLabel(currentSort),
        })
        altSortDD:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y)
        OneWoW_GUI:AttachFilterMenu(altSortDD, {
            searchable = false,
            buildItems = function() return ALT_SORT_OPTIONS end,
            onSelect = function(value, text)
                altSortDDText:SetText(text)
                reg:SetOverlaySetting(featureId, "tooltipAltSort", value)
            end,
            getActiveValue = function()
                return reg:GetOverlaySetting(featureId, "tooltipAltSort") or "UPGRADE_DESC"
            end,
        })
        y = y - 34

        local scopeY, scopeControls = ns.UI.BuildAltScopeSection(content, {
            yOffset = y,
            x = 36,
            width = w,
            getScope = function()
                local s = reg:GetOverlaySetting(featureId, "altScope")
                if type(s) ~= "table" then s = { mode = "all", chars = {}, roles = {} } end
                return s
            end,
            saveScope = function(s)
                reg:SetOverlaySetting(featureId, "altScope", s)
            end,
        })
        y = scopeY - 6

        local function setAltChildrenEnabled(enabled)
            local key = enabled and "TEXT_PRIMARY" or "TEXT_MUTED"
            if enabled then
                altSpecCb:Enable()
                ignoreSBCb:Enable()
                if altLimitSliderWrap.slider then altLimitSliderWrap.slider:Enable() end
                altSortDD:Enable()
            else
                altSpecCb:Disable()
                ignoreSBCb:Disable()
                if altLimitSliderWrap.slider then altLimitSliderWrap.slider:Disable() end
                altSortDD:Disable()
            end
            ApplyThemeText(altSpecCb.label, key)
            ApplyThemeText(ignoreSBCb.label, key)
            ApplyThemeText(altLimitLbl, key)
            ApplyThemeText(altLimitSliderWrap.valLabel, key)
            ApplyThemeText(altSortLbl, key)
            ApplyThemeText(altSortDD._text, key)
            scopeControls.SetEnabled(enabled)
        end

        local function refreshTooltipSubs(enabled)
            local key = enabled and "TEXT_PRIMARY" or "TEXT_MUTED"
            if enabled then
                detailDD:Enable()
                onlyUpgradeCb:Enable()
                showSkipCb:Enable()
                showAltsCb:Enable()
                setAltChildrenEnabled(showAltsCb:GetChecked())
            else
                detailDD:Disable()
                onlyUpgradeCb:Disable()
                showSkipCb:Disable()
                showAltsCb:Disable()
                setAltChildrenEnabled(false)
            end
            ApplyThemeText(detailDD._text, key)
            ApplyThemeText(onlyUpgradeCb.label, key)
            ApplyThemeText(showSkipCb.label, key)
            ApplyThemeText(showAltsCb.label, key)
        end
        refreshTooltipSubs(reg:GetOverlaySetting(featureId, "showInTooltip") or false)

        showAltsCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "tooltipShowAlts", myself:GetChecked())
            setAltChildrenEnabled(myself:GetChecked())
        end)

        tooltipCb:SetScript("OnClick", function(myself)
            reg:SetOverlaySetting(featureId, "showInTooltip", myself:GetChecked())
            refreshTooltipSubs(myself:GetChecked())
        end)

        return math.abs(y)
    end)

    stack:AddCard("upgrade-icon", L["OVR_ICON_LABEL"], function(content, w)
        return BuildIconCard(content, acc, w)
    end)

    stack:AddCard("upgrade-placement", L["OVR_CARD_PLACEMENT"], function(content)
        return BuildPlacementCard(content, acc)
    end)

    stack:AddCard("upgrade-effect", L["OVR_EFFECT_LABEL"], function(content, w)
        return BuildEffectCard(content, acc, w)
    end)

    stack:AddCard("upgrade-bg", L["OVR_CARD_BACKGROUND"], function(content, w)
        return BuildBackgroundCard(content, acc, w)
    end)

    stack:AddCard("upgrade-surfaces", L["OVR_CARD_SURFACES"], function(content)
        return BuildSurfacesCard(content, acc.get, acc.set)
    end)

    stack:AddCard("upgrade-manage", L["OVR_CARD_MANAGE"], function(content)
        local resetBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_RESET_DEFAULTS_BTN"], height = 26 })
        resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        resetBtn:SetScript("OnClick", function()
            local fresh = OneWoW:GetSettingsDefaults("overlays")[featureId]
            fresh.enabled = reg:IsEnabled("overlays", featureId)
            local cfg = reg:GetFeatureSettings("overlays", featureId)
            for key in pairs(cfg) do
                if fresh[key] == nil then
                    reg:SetOverlaySetting(featureId, key, nil)
                end
            end
            for key, value in pairs(fresh) do
                reg:SetOverlaySetting(featureId, key, value)
            end
            ShowUpgradeDetail(split, feature, selectedRow)
        end)
        return 28
    end)

    stack:Finish()
end

-- Public entry point so Tooltips > Gear Upgrades can render the same detail
-- panel as a 1:1 mirror (feature.id == "upgrade" with tooltip-flavored
-- title/description keys).
function ns.UI.ShowOverlayFeatureDetail(split, feature, selectedRow)
    ShowUpgradeDetail(split, feature, selectedRow)
end

-- ----------------------------------------------------------------------------
-- User overlay detail
-- ----------------------------------------------------------------------------

local ShowUserOverlayDetail

ShowUserOverlayDetail = function(split, id, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local entry = GetUserOverlays()[id]
    if not entry then
        dsc:SetHeight(10)
        split.UpdateDetailThumb()
        return
    end

    local Defs = OneWoW.Overlays2Defs
    local Renderer = OneWoW.Overlays2Renderer
    local preset = entry.preset and Defs:GetPreset(entry.preset)
    local stack = NewCardStack(split, dsc)

    local refreshPreviewRef
    local acc = UserAccessor(id, entry, function()
        if refreshPreviewRef then refreshPreviewRef() end
    end)

    refreshPreviewRef = AddHeroBlock(stack, {
        title = EntryDisplayName(entry),
        desc = preset and L[preset.description] or nil,
        isEnabled = function() return entry.enabled == true end,
        onToggle = function(newState) SetEntryField(id, entry, "enabled", newState) end,
        selectedRow = selectedRow,
        tintAccessor = acc,
        paintSlot = function(slot)
            Renderer:ApplyOverlay(slot, AccessorPaint(acc), 1, PREVIEW_BG_RARITY_ITEM_LINK)
        end,
    })

    -- ---- Rule card ----
    stack:AddCard("user-rule", L["OVR_RULE_LABEL"], function(content, w)
        local y = 0

        if preset then
            local expr = Defs:ResolveExpression(entry) or ""
            y = AddNote(content, y, L["OVR_RULE_PRESET_NOTE"] .. " |cffffffff" .. expr .. "|r", w)

            if preset.extras then
                if preset.extras.includeWUE ~= nil then
                    local _, cbY = AddCheckbox(content, y, L["OVR_WARBOUND_INCLUDE_WUE_LABEL"],
                        entry.includeWUE ~= false, function(checked)
                            SetEntryField(id, entry, "includeWUE", checked)
                            ShowUserOverlayDetail(split, id, selectedRow)
                        end)
                    y = cbY
                end
                if preset.extras.includeGreyItems ~= nil then
                    local _, cbY = AddCheckbox(content, y, L["OVR_JUNK_GREY_LABEL"],
                        entry.includeGreyItems == true, function(checked)
                            SetEntryField(id, entry, "includeGreyItems", checked)
                            ShowUserOverlayDetail(split, id, selectedRow)
                        end)
                    y = cbY
                end
                if preset.extras.onlyNeeded ~= nil then
                    local _, cbY = AddCheckbox(content, y, L["OVR_SHOPPINGLIST_NEEDED_LABEL"],
                        entry.onlyNeeded == true, function(checked)
                            SetEntryField(id, entry, "onlyNeeded", checked)
                            ShowUserOverlayDetail(split, id, selectedRow)
                        end)
                    y = cbY
                end
                if preset.extras.showInTooltip ~= nil then
                    local _, cbY = AddCheckbox(content, y, L["OVR_TOOLTIP_LABEL"],
                        entry.showInTooltip ~= false, function(checked)
                            SetEntryField(id, entry, "showInTooltip", checked)
                        end)
                    y = cbY
                end
            end

            if entry.preset == "junk" or entry.preset == "protected" then
                local noteKey = (entry.preset == "junk") and "OVR_JUNK_NOTE" or "OVR_PROTECTED_NOTE"
                y = AddNote(content, y - 4, L[noteKey], w)
            end
            return math.abs(y)
        end

        -- Custom overlay: editable name + rule.
        local nameLbl = OneWoW_GUI:CreateFS(content, 12)
        nameLbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y - 5)
        nameLbl:SetText(NAME)
        nameLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local nameBox = OneWoW_GUI:CreateEditBox(content, { maxLetters = 40, width = 220, height = 22 })
        nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 10, 0)
        nameBox:SetText(entry.name or "")
        nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        nameBox:SetScript("OnEnterPressed", function(box)
            box:ClearFocus()
            local newName = box:GetSearchText()
            if newName ~= "" then
                SetEntryField(id, entry, "name", newName)
                RefreshList(id)
            end
        end)
        y = y - 30

        local ruleBox = OneWoW_GUI:CreateEditBox(content, {
            placeholderText = L["OVR_RULE_PLACEHOLDER"],
            height = 22,
        })
        ruleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        ruleBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -30, y)
        if entry.expression and entry.expression ~= "" then
            ruleBox:SetText(entry.expression)
            ruleBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local helpBtn = OneWoW_GUI:CreateKeywordHelpButton(content, {
            editBox = ruleBox,
            size = 22,
            tooltipTitle = L["OVR_RULE_HELP_TITLE"],
            tooltipDesc = L["OVR_RULE_HELP_DESC"],
        })
        helpBtn:SetPoint("LEFT", ruleBox, "RIGHT", 8, 0)
        y = y - 28

        local errLabel = OneWoW_GUI:CreateFS(content, 11)
        errLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        errLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -70, y)
        errLabel:SetJustifyH("LEFT")
        errLabel:SetWordWrap(true)

        local function ShowRuleState(ok, err)
            if ok then
                errLabel:SetText(L["OVR_RULE_SAVED"])
                errLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                errLabel:SetText(string.format(L["OVR_RULE_ERROR"], err or "?"))
                errLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
        end

        if entry.expression and entry.expression ~= "" then
            local ok, err = Defs:ValidateExpression(entry.expression)
            if not ok then ShowRuleState(false, err) else errLabel:SetText("") end
        else
            errLabel:SetText("")
        end

        local function SaveRule()
            local text = ruleBox:GetSearchText()
            local ok, err = Defs:ValidateExpression(text)
            if ok then
                SetEntryField(id, entry, "expression", text)
            end
            ShowRuleState(ok, err)
        end

        ruleBox:SetScript("OnEnterPressed", function(box)
            box:ClearFocus()
            SaveRule()
        end)

        local saveBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_RULE_SAVE_BTN"], height = 22 })
        saveBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        saveBtn:SetScript("OnClick", SaveRule)
        y = y - 30

        return math.abs(y)
    end)

    stack:AddCard("user-icon-type", L["OVR_ICON_TYPE_LABEL"], function(content, w)
        return BuildIconTypeCard(content, acc, w, function()
            ShowUserOverlayDetail(split, id, selectedRow)
        end)
    end)

    -- The system-icon gallery only applies to the "list" icon type; atlas and
    -- custom-file types use the inputs inside the Icon Type card instead.
    if (acc.getIconSpec().kind or "list") == "list" then
        stack:AddCard("user-icon", L["OVR_ICON_LABEL"], function(content, w)
            return BuildIconCard(content, acc, w)
        end)
    end

    stack:AddCard("user-placement", L["OVR_CARD_PLACEMENT"], function(content)
        return BuildPlacementCard(content, acc)
    end)

    stack:AddCard("user-effect", L["OVR_EFFECT_LABEL"], function(content, w)
        return BuildEffectCard(content, acc, w)
    end)

    stack:AddCard("user-bg", L["OVR_CARD_BACKGROUND"], function(content, w)
        return BuildBackgroundCard(content, acc, w)
    end)

    stack:AddCard("user-surfaces", L["OVR_CARD_SURFACES"], function(content)
        return BuildSurfacesCard(content,
            function(key) return entry[key] end,
            function(key, value) SetEntryField(id, entry, key, value) end)
    end)

    stack:AddCard("user-manage", L["OVR_CARD_MANAGE"], function(content)
        local deleteBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["OVR_DELETE_BTN"], height = 26 })
        deleteBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        deleteBtn:SetScript("OnClick", function()
            local dialog = OneWoW_GUI:CreateConfirmDialog({
                name    = "OneWoW_OverlayDeleteConfirm",
                title   = L["OVR_DELETE_BTN"],
                message = string.format(L["OVR_DELETE_CONFIRM_MSG"], EntryDisplayName(entry)),
                buttons = {
                    { text = DELETE, color = { 0.6, 0.2, 0.2 }, onClick = function(d)
                        d:Hide()
                        Reg():SetSetting("overlays", "userOverlays", id, nil)
                        RefreshList("general")
                    end },
                    { text = CANCEL, onClick = function(d) d:Hide() end },
                },
            })
            dialog.frame:Show()
        end)
        return 28
    end)

    stack:Finish()
end

-- ----------------------------------------------------------------------------
-- Add Overlay dialog
-- ----------------------------------------------------------------------------

local addDialog

function ns.UI.ShowAddOverlayDialog()
    if addDialog then
        addDialog.frame:Show()
        return
    end

    local selectedPreset = nil -- nil == custom

    addDialog = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_OverlayAddDialog",
        title  = L["OVR_ADD_OVERLAY_BTN"],
        width  = 420,
        height = 240,
    })

    local content = addDialog.contentFrame

    local typeLabel = OneWoW_GUI:CreateFS(content, 12)
    typeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -16)
    typeLabel:SetText(L["OVR_ADD_DIALOG_TYPE_LABEL"])
    typeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local nameLabel = OneWoW_GUI:CreateFS(content, 12)
    local nameBox

    local typeDD, typeDDText = OneWoW_GUI:CreateDropdown(content, {
        width = 240,
        text = L["OVR_ADD_DIALOG_CUSTOM"],
    })
    typeDD:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -36)
    typeDD:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -36)

    local function SetNameEnabled(enabled)
        if enabled then
            nameBox:Enable()
            nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            nameBox:Disable()
            nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    OneWoW_GUI:AttachFilterMenu(typeDD, {
        searchable = true,
        buildItems = function()
            local items = { { text = L["OVR_ADD_DIALOG_CUSTOM"], value = "__custom__" } }
            -- Skip presets that already exist as an overlay; only deleted
            -- presets should be offered for re-adding.
            local present = {}
            for _, e in pairs(GetUserOverlays()) do
                if type(e) == "table" and e.preset then
                    present[e.preset] = true
                end
            end
            for _, preset in ipairs(OneWoW.Overlays2Defs:GetPresets()) do
                if not present[preset.id] then
                    table.insert(items, { text = L[preset.title], value = preset.id })
                end
            end
            return items
        end,
        onSelect = function(value, text)
            typeDDText:SetText(text)
            selectedPreset = (value ~= "__custom__") and value or nil
            SetNameEnabled(selectedPreset == nil)
        end,
        getActiveValue = function()
            return selectedPreset or "__custom__"
        end,
    })

    nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -76)
    nameLabel:SetText(NAME)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    nameBox = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["OVR_CUSTOM_DEFAULT_NAME"],
        maxLetters = 40,
    })
    nameBox:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -96)
    nameBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -96)

    local capNote = OneWoW_GUI:CreateFS(content, 11)
    capNote:SetPoint("TOPLEFT",  content, "TOPLEFT",  14, -132)
    capNote:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -132)
    capNote:SetJustifyH("LEFT")
    capNote:SetWordWrap(true)
    capNote:SetText(L["OVR_MAX_OVERLAYS_NOTE"])
    capNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local createBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["CREATE"], height = 26 })
    createBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 12)
    createBtn:SetScript("OnClick", function()
        local Defs = OneWoW.Overlays2Defs
        local userOverlays = GetUserOverlays()

        local maxOrder = 0
        for _, entry in pairs(userOverlays) do
            if type(entry) == "table" and (entry.order or 0) > maxOrder then
                maxOrder = entry.order or 0
            end
        end

        local name = nameBox:GetSearchText()
        local entry = Defs:NewEntry(selectedPreset, name ~= "" and name or L["OVR_CUSTOM_DEFAULT_NAME"])
        entry.order = maxOrder + 1

        local id = Defs:GenerateId(userOverlays)
        SaveEntry(id, entry)

        addDialog.frame:Hide()
        RefreshList(id)
    end)

    SetNameEnabled(true)
    addDialog.frame:Show()
end

-- ----------------------------------------------------------------------------
-- Left list
-- ----------------------------------------------------------------------------

--- List row with icon thumbnail, label, drag-reorder handle, and enable dot.
local function CreateOverlayRow(parent, opts)
    local row = OneWoW_GUI:CreateListRowBasic(parent, {
        height = 30,
        label = opts.label,
        showDot = true,
        dotEnabled = opts.enabled,
        onClick = opts.onClick,
    })

    if opts.iconSpec then
        local icoFrame = CreateFrame("Frame", nil, row)
        icoFrame:SetSize(18, 18)
        icoFrame:SetPoint("LEFT", row, "LEFT", 8, 0)
        local icoTex = icoFrame:CreateTexture(nil, "ARTWORK")
        icoTex:SetAllPoints(icoFrame)
        OneWoW.OverlayIcons:ApplyIconSpec(icoTex, opts.iconSpec)

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", icoFrame, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", opts.canMove and -46 or -24, 0)
        row.label:SetJustifyH("LEFT")
    end

    -- Drag-handle affordance. The whole row is the drag source (wired by the
    -- reorder controller); this grip is a visual hint carrying the tooltip.
    -- Motion-only so mouse clicks fall through to the row and start the drag.
    if opts.canMove then
        local grip = CreateFrame("Frame", nil, row)
        grip:SetSize(16, 16)
        grip:SetPoint("RIGHT", row.dot, "LEFT", -6, 0)
        -- Motion only (for the tooltip); a Frame does not capture clicks by
        -- default, so mouse-down falls through to the row and starts the drag.
        grip:EnableMouseMotion(true)

        local gripTex = grip:CreateTexture(nil, "ARTWORK")
        gripTex:SetAllPoints(grip)
        gripTex:SetAtlas("common-icon-move")
        gripTex:SetAlpha(0.7)

        grip:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["OVR_DRAG_REORDER_HINT"], 1, 1, 1)
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", GameTooltip_Hide)
    end

    return row
end

local function BuildOverlayList(split)
    local lsc = split.listScrollChild
    local selectedRow = nil
    local selectedId = nil

    local BUILTINS = {
        { id = "general",       title = "OVR_GENERAL_TITLE" },
        { id = "itemlevel",     title = "OVR_ITEMLEVEL_TITLE" },
        { id = "qualityborder", title = "OVR_QUALITYBORDER_TITLE" },
        { id = "upgrade",       title = "OVR_UPGRADE_TITLE" },
    }

    -- Drag-reorder for user overlay rows. Rebuilt each render into
    -- userRowFrames; built-ins never join this list, so they stay pinned and
    -- cannot be dragged or used as drop targets.
    local userRowFrames = {}
    local reorderCtrl

    local function RestoreRowBorder(row)
        if row.isActive then
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    local function EnsureReorder()
        if reorderCtrl then return reorderCtrl end
        local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        reorderCtrl = OneWoW_GUI:CreateReorderDrag({
            getItems = function() return userRowFrames end,
            dropIndicator = { thickness = 2, horizontalPadding = 6, color = { r, g, b, 1 } },
            autoScroll = {
                getFrame = function() return split.listScrollFrame end,
                edgeZone = 40, maxSpeed = 14, minSpeed = 2,
            },
            onPickup = function(row)
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end,
            onRestore = function(row)
                RestoreRowBorder(row)
            end,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local src = userRowFrames[fromIdx]
                local tgt = userRowFrames[toIdx]
                if not src or not tgt or not src._ovrId or not tgt._ovrId then return end
                if ReorderEntry(src._ovrId, tgt._ovrId, insertBefore) then
                    RefreshList(src._ovrId)
                end
            end,
        })
        return reorderCtrl
    end

    local function ShowDetailFor(rowId, row)
        local dsc = split.detailScrollChild
        OneWoW_GUI:ClearFrame(dsc)

        if rowId == "general" then
            ShowGeneralDetail(split, dsc, row)
        elseif rowId == "itemlevel" then
            ShowItemLevelDetail(split, dsc, row)
        elseif rowId == "qualityborder" then
            ShowQualityBorderDetail(split, dsc, row)
        elseif rowId == "upgrade" then
            ShowUpgradeDetail(split, { id = "upgrade", title = "OVR_UPGRADE_TITLE", description = "OVR_UPGRADE_DESC" }, row)
        else
            ShowUserOverlayDetail(split, rowId, row)
        end
    end

    local function IsRowEnabled(rowId)
        if rowId == "general" or rowId == "itemlevel"
            or rowId == "qualityborder" or rowId == "upgrade" then
            return Reg():IsEnabled("overlays", rowId)
        end
        local entry = GetUserOverlays()[rowId]
        return entry ~= nil and entry.enabled == true
    end

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        local allRows = {}
        local rowToSelect = nil
        local yOffset = -5
        local filter = (filterText or ""):lower()

        -- Only allow drag-reordering when the list is unfiltered; a filtered
        -- subset has no meaningful full-list ordering.
        local canDrag = (filter == "")
        local reorder = EnsureReorder()
        wipe(userRowFrames)

        local function PlaceRow(row, rowId)
            row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
            row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
            if rowId == selectedId then
                rowToSelect = row
            end
            table.insert(allRows, row)
            yOffset = yOffset - 34
        end

        local function RowClick(rowId)
            return function(myself)
                if reorderCtrl and reorderCtrl:IsActive() then return end
                if selectedRow and selectedRow ~= myself then
                    selectedRow:SetActive(false)
                end
                selectedRow = myself
                selectedId = rowId
                myself:SetActive(true)
                ShowDetailFor(rowId, myself)
            end
        end

        for _, builtin in ipairs(BUILTINS) do
            local displayName = L[builtin.title]
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local row = OneWoW_GUI:CreateListRowBasic(lsc, {
                    height = 30,
                    label = displayName,
                    showDot = true,
                    dotEnabled = IsRowEnabled(builtin.id),
                    onClick = RowClick(builtin.id),
                })
                PlaceRow(row, builtin.id)
            end
        end

        local ordered = GetOrderedEntries()
        for _, item in ipairs(ordered) do
            local displayName = EntryDisplayName(item.entry)
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local capturedId = item.id
                local row = CreateOverlayRow(lsc, {
                    label = displayName,
                    enabled = item.entry.enabled == true,
                    iconSpec = type(item.entry.icon) == "table" and item.entry.icon or nil,
                    canMove = canDrag,
                    onClick = RowClick(capturedId),
                })
                row._ovrId = capturedId
                PlaceRow(row, capturedId)
                if canDrag then
                    table.insert(userRowFrames, row)
                    reorder:Attach(row)
                end
            end
        end

        -- Pinned "+ Add Overlay" action row (never auto-selected).
        local addRow = OneWoW_GUI:CreateListRowBasic(lsc, {
            height = 30,
            label = "+ " .. L["OVR_ADD_OVERLAY_BTN"],
            onClick = function() ns.UI.ShowAddOverlayDialog() end,
        })
        addRow.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        addRow.label:SetJustifyH("CENTER")
        addRow:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
        addRow:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
        yOffset = yOffset - 34

        lsc:SetHeight(math.abs(yOffset) + 10)

        local enabledCount = 0
        for _, item in ipairs(ordered) do
            if item.entry.enabled then enabledCount = enabledCount + 1 end
        end
        split.leftStatusText:SetText(string.format("%s: %d/%d", L["OVERLAYS_LIST_TITLE"], enabledCount, #ordered))

        if #allRows > 0 and not selectedRow then
            local target = rowToSelect or allRows[1]
            target:Click()
        end
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(myself)
            RenderRows(myself:GetSearchText())
        end)
    end

    RefreshListRef = function(selectId)
        if selectId then selectedId = selectId end
        local text = split.searchBox and split.searchBox:GetSearchText() or ""
        RenderRows(text)
    end

    split.RefreshList = RefreshListRef
end

function ns.UI.CreateOverlaysTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
        hideTitles = true,
    })

    CreateSidePreviewPanel(split)

    C_Timer.After(0.1, function()
        BuildOverlayList(split)
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)

    -- nil until the deferred BuildOverlayList above has run once.
    parent.Activate = function()
        if split.RefreshList then split.RefreshList() end
    end
end
