local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local tinsert = table.insert
local strlower = string.lower

local Constants = OneWoW_GUI.Constants

---@class OneWoW_GUI_KeywordEntry
---@field canonical string  Lowercase canonical keyword name (no leading "#").
---@field aliases string[]  Other names for the same predicate. Excludes `canonical`. Sorted alphabetically. May be empty.

---@class OneWoW_GUI_KeywordCategory
---@field id string     Stable category key referenced by `CATEGORY_RULES`.
---@field title string  Human-readable header rendered above the chip group.

---@class OneWoW_GUI_GrammarRow
---@field left string   Syntax sample shown in the left column.
---@field right string  Plain-language description shown in the right column.

--- A chip Button extended with `BackdropTemplate` mixin methods plus the
--- per-chip metadata stashed by `MakeKeywordChip`.
---@class OneWoW_GUI_KeywordChip : Button, BackdropTemplate
---@field label FontString          Always present; renders `#canonical`.
---@field sub FontString?           Present only when the keyword has aliases; renders the alias list in muted text.
---@field canonical string          Mirrors `OneWoW_GUI_KeywordEntry.canonical`.
---@field aliasList string[]        Mirrors `OneWoW_GUI_KeywordEntry.aliases`. Empty array, never nil.

--- The "?" Button created by `CreateKeywordHelpButton`. No extra fields, but the
--- class lets us cleanly express "Button + BackdropTemplate".
---@class OneWoW_GUI_KeywordHelpButton : Button, BackdropTemplate

--- An `OneWoW_GUI:CreateEditBox`-flavored EditBox that optionally carries a
--- `placeholderText` field. Native EditBoxes created elsewhere may not, so the
--- field is typed optional.
---@class OneWoW_GUI_PlaceholderEditBox : EditBox
---@field placeholderText string?

---@return table?  The `OneWoW_GUI.PredicateEngine` instance, or nil if not yet attached.
local function GetPE()
    return OneWoW_GUI.PredicateEngine
end

-- Category bucketing. Any keyword whose canonical name isn't listed here
-- falls into "Other". This keeps the help panel scannable without forcing
-- hard categorization on the engine itself.
---@type OneWoW_GUI_KeywordCategory[]
local CATEGORIES = {
    { id = "grammar", title = "Syntax & Operators" },
    { id = "quality", title = "Quality" },
    { id = "bind",    title = "Binding" },
    { id = "gear",    title = "Gear / Equipment" },
    { id = "weapon",  title = "Weapons" },
    { id = "armor",   title = "Armor" },
    { id = "slot",    title = "Equipment Slot" },
    { id = "class",   title = "Class / Spec" },
    { id = "stat",    title = "Stats" },
    { id = "socket",  title = "Sockets / Gems" },
    { id = "consum",  title = "Consumables" },
    { id = "prof",    title = "Professions / Recipes" },
    { id = "collect", title = "Collectibles (Toys / Mounts / Pets)" },
    { id = "transmog",title = "Transmog / Catalyst" },
    { id = "expans",  title = "Expansion" },
    { id = "upgrade", title = "Upgrades" },
    { id = "state",   title = "Item State" },
    { id = "context", title = "Item Context" },
    { id = "special", title = "Special" },
    { id = "other",   title = "Other" },
}

---@type table<string, table<string, boolean>>
local CATEGORY_RULES = {
    quality = { poor = true, common = true, uncommon = true, rare = true, epic = true, legendary = true, artifact = true, heirloom = true, junk = true },
    bind    = { soulbound = true, boe = true, boa = true, bou = true, wue = true },
    gear    = { gear = true, set = true, needsrepair = true, broken = true, cosmetic = true },
    class   = { myclass = true, myspec = true },
    slot    = { head = true, neck = true, shoulder = true, chest = true, robe = true, waist = true, legs = true, feet = true, wrist = true, hand = true, finger = true, trinket = true, cloak = true, weapon = true, mainhand = true, offhand = true, holdable = true, shield = true, wand = true, ranged = true, thrown = true, relic = true, shirt = true, tabard = true, bag = true, ammopouch = true, quiver = true },
    weapon  = { ["1haxe"] = true, ["1hsword"] = true, ["1hmace"] = true, bow = true, gun = true, crossbow = true, dagger = true, fist = true, polearm = true, stave = true, staff = true, ["2haxe"] = true, ["2hsword"] = true, ["2hmace"] = true, ["1h"] = true, onehand = true, ["2h"] = true, twohand = true, axe = true, sword = true, mace = true },
    armor   = { cloth = true, leather = true, mail = true, plate = true },
    consum  = { consumable = true, potion = true, food = true, flask = true, elixir = true, bandage = true, scroll = true, vantusrune = true, utilitycurio = true, combatcurio = true, curio = true, explosive = true, knowledge = true },
    prof    = { recipe = true, tradeskill = true, tradegoods = true, reagent = true, craftingreagent = true, crafted = true, professionequipment = true, blacksmithing = true, leatherworking = true, tailoring = true, engineering = true, enchanting = true, alchemy = true, jewelcrafting = true, inscription = true, cooking = true, fishing = true, mining = true, herbalism = true, skinning = true, archaeology = true, myprofs = true, alchemyrecipe = true, blacksmithingrecipe = true, leatherworkingrecipe = true, tailoringrecipe = true, engineeringrecipe = true, enchantingrecipe = true, jewelcraftingrecipe = true, inscriptionrecipe = true, cookingrecipe = true, fishingrecipe = true },
    collect = { toy = true, mount = true, pet = true, collected = true, uncollected = true, alreadyknown = true, pethumanoid = true, petbeast = true, petdragonkin = true, petflying = true, petundead = true, petcritter = true, petmagic = true, petelemental = true, petaquatic = true, petmechanical = true, wildpet = true, petcanbattle = true, pettradeable = true, companionpet = true },
    transmog = { transmog = true, knowntransmog = true, unknowntransmog = true, catalyst = true, catalystupgrade = true },
    expans  = { classic = true, tbc = true, wrath = true, cata = true, mop = true, wod = true, legion = true, bfa = true, shadowlands = true, dragonflight = true, tww = true, midnight = true, lasttitan = true, titan = true },
    upgrade = { upgrade = true, upgradeable = true, fullyupgraded = true },
    stat    = { intellect = true, agility = true, strength = true, stamina = true, crit = true, haste = true, mastery = true, versatility = true, speed = true, leech = true, avoidance = true },
    socket  = { prismatic = true, metasocket = true, redsocket = true, yellowsocket = true, bluesocket = true, primordial = true },
    context = { raid = true, dungeon = true, delves = true, worldquest = true, pvp = true, store = true },
    state   = { usable = true, unusable = true, locked = true, new = true, socket = true, equipped = true, refundable = true, enchanted = true, charges = true, onuse = true, onequip = true, unique = true, uniqueequipped = true, reputation = true, tradeableloot = true, openable = true, sellable = true, unsellable = true, quest = true, questitem = true },
    special = { hearthstone = true, keystone = true, tierset = true, battlepay = true, wowtoken = true, housing = true, decor = true, dye = true, room = true, recent = true },
}

--- Resolve the display category for a canonical keyword name. Falls back to
--- `"other"` when no `CATEGORY_RULES` entry claims it.
---@param canonical string  Lowercase keyword name (no leading "#").
---@return string catId     One of the `id` values in `CATEGORIES`.
local function CategorizeKeyword(canonical)
    for catId, map in pairs(CATEGORY_RULES) do
        if map[canonical] then return catId end
    end
    return "other"
end

---@type OneWoW_GUI_GrammarRow[]
local GRAMMAR_ROWS = {
    { left = "a and b   |   a & b",             right = "Both conditions must match (default)." },
    { left = "a or b   |   a | b",              right = "Either condition may match." },
    { left = "not a   |   !a",                  right = "Negate a condition." },
    { left = "(a or b) and c",                  right = "Use parentheses to group terms." },
    { left = "#rare",                           right = "Match all rare-quality items." },
    { left = "#soulbound or #warbound",         right = "Match items that are either soulbound OR warbound." },
    { left = "(#soulbound or #warbound) and #quest", right = "Example of mixing OR and AND." },
    { left = "ilvl>=200   |   ilvl:200-300",    right = "Numeric property comparisons / ranges." },
    { left = "vendorprice>50g",                 right = "Gold/silver/copper values: 50g, 10s 5c, or raw copper." },
    { left = "name~sword",                      right = "'Contains' match on item name (bare text does the same thing)." },
    { left = "#epic and ilvl>=600 and !#soulbound", right = "Complex example: epic items 600+ ilvl that are not soulbound." },
}

---@type Frame?  Lazy-built shared help window. nil until `BuildKeywordFrame` runs.
local keywordFrame
---@type Frame?  Scroll child that hosts the per-category chip grid.
local keywordContent
---@type OneWoW_GUI_PlaceholderEditBox?  Edit box that receives clicked-keyword tokens, set per-`ShowKeywordHelp` call.
local currentEditBox
---@type string  Current filter substring, lower-cased on apply by `KeywordMatchesFilter`.
local currentFilterText = ""
---@type table<string, FontString>  catId -> reusable header FontString rendered above each chip group.
local categoryHeaders = {}
---@type OneWoW_GUI_KeywordChip[]  All keyword chips ever created, kept for re-layout on filter/resize.
local keywordChips = {}

--- Append `token` to `editBox` with a single-space separator, restoring the
--- normal text color (clearing placeholder/muted styling) and re-running any
--- registered `OnTextChanged` handler so search results update immediately.
--- No-op when `editBox` is nil.
---@param editBox OneWoW_GUI_PlaceholderEditBox?  Target edit box (typically a search input). `placeholderText` is honored if present.
---@param token string                            Text to append (e.g. `"#rare"`).
local function AppendToEditBox(editBox, token)
    if not editBox then
        return
    end
    local text = editBox:GetText() or ""
    local placeholder = editBox.placeholderText
    if placeholder and text == placeholder then
        text = ""
    end
    if text ~= "" and not text:match("%s$") then
        text = text .. " "
    end
    text = text .. token
    editBox:SetText(text)
    editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if editBox:HasScript("OnTextChanged") then
        local handler = editBox:GetScript("OnTextChanged")
        if handler then handler(editBox) end
    end
    editBox:SetFocus()
    editBox:SetCursorPosition(#text)
end

--- Build the two label strings for a keyword chip.
---@param entry OneWoW_GUI_KeywordEntry
---@return string mainLabel   `"#" .. canonical` (e.g. `"#rare"`).
---@return string? aliasLabel Space-separated `"#alias1 #alias2"` string, or nil when `entry.aliases` is empty.
local function BuildChipLabel(entry)
    if entry.aliases and #entry.aliases > 0 then
        local aliasStr = "#" .. table.concat(entry.aliases, " #")
        return "#" .. entry.canonical, aliasStr
    end
    return "#" .. entry.canonical, nil
end

--- Create a clickable chip Button representing a single keyword.
---
--- Click behavior: when `currentEditBox` is set, the chip appends `"#canonical"`
--- to that edit box (see `AppendToEditBox`). When unset, the click is a no-op
--- and the tooltip omits the "click to insert" hint.
---
--- The returned button stashes `canonical` and `aliasList` fields for later
--- filtering/categorization without re-walking the entry table.
---@param parent Frame
---@param entry OneWoW_GUI_KeywordEntry
---@return OneWoW_GUI_KeywordChip chip
local function MakeKeywordChip(parent, entry)
    local canonical = entry.canonical
    ---@type OneWoW_GUI_KeywordChip
    local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
    chip:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    chip:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mainLabel, aliasLabel = BuildChipLabel(entry)
    local label = chip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", chip, "LEFT", 6, 0)
    label:SetText(mainLabel)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    chip.label = label

    local sub
    if aliasLabel then
        sub = chip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("LEFT", label, "RIGHT", 6, 0)
        sub:SetText(aliasLabel)
        sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        chip.sub = sub
    end

    local textWidth = label:GetStringWidth() + 12
    if sub then textWidth = textWidth + sub:GetStringWidth() + 6 end
    chip:SetSize(math.max(60, textWidth), 20)

    chip:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("#" .. canonical, 1, 1, 1)
        if entry.aliases and #entry.aliases > 0 then
            GameTooltip:AddLine("Aliases: #" .. table.concat(entry.aliases, " #"), 0.7, 0.7, 0.7, true)
        end
        if currentEditBox then
            GameTooltip:AddLine("Click to insert into search box.", 0.5, 0.9, 0.5, true)
        end
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        GameTooltip:Hide()
    end)
    chip:SetScript("OnClick", function()
        if currentEditBox then
            AppendToEditBox(currentEditBox, "#" .. canonical)
        end
    end)

    chip.canonical = canonical
    chip.aliasList = entry.aliases or {}
    return chip
end

--- Substring match against canonical name and aliases. Empty/nil filter matches
--- everything. Comparison is case-insensitive (filter is lowered) and uses plain
--- `string.find` (no Lua patterns).
---@param entry { canonical: string, aliases: string[]? }
---@param filter string?
---@return boolean
local function KeywordMatchesFilter(entry, filter)
    if not filter or filter == "" then return true end
    local lower = strlower(filter)
    if entry.canonical:find(lower, 1, true) then return true end
    for _, alias in ipairs(entry.aliases or {}) do
        if alias:find(lower, 1, true) then return true end
    end
    return false
end

--- Re-position every chip into category groups, applying the active
--- `currentFilterText` filter and showing/hiding chips accordingly. Recomputes
--- `keywordContent` height so the parent scroll frame can size correctly.
---
--- Safe to call repeatedly. Invoked on filter change, OnSizeChanged, and OnShow.
--- The `"grammar"` category is intentionally skipped — grammar rows are rendered
--- statically above the chip area in `BuildKeywordFrame`.
local function LayoutChips()
    local content = keywordContent
    if not content then return end
    local width = content:GetWidth()
    if width <= 0 then width = 480 end

    local rowX, rowY = 8, -8
    local rowHeight = 22
    local gapX, gapY = 6, 6

    -- Group chips by category
    local grouped = {}
    for _, catDef in ipairs(CATEGORIES) do
        grouped[catDef.id] = {}
    end
    for _, chip in ipairs(keywordChips) do
        local visible = KeywordMatchesFilter({ canonical = chip.canonical, aliases = chip.aliasList }, currentFilterText)
        chip:SetShown(visible)
        if visible then
            local catId = CategorizeKeyword(chip.canonical)
            tinsert(grouped[catId], chip)
        end
    end

    for _, header in pairs(categoryHeaders) do
        header:Hide()
    end

    local totalHeight = 8
    for _, catDef in ipairs(CATEGORIES) do
        if catDef.id == "grammar" then
            -- skip grammar section in chip list; it is drawn separately above
        else
            local chipsInCat = grouped[catDef.id]
            if chipsInCat and #chipsInCat > 0 then
                local header = categoryHeaders[catDef.id]
                if not header then
                    header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    categoryHeaders[catDef.id] = header
                end
                header:SetText(catDef.title)
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 8, rowY)
                header:Show()
                rowY = rowY - 18
                totalHeight = totalHeight + 18

                rowX = 8
                local rowUsed = false
                for _, chip in ipairs(chipsInCat) do
                    chip:ClearAllPoints()
                    local cw = chip:GetWidth()
                    if rowX + cw > width - 8 and rowUsed then
                        rowX = 8
                        rowY = rowY - (rowHeight + gapY)
                        totalHeight = totalHeight + rowHeight + gapY
                    end
                    chip:SetPoint("TOPLEFT", content, "TOPLEFT", rowX, rowY)
                    rowX = rowX + cw + gapX
                    rowUsed = true
                end
                rowY = rowY - (rowHeight + gapY + 4)
                totalHeight = totalHeight + rowHeight + gapY + 4
            end
        end
    end

    content:SetHeight(math.max(totalHeight + 16, 1))
end

--- Lazily build the shared keyword help window the first time it is requested.
--- Subsequent calls return the cached frame untouched.
---
--- Side effects on first build:
---   * Populates the module-level `keywordFrame`, `keywordContent`,
---     `categoryHeaders`, and `keywordChips` tables.
---   * Queries `OneWoW_GUI.PredicateEngine:GetAllKeywords()` and creates one
---     chip per entry. If the engine isn't attached yet, the chip area stays
---     empty (the frame still builds).
---   * Hooks `OnSizeChanged` / `OnShow` so layout re-runs after resize/reopen.
---@return Frame keywordFrame  The shared, hidden-by-default help window.
local function BuildKeywordFrame()
    if keywordFrame then return keywordFrame end

    keywordFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_GUI_KeywordHelpFrame",
        width = 560,
        height = 520,
        bgColor = "BG_PRIMARY",
    })
    keywordFrame:SetPoint("CENTER")
    keywordFrame:SetFrameStrata("DIALOG")
    keywordFrame:SetFrameLevel(500)
    keywordFrame:SetMovable(true)
    keywordFrame:EnableMouse(true)
    keywordFrame:SetToplevel(true)
    keywordFrame:Hide()

    local titleBar = CreateFrame("Frame", nil, keywordFrame)
    titleBar:SetPoint("TOPLEFT", keywordFrame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", keywordFrame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() keywordFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() keywordFrame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("Search Keywords & Syntax")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetSize(22, 22)
    closeBtn:SetScript("OnClick", function() keywordFrame:Hide() end)

    -- Grammar section (static)
    local grammarFrame = OneWoW_GUI:CreateFrame(keywordFrame, {
        name = "OneWoW_GUI_KeywordHelpGrammar",
        bgColor = "BG_SECONDARY",
    })
    grammarFrame:SetPoint("TOPLEFT", keywordFrame, "TOPLEFT", 10, -32)
    grammarFrame:SetPoint("TOPRIGHT", keywordFrame, "TOPRIGHT", -10, -32)
    grammarFrame:SetHeight(2000)

    local gy = -8
    local gHeaderFS = grammarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gHeaderFS:SetPoint("TOPLEFT", grammarFrame, "TOPLEFT", 10, gy)
    gHeaderFS:SetText("Syntax & Operators")
    gHeaderFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    gy = gy - 18

    local grammarRowGap = 4
    for _, row in ipairs(GRAMMAR_ROWS) do
        local rightColW = math.max(1, grammarFrame:GetWidth() - 260)

        local leftFS = grammarFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leftFS:SetHeight(0)
        leftFS:SetPoint("TOPLEFT", grammarFrame, "TOPLEFT", 12, gy)
        leftFS:SetWidth(230)
        leftFS:SetJustifyH("LEFT")
        leftFS:SetWordWrap(true)
        leftFS:SetText(row.left)
        leftFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local rightFS = grammarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rightFS:SetHeight(0)
        rightFS:SetPoint("TOPLEFT", grammarFrame, "TOPLEFT", 250, gy)
        rightFS:SetWidth(rightColW)
        rightFS:SetJustifyH("LEFT")
        rightFS:SetWordWrap(true)
        rightFS:SetText(row.right)
        rightFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local rowH = math.max(leftFS:GetHeight(), rightFS:GetHeight(), 14)
        gy = gy - rowH - grammarRowGap
    end
    grammarFrame:SetHeight(math.abs(gy) + 12)

    local filterBox = OneWoW_GUI:CreateEditBox(keywordFrame, {
        height = 22,
        placeholderText = "Filter keywords (e.g. mount, boe, rare)...",
        onTextChanged = function(text)
            currentFilterText = text or ""
            LayoutChips()
        end,
    })
    filterBox:SetPoint("TOPLEFT", grammarFrame, "BOTTOMLEFT", 0, -10)
    filterBox:SetPoint("TOPRIGHT", grammarFrame, "BOTTOMRIGHT", 0, -10)

    -- Scroll frame for chips
    local scroll, content = OneWoW_GUI:CreateScrollFrame(keywordFrame, { name = "OneWoW_GUI_KeywordHelpScroll" })
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", filterBox, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", keywordFrame, "BOTTOMRIGHT", -10, 36)
    keywordContent = content

    local footer = keywordFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", keywordFrame, "BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", keywordFrame, "BOTTOMRIGHT", -12, 10)
    footer:SetJustifyH("LEFT")
    footer:SetWordWrap(true)
    footer:SetText("Click any keyword to insert it into the search box. Combine with 'and' / 'or' / 'not' or & | !.")
    footer:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    -- Populate chips
    local PE = GetPE()
    if PE and PE.GetAllKeywords then
        local keywords = PE:GetAllKeywords()
        for _, entry in ipairs(keywords) do
            local chip = MakeKeywordChip(content, entry)
            tinsert(keywordChips, chip)
        end
    end

    content:HookScript("OnSizeChanged", LayoutChips)
    keywordFrame:HookScript("OnShow", LayoutChips)
    LayoutChips()

    return keywordFrame
end

--- Open the shared keyword help panel and (optionally) wire its chips to an
--- edit box. The panel is built lazily on first call and reused thereafter.
---
--- The `editBox` binding is global to the panel for the duration it is open:
--- calling `ShowKeywordHelp` again replaces the previously bound box. Pass nil
--- to display the panel in read-only mode (chips become non-inserting).
---@param editBox OneWoW_GUI_PlaceholderEditBox?  Optional edit box that receives `#keyword` tokens on chip click. Any standard `EditBox` is accepted; the optional `placeholderText` field is honored if present.
function OneWoW_GUI:ShowKeywordHelp(editBox)
    local frame = BuildKeywordFrame()
    currentEditBox = editBox
    frame:Show()
    frame:Raise()
end

--- Hide the shared keyword help panel if it has been built. No-op otherwise.
function OneWoW_GUI:HideKeywordHelp()
    if keywordFrame then keywordFrame:Hide() end
end

---@class OneWoW_GUI_KeywordHelpButtonOptions
---@field editBox OneWoW_GUI_PlaceholderEditBox?  Edit box that chip clicks should target while the panel is open. Optional.
---@field size number?                            Square pixel size of the button. Defaults to 20.
---@field tooltipTitle string?                    Tooltip header text. Defaults to `"Search Help"`.
---@field tooltipDesc string?                     Tooltip body text. Defaults to a generic search-syntax hint.

--- Create a small "?" button that opens the shared keyword help panel.
---
--- The button styles itself from the active OneWoW_GUI theme (BG_TERTIARY +
--- BORDER_SUBTLE, with a BTN_HOVER swap on mouseover) and is parented but not
--- positioned — callers must `SetPoint` it themselves.
---@param parent Frame
---@param options OneWoW_GUI_KeywordHelpButtonOptions?
---@return OneWoW_GUI_KeywordHelpButton
function OneWoW_GUI:CreateKeywordHelpButton(parent, options)
    options = options or {}
    local size = options.size or 20
    local editBoxTarget = options.editBox
    local title = options.tooltipTitle or "Search Help"
    local desc = options.tooltipDesc or "Search by item name, item ID, or #keywords. Click to see all keywords and syntax."

    ---@type OneWoW_GUI_KeywordHelpButton
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText("?")
    label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(desc, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        OneWoW_GUI:ShowKeywordHelp(editBoxTarget)
    end)

    return btn
end

---@class OneWoW_GUI_SearchTooltipOptions
---@field tooltipTitle string? Tooltip header text. Defaults to `"Search"`.
---@field tooltipDesc string?  Tooltip body text. Defaults to a generic search-syntax hint.

--- Attach a standard search-help tooltip (no button) to an existing edit box.
---
--- Existing `OnEnter` / `OnLeave` handlers are preserved: the previous handler
--- runs first, then the tooltip is shown/hidden. No-op when `editBox` is nil.
---@param editBox EditBox?
---@param options OneWoW_GUI_SearchTooltipOptions?
function OneWoW_GUI:AttachSearchTooltip(editBox, options)
    if not editBox then return end
    options = options or {}
    local title = options.tooltipTitle or "Search"
    local desc  = options.tooltipDesc or "Search by item name, item ID, or #keywords. Use the nearby ? button to see all keywords."
    local prevEnter = editBox:GetScript("OnEnter")
    local prevLeave = editBox:GetScript("OnLeave")
    editBox:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(desc, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    editBox:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        GameTooltip:Hide()
    end)
end
