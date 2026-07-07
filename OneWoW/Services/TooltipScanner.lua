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

local LINE_LEARN = Enum.TooltipDataLineType.ItemSpellTriggerLearn
local LINE_BINDING = Enum.TooltipDataLineType.ItemBinding
local LINE_USAGE_REQ = Enum.TooltipDataLineType.UsageRequirement

local chargesPattern = ITEM_SPELL_CHARGES:match("|4(.-):.-%;")
local tradeablePattern = BIND_TRADE_TIME_REMAINING:match("^(.-)%%s")
local uniqueEquipPattern = ITEM_UNIQUE_EQUIPPABLE:gsub("%-", "%%-")

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

function TooltipScanner:InvalidateTooltipCaches()
    wipe(bagDataCache)
    wipe(linkDataCache)
    wipe(bagTextCache)
    wipe(linkTextCache)
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

---@param itemID number
---@return number|nil bagID
---@return number|nil slotID
function TooltipScanner:FindBagSlotForItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return bag, slot
            end
        end
    end
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
    return strfind(text, "^" .. USE_COLON) ~= nil
        or strfind(text, "\n" .. USE_COLON, 1, true) ~= nil
end

---@param text string|nil
---@return boolean
function TooltipScanner:HasEquipEffect(text)
    if not text or text == "" then return false end
    return strfind(text, "^" .. ITEM_SPELL_TRIGGER_ONEQUIP) ~= nil
        or strfind(text, "\n" .. ITEM_SPELL_TRIGGER_ONEQUIP, 1, true) ~= nil
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

--- Red unmet-requirement lines from a merchant tooltip snapshot.
---@param tooltipData table|nil
---@return string|nil joined reasons
function TooltipScanner:ScanRedRequirementLines(tooltipData)
    if not tooltipData or not tooltipData.lines then return nil end

    local reasons
    for _, line in ipairs(tooltipData.lines) do
        local c = line.leftColor
        if c and c.r and c.r > 0.8 and c.g < 0.4 and c.b < 0.4 then
            local text = line.leftText
            if text and text ~= "" then
                text = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
                if text ~= "" then
                    reasons = reasons or {}
                    reasons[#reasons + 1] = text
                end
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

    local isUniqueEquipped = strfind(tt, "^" .. uniqueEquipPattern) ~= nil
        or strfind(tt, "\n" .. ITEM_UNIQUE_EQUIPPABLE, 1, true) ~= nil

    rawset(props, "tooltipText", tt)
    rawset(props, "hasCharges", strfind(tt, "(%d+) |4" .. chargesPattern) ~= nil)
    rawset(props, "hasUseAbility", self:HasUseEffect(tt))
    rawset(props, "hasEquipAbility", self:HasEquipEffect(tt))
    rawset(props, "isTradeableLoot", strfind(tt, tradeablePattern, 1, true) ~= nil)

    local td = self:GetPropsData(props)
    local alreadyKnown = td and self:IsAlreadyKnown(td) or self:IsAlreadyKnownText(tt)
    if not alreadyKnown and opts and opts.recipeAlreadyKnown then
        alreadyKnown = opts.recipeAlreadyKnown(props) == true
    end
    rawset(props, "isAlreadyKnown", alreadyKnown)
    rawset(props, "isUniqueEquipped", isUniqueEquipped)
    rawset(props, "isUnique", isUniqueEquipped
        or strfind(tt, "^" .. ITEM_UNIQUE) ~= nil
        or strfind(tt, "\n" .. ITEM_UNIQUE, 1, true) ~= nil)
    return true
end
