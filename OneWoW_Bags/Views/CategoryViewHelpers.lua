local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L

local tremove, tinsert, wipe = tremove, tinsert, wipe
local pairs, ipairs = pairs, ipairs
local floor, min, max, ceil, sqrt = math.floor, math.min, math.max, math.ceil, math.sqrt
local tostring = tostring

OneWoW_Bags.CategoryViewHelpers = {}
local H = OneWoW_Bags.CategoryViewHelpers

function H.CreateLabelPool()
    local pool = {}
    local active = {}

    local function Acquire(parent)
        local label
        if #pool > 0 then
            label = tremove(pool)
            label:SetParent(parent)
        else
            label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
        end
        label:ClearAllPoints()
        label:Show()
        active[label] = true
        return label
    end

    local function ReleaseAll()
        for label in pairs(active) do
            label:Hide()
            label:ClearAllPoints()
            tinsert(pool, label)
        end
        wipe(active)
    end

    return Acquire, ReleaseAll
end

function H.ResolveCategoryName(categoryName)
    local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
    return L[localeKey] or categoryName
end

function H.ApplyCategoryColor(fontString, catMods, categoryName)
    local catMod = catMods[categoryName]
    if catMod and catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        fontString:SetTextColor(cr, cg, cb, 1.0)
    else
        fontString:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
end

function H.PinSpecialCategories(list, moveRecentToTop, moveOtherToBottom, getName)
    if not moveRecentToTop and not moveOtherToBottom then return list end
    getName = getName or function(entry) return entry end
    local pinRecent, pinBottom, rest = {}, {}, {}
    for _, entry in ipairs(list) do
        local name = getName(entry)
        if name == "Recent Items" and moveRecentToTop then
            tinsert(pinRecent, entry)
        elseif name == "Other" and moveOtherToBottom then
            tinsert(pinBottom, entry)
        else
            tinsert(rest, entry)
        end
    end
    local result = {}
    for _, e in ipairs(pinRecent) do tinsert(result, e) end
    for _, e in ipairs(rest) do tinsert(result, e) end
    for _, e in ipairs(pinBottom) do tinsert(result, e) end
    return result
end

function H.VerticalGap(cellSize, verticalSpacing)
    return floor(cellSize * verticalSpacing * 0.25 + 0.5)
end

function H.RenderItemGrid(parentFrame, items, startY, leftPadding, cellSize, iconSize, cols)
    local itemRow = 0
    local itemCol = 0
    for _, button in ipairs(items) do
        local x = leftPadding + (itemCol * cellSize)
        local y = -(startY + itemRow * cellSize)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        button:OWB_SetIconSize(iconSize)
        button:Show()
        itemCol = itemCol + 1
        if itemCol >= cols then
            itemCol = 0
            itemRow = itemRow + 1
        end
    end
    local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
    return totalRows * cellSize
end

function H.SetupCategorySection(section, contentFrame, yOffset, categoryName, itemCount, catMods)
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
    section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    section.title:SetText(H.ResolveCategoryName(categoryName))
    H.ApplyCategoryColor(section.title, catMods, categoryName)
    section.count:SetText(tostring(itemCount))
    section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
end

function H.LayoutCompactGroup(catInfoList, contentFrame, opts)
    if #catInfoList == 0 then return opts.yOffset end

    local yOffset = opts.yOffset
    local cols = opts.cols
    local gapSlots = opts.gapSlots
    local showHeaders = opts.showHeaders
    local labelHeight = showHeaders and 16 or 0
    local leftPadding = opts.leftPadding
    local cellSize = opts.cellSize
    local iconSize = opts.iconSize
    local catMods = opts.catMods
    local AcquireLabel = opts.AcquireLabel
    local verticalSpacing = opts.verticalSpacing

    local lines = {}
    local currentLine = {}
    local curCol = 0

    for _, catInfo in ipairs(catInfoList) do
        local count = #catInfo.items
        local startCol = curCol > 0 and (curCol + gapSlots) or 0
        local avail = floor(cols - startCol)

        if avail < 1 then
            tinsert(lines, currentLine)
            currentLine = {}
            curCol = 0
            startCol = 0
            avail = cols
        end

        local optimalWidth = count <= cols and count or max(2, floor(sqrt(count / 1.618)))
        local blockWidth = min(optimalWidth, avail)
        local blockRows = ceil(count / blockWidth)

        if blockRows > 1 and (curCol > 0 or blockWidth < cols) then
            if #currentLine > 0 then
                tinsert(lines, currentLine)
                currentLine = {}
            end
            curCol = 0
            startCol = 0
            blockWidth = min(count, cols)
            blockRows = ceil(count / blockWidth)
        end

        tinsert(currentLine, {
            name = catInfo.name,
            displayName = catInfo.displayName,
            items = catInfo.items,
            startCol = startCol,
            blockWidth = blockWidth,
            blockRows = blockRows,
        })

        if blockRows > 1 then
            tinsert(lines, currentLine)
            currentLine = {}
            curCol = 0
        else
            curCol = startCol + blockWidth
        end
    end
    if #currentLine > 0 then
        tinsert(lines, currentLine)
    end

    for _, line in ipairs(lines) do
        if showHeaders then
            for _, cat in ipairs(line) do
                local label = AcquireLabel(contentFrame)
                label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT",
                    leftPadding + cat.startCol * cellSize, -yOffset)
                label:SetWidth(cat.blockWidth * cellSize)
                label:SetText(cat.displayName)
                H.ApplyCategoryColor(label, catMods, cat.name)
            end
        end
        yOffset = yOffset + labelHeight

        local maxRows = 0
        for _, cat in ipairs(line) do
            if cat.blockRows > maxRows then maxRows = cat.blockRows end
            local itemCol = 0
            local itemRow = 0
            for _, button in ipairs(cat.items) do
                local x = leftPadding + (cat.startCol + itemCol) * cellSize
                local y = -(yOffset + itemRow * cellSize)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
                button:OWB_SetIconSize(iconSize)
                button:Show()
                itemCol = itemCol + 1
                if itemCol >= cat.blockWidth then
                    itemCol = 0
                    itemRow = itemRow + 1
                end
            end
        end
        yOffset = yOffset + maxRows * cellSize
    end

    if #lines > 0 then
        yOffset = yOffset + H.VerticalGap(cellSize, verticalSpacing)
    end

    return yOffset
end
