local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local PE = OneWoW_GUI.PredicateEngine

local L = OneWoW_Bags.L

local tinsert = tinsert
local tconcat = table.concat
local ipairs = ipairs

local MAX_KEYWORDS_PER_LINE = 8

local KEYWORD_COLOR = { 0.55, 0.9, 0.55 }

local function IsEnabled()
    return OneWoW_Bags:GetDB().global.showKeywordsInTooltips ~= false
end

local function IsManagerOpen()
    return OneWoW_Bags.CategoryManagerUI:IsOpen()
end

local function FormatKeywordLines(keywords)
    local lines = {}
    tinsert(lines, {
        type = "header",
        text = L["TOOLTIP_KEYWORDS_HEADER"],
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

    for _, kw in ipairs(keywords) do
        tinsert(chunk, "#" .. kw)
        if #chunk >= MAX_KEYWORDS_PER_LINE then
            flush()
        end
    end
    flush()

    return lines
end

local function KeywordProvider(tooltip, context)
    if context.type ~= "item" then return nil end
    if not context.itemID then return nil end
    if not IsEnabled() then return nil end
    if not IsManagerOpen() then return nil end

    local keywords = PE:GetMatchingKeywords(
        context.itemID, nil, nil, { hyperlink = context.itemLink }
    )
    if #keywords == 0 then return nil end

    return FormatKeywordLines(keywords)
end

local function RegisterWithOneWoW()
    local OW = _G.OneWoW
    if not OW or not OW.TooltipEngine then return end
    OW.TooltipEngine:RegisterProvider({
        id = "bags_keywords",
        order = 99999,
        tooltipTypes = { "item" },
        callback = KeywordProvider,
    })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        RegisterWithOneWoW()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
