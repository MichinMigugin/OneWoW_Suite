local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.CleanupPreview = ns.CleanupPreview or {}
local CleanupPreview = ns.CleanupPreview

local ipairs = ipairs
local tinsert = tinsert
local format = string.format

local L = ns.L

local KIND_LABELS = {
    orphan_modification = "CLEANUP_KIND_ORPHAN_MOD",
    stale_section_member = "CLEANUP_KIND_STALE_MEMBER",
    stale_section_order = "CLEANUP_KIND_STALE_SECTION_ORDER",
    stale_category_order = "CLEANUP_KIND_STALE_CATEGORY_ORDER",
    stale_display_order = "CLEANUP_KIND_STALE_DISPLAY_ORDER",
}

local KIND_ORDER = {
    "orphan_modification",
    "stale_section_member",
    "stale_section_order",
    "stale_category_order",
    "stale_display_order",
}

local dlg
local renderContent

local function clearChildren(parent)
    if not parent._children then parent._children = {} end
    for _, c in ipairs(parent._children) do
        c:Hide()
        c:SetParent(nil)
    end
    parent._children = {}
end

local function addChild(parent, child)
    parent._children = parent._children or {}
    tinsert(parent._children, child)
end

local function makeText(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), size or 11)
    fs:SetText(text or "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function makeSmallBtn(parent, text, onClick)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = text, height = 20, minWidth = 60 })
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function countSelected(report)
    local n = 0
    for _, item in ipairs(report.items or {}) do
        if item.selected then n = n + 1 end
    end
    return n
end

local function setAllSelected(report, selected)
    for _, item in ipairs(report.items or {}) do
        item.selected = selected
    end
end

local function kindLabel(kind)
    local key = KIND_LABELS[kind]
    return key and L[key] or kind
end

renderContent = function(state)
    local scrollContent = state.scrollContent
    local report = state.report
    clearChildren(scrollContent)

    local y = -4
    local total = #(report.items or {})
    local selected = countSelected(report)

    local header = makeText(scrollContent,
        format(L["CLEANUP_PREVIEW_SUMMARY"], total),
        14, { 1, 0.82, 0 })
    header:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, header)
    y = y - 22

    local sub = makeText(scrollContent,
        format("%s: %d / %d", L["CLEANUP_PREVIEW_SELECTED"], selected, total),
        11, { 0.9, 0.9, 0.9 })
    sub:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, sub)

    local selectAll = makeSmallBtn(scrollContent, L["CLEANUP_PREVIEW_SELECT_ALL"], function()
        setAllSelected(report, true)
        renderContent(state)
    end)
    selectAll:SetPoint("LEFT", sub, "RIGHT", 12, 0)
    addChild(scrollContent, selectAll)

    local selectNone = makeSmallBtn(scrollContent, L["CLEANUP_PREVIEW_SELECT_NONE"], function()
        setAllSelected(report, false)
        renderContent(state)
    end)
    selectNone:SetPoint("LEFT", selectAll, "RIGHT", 6, 0)
    addChild(scrollContent, selectNone)
    y = y - 28

    local grouped = {}
    for _, item in ipairs(report.items or {}) do
        grouped[item.kind] = grouped[item.kind] or {}
        tinsert(grouped[item.kind], item)
    end

    for _, kind in ipairs(KIND_ORDER) do
        local items = grouped[kind]
        if items and #items > 0 then
            local sectionHeader = makeText(scrollContent,
                format("%s (%d)", kindLabel(kind), #items),
                12, { 1, 0.82, 0 })
            sectionHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
            addChild(scrollContent, sectionHeader)
            y = y - 20

            for _, item in ipairs(items) do
                local row = CreateFrame("Frame", nil, scrollContent)
                row:SetSize(scrollContent:GetWidth() - 16, 22)
                row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
                addChild(scrollContent, row)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(24, 24)
                cb:SetPoint("LEFT", row, "LEFT", 0, 0)
                cb:SetChecked(item.selected == true)
                cb:SetScript("OnClick", function(myself)
                    item.selected = myself:GetChecked()
                    renderContent(state)
                end)

                local labelText = item.label or "?"
                if item.detail and item.detail ~= "" then
                    labelText = labelText .. " — " .. item.detail
                end
                local label = makeText(row, labelText, 11)
                label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                label:SetJustifyH("LEFT")

                y = y - 24
            end

            y = y - 6
        end
    end

    scrollContent:SetHeight(math.max(10, -y + 20))
end

function CleanupPreview:Show(report, controller, db)
    if not report then return end
    if not controller then controller = ns.CategoryController end
    if not db then db = ns:GetDB() end

    local state = {
        report = report,
        controller = controller,
        db = db,
    }

    if not dlg then
        dlg = OneWoW_GUI:CreateDialog({
            name   = "OneWoW_Bags_CleanupPreview",
            title  = L["CLEANUP_PREVIEW_TITLE"],
            width  = 640,
            height = 520,
            showScrollFrame = true,
            buttons = {
                { text = CANCEL, onClick = function(f) f:Hide() end },
                { text = L["CLEANUP_PREVIEW_CONFIRM"],
                  color = { 0.2, 0.6, 0.2 },
                  onClick = function(f)
                      if not dlg._state then return end
                      local s = dlg._state
                      local ConfigCleanup = ns.ImportExport and ns.ImportExport.ConfigCleanup
                      if not ConfigCleanup then return end
                      local result = ConfigCleanup:Apply(s.report, s.db)
                      f:Hide()
                      if result and result.removed then
                          local r = result.removed
                          local prefix = L["ADDON_CHAT_PREFIX"]
                          local msg = format(
                              L["CLEANUP_PREVIEW_APPLY_SUCCESS"],
                              r.orphan_modification or 0,
                              r.stale_section_member or 0,
                              r.stale_section_order or 0,
                              r.stale_category_order or 0,
                              r.stale_display_order or 0)
                          print("|cFFFFD100" .. prefix .. "|r " .. msg)
                          if s.controller and s.controller.RefreshUI then
                              s.controller:RefreshUI()
                          end
                          local cmUI = ns.CategoryManagerUI
                          if cmUI and cmUI.RefreshUndoButton then
                              cmUI.RefreshUndoButton()
                          end
                      end
                  end,
                },
            },
        })
    end

    dlg._state = state
    state.scrollContent = dlg.scrollContent
    state.scrollFrame   = dlg.scrollFrame

    renderContent(state)
    dlg.frame:Show()
end

function CleanupPreview:Hide()
    if dlg and dlg.frame then dlg.frame:Hide() end
end
