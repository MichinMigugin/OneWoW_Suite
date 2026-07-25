local _, ns = ...

local PE = OneWoW.PredicateEngine
local SE = OneWoW.SearchExpand
local L = ns.L

local tinsert = tinsert
local tconcat = table.concat
local ipairs = ipairs

local MAX_KEYWORDS_PER_LINE = 8

local KEYWORD_COLOR = { 0.55, 0.9, 0.55 }

local function IsEnabled()
    return ns:GetDB().global.showKeywordsInTooltips ~= false
end

local function IsManagerOpen()
    return ns.CategoryManagerUI:IsOpen()
end

local function AppendTaggedLines(lines, header, names)
    if #names == 0 then return end

    tinsert(lines, {
        type = "header",
        text = header,
    })

    local chunk = {}
    local function flush()
        if #chunk == 0 then return end
        tinsert(lines, {
            type = "text",
            text = "  " .. tconcat(chunk, "  "),
            r = KEYWORD_COLOR[1], g = KEYWORD_COLOR[2], b = KEYWORD_COLOR[3],
        })
        chunk = {}
    end

    for _, name in ipairs(names) do
        tinsert(chunk, "#" .. name)
        if #chunk >= MAX_KEYWORDS_PER_LINE then
            flush()
        end
    end
    flush()
end

local function KeywordProvider(_, context)
    if context.type ~= "item" then return nil end
    if not context.itemID then return nil end
    if not IsEnabled() then return nil end
    if not IsManagerOpen() then return nil end

    local itemInfo = { hyperlink = context.itemLink }
    local keywords = PE:GetMatchingKeywords(context.itemID, nil, nil, itemInfo)
    local aliases = SE:GetMatchingTokens(context.itemID, nil, nil, itemInfo)
    if #keywords == 0 and #aliases == 0 then return nil end

    local lines = {}
    AppendTaggedLines(lines, L["TOOLTIP_KEYWORDS_HEADER"], keywords)
    AppendTaggedLines(lines, L["TOOLTIP_ALIASES_HEADER"], aliases)
    return lines
end

local function RegisterWithOneWoW()
    OneWoW.TooltipEngine:RegisterProvider({
        id = "bags_keywords",
        order = 99999,
        tooltipTypes = { "item" },
        callback = KeywordProvider,
    })
end

ns.RegisterTooltipProvider = RegisterWithOneWoW
