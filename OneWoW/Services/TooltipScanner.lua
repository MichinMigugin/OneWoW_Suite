local _, ns = ...

-- ============================================================================
-- TooltipScanner
-- ============================================================================
-- Central owner of C_TooltipInfo routing, tooltip-data caches, and structured
-- line extraction. PredicateEngine, RecipeKnownUtil, and Merchant delegate here.

local TooltipScanner = {}
ns.TooltipScanner = TooltipScanner

local C_TooltipInfo = C_TooltipInfo
local C_Container = C_Container
local strfind = string.find
local tconcat = table.concat
local ipairs, wipe, tonumber = ipairs, wipe, tonumber
local rawset, rawget = rawset, rawget
local sort = sort

local LINE_LEARN = Enum.TooltipDataLineType.ItemSpellTriggerLearn
local LINE_BINDING = Enum.TooltipDataLineType.ItemBinding
local LINE_TRADE_TIME = Enum.TooltipDataLineType.TradeTimeRemaining
local LINE_USAGE_REQ = Enum.TooltipDataLineType.UsageRequirement
local LINE_ERROR = Enum.TooltipDataLineType.ErrorLine
local LINE_DISABLED = Enum.TooltipDataLineType.DisabledLine

-- Backpack + equipped bags + reagent bag; IsUsableItem is authoritative here.
local PLAYER_INVENTORY_BAG_MAX = 5
-- Personal bank tabs and warband vault (6+).
local BANK_BAG_MIN = 6

-- CHARGES PATTERN NOTE: C_TooltipInfo keeps raw |4 markup when the global uses
-- plural forms (enUS "1 |4Charge:Charges;"). Locales without |4 (zhCN "%d次",
-- koKR "%d회 사용 가능") emit filled format text instead. BuildChargesSearchPattern
-- handles both; placeholder-first escape order is mandatory (escape-then-%d
-- replacement leaves a stray %). Mirrored by bin/check_tooltip_patterns.py.
local PATTERN_MAGIC = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
local CHARGES_DIGIT_PH = "\1"

--- Convert ITEM_SPELL_CHARGES into a Lua pattern that matches C_TooltipInfo text.
---@param fmt string
---@return string pattern
local function BuildChargesSearchPattern(fmt)
    local firstForm = fmt:match("|4(.-):.-%;")
    if firstForm then
        return "(%d+) |4" .. firstForm
    end
    -- Non-|4: "%d次" → "(%d+)次". Substitute %d before escaping metacharacters.
    local withPh = fmt:gsub("%%d", CHARGES_DIGIT_PH, 1)
    local escaped = withPh:gsub(PATTERN_MAGIC, "%%%1")
    return (escaped:gsub(CHARGES_DIGIT_PH, "(%%d+)", 1))
end

local chargesSearchPattern = BuildChargesSearchPattern(ITEM_SPELL_CHARGES)
local uniqueEquipPattern = ITEM_UNIQUE_EQUIPPABLE:gsub("%-", "%%-")

-- Precomputed search patterns: these were previously rebuilt via string
-- concatenation on every call (and per tooltip line in the line-walk paths).
local usePatternHead = "^" .. USE_COLON
local usePatternBody = "\n" .. USE_COLON
local equipPatternHead = "^" .. ITEM_SPELL_TRIGGER_ONEQUIP
local equipPatternBody = "\n" .. ITEM_SPELL_TRIGGER_ONEQUIP
local uniqueEquipPatternHead = "^" .. uniqueEquipPattern
local uniqueEquipPlainBody = "\n" .. ITEM_UNIQUE_EQUIPPABLE
local uniquePatternHead = "^" .. ITEM_UNIQUE
local uniquePlainBody = "\n" .. ITEM_UNIQUE

-- ITEM_CLASSES_ALLOWED = "Classes: %s" — capture the class-list substring.
local CLASS_LIST_CAPTURE_PH = "\1"
local function BuildClassesAllowedCapturePattern(fmt)
    local withPh = fmt:gsub("%%s", CLASS_LIST_CAPTURE_PH, 1)
    local escaped = withPh:gsub(PATTERN_MAGIC, "%%%1")
    return "^" .. escaped:gsub(CLASS_LIST_CAPTURE_PH, "(.+)", 1) .. "$"
end
local classesAllowedCapture = BuildClassesAllowedCapturePattern(ITEM_CLASSES_ALLOWED)

-- Localized className → classID. Built lazily (C_CreatureInfo can be empty at
-- file-load in some load orders); longest names first for segment matching.
local classNameToID = {}
local classNamesByLen = {}

local function EnsureClassNameMap()
    if #classNamesByLen > 0 then return end
    wipe(classNameToID)
    wipe(classNamesByLen)
    local n = GetNumClasses() or 0
    for classID = 1, n do
        local info = C_CreatureInfo.GetClassInfo(classID)
        local name = info and info.className
        if name and name ~= "" then
            classNameToID[name] = classID
            classNamesByLen[#classNamesByLen + 1] = name
        end
    end
    sort(classNamesByLen, function(a, b)
        return #a > #b
    end)
end

--- True when `name` appears as a whole list segment in `list` (comma-separated
--- or the sole entry). Avoids substring false positives.
---@param list string
---@param name string
---@return boolean
local function ClassListContainsName(list, name)
    if list == name then return true end
    local pos = 1
    while true do
        local startPos, endPos = list:find(name, pos, true)
        if not startPos then return false end
        local beforeOK = startPos == 1 or list:sub(startPos - 1, startPos - 1):match("[,，、%s]")
        local afterOK = endPos == #list or list:sub(endPos + 1, endPos + 1):match("[,，、%s]")
        if beforeOK and afterOK then return true end
        pos = startPos + 1
    end
end

---@param color table|nil colorRGB
---@return boolean
local function IsRedRequirementColor(color)
    if not color or not color.r then return false end
    return color.r > 0.8 and color.g < 0.4 and color.b < 0.4
end

---@param text string|nil
---@return string
local function StripTooltipMarkup(text)
    if not text or text == "" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

--- Nil-safe accumulator for ScanRedRequirementLines (lazily creates the table).
---@param reasons table|nil
---@param text string|nil
---@return table|nil reasons
local function AppendReason(reasons, text)
    text = StripTooltipMarkup(text)
    if text == "" then return reasons end
    reasons = reasons or {}
    reasons[#reasons + 1] = text
    return reasons
end

local bagDataCache = {}
local linkDataCache = {}
local bagTextCache = {}
local linkTextCache = {}

local function BagSlotKey(bagID, slotID)
    return bagID .. ":" .. slotID
end

local function ConcatTooltipLines(tooltipData)
    if not tooltipData or not tooltipData.lines or #tooltipData.lines == 0 then
        return ""
    end
    local parts = {}
    for _, line in ipairs(tooltipData.lines) do
        parts[#parts + 1] = line.leftText or ""
    end
    return tconcat(parts, "\n")
end

local function ProfileStart(name)
    local Profile = OneWoW_Bags_API and OneWoW_Bags_API.GetProfile()
    if Profile then Profile:Start(name) end
end

local function ProfileStop(name)
    local Profile = OneWoW_Bags_API and OneWoW_Bags_API.GetProfile()
    if Profile then Profile:Stop(name) end
end

--- Full wipe: slot tier + link tier. For character-context changes and full
--- PE:InvalidateCache. Frequent bag-update invalidation should use
--- InvalidateSlotTooltipCaches instead — hyperlink tooltips are template-scoped
--- and do not change when bag contents move.
function TooltipScanner:InvalidateTooltipCaches()
    wipe(bagDataCache)
    wipe(linkDataCache)
    wipe(bagTextCache)
    wipe(linkTextCache)
end

--- Slot tier only (bag/slot-keyed data + text). Cheap-path invalidation for
--- BAG_UPDATE_DELAYED where slot contents changed but item templates did not.
function TooltipScanner:InvalidateSlotTooltipCaches()
    wipe(bagDataCache)
    wipe(bagTextCache)
end

function TooltipScanner:InvalidateBagSlot(slotKey)
    bagDataCache[slotKey] = nil
    bagTextCache[slotKey] = nil
end

function TooltipScanner:InvalidateHyperlink(hyperlink)
    if not hyperlink then return end
    linkDataCache[hyperlink] = nil
    linkTextCache[hyperlink] = nil
end

---@param bagID number
---@param slotID number
---@return table|nil tooltipData
function TooltipScanner:GetBagItemData(bagID, slotID)
    if not bagID or not slotID then return nil end
    local key = BagSlotKey(bagID, slotID)
    local cached = bagDataCache[key]
    if cached then
        ProfileStart("tooltipDataCache.hit")
        ProfileStop("tooltipDataCache.hit")
        return cached
    end

    ProfileStart("tooltipDataCache.miss")
    local td = C_TooltipInfo.GetBagItem(bagID, slotID)
    if td then bagDataCache[key] = td end
    ProfileStop("tooltipDataCache.miss")
    return td
end

---@param hyperlink string
---@return table|nil tooltipData
function TooltipScanner:GetHyperlinkData(hyperlink)
    if not hyperlink or hyperlink == "" then return nil end
    local cached = linkDataCache[hyperlink]
    if cached then
        ProfileStart("tooltipDataLinkCache.hit")
        ProfileStop("tooltipDataLinkCache.hit")
        return cached
    end

    ProfileStart("tooltipDataLinkCache.miss")
    local td = C_TooltipInfo.GetHyperlink(hyperlink)
    if td then linkDataCache[hyperlink] = td end
    ProfileStop("tooltipDataLinkCache.miss")
    return td
end

---@param itemID number
---@return table|nil tooltipData
function TooltipScanner:GetItemByIDData(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    return C_TooltipInfo.GetItemByID(itemID)
end

---@param merchantIndex number
---@return table|nil tooltipData
function TooltipScanner:GetMerchantItemData(merchantIndex)
    merchantIndex = tonumber(merchantIndex)
    if not merchantIndex then return nil end
    return C_TooltipInfo.GetMerchantItem(merchantIndex)
end

--- First player-owned container slot holding itemID (bags 0–5, bank tabs 6–17).
---@param itemID number
---@return number|nil bagID
---@return number|nil slotID
function TooltipScanner:FindBagSlotForItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    for bag = 0, 17 do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    return bag, slot
                end
            end
        end
    end
end

--- Single-pass usability facts for character-usability resolution. One walk
--- over tooltipData.lines with no per-line table allocations.
---
--- Combine-type items (Darkmoon cards, spear parts, etc.) are NOT detectable
--- from tooltip data — the reagent lists players see are injected into the
--- displayed GameTooltip by other addons (e.g. Plumber) and never appear in
--- C_TooltipInfo data. PredicateEngine detects them structurally via
--- GetItemSpell → C_TradeSkillUI.GetRecipeSchematic before consulting facts.
---
--- unmetRequirements mirrors ScanRedRequirementLines: a red-colored left/right
--- field with visible text counts as an unmet requirement. ErrorLine and
--- DisabledLine are only treated as unmet when they are *also* red — grey
--- DisabledLines carry inactive off-spec stat variants (e.g. a trinket's
--- +Agility/+Strength lines while you're a caster), not requirement failures.
---@param tooltipData table|nil
---@return table|nil facts `{ learnSpellID?, directUse, unmetRequirements }`; nil when no tooltip data
function TooltipScanner:GetUsabilityFacts(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end

    local learnSpellID
    local directUse = false
    local unmetRequirements = false

    for _, line in ipairs(tooltipData.lines) do
        local leftText, rightText = line.leftText, line.rightText

        if not learnSpellID and line.type == LINE_LEARN and line.spellID then
            learnSpellID = line.spellID
        end

        if not directUse and leftText and strfind(leftText, usePatternHead) then
            directUse = true
        end

        if not unmetRequirements then
            if (IsRedRequirementColor(line.leftColor) and leftText and StripTooltipMarkup(leftText) ~= "")
                or (IsRedRequirementColor(line.rightColor) and rightText and StripTooltipMarkup(rightText) ~= "") then
                unmetRequirements = true
            end
        end
    end

    return {
        learnSpellID = learnSpellID,
        directUse = directUse,
        unmetRequirements = unmetRequirements,
    }
end

--- Route to the best available tooltip snapshot for an item context.
--- Precedence: live tooltipData → bag slot → merchant → hyperlink → itemByID.
---@param context table|nil `{ itemID?, hyperlink?, bagID?, slotID?, tooltipData?, merchantIndex? }`
---@return table|nil tooltipData
function TooltipScanner:ResolveItemData(context)
    if not context then return nil end
    if context.tooltipData then return context.tooltipData end

    local merchantIndex = context.merchantIndex
    if merchantIndex then
        return self:GetMerchantItemData(merchantIndex)
    end

    local bagID, slotID = context.bagID, context.slotID
    local itemID = tonumber(context.itemID)
    if itemID and not (bagID and slotID) then
        bagID, slotID = self:FindBagSlotForItem(itemID)
    end
    if bagID and slotID then
        local td = self:GetBagItemData(bagID, slotID)
        if td then return td end
    end

    if context.hyperlink then
        local td = self:GetHyperlinkData(context.hyperlink)
        if td then return td end
    end

    if itemID then
        return self:GetItemByIDData(itemID)
    end

    return nil
end

--- Bag slot first, then hyperlink — the PredicateEngine props shape.
---@param props table
---@return table|nil tooltipData
function TooltipScanner:GetPropsData(props)
    if not props then return nil end
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if bagID and slotID then
        local td = self:GetBagItemData(bagID, slotID)
        if td then return td end
    end
    local hyperlink = rawget(props, "hyperlink")
    if hyperlink then
        return self:GetHyperlinkData(hyperlink)
    end
    return nil
end

---@param bagID number
---@param slotID number
---@return string
function TooltipScanner:GetBagItemText(bagID, slotID)
    if not bagID or not slotID then return "" end
    local key = BagSlotKey(bagID, slotID)
    local cached = bagTextCache[key]
    if cached then return cached end

    local text = ConcatTooltipLines(self:GetBagItemData(bagID, slotID))
    if text == "" then return "" end

    bagTextCache[key] = text
    return text
end

---@param hyperlink string
---@return string
function TooltipScanner:GetHyperlinkText(hyperlink)
    if not hyperlink or hyperlink == "" then return "" end
    local cached = linkTextCache[hyperlink]
    if cached then return cached end

    local text = ConcatTooltipLines(self:GetHyperlinkData(hyperlink))
    if text == "" then return "" end

    linkTextCache[hyperlink] = text
    return text
end

---@param props table
---@return string
function TooltipScanner:GetPropsText(props)
    if not props then return "" end
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    local hyperlink = rawget(props, "hyperlink")
    local tt = ""
    if bagID and slotID then
        tt = self:GetBagItemText(bagID, slotID)
    end
    if tt == "" and hyperlink then
        tt = self:GetHyperlinkText(hyperlink)
    end
    return tt
end

---@param tooltipData table|nil
---@return number|nil spellID
function TooltipScanner:GetLearnSpellID(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end
    for _, line in ipairs(tooltipData.lines) do
        if line.type == LINE_LEARN and line.spellID then
            return line.spellID
        end
    end
    return nil
end

---@param tooltipData table|nil
---@return boolean
function TooltipScanner:IsAlreadyKnown(tooltipData)
    if not tooltipData or not tooltipData.lines then return false end
    for _, line in ipairs(tooltipData.lines) do
        if line.leftText and line.leftText == ITEM_SPELL_KNOWN then
            return true
        end
    end
    return false
end

---@param text string|nil
---@return boolean
function TooltipScanner:IsAlreadyKnownText(text)
    if not text or text == "" then return false end
    return strfind(text, ITEM_SPELL_KNOWN, 1, true) ~= nil
end

---@param text string|nil
---@return boolean
function TooltipScanner:HasUseEffect(text)
    if not text or text == "" then return false end
    return strfind(text, usePatternHead) ~= nil
        or strfind(text, usePatternBody, 1, true) ~= nil
end

---@param text string|nil
---@return boolean
function TooltipScanner:HasEquipEffect(text)
    if not text or text == "" then return false end
    return strfind(text, equipPatternHead) ~= nil
        or strfind(text, equipPatternBody, 1, true) ~= nil
end

---@param tooltipData table|nil
---@return number|nil bonding Enum.TooltipDataItemBinding
function TooltipScanner:GetBindState(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end
    for _, line in ipairs(tooltipData.lines) do
        if line.type == LINE_BINDING and line.bonding ~= nil then
            return line.bonding
        end
    end
    return nil
end

--- True when the item exists in backpack, equipped bags, or reagent bag.
---@param itemID number
---@return boolean
function TooltipScanner:HasItemInAccessibleBags(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    for bag = 0, PLAYER_INVENTORY_BAG_MAX do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots > 0 then
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    return true
                end
            end
        end
    end
    return false
end

--- Spell/equip fallback applies only when IsUsableItem is inventory-gated
--- (bank/warband-only), not when it reflects a real unmet requirement.
---@param bagID number|nil
---@param itemID number|nil
---@return boolean
function TooltipScanner:NeedsUsabilityFallback(bagID, itemID)
    if bagID and bagID >= 0 and bagID <= PLAYER_INVENTORY_BAG_MAX then
        return false
    end
    if bagID and bagID >= BANK_BAG_MIN then
        return true
    end
    itemID = tonumber(itemID)
    if not itemID then return false end
    if self:HasItemInAccessibleBags(itemID) then
        return false
    end
    local findBag = self:FindBagSlotForItem(itemID)
    return findBag ~= nil and findBag >= BANK_BAG_MIN
end

---@param tooltipData table|nil
---@return table|nil requirements `{ { text, requirementType } }`
function TooltipScanner:GetUsageRequirements(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end
    local requirements
    for _, line in ipairs(tooltipData.lines) do
        if line.type == LINE_USAGE_REQ and line.leftText and line.leftText ~= "" then
            requirements = requirements or {}
            requirements[#requirements + 1] = {
                text = line.leftText,
                requirementType = line.requirementType,
            }
        end
    end
    return requirements
end

--- Allowed class IDs from an ITEM_CLASSES_ALLOWED UsageRequirement line
--- ("Classes: Hunter, Shaman, …"). Viewer-independent membership — line color
--- (red unmet vs white met) is ignored. Returns nil when no Classes line.
---@param tooltipData table|nil
---@return table|nil classSet `{ [classID] = true }`
function TooltipScanner:GetAllowedClassIDs(tooltipData)
    EnsureClassNameMap()
    if not tooltipData or not tooltipData.lines then return nil end

    local list
    for _, line in ipairs(tooltipData.lines) do
        if line.type == LINE_USAGE_REQ and line.leftText then
            local text = StripTooltipMarkup(line.leftText)
            local captured = text:match(classesAllowedCapture)
            if captured then
                list = captured
                break
            end
        end
    end
    if not list or list == "" then return nil end

    local classSet
    for _, name in ipairs(classNamesByLen) do
        if ClassListContainsName(list, name) then
            classSet = classSet or {}
            classSet[classNameToID[name]] = true
        end
    end
    return classSet
end

--- Red unmet-requirement lines from a player-evaluated tooltip snapshot
--- (bag slot, merchant row, etc.). Template-only GetHyperlink / GetItemByID
--- omit these lines.
---@param tooltipData table|nil
---@return string|nil joined reasons
function TooltipScanner:ScanRedRequirementLines(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end

    local reasons
    for _, line in ipairs(tooltipData.lines) do
        -- ErrorLine/DisabledLine only count when red: grey DisabledLines carry
        -- inactive off-spec stat variants, not requirement failures.
        if line.type == LINE_ERROR or line.type == LINE_DISABLED then
            if IsRedRequirementColor(line.leftColor) then
                reasons = AppendReason(reasons, line.leftText)
            end
        elseif line.type == LINE_USAGE_REQ and IsRedRequirementColor(line.leftColor) then
            reasons = AppendReason(reasons, line.leftText)
        else
            if IsRedRequirementColor(line.leftColor) then
                reasons = AppendReason(reasons, line.leftText)
            end
            if IsRedRequirementColor(line.rightColor) then
                reasons = AppendReason(reasons, line.rightText)
            end
        end
    end

    if not reasons then return nil end
    return tconcat(reasons, "\n")
end

---@param merchantIndex number
---@return string|nil
function TooltipScanner:ScanMerchantBlockReason(merchantIndex)
    return self:ScanRedRequirementLines(self:GetMerchantItemData(merchantIndex))
end

--- Populate lazy tooltip-derived fields on a PredicateEngine props table.
--- opts.recipeAlreadyKnown(props) is an optional PE bridge for legacy recipe items.
---@param props table
---@param opts table|nil `{ recipeAlreadyKnown?: fun(props): boolean }`
---@return boolean true when tooltip text was available
function TooltipScanner:PopulateTooltipProps(props, opts)
    if not props then return false end

    local tt = self:GetPropsText(props)
    if tt == "" then
        rawset(props, "hasCharges", false)
        rawset(props, "hasUseAbility", false)
        rawset(props, "hasEquipAbility", false)
        rawset(props, "isAlreadyKnown", false)
        rawset(props, "isTradeableLoot", false)
        rawset(props, "isUnique", false)
        rawset(props, "isUniqueEquipped", false)
        rawset(props, "tooltipText", "")
        return false
    end

    local isUniqueEquipped = strfind(tt, uniqueEquipPatternHead) ~= nil
        or strfind(tt, uniqueEquipPlainBody, 1, true) ~= nil

    local td = self:GetPropsData(props)
    local isTradeableLoot = false
    if td and td.lines then
        for _, line in ipairs(td.lines) do
            if line.type == LINE_TRADE_TIME then
                isTradeableLoot = true
                break
            end
        end
    end

    rawset(props, "tooltipText", tt)
    rawset(props, "hasCharges", strfind(tt, chargesSearchPattern) ~= nil)
    rawset(props, "hasUseAbility", self:HasUseEffect(tt))
    rawset(props, "hasEquipAbility", self:HasEquipEffect(tt))
    rawset(props, "isTradeableLoot", isTradeableLoot)

    local alreadyKnown = td and self:IsAlreadyKnown(td) or self:IsAlreadyKnownText(tt)
    if not alreadyKnown and opts and opts.recipeAlreadyKnown then
        alreadyKnown = opts.recipeAlreadyKnown(props) == true
    end
    rawset(props, "isAlreadyKnown", alreadyKnown)
    rawset(props, "isUniqueEquipped", isUniqueEquipped)
    rawset(props, "isUnique", isUniqueEquipped
        or strfind(tt, uniquePatternHead) ~= nil
        or strfind(tt, uniquePlainBody, 1, true) ~= nil)
    return true
end
