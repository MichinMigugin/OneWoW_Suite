local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.ImportPreview = ns.ImportPreview or {}
local ImportPreview = ns.ImportPreview

local pairs, ipairs, tostring = pairs, ipairs, tostring
local tinsert, sort = tinsert, sort
local format = format

local L = ns.L
local GameTooltip = GameTooltip

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
        baganator_direct = L["IMPORT_SRC_BAGANATOR_DIRECT"],
        baganator_string = L["IMPORT_SRC_BAGANATOR_PASTE"],
        tsm_direct       = L["IMPORT_SRC_TSM_DIRECT"],
        onewow_string    = L["IMPORT_SRC_ONEWOW_PASTE"],
    }
    return map[source] or tostring(source)
end

-- ------------------------------------------------------------------
-- Dialog state (module-scoped singleton)
-- ------------------------------------------------------------------

local dlg
-- Catalog entries arrive as a plan from core: create / merge / conflict. Merge is
-- a no-op (identical bodies) and needs no row; create only needs one when it
-- reclaims a retired name. A conflict is the only case that cannot be decided
-- without the user, and until this UI existed it was silently skipped.
local CATALOG_REF = {
    token = function(name) return "#" .. (name or "?") end,
    saved = function(name) return "SAVED(" .. (name or "?") .. ")" end,
}

local function catalogRef(item)
    local fn = CATALOG_REF[item.kind or ""]
    return fn and fn(item.name) or tostring(item.name)
end

local CONFLICT_SEQUENCE = { "import_as_new", "keep_mine" }

local function conflictLabel(action)
    return action == "keep_mine"
        and L["IMPORT_PREVIEW_CATALOG_KEEP_MINE"]
        or L["IMPORT_PREVIEW_CATALOG_AS_NEW"]
end

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
    if r == "skip"   then return L["IMPORT_PREVIEW_RES_SKIP"] end
    if r == "merge"  then return L["IMPORT_PREVIEW_RES_MERGE"] end
    if r == "rename" then return L["RENAME"] end
    return L["CREATE"]
end

local function ruleLabel(r)
    if r == "skip_rule"      then return L["IMPORT_PREVIEW_RULE_SKIP"] end
    if r == "snapshot_items" then return L["IMPORT_PREVIEW_RULE_SNAPSHOT"] end
    return L["IMPORT_PREVIEW_RULE_USE_TRANSLATED"]
end

local function ruleTooltipKey(r)
    if r == "skip_rule"      then return "IMPORT_PREVIEW_RULE_SKIP_TIP" end
    if r == "snapshot_items" then return "IMPORT_PREVIEW_RULE_SNAPSHOT_TIP" end
    return "IMPORT_PREVIEW_RULE_USE_TRANSLATED_TIP"
end

local function attachRuleTooltip(btn, cat)
    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(ruleLabel(cat.ruleHandling), 1, 1, 1)
        GameTooltip:AddLine(L[ruleTooltipKey(cat.ruleHandling)], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["IMPORT_PREVIEW_RULE_CYCLE_HINT"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function unmappedLabel(r)
    if r == "keep" then return L["KEEP"] end
    return IGNORE
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
    local eb = OneWoW_GUI:CreateEditBox(parent, {
        width = width,
        height = 20,
        maxLetters = 64,
        placeholderText = "",
    })
    eb:SetText(initial or "")
    eb:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
            L["IMPORT_PREVIEW_STAT_SECTIONS"],   counts.sectionsNew + counts.sectionsMerge,
            CATEGORIES, counts.catsNew + counts.renamed + counts.merged,
            ITEMS,      counts.itemsTotal),
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
            format("%s (%d)", L["IMPORT_PREVIEW_WARNINGS"], #state.plan.warnings),
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
    local bulkLabel = makeText(scrollContent, L["IMPORT_PREVIEW_BULK_LABEL"], 11)
    bulkLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, bulkLabel)

    local bulkButtons = {
        { txt = L["IMPORT_PREVIEW_BULK_SKIP"],   val = "skip" },
        { txt = L["IMPORT_PREVIEW_BULK_RENAME"], val = "rename" },
        { txt = L["IMPORT_PREVIEW_BULK_MERGE"],  val = "merge" },
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
            L["IMPORT_PREVIEW_UNMAPPED_TITLE"],
            12, { 1, 0.82, 0 })
        h:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
        addChild(scrollContent, h)
        y = y - 18

        local bulkKeep = makeSmallBtn(scrollContent, L["IMPORT_PREVIEW_UNMAPPED_KEEP_ALL"], function()
            for _, def in ipairs(state.plan.unmappedDefaults) do def.resolution = "keep" end
            renderContent(state)
        end)
        bulkKeep:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 16, y)
        addChild(scrollContent, bulkKeep)

        local bulkIgnore = makeSmallBtn(scrollContent, L["IMPORT_PREVIEW_UNMAPPED_IGNORE_ALL"], function()
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
        L["IMPORT_PREVIEW_TREE_TITLE"],
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
        local name = cat.name or L["IMPORT_PREVIEW_CATEGORY_UNNAMED"]
        local tag = cat.isNew and L["IMPORT_PREVIEW_TAG_NEW"] or L["IMPORT_PREVIEW_TAG_EXISTS"]
        local color = cat.isNew and { 0.6, 1, 0.6 } or { 1, 0.8, 0.3 }
        local itemCount = 0
        if cat.items then for _ in pairs(cat.items) do itemCount = itemCount + 1 end end

        local label = format("%s  [%s]  %s", name, tag, format(L["IMPORT_PREVIEW_CATEGORY_ITEM_COUNT"], itemCount))
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
            attachRuleTooltip(ruleBtn, cat)

            local originalText = makeText(scrollContent, format(L["IMPORT_PREVIEW_RULE_LINE"], cat.originalSearchExpression), 10, { 0.7, 0.7, 0.9 })
            originalText:SetPoint("LEFT", ruleBtn, "RIGHT", 8, 0)
            originalText:SetWidth(scrollContent:GetWidth() - 200 - indent)
            originalText:SetJustifyH("LEFT")
            addChild(scrollContent, originalText)
            -- 20px button + 8px breathing room before the next row
            y = y - 28
        end

        y = y - 4
    end

    for idx, sid in ipairs(sectionIds) do
        local sec = state.plan.sections[sid]
        if idx > 1 then
            y = y - 6
        end
        local secLabel = sec.isNew
            and format("+ %s  [%s]", sec.name or "", L["IMPORT_PREVIEW_TAG_NEW"])
            or  format("= %s  [%s]", sec.name or "", L["IMPORT_PREVIEW_TAG_MERGE"])
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
        local lh = makeText(scrollContent, L["IMPORT_PREVIEW_LOOSE_CATEGORIES"], 12, { 0.9, 0.9, 0.6 })
        lh:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 12, y)
        addChild(scrollContent, lh)
        y = y - 18
        sort(loose, function(a, b) return (a.name or "") < (b.name or "") end)
        for _, cat in ipairs(loose) do
            renderCategoryRow(cat, 16)
        end
    end

    -- ---------- Catalog entries ----------
    local catalogRows = {}
    for _, item in ipairs(state.plan.catalogPlan or {}) do
        if item.action == "conflict" or item.action == "import_as_new"
            or item.action == "keep_mine" or item.reclaims then
            tinsert(catalogRows, item)
        end
    end

    if #catalogRows > 0 then
        y = y - 10
        local ch = makeText(scrollContent, L["IMPORT_PREVIEW_CATALOG_HEADER"], 12, { 0.9, 0.9, 0.6 })
        ch:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 12, y)
        addChild(scrollContent, ch)
        y = y - 18

        for _, item in ipairs(catalogRows) do
            if item.reclaims then
                -- A create that takes back a name some entry retired. Not a
                -- choice — it is what importing this payload means — but it
                -- silently changes what older text pointing at that name hits.
                local rf = makeText(scrollContent,
                    format(L["IMPORT_PREVIEW_CATALOG_RECLAIMS"], catalogRef(item), item.reclaims),
                    11, { 1, 0.65, 0 })
                rf:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 28, y)
                rf:SetWidth(scrollContent:GetWidth() - 48)
                rf:SetJustifyH("LEFT")
                addChild(scrollContent, rf)
                y = y - 20
            else
                if item.action == "conflict" then
                    item.action = "import_as_new"
                    item.newName = item.newName or item.suggestedName
                end

                local label = makeText(scrollContent,
                    format(L["IMPORT_PREVIEW_CATALOG_CONFLICT"], catalogRef(item)),
                    11, { 0.9, 0.9, 0.9 })
                label:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 28, y)
                addChild(scrollContent, label)
                y = y - 18

                local resBtn = makeSmallBtn(scrollContent, conflictLabel(item.action), function(self)
                    item.action = cycleValue(CONFLICT_SEQUENCE, item.action)
                    self.text:SetText(conflictLabel(item.action))
                    renderContent(state)
                end)
                resBtn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 44, y)
                addChild(scrollContent, resBtn)

                if item.action == "import_as_new" then
                    local nameBox = makeEditBox(scrollContent, 180, item.newName or "")
                    nameBox:SetPoint("LEFT", resBtn, "RIGHT", 8, 0)
                    nameBox:SetScript("OnTextChanged", function(eb)
                        item.newName = eb:GetText()
                    end)
                    addChild(scrollContent, nameBox)
                end
                y = y - 24
            end
        end
    end

    -- ---------- Bottom summary ----------
    y = y - 8
    local summary = makeText(scrollContent,
        format("%s  new:%d rename:%d merge:%d skip:%d  items:%d",
            L["IMPORT_PREVIEW_SUMMARY_LABEL"],
            counts.catsNew, counts.renamed, counts.merged, counts.skipped, counts.itemsTotal),
        11, { 1, 0.82, 0 })
    summary:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, y)
    addChild(scrollContent, summary)
    y = y - 20

    scrollContent:SetHeight(math.max(10, -y + 20))

    -- Live-update footer if present
    if state.footerFS then
        state.footerFS:SetText(format("%s  new:%d  rename:%d  merge:%d  skip:%d  items:%d",
            L["IMPORT_PREVIEW_SUMMARY_LABEL"],
            counts.catsNew, counts.renamed, counts.merged, counts.skipped, counts.itemsTotal))
    end
end

-- ------------------------------------------------------------------
-- Show
-- ------------------------------------------------------------------

function ImportPreview:Show(plan, controller, db)
    if not plan then return end
    if not controller then controller = ns.CategoryController end
    if not db then db = ns:GetDB() end

    local state = {
        plan = plan,
        controller = controller,
        db = db,
    }

    if not dlg then
        dlg = OneWoW_GUI:CreateDialog({
            name   = "OneWoW_Bags_ImportPreview",
            title  = L["IMPORT_PREVIEW_TITLE"],
            width  = 640,
            height = 520,
            showScrollFrame = true,
            buttons = {
                { text = CANCEL, onClick = function(f) f:Hide() end },
                { text = L["IMPORT_PREVIEW_CONFIRM"],
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
                      local Applier = ns.ImportExport.Applier
                      local result = Applier:Apply(s.plan, s.controller, s.db)
                      f:Hide()
                      if result then
                          local prefix = L["ADDON_CHAT_PREFIX"]
                          local msg = format(
                              L["IMPORT_PREVIEW_APPLY_SUCCESS"],
                              result.sectionsNew or 0, result.sectionsMerged or 0,
                              result.categoriesNew or 0, result.categoriesRenamed or 0,
                              result.categoriesMerged or 0, result.categoriesSkipped or 0)
                          print("|cFFFFD100" .. prefix .. "|r " .. msg)
                          if (result.savedSearchesMerged or 0) > 0 then
                              print("|cFFFFD100" .. prefix .. "|r " .. format(
                                  L["IMPORT_RESULT_SAVED_SEARCHES"],
                                  result.savedSearchesMerged))
                          end
                          if (result.displayOrderDropped or 0) > 0 then
                              print("|cFFFFD100" .. prefix .. "|r " .. format(
                                  L["IMPORT_RESULT_DISPLAY_ORDER_PARTIAL"],
                                  result.displayOrderDropped))
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

function ImportPreview:Hide()
    if dlg and dlg.frame then dlg.frame:Hide() end
end
