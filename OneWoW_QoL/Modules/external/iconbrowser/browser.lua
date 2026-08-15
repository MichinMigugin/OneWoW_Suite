-- ============================================================================
-- Icon Browser widget
-- ============================================================================
-- Search + category filters + virtualized icon grid. Search walks the catalog
-- through OneWoW.ChunkedJob so a 33k-icon pass does not hitch the client.
-- ============================================================================

local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local Mixin = Mixin
local CreateFromMixins = CreateFromMixins
local CallbackRegistryMixin = CallbackRegistryMixin
local CreateScrollBoxListGridView = CreateScrollBoxListGridView
local ScrollUtil = ScrollUtil
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local next = next
local pairs = pairs
local tinsert = tinsert
local wipe = wipe

local DEFAULT_STRIDE = 9
local CELL = 48
local GRID_PAD = 4
local SEARCH_DELAY = 0.25

local Browser = {}
M.Browser = Browser

local function NormalizeQuery(text)
    return M.Catalog.NormalizeQuery(text)
end

local function InitIconButton(button, browser)
    if button._ibReady then
        return
    end
    button._ibReady = true
    button:SetSize(CELL, CELL)
    button:RegisterForClicks("LeftButtonUp")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.Icon = icon

    local selected = button:CreateTexture(nil, "OVERLAY")
    selected:SetAllPoints()
    selected:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    selected:SetAlpha(0.35)
    selected:Hide()
    button.SelectedTexture = selected

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.18)

    button:SetScript("OnClick", function(myself)
        local info = myself._iconInfo
        if info and browser.OnIconSelected then
            browser:OnIconSelected(info)
        end
    end)
    button:SetScript("OnEnter", function(myself)
        local info = myself._iconInfo
        if not info then return end
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.name or UNKNOWN, 1, 1, 1)
        GameTooltip:AddLine(M.Catalog.FormatFileID(info.file), 0.44, 0.83, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function BindIconButton(button, browser, info)
    InitIconButton(button, browser)
    button._iconInfo = info
    if info then
        M.Catalog.ApplyToTexture(button.Icon, info)
        button.SelectedTexture:SetShown(browser.selectedFile ~= nil and info.file == browser.selectedFile)
    else
        button.Icon:SetTexture(134400)
        button.SelectedTexture:Hide()
    end
end

local function CreateVirtualProvider(browser)
    local provider = CreateFromMixins(CallbackRegistryMixin)
    provider:GenerateCallbackEvents({ "OnSizeChanged" })
    provider:OnLoad()

    function provider:GetSize()
        return browser:GetVisibleCount()
    end

    function provider:Find(index)
        return browser:GetVisibleInfo(index)
    end

    function provider:Enumerate(i, j)
        i = i and (i - 1) or 0
        j = j or self:GetSize()
        return function(_, k)
            k = k + 1
            if k <= j then
                return k, browser:GetVisibleInfo(k)
            end
        end, nil, i
    end

    function provider:IsVirtual()
        return true
    end

    return provider
end

local function AddCategoryCheckbox(parent, label, category, browser)
    parent:CreateCheckbox(label, function()
        return browser.filterCategories[category] == true
    end, function()
        browser:ToggleCategory(category)
    end)
end

local function AddCategoryList(parent, list, browser)
    for i = 1, #list do
        local entry = list[i]
        if entry.category then
            AddCategoryCheckbox(parent, entry.label, entry.category, browser)
        end
    end
end

-- Mixin first in Create: SetDataProvider and SetupMenu call these methods
-- synchronously, so they must exist before those APIs run.
local BrowserFrameMixin = {}

function BrowserFrameMixin:GetVisibleCount()
    if self.filteredIndices then
        return #self.filteredIndices
    end
    return M.Catalog.GetNumIcons()
end

function BrowserFrameMixin:GetVisibleInfo(proxyIndex)
    if self.filteredIndices then
        local sourceIndex = self.filteredIndices[proxyIndex]
        return sourceIndex and M.Catalog.GetIconInfo(sourceIndex) or nil
    end
    return M.Catalog.GetIconInfo(proxyIndex)
end

function BrowserFrameMixin:IsFiltering()
    return self.searchQuery ~= "" or next(self.filterCategories) ~= nil
end

function BrowserFrameMixin:NotifyProvider()
    if self.provider then
        self.provider:TriggerEvent("OnSizeChanged")
    end
end

function BrowserFrameMixin:CancelSearch()
    if self.searchJob then
        self.searchJob:Cancel()
        self.searchJob = nil
    end
    self.ProgressOverlay:Hide()
end

function BrowserFrameMixin:Rebuild()
    self:CancelSearch()
    if not self:IsFiltering() then
        self.filteredIndices = nil
        self:NotifyProvider()
        return
    end

    local active = {}
    for category, on in pairs(self.filterCategories) do
        if on then
            tinsert(active, category)
        end
    end
    local predicate = M.Catalog.CategoryPredicate(active)
    local query = self.searchQuery
    local results = {}
    local total = M.Catalog.GetNumIcons()
    self.searchTotal = total
    self.searched = 0
    self.ProgressOverlay:Show()
    self.ProgressOverlay.ProgressBar:SetValue(0)

    self.searchJob = OneWoW.ChunkedJob.Start({
        budgetMs = 8,
        run = function(shouldYield)
            local n = 0
            for index, info in M.Catalog.EnumerateIcons() do
                local ok = true
                if predicate and not predicate(index) then
                    ok = false
                end
                if ok and not M.Catalog.NameMatches(info, query) then
                    ok = false
                end
                if ok then
                    tinsert(results, index)
                end
                n = n + 1
                self.searched = n
                OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
            end
        end,
        onProgress = function()
            if self.searchTotal > 0 then
                self.ProgressOverlay.ProgressBar:SetValue(self.searched / self.searchTotal)
            end
        end,
        onComplete = function()
            self.searchJob = nil
            self.filteredIndices = results
            self.ProgressOverlay:Hide()
            self:NotifyProvider()
        end,
        onCancel = function()
            self.searchJob = nil
            self.ProgressOverlay:Hide()
        end,
    })
end

function BrowserFrameMixin:SetSearchQuery(text)
    local query = NormalizeQuery(text)
    if self.searchQuery == query then
        return
    end
    self.searchQuery = query
    self:Rebuild()
end

function BrowserFrameMixin:ToggleCategory(category)
    if self.filterCategories[category] then
        self.filterCategories[category] = nil
    else
        self.filterCategories[category] = true
    end
    self:Rebuild()
end

function BrowserFrameMixin:ClearFilters()
    wipe(self.filterCategories)
    self.searchQuery = ""
    self.SearchBox:SetText("")
    self.SearchBox:RestorePlaceholder()
    self:Rebuild()
end

function BrowserFrameMixin:SetSelectedFile(fileID)
    self.selectedFile = fileID
    self:NotifyProvider()
end

function BrowserFrameMixin:SetupFilterMenu(root)
    local spec = M.Catalog.GetFilterSpec()

    AddCategoryCheckbox(root, SPELLS, spec.ability, self)
    AddCategoryCheckbox(root, ACHIEVEMENTS, spec.achievement, self)
    AddCategoryCheckbox(root, AUCTION_CATEGORY_HOUSING, spec.housing, self)
    root:CreateDivider()

    local classMenu = root:CreateButton(CLASS)
    AddCategoryList(classMenu, spec.classes, self)

    local cultureMenu = root:CreateButton(L["ICONBROWSER_CULTURE"])
    AddCategoryList(cultureMenu, spec.cultures, self)

    local weaponMenu = root:CreateButton(AUCTION_CATEGORY_WEAPONS)
    AddCategoryCheckbox(weaponMenu, AUCTION_CATEGORY_WEAPONS, spec.weaponAll, self)
    weaponMenu:CreateDivider()
    weaponMenu:CreateTitle(MELEE)
    AddCategoryList(weaponMenu, spec.melee, self)
    weaponMenu:CreateDivider()
    weaponMenu:CreateTitle(AUCTION_SUBCATEGORY_RANGED)
    AddCategoryList(weaponMenu, spec.ranged, self)

    local armorMenu = root:CreateButton(AUCTION_CATEGORY_ARMOR)
    AddCategoryList(armorMenu, spec.armorTypes, self)
    armorMenu:CreateDivider()
    armorMenu:CreateTitle(ALL_INVENTORY_SLOTS)
    AddCategoryList(armorMenu, spec.slots, self)

    local magicMenu = root:CreateButton(STRING_SCHOOL_MAGIC)
    AddCategoryList(magicMenu, spec.magic, self)

    local factionMenu = root:CreateButton(FACTION)
    AddCategoryList(factionMenu, spec.factions, self)

    local profMenu = root:CreateButton(TRADE_SKILLS)
    AddCategoryCheckbox(profMenu, TRADE_SKILLS, spec.professionAll, self)
    profMenu:CreateDivider()
    AddCategoryList(profMenu, spec.professions, self)

    local itemMenu = root:CreateButton(ITEMS)
    AddCategoryCheckbox(itemMenu, ITEMS, spec.itemAll, self)
    itemMenu:CreateDivider()
    AddCategoryList(itemMenu, spec.items, self)
end

function BrowserFrameMixin:OnIconSelected(info)
    if not info or not info.file then
        return
    end
    self.selectedFile = info.file
    if self.customSelectCallback then
        self.customSelectCallback(info.file, info)
    end
    local popup = self.popup
    if popup and popup.BorderBox and popup.BorderBox.SelectedIconArea then
        popup.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(info.file)
        popup.selectedIconTexture = info.file
        popup.selectedIconIndex = nil
        if popup.SetSelectedIconText then
            popup:SetSelectedIconText()
        end
        if popup.BorderBox.OkayButton then
            popup.BorderBox.OkayButton:Enable()
        end
    end
    self:NotifyProvider()
end

function BrowserFrameMixin:SyncPopupSelection()
    local popup = self.popup
    if not popup or not popup.BorderBox or not popup.BorderBox.SelectedIconArea then
        return
    end
    local current = popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    if current then
        self:SetSelectedFile(current)
    end
end

function Browser.Create(parent, opts)
    opts = opts or {}
    local stride = opts.stride or DEFAULT_STRIDE
    local width = opts.width
    local height = opts.height

    local frame = CreateFrame("Frame", nil, parent)
    Mixin(frame, BrowserFrameMixin)
    if width and height then
        frame:SetSize(width, height)
    end

    frame.filterCategories = {}
    frame.searchQuery = ""
    frame.filteredIndices = nil
    frame.selectedFile = opts.selectedFile
    frame.customSelectCallback = opts.onSelect
    frame.popup = opts.popup
    frame.stride = stride
    frame.searchJob = nil
    frame.searchTimer = nil
    frame.searched = 0
    frame.searchTotal = 0

    local filter = CreateFrame("DropdownButton", nil, frame, "WowStyle1FilterDropdownTemplate")
    filter:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -2)
    frame.FilterDropdown = filter

    local searchBox = OneWoW_GUI:CreateEditBox(frame, {
        placeholderText = L["SEARCH"],
        height = 22,
        showClear = true,
        onTextChanged = function(text)
            if frame.searchTimer then
                frame.searchTimer:Cancel()
            end
            frame.searchTimer = C_Timer.NewTimer(SEARCH_DELAY, function()
                frame.searchTimer = nil
                frame:SetSearchQuery(text)
            end)
        end,
        onClear = function()
            frame:SetSearchQuery("")
        end,
    })
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    searchBox:SetPoint("RIGHT", filter, "LEFT", -8, 0)
    frame.SearchBox = searchBox

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    frame.Content = content

    local scrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 4)

    local view = CreateScrollBoxListGridView(stride, GRID_PAD, GRID_PAD, GRID_PAD, GRID_PAD)
    view:SetElementSize(CELL, CELL)
    view:SetElementInitializer("Button", function(button, iconInfo)
        BindIconButton(button, frame, iconInfo)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    local anchorsWithBar = {
        AnchorUtil.CreateAnchor("TOPLEFT", content, "TOPLEFT", 0, 0),
        AnchorUtil.CreateAnchor("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -4, 0),
    }
    local anchorsWithoutBar = {
        AnchorUtil.CreateAnchor("TOPLEFT", content, "TOPLEFT", 0, 0),
        AnchorUtil.CreateAnchor("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, anchorsWithBar, anchorsWithoutBar)

    frame.ScrollBox = scrollBox
    frame.ScrollBar = scrollBar
    frame.ScrollView = view

    local overlay = CreateFrame("Frame", nil, content)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(content:GetFrameLevel() + 20)
    overlay:Hide()
    local dim = overlay:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.55)
    local bar = CreateFrame("StatusBar", nil, overlay)
    bar:SetSize(220, 14)
    bar:SetPoint("CENTER")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0, 0.75, 0)
    local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER")
    barText:SetText(SEARCHING)
    overlay.ProgressBar = bar
    frame.ProgressOverlay = overlay

    local provider = CreateVirtualProvider(frame)
    scrollBox:SetDataProvider(provider)
    frame.provider = provider

    filter:SetIsDefaultCallback(function()
        return not frame:IsFiltering()
    end)
    filter:SetDefaultCallback(function()
        frame:ClearFilters()
    end)
    filter:SetupMenu(function(_, rootDescription)
        frame:SetupFilterMenu(rootDescription)
    end)

    frame:SetScript("OnShow", function(myself)
        myself.SearchBox:SetFocus()
        RunNextFrame(function()
            if myself:IsShown() then
                myself:SyncPopupSelection()
            end
        end)
    end)

    frame:SetScript("OnHide", function(myself)
        myself:CancelSearch()
    end)

    return frame
end
