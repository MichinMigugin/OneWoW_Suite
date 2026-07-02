local _, ns = ...

local format = string.format
local tinsert = tinsert
local table = table
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local L = ns.L

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local ItemPrices = OneWoW.ItemPrices

ns.AHPricesPanel = ns.AHPricesPanel or {}
local Panel = ns.AHPricesPanel

local PANEL_WIDTH = 320
local initialized = false
local panelFrame = nil
local panelTab = nil
local contentFrame = nil
local scanBtn = nil
local progressBar = nil
local progressText = nil
local statusText = nil
local autoScanCheck = nil
local disabledNote = nil
local isScanning = false
local EnsureTab
local RelayoutPanel

local function GetBrandIcon()
    local theme = (OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
    return OneWoW_GUI:GetBrandIcon(theme)
end

local function GetSettings()
    return OneWoW_AltTracker_Auctions_DB.settings
end

local function RefreshStatus()
    if not statusText or not OneWoW_AltTracker_Auctions_API then return end
    local meta = OneWoW_AltTracker_Auctions_API.GetScanMeta()
    local lines = {}
    if meta.lastFullScanAt and meta.lastFullScanAt > 0 then
        local ago = GetServerTime() - meta.lastFullScanAt
        local mins = math.floor(ago / 60)
        if mins < 60 then
            tinsert(lines, format(L["AH_PANEL_STATUS_LAST"], mins .. "m"))
        else
            tinsert(lines, format(L["AH_PANEL_STATUS_LAST"], math.floor(mins / 60) .. "h"))
        end
        tinsert(lines, format(L["AH_PANEL_STATUS_ENTRIES"], meta.lastFullScanItemCount or 0))
    else
        tinsert(lines, L["AH_PANEL_NEVER_SCANNED"])
    end
    tinsert(lines, format(L["AH_PANEL_STATUS_REALM"], meta.realmID or GetRealmID()))
    local canScan, minsLeft = OneWoW_AltTracker_Auctions_API.CanFullScan()
    if not canScan and minsLeft and minsLeft > 0 then
        tinsert(lines, format(L["AH_PANEL_STATUS_COOLDOWN"], minsLeft))
    end
    statusText:SetText(table.concat(lines, "\n"))
end

local function UpdateScanControls()
    -- Controls are always visible. When the active AH price source is not OneWoW
    -- (Auctionator / TSM selected), the scan controls are disabled and a note
    -- explains why; the source dropdown stays usable so the user can switch back.
    local offerScan = ItemPrices:ShouldOfferOneWoWAHScanUI()
    local canScan = OneWoW_AltTracker_Auctions_API and select(1, OneWoW_AltTracker_Auctions_API.CanFullScan())

    if scanBtn and not isScanning then
        scanBtn:SetEnabled(offerScan and canScan ~= false)
    end
    if autoScanCheck then
        autoScanCheck:SetEnabled(offerScan)
        autoScanCheck:SetAlpha(offerScan and 1 or 0.5)
    end
    if disabledNote then disabledNote:SetShown(not offerScan) end
    if statusText then statusText:SetShown(offerScan) end

    RefreshStatus()
end

local function OnScanCallback(status, progress, extra)
    if not progressBar or not progressText or not scanBtn then return end

    if status == "scanStarted" then
        isScanning = true
        scanBtn:SetText(L["AH_PANEL_STOP_SCAN"])
        progressBar:GetParent():Show()
        progressBar:SetValue(0)
        progressText:SetText(L["AH_PANEL_SCAN_WAITING"])
    elseif status == "scanWaiting" then
        progressBar:SetValue(0.1)
        progressText:SetText(format("%s (%ds)", L["AH_PANEL_SCAN_WAITING"], extra or 0))
    elseif status == "scanProgress" then
        local pct = progress or 0
        progressBar:SetValue(pct)
        progressText:SetText(format(L["AH_PANEL_SCAN_PROCESSING"], math.floor(pct * 100)))
    elseif status == "scanCompleted" then
        isScanning = false
        scanBtn:SetText(L["AH_PANEL_SCAN"])
        progressBar:SetValue(1)
        progressText:SetText(format(L["AH_PANEL_SCAN_COMPLETE"], extra or 0))
        C_Timer.After(3, function()
            if progressBar and progressBar:GetParent() then
                progressBar:GetParent():Hide()
            end
        end)
        UpdateScanControls()
    elseif status == "scanStopped" or status == "scanFailed" then
        isScanning = false
        scanBtn:SetText(L["AH_PANEL_SCAN"])
        progressBar:GetParent():Hide()
        UpdateScanControls()
    end
end

local function RepositionAuctionSidebar()
    local sidebar = AuctionHouseFrameTabSideBar
    if not sidebar or not AuctionHouseFrame then return end
    OneWoW_GUI:RepositionSideBar(sidebar, {
        hostFrame = AuctionHouseFrame,
        dockedPanel = (panelFrame and panelFrame:IsShown()) and panelFrame or nil,
        anchoredTab = panelTab,
    })
end

local function TogglePanel(show)
    if not panelFrame or not panelTab then return end
    if show then
        panelFrame:Show()
        if RelayoutPanel then RelayoutPanel() end
        RepositionAuctionSidebar()
    else
        panelFrame:Hide()
        if AuctionHouseFrameTabSideBar then
            AuctionHouseFrameTabSideBar.selTab = 0
        end
        RepositionAuctionSidebar()
    end
    UpdateScanControls()
end

local function BuildPanel()
    if panelFrame then return end
    if not AuctionHouseFrame then return end

    panelFrame = CreateFrame("Frame", "OneWoW_AHPricesPanel", AuctionHouseFrame, "BackdropTemplate")
    panelFrame:SetWidth(PANEL_WIDTH)
    panelFrame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 0, 0)
    panelFrame:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 0)
    panelFrame:SetFrameStrata("MEDIUM")
    panelFrame:SetToplevel(true)
    panelFrame:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 5)
    panelFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    panelFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    panelFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    panelFrame:Hide()

    -- No brand icon/label: the title itself already reads "OneWoW AH Prices", and
    -- in this narrow (320px) panel the centered brand text overlaps the title.
    OneWoW_GUI:CreateTitleBar(panelFrame, {
        title = L["AH_PANEL_TITLE"],
        showBrand = false,
        onClose = function()
            panelTab:SetChecked(false)
            TogglePanel(false)
        end,
    })

    contentFrame = CreateFrame("Frame", nil, panelFrame)
    contentFrame:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 12, -42)
    contentFrame:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -12, 12)

    -- Fixed metrics for non-text rows (button, progress bar, checkbox). The two
    -- wrapping-text rows below (auto-scan description, AH source picker) grow with
    -- the font size, so their heights are measured in RelayoutPanel instead of
    -- being hard-coded — otherwise the status text overlaps them at larger fonts.
    local BTN_H = 26
    local PROGRESS_H = 28
    local CHECK_H = 24
    local AUTODESC_FALLBACK_H = 32  -- used only until the FontString can be measured
    local SOURCE_FALLBACK_H = 110

    -- Scan button
    scanBtn = OneWoW_GUI:CreateFitTextButton(contentFrame, { text = L["AH_PANEL_SCAN"], height = BTN_H })
    scanBtn:SetScript("OnClick", function()
        if isScanning then
            OneWoW_AltTracker_Auctions_API.StopFullScan()
            return
        end
        if not OneWoW_AltTracker_Auctions_API then return end
        local canScan, minsLeft = OneWoW_AltTracker_Auctions_API.CanFullScan()
        if not canScan then
            print("|cFFFFD100OneWoW:|r " .. format(L["AH_SCAN_COOLDOWN"], minsLeft or 0))
            return
        end
        OneWoW_AltTracker_Auctions_API.StartFullScan(OnScanCallback)
    end)

    -- Progress bar (reserves a fixed row; shown only while scanning)
    local progressHolder = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    progressHolder:SetHeight(PROGRESS_H)
    progressHolder:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
    progressHolder:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    progressHolder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    progressHolder:Hide()

    progressBar = CreateFrame("StatusBar", nil, progressHolder, "BackdropTemplate")
    progressBar:SetPoint("TOPLEFT", progressHolder, "TOPLEFT", 4, -4)
    progressBar:SetPoint("BOTTOMRIGHT", progressHolder, "BOTTOMRIGHT", -4, 16)
    progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    progressBar:SetStatusBarColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)

    progressText = OneWoW_GUI:CreateFS(progressHolder, 10)
    progressText:SetPoint("BOTTOMLEFT", progressHolder, "BOTTOMLEFT", 6, 4)
    progressText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- Auto-scan toggle
    autoScanCheck = OneWoW_GUI:CreateCheckbox(contentFrame, {
        label = L["AH_PANEL_AUTO_SCAN"],
        checked = GetSettings().autoScanOnOpen == true,
        onClick = function(myself)
            GetSettings().autoScanOnOpen = myself:GetChecked() and true or false
        end,
    })

    local autoScanDesc = OneWoW_GUI:CreateFS(contentFrame, 10)
    autoScanDesc:SetJustifyH("LEFT")
    autoScanDesc:SetJustifyV("TOP")
    autoScanDesc:SetWordWrap(true)
    autoScanDesc:SetText(L["AH_PANEL_AUTO_SCAN_DESC"])
    autoScanDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    -- AH price source picker (always usable, even when scan is disabled).
    -- AttachAHSourceControl lays out its own label/dropdown/description and
    -- returns them so we can measure the block for the stack.
    local sourceHolder = CreateFrame("Frame", nil, contentFrame)
    local srcCtl = ItemPrices:AttachAHSourceControl(sourceHolder, { yOffset = 0, width = 200, onSelect = UpdateScanControls })

    -- Scan status / cache stats and the "external source" note share one slot;
    -- only one is visible at a time (toggled in UpdateScanControls).
    statusText = OneWoW_GUI:CreateFS(contentFrame, 11)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    statusText:SetWordWrap(true)
    statusText:SetSpacing(3)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    disabledNote = OneWoW_GUI:CreateFS(contentFrame, 11)
    disabledNote:SetJustifyH("LEFT")
    disabledNote:SetJustifyV("TOP")
    disabledNote:SetWordWrap(true)
    disabledNote:SetText(L["AH_PANEL_EXTERNAL_SOURCE"])
    disabledNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    disabledNote:Hide()

    -- Re-flow the stack top-to-bottom, measuring the wrapping-text rows so nothing
    -- overlaps regardless of font size. Called on build, on show, and on font
    -- change. GetStringHeight is only meaningful once the FontString width is
    -- resolved, so fall back to the fixed heights when a measure returns nothing.
    RelayoutPanel = function()
        if not contentFrame then return end
        local y = 0

        scanBtn:ClearAllPoints()
        scanBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
        y = y - BTN_H - 10

        progressHolder:ClearAllPoints()
        progressHolder:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
        progressHolder:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, y)
        y = y - PROGRESS_H - 10

        autoScanCheck:ClearAllPoints()
        autoScanCheck:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
        y = y - CHECK_H - 4

        local descH = math.ceil(autoScanDesc:GetStringHeight() or 0)
        if descH < 14 then descH = AUTODESC_FALLBACK_H end
        autoScanDesc:ClearAllPoints()
        autoScanDesc:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, y)
        autoScanDesc:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, y)
        autoScanDesc:SetHeight(descH)
        y = y - descH - 14

        sourceHolder:ClearAllPoints()
        sourceHolder:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
        sourceHolder:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, y)
        -- Mirror AttachAHSourceControl's internal stack: label + gap + dropdown(32) + desc + gap.
        local srcLabelH = math.ceil((srcCtl and srcCtl.label and srcCtl.label:GetStringHeight()) or 0)
        local srcDescH  = math.ceil((srcCtl and srcCtl.desc  and srcCtl.desc:GetStringHeight())  or 0)
        local sourceH
        if srcLabelH > 0 and srcDescH > 0 then
            sourceH = srcLabelH + 4 + 32 + srcDescH + 8
        else
            sourceH = SOURCE_FALLBACK_H
        end
        sourceHolder:SetHeight(sourceH)
        y = y - sourceH - 6

        statusText:ClearAllPoints()
        statusText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, y)
        statusText:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, y)

        disabledNote:ClearAllPoints()
        disabledNote:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, y)
        disabledNote:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, y)
    end

    AuctionHouseFrame:HookScript("OnHide", function()
        if panelTab then panelTab:SetChecked(false) end
        TogglePanel(false)
    end)

    RelayoutPanel()
    C_Timer.After(0, RelayoutPanel)  -- re-measure once frame widths resolve

    -- The panel is docked to AuctionHouseFrame, outside the main OneWoW window, so
    -- it isn't caught by the core window's font rebuild. Registering it as a font
    -- root re-applies fonts across the subtree and re-flows on font/size change.
    OneWoW_GUI:RegisterFontRoot(panelFrame, RelayoutPanel)

    UpdateScanControls()
end

local ahShowHooked = false
local ensureTabAttempts = 0
local MAX_ENSURE_TAB_ATTEMPTS = 20

local function FinishEnsureTab()
    if not AuctionHouseFrame then
        ensureTabAttempts = ensureTabAttempts + 1
        if ensureTabAttempts < MAX_ENSURE_TAB_ATTEMPTS then
            C_Timer.After(0.1, function()
                OneWoW:WithAddon("Blizzard_AuctionHouseUI", FinishEnsureTab)
            end)
        end
        return
    end
    ensureTabAttempts = 0

    if not ahShowHooked then
        ahShowHooked = true
        AuctionHouseFrame:HookScript("OnShow", function()
            if panelTab then
                RepositionAuctionSidebar()
                panelTab:Show()
            else
                EnsureTab()
            end
            UpdateScanControls()
        end)
    end

    if panelTab then
        RepositionAuctionSidebar()
        panelTab:Show()
        return
    end

    BuildPanel()

    local sidebar = OneWoW_GUI:EnsureSideBar(AuctionHouseFrame, "AuctionHouseFrameTabSideBar")
    panelTab, _ = OneWoW_GUI:CreateSideBarTab(sidebar, {
        name = "OneWoW_AHPricesTab",
        icon = GetBrandIcon(),
        tooltip = L["AH_PANEL_TAB_TOOLTIP"],
        onToggle = function(show)
            TogglePanel(show)
        end,
    })
    RepositionAuctionSidebar()
    panelTab:Show()
end

EnsureTab = function()
    OneWoW:WithAddon("Blizzard_AuctionHouseUI", FinishEnsureTab)
end

function Panel:OnAuctionHouseOpen()
    C_Timer.After(0.1, function()
        EnsureTab()
        UpdateScanControls()
    end)
end

function Panel:Initialize()
    if initialized then return end
    initialized = true

    ns:RegisterAddonLoadedWatcher("Blizzard_AuctionHouseUI", function()
        if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
            Panel:OnAuctionHouseOpen()
        end
    end)

    OneWoW:WithAddon("Blizzard_AuctionHouseUI", function()
        if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
            Panel:OnAuctionHouseOpen()
        end
    end)
end

function Panel:TryAutoScan()
    if not GetSettings().autoScanOnOpen then return end
    if not ItemPrices:ShouldOfferOneWoWAHScanUI() then return end
    if not OneWoW_AltTracker_Auctions_API then return end
    if isScanning then return end
    local canScan = select(1, OneWoW_AltTracker_Auctions_API.CanFullScan())
    if not canScan then return end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return end
    OneWoW_AltTracker_Auctions_API.StartFullScan(OnScanCallback)
end

function Panel:Refresh()
    UpdateScanControls()
end
