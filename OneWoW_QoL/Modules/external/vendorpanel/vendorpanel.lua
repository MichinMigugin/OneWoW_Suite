-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/vendorpanel/vendorpanel.lua
local _, ns = ...
local VendorPanelModule, L = ns.ModuleRegistry:Current()
if not VendorPanelModule then return end

local OneWoW_GUI = OneWoW_GUI
local Inventory = OneWoW.Inventory

local function GetDB()
    return ns.ModuleRegistry:GetModuleBucket("vendorpanel")
end

local function GetSettings()
    local db = GetDB()
    if not db.settings then db.settings = {} end
    return db.settings
end

local function GetShowBlizzJunk()
    local db = GetDB()
    return db and db.toggles and db.toggles.show_blizz_junk or false
end

local function GetShowPanel()
    return ns.ModuleRegistry:GetToggleValue("vendorpanel", "show_panel")
end

--- True when the standalone VendorFilter addon is loaded. We defer all merchant
--- grid filtering to it while it is present (to avoid two addons fighting over
--- the same MerchantFrame_Update hook) and reposition our button clear of its
--- dropdown.
---@return boolean
local function IsVendorFilterLoaded()
    return C_AddOns.IsAddOnLoaded("VendorFilter") and true or false
end

ns.VPGetDB = GetDB
ns.VPGetSettings = GetSettings
ns.VPGetShowBlizzJunk = GetShowBlizzJunk
ns.VPGetShowPanel = GetShowPanel
ns.VPIsVendorFilterLoaded = IsVendorFilterLoaded

-- ============================================================
-- Shared state (vendorpanel-ui.lua reads ns.VPState)
-- ============================================================
local state = {
    vendorButton = nil,
    junkPreviewPanel = nil,
    panelToggleTab = nil,
    _merchantSidebarIndex = nil,
    _merchantToggleHandler = nil,
    replacementSellButton = nil,
    addTab = nil,
    optionsTab = nil,
    activePanelTab = "sell",
    neverSellDialog = nil,
    updateTicker = nil,
    currentVendorFilter = "Show All",
    showAllArmor = false,
    dimKnownItems = false,
    availableFilters = {},
    playerClass = nil,
    playerClassId = nil,
    oneTimeItems = { ilvlGear = {}, reagents = {}, custom = {} },
    collapsedCategories = { gray = false, marked = false, ilvlGear = false, reagents = false, custom = false, noValueJunk = false },
    vendorDropdown = nil,
    activeSellTicker = nil,
    activeSellConfirmTicker = nil,
    activeSellErrFrame = nil,
    vendorSellSeq = 0,
    _buttonRetry = nil,
    filteredVendorItems = {},
    clearedSlots = {},
    slotMap = {},
    _plumberPostRemap = false,
    _plumberPriceRefresh = false,
    -- hooksecurefunc("MerchantFrame_Update") cannot be removed; gate the
    -- callback so OnDisable stops merchant-grid work for the rest of the session.
    moduleActive = false,
    -- Set around junkPreviewPanel:Hide() in OnMerchantClosed so OnHide does
    -- not call MerchantFrame_Update during teardown (redraw storm on close).
    _closingMerchant = false,
}
ns.VPState = state

--- True while the Vendor Panel module may touch the open merchant frame.
---@return boolean
local function IsMerchantWorkAllowed()
    return state.moduleActive
        and MerchantFrame ~= nil
        and MerchantFrame:IsShown()
end
ns.VPIsMerchantWorkAllowed = IsMerchantWorkAllowed

local function GetItemStatus()
    return OneWoW.ItemStatus
end

-- ============================================================
-- Filter helpers (exposed in VPFilters for cross-file access)
-- ============================================================
local VPFilters = {}
ns.VPFilters = VPFilters

local function IsMount(itemLink)
    if not itemLink then return false end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Miscellaneous" and itemSubType == "Mount"
end

local function IsPet(itemLink)
    if not itemLink then return false end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        local speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        return speciesID ~= nil
    end
    return false
end

local function IsToy(itemLink)
    if not itemLink then return false end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        local toyName = C_ToyBox.GetToyInfo(itemID)
        return toyName ~= nil
    end
    return false
end

local function IsCosmetic(itemLink)
    if not itemLink then return false end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Armor" and itemSubType == "Cosmetic"
end

local function IsEnsemble(itemLink)
    if not itemLink then return false end
    if not _G["OneWoW_QoL_VendorEnsembleScanner"] then
        CreateFrame("GameTooltip", "OneWoW_QoL_VendorEnsembleScanner", nil, "GameTooltipTemplate")
    end
    local scanner = _G["OneWoW_QoL_VendorEnsembleScanner"]
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["OneWoW_QoL_VendorEnsembleScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            if text:find("Ensemble", 1, true) then return true end
            if text:find("Collect the appearances", 1, true) then return true end
        end
    end
    return false
end

local function IsAnyCosmetic(itemLink)
    if not itemLink then return false end
    return IsCosmetic(itemLink) or IsEnsemble(itemLink)
end

local function IsDecorItem(itemLink)
    if not itemLink then return false end
    return C_Item.IsDecorItem(itemLink) or false
end

local function IsHousingItem(itemLink)
    if not itemLink then return false end
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Housing"
end

local function IsConsumable(itemLink)
    if not itemLink then return false end
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Consumable"
end

local function IsReagent(itemLink)
    if not itemLink then return false end
    local _, _, _, _, _, _, _, _, _, _, _, classID = select(6, C_Item.GetItemInfo(itemLink))
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Reagent" or classID == Enum.ItemClass.Tradegoods
end

local function GetArmorTypeFromLink(itemLink)
    if not itemLink then return nil end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    if itemType == "Armor" then return itemSubType end
    return nil
end

local CLASS_ARMOR = {
    WARRIOR = "Plate",
    PALADIN = "Plate",
    DEATHKNIGHT = "Plate",
    DEMONHUNTER = "Leather",
    ROGUE = "Leather",
    MONK = "Leather",
    DRUID = "Leather",
    HUNTER = "Mail",
    SHAMAN = "Mail",
    EVOKER = "Mail",
    MAGE = "Cloth",
    PRIEST = "Cloth",
    WARLOCK = "Cloth",
}

local ARMOR_TYPES = {
    ["Cloth"] = true,
    ["Leather"] = true,
    ["Mail"] = true,
    ["Plate"] = true,
}

local function GetPreferredArmor()
    return CLASS_ARMOR[state.playerClass]
end

-- Known = collected (mounts/pets/toys/recipes/decor/transmog) or ITEM_SPELL_KNOWN.
-- Prefer Collectibles over a live GameTooltip scan: SetHyperlink often returns
-- before "Already Known" is filled on first merchant open.
local function IsAlreadyKnown(itemLink)
    if not itemLink then return false end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return false end

    local status = OneWoW.Collectibles.GetItemCollectionStatus(itemID, itemLink, { hyperlink = itemLink })
    if status and status.collected then
        return true
    end

    local Scanner = OneWoW.TooltipScanner
    local td = Scanner:GetHyperlinkData(itemLink)
    if Scanner:IsAlreadyKnown(td) then
        return true
    end
    return Scanner:IsAlreadyKnownText(Scanner:GetHyperlinkText(itemLink))
end

local function GetProfessionFromTooltip(itemLink)
    if not itemLink then return nil end
    if not _G["OneWoW_QoL_VendorProfScanner"] then
        CreateFrame("GameTooltip", "OneWoW_QoL_VendorProfScanner", nil, "GameTooltipTemplate")
    end
    local scanner = _G["OneWoW_QoL_VendorProfScanner"]
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["OneWoW_QoL_VendorProfScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            if text:find("Alchemy", 1, true) then return "Alchemy" end
            if text:find("Blacksmithing", 1, true) then return "Blacksmithing" end
            if text:find("Cooking", 1, true) then return "Cooking" end
            if text:find("Enchanting", 1, true) then return "Enchanting" end
            if text:find("Engineering", 1, true) then return "Engineering" end
            if text:find("Inscription", 1, true) then return "Inscription" end
            if text:find("Jewelcrafting", 1, true) then return "Jewelcrafting" end
            if text:find("Leatherworking", 1, true) then return "Leatherworking" end
            if text:find("Tailoring", 1, true) then return "Tailoring" end
        end
    end
    return nil
end

local professionList = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["Inscription"] = true,
    ["Jewelcrafting"] = true, ["Leatherworking"] = true, ["Tailoring"] = true,
}

local slotFilterMap = {
    ["Head"] = "INVTYPE_HEAD", ["Neck"] = "INVTYPE_NECK", ["Shoulder"] = "INVTYPE_SHOULDER",
    ["Back"] = "INVTYPE_CLOAK", ["Chest"] = "INVTYPE_CHEST", ["Waist"] = "INVTYPE_WAIST",
    ["Legs"] = "INVTYPE_LEGS", ["Feet"] = "INVTYPE_FEET", ["Wrist"] = "INVTYPE_WRIST",
    ["Hands"] = "INVTYPE_HAND", ["Rings"] = "INVTYPE_FINGER", ["Trinkets"] = "INVTYPE_TRINKET",
}

local weaponSlots = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGED = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
}

function VPFilters.CheckVendorItemFilter(itemLink, filterType)
    if not itemLink then return false end

    local matches = true

    if filterType == "Show All" then
        matches = true
    elseif filterType == "Mounts" then
        matches = IsMount(itemLink)
    elseif filterType == "Pets" then
        matches = IsPet(itemLink)
    elseif filterType == "Toys" then
        matches = IsToy(itemLink)
    elseif filterType == "Cosmetic Items" then
        matches = IsAnyCosmetic(itemLink)
    elseif filterType == "Decor" then
        matches = IsDecorItem(itemLink)
    elseif filterType == "Housing" then
        matches = IsHousingItem(itemLink)
    elseif filterType == "Consumables" then
        matches = IsConsumable(itemLink)
    elseif filterType == "Reagents" then
        matches = IsReagent(itemLink)
    elseif filterType == "Equipable" then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE"
    elseif filterType == "Weapons" then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = weaponSlots[equipSlot] or false
    elseif filterType == "Patterns" or filterType == "All Patterns" then
        local itemType = select(6, C_Item.GetItemInfo(itemLink))
        matches = itemType == "Recipe"
    elseif professionList[filterType] then
        local profession = GetProfessionFromTooltip(itemLink)
        matches = (profession == filterType)
    elseif slotFilterMap[filterType] then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = (equipSlot == slotFilterMap[filterType])
    end

    return matches
end

local filterLabelKeys = {
    ["Show All"] = "VENDOR_FILTER_SHOW_ALL",
    ["Equipable"] = "VENDOR_FILTER_EQUIPABLE",
    ["Weapons"] = "VENDOR_FILTER_WEAPONS",
    ["Patterns"] = "VENDOR_FILTER_ALL_PATTERNS",
    ["Consumables"] = "VENDOR_FILTER_CONSUMABLES",
    ["Reagents"] = "VENDOR_REAGENTS",
    ["Cosmetic Items"] = "VENDOR_FILTER_COSMETICS",
    ["Alchemy"] = "VENDOR_FILTER_PROF_ALCHEMY",
    ["Blacksmithing"] = "VENDOR_FILTER_PROF_BLACKSMITHING",
    ["Cooking"] = "VENDOR_FILTER_PROF_COOKING",
    ["Enchanting"] = "VENDOR_FILTER_PROF_ENCHANTING",
    ["Engineering"] = "VENDOR_FILTER_PROF_ENGINEERING",
    ["Inscription"] = "VENDOR_FILTER_PROF_INSCRIPTION",
    ["Jewelcrafting"] = "VENDOR_FILTER_PROF_JEWELCRAFTING",
    ["Leatherworking"] = "VENDOR_FILTER_PROF_LEATHERWORKING",
    ["Tailoring"] = "VENDOR_FILTER_PROF_TAILORING",
}

function VPFilters.ScanVendor()
    wipe(state.availableFilters)
    local nonEquipSlots = {
        ["INVTYPE_NON_EQUIP_IGNORE"] = true, ["INVTYPE_BAG"] = true,
        ["INVTYPE_TABARD"] = true, ["INVTYPE_RELIC"] = true,
    }
    local slotLabels = {
        ["INVTYPE_HEAD"] = "Head", ["INVTYPE_NECK"] = "Neck", ["INVTYPE_SHOULDER"] = "Shoulder",
        ["INVTYPE_CLOAK"] = "Back", ["INVTYPE_CHEST"] = "Chest", ["INVTYPE_WAIST"] = "Waist",
        ["INVTYPE_LEGS"] = "Legs", ["INVTYPE_FEET"] = "Feet", ["INVTYPE_WRIST"] = "Wrist",
        ["INVTYPE_HAND"] = "Hands", ["INVTYPE_FINGER"] = "Rings", ["INVTYPE_TRINKET"] = "Trinkets",
        ["INVTYPE_WEAPON"] = "Weapons", ["INVTYPE_2HWEAPON"] = "Weapons",
        ["INVTYPE_WEAPONMAINHAND"] = "Weapons", ["INVTYPE_WEAPONOFFHAND"] = "Weapons",
        ["INVTYPE_RANGED"] = "Weapons", ["INVTYPE_SHIELD"] = "Weapons", ["INVTYPE_HOLDABLE"] = "Weapons",
    }
    for i = 1, GetMerchantNumItems() do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemType, _, _, equipSlot = select(6, C_Item.GetItemInfo(itemLink))
            local armorType = GetArmorTypeFromLink(itemLink)
            if armorType then state.availableFilters[armorType] = true end
            local label = slotLabels[equipSlot]
            if equipSlot and not nonEquipSlots[equipSlot] and label then
                state.availableFilters["Equipable"] = true
                state.availableFilters[label] = true
            elseif IsMount(itemLink) then state.availableFilters["Mounts"] = true
            elseif itemType == "Recipe" then
                state.availableFilters["Patterns"] = true
                local profession = GetProfessionFromTooltip(itemLink)
                if profession then state.availableFilters[profession] = true end
            elseif IsPet(itemLink) then state.availableFilters["Pets"] = true
            elseif IsToy(itemLink) then state.availableFilters["Toys"] = true
            elseif IsAnyCosmetic(itemLink) then state.availableFilters["Cosmetic Items"] = true
            elseif IsDecorItem(itemLink) then state.availableFilters["Decor"] = true
            elseif IsHousingItem(itemLink) then state.availableFilters["Housing"] = true
            elseif IsConsumable(itemLink) then state.availableFilters["Consumables"] = true
            elseif IsReagent(itemLink) then state.availableFilters["Reagents"] = true
            end
        end
    end
end

function VPFilters.FormatMoney(amount)
    if amount <= 0 then return "0c" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local formatted = ""
    if gold > 0 then formatted = formatted .. gold .. "g" end
    if silver > 0 then formatted = formatted .. (formatted ~= "" and " " or "") .. silver .. "s" end
    if copper > 0 or formatted == "" then formatted = formatted .. (formatted ~= "" and " " or "") .. copper .. "c" end
    return formatted
end

-- ============================================================
-- Global exclusions + merchant-grid filtering
-- ============================================================
-- These power the "filter the vendor itself" features (hide non-matching
-- items, hide known items, permanently exclude whole categories) that were
-- absorbed from the standalone VendorFilter addon. The grid renderer below
-- repopulates MerchantFrame's 12 slots from a pre-built index list and
-- repaginates, the same way Blizzard's own paging works.

local EXCLUSION_KEYS = { "Mounts", "Pets", "Toys", "Cosmetics", "Decor", "Housing" }

local function GetExclusions()
    local settings = GetSettings()
    if not settings.exclusions then settings.exclusions = {} end
    return settings.exclusions
end
ns.VPGetExclusions = GetExclusions

local CUSTOM_FILTER_SLOT_COUNT = 5

local function GetCustomFilters()
    local settings = GetSettings()
    if not settings.customFilters then
        settings.customFilters = {}
    end
    for i = 1, CUSTOM_FILTER_SLOT_COUNT do
        if not settings.customFilters[i] then
            settings.customFilters[i] = { name = nil, expr = nil }
        end
    end
    return settings.customFilters
end

ns.VPGetCustomFilters = GetCustomFilters
ns.VPCustomFilterSlotCount = CUSTOM_FILTER_SLOT_COUNT

local function AnyExclusionActive()
    local ex = GetExclusions()
    for _, key in ipairs(EXCLUSION_KEYS) do
        if ex[key] then return true end
    end
    return false
end

--- True when the item belongs to a category the user has globally excluded.
---@param itemLink string
---@return boolean
local function IsExcluded(itemLink)
    local ex = GetExclusions()
    if ex.Mounts and IsMount(itemLink) then return true end
    if ex.Pets and IsPet(itemLink) then return true end
    if ex.Toys and IsToy(itemLink) then return true end
    if ex.Cosmetics and IsAnyCosmetic(itemLink) then return true end
    if ex.Decor and IsDecorItem(itemLink) then return true end
    if ex.Housing and IsHousingItem(itemLink) then return true end
    return false
end

--- Whether the item matches the active category filter, applying the same
--- preferred-armor override the fade renderer uses.
---@param itemLink string
---@param preferredArmor string|nil
---@return boolean
local function ComputeFilterMatch(itemLink, preferredArmor)
    local matches = VPFilters.CheckVendorItemFilter(itemLink, state.currentVendorFilter)
    local _, itemSubType, _, equipSlot = select(6, C_Item.GetItemInfo(itemLink))
    if state.currentVendorFilter == "Show All" then
        -- no armor override when showing all
    elseif state.showAllArmor then
        -- keep matches as is
    elseif itemSubType == preferredArmor then
        -- keep matches as is
    elseif equipSlot == "INVTYPE_CLOAK" then
        -- keep matches as is
    elseif ARMOR_TYPES[itemSubType] then
        matches = false
    end
    return matches
end
ns.VPComputeFilterMatch = ComputeFilterMatch

-- ============================================================
-- VendorPanel
-- ============================================================
local VendorPanel = {}
ns.VendorPanel = VendorPanel

function VendorPanel:GetVendorFilterDisplayLabel(filterType)
    if filterType == "Mounts" then return MOUNTS end
    if filterType == "Pets" then return PETS end
    if filterType == "Toys" then return L["VENDOR_EX_TOYS"] end
    -- Shared locale key — bare DECOR is not a Blizzard global on Retail.
    if filterType == "Decor" then return L["DECOR"] end
    if filterType == "Housing" then return L["VENDOR_EX_HOUSING"] end
    local invGlobal = slotFilterMap[filterType]
    if invGlobal then
        return _G[invGlobal]
    end
    local key = filterLabelKeys[filterType]
    if key then return L[key] end
    return filterType
end

--- True when our merchant-grid filtering should engage (hide + repaginate). We
--- stand down entirely when VendorFilter is loaded (it owns the grid then).
--- Otherwise we repaginate whenever a specific category filter is chosen, known
--- items are being hidden, or any category is globally excluded. With "Show All"
--- and no hiding, the lighter fade renderer is used instead.
---@return boolean
function VendorPanel:GridFilteringActive()
    if IsVendorFilterLoaded() then return false end
    local settings = GetSettings()
    return (state.currentVendorFilter ~= "Show All" or settings.hideKnownEntirely or AnyExclusionActive()) and true or false
end

--- Builds state.filteredVendorItems: the ordered merchant indices to display
--- after removing excluded categories, removing known items (when hide-known is
--- on), and removing non-matching items (when hide-filtered is on).
function VPFilters.BuildDisplayList()
    wipe(state.filteredVendorItems)
    local settings = GetSettings()
    local hideKnown = settings.hideKnownEntirely
    local hideNonMatching = (state.currentVendorFilter ~= "Show All")
    local preferredArmor = GetPreferredArmor()
    for i = 1, GetMerchantNumItems() do
        local itemLink = GetMerchantItemLink(i)
        if itemLink and not IsExcluded(itemLink) then
            if not (hideKnown and IsAlreadyKnown(itemLink)) then
                if not hideNonMatching or ComputeFilterMatch(itemLink, preferredArmor) then
                    tinsert(state.filteredVendorItems, i)
                end
            end
        end
    end
end

-- ---- Merchant grid renderers ----
-- RenderMerchantGrid repopulates and repaginates the 12 merchant slots from
-- state.filteredVendorItems (excluded / known / non-matching items removed).
-- FadeMerchantGrid is the lighter path used when no hiding is requested: it
-- leaves Blizzard's own layout intact and only fades / dims items in place.

--- Plumber's MerchantPrice module reads itemButton:GetID() itself, so when it is
--- active we must not also re-drive native currency display or we double it up.
--- Remapped slots must be in place before Plumber's deferred UpdateShopUI pass.
---@return boolean
local function IsPlumberMerchantActive()
    if not C_AddOns.IsAddOnLoaded("Plumber") then return false end
    local db = _G["PlumberDB"]
    if not db then return false end
    local mp = db["MerchantPrice"]
    if type(mp) == "table" then
        local enable = mp["enable"]
        if type(enable) == "boolean" then
            return enable
        elseif type(enable) == "table" then
            return enable == true
        end
        return false
    end
    return mp == true
end

--- Re-drives native currency display for a populated slot using the correct
--- merchant index (native display keys off slot position, which our remapping
--- breaks).
---@param btn integer
---@param merchantIndex integer
local function FixSlotCurrency(btn, merchantIndex)
    local moneyFrame  = _G["MerchantItem" .. btn .. "MoneyFrame"]
    local altCurrency = _G["MerchantItem" .. btn .. "AltCurrencyFrame"]
    local numCurrencies = GetMerchantItemCostInfo(merchantIndex)
    if not numCurrencies or numCurrencies == 0 then
        if altCurrency then altCurrency:Hide() end
        local info = C_MerchantFrame.GetItemInfo(merchantIndex)
        if info and info.price and info.price > 0 and moneyFrame then
            MoneyFrame_Update("MerchantItem" .. btn .. "MoneyFrame", info.price)
            moneyFrame:Show()
        end
        return
    end
    if moneyFrame then moneyFrame:Hide() end
    if altCurrency then
        MerchantFrame_UpdateAltCurrency(merchantIndex, btn, CanAffordMerchantItem(merchantIndex))
        altCurrency:Show()
    end
end

--- Second pass: hide stale currency on cleared slots; re-drive Blizzard frames when
--- Plumber is not painting prices itself.
---@param perPage integer
local function FinalizeMerchantGridCurrency(perPage)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local usePlumber = IsPlumberMerchantActive()
    for btn = 1, perPage do
        if state.clearedSlots[btn] then
            local altCurrency = _G["MerchantItem" .. btn .. "AltCurrencyFrame"]
            if altCurrency then altCurrency:Hide() end
            for j = 1, 3 do
                local cb = _G["MerchantItem" .. btn .. "AltCurrencyFrameItem" .. j]
                if cb then cb:Hide() end
            end
            local moneyFrame = _G["MerchantItem" .. btn .. "MoneyFrame"]
            if moneyFrame then moneyFrame:Hide() end
        elseif not usePlumber and state.slotMap[btn] then
            FixSlotCurrency(btn, state.slotMap[btn])
        end
    end
end

--- Plumber paints merchant prices on the frame after MerchantFrame_Update using
--- ItemButton:GetID(). Re-run the update after our remap so it reads mapped indices.
local function RefreshPlumberMerchantPrices()
    if not IsPlumberMerchantActive() then return end
    if not IsMerchantWorkAllowed() or MerchantFrame.selectedTab ~= 1 then return end
    if state._plumberPriceRefresh then return end
    state._plumberPriceRefresh = true
    C_Timer.After(0, function()
        state._plumberPriceRefresh = false
        if not IsMerchantWorkAllowed() then return end
        state._plumberPostRemap = true
        MerchantFrame_Update()
        state._plumberPostRemap = false
    end)
end

---@param btn integer
local function ClearMerchantSlot(btn)
    local merchantButton = _G["MerchantItem" .. btn]
    local itemName       = _G["MerchantItem" .. btn .. "Name"]
    local itemButton     = _G["MerchantItem" .. btn .. "ItemButton"]
    local altCurrency    = _G["MerchantItem" .. btn .. "AltCurrencyFrame"]
    state.clearedSlots[btn] = true
    itemName:SetText("")
    itemButton:Hide()
    altCurrency:Hide()
    for j = 1, 3 do
        local cb = _G["MerchantItem" .. btn .. "AltCurrencyFrameItem" .. j]
        if cb then cb:Hide() end
    end
    itemButton.IconQuestTexture:Hide()
    SetItemButtonSlotVertexColor(merchantButton, 0.4, 0.4, 0.4)
    SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
    merchantButton:SetAlpha(1)
    merchantButton:Show()
end

--- Populates merchant slot `btn` with the item at merchant index `i`, or clears
--- it when `i` is nil. Applies fade (non-matching) / dim (known) alpha.
---@param btn integer
---@param i integer|nil
---@param preferredArmor string|nil
local function UpdateMerchantSlot(btn, i, preferredArmor)
    local merchantButton = _G["MerchantItem" .. btn]
    local itemName       = _G["MerchantItem" .. btn .. "Name"]
    local itemButton     = _G["MerchantItem" .. btn .. "ItemButton"]
    local altCurrency    = _G["MerchantItem" .. btn .. "AltCurrencyFrame"]

    if i == nil then
        state.slotMap[btn] = nil
        ClearMerchantSlot(btn)
        return
    end

    local item = C_MerchantFrame.GetItemInfo(i)
    if not item or item.name == nil then
        state.slotMap[btn] = nil
        ClearMerchantSlot(btn)
        return
    end

    state.clearedSlots[btn] = nil
    state.slotMap[btn] = i
    altCurrency:Hide()
    for j = 1, 3 do
        local cb = _G["MerchantItem" .. btn .. "AltCurrencyFrameItem" .. j]
        if cb then cb:Hide() end
    end

    itemName:SetText(item.name)
    SetItemButtonTexture(itemButton, item.texture)
    MerchantFrame_UpdateAltCurrency(i, btn, CanAffordMerchantItem(i))
    altCurrency:Show()

    local itemLink = GetMerchantItemLink(i)
    MerchantFrameItem_UpdateQuality(merchantButton, itemLink)

    itemButton:SetID(i)
    itemButton:Show()
    itemButton.link = itemLink
    itemButton.texture = item.texture

    if not item.isPurchasable or not item.isUsable then
        SetItemButtonSlotVertexColor(merchantButton, 1.0, 0, 0)
        SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0)
        SetItemButtonNameFrameVertexColor(merchantButton, 1.0, 0, 0)
    else
        SetItemButtonSlotVertexColor(merchantButton, 1.0, 1.0, 1.0)
        SetItemButtonTextureVertexColor(itemButton, 1.0, 1.0, 1.0)
        SetItemButtonNormalTextureVertexColor(itemButton, 1.0, 1.0, 1.0)
        SetItemButtonNameFrameVertexColor(merchantButton, 1.0, 1.0, 1.0)
    end

    local matches = ComputeFilterMatch(itemLink, preferredArmor)
    if not matches then
        merchantButton:SetAlpha(0.4)
        SetItemButtonDesaturated(itemButton, true)
    elseif state.dimKnownItems and IsAlreadyKnown(itemLink) then
        merchantButton:SetAlpha(0.2)
        SetItemButtonDesaturated(itemButton, true)
    else
        merchantButton:SetAlpha(1.0)
        SetItemButtonDesaturated(itemButton, false)
    end
end

--- Restores all merchant slots to a clean, fully-visible state (used when
--- filtering is not engaged or the Sell tab is active). Blizzard repopulates
--- slot content on its own each MerchantFrame_Update, so we only undo our
--- alpha / desaturation.
function VendorPanel:ResetMerchantButtons()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i]
        if button then button:Show(); button:SetAlpha(1.0) end
        local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
        if itemButton then SetItemButtonDesaturated(itemButton, false) end
    end
end

--- Light renderer: keep Blizzard's layout, only fade non-matching and dim known
--- items in place. No repagination.
function VendorPanel:FadeMerchantGrid()
    local preferredArmor = GetPreferredArmor()
    local missingLink = false
    local numItems = GetMerchantNumItems() or 0
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i]
        local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
        local index = i + (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
        local itemLink = GetMerchantItemLink(index)
        if button then
            if not itemLink then
                if index <= numItems then
                    missingLink = true
                end
            else
                local matches = ComputeFilterMatch(itemLink, preferredArmor)
                button:Show()
                if matches then
                    local known = state.dimKnownItems and IsAlreadyKnown(itemLink)
                    button:SetAlpha(known and 0.2 or 1.0)
                    if itemButton then SetItemButtonDesaturated(itemButton, known and true or false) end
                else
                    button:SetAlpha(0.4)
                    if itemButton then SetItemButtonDesaturated(itemButton, true) end
                end
            end
        end
    end
    if missingLink then
        local retries = (state._merchantLinkRetries or 0) + 1
        state._merchantLinkRetries = retries
        if retries <= 3 then
            self:ScheduleMerchantGridRefresh(0.25)
        end
    end
end

--- Heavy renderer: repopulate and repaginate the 12 slots from the filtered
--- index list so excluded / known / non-matching items are physically removed.
---@param skipPlumberRefresh boolean|nil
function VendorPanel:RenderMerchantGrid(skipPlumberRefresh)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if MerchantFrame.selectedTab ~= 1 then return end

    VPFilters.BuildDisplayList()
    wipe(state.clearedSlots)
    wipe(state.slotMap)

    local preferredArmor = GetPreferredArmor()
    local perPage = MERCHANT_ITEMS_PER_PAGE
    local totalFiltered = #state.filteredVendorItems
    local totalPages = math.max(1, math.ceil(totalFiltered / perPage))
    if MerchantFrame.page > totalPages then MerchantFrame.page = totalPages end

    if totalFiltered <= perPage then
        MerchantPageText:Hide()
        MerchantPrevPageButton:Hide()
        MerchantNextPageButton:Hide()
    else
        MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, MerchantFrame.page, totalPages)
        MerchantPageText:Show()
        MerchantPrevPageButton:Show()
        MerchantNextPageButton:Show()
        if MerchantFrame.page <= 1 then MerchantPrevPageButton:Disable() else MerchantPrevPageButton:Enable() end
        if MerchantFrame.page >= totalPages then MerchantNextPageButton:Disable() else MerchantNextPageButton:Enable() end
    end

    for btn = 1, perPage do
        local filteredIndex = (MerchantFrame.page - 1) * perPage + btn
        UpdateMerchantSlot(btn, state.filteredVendorItems[filteredIndex], preferredArmor)
    end

    if IsPlumberMerchantActive() then
        FinalizeMerchantGridCurrency(perPage)
        if not skipPlumberRefresh then
            RefreshPlumberMerchantPrices()
        end
    else
        C_Timer.After(0.05, function()
            if not IsMerchantWorkAllowed() then return end
            FinalizeMerchantGridCurrency(perPage)
        end)
    end
end

--- Runs after MerchantFrame_Update when our grid filter is active.
local function DispatchMerchantGridUpdate()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local isBuyMode = (MerchantFrame.selectedTab == 1)
    if not isBuyMode then
        VendorPanel:ResetMerchantButtons()
        if state.replacementSellButton then state.replacementSellButton:Hide() end
        return
    end
    local panelShown = state.junkPreviewPanel and state.junkPreviewPanel:IsShown()
    VendorPanel:ManageBlizzardSellButton(panelShown and true or false)
    if not panelShown or IsVendorFilterLoaded() then
        VendorPanel:ResetMerchantButtons()
        return
    end
    if VendorPanel:GridFilteringActive() then
        VendorPanel:RenderMerchantGrid()
    else
        VendorPanel:FadeMerchantGrid()
    end
end

--- Re-apply fade/dim/repagination after the side panel is shown (or when
--- merchant links finish loading). DispatchMerchantGridUpdate no-ops until the
--- panel reports shown, so UpdatePreviewPanel must call this after Show.
function VendorPanel:RefreshMerchantGrid()
    if not IsMerchantWorkAllowed() then return end
    DispatchMerchantGridUpdate()
end

--- Deferred grid refresh (cancels any prior pending timer).
---@param delay number|nil
function VendorPanel:ScheduleMerchantGridRefresh(delay)
    if state._merchantGridRetry then
        state._merchantGridRetry:Cancel()
        state._merchantGridRetry = nil
    end
    state._merchantGridRetry = C_Timer.NewTimer(delay or 0.35, function()
        state._merchantGridRetry = nil
        VendorPanel:RefreshMerchantGrid()
    end)
end

function VendorPanel:IsItemInNeverSellList(itemID)
    return GetItemStatus():IsItemProtected(itemID)
end

function VendorPanel:AddToNeverSellList(itemID, itemLink)
    if not itemID then return end
    if GetItemStatus():IsItemJunk(itemID) then GetItemStatus():RemoveItemStatus(itemID) end
    GetItemStatus():MarkAsProtected(itemID, itemLink)
    print("OneWoW QoL: " .. L["VENDOR_ITEM_PROTECTED"])
    C_Timer.After(0.1, function()
        VendorPanel:UpdatePreviewPanel()
        VendorPanel:UpdateButton()
        if state.neverSellDialog and state.neverSellDialog:IsShown() then
            VendorPanel:UpdateNeverSellDialog()
        end
        VendorPanel:UpdateNeverSellButtonCount()
    end)
end

function VendorPanel:RemoveFromNeverSellList(itemID)
    if not itemID then return end
    GetItemStatus():RemoveItemStatus(itemID)
    print("OneWoW QoL: " .. L["VENDOR_PROTECTION_REMOVED"])
    C_Timer.After(0.1, function()
        VendorPanel:UpdatePreviewPanel()
        VendorPanel:UpdateButton()
        VendorPanel:UpdateNeverSellButtonCount()
    end)
end

function VendorPanel:GetNeverSellList()
    local protectedItems = {}
    local allStatuses = GetItemStatus():GetAllStatuses()
    for itemID, statusData in pairs(allStatuses) do
        if statusData.status == "Protected" then
            protectedItems[itemID] = statusData.link or true
        end
    end
    return protectedItems
end

function VendorPanel:GetGearButtonLabel()
    local settings = GetSettings()
    local ilvl = settings.gearButtonIlvl and tonumber(settings.gearButtonIlvl)
    if ilvl and ilvl > 0 then
        return string.format(L["VENDOR_GEAR_BUTTON"], ilvl)
    end
    return string.format(L["VENDOR_GEAR_BUTTON"], "—")
end

function VendorPanel:RefreshGearButton()
    if state.addTab then
        self:RelayoutAddTab()
    end
end

function VendorPanel:AddGearFromGearButton()
    local ilvl = tonumber(GetSettings().gearButtonIlvl)
    if not ilvl or ilvl <= 0 then
        print("OneWoW QoL: " .. L["VENDOR_GEAR_NO_ILVL"])
        return
    end
    self:AddGearBelowIlvl(ilvl)
end

function VendorPanel:UpdateNeverSellButtonCount()
    local count = 0
    for _ in pairs(self:GetNeverSellList()) do count = count + 1 end
    local text = string.format(L["VENDOR_PROTECTED_ITEMS_COUNT"], count)
    if state.optionsTab and state.optionsTab.neverSellBtnText then
        state.optionsTab.neverSellBtnText:SetText(text)
    end
end

function VendorPanel:GetOneTimeItems()
    return state.oneTimeItems
end

function VendorPanel:SellJunkItems()
    if state.activeSellTicker then
        state.activeSellTicker:Cancel()
        state.activeSellTicker = nil
    end
    if state.activeSellConfirmTicker then
        state.activeSellConfirmTicker:Cancel()
        state.activeSellConfirmTicker = nil
    end
    state.vendorSellSeq = (state.vendorSellSeq or 0) + 1
    local sellSeq = state.vendorSellSeq

    local oneTime = state.oneTimeItems
    local itemsToSell = {}

    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local isGray = quality == 0
                        local isMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isIlvlGear = oneTime.ilvlGear and oneTime.ilvlGear[itemInfo.itemID]
                        local isReagent = oneTime.reagents and oneTime.reagents[itemInfo.itemID]
                        local isCustom = oneTime.custom and oneTime.custom[itemInfo.itemID]
                        local isJunkItem = isGray or isMarked or isIlvlGear or isReagent or isCustom
                        if GetItemStatus():IsItemProtected(itemInfo.itemID) then isJunkItem = false end
                        if isJunkItem and not itemInfo.hasNoValue and sellPrice and sellPrice > 0 then
                            table.insert(itemsToSell, {
                                bag = bag, slot = slot, itemID = itemInfo.itemID,
                                name = itemName, sellPrice = sellPrice * (itemInfo.stackCount or 1),
                                isGray = isGray, isMarked = isMarked, isIlvlGear = isIlvlGear, isReagent = isReagent, isCustom = isCustom
                            })
                        end
                    end
                end
            end
        end
    end

    if #itemsToSell == 0 then
        print("OneWoW QoL: " .. L["VENDOR_NO_JUNK"])
        return
    end

    local vendorRefused = false
    local sellDone = false
    local pendingSells = {}
    local actualSoldCount = 0
    local actualGold = 0
    local grayCount, markedCount, ilvlGearCount, reagentsCount, customCount = 0, 0, 0, 0, 0
    local confirmTicker, sellTicker
    local summaryPrinted = false

    if not state.activeSellErrFrame then
        state.activeSellErrFrame = CreateFrame("Frame")
    end
    local errFrame = state.activeSellErrFrame
    errFrame:RegisterEvent("UI_ERROR_MESSAGE")
    errFrame:SetScript("OnEvent", function(_, _, _, msg)
        if msg == ERR_VENDOR_DOESNT_BUY then
            vendorRefused = true
            errFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            wipe(pendingSells)
            if sellTicker then sellTicker:Cancel() end
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
                state.activeSellConfirmTicker = nil
            end
            print("OneWoW QoL: " .. L["VENDOR_DOES_NOT_BUY"])
        end
    end)

    confirmTicker = C_Timer.NewTicker(0, function()
        if state.vendorSellSeq ~= sellSeq then
            if confirmTicker then confirmTicker:Cancel() end
            return
        end
        if vendorRefused then
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellConfirmTicker = nil
            end
            return
        end

        for i = #pendingSells, 1, -1 do
            local item = pendingSells[i]
            if C_Container.GetContainerItemID(item.bag, item.slot) ~= item.itemID then
                actualSoldCount = actualSoldCount + 1
                actualGold = actualGold + item.sellPrice
                if item.isGray then grayCount = grayCount + 1
                elseif item.isMarked then markedCount = markedCount + 1
                elseif item.isIlvlGear then ilvlGearCount = ilvlGearCount + 1
                elseif item.isReagent then reagentsCount = reagentsCount + 1
                elseif item.isCustom then customCount = customCount + 1
                end
                table.remove(pendingSells, i)
            end
        end

        if sellDone and #pendingSells == 0 then
            if summaryPrinted then return end
            summaryPrinted = true
            errFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellConfirmTicker = nil
            end
            if actualSoldCount > 0 then
                local moneyStr = VPFilters.FormatMoney(actualGold)
                local categoryParts = {}
                if grayCount > 0 then table.insert(categoryParts, grayCount .. " " .. L["VENDOR_SOLD_GRAY"]) end
                if markedCount > 0 then table.insert(categoryParts, markedCount .. " " .. L["VENDOR_SOLD_MARKED"]) end
                if ilvlGearCount > 0 then table.insert(categoryParts, ilvlGearCount .. " " .. L["VENDOR_SOLD_ILVL"]) end
                if reagentsCount > 0 then table.insert(categoryParts, reagentsCount .. " " .. L["VENDOR_SOLD_REAGENT"]) end
                if customCount > 0 then table.insert(categoryParts, customCount .. " " .. L["VENDOR_SOLD_CUSTOM"]) end
                local categoryStr = table.concat(categoryParts, ", ")
                print("OneWoW QoL: " .. string.format(L["VENDOR_SOLD"], actualSoldCount, categoryStr, moneyStr))
            end
        end
    end)
    state.activeSellConfirmTicker = confirmTicker

    local currentIndex = 1
    sellTicker = C_Timer.NewTicker(0.3, function()
        if state.vendorSellSeq ~= sellSeq then
            if sellTicker then sellTicker:Cancel() end
            return
        end
        if vendorRefused then
            if sellTicker then sellTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
            end
            return
        end
        if currentIndex > #itemsToSell then
            if sellTicker then sellTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
            end
            sellDone = true
            return
        end
        local item = itemsToSell[currentIndex]
        table.insert(pendingSells, item)
        ClearCursor()
        C_Container.PickupContainerItem(item.bag, item.slot)
        SellCursorItem()
        currentIndex = currentIndex + 1
    end)
    state.activeSellTicker = sellTicker
end

--- Sellable / destroyable junk counts that mirror the side panel exactly.
--- Reuses GetJunkItemsDetailed (the same source the panel renders from) so the
--- button text, button tooltip, and panel can never disagree. Returns
--- allCached=false while bag item data is still loading, so callers can retry
--- instead of locking in an early, undercounted value.
---@return integer sellable
---@return integer destroyable
---@return boolean allCached
function VendorPanel:GetJunkCounts()
    local grayItems, markedItems, ilvlGearItems, reagentItems, noValueJunkItems, customItems, allCached = self:GetJunkItemsDetailed()
    if not allCached then return 0, 0, false end
    if not GetShowBlizzJunk() then noValueJunkItems = {} end

    local sellable, destroyable = 0, 0
    for _, list in ipairs({ grayItems, markedItems, ilvlGearItems, reagentItems, customItems }) do
        for _, item in ipairs(list) do
            if not item.noSellPrice then sellable = sellable + 1 else destroyable = destroyable + 1 end
        end
    end
    for _ in ipairs(noValueJunkItems) do destroyable = destroyable + 1 end
    return sellable, destroyable, true
end

function VendorPanel:DestroyNextJunkItem()
    if OneWoW.Restriction.IsInCombat() then
        print("OneWoW QoL: Cannot destroy items while in combat.")
        return
    end
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local classID, subclassID = select(12, C_Item.GetItemInfo(itemInfo.itemID))
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local isCustom = state.oneTimeItems.custom[itemInfo.itemID]
                        local isJunkItem = isUserMarked or isGray or isGameJunk or isIlvlGear or isReagent or isCustom
                        if isJunkItem and (itemInfo.hasNoValue or not sellPrice or sellPrice == 0) then
                            local shouldDestroy = false
                            if isUserMarked or isIlvlGear or isReagent or isCustom then shouldDestroy = true
                            elseif (isGray or isGameJunk) and GetShowBlizzJunk() then shouldDestroy = true
                            end
                            if shouldDestroy then
                                ClearCursor()
                                C_Container.PickupContainerItem(bag, slot)
                                DeleteCursorItem()
                                print("OneWoW QoL: Destroyed " .. (itemName or "item") .. ".")
                                C_Timer.After(0.2, function()
                                    VendorPanel:UpdatePreviewPanel()
                                    VendorPanel:UpdateButton()
                                end)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    print("OneWoW QoL: No junk items to destroy.")
end

function VendorPanel:DeleteAllNoValueJunk()
    if OneWoW.Restriction.IsInCombat() then
        print("OneWoW QoL: Cannot delete items while in combat.")
        return
    end
    local itemsToDelete = {}
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID = C_Item.GetItemInfo(itemInfo.itemID)
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local isCustom = state.oneTimeItems.custom[itemInfo.itemID]
                        local shouldDelete = false
                        if isUserMarked or isIlvlGear or isReagent or isCustom then shouldDelete = true
                        elseif (isGray or isGameJunk) and GetShowBlizzJunk() then shouldDelete = true
                        end
                        if shouldDelete and (itemInfo.hasNoValue or not sellPrice or sellPrice == 0) then
                            table.insert(itemsToDelete, { bag = bag, slot = slot, name = itemName })
                        end
                    end
                end
            end
        end
    end
    if #itemsToDelete == 0 then
        print("OneWoW QoL: No no-value junk items to delete.")
        return
    end
    print("OneWoW QoL: Deleting " .. #itemsToDelete .. " no-value junk items...")
    local currentIndex = 1
    local deleteTicker
    deleteTicker = C_Timer.NewTicker(0.2, function()
        if currentIndex > #itemsToDelete then
            deleteTicker:Cancel()
            print("OneWoW QoL: Deleted " .. #itemsToDelete .. " no-value junk items.")
            C_Timer.After(0.2, function()
                VendorPanel:UpdatePreviewPanel()
                VendorPanel:UpdateButton()
            end)
            return
        end
        local item = itemsToDelete[currentIndex]
        ClearCursor()
        C_Container.PickupContainerItem(item.bag, item.slot)
        DeleteCursorItem()
        currentIndex = currentIndex + 1
    end)
end

function VendorPanel:AddNonSoulboundReagents()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk then
                                local isReagent = (classID == Enum.ItemClass.Reagent or classID == Enum.ItemClass.Tradegoods)
                                if isReagent then
                                    local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                    if not isSoulbound then
                                        state.oneTimeItems.reagents[itemInfo.itemID] = true
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " non-soulbound reagents/tradeskill items to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No non-soulbound reagents or tradeskill items found.")
    end
end

function VendorPanel:AddConsumables()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk and classID == Enum.ItemClass.Consumable then
                                local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                if not isSoulbound then
                                    state.oneTimeItems.reagents[itemInfo.itemID] = true
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " non-soulbound consumables to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No non-soulbound consumables found.")
    end
end

function VendorPanel:AddWhiteQuality()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality == 1 and not alreadyJunk then
                                local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                if not isSoulbound then
                                    state.oneTimeItems.reagents[itemInfo.itemID] = true
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " white quality items to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No white quality items found.")
    end
end

function VendorPanel:AddGearBelowIlvl(targetIlvl)
    local count = 0
    local settings = GetSettings()
    local excludeIlvl1 = settings.gearSkipIlvl1 ~= false
    if state.optionsTab and state.optionsTab.excludeIlvl1 then
        excludeIlvl1 = state.optionsTab.excludeIlvl1:GetChecked()
    end
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLevel = 0
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                            end
                        end
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk then
                                local isEquipment = (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
                                if isEquipment and itemLevel and itemLevel < targetIlvl then
                                    if not (excludeIlvl1 and itemLevel == 1) then
                                        state.oneTimeItems.ilvlGear[itemInfo.itemID] = true
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: " .. string.format(L["VENDOR_GEAR_ADDED"], count, targetIlvl))
        self:UpdatePreviewPanel()
        self:UpdateButton()
        self:SetVendorTab("sell")
    else
        print("OneWoW QoL: " .. string.format(L["VENDOR_GEAR_NONE"], targetIlvl))
    end
end

local SEARCH_PREVIEW_ITEM_LIMIT = 50

--- Scan bags for items matching a bag-search expression (same syntax as the Bags
--- search box). Reuses the shared PredicateEngine.
---@param expr string
---@param collectDetails number|nil max item rows to return (0 = IDs/count only)
---@return table result { valid, empty, error, totalCount, itemIDs, items }
function VendorPanel:GetSearchMatches(expr, collectDetails)
    expr = expr and strtrim(expr) or ""
    if expr == "" then
        return { valid = false, empty = true, error = nil, totalCount = 0, itemIDs = {}, items = {} }
    end
    local PE = OneWoW.PredicateEngine
    local compiled, err = OneWoW.SearchExpand:Compile(expr)
    if not compiled then
        return { valid = false, empty = false, error = err, totalCount = 0, itemIDs = {}, items = {} }
    end
    local detailLimit = collectDetails
    if detailLimit == nil then detailLimit = SEARCH_PREVIEW_ITEM_LIMIT end
    local itemIDs = {}
    local items = {}
    local totalCount = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID and not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                    local props = PE:BuildProps(itemInfo.itemID, bag, slot, itemInfo)
                    if PE:SafeEvaluate(compiled, props) then
                        totalCount = totalCount + 1
                        itemIDs[itemInfo.itemID] = true
                        if detailLimit > 0 and #items < detailLimit then
                            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture, sellPrice =
                                C_Item.GetItemInfo(itemInfo.itemID)
                            if not itemName then
                                C_Item.RequestLoadItemDataByID(itemInfo.itemID)
                                itemName = "Item " .. itemInfo.itemID
                            end
                            local itemLevel, actualItemLink = 0, itemLink
                            local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                            if itemLocation and C_Item.DoesItemExist(itemLocation) then
                                local item = Item:CreateFromItemLocation(itemLocation)
                                if item and item:IsItemDataCached() then
                                    itemLevel = item:GetCurrentItemLevel() or 0
                                    actualItemLink = item:GetItemLink() or itemLink
                                end
                            end
                            items[#items + 1] = {
                                itemID = itemInfo.itemID,
                                link = actualItemLink or itemLink,
                                icon = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
                                stackCount = itemInfo.stackCount or 1,
                                itemLevel = itemLevel,
                                sellPrice = sellPrice or 0,
                            }
                        end
                    end
                end
            end
        end
    end
    return { valid = true, empty = false, error = nil, totalCount = totalCount, itemIDs = itemIDs, items = items }
end

function VendorPanel:GetCustomFilterSlotLabel(slotIndex)
    local slot = GetCustomFilters()[slotIndex]
    if slot and slot.name and slot.name ~= "" then
        return slot.name
    end
    return string.format(L["VENDOR_CUSTOM_SLOT"], slotIndex)
end

function VendorPanel:CustomFilterSlotIsEmpty(slotIndex)
    local slot = GetCustomFilters()[slotIndex]
    return not slot or not slot.expr or slot.expr == ""
end

function VendorPanel:SaveCustomFilterSlot(slotIndex, name, expr)
    local filters = GetCustomFilters()
    filters[slotIndex] = { name = name, expr = expr }
end

function VendorPanel:ClearCustomFilterSlot(slotIndex)
    local filters = GetCustomFilters()
    filters[slotIndex] = { name = nil, expr = nil }
    print("OneWoW QoL: " .. string.format(L["VENDOR_FILTER_SLOT_CLEARED"], slotIndex))
end

--- Add bag items matching a saved filter and switch to the sell list.
function VendorPanel:ApplyCustomFilterSlot(slotIndex)
    local slot = GetCustomFilters()[slotIndex]
    if not slot or not slot.expr or slot.expr == "" then return end
    if state.addTab and state.addTab.searchBox then
        state.addTab.searchBox:SetText(slot.expr)
        state.addTab.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    self:AddSearchMatches(slot.expr)
end

--- Add every bag item matching a bag-search expression to the sell list.
function VendorPanel:AddSearchMatches(expr)
    local result = self:GetSearchMatches(expr, 0)
    if result.empty then
        print("OneWoW QoL: " .. L["VENDOR_SEARCH_EMPTY"])
        return
    end
    if not result.valid then
        print("OneWoW QoL: " .. L["VENDOR_SEARCH_INVALID"] .. (result.error and (" " .. result.error) or ""))
        return
    end
    if result.totalCount > 0 then
        for itemID in pairs(result.itemIDs) do
            state.oneTimeItems.custom[itemID] = true
        end
        print("OneWoW QoL: " .. string.format(L["VENDOR_SEARCH_ADDED"], result.totalCount, expr))
        self:UpdatePreviewPanel()
        self:UpdateButton()
        self:UpdateSearchPreview()
        self:SetVendorTab("sell")
    else
        print("OneWoW QoL: " .. string.format(L["VENDOR_SEARCH_NONE"], expr))
        self:UpdateSearchPreview()
    end
end

--- Set of itemIDs that belong to any equipment-manager set, so "Add Soulbound
--- Equipment" can skip gear the player has saved into a set.
local function BuildEquipmentSetItemIDs()
    local inSet = {}
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        if itemIDs then
            for _, itemID in pairs(itemIDs) do
                if itemID and itemID > 0 then inSet[itemID] = true end
            end
        end
    end
    return inSet
end

--- Add all soulbound equippable items (weapons/armor) to the sell list, skipping
--- anything saved into an equipment-manager set.
function VendorPanel:AddSoulboundEquipment()
    local inSet = BuildEquipmentSetItemIDs()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID and not inSet[itemInfo.itemID]
                   and not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                    local classID = select(12, C_Item.GetItemInfo(itemInfo.itemID))
                    local isEquipment = (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
                    if isEquipment then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        local isSoulbound = itemLocation and C_Item.DoesItemExist(itemLocation) and C_Item.IsBound(itemLocation)
                        if isSoulbound then
                            state.oneTimeItems.custom[itemInfo.itemID] = true
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: " .. string.format(L["VENDOR_SOULBOUND_ADDED"], count))
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: " .. L["VENDOR_SOULBOUND_NONE"])
    end
end

-- Count colors match the side panel: destroy = theme red, sell = gray-items grey.
-- Display order is always destroy then sell (same as the panel bottom row).
local SELL_COUNT_R, SELL_COUNT_G, SELL_COUNT_B = 0.7, 0.7, 0.7

local function ColorCount(n, r, g, b)
    return string.format("|cff%02x%02x%02x%d|r", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5, n)
end

function VendorPanel:FormatDestroyCount(n)
    local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED")
    return ColorCount(n, r, g, b)
end

function VendorPanel:FormatSellCount(n)
    return ColorCount(n, SELL_COUNT_R, SELL_COUNT_G, SELL_COUNT_B)
end

function VendorPanel:GetSellCountColor()
    return SELL_COUNT_R, SELL_COUNT_G, SELL_COUNT_B
end

function VendorPanel:FormatSellCountsText(destroyCount, sellCount)
    local fmt = L["VENDOR_SELL_COUNTS"]:gsub("%%d", "%%s")
    return string.format(fmt, self:FormatDestroyCount(destroyCount), self:FormatSellCount(sellCount))
end

function VendorPanel:FormatCountsLabelText(destroyCount, sellCount)
    local fmt = L["VENDOR_COUNTS_LABEL"]:gsub("%%d", "%%s")
    return string.format(fmt, self:FormatDestroyCount(destroyCount), self:FormatSellCount(sellCount))
end

function VendorPanel:FormatDestroyButtonText(destroyCount)
    local fmt = L["VENDOR_DESTROY_COUNT"]:gsub("%%d", "%%s")
    return string.format(fmt, self:FormatDestroyCount(destroyCount))
end

function VendorPanel:FormatSellButtonText(sellCount)
    local fmt = L["VENDOR_SELL_COUNT"]:gsub("%%d", "%%s")
    return string.format(fmt, self:FormatSellCount(sellCount))
end

function VendorPanel:UpdateButton()
    if not state.moduleActive then return end
    if not state.vendorButton then return end
    local sellCount, destroyCount, allCached = self:GetJunkCounts()
    if not allCached then
        if state._buttonRetry then state._buttonRetry:Cancel() end
        state._buttonRetry = C_Timer.NewTimer(0.3, function()
            if not state.moduleActive then return end
            VendorPanel:UpdateButton()
        end)
        return
    end
    ---@diagnostic disable-next-line: undefined-field
    local btnText = state.vendorButton.text
    btnText:SetText(self:FormatSellCountsText(destroyCount, sellCount))
    if sellCount > 0 or destroyCount > 0 then
        state.vendorButton:Enable()
        state.vendorButton:SetAlpha(1.0)
    else
        state.vendorButton:Disable()
        state.vendorButton:SetAlpha(0.6)
    end
end

function VendorPanel:UpdatePanelToggleButton()
    if not state.panelToggleTab then return end
    local panelShown = state.junkPreviewPanel and state.junkPreviewPanel:IsShown()
    state.panelToggleTab:SetChecked(panelShown)
    local gui = OneWoW_GUI
    if gui then
        local theme = (gui.GetSetting and gui:GetSetting("minimap.theme")) or "horde"
        state.panelToggleTab.Icon:SetTexture(gui:GetBrandIcon(theme))
    end
    state.panelToggleTab.Icon:SetSize(24, 24)
end

function VendorPanel:ManageBlizzardSellButton(hideIt)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local blizzButton = _G["MerchantSellAllJunkButton"]
    if not blizzButton then return end
    if hideIt then
        blizzButton:Hide()
        if not state.replacementSellButton then self:CreateReplacementSellButton() end
        if state.replacementSellButton then state.replacementSellButton:Show() end
    else
        blizzButton:Show()
        if state.replacementSellButton then state.replacementSellButton:Hide() end
    end
end

function VendorPanel:TogglePreviewPanel()
    if state._merchantToggleHandler then
        state._merchantToggleHandler()
        return
    end

    if not state.junkPreviewPanel then self:CreatePreviewPanel() end
    if state.junkPreviewPanel:IsShown() then
        state.junkPreviewPanel.manuallyHidden = true
        state.junkPreviewPanel:Hide()
        self:ManageBlizzardSellButton(false)
    else
        state.junkPreviewPanel.manuallyHidden = false
        state.junkPreviewPanel:Show()
        self:UpdatePreviewPanel()
        self:ManageBlizzardSellButton(true)
    end
    self:UpdatePanelToggleButton()
end

function VendorPanel:ToggleNeverSellDialog()
    if not state.neverSellDialog then self:CreateNeverSellDialog() end
    if state.neverSellDialog:IsShown() then
        state.neverSellDialog:Hide()
    else
        self:UpdateNeverSellDialog()
        state.neverSellDialog:ClearAllPoints()
        state.neverSellDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        state.neverSellDialog:Show()
    end
end

function VendorPanel:StartUpdates()
    if state.updateTicker then return end
    state.updateTicker = C_Timer.NewTicker(5.0, function()
        if not state.moduleActive then return end
        if OneWoW.Restriction.IsInCombat() or IsInInstance() then return end
        VendorPanel:UpdateButton()
        VendorPanel:UpdatePreviewPanel()
    end)
end

function VendorPanel:StopUpdates()
    if state.updateTicker then
        state.updateTicker:Cancel()
        state.updateTicker = nil
    end
end

--- Apply the user's persistent default for Blizzard's native merchant filter.
--- "all" shows every item (LE_LOOT_FILTER_ALL); anything else restores Blizzard's
--- current-spec default. Runs on every vendor open and when the option changes.
function VendorPanel:SyncMerchantSpecFilter()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    if (GetSettings().defaultMerchantFilter or "spec") == "all" then
        SetMerchantFilter(LE_LOOT_FILTER_ALL)
    else
        ResetSetMerchantFilter()
    end

    if MerchantFrame.FilterDropdown and MerchantFrame.FilterDropdown:IsShown() then
        MerchantFrame.FilterDropdown:Update()
    end

    self:RerenderMerchantGrid()
end

--- Repaginate + rescan the merchant grid and refresh our filter dropdown label.
--- Used by both the merchant-filter sync and the panel-side toggles (armor dim,
--- known-item handling) that change what our grid shows without touching the
--- native Blizzard filter.
function VendorPanel:RerenderMerchantGrid()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    MerchantFrame.page = 1
    MerchantFrame_Update()
    VPFilters.ScanVendor()

    if state.vendorDropdown and state.vendorDropdown.RefreshFilters then
        state.vendorDropdown:RefreshFilters()
    end
end

function VendorPanel:OnMerchantShow()
    state.currentVendorFilter = "Show All"
    local settings = GetSettings()
    state.showAllArmor = settings.showAllArmor or false
    state.dimKnownItems = settings.dimKnownItems or false
    state._merchantLinkRetries = 0
    state._knownDimRetryScheduled = false

    if not state.vendorButton then
        self:CreateVendorButton()
    end
    state.vendorButton:Show()
    self:UpdateButton()

    if not state.panelToggleTab then self:CreatePanelToggleButton() end

    if GetShowPanel() then
        if not state.junkPreviewPanel then self:CreatePreviewPanel() end
        C_Timer.After(0.25, function()
            if not IsMerchantWorkAllowed() then return end
            VPFilters.ScanVendor()
            if state.vendorDropdown and state.vendorDropdown.RefreshFilters then
                state.vendorDropdown:RefreshFilters()
            end
        end)
        self:UpdatePreviewPanel()
        if state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            self:ManageBlizzardSellButton(true)
            if state.panelToggleTab then
                state.panelToggleTab:SetChecked(true)
                local gui = OneWoW_GUI
                if gui then
                    local theme = (gui.GetSetting and gui:GetSetting("minimap.theme")) or "horde"
                    state.panelToggleTab.Icon:SetTexture(gui:GetBrandIcon(theme))
                end
                state.panelToggleTab.Icon:SetSize(24, 24)
                if MerchantFrameTabSideBar then
                    MerchantFrameTabSideBar.selTab = state._merchantSidebarIndex or 0
                end
            end
            if VendorPanel.RepositionMerchantSidebar then
                VendorPanel:RepositionMerchantSidebar()
            end
        end
    end

    C_Timer.After(0, function()
        if not state.moduleActive then return end
        VendorPanel:UpdatePanelToggleButton()
    end)

    -- Apply the persistent default merchant filter (ALL / current spec) on every open.
    C_Timer.After(0, function()
        if not IsMerchantWorkAllowed() then return end
        VendorPanel:SyncMerchantSpecFilter()
    end)
end

function VendorPanel:OnMerchantClosed()
    self:StopUpdates()
    if state._buttonRetry then state._buttonRetry:Cancel(); state._buttonRetry = nil end
    if state._merchantGridRetry then state._merchantGridRetry:Cancel(); state._merchantGridRetry = nil end
    if state.activeSellTicker then state.activeSellTicker:Cancel(); state.activeSellTicker = nil end
    if state.activeSellConfirmTicker then state.activeSellConfirmTicker:Cancel(); state.activeSellConfirmTicker = nil end
    state.vendorSellSeq = (state.vendorSellSeq or 0) + 1
    if state.activeSellErrFrame then state.activeSellErrFrame:UnregisterEvent("UI_ERROR_MESSAGE") end
    if state.vendorButton then state.vendorButton:Hide() end
    if state.panelToggleTab then state.panelToggleTab:SetChecked(false) end
    -- Suppress junkPreviewPanel OnHide → MerchantFrame_Update during teardown.
    state._closingMerchant = true
    if state.junkPreviewPanel then state.junkPreviewPanel:Hide() end
    state._closingMerchant = false
    self:ManageBlizzardSellButton(false)
    if state.neverSellDialog then state.neverSellDialog:Hide() end
    state.activePanelTab = "sell"
    state.currentVendorFilter = "Show All"
    wipe(state.availableFilters)
    state.oneTimeItems.ilvlGear = {}
    state.oneTimeItems.reagents = {}
    state.oneTimeItems.custom = {}
end

-- ============================================================
-- Module
-- ============================================================
function VendorPanelModule:OnEnable()
    local db = GetDB()
    if not db then return end
    if not db.settings then db.settings = {} end
    if not db.settings.panelWidth then db.settings.panelWidth = 320 end
    GetCustomFilters()
    local settings = GetSettings()
    if settings.gearSkipIlvl1 == nil then settings.gearSkipIlvl1 = true end
    state.moduleActive = true

    if not VendorPanel._saveFilterPopupRegistered then
        VendorPanel._saveFilterPopupRegistered = true
        StaticPopupDialogs["ONEWOW_VP_REPLACE_FILTER"] = {
            text = "",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                local pending = state._pendingFilterSave
                if pending then
                    VendorPanel:SaveCustomFilterSlot(pending.slotIndex, pending.name, pending.expr)
                    VendorPanel:RefreshCustomFilterButtons()
                    if state.saveFilterDialog then state.saveFilterDialog:Hide() end
                    print("OneWoW QoL: " .. string.format(L["VENDOR_FILTER_SAVED"], pending.name))
                    state._pendingFilterSave = nil
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local coreIS = GetItemStatus()
    if coreIS and (db.itemStatus or db.charItemStatus) then
        local coreDB = OneWoW.ItemStatus and OneWoW.ItemStatus:GetAllStatuses()
        if coreDB then
            local migrated = 0
            if db.itemStatus then
                for itemID, statusData in pairs(db.itemStatus) do
                    if not coreDB[tonumber(itemID)] then
                        coreDB[tonumber(itemID)] = statusData
                        migrated = migrated + 1
                    end
                end
            end
            if db.charItemStatus then
                for itemID, statusData in pairs(db.charItemStatus) do
                    if not coreDB[tonumber(itemID)] then
                        coreDB[tonumber(itemID)] = statusData
                        migrated = migrated + 1
                    end
                end
            end
            if migrated > 0 then
                print("|cFF00FF00OneWoW QoL|r: Migrated " .. migrated .. " item statuses to OneWoW Core")
            end
            db.itemStatus = nil
            db.charItemStatus = nil
        end
    end

    if coreIS and coreIS.RegisterCallback then
        coreIS:RegisterCallback("vendorpanel", function()
            if MerchantFrame and MerchantFrame:IsShown() then
                VendorPanel:UpdatePreviewPanel()
                VendorPanel:UpdateButton()
            end
            if state.neverSellDialog and state.neverSellDialog:IsShown() then
                VendorPanel:UpdateNeverSellDialog()
            end
        end)
    end

    if not state.playerClass then
        local _, classFilename, classId = UnitClass("player")
        state.playerClass = classFilename
        state.playerClassId = classId
    end

    if IsVendorFilterLoaded() then
        if not settings.vfNotified then
            settings.vfNotified = true
            C_Timer.After(5, function()
                print("|cFF00FF00OneWoW QoL|r: " .. L["VENDOR_VF_DETECTED"])
            end)
        end
    end

    Inventory.RegisterDirtyCallback("QoL_vendorpanel", function()
        VendorPanel:UpdateButton()
        VendorPanel:UpdatePreviewPanel()
    end)

    -- MERCHANT_SHOW / MERCHANT_CLOSED route through the core OneWoW.Merchant
    -- funnel (single MERCHANT_* owner). Module enable/disable maps onto
    -- subscribe / UnregisterCallback.
    OneWoW.Merchant.RegisterShowCallback("QoL_vendorpanel", function()
        VendorPanel:OnMerchantShow()
    end)
    OneWoW.Merchant.RegisterClosedCallback("QoL_vendorpanel", function()
        VendorPanel:OnMerchantClosed()
    end)

    local GUI = OneWoW_GUI
    if GUI and not self._guiCallbacksRegistered then
        self._guiCallbacksRegistered = true
        local function onSettingsChanged()
            VendorPanel:OnMerchantClosed()
            state.vendorButton = nil
            state.panelToggleTab = nil
            state._merchantSidebarIndex = nil
            state._merchantToggleHandler = nil
            state.junkPreviewPanel = nil
            state.replacementSellButton = nil
            state.addTab = nil
            state.optionsTab = nil
            state.neverSellDialog = nil
        end
        GUI:RegisterSettingsCallback("OnThemeChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnLanguageChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnIconThemeChanged", self, onSettingsChanged)
    end

    if not self._hookDone and MerchantFrame_Update then
        self._hookDone = true
        -- Permanent post-hook: WoW has no unhook for hooksecurefunc. Armed via
        -- state.moduleActive so soft module disable stops DispatchMerchantGridUpdate
        -- without requiring a full /reload (same pattern as Frame Mover's FM.active).
        hooksecurefunc("MerchantFrame_Update", function()
            if not state.moduleActive then return end
            -- Plumber refresh pass: Blizzard repopulated native slots; restore our
            -- filtered layout so Plumber's next UpdateShopUI reads mapped GetID().
            if state._plumberPostRemap then
                if VendorPanel:GridFilteringActive() then
                    VendorPanel:RenderMerchantGrid(true)
                end
                return
            end
            -- Remap synchronously so ItemButton:SetID() is correct before Plumber's
            -- deferred price pass (was 0.05s late, leaving stale slot-position costs).
            DispatchMerchantGridUpdate()
        end)
    end
end

function VendorPanelModule:OnDisable()
    state.moduleActive = false
    OneWoW.Merchant.UnregisterCallback("QoL_vendorpanel")
    Inventory.UnregisterCallback("QoL_vendorpanel")
    VendorPanel:OnMerchantClosed()
end

function VendorPanelModule:OnToggle(toggleId, value)
    if toggleId == "show_panel" then
        if not value and state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            state.junkPreviewPanel:Hide()
        end
        if state.optionsTab and state.optionsTab.showPanelCheck then
            state.optionsTab.showPanelCheck:SetChecked(value)
        end
    elseif toggleId == "show_blizz_junk" then
        if state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            VendorPanel:UpdatePreviewPanel()
        end
        if state.optionsTab and state.optionsTab.showBlizzCheck then
            state.optionsTab.showBlizzCheck:SetChecked(value)
        end
    end
end
