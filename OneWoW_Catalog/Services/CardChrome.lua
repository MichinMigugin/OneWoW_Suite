local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local C_Texture = C_Texture
local tinsert = tinsert

-- ============================================================================
-- CardChrome
-- ============================================================================
-- Shared list-card art for Journal, Quests, Vendors, and Item Search.
--
-- Backgrounds:
--   1. Specific art when we already have it (Adventure Guide instance file,
--      official Delve entrance atlas).
--   2. One Encounter Journal expansion atlas (UI-EJ-Classic ... ui-ej-midnight).
--      Those sheets are already in the client. We cache the first probe so a
--      long list does not keep asking C_Texture.
--
-- Zone maps are not used as card art. C_Map tiles are large, many per zone,
-- and would hitch a virtualized list. Expansion art is the fallback for
-- zones, cities, synthetic World cards, and anything else without a file.
--
-- Borders:
--   Every card can take a named key (journal.raid, quest.campaign,
--   vendor.quartermaster, ...). Today that drives the 1px edge color.
--   Set atlas or texture on BORDER_DEFS[key] when custom frames ship under
--   OneWoW/Media/OneWoW_Catalog/.
--
-- Expansion IDs:
--   Journal cards use 1 = Classic ... 12 = Midnight.
--   Quests (and LE_EXPANSION_*) use 0 = Classic ... 11 = Midnight.
-- ============================================================================

ns.CardChrome = ns.CardChrome or {}
local CardChrome = ns.CardChrome

local BG_ALPHA = 0.3
local BG_ALPHA_HOVER = 0.5

-- Adventure Guide tier backgrounds. Names match AtlasInfo
-- interface/encounterjournal/dungeonjournaltierbackgrounds*.
local EXPANSION_BG_ATLAS = {
    [0]  = "UI-EJ-Classic",
    [1]  = "UI-EJ-BurningCrusade",
    [2]  = "UI-EJ-WrathoftheLichKing",
    [3]  = "UI-EJ-Cataclysm",
    [4]  = "UI-EJ-MistsofPandaria",
    [5]  = "UI-EJ-WarlordsofDraenor",
    [6]  = "UI-EJ-Legion",
    [7]  = "UI-EJ-BattleforAzeroth",
    [8]  = "UI-EJ-Shadowlands",
    [9]  = "UI-EJ-Dragonflight",
    [10] = "UI-EJ-TheWarWithin",
    [11] = "ui-ej-midnight",
}

local expansionAtlasCache = {}
local ejBgCache = {}
local delveBgCache = {}

local DELVE_BG_ALIAS = {
    [2826] = "delves-entrance-background-sewers",
    [2831] = "delve-entrance-background-goblin-boss",
}

-- theme: GetThemeColor key. constant: OneWoW_GUI.Constants color table.
-- atlas / texture: optional overlay when custom frames exist.
local BORDER_DEFS = {
    default = { theme = "BORDER_SUBTLE" },

    ["journal.raid"] = { theme = "ACCENT_PRIMARY" },
    ["journal.party"] = { theme = "ACCENT_SECONDARY" },
    ["journal.world"] = { theme = "ACCENT_HIGHLIGHT" },
    ["journal.zone"] = { theme = "BORDER_DEFAULT" },
    ["journal.city"] = { constant = "WOW_QUEST_GOLD" },
    ["journal.delve"] = { theme = "ACCENT_MUTED" },
    ["journal.delve_bountiful"] = { theme = "TEXT_WARNING" },

    ["quest.standard"] = { theme = "BORDER_SUBTLE" },
    ["quest.campaign"] = { constant = "WOW_QUEST_GOLD" },
    ["quest.story"] = { theme = "ACCENT_HIGHLIGHT" },
    ["quest.legendary"] = { theme = "TEXT_WARNING" },
    ["quest.dungeon"] = { theme = "ACCENT_SECONDARY" },
    ["quest.raid"] = { theme = "ACCENT_PRIMARY" },
    ["quest.world"] = { theme = "ACCENT_HIGHLIGHT" },
    ["quest.pvp"] = { theme = "TEXT_WARNING" },
    ["quest.profession"] = { theme = "ACCENT_MUTED" },
    ["quest.scenario"] = { theme = "ACCENT_SECONDARY" },
    ["quest.group"] = { theme = "ACCENT_HIGHLIGHT" },

    ["vendor.quartermaster"] = { constant = "WOW_QUEST_GOLD" },
    ["vendor.quest_giver"] = { theme = "ACCENT_HIGHLIGHT" },
}

local function ExpansionLevel(id, scheme)
    if not id then
        return nil
    end
    if scheme == "journal" then
        return id - 1
    end
    return id
end

--- Cached EJ expansion atlas, or nil when the client has no sheet for that level.
---@param expansionID number|nil
---@param scheme string|nil "journal" (1=Classic) or "level" (0=Classic)
---@return string|nil atlas
function CardChrome.GetExpansionBackgroundAtlas(expansionID, scheme)
    local level = ExpansionLevel(expansionID, scheme or "level")
    if not level then
        return nil
    end
    if expansionAtlasCache[level] ~= nil then
        return expansionAtlasCache[level] or nil
    end
    local atlas = EXPANSION_BG_ATLAS[level]
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        expansionAtlasCache[level] = atlas
        return atlas
    end
    expansionAtlasCache[level] = false
    return nil
end

---@param expansionID number|nil
---@param scheme string|nil
---@return table|nil art { atlas = string }
function CardChrome.ResolveExpansionBackground(expansionID, scheme)
    local atlas = CardChrome.GetExpansionBackgroundAtlas(expansionID, scheme)
    if atlas then
        return { atlas = atlas }
    end
    return nil
end

---@param instanceID number
---@return string|false
local function GetInstanceBackground(instanceID)
    if ejBgCache[instanceID] ~= nil then
        return ejBgCache[instanceID]
    end
    -- EJ_GetInstanceInfo lives on the Encounter Journal load unit.
    if EJ_GetInstanceInfo then
        local _, _, bgImage = EJ_GetInstanceInfo(instanceID)
        ejBgCache[instanceID] = bgImage or false
        return ejBgCache[instanceID]
    end
    ejBgCache[instanceID] = false
    return false
end

local function SlugDelveName(name, keepPunctAsHyphen)
    name = (name or ""):lower()
    if not keepPunctAsHyphen then
        name = name:gsub("['’`]", "")
    end
    name = name:gsub("[^%w]+", "-")
    name = name:gsub("^-+", ""):gsub("-+$", "")
    return name
end

local function TitleCaseSlug(slug)
    return (slug:gsub("(%f[%w]%a)", string.upper))
end

local function AddDelveBgCandidates(candidates, slug)
    if slug == "" then
        return
    end
    tinsert(candidates, "delve-entrance-background-" .. slug)
    tinsert(candidates, "delves-entrance-background-" .. slug)
    tinsert(candidates, "delve-entrance-background-" .. TitleCaseSlug(slug))
    if slug:sub(1, 4) == "the-" then
        tinsert(candidates, "delve-entrance-background-" .. slug:sub(5))
    else
        tinsert(candidates, "delve-entrance-background-the-" .. slug)
    end
end

---@param instData table
---@return string|nil atlas
local function GetDelveBackgroundAtlas(instData)
    local mid = instData and instData.mapID
    if not mid then
        return nil
    end
    if delveBgCache[mid] ~= nil then
        return delveBgCache[mid] or nil
    end

    local candidates = {}
    if DELVE_BG_ALIAS[mid] then
        tinsert(candidates, DELVE_BG_ALIAS[mid])
    end
    AddDelveBgCandidates(candidates, SlugDelveName(instData.name, false))
    AddDelveBgCandidates(candidates, SlugDelveName(instData.name, true))
    tinsert(candidates, "delves-dashboard-background")

    for i = 1, #candidates do
        local atlas = candidates[i]
        if C_Texture.GetAtlasInfo(atlas) then
            delveBgCache[mid] = atlas
            return atlas
        end
    end
    delveBgCache[mid] = false
    return nil
end

local function InstanceHasEJArt(instData)
    local t = instData.instanceType
    if t ~= "raid" and t ~= "party" and t ~= "world" then
        return false
    end
    return instData.instanceID and instData.instanceID > 0
end

--- Specific instance / Delve art, else the card's expansion atlas.
---@param instData table
---@return table|nil art { atlas = string }|{ file = string }
function CardChrome.ResolveJournalBackground(instData)
    if not instData then
        return nil
    end
    if instData.instanceType == "delve" then
        local atlas = GetDelveBackgroundAtlas(instData)
        if atlas then
            return { atlas = atlas }
        end
        return CardChrome.ResolveExpansionBackground(instData.expansionID, "journal")
    end
    if InstanceHasEJArt(instData) then
        local bgImage = GetInstanceBackground(instData.instanceID)
        if bgImage and bgImage ~= false then
            return { file = bgImage }
        end
    end
    return CardChrome.ResolveExpansionBackground(instData.expansionID, "journal")
end

---@param instData table
---@param bountiful boolean|nil
---@return string
function CardChrome.JournalBorderKey(instData, bountiful)
    if not instData then
        return "default"
    end
    if instData.instanceType == "delve" then
        return bountiful and "journal.delve_bountiful" or "journal.delve"
    end
    if instData.instanceType == "zone" then
        return instData.isCity and "journal.city" or "journal.zone"
    end
    if instData.instanceType == "raid" then
        return "journal.raid"
    end
    if instData.instanceType == "party" then
        return "journal.party"
    end
    if instData.instanceType == "world" then
        return "journal.world"
    end
    return "default"
end

local function QuestHasCategory(quest, key)
    local cats = quest and quest.categories
    if type(cats) ~= "table" then
        return false
    end
    for i = 1, #cats do
        if cats[i] == key then
            return true
        end
    end
    return false
end

---@param quest table|nil
---@return string
function CardChrome.QuestBorderKey(quest)
    if not quest then
        return "quest.standard"
    end
    if QuestHasCategory(quest, "campaign") then
        return "quest.campaign"
    end
    if QuestHasCategory(quest, "legendary") then
        return "quest.legendary"
    end
    if QuestHasCategory(quest, "story") then
        return "quest.story"
    end
    local qt = quest.questType
    if qt and qt ~= "" and qt ~= "standard" then
        local key = "quest." .. qt
        if BORDER_DEFS[key] then
            return key
        end
    end
    return "quest.standard"
end

---@param vendor table|nil
---@return string
function CardChrome.VendorBorderKey(vendor)
    local cat = vendor and vendor.category
    if cat and cat ~= "" then
        local key = "vendor." .. cat
        if BORDER_DEFS[key] then
            return key
        end
    end
    return "default"
end

---@param tex Texture
---@param art table|nil
function CardChrome.ApplyBackground(tex, art)
    if not tex then
        return
    end
    if not art then
        tex:Hide()
        return
    end
    if art.atlas then
        tex:SetTexture(nil)
        tex:SetAtlas(art.atlas)
        tex:Show()
    elseif art.file then
        tex:SetAtlas(nil)
        tex:SetTexture(art.file)
        tex:Show()
    else
        tex:Hide()
    end
end

local function ApplyBorderColor(card, key)
    local def = BORDER_DEFS[key] or BORDER_DEFS.default
    if def.constant then
        local c = OneWoW_GUI.Constants[def.constant]
        card:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
        return
    end
    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor(def.theme or "BORDER_SUBTLE"))
end

local function ApplyBorderOverlay(card, key)
    local tex = card.borderTex
    if not tex then
        return
    end
    local def = BORDER_DEFS[key] or BORDER_DEFS.default
    if def.atlas then
        tex:SetTexture(nil)
        tex:SetAtlas(def.atlas)
        tex:Show()
    elseif def.texture then
        tex:SetAtlas(nil)
        tex:SetTexture(def.texture)
        tex:Show()
    else
        tex:Hide()
    end
end

--- Create bg + overlay on a list card once. Safe to call again.
---@param card Frame
---@param opts table|nil
---  skipBackground boolean
---  bgWidth, bgHeight, bgOffsetX, bgOffsetY, bgAlpha number
function CardChrome.Attach(card, opts)
    opts = opts or {}
    if not opts.skipBackground and not card.bgTex then
        local bgTex = card:CreateTexture(nil, "ARTWORK")
        bgTex:SetPoint("CENTER", card, "CENTER", opts.bgOffsetX or 20, opts.bgOffsetY or -5)
        bgTex:SetSize(opts.bgWidth or 380, opts.bgHeight or 140)
        bgTex:SetDrawLayer("ARTWORK", -1)
        bgTex:SetAlpha(opts.bgAlpha or BG_ALPHA)
        bgTex:Hide()
        card.bgTex = bgTex
    end
    if not card.borderTex then
        local borderTex = card:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(card)
        borderTex:Hide()
        card.borderTex = borderTex
    end
end

--- Fill, 1px edge, optional overlay. Persists borderKey / fill on the card
--- so OnEnter / OnLeave can re-apply without the row payload.
---@param card Frame
---@param state table
---  selected boolean
---  hover boolean
---  borderKey string|nil
---  fillTheme string|nil
---  zebraIndex number|nil
function CardChrome.ApplyRowChrome(card, state)
    state = state or {}
    if state.borderKey ~= nil then
        card._borderKey = state.borderKey
    end
    if state.selected ~= nil then
        card._chromeSelected = state.selected and true or false
    end
    if state.fillTheme ~= nil then
        card._chromeFill = state.fillTheme
    end
    if state.zebraIndex ~= nil then
        card._zebraIndex = state.zebraIndex
    end

    local selected = card._chromeSelected
    local hover = state.hover
    local fillKey
    if selected then
        fillKey = "BG_ACTIVE"
    elseif hover then
        fillKey = "BG_HOVER"
    else
        local fillTheme = card._chromeFill
        if not fillTheme or fillTheme == "BG_PRIMARY" or fillTheme == "BG_SECONDARY" then
            fillKey = OneWoW_GUI:GetZebraThemeKey(card._zebraIndex or 1)
        else
            fillKey = fillTheme
        end
    end
    card:SetBackdropColor(OneWoW_GUI:GetThemeColor(fillKey))

    if selected then
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    elseif hover then
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    else
        ApplyBorderColor(card, card._borderKey)
    end

    if card.bgTex and card.bgTex:IsShown() then
        card.bgTex:SetAlpha(hover and BG_ALPHA_HOVER or BG_ALPHA)
    end
    ApplyBorderOverlay(card, card._borderKey)
end
