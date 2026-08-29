local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local ipairs = ipairs
local tinsert, sort = tinsert, sort
local C_TradeSkillUI, C_Spell, C_Timer, C_Map, C_TooltipInfo =
    C_TradeSkillUI, C_Spell, C_Timer, C_Map, C_TooltipInfo

local L = ns.L
ns.UI = ns.UI or {}

local selectedProfession = nil
local selectedRecipe = nil
local currentSearch = ""
local panels = nil
local detailElements = {}
local listEntries = {}
local recipeListAPI = nil
local searchBox = nil
local emptyList = nil
local emptyDetail = nil
local searchTimer = nil
local recipeDetailCallbacks = {}
local filterKnownByMe = false
local filterKnownByAlts = false
local filterNotKnownByMe = false
local filterNotKnownByAlts = false
local filterHaveMaterials = false
local filterExpansion = nil

OneWoW_Catalog_TradeskillAPI = {
    RegisterRecipeCallback = function(callback)
        tinsert(recipeDetailCallbacks, callback)
    end,
}

local RECIPE_ROW_HEIGHT = 40
local REAGENT_ROW_HEIGHT = 28
local LIST_ROW_STRIDE = RECIPE_ROW_HEIGHT
local FILTER_HEADER_H = 116

local EXPANSION_DISPLAY = {
    Classic = "Classic",
    BurningCrusade = "The Burning Crusade",
    WrathOfTheLichKing = "Wrath of the Lich King",
    Cataclysm = "Cataclysm",
    MistsOfPandaria = "Mists of Pandaria",
    WarlordsOfDraenor = "Warlords of Draenor",
    Legion = "Legion",
    BattleForAzeroth = "Battle for Azeroth",
    Shadowlands = "Shadowlands",
    Dragonflight = "Dragonflight",
    TheWarWithin = "The War Within",
    Midnight = "Midnight",
}

local expandedExpansions = {}
local expandedOnHand = {}
local onHandRecipeID = nil

local RefreshRecipeList
local ShowRecipeDetail

local function GetDataAddon()
    return OneWoW_CatalogData_Tradeskills_API
end

--- Soft Storage surface (no TOC OptionalDeps). Sticky nil when Storage is off.
local function IsStorageReady()
    return OneWoW_AltTracker_Storage_API ~= nil
end

local function GetStorageItemIndex()
    local api = OneWoW_AltTracker_Storage_API
    if not api or not api.GetItemIndex then
        return nil
    end
    return api.GetItemIndex()
end

--- Account-wide owned count for an item family (includes craft-rank siblings).
--- Returns nil when Storage is unavailable (caller should fall back to xN).
---@param itemID number|nil
---@return number|nil
local function GetFamilyOwnedCount(itemID)
    if not itemID then
        return nil
    end
    local idx = GetStorageItemIndex()
    if not idx or not idx.GetFamilyLocations then
        return nil
    end
    local locs = idx:GetFamilyLocations(itemID)
    if not locs then
        return 0
    end
    local total = 0
    for _, loc in ipairs(locs) do
        total = total + (loc.count or 0)
    end
    return total
end

--- Format reagent qty: have/need when Storage is ready, else legacy xN.
---@param need number
---@param have number|nil
---@return string text
---@return boolean|nil met nil when have is unknown
local function FormatReagentHaveNeed(need, have)
    need = need or 0
    if have == nil then
        return "x" .. need, nil
    end
    return string.format("%d/%d", have, need), have >= need
end

local function GetLocationTypeLabel(locType)
    if locType == "bags" then
        return L["ITEMSEARCH_LOC_BAGS"]
    elseif locType == "bank" then
        return BANK
    elseif locType == "warband" then
        return L["ITEMSEARCH_LOC_WARBAND"]
    elseif locType == "guild" then
        return GUILD_BANK
    elseif locType == "auction" then
        return L["ITEMSEARCH_LOC_AH"]
    elseif locType == "mail" then
        return L["MAIL"]
    elseif locType == "equipped" then
        return EQUIPPED
    end
    return locType
end

--- Bucket GetFamilyLocations into owner · location rows (one per bucket).
---@param itemID number
---@return table[] rows { ownerName, locLabel, count }
local function AggregateFamilyLocationRows(itemID)
    local rows = {}
    local idx = GetStorageItemIndex()
    if not idx or not idx.GetFamilyLocations then
        return rows
    end
    local locs = idx:GetFamilyLocations(itemID)
    if not locs then
        return rows
    end

    local buckets = {}
    local order = {}
    for _, loc in ipairs(locs) do
        local locType = loc.locationType
        if locType then
            local ownerName
            local ownerKind
            local key
            if locType == "warband" then
                ownerName = L["ITEMSEARCH_LOC_WARBAND"]
                ownerKind = "warband"
                key = "WARBAND"
            elseif locType == "guild" then
                ownerName = loc.guildName or GUILD_BANK
                ownerKind = "guild"
                key = "GUILD|" .. ownerName
            elseif loc.charKey then
                ownerName = loc.name or loc.charKey
                if loc.realm and loc.realm ~= "" and not (loc.name and loc.name:find("-", 1, true)) then
                    ownerName = ownerName .. "-" .. loc.realm
                end
                ownerKind = "char"
                key = loc.charKey .. "|" .. locType
            else
                ownerName = GetLocationTypeLabel(locType)
                ownerKind = "other"
                key = locType
            end

            local bucketKey = key .. "|" .. locType
            local b = buckets[bucketKey]
            if not b then
                local locLabel = GetLocationTypeLabel(locType)
                if locType == "warband" then
                    locLabel = BANK
                end
                b = {
                    ownerName = ownerName,
                    ownerKind = ownerKind,
                    locLabel = locLabel,
                    count = 0,
                }
                buckets[bucketKey] = b
                tinsert(order, bucketKey)
            end
            b.count = b.count + (loc.count or 0)
        end
    end

    sort(order, function(a, b)
        local ea, eb = buckets[a], buckets[b]
        local kindOrder = { char = 1, warband = 2, guild = 3, other = 4 }
        local ka, kb = kindOrder[ea.ownerKind] or 9, kindOrder[eb.ownerKind] or 9
        if ka ~= kb then return ka < kb end
        if (ea.ownerName or "") ~= (eb.ownerName or "") then
            return (ea.ownerName or "") < (eb.ownerName or "")
        end
        return (ea.locLabel or "") < (eb.locLabel or "")
    end)

    for _, key in ipairs(order) do
        tinsert(rows, buckets[key])
    end
    return rows
end

--- Owned reagents for On Hand: required fixed lines with have>0, plus owned optional slot choices.
---@return table[] entries { itemID, have }
local function CollectOnHandEntries(reagents, slots)
    local entries = {}
    local seen = {}

    if reagents then
        for _, rg in ipairs(reagents) do
            local itemID = rg[1]
            local reagentType = rg[3]
            -- type 0 = schematic slot (handled via slots); type 2 = optional finishing reagent
            if itemID and reagentType ~= 0 and reagentType ~= 2 and not seen[itemID] then
                local have = GetFamilyOwnedCount(itemID)
                if have and have > 0 then
                    seen[itemID] = true
                    tinsert(entries, { itemID = itemID, have = have })
                end
            end
        end
    end

    if slots then
        for _, sl in ipairs(slots) do
            local opts = sl[5]
            if opts then
                for _, optItemID in ipairs(opts) do
                    if optItemID and not seen[optItemID] then
                        local have = GetFamilyOwnedCount(optItemID)
                        if have and have > 0 then
                            seen[optItemID] = true
                            tinsert(entries, { itemID = optItemID, have = have })
                        end
                    end
                end
            end
        end
    end

    return entries
end

--- True when every required reagent (fixed + required slots) is owned at need qty.
--- Optional finishing reagents / optional slots are ignored. Uses ownedCache when provided.
---@param recipe table
---@param addon table
---@param ownedCache table|nil
---@return boolean
local function RecipeHasRequiredMaterials(recipe, addon, ownedCache)
    if not recipe or not addon or not IsStorageReady() then
        return false
    end

    local function owned(itemID)
        if not itemID then return 0 end
        if ownedCache then
            local cached = ownedCache[itemID]
            if cached ~= nil then
                return cached
            end
            local have = GetFamilyOwnedCount(itemID) or 0
            ownedCache[itemID] = have
            return have
        end
        return GetFamilyOwnedCount(itemID) or 0
    end

    local reagents, slots = addon.GetRecipeReagents(recipe.id)

    if reagents then
        for _, rg in ipairs(reagents) do
            local itemID = rg[1]
            local qty = rg[2] or 0
            local reagentType = rg[3]
            if itemID and reagentType ~= 0 and reagentType ~= 2 then
                if owned(itemID) < qty then
                    return false
                end
            end
        end
    end

    if slots then
        for _, sl in ipairs(slots) do
            local qty = sl[2] or 0
            local required = sl[3]
            local opts = sl[5]
            if required and opts and #opts > 0 then
                local ok = false
                for _, optItemID in ipairs(opts) do
                    if owned(optItemID) >= qty then
                        ok = true
                        break
                    end
                end
                if not ok then
                    return false
                end
            end
        end
    end

    return true
end

local function FilterByHaveMaterials(recipes, addon)
    if not filterHaveMaterials or not IsStorageReady() then
        return recipes
    end
    local ownedCache = {}
    local filtered = {}
    for _, recipe in ipairs(recipes) do
        if RecipeHasRequiredMaterials(recipe, addon, ownedCache) then
            tinsert(filtered, recipe)
        end
    end
    return filtered
end

local function FilterByKnown(recipes, addon)
    if not filterKnownByMe and not filterKnownByAlts
        and not filterNotKnownByMe and not filterNotKnownByAlts then
        return recipes
    end
    local charKey = OneWoW_GUI:BuildCharKey()
    local filtered = {}
    for _, recipe in ipairs(recipes) do
        local knownBy = addon.GetRecipeKnownBy(recipe.id)
        local knownByMe = false
        local knownByAlt = false
        if knownBy then
            for _, key in ipairs(knownBy) do
                if key == charKey then
                    knownByMe = true
                else
                    knownByAlt = true
                end
            end
        end

        local include = true
        if filterKnownByMe and not knownByMe then include = false end
        if filterNotKnownByMe and knownByMe then include = false end
        if filterKnownByAlts and not knownByAlt then include = false end
        if filterNotKnownByAlts and knownByAlt then include = false end

        if include then
            tinsert(filtered, recipe)
        end
    end
    return filtered
end

local function ClearDetailElements()
    for _, el in ipairs(detailElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(detailElements)
end

local function GetLocalizedProfName(profData)
    local name = C_TradeSkillUI.GetTradeSkillDisplayName(profData.id)
    if name and name ~= "" then return name end

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profData.id)
    if info and info.professionName and info.professionName ~= "" then
        return info.professionName
    end

    return profData.name
end

local NPC_NAME_RETRY = { 0.1, 0.25, 0.5, 1.0 }

local function IsGenericNPCName(name, npcID)
    if not name or name == "" then
        return true
    end
    if npcID and name == string.format(L["QUESTS_NPC_UNNAMED"], npcID) then
        return true
    end
    return name:find("^NPC %d") ~= nil or name:find("^NPC #%d") ~= nil
end

local function ResolveCreatureName(npcID)
    local tooltipData = C_TooltipInfo.GetHyperlink(
        ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID)
    )
    if not tooltipData or not tooltipData.lines then
        return nil
    end
    for _, line in ipairs(tooltipData.lines) do
        local text = line.leftText
        if text and text ~= "" and text ~= RETRIEVING_ITEM_INFO then
            return text
        end
    end
    return nil
end

local function GetVendorsAPI()
    return OneWoW_CatalogData_Vendors_API
end

local function VendorRecord(npcID)
    local api = GetVendorsAPI()
    return api and api.GetVendor(npcID) or nil
end

local function RememberNPCName(npcID, name)
    local api = GetVendorsAPI()
    if api and not IsGenericNPCName(name, npcID) then
        api.RememberNPCName(npcID, name)
    end
end

local function PeekNPCName(npcID)
    local api = GetVendorsAPI()
    if api then
        local cached = api.GetCachedNPCName(npcID)
        if not IsGenericNPCName(cached, npcID) then
            return cached
        end
        local vendor = api.GetVendor(npcID)
        if vendor and not IsGenericNPCName(vendor.name, npcID) then
            return vendor.name
        end
    end
    local live = ResolveCreatureName(npcID)
    if not IsGenericNPCName(live, npcID) then
        RememberNPCName(npcID, live)
        return live
    end
    return nil
end

local function FillLearnNPCName(npcID, apply, isCurrent)
    local function accept(name)
        if IsGenericNPCName(name, npcID) then
            return false
        end
        RememberNPCName(npcID, name)
        apply(name)
        return true
    end

    local api = GetVendorsAPI()
    if api then
        if accept(api.GetCachedNPCName(npcID)) then
            return
        end
        local vendor = api.GetVendor(npcID)
        if vendor and accept(vendor.name) then
            return
        end
    end
    if accept(ResolveCreatureName(npcID)) then
        return
    end

    local attempt = 1
    local function retry()
        if isCurrent and not isCurrent() then
            return
        end
        api = GetVendorsAPI()
        if api and accept(api.GetCachedNPCName(npcID)) then
            return
        end
        if accept(ResolveCreatureName(npcID)) then
            return
        end
        attempt = attempt + 1
        local delay = NPC_NAME_RETRY[attempt]
        if delay then
            C_Timer.After(delay, retry)
        end
    end
    C_Timer.After(NPC_NAME_RETRY[1], retry)
end

local function LearnKindText(recipe)
    local learn = recipe.learn
    if learn == "trainer" then
        return L["TRADESKILLS_LEARN_TRAINER"]
    elseif learn == "drop" then
        return BATTLE_PET_SOURCE_1
    elseif learn == "vendor" then
        return BATTLE_PET_SOURCE_3
    elseif learn == "auto" then
        return L["TRADESKILLS_LEARN_AUTO"]
    elseif learn == "spec" then
        return PROFESSIONS_SPECIALIZATION
    elseif learn == "quest" then
        if recipe.quest then
            return BATTLE_PET_SOURCE_2 .. " " .. tostring(recipe.quest)
        end
        return BATTLE_PET_SOURCE_2
    elseif recipe.quest then
        return BATTLE_PET_SOURCE_2 .. " " .. tostring(recipe.quest)
    end
    return nil
end

local function LearnMapText(recipe)
    if not recipe.map then
        return nil
    end
    local mapInfo = C_Map.GetMapInfo(recipe.map)
    if mapInfo and mapInfo.name and mapInfo.name ~= "" then
        return mapInfo.name
    end
    return nil
end

local function RecipeShowsLearnNPC(recipe)
    local learn = recipe.learn
    return recipe.npc and recipe.npc > 0
        and learn ~= "quest"
        and learn ~= "spec"
        and learn ~= "item"
end

local function JoinLearnParts(kindText, npcName, mapText)
    local parts = {}
    if kindText then
        tinsert(parts, kindText)
    end
    if npcName then
        tinsert(parts, npcName)
    end
    if mapText then
        tinsert(parts, mapText)
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " - ")
end

local function FindProfessionByName(profName)
    if not profName then return nil end
    local addon = GetDataAddon()
    local professions = addon and addon.GetProfessions() or {}
    for _, prof in ipairs(professions) do
        if prof.hasData and prof.name == profName then
            return prof
        end
    end
    return nil
end

local function ApplyRecipeRowChrome(row, selected, zebraIndex)
    if selected then
        OneWoW_GUI:ApplyListRowFill(row, { selected = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        row.selectedAccent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        row.selectedAccent:Show()
    elseif row.entry and row.entry.type == "header" then
        OneWoW_GUI:ApplyListRowFill(row, { header = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.selectedAccent:Hide()
    else
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = zebraIndex or row._zebraIndex })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.selectedAccent:Hide()
    end
end

local function PaintDetailReagentRow(row, hover)
    if hover then
        OneWoW_GUI:ApplyListRowFill(row, { hover = true })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    else
        OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = row._zebraIndex })
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

local function FormatRecipeListMeta(recipe)
    if not recipe then return nil end

    local isSearching = currentSearch ~= "" and currentSearch ~= nil
    -- Grouped list puts recipes under expansion headers while a profession is selected.
    local underExpansionHeader = selectedProfession ~= nil and not isSearching
    local showExpansion = not filterExpansion and not underExpansionHeader
    local showProfession = not selectedProfession

    local parts = {}
    if showExpansion then
        local expDisplay = EXPANSION_DISPLAY[recipe.exp] or recipe.exp
        if expDisplay and expDisplay ~= "" then
            tinsert(parts, expDisplay)
        end
    end
    if showProfession and recipe.prof and recipe.prof ~= "" then
        tinsert(parts, recipe.prof)
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "  |  ")
end

local function CreateRecipeListRow(parent, _)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(LIST_ROW_STRIDE)
    row:SetBackdrop(BACKDROP_SIMPLE)

    local selectedAccent = row:CreateTexture(nil, "OVERLAY")
    selectedAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    selectedAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    selectedAccent:SetWidth(4)
    selectedAccent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    selectedAccent:Hide()
    row.selectedAccent = selectedAccent

    ApplyRecipeRowChrome(row, false, false)

    local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("LEFT", 8, 0)
    iconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.iconFrame = iconFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local nameText = OneWoW_GUI:CreateFS(row, 10)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local metaText = OneWoW_GUI:CreateFS(row, 9)
    metaText:SetJustifyH("LEFT")
    metaText:SetWordWrap(false)
    metaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    metaText:Hide()
    row.metaText = metaText

    local arrowText = OneWoW_GUI:CreateFS(row, 12)
    arrowText:SetPoint("LEFT", row, "LEFT", 8, 0)
    arrowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    arrowText:Hide()
    row.arrowText = arrowText

    local headerName = OneWoW_GUI:CreateFS(row, 12)
    headerName:SetPoint("LEFT", arrowText, "RIGHT", 6, 0)
    headerName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    headerName:Hide()
    row.headerName = headerName

    local countText = OneWoW_GUI:CreateFS(row, 10)
    countText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    countText:Hide()
    row.countText = countText

    row:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        local entry = myself.entry
        if entry and entry.type == "recipe" and entry.recipe then
            local recipe = entry.recipe
            if recipe.item and recipe.item > 0 then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(recipe.item)
                GameTooltip:Show()
            elseif recipe.id then
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(recipe.id)
                GameTooltip:Show()
            end
        end
    end)
    row:SetScript("OnLeave", function(myself)
        ApplyRecipeRowChrome(myself, myself._rowSelected, myself._zebraIndex)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(myself)
        local entry = myself.entry
        if not entry then
            return
        end
        if entry.type == "header" then
            expandedExpansions[entry.expKey] = not expandedExpansions[entry.expKey]
            RefreshRecipeList()
        elseif entry.type == "recipe" and recipeListAPI and myself.entryIndex then
            recipeListAPI.SetSelectedIndex(myself.entryIndex)
        end
    end)

    return row
end

local function LayoutRecipeNameMeta(row, hasMeta)
    row.nameText:ClearAllPoints()
    row.metaText:ClearAllPoints()
    if hasMeta then
        row.nameText:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 6, 2)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.metaText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -1)
        row.metaText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.metaText:Show()
    else
        row.nameText:SetPoint("LEFT", row.iconFrame, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.metaText:Hide()
        row.metaText:SetText("")
    end
end

local function BindRecipeListRow(row, index, entry, state)
    row.entry = entry
    row._rowSelected = state.selected and entry.type == "recipe" or false
    row._zebraIndex = index

    if entry.type == "header" then
        row.iconFrame:Hide()
        row.nameText:Hide()
        row.metaText:Hide()
        row.arrowText:Show()
        row.headerName:Show()
        row.countText:Show()
        row.arrowText:SetText(expandedExpansions[entry.expKey] and "v" or ">")
        row.headerName:SetText(entry.displayName or entry.expKey or "")
        row.countText:SetText(string.format(L["TRADESKILLS_RECIPES"], entry.count or 0))
        ApplyRecipeRowChrome(row, false, false)
        return
    end

    row.arrowText:Hide()
    row.headerName:Hide()
    row.countText:Hide()
    row.iconFrame:Show()
    row.nameText:Show()
    ApplyRecipeRowChrome(row, row._rowSelected, row._zebraIndex)

    local recipe = entry.recipe
    local addon = GetDataAddon()
    local bindToken = recipe and recipe.id
    row._bindToken = bindToken

    local meta = FormatRecipeListMeta(recipe)
    if meta then
        row.metaText:SetText(meta)
        LayoutRecipeNameMeta(row, true)
    else
        LayoutRecipeNameMeta(row, false)
    end

    if addon and recipe and recipe.item and recipe.item > 0 then
        local cached = addon.GetCachedItem(recipe.item)
        if cached and cached.name then
            row.nameText:SetText(cached.name)
            row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            row.icon:SetTexture(cached.icon or recipe.icon)
        else
            row.nameText:SetText("...")
            row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            row.icon:SetTexture(recipe.icon)
            addon.LoadItemData(recipe.item, function(_, itemData)
                if row:IsVisible() and row._bindToken == bindToken and itemData then
                    row.nameText:SetText(itemData.name)
                    row.nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    if itemData.icon then
                        row.icon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        row.icon:SetTexture(recipe and recipe.icon)
        local spellName = recipe and C_Spell.GetSpellName(recipe.id)
        row.nameText:SetText(spellName or (recipe and ("Recipe #" .. recipe.id)) or "")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

ShowRecipeDetail = function(recipe)
    if not panels or not recipe then return end

    selectedRecipe = recipe
    ClearDetailElements()

    if emptyDetail then emptyDetail:Hide() end

    local addon = GetDataAddon()
    if not addon then return end

    local child = panels.detailScrollChild
    local yOffset = -8

    local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    headerFrame:SetHeight(50)
    headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    tinsert(detailElements, headerFrame)

    local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    hIconFrame:SetSize(40, 40)
    hIconFrame:SetPoint("LEFT", 8, 0)
    hIconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    hIconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    hIconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local hIcon = hIconFrame:CreateTexture(nil, "ARTWORK")
    hIcon:SetPoint("TOPLEFT", 1, -1)
    hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    hIconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if recipe.item and recipe.item > 0 then
            GameTooltip:SetItemByID(recipe.item)
        elseif recipe.id then
            GameTooltip:SetSpellByID(recipe.id)
        end
        GameTooltip:Show()
    end)
    hIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local recipeName = OneWoW_GUI:CreateFS(headerFrame, 16)
    recipeName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
    recipeName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWordWrap(false)

    if recipe.item and recipe.item > 0 then
        local cached = addon.GetCachedItem(recipe.item)
        if cached and cached.name then
            recipeName:SetText(cached.name)
            recipeName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            hIcon:SetTexture(cached.icon or recipe.icon)
        else
            hIcon:SetTexture(recipe.icon)
            recipeName:SetText("...")
            recipeName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            addon.LoadItemData(recipe.item, function(_, itemData)
                if headerFrame:IsVisible() and itemData then
                    recipeName:SetText(itemData.name)
                    recipeName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    if itemData.icon then
                        hIcon:SetTexture(itemData.icon)
                    end
                end
            end)
        end
    else
        hIcon:SetTexture(recipe.icon)
        recipeName:SetText(C_Spell.GetSpellName(recipe.id) or ("Recipe #" .. recipe.id))
        recipeName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    local subInfo = OneWoW_GUI:CreateFS(headerFrame, 10)
    subInfo:SetPoint("TOPLEFT", recipeName, "BOTTOMLEFT", 0, -2)
    local expDisplay = EXPANSION_DISPLAY[recipe.exp] or recipe.exp or ""
    subInfo:SetText(expDisplay .. "  |  " .. (recipe.prof or ""))
    subInfo:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 58

    local idParts = { L["TRADESKILLS_RECIPE_ID"] .. ": " .. tostring(recipe.id) }
    if recipe.item and recipe.item > 0 then
        tinsert(idParts, L["TRADESKILLS_ITEM_ID"] .. ": " .. tostring(recipe.item))
    end
    local idLine = OneWoW_GUI:CreateFS(child, 10)
    idLine:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
    idLine:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
    idLine:SetJustifyH("LEFT")
    idLine:SetText(table.concat(idParts, "  |  "))
    idLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tinsert(detailElements, idLine)
    yOffset = yOffset - 20

    local function AddInfoRow(label, value)
        local row = CreateFrame("Frame", nil, child)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        tinsert(detailElements, row)

        local lbl = OneWoW_GUI:CreateFS(row, 10)
        lbl:SetPoint("LEFT", 0, 0)
        lbl:SetText(label .. ":")
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        lbl:SetWidth(100)
        lbl:SetJustifyH("LEFT")

        local val = OneWoW_GUI:CreateFS(row, 10)
        val:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        val:SetText(value)
        val:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - 20
    end

    if recipe.qual then
        AddInfoRow(QUALITY, string.format(L["TRADESKILLS_QUALITY_FMT"], recipe.maxQ or 3))
    end
    if recipe.rank then
        AddInfoRow(L["TRADESKILLS_RANK"], string.format(L["TRADESKILLS_RANK"], recipe.rank))
    end
    if recipe.min or recipe.hi then
        local skillText
        if recipe.min and recipe.hi then
            skillText = recipe.min .. " - " .. recipe.hi
        else
            skillText = tostring(recipe.min or recipe.hi)
        end
        AddInfoRow(PROFESSIONS_CRAFTING_STAT_TT_SKILL_HEADER, skillText)
    end

    if recipe.learn ~= "item" then
        local kindText = LearnKindText(recipe)
        local mapText = LearnMapText(recipe)
        local npcID = RecipeShowsLearnNPC(recipe) and recipe.npc or nil
        if kindText or npcID or mapText then
            local row = CreateFrame("Frame", nil, child)
            row:SetHeight(20)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            tinsert(detailElements, row)

            local lbl = OneWoW_GUI:CreateFS(row, 10)
            lbl:SetPoint("LEFT", 0, 0)
            lbl:SetText(L["TRADESKILLS_LEARNED_FROM"] .. ":")
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            lbl:SetWidth(100)
            lbl:SetJustifyH("LEFT")

            local npcName = npcID and (PeekNPCName(npcID) or string.format(L["QUESTS_NPC_UNNAMED"], npcID)) or nil
            local clickVendor = npcID and VendorRecord(npcID) ~= nil
            local npcFS, npcBtn, valueFS

            if clickVendor then
                local prev = lbl
                local gap = 4
                if kindText then
                    local kindFS = OneWoW_GUI:CreateFS(row, 10)
                    kindFS:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                    kindFS:SetText(kindText .. " - ")
                    kindFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    kindFS:SetWordWrap(false)
                    prev = kindFS
                    gap = 0
                end

                npcBtn = CreateFrame("Button", nil, row)
                npcBtn:SetHeight(20)
                npcBtn:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                npcFS = OneWoW_GUI:CreateFS(npcBtn, 10)
                npcFS:SetPoint("LEFT", 0, 0)
                npcFS:SetText(npcName)
                npcFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                npcFS:SetWordWrap(false)
                npcBtn:SetWidth(math.max(npcFS:GetStringWidth() + 2, 8))
                npcBtn:SetScript("OnEnter", function()
                    npcFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
                end)
                npcBtn:SetScript("OnLeave", function()
                    npcFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end)
                npcBtn:SetScript("OnClick", function()
                    ns.UI.OpenToVendor(npcID)
                end)

                if mapText then
                    local mapFS = OneWoW_GUI:CreateFS(row, 10)
                    mapFS:SetPoint("LEFT", npcBtn, "RIGHT", 0, 0)
                    mapFS:SetText(" - " .. mapText)
                    mapFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    mapFS:SetWordWrap(false)
                end
            else
                valueFS = OneWoW_GUI:CreateFS(row, 10)
                valueFS:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
                valueFS:SetText(JoinLearnParts(kindText, npcName, mapText) or "")
                valueFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            yOffset = yOffset - 20

            if npcID and IsGenericNPCName(npcName, npcID) then
                FillLearnNPCName(npcID, function(name)
                    if selectedRecipe ~= recipe then
                        return
                    end
                    if npcFS then
                        npcFS:SetText(name)
                        npcBtn:SetWidth(math.max(npcFS:GetStringWidth() + 2, 8))
                    elseif valueFS then
                        valueFS:SetText(JoinLearnParts(kindText, name, mapText) or "")
                    end
                end, function()
                    return selectedRecipe == recipe
                end)
            end
        end
    end

    yOffset = yOffset - 8

    -- Recipe scroll/book (not crafted output); SetItemByID feeds TooltipEngine.
    local recipeItemID = recipe.taught
    if not recipeItemID or recipeItemID <= 0 then
        recipeItemID = OneWoW.RecipeKnownUtil:GetRecipeItemID(recipe.id)
    end
    if recipeItemID then
        local recipeItemHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
        recipeItemHeader:SetHeight(24)
        recipeItemHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        recipeItemHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        recipeItemHeader:SetBackdrop(BACKDROP_SIMPLE)
        recipeItemHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        recipeItemHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, recipeItemHeader)

        local recipeItemTitle = OneWoW_GUI:CreateFS(recipeItemHeader, 12)
        recipeItemTitle:SetPoint("LEFT", 8, 0)
        recipeItemTitle:SetText(L["TRADESKILLS_RECIPE_ITEM"])
        recipeItemTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        yOffset = yOffset - 28

        local riRow = CreateFrame("Frame", nil, child, "BackdropTemplate")
        riRow:SetHeight(REAGENT_ROW_HEIGHT)
        riRow:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
        riRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        riRow:SetBackdrop(BACKDROP_SIMPLE)
        riRow._zebraIndex = 1
        PaintDetailReagentRow(riRow, false)
        tinsert(detailElements, riRow)

        local riIcon = CreateFrame("Frame", nil, riRow, "BackdropTemplate")
        riIcon:SetSize(22, 22)
        riIcon:SetPoint("LEFT", 4, 0)
        riIcon:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        riIcon:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        riIcon:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local riIconTex = riIcon:CreateTexture(nil, "ARTWORK")
        riIconTex:SetPoint("TOPLEFT", 1, -1)
        riIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
        riIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local riName = OneWoW_GUI:CreateFS(riRow, 10)
        riName:SetPoint("LEFT", riIcon, "RIGHT", 6, 0)
        riName:SetPoint("RIGHT", riRow, "RIGHT", -4, 0)
        riName:SetJustifyH("LEFT")
        riName:SetWordWrap(false)

        local riCached = addon.GetCachedItem(recipeItemID)
        if riCached and riCached.name then
            riName:SetText(riCached.name)
            riIconTex:SetTexture(riCached.icon)
            riName:SetTextColor(OneWoW_GUI:GetItemQualityColor(riCached.quality))
        else
            riName:SetText("...")
            riName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            riIconTex:SetTexture(134400)
            addon.LoadItemData(recipeItemID, function(_, itemData)
                if riRow:IsVisible() and itemData then
                    riName:SetText(itemData.name)
                    riIconTex:SetTexture(itemData.icon)
                    riName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                end
            end)
        end

        riRow:SetScript("OnEnter", function(self)
            PaintDetailReagentRow(self, true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(recipeItemID)
            GameTooltip:Show()
        end)
        riRow:SetScript("OnLeave", function(self)
            PaintDetailReagentRow(self, false)
            GameTooltip:Hide()
        end)

        yOffset = yOffset - REAGENT_ROW_HEIGHT - 8
    end

    local reagents, slots = addon.GetRecipeReagents(recipe.id)

    if reagents and #reagents > 0 then
        local reagentHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
        reagentHeader:SetHeight(24)
        reagentHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        reagentHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        reagentHeader:SetBackdrop(BACKDROP_SIMPLE)
        reagentHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        reagentHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailElements, reagentHeader)

        local reagentTitle = OneWoW_GUI:CreateFS(reagentHeader, 12)
        reagentTitle:SetPoint("LEFT", 8, 0)
        reagentTitle:SetText(L["TRADESKILLS_REAGENTS"])
        reagentTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 28

        local rgIndex = 0
        for _, rg in ipairs(reagents) do
            local reagentItemID = rg[1]
            local reagentQty = rg[2]
            local reagentType = rg[3]

            if reagentType == 0 then
                -- skip, displayed in slots section below
            else
            rgIndex = rgIndex + 1

            local rgRow = CreateFrame("Frame", nil, child, "BackdropTemplate")
            rgRow:SetHeight(REAGENT_ROW_HEIGHT)
            rgRow:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
            rgRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            rgRow:SetBackdrop(BACKDROP_SIMPLE)
            rgRow._zebraIndex = rgIndex
            PaintDetailReagentRow(rgRow, false)
            tinsert(detailElements, rgRow)

            local rgIcon = CreateFrame("Frame", nil, rgRow, "BackdropTemplate")
            rgIcon:SetSize(22, 22)
            rgIcon:SetPoint("LEFT", 4, 0)
            rgIcon:SetBackdrop(BACKDROP_INNER_NO_INSETS)
            rgIcon:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            rgIcon:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local rgIconTex = rgIcon:CreateTexture(nil, "ARTWORK")
            rgIconTex:SetPoint("TOPLEFT", 1, -1)
            rgIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
            rgIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local rgName = OneWoW_GUI:CreateFS(rgRow, 10)
            rgName:SetPoint("LEFT", rgIcon, "RIGHT", 6, 0)
            rgName:SetPoint("RIGHT", rgRow, "RIGHT", -72, 0)
            rgName:SetJustifyH("LEFT")
            rgName:SetWordWrap(false)

            local rgQty = OneWoW_GUI:CreateFS(rgRow, 10)
            rgQty:SetPoint("RIGHT", rgRow, "RIGHT", -4, 0)
            rgQty:SetWidth(64)
            rgQty:SetJustifyH("RIGHT")

            local have = GetFamilyOwnedCount(reagentItemID)
            local qtyText, met = FormatReagentHaveNeed(reagentQty, have)
            rgQty:SetText(qtyText)
            if met == true then
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            elseif met == false then
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            elseif reagentType == 2 then
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
            else
                rgQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end

            local cached = addon.GetCachedItem(reagentItemID)
            if cached and cached.name then
                rgName:SetText(cached.name)
                rgIconTex:SetTexture(cached.icon)
                rgName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
            else
                rgName:SetText("...")
                rgName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                rgIconTex:SetTexture(134400)
                addon.LoadItemData(reagentItemID, function(_, itemData)
                    if rgRow:IsVisible() and itemData then
                        rgName:SetText(itemData.name)
                        rgIconTex:SetTexture(itemData.icon)
                        rgName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                    end
                end)
            end

            rgRow:SetScript("OnEnter", function(self)
                PaintDetailReagentRow(self, true)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(reagentItemID)
                GameTooltip:Show()
            end)
            rgRow:SetScript("OnLeave", function(self)
                PaintDetailReagentRow(self, false)
                GameTooltip:Hide()
            end)

            yOffset = yOffset - REAGENT_ROW_HEIGHT

            end
        end

        if slots and #slots > 0 then
            for _, sl in ipairs(slots) do
                local opts = sl[5]
                if opts and #opts > 1 then
                    yOffset = yOffset - 4
                    local slotLabel = CreateFrame("Frame", nil, child)
                    slotLabel:SetHeight(16)
                    slotLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
                    slotLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                    tinsert(detailElements, slotLabel)

                    local slotText = OneWoW_GUI:CreateFS(slotLabel, 10)
                    slotText:SetPoint("LEFT", 0, 0)
                    local reqStr = sl[3] and L["TRADESKILLS_REAGENT_REQ"] or L["TRADESKILLS_REAGENT_OPT"]
                    slotText:SetText("Slot " .. sl[1] .. " (" .. reqStr .. ", x" .. sl[2] .. ") - " .. #opts .. " options:")
                    slotText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    yOffset = yOffset - 18

                    for _, optItemID in ipairs(opts) do
                        local optRow = CreateFrame("Frame", nil, child)
                        optRow:SetHeight(18)
                        optRow:SetPoint("TOPLEFT", child, "TOPLEFT", 28, yOffset)
                        optRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                        tinsert(detailElements, optRow)

                        local optName = OneWoW_GUI:CreateFS(optRow, 10)
                        optName:SetPoint("LEFT", 0, 0)

                        local optCached = addon.GetCachedItem(optItemID)
                        if optCached and optCached.name then
                            optName:SetText("- " .. optCached.name)
                            optName:SetTextColor(OneWoW_GUI:GetItemQualityColor(optCached.quality))
                        else
                            optName:SetText("- ...")
                            optName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                            addon.LoadItemData(optItemID, function(_, itemData)
                                if optRow:IsVisible() and itemData then
                                    optName:SetText("- " .. itemData.name)
                                    optName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                                end
                            end)
                        end

                        optRow:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetItemByID(optItemID)
                            GameTooltip:Show()
                        end)
                        optRow:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)

                        yOffset = yOffset - 18
                    end
                end
            end
        end
    end

    yOffset = yOffset - 12

    -- On Hand: account-owned reagents for this recipe (Storage soft). Expand for locations.
    if IsStorageReady() then
        if onHandRecipeID ~= recipe.id then
            wipe(expandedOnHand)
            onHandRecipeID = recipe.id
        end

        local onHandEntries = CollectOnHandEntries(reagents, slots)
        if #onHandEntries > 0 then
            local onHandHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
            onHandHeader:SetHeight(24)
            onHandHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
            onHandHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
            onHandHeader:SetBackdrop(BACKDROP_SIMPLE)
            onHandHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            onHandHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailElements, onHandHeader)

            local onHandTitle = OneWoW_GUI:CreateFS(onHandHeader, 12)
            onHandTitle:SetPoint("LEFT", 8, 0)
            onHandTitle:SetText(L["TRADESKILLS_ON_HAND"])
            onHandTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            yOffset = yOffset - 28

            for i, entry in ipairs(onHandEntries) do
                local itemID = entry.itemID
                local isExpanded = expandedOnHand[itemID] == true

                local ohBtn = CreateFrame("Button", nil, child, "BackdropTemplate")
                ohBtn:SetHeight(REAGENT_ROW_HEIGHT)
                ohBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 8, yOffset)
                ohBtn:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                ohBtn:SetBackdrop(BACKDROP_SIMPLE)
                ohBtn._zebraIndex = i
                PaintDetailReagentRow(ohBtn, false)
                tinsert(detailElements, ohBtn)

                local expandIcon = ohBtn:CreateTexture(nil, "ARTWORK")
                expandIcon:SetSize(14, 14)
                expandIcon:SetPoint("LEFT", ohBtn, "LEFT", 6, 0)
                expandIcon:SetAtlas(isExpanded and "Gamepad_Rev_Minus_64" or "Gamepad_Rev_Plus_64")

                local ohIcon = CreateFrame("Frame", nil, ohBtn, "BackdropTemplate")
                ohIcon:SetSize(22, 22)
                ohIcon:SetPoint("LEFT", expandIcon, "RIGHT", 6, 0)
                ohIcon:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                ohIcon:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                ohIcon:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                local ohIconTex = ohIcon:CreateTexture(nil, "ARTWORK")
                ohIconTex:SetPoint("TOPLEFT", 1, -1)
                ohIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
                ohIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                local ohName = OneWoW_GUI:CreateFS(ohBtn, 10)
                ohName:SetPoint("LEFT", ohIcon, "RIGHT", 6, 0)
                ohName:SetPoint("RIGHT", ohBtn, "RIGHT", -48, 0)
                ohName:SetJustifyH("LEFT")
                ohName:SetWordWrap(false)

                local ohQty = OneWoW_GUI:CreateFS(ohBtn, 10)
                ohQty:SetPoint("RIGHT", ohBtn, "RIGHT", -8, 0)
                ohQty:SetJustifyH("RIGHT")
                ohQty:SetText(tostring(entry.have))
                ohQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))

                local cached = addon.GetCachedItem(itemID)
                if cached and cached.name then
                    ohName:SetText(cached.name)
                    ohIconTex:SetTexture(cached.icon)
                    ohName:SetTextColor(OneWoW_GUI:GetItemQualityColor(cached.quality))
                else
                    ohName:SetText("...")
                    ohName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    ohIconTex:SetTexture(134400)
                    addon.LoadItemData(itemID, function(_, itemData)
                        if ohBtn:IsVisible() and itemData then
                            ohName:SetText(itemData.name)
                            ohIconTex:SetTexture(itemData.icon)
                            ohName:SetTextColor(OneWoW_GUI:GetItemQualityColor(itemData.quality))
                        end
                    end)
                end

                local capturedItemID = itemID
                ohBtn:SetScript("OnClick", function()
                    expandedOnHand[capturedItemID] = not expandedOnHand[capturedItemID]
                    if selectedRecipe then
                        ShowRecipeDetail(selectedRecipe)
                    end
                end)
                ohBtn:SetScript("OnEnter", function(self)
                    PaintDetailReagentRow(self, true)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(capturedItemID)
                    GameTooltip:Show()
                end)
                ohBtn:SetScript("OnLeave", function(self)
                    PaintDetailReagentRow(self, false)
                    GameTooltip:Hide()
                end)

                yOffset = yOffset - REAGENT_ROW_HEIGHT

                if isExpanded then
                    local locRows = AggregateFamilyLocationRows(itemID)
                    for _, locRow in ipairs(locRows) do
                        local locFrame = CreateFrame("Frame", nil, child)
                        locFrame:SetHeight(18)
                        locFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 28, yOffset)
                        locFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
                        tinsert(detailElements, locFrame)

                        local locText = OneWoW_GUI:CreateFS(locFrame, 10)
                        locText:SetPoint("LEFT", 0, 0)
                        locText:SetPoint("RIGHT", locFrame, "RIGHT", -40, 0)
                        locText:SetJustifyH("LEFT")
                        locText:SetWordWrap(false)
                        locText:SetText(locRow.ownerName .. "  |  " .. locRow.locLabel)
                        locText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

                        local locQty = OneWoW_GUI:CreateFS(locFrame, 10)
                        locQty:SetPoint("RIGHT", locFrame, "RIGHT", 0, 0)
                        locQty:SetJustifyH("RIGHT")
                        locQty:SetText(tostring(locRow.count))
                        locQty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                        yOffset = yOffset - 18
                    end
                end
            end

            yOffset = yOffset - 12
        end
    end

    local knownByHeader = CreateFrame("Frame", nil, child, "BackdropTemplate")
    knownByHeader:SetHeight(24)
    knownByHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    knownByHeader:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    knownByHeader:SetBackdrop(BACKDROP_SIMPLE)
    knownByHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    knownByHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    tinsert(detailElements, knownByHeader)

    local knownByTitle = OneWoW_GUI:CreateFS(knownByHeader, 12)
    knownByTitle:SetPoint("LEFT", 8, 0)
    knownByTitle:SetText(L["TRADESKILLS_KNOWN_BY"])
    knownByTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - 28

    local knownBy = addon.GetRecipeKnownBy(recipe.id)
    if knownBy and #knownBy > 0 then
        for _, charKey in ipairs(knownBy) do
            local charRow = CreateFrame("Frame", nil, child)
            charRow:SetHeight(18)
            charRow:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
            charRow:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
            tinsert(detailElements, charRow)

            local charText = OneWoW_GUI:CreateFS(charRow, 10)
            charText:SetPoint("LEFT", 0, 0)
            charText:SetText(charKey)
            charText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            yOffset = yOffset - 18
        end
    else
        local noData = CreateFrame("Frame", nil, child)
        noData:SetHeight(18)
        noData:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOffset)
        noData:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        tinsert(detailElements, noData)

        local noDataText = OneWoW_GUI:CreateFS(noData, 10)
        noDataText:SetPoint("LEFT", 0, 0)
        noDataText:SetText(L["TRADESKILLS_NOT_SCANNED"])
        noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yOffset = yOffset - 18
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)

    local requiredReagents = {}
    if reagents then
        for _, rg in ipairs(reagents) do
            if rg[3] ~= 0 then
                tinsert(requiredReagents, rg)
            end
        end
    end

    for _, cb in ipairs(recipeDetailCallbacks) do
        cb(recipe, requiredReagents, panels)
    end
end

local function PublishRecipeList(totalRecipes, statusText)
    local keepID = selectedRecipe and selectedRecipe.id
    local keepIndex = nil
    if keepID then
        for i, entry in ipairs(listEntries) do
            if entry.type == "recipe" and entry.recipe and entry.recipe.id == keepID then
                keepIndex = i
                break
            end
        end
    end

    if recipeListAPI then
        if keepIndex then
            recipeListAPI.SetSelectedIndex(keepIndex)
        else
            recipeListAPI.SetSelectedIndex(nil)
            recipeListAPI.Refresh()
        end
    end

    if panels.leftStatusText then
        panels.leftStatusText:SetText(statusText or string.format(L["TRADESKILLS_RECIPES"], totalRecipes or 0))
    end
end

local function BuildFlatRecipeEntries(recipes)
    wipe(listEntries)
    for _, recipe in ipairs(recipes) do
        tinsert(listEntries, { type = "recipe", recipe = recipe })
    end
    local totalCount = #recipes
    PublishRecipeList(totalCount, string.format(L["TRADESKILLS_RECIPES"], totalCount))
end

local function BuildGroupedRecipeEntries(recipes, addon)
    wipe(listEntries)
    local expansions = addon.GetExpansions()

    local grouped = {}
    for _, recipe in ipairs(recipes) do
        local key = recipe.exp or "Unknown"
        if not grouped[key] then grouped[key] = {} end
        tinsert(grouped[key], recipe)
    end

    local orderedGroups = {}
    for _, exp in ipairs(expansions) do
        if grouped[exp.key] and #grouped[exp.key] > 0 then
            tinsert(orderedGroups, { key = exp.key, order = exp.order, recipes = grouped[exp.key] })
        end
    end
    if grouped["Unknown"] and #grouped["Unknown"] > 0 then
        tinsert(orderedGroups, { key = "Unknown", order = 99, recipes = grouped["Unknown"] })
    end

    sort(orderedGroups, function(a, b) return a.order > b.order end)

    local totalRecipes = 0
    for _, group in ipairs(orderedGroups) do
        local expKey = group.key
        local expRecipes = group.recipes
        local count = #expRecipes
        totalRecipes = totalRecipes + count
        tinsert(listEntries, {
            type = "header",
            expKey = expKey,
            count = count,
            displayName = EXPANSION_DISPLAY[expKey] or expKey,
        })
        if expandedExpansions[expKey] then
            for _, recipe in ipairs(expRecipes) do
                tinsert(listEntries, { type = "recipe", recipe = recipe })
            end
        end
    end

    local profLabel = selectedProfession and selectedProfession.name or L["TRADESKILLS_ALL"]
    PublishRecipeList(totalRecipes, profLabel .. " - " .. string.format(L["TRADESKILLS_RECIPES"], totalRecipes))
end

RefreshRecipeList = function()
    if not panels then return end
    wipe(listEntries)

    local addon = GetDataAddon()
    if not addon then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_NO_DATA"])
            emptyList:Show()
        end
        if recipeListAPI then
            recipeListAPI.SetSelectedIndex(nil)
        end
        return
    end

    local isSearching = currentSearch ~= "" and currentSearch ~= nil
    local recipes

    if selectedProfession then
        recipes = addon.GetRecipesByProfession(
            selectedProfession.name,
            filterExpansion,
            isSearching and currentSearch or nil
        )
    else
        recipes = {}
        local professions = addon.GetProfessions()
        for _, prof in ipairs(professions) do
            if prof.hasData then
                local profRecipes = addon.GetRecipesByProfession(
                    prof.name,
                    filterExpansion,
                    isSearching and currentSearch or nil
                )
                if profRecipes then
                    for _, r in ipairs(profRecipes) do
                        tinsert(recipes, r)
                    end
                end
            end
        end
    end

    if (filterKnownByMe or filterKnownByAlts or filterNotKnownByMe or filterNotKnownByAlts) and recipes then
        recipes = FilterByKnown(recipes, addon)
    end

    if filterHaveMaterials and recipes then
        recipes = FilterByHaveMaterials(recipes, addon)
    end

    if not recipes or #recipes == 0 then
        if emptyList then
            emptyList:SetText(L["TRADESKILLS_EMPTY"])
            emptyList:Show()
        end
        if recipeListAPI then
            recipeListAPI.SetSelectedIndex(nil)
        end
        return
    end

    if emptyList then emptyList:Hide() end

    if isSearching or not selectedProfession then
        BuildFlatRecipeEntries(recipes)
    else
        BuildGroupedRecipeEntries(recipes, addon)
    end
end

function ns.UI.CreateTradeskillsTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP = ns.Constants.GUI.PANEL_GAP
    local KNOWN_FILTER_COL_OFFSET = 148

    local searchHeader = OneWoW_GUI:CreateFilterBar(parent, { height = FILTER_HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local profHeader = OneWoW_GUI:CreateFilterBar(parent, { height = FILTER_HEADER_H, offset = 0 })
    profHeader:ClearAllPoints()
    profHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    profHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = OneWoW_GUI:CreateSplitPanel(contentArea, { hideTitles = true })

    recipeListAPI = OneWoW_GUI:CreateVirtualizer(panels.listPanel, {
        name = "CatalogTradeskillsList",
        rowHeight = LIST_ROW_STRIDE,
        minRowHeight = LIST_ROW_STRIDE,
        numVisibleRows = 20,
        rowInset = 0,
        selectOnClick = false,
        scrollFrame = panels.listScrollFrame,
        content = panels.listScrollChild,
        getCount = function()
            return #listEntries
        end,
        getEntry = function(index)
            return listEntries[index]
        end,
        onSelect = function(_, entry)
            if entry and entry.type == "recipe" and entry.recipe then
                ShowRecipeDetail(entry.recipe)
            end
        end,
        createRow = CreateRecipeListRow,
        bindRow = BindRecipeListRow,
    })
    panels.virtualizedList = recipeListAPI

    local function ClearRecipeSelection()
        selectedRecipe = nil
        wipe(expandedExpansions)
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["TRADESKILLS_SELECT"])
            emptyDetail:Show()
        end
        for _, cb in ipairs(recipeDetailCallbacks) do
            cb(nil, nil, panels)
        end
    end

    local profDropdown, profDropText = OneWoW_GUI:CreateDropdown(profHeader, {
        width = 10,
        height = 26,
        text = L["TRADESKILLS_ALL"],
    })
    profDropdown:SetPoint("TOPLEFT", profHeader, "TOPLEFT", 8, -8)
    profDropdown:SetPoint("RIGHT", profHeader, "RIGHT", -8, 0)

    local haveMatsCheck = OneWoW_GUI:CreateCheckbox(profHeader, {
        label = L["TRADESKILLS_HAVE_MATERIALS"],
        checked = false,
    })
    haveMatsCheck:SetPoint("TOPLEFT", profDropdown, "BOTTOMLEFT", 0, -6)

    local function SyncHaveMaterialsCheckbox()
        if IsStorageReady() then
            haveMatsCheck:Enable()
        else
            filterHaveMaterials = false
            haveMatsCheck:SetChecked(false)
            haveMatsCheck:Disable()
        end
    end

    haveMatsCheck:SetScript("OnClick", function(self)
        if not IsStorageReady() then
            filterHaveMaterials = false
            self:SetChecked(false)
            return
        end
        filterHaveMaterials = self:GetChecked() and true or false
        RefreshRecipeList()
    end)

    local function SyncProfessionDropdownText()
        if selectedProfession then
            local still = FindProfessionByName(selectedProfession.name)
            if still then
                selectedProfession = still
                profDropText:SetText(GetLocalizedProfName(still))
                return
            end
            selectedProfession = nil
        end
        profDropText:SetText(L["TRADESKILLS_ALL"])
    end

    OneWoW_GUI:AttachFilterMenu(profDropdown, {
        searchable = true,
        getActiveValue = function()
            return selectedProfession and selectedProfession.name or nil
        end,
        buildItems = function()
            local items = { { value = nil, text = L["TRADESKILLS_ALL"] } }
            local addon = GetDataAddon()
            local professions = addon and addon.GetProfessions() or {}
            for _, prof in ipairs(professions) do
                if prof.hasData then
                    tinsert(items, { value = prof.name, text = GetLocalizedProfName(prof) })
                end
            end
            return items
        end,
        onSelect = function(value, text)
            selectedProfession = value and FindProfessionByName(value) or nil
            profDropText:SetText(selectedProfession and text or L["TRADESKILLS_ALL"])
            ClearRecipeSelection()
            RefreshRecipeList()
        end,
    })

    local clearBtn = OneWoW_GUI:CreateFitTextButton(searchHeader, {
        text = L["TRADESKILLS_FILTER_CLEAR"],
        height = 26,
        minWidth = 34,
    })
    clearBtn:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
        height = 26,
        placeholderText = L["TRADESKILLS_SEARCH"],
        onTextChanged = function(text)
            if searchTimer then searchTimer:Cancel() end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                if RefreshRecipeList then RefreshRecipeList() end
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -4, 0)

    local EXPANSION_OPTIONS = {
        {key = nil,                 label = L["TRADESKILLS_ALL_EXPANSIONS"]},
        {key = "Midnight",          label = EXPANSION_DISPLAY["Midnight"]},
        {key = "TheWarWithin",      label = EXPANSION_DISPLAY["TheWarWithin"]},
        {key = "Dragonflight",      label = EXPANSION_DISPLAY["Dragonflight"]},
        {key = "Shadowlands",       label = EXPANSION_DISPLAY["Shadowlands"]},
        {key = "BattleForAzeroth",  label = EXPANSION_DISPLAY["BattleForAzeroth"]},
        {key = "Legion",            label = EXPANSION_DISPLAY["Legion"]},
        {key = "WarlordsOfDraenor", label = EXPANSION_DISPLAY["WarlordsOfDraenor"]},
        {key = "MistsOfPandaria",   label = EXPANSION_DISPLAY["MistsOfPandaria"]},
        {key = "Cataclysm",         label = EXPANSION_DISPLAY["Cataclysm"]},
        {key = "WrathOfTheLichKing",label = EXPANSION_DISPLAY["WrathOfTheLichKing"]},
        {key = "BurningCrusade",    label = EXPANSION_DISPLAY["BurningCrusade"]},
        {key = "Classic",           label = EXPANSION_DISPLAY["Classic"]},
    }

    local expDropdown, expDropText = OneWoW_GUI:CreateDropdown(searchHeader, {
        width = 10,
        height = 22,
        text = L["TRADESKILLS_ALL_EXPANSIONS"],
    })
    expDropdown:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    expDropdown:SetPoint("RIGHT", searchHeader, "RIGHT", -8, 0)

    OneWoW_GUI:AttachFilterMenu(expDropdown, {
        searchable = false,
        getActiveValue = function() return filterExpansion end,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(EXPANSION_OPTIONS) do
                tinsert(items, { value = opt.key, text = opt.label })
            end
            return items
        end,
        onSelect = function(value, text)
            filterExpansion = value
            expDropText:SetText(value and text or L["TRADESKILLS_ALL_EXPANSIONS"])
            wipe(expandedExpansions)
            RefreshRecipeList()
        end,
    })

    local knownMeCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_KNOWN_ME"] })
    knownMeCheck:SetPoint("TOPLEFT", expDropdown, "BOTTOMLEFT", 0, -4)
    knownMeCheck:SetChecked(false)

    local notKnownMeCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_NOT_KNOWN_ME"] })
    notKnownMeCheck:SetPoint("LEFT", knownMeCheck, "LEFT", KNOWN_FILTER_COL_OFFSET, 0)
    notKnownMeCheck:SetChecked(false)

    local knownAltsCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_KNOWN_ALTS"] })
    knownAltsCheck:SetPoint("TOPLEFT", knownMeCheck, "BOTTOMLEFT", 0, -2)
    knownAltsCheck:SetChecked(false)

    local notKnownAltsCheck = OneWoW_GUI:CreateCheckbox(searchHeader, { label = L["TRADESKILLS_SHOW_NOT_KNOWN_ALTS"] })
    notKnownAltsCheck:SetPoint("LEFT", knownAltsCheck, "LEFT", KNOWN_FILTER_COL_OFFSET, 0)
    notKnownAltsCheck:SetChecked(false)

    local function WireKnownFilterPair(knownCheck, notKnownCheck, setKnown, setNotKnown)
        knownCheck:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setKnown(checked)
            if checked then
                setNotKnown(false)
                notKnownCheck:SetChecked(false)
            end
            RefreshRecipeList()
        end)
        notKnownCheck:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setNotKnown(checked)
            if checked then
                setKnown(false)
                knownCheck:SetChecked(false)
            end
            RefreshRecipeList()
        end)
    end

    WireKnownFilterPair(knownMeCheck, notKnownMeCheck,
        function(v) filterKnownByMe = v end,
        function(v) filterNotKnownByMe = v end)
    WireKnownFilterPair(knownAltsCheck, notKnownAltsCheck,
        function(v) filterKnownByAlts = v end,
        function(v) filterNotKnownByAlts = v end)

    clearBtn:SetScript("OnClick", function()
        currentSearch = ""
        selectedProfession = nil
        filterKnownByMe = false
        filterKnownByAlts = false
        filterNotKnownByMe = false
        filterNotKnownByAlts = false
        filterHaveMaterials = false
        filterExpansion = nil
        wipe(expandedExpansions)

        searchBox:SetText("")
        searchBox:ClearFocus()
        searchBox:RestorePlaceholder()
        knownMeCheck:SetChecked(false)
        knownAltsCheck:SetChecked(false)
        notKnownMeCheck:SetChecked(false)
        notKnownAltsCheck:SetChecked(false)
        haveMatsCheck:SetChecked(false)
        expDropText:SetText(L["TRADESKILLS_ALL_EXPANSIONS"])
        profDropText:SetText(L["TRADESKILLS_ALL"])
        SyncHaveMaterialsCheckbox()
        ClearRecipeSelection()
        RefreshRecipeList()
    end)

    SyncHaveMaterialsCheckbox()

    emptyList = OneWoW_GUI:CreateFS(panels.listScrollFrame, 12)
    emptyList:SetPoint("CENTER", panels.listScrollFrame, "CENTER", 0, 0)
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = OneWoW_GUI:CreateFS(panels.detailScrollChild, 12)
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["TRADESKILLS_SELECT"])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    panels.detailScrollChild:SetHeight(100)

    ns.UI.tradeskillsPanels = panels

    -- Start in the no-data state; the data-ready watcher swaps to the live view
    -- and refreshes the profession dropdown once Tradeskills data is queryable.
    if GetDataAddon() then
        emptyList:SetText(L["TRADESKILLS_SELECT"])
    else
        emptyList:SetText(L["TRADESKILLS_NO_DATA"])
        panels.listScrollChild:SetHeight(100)
    end

    local wired = false
    OneWoW:RegisterDataReadyWatcher("OneWoW_CatalogData_Tradeskills", function()
        local addon = GetDataAddon()
        if not addon then return end
        emptyList:SetText(L["TRADESKILLS_SELECT"])
        SyncProfessionDropdownText()
        if not wired then
            wired = true
            addon.RegisterScanCallback(function()
                if selectedProfession and RefreshRecipeList then
                    RefreshRecipeList()
                end
            end)
        end
    end)

    -- Soft Storage: refresh open recipe detail / Have Materials list when bags change.
    local storageWired = false
    OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Storage", function()
        SyncHaveMaterialsCheckbox()
        if selectedRecipe then
            ShowRecipeDetail(selectedRecipe)
        end
        if filterHaveMaterials and RefreshRecipeList then
            RefreshRecipeList()
        end
        if storageWired then return end
        local api = OneWoW_AltTracker_Storage_API
        if not api or not api.RegisterStorageChanged then return end
        storageWired = true
        api.RegisterStorageChanged(function()
            if selectedRecipe then
                ShowRecipeDetail(selectedRecipe)
            end
            if filterHaveMaterials and RefreshRecipeList then
                RefreshRecipeList()
            end
        end)
    end)

    parent:SetScript("OnShow", function()
        selectedProfession = nil
        selectedRecipe = nil
        currentSearch = ""
        filterKnownByMe = false
        filterKnownByAlts = false
        filterNotKnownByMe = false
        filterNotKnownByAlts = false
        filterHaveMaterials = false
        filterExpansion = nil
        wipe(expandedExpansions)
        wipe(expandedOnHand)
        onHandRecipeID = nil

        if searchBox then
            searchBox:SetText("")
            searchBox:RestorePlaceholder()
        end
        if knownMeCheck then knownMeCheck:SetChecked(false) end
        if knownAltsCheck then knownAltsCheck:SetChecked(false) end
        if notKnownMeCheck then notKnownMeCheck:SetChecked(false) end
        if notKnownAltsCheck then notKnownAltsCheck:SetChecked(false) end
        if haveMatsCheck then haveMatsCheck:SetChecked(false) end
        if expDropText then expDropText:SetText(L["TRADESKILLS_ALL_EXPANSIONS"]) end
        if profDropText then profDropText:SetText(L["TRADESKILLS_ALL"]) end
        SyncHaveMaterialsCheckbox()

        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["TRADESKILLS_SELECT"])
            emptyDetail:Show()
        end
        if RefreshRecipeList then RefreshRecipeList() end
    end)
end
