local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

-- ============================================================================
-- Crafting Orders — Features layout editor
-- ============================================================================
-- Vertical column list (show/hide + CreateReorderDrag), icon-size sliders,
-- hide-have-mats, and the profit price-source picker. Overlay header drag is
-- not in this pass. Features On/Off only enables the existing controls;
-- rebuilding the card stack from that click broke the toggle.
-- ============================================================================

local OneWoW_GUI = OneWoW_GUI

local collapsedCards = {}

local ROW_H = 28
local ROW_GAP = 4

local function CopyOrder(src)
    local out = {}
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function SetControlEnabled(widget, enabled)
    if not widget then return end
    if enabled then
        widget:Enable()
    else
        widget:Disable()
    end
end

local function BuildContent(cardsHost, isEnabled, applyHostHeight)
    local detailEnabled = isEnabled == true
    local function IsDetailEnabled()
        return detailEnabled
    end

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    stack.OnRelayout = applyHostHeight

    local widgets = {
        sliders = {},
    }
    local refreshLayoutWidgets
    local applyEnabled

    local incompat = M:CollectIncompatibleTitles()
    if #incompat > 0 then
        widgets.incompatCard = stack:AddCard("craftingorders:incompat", L["CRAFTORDERS_INCOMPATIBLE_TITLE"], function(content, contentWidth)
            local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            local w = tonumber(contentWidth) or 0
            if w >= 1 then
                fs:SetWidth(w)
            else
                fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
            end
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            fs:SetText(L["CRAFTORDERS_INCOMPATIBLE_BODY"]:format(table.concat(incompat, ", ")))
            return math.max(1, fs:GetStringHeight())
        end)
    end

    stack:AddCard("craftingorders:columns", L["CRAFTORDERS_LAYOUT_COLUMNS"], function(content, contentWidth)
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            hint:SetWidth(w)
        else
            hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        hint:SetText(L["CRAFTORDERS_DRAG_HINT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local host = CreateFrame("Frame", nil, content)
        local hintH = hint:GetStringHeight() or 14
        host:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(hintH + 8))
        host:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(hintH + 8))

        local rows = {}
        local reorderCtrl
        widgets.columnRows = rows

        local function RelayoutRows()
            local y = 0
            for i = 1, #rows do
                rows[i]:ClearAllPoints()
                rows[i]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
                rows[i]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, y)
                y = y - ROW_H - ROW_GAP
            end
            host:SetHeight(math.max(1, -y))
        end

        local function RebuildRows()
            for i = 1, #rows do
                if reorderCtrl then
                    reorderCtrl:Detach(rows[i])
                end
                rows[i]:Hide()
                rows[i]:SetParent(nil)
            end
            wipe(rows)

            local layout = M:GetLayout()
            for i = 1, #layout.order do
                local id = layout.order[i]
                local row = OneWoW_GUI:CreateFrame(host, {
                    height = ROW_H,
                    bgColor = "BG_TERTIARY",
                    borderColor = "BORDER_SUBTLE",
                })
                row:EnableMouse(true)
                row._colId = id

                local cb = OneWoW_GUI:CreateCheckbox(row, {
                    label = M:ColumnLabel(id),
                    checked = layout.hidden[id] ~= true,
                    onClick = function(myself)
                        M:SetColumnHidden(id, not myself:GetChecked())
                    end,
                })
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.cb = cb
                SetControlEnabled(cb, IsDetailEnabled())

                rows[#rows + 1] = row
                if reorderCtrl then
                    reorderCtrl:Attach(row, #rows)
                    row._reorderAttached = true
                    row:EnableMouse(IsDetailEnabled())
                end
            end
            RelayoutRows()
        end

        local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        reorderCtrl = OneWoW_GUI:CreateReorderDrag({
            getItems = function()
                return rows
            end,
            dropIndicator = {
                thickness = 2,
                horizontalPadding = 4,
                color = { r, g, b, 1 },
            },
            onReorder = function(fromIdx, toIdx, insertBefore)
                local destIdx = insertBefore and toIdx or (toIdx + 1)
                if destIdx > fromIdx then
                    destIdx = destIdx - 1
                end
                if destIdx == fromIdx then
                    return
                end
                local order = CopyOrder(M:GetLayout().order)
                local id = tremove(order, fromIdx)
                tinsert(order, destIdx, id)
                M:SetColumnOrder(order)
                RebuildRows()
                stack:Relayout()
            end,
            onPickup = function(row)
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end,
            onRestore = function(row)
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end,
        })
        widgets.reorderCtrl = reorderCtrl

        RebuildRows()

        local resetBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = RESET,
            height = 22,
        })
        resetBtn:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -8)
        resetBtn:SetScript("OnClick", function()
            M:ResetLayout()
            if refreshLayoutWidgets then
                refreshLayoutWidgets()
            end
        end)
        SetControlEnabled(resetBtn, IsDetailEnabled())
        widgets.resetBtn = resetBtn

        refreshLayoutWidgets = function()
            RebuildRows()
            local layout = M:GetLayout()
            for i = 1, #widgets.sliders do
                local sl = widgets.sliders[i]
                sl.slider:SetValue(layout.sizes[sl._sizeKey])
            end
            if widgets.hideHaveCb then
                widgets.hideHaveCb:SetChecked(layout.hideHaveMats == true)
            end
            if widgets.profitDd then
                local src = M:GetPriceSource()
                widgets.profitDd._activeValue = src
                widgets.profitDdText:SetText(M:PriceSourceLabel(src))
                widgets.profitIcon:SetTexture(M:PriceSourceIcon(src))
            end
            stack:Relayout()
        end

        return hintH + 8 + host:GetHeight() + 8 + 22
    end)

    stack:AddCard("craftingorders:sizes", L["CRAFTORDERS_LAYOUT_SIZES"], function(content, _)
        wipe(widgets.sliders)
        local layout = M:GetLayout()
        local y = 0
        local keys = {
            { key = "product", label = L["CRAFTORDERS_SIZE_ITEM"] },
            { key = "you", label = L["CRAFTORDERS_SIZE_YOU"] },
            { key = "customer", label = L["CRAFTORDERS_SIZE_CUSTOMER"] },
            { key = "reward", label = L["CRAFTORDERS_SIZE_REWARD"] },
        }
        local lane = M:LaneConstants()
        widgets.sizeLabels = {}
        for i = 1, #keys do
            local spec = keys[i]
            local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            lbl:SetText(spec.label)
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
            widgets.sizeLabels[#widgets.sizeLabels + 1] = lbl
            y = y - (lbl:GetStringHeight() or 14) - 4

            local sl = OneWoW_GUI:CreateSlider(content, {
                minVal = lane.sizeMin,
                maxVal = lane.sizeMax,
                step = 1,
                currentVal = layout.sizes[spec.key],
                width = 240,
                fmt = "%.0f",
                onChange = function(val)
                    M:SetIconSize(spec.key, val)
                end,
            })
            sl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            sl._sizeKey = spec.key
            SetControlEnabled(sl.slider, IsDetailEnabled())
            widgets.sliders[#widgets.sliders + 1] = sl
            y = y - 42
        end
        return math.max(1, -y)
    end)

    stack:AddCard("craftingorders:mats", L["CRAFTORDERS_LAYOUT_MATS"], function(content, contentWidth)
        local layout = M:GetLayout()
        local cb = OneWoW_GUI:CreateCheckbox(content, {
            label = L["CRAFTORDERS_HIDE_HAVE"],
            checked = layout.hideHaveMats == true,
            onClick = function(myself)
                M:SetHideHaveMats(myself:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        SetControlEnabled(cb, IsDetailEnabled())
        widgets.hideHaveCb = cb

        local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -32)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            desc:SetWidth(w)
        else
            desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -32)
        end
        desc:SetText(L["CRAFTORDERS_HIDE_HAVE_DESC"])
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        return 32 + (desc:GetStringHeight() or 14)
    end)

    stack:AddCard("craftingorders:profit", L["CRAFTORDERS_LAYOUT_PROFIT"], function(content, _)
        local src = M:GetPriceSource()
        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
        icon:SetTexture(M:PriceSourceIcon(src))
        widgets.profitIcon = icon

        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        lbl:SetText(L["CRAFTORDERS_PROFIT_SOURCE"])
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor(IsDetailEnabled() and "TEXT_PRIMARY" or "TEXT_MUTED"))
        widgets.profitLbl = lbl

        local dd, ddText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            height = 26,
            text = M:PriceSourceLabel(src),
        })
        dd:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -28)
        dd._activeValue = src
        OneWoW_GUI:AttachFilterMenu(dd, {
            searchable = false,
            menuHeight = 140,
            buildItems = function()
                local items = {}
                local list = M:DetectedPriceSources()
                for i = 1, #list do
                    local id = list[i]
                    items[#items + 1] = { value = id, text = M:PriceSourceLabel(id) }
                end
                return items
            end,
            getActiveValue = function()
                return M:GetPriceSource()
            end,
            onSelect = function(value, text)
                M:SetPriceSource(value)
                dd._activeValue = value
                ddText:SetText(text)
                icon:SetTexture(M:PriceSourceIcon(value))
                M:ApplyOverlayLayout()
            end,
        })
        widgets.profitDd = dd
        widgets.profitDdText = ddText
        if IsDetailEnabled() then
            dd:Enable()
            ddText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            dd:Disable()
            ddText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        return 28 + 26 + 4
    end)

    applyEnabled = function(enabled)
        detailEnabled = enabled == true
        local rows = widgets.columnRows
        if rows then
            for i = 1, #rows do
                local row = rows[i]
                SetControlEnabled(row.cb, detailEnabled)
                row:EnableMouse(detailEnabled)
            end
        end
        SetControlEnabled(widgets.resetBtn, detailEnabled)
        for i = 1, #widgets.sliders do
            SetControlEnabled(widgets.sliders[i].slider, detailEnabled)
        end
        if widgets.sizeLabels then
            local color = detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"
            for i = 1, #widgets.sizeLabels do
                widgets.sizeLabels[i]:SetTextColor(OneWoW_GUI:GetThemeColor(color))
            end
        end
        SetControlEnabled(widgets.hideHaveCb, detailEnabled)
        if widgets.profitLbl then
            widgets.profitLbl:SetTextColor(OneWoW_GUI:GetThemeColor(detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
        if widgets.profitDd then
            SetControlEnabled(widgets.profitDd, detailEnabled)
            widgets.profitDdText:SetTextColor(OneWoW_GUI:GetThemeColor(detailEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end

        local incompatCard = widgets.incompatCard
        if incompatCard then
            local titles = M:CollectIncompatibleTitles()
            if #titles == 0 then
                incompatCard:Hide()
                for i = 1, #stack.items do
                    if stack.items[i] == incompatCard then
                        tremove(stack.items, i)
                        break
                    end
                end
                widgets.incompatCard = nil
                stack:Relayout()
            end
        end
    end

    stack:Finish()
    return stack, applyEnabled, refreshLayoutWidgets
end

function M:CreateCustomDetail(parent, yOffset, isEnabled, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, parent)
    cardsHost:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if parent.UpdateDetailHeight then
            parent:SetHeight(h)
            parent.UpdateDetailHeight()
        else
            parent:SetHeight(math.abs(yOffset) + h + 20)
            if parent.updateThumb then
                parent.updateThumb()
            end
        end
    end

    local _, applyEnabled, refreshLayoutWidgets = BuildContent(cardsHost, isEnabled, applyHostHeight)
    applyHostHeight()
    M._refreshCustomDetail = refreshLayoutWidgets

    if registerRefresh then
        registerRefresh(function()
            if applyEnabled then
                applyEnabled(ns.ModuleRegistry:IsEnabled("craftingorders"))
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
