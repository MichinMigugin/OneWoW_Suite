local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.ImportPreview = OneWoW_Bags.ImportPreview or {}
local ImportPreview = OneWoW_Bags.ImportPreview

local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local tinsert, tconcat = table.insert, table.concat
local sort = table.sort
local format = string.format

local L = OneWoW_Bags.L

local function getLoc(key, fallback)
    local s = L and L[key]
    if s and s ~= "" then return s end
    return fallback or key
end

-- ------------------------------------------------------------------
-- Summary helpers
-- ------------------------------------------------------------------

local function countPlan(plan)
    local sectionsNew, sectionsMerge = 0, 0
    for _, sec in pairs(plan.sections) do
        if sec.isNew then sectionsNew = sectionsNew + 1
        else sectionsMerge = sectionsMerge + 1 end
    end

    local catsNew, renamed, merged, skipped = 0, 0, 0, 0
    local itemsTotal = 0
    for _, cat in pairs(plan.categories) do
        if cat.items then
            for _ in pairs(cat.items) do itemsTotal = itemsTotal + 1 end
        end
        if cat.isNew then
            catsNew = catsNew + 1
        elseif cat.resolution == "skip" then
            skipped = skipped + 1
        elseif cat.resolution == "merge" then
            merged = merged + 1
        elseif cat.resolution == "rename" then
            renamed = renamed + 1
        end
    end

    local kept = 0
    for _, def in ipairs(plan.unmappedDefaults or {}) do
        if def.resolution == "keep" then kept = kept + 1 end
    end

    return {
        sectionsNew = sectionsNew, sectionsMerge = sectionsMerge,
        catsNew = catsNew, renamed = renamed, merged = merged, skipped = skipped,
        itemsTotal = itemsTotal, unmappedKept = kept,
    }
end

local function sourceLabel(source)
    local map = {
        baganator_direct = getLoc("IMPORT_SRC_BAGANATOR_DIRECT", "Import from Baganator (direct)"),
        baganator_string = getLoc("IMPORT_SRC_BAGANATOR_PASTE",  "Import from Baganator (paste)"),
        tsm_direct       = getLoc("IMPORT_SRC_TSM_DIRECT",       "Import from TSM (direct)"),
        onewow_string    = getLoc("IMPORT_SRC_ONEWOW_PASTE",     "Import from OneWoW string"),
    }
    return map[source] or tostring(source)
end

-- ------------------------------------------------------------------
-- Dialog state (module-scoped singleton)
-- ------------------------------------------------------------------

local dlg
local renderContent

-- ------------------------------------------------------------------
-- Rendering
-- ------------------------------------------------------------------

local RES_SEQUENCE = { "rename", "skip", "merge" }
local UNMAPPED_SEQUENCE = { "keep", "ignore" }
local RULE_SEQUENCE = { "use_translated", "skip_rule", "snapshot_items" }

local function cycleValue(seq, current)
    for i, v in ipairs(seq) do
        if v == current then
            return seq[(i % #seq) + 1]
        end
    end
    return seq[1]
end

local function resolutionLabel(r)
    if r == "skip"   then return getLoc("IMPORT_CONFLICT_SKIP",   "Skip") end
    if r == "merge"  then return getLoc("IMPORT_CONFLICT_MERGE",  "Merge") end
    if r == "rename" then return getLoc("IMPORT_CONFLICT_RENAME", "Rename") end
    return "Create"
end

local function ruleLabel(r)
    if r == "skip_rule"     then return getLoc("IMPORT_RULE_SKIP",       "Skip rule") end
    if r == "snapshot_items" then return getLoc("IMPORT_RULE_SNAPSHOT",  "Snapshot items") end
    return getLoc("IMPORT_RULE_USE_TRANSLATED", "Use translated")
end

local function unmappedLabel(r)
    if r == "keep" then return getLoc("IMPORT_UNMAPPED_KEEP", "Keep") end
    return getLoc("IMPORT_UNMAPPED_IGNORE", "Ignore")
end

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

local function makeEditBox(parent, width, initial)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlight")
    eb:SetMaxLetters(64)
    eb:SetTextInsets(5, 5, 0, 0)
    eb:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    eb:SetBackdropColor(0, 0, 0, 0.7)
    eb:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    eb:SetText(initial or "")
    return eb
end

-- Render the single scrollable content region. This is re-invoked whenever
-- the plan state changes (user toggles a resolution, enters rename text,
-- applies a bulk action) so the summary stays accurate.
renderContent = function(state)
    local scrollContent = state.scrollContent
    clearChildren(scrollContent)

    local y = -4

    -- ---------- Header / summary ----------
    local counts = countPlan(state.plan)
    local header = makeText(scrollContent, sourceLabel(state.plan.source), 14, { 1, 0.82, 0 })
    header:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, header)
    y = y - 20

    local stats = makeText(scrollContent,
        format("%s: %d | %s: %d | %s: %d",
            getLoc("IMPORT_PREVIEW_SECTIONS",   "Sections"),   counts.sectionsNew + counts.sectionsMerge,
            getLoc("IMPORT_PREVIEW_CATEGORIES", "Categories"), counts.catsNew + counts.renamed + counts.merged,
            getLoc("IMPORT_PREVIEW_ITEMS",      "Items"),      counts.itemsTotal),
        11, { 0.9, 0.9, 0.9 })
    stats:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, stats)
    y = y - 20

    -- ---------- Locale / version warning ----------
    local warnCount = 0
    for _, w in ipairs(state.plan.warnings) do
        if w.severity ~= "info" then warnCount = warnCount + 1 end
    end

    if #state.plan.warnings > 0 then
        local warnHeader = makeText(scrollContent,
            format("%s (%d)", getLoc("IMPORT_PREVIEW_WARNINGS", "Warnings"), #state.plan.warnings),
            12, { 1, 0.6, 0.2 })
        warnHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
        addChild(scrollContent, warnHeader)
        y = y - 18

        for _, w in ipairs(state.plan.warnings) do
            local col = { 0.9, 0.9, 0.5 }
            if w.severity == "error" then col = { 1, 0.3, 0.3 }
            elseif w.severity == "warn" then col = { 1, 0.8, 0.3 } end
            local fs = makeText(scrollContent, "  - " .. (w.text or ""), 10, col)
            fs:SetWidth(scrollContent:GetWidth() - 20)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
            addChild(scrollContent, fs)
            y = y - (fs:GetStringHeight() + 4)
        end
        y = y - 6
    end

    -- ---------- Bulk apply-to-all bar ----------
    local bulkLabel = makeText(scrollContent, getLoc("IMPORT_APPLY_TO_ALL_LABEL", "Apply to conflicts:"), 11)
    bulkLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, bulkLabel)

    local bulkButtons = {
        { txt = getLoc("IMPORT_APPLY_ALL_SKIP",   "Skip all"),   val = "skip" },
        { txt = getLoc("IMPORT_APPLY_ALL_RENAME", "Rename all"), val = "rename" },
        { txt = getLoc("IMPORT_APPLY_ALL_MERGE",  "Merge all"),  val = "merge" },
    }
    local lastAnchor
    for _, def in ipairs(bulkButtons) do
        local btn = makeSmallBtn(scrollContent, def.txt, function()
            for _, cat in pairs(state.plan.categories) do
                if not cat.isNew and not cat.manualOverride then
                    cat.resolution = def.val
                end
            end
            renderContent(state)
        end)
        if not lastAnchor then
            btn:SetPoint("LEFT", bulkLabel, "RIGHT", 8, 0)
        else
            btn:SetPoint("LEFT", lastAnchor, "RIGHT", 6, 0)
        end
        addChild(scrollContent, btn)
        lastAnchor = btn
    end
    y = y - 26

    -- ---------- Unmapped defaults panel (Baganator-only) ----------
    if state.plan.unmappedDefaults and #state.plan.unmappedDefaults > 0 then
        local h = makeText(scrollContent,
            getLoc("IMPORT_UNMAPPED_PANEL_TITLE", "Baganator default categories without an equivalent"),
            12, { 1, 0.82, 0 })
        h:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
        addChild(scrollContent, h)
        y = y - 18

        local bulkKeep = makeSmallBtn(scrollContent, getLoc("IMPORT_UNMAPPED_KEEP_ALL", "Keep all"), function()
            for _, def in ipairs(state.plan.unmappedDefaults) do def.resolution = "keep" end
            renderContent(state)
        end)
        bulkKeep:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 16, y)
        addChild(scrollContent, bulkKeep)

        local bulkIgnore = makeSmallBtn(scrollContent, getLoc("IMPORT_UNMAPPED_IGNORE_ALL", "Ignore all"), function()
            for _, def in ipairs(state.plan.unmappedDefaults) do def.resolution = "ignore" end
            renderContent(state)
        end)
        bulkIgnore:SetPoint("LEFT", bulkKeep, "RIGHT", 6, 0)
        addChild(scrollContent, bulkIgnore)
        y = y - 22

        for _, def in ipairs(state.plan.unmappedDefaults) do
            local row = makeText(scrollContent,
                format("  %s  [%s]", def.displayName or def.sourceId, def.sourceId),
                10, { 0.9, 0.9, 0.9 })
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 16, y)
            addChild(scrollContent, row)

            local btn = makeSmallBtn(scrollContent, unmappedLabel(def.resolution), function(self)
                def.resolution = cycleValue(UNMAPPED_SEQUENCE, def.resolution)
                self.text:SetText(unmappedLabel(def.resolution))
                renderContent(state)
            end)
            btn:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -12, y + 2)
            addChild(scrollContent, btn)
            y = y - 22
        end
        y = y - 6
    end

    -- ---------- Section tree ----------
    local treeHeader = makeText(scrollContent,
        getLoc("IMPORT_PREVIEW_TREE_TITLE", "Sections & categories"),
        12, { 1, 0.82, 0 })
    treeHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, treeHeader)
    y = y - 18

    -- group categories by plan section using section.categories array; any
    -- category not assigned to a section is rendered under "(no section)".
    local assignedNames = {}
    local sectionIds = {}
    for sid in pairs(state.plan.sections) do tinsert(sectionIds, sid) end
    sort(sectionIds)

    local function renderCategoryRow(cat, indent)
        local name = cat.name or "(unnamed)"
        local tag = cat.isNew and getLoc("IMPORT_TAG_NEW", "new") or getLoc("IMPORT_TAG_CONFLICT", "exists")
        local color = cat.isNew and { 0.6, 1, 0.6 } or { 1, 0.8, 0.3 }
        local itemCount = 0
        if cat.items then for _ in pairs(cat.items) do itemCount = itemCount + 1 end end

        local label = format("%s  [%s]  (%d items)", name, tag, itemCount)
        local fs = makeText(scrollContent, label, 11, color)
        fs:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 16 + indent, y)
        addChild(scrollContent, fs)

        if cat.isNew then
            y = y - 18
        else
            local resBtn = makeSmallBtn(scrollContent, resolutionLabel(cat.resolution), function(self)
                cat.resolution = cycleValue(RES_SEQUENCE, cat.resolution)
                cat.manualOverride = true
                self.text:SetText(resolutionLabel(cat.resolution))
                renderContent(state)
            end)
            resBtn:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -12, y + 2)
            addChild(scrollContent, resBtn)

            if cat.resolution == "rename" then
                local prefixBox = makeEditBox(scrollContent, 70, cat.renamePrefix or "")
                prefixBox:SetPoint("RIGHT", resBtn, "LEFT", -6, 0)
                prefixBox:SetScript("OnTextChanged", function(eb)
                    cat.renamePrefix = eb:GetText()
                end)
                addChild(scrollContent, prefixBox)
            end
            y = y - 22
        end

        if cat.originalSearchExpression and cat.originalSearchExpression ~= "" then
            local ruleBtn = makeSmallBtn(scrollContent, ruleLabel(cat.ruleHandling), function(self)
                cat.ruleHandling = cycleValue(RULE_SEQUENCE, cat.ruleHandling)
                self.text:SetText(ruleLabel(cat.ruleHandling))
                renderContent(state)
            end)
            ruleBtn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 32 + indent, y)
            addChild(scrollContent, ruleBtn)

            local originalText = makeText(scrollContent, "rule: " .. cat.originalSearchExpression, 10, { 0.7, 0.7, 0.9 })
            originalText:SetPoint("LEFT", ruleBtn, "RIGHT", 8, 0)
            originalText:SetWidth(scrollContent:GetWidth() - 200 - indent)
            originalText:SetJustifyH("LEFT")
            addChild(scrollContent, originalText)
            y = y - 20
        end
    end

    for _, sid in ipairs(sectionIds) do
        local sec = state.plan.sections[sid]
        local secLabel = sec.isNew
            and format("+ %s  [%s]", sec.name or "", getLoc("IMPORT_TAG_NEW", "new"))
            or  format("= %s  [%s]", sec.name or "", getLoc("IMPORT_TAG_MERGE", "merge"))
        local color = sec.isNew and { 0.7, 1, 0.7 } or { 0.7, 0.9, 1 }
        local sfs = makeText(scrollContent, secLabel, 12, color)
        sfs:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 12, y)
        addChild(scrollContent, sfs)
        y = y - 18

        for _, catName in ipairs(sec.categories or {}) do
            assignedNames[catName] = true
            -- find the plan category by name
            for _, cat in pairs(state.plan.categories) do
                if cat.name == catName then
                    renderCategoryRow(cat, 16)
                    break
                end
            end
        end
    end

    -- Categories not assigned to any section (loose)
    local loose = {}
    for _, cat in pairs(state.plan.categories) do
        if not assignedNames[cat.name] then tinsert(loose, cat) end
    end
    if #loose > 0 then
        local lh = makeText(scrollContent, getLoc("IMPORT_LOOSE_CATEGORIES", "Categories (no section)"), 12, { 0.9, 0.9, 0.6 })
        lh:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 12, y)
        addChild(scrollContent, lh)
        y = y - 18
        sort(loose, function(a, b) return (a.name or "") < (b.name or "") end)
        for _, cat in ipairs(loose) do
            renderCategoryRow(cat, 16)
        end
    end

    -- ---------- Bottom summary ----------
    y = y - 8
    local summary = makeText(scrollContent,
        format("%s  new:%d rename:%d merge:%d skip:%d  items:%d",
            getLoc("IMPORT_SUMMARY", "Summary:"),
            counts.catsNew, counts.renamed, counts.merged, counts.skipped, counts.itemsTotal),
        11, { 1, 0.82, 0 })
    summary:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, summary)
    y = y - 20

    scrollContent:SetHeight(math.max(10, -y + 20))

    -- Live-update footer if present
    if state.footerFS then
        state.footerFS:SetText(format("%s  new:%d  rename:%d  merge:%d  skip:%d  items:%d",
            getLoc("IMPORT_SUMMARY", "Summary:"),
            counts.catsNew, counts.renamed, counts.merged, counts.skipped, counts.itemsTotal))
    end
end

-- ------------------------------------------------------------------
-- Show
-- ------------------------------------------------------------------

function ImportPreview:Show(plan, controller, db)
    if not plan then return end
    if not controller then controller = OneWoW_Bags.CategoryController end
    if not db then db = OneWoW_Bags:GetDB() end

    local state = {
        plan = plan,
        controller = controller,
        db = db,
    }

    if not dlg then
        dlg = OneWoW_GUI:CreateDialog({
            name   = "OneWoW_Bags_ImportPreview",
            title  = getLoc("IMPORT_PREVIEW_TITLE", "Import Preview"),
            width  = 640,
            height = 520,
            showScrollFrame = true,
            buttons = {
                { text = getLoc("IMPORT_CANCEL", "Cancel"), onClick = function(f) f:Hide() end },
                { text = getLoc("IMPORT_APPLY",  "Import"),
                  color = { 0.2, 0.6, 0.2 },
                  onClick = function(f)
                      if not dlg._state then return end
                      local s = dlg._state
                      for _, cat in pairs(s.plan.categories) do
                          if cat.originalSearchExpression and cat.ruleHandling == "skip_rule" then
                              cat.filterMode = "items"
                              cat.searchExpression = nil
                          elseif cat.originalSearchExpression and cat.ruleHandling == "snapshot_items" then
                              cat.filterMode = "items"
                              cat.searchExpression = nil
                          end
                      end
                      local Applier = OneWoW_Bags.ImportExport.Applier
                      local result = Applier:Apply(s.plan, s.controller, s.db)
                      f:Hide()
                      if result then
                          local prefix = getLoc("ADDON_CHAT_PREFIX", "OneWoW Bags:")
                          local msg = format(
                              getLoc("IMPORT_SUCCESS_COUNTS",
                                  "Import complete. Sections new:%d merged:%d | Categories new:%d renamed:%d merged:%d skipped:%d"),
                              result.sectionsNew or 0, result.sectionsMerged or 0,
                              result.categoriesNew or 0, result.categoriesRenamed or 0,
                              result.categoriesMerged or 0, result.categoriesSkipped or 0)
                          print("|cFFFFD100" .. prefix .. "|r " .. msg)
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

function ImportPreview:Hide()
    if dlg and dlg.frame then dlg.frame:Hide() end
end
